# import_metro_current.R
# -----------------------------------------------------------------------------
# Builder functions for current-era (2020-present) METRO data (Lines 1, 2, 3,
# 15), read from the raw transparency-portal CSVs in
# data-raw/metro_sp/metro/csv/ (gitignored).
#
# Each build_*_current() returns an in-memory tibble. refresh_metro_current() is
# the gated side-effecting step that writes them to the committed processed CSVs
# (data-raw/outputs/processed/metro_sp_*_current.csv), which the assemble_*() functions
# then read -- mirroring refresh_historic_*() and refresh_dataverse(). This is
# what makes the graph rebuildable offline and gives every upstream change a
# reviewable text diff.
#
# Refactored from the former current-era passenger and station importers.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# --- Passengers entrance / transported by line -------------------------------

import_psg_line_current <- function(year, variable) {
  path <- get_path_csv(year, variable)
  clean_psg_line(read_psg_line(path), year = year)
}

#' Build current-era passengers entrance (2020-present).
#' Schema: date, line_number, metric_abb, metric, value, year.
build_entrance_current <- function(years = get_available_years("entrance")) {
  purrr::map(years, \(y) import_psg_line_current(y, "entrance")) |>
    dplyr::bind_rows()
}

#' Build current-era passengers transported (2020-present).
build_transported_current <- function(
  years = get_available_years("transport")
) {
  purrr::map(years, \(y) import_psg_line_current(y, "transport")) |>
    dplyr::bind_rows()
}

# --- Station averages (weekday) by station -----------------------------------

import_stn_avg_current <- function(
  year = 2020,
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  path <- get_path_csv(variable = "stations", year = year, datadir = datadir)

  if (length(path) == 0) {
    cli::cli_abort("No station-averages CSV found for {year}.")
  }

  clean_stn_avg(read_stn_avg(path), year = year)
}

#' Build current-era station averages (2020-present), lines 1/2/3/15.
#' Schema: date, line_number, station_name, avg_passenger, year.
build_stn_avg_current <- function(years = get_available_years("stations")) {
  purrr::map(years, import_stn_avg_current) |>
    dplyr::bind_rows()
}

# --- Station daily entries ----------------------------------------------------
# One block per month, holding the four lines side by side: days in rows,
# station codes in columns, each block closed by a TOTAL column and separated by
# an empty padding column. The block's title row names the lines it contains
# ("ENTRADAS POR ESTAÇÃO - LINHA 1-AZUL - JAN/2024"), so the left-to-right line
# order is read from the file rather than assumed.

#' Split one month's wide frame at its empty padding columns.
#' make_clean_names() renames those to "x", "x_2", ...
split_stn_daily_blocks <- function(dat) {
  pads <- which(grepl("^x(_\\d+)?$", names(dat)))

  starts <- c(1L, pads + 1L)
  ends <- c(pads - 1L, ncol(dat))

  keep <- starts <= ends
  purrr::map2(starts[keep], ends[keep], \(i, j) dat[, i:j, drop = FALSE])
}

#' Reshape one line's day-by-station block into long form.
clean_stn_daily_block <- function(dat, line_number, year, month_num) {
  names(dat)[1] <- "day"

  dat |>
    # The trailing TOTAL column is the line's own sum, not a station.
    dplyr::select(-dplyr::matches("^total(_\\d+)?$")) |>
    dplyr::mutate(day = as.integer(gsub("\\*", "", day))) |>
    tidyr::pivot_longer(
      cols = -day,
      names_to = "station_code",
      values_to = "passengers",
      values_transform = as_numeric_pt
    ) |>
    dplyr::mutate(
      # Repeated codes (Ana Rosa, Paraíso, Sé) are suffixed by make_clean_names.
      station_code = gsub("_\\d+$", "", trimws(station_code)),
      line_number = line_number,
      year = year,
      date = as.Date(paste(year, month_num, day, sep = "-"))
    )
}

clean_stn_daily <- function(parcels, year) {
  long <- purrr::map(parcels, \(dat) {
    blocks <- split_stn_daily_blocks(dat)
    lines <- attr(dat, "line_numbers")
    month_num <- attr(dat, "month_num")

    if (length(blocks) != length(lines)) {
      cli::cli_abort(c(
        "Daily block layout does not match its title row ({month.abb[month_num]}/{year}).",
        "x" = "Title row names {length(lines)} line{?s} but the data splits into {length(blocks)} block{?s}."
      ))
    }

    purrr::pmap(
      list(blocks, lines),
      \(block, line_number) {
        clean_stn_daily_block(block, line_number, year, month_num)
      }
    )
  })

  dplyr::bind_rows(long) |>
    dplyr::left_join(dim_station_code, by = c("station_code", "line_number")) |>
    dplyr::filter(!is.na(passengers), !is.na(date)) |>
    dplyr::select(dplyr::all_of(.cols_stn_daily)) |>
    dplyr::arrange(date, line_number, station_code)
}

import_stn_daily_current <- function(year = 2020) {
  path <- get_path_csv(year = year, variable = "stations_daily")
  if (length(path) == 0) {
    cli::cli_abort("No daily station CSV found for year {year}.")
  }

  raw_lines <- readLines(path, encoding = "latin1")
  header_rows <- grep("^DIA;", raw_lines)

  parcels <- list()

  for (month in seq_along(header_rows)) {
    if (month > nrow(dim_month)) {
      break
    }

    dat <- tryCatch(
      readr::read_delim(
        path,
        delim = ";",
        skip = header_rows[month] - 1L,
        n_max = n_days_in_month(year, month),
        na = c("- ", "-", " - ", ""),
        col_types = readr::cols(.default = readr::col_character()),
        locale = readr::locale(encoding = "ISO-8859-1"),
        show_col_types = FALSE,
        name_repair = janitor::make_clean_names
      ),
      error = function(e) NULL
    )

    if (is.null(dat) || nrow(dat) == 0) {
      next
    }

    attr(dat, "month_num") <- month
    attr(dat, "line_numbers") <- label_line_number(
      split_line_labels(raw_lines[header_rows[month] - 1L])
    )
    parcels[[length(parcels) + 1]] <- dat
  }

  clean_stn_daily(parcels, year = year)
}

#' Build current-era daily station entries (2020-present), lines 1/2/3/15.
#' Schema: date, year, line_number, station_code, station_name, passengers.
build_stn_daily_current <- function(
  years = get_available_years("stations_daily")
) {
  safe_import <- purrr::safely(import_stn_daily_current)
  results <- purrr::map(years, safe_import)

  errors <- purrr::map(results, "error")
  n_errors <- sum(!sapply(errors, is.null))

  if (n_errors > 0) {
    for (i in seq_along(errors)) {
      if (!is.null(errors[[i]])) {
        cli::cli_warn("Year {years[i]}: {errors[[i]]$message}")
      }
    }
  }

  dplyr::bind_rows(purrr::map(results, "result"))
}

# --- Service (oferta) by line -------------------------------------------------
# A separate portal dataset (/dataset/oferta), one file per year from 2021. Two
# stacked blocks, each a title row naming the measure and its unit, a header row
# ("Mês;Linha 1-Azul ;...") and twelve month rows. Unpublished months are empty
# rows. The rows above the first block vary between files, so blocks are found
# by their titles.

# The lines METRO operates and publishes service for. A file without all of
# them, or without both metrics, is a layout change, not a data gap.
.service_lines <- c(1L, 2L, 3L, 15L)
.service_metrics <- c("headway", "speed")

#' Map a service block title to its metric, checking the unit it states.
service_metric <- function(title) {
  title <- stringi::stri_trans_general(title, "Latin-ASCII")
  metric <- dplyr::case_when(
    grepl("^Intervalo minimo entre trens \\(segundos\\)", title) ~ "headway",
    grepl("^Velocidade comercial \\(km/h\\)", title, ignore.case = TRUE) ~
      "speed"
  )
  if (anyNA(metric)) {
    cli::cli_abort(
      "Unrecognized service block{?s}: {.val {title[is.na(metric)]}}."
    )
  }
  metric
}

#' Read a raw annual service CSV into one wide frame: one row per month and
#' block, one column per line, tagged with the block's metric.
read_service <- function(path) {
  raw_lines <- readLines(path, encoding = "latin1")
  titles <- grep("^(Intervalo|Velocidade)", raw_lines)

  if (length(titles) == 0L) {
    cli::cli_abort("No service blocks found in {.path {path}}.")
  }

  metrics <- service_metric(stringr::str_remove(raw_lines[titles], ";.*$"))
  if (!setequal(metrics, .service_metrics) || anyDuplicated(metrics)) {
    cli::cli_abort(c(
      "Service file {.path {path}} must hold one block per metric.",
      "i" = "Expected {.val {(.service_metrics)}}.",
      "x" = "Found {.val {metrics}}."
    ))
  }

  blocks <- purrr::map2(titles, metrics, \(row, metric) {
    lines <- label_line_number(split_line_labels(raw_lines[row + 1L])[-1])
    missing <- setdiff(.service_lines, lines)
    if (length(missing) > 0) {
      cli::cli_abort(
        "Service block {.val {metric}} in {.path {path}} lacks line{?s} {.val {missing}}."
      )
    }
    body <- raw_lines[row + 1L + seq_len(nrow(dim_month))]
    cells <- stringr::str_split_fixed(body, ";", length(lines) + 2L)

    months <- stringr::str_squish(stringr::str_remove(cells[, 1], "\\*"))
    if (!identical(months, dim_month$month_abb)) {
      cli::cli_abort(c(
        "Service block {.val {metric}} in {.path {path}} does not hold twelve month rows.",
        "x" = "Found {.val {months}}."
      ))
    }

    out <- tibble::as_tibble(
      cells[, seq_len(length(lines) + 1L), drop = FALSE],
      .name_repair = "minimal"
    )
    names(out) <- c("month_abb", lines)
    # Drop the "*" footnote markers ("Jan*") the 2021-2022 files carry.
    out$month_abb <- months
    dplyr::mutate(out, metric = metric, .before = 1)
  })

  dplyr::bind_rows(blocks)
}

#' Reshape a wide annual service frame into the long import schema.
clean_service <- function(dat, year) {
  dat |>
    tidyr::pivot_longer(
      -c(metric, month_abb),
      names_to = "line_number",
      names_transform = as.integer,
      values_to = "value",
      values_transform = as_numeric_pt
    ) |>
    dplyr::left_join(dim_month, by = dplyr::join_by(month_abb)) |>
    dplyr::mutate(
      year = as.integer(local(year)),
      date = as.Date(paste(year, month_num, "01", sep = "-"))
    ) |>
    dplyr::select(dplyr::all_of(.cols_service)) |>
    dplyr::arrange(date, line_number, metric)
}

import_service_current <- function(year) {
  path <- get_path_csv(year, "service")
  if (length(path) != 1L) {
    cli::cli_abort("Expected one service CSV for {year}, found {length(path)}.")
  }
  clean_service(read_service(path), year = year)
}

#' Build current-era service by line (2021-present), lines 1/2/3/15.
#' Schema: date, year, line_number, metric, value.
build_service_current <- function(years = get_available_years("service")) {
  purrr::map(years, import_service_current) |>
    dplyr::bind_rows()
}

# --- Gated refresh: rewrite the committed current-era processed CSVs ----------

# Filenames carry no year range: the current era is open-ended, and a hardcoded
# range would need renaming every January in an unattended pipeline. This also
# matches the `import_{dataset}` (no period suffix) script convention.
.current_csv_names <- c(
  entrance = "metro_sp_passengers_entrance_current.csv",
  transported = "metro_sp_passengers_transported_current.csv",
  averages = "metro_sp_station_averages_current.csv",
  daily = "metro_sp_station_daily_current.csv",
  service = "metro_sp_service_current.csv"
)

#' Rebuild the five current-era processed CSVs from the raw portal files.
#' Returns the path of the directory written (so a target can depend on it).
refresh_metro_current <- function(
  proc_dir = here::here("data-raw/outputs/processed")
) {
  readr::write_csv(
    build_entrance_current(),
    file.path(proc_dir, .current_csv_names[["entrance"]])
  )
  readr::write_csv(
    build_transported_current(),
    file.path(proc_dir, .current_csv_names[["transported"]])
  )
  readr::write_csv(
    build_stn_avg_current(),
    file.path(proc_dir, .current_csv_names[["averages"]])
  )
  readr::write_csv(
    build_stn_daily_current(),
    file.path(proc_dir, .current_csv_names[["daily"]])
  )
  readr::write_csv(
    build_service_current(),
    file.path(proc_dir, .current_csv_names[["service"]])
  )

  cli::cli_alert_success("Current-era CSVs refreshed in {.path {proc_dir}}.")
  invisible(proc_dir)
}
