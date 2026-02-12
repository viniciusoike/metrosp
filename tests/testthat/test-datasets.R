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
