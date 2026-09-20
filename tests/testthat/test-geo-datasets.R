test_that("rail_lines and rail_stations load as sf objects", {
  expect_s3_class(metrosp::rail_lines, "sf")
  expect_s3_class(metrosp::rail_stations, "sf")
})

test_that("rail_lines has expected columns", {
  cols <- names(metrosp::rail_lines)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
  expect_true("company_name" %in% cols)
  expect_true("type" %in% cols)
  expect_true("status" %in% cols)
  expect_false(is.null(sf::st_geometry(metrosp::rail_lines)))
})

test_that("rail_stations has expected columns", {
  cols <- names(metrosp::rail_stations)
  expect_true("station_id" %in% cols)
  expect_true("station_name" %in% cols)
  expect_true("station_code" %in% cols)
  expect_true("line_number" %in% cols)
  expect_true("line_name_pt" %in% cols)
  expect_true("line_name" %in% cols)
  expect_true("company_name" %in% cols)
  expect_true("type" %in% cols)
  expect_true("status" %in% cols)
  expect_false(is.null(sf::st_geometry(metrosp::rail_stations)))
})

test_that("station ids identify physical complexes", {
  se <- metrosp::rail_stations[metrosp::rail_stations$station_name == "Sé", ]
  paulista <- metrosp::rail_stations[
    metrosp::rail_stations$station_name %in% c("Consolação", "Paulista"),
  ]
  santo_amaro <- metrosp::rail_stations[
    metrosp::rail_stations$station_name %in%
      c("Santo Amaro", "Santo Amaro (Linha 9)"),
  ]
  santo <- metrosp::rail_stations[
    metrosp::rail_stations$station_name == "Santo Antônio",
  ]

  expect_length(unique(se$station_id), 1L)
  expect_setequal(unique(paulista$station_name), c("Consolação", "Paulista"))
  expect_length(unique(paulista$station_id), 1L)
  expect_length(unique(santo_amaro$station_id), 1L)
  expect_length(unique(santo$station_id), 2L)
})

test_that("rail_lines type and status values are valid", {
  expect_true(all(metrosp::rail_lines$type %in% c("metro", "train")))
  expect_true(all(metrosp::rail_lines$status %in% c("current", "future")))
})

test_that("rail_stations type and status values are valid", {
  expect_true(all(metrosp::rail_stations$type %in% c("metro", "train")))
  expect_true(all(metrosp::rail_stations$status %in% c("current", "future")))
})

test_that("lines CRS is EPSG:4326", {
  expect_equal(sf::st_crs(metrosp::rail_lines)$epsg, 4326)
})

test_that("stations CRS is EPSG:4326", {
  expect_equal(sf::st_crs(metrosp::rail_stations)$epsg, 4326)
})

test_that("lines geometry type is LINESTRING or MULTILINESTRING", {
  geom_types <- unique(sf::st_geometry_type(metrosp::rail_lines))
  expect_true(all(geom_types %in% c("LINESTRING", "MULTILINESTRING")))
})

test_that("stations geometry type is POINT", {
  geom_types <- unique(sf::st_geometry_type(metrosp::rail_stations))
  expect_true(all(geom_types %in% c("POINT", "MULTIPOINT")))
})

test_that("Line 5 geometry identifies ViaMobilidade as the operator", {
  line_5_operators <- unique(metrosp::rail_lines$company_name[
    metrosp::rail_lines$type == "metro" &
      metrosp::rail_lines$line_number == 5L
  ])
  station_5_operators <- unique(metrosp::rail_stations$company_name[
    metrosp::rail_stations$type == "metro" &
      metrosp::rail_stations$line_number == 5L
  ])

  expect_identical(line_5_operators, "ViaMobilidade")
  expect_identical(station_5_operators, "ViaMobilidade")
})

test_that("both networks are represented in lines", {
  types <- metrosp::rail_lines$type
  expect_true("metro" %in% types)
  expect_true("train" %in% types)
})

test_that("both networks are represented in stations", {
  types <- metrosp::rail_stations$type
  expect_true("metro" %in% types)
  expect_true("train" %in% types)
})

test_that("current metro lines include known line numbers", {
  current_metro <- metrosp::rail_lines[
    metrosp::rail_lines$type == "metro" &
      metrosp::rail_lines$status == "current",
  ]
  nums <- current_metro$line_number
  expect_true(1L %in% nums)
  expect_true(2L %in% nums)
  expect_true(3L %in% nums)
  expect_true(15L %in% nums)
})

test_that("current train lines include known CPTM line numbers", {
  current_train <- metrosp::rail_lines[
    metrosp::rail_lines$type == "train" &
      metrosp::rail_lines$status == "current",
  ]
  nums <- current_train$line_number
  expect_true(any(nums %in% c(7L, 8L, 9L, 10L, 11L, 12L)))
})

test_that("rail_lines and rail_stations have rows", {
  expect_gt(nrow(metrosp::rail_lines), 0)
  expect_gt(nrow(metrosp::rail_stations), 0)
})

test_that("no NA line numbers in lines", {
  expect_false(any(is.na(metrosp::rail_lines$line_number)))
})

test_that("no NA station names in stations", {
  expect_false(any(is.na(metrosp::rail_stations$station_name)))
})

test_that("stations has no duplicate rows", {
  dat <- sf::st_drop_geometry(metrosp::rail_stations)
  expect_false(any(duplicated(dat)))
})
