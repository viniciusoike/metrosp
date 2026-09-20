# Structural invariants for the shipped (frozen) datasets.
#
# The assertions live in helper-checks.R so the scheduled pipeline can run the
# identical checks against freshly rebuilt data before publishing it. Here they
# guard the snapshot in data/*.rda; see data-raw/R/publish/validate_refresh.R for the
# other caller.

test_that("all datasets load as data frames", {
  expect_s3_class(metrosp::line_entries_monthly, "data.frame")
  expect_s3_class(metrosp::line_transported_monthly, "data.frame")
  expect_s3_class(metrosp::station_entries_monthly, "data.frame")
  expect_s3_class(metrosp::station_entries_daily, "data.frame")
})

test_that("line_entries_monthly satisfies its structural invariants", {
  expect_equal(
    check_line_entries_monthly(metrosp::line_entries_monthly),
    character(0)
  )
})

test_that("line_transported_monthly satisfies its structural invariants", {
  expect_equal(
    check_line_transported_monthly(metrosp::line_transported_monthly),
    character(0)
  )
})

test_that("demand checks enforce the 2.0 metric and type contract", {
  bad_metric <- metrosp::line_entries_monthly
  bad_metric$metric[[1]] <- "weekday_average"
  expect_match(
    check_line_entries_monthly(bad_metric)[[1]],
    "unexpected value"
  )

  bad_type <- metrosp::line_transported_monthly
  bad_type$year <- as.double(bad_type$year)
  expect_match(
    check_line_transported_monthly(bad_type)[[1]],
    "unexpected type"
  )

  missing_year <- metrosp::station_entries_monthly |>
    dplyr::select(-year)
  expect_match(
    check_station_entries_monthly(missing_year)[[1]],
    "missing column"
  )
})

test_that("station_entries_monthly satisfies its structural invariants", {
  expect_equal(
    check_station_entries_monthly(metrosp::station_entries_monthly),
    character(0)
  )
})

test_that("station_entries_daily satisfies its structural invariants", {
  expect_equal(
    check_station_entries_daily(metrosp::station_entries_daily),
    character(0)
  )
})

test_that("station identities are stable across demand grains", {
  monthly <- metrosp::station_entries_monthly |>
    dplyr::distinct(station_id, station_name)
  daily <- metrosp::station_entries_daily |>
    dplyr::distinct(station_id, station_name)

  expect_length(intersect(monthly$station_id, daily$station_id), 86L)
  expect_identical(
    unique(metrosp::station_entries_monthly$station_id[
      metrosp::station_entries_monthly$station_name == "República"
    ]),
    unique(metrosp::station_entries_daily$station_id[
      metrosp::station_entries_daily$station_name == "República"
    ])
  )
  expect_equal(
    unique(metrosp::station_entries_daily$line_number[
      metrosp::station_entries_daily$station_name == "República"
    ]),
    3L
  )
})

test_that("station_entries_monthly names all resolve to a current metro geometry", {
  geo <- sf::st_drop_geometry(metrosp::rail_stations)
  geo_current_metro <- geo[geo$status == "current" & geo$type == "metro", ]
  unmatched <- setdiff(
    unique(metrosp::station_entries_monthly$station_name),
    unique(geo_current_metro$station_name)
  )
  expect_equal(unmatched, character(0))
})
