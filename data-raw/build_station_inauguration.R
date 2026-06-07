# Build station_inauguration dataset ------------------------------------------
#
# Produces `station_inauguration` — one row per (line_number, station_name)
# with the station's commercial opening date, plus a derived "ramp-up"
# window flag (~6 months after opening, where monthly ridership is below
# steady-state and should typically be excluded from year-on-year or
# baseline comparisons).
#
# Source: `data-raw/station_inauguration.csv`. Stations whose opening date
# falls before the first available data are flagged but not given an
# inauguration_date (we don't know exactly — they were already open).
#
# Workflow:
#   1. Add / verify dates in `station_inauguration.csv`. Always set the
#      `verified` column to TRUE once cross-checked against the operator's
#      press release or another reliable source.
#   2. `source("data-raw/build_station_inauguration.R")`.
#   3. `devtools::document()` to refresh the Rd file.

# OBS: still experimental and building

library(dplyr)
library(readr)
library(tidyr)

devtools::load_all(quiet = TRUE)

raw <- readr::read_csv(
  "data-raw/station_inauguration.csv",
  col_types = readr::cols(
    line_number = readr::col_integer(),
    station_name = readr::col_character(),
    inauguration_date = readr::col_date(),
    phase = readr::col_character(),
    verified = readr::col_logical(),
    notes = readr::col_character()
  )
)

# Sanity check: every station in the CSV must exist in `station_daily` or
# `station_averages`. Catches typos in station_name.
known_stations <- bind_rows(
  metrosp::station_daily |>
    select(line_number, station_name) |>
    distinct(),
  metrosp::station_averages |>
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

# Join with full station list so every station has a row. Stations not in
# the CSV are assumed to have opened before the dataset window starts.
data_start <- min(metrosp::station_averages$date, na.rm = TRUE)

station_inauguration <- known_stations |>
  left_join(raw, by = c("line_number", "station_name")) |>
  mutate(
    pre_data_window = is.na(inauguration_date),
    ramp_up_end = inauguration_date + 180L,
    verified = tidyr::replace_na(verified, FALSE)
  ) |>
  arrange(line_number, station_name)

# usethis::use_data(station_inauguration, overwrite = TRUE)

cli::cli_alert_success(sprintf(
  "Built station_inauguration: %d stations (%d with known opening date, %d verified)",
  nrow(station_inauguration),
  sum(!station_inauguration$pre_data_window),
  sum(station_inauguration$verified, na.rm = TRUE)
))
