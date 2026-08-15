# helpers.R
# -----------------------------------------------------------------------------
# Path lookup, CSV parsing, and numeric-conversion helpers used by the import
# builders. Lifted verbatim from the former data-raw/utils.R (and the
# n_days_in_month helper from import_station_daily.R).
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# --- Network retry -------------------------------------------------------------

#' Retry an expression that hits the network.
#' Both upstream sources (METRO portal, Insper Dataverse) are unattended
#' dependencies of the scheduled pipeline, where a single transient 5xx should
#' not fail a whole run. Backs off exponentially and re-raises the last error.
with_retry <- function(expr, tries = 3L, base_wait = 2, what = "request") {
  expr <- rlang::enquo(expr)

  for (i in seq_len(tries)) {
    result <- tryCatch(rlang::eval_tidy(expr), error = function(e) e)

    if (!inherits(result, "error")) {
      return(result)
    }

    if (i == tries) {
      cli::cli_abort(
        "{what} failed after {tries} attempt{?s}.",
        parent = result
      )
    }

    wait <- base_wait * 2^(i - 1L)
    cli::cli_alert_warning(
      "{what} failed (attempt {i}/{tries}); retrying in {wait}s."
    )
    Sys.sleep(wait)
  }
}

# --- Footnote markers --------------------------------------------------------

# Footnote markers leaking from the source spreadsheets: digits, superscripts,
# or asterisks at the end of a label ("Sé4", "Sé 2", "Brooklin7", "Linha 5 -
# Lilás²") or wrapped in parentheses anywhere ("Luz (3)", "Ana Rosa ()").
.footnote_pattern <- "\\s*\\([0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]*\\)|\\s*[0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]+$"

#' Strip source-spreadsheet footnote markers from a station or line label.
#' Used by the readers, again at assembly (defense in depth, so a stale
#' committed CSV can never leak markers into data/*.rda), and by the block
#' detectors, which read the same labels out of the raw header rows.
#' Squish first: the marker is anchored to the end of the string, so a trailing
#' space in the source ("Linha 5 - Lilás² ") would otherwise defeat the anchor.
strip_footnotes <- function(x) {
  x <- stringr::str_squish(x)
  stringr::str_squish(stringr::str_remove_all(x, .footnote_pattern))
}

# --- Trailing-NA trimmer -----------------------------------------------------

#' Drop rows beyond the last observed (non-NA) date per line.
#' Preserves legitimate interior NAs (e.g. station outages) while removing
#' unpublished trailing months/days that arrive as all-NA from the source.
drop_trailing_na <- function(data, value_col) {
  value_col <- rlang::enquo(value_col)
  max_date <- data |>
    filter(!is.na(!!value_col)) |>
    summarise(max_date = max(date, na.rm = TRUE), .by = line_number)
  data |>
    left_join(max_date, by = "line_number") |>
    filter(date <= max_date) |>
    select(-max_date)
}

# --- Path helpers ------------------------------------------------------------

#' List years available in the raw CSV directory.
get_available_years <- function(
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  files <- list.files(datadir, pattern = "\\.csv$")
  years <- suppressWarnings(as.integer(stringr::str_extract(files, "\\d{4}")))
  sort(unique(years[!is.na(years) & years >= 2020]))
}

#' Get path to a CSV file for current-era (2020-present) data.
get_path_csv <- function(
  year = 2020,
  variable = "stations",
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  var_pattern <- c(
    "stations_daily" = "estacao_diaria",
    "stations" = "estacao_media_dias_uteis",
    "transport" = "transportados_por_linha",
    "entrance" = "passageiros_por_linha"
  )

  available_variables <- names(var_pattern)

  if (!variable %in% available_variables) {
    cli::cli_abort("Variable {variable} not available.")
  }

  valid_years <- get_available_years(datadir)
  if (
    length(year) > 0 && length(valid_years) > 0 && !any(year %in% valid_years)
  ) {
    cli::cli_abort(
      "Year {year} not available. Valid years: {min(valid_years)}-{max(valid_years)}."
    )
  }

  pat <- var_pattern[variable]
  pat <- paste0(pat, "_", as.character(year))

  path_csv <- list.files(datadir, pattern = "\\.csv$", full.names = TRUE)
  path_csv <- path_csv[stringr::str_detect(path_csv, pat)]

  return(path_csv)
}

#' Get path to files for 2017-2019 data (nested folders by year/month).
get_path_flds <- function(year, variable = "transport") {
  valid_vars <- c("transport", "entrance", "daily")

  if (length(variable) != 1) {
    cli::cli_abort("Argument {.arg variable} must be a length 1 string.")
  }

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  # Each year uses a different folder name
  fld <- case_when(
    year == 2017 ~ "2017",
    year == 2018 ~ "2018",
    year == 2019 ~ "demanda_2019",
    year == 2020 ~ "demanda_2020"
  )

  path_files <- list.files(
    here::here(stringr::str_glue("data-raw/metro_sp/metro/{fld}")),
    pattern = "\\.csv$",
    recursive = TRUE,
    full.names = TRUE
  )

  # Portuguese month names for sorting
  # fmt: skip
  mes <- c("Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
           "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  )

  # Match file paths by variable type
  pat <- case_when(
    variable == "transport" ~ "Transportados por Linha",
    variable == "entrance" ~ "Passageiros por Linha",
    variable == "daily" ~ "Dias"
  )

  path <- path_files[stringr::str_detect(path_files, pat)]

  # For daily data, further filter to station-level files
  if (variable == "daily") {
    path <- path[stringr::str_detect(path, "Esta")]
  }

  df_line <- tibble(path = path) |>
    mutate(
      name = stringr::str_extract(path, paste(mes, collapse = "|")),
      name = if_else(is.na(name), "Março", name),
      name = factor(name, levels = mes)
    ) |>
    arrange(name)

  return(df_line)
}

#' Number of days in a given month/year (from import_station_daily.R).
n_days_in_month <- function(year, month) {
  next_first <- if (month == 12L) {
    as.Date(paste(year + 1L, 1L, 1L, sep = "-"))
  } else {
    as.Date(paste(year, month + 1L, 1L, sep = "-"))
  }
  as.integer(next_first - as.Date(paste(year, month, 1L, sep = "-")))
}

# --- Numeric conversion ------------------------------------------------------

#' Convert Portuguese-formatted numbers to numeric ("1.234" = 1234).
#' The source pads some cells with spaces and writes an unobserved month as a
#' bare dash, so squish first and treat a lone dash as missing.
as_numeric_pt <- function(x) {
  if (!is.character(x)) {
    return(x)
  }

  # The source marks an unobserved cell with dashes or footnote asterisks.
  y <- stringr::str_squish(x)
  y[grepl("^[-*]*$", y)] <- NA_character_
  y <- gsub("\\.", "", y)
  y <- gsub(",", ".", y)

  as.numeric(y)
}

# --- Block detection ----------------------------------------------------------

# The METRO files are spreadsheets exported to CSV: one table per line, stacked
# or set side by side, with title rows, footnotes and padding columns around
# them. Every block announces itself in the text ("LINHA 1-AZUL", "REDE",
# "Mês;Total;..."), so the readers below locate blocks by scanning for those
# markers. Row offsets are never hardcoded: the source added header rows in 2025
# and again in 2026, and a stale offset table fails silently.

#' Split a block-label row into its line labels.
#' "LINHA 1-AZUL ¹;;;;;;;LINHA 2-VERDE ²" -> c("LINHA 1-AZUL", "LINHA 2-VERDE")
split_line_labels <- function(row) {
  labels <- strip_footnotes(stringr::str_split_1(row, ";"))
  labels[nzchar(labels)]
}

#' Line number behind a raw block label. "REDE" carries no digits: it is the
#' network total, which the pipeline numbers 99.
label_line_number <- function(labels) {
  num <- suppressWarnings(as.integer(stringr::str_extract(labels, "\\d{1,2}")))
  if_else(is.na(num), 99L, num)
}

# --- Passengers by line (annual files: 2016 and 2020-present) -----------------
# One file per year and measure. Blocks hold months in rows and the five metrics
# in columns, two lines side by side except for the last (REDE alone in the
# current era, L15 + REDE in 2016). Reading the block-label row makes the line
# layout self-describing, so 2016 needs no special case.

#' Read a raw annual passenger-by-line CSV into one wide frame.
#' Columns are named "<line_number>|<metric_abb>".
read_psg_line <- function(path) {
  raw_lines <- readLines(path, encoding = "latin1")

  # Each block's first data row is January; the labels sit two rows above it,
  # separated by the "Mês;Total;MDU;..." metric header.
  data_rows <- grep("^Jan\\*?;", raw_lines)

  if (length(data_rows) == 0L) {
    cli::cli_abort("No month blocks found in {.path {path}}.")
  }

  parcels <- purrr::map(data_rows, \(row) {
    lines <- label_line_number(split_line_labels(raw_lines[row - 2L]))

    # Side-by-side blocks are separated by one empty padding column.
    per_line <- purrr::map(
      lines,
      \(n) paste(n, c("month", dim_metric$metric_abb), sep = "|")
    )
    col_names <- unlist(purrr::imap(
      per_line,
      \(nms, i) if (i == 1L) nms else c(paste0("pad_", i), nms)
    ))

    readr::read_delim(
      path,
      delim = ";",
      skip = row - 1L,
      n_max = nrow(dim_month),
      locale = readr::locale(encoding = "ISO-8859-1"),
      col_names = col_names,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE
    ) |>
      select(-matches("^pad_")) |>
      select(where(~ !all(is.na(.x))))
  })

  bind_cols(parcels)
}

#' Reshape a wide annual passenger-by-line frame into the long import schema.
clean_psg_line <- function(dat, year) {
  # Every block repeats the month column; keep the first and drop the rest.
  months <- stringr::str_squish(stringr::str_remove(dat[[1]], "\\*"))

  dat |>
    select(-matches("\\|month$")) |>
    mutate(month_abb = months) |>
    tidyr::pivot_longer(-month_abb, values_transform = as_numeric_pt) |>
    tidyr::separate(
      name,
      into = c("line_number", "metric_abb"),
      sep = "\\|",
      convert = TRUE
    ) |>
    left_join(dim_month, by = join_by(month_abb)) |>
    left_join(dim_metric, by = join_by(metric_abb)) |>
    mutate(
      year = local(year),
      date = as.Date(paste(year, month_num, "01", sep = "-"))
    ) |>
    select(all_of(.cols_psg_entrance))
}

# --- Station averages (annual files: 2016 and 2020-present) -------------------
# One section per line, stations in rows and months in columns, closed by a
# "Total" row that is excluded. 2016 additionally carries Line 5.

#' Read a raw annual station-averages CSV into one wide frame: one row per
#' station, tagged with line_number.
read_stn_avg <- function(path) {
  raw_lines <- readLines(path, encoding = "latin1")

  starts <- grep("^LINHA", raw_lines)
  ends <- grep("^Total", raw_lines)

  if (length(starts) == 0L || length(starts) != length(ends)) {
    cli::cli_abort(c(
      "Malformed station-averages file {.path {path}}.",
      "x" = "Found {length(starts)} line header{?s} but {length(ends)} total row{?s}."
    ))
  }

  lines <- label_line_number(
    strip_footnotes(stringr::str_remove(raw_lines[starts], ";.*$"))
  )

  sections <- purrr::pmap(
    list(starts, ends, lines),
    \(start, end, line_number) {
      readr::read_delim(
        path,
        delim = ";",
        # Skip past the label row so "Estação;Jan;..." names the columns, and
        # stop one row short of "Total".
        skip = start,
        n_max = end - start - 2L,
        locale = readr::locale(encoding = "ISO-8859-1"),
        col_types = readr::cols(.default = readr::col_character()),
        name_repair = janitor::make_clean_names,
        show_col_types = FALSE
      ) |>
        mutate(line_number = line_number, .before = 1)
    }
  )

  bind_rows(sections)
}

#' Reshape a wide annual station-averages frame into the long import schema.
clean_stn_avg <- function(dat, year) {
  dat |>
    select(-any_of("media")) |>
    tidyr::pivot_longer(
      cols = -c(line_number, estacao),
      names_to = "month_abb",
      values_to = "avg_passenger",
      values_transform = as_numeric_pt
    ) |>
    filter(!is.na(avg_passenger)) |>
    mutate(
      station_name = strip_footnotes(estacao),
      # make_clean_names() lowercases the month headers ("jan", "fev", ...).
      month_abb = stringr::str_to_title(stringr::str_remove(month_abb, "\\*")),
      year = local(year)
    ) |>
    left_join(dim_month, by = join_by(month_abb)) |>
    mutate(date = as.Date(paste(year, month_num, "01", sep = "-"))) |>
    select(all_of(.cols_stn_avg))
}
