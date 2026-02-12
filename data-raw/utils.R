library(dplyr, warn.conflicts = FALSE)

get_path_csv <- function(
  year = 2020,
  variable = "stations",
  datadir = here::here("data-raw/metro_sp/metro/csv")
) {
  # Check variable argument
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
  # Check year argument
  if (length(year) > 0 & !any(year %in% 2020:2025)) {
    cli::cli_abort("Year {year} not available.")
  }

  pat <- var_pattern[variable]
  pat <- paste0(pat, "_", as.character(year))

  path_csv <- list.files(datadir, pattern = "\\.csv$", full.names = TRUE)
  path_csv <- path_csv[stringr::str_detect(path_csv, pat)]

  return(path_csv)
}

# Dimension table with name/numbers of each line
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

# Dimension table with some stations that changed name
dim_station_name_change <- tibble(
  station_name = c("Carrão", "Penha", "Saúde", "Patriarca"),
  station_name_full = c(
    "Carrão-Assaí Atacadista",
    "Penha-Lojas Besni",
    "Saúde-Ultrafarma",
    "Patriarca-Vila Ré"
  )
)

# Dimension table with metric categories
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

as_numeric_pt <- Vectorize(function(x) {
  if (is.character(x)) {
    as.numeric(gsub("\\.", "", x))
  }
})


#' Get path to files for 2017-2019
#'
#' @param year Year
#' @param variable One of "transport", "entrance", or "daily"
#' @noRd
get_path_flds <- function(year, variable = "transport") {
  valid_vars <- c("transport", "entrance", "daily")

  if (length(variable) != 1) {
    cli::cli_abort("Argument {.arg variable} must be a length 1 string.")
  }

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  fld <- case_when(
    year == 2017 ~ "2017",
    year == 2018 ~ "2018",
    year == 2019 ~ "demanda_2019",
    year == 2020 ~ "demanda_2020"
  )

  path_files <- list.files(
    here(stringr::str_glue("data-raw/metro_sp/metro/{fld}")),
    pattern = "\\.csv$",
    recursive = TRUE,
    full.names = TRUE
  )

  # fmt: skip
  mes <- c("Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
           "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  )

  pat <- case_when(
    variable == "transport" ~ "Transportados por Linha",
    variable == "entrance" ~ "Passageiros por Linha",
    variable == "daily" ~ "Dias"
  )

  path <- path_files[str_detect(path_files, pat)]

  if (variable == "daily") {
    path <- path[str_detect(path, "Esta")]
  }

  df_line <- tibble(
    path = path
  )

  df_line <- df_line |>
    mutate(
      name = stringr::str_extract(path, paste(mes, collapse = "|")),
      name = if_else(is.na(name), "Março", name),
      name = factor(name, levels = mes)
    ) |>
    arrange(name)

  return(df_line)
}
