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

read_csv_stations_average <- function(path, year = 2020, line = 1) {
  skip <- dplyr::case_when(
    line == 1 & year == 2025 ~ 6,
    line == 1 ~ 5,
    line == 2 & year == 2025 ~ 37,
    line == 2 ~ 35,
    line == 3 & year == 2025 ~ 59,
    line == 3 ~ 56,
    line == 15 & year == 2025 ~ 84,
    line == 15 ~ 80,
    TRUE ~ NA_integer_
  )

  n_max <- dplyr::case_when(
    line == 1 ~ 23,
    line == 2 ~ 14,
    line == 3 ~ 18,
    line == 15 & year == 2020 ~ 10,
    # line == 15 & year == 2021 ~ 13,
    line == 15 ~ 11,
    TRUE ~ NA_integer_
  )

  dat <- readr::read_delim(
    path,
    delim = ";",
    skip = skip,
    na = c("- ", "-", " - "),
    n_max = n_max,
    locale = readr::locale(grouping_mark = ".", encoding = "ISO-8859-1"),
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
      station_name = stringr::str_remove(station_name, "¹|2|²|³|\\*"),
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

grid <- tidyr::expand_grid(
  year = 2020:2025,
  line = c(1, 2, 3, 15)
)

safe_import_station_average <- purrr::safely(import_csv_stations_average)
dat <- purrr::pmap(grid, safe_import_station_average)
n_errors <- sum(sapply(dat, \(x) !is.null(x$error)))

if (n_errors == 0) {
  stations_averages <- purrr::map(dat, \(x) x$result)
  stations_averages <- dplyr::bind_rows(stations_averages)
  readr::write_csv(
    stations_averages,
    here::here("data-raw/processed/metro_sp_stations_averages_2020_2025.csv")
  )
}
