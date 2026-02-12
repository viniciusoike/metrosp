test_that("all datasets load as data frames", {
  expect_s3_class(metrosp::passengers_entrance, "data.frame")
  expect_s3_class(metrosp::passengers_transported, "data.frame")
  expect_s3_class(metrosp::station_averages, "data.frame")
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
