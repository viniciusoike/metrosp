# assemble.R
# -----------------------------------------------------------------------------
# Harmonize the 2016-2019 (historic), current-era (2020-present), and Lines
# 4/5 sources into the four exported passenger/station datasets. Refactored
# from the former monolithic builder: each section becomes a function taking its inputs as
# arguments (historic / Lines 4/5 read from the committed processed CSVs;
# current-era passed in from the import builders). Sanity checks (stopifnot)
# live inside the relevant function so a failed check fails that target.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# map_metric() and the .cols_* constants live in dims.R, next to the dimension
# tables they read.

# --- line_entries_monthly -----------------------------------------------------

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

  line_entries_monthly <- bind_rows(entrance_hist, entrance_20) |>
    # Adjust values to match Lines 4/5 (Dataverse source)
    mutate(value = value * 1000)

  line_entries_monthly <- bind_rows(line_entries_monthly, entrance_4_5) |>
    drop_trailing_na(value) |>
    # Processed inputs retain the 1.x names; the public contract changes here.
    rename(
      metric_name = metric,
      metric_name_pt = metric_pt,
      metric = metric_abb
    ) |>
    mutate(year = as.integer(year), line_number = as.integer(line_number)) |>
    select(all_of(.cols_psg)) |>
    arrange(date, line_number, metric)

  stopifnot(
    "NA dates in line_entries_monthly" = !any(is.na(line_entries_monthly$date))
  )

  line_entries_monthly
}

# --- line_transported_monthly --------------------------------------------------

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

  line_transported_monthly <- bind_rows(transported_hist, transported_20) |>
    drop_trailing_na(value) |>
    # Processed inputs retain the 1.x names; the public contract changes here.
    rename(
      metric_name = metric,
      metric_name_pt = metric_pt,
      metric = metric_abb
    ) |>
    mutate(year = as.integer(year), line_number = as.integer(line_number)) |>
    select(all_of(.cols_psg)) |>
    arrange(date, line_number, metric)

  stopifnot(
    "NA dates in line_transported_monthly" = !any(
      is.na(line_transported_monthly$date)
    )
  )

  line_transported_monthly
}

# --- station_entries_monthly --------------------------------------------------------

#' @param stations_historic Raw historic station-averages tibble (committed CSV).
#' @param averages_current Current-era averages tibble (builder output).
#' @param averages_4_5 Lines 4/5 averages tibble (committed CSV).
assemble_averages <- function(
  stations_historic,
  averages_current,
  averages_4_5,
  dim_station,
  dim_station_alias
) {
  stations_hist <- stations_historic |>
    # One source month prints the label with a footnote digit ("Linha 5 -
    # Lilás9"); stripping it first means dim_line is the only lookup.
    mutate(line_name_full = strip_footnotes(line_name_full)) |>
    left_join(
      select(dim_line, line_name_full, line_number),
      by = join_by(line_name_full)
    ) |>
    mutate(station_name = strip_footnotes(name_station)) |>
    rename(avg_passenger = value) |>
    select(all_of(.cols_stn_avg_in)) |>
    # Line 5 was handed over to ViaMobilidade in Aug 2018: the Dataverse
    # source covers it from 2018-08-01, so drop the overlapping historic
    # month (mirrors assemble_entrance). Keeps one series per station.
    filter_out(line_number == 5L & date >= as.Date("2018-08-01")) |>
    resolve_stations("metro_historic", dim_station, dim_station_alias)

  averages_current <- resolve_stations(
    averages_current,
    "metro_current_averages",
    dim_station,
    dim_station_alias
  )

  averages_4_5 <- resolve_stations(
    averages_4_5,
    "dataverse_averages",
    dim_station,
    dim_station_alias
  )

  station_entries_monthly <- bind_rows(stations_hist, averages_current) |>
    mutate(avg_passenger = avg_passenger * 1000)

  station_entries_monthly <- bind_rows(station_entries_monthly, averages_4_5) |>
    left_join(metro_lines, join_by(line_number))

  station_entries_monthly <- station_entries_monthly |>
    drop_trailing_na(avg_passenger) |>
    rename(value = avg_passenger) |>
    mutate(
      year = as.integer(year),
      line_number = as.integer(line_number),
      metric = "mdu"
    ) |>
    left_join(dim_metric_public, by = join_by(metric)) |>
    select(all_of(.cols_stn_avg_out)) |>
    mutate(station_order = paste(line_number, station_name, sep = "_")) |>
    arrange(date, station_order) |>
    select(-station_order)

  stopifnot(
    "NA dates in station_entries_monthly" = !any(is.na(
      station_entries_monthly$date
    )),
    "station_entries_monthly has footnote markers in station_name" = !any(
      stringr::str_detect(
        station_entries_monthly$station_name,
        "[0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]$|\\("
      )
    ),
    # Footnote variants of one station must merge into a single series; a
    # duplicate key here means two sources overlap — investigate, never sum.
    "station_entries_monthly has duplicate date/line/station" = nrow(
      station_entries_monthly
    ) ==
      nrow(distinct(station_entries_monthly, date, line_number, station_name))
  )

  station_entries_monthly
}

# --- station_entries_daily -----------------------------------------------------------

#' @param daily_current Current-era daily tibble (builder output).
#' @param daily_4_5 Lines 4/5 daily tibble (committed CSV).
assemble_daily <- function(
  daily_current,
  daily_4_5,
  dim_station,
  dim_station_alias
) {
  station_entries_daily <- daily_current |>
    mutate(passengers = passengers * 1000) |>
    resolve_stations(
      "metro_current_daily",
      dim_station,
      dim_station_alias
    )

  daily_4_5 <- resolve_stations(
    daily_4_5,
    "dataverse_daily",
    dim_station,
    dim_station_alias
  )

  station_entries_daily <- bind_rows(station_entries_daily, daily_4_5)

  station_entries_daily <- left_join(
    station_entries_daily,
    metro_lines,
    join_by(line_number)
  )

  station_entries_daily <- station_entries_daily |>
    drop_trailing_na(passengers) |>
    rename(value = passengers) |>
    mutate(year = as.integer(year), line_number = as.integer(line_number)) |>
    select(all_of(.cols_stn_daily_out)) |>
    mutate(station_order = paste(line_number, station_name, sep = "_")) |>
    arrange(date, station_order) |>
    select(-station_order)

  # --- Sanity checks ---------------------------------------------------------
  stopifnot(
    "NA dates in station_entries_daily" = !any(is.na(
      station_entries_daily$date
    )),
    "station_entries_daily date range starts before 2012" = min(
      station_entries_daily$date
    ) >=
      as.Date("2012-01-01"),
    "station_entries_daily should only have lines 1, 2, 3, 4, 5, 15" = all(
      station_entries_daily$line_number %in% c(1L, 2L, 3L, 4L, 5L, 15L)
    ),
    "station_entries_daily lines 4 and 5 should have NA station_code" = all(
      is.na(station_entries_daily$station_code[
        station_entries_daily$line_number %in% c(4L, 5L)
      ])
    ),
    "station_entries_daily has negative passengers" = all(
      station_entries_daily$value >= 0
    ),
    "station_entries_daily missing station_name" = !any(
      is.na(station_entries_daily$station_name)
    ),
    "station_entries_daily has footnote markers in station_name" = !any(
      stringr::str_detect(
        station_entries_daily$station_name,
        "[0-9¹²³⁰⁴⁵⁶⁷⁸⁹*]$|\\("
      )
    ),
    "station_entries_daily lines 1/2/3/15 missing station_code" = !any(
      is.na(station_entries_daily$station_code[
        station_entries_daily$line_number %in% c(1L, 2L, 3L, 15L)
      ])
    ),
    "station_entries_daily has duplicate date/line/station" = nrow(
      station_entries_daily
    ) ==
      nrow(distinct(station_entries_daily, date, line_number, station_name)),
    "station_entries_daily too few rows (expect > 100k)" = nrow(
      station_entries_daily
    ) >
      100000
  )

  station_entries_daily
}
