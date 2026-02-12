# import_station_daily.R
# -------------------------------------------------------
# INCOMPLETE: This script was intended to process daily station-level
# passenger entrance data from 2020-2025.
#
# The daily data format is complex: each monthly section has a variable
# number of rows (matching days in the month), with different skip offsets.
# All 6 daily CSVs (2020-2025) exist in data-raw/metro_sp/metro/csv/.
#
# Not needed for the current package release (v0.1.0) which uses
# monthly averages from import_station_averages.R instead.
# -------------------------------------------------------

library(dplyr)
library(readr)
source(here::here("data-raw/utils.R"))

dim_dates <- tibble(
  date = seq(as.Date("2020-01-01"), as.Date("2025-12-31"), by = "1 day")
)

days_month <- dim_dates |>
  mutate(
    year = lubridate::year(date),
    month = lubridate::month(date)
  ) |>
  count(year, month, name = "n_days")

import_station_daily <- function(year = 2020) {
  path <- get_path_csv(year, "stations_daily")
  dat <- read_csv_stations(path)
  clean_dat <- clean_csv_stations(dat, year = year)
  return(clean_dat)
}

get_path_csv(year = 2020, variable = "stations_daily")

params <- subset(days_month, year == 2020)

skip <- 6
k <- c(0, 7, 5, 6, 5, 6, 5, 5, 6, 5, rep(5, 8))

for (i in 2:11) {
  skip[i] <- skip[i - 1] + params$n_days[i] + k[i]
}

path <- get_path_csv(year = 2020, variable = "stations_daily")

parcels <- list()

for (i in 1:12) {
  parcels[[i]] <- readr::read_delim(
    path,
    delim = ";",
    skip = skip[i],
    n_max = params$n_days[i],
    na = c("- ", "-", " - "),
    locale = readr::locale(encoding = "ISO-8859-1", grouping_mark = "."),
    show_col_types = FALSE,
    name_repair = janitor::make_clean_names
  )
}

sapply(parcels, names)
parcels[[3]]


read_delim(
  get_path_csv(year = 2020, variable = "stations_daily"),
  delim = ";",
  skip = 6,
  n_max = 31,
  na = c("- ", "-", " - "),
  locale = locale(encoding = "ISO-8859-1", grouping_mark = "."),
  show_col_types = FALSE
)

read_delim(
  get_path_csv(year = 2020, variable = "stations_daily"),
  delim = ";",
  skip = 6 + 31 + 5,
  n_max = 27,
  na = c("- ", "-", " - "),
  locale = locale(encoding = "ISO-8859-1", grouping_mark = "."),
  show_col_types = FALSE
)


read_csv_stations <- function(path, year = 2020) {
  skip <- c(6, 25, 45)
  if (year == 2025) {
    skip <- c(7, 23, 39)
  }

  metric_names <- c("month", "total", "mdu", "msa", "mdo", "max")
  line_names <- c("azul", "verde", "vermelha", "prata", "rede")
  comb_names <- paste(rep(line_names, each = 6), metric_names, sep = "_")

  col_names <- list(
    c1 = c(comb_names[1:6], "drop_col", comb_names[7:12]),
    c2 = c(comb_names[13:18], "drop_col", comb_names[19:24]),
    c3 = comb_names[25:30]
  )
}
