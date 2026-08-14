# sanity_2017.R
# -----------------------------------------------------------------------------
# Plausibility checks on the transcribed Jan-Sep 2017 months (see README.md).
#
# validate_2017.R proves the transcription is internally consistent: the numbers
# reproduce the totals printed beside them. That cannot catch a value that is
# wrong in both the cell and the total, nor one the source itself got wrong. The
# checks here compare each transcribed month against neighbouring months that
# came from a different source path (the 2016 annual CSVs and the Oct 2017-2019
# monthly CSVs), so agreement is evidence the transcription is right.
#
# Demand is strongly seasonal -- January and July are school holidays -- so no
# check compares a month to its raw neighbours. Each one removes the seasonal
# term first, either by comparing the same calendar month across years or by
# comparing a ratio against that same ratio in other years.
#
# Nothing here is wired into the pipeline. Run it, read the ranked output, and
# check the flagged cells against the rendered PNGs.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(tidyr)

.transcribed_months <- as.Date(paste0("2017-", sprintf("%02d", 1:9), "-01"))

read_stations <- function(
  path = here::here("data-raw/processed/metro_sp_station_averages_historic.csv")
) {
  readr::read_csv(path, show_col_types = FALSE) |>
    mutate(year = as.integer(format(date, "%Y")), mon = as.integer(format(date, "%m"))) |>
    select(date, year, mon, line = line_name_full, station = name_station, value)
}

read_lines_psg <- function(
  path = here::here("data-raw/processed/metro_sp_passengers_historic.csv")
) {
  readr::read_csv(path, show_col_types = FALSE) |>
    mutate(year = as.integer(format(date, "%Y")), mon = as.integer(format(date, "%m"))) |>
    select(date, year, mon, measure, metric = variable, line_number, value) |>
    # The metric label changed case between eras; fold it so series line up.
    mutate(metric = tolower(trimws(metric)))
}

# --- Check 1: same calendar month, 2017 against 2016 and 2018 -----------------
# The strongest anchor available. Both comparison years come entirely from CSVs,
# so a transcription error cannot propagate into the expectation.

#' Compare each transcribed value to the mean of its 2016 and 2018 counterparts.
check_yoy <- function(dat, keys) {
  wide <- dat |>
    filter(year %in% 2016:2018) |>
    select(all_of(keys), mon, year, value) |>
    pivot_wider(names_from = year, values_from = value, names_prefix = "y")

  wide |>
    filter(mon <= 9) |>
    mutate(
      expected = rowMeans(cbind(y2016, y2018), na.rm = TRUE),
      dev = y2017 / expected,
      # Absolute floor: values are in thousands and the smallest stations sit
      # near 6, where a one-unit rounding difference is already 17%.
      material = abs(y2017 - expected) >= 5
    ) |>
    filter(is.finite(dev)) |>
    arrange(desc(abs(log(dev))))
}

# --- Check 2: the +/-6 month profile ------------------------------------------
# For each month, value / mean(value 6 months earlier, value 6 months later).
# For April-September 2017 both endpoints sit outside the transcribed window.
# The ratio is seasonal, so it is judged against the same ratio in other years
# rather than against 1.

#' Compare the +/-6 month ratio in 2017 to the same ratio in other years.
check_pm6 <- function(dat, keys) {
  dat |>
    arrange(across(all_of(c(keys, "date")))) |>
    mutate(
      lag6 = lag(value, 6),
      lead6 = lead(value, 6),
      .by = all_of(keys)
    ) |>
    mutate(ratio = value / rowMeans(cbind(lag6, lead6), na.rm = TRUE)) |>
    filter(is.finite(ratio)) |>
    mutate(
      baseline = median(ratio[!date %in% .transcribed_months], na.rm = TRUE),
      .by = all_of(c(keys, "mon"))
    ) |>
    filter(date %in% .transcribed_months, !is.na(baseline)) |>
    mutate(
      expected = baseline * rowMeans(cbind(lag6, lead6), na.rm = TRUE),
      dev = ratio / baseline,
      material = abs(value - expected) >= 5
    ) |>
    arrange(desc(abs(log(dev))))
}

# --- Check 3: month-over-month steps inside the window ------------------------

#' Flag month-over-month steps that are extreme against the same step in other
#' years -- a misread digit shows up as a jump into and back out of one month.
check_mom <- function(dat, keys) {
  dat |>
    arrange(across(all_of(c(keys, "date")))) |>
    mutate(step = value / lag(value), .by = all_of(keys)) |>
    filter(is.finite(step)) |>
    mutate(
      baseline = median(step[!date %in% .transcribed_months], na.rm = TRUE),
      .by = all_of(c(keys, "mon"))
    ) |>
    filter(date %in% .transcribed_months, !is.na(baseline)) |>
    mutate(dev = step / baseline, material = abs(value - lag(value)) >= 5) |>
    arrange(desc(abs(log(dev))))
}

#' Print the worst offenders from each check.
sanity_2017 <- function(n = 12, threshold = 0.22) {
  stations <- read_stations()
  psg <- read_lines_psg()

  show <- function(x, cols) {
    x <- filter(x, material, abs(log(dev)) >= threshold)
    cli::cli_alert_info("{nrow(x)} cell{?s} past {round(100 * (exp(threshold) - 1))}%.")
    if (nrow(x) > 0) {
      print(as.data.frame(head(select(x, all_of(cols)), n)), row.names = FALSE)
    }
    invisible(x)
  }

  skeys <- c("line", "station")
  lkeys <- c("measure", "metric", "line_number")

  cli::cli_h2("Stations: 2017 vs mean of 2016 and 2018, same month")
  s_yoy <- show(
    check_yoy(stations, skeys),
    c(skeys, "mon", "y2016", "y2017", "y2018", "expected", "dev")
  )

  cli::cli_h2("Stations: +/-6 month profile vs other years")
  s_pm6 <- show(
    check_pm6(stations, skeys),
    c(skeys, "date", "lag6", "value", "lead6", "ratio", "baseline", "dev")
  )

  cli::cli_h2("Stations: month-over-month step vs other years")
  s_mom <- show(check_mom(stations, skeys), c(skeys, "date", "value", "step", "baseline", "dev"))

  cli::cli_h2("Lines: 2017 vs mean of 2016 and 2018, same month")
  l_yoy <- show(
    check_yoy(psg, lkeys),
    c(lkeys, "mon", "y2016", "y2017", "y2018", "expected", "dev")
  )

  invisible(list(s_yoy = s_yoy, s_pm6 = s_pm6, s_mom = s_mom, l_yoy = l_yoy))
}

if (!interactive()) {
  sanity_2017()
}
