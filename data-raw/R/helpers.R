# helpers.R
# -----------------------------------------------------------------------------
# Path lookup, CSV parsing, and numeric-conversion helpers used by the import
# builders. Lifted verbatim from the former data-raw/utils.R (and the
# n_days_in_month helper from import_station_daily.R).
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# --- Path helpers ------------------------------------------------------------

#' List years available in the raw CSV directory.
get_available_years <- function(
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  files <- list.files(datadir, pattern = "\\.csv$")
  years <- suppressWarnings(as.integer(stringr::str_extract(files, "\\d{4}")))
  sort(unique(years[!is.na(years) & years >= 2020]))
}

#' Get path to a CSV file for current-era (2020-present) data.
get_path_csv <- function(
  year = 2020,
  variable = "stations",
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  var_pattern <- c(
    "stations_daily" = "estacao_diaria",
    "stations" = "estacao_media_dias_uteis",
    "transport" = "transportados_por_linha",
    "entrance" = "passageiros_por_linha"
  )

  available_variables <- names(var_pattern)

  if (!variable %in% available_variables) {
    cli::cli_abort("Variable {variable} not available.")
  }

  valid_years <- get_available_years(datadir)
  if (
    length(year) > 0 && length(valid_years) > 0 && !any(year %in% valid_years)
  ) {
    cli::cli_abort(
      "Year {year} not available. Valid years: {min(valid_years)}-{max(valid_years)}."
    )
  }

  pat <- var_pattern[variable]
  pat <- paste0(pat, "_", as.character(year))

  path_csv <- list.files(datadir, pattern = "\\.csv$", full.names = TRUE)
  path_csv <- path_csv[stringr::str_detect(path_csv, pat)]

  return(path_csv)
}

#' Get path to files for 2017-2019 data (nested folders by year/month).
get_path_flds <- function(year, variable = "transport") {
  valid_vars <- c("transport", "entrance", "daily")

  if (length(variable) != 1) {
    cli::cli_abort("Argument {.arg variable} must be a length 1 string.")
  }

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  # Each year uses a different folder name
  fld <- case_when(
    year == 2017 ~ "2017",
    year == 2018 ~ "2018",
    year == 2019 ~ "demanda_2019",
    year == 2020 ~ "demanda_2020"
  )

  path_files <- list.files(
    here::here(stringr::str_glue("data-raw/metro_sp/metro/{fld}")),
    pattern = "\\.csv$",
    recursive = TRUE,
    full.names = TRUE
  )

  # Portuguese month names for sorting
  # fmt: skip
  mes <- c("Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
           "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  )

  # Match file paths by variable type
  pat <- case_when(
    variable == "transport" ~ "Transportados por Linha",
    variable == "entrance" ~ "Passageiros por Linha",
    variable == "daily" ~ "Dias"
  )

  path <- path_files[stringr::str_detect(path_files, pat)]

  # For daily data, further filter to station-level files
  if (variable == "daily") {
    path <- path[stringr::str_detect(path, "Esta")]
  }

  df_line <- tibble(path = path) |>
    mutate(
      name = stringr::str_extract(path, paste(mes, collapse = "|")),
      name = if_else(is.na(name), "Março", name),
      name = factor(name, levels = mes)
    ) |>
    arrange(name)

  return(df_line)
}

#' Number of days in a given month/year (from import_station_daily.R).
n_days_in_month <- function(year, month) {
  next_first <- if (month == 12L) {
    as.Date(paste(year + 1L, 1L, 1L, sep = "-"))
  } else {
    as.Date(paste(year, month + 1L, 1L, sep = "-"))
  }
  as.integer(next_first - as.Date(paste(year, month, 1L, sep = "-")))
}

# --- Numeric conversion ------------------------------------------------------

#' Convert Portuguese-formatted numbers to numeric ("1.234" = 1234).
as_numeric_pt <- Vectorize(function(x) {
  if (is.character(x)) {
    y <- as.numeric(gsub("\\.", "", x))
  }
  return(y)
})

# --- Current-era passenger CSV import (entrance + transported) ---------------

#' Read a raw passenger CSV file (2020-present).
read_csv_passengers <- function(path, year = 2020) {
  get_skip <- function(year) {
    .skip <- list(
      "default" = c(6, 25, 45),
      `2025` = c(6, 22, 38),
      `2026` = c(7, 23, 39)
    )

    if (as.character(year) %in% names(.skip)) {
      offset <- .skip[[as.character(year)]]
    } else {
      offset <- .skip[["default"]]
    }

    return(offset)
  }

  metric_names <- c("month", "total", "mdu", "msa", "mdo", "max")
  line_names <- c("azul", "verde", "vermelha", "prata", "rede")
  comb_names <- paste(rep(line_names, each = 6), metric_names, sep = "_")

  col_names <- list(
    c1 = c(comb_names[1:6], "drop_col", comb_names[7:12]),
    c2 = c(comb_names[13:18], "drop_col", comb_names[19:24]),
    c3 = comb_names[25:30]
  )

  skip <- get_skip(year)

  parcels <- list()

  for (i in 1:3) {
    parcels[[i]] <- readr::read_delim(
      path,
      delim = ";",
      skip = skip[i],
      n_max = 12,
      na = c("- ", "-", " - "),
      locale = readr::locale(encoding = "ISO-8859-1", grouping_mark = "."),
      col_names = col_names[[i]],
      col_types = readr::cols(.default = readr::col_character()),
      name_repair = janitor::make_clean_names,
      show_col_types = FALSE
    )
  }

  # Replace empty strings with NAs and drop columns with all NAs
  parcels <- purrr::map(parcels, \(dat) {
    d <- dat |>
      mutate(across(where(is.character), ~ replace_values(.x, "" ~ NA))) |>
      select(where(~ !all(is.na(.x))))

    return(d)
  })

  dat <- bind_cols(parcels)
  return(dat)
}

#' Clean a wide passenger data frame into long tidy format.
clean_csv_passengers <- function(dat, year = 2020) {
  dim_line <- dim_line |>
    mutate(
      line = tolower(line_name_pt)
    )

  clean_dat <- dat |>
    select(-matches("month$")) |>
    mutate(month = month.abb) |>
    tidyr::pivot_longer(cols = -month, values_transform = as_numeric_pt) |>
    tidyr::separate(name, into = c("line", "metric_abb"), sep = "_") |>
    mutate(
      year = local(year),
      date = readr::parse_date(
        glue::glue("{year}-{month}-01"),
        format = "%Y-%b-%d"
      )
    )

  clean_dat <- clean_dat |>
    left_join(dim_metric, by = join_by(metric_abb)) |>
    left_join(dim_line, by = join_by(line)) |>
    mutate(
      # as_numeric_pt is Vectorize()d and carries element names; drop them so
      # the assembled `value` column matches the old CSV round-trip output.
      value = unname(value)
    ) |>
    select(
      date,
      line_number,
      metric_abb,
      metric,
      value,
      year
    )

  return(clean_dat)
}
