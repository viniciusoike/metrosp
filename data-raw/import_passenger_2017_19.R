# import_passenger_2017_19.R
# -------------------------------------------------------
# Imports passenger data by metro line (2017-2019): both entrance and
# transported measures.
# Reads from: data-raw/metro_sp/metro/{2017,2018,demanda_2019}/**/*.csv
# Writes to:  data-raw/processed/metro_sp_passengers_2017_2019.csv
#
# Data quirks:
# - 2017 CSVs have inconsistent skip rows per file (handled in read_psg_line)
# - June 2018 uses UTF-8 encoding; all others use Latin-1
# - Line 5 (Lilas) column name varies: "linha_5_lilas" vs "linha_5_lilas2"
# - 2017 format differs from 2018-2019 in how metric labels are stored
# - Contains both "entrance" and "transport" measures in a single output
# -------------------------------------------------------

library(dplyr)
library(stringr)

import::from(purrr, map, pmap, safely)
import::from(data.table, fread)
import::from(here, here)
import::from(tidyr, pivot_longer)
import::from(janitor, clean_names, make_clean_names)
import::from(lubridate, month)
source(here("data-raw/utils.R"))

# 2017-2019 ----------------------------------------------------------------

## Passageiros transportados por linha -------------------------------------

import_psg_line <- function(year, variable = "transport") {
  valid_vars <- c("transport", "entrance")

  if (length(variable) != 1) {
    cli::cli_abort("Argument {.arg variable} must be a length 1 string.")
  }

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  df_path <- get_path_flds(year, variable)

  if (nrow(df_path) == 0) {
    cli::cli_abort("No paths found. Check basedir.")
  }

  files_psg_line <- purrr::map(df_path$path, \(p) {
    psg_line <- read_psg_line(p)
    psg_line <- clean_psg_line(psg_line)
    return(psg_line)
  })

  if (length(files_psg_line) != length(df_path$name)) {
    cli::cli_abort("Failed to import data.")
  }

  files_psg_line <- rlang::set_names(files_psg_line, df_path$name)
  psg_line <- stack_passengers(files_psg_line, year = year)

  return(psg_line)
}

read_psg_line <- function(path, force_names = FALSE) {
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

clean_psg_line <- function(dat) {
  as_numeric_pt <- Vectorize(function(x) {
    if (is.character(x)) {
      as.numeric(gsub("\\.", "", x))
    }
  })

  cols_rename <- c(
    "linha_5_lilas" = "linha_5_lilas2"
  )

  clean_dat <- dat |>
    rename(any_of(cols_rename)) |>
    # Remove lines where all values are missing
    filter(!if_all(2:last_col(), ~ . == "")) |>
    # Extract only first 5 lines (might not work always)
    # slice(1:5) |>
    # Convert numbers
    mutate(across(2:last_col(), as_numeric_pt)) |>
    # Remove columns where all values are missing
    select(where(~ !all(is.na(.x))))

  # dat <- dat |>
  #   mutate(across(2:last_col(), as_numeric_pt)) |>
  #   select(where(~!all(is.na(.x))))

  return(clean_dat)
}

stack_passengers <- function(ls, year = 2018, unite = TRUE) {
  x <- c(
    "Total",
    "Média dos dias úteis",
    "Média dos Sábados",
    "Média dos Domingos",
    "Máxima Diária"
  )
  #> Stack tables
  tbl <- bind_rows(ls, .id = "month")

  # if (unite) {
  #   col_names <- names(tbl)
  #   unite_cols <- col_names[str_detect(col_names, "^linha_5_lil")]
  #
  #   if (length(unite_cols) == 0) {
  #     warning("No columns to unite found.")
  #   } else {
  #     tbl <- tbl |>
  #       unite(
  #         "linha_5_lilas",
  #         all_of(unite_cols),
  #         na.rm = TRUE
  #       )
  #   }
  # }

  #> Manually replace the 'demanda_milhares' column and convert to long

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

  #> Parse date and select columns
  tbl <- tbl |>
    mutate(
      date = glue::glue("{year}-{month}-01"),
      date = parse_date(date, format = "%Y-%B-%d", locale = locale("pt"))
    ) |>
    select(date, year, variable, metro_line, value)

  return(tbl)
}


passengers_line <- expand_grid(
  year = 2017:2019,
  measure = c("entrance", "transport")
)

passengers_line <- passengers_line |>
  mutate(dat = pmap(list(year, measure), import_psg_line)) |>
  unnest(cols = dat, names_repair = janitor::make_clean_names) |>
  select(-year_2)

d1 <- passengers_line |>
  filter(metro_line == "rede", variable == "Total") |>
  select(date, measure, value) |>
  arrange(date, measure)

d2 <- passengers_line |>
  filter(metro_line != "rede", variable == "Total") |>
  summarise(
    total = sum(value, na.rm = TRUE),
    .by = c("date", "measure")
  ) |>
  arrange(date, measure)

passengers_line <- passengers_line |>
  mutate(
    line_number = as.numeric(str_extract(metro_line, "[0-9]{1,2}")),
    line_number = if_else(is.na(line_number), 99L, line_number)
  ) |>
  select(-metro_line) |>
  left_join(dim_line, by = join_by(line_number))

write_csv(
  passengers_line,
  "data-raw/processed/metro_sp_passengers_2017_2019.csv"
)

# library(insperplot)
#
#
# passengers_line |>
#   count(variable, measure, metro_line) |>
#   filter(n < 27)
#
# passengers_line |>
#   filter(variable == "Total", measure == "entrance", metro_line != "rede") |>
#   ggplot(aes(date, value)) +
#   geom_line(lwd = 0.8, color = insperplot::get_insper_colors("reds3")) +
#   geom_hline(yintercept = 0) +
#   geom_smooth(se = FALSE, color = insperplot::get_insper_colors("oranges2")) +
#   facet_wrap(vars(metro_line), scales = "free_y") +
#   theme_insper()
