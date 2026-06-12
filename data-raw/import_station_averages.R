# import_station_averages.R
# -------------------------------------------------------
# Imports station-level average weekday passenger entries (2020-present).
# Reads from: data-raw/metro_sp/metro/csv/demanda_de_passageiros_por_estacao_media_dias_uteis_*.csv
# Writes to:  data-raw/processed/metro_sp_stations_averages_{start}_{end}.csv
#
# Processes lines 1 (Azul), 2 (Verde), 3 (Vermelha), and 15 (Prata).
# Each line has a different skip/n_max in the CSV due to variable layout.
# Skip offsets are stored in .skip_offsets; add a new entry when the CSV
# format changes between years (as happened for 2025).
# -------------------------------------------------------

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
  # browser()
  dat <- read_csv_stations_average(path_csv, year = year, line = line)
  clean_dat <- clean_stations_average(dat, year = year, line = line)
  return(clean_dat)
}

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
      # Strip footnote markers ("Sé4", "Sé 2", "Luz (3)"); keep in sync with
      # clean_station_name() in data-raw/R/helpers.R
      station_name = stringr::str_remove_all(
        station_name,
        "\\s*\\([0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]*\\)|\\s*[0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]+$"
      ),
      station_name = stringr::str_squish(station_name),
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

source(here::here("data-raw/utils.R"))

grid_year <- get_available_years()

grid <- tidyr::expand_grid(
  year = grid_year,
  line = c(1, 2, 3, 15)
)

safe_import_station_average <- purrr::safely(import_csv_stations_average)
dat <- purrr::pmap(grid, safe_import_station_average)
n_errors <- sum(sapply(dat, \(x) !is.null(x$error)))

if (n_errors == 0) {
  cli::cli_alert_success("Process successfully without errors.")
  stations_averages <- purrr::map(dat, \(x) x$result)
  stations_averages <- dplyr::bind_rows(stations_averages)

  name_file <- stringr::str_glue(
    "metro_sp_station_averages_{min(grid_year)}_{max(grid_year)}.csv"
  )

  readr::write_csv(
    stations_averages,
    here::here("data-raw/processed", name_file)
  )
}
