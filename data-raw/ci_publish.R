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

# Every batch goes to two tags. `data-latest` is what read_metro_demand() reads
# by default and is overwritten on every run; the dated tag is what
# `vintage = "2026-08"` pins, so an analysis can name the batch it used. A
# second publish inside the same month overwrites that month's tag with the
# more complete batch.
VINTAGE_TAG <- format(Sys.Date(), "data-%Y-%m")

publish <- function(tag, name, body) {
  # pb_release_create() errors when the release already exists; for the rolling
  # tag that is the steady state, so treat failure as "already there".
  tryCatch(
    {
      piggyback::pb_release_create(
        repo = repo,
        tag = tag,
        name = name,
        body = body
      )
      cli::cli_alert_success("Created release {.val {tag}}.")
    },
    error = function(e) {
      cli::cli_alert_info("Release {.val {tag}} already exists; updating assets.")
    }
  )

  piggyback::pb_upload(
    file = assets,
    repo = repo,
    tag = tag,
    overwrite = TRUE,
    show_progress = FALSE
  )

  cli::cli_alert_success("Published {length(assets)} asset{?s} to {.val {tag}}.")
}

publish(
  TAG,
  "Latest data batch",
  paste(
    "Rolling release of the most recent metrosp data batch, rebuilt from",
    "the upstream sources by `data-refresh.yaml`.",
    "",
    "These assets are *not* the package's frozen datasets -- they are the",
    "current data. See `manifest.json` for the vintage, row counts, date",
    "coverage, and SHA-256 of every asset.",
    "",
    "```r",
    'metrosp::read_metro_demand("station_daily")',
    "```",
    sep = "\n"
  )
)

publish(
  VINTAGE_TAG,
  paste("Data batch", format(Sys.Date(), "%Y-%m")),
  paste(
    sprintf(
      "Pinned copy of the metrosp data batch published in %s.",
      format(Sys.Date(), "%B %Y")
    ),
    "",
    "Use this tag to hold an analysis to one batch while `data-latest` moves on.",
    "",
    "```r",
    sprintf(
      'metrosp::read_metro_demand("station_daily", vintage = "%s")',
      format(Sys.Date(), "%Y-%m")
    ),
    "```",
    sep = "\n"
  )
)
