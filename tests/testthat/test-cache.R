# Tests for cache location and consent.
#
# CRAN forbids writing to a user's home filesystem without consent, so the key
# assertion is that the persistent directory is never chosen by default.

test_that("the option wins over every other source", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)
  withr::local_envvar(METROSP_CACHE_DIR = "/should/be/ignored")

  expect_identical(metrosp_cache_dir(), dir)
})

test_that("the environment variable applies when no option is set", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = NULL)
  withr::local_envvar(METROSP_CACHE_DIR = dir)

  expect_identical(metrosp_cache_dir(), dir)
})

test_that("without consent the cache stays inside the session temp directory", {
  withr::local_options(metrosp.cache_dir = NULL, metrosp.cache = FALSE)
  withr::local_envvar(METROSP_CACHE_DIR = "", METROSP_CACHE = "")
  local_mocked_bindings(cache_consented = function() FALSE)

  expect_identical(metrosp_cache_dir(), file.path(tempdir(), "metrosp-cache"))
  expect_false(
    startsWith(metrosp_cache_dir(), tools::R_user_dir("metrosp", "cache"))
  )
})

test_that("consent moves the cache to the persistent user directory", {
  withr::local_options(metrosp.cache_dir = NULL)
  withr::local_envvar(METROSP_CACHE_DIR = "", METROSP_CACHE = "")
  local_mocked_bindings(cache_consented = function() TRUE)

  expect_identical(
    metrosp_cache_dir(),
    tools::R_user_dir("metrosp", "cache")
  )
})

test_that("consent reads the option and the environment variable", {
  withr::local_envvar(METROSP_CACHE = "")
  the$consent <- NULL
  withr::defer(the$consent <- NULL)

  withr::with_options(list(metrosp.cache = TRUE), expect_true(cache_consented()))
  withr::with_options(list(metrosp.cache = FALSE), expect_false(cache_consented()))

  withr::with_options(
    list(metrosp.cache = NULL),
    withr::with_envvar(
      c(METROSP_CACHE = "true"),
      expect_true(cache_consented())
    )
  )
})

test_that("create = TRUE makes the directory", {
  parent <- withr::local_tempdir()
  dir <- file.path(parent, "nested", "cache")
  withr::local_options(metrosp.cache_dir = dir)

  expect_false(dir.exists(dir))
  metrosp_cache_dir(create = TRUE)
  expect_true(dir.exists(dir))
})

test_that("listing an empty or absent cache returns zero rows", {
  withr::local_options(metrosp.cache_dir = file.path(tempdir(), "does-not-exist"))
  expect_identical(nrow(metrosp_cache_list()), 0L)

  withr::local_options(metrosp.cache_dir = withr::local_tempdir())
  expect_identical(nrow(metrosp_cache_list()), 0L)
})

test_that("listing reports one row per cached file, tagged by vintage", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)

  dir.create(file.path(dir, "data-latest"))
  saveRDS(1:10, file.path(dir, "data-latest", "station_daily.rds"))
  file.create(file.path(dir, "data-latest", "manifest.json"))

  cached <- metrosp_cache_list()
  expect_identical(nrow(cached), 2L)
  expect_identical(unique(cached$vintage), "data-latest")
  expect_true("station_daily.rds" %in% cached$file)
  expect_true(all(cached$bytes >= 0))
})

test_that("clearing removes one vintage or the whole cache", {
  dir <- withr::local_tempdir()
  withr::local_options(metrosp.cache_dir = dir)

  for (tag in c("data-latest", "data-2026-08")) {
    dir.create(file.path(dir, tag))
    saveRDS(1, file.path(dir, tag, "passengers_entrance.rds"))
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

test_that("consent is never solicited non-interactively", {
  withr::local_options(metrosp.cache_dir = NULL, metrosp.cache = NULL)
  withr::local_envvar(METROSP_CACHE_DIR = "", METROSP_CACHE = "")
  the$consent <- NULL
  the$asked <- NULL
  withr::defer({
    the$consent <- NULL
    the$asked <- NULL
  })

  local_mocked_bindings(
    cache_consented = function() FALSE,
    .package = "metrosp"
  )
  local_mocked_bindings(
    askYesNo = function(...) stop("prompted in a non-interactive session"),
    .package = "utils"
  )

  expect_silent(ask_cache_consent())
})
