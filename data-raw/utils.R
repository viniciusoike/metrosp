# utils.R
# -------------------------------------------------------
# Shared utility functions and dimension tables used by the ETL scripts.
# Sourced by all import_*.R scripts in data-raw/.
# -------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# --- Path helpers ------------------------------------------------------------

#' Get path to a CSV file for 2020-2025 data.
#'
#' Looks up a CSV file in data-raw/metro_sp/metro/csv/ matching the given
#' year and variable type. The CSV filenames follow a standard naming
#' convention from the METRO transparency portal.
#'
#' @param year Integer year (2020-2025).
#' @param variable One of "stations_daily", "stations", "transport", "entrance".
#' @param datadir Directory containing the raw CSV files.
#' @return Character path to the matching CSV file.
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

  if (length(year) > 0 & !any(year %in% 2020:2025)) {
    cli::cli_abort("Year {year} not available.")
  }

  pat <- var_pattern[variable]
  pat <- paste0(pat, "_", as.character(year))

  path_csv <- list.files(datadir, pattern = "\\.csv$", full.names = TRUE)
  path_csv <- path_csv[stringr::str_detect(path_csv, pat)]

  return(path_csv)
}

#' Get path to files for 2017-2019 data.
#'
#' The 2017-2019 data is organized in nested folders by year and month.
#' This function finds matching CSV files and returns them sorted by month.
#'
#' @param year Integer year (2017-2019).
#' @param variable One of "transport", "entrance", or "daily".
#' @return A tibble with columns `path` (full file path) and `name` (month).
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

# --- Dimension tables --------------------------------------------------------

# Metro line reference table: maps Portuguese/English names to line numbers.
# Line 99 represents the network total ("Sistema METRO").
dim_line <- tibble(
  line_name_pt = c(
    "Azul",
    "Verde",
    "Vermelha",
    "Amarela",
    "Lilás",
    "Laranja",
    "Prata",
    "Violeta",
    "Ouro",
    "Celeste",
    "Rosa",
    "Marrom",
    "Sistema METRÔ"
  ),
  line_name = c(
    "Blue",
    "Green",
    "Red",
    "Yellow",
    "Lilac",
    "Orange",
    "Silver",
    "Violet",
    "Gold",
    "Sky Blue",
    "Pink",
    "Brown",
    "METRÔ System"
  ),
  line_number = c(1L, 2L, 3L, 4L, 5L, 6L, 15L, 16L, 17L, 19L, 20L, 22L, 99L)
)

# CPTM train line reference table: maps Portuguese/English names to line numbers.
dim_train_line <- tibble(
  line_name_pt = c(
    "Rubi",
    "Diamante",
    "Esmeralda",
    "Turquesa",
    "Coral",
    "Safira",
    "Jade",
    "Onix"
  ),
  line_name = c(
    "Ruby",
    "Diamond",
    "Emerald",
    "Turquoise",
    "Coral",
    "Sapphire",
    "Jade",
    "Onyx"
  ),
  line_number = c(7L, 8L, 9L, 10L, 11L, 12L, 13L, 14L)
)

# Stations that were renamed (original short name -> current full name).
dim_station_name_change <- tibble(
  station_name = c("Carrão", "Penha", "Saúde", "Patriarca"),
  station_name_full = c(
    "Carrão-Assaí Atacadista",
    "Penha-Lojas Besni",
    "Saúde-Ultrafarma",
    "Patriarca-Vila Ré"
  )
)

# Metric categories used in passenger data.
# Abbreviations: total, mdu (weekday avg), msa (Saturday avg),
# mdo (Sunday avg), max (daily maximum).
dim_metric <- tibble(
  metric_abb = c("total", "mdu", "msa", "mdo", "max"),
  metric = c(
    "Total",
    "Média dos Dias Úteis",
    "Média dos Sábados",
    "Média dos Domingos",
    "Máxima Diária"
  )
)

# --- Utility functions -------------------------------------------------------

#' Convert Portuguese-formatted numbers to numeric.
#'
#' Portuguese uses "." as a thousands separator (e.g., "1.234" = 1234).
#' This function removes the dots and converts to numeric.
as_numeric_pt <- Vectorize(function(x) {
  if (is.character(x)) {
    as.numeric(gsub("\\.", "", x))
  }
})

# --- Passenger CSV import functions ------------------------------------------
# Used by import_passengers_entrance.R and import_passengers_transported.R
# to read and clean the 2020-2025 passenger data by line.

#' Read a raw passenger CSV file for 2020-2025.
#'
#' Each file contains 3 sections (batches) for different line groups,
#' read separately with different skip rows and bound by column.
#'
#' @param path Path to the raw CSV file.
#' @param year Integer year (affects skip offsets; 2025 differs from others).
#' @return A wide data frame with one row per month.
read_csv_passengers <- function(path, year = 2020) {
  skip <- c(6, 25, 45)
  if (year == 2025) {
    skip <- c(7, 23, 39)
  }

  metric_names <- c("month", "total", "mdu", "msa", "mdo", "max")
  line_names <- c("azul", "verde", "vermelha", "prata", "rede")
  comb_names <- paste(rep(line_names, each = 6), metric_names, sep = "_")

  col_names <- list(
    c1 = c(comb_names[1:6], "drop_col", comb_names[7:12]),
    c2 = c(comb_names[13:18], "drop_col", comb_names[19:24]),
    c3 = comb_names[25:30]
  )

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
      # Experimental: try to remove warnings
      #col_types = readr::cols(.default = readr::col_character()),
      #name_repair = janitor::make_clean_names,
      show_col_types = FALSE
    )
  }

  # Remove empty columns and bind by column
  parcels <- purrr::map(parcels, \(dat) select(dat, where(~ !all(is.na(.x)))))
  dat <- bind_cols(parcels)
  return(dat)
}

#' Clean a wide passenger data frame into long tidy format.
#'
#' Pivots the wide data from read_csv_passengers() to long format,
#' separates line and metric columns, and joins dimension tables.
#'
#' @param dat Wide data frame from read_csv_passengers().
#' @param year Integer year for date construction.
#' @return A tidy data frame with columns: date, line_number, metric_abb,
#'   metric, value, year.
clean_csv_passengers <- function(dat, year = 2020) {
  dim_line <- dim_line |>
    mutate(
      line = tolower(line_name_pt)
    )

  clean_dat <- dat |>
    select(-matches("month$")) |>
    mutate(month = month.abb) |>
    tidyr::pivot_longer(cols = -month, values_transform = as.numeric) |>
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
