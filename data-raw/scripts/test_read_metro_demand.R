# Internal test suite for read_metro_demand() --------------------------------#
#                                                                             #
# Run by hand, outside the targets graph and the CRAN suite:                  #
#                                                                             #
#   Rscript data-raw/scripts/test_read_metro_demand.R               (offline) #
#   METROSP_TEST_REMOTE=true Rscript data-raw/scripts/test_read_metro_demand.R#
#                                                                             #
# Phase 1 -- the four demand datasets through read_metro_demand(bundled):     #
#   schema contract (data-raw/inputs/schema.json) + the structural invariants #
#   shared with the pipeline (tests/testthat/helper-checks.R).                #
# Phase 2 -- the bundled reference datasets against the same contract.        #
# Phase 3 -- opt-in, network: the real release client end to end, with the    #
#   invariants re-run on the freshly published data.                          #
#                                                                             #
# Exits non-zero if any check failed.                                         #
# ---------------------------------------------------------------------------

script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]])))
  }
  normalizePath("test_read_metro_demand.R")
}
root <- file.path(dirname(script_path()), "..", "..") |> normalizePath()

# read_metro_demand() is a dev-surface function, so this tests against the
# dev package, not an installed library copy.
pkgload::load_all(root, quiet = TRUE)

# --- Test harness -------------------------------------------------------------

tests_run <- 0L
tests_failed <- character(0)

check <- function(.condition, .description) {
  tests_run <<- tests_run + 1L

  if (isTRUE(.condition)) {
    cli::cli_alert_success("{(.description)}")
  } else {
    cli::cli_alert_danger("{(.description)}")
    tests_failed <<- c(tests_failed, .description)
  }
  invisible(.condition)
}

# `problems` is a character vector from one of the check_* helpers in
# helper-checks.R; empty means the data conforms.
check_problems <- function(.problems, .description) {
  check(length(.problems) == 0L, .description)
  if (length(.problems) > 0L) {
    cli::cli_bullets(stats::setNames(utils::head(.problems, 10L), "x"))
  }
  invisible(.problems)
}

# --- Schema contract -----------------------------------------------------------

schema <- jsonlite::read_json(
  file.path(root, "data-raw", "inputs", "schema.json"),
  simplifyVector = FALSE
)

schema_predicates <- list(
  character = is.character,
  double = is.numeric,
  integer = function(x) is.integer(x) || is.numeric(x),
  logical = is.logical,
  Date = function(x) inherits(x, "Date"),
  sfc = function(x) inherits(x, "sfc")
)

# Reads `name` via `reader`, then asserts the schema.json contract. `fail_cache`
# remembers which names already had a schema failure so later phases can skip
# invariant checks that would just repeat it.
read_and_check_schema <- function(name, reader) {
  obj <- reader(name)
  spec <- schema[[name]]

  if (identical(spec$kind, "vector")) {
    check(
      schema_predicates[[spec$type]](obj),
      sprintf("%s: %s vector", name, spec$type)
    )
    check(
      length(obj) == spec$length && identical(names(obj), unlist(spec$names)),
      sprintf("%s: length/names match the contract", name)
    )
    return(obj)
  }

  expected <- unlist(spec$columns)
  cols <- check_columns(df = obj, required = names(expected), name = name)
  ok_order <- identical(names(obj), names(expected))
  check(
    length(cols) == 0L && ok_order,
    sprintf(
      "%s: columns match the contract (nrow %d, ncol %d)",
      name,
      nrow(as.data.frame(obj)),
      length(expected)
    )
  )

  bad_types <- character(0)
  for (col in intersect(names(expected), names(obj))) {
    pred <- schema_predicates[[expected[[col]]]]
    ok <- !is.null(pred) && isTRUE(pred(obj[[col]]))
    if (!ok) {
      bad_types <- c(bad_types, sprintf("%s$%s", name, col))
    }
  }
  check(
    length(bad_types) == 0L,
    sprintf(
      "%s: column types match the contract%s",
      name,
      if (length(bad_types) > 0L) {
        paste0(" -- bad: ", paste(bad_types, collapse = ", "))
      } else {
        ""
      }
    )
  )

  return(obj)
}

# --- Phase 1: bundled demand datasets ------------------------------------------

run_phase_1 <- function() {
  cli::cli_h1(
    "Phase 1: demand datasets via read_metro_demand(source = 'bundled')"
  )

  source(file.path(root, "tests", "testthat", "helper-checks.R"), local = TRUE)

  demand_datasets <- c(
    "passengers_entrance",
    "passengers_transported",
    "station_averages",
    "station_daily"
  )

  bundled <- list()

  for (nm in demand_datasets) {
    bundled[[nm]] <- read_and_check_schema(
      nm,
      function(.nm) read_metro_demand(.nm, source = "bundled", quiet = TRUE)
    )
  }

  # Bundled reads must return the snapshot object itself, not a copy of it.
  for (nm in demand_datasets) {
    check(
      identical(bundled[[nm]], get(nm, envir = asNamespace("metrosp"))),
      sprintf("%s: bundled read matches data/%s.rda", nm, nm)
    )
    check_problems(
      check_all_datasets(bundled)[[nm]],
      sprintf("%s: structural invariants", nm)
    )
  }

  check(
    all(vapply(bundled, nrow, integer(1)) > 0L),
    "all four demand datasets are non-empty"
  )

  # Argument validation. Reference datasets are bundle-only by design; a
  # nonsense vintage is rejected before any I/O happens.
  check(
    tryCatch(
      {
        read_metro_demand("lines", source = "bundled")
        FALSE
      },
      error = function(e) grepl("must be one of", conditionMessage(e))
    ),
    "reference datasets rejected with a pointer to the bundled ones"
  )
  check(
    tryCatch(
      {
        read_metro_demand("station_daily", vintage = "august", source = "cache")
        FALSE
      },
      error = function(e) grepl("Unrecognised", conditionMessage(e))
    ),
    "unknown vintage strings are rejected"
  )

  return(invisible(TRUE))
}

# --- Phase 2: reference datasets ------------------------------------------------

run_phase_2 <- function() {
  cli::cli_h1("Phase 2: bundled reference datasets")

  reference <- c(
    "calendar_spo",
    "lines",
    "metro_colors",
    "station_inauguration",
    "stations"
  )

  for (nm in reference) {
    read_and_check_schema(nm, function(.nm) {
      get(.nm, envir = asNamespace("metrosp"))
    })
  }
  return(invisible(TRUE))
}

# --- Phase 3: published data (network) ------------------------------------------

# Exercises the real release client: manifest fetch, checksum verification,
# warm-cache reuse, and the published payload itself re-running every
# structural invariant.
run_phase_3 <- function() {
  cli::cli_h1("Phase 3: published data via the release client")

  source(file.path(root, "tests", "testthat", "helper-checks.R"), local = TRUE)

  # A throwaway cache dir, so this run never touches the user's cache.
  withr::local_options(
    metrosp.cache_dir = file.path(tempdir(), "metrosp-readtest"),
    metrosp.cache = TRUE
  )

  demand_datasets <- c(
    "passengers_entrance",
    "passengers_transported",
    "station_averages",
    "station_daily"
  )

  paid <- 0L
  # A cold 'auto' read must end in data, whatever it took: download, or a
  # bundled fallback with a warning if the release is unreachable.
  for (nm in demand_datasets) {
    out <- tryCatch(
      read_metro_demand(nm, source = "auto"),
      error = function(e) {
        cli::cli_bullets(setNames(
          sprintf("%s: error -- %s", nm, conditionMessage(e)),
          "x"
        ))
        NULL
      }
    )
    if (!is.null(out)) {
      paid <- paid + 1L
    }
    check(
      !is.null(out) && nrow(out) > 0L,
      sprintf("%s: auto read returned data", nm)
    )

    # The invariants again -- published data, not the snapshot.
    if (!is.null(out)) {
      check_problems(
        check_all_datasets(list(out))[[nm]],
        sprintf("%s: structural invariants on published data", nm)
      )
    }
  }

  # The cache must show what landed; the dated tag only appears when a
  # publish ran in the same month.
  listing <- metrosp_cache_list()
  check(
    nrow(listing) > 0L && all(grepl("^data-", listing$vintage)),
    "the cache records the published batch"
  )
  metrosp_cache_clear()
  check(
    nrow(metrosp_cache_list()) == 0L,
    "metrosp_cache_clear() empties the cache"
  )
  cli::cli_alert_info(
    "Published data arrived for {paid} of {length(demand_datasets)} datasets."
  )
  return(invisible(TRUE))
}

# --- Run -------------------------------------------------------------------------

run_phase_1()
run_phase_2()

if (identical(Sys.getenv("METROSP_TEST_REMOTE"), "true")) {
  run_phase_3()
} else {
  cli::cli_h1(
    "Phase 3: skipped (offline). Set METROSP_TEST_REMOTE=true to run it."
  )
}

if (length(tests_failed) > 0L) {
  quit(status = 1L)
}
