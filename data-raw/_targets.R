# _targets.R
# -----------------------------------------------------------------------------
# targets pipeline for the metrosp data package. Replaces the flag-driven
# source() orchestrator (run_pipeline.R). Run from the repo root:
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
# 2017-2019 reimport, Lines 4/5 Dataverse fetch — are GATED refreshes that run
# only when their flag is set, then rewrite the committed CSVs in place (the
# targets equivalent of the old download/historical/dataverse booleans).
#
# Gating idiom: each flag is a global (from an env var). A gated stage branches
# on its flag inside the command — when off it is a cheap no-op returning the
# existing path/NULL; when on it does the network/IO work. Because the flag is a
# tracked dependency of the command, flipping it invalidates the stage and its
# descendants. (We deliberately do NOT use tar_cue(mode = "never"): a
# never-built never-cued target would leave downstream targets with no value.)
#
# Forecasts (build_forecasts.R) are intentionally out of scope for now.
# -----------------------------------------------------------------------------

library(targets)

tar_option_set(
  packages = c(
    "dplyr", "tidyr", "stringr", "readr", "purrr", "janitor", "glue",
    "lubridate", "sf", "fs", "cli", "rlang", "here"
  )
)

# Load all extracted functions + dimension tables.
tar_source("data-raw/R")

# --- Flags (env-var driven; defaults mirror the old run_pipeline.R) ----------
flag <- function(name, default = FALSE) {
  val <- Sys.getenv(name, unset = NA_character_)
  if (is.na(val) || val == "") {
    return(default)
  }
  isTRUE(as.logical(val))
}

download   <- flag("METROSP_DOWNLOAD")
historical <- flag("METROSP_HISTORICAL")
dataverse  <- flag("METROSP_DATAVERSE")
geosampa   <- flag("METROSP_GEOSAMPA")

proc <- function(f) here::here("data-raw/processed", f)

list(
  # --- Gated source refreshes ------------------------------------------------
  # Each branches on its flag: a cheap no-op when off, the real work when on.
  # download_metro() refreshes the raw csv/ dir in place and returns its path.
  tar_target(
    metro_csv_dir,
    if (download) {
      download_metro()
    } else {
      here::here("data-raw/metro_sp/metro/csv")
    }
  ),
  # Regenerate the 2017-2019 committed CSVs (both at once) when historical=TRUE.
  tar_target(
    historic_refresh,
    if (historical) {
      refresh_historic_passengers()
      refresh_historic_averages()
      TRUE
    } else {
      FALSE
    }
  ),
  # Regenerate the three Lines 4/5 committed CSVs when dataverse=TRUE.
  tar_target(
    dataverse_refresh,
    if (dataverse) {
      refresh_dataverse()
      TRUE
    } else {
      FALSE
    }
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
