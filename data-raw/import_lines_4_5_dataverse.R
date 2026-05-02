# import_lines45_dataverse.R
# -------------------------------------------------------
# Imports Lines 4 (Yellow/ViaQuatro) and 5 (Lilac/ViaMobilidade) passenger
# data from the Insper Dataverse (doi:10.60873/FK2/UTGQ0I).
#
# Source: embarques_diarios (emb_diarios.rds) — daily gate entries per station.
# Writes three processed CSVs to data-raw/processed/:
#   metro_sp_passengers_entrance_lines45.csv
#   metro_sp_station_averages_lines45.csv
#   metro_sp_station_daily_lines45.csv
# -------------------------------------------------------

library(dataverse)
library(dplyr)
library(here)
library(bizdays)
import::from(tidyr, pivot_longer)
import::from(lubridate, year, month, wday, make_date)

source(here("data-raw/utils.R"))

# Data Import -----------------------------------------------------------------

import_dataverse <- function() {
  server <- "dataverse.datascience.insper.edu.br"
  doi <- "doi:10.60873/FK2/UTGQ0I"

  cli::cli_inform("Fetching {.val emb_diarios.rds} from Dataverse...")

  dataverse::get_dataframe_by_name(
    "emb_diarios.rds",
    dataset = doi,
    server = server,
    original = TRUE,
    .f = readr::read_rds
  )
}

# Cleaning helpers ------------------------------------------------------------

valid_bus <- dim_bus$business_unit

# Filter to Lines 4/5 gate entries and join line metadata.
.prep_data <- function(dat, type = "entrada") {
  dat <- dat |>
    filter(business_unit %in% valid_bus) |>
    rename(value = embarques, date = data) |>
    left_join(dim_bus, by = join_by(business_unit))

  if (type == "entrada") {
    dat <- subset(dat, tipo_embarque == "Bloqueio")
  }

  return(dat)
}

fix_station_names_line5 <- function(x) {
  replace_values(
    x,
    "AACD - Servidor" ~ "AACD-Servidor",
    "Alto Da Boa Vista" ~ "Alto da Boa Vista",
    "Vila Das Belezas" ~ "Vila das Belezas"
  )
}

# Cleaning functions ----------------------------------------------------------

# Produces: date, line_number, metric_abb, metric, value, year
# Matches schema of metro_sp_passengers_entrance_2020_2025.csv
clean_passengers_entrance <- function(dat) {
  .prep_data(dat) |>
    mutate(
      year = year(date),
      month = month(date),
      dia_semana = wday(date),
      is_business_day = as.integer(is.bizday(date, cal = "Brazil/ANBIMA"))
    ) |>
    summarise(
      total = sum(value, na.rm = TRUE),
      msa = mean(value[dia_semana == 7], na.rm = TRUE),
      mdo = mean(value[dia_semana == 1], na.rm = TRUE),
      mdu = mean(value[is_business_day == 1], na.rm = TRUE),
      max = max(value, na.rm = TRUE),
      .by = c(year, month, line_number)
    ) |>
    pivot_longer(
      cols = c(total, msa, mdo, mdu, max),
      names_to = "metric_abb",
      values_to = "value"
    ) |>
    left_join(dim_metric, by = join_by(metric_abb)) |>
    mutate(date = make_date(year, month, 1L)) |>
    select(all_of(.cols_passengers_entrance)) |>
    arrange(date, line_number, metric_abb)
}

# Produces: date, line_number, station_name, avg_passenger, year
# Matches schema of metro_sp_stations_averages_2020_2025.csv
clean_station_averages <- function(dat) {
  dat <- .prep_data(dat, type = "transportado")

  dat <- dat |>
    mutate(
      year = year(date),
      month = month(date),
      is_business_day = as.integer(is.bizday(date, cal = "Brazil/ANBIMA")),
      station_name = fix_station_names_line5(station_name)
    )

  dat <- dat |>
    filter(is_business_day == 1L) |>
    summarise(
      avg_passenger = mean(value, na.rm = TRUE),
      .by = c(year, month, line_number, station_name)
    )

  dat <- dat |>
    mutate(date = make_date(year, month, 1L)) |>
    select(all_of(.cols_st_averages)) |>
    arrange(date, line_number, station_name)

  return(dat)
}

# Produces: date, year, line_number, station_code, station_name, passengers
# Matches schema of metro_sp_stations_daily_2020_2025.csv
# Lines 4/5 have no station codes (set to NA).
clean_station_daily <- function(dat) {
  dat <- .prep_data(dat)

  dat <- dat |>
    mutate(
      year = year(date),
      station_code = NA_character_,
      station_name = fix_station_names_line5(station_name),
      passengers = value
    ) |>
    select(all_of(.cols_st_daily)) |>
    arrange(date, line_number, station_name)

  return(dat)
}


# Main ------------------------------------------------------------------------

cli::cli_inform("Fetching Lines 4 and 5 data from Dataverse...")
raw <- import_dataverse()

cli::cli_inform("Processing {.val passengers_entrance}...")
dat_entrance <- clean_passengers_entrance(raw)

cli::cli_inform("Processing {.val station_averages}...")
dat_averages <- clean_station_averages(raw)

cli::cli_inform("Processing {.val station_daily}...")
dat_daily <- clean_station_daily(raw)

readr::write_csv(
  dat_entrance,
  here("data-raw/processed/metro_sp_passengers_entrance_lines_4_5.csv")
)
readr::write_csv(
  dat_averages,
  here("data-raw/processed/metro_sp_station_averages_lines_4_5.csv")
)
readr::write_csv(
  dat_daily,
  here("data-raw/processed/metro_sp_station_daily_lines_4_5.csv")
)

cli::cli_alert_success(
  "Lines 4 and 5 CSVs written to {.path data-raw/processed/}."
)
