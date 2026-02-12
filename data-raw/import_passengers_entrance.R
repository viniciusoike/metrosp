# import_passengers_entrance.R
# -------------------------------------------------------
# Imports passenger entrance data by metro line (2020-2025).
# Reads from: data-raw/metro_sp/metro/csv/entrada_de_passageiros_por_linha_*.csv
# Writes to:  data-raw/processed/metro_sp_passengers_entrance_2020_2025.csv
#
# The raw CSVs are semicolon-delimited with ISO-8859-1 encoding.
# Each file contains 3 sections (batches) for different line groups,
# read separately and bound by column.
#
# Uses read_csv_passengers() and clean_csv_passengers() from utils.R.
# -------------------------------------------------------

library(dplyr)
library(readr)
source(here::here("data-raw/utils.R"))

import_passengers_entrance <- function(year = 2020) {
  path <- get_path_csv(year, "entrance")
  dat <- read_csv_passengers(path)
  clean_dat <- clean_csv_passengers(dat, year = year)
  return(clean_dat)
}

grid_year <- 2020:2025
safe_import_passengers <- purrr::safely(import_passengers_entrance)
passengers <- purrr::map(grid_year, safe_import_passengers)
n_errors <- sum(sapply(passengers, \(x) !is.null(x$error)))

if (n_errors == 0) {
  passengers <- purrr::map(passengers, \(x) x$result)
  passengers <- dplyr::bind_rows(passengers)
  readr::write_csv(
    passengers,
    here::here("data-raw/processed/metro_sp_passengers_entrance_2020_2025.csv")
  )
}
