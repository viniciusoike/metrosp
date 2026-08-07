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
# 2016-2019 reimport, Lines 4/5 Dataverse fetch — are gated with
# tarchetypes::tar_force(). Each only re-runs when its env-var flag is TRUE;
# otherwise the cached result is reused and downstream targets skip unless
# their own inputs changed.
#
# All three sources follow one shape: a gated refresh_*() writes committed
# CSVs under data-raw/processed/, and the graph reads only those CSVs. Nothing
# downstream of the refresh targets touches the network or the gitignored raw
# files, so a fresh clone rebuilds every dataset offline. Because the committed
# CSVs are the only inputs, any upstream change — including METRO restating an
# already-published year — surfaces as a reviewable text diff.
#
# First-build note: tar_force() targets always run their command once (to
# populate the store), but each body is a no-op when its flag is off, so a
# fresh clone's first tar_make() makes no network calls.
#
# Forecasts (build_forecasts.R) are intentionally out of scope for now.
# -----------------------------------------------------------------------------

library(targets)
library(tarchetypes)

tar_option_set(
  packages = c(
    "dplyr",
    "tidyr",
    "stringr",
    "readr",
    "purrr",
    "janitor",
    "glue",
    "lubridate",
    "sf",
    "fs",
    "cli",
    "rlang",
    "here",
    "bizdays",
    "jsonlite",
    "digest"
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
  # tar_force() caches the result and only re-runs when force = TRUE. Each body
  # is guarded by its own flag so that when the flag is off the side-effecting
  # refresh (network scrape / reading the gitignored raw files) never runs --
  # not even on the first build or after a flag toggle invalidates the target.
  # Each refresh rewrites committed CSVs in data-raw/processed/; the *_csv file
  # targets below re-hash them, so a real upstream change propagates and a
  # no-op refresh leaves the whole downstream graph skipped.
  tar_force(
    metro_current_refresh,
    {
      if (refresh_flag("METROSP_DOWNLOAD")) {
        download_metro()
        refresh_metro_current()
      }
      TRUE
    },
    force = refresh_flag("METROSP_DOWNLOAD")
  ),
  tar_force(
    historic_refresh,
    {
      if (refresh_flag("METROSP_HISTORICAL")) {
        refresh_historic_passengers()
        refresh_historic_averages()
      }
      TRUE
    },
    force = refresh_flag("METROSP_HISTORICAL")
  ),
  tar_force(
    dataverse_refresh,
    {
      if (refresh_flag("METROSP_DATAVERSE")) {
        refresh_dataverse()
      }
      TRUE
    },
    force = refresh_flag("METROSP_DATAVERSE")
  ),

  # --- Tracked file inputs (committed CSVs; re-hash after a refresh) ----------
  tar_target(
    hist_passengers_csv,
    {
      historic_refresh
      proc("metro_sp_passengers_historic.csv")
    },
    format = "file"
  ),
  tar_target(
    hist_averages_csv,
    {
      historic_refresh
      proc("metro_sp_station_averages_historic.csv")
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
    entrance_current_csv,
    {
      metro_current_refresh
      proc("metro_sp_passengers_entrance_current.csv")
    },
    format = "file"
  ),
  tar_target(
    transported_current_csv,
    {
      metro_current_refresh
      proc("metro_sp_passengers_transported_current.csv")
    },
    format = "file"
  ),
  tar_target(
    averages_current_csv,
    {
      metro_current_refresh
      proc("metro_sp_station_averages_current.csv")
    },
    format = "file"
  ),
  tar_target(
    daily_current_csv,
    {
      metro_current_refresh
      proc("metro_sp_station_daily_current.csv")
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

  # --- Read committed current-era / historic / Lines 4/5 CSVs ----------------
  tar_target(
    entrance_current,
    readr::read_csv(entrance_current_csv, show_col_types = FALSE)
  ),
  tar_target(
    transported_current,
    readr::read_csv(transported_current_csv, show_col_types = FALSE)
  ),
  tar_target(
    averages_current,
    readr::read_csv(averages_current_csv, show_col_types = FALSE)
  ),
  tar_target(
    daily_current,
    readr::read_csv(
      daily_current_csv,
      col_types = readr::cols(station_code = readr::col_character()),
      show_col_types = FALSE
    )
  ),
  tar_target(
    psg_historic,
    readr::read_csv(hist_passengers_csv, show_col_types = FALSE)
  ),
  tar_target(
    stations_historic,
    readr::read_csv(hist_averages_csv, show_col_types = FALSE)
  ),
  tar_target(
    entrance_4_5,
    readr::read_csv(entrance_4_5_csv, show_col_types = FALSE)
  ),
  tar_target(
    averages_4_5,
    readr::read_csv(averages_4_5_csv, show_col_types = FALSE)
  ),
  tar_target(daily_4_5, readr::read_csv(daily_4_5_csv, show_col_types = FALSE)),

  # --- GeoSampa spatial datasets ---------------------------------------------
  tar_target(geo, build_geosampa(geosampa_files)),
  tar_target(lines, geo$lines),
  tar_target(stations, geo$stations),

  # --- Assemble exported datasets --------------------------------------------
  tar_target(
    passengers_entrance,
    assemble_entrance(psg_historic, entrance_current, entrance_4_5)
  ),
  tar_target(
    passengers_transported,
    assemble_transported(psg_historic, transported_current)
  ),
  tar_target(
    station_averages,
    assemble_averages(stations_historic, averages_current, averages_4_5)
  ),
  tar_target(station_daily, assemble_daily(daily_current, daily_4_5)),
  tar_target(
    station_inauguration,
    build_station_inauguration(
      inauguration_csv,
      station_daily,
      station_averages
    )
  ),

  # --- Calendar ---------------------------------------------------------------
  tar_target(calendar_spo, build_calendar_spo()),

  # --- Reference datasets (surfaced from dims.R) -----------------------------
  # metro_lines stays an internal join dimension in dims.R (not exported); its
  # line-name columns are already denormalized onto every passenger/station
  # dataset and the full line list lives in `lines`.
  tar_target(metro_colors_out, metro_colors),

  # --- Collected build --------------------------------------------------------
  # One named list so the schema gate, the release payload, and the frozen
  # writer all operate on exactly the same objects.
  tar_target(
    datasets,
    list(
      passengers_entrance = passengers_entrance,
      passengers_transported = passengers_transported,
      station_averages = station_averages,
      station_daily = station_daily,
      lines = lines,
      stations = stations,
      metro_colors = metro_colors_out,
      station_inauguration = station_inauguration,
      calendar_spo = calendar_spo
    )
  ),

  # --- Schema gate ------------------------------------------------------------
  # Hard-fails when the rebuilt data stops matching data-raw/schema.json, which
  # is the one condition that invalidates the frozen data/*.rda snapshot.
  # Everything downstream depends on it, so a drifted build publishes nothing.
  tar_target(schema_ok, check_schema(datasets)),

  # --- Routine terminal step: stage the release payload -----------------------
  # Runs every refresh. Writes data-raw/cache/*.rds + manifest.json for the
  # publish workflow to upload; touches nothing tracked by git.
  tar_target(
    release_payload,
    {
      schema_ok
      write_release_payload(datasets)
    },
    cue = tar_cue(mode = "always")
  ),

  # --- Exceptional terminal step: refreeze the shipped snapshot ---------------
  # data/*.rda is a frozen sample, regenerated only when a schema changes (or
  # for a deliberate data-bearing release). Gated so the scheduled pipeline can
  # never move it:
  #   METROSP_FREEZE=true Rscript -e 'targets::tar_make()'
  tar_force(
    write_rda,
    {
      schema_ok
      if (refresh_flag("METROSP_FREEZE")) {
        write_all_data(
          passengers_entrance = passengers_entrance,
          passengers_transported = passengers_transported,
          station_averages = station_averages,
          station_daily = station_daily,
          lines = lines,
          stations = stations,
          metro_colors = metro_colors_out,
          station_inauguration = station_inauguration,
          calendar_spo = calendar_spo
        )
      } else {
        cli::cli_alert_info(
          "Snapshot frozen; data/*.rda untouched (set METROSP_FREEZE=true to refreeze)."
        )
        character(0)
      }
    },
    force = refresh_flag("METROSP_FREEZE")
  )
)
