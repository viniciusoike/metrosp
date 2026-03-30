library(dataverse)
library(dplyr)
library(here)
library(bizdays)
import::from(tidyr, pivot_longer)

source(here("data-raw/utils.R"))

# Data Import -------------------------------------------------------------

valid_tables <- c("passengers_entrance", "station_daily", "station_averages")

import_dataverse <- function(table) {
  if (!table %in% valid_tables) {
    cli::cli_abort(
      c(
        "{.arg table} must be one of {.val {valid_tables}}.",
        "x" = "Got {.val {table}}."
      )
    )
  }

  server <- "dataverse.datascience.insper.edu.br"

  # Which raw Dataverse dataset backs each output table?
  table_switch <- c(
    "passengers_entrance" = "embarques_diarios",
    "station_daily"       = "embarques_diarios",
    "station_averages"    = "embarques_diarios"
  )

  # DOIs on record (kept for reference / re-download)
  dois <- c(
    "media_embarques_diarios" = "10.60873/FK2/BPYHFB",
    "embarques_diarios"       = "doi:10.60873/FK2/UTGQ0I",
    "embarques_horarios"      = "doi:10.60873/FK2/9MZGJL",
    "linhas_estacoes"         = "doi:10.60873/FK2/YWXLQS"
  )

  # Corresponding .rds filenames on Dataverse (kept for reference)
  file_names <- c(
    "media_embarques_diarios" = "emb_media.rds",
    "embarques_diarios"       = "emb_diarios.rds",
    "embarques_horarios"      = "emb_horarios.rds",
    "linhas_estacoes"         = "dim_station.rds"
  )

  dataset_name <- table_switch[[table]]

  cli::cli_inform("Fetching {.val {file_names[[dataset_name]]}} from Dataverse...")

  dataverse::get_dataframe_by_name(
    file_names[[dataset_name]],
    dataset  = dois[[dataset_name]],
    server   = server,
    original = TRUE,
    .f       = readr::read_rds
  )
}


# Cleaning helpers --------------------------------------------------------

valid_bus <- dim_bus$business_unit

.prep_data <- function(dat) {
  dat |>
    filter(business_unit %in% valid_bus, tipo_embarque == "Bloqueio") |>
    rename(value = embarques, date = data) |>
    left_join(dim_bus, by = join_by(business_unit))
}

.compat_columns <- function(dat, table = NULL) {
  if (table %in% c("station_daily", "passengers_entrance")) {
    cols_select <- c(
      "date",
      "line_number",
      "metric_abb",
      "value",
      "metric",
      "line_name",
      "line_name_pt",
      "year"
    )
  } else if (table == "station_averages") {
    cols_select <- c(
      "date",
      "line_number",
      "station_name",
      "passengers",
      "line_name",
      "line_name_pt",
      "station_code",
      "year"
    )
  }

  return(cols_select)
}

.clean_daily <- function(dat, table = NULL) {
  cols_select <- .compat_columns(dat, table)

  clean_dat <- .prep_data(dat)

  clean_dat <- clean_dat |>
    mutate(
      year = lubridate::year(date),
      month = lubridate::month(date),
      dia_semana = lubridate::wday(date),
      is_business_day = as.integer(is.bizday(date, cal = "Brazil/ANBIMA"))
    )

  if (table == "station_daily") {
    cols_group <- c(
      "year",
      "month",
      "line_number",
      "station_name",
      "line_name",
      "line_name_pt"
    )
  } else if (table == "passengers_entrance") {
    cols_group <- c(
      "year",
      "month",
      "line_number",
      "line_name",
      "line_name_pt"
    )
  }

  clean_dat <- clean_dat |>
    summarise(
      total = sum(value, na.rm = TRUE),
      # Average across saturdays
      msa = mean(value[dia_semana == 7], na.rm = TRUE),
      # Average across sundays
      mdo = mean(value[dia_semana == 1], na.rm = TRUE),
      # Average across business days
      mdu = mean(value[is_business_day == 1], na.rm = TRUE),
      max = max(value, na.rm = TRUE),
      .by = all_of(cols_group)
    )

  clean_dat <- clean_dat |>
    tidyr::pivot_longer(
      cols = c("total", "msa", "mdo", "mdu", "max"),
      names_to = "metric_abb",
      values_to = "value"
    )

  clean_dat <- clean_dat |>
    left_join(dim_metric, by = join_by(metric_abb)) |>
    mutate(date = lubridate::make_date(year, month, 1)) |>
    select(all_of(cols_select))

  return(clean_dat)
}

.clean_station_averages <- function(dat) {
  cols_select <- .compat_columns(dat, "station_averages")

  clean_dat <- .prep_data(dat)

  clean_dat <- clean_dat |>
    mutate(
      year = lubridate::year(date),
      is_business_day = as.integer(is.bizday(date, cal = "Brazil/ANBIMA")),
      station_name = fix_station_names_line5(station_name),
      station_code = NA_character_
    ) |>
    select(all_of(cols_select))

  return(clean_dat)
}

fix_station_names_line5 <- function(x) {
  replace_values(
    x,
    "AACD - Servidor" ~ "AACD-Servidor",
    "Alto Da Boa Vista" ~ "Alto da Boa Vista",
    "Vila Das Belezas" ~ "Vila das Belezas"
  )
}


# Main entry point --------------------------------------------------------

get_data_4_5 <- function(table) {
  if (!table %in% valid_tables) {
    cli::cli_abort(
      c(
        "{.arg table} must be one of {.val {valid_tables}}.",
        "x" = "Got {.val {table}}."
      )
    )
  }

  cli::cli_inform("Processing table {.val {table}}...")

  dat <- import_dataverse(table)

  if (table %in% c("station_daily", "passengers_entrance")) {
    .clean_daily(dat, table)
  } else if (table == "station_averages") {
    .clean_station_averages(dat)
  }
}
