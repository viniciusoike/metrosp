# import_metro_current.R
# -----------------------------------------------------------------------------
# Builder functions for current-era (2020-present) METRO data (Lines 1, 2, 3,
# 15), read from the raw transparency-portal CSVs in
# data-raw/metro_sp/metro/csv/ (gitignored).
#
# Each build_*_current() returns an in-memory tibble. refresh_metro_current() is
# the gated side-effecting step that writes them to the committed processed CSVs
# (data-raw/processed/metro_sp_*_current.csv), which the assemble_*() functions
# then read -- mirroring refresh_historic_*() and refresh_dataverse(). This is
# what makes the graph rebuildable offline and gives every upstream change a
# reviewable text diff.
#
# Refactored from import_passengers_entrance.R, import_passengers_transported.R,
# import_station_averages.R, and import_station_daily.R.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# --- Passengers entrance / transported by line -------------------------------

import_passengers_line <- function(year, variable) {
  path <- get_path_csv(year, variable)
  dat <- read_csv_passengers(path, year = year)
  clean_csv_passengers(dat, year = year)
}

#' Build current-era passengers entrance (2020-present).
#' Schema: date, line_number, metric_abb, metric, value, year.
build_entrance_current <- function(years = get_available_years()) {
  purrr::map(years, \(y) import_passengers_line(y, "entrance")) |>
    dplyr::bind_rows()
}

#' Build current-era passengers transported (2020-present).
build_transported_current <- function(years = get_available_years()) {
  purrr::map(years, \(y) import_passengers_line(y, "transport")) |>
    dplyr::bind_rows()
}

# --- Station averages (weekday) by station -----------------------------------

get_skip_offset <- function(year, line) {
  .skip_offsets <- list(
    default = c(`1` = 5L, `2` = 35L, `3` = 56L, `15` = 80L),
    `2025` = c(`1` = 5L, `2` = 36L, `3` = 58L, `15` = 83L),
    `2026` = c(`1` = 7L, `2` = 38L, `3` = 61L, `15` = 86L)
  )

  if (as.character(year) %in% names(.skip_offsets)) {
    offsets <- .skip_offsets[[as.character(year)]]
  } else {
    offsets <- .skip_offsets[["default"]]
  }

  return(offsets[[as.character(line)]])
}

read_csv_stations_average <- function(path, year = 2020, line = 1) {
  skip <- get_skip_offset(year, line)

  n_max <- dplyr::case_when(
    line == 1 ~ 23L,
    line == 2 ~ 14L,
    line == 3 ~ 18L,
    line == 15 & year == 2020 ~ 10L,
    line == 15 ~ 11L,
    TRUE ~ NA_integer_
  )

  ncols <- stringr::str_count(readLines(path, n = 1), ";")
  col_types <- paste0(rep("c", ncols + 1), collapse = "")

  dat <- readr::read_delim(
    path,
    delim = ";",
    skip = skip,
    na = c("- ", "-", " - ", ""),
    n_max = n_max,
    locale = readr::locale(grouping_mark = ".", encoding = "ISO-8859-1"),
    col_types = col_types,
    show_col_types = FALSE,
    name_repair = janitor::make_clean_names
  )

  return(dat)
}

clean_stations_average <- function(dat, year = 2020, line = 1) {
  clean_dat <- dat |>
    janitor::clean_names() |>
    dplyr::select(dplyr::where(~ !all(is.na(.x))))

  drop_cols <- c("media")

  rename_cols <- c("station_name" = "estacao")

  sel_cols <- c(
    "date",
    "line_number",
    "station_name",
    "avg_passenger",
    "year"
  )

  clean_dat <- clean_dat |>
    dplyr::select(-dplyr::any_of(drop_cols)) |>
    tidyr::pivot_longer(
      cols = -1,
      names_to = "month_abb",
      values_to = "avg_passenger",
      values_transform = as.numeric
    )

  clean_dat <- clean_dat |>
    dplyr::rename(dplyr::any_of(rename_cols)) |>
    dplyr::mutate(
      station_name = clean_station_name(station_name),
      month_abb = stringr::str_remove(month_abb, "\\*"),
      year = year,
      line_number = line,
      date = readr::parse_date(
        glue::glue("{year}-{month_abb}-01"),
        format = "%Y-%b-%d",
        locale = readr::locale("pt")
      )
    ) |>
    dplyr::select(dplyr::any_of(sel_cols))

  return(clean_dat)
}

import_csv_stations_average <- function(
  variable = "stations",
  year = 2020,
  line = 1,
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  path_csv <- get_path_csv(variable = variable, year = year, datadir = datadir)

  if (length(path_csv) == 0) {
    cli::cli_abort("No files found.")
  }
  dat <- read_csv_stations_average(path_csv, year = year, line = line)
  clean_dat <- clean_stations_average(dat, year = year, line = line)
  return(clean_dat)
}

#' Build current-era station averages (2020-present), lines 1/2/3/15.
#' Schema: date, line_number, station_name, avg_passenger, year.
build_averages_current <- function(years = get_available_years()) {
  grid <- tidyr::expand_grid(
    year = years,
    line = c(1, 2, 3, 15)
  )

  purrr::pmap(grid, import_csv_stations_average) |>
    dplyr::bind_rows()
}

# --- Station daily entries ----------------------------------------------------

# Line numbers in the order they appear left-to-right in the daily CSV.
line_order <- c(1L, 2L, 3L, 15L)

split_lines_from_wide <- function(dat) {
  col_names <- names(dat)
  sep_positions <- which(grepl("^x(_\\d+)?$", col_names))

  n_cols <- ncol(dat)
  starts <- c(1L)
  ends <- c()

  for (pos in sep_positions) {
    ends <- c(ends, pos - 1L)
    starts <- c(starts, pos + 1L)
  }
  ends <- c(ends, n_cols)

  valid <- starts <= ends
  starts <- starts[valid]
  ends <- ends[valid]

  if (length(starts) != 4) {
    cli::cli_warn(
      "Expected 4 line sections, found {length(starts)}. Using available sections."
    )
  }

  line_tables <- list()
  for (j in seq_along(starts)) {
    cols <- starts[j]:ends[j]
    sub_dat <- dat[, cols, drop = FALSE]
    line_tables[[j]] <- sub_dat
  }

  return(line_tables)
}

clean_station_daily_metro <- function(parcels, year) {
  all_data <- list()

  for (i in seq_along(parcels)) {
    dat <- parcels[[i]]
    month_num <- attr(dat, "month_num")

    line_tables <- split_lines_from_wide(dat)

    for (j in seq_along(line_tables)) {
      sub <- line_tables[[j]]

      col_names <- names(sub)
      dia_col <- col_names[1]

      station_cols <- col_names[2:(length(col_names) - 1)]

      if (length(station_cols) == 0) {
        next
      }

      sub[[dia_col]] <- as.integer(gsub(
        "\\*",
        "",
        as.character(sub[[dia_col]])
      ))

      sub <- sub[, c(dia_col, station_cols), drop = FALSE]

      long <- tidyr::pivot_longer(
        sub,
        cols = -1,
        names_to = "station_code",
        values_to = "passengers"
      )

      names(long)[1] <- "day"

      long$station_code <- trimws(tolower(long$station_code))
      long$station_code <- gsub("_\\d+$", "", long$station_code)

      long$passengers <- as.numeric(gsub(
        ",",
        ".",
        gsub("\\.", "", long$passengers)
      ))

      long$year <- year
      long$month <- month_num
      long$line_number <- line_order[j]

      long$date <- as.Date(
        paste(year, month_num, long$day, sep = "-"),
        format = "%Y-%m-%d"
      )

      all_data[[length(all_data) + 1]] <- long
    }
  }

  result <- dplyr::bind_rows(all_data)

  result <- result |>
    dplyr::left_join(
      dim_station_code,
      by = c("station_code", "line_number")
    ) |>
    dplyr::filter(!is.na(passengers), !is.na(date)) |>
    dplyr::select(
      date,
      year,
      line_number,
      station_code,
      station_name,
      passengers
    ) |>
    dplyr::arrange(date, line_number, station_code)

  return(result)
}

import_station_daily_year <- function(year = 2020) {
  path <- get_path_csv(year = year, variable = "stations_daily")
  if (length(path) == 0) {
    cli::cli_abort("No daily station CSV found for year {year}.")
  }

  raw_lines <- readLines(path, encoding = "latin1")
  dia_positions <- grep("^DIA;", raw_lines)

  parcels <- list()

  for (month in seq_along(dia_positions)) {
    if (month > 12L) {
      break
    }
    skip <- dia_positions[month] - 1L
    n_max <- n_days_in_month(year, month)

    dat <- tryCatch(
      readr::read_delim(
        path,
        delim = ";",
        skip = skip,
        n_max = n_max,
        na = c("- ", "-", " - ", ""),
        col_types = readr::cols(.default = readr::col_character()),
        locale = readr::locale(encoding = "ISO-8859-1"),
        show_col_types = FALSE,
        name_repair = janitor::make_clean_names
      ),
      error = function(e) NULL
    )

    if (is.null(dat) || nrow(dat) == 0) {
      next
    }

    attr(dat, "month_num") <- month
    parcels[[length(parcels) + 1]] <- dat
  }

  clean_dat <- clean_station_daily_metro(parcels, year = year)
  return(clean_dat)
}

#' Build current-era daily station entries (2020-present), lines 1/2/3/15.
#' Schema: date, year, line_number, station_code, station_name, passengers.
build_station_daily_current <- function(years = get_available_years()) {
  safe_import <- purrr::safely(import_station_daily_year)
  results <- purrr::map(years, safe_import)

  errors <- purrr::map(results, "error")
  n_errors <- sum(!sapply(errors, is.null))

  if (n_errors > 0) {
    for (i in seq_along(errors)) {
      if (!is.null(errors[[i]])) {
        cli::cli_warn("Year {years[i]}: {errors[[i]]$message}")
      }
    }
  }

  dplyr::bind_rows(purrr::map(results, "result"))
}

# --- Gated refresh: rewrite the committed current-era processed CSVs ----------

# Filenames carry no year range: the current era is open-ended, and a hardcoded
# range would need renaming every January in an unattended pipeline. This also
# matches the `import_{dataset}` (no period suffix) script convention.
.current_csv_names <- c(
  entrance = "metro_sp_passengers_entrance_current.csv",
  transported = "metro_sp_passengers_transported_current.csv",
  averages = "metro_sp_station_averages_current.csv",
  daily = "metro_sp_station_daily_current.csv"
)

#' Rebuild the four current-era processed CSVs from the raw portal files.
#' Returns the path of the directory written (so a target can depend on it).
refresh_metro_current <- function(
  proc_dir = here::here("data-raw/processed")
) {
  readr::write_csv(
    build_entrance_current(),
    file.path(proc_dir, .current_csv_names[["entrance"]])
  )
  readr::write_csv(
    build_transported_current(),
    file.path(proc_dir, .current_csv_names[["transported"]])
  )
  readr::write_csv(
    build_averages_current(),
    file.path(proc_dir, .current_csv_names[["averages"]])
  )
  readr::write_csv(
    build_station_daily_current(),
    file.path(proc_dir, .current_csv_names[["daily"]])
  )

  cli::cli_alert_success("Current-era CSVs refreshed in {.path {proc_dir}}.")
  invisible(proc_dir)
}
