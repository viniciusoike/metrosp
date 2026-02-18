test_that("all datasets load as data frames", {
  expect_s3_class(metrosp::passengers_entrance, "data.frame")
  expect_s3_class(metrosp::passengers_transported, "data.frame")
  expect_s3_class(metrosp::station_averages, "data.frame")
  expect_s3_class(metrosp::station_daily, "data.frame")
  expect_s3_class(metrosp::metro_lines, "data.frame")
})

test_that("passengers_entrance has expected columns", {
  cols <- names(metrosp::passengers_entrance)
  expect_true("date" %in% cols)
  expect_true("year" %in% cols)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
  expect_true("metric" %in% cols)
  expect_true("metric_abb" %in% cols)
  expect_true("value" %in% cols)
})

test_that("passengers_transported has expected columns", {
  cols <- names(metrosp::passengers_transported)
  expect_true("date" %in% cols)
  expect_true("value" %in% cols)
  expect_true("line_number" %in% cols)
})

test_that("station_averages has expected columns", {
  cols <- names(metrosp::station_averages)
  expect_true("date" %in% cols)
  expect_true("station_name" %in% cols)
  expect_true("avg_passenger" %in% cols)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
})

test_that("metro_lines reference table is complete", {
  expect_equal(nrow(metrosp::metro_lines), 13)
  expect_true(1L %in% metrosp::metro_lines$line_number)
  expect_true(15L %in% metrosp::metro_lines$line_number)
  expect_true(99L %in% metrosp::metro_lines$line_number)
})

test_that("no NA dates in key datasets", {
  expect_false(any(is.na(metrosp::passengers_entrance$date)))
  expect_false(any(is.na(metrosp::passengers_transported$date)))
  expect_false(any(is.na(metrosp::station_averages$date)))
})

test_that("datasets have rows", {
  expect_gt(nrow(metrosp::passengers_entrance), 0)
  expect_gt(nrow(metrosp::passengers_transported), 0)
  expect_gt(nrow(metrosp::station_averages), 0)
})

test_that("line numbers are valid", {
  valid <- metrosp::metro_lines$line_number
  expect_true(all(metrosp::passengers_entrance$line_number %in% valid))
  expect_true(all(metrosp::passengers_transported$line_number %in% valid))
  expect_true(all(metrosp::station_averages$line_number %in% valid))
})

test_that("date range starts in October 2017", {
  expect_equal(
    min(metrosp::passengers_entrance$date),
    as.Date("2017-10-01")
  )
  expect_equal(
    min(metrosp::passengers_transported$date),
    as.Date("2017-10-01")
  )
  expect_equal(
    min(metrosp::station_averages$date),
    as.Date("2017-10-01")
  )
})

test_that("column types are correct", {
  pe <- metrosp::passengers_entrance
  expect_s3_class(pe$date, "Date")
  expect_true(is.numeric(pe$year))
  expect_true(is.numeric(pe$line_number))
  expect_type(pe$value, "double")
  expect_type(pe$metric_abb, "character")

  sa <- metrosp::station_averages
  expect_s3_class(sa$date, "Date")
  expect_true(is.numeric(sa$line_number))
  expect_type(sa$avg_passenger, "double")
})

test_that("metric values are non-negative", {
  expect_true(all(metrosp::passengers_entrance$value >= 0, na.rm = TRUE))
  expect_true(all(metrosp::passengers_transported$value >= 0, na.rm = TRUE))
  expect_true(all(metrosp::station_averages$avg_passenger >= 0, na.rm = TRUE))
})

test_that("no duplicate date/line/metric combinations in passengers", {
  pe <- metrosp::passengers_entrance
  dupes_pe <- sum(duplicated(pe[, c("date", "line_number", "metric_abb")]))
  expect_equal(dupes_pe, 0)

  pt <- metrosp::passengers_transported
  dupes_pt <- sum(duplicated(pt[, c("date", "line_number", "metric_abb")]))
  expect_equal(dupes_pt, 0)
})

test_that("station names have no trailing whitespace", {
  sn <- metrosp::station_averages$station_name
  expect_equal(sn, trimws(sn))
})

test_that("station_daily has expected columns", {
  cols <- names(metrosp::station_daily)
  expect_true("date" %in% cols)
  expect_true("year" %in% cols)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
  expect_true("station_code" %in% cols)
  expect_true("station_name" %in% cols)
  expect_true("passengers" %in% cols)
})

test_that("station_daily has correct column types", {
  sd <- metrosp::station_daily
  expect_s3_class(sd$date, "Date")
  expect_true(is.numeric(sd$year))
  expect_true(is.numeric(sd$line_number))
  expect_type(sd$station_code, "character")
  expect_type(sd$station_name, "character")
  expect_type(sd$passengers, "double")
})

test_that("station_daily has no NA values in key columns", {
  sd <- metrosp::station_daily
  expect_false(any(is.na(sd$date)))
  expect_false(any(is.na(sd$station_name)))
  expect_false(any(is.na(sd$station_code)))
  expect_false(any(is.na(sd$passengers)))
})

test_that("station_daily has valid line numbers", {
  expect_true(all(metrosp::station_daily$line_number %in% c(1L, 2L, 3L, 15L)))
})

test_that("station_daily date range is 2020-2025", {
  sd <- metrosp::station_daily
  expect_gte(min(sd$date), as.Date("2020-01-01"))
  expect_lte(max(sd$date), as.Date("2025-12-31"))
})

test_that("station_daily has non-negative passengers", {
  expect_true(all(metrosp::station_daily$passengers >= 0))
})

test_that("station_daily has no duplicate date/line/station", {
  sd <- metrosp::station_daily
  dupes <- sum(duplicated(sd[, c("date", "line_number", "station_code")]))
  expect_equal(dupes, 0)
})

test_that("station_daily has correct station count per line", {
  sd <- metrosp::station_daily
  station_counts <- tapply(sd$station_code, sd$line_number, function(x) length(unique(x)))
  expect_equal(unname(station_counts["1"]), 23)
  expect_equal(unname(station_counts["2"]), 14)
  expect_equal(unname(station_counts["3"]), 18)
  expect_equal(unname(station_counts["15"]), 11)
})

test_that("station_daily has > 100k rows", {
  expect_gt(nrow(metrosp::station_daily), 100000)
})

test_that("Line 5 only appears in pre-2020 data", {
  pe_line5 <- metrosp::passengers_entrance[
    metrosp::passengers_entrance$line_number == 5L,
  ]
  if (nrow(pe_line5) > 0) {
    expect_true(all(pe_line5$year < 2020))
  }

  sa_line5 <- metrosp::station_averages[
    metrosp::station_averages$line_number == 5L,
  ]
  if (nrow(sa_line5) > 0) {
    expect_true(all(sa_line5$year < 2020))
  }
})
