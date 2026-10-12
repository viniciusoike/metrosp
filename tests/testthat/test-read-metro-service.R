# Tests for read_metro_service(). It shares the release client with
# read_metro_demand(), so these cover only what differs: the dataset it reads
# and how it fails on a vintage published before the dataset existed.

test_that("the bundled source returns the frozen snapshot unchanged", {
  expect_identical(
    read_metro_service(source = "bundled"),
    metrosp::line_service_monthly
  )
})

test_that("a remote read downloads the service asset", {
  payload <- data.frame(date = as.Date("2026-08-01"), value = 131)
  release <- local_fake_release(list(line_service_monthly = payload))
  local_release_source(release)

  expect_identical(
    read_metro_service(source = "remote", quiet = TRUE),
    payload
  )
})

test_that("a vintage without service data is reported by name", {
  release <- local_fake_release()
  local_release_source(release)

  expect_error(
    read_metro_service(source = "remote", vintage = "2026-09", quiet = TRUE),
    "does not contain"
  )
})

test_that("auto reports a vintage without service data instead of falling back", {
  release <- local_fake_release()
  local_release_source(release)

  expect_error(
    read_metro_service(vintage = "2026-09", quiet = TRUE),
    "does not contain"
  )
})

test_that("auto falls back to the bundled snapshot when the release is unreachable", {
  local_release_source(withr::local_tempdir())

  expect_warning(
    out <- read_metro_service(quiet = TRUE),
    "bundled snapshot"
  )
  expect_identical(out, metrosp::line_service_monthly)
})

test_that("the demand reader does not serve the service dataset", {
  expect_error(
    read_metro_demand("line_service_monthly", source = "bundled"),
    "must be one of"
  )
})
