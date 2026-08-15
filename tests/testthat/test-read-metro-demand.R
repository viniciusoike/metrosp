# Tests for the published-data reader.
#
# No test touches the network: fetch_url() is the single network seam, and the
# round-trip tests mock it to copy from a fixture directory standing in for the
# GitHub release.

# Fixtures --------------------------------------------------------------------

# Builds a directory shaped like a release: one .rds per dataset plus the
# manifest.json the reader navigates by.
local_fake_release <- function(
  datasets = list(passengers_entrance = data.frame(date = as.Date("2026-01-01"), value = 1)),
  corrupt = character(0),
  env = parent.frame()
) {
  dir <- withr::local_tempdir(.local_envir = env)
  entries <- list()

  for (nm in names(datasets)) {
    path <- file.path(dir, paste0(nm, ".rds"))
    saveRDS(datasets[[nm]], path)
    entries[[nm]] <- list(
      file = basename(path),
      bytes = as.numeric(file.size(path)),
      sha256 = digest::digest(path, algo = "sha256", file = TRUE),
      kind = "data.frame",
      rows = nrow(datasets[[nm]])
    )
  }

  # Rewrite the payload after hashing so the manifest advertises a hash the
  # asset no longer has.
  for (nm in corrupt) {
    saveRDS(data.frame(tampered = TRUE), file.path(dir, paste0(nm, ".rds")))
  }

  jsonlite::write_json(
    list(built_at = "2026-08-13T23:07:37Z", datasets = entries),
    file.path(dir, "manifest.json"),
    auto_unbox = TRUE
  )

  dir
}

# Points the cache at a scratch directory and serves downloads from `release`.
local_release_source <- function(release, env = parent.frame()) {
  cache <- withr::local_tempdir(.local_envir = env)
  withr::local_options(metrosp.cache_dir = cache, .local_envir = env)

  testthat::local_mocked_bindings(
    fetch_url = function(url, path, quiet = FALSE) {
      src <- file.path(release, basename(url))
      if (!file.exists(src)) stop("404: ", url)
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      file.copy(src, path, overwrite = TRUE)
      invisible(path)
    },
    .env = env
  )

  cache
}

# Bundled source --------------------------------------------------------------

test_that("the bundled source returns the frozen snapshot unchanged", {
  expect_identical(
    read_metro_demand("passengers_entrance", source = "bundled"),
    metrosp::passengers_entrance
  )
  expect_identical(
    read_metro_demand("station_daily", source = "bundled"),
    metrosp::station_daily
  )
})

test_that("the bundled source never reaches the network", {
  local_mocked_bindings(
    fetch_url = function(...) stop("network access attempted")
  )
  expect_s3_class(
    read_metro_demand("station_averages", source = "bundled"),
    "data.frame"
  )
})

test_that("dataset defaults to the first demand dataset", {
  expect_identical(
    read_metro_demand(source = "bundled"),
    metrosp::passengers_entrance
  )
})

# Argument validation ---------------------------------------------------------

test_that("non-demand datasets are rejected with a pointer to the bundled ones", {
  expect_error(read_metro_demand("lines", source = "bundled"), "must be one of")
  expect_error(read_metro_demand("metro_colors", source = "bundled"), "must be one of")
  expect_error(read_metro_demand(1, source = "bundled"), "must be one of")
})

test_that("vintage strings map to release tags", {
  expect_identical(vintage_tag("latest"), "data-latest")
  expect_identical(vintage_tag(NULL), "data-latest")
  expect_identical(vintage_tag("2026-08"), "data-2026-08")
  expect_identical(vintage_tag("data-2026-08"), "data-2026-08")

  expect_error(vintage_tag("august"), "Unrecognised")
  expect_error(vintage_tag("2026"), "Unrecognised")
  expect_error(vintage_tag(c("2026-08", "2026-09")), "single string")
})

test_that("asset URLs point at the release download endpoint", {
  withr::local_options(metrosp.repo = "someone/metrosp")
  expect_identical(
    asset_url("data-latest", "station_daily.rds"),
    "https://github.com/someone/metrosp/releases/download/data-latest/station_daily.rds"
  )
})

# Remote round trip -----------------------------------------------------------

test_that("a remote read downloads the asset and returns it", {
  payload <- data.frame(date = as.Date("2026-07-01"), value = 42)
  release <- local_fake_release(list(passengers_entrance = payload))
  cache <- local_release_source(release)

  out <- read_metro_demand(
    "passengers_entrance",
    source = "remote",
    quiet = TRUE
  )

  expect_identical(out, payload)
  expect_true(
    file.exists(file.path(cache, "data-latest", "passengers_entrance.rds"))
  )
})

test_that("a warm cache serves the asset without downloading again", {
  release <- local_fake_release()
  local_release_source(release)

  read_metro_demand("passengers_entrance", source = "remote", quiet = TRUE)

  # Removing the fixture makes any further fetch fail, so a successful read
  # proves nothing was downloaded.
  unlink(release, recursive = TRUE)
  expect_s3_class(
    read_metro_demand("passengers_entrance", source = "cache"),
    "data.frame"
  )
})

test_that("cache = FALSE keeps the persistent cache empty", {
  release <- local_fake_release()
  cache <- local_release_source(release)

  read_metro_demand(
    "passengers_entrance",
    source = "remote",
    cache = FALSE,
    quiet = TRUE
  )

  expect_false(dir.exists(file.path(cache, "data-latest")))
})

test_that("a dataset missing from the vintage is reported by name", {
  release <- local_fake_release()
  local_release_source(release)

  expect_error(
    read_metro_demand("station_daily", source = "remote", quiet = TRUE),
    "does not contain"
  )
})

# Integrity -------------------------------------------------------------------

test_that("a checksum mismatch errors and discards the download", {
  skip_if_not_installed("digest")

  release <- local_fake_release(corrupt = "passengers_entrance")
  cache <- local_release_source(release)

  expect_error(
    read_metro_demand("passengers_entrance", source = "remote", quiet = TRUE),
    "Checksum mismatch"
  )
  expect_false(
    file.exists(file.path(cache, "data-latest", "passengers_entrance.rds"))
  )
})

test_that("a corrupted cached asset is re-downloaded", {
  skip_if_not_installed("digest")

  payload <- data.frame(date = as.Date("2026-07-01"), value = 42)
  release <- local_fake_release(list(passengers_entrance = payload))
  cache <- local_release_source(release)

  read_metro_demand("passengers_entrance", source = "remote", quiet = TRUE)

  cached <- file.path(cache, "data-latest", "passengers_entrance.rds")
  saveRDS(data.frame(tampered = TRUE), cached)

  expect_identical(
    read_metro_demand("passengers_entrance", source = "auto", quiet = TRUE),
    payload
  )
})

# Source resolution -----------------------------------------------------------

test_that("the cache source errors instead of downloading", {
  release <- local_fake_release()
  local_release_source(release)

  expect_error(
    read_metro_demand("passengers_entrance", source = "cache"),
    "No cached manifest"
  )
})

test_that("auto falls back to the bundled snapshot when the release is unreachable", {
  withr::local_options(metrosp.cache_dir = withr::local_tempdir())
  local_mocked_bindings(
    fetch_url = function(...) stop("no network")
  )

  expect_warning(
    out <- read_metro_demand("passengers_entrance", source = "auto"),
    "using the bundled snapshot"
  )
  expect_identical(out, metrosp::passengers_entrance)
})

test_that("remote propagates the failure instead of falling back", {
  withr::local_options(metrosp.cache_dir = withr::local_tempdir())
  local_mocked_bindings(
    fetch_url = function(...) stop("no network")
  )

  expect_error(
    read_metro_demand("passengers_entrance", source = "remote"),
    "Could not download the manifest"
  )
})

# Manifest freshness ----------------------------------------------------------

test_that("only the rolling tag goes stale", {
  path <- withr::local_tempfile()
  file.create(path)
  withr::local_options(metrosp.cache_ttl = -1)

  expect_true(manifest_stale(path, "data-latest"))
  expect_false(manifest_stale(path, "data-2026-08"))
})

test_that("a fresh manifest is not re-fetched", {
  release <- local_fake_release()
  local_release_source(release)
  withr::local_options(metrosp.cache_ttl = 3600)

  read_metro_demand("passengers_entrance", source = "auto", quiet = TRUE)
  unlink(file.path(release, "manifest.json"))

  expect_s3_class(
    read_metro_demand("passengers_entrance", source = "auto", quiet = TRUE),
    "data.frame"
  )
})

test_that("a stale manifest that cannot be refreshed falls back to the cached copy", {
  release <- local_fake_release()
  local_release_source(release)

  read_metro_demand("passengers_entrance", source = "auto", quiet = TRUE)

  withr::local_options(metrosp.cache_ttl = -1)
  unlink(file.path(release, "manifest.json"))

  expect_warning(
    out <- read_metro_demand("passengers_entrance", source = "auto", quiet = TRUE),
    "using the cached copy"
  )
  expect_s3_class(out, "data.frame")
})

# Helpers ---------------------------------------------------------------------

test_that("byte counts render at a readable scale", {
  expect_identical(format_bytes(512), "512.0 B")
  expect_identical(format_bytes(2048), "2.0 KB")
  expect_identical(format_bytes(5 * 1024^2), "5.0 MB")
  expect_identical(format_bytes(NULL), "unknown size")
})
