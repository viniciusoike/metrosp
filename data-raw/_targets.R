# _targets.R
# -----------------------------------------------------------------------------
# targets pipeline for the metrosp data package. Run from the repo root:
#
#   Rscript -e 'targets::tar_make()'                 # incremental rebuild
#   METROSP_DOWNLOAD=true METROSP_DATAVERSE=true \
#     Rscript -e 'targets::tar_make()'               # refresh from sources
#   Rscript -e 'targets::tar_visnetwork()'           # inspect the DAG
#
# Then, outside the graph:
#   Rscript -e 'devtools::document()'                # refresh man/*.Rd
#
# Pipeline boundary: the graph assembles data/*.rda from the committed
# intermediate CSVs (data-raw/processed/), the GeoSampa GPKGs, and the
# station_inauguration.csv. The expensive/network stages — METRO download,
# 2017-2019 reimport, Lines 4/5 Dataverse fetch — are gated with
# tarchetypes::tar_force(). Each only re-runs when its env-var flag is TRUE;
# otherwise the cached result is reused and downstream targets skip unless
# their own inputs changed.
#
# First-build note: tar_force() targets always run their command once (to
# populate the store). On a fresh clone this means the first tar_make() will
# attempt network calls. Set flags explicitly on first build or seed the store
# with tar_make(names = c(...)) for the offline-only targets.
#
# Forecasts (build_forecasts.R) are intentionally out of scope for now.
# -----------------------------------------------------------------------------

library(targets)
library(tarchetypes)

tar_option_set(
  packages = c(
    "dplyr", "tidyr", "stringr", "readr", "purrr", "janitor", "glue",
    "lubridate", "sf", "fs", "cli", "rlang", "here", "bizdays"
  )
)

tar_source("data-raw/R")

# --- Helpers -----------------------------------------------------------------
refresh_flag <- function(name) {
  isTRUE(as.logical(Sys.getenv(name, unset = "FALSE")))
}

proc <- function(f) here::here("data-raw/processed", f)

list(
  # --- Gated source refreshes (tar_force) ------------------------------------
  # tar_force() caches the result and only re-runs when force = TRUE.
  # Downstream targets rebuild only if the refreshed output actually changed.
  tar_force(
    metro_csv_dir,
    download_metro(),
    force = refresh_flag("METROSP_DOWNLOAD")
  ),
  tar_force(
    historic_refresh,
    {
      refresh_historic_passengers()
      refresh_historic_averages()
      TRUE
    },
    force = refresh_flag("METROSP_HISTORICAL")
  ),
  tar_force(
    dataverse_refresh,
    {
      refresh_dataverse()
      TRUE
    },
    force = refresh_flag("METROSP_DATAVERSE")
  ),

  # --- Tracked file inputs (committed CSVs; re-hash after a refresh) ----------
  tar_target(
    hist_passengers_csv,
    {
      historic_refresh
      proc("metro_sp_passengers_2017_2019.csv")
    },
    format = "file"
  ),
  tar_target(
    hist_averages_csv,
    {
      historic_refresh
      proc("metro_sp_station_averages_2017_2019.csv")
    },
    format = "file"
  ),
  tar_target(
    entrance_4_5_csv,
    {
      dataverse_refresh
      proc("metro_sp_passengers_entrance_lines_4_5.csv")
    },
    format = "file"
  ),
  tar_target(
    averages_4_5_csv,
    {
      dataverse_refresh
      proc("metro_sp_station_averages_lines_4_5.csv")
    },
    format = "file"
  ),
  tar_target(
    daily_4_5_csv,
    {
      dataverse_refresh
      proc("metro_sp_station_daily_lines_4_5.csv")
    },
    format = "file"
  ),
  tar_target(
    inauguration_csv,
    here::here("data-raw/station_inauguration.csv"),
    format = "file"
  ),
  tar_target(
    geosampa_files,
    list.files(
      here::here("data-raw/geosampa"),
      pattern = "\\.gpkg$",
      full.names = TRUE
    ),
    format = "file"
  ),

  # --- Current-era METRO builders (content-addressed; depend on download) ----
  tar_target(entrance_current,    { metro_csv_dir; build_entrance_current() }),
  tar_target(transported_current, { metro_csv_dir; build_transported_current() }),
  tar_target(averages_current,    { metro_csv_dir; build_averages_current() }),
  tar_target(daily_current,       { metro_csv_dir; build_station_daily_current() }),

  # --- Read committed historic / Lines 4/5 CSVs ------------------------------
  tar_target(psg_17_19,      readr::read_csv(hist_passengers_csv, show_col_types = FALSE)),
  tar_target(stations_17_19, readr::read_csv(hist_averages_csv, show_col_types = FALSE)),
  tar_target(entrance_4_5,   readr::read_csv(entrance_4_5_csv, show_col_types = FALSE)),
  tar_target(averages_4_5,   readr::read_csv(averages_4_5_csv, show_col_types = FALSE)),
  tar_target(daily_4_5,      readr::read_csv(daily_4_5_csv, show_col_types = FALSE)),

  # --- GeoSampa spatial datasets ---------------------------------------------
  tar_target(geo, build_geosampa(geosampa_files)),
  tar_target(lines, geo$lines),
  tar_target(stations, geo$stations),

  # --- Assemble exported datasets --------------------------------------------
  tar_target(passengers_entrance,    assemble_entrance(psg_17_19, entrance_current, entrance_4_5)),
  tar_target(passengers_transported, assemble_transported(psg_17_19, transported_current)),
  tar_target(station_averages,       assemble_averages(stations_17_19, averages_current, averages_4_5)),
  tar_target(station_daily,          assemble_daily(daily_current, daily_4_5)),
  tar_target(
    station_inauguration,
    build_station_inauguration(inauguration_csv, station_daily, station_averages)
  ),

  # --- Reference datasets (surfaced from dims.R) -----------------------------
  tar_target(metro_lines_out, metro_lines),
  tar_target(metro_colors_out, metro_colors),

  # --- Terminal writer: the only use_data() side effect ----------------------
  tar_target(
    write_rda,
    write_all_data(
      passengers_entrance = passengers_entrance,
      passengers_transported = passengers_transported,
      station_averages = station_averages,
      station_daily = station_daily,
      lines = lines,
      stations = stations,
      metro_lines = metro_lines_out,
      metro_colors = metro_colors_out,
      station_inauguration = station_inauguration
    ),
    cue = tar_cue(mode = "always")
  )
)
