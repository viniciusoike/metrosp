test_that("spatial datasets load as sf objects", {
  skip_if_not_installed("sf")
  expect_s3_class(metrosp::metro_lines_geo, "sf")
  expect_s3_class(metrosp::metro_stations_geo, "sf")
  expect_s3_class(metrosp::train_lines_geo, "sf")
  expect_s3_class(metrosp::train_stations_geo, "sf")
})

test_that("train_lines reference table loads", {
  expect_s3_class(metrosp::train_lines, "data.frame")
  expect_equal(nrow(metrosp::train_lines), 8)
  expect_true(all(c("line_number", "line_name_pt", "line_name") %in% names(metrosp::train_lines)))
})

test_that("spatial datasets have expected columns", {
  skip_if_not_installed("sf")
  line_cols <- c("line_number", "line_name_pt", "line_name", "company", "status")
  station_cols <- c("station_name", "line_number", "line_name_pt", "line_name", "company", "status")

  expect_true(all(line_cols %in% names(metrosp::metro_lines_geo)))
  expect_true(all(line_cols %in% names(metrosp::train_lines_geo)))
  expect_true(all(station_cols %in% names(metrosp::metro_stations_geo)))
  expect_true(all(station_cols %in% names(metrosp::train_stations_geo)))
})

test_that("CRS is WGS84 (EPSG:4326)", {
  skip_if_not_installed("sf")
  expect_equal(sf::st_crs(metrosp::metro_lines_geo)$epsg, 4326L)
  expect_equal(sf::st_crs(metrosp::metro_stations_geo)$epsg, 4326L)
  expect_equal(sf::st_crs(metrosp::train_lines_geo)$epsg, 4326L)
  expect_equal(sf::st_crs(metrosp::train_stations_geo)$epsg, 4326L)
})

test_that("status column has valid values", {
  skip_if_not_installed("sf")
  valid_status <- c("current", "planned")
  expect_true(all(metrosp::metro_lines_geo$status %in% valid_status))
  expect_true(all(metrosp::metro_stations_geo$status %in% valid_status))
  expect_true(all(metrosp::train_lines_geo$status %in% valid_status))
  expect_true(all(metrosp::train_stations_geo$status %in% valid_status))
})

test_that("datasets have both current and planned rows", {
  skip_if_not_installed("sf")
  expect_true("current" %in% metrosp::metro_lines_geo$status)
  expect_true("planned" %in% metrosp::metro_lines_geo$status)
  expect_true("current" %in% metrosp::metro_stations_geo$status)
  expect_true("planned" %in% metrosp::metro_stations_geo$status)
})

test_that("current metro lines has 6 unique lines", {
  skip_if_not_installed("sf")
  current <- metrosp::metro_lines_geo[metrosp::metro_lines_geo$status == "current", ]
  expect_equal(length(unique(current$line_number)), 6)
})

test_that("current train lines has 7 unique lines", {
  skip_if_not_installed("sf")
  current <- metrosp::train_lines_geo[metrosp::train_lines_geo$status == "current", ]
  expect_equal(length(unique(current$line_number)), 7)
})

test_that("no empty station names", {
  skip_if_not_installed("sf")
  expect_false(any(is.na(metrosp::metro_stations_geo$station_name)))
  expect_false(any(metrosp::metro_stations_geo$station_name == ""))
  expect_false(any(is.na(metrosp::train_stations_geo$station_name)))
  expect_false(any(metrosp::train_stations_geo$station_name == ""))
})
