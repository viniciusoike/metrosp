# helper-checks.R
# -----------------------------------------------------------------------------
# Structural invariants for the demand datasets, defined once and asserted from
# two places:
#
#   1. tests/testthat/test-datasets.R -- against the frozen data/*.rda that
#      ships with the package (guards the snapshot; runs on CRAN).
#   2. data-raw/R/publish/validate_refresh.R  -- against the freshly rebuilt datasets in
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

check_absent_values <- function(df, col, disallowed, name) {
  if (!col %in% names(df)) {
    return(character(0))
  }
  present <- intersect(unique(df[[col]]), disallowed)
  if (length(present) == 0) {
    return(character(0))
  }
  sprintf(
    "%s$%s: disallowed value(s) %s",
    name,
    col,
    paste(present, collapse = ", ")
  )
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

check_values <- function(df, col, allowed, name) {
  if (!col %in% names(df)) {
    return(character(0))
  }
  unexpected <- setdiff(unique(df[[col]]), allowed)
  if (length(unexpected) == 0) {
    return(character(0))
  }
  sprintf(
    "%s$%s: unexpected value(s) %s",
    name,
    col,
    paste(unexpected, collapse = ", ")
  )
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
check_freshness <- function(
  df,
  name,
  max_months_behind = 4,
  today = Sys.Date()
) {
  if (!"date" %in% names(df) || nrow(df) == 0) {
    return(character(0))
  }
  months_behind <- as.numeric(
    difftime(today, max(df$date, na.rm = TRUE), units = "days")
  ) /
    30.44
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
#' data-raw/R/publish/validate_refresh.R rather than here.
line_coverage <- function(df) {
  needed <- c("date", "line_number")
  if (!all(needed %in% names(df)) || nrow(df) == 0) {
    return(stats::setNames(as.Date(character(0)), character(0)))
  }
  cov <- tapply(df$date, df$line_number, max, na.rm = TRUE)
  stats::setNames(as.Date(cov, origin = "1970-01-01"), names(cov))
}

# --- Dataset-level composites ------------------------------------------------

# July 2017 entrance data was never published for the METRO-operated lines.
# Line 4 is present because it comes from the separate Dataverse source. Keep
# this exception source-aware: a generic monthly-grid check would either flag
# valid data or silently normalize the gap away.
check_entrance_july_2017_gap <- function(df, name = "line_entries_monthly") {
  if (!all(c("date", "line_number") %in% names(df))) {
    return(character(0))
  }

  july <- df[format(df$date, "%Y-%m") == "2017-07", , drop = FALSE]
  actual <- sort(unique(as.integer(july$line_number)))

  if (identical(actual, 4L)) {
    return(character(0))
  }

  sprintf(
    "%s: July 2017 should contain only Line 4; found line(s): %s",
    name,
    if (length(actual) == 0) "none" else paste(actual, collapse = ", ")
  )
}

check_line_entries_monthly <- function(df, name = "line_entries_monthly") {
  c(
    check_columns(
      df,
      c(
        "date",
        "year",
        "line_number",
        "line_name",
        "line_name_pt",
        "metric",
        "metric_name",
        "metric_name_pt",
        "value"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        year = is.integer,
        line_number = is.integer,
        value = is.double,
        metric = is.character
      ),
      name
    ),
    # metric labels come from a lookup keyed on Portuguese text; an unmatched
    # key leaves them NA rather than erroring, so assert them directly.
    check_no_na(
      df,
      c("date", "line_number", "metric", "metric_name", "metric_name_pt"),
      name
    ),
    check_absent_values(df, "line_number", 99L, name),
    check_values(df, "metric", c("total", "mdu", "msa", "mdo", "max"), name),
    check_entrance_july_2017_gap(df, name),
    check_non_negative(df, "value", name),
    check_no_duplicates(df, c("date", "line_number", "metric"), name),
    check_rows(df, 1L, name)
  )
}

check_line_transported_monthly <- function(
  df,
  name = "line_transported_monthly"
) {
  c(
    check_columns(
      df,
      c(
        "date",
        "year",
        "line_number",
        "line_name",
        "line_name_pt",
        "metric",
        "metric_name",
        "metric_name_pt",
        "value"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        year = is.integer,
        line_number = is.integer,
        value = is.double,
        metric = is.character
      ),
      name
    ),
    check_no_na(
      df,
      c("date", "line_number", "metric", "metric_name", "metric_name_pt"),
      name
    ),
    check_absent_values(df, "line_number", 99L, name),
    check_values(df, "metric", c("total", "mdu", "msa", "mdo", "max"), name),
    check_non_negative(df, "value", name),
    check_no_duplicates(df, c("date", "line_number", "metric"), name),
    check_rows(df, 1L, name)
  )
}

check_station_transported_monthly <- function(
  df,
  name = "station_transported_monthly"
) {
  problems <- c(
    check_columns(
      df,
      c(
        "date",
        "year",
        "station_id",
        "station_name",
        "value",
        "line_number",
        "line_name_pt",
        "line_name",
        "metric",
        "metric_name",
        "metric_name_pt"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        year = is.integer,
        line_number = is.integer,
        station_id = is.character,
        value = is.double,
        metric = is.character
      ),
      name
    ),
    check_no_na(df, c("date", "station_id"), name),
    check_no_na(df, c("metric", "metric_name", "metric_name_pt"), name),
    check_values(df, "metric", "mdu", name),
    check_non_negative(df, "value", name),
    check_no_duplicates(
      df,
      c("date", "line_number", "station_id", "metric"),
      name
    ),
    check_rows(df, 1L, name),
    check_station_names(df$station_name, name)
  )

  # Line 5's post-handover rows are turnstile-only and live in the daily
  # table; the monthly transported table must not carry them.
  if (all(c("line_number", "date") %in% names(df))) {
    n_bad <- sum(
      df$line_number %in% 5L & df$date >= as.Date("2018-08-01"),
      na.rm = TRUE
    )
    if (n_bad > 0) {
      problems <- c(
        problems,
        sprintf(
          "%s: %d Line 5 row(s) from Aug 2018 or later",
          name,
          n_bad
        )
      )
    }
  }

  problems
}

check_station_entries_daily <- function(df, name = "station_entries_daily") {
  problems <- c(
    check_columns(
      df,
      c(
        "date",
        "year",
        "line_number",
        "station_id",
        "line_name_pt",
        "line_name",
        "station_code",
        "station_name",
        "value"
      ),
      name
    ),
    check_types(
      df,
      list(
        date = function(x) inherits(x, "Date"),
        year = is.integer,
        line_number = is.integer,
        station_id = is.character,
        station_code = is.character,
        station_name = is.character,
        value = is.double
      ),
      name
    ),
    check_no_na(df, c("date", "station_id", "station_name", "value"), name),
    check_non_negative(df, "value", name),
    check_no_duplicates(df, c("date", "line_number", "station_id"), name),
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

check_line_5_operator <- function(df, name) {
  needed <- c("type", "line_number", "company_name")
  if (!all(needed %in% names(df))) {
    return(character(0))
  }

  line_5 <- df$type %in% "metro" & df$line_number %in% 5L
  wrong <- line_5 &
    (is.na(df$company_name) | df$company_name != "ViaMobilidade")
  n <- sum(wrong)
  if (n == 0) {
    return(character(0))
  }
  sprintf("%s: %d Line 5 row(s) have the wrong operator", name, n)
}

check_rail_lines <- function(df, name = "rail_lines") {
  check_line_5_operator(df, name)
}

check_rail_stations <- function(df, name = "rail_stations") {
  check_line_5_operator(df, name)
}

#' Run every dataset check over a named list of built datasets.
#' Returns a named list of character vectors (empty ones included).
check_all_datasets <- function(datasets) {
  checkers <- list(
    line_entries_monthly = check_line_entries_monthly,
    line_transported_monthly = check_line_transported_monthly,
    station_transported_monthly = check_station_transported_monthly,
    station_entries_daily = check_station_entries_daily,
    rail_lines = check_rail_lines,
    rail_stations = check_rail_stations
  )

  out <- list()
  for (nm in names(checkers)) {
    if (!is.null(datasets[[nm]])) {
      out[[nm]] <- checkers[[nm]](datasets[[nm]])
    }
  }

  # Cross-dataset reconciliation: station sums against line totals.
  if (
    !is.null(datasets$station_transported_monthly) &&
      !is.null(datasets$line_transported_monthly)
  ) {
    out$station_transported_monthly <- c(
      out$station_transported_monthly,
      check_station_transported_agreement(
        datasets$station_transported_monthly,
        datasets$line_transported_monthly
      )
    )
  }
  if (
    !is.null(datasets$station_entries_daily) &&
      !is.null(datasets$line_entries_monthly)
  ) {
    out$station_entries_daily <- c(
      out$station_entries_daily,
      check_daily_entries_agreement(
        datasets$station_entries_daily,
        datasets$line_entries_monthly
      )
    )
  }
  if (
    !is.null(datasets$line_entries_monthly) &&
      !is.null(datasets$line_transported_monthly)
  ) {
    out$line_transported_monthly <- c(
      out$line_transported_monthly,
      check_transported_gte_entries(
        datasets$line_entries_monthly,
        datasets$line_transported_monthly
      )
    )
  }

  out
}

# --- Reconciliation ----------------------------------------------------------

# Station transported mdu summed by line should approximate line transported
# mdu: both measure boardings plus transfers. Compares the median ratio per
# line (robust to isolated source months such as Line 2 May 2022 and Line 5
# November 2017, each ~5% off with exact neighbors). Excludes Line 15
# (station values rounded to the thousand) and Feb–Jun 2016 Line 1 (known
# source defect where the station sum runs ~14% below the line mdu).
check_station_transported_agreement <- function(
  station_df,
  line_df,
  name = "station_transported_monthly",
  tol = 0.02
) {
  needed_station <- c("date", "line_number", "metric", "value")
  needed_line <- c("date", "line_number", "metric", "value")
  if (
    !all(needed_station %in% names(station_df)) ||
      !all(needed_line %in% names(line_df))
  ) {
    return(character(0))
  }

  station_mdu <- station_df[station_df$metric == "mdu", , drop = FALSE]
  line_mdu <- line_df[line_df$metric == "mdu", , drop = FALSE]
  if (nrow(station_mdu) == 0 || nrow(line_mdu) == 0) {
    return(character(0))
  }

  station_sum <- stats::aggregate(
    station_mdu$value,
    by = list(
      date = station_mdu$date,
      line_number = station_mdu$line_number
    ),
    FUN = sum,
    na.rm = TRUE
  )
  names(station_sum)[3] <- "station_value"

  merged <- merge(
    station_sum,
    line_mdu[, c("date", "line_number", "value")],
    by = c("date", "line_number"),
    all = FALSE
  )
  names(merged)[names(merged) == "value"] <- "line_value"
  if (nrow(merged) == 0) {
    return(character(0))
  }

  # Known exclusions: Line 15 rounding, Feb–Jun 2016 Line 1 defect.
  excluded <- merged$line_number == 15L |
    (merged$line_number == 1L &
      merged$date >= as.Date("2016-02-01") &
      merged$date <= as.Date("2016-06-01"))
  merged <- merged[!excluded, , drop = FALSE]
  if (nrow(merged) == 0) {
    return(character(0))
  }

  merged <- merged[
    !is.na(merged$station_value) & !is.na(merged$line_value),
    ,
    drop = FALSE
  ]
  merged <- merged[merged$line_value > 0, , drop = FALSE]
  if (nrow(merged) == 0) {
    return(character(0))
  }

  merged$ratio <- merged$station_value / merged$line_value
  medians <- tapply(
    merged$ratio,
    merged$line_number,
    stats::median,
    na.rm = TRUE
  )
  bad <- abs(medians - 1) > tol
  bad <- bad[!is.na(bad)]
  if (!any(bad)) {
    return(character(0))
  }

  worst_line <- names(medians)[which.max(abs(medians - 1))]
  sprintf(
    "%s: line(s) %s have a median station-to-line mdu ratio outside %.0f%% (worst: line %s, %.3f)",
    name,
    paste(names(medians)[bad], collapse = ", "),
    tol * 100,
    worst_line,
    medians[[worst_line]]
  )
}

# Station daily summed by line-month should equal line entries total. METRO
# station values are rounded to the thousand, so allow 1%.
check_daily_entries_agreement <- function(
  daily_df,
  entries_df,
  name = "station_entries_daily",
  tol = 0.01
) {
  if (
    !all(c("date", "line_number", "value") %in% names(daily_df)) ||
      !all(c("date", "line_number", "metric", "value") %in% names(entries_df))
  ) {
    return(character(0))
  }

  daily_df$month <- as.Date(format(daily_df$date, "%Y-%m-01"))
  daily_sum <- stats::aggregate(
    daily_df$value,
    by = list(date = daily_df$month, line_number = daily_df$line_number),
    FUN = sum,
    na.rm = TRUE
  )
  names(daily_sum)[3] <- "daily_value"

  entries_total <- entries_df[entries_df$metric == "total", , drop = FALSE]
  if (nrow(entries_total) == 0) {
    return(character(0))
  }

  merged <- merge(
    daily_sum,
    entries_total[, c("date", "line_number", "value")],
    by = c("date", "line_number"),
    all = FALSE
  )
  names(merged)[names(merged) == "value"] <- "line_value"
  if (nrow(merged) == 0) {
    return(character(0))
  }

  merged <- merged[
    !is.na(merged$daily_value) & !is.na(merged$line_value),
    ,
    drop = FALSE
  ]
  merged <- merged[merged$line_value > 0, , drop = FALSE]
  if (nrow(merged) == 0) {
    return(character(0))
  }

  rel <- abs(merged$daily_value - merged$line_value) / merged$line_value
  bad <- rel > tol
  if (!any(bad)) {
    return(character(0))
  }

  worst <- merged[which.max(rel), , drop = FALSE]
  sprintf(
    "%s: %d line-month(s) differ by more than %.0f%% from line entries total (worst: line %s at %s, %.1f%%)",
    name,
    sum(bad),
    tol * 100,
    worst$line_number,
    format(worst$date),
    max(rel, na.rm = TRUE) * 100
  )
}

# Transported adds transfers to turnstile entries, so it can only run above
# entries. August 2018 Line 5 transported covers only the days before the
# ViaMobilidade handover and is excluded.
check_transported_gte_entries <- function(
  entries_df,
  transported_df,
  name = "line_transported_monthly"
) {
  keys <- c("date", "line_number", "metric")
  if (
    !all(keys %in% names(entries_df)) ||
      !all(keys %in% names(transported_df))
  ) {
    return(character(0))
  }

  paired <- merge(
    entries_df[c(keys, "value")],
    transported_df[c(keys, "value")],
    by = keys,
    suffixes = c("_entries", "_transported")
  )
  if (nrow(paired) == 0) {
    return(character(0))
  }

  partial <- paired$line_number == 5L & paired$date == as.Date("2018-08-01")
  paired <- paired[paired$metric == "total" & !partial, , drop = FALSE]
  if (nrow(paired) == 0) {
    return(character(0))
  }

  paired <- paired[
    !is.na(paired$value_entries) & !is.na(paired$value_transported),
    ,
    drop = FALSE
  ]
  bad <- paired$value_transported < paired$value_entries
  if (!any(bad)) {
    return(character(0))
  }

  worst <- paired[
    which.min(
      paired$value_transported - paired$value_entries
    ),
    ,
    drop = FALSE
  ]
  sprintf(
    "%s: %d month(s) with transported below entries (worst: line %s at %s)",
    name,
    sum(bad),
    worst$line_number,
    format(worst$date)
  )
}
