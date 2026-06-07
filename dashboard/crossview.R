library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(leaflet)
library(echarts4r)
library(metrosp)
library(sf)
library(htmltools)

source("shared.R", local = TRUE)

# Constants ----

DATA_START <- as.Date("2019-01-01")

# Pre-build data ----

## Station monthly averages ----
sta_avg <- metrosp::station_averages |>
  filter(date >= DATA_START) |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES) |>
  select(date, line_number, station_name, value = avg_passenger, year)

## Station demand summary (last 12 months) ----
latest_date <- max(sta_avg$date, na.rm = TRUE)

sta_summary <- sta_avg |>
  filter(!is.na(value), date > latest_date - 365) |>
  group_by(line_number, station_name) |>
  summarise(avg_demand = round(mean(value, na.rm = TRUE)), .groups = "drop")

## Station coordinates ----
sf_stations <- metrosp::stations |>
  filter(status == "current", type == "metro") |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES)

coords <- sf::st_coordinates(sf_stations)
stations_geo <- sf_stations |>
  sf::st_drop_geometry() |>
  mutate(lng = coords[, 1], lat = coords[, 2]) |>
  select(station_name, line_number, lng, lat)

station_map_data <- sta_summary |>
  inner_join(stations_geo, by = c("line_number", "station_name"))

## Line geometries ----
sf_lines <- tryCatch(
  metrosp::lines |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) NULL
)

# UI ----

ui <- page_sidebar(
  title = tags$span(
    bs_icon("train-front-fill", size = "1.05em", class = "me-2"),
    "Metro SP — Crossview"
  ),
  theme = metro_theme,
  lang = "pt-BR",
  fillable = FALSE,

  sidebar = sidebar(
    title = div(class = "sidebar-title", "Filtros"),
    width = 260,
    selectInput(
      "line", "Linha",
      choices = setNames(LINES, unname(line_labels)),
      selected = "1"
    ),
    selectizeInput(
      "station_search", "Buscar estação",
      choices = NULL,
      options = list(placeholder = "Todas as estações...")
    ),
    actionButton("clear_sel", "Limpar seleção",
      class = "btn-sm btn-outline-secondary w-100 mt-2"
    ),
    hr(),
    tags$p(
      class = "text-muted small mb-0",
      "Clique numa estação no mapa ou no ranking para ver a série mensal. ",
      "Círculos proporcionais à demanda média (últimos 12 meses)."
    )
  ),

  tags$head(tags$link(rel = "stylesheet", href = "styles.css")),

  uiOutput("kpis"),

  layout_column_wrap(
    width = 1 / 2,
    heights_equal = "row",
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center gap-2",
        bs_icon("geo-alt-fill"),
        "Estações — mapa"
      ),
      leafletOutput("map", height = "460px")
    ),
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center gap-2",
        bs_icon("bar-chart-fill"),
        textOutput("bar_title", inline = TRUE)
      ),
      echarts4rOutput("bar_chart", height = "460px")
    )
  ),

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex align-items-center gap-2",
      bs_icon("graph-up"),
      textOutput("ts_title", inline = TRUE)
    ),
    echarts4rOutput("ts_chart", height = "300px")
  )
)

# Server ----

server <- function(input, output, session) {

  sel_station <- reactiveVal(NULL)

  ## Update station choices on line change ----
  observeEvent(input$line, {
    choices <- station_map_data |>
      filter(line_number == input$line) |>
      arrange(station_name) |>
      pull(station_name)
    freezeReactiveValue(input, "station_search")
    updateSelectizeInput(session, "station_search",
      choices = c("" = "", choices), selected = ""
    )
    sel_station(NULL)
  })

  ## Selection: search dropdown ----
  observeEvent(input$station_search, {
    if (nzchar(input$station_search)) sel_station(input$station_search)
  }, ignoreInit = TRUE)

  ## Selection: map click ----
  observeEvent(input$map_marker_click, {
    id <- input$map_marker_click$id
    freezeReactiveValue(input, "station_search")
    updateSelectizeInput(session, "station_search", selected = id)
    sel_station(id)
  })

  ## Selection: bar chart click ----
  observeEvent(input$bar_click, {
    freezeReactiveValue(input, "station_search")
    updateSelectizeInput(session, "station_search", selected = input$bar_click)
    sel_station(input$bar_click)
  })

  ## Clear selection ----
  observeEvent(input$clear_sel, {
    freezeReactiveValue(input, "station_search")
    updateSelectizeInput(session, "station_search", selected = "")
    sel_station(NULL)
  })

  ## Current line stations ----
  line_stations <- reactive({
    station_map_data |>
      filter(line_number == input$line) |>
      arrange(desc(avg_demand))
  })

  ## KPIs ----
  output$kpis <- renderUI({
    df <- line_stations()
    sel <- sel_station()

    if (!is.null(sel) && sel %in% df$station_name) {
      row <- df |> filter(station_name == sel)
      rank_pos <- which(df$station_name == sel)

      monthly <- sta_avg |>
        filter(line_number == input$line, station_name == sel, !is.na(value))
      latest <- max(monthly$date, na.rm = TRUE)
      recent <- monthly |> filter(date > latest - 365)
      prior <- monthly |> filter(date > latest - 730, date <= latest - 365)
      yoy <- if (nrow(recent) >= 6 && nrow(prior) >= 6) {
        fmt_pct((mean(recent$value) / mean(prior$value) - 1) * 100)
      } else {
        "—"
      }

      div(
        class = "kpi-grid kpi-grid-4",
        kpi_card("Estação", sel, line_labels[input$line]),
        kpi_card("Média dias úteis", fmt_n(row$avg_demand),
          "embarques/dia (12m)"),
        kpi_card("Ranking", paste0(rank_pos, "º / ", nrow(df)), "na linha"),
        kpi_card("Variação anual", yoy, "12m vs. anteriores")
      )
    } else {
      div(
        class = "kpi-grid kpi-grid-4",
        kpi_card("Estações", as.character(nrow(df)),
          line_labels[input$line]),
        kpi_card("Maior demanda", fmt_n(max(df$avg_demand)),
          df$station_name[1]),
        kpi_card("Menor demanda", fmt_n(min(df$avg_demand)),
          df$station_name[nrow(df)]),
        kpi_card("Total", fmt_n(sum(df$avg_demand)), "embarques/dia (12m)")
      )
    }
  })

  ## Map ----
  output$map <- renderLeaflet({
    df <- line_stations()
    max_avg <- max(df$avg_demand, na.rm = TRUE)
    df <- df |> mutate(radius = 5 + 14 * sqrt(avg_demand / max_avg))
    col <- line_colors[input$line]

    m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron)

    if (!is.null(sf_lines)) {
      geom <- sf_lines |> filter(line_number == input$line)
      if (nrow(geom) > 0) {
        m <- m |> addPolylines(data = geom, color = col, weight = 3, opacity = 0.4)
      }
    }

    labels <- lapply(seq_len(nrow(df)), function(i) {
      HTML(paste0(
        "<b>", df$station_name[i], "</b><br/>",
        "Média: <b>", fmt_n(df$avg_demand[i]), "</b> pass./dia"
      ))
    })

    m |>
      addCircleMarkers(
        data = df, lng = ~lng, lat = ~lat,
        radius = ~radius,
        color = "white", fillColor = col,
        fillOpacity = 0.85, weight = 1.5, stroke = TRUE,
        layerId = ~station_name,
        label = labels,
        labelOptions = labelOptions(
          style = list(
            "font-family" = "Inter, -apple-system, sans-serif",
            "font-size" = "13px",
            "padding" = "8px 12px",
            "border-radius" = "6px"
          )
        )
      ) |>
      fitBounds(
        lng1 = min(df$lng) - 0.01, lat1 = min(df$lat) - 0.01,
        lng2 = max(df$lng) + 0.01, lat2 = max(df$lat) + 0.01
      )
  })

  ## Map: highlight ring on selected station ----
  observe({
    sel <- sel_station()
    df <- line_stations()
    proxy <- leafletProxy("map")
    proxy |> clearGroup("highlight")

    if (!is.null(sel) && sel %in% df$station_name) {
      row <- df |> filter(station_name == sel)
      proxy |> addCircleMarkers(
        data = row, lng = ~lng, lat = ~lat,
        radius = 18,
        color = line_colors[input$line],
        fillColor = "transparent", fillOpacity = 0,
        weight = 3, stroke = TRUE,
        group = "highlight"
      )
    }
  })

  ## Bar chart: station ranking ----
  output$bar_title <- renderText({
    paste0("Ranking — ", line_labels[input$line])
  })

  output$bar_chart <- renderEcharts4r({
    df <- line_stations() |> arrange(avg_demand)
    sel <- sel_station()
    col <- line_colors[input$line]

    color_js <- if (is.null(sel)) {
      htmlwidgets::JS(sprintf("function() { return '%s'; }", col))
    } else {
      safe_sel <- gsub("'", "\\\\'", sel)
      htmlwidgets::JS(sprintf(
        "function(params) { return params.name === '%s' ? '%s' : '#D0D3DC'; }",
        safe_sel, col
      ))
    }

    df |>
      e_charts(station_name) |>
      e_bar(
        avg_demand,
        name = "Média dias úteis",
        barWidth = "55%",
        itemStyle = list(
          color = color_js,
          borderRadius = c(0, 3, 3, 0)
        )
      ) |>
      e_flip_coords() |>
      e_grid(left = 140, right = 40, top = 10, bottom = 30) |>
      e_x_axis(
        axisLabel = list(formatter = js_axis_label_compact),
        splitLine = list(lineStyle = list(type = "dashed", color = "#E8E9EF"))
      ) |>
      e_y_axis(
        axisLabel = list(
          fontSize = 11,
          color = "#6B7280",
          overflow = "truncate",
          width = 120
        )
      ) |>
      e_tooltip(
        trigger = "axis",
        formatter = htmlwidgets::JS(
          "function(params) {",
          "  var p = Array.isArray(params) ? params[0] : params;",
          "  var v = p.value[0];",
          "  var label = v != null ? v.toLocaleString('pt-BR') : '—';",
          "  return '<b>' + p.name + '</b><br/>Média dias úteis: <b>' + label + '</b> pass./dia';",
          "}"
        )
      ) |>
      e_legend(show = FALSE) |>
      e_on(
        query = "series.bar",
        handler = htmlwidgets::JS(
          "function(params) {",
          "  Shiny.setInputValue('bar_click', params.name, {priority: 'event'});",
          "}"
        ),
        event = "click"
      )
  })

  ## Time series: selected station ----
  output$ts_title <- renderText({
    sel <- sel_station()
    if (is.null(sel)) {
      "Série mensal — selecione uma estação"
    } else {
      paste0(sel, " — Média dias úteis (mensal)")
    }
  })

  output$ts_chart <- renderEcharts4r({
    sel <- sel_station()
    validate(need(
      !is.null(sel),
      "Clique numa estação no mapa ou no ranking para ver a série mensal."
    ))

    df <- sta_avg |>
      filter(line_number == input$line, station_name == sel, !is.na(value))
    validate(need(nrow(df) > 0, "Sem dados mensais para esta estação."))

    col <- line_colors[input$line]

    df |>
      e_charts(date) |>
      e_line(
        value,
        name = "Média dias úteis",
        symbol = "circle",
        symbolSize = 4,
        smooth = FALSE,
        lineStyle = list(width = 2.2, color = col),
        itemStyle = list(color = col)
      ) |>
      e_metro_defaults(grid_bottom = 50)
  })
}

shinyApp(ui, server)
