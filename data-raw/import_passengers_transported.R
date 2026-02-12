library(dplyr)
library(readr)
source(here::here("data-raw/utils.R"))

import_passengers_transported <- function(year = 2020) {
  path <- get_path_csv(year, "transport")
  dat <- read_csv_passengers(path)
  clean_dat <- clean_csv_passengers(dat, year = year)
  return(clean_dat)
}

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
      show_col_types = FALSE
    )
  }

  # Remove empty columns and bind by column
  parcels <- purrr::map(parcels, \(dat) select(dat, where(~ !all(is.na(.x)))))
  dat <- bind_cols(parcels)
  return(dat)
}

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

grid_year <- 2020:2025
safe_import_passengers <- purrr::safely(import_passengers_transported)
passengers <- purrr::map(grid_year, safe_import_passengers)
n_errors <- sum(sapply(passengers, \(x) !is.null(x$error)))

if (n_errors == 0) {
  passengers <- purrr::map(passengers, \(x) x$result)
  passengers <- dplyr::bind_rows(passengers)
  readr::write_csv(
    passengers,
    here::here(
      "data-raw/processed/metro_sp_passengers_tranported_2020_2025.csv"
    )
  )
}
