test_that("monthly passenger readers preserve the published system total", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(sys.source(file.path(pipeline_dir, "build", "dims.R"), env))
  suppressWarnings(sys.source(file.path(pipeline_dir, "helpers.R"), env))
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "import", "import_historic.R"), env)
  )

  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "DEMANDA;Linha 1 - Azul;Rede",
      "Total;100;100",
      "Media dos Dias Uteis;10;10",
      "Media dos Sabados;8;8",
      "Media dos Domingos;6;6",
      "Maxima Diaria;12;12"
    ),
    path
  )

  result <- env$clean_psg_month(env$read_psg_month(path))

  expect_setequal(result$line_number, c(1L, 99L))
})

test_that("unrecognized line labels fail visibly", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(sys.source(file.path(pipeline_dir, "helpers.R"), env))

  condition <- tryCatch(
    env$label_line_number(c("Linha 1 - Azul", "unknown")),
    error = identity
  )

  expect_s3_class(condition, "error")
  expect_match(
    conditionMessage(condition),
    'Unrecognized line label: "unknown".',
    fixed = TRUE
  )
})

test_that("station dimensions report invalid ids without crashing", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "build", "station_identity.R"), env)
  )
  stations <- data.frame(
    station_member_id = c(NA_character_, "duplicate", "duplicate"),
    station_id = c("valid", "bad id", "other"),
    station_name = c("A", "B", "C"),
    station_code = NA_character_,
    complex_source = NA_character_,
    notes = NA_character_
  )
  aliases <- data.frame(
    station_name_raw = "A",
    station_member_id = "missing-member",
    source = "test",
    notes = NA_character_
  )

  condition <- tryCatch(
    env$validate_station_dimensions(stations, aliases),
    error = identity
  )

  expect_s3_class(condition, "error")
  message <- conditionMessage(condition)
  expect_match(message, "missing station_member_id", fixed = TRUE)
  expect_match(message, "duplicate station_member_id", fixed = TRUE)
  expect_match(message, "unknown station_member_id", fixed = TRUE)
  expect_match(message, "invalid station_member_id", fixed = TRUE)
  expect_match(message, "invalid station_id", fixed = TRUE)
})

test_that("station resolution rejects recycled source vectors", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "build", "station_identity.R"), env)
  )
  stations <- data.frame(
    station_member_id = "a",
    station_id = "a",
    station_name = "A",
    station_code = NA_character_,
    complex_source = NA_character_,
    notes = NA_character_
  )
  aliases <- data.frame(
    station_name_raw = "A",
    station_member_id = "a",
    source = "test",
    notes = NA_character_
  )
  dat <- data.frame(station_name = rep("A", 3))

  condition <- tryCatch(
    env$resolve_stations(dat, c("test", "test"), stations, aliases),
    error = identity
  )

  expect_s3_class(condition, "error")
  expect_match(
    conditionMessage(condition),
    "`source` must have length 1 or match the 3 data rows.",
    fixed = TRUE
  )
})

test_that("legacy station names resolve through the committed crosswalk", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "publish", "validate_refresh.R"), env)
  )
  stations <- data.frame(
    station_member_id = c("consolacao", "paulista"),
    station_id = rep("consolacao-paulista", 2),
    station_name = c("Consolação", "Paulista")
  )
  aliases <- data.frame(
    station_name_raw = c("Consolação", "Paulista"),
    station_member_id = c("consolacao", "paulista"),
    source = c("metro_current_daily", "dataverse_daily")
  )
  baseline <- data.frame(station_name = c("Consolação", "Paulista"))

  resolved <- env$add_baseline_station_ids(baseline, stations, aliases)

  expect_identical(
    resolved$station_id,
    c("consolacao-paulista", "consolacao-paulista")
  )
})

test_that("the baseline adapter renames 1.x datasets before comparing", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "publish", "validate_refresh.R"), env)
  )

  baseline <- list(
    passengers_entrance = data.frame(
      date = rep(as.Date("2026-07-01"), 2),
      line_number = c(1, 99),
      metric_abb = "total",
      metric = "Total",
      metric_pt = "Total",
      passengers = c(10, 10)
    ),
    station_averages = data.frame(
      date = as.Date("2026-07-01"),
      avg_passenger = 5
    ),
    lines = data.frame(line_number = 1),
    stations = data.frame(station_name = "Sé")
  )

  out <- env$normalize_baseline_schema(baseline)

  # Renamed, so anything keyed on the 2.0 names can find it.
  expect_true(all(
    c(
      "line_entries_monthly",
      "station_entries_monthly",
      "rail_lines",
      "rail_stations"
    ) %in%
      names(out)
  ))
  expect_false(any(c("passengers_entrance", "lines") %in% names(out)))

  # Columns translated, and the SISTEMA row dropped so the intended removal
  # does not read as shrinkage.
  expect_identical(out$line_entries_monthly$metric, "total")
  expect_identical(out$line_entries_monthly$value, 10)
  expect_false(99 %in% out$line_entries_monthly$line_number)
  expect_identical(out$station_entries_monthly$value, 5)
})

test_that("a demand dataset missing from the baseline fails validation", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")
  skip_if_not_installed("dplyr")

  env <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "publish", "validate_refresh.R"), env)
  )

  new <- list(line_entries_monthly = metrosp::line_entries_monthly)
  # A baseline that loaded fine but shares no demand dataset with the build.
  result <- env$validate_refresh(new, baseline = list(metro_colors = "x"))

  expect_false(result$ok)
  expect_true(any(grepl("absent from the baseline", result$failures)))
})
