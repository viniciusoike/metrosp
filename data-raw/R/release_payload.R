# release_payload.R
# -----------------------------------------------------------------------------
# The routine endpoint of the pipeline: stage the freshly built datasets for
# publication as GitHub Release assets.
#
# This is what replaced write_all_data() as the every-run terminal step. Writing
# data/*.rda is now the exceptional path (METROSP_FREEZE), because the shipped
# snapshot is frozen; the staged .rds files here are what get_data() will fetch.
#
# Staging dir is data-raw/cache/ -- already gitignored and already named for
# this job ("Piggyback cache (datasets managed via GitHub Releases)").
# -----------------------------------------------------------------------------

.cache_dir <- function() here::here("data-raw/cache")

#' Stage datasets as .rds plus a manifest describing the batch.
#'
#' The manifest is the contract get_data() reads: it turns cache invalidation
#' into a timestamp comparison, integrity into a hash check, and asset discovery
#' into a lookup rather than a guess.
#'
#' @param datasets Named list of built datasets.
#' @param dir Staging directory.
#' @return Invisibly, the path to manifest.json.
write_release_payload <- function(datasets, dir = .cache_dir()) {
  fs::dir_create(dir)

  entries <- list()

  for (nm in names(datasets)) {
    x <- datasets[[nm]]
    path <- file.path(dir, paste0(nm, ".rds"))
    # compress = "xz" keeps station_daily (the only large one) modest over the
    # wire; the cost is build-time only.
    saveRDS(x, path, compress = "xz")

    entries[[nm]] <- c(
      list(
        file = basename(path),
        bytes = as.numeric(fs::file_size(path)),
        sha256 = digest::digest(path, algo = "sha256", file = TRUE)
      ),
      .payload_shape(x)
    )
  }

  manifest <- list(
    built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pipeline_commit = .git_sha(),
    schema_version = .package_version(),
    datasets = entries
  )

  manifest_path <- file.path(dir, "manifest.json")
  jsonlite::write_json(
    manifest,
    manifest_path,
    auto_unbox = TRUE,
    pretty = TRUE
  )

  cli::cli_alert_success(
    "Staged {length(entries)} dataset{?s} + manifest in {.path {dir}}."
  )
  invisible(manifest_path)
}

# Row counts and date coverage per dataset. These are what make the manifest
# readable at a glance and what the validation report diffs against.
.payload_shape <- function(x) {
  if (!is.data.frame(x)) {
    return(list(kind = "vector", length = length(x)))
  }

  shape <- list(kind = "data.frame", rows = nrow(x), columns = ncol(x))

  if ("date" %in% names(x) && nrow(x) > 0) {
    shape$date_min <- as.character(min(x$date, na.rm = TRUE))
    shape$date_max <- as.character(max(x$date, na.rm = TRUE))
  }

  shape
}

# Read from DESCRIPTION rather than packageVersion(): the pipeline must not
# require metrosp to be installed to stage a payload.
.package_version <- function() {
  as.character(read.dcf(here::here("DESCRIPTION"), fields = "Version")[[1]])
}

.git_sha <- function() {
  sha <- tryCatch(
    system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE),
    error = function(e) NA_character_,
    warning = function(w) NA_character_
  )
  if (length(sha) == 0 || is.na(sha[[1]])) NA_character_ else sha[[1]]
}

#' Read a manifest from a staging dir or an extracted release download.
read_manifest <- function(dir = .cache_dir()) {
  jsonlite::read_json(file.path(dir, "manifest.json"), simplifyVector = FALSE)
}
