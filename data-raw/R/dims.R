# dims.R
# -----------------------------------------------------------------------------
# Dimension tables and shared column constants for the targets pipeline.
#
# These are defined as top-level objects (not inside a function) so that
# `targets::tar_source("data-raw/R")` loads them as tracked globals: editing
# any table re-hashes it and invalidates every target that depends on it.
#
# Lifted verbatim from the former data-raw/utils.R (dimension tables) and
# data-raw/make_datasets.R (metro_lines, metro_colors, column constants).
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)

# --- Line dimension tables ---------------------------------------------------

# Metro line reference table: maps Portuguese/English names to line numbers.
# Line 99 represents the network total ("Sistema METRO").
dim_metro_line <- tibble(
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
    "Sistema METRO"
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
    "METRO System"
  ),
  line_number = c(1L, 2L, 3L, 4L, 5L, 6L, 15L, 16L, 17L, 19L, 20L, 22L, 99L)
)

# CPTM train line reference table: maps Portuguese/English names to line numbers.
dim_train_line <- tibble(
  line_name_pt = c(
    "Rubi",
    "Diamante",
    "Esmeralda",
    "Turquesa",
    "Coral",
    "Safira",
    "Jade",
    "Onix"
  ),
  line_name = c(
    "Ruby",
    "Diamond",
    "Emerald",
    "Turquoise",
    "Coral",
    "Sapphire",
    "Jade",
    "Onyx"
  ),
  line_number = c(7L, 8L, 9L, 10L, 11L, 12L, 13L, 14L)
)

dim_line <- bind_rows(
  list("metro" = dim_metro_line, "train" = dim_train_line),
  .id = "type"
)

# line_name_full is the label the raw METRO files print above each block
# ("Linha 1 - Azul"). Building it here gives every reader and assemble_averages()
# one lookup instead of a private copy each. Line 99 is the network total and
# never appears under that label, so it gets NA.
dim_line <- dim_line |>
  mutate(
    line_name_full = if_else(
      line_number == 99L,
      NA_character_,
      paste0("Linha ", line_number, " - ", line_name_pt)
    )
  )

# Station-name canonicalization (source variant -> published canonical name).
# Sponsor / commercial names are collapsed BACK to the plain station name so
# published demand data never carries a sponsor: both eras of each station map
# to the short canonical name. "Liberdade" is the lone honorific rename (not
# commercial) and instead maps forward to its current official name.
dim_station_name_change <- tibble(
  station_name_raw = c(
    "Carrão-Assaí Atacadista",
    "Penha-Lojas Besni",
    "Saúde-Ultrafarma",
    "Patriarca-Vila Ré",
    "Liberdade",
    "Giovani Gronchi"
  ),
  station_name = c(
    "Carrão",
    "Penha",
    "Saúde",
    "Patriarca",
    "Japão-Liberdade",
    "Giovanni Gronchi"
  )
)

# Metric categories used in passenger data.
# Abbreviations: total, mdu (weekday avg), msa (Saturday avg),
# mdo (Sunday avg), max (daily maximum).
dim_metric <- tibble(
  metric_abb = c("total", "mdu", "msa", "mdo", "max"),
  metric = c(
    "Total",
    "Average on Business Days",
    "Average on Saturdays",
    "Average on Sundays",
    "Daily Peak"
  ),
  metric_pt = c(
    "Total",
    "Média dos Dias Úteis",
    "Média dos Sábados",
    "Média dos Domingos",
    "Máxima Diária"
  )
)

# Map the Portuguese metric label printed in the raw files to its abbreviation.
# Keys are accent-stripped ASCII on purpose. R stores the names of a named
# vector in the native encoding, so accented keys parsed under a non-UTF-8
# LC_CTYPE stop matching the UTF-8 strings readr returns, and every metric
# label silently becomes NA. Normalizing both sides with stringi keeps the
# lookup locale-independent. The source also varies the casing between files
# ("Média dos dias úteis" / "Média dos Dias Úteis"), which this absorbs.
.metric_map_keys <- c(
  "total" = "total",
  "media dos dias uteis" = "mdu",
  "media dos sabados" = "msa",
  "media dos domingos" = "mdo",
  "maxima diaria" = "max"
)

map_metric <- function(x) {
  key <- stringi::stri_trans_general(trimws(x), "Latin-ASCII")
  unname(.metric_map_keys[stringi::stri_trans_tolower(key)])
}

# Month dimension. The raw files key months three ways -- by number, by the
# abbreviation in a column header ("Jan"), and by the full name in a folder or
# file name ("Janeiro") -- so all three live side by side and are joined, never
# indexed positionally.
dim_month <- tibble(
  month_num = 1:12,
  month_abb = c(
    "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
    "Jul", "Ago", "Set", "Out", "Nov", "Dez"
  ),
  month_name = c(
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
  )
)

# Station code lookup: maps 3-letter abbreviations used in the daily
# passenger CSVs to full station names and line numbers.
# fmt: skip
dim_station_code <- tibble(
  station_code = c(
    # Line 1 - Azul (23 stations, south to north)
    "jab", "con", "jud", "sau", "arv", "scz", "vmn", "anr", "pso",
    "vgo", "jqm", "lib", "pse", "bto", "luz", "trd", "ppq", "tte",
    "cdu", "san", "jpa", "pig", "tuc",
    # Line 2 - Verde (14 stations, east to west)
    "vpt", "tti", "sac", "aip", "img", "ckb", "anr", "pso",
    "bgd", "tri", "cns", "cli", "sum", "vmd",
    # Line 3 - Vermelha (18 stations, east to west)
    "itq", "art", "pca", "vpa", "vtd", "pen", "car", "tat",
    "bel", "bre", "bas", "pds", "pse", "gbu", "rep", "cec", "deo", "bfu",
    # Line 15 - Prata (11 stations, west to east)
    "vpm", "ort", "slu", "cad", "vtl", "vun", "jpl", "sap", "fjt", "mat",
    "igt"
  ),
  station_name = c(
    # Line 1 - Azul
    "Jabaquara", "Conceição", "São Judas", "Saúde",
    "Praça da Árvore", "Santa Cruz", "Vila Mariana", "Ana Rosa",
    "Paraíso", "Vergueiro", "São Joaquim", "Japão-Liberdade",
    "Sé", "São Bento", "Luz", "Tiradentes", "Armênia",
    "Portuguesa-Tietê", "Carandiru", "Santana",
    "Jardim São Paulo-Ayrton Senna", "Parada Inglesa", "Tucuruvi",
    # Line 2 - Verde
    "Vila Prudente", "Tamanduateí", "Sacomã", "Alto do Ipiranga",
    "Santos-Imigrantes", "Chácara Klabin", "Ana Rosa", "Paraíso",
    "Brigadeiro", "Trianon-Masp", "Consolação", "Clínicas",
    "Sumaré", "Vila Madalena",
    # Line 3 - Vermelha
    "Corinthians-Itaquera", "Artur Alvim", "Patriarca",
    "Guilhermina-Esperança", "Vila Matilde", "Penha", "Carrão",
    "Tatuapé", "Belém", "Bresser-Moóca", "Brás", "Pedro II",
    "Sé", "Anhangabaú", "República", "Santa Cecília",
    "Marechal Deodoro", "Palmeiras-Barra Funda",
    # Line 15 - Prata
    "Vila Prudente", "Oratório", "São Lucas", "Camilo Haddad",
    "Vila Tolstói", "Vila União", "Jardim Planalto", "Sapopemba",
    "Fazenda da Juta", "São Mateus", "Jardim Colonial"
  ),
  line_number = c(
    rep(1L, 23),
    rep(2L, 14),
    rep(3L, 18),
    rep(15L, 11)
  )
)

# Business unit -> line mapping for Lines 4 (ViaQuatro) and 5 (ViaMobilidade).
dim_bus <- tibble(
  business_unit = c("ViaMobilidade - Linha 5", "ViaQuatro"),
  line_name_pt = c("Lilás", "Amarela"),
  line_number = c(5L, 4L),
  line_name = c("Lilac", "Yellow")
)

# Maps the Portuguese day-type label in Dataverse data to metric abbreviations.
dim_convert_metric <- tibble(
  tipo_dia = c("Dias Úteis", "Sábado", "Domingo"),
  metric_abb = c("mdu", "msa", "mdo"),
  metric = c("Média dos Dias Úteis", "Média dos Sábados", "Média dos Domingos")
)

# Old metro stations that were handed over to ViaMobilidade (Line 5).
dim_station_lilac <- tibble(
  line_number = 5L,
  station_name = c(
    "Capão Redondo",
    "Campo Limpo",
    "Vila das Belezas",
    "Giovanni Gronchi",
    "Santo Amaro",
    "Largo Treze",
    "Adolfo Pinheiro",
    "Alto da Boa Vista",
    "Borba Gato",
    "Brooklin",
    "Campo Belo",
    "Eucaliptos",
    "Moema",
    "AACD-Servidor",
    "Hospital São Paulo",
    "Santa Cruz",
    "Chácara Klabin"
  )
)

# --- Exported reference datasets ---------------------------------------------
# metro_lines and metro_colors are package datasets in their own right and are
# also joined onto the passenger/station tables during assembly. metro_lines is
# the metro half of dim_line with line_number first; deriving it keeps the two
# from drifting apart. Every use is a left_join by line_number, so row order
# does not matter.

metro_lines <- dim_line |>
  filter(type == "metro") |>
  select(line_number, line_name_pt, line_name)

metro_colors <- c(
  "Blue" = "#171796",
  "Green" = "#007A5E",
  "Red" = "#ED2E38",
  "Yellow" = "#FFD525",
  "Lilac" = "#874ABF",
  "Silver" = "#8F8F8C"
)

# --- Column-order constants --------------------------------------------------

# Final column order for the assembled passenger tables (from make_datasets.R).
.cols_psg <- c(
  "date",
  "line_number",
  "metric_abb",
  "value",
  "metric",
  "metric_pt",
  "line_name",
  "line_name_pt",
  "year"
)

# Intermediate schemas produced by the import builders (from utils.R).
.cols_psg_entrance <- c(
  "date",
  "line_number",
  "metric_abb",
  "metric",
  "value",
  "year"
)

.cols_stn_avg <- c(
  "date",
  "line_number",
  "station_name",
  "avg_passenger",
  "year"
)

.cols_stn_daily <- c(
  "date",
  "year",
  "line_number",
  "station_code",
  "station_name",
  "passengers"
)

# Long schema of the committed historic CSVs (2016-2019). The historic era keys
# its metric by the Portuguese label; assemble_*() maps it with map_metric().
.cols_stn_avg_historic <- c(
  "date",
  "year",
  "month",
  "line_name_full",
  "name_station",
  "metric_abb",
  "value"
)

# Inputs and outputs of the assemble_*() harmonization step.
.cols_stn_avg_in <- c(
  "date",
  "year",
  "line_number",
  "station_name",
  "avg_passenger"
)

.cols_stn_avg_out <- c(
  "date",
  "line_number",
  "station_name",
  "avg_passenger",
  "line_name",
  "line_name_pt",
  "year"
)

.cols_stn_daily_out <- c(
  "date",
  "line_number",
  "station_name",
  "passengers",
  "line_name",
  "line_name_pt",
  "station_code",
  "year"
)
