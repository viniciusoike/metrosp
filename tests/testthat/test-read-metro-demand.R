# Tests for the published-data reader.
#
# No test touches the network: fetch_url() is the single network seam, and the
# round-trip tests mock it to copy from a fixture directory standing in for the
# GitHub release.

# Fixtures --------------------------------------------------------------------

# Builds a directory shaped like a release: one .rds per dataset plus the
# manifest.json the reader navigates by.
local_fake_release <- function(
  datasets = list(
    line_entries_monthly = data.frame(date = as.Date("2026-01-01"), value = 1)
  ),
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
      if (!file.exists(src)) {
        stop("404: ", url)
      }
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
    read_metro_demand("line_entries_monthly", source = "bundled"),
    metrosp::line_entries_monthly
  )
  expect_identical(
    read_metro_demand("station_entries_daily", source = "bundled"),
    metrosp::station_entries_daily
  )
})

test_that("the bundled source never reaches the network", {
  local_mocked_bindings(
    fetch_url = function(...) stop("network access attempted")
  )
  expect_s3_class(
    read_metro_demand("station_entries_monthly", source = "bundled"),
    "data.frame"
  )
})

test_that("dataset defaults to the first demand dataset", {
  expect_identical(
    read_metro_demand(source = "bundled"),
    metrosp::line_entries_monthly
  )
})

# Argument validation ---------------------------------------------------------

test_that("non-demand datasets are rejected with a pointer to the bundled ones", {
  expect_error(
    read_metro_demand("rail_lines", source = "bundled"),
    "must be one of"
  )
  expect_error(
    read_metro_demand("metro_colors", source = "bundled"),
    "must be one of"
  )
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
    asset_url("data-latest", "station_entries_daily.rds"),
    "https://github.com/someone/metrosp/releases/download/data-latest/station_entries_daily.rds"
  )
})

test_that("release manifests resolve new names before legacy names", {
  both <- list(
    datasets = list(
      line_entries_monthly = list(file = "line_entries_monthly.rds"),
      passengers_entrance = list(file = "passengers_entrance.rds")
    )
  )
  legacy <- list(
    datasets = list(
      passengers_entrance = list(file = "passengers_entrance.rds")
    )
  )

  expect_identical(
    release_dataset_entry(both, "line_entries_monthly")$file,
    "line_entries_monthly.rds"
  )
  expect_identical(
    release_dataset_entry(legacy, "line_entries_monthly")$file,
    "passengers_entrance.rds"
  )
  expect_null(release_dataset_entry(legacy, "station_entries_daily"))
})

# Remote round trip -----------------------------------------------------------

test_that("a remote read downloads the asset and returns it", {
  payload <- data.frame(date = as.Date("2026-07-01"), value = 42)
  release <- local_fake_release(list(line_entries_monthly = payload))
  cache <- local_release_source(release)

  out <- read_metro_demand(
    "line_entries_monthly",
    source = "remote",
    quiet = TRUE
  )

  expect_identical(out, payload)
  expect_true(
    file.exists(file.path(cache, "data-latest", "line_entries_monthly.rds"))
  )
})

test_that("an archived vintage reads its legacy asset", {
  payload <- data.frame(
    date = as.Date("2026-07-01"),
    line_number = 1,
    metric_abb = "total",
    value = 42,
    metric = "Total",
    metric_pt = "Total",
    line_name = "Blue",
    line_name_pt = "Azul",
    year = 2026
  )
  release <- local_fake_release(list(passengers_entrance = payload))
  cache <- local_release_source(release)

  out <- read_metro_demand(
    "line_entries_monthly",
    source = "remote",
    vintage = "2026-09",
    quiet = TRUE
  )

  expect_identical(out$value, 42)
  expect_identical(out$metric, "total")
  expect_true(
    file.exists(file.path(cache, "data-2026-09", "passengers_entrance.rds"))
  )
})

test_that("the rolling vintage reads a legacy asset when necessary", {
  payload <- data.frame(
    date = as.Date("2026-07-01"),
    line_number = 1,
    metric_abb = "total",
    value = 42,
    metric = "Total",
    metric_pt = "Total",
    line_name = "Blue",
    line_name_pt = "Azul",
    year = 2026
  )
  release <- local_fake_release(list(passengers_entrance = payload))
  cache <- local_release_source(release)

  out <- read_metro_demand(
    "line_entries_monthly",
    source = "remote",
    quiet = TRUE
  )

  expect_identical(
    names(out),
    c(
      "date",
      "year",
      "line_number",
      "line_name",
      "line_name_pt",
      "metric",
      "metric_name",
      "metric_name_pt",
      "value"
    )
  )
  expect_identical(out$metric, "total")
  expect_identical(out$metric_name, "Total")
  expect_identical(out$line_number, 1L)
  expect_true(
    file.exists(file.path(cache, "data-latest", "passengers_entrance.rds"))
  )
})

test_that("legacy station assets receive stable station ids", {
  payload <- data.frame(
    date = as.Date("2026-07-01"),
    year = 2026,
    line_number = 2,
    station_name = "Consolação",
    avg_passenger = 42,
    line_name = "Green",
    line_name_pt = "Verde"
  )
  release <- local_fake_release(list(station_averages = payload))
  local_release_source(release)

  out <- read_metro_demand(
    "station_entries_monthly",
    source = "remote",
    quiet = TRUE
  )

  expect_identical(out$station_id, "consolacao-paulista")
  expect_identical(out$metric, "mdu")
  expect_identical(out$value, 42)
})

test_that("a warm cache serves the asset without downloading again", {
  release <- local_fake_release()
  local_release_source(release)

  read_metro_demand("line_entries_monthly", source = "remote", quiet = TRUE)

  # Removing the fixture makes any further fetch fail, so a successful read
  # proves nothing was downloaded.
  unlink(release, recursive = TRUE)
  expect_s3_class(
    read_metro_demand("line_entries_monthly", source = "cache"),
    "data.frame"
  )
})

test_that("cache = FALSE keeps the persistent cache empty", {
  release <- local_fake_release()
  cache <- local_release_source(release)

  read_metro_demand(
    "line_entries_monthly",
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
    read_metro_demand("station_entries_daily", source = "remote", quiet = TRUE),
    "does not contain"
  )
})

# Integrity -------------------------------------------------------------------

test_that("a checksum mismatch errors and discards the download", {
  skip_if_not_installed("digest")

  release <- local_fake_release(corrupt = "line_entries_monthly")
  cache <- local_release_source(release)

  expect_error(
    read_metro_demand("line_entries_monthly", source = "remote", quiet = TRUE),
    "Checksum mismatch"
  )
  expect_false(
    file.exists(file.path(cache, "data-latest", "line_entries_monthly.rds"))
  )
})

test_that("a corrupted cached asset is re-downloaded", {
  skip_if_not_installed("digest")

  payload <- data.frame(date = as.Date("2026-07-01"), value = 42)
  release <- local_fake_release(list(line_entries_monthly = payload))
  cache <- local_release_source(release)

  read_metro_demand("line_entries_monthly", source = "remote", quiet = TRUE)

  cached <- file.path(cache, "data-latest", "line_entries_monthly.rds")
  saveRDS(data.frame(tampered = TRUE), cached)

  expect_identical(
    read_metro_demand("line_entries_monthly", source = "auto", quiet = TRUE),
    payload
  )
})

# Source resolution -----------------------------------------------------------

test_that("the cache source errors instead of downloading", {
  release <- local_fake_release()
  local_release_source(release)

  expect_error(
    read_metro_demand("line_entries_monthly", source = "cache"),
    "No cached manifest"
  )
})

test_that("auto falls back to the bundled snapshot when the release is unreachable", {
  withr::local_options(metrosp.cache_dir = withr::local_tempdir())
  local_mocked_bindings(
    fetch_url = function(...) stop("no network")
  )

  expect_warning(
    out <- read_metro_demand("line_entries_monthly", source = "auto"),
    "using the bundled snapshot"
  )
  expect_identical(out, metrosp::line_entries_monthly)
})

test_that("remote propagates the failure instead of falling back", {
  withr::local_options(metrosp.cache_dir = withr::local_tempdir())
  local_mocked_bindings(
    fetch_url = function(...) stop("no network")
  )

  expect_error(
    read_metro_demand("line_entries_monthly", source = "remote"),
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

  read_metro_demand("line_entries_monthly", source = "auto", quiet = TRUE)
  unlink(file.path(release, "manifest.json"))

  expect_s3_class(
    read_metro_demand("line_entries_monthly", source = "auto", quiet = TRUE),
    "data.frame"
  )
})

test_that("a stale manifest that cannot be refreshed falls back to the cached copy", {
  release <- local_fake_release()
  local_release_source(release)

  read_metro_demand("line_entries_monthly", source = "auto", quiet = TRUE)

  withr::local_options(metrosp.cache_ttl = -1)
  unlink(file.path(release, "manifest.json"))

  expect_warning(
    out <- read_metro_demand(
      "line_entries_monthly",
      source = "auto",
      quiet = TRUE
    ),
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

test_that("a legacy asset drops the line 99 system rows", {
  payload <- data.frame(
    date = rep(as.Date("2026-07-01"), 3),
    line_number = c(1, 2, 99),
    metric_abb = "total",
    value = c(10, 20, 30),
    metric = "Total",
    metric_pt = "Total",
    line_name = c("Blue", "Green", "System"),
    line_name_pt = c("Azul", "Verde", "Sistema"),
    year = 2026
  )
  release <- local_fake_release(list(passengers_entrance = payload))
  local_release_source(release)

  out <- read_metro_demand(
    "line_entries_monthly",
    source = "remote",
    quiet = TRUE
  )

  expect_false(99L %in% out$line_number)
  expect_identical(nrow(out), 2L)
  # The whole point: the documented "sum the lines" recipe must not double.
  expect_identical(sum(out$value), 30)
})

test_that("a malformed vintage errors instead of falling back to bundled", {
  expect_error(
    read_metro_demand("line_entries_monthly", vintage = "2026"),
    "Unrecognised"
  )
  expect_error(
    read_metro_demand("line_entries_monthly", vintage = "latest-ish"),
    "Unrecognised"
  )
})

test_that("a failed download still falls back to the bundled snapshot", {
  release <- local_fake_release(list())
  local_release_source(release)

  expect_warning(
    out <- read_metro_demand("line_entries_monthly", quiet = TRUE),
    "using the bundled snapshot"
  )
  expect_identical(out, metrosp::line_entries_monthly)
})
