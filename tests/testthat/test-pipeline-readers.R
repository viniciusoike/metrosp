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
    passengers_transported = data.frame(
      date = as.Date("2026-07-01"),
      line_number = 1,
      metric_abb = "total",
      metric = "Total",
      metric_pt = "Total",
      value = 26.5
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
      "station_transported_monthly",
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
  expect_identical(out$station_transported_monthly$value, 5)

  # 1.x published transported counts in thousands; 2.0 counts passengers.
  expect_identical(out$line_transported_monthly$value, 26500)
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

test_that("the baseline adapter drops post-handover Line 5 station rows", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "publish", "validate_refresh.R"), env)
  )

  baseline <- list(
    station_averages = data.frame(
      date = as.Date(c("2018-07-01", "2018-08-01")),
      line_number = c(5L, 5L),
      avg_passenger = c(10, 12)
    )
  )

  out <- env$normalize_baseline_schema(baseline)

  expect_true("station_transported_monthly" %in% names(out))
  expect_equal(nrow(out$station_transported_monthly), 1L)
  expect_equal(out$station_transported_monthly$date, as.Date("2018-07-01"))
})

test_that("clean_transported_4_5 sums both boarding types for Line 4 only", {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")
  skip_if_not_installed("dplyr")
  skip_if_not_installed("bizdays")
  bizdays::load_builtin_calendars()

  env <- new.env(parent = globalenv())
  suppressWarnings(sys.source(file.path(pipeline_dir, "build", "dims.R"), env))
  suppressWarnings(sys.source(file.path(pipeline_dir, "helpers.R"), env))
  suppressWarnings(
    sys.source(file.path(pipeline_dir, "import", "import_dataverse.R"), env)
  )

  raw <- data.frame(
    business_unit = c("ViaQuatro", "ViaQuatro", "ViaMobilidade - Linha 5"),
    tipo_embarque = c("Bloqueio", "Integracao", "Bloqueio"),
    embarques = c(100, 50, 999),
    data = as.Date("2025-06-02"),
    station_name = c("Luz", "Luz", "Chácara Klabin")
  )

  daily <- env$transported_line_daily_4(raw)

  # ViaQuatro Bloqueio + Integracao summed; Line 5 excluded entirely.
  expect_equal(nrow(daily), 1L)
  expect_equal(daily$line_number, 4L)
  expect_equal(daily$value, 150)

  monthly <- env$clean_transported_4_5(raw)
  expect_setequal(
    unique(monthly$metric_abb),
    c("total", "mdu", "msa", "mdo", "max")
  )
  expect_true(all(monthly$line_number == 4L))
})

# Baseline retrieval -----------------------------------------------------------

local_publish_env <- function() {
  pipeline_dir <- test_path("..", "..", "data-raw", "R")
  skip_if_not(dir.exists(pipeline_dir), "data-raw pipeline code not available")

  env <- new.env(parent = globalenv())
  for (file in c("gh_release.R", "release_payload.R", "validate_refresh.R")) {
    suppressWarnings(
      sys.source(file.path(pipeline_dir, "publish", file), env)
    )
  }
  env
}

# A fake `gh` that answers like the real CLI: output lines with a `status`
# attribute on failure.
stub_gh <- function(env, output, status = 1L) {
  env$system2 <- function(...) {
    structure(output, status = status)
  }
}

write_baseline <- function(dir, datasets) {
  entries <- list()
  for (nm in names(datasets)) {
    saveRDS(datasets[[nm]], file.path(dir, paste0(nm, ".rds")))
    entries[[nm]] <- list(file = paste0(nm, ".rds"))
  }
  jsonlite::write_json(
    list(datasets = entries),
    file.path(dir, "manifest.json"),
    auto_unbox = TRUE
  )
}

test_that("only a confirmed missing release counts as absent", {
  env <- local_publish_env()

  stub_gh(env, "release not found")
  expect_false(env$release_exists("data-latest"))

  stub_gh(env, character(0), status = 0L)
  expect_true(env$release_exists("data-latest"))

  operational <- c(
    "HTTP 401: Bad credentials (https://api.github.com/graphql)",
    "error connecting to api.github.com",
    "HTTP 403: API rate limit exceeded for installation ID 1.",
    "HTTP 502: Bad Gateway (https://api.github.com/repos/x/y/releases)"
  )
  for (message in operational) {
    stub_gh(env, message)
    expect_error(env$release_exists("data-latest"), "gh")
  }
})

test_that("a confirmed first publication proceeds without a baseline", {
  env <- local_publish_env()
  env$release_exists <- function(...) FALSE
  env$download_release_assets <- function(...) stop("should not download")

  expect_message(
    out <- env$fetch_baseline("data-latest", withr::local_tempdir()),
    "first publish"
  )
  expect_null(out)
})

test_that("an existing release with no assets fails", {
  env <- local_publish_env()
  env$release_exists <- function(...) TRUE
  env$release_asset_names <- function(...) character(0)

  expect_error(
    env$fetch_baseline("data-latest", withr::local_tempdir()),
    "no assets"
  )
})

test_that("a failed baseline download fails", {
  env <- local_publish_env()
  env$release_exists <- function(...) TRUE
  env$release_asset_names <- function(...) "manifest.json"
  stub_gh(env, "HTTP 503: Service Unavailable")

  expect_error(
    env$fetch_baseline("data-latest", withr::local_tempdir()),
    "503"
  )
})

test_that("an unloadable baseline directory fails", {
  env <- local_publish_env()

  # No manifest.
  expect_error(env$load_baseline(withr::local_tempdir()), "manifest")

  # Malformed manifest.
  dir <- withr::local_tempdir()
  writeLines("{not json", file.path(dir, "manifest.json"))
  expect_error(env$load_baseline(dir), "manifest")

  # Manifest without datasets.
  dir <- withr::local_tempdir()
  jsonlite::write_json(list(built_at = "x"), file.path(dir, "manifest.json"))
  expect_error(env$load_baseline(dir), "manifest")

  # Listed asset missing.
  dir <- withr::local_tempdir()
  write_baseline(dir, list(line_entries_monthly = data.frame(value = 1)))
  unlink(file.path(dir, "line_entries_monthly.rds"))
  expect_error(env$load_baseline(dir), "line_entries_monthly")

  # Listed asset unreadable.
  dir <- withr::local_tempdir()
  write_baseline(dir, list(line_entries_monthly = data.frame(value = 1)))
  writeLines("garbage", file.path(dir, "line_entries_monthly.rds"))
  expect_error(env$load_baseline(dir), "line_entries_monthly")
})

test_that("a valid baseline loads under its published names", {
  env <- local_publish_env()

  dir <- withr::local_tempdir()
  write_baseline(
    dir,
    list(
      passengers_entrance = data.frame(value = 1),
      line_entries_monthly = data.frame(value = 2)
    )
  )

  out <- env$load_baseline(dir)

  expect_named(out, c("passengers_entrance", "line_entries_monthly"))
  expect_identical(out$line_entries_monthly$value, 2)
})

# Build gate -------------------------------------------------------------------

test_that("the build gate rejects inconsistent fresh data", {
  env <- local_publish_env()
  env$checks_helper <- function() test_path("helper-checks.R")

  datasets <- list(
    line_transported_monthly = metrosp::line_transported_monthly,
    station_transported_monthly = metrosp::station_transported_monthly
  )
  expect_equal(env$check_built_datasets(datasets), TRUE)
  changed <- datasets$station_transported_monthly$line_number == 1L &
    datasets$station_transported_monthly$date == as.Date("2025-06-01")
  datasets$station_transported_monthly$value[changed] <- 0
  condition <- tryCatch(env$check_built_datasets(datasets), error = identity)
  expect_s3_class(condition, "error")
  expect_match(conditionMessage(condition), "2025-06-01")
})
