# Tests for cache location, listing, printing, and clearing.

test_that("the option wins over the environment variable", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)
  withr::local_envvar(METROSP_CACHE_DIR = "/should/be/ignored")

  expect_identical(cache_dir(), dir)
})

test_that("the environment variable applies when no option is set", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = NULL)
  withr::local_envvar(METROSP_CACHE_DIR = dir)

  expect_identical(cache_dir(), dir)
})

test_that("the user cache directory is the default", {
  withr::local_options(metrosp.cache_dir = NULL)
  withr::local_envvar(METROSP_CACHE_DIR = "")

  expect_identical(cache_dir(), tools::R_user_dir("metrosp", "cache"))
})

test_that("create = TRUE makes the directory", {
  parent <- withr::local_tempdir()
  dir <- file.path(parent, "nested", "cache")
  withr::local_options(metrosp.cache_dir = dir)

  expect_false(dir.exists(dir))
  cache_dir(create = TRUE)
  expect_true(dir.exists(dir))
})

test_that("an empty or absent cache returns a typed zero-row listing", {
  dir <- file.path(withr::local_tempdir(), "does-not-exist")
  withr::local_options(metrosp.cache_dir = dir)

  cached <- metrosp_cache()

  expect_s3_class(cached, "metrosp_cache")
  expect_s3_class(cached, "data.frame")
  expect_named(cached, c("vintage", "file", "bytes", "modified"))
  expect_identical(nrow(cached), 0L)
  expect_identical(attr(cached, "directory"), dir)
})

test_that("the cache listing reports one row per file and its directory", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)

  dir.create(file.path(dir, "data-latest"))
  saveRDS(1:10, file.path(dir, "data-latest", "station_entries_daily.rds"))
  file.create(file.path(dir, "data-latest", "manifest.json"))

  cached <- metrosp_cache()

  expect_identical(nrow(cached), 2L)
  expect_identical(unique(cached$vintage), "data-latest")
  expect_true("station_entries_daily.rds" %in% cached$file)
  expect_true(all(cached$bytes >= 0))
  expect_identical(attr(cached, "directory"), dir)
})

test_that("printing a cache listing shows its directory and contents", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)

  cached <- metrosp_cache()
  capture.output(
    output <- capture.output(print(cached), type = "message")
  )

  expect_true(any(grepl("Cache directory", output, fixed = TRUE)))
  expect_true(any(grepl(dir, output, fixed = TRUE)))
})

test_that("clearing removes one vintage or the whole cache", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)

  for (tag in c("data-latest", "data-2026-08")) {
    dir.create(file.path(dir, tag))
    saveRDS(1, file.path(dir, tag, "line_entries_monthly.rds"))
  }

  expect_message(metrosp_cache_clear("2026-08"), "Removed")
  expect_false(dir.exists(file.path(dir, "data-2026-08")))
  expect_true(dir.exists(file.path(dir, "data-latest")))

  expect_message(metrosp_cache_clear(), "Removed")
  expect_false(dir.exists(dir))
})

test_that("clearing an uncached vintage is not an error", {
  withr::local_options(metrosp.cache_dir = withr::local_tempdir())

  expect_message(n <- metrosp_cache_clear("2019-01"), "Nothing cached")
  expect_identical(n, 0L)
})

test_that("cache = FALSE uses session-temporary storage", {
  withr::local_options(metrosp.cache_dir = "/should/be/ignored")

  path <- vintage_dir("data-latest", cache = FALSE)

  expect_identical(path, file.path(tempdir(), "metrosp-nocache", "data-latest"))
})
