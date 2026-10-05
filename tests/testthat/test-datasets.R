# Structural invariants for the shipped (frozen) datasets.
#
# The assertions live in helper-checks.R so the scheduled pipeline can run the
# identical checks against freshly rebuilt data before publishing it. Here they
# guard the snapshot in data/*.rda; see data-raw/R/publish/validate_refresh.R for the
# other caller.

test_that("all datasets load as data frames", {
  expect_s3_class(metrosp::line_entries_monthly, "data.frame")
  expect_s3_class(metrosp::line_transported_monthly, "data.frame")
  expect_s3_class(metrosp::station_transported_monthly, "data.frame")
  expect_s3_class(metrosp::station_entries_daily, "data.frame")
})

test_that("line_entries_monthly satisfies its structural invariants", {
  expect_equal(
    check_line_entries_monthly(metrosp::line_entries_monthly),
    character(0)
  )
})

test_that("line_entries_monthly preserves the July 2017 source gap", {
  entries <- metrosp::line_entries_monthly[, c("date", "line_number")]
  expect_equal(check_entrance_july_2017_gap(entries), character(0))

  extra_line <- entries[1, ]
  extra_line$date <- as.Date("2017-07-01")
  extra_line$line_number <- 1L

  expect_match(
    check_entrance_july_2017_gap(rbind(entries, extra_line)),
    "should contain only Line 4"
  )
})

test_that("line_transported_monthly satisfies its structural invariants", {
  expect_equal(
    check_line_transported_monthly(metrosp::line_transported_monthly),
    character(0)
  )
})

test_that("line_transported_monthly covers Line 4 with all five metrics", {
  line4 <- metrosp::line_transported_monthly[
    metrosp::line_transported_monthly$line_number == 4L,
    ,
    drop = FALSE
  ]
  expect_gt(nrow(line4), 0)
  expect_setequal(
    unique(line4$metric),
    c("total", "mdu", "msa", "mdo", "max")
  )
  expect_equal(min(line4$date), as.Date("2012-01-01"))
})

test_that("transported counts share the entry counts' unit", {
  expect_equal(
    check_transported_gte_entries(
      metrosp::line_entries_monthly,
      metrosp::line_transported_monthly
    ),
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

  missing_year <- metrosp::station_transported_monthly |>
    dplyr::select(-year)
  expect_match(
    check_station_transported_monthly(missing_year)[[1]],
    "missing column"
  )
})

test_that("line checks reject system totals without fixing the line roster", {
  future_line <- data.frame(line_number = c(1L, 6L))
  system_total <- data.frame(line_number = c(1L, 99L))

  expect_equal(
    check_absent_values(future_line, "line_number", 99L, "demand"),
    character(0)
  )
  expect_match(
    check_absent_values(system_total, "line_number", 99L, "demand"),
    "99"
  )
})

test_that("station_transported_monthly satisfies its structural invariants", {
  expect_equal(
    check_station_transported_monthly(metrosp::station_transported_monthly),
    character(0)
  )
})

test_that("station_transported_monthly holds no post-handover Line 5 rows", {
  transported <- metrosp::station_transported_monthly
  expect_false(any(
    transported$line_number == 5L & transported$date >= as.Date("2018-08-01")
  ))

  bad <- transported
  bad <- rbind(
    bad,
    data.frame(
      date = as.Date("2020-01-01"),
      year = 2020L,
      line_number = 5L,
      station_id = "chacara-klabin",
      station_name = "Chácara Klabin",
      line_name = "Lilac",
      line_name_pt = "Lilás",
      metric = "mdu",
      metric_name = "Average on Business Days",
      metric_name_pt = "Média dos Dias Úteis",
      value = 1000
    )
  )
  expect_match(
    check_station_transported_monthly(bad)[[1]],
    "Line 5"
  )
})

test_that("station transported sums approximate line transported mdu", {
  expect_equal(
    check_station_transported_agreement(
      metrosp::station_transported_monthly,
      metrosp::line_transported_monthly
    ),
    character(0)
  )
})

test_that("station daily sums equal line entries totals", {
  expect_equal(
    check_daily_entries_agreement(
      metrosp::station_entries_daily,
      metrosp::line_entries_monthly
    ),
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
  monthly <- metrosp::station_transported_monthly |>
    dplyr::distinct(station_id, station_name)
  daily <- metrosp::station_entries_daily |>
    dplyr::distinct(station_id, station_name)

  # Every daily station appears in the monthly table, except Line 5's
  # post-handover stations: the monthly transported table drops Line 5 from
  # Aug 2018 onward while the daily table starts there.
  missing <- setdiff(daily$station_id, monthly$station_id)
  missing_lines <- metrosp::station_entries_daily |>
    dplyr::filter(station_id %in% missing) |>
    dplyr::distinct(line_number)
  expect_true(all(missing_lines$line_number == 5L))
  expect_setequal(
    intersect(monthly$station_id, daily$station_id),
    setdiff(unique(daily$station_id), missing)
  )
  expect_identical(
    unique(metrosp::station_transported_monthly$station_id[
      metrosp::station_transported_monthly$station_name == "República"
    ]),
    "republica"
  )
  expect_setequal(
    unique(metrosp::station_transported_monthly$line_number[
      metrosp::station_transported_monthly$station_name == "República"
    ]),
    c(3L, 4L)
  )
  expect_equal(
    unique(metrosp::station_entries_daily$line_number[
      metrosp::station_entries_daily$station_name == "República"
    ]),
    3L
  )
})

test_that("station_transported_monthly names all resolve to a current metro geometry", {
  geo <- sf::st_drop_geometry(metrosp::rail_stations)
  geo_current_metro <- geo[geo$status == "current" & geo$type == "metro", ]
  unmatched <- setdiff(
    unique(metrosp::station_transported_monthly$station_name),
    unique(geo_current_metro$station_name)
  )
  expect_equal(unmatched, character(0))
})


test_that("transported reconciliation detects one corrupt line-month", {
  station <- metrosp::station_transported_monthly
  changed <- station$line_number == 1L &
    station$date == as.Date("2025-06-01")
  station$value[changed] <- station$value[changed] / 2

  problems <- check_station_transported_agreement(
    station,
    metrosp::line_transported_monthly
  )
  expect_length(problems, 1L)
  expect_match(problems, "2025-06-01")
})

test_that("known transported source defects do not exempt neighboring months", {
  station <- metrosp::station_transported_monthly
  changed <- station$line_number == 2L &
    station$date == as.Date("2022-06-01")
  station$value[changed] <- station$value[changed] / 2

  problems <- check_station_transported_agreement(
    station,
    metrosp::line_transported_monthly
  )
  expect_length(problems, 1L)
  expect_match(problems, "2022-06-01")
})
