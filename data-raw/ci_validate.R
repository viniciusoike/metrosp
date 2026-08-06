# ci_validate.R
# -----------------------------------------------------------------------------
# Validation step of the scheduled refresh workflow. Run after tar_make() has
# rebuilt the datasets and staged data-raw/cache/.
#
#   Rscript data-raw/ci_validate.R
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
})

targets::tar_source("data-raw/R")

REPORT_PATH <- here::here("data-raw/validation-report.md")
BASELINE_TAG <- "data-latest"

# --- Fetch the previously published batch ------------------------------------

baseline_dir <- file.path(tempdir(), "metrosp-baseline")
dir.create(baseline_dir, showWarnings = FALSE, recursive = TRUE)

baseline <- tryCatch(
  {
    piggyback::pb_download(
      dest = baseline_dir,
      tag = BASELINE_TAG,
      show_progress = FALSE
    )
    load_baseline(baseline_dir)
  },
  error = function(e) {
    cli::cli_alert_warning(
      "No baseline from tag {.val {BASELINE_TAG}}: {conditionMessage(e)}"
    )
    NULL
  }
)

if (is.null(baseline)) {
  cli::cli_alert_info("Proceeding without a baseline (first publish).")
} else {
  cli::cli_alert_success("Baseline loaded: {length(baseline)} dataset{?s}.")
}

# --- Validate ----------------------------------------------------------------

datasets <- targets::tar_read(datasets)
result <- validate_refresh(datasets, baseline)

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
