test_that("all datasets load as data frames", {
  expect_s3_class(metrosp::passengers_entrance, "data.frame")
  expect_s3_class(metrosp::passengers_transported, "data.frame")
  expect_s3_class(metrosp::station_averages, "data.frame")
  expect_s3_class(metrosp::station_daily, "data.frame")
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

test_that("no NA dates in key datasets", {
  expect_false(any(is.na(metrosp::passengers_entrance$date)))
  expect_false(any(is.na(metrosp::passengers_transported$date)))
  expect_false(any(is.na(metrosp::station_averages$date)))
})

test_that("datasets have rows", {
  expect_gt(nrow(metrosp::passengers_entrance), 0)
  expect_gt(nrow(metrosp::passengers_transported), 0)
  expect_gt(nrow(metrosp::station_averages), 0)
  expect_gt(nrow(metrosp::station_daily), 0)
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
  # Lines 4 and 5 (Dataverse source) have no station codes — NA is expected
  sd_non_dataverse <- sd[!sd$line_number %in% c(4L, 5L), ]
  expect_false(any(is.na(sd_non_dataverse$station_code)))
  expect_false(any(is.na(sd$passengers)))
})

test_that("station_daily has non-negative passengers", {
  expect_true(all(metrosp::station_daily$passengers >= 0))
})

test_that("station names carry no source footnote markers", {
  # Digits/superscripts/asterisks glued by the source spreadsheets, e.g.
  # "Sé4", "Brooklin7", "Luz (3)"
  pat <- "[0-9¹²³*]$|\\("
  expect_false(any(grepl(pat, metrosp::station_averages$station_name)))
  expect_false(any(grepl(pat, metrosp::station_daily$station_name)))
  expect_false(any(grepl(pat, metrosp::station_inauguration$station_name)))
})

test_that("station_averages has no duplicate date/line/station", {
  sa <- metrosp::station_averages
  dupes <- sum(duplicated(sa[, c("date", "line_number", "station_name")]))
  expect_equal(dupes, 0)
})

test_that("station_daily has no duplicate date/line/station", {
  sd <- metrosp::station_daily
  dupes <- sum(duplicated(sd[, c("date", "line_number", "station_name")]))
  expect_equal(dupes, 0)
})

test_that("station_daily has > 100k rows", {
  expect_gt(nrow(metrosp::station_daily), 100000)
})
