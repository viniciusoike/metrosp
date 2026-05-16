library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(ggiraph)
library(dygraphs)
library(xts)
library(metrosp)

# ── Line metadata ──────────────────────────────────────────────────────────────

line_colors <- c(
  "1"  = "#171796",
  "2"  = "#007A5E",
  "3"  = "#ED2E38",
  "4"  = "#B89000",   # darkened from official #FFD525 for contrast on white
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

pt_months_abb <- c(
  "jan", "fev", "mar", "abr", "mai", "jun",
  "jul", "ago", "set", "out", "nov", "dez"
)

pt_months_full <- c(
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
)

pt_weekdays <- c(
  "Segunda-feira", "Terça-feira", "Quarta-feira",
  "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"
)

day_abb <- c("Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom")

# ── Helpers ────────────────────────────────────────────────────────────────────

roll_mean <- function(x, k = 7L) {
  n   <- length(x)
  out <- rep(NA_real_, n)
  for (i in seq(k, n)) out[i] <- mean(x[(i - k + 1L):i], na.rm = TRUE)
  out
}

# Compact number format: 1.2M, 45.3K, etc. (PT decimal conventions)
fmt_n <- function(x) {
  if (!length(x) || is.na(x[1])) return("—")
  x <- x[1]
  if (x >= 1e6) sprintf("%.1fM", x / 1e6)
  else if (x >= 1e3) sprintf("%.1fK", x / 1e3)
  else format(round(x), big.mark = ".")
}

# Full PT number format for tooltips: "1.234.567"
fmt_n_full <- function(x) {
  formatC(round(x), format = "d", big.mark = ".")
}

# ── Data (pre-process once at startup) ────────────────────────────────────────

dat <- metrosp::station_daily |>
  mutate(
    line_number = as.character(line_number),
    dow_num     = as.integer(format(date, "%u"))  # 1 = Mon, 7 = Sun (ISO)
  )

date_min        <- min(dat$date, na.rm = TRUE)
date_max        <- max(dat$date, na.rm = TRUE)
available_years <- sort(unique(dat$year), decreasing = TRUE)
available_lines <- sort(unique(dat$line_number))

# ── UI ─────────────────────────────────────────────────────────────────────────

ui <- page_sidebar(
  title  = "Metro SP — Embarques Diários por Estação",
  theme  = bs_theme(version = 5, bootswatch = "flatly"),
  lang   = "pt-BR",
  sidebar = sidebar(
    title = "Filtros",
    selectInput(
      "line", "Linha",
      choices  = setNames(available_lines, line_labels[available_lines]),
      selected = "1"
    ),
    selectInput("station", "Estação", choices = NULL),
    hr(),
    dateRangeInput(
      "date_range", "Período",
      start    = date_max - 365L,
      end      = date_max,
      min      = date_min,
      max      = date_max,
      language = "pt-BR",
      format   = "dd/mm/yyyy"
    ),
    checkboxInput("rolling", "Média móvel 7 dias", value = TRUE),
    hr(),
    p(class = "text-muted small",
      "Fonte: METRO SP / Insper Dataverse")
  ),
  # ── KPI row ─────────────────────────────────────────────────────────────────
  layout_columns(
    col_widths = c(3, 3, 3, 3),
    value_box(
      title    = "Total no período",
      value    = textOutput("vb_total"),
      showcase = bsicons::bs_icon("people-fill"),
      theme    = "primary"
    ),
    value_box(
      title    = "Dias úteis",
      value    = textOutput("vb_weekday"),
      p(class = "text-muted mb-0", "Média diária"),
      showcase = bsicons::bs_icon("briefcase"),
      theme    = "info"
    ),
    value_box(
      title    = "Finais de semana",
      value    = textOutput("vb_weekend"),
      p(class = "text-muted mb-0", "Média diária"),
      showcase = bsicons::bs_icon("calendar2-week"),
      theme    = "success"
    ),
    uiOutput("vb_yoy")
  ),
  # ── Plot tabs ────────────────────────────────────────────────────────────────
  navset_card_tab(
    nav_panel(
      "Série Temporal",
      dygraphOutput("ts_plot", height = "400px")
    ),
    nav_panel(
      "Calendário",
      div(
        class = "p-3 pb-1",
        selectInput(
          "heatmap_year", "Ano",
          choices  = available_years,
          selected = available_years[1],
          width    = "130px"
        )
      ),
      girafeOutput("heatmap_plot", height = "310px")
    )
  )
)

# ── Server ─────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # Populate station list when line changes
  observe({
    stations <- dat |>
      filter(line_number == input$line) |>
      pull(station_name) |>
      unique() |>
      sort()
    updateSelectInput(session, "station", choices = stations)
  })

  # Full history for the selected station (used for YoY previous-year lookup)
  station_data <- reactive({
    req(input$station, nchar(input$station) > 0)
    filter(dat, line_number == input$line, station_name == input$station)
  })

  # Period slice (drives KPI cards + time series)
  ts_data <- reactive({
    req(input$date_range)
    station_data() |>
      filter(date >= input$date_range[1], date <= input$date_range[2]) |>
      arrange(date)
  })

  # Year slice with calendar columns (drives heatmap)
  heatmap_data <- reactive({
    req(input$heatmap_year)
    yr <- as.integer(input$heatmap_year)
    station_data() |>
      filter(year == yr) |>
      arrange(date) |>
      mutate(
        week      = as.integer(format(date, "%W")),
        dow       = factor(day_abb[dow_num], levels = day_abb),
        wday_pt   = pt_weekdays[dow_num],
        month_num = as.integer(format(date, "%m")),
        day_num   = as.integer(format(date, "%d")),
        tooltip   = paste0(
          "<b>", wday_pt, "</b>, ",
          day_num, " de ", pt_months_full[month_num], " de ", yr,
          "<br/>Embarques: <b>", fmt_n_full(passengers), "</b>"
        )
      )
  })

  # ── KPI: Total no período ──────────────────────────────────────────────────

  output$vb_total <- renderText({
    df <- ts_data()
    if (nrow(df) == 0) return("—")
    fmt_n(sum(df$passengers, na.rm = TRUE))
  })

  # ── KPI: Dias úteis (weekday average) ─────────────────────────────────────

  output$vb_weekday <- renderText({
    df <- ts_data()
    wd <- df[df$dow_num <= 5L, ]
    if (nrow(wd) == 0) return("—")
    fmt_n(mean(wd$passengers, na.rm = TRUE))
  })

  # ── KPI: Finais de semana (weekend average) ────────────────────────────────

  output$vb_weekend <- renderText({
    df <- ts_data()
    we <- df[df$dow_num >= 6L, ]
    if (nrow(we) == 0) return("—")
    fmt_n(mean(we$passengers, na.rm = TRUE))
  })

  # ── KPI: Variação anual (YoY) — dynamic theme ──────────────────────────────

  output$vb_yoy <- renderUI({
    df_curr <- ts_data()
    req(nrow(df_curr) > 0, input$date_range)

    prev_start <- input$date_range[1] - 365L
    prev_end   <- input$date_range[2] - 365L

    df_prev <- station_data() |>
      filter(date >= prev_start, date <= prev_end)

    curr <- sum(df_curr$passengers, na.rm = TRUE)
    prev <- sum(df_prev$passengers, na.rm = TRUE)

    if (nrow(df_prev) == 0 || prev == 0) {
      return(value_box(
        title    = "Variação anual",
        value    = "—",
        p(class = "text-muted mb-0", "Sem dados do ano anterior"),
        showcase = bsicons::bs_icon("dash-circle"),
        theme    = "secondary"
      ))
    }

    pct   <- (curr - prev) / prev * 100
    label <- sprintf("%+.1f%%", pct)
    icon  <- if (pct >= 0) "arrow-up-circle-fill" else "arrow-down-circle-fill"
    theme <- if (pct >= 0) "success" else "danger"
    note  <- sprintf(
      "vs. %s – %s",
      format(prev_start, "%d/%m/%Y"),
      format(prev_end,   "%d/%m/%Y")
    )

    value_box(
      title    = "Variação anual",
      value    = label,
      p(class = "text-muted mb-0 small", note),
      showcase = bsicons::bs_icon(icon),
      theme    = theme
    )
  })

  # ── Time series (dygraph) ──────────────────────────────────────────────────

  output$ts_plot <- renderDygraph({
    df  <- ts_data()
    req(nrow(df) > 0)
    col <- line_colors[input$line]

    # JS formatters for PT-BR locale
    val_fmt   <- "function(v) { return v != null ? v.toLocaleString('pt-BR') : ''; }"
    axis_fmt  <- paste0(
      "function(v) {",
      "  if (v >= 1e6) return (v/1e6).toFixed(1) + 'M';",
      "  if (v >= 1e3) return Math.round(v/1e3) + 'K';",
      "  return v;",
      "}"
    )

    daily <- xts::xts(df$passengers, order.by = df$date)

    if (isTRUE(input$rolling) && nrow(df) >= 7L) {
      roll <- xts::xts(roll_mean(df$passengers), order.by = df$date)
      mat  <- cbind(Diario = daily, Media7 = roll)

      dygraph(mat) |>
        dySeries("Diario", label = "Diário",        color = "#BBBBBB", strokeWidth = 0.8) |>
        dySeries("Media7", label = "Média 7 dias",  color = col,       strokeWidth = 2.2) |>
        dyAxis("y", valueFormatter = val_fmt, axisLabelFormatter = axis_fmt) |>
        dyOptions(drawGrid = TRUE, axisLabelFontSize = 12, includeZero = FALSE) |>
        dyRangeSelector(height = 30, strokeColor = "") |>
        dyHighlight(
          highlightCircleSize        = 4,
          highlightSeriesBackgroundAlpha = 0.6,
          hideOnMouseOut             = TRUE
        ) |>
        dyLegend(show = "follow", width = 220)
    } else {
      names(daily) <- "Diario"
      dygraph(daily) |>
        dySeries("Diario", label = "Embarques", color = col, strokeWidth = 1.8) |>
        dyAxis("y", valueFormatter = val_fmt, axisLabelFormatter = axis_fmt) |>
        dyOptions(drawGrid = TRUE, axisLabelFontSize = 12, includeZero = FALSE) |>
        dyRangeSelector(height = 30, strokeColor = "") |>
        dyHighlight(highlightCircleSize = 4, hideOnMouseOut = TRUE) |>
        dyLegend(show = "follow")
    }
  })

  # ── Calendar heatmap (ggiraph) ─────────────────────────────────────────────

  output$heatmap_plot <- renderGirafe({
    df  <- heatmap_data()
    req(nrow(df) > 0)
    col <- line_colors[input$line]

    p <- ggplot(df, aes(
      x       = week,
      y       = dow,
      fill    = passengers,
      tooltip = tooltip,
      data_id = as.character(date)
    )) +
      geom_tile_interactive(
        color     = "white",
        linewidth = 0.4,
        na.rm     = TRUE
      ) +
      scale_fill_gradient(
        low      = "#f2f2f2",
        high     = col,
        labels   = scales::label_number(scale_cut = scales::cut_short_scale()),
        na.value = "grey90"
      ) +
      scale_x_continuous(
        breaks = c(1, 5, 9, 14, 18, 22, 27, 31, 36, 40, 44, 48),
        labels = c("Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
                   "Jul", "Ago", "Set", "Out", "Nov", "Dez"),
        expand = c(0.01, 0)
      ) +
      scale_y_discrete(limits = rev(day_abb)) +
      labs(x = NULL, y = NULL, fill = "Embarques") +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid       = element_blank(),
        legend.position  = "right",
        axis.text.y      = element_text(size = 11),
        plot.margin      = margin(4, 8, 4, 8)
      )

    girafe(
      ggobj     = p,
      width_svg = 11,
      height_svg = 3.2,
      options   = list(
        opts_hover(css = "stroke: #333333; stroke-width: 1.5px; opacity: 1;"),
        opts_hover_inv(css = "opacity: 0.4;"),
        opts_tooltip(
          css = paste0(
            "background-color: #ffffff;",
            "border: 1px solid #dddddd;",
            "padding: 8px 12px;",
            "border-radius: 6px;",
            "font-family: -apple-system, sans-serif;",
            "font-size: 13px;",
            "line-height: 1.5;",
            "box-shadow: 0 2px 8px rgba(0,0,0,0.12);"
          ),
          opacity  = 1,
          offx     = 12,
          offy     = -20
        ),
        opts_sizing(rescale = TRUE, width = 1)
      )
    )
  })
}

shinyApp(ui, server)
