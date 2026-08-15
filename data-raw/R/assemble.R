# assemble.R
# -----------------------------------------------------------------------------
# Harmonize the 2016-2019 (historic), current-era (2020-present), and Lines
# 4/5 sources into the four exported passenger/station datasets. Refactored
# from make_datasets.R: each section becomes a function taking its inputs as
# arguments (historic / Lines 4/5 read from the committed processed CSVs;
# current-era passed in from the import builders). Sanity checks (stopifnot)
# live inside the relevant function so a failed check fails that target.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# map_metric() and the .cols_* constants live in dims.R, next to the dimension
# tables they read.

# --- passengers_entrance -----------------------------------------------------

#' @param psg_historic Raw historic passengers tibble (entrance + transport).
#' @param entrance_current Current-era entrance tibble (import builder output).
#' @param entrance_4_5 Lines 4/5 entrance tibble (committed CSV).
assemble_entrance <- function(psg_historic, entrance_current, entrance_4_5) {
  entrance_hist <- psg_historic |>
    filter(measure == "entrance") |>
    mutate(metric_abb = map_metric(variable)) |>
    left_join(
      select(dim_metric, metric_abb, metric, metric_pt),
      by = "metric_abb"
    ) |>
    filter_out(line_number == 5L & date >= as.Date("2018-08-01"))

  entrance_20 <- entrance_current |>
    left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
    mutate(line_number = as.integer(line_number)) |>
    left_join(metro_lines, by = join_by(line_number))

  entrance_4_5 <- entrance_4_5 |>
    left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
    left_join(metro_lines, by = join_by(line_number))

  passengers_entrance <- bind_rows(entrance_hist, entrance_20) |>
    # Adjust values to match Lines 4/5 (Dataverse source)
    mutate(value = value * 1000)

  passengers_entrance <- bind_rows(passengers_entrance, entrance_4_5) |>
    drop_trailing_na(value) |>
    select(all_of(.cols_psg)) |>
    arrange(date, line_number, metric_abb)

  stopifnot(
    "NA dates in passengers_entrance" = !any(is.na(passengers_entrance$date))
  )

  passengers_entrance
}

# --- passengers_transported --------------------------------------------------

#' @param psg_historic Raw historic passengers tibble (entrance + transport).
#' @param transported_current Current-era transported tibble (builder output).
assemble_transported <- function(psg_historic, transported_current) {
  transported_hist <- psg_historic |>
    filter(measure == "transport") |>
    mutate(metric_abb = map_metric(variable)) |>
    left_join(
      select(dim_metric, metric_abb, metric, metric_pt),
      by = "metric_abb"
    )

  transported_20 <- transported_current |>
    left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
    mutate(line_number = as.integer(line_number)) |>
    left_join(metro_lines, by = join_by(line_number))

  passengers_transported <- bind_rows(transported_hist, transported_20) |>
    drop_trailing_na(value) |>
    select(all_of(.cols_psg)) |>
    arrange(date, line_number, metric_abb)

  stopifnot(
    "NA dates in passengers_transported" = !any(
      is.na(passengers_transported$date)
    )
  )

  passengers_transported
}

# --- station_averages --------------------------------------------------------

#' @param stations_historic Raw historic station-averages tibble (committed CSV).
#' @param averages_current Current-era averages tibble (builder output).
#' @param averages_4_5 Lines 4/5 averages tibble (committed CSV).
assemble_averages <- function(
  stations_historic,
  averages_current,
  averages_4_5
) {
  # Collapse sponsor/renamed variants to the canonical name (raw -> canonical).
  station_renames <- dim_station_name_change$station_name
  names(station_renames) <- dim_station_name_change$station_name_raw

  stations_hist <- stations_historic |>
    # One source month prints the label with a footnote digit ("Linha 5 -
    # Lilás9"); stripping it first means dim_line is the only lookup.
    mutate(line_name_full = strip_footnotes(line_name_full)) |>
    left_join(
      select(dim_line, line_name_full, line_number),
      by = join_by(line_name_full)
    ) |>
    mutate(station_name = name_station) |>
    rename(avg_passenger = value) |>
    select(all_of(.cols_stn_avg_in)) |>
    # Line 5 was handed over to ViaMobilidade in Aug 2018: the Dataverse
    # source covers it from 2018-08-01, so drop the overlapping historic
    # month (mirrors assemble_entrance). Keeps one series per station.
    filter_out(line_number == 5L & date >= as.Date("2018-08-01"))

  station_averages <- bind_rows(stations_hist, averages_current) |>
    mutate(avg_passenger = avg_passenger * 1000)

  station_averages <- bind_rows(station_averages, averages_4_5) |>
    # Defense in depth: re-clean names so a stale committed CSV can never
    # leak footnote markers (e.g. "Sé4", "Brooklin7") into the package data.
    mutate(station_name = strip_footnotes(station_name))

  station_averages <- station_averages |>
    mutate(
      station_name = if_else(
        station_name %in% names(station_renames),
        unname(station_renames[station_name]),
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
    select(all_of(.cols_stn_avg_out)) |>
    mutate(station_order = paste(line_number, station_name, sep = "_")) |>
    arrange(date, station_order) |>
    select(-station_order)

  stopifnot(
    "NA dates in station_averages" = !any(is.na(station_averages$date)),
    "station_averages has footnote markers in station_name" = !any(
      stringr::str_detect(
        station_averages$station_name,
        "[0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]$|\\("
      )
    ),
    # Footnote variants of one station must merge into a single series; a
    # duplicate key here means two sources overlap — investigate, never sum.
    "station_averages has duplicate date/line/station" = nrow(
      station_averages
    ) ==
      nrow(distinct(station_averages, date, line_number, station_name))
  )

  station_averages
}

# --- station_daily -----------------------------------------------------------

#' @param daily_current Current-era daily tibble (builder output).
#' @param daily_4_5 Lines 4/5 daily tibble (committed CSV).
assemble_daily <- function(daily_current, daily_4_5) {
  # Collapse sponsor/renamed variants to the canonical name (raw -> canonical).
  station_renames <- dim_station_name_change$station_name
  names(station_renames) <- dim_station_name_change$station_name_raw

  station_daily <- daily_current |>
    mutate(passengers = passengers * 1000)

  station_daily <- bind_rows(station_daily, daily_4_5) |>
    # Defense in depth: same footnote-marker cleaning as assemble_averages.
    mutate(station_name = strip_footnotes(station_name))

  station_daily <- station_daily |>
    mutate(
      station_name = if_else(
        station_name %in% names(station_renames),
        unname(station_renames[station_name]),
        station_name
      )
    )

  station_daily <- left_join(station_daily, metro_lines, join_by(line_number))

  station_daily <- station_daily |>
    drop_trailing_na(passengers) |>
    select(all_of(.cols_stn_daily_out)) |>
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
    "station_daily has negative passengers" = all(
      station_daily$passengers >= 0
    ),
    "station_daily missing station_name" = !any(
      is.na(station_daily$station_name)
    ),
    "station_daily has footnote markers in station_name" = !any(
      stringr::str_detect(
        station_daily$station_name,
        "[0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]$|\\("
      )
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
