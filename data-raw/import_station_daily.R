# import_station_daily.R
# -------------------------------------------------------
# Imports daily station-level passenger entrance data (2020-2025).
# Reads from: data-raw/metro_sp/metro/csv/entrada_de_passageiros_por_estacao_diaria_*.csv
# Writes to:  data-raw/processed/metro_sp_stations_daily_2020_2025.csv
#
# Each CSV has 12 monthly sections with 4 metro lines side-by-side,
# separated by ;; (double semicolons). Header positions are found via
# readLines (robust against variable block sizes across years), and
# n_max is set to the number of days in each month.
# -------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(readr)
library(tidyr)
library(stringr)
source(here::here("data-raw/utils.R"))

# Line numbers in the order they appear left-to-right in the CSV
line_order <- c(1L, 2L, 3L, 15L)

# --- Helper -------------------------------------------------------------------

#' Number of days in a given month/year.
n_days_in_month <- function(year, month) {
  next_first <- if (month == 12L) {
    as.Date(paste(year + 1L, 1L, 1L, sep = "-"))
  } else {
    as.Date(paste(year, month + 1L, 1L, sep = "-"))
  }
  as.integer(next_first - as.Date(paste(year, month, 1L, sep = "-")))
}

# --- Core functions ----------------------------------------------------------

#' Import daily station data for one year.
#'
#' @param year Integer year (2020-2025).
#' @return A tidy data frame with daily passenger entries per station.
import_station_daily <- function(year = 2020) {
  path <- get_path_csv(year = year, variable = "stations_daily")
  if (length(path) == 0) {
    cli::cli_abort("No daily station CSV found for year {year}.")
  }

  # Find DIA header positions (robust against variable block sizes)
  raw_lines <- readLines(path, encoding = "latin1")
  dia_positions <- grep("^DIA;", raw_lines)

  parcels <- list()

  for (month in seq_along(dia_positions)) {
    if (month > 12L) break
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

    if (is.null(dat) || nrow(dat) == 0) next

    attr(dat, "month_num") <- month
    parcels[[length(parcels) + 1]] <- dat
  }

  clean_dat <- clean_station_daily(parcels, year = year)
  return(clean_dat)
}

#' Split a wide monthly data frame into per-line sub-tables.
#'
#' Each monthly section has 4 line blocks separated by empty columns
#' (from the ;; separator in the CSV). Separator columns are detected
#' by their auto-generated names (x, x_2, x_3) from janitor::make_clean_names.
#'
#' @param dat Wide data frame from a single month's read.
#' @return A list of data frames (one per metro line).
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

  # Drop empty trailing section (trailing ;; creates a separator at end)
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

#' Clean and reshape all monthly data for one year.
#'
#' For each month: splits into 4 line sub-tables, pivots to long format,
#' assigns station names, constructs dates, and binds everything together.
#'
#' @param parcels List of wide data frames (one per month).
#' @param year Integer year.
#' @return A tidy data frame with one row per station per day.
clean_station_daily <- function(parcels, year) {
  all_data <- list()

  for (i in seq_along(parcels)) {
    dat <- parcels[[i]]
    month_num <- attr(dat, "month_num")

    line_tables <- split_lines_from_wide(dat)

    for (j in seq_along(line_tables)) {
      sub <- line_tables[[j]]

      # First column is "dia" (day number), last is "total"
      col_names <- names(sub)
      dia_col <- col_names[1]

      # Station columns are everything between dia and total
      station_cols <- col_names[2:(length(col_names) - 1)]

      if (length(station_cols) == 0) next

      # Clean day column: remove asterisks, convert to integer
      sub[[dia_col]] <- as.integer(gsub("\\*", "", as.character(sub[[dia_col]])))

      # Select dia + station columns only (drop total)
      sub <- sub[, c(dia_col, station_cols), drop = FALSE]

      # Pivot to long format
      long <- tidyr::pivot_longer(
        sub,
        cols = -1,
        names_to = "station_code",
        values_to = "passengers"
      )

      names(long)[1] <- "day"

      # Clean station codes
      long$station_code <- trimws(tolower(long$station_code))

      # Remove duplicate suffixes from make_clean_names (e.g., "anr_2" -> "anr")
      # These occur because some station codes appear on multiple lines
      # (ANR = Ana Rosa on both Line 1 and Line 2, PSO = Paraíso, PSE = Sé)
      long$station_code <- gsub("_\\d+$", "", long$station_code)

      # Convert passengers: remove thousands separator (dot), replace decimal
      # comma with dot, then convert to numeric.
      # Portuguese format: "1.234,5" = 1234.5 (thousands)
      long$passengers <- as.numeric(gsub(",", ".", gsub("\\.", "", long$passengers)))

      # Add metadata
      long$year <- year
      long$month <- month_num
      long$line_number <- line_order[j]

      # Construct date
      long$date <- as.Date(
        paste(year, month_num, long$day, sep = "-"),
        format = "%Y-%m-%d"
      )

      all_data[[length(all_data) + 1]] <- long
    }
  }

  result <- dplyr::bind_rows(all_data)

  # Join with station code lookup to get full station names
  result <- result |>
    dplyr::left_join(
      dim_station_code,
      by = c("station_code", "line_number")
    ) |>
    # Drop rows with NA passengers (missing/test data like dashes)
    dplyr::filter(!is.na(passengers), !is.na(date)) |>
    dplyr::select(date, year, line_number, station_code, station_name, passengers) |>
    dplyr::arrange(date, line_number, station_code)

  return(result)
}

# --- Execute -----------------------------------------------------------------

safe_import <- purrr::safely(import_station_daily)
results <- purrr::map(2020:2025, safe_import)

errors <- purrr::map(results, "error")
n_errors <- sum(!sapply(errors, is.null))

if (n_errors > 0) {
  for (i in seq_along(errors)) {
    if (!is.null(errors[[i]])) {
      cli::cli_warn("Year {2019 + i}: {errors[[i]]$message}")
    }
  }
}

stations_daily <- dplyr::bind_rows(purrr::map(results, "result"))

cli::cli_alert_success(
  "Imported {nrow(stations_daily)} daily station rows ({min(stations_daily$year)}-{max(stations_daily$year)})"
)

readr::write_csv(
  stations_daily,
  here::here("data-raw/processed/metro_sp_stations_daily_2020_2025.csv")
)

cli::cli_alert_success("Wrote data-raw/processed/metro_sp_stations_daily_2020_2025.csv")
