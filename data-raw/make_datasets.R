# make_datasets.R
# -------------------------------------------------------
# Master script: reads processed CSVs, harmonizes schemas across time
# periods, merges into unified datasets, and saves as .rda files.
#
# Run with: source("data-raw/make_datasets.R") from the project root.
#
# Inputs:  data-raw/processed/*.csv
# Outputs: data/*.rda (passengers_entrance, passengers_transported,
#          station_averages, metro_lines)
# -------------------------------------------------------

library(readr)
library(dplyr)
library(usethis)
import::from(here, here)
source(here::here("data-raw/utils.R"))
data_dir <- here("data-raw/processed")

# --- metro_lines (reference table) -------------------------------------------

metro_lines <- tibble::tibble(
  line_number = c(1L, 2L, 3L, 4L, 5L, 6L, 15L, 16L, 17L, 19L, 20L, 22L, 99L),
  line_name_pt = c(
    "Azul",
    "Verde",
    "Vermelha",
    "Amarela",
    "Lilás",
    "Laranja",
    "Prata",
    "Violeta",
    "Ouro",
    "Celeste",
    "Rosa",
    "Marrom",
    "Sistema METRÔ"
  ),
  line_name = c(
    "Blue",
    "Green",
    "Red",
    "Yellow",
    "Lilac",
    "Orange",
    "Silver",
    "Violet",
    "Gold",
    "Sky Blue",
    "Pink",
    "Brown",
    "METRÔ System"
  )
)

# --- passengers_entrance -----------------------------------------------------

# 2017-2019: filter measure == "entrance" from combined file
# Columns: year, measure, date, variable, value, line_number, line_name_pt, line_name
psg_17_19 <- read_csv(
  here::here(data_dir, "metro_sp_passengers_2017_2019.csv"),
  show_col_types = FALSE
)

# Map Portuguese variable names to metric abbreviations (case-insensitive)
metric_map_keys <- c(
  "total" = "total",
  "média dos dias úteis" = "mdu",
  "média dos sábados" = "msa",
  "média dos domingos" = "mdo",
  "máxima diária" = "max"
)

map_metric <- function(x) {
  metric_map_keys[tolower(trimws(x))]
}

# Ordering of columns for passenger tables
psg_sel_cols <- c(
  "date",
  "line_number",
  "metric_abb",
  "value",
  "metric",
  "line_name",
  "line_name_pt",
  "year"
)

entrance_17_19 <- psg_17_19 |>
  filter(measure == "entrance") |>
  mutate(
    metric_abb = map_metric(variable),
    metric = variable
  )

# 2020-2025: already separate file for entrance
# Columns: date, line_number, metric_abb, metric, value, year

entrance_20 <- read_csv(
  here(data_dir, "metro_sp_passengers_entrance_2020_2025.csv"),
  show_col_types = FALSE
)

entrance_20 <- entrance_20 |>
  mutate(
    # Set NA line_number (network total / "rede") to 99
    line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
  ) |>
  # Add line names from reference table
  left_join(metro_lines, by = join_by(line_number))

# Check for missing values

missing_vals <- entrance_20 |>
  filter(if_any(everything(), is.na)) |>
  # We expect missing values during 2020/03-2020/05 for Line 15
  filter(!(year == 2020 & line_number == 15))

if (nrow(missing_vals) > 0) {
  cli::cli_abort("Missing values in entrance_20: {nrow(missing_vals)} rows")
}

passengers_entrance <- bind_rows(entrance_17_19, entrance_20) |>
  select(all_of(psg_sel_cols)) |>
  arrange(date, line_number, metric_abb)

# --- passengers_transported --------------------------------------------------

transported_17_19 <- psg_17_19 |>
  filter(measure == "transport") |>
  mutate(
    metric_abb = map_metric(variable),
    metric = variable
  )

transported_20 <- read_csv(
  here(data_dir, "metro_sp_passengers_tranported_2020_2025.csv"),
  show_col_types = FALSE
)

transported_20 <- transported_20 |>
  mutate(
    # Set NA line_number (network total / "rede") to 99
    line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
  ) |>
  # Add line names from reference table
  left_join(metro_lines, by = join_by(line_number))

passengers_transported <- bind_rows(transported_17_19, transported_20) |>
  select(all_of(psg_sel_cols)) |>
  arrange(date, line_number, metric_abb)

# --- station_averages --------------------------------------------------------

# 2017-2019: needs schema harmonization
# Columns: date, year, month, line_name_full, name_station, metric_abb, value
stations_17_19 <- read_csv(
  here::here("data-raw/processed/metro_sp_stations_averages_2017_2019.csv"),
  show_col_types = FALSE
)

# Parse line_name_full -> line_number
line_lookup <- c(
  "Linha 1 - Azul" = 1L,
  "Linha 2 - Verde" = 2L,
  "Linha 3 - Vermelha" = 3L,
  "Linha 5 - Lilás" = 5L,
  "Linha 5 - Lilás9" = 5L, # Fix typo in raw data
  "Linha 15 - Prata" = 15L
)

# Station name standardization: update old short names to current full names
# (dim_station_name_change is defined in utils.R but not loaded here,
# so we define the mapping inline)
# station_renames <- c(
#   "Carrão" = "Carrão-Assaí Atacadista",
#   "Penha" = "Penha-Lojas Besni",
#   "Saúde" = "Saúde-Ultrafarma",
#   "Patriarca" = "Patriarca-Vila Ré"
# )

station_renames <- dim_station_name_change$station_name_full
names(station_renames) <- dim_station_name_change$station_name

stations_17_19 <- stations_17_19 |>
  mutate(
    line_number = line_lookup[line_name_full],
    station_name = name_station,
    station_name = if_else(
      station_name %in% names(station_renames),
      station_renames[station_name],
      station_name
    )
  ) |>
  rename(avg_passenger = value) |>
  select(date, year, line_number, station_name, avg_passenger)

# 2020-2025: already has correct schema
# Columns: date, line_number, station_name, avg_passenger, year
stations_20 <- read_csv(
  here::here(data_dir, "metro_sp_stations_averages_2020_2025.csv"),
  show_col_types = FALSE
)

missing_vals <- stations_20 |>
  filter(
    is.na(avg_passenger),
    !(line_number == 15 &
      date == as.Date("2022-01-01") &
      station_name == "Jardim Colonial")
  )

if (nrow(missing_vals) > 0) {
  cli::cli_abort("Missing values in stations_20: {nrow(missing_vals)} rows")
}

station_sel_cols <- c(
  "date",
  "line_number",
  "station_name",
  "avg_passenger",
  "line_name",
  "line_name_pt",
  "year"
)

station_averages <- bind_rows(stations_17_19, stations_20) |>
  mutate(
    year = as.integer(year),
    line_number = as.integer(line_number),
    # Fix station_name for consistency with other datasets (Sumaré)
    station_name = if_else(
      station_name == "Santuário N.S. de Fátima-Sumaré",
      "Sumaré",
      station_name
    )
  ) |>
  # Add line names for consistency with passengers datasets
  left_join(metro_lines, join_by(line_number))

# Define a temporary id vector (station name + line number) to sort stations
# in proper order
# OBS: due to repeated station names it's not possible to simply convert to
# factor and sort.

st_order <- paste(
  dim_station_code$line_number,
  dim_station_code$station_name,
  sep = "_"
)

station_averages <- station_averages |>
  select(all_of(station_sel_cols)) |>
  mutate(
    station_order = paste(line_number, station_name, sep = "_"),
    station_order = factor(station_order, levels = local(st_order))
  ) |>
  arrange(date, station_order) |>
  select(-station_order)

# --- station_daily ------------------------------------------------------------

station_daily <- read_csv(
  here(data_dir, "metro_sp_stations_daily_2020_2025.csv"),
  show_col_types = FALSE
)

station_daily <- station_daily |>
  mutate(line_number = as.integer(line_number)) |>
  left_join(metro_lines, join_by(line_number))

missing_vals <- station_daily |>
  filter(is.na(passengers))

if (nrow(missing_vals) > 0) {
  cli::cli_abort("Missing values in station_daily: {nrow(missing_vals)} rows")
}

stdaily_sel_cols <- c(
  "date",
  "line_number",
  "station_name",
  "passengers",
  "line_name",
  "line_name_pt",
  "station_code",
  "year"
)

station_daily <- station_daily |>
  select(all_of(stdaily_sel_cols)) |>
  # Define a temporary id vector (station name + line number) to sort stations
  # in proper order
  mutate(
    station_order = paste(line_number, station_name, sep = "_"),
    station_order = factor(station_order, levels = local(st_order))
  ) |>
  arrange(date, station_order) |>
  select(-station_order)

# --- Sanity checks -----------------------------------------------------------

stopifnot(
  "NA dates in passengers_entrance" = !any(is.na(passengers_entrance$date))
)
stopifnot(
  "NA dates in passengers_transported" = !any(is.na(
    passengers_transported$date
  ))
)
stopifnot("NA dates in station_averages" = !any(is.na(station_averages$date)))
stopifnot("NA dates in station_daily" = !any(is.na(station_daily$date)))

# station_daily specific checks
stopifnot(
  "station_daily date range starts before 2020" = min(station_daily$date) >=
    as.Date("2020-01-01")
)

stopifnot(
  "station_daily should only have lines 1, 2, 3, 15" = all(
    station_daily$line_number %in% c(1L, 2L, 3L, 15L)
  )
)
stopifnot(
  "station_daily has negative passengers" = all(station_daily$passengers >= 0)
)
stopifnot(
  "station_daily missing station_name" = !any(is.na(station_daily$station_name))
)
stopifnot(
  "station_daily missing station_code" = !any(is.na(station_daily$station_code))
)
stopifnot(
  "station_daily has duplicate date/line/station" = nrow(station_daily) ==
    nrow(distinct(station_daily, date, line_number, station_code))
)
stopifnot(
  "station_daily too few rows (expect > 100k)" = nrow(station_daily) > 100000
)

message("Sanity checks passed.")
message(sprintf("passengers_entrance:    %d rows", nrow(passengers_entrance)))
message(sprintf(
  "passengers_transported: %d rows",
  nrow(passengers_transported)
))
message(sprintf("station_averages:       %d rows", nrow(station_averages)))
message(sprintf("station_daily:          %d rows", nrow(station_daily)))
message(sprintf("metro_lines:            %d rows", nrow(metro_lines)))

# --- Save datasets -----------------------------------------------------------

usethis::use_data(passengers_entrance, overwrite = TRUE)
usethis::use_data(passengers_transported, overwrite = TRUE)
usethis::use_data(station_averages, overwrite = TRUE)
usethis::use_data(station_daily, overwrite = TRUE)
usethis::use_data(metro_lines, overwrite = TRUE)

message("All datasets saved to data/")
