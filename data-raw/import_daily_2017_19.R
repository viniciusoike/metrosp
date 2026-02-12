library(dplyr)
library(stringr)
import::from(here, here)
import::from(tidyr, pivot_longer)
source(here::here("data-raw/utils.R"))

read_clean_stn_avg <- function(path) {
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
    col_types = cols(.default = col_character())
  )

  names(dat)[1:2] <- c("estacao_1", "entradas_1")

  header <- readr::read_csv2(
    path,
    skip = skip - 1,
    n_max = 1,
    col_names = FALSE,
    locale = readr::locale(encoding = enc),
    name_repair = janitor::make_clean_names,
    col_types = cols(.default = col_character())
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
    # OBS: careful with this line. Assumes conversion to numeric is perfect
    filter(!is.na(entradas)) |>
    left_join(df_code, by = join_by(code)) |>
    mutate(
      name_station = str_remove(estacao, "¹|2|²|³|\\*"),
      name_station = str_remove(name_station, "[0-9]$"),
      metric_abb = "mdu"
    ) |>
    select(line_name_full, name_station, metric_abb, value = entradas)

  return(clean_dat)
}

import_stn_avg <- function(year) {
  # Get paths
  df_path <- get_path_flds(year = year, variable = "daily")

  cli::cli_alert_info("Number of files: {nrow(df_path)}")

  # ls <- list()

  # for (i in 1:nrow(df_path)) {
  #   dat <- read_clean_stn_avg(df_path$path[i])
  # }

  # Import data
  dat <- purrr::map(df_path$path, \(x) suppressMessages(read_clean_stn_avg(x)))
  dat <- rlang::set_names(dat, df_path$name)
  dat <- dplyr::bind_rows(dat, .id = "month")

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

avg_psg_station_years <- 2017:2019
stations_files <- lapply(avg_psg_station_years, import_stn_avg)
stations_files <- rlang::set_names(stations_files, avg_psg_station_years)

avg_psg_station <- bind_rows(stations_files, .id = "year")

avg_psg_station <- avg_psg_station |>
  select(date, year, month, line_name_full, name_station, metric_abb, value)

readr::write_csv(
  avg_psg_station,
  "data-raw/processed/metro_sp_stations_averages_2017_2019.csv"
)

# library(ggplot2)

# avg_psg_station |>
#   filter(name_station == "Luz") |>
#   ggplot(aes(date, value)) +
#   geom_line()

# avg_psg_station |>
#   count(name_station, sort = TRUE)

# avg_psg_station |>
#   filter(is.na(name_station))

# # Count NAs per row across all columns
# avg_psg_station |>
#   summarise(across(everything(), ~ sum(is.na(.x))))

# df_path <- get_path_flds(year = 2018, variable = "daily")

# df_path$path[7] |>
#   readr::read_csv2(
#     skip = 5,
#     locale = readr::locale(encoding = "UTF-8"),
#     name_repair = janitor::make_clean_names,
#     na = c("- ", "-", " - "),
#     n_max = 10,
#   )
