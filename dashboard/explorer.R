library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(tidyr)
library(leaflet)
library(echarts4r)
library(metrosp)
library(sf)
library(htmltools)
library(writexl)
library(trendseries)

# Metadata ----

line_colors <- c(
  "1" = "#171796",
  "2" = "#007A5E",
  "3" = "#ED2E38",
  "4" = "#B89000",
  "5" = "#874ABF",
  "15" = "#6B6B68"
)

line_labels <- c(
  "1" = "Linha 1 — Azul",
  "2" = "Linha 2 — Verde",
  "3" = "Linha 3 — Vermelha",
  "4" = "Linha 4 — Amarela",
  "5" = "Linha 5 — Lilás",
  "15" = "Linha 15 — Prata"
)

LINES <- names(line_labels)
DATA_START <- as.Date("2019-01-01")
metro_primary <- "#171796"

# Helpers ----

fmt_n <- function(x) {
  if (!length(x) || all(is.na(x))) return("—")
  x <- x[!is.na(x)][1]
  if (x >= 1e9) sprintf("%.2f bi", x / 1e9)
  else if (x >= 1e6) sprintf("%.1f M", x / 1e6)
  else if (x >= 1e3) sprintf("%.1f K", x / 1e3)
  else formatC(round(x), format = "d", big.mark = ".")
}

js_axis_label_compact <- htmlwidgets::JS(
  "function(v) {",
  "  if (v >= 1e9) return (v/1e9).toFixed(1) + 'bi';",
  "  if (v >= 1e6) return (v/1e6).toFixed(1) + 'M';",
  "  if (v >= 1e3) return Math.round(v/1e3) + 'K';",
  "  return v;",
  "}"
)

js_tooltip_pt_br <- htmlwidgets::JS(
  "function(params) {",
  "  if (!Array.isArray(params)) params = [params];",
  "  var t = '<div style=\"font-weight:600;margin-bottom:4px;color:#0E1130\">' + params[0].axisValueLabel + '</div>';",
  "  params.forEach(function(p) {",
  "    var v = (typeof p.value === 'object' ? p.value[1] : p.value);",
  "    var label = v != null ? v.toLocaleString('pt-BR', {maximumFractionDigits: 1}) : '—';",
  "    t += '<div style=\"display:flex;align-items:center;gap:6px;\">';",
  "    t += '<span style=\"display:inline-block;width:8px;height:8px;border-radius:50%;background:' + p.color + '\"></span>';",
  "    t += '<span style=\"color:#4A4F6B\">' + p.seriesName + '</span>';",
  "    t += '<span style=\"margin-left:auto;font-weight:600;color:#0E1130\">' + label + '</span>';",
  "    t += '</div>';",
  "  });",
  "  return t;",
  "}"
)

# Pre-build data ----

## Line-level monthly (entrance) ----
ent <- metrosp::passengers_entrance |>
  filter(
    metric_abb == "total",
    line_number %in% as.integer(LINES),
    date >= DATA_START
  ) |>
  mutate(line_number = as.character(line_number)) |>
  select(date, line_number, value, year)

ent_trend <- tryCatch(
  augment_trends(
    ent,
    date_col = "date",
    value_col = "value",
    group_cols = "line_number",
    methods = "stl",
    params = list(robust = TRUE, s.window = 13),
    .quiet = TRUE
  ),
  error = function(e) ent |> mutate(trend_stl = NA_real_)
)

## Line-level monthly (transported) ----
trans <- metrosp::passengers_transported |>
  filter(
    metric_abb == "total",
    line_number %in% as.integer(LINES),
    date >= DATA_START
  ) |>
  mutate(line_number = as.character(line_number)) |>
  select(date, line_number, value, year)

trans_trend <- tryCatch(
  augment_trends(
    trans,
    date_col = "date",
    value_col = "value",
    group_cols = "line_number",
    methods = "stl",
    params = list(robust = TRUE, s.window = 13),
    .quiet = TRUE
  ),
  error = function(e) trans |> mutate(trend_stl = NA_real_)
)

## Station averages (monthly weekday avg) ----
sta_avg <- metrosp::station_averages |>
  filter(date >= DATA_START) |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES) |>
  select(date, line_number, station_name, value = avg_passenger, year)

# Only compute STL for groups with enough observations (>= 24 months)
sta_avg_enough <- sta_avg |>
 group_by(line_number, station_name) |>
 filter(sum(!is.na(value)) >= 24L) |>
 ungroup()

sta_avg_trend <- tryCatch(
  augment_trends(
    sta_avg_enough,
    date_col = "date",
    value_col = "value",
    group_cols = c("line_number", "station_name"),
    methods = "stl",
    params = list(robust = TRUE, s.window = 13),
    .quiet = TRUE
  ),
  error = function(e) {
    sta_avg_enough |> mutate(trend_stl = NA_real_)
  }
)

## Station daily ----
sta_daily <- metrosp::station_daily |>
  filter(date >= DATA_START) |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES) |>
  select(date, line_number, station_name, value = passengers, year)

## Spatial data ----
sf_lines <- tryCatch(
  metrosp::lines |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) NULL
)

sf_stations <- tryCatch(
  metrosp::stations |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) NULL
)

## Station lookup per line ----
stations_by_line <- sta_avg |>
  distinct(line_number, station_name) |>
  arrange(line_number, station_name)

## Dataset metadata for download tab ----
dataset_info <- list(
  passengers_entrance = list(
    label = "Embarques por Linha (mensal)",
    desc = "Passageiros entrando nas estações, agregado por linha. Métrica: total mensal.",
    cols = c("date", "line_number", "value", "year"),
    rows = nrow(ent),
    range = paste(min(ent$date), "a", max(ent$date)),
    source = "METRO SP / Insper Dataverse"
  ),
  passengers_transported = list(
    label = "Passageiros Transportados (mensal)",
    desc = "Total de passageiros transportados por linha por mês.",
    cols = c("date", "line_number", "value", "year"),
    rows = nrow(trans),
    range = paste(min(trans$date), "a", max(trans$date)),
    source = "METRO SP"
  ),
  station_averages = list(
    label = "Média Dias Úteis por Estação (mensal)",
    desc = "Média de embarques em dias úteis por estação, mensal.",
    cols = c("date", "line_number", "station_name", "value", "year"),
    rows = nrow(sta_avg),
    range = paste(min(sta_avg$date), "a", max(sta_avg$date)),
    source = "METRO SP / Insper Dataverse"
  ),
  station_daily = list(
    label = "Embarques Diários por Estação",
    desc = "Embarques diários em cada estação do metrô.",
    cols = c("date", "line_number", "station_name", "value", "year"),
    rows = nrow(sta_daily),
    range = paste(min(sta_daily$date), "a", max(sta_daily$date)),
    source = "METRO SP / Insper Dataverse"
  ),
  lines_spatial = list(
    label = "Geometrias das Linhas (espacial)",
    desc = "Traçado das linhas de metrô em operação (LINESTRING, WGS84).",
    cols = c("line_number", "line_name_pt", "type", "status", "geometry"),
    rows = if (!is.null(sf_lines)) nrow(sf_lines) else 0L,
    range = "Atualizado conforme GeoSampa",
    source = "GeoSampa"
  ),
  stations_spatial = list(
    label = "Localização das Estações (espacial)",
    desc = "Ponto de cada estação de metrô em operação (POINT, WGS84).",
    cols = c("station_name", "line_number", "line_name_pt", "type", "status", "geometry"),
    rows = if (!is.null(sf_stations)) nrow(sf_stations) else 0L,
    range = "Atualizado conforme GeoSampa",
    source = "GeoSampa"
  )
)

# Theme ----

metro_theme <- bs_theme(
  version = 5,
  bootswatch = NULL,
  primary = metro_primary,
  secondary = "#4A4F6B",
  success = "#2E7D32",
  danger = "#C62828",
  info = "#1565C0",
  warning = "#B89000",
  base_font = font_google("Inter", local = FALSE),
  heading_font = font_google("Inter", local = FALSE),
  bg = "#F7F8FB",
  fg = "#0E1130"
)

# UI ----

ui <- page_navbar(
  title = tags$span(
    bs_icon("train-front-fill", size = "1.05em", class = "me-2"),
    "Metro SP — Explorador de Dados"
  ),
  theme = metro_theme,
  lang = "pt-BR",
  fillable = FALSE,
  header = tags$head(
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),

  ## Tab: Linhas ----
  nav_panel(
    title = "Linhas",
    icon = bs_icon("graph-up"),

    layout_sidebar(
      sidebar = sidebar(
        title = div(class = "sidebar-title", "Filtros"),
        width = 260,
        selectInput(
          "lines_line",
          "Linha",
          choices = setNames(LINES, unname(line_labels)),
          selected = "1"
        ),
        selectInput(
          "lines_metric",
          "Variável",
          choices = c(
            "Embarques (entrada)" = "entrance",
            "Passageiros transportados" = "transported"
          ),
          selected = "entrance"
        ),
        checkboxInput("lines_trend", "Mostrar tendência (STL)", value = FALSE),
        hr(),
        tags$p(
          class = "text-muted small mb-0",
          "Dados mensais a partir de janeiro de 2019. ",
          "Tendência extraída via decomposição STL robusta (s.window = 13)."
        )
      ),

      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center justify-content-between gap-2",
          textOutput("lines_title", inline = TRUE),
          downloadButton(
            "dl_lines_csv",
            NULL,
            icon = icon("download"),
            class = "btn-sm btn-link p-1 download-icon",
            title = "Baixar CSV"
          )
        ),
        echarts4rOutput("lines_chart", height = "480px")
      )
    )
  ),

  ## Tab: Estações ----
  nav_panel(
    title = "Estações",
    icon = bs_icon("pin-map-fill"),

    layout_sidebar(
      sidebar = sidebar(
        title = div(class = "sidebar-title", "Filtros"),
        width = 260,
        selectInput(
          "sta_line",
          "Linha",
          choices = setNames(LINES, unname(line_labels)),
          selected = "1"
        ),
        selectInput(
          "sta_station",
          "Estação",
          choices = NULL
        ),
        selectInput(
          "sta_grain",
          "Granularidade",
          choices = c(
            "Média dias úteis (mensal)" = "monthly",
            "Diário" = "daily"
          ),
          selected = "monthly"
        ),
        checkboxInput("sta_trend", "Mostrar tendência (STL)", value = FALSE),
        hr(),
        tags$p(
          class = "text-muted small mb-0",
          "Dados a partir de janeiro de 2019. ",
          "Tendência STL disponível apenas para dados mensais."
        )
      ),

      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center justify-content-between gap-2",
          textOutput("sta_title", inline = TRUE),
          downloadButton(
            "dl_sta_csv",
            NULL,
            icon = icon("download"),
            class = "btn-sm btn-link p-1 download-icon",
            title = "Baixar CSV"
          )
        ),
        echarts4rOutput("sta_chart", height = "480px")
      )
    )
  ),

  ## Tab: Mapa ----
  nav_panel(
    title = "Mapa",
    icon = bs_icon("geo-alt-fill"),

    card(
      full_screen = TRUE,
      card_header(
        "Linhas e estações do Metrô de São Paulo",
        tags$small(
          class = "ms-2 text-muted",
          "passe o mouse para ver nomes"
        )
      ),
      leafletOutput("map", height = "600px")
    )
  ),

  ## Tab: Download ----
  nav_panel(
    title = "Download",
    icon = bs_icon("download"),

    div(
      class = "section-label",
      "Datasets disponíveis (a partir de 2019)"
    ),

    layout_column_wrap(
      width = 1 / 2,
      heights_equal = "row",

      card(
        card_header("Embarques por Linha (mensal)"),
        card_body(
          tags$p(class = "small text-muted", dataset_info$passengers_entrance$desc),
          tags$p(class = "small",
            tags$b("Colunas: "), paste(dataset_info$passengers_entrance$cols, collapse = ", "),
            tags$br(),
            tags$b("Linhas: "), format(dataset_info$passengers_entrance$rows, big.mark = "."),
            tags$br(),
            tags$b("Período: "), dataset_info$passengers_entrance$range,
            tags$br(),
            tags$b("Fonte: "), dataset_info$passengers_entrance$source
          ),
          div(
            class = "d-flex gap-2",
            downloadButton("dl_ent_csv", "CSV", class = "btn-sm btn-outline-primary"),
            downloadButton("dl_ent_xlsx", "Excel", class = "btn-sm btn-outline-primary")
          )
        )
      ),

      card(
        card_header("Passageiros Transportados (mensal)"),
        card_body(
          tags$p(class = "small text-muted", dataset_info$passengers_transported$desc),
          tags$p(class = "small",
            tags$b("Colunas: "), paste(dataset_info$passengers_transported$cols, collapse = ", "),
            tags$br(),
            tags$b("Linhas: "), format(dataset_info$passengers_transported$rows, big.mark = "."),
            tags$br(),
            tags$b("Período: "), dataset_info$passengers_transported$range,
            tags$br(),
            tags$b("Fonte: "), dataset_info$passengers_transported$source
          ),
          div(
            class = "d-flex gap-2",
            downloadButton("dl_trans_csv", "CSV", class = "btn-sm btn-outline-primary"),
            downloadButton("dl_trans_xlsx", "Excel", class = "btn-sm btn-outline-primary")
          )
        )
      ),

      card(
        card_header("Média Dias Úteis por Estação (mensal)"),
        card_body(
          tags$p(class = "small text-muted", dataset_info$station_averages$desc),
          tags$p(class = "small",
            tags$b("Colunas: "), paste(dataset_info$station_averages$cols, collapse = ", "),
            tags$br(),
            tags$b("Linhas: "), format(dataset_info$station_averages$rows, big.mark = "."),
            tags$br(),
            tags$b("Período: "), dataset_info$station_averages$range,
            tags$br(),
            tags$b("Fonte: "), dataset_info$station_averages$source
          ),
          div(
            class = "d-flex gap-2",
            downloadButton("dl_staavg_csv", "CSV", class = "btn-sm btn-outline-primary"),
            downloadButton("dl_staavg_xlsx", "Excel", class = "btn-sm btn-outline-primary")
          )
        )
      ),

      card(
        card_header("Embarques Diários por Estação"),
        card_body(
          tags$p(class = "small text-muted", dataset_info$station_daily$desc),
          tags$p(class = "small",
            tags$b("Colunas: "), paste(dataset_info$station_daily$cols, collapse = ", "),
            tags$br(),
            tags$b("Linhas: "), format(dataset_info$station_daily$rows, big.mark = "."),
            tags$br(),
            tags$b("Período: "), dataset_info$station_daily$range,
            tags$br(),
            tags$b("Fonte: "), dataset_info$station_daily$source
          ),
          div(
            class = "d-flex gap-2",
            downloadButton("dl_stadaily_csv", "CSV", class = "btn-sm btn-outline-primary"),
            downloadButton("dl_stadaily_xlsx", "Excel", class = "btn-sm btn-outline-primary")
          )
        )
      ),

      card(
        card_header("Geometrias das Linhas (espacial)"),
        card_body(
          tags$p(class = "small text-muted", dataset_info$lines_spatial$desc),
          tags$p(class = "small",
            tags$b("Colunas: "), paste(dataset_info$lines_spatial$cols, collapse = ", "),
            tags$br(),
            tags$b("Feições: "), dataset_info$lines_spatial$rows,
            tags$br(),
            tags$b("Fonte: "), dataset_info$lines_spatial$source
          ),
          div(
            class = "d-flex gap-2",
            downloadButton("dl_lines_gpkg", "GPKG", class = "btn-sm btn-outline-primary"),
            downloadButton("dl_lines_geojson", "GeoJSON", class = "btn-sm btn-outline-primary")
          )
        )
      ),

      card(
        card_header("Localização das Estações (espacial)"),
        card_body(
          tags$p(class = "small text-muted", dataset_info$stations_spatial$desc),
          tags$p(class = "small",
            tags$b("Colunas: "), paste(dataset_info$stations_spatial$cols, collapse = ", "),
            tags$br(),
            tags$b("Feições: "), dataset_info$stations_spatial$rows,
            tags$br(),
            tags$b("Fonte: "), dataset_info$stations_spatial$source
          ),
          div(
            class = "d-flex gap-2",
            downloadButton("dl_stations_gpkg", "GPKG", class = "btn-sm btn-outline-primary"),
            downloadButton("dl_stations_geojson", "GeoJSON", class = "btn-sm btn-outline-primary")
          )
        )
      )
    )
  ),

  ## Tab: Sobre ----
  nav_panel(
    title = "Sobre",
    icon = bs_icon("info-circle-fill"),

    layout_column_wrap(
      width = 1 / 2,

      card(
        card_header("Sobre o pacote metrosp"),
        card_body(
          tags$p(
            "O ", tags$b("metrosp"), " é um pacote R de dados que disponibiliza ",
            "informações de demanda de passageiros do Metrô de São Paulo (2017-2025). ",
            "Similar ao ", tags$code("nycflights13"), ", o pacote contém apenas datasets, ",
            "sem funções voltadas ao usuário."
          ),
          tags$p(
            "Este explorador apresenta os dados a partir de janeiro de 2019, ",
            "permitindo visualização rápida e download em múltiplos formatos."
          ),
          tags$h6("Links"),
          tags$ul(
            tags$li(tags$a(
              href = "https://github.com/viniciusoike/metrosp",
              target = "_blank",
              "GitHub"
            )),
            tags$li(tags$a(
              href = "https://viniciusoike.github.io/metrosp/",
              target = "_blank",
              "Documentação (pkgdown)"
            )),
            tags$li(tags$a(
              href = "https://github.com/viniciusoike/metrosp/issues",
              target = "_blank",
              "Reportar problema"
            ))
          ),
          tags$h6("Licença"),
          tags$p(class = "small text-muted", "MIT")
        )
      ),

      card(
        card_header("Fontes de dados"),
        card_body(
          tags$h6("Demanda de passageiros"),
          tags$ul(class = "small",
            tags$li(
              tags$b("Linhas 1, 2, 3 e 15: "),
              tags$a(
                href = "https://transparencia.metrosp.com.br/dataset/demanda",
                target = "_blank",
                "METRO SP — Portal de Transparência"
              )
            ),
            tags$li(
              tags$b("Linhas 4 e 5: "),
              "Insper Dataverse (doi:10.60873/FK2/UTGQ0I)"
            )
          ),
          tags$h6("Dados espaciais"),
          tags$ul(class = "small",
            tags$li(tags$a(
              href = "https://geosampa.prefeitura.sp.gov.br/",
              target = "_blank",
              "GeoSampa — Prefeitura de São Paulo"
            ))
          ),
          tags$h6("Limitações conhecidas"),
          tags$ul(class = "small text-muted",
            tags$li("Linhas 4/5 — passageiros transportados não disponíveis"),
            tags$li("Linhas 4/5 — código de estação é NA"),
            tags$li("2019: dados começam em janeiro (2017 parcial excluído)"),
            tags$li("Meses finais de 2025 podem conter NA (publicação pendente)")
          )
        )
      )
    )
  ),

  nav_spacer(),
  nav_item(
    tags$span(
      class = "source-tag",
      "Fontes: METRO SP · Insper Dataverse · GeoSampa"
    )
  )
)

# Server ----

server <- function(input, output, session) {

  ## Lines tab ----

  lines_data <- reactive({
    ln <- input$lines_line
    req(ln)
    if (input$lines_metric == "entrance") {
      ent_trend |> filter(line_number == ln)
    } else {
      trans_trend |> filter(line_number == ln)
    }
  })

  output$lines_title <- renderText({
    metric_lbl <- if (input$lines_metric == "entrance") "Embarques" else "Transportados"
    paste0(metric_lbl, " — ", line_labels[input$lines_line])
  })

  output$lines_chart <- renderEcharts4r({
    df <- lines_data()
    req(nrow(df) > 0)
    col <- unname(line_colors[input$lines_line])
    show_trend <- input$lines_trend

    e <- df |>
      e_charts(date) |>
      e_line(
        value,
        name = "Observado",
        symbol = "none",
        smooth = FALSE,
        lineStyle = list(width = if (show_trend) 1.2 else 2.2, color = col),
        itemStyle = list(color = col)
      )

    if (show_trend && "trend_stl" %in% names(df)) {
      e <- e |>
        e_line(
          trend_stl,
          name = "Tendência (STL)",
          symbol = "none",
          smooth = TRUE,
          lineStyle = list(width = 2.8, color = col, type = "solid"),
          itemStyle = list(color = col)
        )
    }

    e |>
      e_x_axis(type = "time") |>
      e_y_axis(
        axisLabel = list(formatter = js_axis_label_compact),
        splitLine = list(lineStyle = list(color = "#EDEEF3"))
      ) |>
      e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
      e_legend(bottom = 0, itemWidth = 14, itemHeight = 8) |>
      e_grid(left = 60, right = 24, top = 20, bottom = 50) |>
      e_datazoom(type = "inside") |>
      e_toolbox_feature(feature = "saveAsImage", title = "Salvar")
  })

  output$dl_lines_csv <- downloadHandler(
    filename = function() {
      paste0("metrosp-linhas-", input$lines_line, "-", input$lines_metric, ".csv")
    },
    content = function(file) {
      utils::write.csv(lines_data(), file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  ## Stations tab ----

  observeEvent(input$sta_line, {
    choices <- stations_by_line |>
      filter(line_number == input$sta_line) |>
      pull(station_name)
    updateSelectInput(session, "sta_station", choices = choices, selected = choices[1])
  })

  sta_data <- reactive({
    ln <- input$sta_line
    sta <- input$sta_station
    grain <- input$sta_grain
    req(ln, sta)

    if (grain == "monthly") {
      df <- sta_avg_trend |>
        filter(line_number == ln, station_name == sta)
      if (nrow(df) == 0) {
        df <- sta_avg |>
          filter(line_number == ln, station_name == sta) |>
          mutate(trend_stl = NA_real_)
      }
      df
    } else {
      sta_daily |>
        filter(line_number == ln, station_name == sta)
    }
  })

  output$sta_title <- renderText({
    grain_lbl <- if (input$sta_grain == "monthly") "Média dias úteis" else "Diário"
    paste0(input$sta_station, " — ", grain_lbl)
  })

  output$sta_chart <- renderEcharts4r({
    df <- sta_data()
    req(nrow(df) > 0)
    col <- unname(line_colors[input$sta_line])
    show_trend <- input$sta_trend && input$sta_grain == "monthly"

    e <- df |>
      e_charts(date) |>
      e_line(
        value,
        name = "Observado",
        symbol = if (input$sta_grain == "daily") "none" else "circle",
        symbolSize = if (input$sta_grain == "daily") 0 else 4,
        smooth = FALSE,
        lineStyle = list(
          width = if (show_trend) 1.2 else if (input$sta_grain == "daily") 1 else 2.2,
          color = if (input$sta_grain == "daily" && !show_trend) "#C8CAD3" else col
        ),
        itemStyle = list(color = col)
      )

    if (show_trend && "trend_stl" %in% names(df)) {
      e <- e |>
        e_line(
          trend_stl,
          name = "Tendência (STL)",
          symbol = "none",
          smooth = TRUE,
          lineStyle = list(width = 2.8, color = col),
          itemStyle = list(color = col)
        )
    }

    e |>
      e_x_axis(type = "time") |>
      e_y_axis(
        axisLabel = list(formatter = js_axis_label_compact),
        splitLine = list(lineStyle = list(color = "#EDEEF3"))
      ) |>
      e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
      e_legend(bottom = 0, itemWidth = 14, itemHeight = 8) |>
      e_grid(left = 60, right = 24, top = 20, bottom = 50) |>
      e_datazoom(type = "slider", bottom = 8, height = 20) |>
      e_toolbox_feature(feature = "saveAsImage", title = "Salvar")
  })

  output$dl_sta_csv <- downloadHandler(
    filename = function() {
      sta_slug <- gsub(" ", "-", tolower(input$sta_station))
      paste0("metrosp-estacao-", sta_slug, "-", input$sta_grain, ".csv")
    },
    content = function(file) {
      utils::write.csv(sta_data(), file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  ## Map tab ----

  output$map <- renderLeaflet({
    m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      setView(lng = -46.633, lat = -23.555, zoom = 12)

    if (!is.null(sf_lines)) {
      for (ln in LINES) {
        geom <- sf_lines |> filter(line_number == ln)
        if (nrow(geom) > 0) {
          m <- m |>
            addPolylines(
              data = geom,
              color = line_colors[ln],
              weight = 4,
              opacity = 0.8,
              label = line_labels[ln],
              highlightOptions = highlightOptions(weight = 6, opacity = 1)
            )
        }
      }
    }

    if (!is.null(sf_stations)) {
      m <- m |>
        addCircleMarkers(
          data = sf_stations,
          radius = 5,
          color = "white",
          fillColor = ~ line_colors[line_number],
          fillOpacity = 0.9,
          weight = 1.5,
          stroke = TRUE,
          label = ~ paste0(station_name, " — ", line_labels[line_number])
        )
    }

    m
  })

  ## Download handlers ----

  # CSV downloads
  make_csv_handler <- function(data_fn, prefix) {
    downloadHandler(
      filename = function() paste0("metrosp-", prefix, ".csv"),
      content = function(file) {
        utils::write.csv(data_fn(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  }

  make_xlsx_handler <- function(data_fn, prefix) {
    downloadHandler(
      filename = function() paste0("metrosp-", prefix, ".xlsx"),
      content = function(file) writexl::write_xlsx(data_fn(), file)
    )
  }

  output$dl_ent_csv <- make_csv_handler(function() ent, "embarques-linha")
  output$dl_ent_xlsx <- make_xlsx_handler(function() ent, "embarques-linha")
  output$dl_trans_csv <- make_csv_handler(function() trans, "transportados-linha")
  output$dl_trans_xlsx <- make_xlsx_handler(function() trans, "transportados-linha")
  output$dl_staavg_csv <- make_csv_handler(function() sta_avg, "media-estacao")
  output$dl_staavg_xlsx <- make_xlsx_handler(function() sta_avg, "media-estacao")
  output$dl_stadaily_csv <- make_csv_handler(function() sta_daily, "diario-estacao")
  output$dl_stadaily_xlsx <- make_xlsx_handler(function() sta_daily, "diario-estacao")

  # Spatial downloads
  output$dl_lines_gpkg <- downloadHandler(
    filename = function() "metrosp-linhas.gpkg",
    content = function(file) {
      if (!is.null(sf_lines)) sf::st_write(sf_lines, file, driver = "GPKG", quiet = TRUE)
    }
  )
  output$dl_lines_geojson <- downloadHandler(
    filename = function() "metrosp-linhas.geojson",
    content = function(file) {
      if (!is.null(sf_lines)) sf::st_write(sf_lines, file, driver = "GeoJSON", quiet = TRUE)
    }
  )
  output$dl_stations_gpkg <- downloadHandler(
    filename = function() "metrosp-estacoes.gpkg",
    content = function(file) {
      if (!is.null(sf_stations)) sf::st_write(sf_stations, file, driver = "GPKG", quiet = TRUE)
    }
  )
  output$dl_stations_geojson <- downloadHandler(
    filename = function() "metrosp-estacoes.geojson",
    content = function(file) {
      if (!is.null(sf_stations)) sf::st_write(sf_stations, file, driver = "GeoJSON", quiet = TRUE)
    }
  )
}

shinyApp(ui, server)
