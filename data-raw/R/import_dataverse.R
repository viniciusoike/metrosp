# import_dataverse.R
# -----------------------------------------------------------------------------
# Lines 4 (Yellow/ViaQuatro) and 5 (Lilac/ViaMobilidade) passenger data from
# the Insper Dataverse (doi:10.60873/FK2/UTGQ0I).
#
# import_dataverse() fetches the raw daily-gate-entries data frame from the
# network. The clean_*_4_5() functions transform it into the three intermediate
# schemas. refresh_dataverse() is the gated side-effecting step that rewrites
# the committed processed CSVs (data-raw/processed/metro_sp_*_lines_4_5.csv),
# which the assemble_*() functions then read — mirroring the historical data
# treatment and keeping offline rebuilds reproducible.
#
# Refactored from import_lines_4_5_dataverse.R. The dataverse clean function for
# daily data was renamed (clean_daily_4_5) to avoid colliding with the METRO
# daily cleaner (clean_station_daily_metro).
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

#' Fetch the raw embarques_diarios data frame from the Insper Dataverse.
import_dataverse <- function() {
  server <- "dataverse.datascience.insper.edu.br"
  doi <- "doi:10.60873/FK2/UTGQ0I"

  cli::cli_inform("Fetching {.val emb_diarios.rds} from Dataverse...")

  with_retry(
    dataverse::get_dataframe_by_name(
      "emb_diarios.rds",
      dataset = doi,
      server = server,
      original = TRUE,
      .f = readr::read_rds
    ),
    what = "Dataverse fetch"
  )
}

# --- Cleaning helpers --------------------------------------------------------

# Filter to Lines 4/5 gate entries and join line metadata.
.prep_data_4_5 <- function(dat, type = "entrada") {
  valid_bus <- dim_bus$business_unit

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

# --- Cleaning functions ------------------------------------------------------

# Collapse station-level gate entries to one value per line-day. Every metric
# below is an average or a peak over these line-day totals; grouping the station
# rows directly divides the averages by the station count.
.entrance_line_daily <- function(dat) {
  .prep_data_4_5(dat) |>
    summarise(
      value = sum(value, na.rm = TRUE),
      .by = c(date, line_number)
    )
}

# Tag each line-day with its month and its calendar role. week_start is pinned
# because wday() otherwise reads the lubridate.week.start option, which would
# silently swap msa and mdo.
.entrance_tag_days <- function(daily) {
  daily |>
    mutate(
      date_month = lubridate::floor_date(date, "month"),
      wday = lubridate::wday(date, week_start = 7),
      is_business_day = bizdays::is.bizday(date, cal = "Brazil/ANBIMA")
    )
}

.entrance_monthly_metrics <- function(tagged) {
  tagged |>
    summarise(
      total = sum(value),
      msa = mean(value[wday == 7]),
      mdo = mean(value[wday == 1]),
      mdu = mean(value[is_business_day]),
      max = max(value),
      .by = c(date_month, line_number)
    )
}

.entrance_to_long <- function(monthly) {
  monthly |>
    tidyr::pivot_longer(
      cols = c(total, msa, mdo, mdu, max),
      names_to = "metric_abb",
      values_to = "value"
    ) |>
    left_join(dim_metric, by = join_by(metric_abb)) |>
    rename(date = date_month) |>
    mutate(year = lubridate::year(date)) |>
    select(all_of(.cols_passengers_entrance)) |>
    arrange(date, line_number, metric_abb)
}

# Produces: date, line_number, metric_abb, metric, value, year
clean_entrance_4_5 <- function(dat) {
  dat |>
    .entrance_line_daily() |>
    .entrance_tag_days() |>
    .entrance_monthly_metrics() |>
    .entrance_to_long()
}

# Produces: date, line_number, station_name, avg_passenger, year
clean_averages_4_5 <- function(dat) {
  dat <- .prep_data_4_5(dat, type = "transportado")

  dat <- dat |>
    mutate(station_name = fix_station_names_line5(station_name)) |>
    summarise(
      passengers_transported = sum(value, na.rm = TRUE),
      .by = c(date, line_number, station_name)
    )

  dat <- dat |>
    mutate(
      is_business_day = as.integer(bizdays::is.bizday(date, cal = "Brazil/ANBIMA"))
    ) |>
    filter(is_business_day == 1L)

  dat <- dat |>
    mutate(date_month = lubridate::floor_date(date, "month")) |>
    summarise(
      avg_passenger = mean(passengers_transported, na.rm = TRUE),
      .by = c(date_month, line_number, station_name)
    )

  dat <- dat |>
    rename(date = date_month) |>
    mutate(year = lubridate::year(date)) |>
    select(all_of(.cols_st_averages)) |>
    arrange(date, line_number, station_name)

  return(dat)
}

# Produces: date, year, line_number, station_code, station_name, passengers
# Lines 4/5 have no station codes (set to NA).
clean_daily_4_5 <- function(dat) {
  dat <- .prep_data_4_5(dat)

  dat <- dat |>
    mutate(
      year = lubridate::year(date),
      station_code = NA_character_,
      station_name = fix_station_names_line5(station_name),
      passengers = value
    ) |>
    select(all_of(.cols_st_daily)) |>
    arrange(date, line_number, station_name)

  return(dat)
}

# --- Gated refresh: rewrite the committed Lines 4/5 processed CSVs ------------

#' Fetch from Dataverse and regenerate the three Lines 4/5 processed CSVs.
#' Returns the path of the directory written (so a target can depend on it).
refresh_dataverse <- function(
  proc_dir = here::here("data-raw/processed")
) {
  raw <- import_dataverse()

  readr::write_csv(
    clean_entrance_4_5(raw),
    file.path(proc_dir, "metro_sp_passengers_entrance_lines_4_5.csv")
  )
  readr::write_csv(
    clean_averages_4_5(raw),
    file.path(proc_dir, "metro_sp_station_averages_lines_4_5.csv")
  )
  readr::write_csv(
    clean_daily_4_5(raw),
    file.path(proc_dir, "metro_sp_station_daily_lines_4_5.csv")
  )

  cli::cli_alert_success("Lines 4/5 CSVs refreshed in {.path {proc_dir}}.")
  invisible(proc_dir)
}
