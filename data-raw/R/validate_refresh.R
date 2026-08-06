# validate_refresh.R
# -----------------------------------------------------------------------------
# Differential validation for the scheduled refresh: compare a freshly built
# batch against the previously published one and decide whether it is safe to
# publish.
#
# Structural invariants live in tests/testthat/helper-checks.R and are shared
# with the package test suite (see the note there). What is here is everything
# that needs a *baseline* and therefore cannot live in tests/: shrinkage,
# per-line coverage regressions, retroactive restatements, and magnitude
# outliers.
#
# The retroactive-drift check is the important one. METRO revises
# already-published years (the 2026-07-29 batch restated "Demanda - 2016"),
# which no structural check can see: the restated data is perfectly well-formed,
# it just disagrees with what was published last week. That is reported, never
# failed -- restatements are legitimate, they just must not pass unnoticed.
# -----------------------------------------------------------------------------

.checks_helper <- function() here::here("tests/testthat/helper-checks.R")

# Join keys per dataset, used for the retroactive-drift comparison.
.drift_keys <- list(
  passengers_entrance = c("date", "line_number", "metric_abb"),
  passengers_transported = c("date", "line_number", "metric_abb"),
  station_averages = c("date", "line_number", "station_name"),
  station_daily = c("date", "line_number", "station_name")
)

.drift_values <- list(
  passengers_entrance = "value",
  passengers_transported = "value",
  station_averages = "avg_passenger",
  station_daily = "passengers"
)

#' Validate a rebuilt batch against the previously published one.
#'
#' @param new Named list of freshly built datasets.
#' @param baseline Named list of previously published datasets, or NULL for the
#'   first run (differential checks are skipped, structural ones still run).
#' @param magnitude_tol Relative deviation from a line's trailing 12-month
#'   median above which a month is flagged.
#' @return A list with `ok` (logical), `failures`, `warnings`, and `report`
#'   (markdown).
validate_refresh <- function(new, baseline = NULL, magnitude_tol = 0.4) {
  source(.checks_helper(), local = TRUE)

  failures <- character(0)
  warnings <- character(0)
  notes <- character(0)

  # --- Structural (shared with the package test suite) -----------------------
  structural <- check_all_datasets(new)
  for (nm in names(structural)) {
    failures <- c(failures, structural[[nm]])
  }

  # --- Freshness (warn only; an irregular upstream is normal) ---------------
  for (nm in names(.drift_keys)) {
    if (!is.null(new[[nm]])) {
      warnings <- c(warnings, check_freshness(new[[nm]], nm))
    }
  }

  if (is.null(baseline)) {
    notes <- c(notes, "No baseline available; differential checks skipped.")
    return(.validation_result(failures, warnings, notes, list()))
  }

  drift <- list()

  for (nm in names(.drift_keys)) {
    if (is.null(new[[nm]]) || is.null(baseline[[nm]])) {
      next
    }
    nw <- new[[nm]]
    bl <- baseline[[nm]]

    # --- Shrinkage (hard fail) ----------------------------------------------
    if (nrow(nw) < nrow(bl)) {
      failures <- c(
        failures,
        sprintf(
          "%s: row count shrank %d -> %d (%+d)",
          nm,
          nrow(bl),
          nrow(nw),
          nrow(nw) - nrow(bl)
        )
      )
    }

    # --- Per-line coverage regression (hard fail) ---------------------------
    cov_new <- line_coverage(nw)
    cov_old <- line_coverage(bl)
    for (ln in intersect(names(cov_old), names(cov_new))) {
      if (cov_new[[ln]] < cov_old[[ln]]) {
        failures <- c(
          failures,
          sprintf(
            "%s: line %s lost coverage (%s -> %s)",
            nm,
            ln,
            format(cov_old[[ln]]),
            format(cov_new[[ln]])
          )
        )
      }
    }
    lost_lines <- setdiff(names(cov_old), names(cov_new))
    if (length(lost_lines) > 0) {
      failures <- c(
        failures,
        sprintf(
          "%s: line(s) %s disappeared entirely",
          nm,
          paste(lost_lines, collapse = ", ")
        )
      )
    }

    # --- Retroactive drift (report only) ------------------------------------
    drift[[nm]] <- .compare_overlap(
      nw,
      bl,
      keys = .drift_keys[[nm]],
      value = .drift_values[[nm]]
    )

    # --- Magnitude outliers (warn) ------------------------------------------
    warnings <- c(
      warnings,
      .magnitude_outliers(nw, nm, .drift_values[[nm]], magnitude_tol)
    )

    # --- New rows (informational) -------------------------------------------
    added <- nrow(nw) - nrow(bl)
    if (added > 0) {
      notes <- c(notes, sprintf("%s: %+d row(s)", nm, added))
    }
  }

  .validation_result(failures, warnings, notes, drift)
}

# Inner-join new against baseline on keys and count value disagreements over the
# overlapping period. Returns a list with the count and a per-year breakdown.
.compare_overlap <- function(new, baseline, keys, value) {
  keys <- intersect(keys, intersect(names(new), names(baseline)))
  if (length(keys) == 0 || !value %in% names(new)) {
    return(NULL)
  }

  a <- new[, c(keys, value), drop = FALSE]
  b <- baseline[, c(keys, value), drop = FALSE]
  names(b)[names(b) == value] <- ".baseline"

  merged <- merge(a, b, by = keys, all = FALSE)
  if (nrow(merged) == 0) {
    return(NULL)
  }

  changed <- !.near(merged[[value]], merged$.baseline)
  n_changed <- sum(changed, na.rm = TRUE)

  if (n_changed == 0) {
    return(list(n_compared = nrow(merged), n_changed = 0L, by_year = NULL))
  }

  years <- as.integer(format(merged$date[changed], "%Y"))
  by_year <- sort(table(years), decreasing = TRUE)

  list(
    n_compared = nrow(merged),
    n_changed = n_changed,
    by_year = by_year
  )
}

# NA-aware near-equality: two NAs agree, one NA disagrees.
.near <- function(x, y, tol = 1e-8) {
  both_na <- is.na(x) & is.na(y)
  one_na <- xor(is.na(x), is.na(y))
  out <- rep(FALSE, length(x))
  out[both_na] <- TRUE
  ok <- !both_na & !one_na
  out[ok] <- abs(x[ok] - y[ok]) <= tol * pmax(1, abs(y[ok]))
  out
}

# Flag line-months whose value departs sharply from that line's own trailing
# 12-month median. Catches unit changes and parsing regressions that leave the
# data structurally valid but numerically absurd.
.magnitude_outliers <- function(df, name, value, tol) {
  if (!all(c("date", "line_number", value) %in% names(df))) {
    return(character(0))
  }
  if ("metric_abb" %in% names(df)) {
    df <- df[df$metric_abb == "total", , drop = FALSE]
  }
  if (nrow(df) == 0) {
    return(character(0))
  }

  agg <- stats::aggregate(
    df[[value]],
    by = list(date = df$date, line_number = df$line_number),
    FUN = sum,
    na.rm = TRUE
  )
  names(agg)[3] <- "value"

  problems <- character(0)
  for (ln in unique(agg$line_number)) {
    sub <- agg[agg$line_number == ln, , drop = FALSE]
    sub <- sub[order(sub$date), , drop = FALSE]
    if (nrow(sub) < 13) {
      next
    }
    latest <- sub[nrow(sub), ]
    window <- sub$value[(nrow(sub) - 12):(nrow(sub) - 1)]
    med <- stats::median(window, na.rm = TRUE)
    if (is.na(med) || med == 0) {
      next
    }
    dev <- (latest$value - med) / med
    if (abs(dev) > tol) {
      problems <- c(
        problems,
        sprintf(
          "%s: line %s at %s is %+.0f%% vs its trailing 12-month median",
          name,
          ln,
          format(latest$date),
          dev * 100
        )
      )
    }
  }
  problems
}

# --- Reporting ---------------------------------------------------------------

.validation_result <- function(failures, warnings, notes, drift) {
  list(
    ok = length(failures) == 0,
    failures = failures,
    warnings = warnings,
    notes = notes,
    drift = drift,
    report = .render_report(failures, warnings, notes, drift)
  )
}

.bullets <- function(x) {
  if (length(x) == 0) {
    return(NULL)
  }
  paste0("- ", x, collapse = "\n")
}

# The markdown here becomes the body of the refresh PR. It is written to be
# read first and skimmed fast: verdict, then what changed, then the detail.
.render_report <- function(failures, warnings, notes, drift) {
  lines <- c(
    if (length(failures) == 0) {
      "## ✅ Validation passed"
    } else {
      "## ❌ Validation failed"
    },
    ""
  )

  if (length(failures) > 0) {
    lines <- c(lines, "### Blocking", "", .bullets(failures), "")
  }

  changed_any <- FALSE
  drift_lines <- character(0)
  for (nm in names(drift)) {
    d <- drift[[nm]]
    if (is.null(d)) {
      next
    }
    if (d$n_changed == 0) {
      drift_lines <- c(
        drift_lines,
        sprintf("- **%s**: no restatements (%d rows compared)", nm, d$n_compared)
      )
    } else {
      changed_any <- TRUE
      by_year <- paste(
        sprintf("%s (%d)", names(d$by_year), as.integer(d$by_year)),
        collapse = ", "
      )
      drift_lines <- c(
        drift_lines,
        sprintf(
          "- **%s**: %d of %d overlapping values changed — %s",
          nm,
          d$n_changed,
          d$n_compared,
          by_year
        )
      )
    }
  }

  if (length(drift_lines) > 0) {
    lines <- c(
      lines,
      "### Retroactive restatements",
      "",
      if (changed_any) {
        paste(
          "Upstream changed values it had already published. This is normal for",
          "METRO but worth a look before merging."
        )
      } else {
        "None — every overlapping value matches the previous release."
      },
      "",
      drift_lines,
      ""
    )
  }

  if (length(notes) > 0) {
    lines <- c(lines, "### Changes", "", .bullets(notes), "")
  }

  if (length(warnings) > 0) {
    lines <- c(lines, "### Warnings", "", .bullets(warnings), "")
  }

  paste(lines, collapse = "\n")
}

# --- Baseline loading --------------------------------------------------------

#' Load the previously published batch from a directory of release assets.
#' Returns NULL when the directory has no manifest (first run).
load_baseline <- function(dir) {
  if (!file.exists(file.path(dir, "manifest.json"))) {
    return(NULL)
  }
  manifest <- read_manifest(dir)
  out <- list()
  for (nm in names(manifest$datasets)) {
    path <- file.path(dir, manifest$datasets[[nm]]$file)
    if (file.exists(path)) {
      out[[nm]] <- readRDS(path)
    }
  }
  out
}
