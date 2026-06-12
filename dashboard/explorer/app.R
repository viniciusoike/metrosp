library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(leaflet)
library(echarts4r)
library(metrosp)
library(sf)
library(htmltools)
library(writexl)
library(readr)

source("shared.R", local = TRUE)

# trendseries (optional): graceful degradation ----

HAS_TRENDSERIES <- requireNamespace("trendseries", quietly = TRUE)
if (!HAS_TRENDSERIES) {
  message(
    "trendseries not installed; STL trend lines will be disabled. ",
    "Install with: pak::pak(\"viniciusoike/trendseries\")"
  )
}

# Constants ----

DEFAULT_START <- as.Date("2019-01-01")

MONTHS_PT <- c(
  "jan", "fev", "mar", "abr", "mai", "jun",
  "jul", "ago", "set", "out", "nov", "dez"
)

fmt_month_pt <- function(x) {
  paste0(MONTHS_PT[as.integer(format(x, "%m"))], "/", format(x, "%Y"))
}

# A cleared dateInput returns a length-0 Date (not NULL), so `%||%` alone
# does not catch it
date_or <- function(x, default) {
  if (length(x) == 1 && !is.na(x)) x else default
}

# Pre-build data ----

## Line-level monthly (entrance) ----
ent <- metrosp::passengers_entrance |>
  filter(
    metric_abb == "total",
    line_number %in% as.integer(LINES)
  ) |>
  mutate(line_number = as.character(line_number)) |>
  select(date, line_number, value, year)

## Line-level monthly (transported) ----
trans <- metrosp::passengers_transported |>
  filter(
    metric_abb == "total",
    line_number %in% as.integer(LINES)
  ) |>
  mutate(line_number = as.character(line_number)) |>
  select(date, line_number, value, year)

## Station averages (monthly weekday avg) ----
sta_avg <- metrosp::station_averages |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES) |>
  select(date, line_number, station_name, value = avg_passenger, year)

## Station daily ----
sta_daily <- metrosp::station_daily |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES) |>
  select(date, line_number, station_name, value = passengers, year)

## Data window (drives copy, input limits, freshness stamp) ----
DATA_MIN <- min(ent$date, na.rm = TRUE)
DATA_MAX <- max(c(ent$date, sta_daily$date), na.rm = TRUE)

## Spatial data ----
sf_lines <- tryCatch(
  metrosp::lines |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) {
    message("Failed to load line geometries: ", conditionMessage(e))
    NULL
  }
)

sf_stations <- tryCatch(
  metrosp::stations |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) {
    message("Failed to load station geometries: ", conditionMessage(e))
    NULL
  }
)

## Station lookup per line ----
stations_by_line <- sta_avg |>
  distinct(line_number, station_name) |>
  arrange(line_number, station_name)

## Station demand for map markers ----
sta_demand_cutoff <- max(sta_avg$date, na.rm = TRUE) - 365
sta_demand_map <- sta_avg |>
  filter(!is.na(value), date > sta_demand_cutoff) |>
  group_by(line_number, station_name) |>
  summarise(avg = mean(value, na.rm = TRUE), .groups = "drop")

sf_stations_map <- if (!is.null(sf_stations)) {
  max_avg <- max(sta_demand_map$avg, na.rm = TRUE)
  sf_stations |>
    left_join(sta_demand_map, by = c("line_number", "station_name")) |>
    mutate(radius = ifelse(is.na(avg), 4, 4 + 12 * sqrt(avg / max_avg)))
} else {
  NULL
}

## Available years for daily station data ----
sta_daily_years <- sta_daily |>
  distinct(line_number, station_name, year) |>
  arrange(line_number, station_name, desc(year))

## Ramp-up windows (stations opened within the data window) ----
ramp_windows <- metrosp::station_inauguration |>
  filter(!is.na(inauguration_date), !is.na(ramp_up_end)) |>
  mutate(line_number = as.character(line_number)) |>
  select(line_number, station_name, inauguration_date, ramp_up_end)

## Dataset metadata for download tab ----
# Downloads serve the package datasets as-is, so the schema here matches the
# pkgdown documentation. Computed from the data so it never drifts.
dataset_info <- list(
  passengers_entrance = list(
    label = "passengers_entrance (mensal)",
    desc = paste(
      "Passageiros entrando nas estações, agregado por linha.",
      "Inclui todas as métricas (coluna metric_abb), não apenas o total."
    ),
    cols = names(metrosp::passengers_entrance),
    rows = nrow(metrosp::passengers_entrance),
    range = paste(
      min(metrosp::passengers_entrance$date),
      "a",
      max(metrosp::passengers_entrance$date)
    ),
    source = "METRO SP / Insper Dataverse"
  ),
  passengers_transported = list(
    label = "passengers_transported (mensal)",
    desc = paste(
      "Passageiros transportados por linha por mês.",
      "Inclui todas as métricas (coluna metric_abb)."
    ),
    cols = names(metrosp::passengers_transported),
    rows = nrow(metrosp::passengers_transported),
    range = paste(
      min(metrosp::passengers_transported$date),
      "a",
      max(metrosp::passengers_transported$date)
    ),
    source = "METRO SP"
  ),
  station_averages = list(
    label = "station_averages (mensal)",
    desc = "Média de embarques em dias úteis por estação, mensal.",
    cols = names(metrosp::station_averages),
    rows = nrow(metrosp::station_averages),
    range = paste(
      min(metrosp::station_averages$date),
      "a",
      max(metrosp::station_averages$date)
    ),
    source = "METRO SP / Insper Dataverse"
  ),
  station_daily = list(
    label = "station_daily (diário)",
    desc = "Embarques diários em cada estação do metrô.",
    cols = names(metrosp::station_daily),
    rows = nrow(metrosp::station_daily),
    range = paste(
      min(metrosp::station_daily$date),
      "a",
      max(metrosp::station_daily$date)
    ),
    source = "METRO SP / Insper Dataverse"
  ),
  lines_spatial = list(
    label = "lines (espacial)",
    desc = paste(
      "Traçados de metrô e trem (CPTM), atuais e planejados",
      "(LINESTRING, WGS84)."
    ),
    cols = names(metrosp::lines),
    rows = nrow(metrosp::lines),
    range = NULL,
    source = "GeoSampa"
  ),
  stations_spatial = list(
    label = "stations (espacial)",
    desc = paste(
      "Ponto de cada estação de metrô e trem, atuais e planejadas",
      "(POINT, WGS84)."
    ),
    cols = names(metrosp::stations),
    rows = nrow(metrosp::stations),
    range = NULL,
    source = "GeoSampa"
  )
)

# Download card helper ----

download_card_configs <- list(
  list(
    key = "passengers_entrance",
    dl_ids = c("dl_ent_csv", "dl_ent_xlsx"),
    dl_labels = c("CSV", "Excel"),
    spatial = FALSE
  ),
  list(
    key = "passengers_transported",
    dl_ids = c("dl_trans_csv", "dl_trans_xlsx"),
    dl_labels = c("CSV", "Excel"),
    spatial = FALSE
  ),
  list(
    key = "station_averages",
    dl_ids = c("dl_staavg_csv", "dl_staavg_xlsx"),
    dl_labels = c("CSV", "Excel"),
    spatial = FALSE
  ),
  list(
    key = "station_daily",
    dl_ids = c("dl_stadaily_csv", "dl_stadaily_xlsx"),
    dl_labels = c("CSV", "Excel"),
    spatial = FALSE
  ),
  list(
    key = "lines_spatial",
    dl_ids = c("dl_lines_gpkg", "dl_lines_geojson"),
    dl_labels = c("GPKG", "GeoJSON"),
    spatial = TRUE
  ),
  list(
    key = "stations_spatial",
    dl_ids = c("dl_stations_gpkg", "dl_stations_geojson"),
    dl_labels = c("GPKG", "GeoJSON"),
    spatial = TRUE
  )
)

make_download_card <- function(cfg) {
  info <- dataset_info[[cfg$key]]
  size_label <- if (cfg$spatial) "Feições: " else "Linhas: "
  size_est <- if (!cfg$spatial && info$rows > 0) {
    bytes <- info$rows * length(info$cols) * 12
    if (bytes >= 1e6) {
      sprintf("~%.1f MB", bytes / 1e6)
    } else {
      sprintf("~%.0f KB", max(1, bytes / 1e3))
    }
  }
  card(
    card_header(info$label),
    card_body(
      tags$p(class = "small text-muted", info$desc),
      tags$p(
        class = "small",
        tags$b("Colunas: "),
        paste(info$cols, collapse = ", "),
        tags$br(),
        tags$b(size_label),
        format(info$rows, big.mark = "."),
        if (!is.null(info$range)) {
          tagList(tags$br(), tags$b("Período: "), info$range)
        },
        if (!is.null(size_est)) {
          tagList(tags$br(), tags$b("Tamanho CSV: "), size_est)
        },
        tags$br(),
        tags$b("Fonte: "),
        info$source
      ),
      div(
        class = "d-flex gap-2",
        downloadButton(
          cfg$dl_ids[1],
          cfg$dl_labels[1],
          class = "btn-sm btn-outline-primary"
        ),
        downloadButton(
          cfg$dl_ids[2],
          cfg$dl_labels[2],
          class = "btn-sm btn-outline-primary"
        )
      )
    )
  )
}

# UI ----

ui <- function(request) {
  page_navbar(
    id = "main_nav",
    title = tags$span(
      bs_icon("train-front-fill", size = "1.05em", class = "me-2"),
      "Metro SP — Explorador de Dados"
    ),
    theme = metro_theme,
    lang = "pt-BR",
    fillable = FALSE,
    header = tags$head(
      tags$link(rel = "stylesheet", href = "styles.css"),
      tags$meta(
        name = "viewport",
        content = "width=device-width, initial-scale=1"
      )
    ),

    ## Tab: Linhas ----
    nav_panel(
      title = "Linhas",
      icon = bs_icon("graph-up"),

      layout_sidebar(
        sidebar = sidebar(
          title = div(class = "sidebar-title", "Filtros"),
          width = 260,
          selectizeInput(
            "lines_line",
            "Linhas",
            choices = setNames(LINES, unname(line_labels)),
            selected = "1",
            multiple = TRUE,
            options = list(
              plugins = list("remove_button"),
              placeholder = "Selecione uma ou mais linhas"
            )
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
          dateInput(
            "lines_start",
            "Início da série",
            value = DEFAULT_START,
            min = DATA_MIN,
            max = DATA_MAX,
            language = "pt-BR"
          ),
          if (HAS_TRENDSERIES) {
            conditionalPanel(
              condition = "input.lines_line !== null && input.lines_line.length === 1",
              checkboxInput(
                "lines_trend",
                "Mostrar tendência (STL)",
                value = FALSE
              )
            )
          },
          hr(),
          tags$p(
            class = "text-muted small mb-0",
            "Dados mensais. ",
            if (HAS_TRENDSERIES) {
              "Tendência extraída via decomposição STL robusta (s.window = 13)."
            } else {
              "Instale o pacote trendseries para habilitar tendência STL."
            }
          )
        ),

        uiOutput("lines_kpis"),

        card(
          full_screen = TRUE,
          card_header(
            class = "d-flex align-items-center justify-content-between gap-2",
            textOutput("lines_title", inline = TRUE),
            downloadButton(
              "dl_lines_csv",
              tagList(
                bs_icon("download"),
                tags$span(class = "visually-hidden", "Baixar CSV")
              ),
              icon = NULL,
              class = "btn-sm btn-link p-1 download-icon",
              title = "Baixar CSV"
            )
          ),
          echarts4rOutput("lines_chart", height = "480px"),
          uiOutput("lines_note")
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
          selectizeInput(
            "sta_station",
            "Estação",
            choices = NULL,
            options = list(placeholder = "Buscar estação...")
          ),
          dateInput(
            "sta_start",
            "Início da série",
            value = DEFAULT_START,
            min = DATA_MIN,
            max = DATA_MAX,
            language = "pt-BR"
          ),
          if (HAS_TRENDSERIES) {
            checkboxInput("sta_trend", "Mostrar tendência (STL)", value = FALSE)
          },
          hr(),
          selectInput("sta_year", "Ano (série diária)", choices = NULL),
          hr(),
          tags$p(
            class = "text-muted small mb-0",
            "A data de início filtra o gráfico mensal. ",
            "O seletor de ano controla o gráfico diário. ",
            if (HAS_TRENDSERIES) {
              "Tendência STL disponível para dados mensais."
            } else {
              "Instale o pacote trendseries para habilitar tendência STL."
            }
          )
        ),

        uiOutput("sta_kpis"),

        card(
          full_screen = TRUE,
          card_header(
            class = "d-flex align-items-center justify-content-between gap-2",
            textOutput("sta_monthly_title", inline = TRUE),
            downloadButton(
              "dl_sta_csv",
              tagList(
                bs_icon("download"),
                tags$span(class = "visually-hidden", "Baixar CSV")
              ),
              icon = NULL,
              class = "btn-sm btn-link p-1 download-icon",
              title = "Baixar CSV"
            )
          ),
          echarts4rOutput("sta_chart", height = "380px")
        ),

        card(
          full_screen = TRUE,
          card_header(
            class = "d-flex align-items-center justify-content-between gap-2",
            textOutput("sta_daily_title", inline = TRUE),
            downloadButton(
              "dl_sta_daily_csv",
              tagList(
                bs_icon("download"),
                tags$span(class = "visually-hidden", "Baixar CSV")
              ),
              icon = NULL,
              class = "btn-sm btn-link p-1 download-icon",
              title = "Baixar CSV"
            )
          ),
          echarts4rOutput("sta_daily_chart", height = "320px")
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
            "círculos proporcionais à demanda — clique para abrir a estação"
          )
        ),
        if (!is.null(sf_lines) || !is.null(sf_stations)) {
          leafletOutput("map", height = "600px")
        } else {
          div(
            class = "station-empty",
            div(class = "empty-icon", bs_icon("geo-alt")),
            div(class = "empty-title", "Dados espaciais indisponíveis"),
            div(
              class = "empty-text",
              "Não foi possível carregar os dados geográficos de linhas e estações."
            )
          )
        }
      )
    ),

    ## Tab: Download ----
    nav_panel(
      title = "Download",
      icon = bs_icon("download"),

      div(
        class = "section-label",
        "Datasets disponíveis"
      ),

      layout_column_wrap(
        width = 1 / 2,
        heights_equal = "row",
        !!!lapply(download_card_configs, make_download_card)
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
              "O ",
              tags$b("metrosp"),
              " é um pacote R de dados que disponibiliza ",
              sprintf(
                "informações de demanda de passageiros do Metrô de São Paulo (%s–%s). ",
                format(DATA_MIN, "%Y"),
                format(DATA_MAX, "%Y")
              ),
              "Similar ao ",
              tags$code("nycflights13"),
              ", o pacote contém apenas datasets, ",
              "sem funções voltadas ao usuário."
            ),
            tags$p(
              sprintf(
                "Este explorador cobre o período de %s a %s (a visualização padrão começa em %s), ",
                fmt_month_pt(DATA_MIN),
                fmt_month_pt(DATA_MAX),
                fmt_month_pt(DEFAULT_START)
              ),
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
            tags$ul(
              class = "small",
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
            tags$ul(
              class = "small",
              tags$li(tags$a(
                href = "https://geosampa.prefeitura.sp.gov.br/",
                target = "_blank",
                "GeoSampa — Prefeitura de São Paulo"
              ))
            ),
            tags$h6("Limitações conhecidas"),
            tags$ul(
              class = "small text-muted",
              tags$li("Linhas 4/5 — passageiros transportados não disponíveis"),
              tags$li("Linhas 4/5 — código de estação é NA"),
              tags$li("2017: dados disponíveis apenas de outubro a dezembro"),
              tags$li(
                sprintf(
                  "Meses após %s ainda não publicados pela fonte",
                  fmt_month_pt(DATA_MAX)
                )
              )
            )
          )
        )
      )
    ),

    nav_spacer(),
    nav_item(
      tags$span(
        class = "source-tag",
        sprintf("Dados até %s", fmt_month_pt(DATA_MAX)),
        " · Fontes: METRO SP · Insper Dataverse · GeoSampa"
      )
    )
  )
}

# Server ----

server <- function(input, output, session) {
  ## Lines tab ----

  lines_data <- reactive({
    lns <- input$lines_line
    req(length(lns) > 0)

    start <- date_or(input$lines_start, DEFAULT_START)
    base <- if (input$lines_metric == "entrance") ent else trans
    df <- base |> filter(line_number %in% lns, date >= start)

    show_trend <- isTRUE(input$lines_trend) &&
      length(lns) == 1 &&
      HAS_TRENDSERIES
    if (!show_trend || nrow(df) == 0) {
      return(df)
    }

    tryCatch(
      trendseries::augment_trends(
        df,
        date_col = "date",
        value_col = "value",
        group_cols = "line_number",
        methods = "stl",
        params = list(robust = TRUE, s.window = 13),
        .quiet = TRUE
      ),
      error = function(e) {
        message("STL trend failed for line ", lns, ": ", conditionMessage(e))
        df |> mutate(trend_stl = NA_real_)
      }
    )
  }) |>
    bindCache(
      input$lines_line,
      input$lines_metric,
      input$lines_start,
      input$lines_trend
    )

  output$lines_kpis <- renderUI({
    lns <- input$lines_line
    req(length(lns) > 0)

    # full series (not start-date filtered) so KPIs describe the selection,
    # not the visible window; keep only months every selected line reported
    base <- if (input$lines_metric == "entrance") ent else trans
    monthly <- base |>
      filter(line_number %in% lns, !is.na(value)) |>
      group_by(date) |>
      summarise(value = sum(value), n_lines = n(), .groups = "drop") |>
      filter(n_lines == length(lns))
    req(nrow(monthly) > 0)

    latest <- monthly |> slice_max(date, n = 1)
    recent <- monthly |> filter(date > latest$date - 365)
    prior <- monthly |>
      filter(date > latest$date - 730, date <= latest$date - 365)
    base_2019 <- monthly |> filter(format(date, "%Y") == "2019")

    yoy_label <- if (nrow(recent) >= 6 && nrow(prior) >= 6) {
      fmt_pct((mean(recent$value) / mean(prior$value) - 1) * 100)
    } else {
      "—"
    }
    vs2019_label <- if (nrow(recent) >= 6 && nrow(base_2019) >= 6) {
      fmt_pct((mean(recent$value) / mean(base_2019$value) - 1) * 100)
    } else {
      "—"
    }
    peak <- monthly |> slice_max(value, n = 1)

    div(
      class = "kpi-grid kpi-grid-4",
      kpi_card("Último mês", fmt_n(latest$value), fmt_month_pt(latest$date)),
      kpi_card("Variação anual", yoy_label, "últimos 12m vs. anteriores"),
      kpi_card("vs. 2019", vs2019_label, "últimos 12m vs. média de 2019"),
      kpi_card("Mês de pico", fmt_n(peak$value[1]), fmt_month_pt(peak$date[1]))
    )
  })

  output$lines_title <- renderText({
    lns <- input$lines_line
    metric_lbl <- if (input$lines_metric == "entrance") {
      "Embarques"
    } else {
      "Transportados"
    }
    if (length(lns) == 1) {
      paste0(metric_lbl, " — ", line_labels[lns])
    } else {
      paste0(metric_lbl, " — ", length(lns), " linhas")
    }
  })

  output$lines_chart <- renderEcharts4r({
    df <- lines_data()
    validate(need(
      nrow(df) > 0,
      paste(
        "Sem dados para a seleção atual. Verifique o período escolhido;",
        "as linhas 4 e 5 não possuem dados de passageiros transportados."
      )
    ))
    lns <- input$lines_line
    show_trend <- isTRUE(input$lines_trend) &&
      length(lns) == 1 &&
      HAS_TRENDSERIES

    if (length(lns) == 1) {
      col <- unname(line_colors[lns])
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

      if (show_trend && any(!is.na(df$trend_stl %||% NA))) {
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
    } else {
      df <- df |>
        mutate(
          line_label = factor(
            unname(line_labels[line_number]),
            levels = unname(line_labels[lns])
          )
        ) |>
        arrange(line_label, date)
      cols <- unname(line_colors[lns])

      e <- df |>
        group_by(line_label) |>
        e_charts(date) |>
        e_line(
          value,
          symbol = "none",
          smooth = FALSE,
          lineStyle = list(width = 2.2),
          emphasis = list(focus = "series", lineStyle = list(width = 3))
        ) |>
        e_color(cols)
    }

    e |> e_metro_defaults()
  })

  output$lines_note <- renderUI({
    df <- lines_data()
    lns <- input$lines_line
    missing <- setdiff(lns, unique(df$line_number))
    if (nrow(df) == 0 || length(missing) == 0) {
      return(NULL)
    }
    div(
      class = "small text-muted px-3 pb-2",
      bs_icon("exclamation-triangle", class = "me-1"),
      paste0(
        "Sem dados para: ",
        paste(line_labels[missing], collapse = ", "),
        if (input$lines_metric == "transported") {
          " (linhas 4 e 5 não possuem passageiros transportados)."
        } else {
          " no período selecionado."
        }
      )
    )
  })

  output$dl_lines_csv <- downloadHandler(
    filename = function() {
      lns <- paste(input$lines_line, collapse = "-")
      paste0("metrosp-linhas-", lns, "-", input$lines_metric, ".csv")
    },
    content = function(file) {
      readr::write_excel_csv2(lines_data(), file)
    }
  )

  ## Stations tab ----

  # Station requested by a map-marker click, applied when the line observer
  # below rebuilds the station choices
  pending_station <- reactiveVal(NULL)

  # freezeReactiveValue() stops downstream reactives from seeing the stale
  # station/year during the flush before the update lands. Valid selections
  # are preserved so switching lines (and bookmark restore) keeps them.
  observeEvent(input$sta_line, {
    choices <- stations_by_line |>
      filter(line_number == input$sta_line) |>
      pull(station_name)
    target <- pending_station() %||% input$sta_station
    pending_station(NULL)
    freezeReactiveValue(input, "sta_station")
    updateSelectizeInput(
      session,
      "sta_station",
      choices = choices,
      selected = if (isTRUE(target %in% choices)) target else choices[1]
    )
  })

  observeEvent(input$sta_station, {
    req(input$sta_station)
    years <- sta_daily_years |>
      filter(
        line_number == input$sta_line,
        station_name == input$sta_station
      ) |>
      pull(year)
    current <- input$sta_year
    freezeReactiveValue(input, "sta_year")
    updateSelectInput(
      session,
      "sta_year",
      choices = years,
      selected = if (isTRUE(current %in% as.character(years))) {
        current
      } else if (length(years)) {
        years[1]
      }
    )
  })

  sta_monthly_data <- reactive({
    ln <- input$sta_line
    sta <- input$sta_station
    req(ln, sta)

    start <- date_or(input$sta_start, DEFAULT_START)
    df <- sta_avg |>
      filter(line_number == ln, station_name == sta, date >= start)
    show_trend <- isTRUE(input$sta_trend) && HAS_TRENDSERIES

    if (!show_trend || sum(!is.na(df$value)) < 24L) {
      return(df)
    }

    tryCatch(
      trendseries::augment_trends(
        df,
        date_col = "date",
        value_col = "value",
        group_cols = c("line_number", "station_name"),
        methods = "stl",
        params = list(robust = TRUE, s.window = 13),
        .quiet = TRUE
      ),
      error = function(e) {
        message(
          "STL trend failed for ",
          sta,
          " (L",
          ln,
          "): ",
          conditionMessage(e)
        )
        df |> mutate(trend_stl = NA_real_)
      }
    )
  }) |>
    bindCache(
      input$sta_line,
      input$sta_station,
      input$sta_start,
      input$sta_trend
    )

  sta_daily_data <- reactive({
    ln <- input$sta_line
    sta <- input$sta_station
    yr <- input$sta_year
    req(ln, sta, yr)
    sta_daily |>
      filter(line_number == ln, station_name == sta, year == as.integer(yr)) |>
      arrange(date)
  })

  output$sta_kpis <- renderUI({
    req(input$sta_station, input$sta_line)

    df_monthly <- sta_monthly_data()
    req(nrow(df_monthly) > 0)
    yr <- input$sta_year
    df_daily <- if (!is.null(yr) && nzchar(yr)) {
      sta_daily |>
        filter(
          line_number == input$sta_line,
          station_name == input$sta_station,
          year == as.integer(yr)
        )
    } else {
      data.frame()
    }

    wd_avg <- if (nrow(df_daily) > 0) {
      wd <- df_daily |> filter(as.integer(format(date, "%u")) <= 5)
      if (nrow(wd) > 0) fmt_n(mean(wd$value, na.rm = TRUE)) else "—"
    } else {
      "—"
    }

    we_avg <- if (nrow(df_daily) > 0) {
      we <- df_daily |> filter(as.integer(format(date, "%u")) >= 6)
      if (nrow(we) > 0) fmt_n(mean(we$value, na.rm = TRUE)) else "—"
    } else {
      "—"
    }

    peak <- df_monthly |> filter(!is.na(value)) |> slice_max(value, n = 1)
    peak_val <- if (nrow(peak) > 0) fmt_n(peak$value) else "—"
    peak_when <- if (nrow(peak) > 0) fmt_month_pt(peak$date[1]) else ""

    latest <- max(df_monthly$date, na.rm = TRUE)
    recent <- df_monthly |> filter(date > latest - 365, !is.na(value))
    prior <- df_monthly |>
      filter(date > latest - 730, date <= latest - 365, !is.na(value))
    yoy_label <- if (nrow(recent) >= 6 && nrow(prior) >= 6) {
      yoy <- (mean(recent$value, na.rm = TRUE) /
        mean(prior$value, na.rm = TRUE) -
        1) *
        100
      fmt_pct(yoy)
    } else {
      "—"
    }

    yr_label <- if (!is.null(yr) && nzchar(yr)) yr else ""

    div(
      class = "kpi-grid kpi-grid-4",
      kpi_card(
        "Média dias úteis",
        wd_avg,
        paste0("embarques/dia — ", yr_label)
      ),
      kpi_card(
        "Média fins de semana",
        we_avg,
        paste0("embarques/dia — ", yr_label)
      ),
      kpi_card("Mês de pico", peak_val, peak_when),
      kpi_card("Variação anual", yoy_label, "últimos 12m vs. anteriores")
    )
  })

  output$sta_monthly_title <- renderText({
    paste0(input$sta_station, " — Média dias úteis (mensal)")
  })

  output$sta_chart <- renderEcharts4r({
    df <- sta_monthly_data()
    validate(need(nrow(df) > 0, "Sem dados mensais para esta estação."))

    col <- unname(line_colors[input$sta_line])
    show_trend <- isTRUE(input$sta_trend) && HAS_TRENDSERIES

    e <- df |>
      e_charts(date) |>
      e_line(
        value,
        name = "Observado",
        symbol = "circle",
        symbolSize = 4,
        smooth = FALSE,
        lineStyle = list(width = if (show_trend) 1.2 else 2.2, color = col),
        itemStyle = list(color = col)
      )

    if (show_trend && any(!is.na(df$trend_stl %||% NA))) {
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

    # Shade opening + ramp-up window (excluded from baseline comparisons)
    rw <- ramp_windows |>
      filter(
        line_number == input$sta_line,
        station_name == input$sta_station,
        ramp_up_end >= min(df$date)
      )
    if (nrow(rw) == 1) {
      e <- e |>
        e_mark_area(
          data = list(
            list(
              xAxis = format(max(rw$inauguration_date, min(df$date))),
              name = "Abertura / ramp-up"
            ),
            list(xAxis = format(rw$ramp_up_end))
          ),
          itemStyle = list(color = "rgba(184, 144, 0, 0.12)"),
          label = list(color = "#8A6D00", fontSize = 11),
          silent = TRUE
        )
    }

    e |> e_metro_defaults(grid_bottom = 50)
  })

  output$sta_daily_title <- renderText({
    yr <- if (!is.null(input$sta_year) && nzchar(input$sta_year)) {
      input$sta_year
    } else {
      ""
    }
    paste0(input$sta_station, " — Série diária (", yr, ")")
  })

  output$sta_daily_chart <- renderEcharts4r({
    df <- sta_daily_data()
    validate(need(nrow(df) > 0, "Sem dados diários para o ano selecionado."))

    col <- unname(line_colors[input$sta_line])
    df <- df |> mutate(rolling7 = roll_mean(value))

    e <- df |>
      e_charts(date) |>
      e_line(
        value,
        name = "Diário",
        symbol = "none",
        smooth = FALSE,
        lineStyle = list(width = 1, color = "#C8CAD3")
      )

    if (nrow(df) >= 7L) {
      e <- e |>
        e_line(
          rolling7,
          name = "Média 7 dias",
          symbol = "none",
          smooth = FALSE,
          lineStyle = list(width = 2.4, color = col),
          connectNulls = FALSE
        )
    }

    e |>
      e_metro_defaults(grid_bottom = 50) |>
      e_legend(top = 0, itemWidth = 12, itemHeight = 6)
  })

  output$dl_sta_csv <- downloadHandler(
    filename = function() {
      sta_slug <- gsub(" ", "-", tolower(input$sta_station))
      paste0("metrosp-estacao-", sta_slug, "-mensal.csv")
    },
    content = function(file) {
      readr::write_excel_csv2(sta_monthly_data(), file)
    }
  )

  output$dl_sta_daily_csv <- downloadHandler(
    filename = function() {
      sta_slug <- gsub(" ", "-", tolower(input$sta_station))
      paste0("metrosp-estacao-", sta_slug, "-diario-", input$sta_year, ".csv")
    },
    content = function(file) {
      readr::write_excel_csv2(sta_daily_data(), file)
    }
  )

  ## Map tab ----

  output$map <- renderLeaflet({
    m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron)

    if (!is.null(sf_stations_map)) {
      bbox <- sf::st_bbox(sf_stations_map)
      m <- m |>
        fitBounds(
          lng1 = bbox[["xmin"]],
          lat1 = bbox[["ymin"]],
          lng2 = bbox[["xmax"]],
          lat2 = bbox[["ymax"]]
        )
    } else {
      m <- m |> setView(lng = -46.633, lat = -23.555, zoom = 12)
    }

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

    if (!is.null(sf_stations_map)) {
      hover_labels <- lapply(seq_len(nrow(sf_stations_map)), function(i) {
        s <- sf_stations_map[i, , drop = FALSE]
        demand <- if (is.na(s$avg)) {
          "Sem dados de demanda"
        } else {
          paste0("Média dias úteis: <b>", fmt_n(s$avg), "</b> pass./dia")
        }
        htmltools::HTML(paste0(
          "<b>",
          s$station_name,
          "</b><br/>",
          line_labels[s$line_number],
          "<br/>",
          demand
        ))
      })

      m <- m |>
        addCircleMarkers(
          data = sf_stations_map,
          layerId = paste(
            sf_stations_map$line_number,
            sf_stations_map$station_name,
            sep = "||"
          ),
          radius = ~radius,
          color = "white",
          fillColor = ~ line_colors[line_number],
          fillOpacity = 0.9,
          weight = 1.5,
          stroke = TRUE,
          label = hover_labels,
          labelOptions = labelOptions(
            style = list(
              "font-family" = "Inter, -apple-system, sans-serif",
              "font-size" = "13px",
              "padding" = "8px 12px",
              "border-radius" = "6px",
              "box-shadow" = "0 2px 8px rgba(14,17,48,0.12)"
            ),
            direction = "auto"
          )
        )
    }

    m
  })

  observeEvent(input$map_marker_click, {
    id <- input$map_marker_click$id
    req(is.character(id), nzchar(id))
    parts <- strsplit(id, "||", fixed = TRUE)[[1]]
    req(length(parts) == 2)
    ln <- parts[1]
    sta <- parts[2]

    has_data <- stations_by_line |>
      filter(line_number == ln, station_name == sta)
    if (nrow(has_data) == 0) {
      showNotification(
        "Sem dados de demanda para esta estação.",
        type = "message"
      )
      return()
    }

    nav_select("main_nav", "Estações")
    if (identical(input$sta_line, ln)) {
      updateSelectizeInput(session, "sta_station", selected = sta)
    } else {
      pending_station(sta)
      updateSelectInput(session, "sta_line", selected = ln)
    }
  })

  ## Download handlers ----
  # Serve the package datasets verbatim so downloads match the documented
  # schemas (charts use filtered/renamed copies; downloads must not)

  make_csv_handler <- function(data, prefix) {
    downloadHandler(
      filename = function() paste0("metrosp-", prefix, ".csv"),
      content = function(file) {
        readr::write_excel_csv2(data, file)
      }
    )
  }

  make_xlsx_handler <- function(data, prefix) {
    downloadHandler(
      filename = function() paste0("metrosp-", prefix, ".xlsx"),
      content = function(file) writexl::write_xlsx(data, file)
    )
  }

  output$dl_ent_csv <- make_csv_handler(
    metrosp::passengers_entrance,
    "passengers-entrance"
  )
  output$dl_ent_xlsx <- make_xlsx_handler(
    metrosp::passengers_entrance,
    "passengers-entrance"
  )
  output$dl_trans_csv <- make_csv_handler(
    metrosp::passengers_transported,
    "passengers-transported"
  )
  output$dl_trans_xlsx <- make_xlsx_handler(
    metrosp::passengers_transported,
    "passengers-transported"
  )
  output$dl_staavg_csv <- make_csv_handler(
    metrosp::station_averages,
    "station-averages"
  )
  output$dl_staavg_xlsx <- make_xlsx_handler(
    metrosp::station_averages,
    "station-averages"
  )
  output$dl_stadaily_csv <- make_csv_handler(
    metrosp::station_daily,
    "station-daily"
  )
  output$dl_stadaily_xlsx <- make_xlsx_handler(
    metrosp::station_daily,
    "station-daily"
  )

  make_spatial_handler <- function(sf_data, prefix, driver) {
    downloadHandler(
      filename = function() paste0("metrosp-", prefix, ".", tolower(driver)),
      content = function(file) {
        sf::st_write(sf_data, file, driver = driver, quiet = TRUE)
      }
    )
  }

  output$dl_lines_gpkg <- make_spatial_handler(metrosp::lines, "lines", "GPKG")
  output$dl_lines_geojson <- make_spatial_handler(
    metrosp::lines,
    "lines",
    "GeoJSON"
  )
  output$dl_stations_gpkg <- make_spatial_handler(
    metrosp::stations,
    "stations",
    "GPKG"
  )
  output$dl_stations_geojson <- make_spatial_handler(
    metrosp::stations,
    "stations",
    "GeoJSON"
  )
}

shinyApp(ui, server, enableBookmarking = "url")
