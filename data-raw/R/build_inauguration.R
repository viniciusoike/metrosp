# build_inauguration.R
# -----------------------------------------------------------------------------
# build_station_inauguration() assembles the station_inauguration dataset from
# the hand-maintained data-raw/station_inauguration.csv, validated against the
# station lists in station_daily / station_averages (passed in as arguments
# rather than via devtools::load_all()/metrosp::). Refactored from
# build_station_inauguration.R.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

#' @param csv_path Path to data-raw/station_inauguration.csv.
#' @param station_daily The assembled station_daily dataset.
#' @param station_averages The assembled station_averages dataset.
build_station_inauguration <- function(
  csv_path,
  station_daily,
  station_averages
) {
  raw <- readr::read_csv(
    csv_path,
    col_types = readr::cols(
      line_number = readr::col_integer(),
      station_name = readr::col_character(),
      inauguration_date = readr::col_date(),
      phase = readr::col_character(),
      verified = readr::col_logical(),
      notes = readr::col_character()
    )
  )

  known_stations <- bind_rows(
    station_daily |>
      select(line_number, station_name) |>
      distinct(),
    station_averages |>
      select(line_number, station_name) |>
      distinct()
  ) |>
    distinct()

  missing <- raw |>
    anti_join(known_stations, by = c("line_number", "station_name"))

  if (nrow(missing) > 0) {
    warning(
      "Stations in CSV with no match in station_daily/station_averages:\n",
      paste(
        sprintf("  L%s %s", missing$line_number, missing$station_name),
        collapse = "\n"
      )
    )
  }

  station_inauguration <- known_stations |>
    left_join(raw, by = c("line_number", "station_name")) |>
    mutate(
      pre_data_window = is.na(inauguration_date),
      ramp_up_end = inauguration_date + 180L,
      verified = tidyr::replace_na(verified, FALSE)
    ) |>
    arrange(line_number, station_name)

  station_inauguration
}
