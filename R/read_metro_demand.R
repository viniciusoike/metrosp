# Reading published demand data ----------------------------------------------
#
# The four demand datasets grow every month and are restated retroactively, so
# the copies in data/*.rda are a frozen snapshot rather than a live mirror. The
# pipeline publishes each fresh build to a GitHub release as .rds assets plus a
# manifest.json carrying row counts, date coverage, and a SHA-256 per asset.
#
# This file is the client for that release. The manifest is what makes it
# cheap: freshness is a timestamp comparison and integrity is a hash check, so
# a warm cache re-downloads nothing.
#
# read_metro_demand() is exported; everything below it is internal. fetch_url()
# is the single network seam, so the tests mock it and never reach GitHub.

demand_datasets <- c(
  "line_entries_monthly",
  "line_transported_monthly",
  "station_entries_monthly",
  "station_entries_daily"
)

legacy_demand_datasets <- c(
  line_entries_monthly = "passengers_entrance",
  line_transported_monthly = "passengers_transported",
  station_entries_monthly = "station_averages",
  station_entries_daily = "station_daily"
)

last_legacy_vintage <- "data-2026-09"

#' Read Metro SP demand data
#'
#' Reads one of the four passenger demand datasets, preferring the most
#' recently published version over the frozen snapshot bundled with the
#' package. Published data lives in the repository's GitHub releases and is
#' rebuilt from the upstream sources on every pipeline run.
#'
#' @param dataset Dataset to read. One of `"line_entries_monthly"`,
#'   `"line_transported_monthly"`, `"station_entries_monthly"`, or
#'   `"station_entries_daily"`.
#' @param source Where to read from.
#'   * `"auto"` (default) uses the cache, downloads when it is stale or empty,
#'     and falls back to the bundled snapshot with a warning if the download
#'     fails.
#'   * `"cache"` reads only what is already on disk and errors otherwise.
#'   * `"remote"` downloads and errors if that fails.
#'   * `"bundled"` reads the frozen snapshot and never touches the network.
#' @param vintage Which published batch to read. `"latest"` tracks the rolling
#'   release; a year-month string such as `"2026-09"` pins an immutable batch.
#' @param cache Whether to write downloads to `metrosp_cache_dir()`.
#' @param quiet Whether to suppress progress messages.
#'
#' @return A data frame. See [line_entries_monthly], [line_transported_monthly],
#'   [station_entries_monthly], and [station_entries_daily] for the column
#'   definitions, which are identical across sources.
#'
#' @details
#' Only the demand datasets are published separately. The reference datasets
#' ([rail_lines], [rail_stations], [calendar_spo], and [metro_colors]) do not
#' change with new months, so read them directly.
#'
#' Downloads verify the manifest's SHA-256 when the \pkg{digest} package is
#' installed and skip verification otherwise.
#'
#' @seealso [metrosp_cache_dir()], [metrosp_cache_enable()],
#'   [metrosp_cache_list()], and [metrosp_cache_clear()] for cache management.
#'
#' @examples
#' # The bundled snapshot, read without touching the network.
#' head(read_metro_demand("line_entries_monthly", source = "bundled"))
#'
#' \donttest{
#' # The most recently published data, cached between calls.
#' entrance <- read_metro_demand("line_entries_monthly")
#'
#' # A pinned vintage, so an analysis can name the batch it used.
#' entrance_sep <- read_metro_demand(
#'   "line_entries_monthly",
#'   vintage = "2026-09"
#' )
#' }
#'
#' @export
read_metro_demand <- function(
  dataset = c(
    "line_entries_monthly",
    "line_transported_monthly",
    "station_entries_monthly",
    "station_entries_daily"
  ),
  source = c("auto", "cache", "remote", "bundled"),
  vintage = "latest",
  cache = TRUE,
  quiet = FALSE
) {
  dataset <- match_dataset(dataset)
  source <- match.arg(source)

  if (identical(source, "bundled")) {
    return(read_bundled(dataset))
  }

  if (identical(source, "auto")) {
    out <- tryCatch(
      read_published(dataset, vintage, "auto", cache, quiet),
      error = function(e) {
        cli::cli_warn(c(
          "Could not read the published {.val {vintage}} data; using the bundled snapshot.",
          "x" = conditionMessage(e),
          "i" = "Use {.code source = \"bundled\"} to silence this."
        ))
        NULL
      }
    )
    return(out %||% read_bundled(dataset))
  }

  read_published(dataset, vintage, source, cache, quiet)
}

# Sources ---------------------------------------------------------------------

read_bundled <- function(dataset) {
  getExportedValue("metrosp", dataset)
}

# `mode` is one of "auto", "cache", or "remote", carrying the same meaning as
# the corresponding `source` values in read_metro_demand().
read_published <- function(dataset, vintage, mode, cache, quiet) {
  tag <- vintage_tag(vintage)
  dir <- vintage_dir(tag, cache)
  release_dataset <- release_dataset_name(dataset, tag)

  manifest <- read_release_manifest(tag, dir, mode, quiet)

  entry <- manifest$datasets[[release_dataset]]
  if (is.null(entry)) {
    cli::cli_abort(
      "Vintage {.val {vintage}} does not contain {.val {dataset}}."
    )
  }

  path <- file.path(dir, entry$file)

  if (!file.exists(path) || !hash_matches(path, entry$sha256)) {
    if (identical(mode, "cache")) {
      cli::cli_abort(c(
        "{.val {dataset}} is not cached for vintage {.val {vintage}}.",
        "i" = "Use {.code source = \"auto\"} or {.code source = \"remote\"} to download it."
      ))
    }
    download_asset(tag, entry, path, quiet = quiet)
  }

  readRDS(path)
}

release_dataset_name <- function(dataset, tag) {
  if (!is_legacy_vintage(tag)) {
    return(dataset)
  }

  if (!dataset %in% names(legacy_demand_datasets)) {
    cli::cli_warn(c(
      "No archived-release mapping exists for {.val {dataset}} in {.val {tag}}.",
      "i" = "This is an unhandled pre-2.0 archive tag; please report it."
    ))
    return(dataset)
  }

  legacy_name <- unname(legacy_demand_datasets[[dataset]])
  return(legacy_name)
}

is_legacy_vintage <- function(tag) {
  is_dated <- grepl("^data-[0-9]{4}-[0-9]{2}$", tag)
  return(is_dated && tag <= last_legacy_vintage)
}

# Manifest --------------------------------------------------------------------

# The rolling `data-latest` tag moves, so its manifest is re-fetched once the
# cached copy passes its TTL. Dated vintages never change and are read straight
# from disk.
read_release_manifest <- function(tag, dir, mode, quiet = FALSE) {
  path <- file.path(dir, "manifest.json")
  cached <- file.exists(path)

  if (identical(mode, "cache")) {
    if (!cached) {
      cli::cli_abort(c(
        "No cached manifest for vintage {.val {tag}}.",
        "i" = "Use {.code source = \"auto\"} or {.code source = \"remote\"} to download it."
      ))
    }
    return(jsonlite::read_json(path, simplifyVector = FALSE))
  }

  fresh <- cached && !manifest_stale(path, tag) && !identical(mode, "remote")
  if (fresh) {
    return(jsonlite::read_json(path, simplifyVector = FALSE))
  }

  ask_cache_consent()

  tryCatch(
    fetch_url(asset_url(tag, "manifest.json"), path, quiet = quiet),
    error = function(e) {
      # A stale manifest beats no data at all when the network is down, but
      # only when the caller did not explicitly demand the remote copy.
      if (cached && !identical(mode, "remote")) {
        cli::cli_warn("Could not refresh the manifest; using the cached copy.")
      } else {
        cli::cli_abort(
          "Could not download the manifest for vintage {.val {tag}}.",
          parent = e
        )
      }
    }
  )

  jsonlite::read_json(path, simplifyVector = FALSE)
}

manifest_stale <- function(path, tag) {
  # Dated vintages are immutable; only the rolling tag can go stale.
  if (!identical(tag, "data-latest")) {
    return(FALSE)
  }
  ttl <- getOption("metrosp.cache_ttl", 6 * 3600)
  age <- as.numeric(difftime(Sys.time(), file.mtime(path), units = "secs"))
  age > ttl
}

# Downloads -------------------------------------------------------------------

download_asset <- function(tag, entry, path, quiet = FALSE) {
  ask_cache_consent()

  if (!quiet) {
    cli::cli_alert_info(
      "Downloading {.file {entry$file}} ({format_bytes(entry$bytes)})."
    )
  }

  fetch_url(asset_url(tag, entry$file), path, quiet = quiet)

  if (!hash_matches(path, entry$sha256)) {
    unlink(path)
    cli::cli_abort(
      c(
        "Checksum mismatch for {.file {entry$file}}.",
        "i" = "The download was discarded. Try again, or report this if it repeats."
      )
    )
  }

  invisible(path)
}

# The single network seam, so tests can mock it.
fetch_url <- function(url, path, quiet = FALSE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".part")

  status <- utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  if (!identical(status, 0L) || !file.exists(tmp)) {
    unlink(tmp)
    cli::cli_abort("Download failed: {.url {url}}")
  }

  file.rename(tmp, path)
  invisible(path)
}

# Helpers ---------------------------------------------------------------------

match_dataset <- function(dataset) {
  if (length(dataset) > 1) {
    dataset <- dataset[[1]]
  }

  if (!is.character(dataset) || !dataset %in% demand_datasets) {
    cli::cli_abort(c(
      "{.arg dataset} must be one of {.val {demand_datasets}}.",
      "i" = "Reference datasets such as {.code rail_lines} and
             {.code rail_stations} are bundled with the package; use them
             directly."
    ))
  }

  dataset
}

vintage_tag <- function(vintage) {
  if (is.null(vintage) || identical(vintage, "latest")) {
    return("data-latest")
  }

  if (!is.character(vintage) || length(vintage) != 1) {
    cli::cli_abort("{.arg vintage} must be a single string.")
  }

  if (grepl("^\\d{4}-\\d{2}$", vintage)) {
    return(paste0("data-", vintage))
  }

  if (grepl("^data-", vintage)) {
    return(vintage)
  }

  cli::cli_abort(c(
    "Unrecognised {.arg vintage}: {.val {vintage}}.",
    "i" = 'Use {.val latest} or a year-month such as {.val 2026-09}.'
  ))
}

vintage_dir <- function(tag, cache = TRUE) {
  dir <- if (isTRUE(cache)) {
    metrosp_cache_dir()
  } else {
    file.path(tempdir(), "metrosp-nocache")
  }

  path <- file.path(dir, tag)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

metrosp_repo <- function() {
  getOption("metrosp.repo", "viniciusoike/metrosp")
}

asset_url <- function(tag, file) {
  sprintf(
    "https://github.com/%s/releases/download/%s/%s",
    metrosp_repo(),
    tag,
    file
  )
}

# Verification is best-effort: digest is a Suggests, and a missing hash in an
# older manifest should not block a read.
hash_matches <- function(path, expected) {
  if (is.null(expected) || !requireNamespace("digest", quietly = TRUE)) {
    return(TRUE)
  }
  identical(
    digest::digest(path, algo = "sha256", file = TRUE),
    as.character(expected)
  )
}

format_bytes <- function(bytes) {
  if (is.null(bytes) || is.na(bytes)) {
    return("unknown size")
  }
  units <- c("B", "KB", "MB", "GB")
  i <- min(length(units), max(1, floor(log(max(bytes, 1), 1024)) + 1))
  sprintf("%.1f %s", bytes / 1024^(i - 1), units[i])
}

`%||%` <- function(x, y) if (is.null(x)) y else x
