library(dataverse)
library(dplyr)
library(here)
library(bizdays)
import::from(tidyr, pivot_longer)

source(here("data-raw/utils.R"))

# Data Import -------------------------------------------------------------

dv <- "dataverse.datascience.insper.edu.br"

dois <- c(
  "media_embarques_diarios" = "10.60873/FK2/BPYHFB",
  "embarques_diarios" = "doi:10.60873/FK2/UTGQ0I",
  "embarques_horarios" = "doi:10.60873/FK2/9MZGJL"
)

file_names <- c(
  "emb_media.rds",
  "emb_diarios.rds",
  "emb_horarios.rds"
)

get_from_dataverse <- function(
  doi,
  file_name,
  server = "dataverse.datascience.insper.edu.br"
) {
  dataset <- get_dataframe_by_name(
    file_name,
    dataset = doi,
    server = server,
    original = TRUE,
    .f = readr::read_rds
  )

  return(dataset)
}

datasets <- purrr::map2(dois, file_names, get_from_dataverse)

dim_bus <- tibble(
  business_unit = c(
    "ViaMobilidade - Linha 5",
    "ViaQuatro"
  ),
  line_name_pt = c("Lilás", "Amarela"),
  line_number = c(5L, 4L),
  line_name = c("Lilac", "Yellow")
)

dim_convert_metric <- tibble(
  tipo_dia = c("Dias Úteis", "Sábado", "Domingo"),
  metric_abb = c("mdu", "msa", "mdo"),
  metric = c("Média dos Dias Úteis", "Média dos Sábados", "Média dos Domingos")
)

valid_bus <- c("ViaMobilidade - Linha 5", "ViaQuatro")

embarques_media <- datasets$media_embarques_diarios

tab_medias <- embarques_media |>
  filter(business_unit %in% valid_bus) |>
  rename(date = data, year = ano, value = embarques_diarios_media) |>
  select(date, business_unit, tipo_dia, value, year)

tab_medias <- left_join(tab_medias, dim_bus, by = join_by(business_unit))
tab_medias <- left_join(tab_medias, dim_convert_metric, by = join_by(tipo_dia))

tab_medias <- tab_medias |>
  select(
    date,
    line_number,
    metric_abb,
    value,
    metric,
    line_name,
    line_name_pt,
    year
  )

diarios <- datasets$embarques_diarios

sel_cols <- c(
  "date",
  "line_number",
  "metric_abb",
  "value",
  "metric",
  "line_name",
  "line_name_pt",
  "year"
)

tab_embarques_diarios <- diarios |>
  filter(business_unit %in% valid_bus, tipo_embarque == "Bloqueio") |>
  rename(value = embarques) |>
  left_join(dim_bus, by = join_by(business_unit)) |>
  mutate(
    ano = lubridate::year(data),
    mes = lubridate::month(data),
    dia_semana = lubridate::wday(data),
    is_business_day = as.integer(is.bizday(data, cal = "Brazil/ANBIMA"))
  ) |>
  summarise(
    total = sum(value, na.rm = TRUE),
    msa = mean(value[dia_semana == 6], na.rm = TRUE),
    mdo = mean(value[dia_semana == 7], na.rm = TRUE),
    mdu = mean(value[is_business_day == 1], na.rm = TRUE),
    max = max(value, na.rm = TRUE),
    .by = c(ano, mes, line_number, line_name, line_name_pt)
  ) |>
  tidyr::pivot_longer(
    cols = c("total", "msa", "mdo", "mdu", "max"),
    names_to = "metric_abb",
    values_to = "value"
  ) |>
  left_join(dim_metric, by = join_by(metric_abb)) |>
  mutate(date = lubridate::make_date(ano, mes, 1)) |>
  rename(year = ano) |>
  select(all_of(sel_cols))


