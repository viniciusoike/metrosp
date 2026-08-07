# ci_publish.R
# -----------------------------------------------------------------------------
# Publish the staged batch to the rolling `data-latest` GitHub Release.
#
#   Rscript data-raw/ci_publish.R
#
# Expects data-raw/cache/ to hold the .rds assets and manifest.json written by
# the release_payload target. Creates the release if it does not exist, then
# overwrites the assets in place -- the tag is a moving pointer to "current",
# and manifest.json carries the vintage.
# -----------------------------------------------------------------------------

suppressPackageStartupMessages(library(dplyr))

targets::tar_source("data-raw/R")

TAG <- "data-latest"

cache <- here::here("data-raw/cache")
assets <- list.files(cache, pattern = "\\.(rds|json)$", full.names = TRUE)

if (length(assets) == 0) {
  cli::cli_abort(
    "Nothing staged in {.path {cache}}; run {.code targets::tar_make()} first."
  )
}

manifest <- read_manifest(cache)
cli::cli_alert_info(
  "Publishing {length(assets)} asset{?s} built at {manifest$built_at}
   (commit {manifest$pipeline_commit}, schema {manifest$schema_version})."
)

repo <- Sys.getenv("GITHUB_REPOSITORY", unset = "viniciusoike/metrosp")

# pb_release_create() errors when the release already exists; that is the
# steady state, so treat failure as "already there" and carry on to upload.
tryCatch(
  {
    piggyback::pb_release_create(
      repo = repo,
      tag = TAG,
      name = "Latest data batch",
      body = paste(
        "Rolling release of the most recent metrosp data batch, rebuilt from",
        "the upstream sources by `data-refresh.yaml`.",
        "",
        "These assets are *not* the package's frozen datasets -- they are the",
        "current data. See `manifest.json` for the vintage, row counts, date",
        "coverage, and SHA-256 of every asset.",
        sep = "\n"
      )
    )
    cli::cli_alert_success("Created release {.val {TAG}}.")
  },
  error = function(e) {
    cli::cli_alert_info("Release {.val {TAG}} already exists; updating assets.")
  }
)

piggyback::pb_upload(
  file = assets,
  repo = repo,
  tag = TAG,
  overwrite = TRUE,
  show_progress = FALSE
)

cli::cli_alert_success("Published {length(assets)} asset{?s} to {.val {TAG}}.")
