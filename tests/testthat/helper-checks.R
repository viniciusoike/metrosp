# helper-checks.R
# -----------------------------------------------------------------------------
# Structural invariants for the demand datasets, defined once and asserted from
# two places:
#
#   1. tests/testthat/test-datasets.R -- against the frozen data/*.rda that
#      ships with the package (guards the snapshot; runs on CRAN).
#   2. data-raw/R/validate_refresh.R  -- against the freshly rebuilt datasets in
#      the scheduled pipeline (guards what gets published).
#
# That second caller is the reason these live here rather than in data-raw/R/:
# data-raw is build-ignored, but tests/ ships, so a helper file is the only
# place both can reach. Without this split the frozen snapshot would be tested
# and the fresh data would not -- the exact failure the freeze makes easy to
# miss.
#
# Every function returns a character vector of problems; character(0) means the
# data conforms. Tests assert emptiness, the pipeline reports the contents.
# -----------------------------------------------------------------------------

# --- Generic checks ----------------------------------------------------------

check_columns <- function(df, required, name) {
  missing <- setdiff(required, names(df))
  if (length(missing) == 0) {
    return(character(0))
  }
  sprintf("%s: missing column(s) %s", name, paste(missing, collapse = ", "))
}

check_types <- function(df, types, name) {
  problems <- character(0)
  for (col in intersect(names(types), names(df))) {
    ok <- types[[col]](df[[col]])
    if (!isTRUE(ok)) {
      problems <- c(problems, sprintf("%s$%s: unexpected type", name, col))
    }
  }
  problems
}

check_no_na <- function(df, cols, name) {
  problems <- character(0)
  for (col in intersect(cols, names(df))) {
    n <- sum(is.na(df[[col]]))
    if (n > 0) {
      problems <- c(problems, sprintf("%s$%s: %d NA value(s)", name, col, n))
    }
  }
  problems
}

check_non_negative <- function(df, col, name) {
  if (!col %in% names(df)) {
    return(character(0))
  }
  n <- sum(df[[col]] < 0, na.rm = TRUE)
  if (n == 0) {
    return(character(0))
  }
  sprintf("%s$%s: %d negative value(s)", name, col, n)
}

check_no_duplicates <- function(df, keys, name) {
  keys <- intersect(keys, names(df))
  if (length(keys) == 0) {
    return(character(0))
  }
  n <- sum(duplicated(df[, keys, drop = FALSE]))
  if (n == 0) {
    return(character(0))
  }
  sprintf(
    "%s: %d duplicate row(s) on %s",
    name,
    n,
    paste(keys, collapse = "/")
  )
}

check_rows <- function(df, min_rows, name) {
  if (nrow(df) >= min_rows) {
    return(character(0))
  }
  sprintf("%s: only %d row(s), expected at least %d", name, nrow(df), min_rows)
}

# --- Station-name hygiene ----------------------------------------------------

# Footnote digits/superscripts/asterisks glued on by the source spreadsheets
# ("Sé4", "Brooklin7", "Luz (3)").
.footnote_pattern <- "[0-9¹²³*]$|\\("

# Commercial naming-rights suffixes, which must never reach published data.
.sponsor_names <- c(
  "Carrão-Assaí Atacadista",
  "Penha-Lojas Besni",
  "Saúde-Ultrafarma",
  "Patriarca-Vila Ré"
)
.sponsor_plain <- c("Carrão", "Penha", "Saúde", "Patriarca")

check_station_names <- function(x, name) {
  problems <- character(0)

  marked <- unique(x[grepl(.footnote_pattern, x)])
  if (length(marked) > 0) {
    problems <- c(
      problems,
      sprintf(
        "%s: footnote markers in station name(s): %s",
        name,
        paste(utils::head(marked, 5), collapse = ", ")
      )
    )
  }

  present <- intersect(.sponsor_names, x)
  if (length(present) > 0) {
    problems <- c(
      problems,
      sprintf(
        "%s: sponsor suffix(es) present: %s",
        name,
        paste(present, collapse = ", ")
      )
    )
  }

  missing_plain <- setdiff(.sponsor_plain, x)
  if (length(missing_plain) > 0) {
    problems <- c(
      problems,
      sprintf(
        "%s: plain station name(s) absent: %s",
        name,
        paste(missing_plain, collapse = ", ")
      )
    )
  }

  # "Japao-Liberdade" (honorific rename, 2018) is canonical; a standalone
  # "Liberdade" would split the station's series across eras.
  if ("Liberdade" %in% x) {
    problems <- c(problems, sprintf("%s: non-canonical name 'Liberdade'", name))
  }
  if (!"Japão-Liberdade" %in% x) {
    problems <- c(
      problems,
      sprintf("%s: canonical name 'Japão-Liberdade' absent", name)
    )
  }

  problems
}

# --- Freshness ---------------------------------------------------------------

#' Flag a dataset whose coverage has fallen far behind the present.
#'
#' Catches a pipeline that silently stopped ingesting -- the failure mode where
#' every structural check still passes because the stale data is perfectly
#' well-formed. Lenient by default: METRO publishes irregularly, with observed
#' gaps of up to two months, so this is meant to catch "months behind", not
#' "this month is late".
check_freshness <- function(df, name, max_months_behind = 4, today = Sys.Date()) {
  if (!"date" %in% names(df) || nrow(df) == 0) {
    return(character(0))
  }
  months_behind <- as.numeric(
    difftime(today, max(df$date, na.rm = TRUE), units = "days")
  ) / 30.44
  if (months_behind <= max_months_behind) {
    return(character(0))
  }
  sprintf(
    "%s: latest date %s is %.1f months behind %s",
    name,
    format(max(df$date, na.rm = TRUE)),
    months_behind,
    format(today)
  )
}

#' Latest observed date per line.
#'
#' Lines legitimately end on different dates: Lines 4/5 come from the Dataverse
#' source, which lags the METRO portal, and drop_trailing_na() trims each line
#' to its own last published point. So "is a line missing from the latest
#' month?" is not a structural question -- it can only be answered against a
#' baseline, which is why the regression check on this lives in
#' data-raw/R/validate_refresh.R rather than here.
line_coverage <- function(df) {
  needed <- c("date", "line_number")
  if (!all(needed %in% names(df)) || nrow(df) == 0) {
    return(stats::setNames(as.Date(character(0)), character(0)))
  }
  cov <- tapply(df$date, df$line_number, max, na.rm = TRUE)
  stats::setNames(as.Date(cov, origin = "1970-01-01"), names(cov))
}

# --- Dataset-level composites ------------------------------------------------

check_passengers_entrance <- function(df, name = "passengers_entrance") {
  c(
    check_columns(
      df,
      c(
        "date", "year", "line_number", "line_name_pt", "line_name",
        "metric", "metric_abb", "value"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        year = is.numeric,
        line_number = is.numeric,
        value = is.double,
        metric_abb = is.character
      ),
      name
    ),
    check_no_na(df, "date", name),
    check_non_negative(df, "value", name),
    check_no_duplicates(df, c("date", "line_number", "metric_abb"), name),
    check_rows(df, 1L, name)
  )
}

check_passengers_transported <- function(df, name = "passengers_transported") {
  c(
    check_columns(df, c("date", "value", "line_number"), name),
    check_no_na(df, "date", name),
    check_non_negative(df, "value", name),
    check_no_duplicates(df, c("date", "line_number", "metric_abb"), name),
    check_rows(df, 1L, name)
  )
}

check_station_averages <- function(df, name = "station_averages") {
  c(
    check_columns(
      df,
      c(
        "date", "station_name", "avg_passenger", "line_number",
        "line_name_pt", "line_name"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        line_number = is.numeric,
        avg_passenger = is.double
      ),
      name
    ),
    check_no_na(df, "date", name),
    check_non_negative(df, "avg_passenger", name),
    check_no_duplicates(df, c("date", "line_number", "station_name"), name),
    check_rows(df, 1L, name),
    check_station_names(df$station_name, name)
  )
}

check_station_daily <- function(df, name = "station_daily") {
  problems <- c(
    check_columns(
      df,
      c(
        "date", "year", "line_number", "line_name_pt", "line_name",
        "station_code", "station_name", "passengers"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        year = is.numeric,
        line_number = is.numeric,
        station_code = is.character,
        station_name = is.character,
        passengers = is.double
      ),
      name
    ),
    check_no_na(df, c("date", "station_name", "passengers"), name),
    check_non_negative(df, "passengers", name),
    check_no_duplicates(df, c("date", "line_number", "station_name"), name),
    check_rows(df, 100000L, name),
    check_station_names(df$station_name, name)
  )

  # Lines 4/5 come from the Dataverse source, which carries no station codes.
  if (all(c("station_code", "line_number") %in% names(df))) {
    coded <- df[!df$line_number %in% c(4L, 5L), ]
    problems <- c(problems, check_no_na(coded, "station_code", name))
  }

  problems
}

#' Run every dataset check over a named list of built datasets.
#' Returns a named list of character vectors (empty ones included).
check_all_datasets <- function(datasets) {
  checkers <- list(
    passengers_entrance = check_passengers_entrance,
    passengers_transported = check_passengers_transported,
    station_averages = check_station_averages,
    station_daily = check_station_daily
  )

  out <- list()
  for (nm in names(checkers)) {
    if (!is.null(datasets[[nm]])) {
      out[[nm]] <- checkers[[nm]](datasets[[nm]])
    }
  }
  out
}
