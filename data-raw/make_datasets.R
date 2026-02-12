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
  here::here("data-raw/processed/metro_sp_passengers_2017_2019.csv"),
  show_col_types = FALSE
)

# Map Portuguese variable names to metric abbreviations
metric_map <- c(
  "Total" = "total",
  "Média dos dias úteis" = "mdu",
  "Média dos Sábados" = "msa",
  "Média dos Domingos" = "mdo",
  "Máxima Diária" = "max"
)

entrance_17_19 <- psg_17_19 |>
  filter(measure == "entrance") |>
  mutate(
    metric_abb = metric_map[variable],
    metric = variable
  ) |>
  select(
    date,
    year,
    line_number,
    line_name_pt,
    line_name,
    metric,
    metric_abb,
    value
  )

# 2020-2025: already separate file for entrance
# Columns: date, line_number, metric_abb, metric, value, year
entrance_20_25 <- read_csv(
  here::here("data-raw/processed/metro_sp_passengers_entrance_2020_2025.csv"),
  show_col_types = FALSE
) |>
  # Set NA line_number (network total / "rede") to 99
  mutate(
    line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
  ) |>
  # Add line names from reference table
  left_join(
    metro_lines |> select(line_number, line_name_pt, line_name),
    by = "line_number"
  ) |>
  # Drop rows with NA values (incomplete 2025 months)
  filter(!is.na(value)) |>
  select(
    date,
    year,
    line_number,
    line_name_pt,
    line_name,
    metric,
    metric_abb,
    value
  )

passengers_entrance <- bind_rows(entrance_17_19, entrance_20_25) |>
  arrange(date, line_number, metric_abb)

# --- passengers_transported --------------------------------------------------

transported_17_19 <- psg_17_19 |>
  filter(measure == "transport") |>
  mutate(
    metric_abb = metric_map[variable],
    metric = variable
  ) |>
  select(
    date,
    year,
    line_number,
    line_name_pt,
    line_name,
    metric,
    metric_abb,
    value
  )

transported_20_25 <- read_csv(
  here::here("data-raw/processed/metro_sp_passengers_tranported_2020_2025.csv"),
  show_col_types = FALSE
) |>
  mutate(
    line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
  ) |>
  left_join(
    metro_lines |> select(line_number, line_name_pt, line_name),
    by = "line_number"
  ) |>
  filter(!is.na(value)) |>
  select(
    date,
    year,
    line_number,
    line_name_pt,
    line_name,
    metric,
    metric_abb,
    value
  )

passengers_transported <- bind_rows(transported_17_19, transported_20_25) |>
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

stations_17_19 <- stations_17_19 |>
  mutate(
    line_number = line_lookup[line_name_full],
    station_name = name_station
  ) |>
  rename(avg_passenger = value) |>
  filter(!is.na(avg_passenger)) |>
  select(date, year, line_number, station_name, avg_passenger)

# 2020-2025: already has correct schema
# Columns: date, line_number, station_name, avg_passenger, year
stations_20_25 <- read_csv(
  here::here("data-raw/processed/metro_sp_stations_averages_2020_2025.csv"),
  show_col_types = FALSE
) |>
  filter(!is.na(avg_passenger)) |>
  select(date, year, line_number, station_name, avg_passenger)

station_averages <- bind_rows(stations_17_19, stations_20_25) |>
  mutate(
    year = as.integer(year),
    line_number = as.integer(line_number)
  ) |>
  arrange(date, line_number, station_name)

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

valid_lines <- metro_lines$line_number
stopifnot(
  "Invalid line_number in passengers_entrance" = all(
    passengers_entrance$line_number %in% valid_lines
  )
)
stopifnot(
  "Invalid line_number in passengers_transported" = all(
    passengers_transported$line_number %in% valid_lines
  )
)
stopifnot(
  "Invalid line_number in station_averages" = all(
    station_averages$line_number %in% valid_lines
  )
)

stopifnot(
  "Date range too early" = min(passengers_entrance$date) >=
    as.Date("2017-01-01")
)
stopifnot(
  "Date range too late" = max(passengers_entrance$date) <= as.Date("2025-12-31")
)

message("Sanity checks passed.")
message(sprintf("passengers_entrance:    %d rows", nrow(passengers_entrance)))
message(sprintf(
  "passengers_transported: %d rows",
  nrow(passengers_transported)
))
message(sprintf("station_averages:       %d rows", nrow(station_averages)))
message(sprintf("metro_lines:            %d rows", nrow(metro_lines)))

# --- Save datasets -----------------------------------------------------------

usethis::use_data(passengers_entrance, overwrite = TRUE)
usethis::use_data(passengers_transported, overwrite = TRUE)
usethis::use_data(station_averages, overwrite = TRUE)
usethis::use_data(metro_lines, overwrite = TRUE)

message("All datasets saved to data/")
