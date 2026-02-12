# import_geosampa.R
# -------------------------------------------------------
# Imports and cleans GeoSampa spatial data for metro and CPTM train
# networks. Reads GPKG files from data-raw/geosampa/ and produces
# sf datasets saved as .rda files in data/.
#
# Source:  https://geosampa.prefeitura.sp.gov.br/
# Reads:   data-raw/geosampa/SIRGAS_GPKG_*.gpkg (9 files)
# Writes:  data/metro_lines_geo.rda
#          data/metro_stations_geo.rda
#          data/train_lines_geo.rda
#          data/train_stations_geo.rda
#          data/train_lines.rda
#
# All output geometries are in CRS EPSG:4326 (WGS84).
# -------------------------------------------------------

library(sf)
library(dplyr, warn.conflicts = FALSE)
library(stringr)

source(here::here("data-raw/utils.R"))

dir_geo <- here::here("data-raw/geosampa")

# --- Helper: standardize company names ----------------------------------------

standardize_company <- function(x) {
  dplyr::case_match(
    toupper(x),
    "METRO"         ~ "Metr\u00f4",
    "VIAQUATRO"     ~ "ViaQuatro",
    "VIAMOBILIDADE" ~ "ViaMobilidade",
    "LINHAUNI"      ~ "LinhaUni",
    "CPTM"          ~ "CPTM",
    .default = x
  )
}

# --- Metro lines --------------------------------------------------------------

metro_lines_current <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_linhametro.gpkg"), quiet = TRUE
) |>
  transmute(
    line_number = as.integer(lmt_linha),
    company     = standardize_company(lmt_empres),
    status      = "current"
  )

# Future metro lines lack a numeric line_number column; parse from lmtp_linom
# (e.g. "LINHA 15 - PRATA" -> 15)
metro_lines_future <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_linhametroprojeto.gpkg"), quiet = TRUE
) |>
  transmute(
    line_number = as.integer(str_extract(lmtp_linom, "\\d+")),
    company     = standardize_company(lmtp_empre),
    status      = "planned"
  )

metro_lines_geo <- bind_rows(metro_lines_current, metro_lines_future) |>
  left_join(
    dim_line |> select(line_number, line_name_pt, line_name),
    by = "line_number"
  ) |>
  select(line_number, line_name_pt, line_name, company, status) |>
  st_transform(crs = 4326)

# --- Metro stations -----------------------------------------------------------

metro_stations_current <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_estacaometro.gpkg"), quiet = TRUE
) |>
  transmute(
    station_name = str_to_title(emt_nome),
    line_name_pt = str_to_title(emt_linha),
    line_name_pt = str_replace(line_name_pt, "Lilas", "Lil\u00e1s"),
    company      = standardize_company(emt_empres),
    status       = "current"
  )

# Using the -2 variant (more recent, has 142 rows vs 141)
metro_stations_future <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_estacaometroprojeto-2.gpkg"), quiet = TRUE
) |>
  transmute(
    station_name = str_to_title(emtp_nome),
    line_name_pt = str_to_title(emtp_linha),
    line_name_pt = str_replace(line_name_pt, "Lilas", "Lil\u00e1s"),
    company      = standardize_company(emtp_empre),
    status       = "planned"
  )

metro_stations_geo <- bind_rows(metro_stations_current, metro_stations_future) |>
  left_join(
    dim_line |> select(line_number, line_name_pt, line_name),
    by = "line_name_pt"
  ) |>
  select(station_name, line_number, line_name_pt, line_name, company, status) |>
  st_transform(crs = 4326)

# --- Train lines --------------------------------------------------------------

train_lines_current <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_linhatrem.gpkg"), quiet = TRUE
) |>
  transmute(
    line_number  = as.integer(nr_linha),
    line_name_pt = str_to_title(nm_linha),
    company      = standardize_company(empresa),
    status       = "current"
  )

train_lines_future <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_linhatremprojeto.gpkg"), quiet = TRUE
) |>
  transmute(
    line_number  = as.integer(ltp_linha),
    line_name_pt = str_to_title(ltp_nome),
    company      = standardize_company(ltp_empres),
    status       = "planned"
  ) |>
  # Placeholder line numbers (98, 99) -> NA

  mutate(line_number = if_else(line_number %in% c(98L, 99L), NA_integer_, line_number))

train_lines_geo <- bind_rows(train_lines_current, train_lines_future) |>
  left_join(
    dim_train_line |> select(line_number, line_name),
    by = "line_number"
  ) |>
  select(line_number, line_name_pt, line_name, company, status) |>
  st_transform(crs = 4326)

# --- Train stations -----------------------------------------------------------

train_stations_current <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_estacaotrem.gpkg"), quiet = TRUE
) |>
  transmute(
    station_name = str_to_title(estacao),
    line_number  = as.integer(nr_linha),
    line_name_pt = str_to_title(nm_linha),
    company      = standardize_company(empresa),
    status       = "current"
  )

train_stations_future <- st_read(
  file.path(dir_geo, "SIRGAS_GPKG_estacaotremprojeto.gpkg"), quiet = TRUE
) |>
  transmute(
    station_name = str_to_title(etp_nome),
    line_name_pt = str_to_title(etp_linha),
    company      = standardize_company(etp_empres),
    status       = "planned"
  ) |>
  # Get line_number from dim_train_line
  left_join(
    dim_train_line |> select(line_number, line_name_pt),
    by = "line_name_pt"
  )

train_stations_geo <- bind_rows(train_stations_current, train_stations_future) |>
  left_join(
    dim_train_line |> select(line_number, line_name),
    by = "line_number"
  ) |>
  select(station_name, line_number, line_name_pt, line_name, company, status) |>
  st_transform(crs = 4326)

# --- train_lines reference table (non-spatial) --------------------------------

train_lines <- dim_train_line |>
  select(line_number, line_name_pt, line_name)

# --- Save datasets ------------------------------------------------------------

usethis::use_data(metro_lines_geo, overwrite = TRUE)
usethis::use_data(metro_stations_geo, overwrite = TRUE)
usethis::use_data(train_lines_geo, overwrite = TRUE)
usethis::use_data(train_stations_geo, overwrite = TRUE)
usethis::use_data(train_lines, overwrite = TRUE)
