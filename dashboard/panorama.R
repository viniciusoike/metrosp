library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggiraph)
library(leaflet)
library(metrosp)
library(scales)
library(sf)

# ── Constants ──────────────────────────────────────────────────────────────────

# Same palette as app.R (Line 4 darkened for legibility on white)
line_colors <- c(
  "1"  = "#171796",
  "2"  = "#007A5E",
  "3"  = "#ED2E38",
  "4"  = "#B89000",
  "5"  = "#874ABF",
  "15" = "#6B6B68"
)

line_labels <- c(
  "1"  = "Linha 1 — Azul",
  "2"  = "Linha 2 — Verde",
  "3"  = "Linha 3 — Vermelha",
  "4"  = "Linha 4 — Amarela",
  "5"  = "Linha 5 — Lilás",
  "15" = "Linha 15 — Prata"
)

LINES <- names(line_labels)

covid_start <- as.Date("2020-03-01")
covid_end   <- as.Date("2021-06-30")

day_abb     <- c("Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom")
pt_months   <- c("Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                 "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro")

# ── Helpers ────────────────────────────────────────────────────────────────────

fmt_n <- function(x) {
  if (!length(x) || all(is.na(x))) return("—")
  x <- x[!is.na(x)][1]
  if (x >= 1e9) sprintf("%.2f bi", x / 1e9)
  else if (x >= 1e6) sprintf("%.1f M", x / 1e6)
  else if (x >= 1e3) sprintf("%.1f K", x / 1e3)
  else formatC(round(x), format = "d", big.mark = ".")
}

tooltip_css <- paste0(
  "background:#ffffff; border:1px solid #dddddd;",
  "padding:8px 12px; border-radius:6px;",
  "font-family:-apple-system,sans-serif;",
  "font-size:13px; line-height:1.5;",
  "box-shadow:0 2px 8px rgba(0,0,0,0.12);"
)

girafe_default_opts <- function(...) {
  list(
    opts_hover(css = "opacity: 1;"),
    opts_hover_inv(css = "opacity: 0.3;"),
    opts_tooltip(css = tooltip_css, opacity = 1, offx = 12, offy = -20),
    opts_sizing(rescale = TRUE, width = 1),
    ...
  )
}

# ── Data prep (runs once at startup) ──────────────────────────────────────────

# Monthly totals by line (metric: total passengers entering)
ent <- metrosp::passengers_entrance |>
  filter(metric_abb == "total", line_number %in% as.integer(LINES)) |>
  mutate(line_number = as.character(line_number))

# Years with usable data
avail_years <- ent |>
  filter(!is.na(value)) |>
  pull(year) |>
  unique() |>
  sort(decreasing = TRUE)

# Last full year = most recent year where all 6 lines have >= 10 months of data
last_full_year <- ent |>
  filter(!is.na(value)) |>
  group_by(year, line_number) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(year) |>
  summarise(min_n = min(n), nlines = n_distinct(line_number), .groups = "drop") |>
  filter(min_n >= 10, nlines == 6) |>
  pull(year) |>
  max()

# 2019 monthly mean per line (index base)
base_2019 <- ent |>
  filter(year == 2019, !is.na(value)) |>
  group_by(line_number) |>
  summarise(base = mean(value, na.rm = TRUE), .groups = "drop")

# Indexed series: value / mean_2019 * 100
ent_idx <- ent |>
  left_join(base_2019, by = "line_number") |>
  mutate(
    index      = value / base * 100,
    line_label = unname(line_labels[line_number]),
    month_lbl  = format(date, "%b/%Y"),
    tooltip    = paste0(
      "<b>", line_labels[line_number], "</b><br/>",
      format(date, "%B/%Y"), "<br/>",
      "Índice: <b>", round(value / base * 100, 1), "</b>"
    )
  ) |>
  filter(!is.na(index))

# YoY: lag 12 months within each line
ent_yoy <- ent |>
  filter(!is.na(value)) |>
  arrange(line_number, date) |>
  group_by(line_number) |>
  mutate(value_prev = lag(value, 12L)) |>
  ungroup() |>
  filter(!is.na(value_prev)) |>
  mutate(
    yoy       = (value - value_prev) / value_prev * 100,
    month_lbl = format(date, "%b/%Y")
  )

# Station-level data
sta_avg <- metrosp::station_averages |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES)

sta_daily_df <- metrosp::station_daily |>
  mutate(
    line_number = as.character(line_number),
    dow_num     = as.integer(format(date, "%u"))  # 1 = Mon, 7 = Sun
  ) |>
  filter(line_number %in% LINES)

sta_years <- sort(unique(sta_daily_df$year), decreasing = TRUE)

# Latest station demand (for map circle sizing)
latest_sta_avg <- sta_avg |>
  filter(year == max(year, na.rm = TRUE), !is.na(avg_passenger)) |>
  group_by(line_number, station_name) |>
  summarise(avg = mean(avg_passenger, na.rm = TRUE), .groups = "drop")

max_avg_global <- max(latest_sta_avg$avg, na.rm = TRUE)

# Spatial data (graceful fallback if sf unavailable)
sf_metro_lines <- tryCatch(
  metrosp::lines |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) NULL
)

sf_metro_stations <- tryCatch({
  sta_geo <- metrosp::stations |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES) |>
    left_join(latest_sta_avg, by = c("line_number", "station_name")) |>
    mutate(
      radius     = ifelse(is.na(avg), 5, 5 + 12 * avg / max_avg_global),
      popup_text = paste0(
        "<b>", station_name, "</b><br/>",
        line_labels[line_number], "<br/>",
        ifelse(
          is.na(avg),
          "Sem dados de demanda",
          paste0("Média dias úteis: <b>", fmt_n(avg), "</b> pass./dia")
        )
      ),
      layer_id   = paste0(line_number, "|", station_name)
    )
  sta_geo
}, error = function(e) NULL)

# ── UI ─────────────────────────────────────────────────────────────────────────

ui <- page_navbar(
  title = tags$span(
    bs_icon("train-front-fill", size = "1.1em", class = "me-2"),
    "Metro SP — Demanda"
  ),
  theme = bs_theme(
    version   = 5,
    bootswatch = "flatly",
    primary   = "#171796"
  ),
  lang = "pt-BR",
  fillable = FALSE,

  # ── Tab 1: Panorama ──────────────────────────────────────────────────────────
  nav_panel(
    title = "Panorama",
    icon  = bs_icon("grid-fill"),

    # Row: year selector + 3 KPIs
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      gap = "1rem",
      card(
        padding = "0.8rem",
        class = "border-0 bg-light",
        selectInput(
          "year_sel", "Ano de referência",
          choices  = avail_years,
          selected = last_full_year
        )
      ),
      value_box(
        title    = "Total de embarques",
        value    = textOutput("vb_total"),
        showcase = bs_icon("people-fill"),
        theme    = "primary"
      ),
      value_box(
        title    = "Linha mais movimentada",
        value    = uiOutput("vb_top_line"),
        showcase = bs_icon("train-front-fill"),
        theme    = "info"
      ),
      uiOutput("vb_yoy_panorama")
    ),

    # Row: monthly line chart + overview map
    layout_columns(
      col_widths = c(8, 4),
      gap = "1rem",
      card(
        full_screen = TRUE,
        card_header("Embarques mensais por linha"),
        girafeOutput("area_chart", height = "340px")
      ),
      card(
        full_screen = TRUE,
        card_header("Rede Metro SP"),
        leafletOutput("map_overview", height = "340px")
      )
    ),

    # Row: annual totals by line
    card(
      full_screen = TRUE,
      card_header("Total anual por linha — ano selecionado vs. anterior"),
      girafeOutput("line_bar_chart", height = "240px")
    )
  ),

  # ── Tab 2: Tendências ─────────────────────────────────────────────────────────
  nav_panel(
    title = "Tendências",
    icon  = bs_icon("graph-up"),

    layout_sidebar(
      sidebar = sidebar(
        title = "Filtros",
        checkboxGroupInput(
          "lines_trend", "Linhas",
          choices  = setNames(LINES, unname(line_labels)),
          selected = LINES
        ),
        hr(),
        tags$p(
          class = "text-muted small mb-0",
          tags$b("Índice 100"), " = média mensal de 2019.",
          tags$br(),
          "Faixa vermelha indica período COVID-19."
        )
      ),

      card(
        full_screen = TRUE,
        card_header("Índice de demanda — base 2019 = 100"),
        girafeOutput("index_chart", height = "380px")
      ),
      card(
        full_screen = TRUE,
        card_header("Variação anual da rede (linhas selecionadas)"),
        girafeOutput("yoy_trend_chart", height = "280px")
      )
    )
  ),

  # ── Tab 3: Estações ───────────────────────────────────────────────────────────
  nav_panel(
    title = "Estações",
    icon  = bs_icon("pin-map-fill"),

    layout_columns(
      col_widths = c(5, 7),
      gap = "1rem",
      card(
        full_screen = TRUE,
        card_header("Mapa de estações"),
        tags$p(class = "text-muted small px-3 pt-1 mb-1",
               "Círculos proporcionais à média de embarques em dias úteis. Clique para selecionar."),
        leafletOutput("station_map", height = "440px")
      ),
      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center justify-content-between gap-2",
          "Ranking de estações",
          selectInput(
            "line_est", NULL,
            choices  = setNames(LINES, unname(line_labels)),
            selected = "1",
            width    = "190px"
          )
        ),
        girafeOutput("station_bar", height = "440px")
      )
    ),

    # Station profile — appears only when a station is selected
    uiOutput("station_profile_ui")
  ),

  # Footer info
  nav_spacer(),
  nav_item(
    tags$small(class = "text-muted me-2",
               "Fontes: METRO SP · Insper Dataverse · GeoSampa")
  )
)

# ── Server ─────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # ── Panorama: year-filtered data ─────────────────────────────────────────────

  yr_curr <- reactive(as.integer(input$year_sel))
  yr_prev <- reactive(as.integer(input$year_sel) - 1L)

  dat_curr <- reactive({
    ent |> filter(year == yr_curr(), !is.na(value))
  })

  dat_prev <- reactive({
    ent |> filter(year == yr_prev(), !is.na(value))
  })

  # ── Panorama: KPI — total ──────────────────────────────────────────────────

  output$vb_total <- renderText({
    fmt_n(sum(dat_curr()$value, na.rm = TRUE))
  })

  # ── Panorama: KPI — top line ───────────────────────────────────────────────

  output$vb_top_line <- renderUI({
    df <- dat_curr() |>
      group_by(line_number) |>
      summarise(total = sum(value, na.rm = TRUE), .groups = "drop") |>
      slice_max(total, n = 1, with_ties = FALSE)

    tagList(
      tags$strong(line_labels[df$line_number]),
      tags$small(class = "d-block text-muted mt-1",
                 fmt_n(df$total), " embarques")
    )
  })

  # ── Panorama: KPI — YoY ────────────────────────────────────────────────────

  output$vb_yoy_panorama <- renderUI({
    curr <- sum(dat_curr()$value, na.rm = TRUE)
    prev <- sum(dat_prev()$value, na.rm = TRUE)

    if (prev == 0 || nrow(dat_prev()) == 0) {
      return(value_box("Variação anual", "—",
                       showcase = bs_icon("dash-circle"), theme = "secondary"))
    }

    pct   <- (curr - prev) / prev * 100
    label <- sprintf("%+.1f%%", pct)
    icon  <- if (pct >= 0) "arrow-up-circle-fill" else "arrow-down-circle-fill"
    theme <- if (pct >= 0) "success" else "danger"

    value_box(
      title    = "Variação anual",
      value    = label,
      tags$small(class = "text-muted", paste("vs.", yr_prev())),
      showcase = bs_icon(icon),
      theme    = theme
    )
  })

  # ── Panorama: Monthly line chart (current + previous year) ─────────────────

  output$area_chart <- renderGirafe({
    y   <- yr_curr()
    df  <- ent |>
      filter(year %in% c(y - 1L, y), !is.na(value)) |>
      mutate(
        line_label = unname(line_labels[line_number]),
        tooltip    = paste0(
          "<b>", line_labels[line_number], "</b><br/>",
          format(date, "%B %Y"), "<br/>",
          "Embarques: <b>", fmt_n(value), "</b>"
        )
      )

    p <- ggplot(
      df,
      aes(
        x       = date,
        y       = value / 1e6,
        color   = line_number,
        group   = line_number,
        tooltip = tooltip,
        data_id = paste(line_number, date)
      )
    ) +
      geom_line_interactive(linewidth = 1.1) +
      geom_point_interactive(size = 2, alpha = 0.8) +
      scale_color_manual(values = line_colors, labels = line_labels, name = NULL) +
      scale_y_continuous(labels = function(x) paste0(x, "M")) +
      scale_x_date(date_breaks = "2 months", date_labels = "%b\n%Y") +
      labs(x = NULL, y = "Milhões de embarques") +
      theme_minimal(base_size = 12) +
      theme(
        legend.position  = "bottom",
        legend.text      = element_text(size = 10),
        panel.grid.minor = element_blank(),
        plot.margin      = margin(8, 12, 8, 8)
      ) +
      guides(color = guide_legend(nrow = 2, override.aes = list(linewidth = 2)))

    girafe(
      ggobj      = p,
      width_svg  = 9,
      height_svg = 4.5,
      options    = girafe_default_opts(
        opts_hover(css = "stroke-width: 2.8px; opacity: 1;"),
        opts_hover_inv(css = "opacity: 0.15;")
      )
    )
  })

  # ── Panorama: Overview map (metro lines only) ──────────────────────────────

  output$map_overview <- renderLeaflet({
    m <- leaflet(options = leafletOptions(zoomControl = FALSE)) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      setView(lng = -46.633, lat = -23.555, zoom = 11)

    if (!is.null(sf_metro_lines)) {
      for (ln in LINES) {
        geom <- sf_metro_lines |> filter(line_number == ln)
        if (nrow(geom) > 0) {
          m <- m |> addPolylines(
            data    = geom,
            color   = line_colors[ln],
            weight  = 4,
            opacity = 0.85,
            label   = line_labels[ln]
          )
        }
      }
    }
    m
  })

  # ── Panorama: Annual totals bar chart ─────────────────────────────────────

  output$line_bar_chart <- renderGirafe({
    y  <- yr_curr()
    df <- ent |>
      filter(year %in% c(y - 1L, y), !is.na(value)) |>
      group_by(year, line_number) |>
      summarise(total = sum(value, na.rm = TRUE) / 1e6, .groups = "drop") |>
      mutate(
        line_label  = factor(
          line_labels[line_number],
          levels = rev(unname(line_labels))
        ),
        year_fct    = factor(year, levels = c(y - 1L, y)),
        is_curr     = year == y,
        tooltip     = paste0(
          "<b>", line_labels[line_number], " — ", year, "</b><br/>",
          sprintf("%.1f M embarques", total)
        )
      )

    p <- ggplot(
      df,
      aes(
        x       = total,
        y       = line_label,
        fill    = line_number,
        alpha   = is_curr,
        tooltip = tooltip,
        data_id = paste(line_number, year)
      )
    ) +
      geom_col_interactive(
        position = position_dodge(width = 0.7),
        width    = 0.65
      ) +
      scale_fill_manual(values = line_colors, guide = "none") +
      scale_alpha_manual(
        values = c("FALSE" = 0.4, "TRUE" = 1),
        labels = c(as.character(y - 1L), as.character(y)),
        name   = "Ano"
      ) +
      scale_x_continuous(
        labels = function(x) paste0(x, "M"),
        expand = expansion(mult = c(0, 0.05))
      ) +
      labs(x = "Total de embarques (milhões)", y = NULL) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.major.y = element_blank(),
        panel.grid.minor   = element_blank(),
        legend.position    = "bottom",
        plot.margin        = margin(8, 16, 8, 8)
      )

    girafe(
      ggobj      = p,
      width_svg  = 11,
      height_svg = 3,
      options    = girafe_default_opts()
    )
  })

  # ── Tendências: Index chart ────────────────────────────────────────────────

  output$index_chart <- renderGirafe({
    lines_sel <- input$lines_trend
    req(length(lines_sel) > 0)

    df <- ent_idx |> filter(line_number %in% lines_sel)
    y_max <- max(df$index, na.rm = TRUE) * 1.02

    p <- ggplot() +
      annotate(
        "rect",
        xmin = covid_start, xmax = covid_end,
        ymin = -Inf, ymax = Inf,
        fill = "#FF6B6B", alpha = 0.12
      ) +
      annotate(
        "text",
        x     = covid_start + (covid_end - covid_start) / 2,
        y     = y_max,
        label = "COVID-19",
        color = "#CC3333", size = 3.5, fontface = "bold", vjust = 1.2
      ) +
      geom_hline(
        yintercept = 100,
        linetype   = "dashed",
        color      = "#888888",
        linewidth  = 0.6
      ) +
      geom_line_interactive(
        data = df,
        aes(
          x       = date,
          y       = index,
          color   = line_number,
          group   = line_number,
          tooltip = tooltip,
          data_id = paste(line_number, date)
        ),
        linewidth = 1.1
      ) +
      scale_color_manual(values = line_colors, labels = line_labels, name = NULL) +
      scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
      scale_y_continuous(
        labels = function(x) paste0(x),
        breaks = seq(0, ceiling(y_max / 20) * 20, by = 20)
      ) +
      labs(x = NULL, y = "Índice (2019 = 100)") +
      theme_minimal(base_size = 12) +
      theme(
        legend.position  = "bottom",
        panel.grid.minor = element_blank(),
        plot.margin      = margin(8, 12, 8, 8)
      ) +
      guides(color = guide_legend(nrow = 2, override.aes = list(linewidth = 2.5)))

    girafe(
      ggobj      = p,
      width_svg  = 10,
      height_svg = 5,
      options    = girafe_default_opts(
        opts_hover(css = "stroke-width: 2.8px; opacity: 1;"),
        opts_hover_inv(css = "opacity: 0.15;")
      )
    )
  })

  # ── Tendências: YoY chart (network total of selected lines) ───────────────

  output$yoy_trend_chart <- renderGirafe({
    lines_sel <- input$lines_trend
    req(length(lines_sel) > 0)

    # Sum selected lines (only months where all selected lines have prev data)
    df <- ent_yoy |>
      filter(line_number %in% lines_sel) |>
      group_by(date) |>
      summarise(
        value      = sum(value, na.rm = TRUE),
        value_prev = sum(value_prev, na.rm = TRUE),
        n_lines    = n(),
        .groups    = "drop"
      ) |>
      filter(n_lines == length(lines_sel)) |>
      mutate(
        yoy       = (value - value_prev) / value_prev * 100,
        pos       = yoy >= 0,
        month_lbl = format(date, "%b/%Y"),
        tooltip   = paste0(
          "<b>", month_lbl, "</b><br/>",
          "Variação anual: <b>", sprintf("%+.1f%%", yoy), "</b>"
        )
      )

    p <- ggplot(
      df,
      aes(
        x       = date,
        y       = yoy,
        fill    = pos,
        tooltip = tooltip,
        data_id = as.character(date)
      )
    ) +
      annotate(
        "rect",
        xmin = covid_start, xmax = covid_end,
        ymin = -Inf, ymax = Inf,
        fill = "#FF6B6B", alpha = 0.08
      ) +
      geom_hline(yintercept = 0, linewidth = 0.5, color = "#444444") +
      geom_col_interactive(width = 20, show.legend = FALSE) +
      scale_fill_manual(values = c("TRUE" = "#2E7D32", "FALSE" = "#C62828")) +
      scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
      scale_y_continuous(labels = function(x) paste0(x, "%")) +
      labs(x = NULL, y = "Variação anual (%)") +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.minor   = element_blank(),
        panel.grid.major.x = element_blank(),
        plot.margin        = margin(8, 12, 8, 8)
      )

    girafe(
      ggobj      = p,
      width_svg  = 10,
      height_svg = 3.5,
      options    = girafe_default_opts()
    )
  })

  # ── Estações: Station map ──────────────────────────────────────────────────

  output$station_map <- renderLeaflet({
    pal <- colorFactor(
      palette = unname(line_colors),
      levels  = names(line_colors)
    )

    m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      setView(lng = -46.633, lat = -23.555, zoom = 11)

    # Metro line geometries
    if (!is.null(sf_metro_lines)) {
      for (ln in LINES) {
        geom <- sf_metro_lines |> filter(line_number == ln)
        if (nrow(geom) > 0) {
          m <- m |> addPolylines(
            data    = geom,
            color   = line_colors[ln],
            weight  = 3,
            opacity = 0.6
          )
        }
      }
    }

    # Station markers sized by demand
    if (!is.null(sf_metro_stations)) {
      m <- m |>
        addCircleMarkers(
          data        = sf_metro_stations,
          radius      = ~radius,
          color       = ~pal(line_number),
          fillColor   = ~pal(line_number),
          fillOpacity = 0.75,
          weight      = 1.5,
          stroke      = TRUE,
          popup       = ~popup_text,
          label       = ~station_name,
          layerId     = ~layer_id
        )
    }

    m
  })

  # ── Estações: Station bar chart ────────────────────────────────────────────

  output$station_bar <- renderGirafe({
    ln <- input$line_est
    req(ln)

    # Use latest available year for that line
    latest_yr_line <- sta_avg |>
      filter(line_number == ln, !is.na(avg_passenger)) |>
      pull(year) |>
      max(na.rm = TRUE)

    df <- sta_avg |>
      filter(line_number == ln, year == latest_yr_line, !is.na(avg_passenger)) |>
      group_by(station_name) |>
      summarise(avg = mean(avg_passenger, na.rm = TRUE), .groups = "drop") |>
      arrange(avg) |>
      mutate(
        station_f = factor(station_name, levels = station_name),
        tooltip   = paste0(
          "<b>", station_name, "</b><br/>",
          "Média dias úteis: <b>", fmt_n(avg), "</b> pass./dia<br/>",
          "(", latest_yr_line, ")"
        )
      )

    p <- ggplot(
      df,
      aes(
        x       = avg / 1e3,
        y       = station_f,
        fill    = ln,
        tooltip = tooltip,
        data_id = station_name
      )
    ) +
      geom_col_interactive(width = 0.75) +
      scale_fill_manual(values = line_colors, guide = "none") +
      scale_x_continuous(
        labels   = function(x) paste0(x, "K"),
        expand   = expansion(mult = c(0, 0.06))
      ) +
      labs(x = "Média embarques dias úteis (mil)", y = NULL) +
      theme_minimal(base_size = 11) +
      theme(
        panel.grid.major.y = element_blank(),
        panel.grid.minor   = element_blank(),
        axis.text.y        = element_text(size = 10),
        plot.margin        = margin(8, 12, 8, 8)
      )

    girafe(
      ggobj      = p,
      width_svg  = 8,
      height_svg = 6,
      options    = girafe_default_opts(
        opts_selection(
          type = "single",
          css  = "opacity:1; stroke:#333333; stroke-width:2px;"
        )
      )
    )
  })

  # Track selected station (from bar or map click)
  selected_station <- reactiveVal(NULL)

  observeEvent(input$station_bar_selected, {
    sel <- input$station_bar_selected
    if (length(sel) == 0 || sel == "") {
      selected_station(NULL)
    } else {
      selected_station(sel)
    }
  })

  observeEvent(input$station_map_marker_click, {
    click <- input$station_map_marker_click
    if (!is.null(click$id)) {
      # layer_id format: "{line_number}|{station_name}"
      parts      <- strsplit(click$id, "|", fixed = TRUE)[[1]]
      ln_click   <- parts[1]
      sta_click  <- paste(parts[-1], collapse = "|")

      selected_station(sta_click)
      updateSelectInput(session, "line_est", selected = ln_click)
    }
  })

  # Reset station selection when line changes
  observeEvent(input$line_est, {
    selected_station(NULL)
  }, ignoreInit = TRUE)

  # ── Estações: Station profile ──────────────────────────────────────────────

  output$station_profile_ui <- renderUI({
    sta <- selected_station()
    if (is.null(sta) || sta == "") return(NULL)

    card(
      class = "mt-3",
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center justify-content-between gap-2",
        paste0("Perfil de demanda — ", sta),
        selectInput(
          "profile_year", "Ano",
          choices  = sta_years,
          selected = sta_years[1],
          width    = "110px"
        )
      ),
      girafeOutput("station_profile_chart", height = "280px")
    )
  })

  output$station_profile_chart <- renderGirafe({
    sta <- selected_station()
    ln  <- input$line_est
    yr  <- as.integer(input$profile_year)
    req(!is.null(sta), !is.null(ln), !is.na(yr))

    df <- sta_daily_df |>
      filter(
        station_name == sta,
        line_number  == ln,
        year         == yr,
        !is.na(passengers)
      ) |>
      group_by(dow_num) |>
      summarise(avg = mean(passengers, na.rm = TRUE), .groups = "drop") |>
      mutate(
        dow_label  = factor(day_abb[dow_num], levels = day_abb),
        is_weekend = dow_num >= 6L,
        tooltip    = paste0(
          "<b>", day_abb[dow_num], "</b><br/>",
          "Média: <b>", fmt_n(avg), "</b> embarques"
        )
      )

    validate(need(nrow(df) > 0, "Sem dados diários para esta estação/ano."))

    p <- ggplot(
      df,
      aes(
        x       = dow_label,
        y       = avg / 1e3,
        fill    = ln,
        alpha   = is_weekend,
        tooltip = tooltip,
        data_id = as.character(dow_num)
      )
    ) +
      geom_col_interactive(width = 0.72) +
      scale_fill_manual(values = line_colors, guide = "none") +
      scale_alpha_manual(
        values = c("FALSE" = 1, "TRUE" = 0.5),
        guide  = "none"
      ) +
      scale_y_continuous(
        labels   = function(x) paste0(x, "K"),
        expand   = expansion(mult = c(0, 0.06))
      ) +
      labs(
        x       = NULL,
        y       = "Média de embarques (mil)",
        caption = paste0("Média por dia da semana — ", sta, " (", yr, ")")
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.major.x = element_blank(),
        panel.grid.minor   = element_blank(),
        plot.caption       = element_text(color = "#888888", size = 10),
        plot.margin        = margin(8, 16, 8, 8)
      )

    girafe(
      ggobj      = p,
      width_svg  = 8,
      height_svg = 3.5,
      options    = girafe_default_opts()
    )
  })
}

shinyApp(ui, server)
