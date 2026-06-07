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

## Station daily entries ----
sta_daily <- metrosp::station_daily |>
  filter(date >= DATA_START) |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES) |>
  select(date, line_number, station_name, value = passengers, year)

## Available years per station ----
sta_daily_years <- sta_daily |>
  distinct(line_number, station_name, year) |>
  arrange(line_number, station_name, desc(year))

## Station lookup per line ----
stations_by_line <- sta_daily |>
  distinct(line_number, station_name) |>
  arrange(line_number, station_name)

## Station coordinates + demand for map markers ----
sf_stations <- metrosp::stations |>
  filter(status == "current", type == "metro") |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES)

coords <- sf::st_coordinates(sf_stations)
stations_geo <- sf_stations |>
  sf::st_drop_geometry() |>
  mutate(lng = coords[, 1], lat = coords[, 2]) |>
  select(station_name, line_number, lng, lat)

sta_avg_raw <- metrosp::station_averages |>
  filter(date >= DATA_START, !is.na(avg_passenger)) |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES)

latest_avg <- max(sta_avg_raw$date, na.rm = TRUE)
sta_demand <- sta_avg_raw |>
  filter(date > latest_avg - 365) |>
  group_by(line_number, station_name) |>
  summarise(avg_demand = round(mean(avg_passenger, na.rm = TRUE)), .groups = "drop")

station_map_data <- sta_demand |>
  inner_join(stations_geo, by = c("line_number", "station_name"))

## Line geometries ----
sf_lines <- tryCatch(
  metrosp::lines |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) NULL
)

# Helpers ----

cal_palette <- function(hex) {
  grDevices::colorRampPalette(c("#EDEEF3", hex))(5)
}

dow_labels_pt <- c("Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom")

month_labels_pt <- c(
  "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
  "Jul", "Ago", "Set", "Out", "Nov", "Dez"
)

# UI ----

ui <- page_sidebar(
  title = tags$span(
    bs_icon("train-front-fill", size = "1.05em", class = "me-2"),
    "Metro SP — Heatmap"
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
      "station", "Estação",
      choices = NULL,
      options = list(placeholder = "Buscar estação...")
    ),
    selectInput("year", "Ano", choices = NULL),
    hr(),
    tags$p(
      class = "text-muted small mb-0",
      "Mapa de calor dos embarques diários por estação. ",
      "Cores proporcionais ao volume: mais escuro = mais passageiros. ",
      "Clique numa estação no mapa para selecioná-la."
    )
  ),

  tags$head(tags$link(rel = "stylesheet", href = "styles.css")),

  uiOutput("kpis"),

  card(
    full_screen = TRUE,
    card_header(
      class = "d-flex align-items-center gap-2",
      bs_icon("calendar3"),
      textOutput("cal_title", inline = TRUE)
    ),
    echarts4rOutput("cal_heatmap", height = "240px")
  ),

  layout_columns(
    col_widths = c(5, 7),
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center gap-2",
        bs_icon("geo-alt-fill"),
        "Estações — mapa"
      ),
      leafletOutput("map", height = "340px")
    ),
    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center gap-2",
        bs_icon("bar-chart-fill"),
        textOutput("dow_title", inline = TRUE)
      ),
      echarts4rOutput("dow_chart", height = "340px")
    )
  )
)

# Server ----

server <- function(input, output, session) {

  ## Update station choices on line change ----
  observeEvent(input$line, {
    choices <- stations_by_line |>
      filter(line_number == input$line) |>
      pull(station_name)
    updateSelectizeInput(session, "station",
      choices = choices, selected = choices[1]
    )
  })

  ## Update year choices on station change ----
  observeEvent(input$station, {
    req(input$station)
    years <- sta_daily_years |>
      filter(line_number == input$line, station_name == input$station) |>
      pull(year)
    updateSelectInput(session, "year",
      choices = years,
      selected = if (length(years)) years[1]
    )
  })

  ## Station selection from map click ----
  observeEvent(input$map_marker_click, {
    updateSelectizeInput(session, "station",
      selected = input$map_marker_click$id
    )
  })

  ## Daily data for selected station + year ----
  daily_data <- reactive({
    req(input$line, input$station, input$year)
    sta_daily |>
      filter(
        line_number == input$line,
        station_name == input$station,
        year == as.integer(input$year)
      ) |>
      arrange(date)
  })

  ## KPIs ----
  output$kpis <- renderUI({
    df <- daily_data()
    req(nrow(df) > 0)

    avg_all <- mean(df$value, na.rm = TRUE)

    wd <- df |> filter(as.integer(format(date, "%u")) <= 5)
    avg_wd <- if (nrow(wd) > 0) mean(wd$value, na.rm = TRUE) else NA
    we <- df |> filter(as.integer(format(date, "%u")) >= 6)
    avg_we <- if (nrow(we) > 0) mean(we$value, na.rm = TRUE) else NA

    peak <- df |> filter(!is.na(value)) |> slice_max(value, n = 1)
    peak_val <- if (nrow(peak) > 0) fmt_n(peak$value[1]) else "—"
    peak_date <- if (nrow(peak) > 0) format(peak$date[1], "%d/%m/%Y") else ""

    div(
      class = "kpi-grid kpi-grid-4",
      kpi_card("Média diária", fmt_n(avg_all),
        paste0(input$station, " — ", input$year)),
      kpi_card("Dias úteis", fmt_n(avg_wd), "embarques/dia"),
      kpi_card("Fins de semana", fmt_n(avg_we), "embarques/dia"),
      kpi_card("Dia de pico", peak_val, peak_date)
    )
  })

  ## Calendar heatmap ----
  output$cal_title <- renderText({
    paste0(input$station, " — Embarques diários (", input$year, ")")
  })

  output$cal_heatmap <- renderEcharts4r({
    df <- daily_data() |> filter(!is.na(value))
    validate(need(
      nrow(df) > 0,
      "Sem dados diários para esta combinação."
    ))

    col <- line_colors[input$line]
    pal <- cal_palette(col)
    max_val <- max(df$value, na.rm = TRUE)

    df |>
      mutate(date = as.character(date)) |>
      e_charts(date) |>
      e_calendar(
        range = input$year,
        cellSize = list("auto", 14),
        left = 60, right = 30, top = 30, bottom = 45,
        orient = "horizontal",
        splitLine = list(
          lineStyle = list(color = "#FFFFFF", width = 2)
        ),
        itemStyle = list(
          borderColor = "#FFFFFF", borderWidth = 2, borderRadius = 2
        ),
        dayLabel = list(
          nameMap = c("Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"),
          fontSize = 10, color = "#6B7280"
        ),
        monthLabel = list(
          nameMap = month_labels_pt,
          fontSize = 11, color = "#4A4F6B"
        )
      ) |>
      e_heatmap(value, coord_system = "calendar") |>
      e_visual_map(
        min = 0,
        max = max_val,
        calculable = TRUE,
        orient = "horizontal",
        bottom = 0, left = "center",
        inRange = list(color = pal),
        textStyle = list(fontSize = 10, color = "#6B7280")
      ) |>
      e_tooltip(
        formatter = htmlwidgets::JS(
          "function(params) {",
          "  var raw = params.value[0];",
          "  var v = params.value[1];",
          "  var d = new Date(raw + 'T12:00:00');",
          "  var days = ['Dom','Seg','Ter','Qua','Qui','Sex','S\\u00e1b'];",
          "  var day = days[d.getDay()];",
          "  var dateStr = d.toLocaleDateString('pt-BR');",
          "  var label = v != null ? v.toLocaleString('pt-BR') : '\\u2014';",
          "  return '<b>' + day + ', ' + dateStr + '</b><br/>' +",
          "         'Embarques: <b>' + label + '</b>';",
          "}"
        )
      )
  })

  ## Map ----
  output$map <- renderLeaflet({
    df <- station_map_data |> filter(line_number == input$line)
    req(nrow(df) > 0)

    max_avg <- max(df$avg_demand, na.rm = TRUE)
    df <- df |> mutate(radius = 5 + 12 * sqrt(avg_demand / max_avg))
    col <- line_colors[input$line]

    m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron)

    if (!is.null(sf_lines)) {
      geom <- sf_lines |> filter(line_number == input$line)
      if (nrow(geom) > 0) {
        m <- m |> addPolylines(
          data = geom, color = col, weight = 3, opacity = 0.4
        )
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

  ## Map: highlight selected station ----
  observe({
    req(input$station)
    df <- station_map_data |> filter(line_number == input$line)
    proxy <- leafletProxy("map")
    proxy |> clearGroup("highlight")

    if (input$station %in% df$station_name) {
      row <- df |> filter(station_name == input$station)
      proxy |> addCircleMarkers(
        data = row, lng = ~lng, lat = ~lat,
        radius = 16,
        color = line_colors[input$line],
        fillColor = "transparent", fillOpacity = 0,
        weight = 3, stroke = TRUE,
        group = "highlight"
      )
    }
  })

  ## Day-of-week bar chart ----
  output$dow_title <- renderText({
    paste0("Padrão semanal — ", input$station, " (", input$year, ")")
  })

  output$dow_chart <- renderEcharts4r({
    df <- daily_data() |> filter(!is.na(value))
    validate(need(nrow(df) > 0, "Sem dados diários."))

    col <- line_colors[input$line]
    weekend_col <- grDevices::colorRampPalette(c("#D0D3DC", col))(3)[2]

    dow_data <- df |>
      mutate(
        dow_n = as.integer(format(date, "%u")),
        dow = factor(dow_labels_pt[dow_n], levels = dow_labels_pt)
      ) |>
      group_by(dow) |>
      summarise(avg = round(mean(value, na.rm = TRUE)), .groups = "drop")

    dow_data |>
      e_charts(dow) |>
      e_bar(
        avg,
        name = "Média embarques",
        barWidth = "50%",
        itemStyle = list(
          borderRadius = c(3, 3, 0, 0),
          color = htmlwidgets::JS(sprintf(
            "function(params) { return params.dataIndex >= 5 ? '%s' : '%s'; }",
            weekend_col, col
          ))
        )
      ) |>
      e_grid(left = 60, right = 20, top = 20, bottom = 30) |>
      e_x_axis(axisLabel = list(fontSize = 12, color = "#4A4F6B")) |>
      e_y_axis(
        axisLabel = list(formatter = js_axis_label_compact, color = "#6B7280"),
        splitLine = list(
          lineStyle = list(type = "dashed", color = "#E8E9EF")
        )
      ) |>
      e_tooltip(
        trigger = "axis",
        formatter = htmlwidgets::JS(
          "function(params) {",
          "  var p = Array.isArray(params) ? params[0] : params;",
          "  var v = (typeof p.value === 'object') ? p.value[1] : p.value;",
          "  var label = v != null ? v.toLocaleString('pt-BR') : '\\u2014';",
          "  return '<b>' + p.name + '</b><br/>' +",
          "         'M\\u00e9dia: <b>' + label + '</b> embarques/dia';",
          "}"
        )
      ) |>
      e_legend(show = FALSE)
  })
}

shinyApp(ui, server)
