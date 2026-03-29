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
library(dplyr)
library(stringr)

source(here::here("data-raw/utils.R"))

dir_geo <- here::here("data-raw/geosampa")

# --- Helper: standardize company names ----------------------------------------

standardize_company <- function(x) {
  dplyr::replace_values(
    x,
    "METRO" ~ "Metr\u00f4",
    "VIAQUATRO" ~ "ViaQuatro",
    "VIAMOBILIDADE" ~ "ViaMobilidade",
    "LINHAUNI" ~ "Linha Universidade",
    "CPTM" ~ "CPTM"
  )
}

standardize_stations <- function(x) {
  dplyr::replace_values(
    x,
    "Ayrton Senna-Jardim São Paulo" ~ "Jardim São Paulo-Ayrton Senna",
    "Santuário Nossa Senhora De Fátima-Sumaré" ~ "Sumaré",
    "Alto Do Ipiranga" ~ "Alto do Ipiranga",
    "Bresser-Mooca" ~ "Bresser-Moóca",
    "Praça Da Árvore" ~ "Praça da Árvore",
    "Vila Das Belezas" ~ "Vila das Belezas",
    "Pedro Ii" ~ "Pedro II",
    "Alto Da Boa Vista" ~ "Alto da Boa Vista"
  )
}

cols_rename <- c(
  "company_name" = "lmt_empres",
  "company_name" = "lmtp_empre",
  "line_name" = "lmtp_nome",
  "line_full_name" = "lmtp_linom",
  "line_number" = "lmt_linha",
  "station_name" = "emtp_nome",
  "station_name" = "emt_nome",
  "line_name_pt" = "emt_linha",
  "line_name_pt" = "emtp_linha",
  "company_name" = "emt_empres",
  "company_name" = "emtp_empre",
  "line_number" = "nr_linha",
  "line_name_pt" = "nm_linha",
  "company_name" = "empresa",
  "company_name" = "ltp_empres",
  "line_number" = "ltp_linha",
  "line_name_pt" = "ltp_nome",
  "station_name" = "estacao",
  "line_number" = "nr_linha",
  "line_name_pt" = "nm_linha",
  "line_name_pt" = "etp_linha",
  "company_name" = "etp_empres",
  "station_name" = "etp_nome"
)

# Finds the path of the files and names them as current or future based on file name
get_path_files <- function(pat) {
  path_files <- fs::dir_ls(dir_geo, regexp = pat)
  file_names <- basename(path_files)
  names(path_files) <- if_else(
    stringr::str_detect(file_names, "proj"),
    "future",
    "current"
  )
  return(path_files)
}

# Imports the shapefile, converts to 4326 and cleans
import_sf <- function(path) {
  shape <- sf::st_read(path, quiet = TRUE)
  shape <- sf::st_transform(shape, crs = 4326)
  shape <- sf::st_make_valid(shape)

  return(shape)
}

# Generic function to clean both metro lines and train lines
clean_lines <- function(dat) {
  cols_select <- c("company_name", "line_number")
  cols_drop <- c("ltp_nrnome", "ltp_situac")

  clean_dat <- dat |>
    rename(any_of(cols_rename)) |>
    mutate(company_name = standardize_company(company_name))

  # When missing line_number extracts the number from line_full_name
  if (!("line_number" %in% names(clean_dat))) {
    clean_dat <- clean_dat |>
      mutate(
        line_number = as.numeric(stringr::str_extract(line_full_name, "\\d+"))
      )
  }

  # Line number > 90 is stored as exception lines (don't join with dim)
  # ex: line_number = 98 ; expresso aeroporto
  if (all(clean_dat$line_number < 90)) {
    clean_dat <- select(clean_dat, all_of(cols_select))
    clean_dat <- left_join(clean_dat, dim_line, by = "line_number")
  } else {
    clean_dat <- select(clean_dat, -any_of(cols_drop))
    clean_dat <- clean_dat |>
      select(-any_of(cols_drop)) |>
      mutate(line_name_pt = stringr::str_to_title(line_name_pt)) |>
      left_join(dim_line, by = c("line_name_pt", "line_number")) |>
      mutate(type = if_else(is.na(type), "train", type))
  }

  return(clean_dat)
}

# Helper function to clean metro stations
clean_stations <- function(dat, station_code = TRUE) {
  cols_select <- c(
    "company_name",
    "station_name",
    "line_number",
    "line_name",
    "line_name_pt"
  )

  clean_dat <- dat |>
    rename(any_of(cols_rename)) |>
    mutate(
      station_name = str_to_title(station_name),
      station_name = standardize_stations(station_name),
      line_name_pt = str_to_title(line_name_pt),
      line_name_pt = str_replace(line_name_pt, "Lilas", "Lilás"),
      company_name = standardize_company(company_name)
    )

  if ("line_number" %in% names(clean_dat)) {
    cols_join <- c("line_number", "line_name_pt")
  } else {
    cols_join <- c("line_name_pt")
  }
  clean_dat <- left_join(clean_dat, dim_line, by = cols_join)

  if (station_code) {
    clean_dat <- left_join(
      clean_dat,
      bind_rows(dim_station_code, dim_station_lilac),
      by = c("station_name", "line_number")
    )
  }

  clean_dat <- select(clean_dat, all_of(cols_select))

  return(clean_dat)
}


# line_number
# line_name
# line_name_pt

# Lines -------------------------------------------------------------------

## --- Metro lines --------------------------------------------------------------

metro_path <- get_path_files("linhametr.+\\.gpkg$")
metro_lines <- purrr::map(metro_path, import_sf)
metro_lines <- purrr::map(metro_lines, clean_lines)
tab_metro_lines <- bind_rows(metro_lines, .id = "status")

## --- Train lines --------------------------------------------------------------

train_path <- get_path_files("linhatre.+\\.gpkg$")
train_lines <- purrr::map(train_path, import_sf)
train_lines <- purrr::map(train_lines, clean_lines)
tab_train_lines <- bind_rows(train_lines, .id = "status")

lines <- bind_rows(tab_metro_lines, tab_train_lines)


# Stations ----------------------------------------------------------------
## --- Metro stations -----------------------------------------------------------

path_files <- fs::dir_ls(dir_geo, regexp = "estacaometro")
name_files <- basename(path_files)

inds_name_files <- stringr::str_detect(name_files, "proj")

if (length(inds_name_files)) {
  inds_future <- which(stringr::str_detect(name_files, "proj.+[0-9]\\.gpkg"))
  inds_current <- which(stringr::str_detect(name_files, "proj", negate = TRUE))
  inds_name_files <- c("future" = inds_future, "current" = inds_current)
  inds_name_files <- inds_name_files[order(inds_name_files)]
}

path_files <- path_files[inds_name_files]
names(path_files) <- names(inds_name_files)


metro_stations <- purrr::map(path_files, import_sf)
metro_stations <- purrr::map(metro_stations, clean_stations)

tab_metro_stations <- bind_rows(metro_stations, .id = "status")

# --- Train stations -----------------------------------------------------------

st_train_paths <- get_path_files("estacaotrem")

station_trains <- purrr::map(st_train_paths, import_sf)
station_trains <- purrr::map(
  station_trains,
  clean_stations,
  station_code = FALSE
)

tab_train_stations <- bind_rows(station_trains, .id = "status")

stations <- bind_rows(
  list("train" = tab_train_stations, "metro" = tab_metro_stations),
  .id = "type"
)

stations <- stations |>
  arrange(type, line_number, station_name)

# --- Save datasets ------------------------------------------------------------
usethis::use_data(lines, overwrite = TRUE)
usethis::use_data(stations, overwrite = TRUE)
