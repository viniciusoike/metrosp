# import_geosampa.R
# -----------------------------------------------------------------------------
# GeoSampa spatial data for the metro and CPTM train networks.
# build_geosampa() reads the GPKG files in data-raw/geosampa/ and returns a
# list(lines = <sf>, stations = <sf>), both in EPSG:4326. No .rda side effects.
#
# Refactored from import_geosampa.R (the usethis::use_data() tail moved to the
# write_all_data() writer target).
#
# Source: https://geosampa.prefeitura.sp.gov.br/
# -----------------------------------------------------------------------------

library(sf)
library(dplyr, warn.conflicts = FALSE)
library(stringr)

standardize_company <- function(x) {
  dplyr::replace_values(
    x,
    "METRO" ~ "Metrô",
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

.cols_rename_geo <- c(
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

# Finds file paths and names them current/future based on file name.
.geo_path_files <- function(pat, dir_geo) {
  path_files <- list.files(dir_geo, pattern = pat, full.names = TRUE)
  file_names <- basename(path_files)
  names(path_files) <- if_else(
    stringr::str_detect(file_names, "proj"),
    "future",
    "current"
  )
  return(path_files)
}

# Imports a shapefile, converts to 4326, cleans geometry.
.geo_import_sf <- function(path) {
  shape <- sf::st_read(path, quiet = TRUE)
  shape <- sf::st_transform(shape, crs = 4326)
  shape <- sf::st_make_valid(shape)
  return(shape)
}

# Generic cleaner for both metro lines and train lines.
.geo_clean_lines <- function(dat) {
  cols_select <- c("company_name", "line_number")
  cols_drop <- c("ltp_nrnome", "ltp_situac")

  clean_dat <- dat |>
    rename(any_of(.cols_rename_geo)) |>
    mutate(company_name = standardize_company(company_name))

  if (!("line_number" %in% names(clean_dat))) {
    clean_dat <- clean_dat |>
      mutate(
        line_number = as.numeric(stringr::str_extract(line_full_name, "\\d+"))
      )
  }

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

# Cleaner for metro/train stations.
.geo_clean_stations <- function(dat, station_code = TRUE) {
  cols_select <- c(
    "company_name",
    "station_name",
    "line_number",
    "line_name",
    "line_name_pt"
  )

  clean_dat <- dat |>
    rename(any_of(.cols_rename_geo)) |>
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

#' Build the spatial datasets from GeoSampa GPKGs.
#' @param geosampa_files Character vector of GPKG paths (or the directory).
#' @return list(lines = <sf>, stations = <sf>).
build_geosampa <- function(
  geosampa_files = here::here("data-raw/geosampa")
) {
  dir_geo <- if (length(geosampa_files) == 1 && dir.exists(geosampa_files)) {
    geosampa_files
  } else {
    unique(dirname(geosampa_files))
  }

  # --- Lines ---
  metro_path <- .geo_path_files("linhametr.+\\.gpkg$", dir_geo)
  metro_lines <- purrr::map(metro_path, .geo_import_sf)
  metro_lines <- purrr::map(metro_lines, .geo_clean_lines)
  tab_metro_lines <- bind_rows(metro_lines, .id = "status")

  train_path <- .geo_path_files("linhatre.+\\.gpkg$", dir_geo)
  train_lines <- purrr::map(train_path, .geo_import_sf)
  train_lines <- purrr::map(train_lines, .geo_clean_lines)
  tab_train_lines <- bind_rows(train_lines, .id = "status")

  lines <- bind_rows(tab_metro_lines, tab_train_lines)

  # --- Metro stations (custom current/future ordering) ---
  path_files <- list.files(dir_geo, pattern = "estacaometro", full.names = TRUE)
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

  metro_stations <- purrr::map(path_files, .geo_import_sf)
  metro_stations <- purrr::map(metro_stations, .geo_clean_stations)
  tab_metro_stations <- bind_rows(metro_stations, .id = "status")

  # --- Train stations ---
  st_train_paths <- .geo_path_files("estacaotrem", dir_geo)
  station_trains <- purrr::map(st_train_paths, .geo_import_sf)
  station_trains <- purrr::map(
    station_trains,
    .geo_clean_stations,
    station_code = FALSE
  )
  tab_train_stations <- bind_rows(station_trains, .id = "status")

  stations <- bind_rows(
    list("train" = tab_train_stations, "metro" = tab_metro_stations),
    .id = "type"
  )

  stations <- stations |>
    arrange(type, line_number, station_name)

  list(lines = lines, stations = stations)
}
