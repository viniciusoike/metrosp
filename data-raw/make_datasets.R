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

check <- FALSE

library(dplyr)
import::from(here, here)
import::from(readr, read_csv)
source(here::here("data-raw/utils.R"))
data_dir <- here("data-raw/processed")

# entrance
# transported
# station_averages
# station_daily

# historic
# current
params <- tibble(path = fs::dir_ls(data_dir, regexp = "\\.csv$"))

params <- params |>
  mutate(
    file_name = basename(path),
    table = case_when(
      stringr::str_detect(file_name, "passengers_entrance") ~ "entrance",
      stringr::str_detect(file_name, "passengers_tranported") ~ "transported",
      stringr::str_detect(file_name, "station_averages") ~ "station_averages",
      stringr::str_detect(file_name, "station_daily") ~ "station_daily",
      stringr::str_detect(
        file_name,
        "metro_sp_passengers_[0-9]{4}"
      ) ~ "passengers",
      TRUE ~ NA_character_
    ),
    date_range = stringr::str_extract(file_name, "[0-9]{4}_[0-9]{4}"),
    year_max = if_else(
      is.na(date_range),
      NA_real_,
      as.numeric(stringr::str_extract(date_range, "[0-9]{4}$"))
    ),
    is_historic = if_else(year_max < 2020, 1L, 0L),
    is_metro = if_else(stringr::str_detect(path, "lines_4_5"), 0L, 1L)
  )

get_path_processed <- function(table = NULL, historic = NULL, line = NULL) {
  # browser()
  valid_tables <- c(
    "entrance",
    "transported",
    "station_averages",
    "station_daily"
  )
  if (!table %in% valid_tables) {
    cli::cli_abort(
      "{.arg table} must be one of {.or {.val {valid_tables}}}, not {.val {table}}."
    )
  }

  if (!is.null(line) && line %in% c(4, 5)) {
    return(params |> filter(table == !!table, is_metro == 0) |> pull(path))
  }

  tbl <- if (historic && table %in% c("entrance", "transported")) {
    "passengers"
  } else {
    table
  }

  subparams <- params |>
    filter(
      table == !!tbl,
      is_metro == 1,
      is_historic == !!historic
    )

  if (nrow(subparams) > 1) {
    out <- subparams |>
      filter(year_max == max(year_max, na.rm = TRUE)) |>
      pull(path)

    return(out)
  }

  if (nrow(subparams) == 0) {
    cli::cli_abort("No files found.")
  }

  out <- subparams$path

  return(out)
}


# --- metro_lines (reference table) -------------------------------------------

metro_lines <- tibble(
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
    "Sistema METRO"
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
    "METRO System"
  )
)

# --- passengers_entrance -----------------------------------------------------

# Map Portuguese variable names to metric abbreviations (case-insensitive)
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

# Ordering of columns for passenger tables
.cols_passengers <- c(
  "date",
  "line_number",
  "metric_abb",
  "value",
  "metric",
  "metric_pt",
  "line_name",
  "line_name_pt",
  "year"
)

## Historic (2017-19) -----------------------------------------------------

# 2017-2019: filter measure == "entrance" from combined file
# Columns: year, measure, date, variable, value, line_number, line_name_pt, line_name

path_file <- get_path_processed("entrance", historic = TRUE)

psg_17_19 <- read_csv(path_file, show_col_types = FALSE)

entrance_17_19 <- psg_17_19 |>
  filter(measure == "entrance") |>
  mutate(metric_abb = map_metric(variable))

entrance_17_19 <- left_join(
  entrance_17_19,
  select(dim_metric, metric_abb, metric, metric_pt),
  by = "metric_abb"
)

entrance_17_19 <- entrance_17_19 |>
  filter_out(line_number == 5L & date >= as.Date("2018-08-01"))

## Current (2020-) --------------------------------------------------------

# Columns: date, line_number, metric_abb, metric, value, year
path_file <- get_path_processed("entrance", historic = FALSE)
entrance_20 <- read_csv(path_file, show_col_types = FALSE)

entrance_20 <- left_join(
  entrance_20,
  select(dim_metric, metric_abb, metric_pt),
  by = "metric_abb"
)

entrance_20 <- entrance_20 |>
  mutate(
    # Set NA line_number (network total / "rede") to 99
    line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
  ) |>
  left_join(metro_lines, by = join_by(line_number))


if (check) {
  # Check for missing values

  missing_vals <- entrance_20 |>
    filter(year < max(year)) |>
    filter(if_any(everything(), is.na)) |>
    # We expect missing values during 2020/03-2020/05 for Line 15
    filter(!(year == 2020 & line_number == 15))

  if (nrow(missing_vals) > 0) {
    cli::cli_warn("Missing values in entrance_20: {nrow(missing_vals)} rows")
  }

  vals <- entrance_20 |>
    filter(year == max(year)) |>
    pull(value)

  if (all(is.na(vals))) {
    cli::cli_abort("All values are NA in entrance.")
  }
}

## Lines 4-5 --------------------------------------------------------------

entrance_4_5 <- read_csv(
  get_path_processed("entrance", line = 4),
  show_col_types = FALSE
)

entrance_4_5 <- entrance_4_5 |>
  left_join(select(dim_metric, metric_abb, metric_pt), by = "metric_abb") |>
  left_join(metro_lines, by = join_by(line_number))


## Stack tables -----------------------------------------------------------

passengers_entrance <- bind_rows(entrance_17_19, entrance_20)
# Adjust values to match Line 4 and 5 (Dataverse source)
passengers_entrance <- passengers_entrance |>
  mutate(value = value * 1000)

passengers_entrance <- bind_rows(passengers_entrance, entrance_4_5)

passengers_entrance <- passengers_entrance |>
  select(all_of(.cols_passengers)) |>
  arrange(date, line_number, metric_abb)

# --- passengers_transported --------------------------------------------------

# OBS: currently this table only includes METRO lines (not 4-5)

## Historic (2017-19) -----------------------------------------------------

transported_17_19 <- psg_17_19 |>
  filter(measure == "transport") |>
  mutate(metric_abb = map_metric(variable)) |>
  left_join(
    select(dim_metric, metric_abb, metric, metric_pt),
    by = "metric_abb"
  )

## Current (2020-) --------------------------------------------------------

transported_20 <- read_csv(
  get_path_processed("transported", historic = FALSE),
  show_col_types = FALSE
)

transported_20 <- left_join(
  transported_20,
  select(dim_metric, metric_abb, metric_pt),
  by = "metric_abb"
)

transported_20 <- transported_20 |>
  mutate(
    # Set NA line_number (network total / "rede") to 99
    line_number = if_else(is.na(line_number), 99L, as.integer(line_number))
  ) |>
  left_join(metro_lines, by = join_by(line_number))


## Stack tables -----------------------------------------------------------

passengers_transported <- bind_rows(transported_17_19, transported_20)

passengers_transported <- passengers_transported |>
  select(all_of(.cols_passengers)) |>
  arrange(date, line_number, metric_abb)

# --- station_averages --------------------------------------------------------

## Historic (2017-19) -----------------------------------------------------

# Columns: date, year, month, line_name_full, name_station, metric_abb, value
stations_17_19 <- read_csv(
  get_path_processed("station_averages", historic = TRUE),
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

.cols_station_avg <- c(
  "date",
  "year",
  "line_number",
  "station_name",
  "avg_passenger"
)

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
  select(all_of(.cols_station_avg))


## Current (2020-) --------------------------------------------------------

# Columns: date, line_number, station_name, avg_passenger, year
stations_20 <- read_csv(
  get_path_processed("station_averages", historic = FALSE),
  show_col_types = FALSE
)

if (check) {
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
}

## Lines 4-5 --------------------------------------------------------------

stations_4_5 <- read_csv(
  get_path_processed("station_averages", line = 4),
  show_col_types = FALSE
)

## Stack tables -----------------------------------------------------------

station_averages <- bind_rows(
  stations_17_19,
  stations_20
)

# Adjust values to match Line 4 and 5 (Dataverse source)
station_averages <- station_averages |>
  mutate(avg_passenger = avg_passenger * 1000)

station_averages <- bind_rows(station_averages, stations_4_5)


station_averages <- station_averages |>
  mutate(
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

.cols_station <- c(
  "date",
  "line_number",
  "station_name",
  "avg_passenger",
  "line_name",
  "line_name_pt",
  "year"
)

station_averages <- station_averages |>
  select(all_of(.cols_station)) |>
  mutate(station_order = paste(line_number, station_name, sep = "_")) |>
  arrange(date, station_order) |>
  select(-station_order)

# --- station_daily ------------------------------------------------------------

# OBS: no "historic" data for station_daily

station_daily <- read_csv(
  get_path_processed("station_daily", historic = FALSE),
  show_col_types = FALSE
)

station_daily_4_5 <- read_csv(
  get_path_processed("station_daily", line = 4),
  show_col_types = FALSE
)

## Stack tables -----------------------------------------------------------

# Adjust values to match Line 4 and 5 (Dataverse source)
station_daily <- station_daily |>
  mutate(passengers = passengers * 1000)

station_daily <- bind_rows(station_daily, station_daily_4_5)
station_daily <- left_join(station_daily, metro_lines, join_by(line_number))

if (check) {
  missing_vals <- station_daily |>
    filter(is.na(passengers))

  if (nrow(missing_vals) > 0) {
    cli::cli_abort("Missing values in station_daily: {nrow(missing_vals)} rows")
  }
}

.cols_station_daily <- c(
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
  select(all_of(.cols_station_daily)) |>
  # Define a temporary id vector (station name + line number) to sort stations
  # in proper order
  mutate(station_order = paste(line_number, station_name, sep = "_")) |>
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
    as.Date("2012-01-01")
)

stopifnot(
  "station_daily should only have lines 1, 2, 3, 4, 5, 15" = all(
    station_daily$line_number %in% c(1L, 2L, 3L, 4L, 5L, 15L)
  )
)
stopifnot(
  "station_daily lines 4 and 5 should have NA station_code" = all(
    is.na(station_daily$station_code[station_daily$line_number %in% c(4L, 5L)])
  )
)
stopifnot(
  "station_daily has negative passengers" = all(station_daily$passengers >= 0)
)
stopifnot(
  "station_daily missing station_name" = !any(is.na(station_daily$station_name))
)
stopifnot(
  "station_daily lines 1/2/3/15 missing station_code" = !any(
    is.na(station_daily$station_code[
      station_daily$line_number %in% c(1L, 2L, 3L, 15L)
    ])
  )
)
stopifnot(
  "station_daily has duplicate date/line/station" = nrow(station_daily) ==
    nrow(distinct(station_daily, date, line_number, station_name))
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

metro_colors <- c(
  "Blue" = "#171796",
  "Green" = "#007A5E",
  "Red" = "#ED2E38",
  "Yellow" = "#FFD525",
  "Lilac" = "#874ABF",
  "Silver" = "#8F8F8C"
)

usethis::use_data(passengers_entrance, overwrite = TRUE)
usethis::use_data(passengers_transported, overwrite = TRUE)
usethis::use_data(station_averages, overwrite = TRUE)
usethis::use_data(station_daily, overwrite = TRUE)
usethis::use_data(metro_lines, overwrite = TRUE)
usethis::use_data(metro_colors, overwrite = TRUE)

message("All datasets saved to data/")

# Add local versions of the datasets
dir.create(here("data-raw/cache"), showWarnings = FALSE)
readr::write_rds(
  passengers_entrance,
  here("data-raw/cache/passengers_entrance.rds")
)
readr::write_rds(
  passengers_transported,
  here("data-raw/cache/passengers_transported.rds")
)
readr::write_rds(station_averages, here("data-raw/cache/station_averages.rds"))
readr::write_rds(station_daily, here("data-raw/cache/station_daily.rds"))
