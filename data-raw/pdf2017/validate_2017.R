# validate_2017.R
# -----------------------------------------------------------------------------
# Step 3 of the one-time Jan-Sep 2017 extraction (see README.md).
#
# The transcription is done by eye, so every value needs a check that does not
# depend on the transcriber. Both source tables carry a printed total that the
# other cells must reproduce, which turns each table into its own checksum:
#
#   line-level    Rede   == sum of the five lines
#   station-level TOTAL  == sum of that line's stations
#
# Totals are printed in thousands after each component was rounded, so the
# comparison allows a few units of slack rather than demanding equality.
#
# A residual outside tolerance means either a misread digit or a defect in the
# source. Both are reported here; report_2017.md records which is which.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(tidyr)

.line_cols <- c(
  "linha_1_azul",
  "linha_2_verde",
  "linha_3_vermelha",
  "linha_5_lilas",
  "linha_15_prata"
)

# Every component is rounded to the nearest thousand before printing, so a total
# over n components can drift from the sum of the printed parts by up to n/2.
# The September source states this ("O total da linha pode ser diferente das
# soma das estações devido o arredondamento"). A single misread digit moves a
# value by at least 1 and usually by 9 or more, so this bound still bites.
.tol <- function(n) pmax(1, n / 2)

.tol_line <- .tol(5)

read_line_2017 <- function(
  path = here::here("data-raw/pdf2017/transcribed_passengers_line_2017.csv")
) {
  readr::read_csv(path, show_col_types = FALSE, na = "NA")
}

#' Read the station transcription, which is stored one row per station and one
#' column per month to mirror the source table, and return it long.
read_station_2017 <- function(
  path = here::here("data-raw/pdf2017/transcribed_station_averages_2017.csv")
) {
  readr::read_csv(path, show_col_types = FALSE, na = "NA") |>
    pivot_longer(
      cols = -c(line, station),
      names_to = "date",
      values_to = "value"
    ) |>
    mutate(date = as.Date(paste0(date, "-01")))
}

#' Check Rede against the sum of the five lines, one row per table row.
#'
#' Additive for Total and the three day-type averages. "Máxima Diária" is not:
#' each line peaks on its own day, so the network peak sits between the largest
#' single-line peak and the sum of the five, and is bounded rather than equated.
check_line_totals <- function(dat = read_line_2017()) {
  dat |>
    mutate(
      computed = rowSums(across(all_of(.line_cols)), na.rm = TRUE),
      largest = do.call(pmax, across(all_of(.line_cols))),
      # Matched on an accent-free fragment so the check does not depend on the
      # encoding this file happens to be sourced under.
      additive = !stringr::str_detect(metric, "xima Di"),
      residual = rede - computed,
      ok = !is.na(rede) &
        if_else(
          additive,
          abs(residual) <= .tol_line,
          rede <= computed + .tol_line & rede >= largest - .tol_line
        )
    ) |>
    select(date, measure, metric, rede, computed, largest, additive, residual, ok)
}

#' Check each line's printed TOTAL against the sum of its stations.
check_station_totals <- function(dat = read_station_2017()) {
  totals <- dat |>
    filter(station == "TOTAL") |>
    select(date, line, printed = value)

  computed <- dat |>
    filter(station != "TOTAL") |>
    summarise(
      computed = sum(value, na.rm = TRUE),
      n = sum(!is.na(value)),
      .by = c(date, line)
    )

  totals |>
    left_join(computed, by = join_by(date, line)) |>
    mutate(
      residual = printed - computed,
      ok = abs(residual) <= .tol(n)
    )
}

# The station table counts an interchange passenger once per line boarded, which
# is exactly what "passengers transported" means at line level. Each line's
# station sum should therefore reproduce that line's transported weekday average
# from the other source table -- a check that spans the two transcriptions and
# does not rely on the printed TOTAL row.
# Keyed on the line number rather than the full label, so the lookup does not
# depend on "Lilás" surviving whatever encoding this file is sourced under.
.station_line_map <- c(
  "1" = "linha_1_azul",
  "2" = "linha_2_verde",
  "3" = "linha_3_vermelha",
  "5" = "linha_5_lilas",
  "15" = "linha_15_prata"
)

#' Cross-check the station sums against the transported weekday averages.
check_station_vs_line <- function(
  stations = read_station_2017(),
  lines = read_line_2017()
) {
  mdu <- lines |>
    filter(measure == "transport", stringr::str_detect(metric, "dias|Dias")) |>
    select(date, all_of(unname(.station_line_map))) |>
    pivot_longer(-date, names_to = "col", values_to = "mdu")

  stations |>
    filter(station != "TOTAL") |>
    summarise(
      computed = sum(value, na.rm = TRUE),
      n = sum(!is.na(value)),
      .by = c(date, line)
    ) |>
    mutate(col = unname(.station_line_map[stringr::str_extract(line, "[0-9]+")])) |>
    left_join(mdu, by = join_by(date, col)) |>
    mutate(
      residual = mdu - computed,
      ok = abs(residual) <= .tol(n)
    ) |>
    select(date, line, mdu, computed, residual, ok)
}

#' Check that the station roster matches the one used by the Oct-Dec 2017 data.
check_station_roster <- function(
  dat = read_station_2017(),
  processed = here::here("data-raw/processed/metro_sp_station_averages_historic.csv")
) {
  baseline <- readr::read_csv(processed, show_col_types = FALSE) |>
    filter(date == as.Date("2017-10-01")) |>
    distinct(line = line_name_full, station = name_station)

  transcribed <- dat |>
    filter(station != "TOTAL") |>
    distinct(line, station)

  list(
    missing = anti_join(baseline, transcribed, by = join_by(line, station)),
    unexpected = anti_join(transcribed, baseline, by = join_by(line, station))
  )
}

#' Run every check and print a summary. Returns the failures invisibly.
validate_2017 <- function() {
  lines <- check_line_totals()
  bad_lines <- filter(lines, !ok)

  cli::cli_h2("Line-level: Rede vs sum of lines")
  cli::cli_alert_info(
    "{sum(lines$ok)}/{nrow(lines)} row{?s} within +/-{(.tol_line)}."
  )
  if (nrow(bad_lines) > 0) {
    print(as.data.frame(bad_lines))
  }

  out <- list(lines = bad_lines)

  station_path <- here::here(
    "data-raw/pdf2017/transcribed_station_averages_2017.csv"
  )

  if (file.exists(station_path)) {
    stations <- check_station_totals()
    bad_stations <- filter(stations, !ok)

    cli::cli_h2("Station-level: printed TOTAL vs sum of stations")
    cli::cli_alert_info("{sum(stations$ok)}/{nrow(stations)} column{?s} within tolerance.")
    if (nrow(bad_stations) > 0) {
      print(as.data.frame(bad_stations))
    }

    cross <- check_station_vs_line()
    bad_cross <- filter(cross, !ok)

    cli::cli_h2("Cross-check: station sum vs transported weekday average")
    cli::cli_alert_info("{sum(cross$ok)}/{nrow(cross)} column{?s} within tolerance.")
    if (nrow(bad_cross) > 0) {
      print(as.data.frame(bad_cross))
    }

    out$cross <- bad_cross

    roster <- check_station_roster()

    cli::cli_h2("Station roster vs October 2017")
    cli::cli_alert_info(
      "{nrow(roster$missing)} missing, {nrow(roster$unexpected)} unexpected."
    )
    if (nrow(roster$missing) > 0) print(as.data.frame(roster$missing))
    if (nrow(roster$unexpected) > 0) print(as.data.frame(roster$unexpected))

    out$stations <- bad_stations
    out$roster <- roster
  }

  invisible(out)
}

if (!interactive()) {
  validate_2017()
}
