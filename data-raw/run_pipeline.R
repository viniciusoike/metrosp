# run_pipeline.R
# -------------------------------------------------------
# Master orchestrator for the metrosp data update pipeline.
#
# Usage:
#   source("data-raw/run_pipeline.R")
#
# Flags (edit before running):
#   download   - set TRUE to re-download raw files from the METRO portal
#   historical - set TRUE to re-import 2017-2019 data (rarely needed)
#   geosampa   - set TRUE to re-import GeoSampa shapefiles (rarely needed)
#   dataverse  - set TRUE to re-fetch Lines 4/5 data from Dataverse
# -------------------------------------------------------

download <- FALSE
historical <- FALSE
geosampa <- FALSE
dataverse <- TRUE

import::from(here, here)

# -- Guard: ensure 2017-2019 processed CSVs exist when skipping historical ---
historical_csvs <- c(
  here("data-raw/processed/metro_sp_passengers_2017_2019.csv"),
  here("data-raw/processed/metro_sp_stations_averages_2017_2019.csv")
)

if (!historical && !all(file.exists(historical_csvs))) {
  cli::cli_alert_warning(
    "2017-2019 processed CSVs not found. Setting {.code historical <- TRUE}."
  )
  historical <- TRUE
}

# -- Guard: ensure Lines 4/5 processed CSVs exist when skipping dataverse ---
dataverse_csvs <- c(
  here("data-raw/processed/metro_sp_passengers_entrance_lines45.csv"),
  here("data-raw/processed/metro_sp_station_averages_lines45.csv"),
  here("data-raw/processed/metro_sp_station_daily_lines45.csv")
)

if (!dataverse && !all(file.exists(dataverse_csvs))) {
  cli::cli_alert_warning(
    "Lines 4/5 processed CSVs not found. Setting {.code dataverse <- TRUE}."
  )
  dataverse <- TRUE
}

# -- 1. Download raw data ----------------------------------------------------
if (download) {
  cli::cli_h2("Downloading raw data from METRO portal")
  source(here("data-raw/download_metro.R"), local = TRUE)
}

# -- 2. Import historical data (2017-2019) ------------------------------------
if (historical) {
  cli::cli_h2("Importing passengers entrance + transported (2017-2019)")
  source(here("data-raw/import_passengers_2017_2019.R"), local = TRUE)

  cli::cli_h2("Importing station averages (2017-2019)")
  source(here("data-raw/import_station_averages_2017_2019.R"), local = TRUE)
}

# -- 3. Import current data (2020-2025) ---------------------------------------
cli::cli_h2("Importing passengers entrance (2020-2025)")
source(here("data-raw/import_passengers_entrance_2020_2025.R"), local = TRUE)

cli::cli_h2("Importing passengers transported (2020-2025)")
source(here("data-raw/import_passengers_transported_2020_2025.R"), local = TRUE)

cli::cli_h2("Importing station averages (2020-2025)")
source(here("data-raw/import_station_averages_2020_2025.R"), local = TRUE)

cli::cli_h2("Importing station daily entries (2020-2025)")
source(here("data-raw/import_station_daily_2020_2025.R"), local = TRUE)

# -- 4. Import Lines 4/5 data from Dataverse ----------------------------------
if (dataverse) {
  cli::cli_h2("Importing Lines 4 and 5 data from Dataverse")
  source(here("data-raw/import_lines_4_5_dataverse.R"), local = TRUE)
}

# -- 5. Import GeoSampa spatial data -------------------------------------------
if (geosampa) {
  cli::cli_h2("Importing GeoSampa spatial data (metro + train)")
  source(here("data-raw/import_geosampa.R"), local = TRUE)
}

# -- 6. Assemble .rda datasets ------------------------------------------------
cli::cli_h2("Assembling final datasets")
source(here("data-raw/make_datasets.R"), local = TRUE)

# -- 7. Regenerate documentation -----------------------------------------------
cli::cli_h2("Generating documentation")
devtools::document()

cli::cli_alert_success("Pipeline complete!")
