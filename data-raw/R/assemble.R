# assemble.R
# -----------------------------------------------------------------------------
# Harmonize the 2017-2019, current-era (2020-present), and Lines 4/5 sources
# into the four exported passenger/station datasets. Refactored from
# make_datasets.R: each section becomes a function taking its inputs as
# arguments (historical / Lines 4/5 read from the committed processed CSVs;
# current-era passed in from the import builders). Sanity checks (stopifnot)
# live inside the relevant function so a failed check fails that target.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# Map Portuguese variable names to metric abbreviations (case-insensitive).
.metric_map_keys <- c(
  "total" = "total",
  "média dos dias úteis" = "mdu",
  "média dos sábados" = "msa",
  "média dos domingos" = "mdo",
  "máxima diária" = "max"
)

map_metric <- function(x) {
  .metric_map_keys[tolower(trimws(x))]
}

# --- passengers_entrance -----------------------------------------------------

#' @param psg_17_19 Raw historic passengers tibble (entrance + transport).
#' @param entrance_current Current-era entrance tibble (import builder output).
#' @param entrance_4_5 Lines 4/5 entrance tibble (committed CSV).
assemble_entrance <- function(psg_17_19, entrance_current, entrance_4_5) {
  entrance_17_19 <- psg_17_19 |>
    filter(measure == "entrance") |>
    mutate(metric_abb = map_metric(variable)) |>
    left_join(
      select(dim_metric, metric_abb, metric, metric_pt),
      by = "metric_abb"
    ) |>
    filter_out(line_number == 5L & date >= as.Date("2018-08-01"))

  entrance_20 <- entrance_current |>
    left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
    mutate(
      line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
    ) |>
    left_join(metro_lines, by = join_by(line_number))

  entrance_4_5 <- entrance_4_5 |>
    left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
    left_join(metro_lines, by = join_by(line_number))

  passengers_entrance <- bind_rows(entrance_17_19, entrance_20) |>
    # Adjust values to match Lines 4/5 (Dataverse source)
    mutate(value = value * 1000)

  passengers_entrance <- bind_rows(passengers_entrance, entrance_4_5) |>
    drop_trailing_na(value) |>
    select(all_of(.cols_passengers)) |>
    arrange(date, line_number, metric_abb)

  stopifnot(
    "NA dates in passengers_entrance" = !any(is.na(passengers_entrance$date))
  )

  passengers_entrance
}

# --- passengers_transported --------------------------------------------------

#' @param psg_17_19 Raw historic passengers tibble (entrance + transport).
#' @param transported_current Current-era transported tibble (builder output).
assemble_transported <- function(psg_17_19, transported_current) {
  transported_17_19 <- psg_17_19 |>
    filter(measure == "transport") |>
    mutate(metric_abb = map_metric(variable)) |>
    left_join(
      select(dim_metric, metric_abb, metric, metric_pt),
      by = "metric_abb"
    )

  transported_20 <- transported_current |>
    left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
    mutate(
      line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
    ) |>
    left_join(metro_lines, by = join_by(line_number))

  passengers_transported <- bind_rows(transported_17_19, transported_20) |>
    drop_trailing_na(value) |>
    select(all_of(.cols_passengers)) |>
    arrange(date, line_number, metric_abb)

  stopifnot(
    "NA dates in passengers_transported" = !any(
      is.na(passengers_transported$date)
    )
  )

  passengers_transported
}

# --- station_averages --------------------------------------------------------

# Parse line_name_full -> line_number (historic averages).
.line_lookup_avg <- c(
  "Linha 1 - Azul" = 1L,
  "Linha 2 - Verde" = 2L,
  "Linha 3 - Vermelha" = 3L,
  "Linha 5 - Lilás" = 5L,
  "Linha 5 - Lilás9" = 5L, # Fix typo in raw data
  "Linha 15 - Prata" = 15L
)

.cols_station_avg_in <- c(
  "date", "year", "line_number", "station_name", "avg_passenger"
)

.cols_station_avg_out <- c(
  "date", "line_number", "station_name", "avg_passenger",
  "line_name", "line_name_pt", "year"
)

#' @param stations_17_19 Raw historic station-averages tibble (committed CSV).
#' @param averages_current Current-era averages tibble (builder output).
#' @param averages_4_5 Lines 4/5 averages tibble (committed CSV).
assemble_averages <- function(stations_17_19, averages_current, averages_4_5) {
  station_renames <- dim_station_name_change$station_name_full
  names(station_renames) <- dim_station_name_change$station_name

  stations_17_19 <- stations_17_19 |>
    mutate(
      line_number = .line_lookup_avg[line_name_full],
      station_name = name_station
    ) |>
    rename(avg_passenger = value) |>
    select(all_of(.cols_station_avg_in))

  station_averages <- bind_rows(stations_17_19, averages_current) |>
    mutate(avg_passenger = avg_passenger * 1000)

  station_averages <- bind_rows(station_averages, averages_4_5)

  station_averages <- station_averages |>
    mutate(
      station_name = if_else(
        station_name %in% names(station_renames),
        station_renames[station_name],
        station_name
      )
    )

  station_averages <- station_averages |>
    mutate(
      station_name = if_else(
        station_name == "Santuário N.S. de Fátima-Sumaré",
        "Sumaré",
        station_name
      )
    ) |>
    left_join(metro_lines, join_by(line_number))

  station_averages <- station_averages |>
    drop_trailing_na(avg_passenger) |>
    select(all_of(.cols_station_avg_out)) |>
    mutate(station_order = paste(line_number, station_name, sep = "_")) |>
    arrange(date, station_order) |>
    select(-station_order)

  stopifnot(
    "NA dates in station_averages" = !any(is.na(station_averages$date))
  )

  station_averages
}

# --- station_daily -----------------------------------------------------------

.cols_station_daily_out <- c(
  "date", "line_number", "station_name", "passengers",
  "line_name", "line_name_pt", "station_code", "year"
)

#' @param daily_current Current-era daily tibble (builder output).
#' @param daily_4_5 Lines 4/5 daily tibble (committed CSV).
assemble_daily <- function(daily_current, daily_4_5) {
  station_renames <- dim_station_name_change$station_name_full
  names(station_renames) <- dim_station_name_change$station_name

  station_daily <- daily_current |>
    mutate(passengers = passengers * 1000)

  station_daily <- bind_rows(station_daily, daily_4_5)

  station_daily <- station_daily |>
    mutate(
      station_name = if_else(
        station_name %in% names(station_renames),
        station_renames[station_name],
        station_name
      )
    )

  station_daily <- left_join(station_daily, metro_lines, join_by(line_number))

  station_daily <- station_daily |>
    drop_trailing_na(passengers) |>
    select(all_of(.cols_station_daily_out)) |>
    mutate(station_order = paste(line_number, station_name, sep = "_")) |>
    arrange(date, station_order) |>
    select(-station_order)

  # --- Sanity checks (from make_datasets.R) ---
  stopifnot(
    "NA dates in station_daily" = !any(is.na(station_daily$date)),
    "station_daily date range starts before 2012" = min(station_daily$date) >=
      as.Date("2012-01-01"),
    "station_daily should only have lines 1, 2, 3, 4, 5, 15" = all(
      station_daily$line_number %in% c(1L, 2L, 3L, 4L, 5L, 15L)
    ),
    "station_daily lines 4 and 5 should have NA station_code" = all(
      is.na(station_daily$station_code[
        station_daily$line_number %in% c(4L, 5L)
      ])
    ),
    "station_daily has negative passengers" = all(station_daily$passengers >= 0),
    "station_daily missing station_name" = !any(
      is.na(station_daily$station_name)
    ),
    "station_daily lines 1/2/3/15 missing station_code" = !any(
      is.na(station_daily$station_code[
        station_daily$line_number %in% c(1L, 2L, 3L, 15L)
      ])
    ),
    "station_daily has duplicate date/line/station" = nrow(station_daily) ==
      nrow(distinct(station_daily, date, line_number, station_name)),
    "station_daily too few rows (expect > 100k)" = nrow(station_daily) > 100000
  )

  station_daily
}
