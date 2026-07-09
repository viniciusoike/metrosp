test_that("lines and stations load as sf objects", {
  expect_s3_class(metrosp::lines, "sf")
  expect_s3_class(metrosp::stations, "sf")
})

test_that("lines has expected columns", {
  cols <- names(metrosp::lines)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
  expect_true("company_name" %in% cols)
  expect_true("type" %in% cols)
  expect_true("status" %in% cols)
  expect_false(is.null(sf::st_geometry(metrosp::lines)))
})

test_that("stations has expected columns", {
  cols <- names(metrosp::stations)
  expect_true("station_name" %in% cols)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
  expect_true("company_name" %in% cols)
  expect_true("type" %in% cols)
  expect_true("status" %in% cols)
  expect_false(is.null(sf::st_geometry(metrosp::stations)))
})

test_that("lines type and status values are valid", {
  expect_true(all(metrosp::lines$type %in% c("metro", "train")))
  expect_true(all(metrosp::lines$status %in% c("current", "future")))
})

test_that("stations type and status values are valid", {
  expect_true(all(metrosp::stations$type %in% c("metro", "train")))
  expect_true(all(metrosp::stations$status %in% c("current", "future")))
})

test_that("lines CRS is EPSG:4326", {
  expect_equal(sf::st_crs(metrosp::lines)$epsg, 4326)
})

test_that("stations CRS is EPSG:4326", {
  expect_equal(sf::st_crs(metrosp::stations)$epsg, 4326)
})

test_that("lines geometry type is LINESTRING or MULTILINESTRING", {
  geom_types <- unique(sf::st_geometry_type(metrosp::lines))
  expect_true(all(geom_types %in% c("LINESTRING", "MULTILINESTRING")))
})

test_that("stations geometry type is POINT", {
  geom_types <- unique(sf::st_geometry_type(metrosp::stations))
  expect_true(all(geom_types %in% c("POINT", "MULTIPOINT")))
})

test_that("both networks are represented in lines", {
  types <- metrosp::lines$type
  expect_true("metro" %in% types)
  expect_true("train" %in% types)
})

test_that("both networks are represented in stations", {
  types <- metrosp::stations$type
  expect_true("metro" %in% types)
  expect_true("train" %in% types)
})

test_that("current metro lines include known line numbers", {
  current_metro <- metrosp::lines[
    metrosp::lines$type == "metro" & metrosp::lines$status == "current",
  ]
  nums <- current_metro$line_number
  expect_true(1L %in% nums)
  expect_true(2L %in% nums)
  expect_true(3L %in% nums)
  expect_true(15L %in% nums)
})

test_that("current train lines include known CPTM line numbers", {
  current_train <- metrosp::lines[
    metrosp::lines$type == "train" & metrosp::lines$status == "current",
  ]
  nums <- current_train$line_number
  expect_true(any(nums %in% c(7L, 8L, 9L, 10L, 11L, 12L)))
})

test_that("lines and stations have rows", {
  expect_gt(nrow(metrosp::lines), 0)
  expect_gt(nrow(metrosp::stations), 0)
})

test_that("no NA line numbers in lines", {
  expect_false(any(is.na(metrosp::lines$line_number)))
})

test_that("no NA station names in stations", {
  expect_false(any(is.na(metrosp::stations$station_name)))
})

test_that("stations has no duplicate rows", {
  dat <- sf::st_drop_geometry(metrosp::stations)
  expect_false(any(duplicated(dat)))
})
