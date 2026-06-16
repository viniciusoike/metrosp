# Unit tests for the shared dashboard helpers (dashboard/shared.R).
# That file is .Rbuildignored, so it is absent from the built/checked tarball:
# these tests run from the source tree (devtools::test()) and skip otherwise.

source_dashboard_helpers <- function() {
  skip_if_not_installed("bslib")
  skip_if_not_installed("htmlwidgets")
  skip_if_not_installed("withr")
  path <- test_path("..", "..", "dashboard", "shared.R")
  skip_if_not(
    file.exists(path),
    "dashboard/shared.R not available (build-ignored)"
  )
  # shared.R calls bs_theme()/font_google() unqualified at source time.
  # suppressWarnings() mutes the harmless "built under R version" load note.
  suppressWarnings(withr::local_package("bslib"))
  env <- new.env(parent = environment())
  sys.source(path, envir = env)
  env
}

# The helpers return an em dash (U+2014) for missing values; compare the raw
# bytes so a latin1/UTF-8/unknown encoding-marking mismatch is not a failure.
expect_emdash <- function(x) {
  expect_equal(charToRaw(x), charToRaw("—"))
}

test_that("roll_mean returns all-NA when fewer than k observations (no crash)", {
  env <- source_dashboard_helpers()
  # Regression: seq(7, 3) counts *down*, which previously grew the output
  # vector past length(x) and crashed the daily chart's mutate().
  expect_equal(env$roll_mean(c(1, 2, 3), k = 7), rep(NA_real_, 3))
  expect_length(env$roll_mean(numeric(0), k = 7), 0)
  expect_equal(env$roll_mean(5, k = 7), NA_real_)
})

test_that("roll_mean computes a trailing mean of length n", {
  env <- source_dashboard_helpers()
  x <- 1:10
  out <- env$roll_mean(x, k = 3)
  expect_length(out, length(x))
  expect_true(all(is.na(out[1:2])))
  expect_equal(out[3], mean(1:3))
  expect_equal(out[10], mean(8:10))
})

test_that("roll_mean is NA-tolerant within a window", {
  env <- source_dashboard_helpers()
  out <- env$roll_mean(c(NA, 2, 4), k = 3)
  expect_equal(out[3], mean(c(2, 4)))
})

test_that("fmt_n formats magnitudes and missing values", {
  env <- source_dashboard_helpers()
  expect_emdash(env$fmt_n(NA_real_))
  expect_emdash(env$fmt_n(numeric(0)))
  expect_equal(env$fmt_n(1500), "1.5 K")
  expect_equal(env$fmt_n(2.5e6), "2.5 M")
})

test_that("fmt_pct signs and formats percentages", {
  env <- source_dashboard_helpers()
  expect_emdash(env$fmt_pct(NA_real_))
  expect_equal(env$fmt_pct(3.21), "+3.2%")
  expect_equal(env$fmt_pct(-3.21), "-3.2%")
  expect_equal(env$fmt_pct(3.21, signed = FALSE), "3.2%")
})
