# import_historic.R
# -----------------------------------------------------------------------------
# Gated refresh of the 2016-2019 historical processed CSVs from the raw files
# (data-raw/metro_sp/metro/{Demanda 2016,2017,2018,demanda_2019}/). These
# rarely change, so the committed CSVs in data-raw/processed/ are the normal
# pipeline input (read by assemble_*). refresh_historic_*() regenerate them.
#
# 2016 was published retroactively by METRO in 2026 as annual files that
# follow the current-era layout, not the 2017-2019 monthly one; see the
# "2016 retroactive publication" section below.
#
# Refactored from import_passengers_2017_2019.R and
# import_station_averages_2017_2019.R.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(stringr)

# --- Passengers by line, monthly files (2017-2019) ---------------------------
# One file per month and measure. Each holds a single block: the five metrics in
# rows, the lines in columns. The block opens with "DEMANDA (milhares);" and
# that row also names the lines it carries, which is what makes the reader
# independent of both the header height (it drifted across 2017) and the line
# roster (Line 5 leaves after Aug 2018).

#' Encoding of one raw monthly file. Two 2018 exports are UTF-8; the rest are
#' Latin-1.
psg_month_encoding <- function(path) {
  if (stringr::str_detect(path, "Junho - 2018")) "UTF-8" else "ISO-8859-1"
}

#' Read one monthly passenger-by-line file into a wide frame.
#' Columns are the metric label plus one column per line, named by line_number.
read_psg_month <- function(path) {
  enc <- psg_month_encoding(path)
  raw_lines <- readr::read_lines(
    path,
    locale = readr::locale(encoding = enc),
    progress = FALSE
  )

  header_row <- grep("^DEMANDA", raw_lines)

  if (length(header_row) != 1) {
    cli::cli_abort(c(
      "Malformed monthly passenger file {.path {path}}.",
      "x" = "Found {length(header_row)} {.val DEMANDA} header row{?s}, expected 1."
    ))
  }

  labels <- split_line_labels(raw_lines[header_row])

  dat <- readr::read_delim(
    path,
    delim = ";",
    skip = header_row,
    n_max = nrow(dim_metric),
    col_names = FALSE,
    # "0³" is a published zero carrying a footnote marker (Line 15 ran no
    # Sunday service in Feb and Mar 2018). The pipeline has always read it as
    # missing rather than as zero; keep that until the choice is revisited.
    na = c("", "0³"),
    col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = enc),
    show_col_types = FALSE
  )

  # Trailing padding columns carry no header label.
  dat <- dat[, seq_along(labels)]
  names(dat) <- c("metric_label", label_line_number(labels[-1]))

  dat
}

#' Reshape one monthly frame to long form: metric_abb, line_number, value.
clean_psg_month <- function(dat) {
  clean_dat <- dat |>
    mutate(metric_abb = map_metric(metric_label)) |>
    select(-metric_label)

  if (anyNA(clean_dat$metric_abb)) {
    unknown <- dat$metric_label[is.na(clean_dat$metric_abb)]
    cli::cli_abort("Unrecognized metric label{?s}: {.val {unknown}}.")
  }

  clean_dat |>
    pivot_longer(
      -metric_abb,
      names_to = "line_number",
      names_transform = as.integer,
      values_to = "value",
      values_transform = as_numeric_pt
    )
}

#' Import one year of monthly files for one measure.
#' Schema: date, line_number, metric_abb, value.
import_psg_line_monthly <- function(year, variable = "transport") {
  df_path <- get_path_flds(year, variable)

  if (nrow(df_path) == 0) {
    cli::cli_abort("No paths found for {variable} in {year}. Check basedir.")
  }

  purrr::map(df_path$path, \(p) clean_psg_month(read_psg_month(p))) |>
    rlang::set_names(as.character(df_path$name)) |>
    bind_rows(.id = "month_name") |>
    add_month_date(year)
}

#' Attach a first-of-month date from a Portuguese month name.
add_month_date <- function(dat, year) {
  dat |>
    left_join(dim_month, by = join_by(month_name)) |>
    mutate(date = as.Date(paste(local(year), month_num, "01", sep = "-"))) |>
    select(-month_name, -month_num, -month_abb)
}

# --- 2016 retroactive publication ---------------------------------------------
# METRO began publishing pre-2017 data retroactively in 2026, one annual file
# per measure in data-raw/metro_sp/metro/Demanda 2016/. Those files follow the
# current-era annual layout, so read_psg_line()/read_stn_avg() handle them
# unchanged -- including the fact that 2016 still reports Line 5 (Lilás), which
# the header-driven readers pick up on their own.

#' Locate one of the annual 2016 raw CSVs by pattern.
path_2016 <- function(pattern) {
  dir <- here::here("data-raw/metro_sp/metro/Demanda 2016")
  path <- list.files(dir, pattern = "\\.csv$", full.names = TRUE)
  path <- path[stringr::str_detect(path, pattern)]

  if (length(path) != 1) {
    cli::cli_abort("Expected 1 file matching {pattern} in {.path {dir}}.")
  }

  path
}

#' Import one 2016 line-level measure, shaped like import_psg_line_monthly().
import_psg_line_2016 <- function(variable = "transport") {
  pattern <- psg_file_pattern(variable)

  clean_psg_line(read_psg_line(path_2016(pattern)), year = 2016) |>
    select(date, line_number, metric_abb, value)
}

#' Raw-file name pattern for a measure.
psg_file_pattern <- function(variable) {
  patterns <- c(
    transport = "Transportados por Linha",
    entrance = "Entrada de Passageiros por Linha"
  )

  if (!variable %in% names(patterns)) {
    cli::cli_abort(
      "Invalid input {variable}. Valid values: {names(patterns)}"
    )
  }

  unname(patterns[[variable]])
}

# --- Jan-Sep 2017, transcribed from PDF ---------------------------------------
# METRO published Jan-Sep 2017 only as PDFs whose pages are pasted screenshots
# with no text layer, so those months were transcribed by hand into
# data-raw/pdf2017/. See data-raw/pdf2017/README.md for the procedure and
# report_2017.md for the source defects the checksums exposed. The transcribed
# CSVs are committed and are the input here; the PDFs themselves are not read.

path_pdf2017 <- function(file) {
  path <- here::here("data-raw/pdf2017", file)

  if (!file.exists(path)) {
    cli::cli_abort("Missing transcription {.path {path}}.")
  }

  path
}

#' Import one Jan-Sep 2017 line-level measure, shaped like
#' import_psg_line_monthly().
import_psg_line_2017_pdf <- function(variable = "transport") {
  valid_vars <- c("transport", "entrance")

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  readr::read_csv(
    path_pdf2017("transcribed_passengers_line_2017.csv"),
    show_col_types = FALSE
  ) |>
    filter(measure == variable) |>
    select(-measure) |>
    pivot_longer(
      cols = -c(date, metric),
      names_to = "line_label",
      values_to = "value"
    ) |>
    mutate(
      metric_abb = map_metric(metric),
      line_number = label_line_number(line_label)
    ) |>
    select(date, line_number, metric_abb, value)
}

#' Import Jan-Sep 2017 station averages, shaped like import_stn_avg_monthly().
import_stn_avg_2017_pdf <- function() {
  readr::read_csv(
    path_pdf2017("transcribed_station_averages_2017.csv"),
    show_col_types = FALSE
  ) |>
    filter(station != "TOTAL") |>
    pivot_longer(
      cols = -c(line, station),
      names_to = "year_month",
      values_to = "value"
    ) |>
    mutate(
      date = as.Date(paste0(year_month, "-01")),
      year = 2017,
      month = dim_month$month_name[as.integer(format(date, "%m"))],
      line_name_full = line,
      name_station = strip_footnotes(station),
      metric_abb = "mdu"
    ) |>
    select(all_of(.cols_stn_avg_historic))
}

#' Regenerate metro_sp_passengers_historic.csv from raw. Returns the path.
#'
#' Every branch below returns the same four columns (date, line_number,
#' metric_abb, value), so the eras differ only in where the numbers come from.
refresh_historic_passengers <- function(
  proc_dir = here::here("data-raw/processed")
) {
  import_year <- function(year, measure) {
    if (year == 2016) {
      import_psg_line_2016(variable = measure)
    } else if (year == 2017) {
      bind_rows(
        import_psg_line_2017_pdf(variable = measure),
        import_psg_line_monthly(year, variable = measure)
      )
    } else {
      import_psg_line_monthly(year, variable = measure)
    }
  }

  passengers_line <- expand_grid(
    year = 2016:2019,
    measure = c("entrance", "transport")
  ) |>
    mutate(dat = purrr::map2(year, measure, import_year)) |>
    unnest(cols = dat)

  passengers_line <- passengers_line |>
    # The published label varies in case between files; go through metric_abb
    # so the committed CSV carries one spelling.
    left_join(
      select(dim_metric, metric_abb, variable = metric_pt),
      by = join_by(metric_abb)
    ) |>
    left_join(dim_line, by = join_by(line_number)) |>
    select(
      year,
      measure,
      date,
      variable,
      value,
      line_number,
      type,
      line_name_pt,
      line_name
    )

  out <- file.path(proc_dir, "metro_sp_passengers_historic.csv")
  readr::write_csv(passengers_line, out)
  cli::cli_alert_success("Wrote {.path {out}}.")
  invisible(out)
}

# --- Station averages, monthly files (2017-2019) ------------------------------
# One file per month. Lines sit side by side as (Estação, Entradas) pairs under
# a row that names them, and the block closes on a TOTAL row. Both the line
# roster and the block height are read from the file.

#' Encoding of one raw monthly station file. Two 2018 exports are UTF-8.
stn_avg_month_encoding <- function(path) {
  if (str_detect(path, "(Junho - 2018)|(Julho - 2018)")) "UTF-8" else "ISO-8859-1"
}

#' Read one monthly station-averages file into a wide frame of side-by-side
#' (estacao_N, entradas_N) column pairs, with the line labels attached.
read_stn_avg_month <- function(path) {
  enc <- stn_avg_month_encoding(path)
  raw_lines <- readr::read_lines(
    path,
    locale = readr::locale(encoding = enc),
    progress = FALSE
  )

  label_row <- grep("^Linha 1", raw_lines)[1]
  total_row <- grep("TOTAL", raw_lines)[1]

  if (is.na(label_row) || is.na(total_row)) {
    cli::cli_abort(c(
      "Malformed monthly station-averages file {.path {path}}.",
      "x" = "Could not locate the line-label row and the TOTAL row."
    ))
  }

  dat <- readr::read_csv2(
    path,
    # Skip past the label row so "Estação;Entradas;..." names the columns, and
    # stop one row short of TOTAL.
    skip = label_row,
    n_max = total_row - label_row - 2,
    locale = readr::locale(encoding = enc),
    name_repair = janitor::make_clean_names,
    na = c("- ", "-", " - "),
    col_types = readr::cols(.default = readr::col_character())
  )

  # make_clean_names() leaves the first pair unsuffixed.
  names(dat)[1:2] <- c("estacao_1", "entradas_1")

  labels <- split_line_labels(raw_lines[label_row])
  attr(dat, "line_labels") <- labels

  dat
}

#' Reshape one monthly station frame into long form.
clean_stn_avg_month <- function(dat) {
  df_code <- tibble(
    code = as.character(seq_along(attr(dat, "line_labels"))),
    line_name_full = attr(dat, "line_labels")
  )

  dat |>
    pivot_longer(
      everything(),
      cols_vary = "slowest",
      names_to = c(".value", "code"),
      names_pattern = "(.*)_(.*)",
      values_drop_na = TRUE
    ) |>
    mutate(entradas = as_numeric_pt(entradas)) |>
    filter(!is.na(entradas)) |>
    left_join(df_code, by = join_by(code)) |>
    mutate(
      name_station = strip_footnotes(estacao),
      metric_abb = "mdu"
    ) |>
    select(line_name_full, name_station, metric_abb, value = entradas)
}

#' Import one year of monthly station-averages files (2017-2019).
import_stn_avg_monthly <- function(year) {
  df_path <- get_path_flds(year = year, variable = "daily")

  purrr::map(df_path$path, \(p) {
    suppressMessages(clean_stn_avg_month(read_stn_avg_month(p)))
  }) |>
    rlang::set_names(as.character(df_path$name)) |>
    bind_rows(.id = "month") |>
    left_join(dim_month, by = join_by(month == month_name)) |>
    mutate(date = as.Date(paste(local(year), month_num, "01", sep = "-"))) |>
    mutate(year = local(year)) |>
    select(all_of(.cols_stn_avg_historic))
}

#' Import 2016 station averages from the annual file.
#'
#' The 2016 file follows the current-era annual layout, so read_stn_avg() does
#' the parsing; this only maps the result onto the historic long schema.
import_stn_avg_2016 <- function() {
  clean_stn_avg(read_stn_avg(path_2016("Esta")), year = 2016) |>
    left_join(select(dim_line, line_number, line_name_full), by = "line_number") |>
    mutate(
      month = dim_month$month_name[as.integer(format(date, "%m"))],
      name_station = station_name,
      metric_abb = "mdu",
      value = avg_passenger
    ) |>
    select(all_of(.cols_stn_avg_historic))
}

#' Regenerate metro_sp_station_averages_historic.csv from raw. Returns the path.
refresh_historic_averages <- function(
  proc_dir = here::here("data-raw/processed")
) {
  years <- 2017:2019
  stations_files <- rlang::set_names(
    lapply(years, import_stn_avg_monthly),
    years
  )
  # Jan-Sep 2017 exists only as the hand transcription; Oct-Dec comes from the
  # monthly files.
  stations_files[["2017"]] <- bind_rows(
    import_stn_avg_2017_pdf(),
    stations_files[["2017"]]
  )

  avg_psg_station <- bind_rows(
    c(list(import_stn_avg_2016()), stations_files)
  ) |>
    select(all_of(.cols_stn_avg_historic))

  out <- file.path(proc_dir, "metro_sp_station_averages_historic.csv")
  readr::write_csv(avg_psg_station, out)
  cli::cli_alert_success("Wrote {.path {out}}.")
  invisible(out)
}
