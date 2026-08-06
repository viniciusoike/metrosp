# Structural invariants for the shipped (frozen) datasets.
#
# The assertions live in helper-checks.R so the scheduled pipeline can run the
# identical checks against freshly rebuilt data before publishing it. Here they
# guard the snapshot in data/*.rda; see data-raw/R/validate_refresh.R for the
# other caller.

test_that("all datasets load as data frames", {
  expect_s3_class(metrosp::passengers_entrance, "data.frame")
  expect_s3_class(metrosp::passengers_transported, "data.frame")
  expect_s3_class(metrosp::station_averages, "data.frame")
  expect_s3_class(metrosp::station_daily, "data.frame")
})

test_that("passengers_entrance satisfies its structural invariants", {
  expect_equal(check_passengers_entrance(metrosp::passengers_entrance), character(0))
})

test_that("passengers_transported satisfies its structural invariants", {
  expect_equal(
    check_passengers_transported(metrosp::passengers_transported),
    character(0)
  )
})

test_that("station_averages satisfies its structural invariants", {
  expect_equal(check_station_averages(metrosp::station_averages), character(0))
})

test_that("station_daily satisfies its structural invariants", {
  expect_equal(check_station_daily(metrosp::station_daily), character(0))
})

test_that("station_inauguration station names carry no footnote markers", {
  # Not covered by check_station_names(): this table is hand-maintained and
  # holds only the stations that have an inauguration record, so the
  # sponsor/canonical-name assertions do not apply.
  expect_false(
    any(grepl("[0-9¹²³*]$|\\(", metrosp::station_inauguration$station_name))
  )
})

test_that("station_averages names all resolve to a current metro geometry", {
  geo <- sf::st_drop_geometry(metrosp::stations)
  geo_current_metro <- geo[geo$status == "current" & geo$type == "metro", ]
  unmatched <- setdiff(
    unique(metrosp::station_averages$station_name),
    unique(geo_current_metro$station_name)
  )
  expect_equal(unmatched, character(0))
})
