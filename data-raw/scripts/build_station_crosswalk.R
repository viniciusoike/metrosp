library(dplyr)
library(readr)
library(sf)
library(stringi)
library(stringr)
library(targets)

tar_source("data-raw/R")

# Bootstrap only. Once committed, station_id values are immutable and the two
# dimensions must be curated rather than regenerated from mutable names.
if (
  file.exists("data-raw/inputs/dim_station.csv") &&
    !identical(Sys.getenv("METROSP_BOOTSTRAP_STATIONS"), "true")
) {
  cli::cli_abort(c(
    "The station crosswalk already exists.",
    "i" = "Edit the committed dimensions to preserve existing station_id values.",
    "i" = "Set METROSP_BOOTSTRAP_STATIONS=true only to rebuild the initial crosswalk from scratch."
  ))
}

slug_station <- function(x) {
  slug <- x |>
    stri_trans_general("Latin-ASCII") |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]+", "-") |>
    str_remove("^-|-$")
  return(slug)
}

stations <- tar_read(stations) |>
  st_transform(31983)

station_rows <- stations |>
  mutate(
    station_id = slug_station(station_name),
    station_id = if_else(
      station_name == "Santo Antônio",
      paste0(station_id, "-", type),
      station_id
    )
  )

codes <- bind_rows(
  tar_read(daily_current) |> select(station_name, station_code),
  tar_read(daily_4_5) |> select(station_name, station_code)
) |>
  filter(!is.na(station_code)) |>
  distinct(station_name, station_code)

dim_station <- station_rows |>
  st_drop_geometry() |>
  select(-any_of("station_code")) |>
  left_join(codes, by = "station_name") |>
  arrange(station_id, nchar(station_name), station_name, station_code) |>
  group_by(station_id) |>
  summarise(
    station_name = first(station_name),
    station_code = first(stats::na.omit(station_code), default = NA_character_),
    code_count = n_distinct(station_code, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    notes = case_when(
      str_detect(
        station_id,
        "santo-antonio-"
      ) ~ "Reviewed split: same name, stations are 12.76 km apart.",
      station_name ==
        "Bonsucesso" ~ "Reviewed merge: same complex; geometry rows span 552 m.",
      station_name ==
        "Brás" ~ "Reviewed merge: same complex; geometry rows span 439 m.",
      code_count >
        1 ~ "Complex has line-specific METRO station codes; primary code retained here.",
      TRUE ~ NA_character_
    )
  ) |>
  select(station_id, station_name, station_code, notes) |>
  arrange(station_id)

source_names <- list(
  metro_historic = tar_read(stations_historic) |>
    transmute(station_name = name_station),
  metro_current_averages = tar_read(averages_current) |> select(station_name),
  metro_current_daily = tar_read(daily_current) |> select(station_name),
  dataverse_averages = tar_read(averages_4_5) |> select(station_name),
  dataverse_daily = tar_read(daily_4_5) |> select(station_name),
  geosampa_metro = station_rows |>
    filter(type == "metro") |>
    st_drop_geometry() |>
    select(station_name, station_id),
  geosampa_train = station_rows |>
    filter(type == "train") |>
    st_drop_geometry() |>
    select(station_name, station_id)
)

aliases <- bind_rows(source_names, .id = "source") |>
  mutate(station_name = strip_footnotes(station_name)) |>
  left_join(
    dim_station |>
      add_count(station_name) |>
      filter(n == 1) |>
      select(station_id_lookup = station_id, station_name),
    by = "station_name"
  ) |>
  mutate(station_id = coalesce(station_id, station_id_lookup)) |>
  select(station_name_raw = station_name, station_id, source) |>
  filter(!is.na(station_id)) |>
  distinct()

alias_path <- "data-raw/inputs/dim_station_alias.csv"
if (file.exists(alias_path)) {
  geometry_aliases <- read_csv(alias_path, show_col_types = FALSE) |>
    filter(source %in% c("geosampa_metro", "geosampa_train")) |>
    select(station_name_raw, station_id, source)
  aliases <- bind_rows(aliases, geometry_aliases) |>
    distinct(source, station_name_raw, .keep_all = TRUE)
}

legacy_aliases <- tibble(
  station_name_raw = c(
    "Carrão-Assaí Atacadista",
    "Penha-Lojas Besni",
    "Saúde-Ultrafarma",
    "Patriarca-Vila Ré",
    "Liberdade",
    "Giovani Gronchi",
    "Santuário N.S. de Fátima-Sumaré"
  ),
  canonical = c(
    "Carrão",
    "Penha",
    "Saúde",
    "Patriarca",
    "Japão-Liberdade",
    "Giovanni Gronchi",
    "Sumaré"
  )
) |>
  tidyr::crossing(
    source = c(
      "metro_historic",
      "metro_current_averages",
      "metro_current_daily"
    )
  ) |>
  left_join(
    dim_station |> select(station_id, canonical = station_name),
    by = "canonical"
  ) |>
  select(station_name_raw, station_id, source)

aliases <- bind_rows(aliases, legacy_aliases) |>
  distinct(source, station_name_raw, .keep_all = TRUE) |>
  mutate(notes = NA_character_) |>
  arrange(source, station_name_raw)

write_csv(dim_station, "data-raw/inputs/dim_station.csv", na = "")
write_csv(aliases, "data-raw/inputs/dim_station_alias.csv", na = "")
