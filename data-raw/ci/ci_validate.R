# ci_validate.R
# -----------------------------------------------------------------------------
# Validation step of the scheduled refresh workflow. Run after tar_make() has
# rebuilt the datasets and staged data-raw/cache/.
#
#   Rscript data-raw/ci/ci_validate.R
#
# Downloads the previously published batch from the `data-latest` release,
# compares it against the fresh build, writes the markdown report that becomes
# the PR body, and exits non-zero if any blocking check failed.
#
# Structural + schema checks already ran inside the graph (schema_ok target);
# what happens here is everything that needs the baseline.
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(stringr)
})

targets::tar_source("data-raw/R")

REPORT_PATH <- here::here("data-raw/outputs/validation-report.md")
BASELINE_TAG <- "data-latest"

# --- Fetch the previously published batch ------------------------------------

baseline_dir <- file.path(tempdir(), "metrosp-baseline")
dir.create(baseline_dir, showWarnings = FALSE, recursive = TRUE)

# "No baseline" used to cover both a genuine first publish and any failure on
# the way to one, so a broken download read as business as usual and the
# baseline-dependent checks below quietly did nothing. The three cases are now
# reported separately.
baseline <- NULL

if (!release_exists(BASELINE_TAG)) {
  cli::cli_alert_info(
    "No {.val {BASELINE_TAG}} release yet; this is a first publish."
  )
} else if (length(release_asset_names(BASELINE_TAG)) == 0) {
  cli::cli_alert_warning(
    "Release {.val {BASELINE_TAG}} exists but carries no assets."
  )
} else {
  baseline <- tryCatch(
    {
      download_release_assets(BASELINE_TAG, baseline_dir)
      load_baseline(baseline_dir)
    },
    error = function(e) {
      cli::cli_alert_warning(
        "Could not load the {.val {BASELINE_TAG}} baseline:
         {conditionMessage(e)}"
      )
      return(NULL)
    }
  )
}

if (is.null(baseline)) {
  cli::cli_alert_warning(
    "Baseline-dependent checks (shrinkage, coverage regression, retroactive
     drift, magnitude outliers) are skipped."
  )
} else {
  cli::cli_alert_success("Baseline loaded: {length(baseline)} dataset{?s}.")
}

# --- Validate ----------------------------------------------------------------

datasets <- targets::tar_read(datasets)
dim_station <- targets::tar_read(dim_station)
dim_station_alias <- targets::tar_read(dim_station_alias)
result <- validate_refresh(
  datasets,
  baseline,
  dim_station = dim_station,
  dim_station_alias = dim_station_alias
)

# A partial refresh (e.g. Dataverse unreachable) is recorded by the workflow so
# the PR says which source is stale rather than silently implying both moved.
partial <- Sys.getenv("METROSP_PARTIAL_REFRESH", unset = "")
report <- result$report
if (nzchar(partial)) {
  report <- paste0(
    report,
    "\n### ⚠️ Partial refresh\n\n",
    partial,
    "\n"
  )
}

writeLines(report, REPORT_PATH)
cli::cli_alert_info("Report written to {.path {REPORT_PATH}}.")
cat("\n", report, "\n", sep = "")

if (!result$ok) {
  cli::cli_abort("Validation failed; refusing to publish.")
}
