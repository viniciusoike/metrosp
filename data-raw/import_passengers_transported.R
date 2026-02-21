# import_passengers_transported.R
# -------------------------------------------------------
# Imports passengers transported data by metro line (2020-2025).
# Reads from: data-raw/metro_sp/metro/csv/passageiros_transportados_por_linha_*.csv
# Writes to:  data-raw/processed/metro_sp_passengers_tranported_2020_2025.csv
#
# Structure is identical to import_passengers_entrance.R but reads
# "transport" instead of "entrance" variable from get_path_csv().
#
# Uses read_csv_passengers() and clean_csv_passengers() from utils.R.
# -------------------------------------------------------

library(dplyr)
library(readr)
source(here::here("data-raw/utils.R"))

import_passengers_transported <- function(year = 2020) {
  path <- get_path_csv(year, "transport")
  dat <- read_csv_passengers(path, year = year)
  clean_dat <- clean_csv_passengers(dat, year = year)
  return(clean_dat)
}

grid_year <- 2020:2025
safe_import_passengers <- purrr::safely(import_passengers_transported)
passengers <- purrr::map(grid_year, safe_import_passengers)
n_errors <- sum(sapply(passengers, \(x) !is.null(x$error)))

if (n_errors == 0) {
  passengers_transported <- purrr::map(passengers, \(x) x$result)
  passengers_transported <- dplyr::bind_rows(passengers_transported)
  readr::write_csv(
    passengers_transported,
    here::here(
      "data-raw/processed/metro_sp_passengers_tranported_2020_2025.csv"
    )
  )
  cli::cli_alert_success("Passengers transported processed.")
}
