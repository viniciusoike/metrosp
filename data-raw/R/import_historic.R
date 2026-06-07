# import_historic.R
# -----------------------------------------------------------------------------
# Gated refresh of the 2017-2019 historical processed CSVs from the raw nested
# monthly folders (data-raw/metro_sp/metro/{2017,2018,demanda_2019}/). These
# rarely change, so the committed CSVs in data-raw/processed/ are the normal
# pipeline input (read by assemble_*). refresh_historic_*() regenerate them.
#
# Refactored from import_passengers_2017_2019.R and
# import_station_averages_2017_2019.R.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(stringr)

# --- Passengers (entrance + transported) 2017-2019 ---------------------------

.read_psg_line <- function(path, force_names = FALSE) {
  encoding <- ifelse(
    stringr::str_detect(path, "Junho - 2018"),
    "UTF-8",
    "Latin-1"
  )

  skip <- case_when(
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Out") &
      stringr::str_detect(path, "Transporta") ~ 5,
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Out") &
      stringr::str_detect(path, "Entrada") ~ 4,
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Nov") &
      stringr::str_detect(path, "Entrada") ~ 4,
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Nov") &
      stringr::str_detect(path, "Transporta") ~ 2,
    stringr::str_detect(path, "2017") & stringr::str_detect(path, "Dez") ~ 4,
    TRUE ~ 4
  )

  dat <- data.table::fread(
    path,
    skip = skip,
    nrows = 5,
    na.strings = c("-", "0<b3>", "0\xb3"),
    encoding = encoding,
    colClasses = "character"
  )

  if (force_names) {
    col_names <- c(
      "demanda_milhares",
      "linha_1_azul",
      "linha_2_verde",
      "linha_3_vermelha",
      "linha_5_lilas",
      "linha_15_prata",
      "rede"
    )

    if (ncol(dat) == 16) {
      data.table::setnames(dat, names(dat)[1:7], col_names)
    } else {
      data.table::setnames(dat, names(dat)[1:6], col_names[-5])
    }
  } else {
    dat <- janitor::clean_names(dat)
  }

  dat <- as_tibble(dat)

  return(dat)
}

.clean_psg_line <- function(dat) {
  cols_rename <- c(
    "linha_5_lilas" = "linha_5_lilas2"
  )

  clean_dat <- dat |>
    rename(any_of(cols_rename)) |>
    filter(!if_all(2:last_col(), ~ . == "")) |>
    mutate(across(2:last_col(), as_numeric_pt)) |>
    select(where(~ !all(is.na(.x))))

  return(clean_dat)
}

.stack_passengers <- function(ls, year = 2018, unite = TRUE) {
  x <- c(
    "Total",
    "Média dos Dias Úteis",
    "Média dos Sábados",
    "Média dos Domingos",
    "Máxima Diária"
  )
  tbl <- bind_rows(ls, .id = "month")

  if (year == 2017) {
    tbl <- tbl |>
      filter(!is.na(linha_1_azul)) |>
      distinct() |>
      mutate(year = local(year)) |>
      rename(variable = demanda_milhares) |>
      pivot_longer(
        cols = -c(variable, year, month),
        names_to = "metro_line",
        values_transform = as.numeric
      )
  } else {
    tbl <- tbl |>
      filter(!is.na(linha_1_azul)) |>
      distinct() |>
      mutate(variable = rep(x, 12), year = year) |>
      select(-demanda_milhares) |>
      pivot_longer(
        cols = -c(variable, year, month),
        names_to = "metro_line",
        values_transform = as.numeric
      )
  }

  tbl <- tbl |>
    mutate(
      date = glue::glue("{year}-{month}-01"),
      date = readr::parse_date(date, format = "%Y-%B-%d", locale = readr::locale("pt"))
    ) |>
    select(date, year, variable, metro_line, value)

  return(tbl)
}

.import_psg_line <- function(year, variable = "transport") {
  valid_vars <- c("transport", "entrance")

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  df_path <- get_path_flds(year, variable)

  if (nrow(df_path) == 0) {
    cli::cli_abort("No paths found. Check basedir.")
  }

  files_psg_line <- purrr::map(df_path$path, \(p) {
    psg_line <- .read_psg_line(p)
    psg_line <- .clean_psg_line(psg_line)
    return(psg_line)
  })

  files_psg_line <- rlang::set_names(files_psg_line, df_path$name)
  .stack_passengers(files_psg_line, year = year)
}

#' Regenerate metro_sp_passengers_2017_2019.csv from raw. Returns the path.
refresh_historic_passengers <- function(
  proc_dir = here::here("data-raw/processed")
) {
  passengers_line <- expand_grid(
    year = 2017:2019,
    measure = c("entrance", "transport")
  ) |>
    mutate(dat = purrr::pmap(list(year, measure), .import_psg_line)) |>
    unnest(cols = dat, names_repair = janitor::make_clean_names) |>
    select(-year_2)

  passengers_line <- passengers_line |>
    mutate(
      line_number = as.numeric(str_extract(metro_line, "[0-9]{1,2}")),
      line_number = if_else(is.na(line_number), 99L, line_number)
    ) |>
    select(-metro_line) |>
    left_join(dim_line, by = join_by(line_number))

  out <- file.path(proc_dir, "metro_sp_passengers_2017_2019.csv")
  readr::write_csv(passengers_line, out)
  cli::cli_alert_success("Wrote {.path {out}}.")
  invisible(out)
}

# --- Station averages 2017-2019 ----------------------------------------------

.read_clean_stn_avg <- function(path) {
  rawfile <- readr::read_lines(path)

  i_stop <- which(str_detect(rawfile, "TOTAL"))

  skip <- 5

  enc <- ifelse(
    str_detect(path, "(Junho - 2018)|(Julho - 2018)"),
    "UTF-8",
    "ISO-8859-1"
  )

  dat <- readr::read_csv2(
    path,
    skip = skip,
    locale = readr::locale(encoding = enc),
    name_repair = janitor::make_clean_names,
    na = c("- ", "-", " - "),
    n_max = i_stop - skip - 2,
    col_types = readr::cols(.default = readr::col_character())
  )

  names(dat)[1:2] <- c("estacao_1", "entradas_1")

  header <- readr::read_csv2(
    path,
    skip = skip - 1,
    n_max = 1,
    col_names = FALSE,
    locale = readr::locale(encoding = enc),
    name_repair = janitor::make_clean_names,
    col_types = readr::cols(.default = readr::col_character())
  )

  header <- unlist(header)
  header <- header[which(header != "NA")]

  df_code <- tibble(
    code = as.character(seq_along(header)),
    line_name_full = header
  )

  clean_dat <- dat |>
    mutate(across(starts_with("entradas"), as.numeric)) |>
    pivot_longer(
      everything(),
      cols_vary = "slowest",
      names_to = c(".value", "code"),
      names_pattern = "(.*)_(.*)",
      values_drop_na = TRUE
    ) |>
    filter(!is.na(entradas)) |>
    left_join(df_code, by = join_by(code)) |>
    mutate(
      name_station = str_remove(estacao, " *\\([0-9¹²³*]*\\)|\\s*[0-9¹²³*]+$"),
      name_station = str_squish(name_station),
      metric_abb = "mdu"
    ) |>
    select(line_name_full, name_station, metric_abb, value = entradas)

  return(clean_dat)
}

.import_stn_avg <- function(year) {
  df_path <- get_path_flds(year = year, variable = "daily")

  dat <- purrr::map(df_path$path, \(x) suppressMessages(.read_clean_stn_avg(x)))
  dat <- rlang::set_names(dat, df_path$name)
  dat <- bind_rows(dat, .id = "month")

  dat <- dat |>
    mutate(
      year = local(year),
      date = readr::parse_date(
        glue::glue("{year}-{month}-01"),
        format = "%Y-%B-%d",
        locale = readr::locale("pt")
      )
    )

  return(dat)
}

#' Regenerate metro_sp_station_averages_2017_2019.csv from raw. Returns the path.
refresh_historic_averages <- function(
  proc_dir = here::here("data-raw/processed")
) {
  years <- 2017:2019
  stations_files <- lapply(years, .import_stn_avg)
  stations_files <- rlang::set_names(stations_files, years)

  avg_psg_station <- bind_rows(stations_files, .id = "year") |>
    select(date, year, month, line_name_full, name_station, metric_abb, value)

  out <- file.path(proc_dir, "metro_sp_station_averages_2017_2019.csv")
  readr::write_csv(avg_psg_station, out)
  cli::cli_alert_success("Wrote {.path {out}}.")
  invisible(out)
}
