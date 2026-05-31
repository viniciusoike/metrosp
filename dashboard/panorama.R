library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(tidyr)
library(leaflet)
library(echarts4r)
library(ggplot2)
library(ggiraph)
library(metrosp)
library(sf)
library(htmltools)

# Forecasts are pre-computed by data-raw/build_forecasts.R and shipped with
# the package; gracefully degrade if the datasets are missing.
HAS_FORECASTS <- tryCatch(
  is.data.frame(metrosp::forecasts) && nrow(metrosp::forecasts) > 0,
  error = function(e) FALSE
)

if (!HAS_FORECASTS) {
  message(
    "metrosp::forecasts not available; projection tab will be disabled. ",
    "Rebuild with: source(\"data-raw/build_forecasts.R\")"
  )
}

forecast_model_labels <- c(
  arima = "ARIMA (Box-Cox)",
  ets = "ETS (Box-Cox)",
  stlf = "STL + ETS (robusto)"
)

# Metadata ---------------------------------------------------------------------

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

line_short <- c(
  "1" = "Azul",
  "2" = "Verde",
  "3" = "Vermelha",
  "4" = "Amarela",
  "5" = "Lilás",
  "15" = "Prata"
)

LINES <- names(line_labels)

covid_start <- as.Date("2020-03-01")
covid_end <- as.Date("2021-06-30")

# Drop noisy 2017 (partial) and early-2018 tail to focus on stable history
hero_start <- as.Date("2018-06-01")

# Brand color for KPIs and accents
metro_primary <- "#171796"

day_abb <- c("Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom")
pt_months_full <- c(
  "Janeiro",
  "Fevereiro",
  "Março",
  "Abril",
  "Maio",
  "Junho",
  "Julho",
  "Agosto",
  "Setembro",
  "Outubro",
  "Novembro",
  "Dezembro"
)
pt_weekdays <- c(
  "Segunda-feira",
  "Terça-feira",
  "Quarta-feira",
  "Quinta-feira",
  "Sexta-feira",
  "Sábado",
  "Domingo"
)

# Helpers ----------------------------------------------------------------------

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

fmt_n <- function(x) {
  if (!length(x) || all(is.na(x))) {
    return("—")
  }
  x <- x[!is.na(x)][1]
  if (x >= 1e9) {
    sprintf("%.2f bi", x / 1e9)
  } else if (x >= 1e6) {
    sprintf("%.1f M", x / 1e6)
  } else if (x >= 1e3) {
    sprintf("%.1f K", x / 1e3)
  } else {
    formatC(round(x), format = "d", big.mark = ".")
  }
}

fmt_n_full <- function(x) formatC(round(x), format = "d", big.mark = ".")

fmt_pct <- function(x, signed = TRUE) {
  if (is.na(x)) {
    return("—")
  }
  if (signed) sprintf("%+.1f%%", x) else sprintf("%.1f%%", x)
}

girafe_tooltip_css <- paste0(
  "background:#ffffff;border:1px solid #E5E7EE;",
  "padding:8px 12px;border-radius:6px;",
  "font-family:Inter,-apple-system,sans-serif;",
  "font-size:13px;line-height:1.5;color:#0E1130;",
  "box-shadow:0 2px 8px rgba(14,17,48,0.12);"
)

roll_mean <- function(x, k = 7L) {
  n <- length(x)
  out <- rep(NA_real_, n)
  for (i in seq(k, n)) {
    out[i] <- mean(x[(i - k + 1L):i], na.rm = TRUE)
  }
  out
}

# Data prep --------------------------------------------------------------------

## Monthly totals by line ----

ent_all <- metrosp::passengers_entrance |>
  filter(metric_abb == "total", line_number %in% as.integer(LINES)) |>
  mutate(line_number = as.character(line_number))

# Series shown in charts: from mid-2018 onward
ent <- ent_all |> filter(date >= hero_start)

avail_years <- ent |>
  filter(!is.na(value)) |>
  pull(year) |>
  unique() |>
  sort(decreasing = TRUE)

## 2019 baseline (monthly mean per line) ----

base_2019 <- ent_all |>
  filter(year == 2019, !is.na(value)) |>
  group_by(line_number) |>
  summarise(base = mean(value, na.rm = TRUE), .groups = "drop")

## Indexed series (2019 = 100) ----

ent_idx <- ent |>
  left_join(base_2019, by = "line_number") |>
  mutate(
    index = value / base * 100,
    line_label = unname(line_labels[line_number])
  ) |>
  filter(!is.na(index))

## Recovery snapshot — last 12 months avg vs 2019 baseline ----

latest_date <- max(ent_idx$date, na.rm = TRUE)
recovery_window_start <- latest_date - 365L
prev_window_start <- recovery_window_start - 365L

recovery <- ent_idx |>
  filter(date > recovery_window_start) |>
  group_by(line_number, line_label) |>
  summarise(
    avg_recent = mean(value, na.rm = TRUE),
    sum_recent = sum(value, na.rm = TRUE),
    base = first(base),
    pct_2019 = mean(index, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(desc(pct_2019))

network_recovery <- mean(recovery$pct_2019, na.rm = TRUE)
top_recover <- recovery |> slice_max(pct_2019, n = 1)
bot_recover <- recovery |> slice_min(pct_2019, n = 1)
busiest_line <- recovery |> slice_max(sum_recent, n = 1)

## Network monthly totals (last 12 months window) ----

monthly_recent <- ent |>
  filter(date > recovery_window_start, !is.na(value)) |>
  group_by(date) |>
  summarise(total = sum(value, na.rm = TRUE), .groups = "drop")

monthly_prev <- ent_all |>
  filter(
    date > prev_window_start,
    date <= recovery_window_start,
    !is.na(value)
  ) |>
  group_by(date) |>
  summarise(total = sum(value, na.rm = TRUE), .groups = "drop")

total_recent <- sum(monthly_recent$total, na.rm = TRUE)
total_prev <- sum(monthly_prev$total, na.rm = TRUE)
yoy_pct <- if (total_prev > 0) {
  (total_recent - total_prev) / total_prev * 100
} else {
  NA_real_
}

peak_month <- monthly_recent |> slice_max(total, n = 1)
mean_month <- mean(monthly_recent$total, na.rm = TRUE)

latest_month_total <- monthly_recent |>
  filter(date == max(date)) |>
  pull(total)

## Latest complete year (for line-comparison defaults) ----

last_full_year <- ent |>
  filter(!is.na(value)) |>
  group_by(year, line_number) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(year) |>
  summarise(
    min_n = min(n),
    nlines = n_distinct(line_number),
    .groups = "drop"
  ) |>
  filter(min_n >= 10, nlines == 6) |>
  pull(year) |>
  max()

## Recent absolute monthly trend (last 36 months) ----

monthly_abs_36 <- ent |>
  filter(date > (latest_date - 1095L), !is.na(value)) |>
  group_by(date, line_number) |>
  summarise(value = sum(value, na.rm = TRUE), .groups = "drop") |>
  arrange(line_number, date) |>
  mutate(line_label = unname(line_labels[line_number]))

monthly_abs_total <- monthly_abs_36 |>
  group_by(date) |>
  summarise(total = sum(value, na.rm = TRUE), .groups = "drop") |>
  arrange(date)

## Heatmap data (per-line % of own 2019 baseline, by year-month) ----

heatmap_yr_mo <- ent_idx |>
  mutate(ym = format(date, "%Y-%m"))

## Seasonality (month-of-year average per line) ----

seasonality <- ent |>
  filter(!is.na(value), year >= 2018) |>
  mutate(
    month_num = as.integer(format(date, "%m")),
    period = case_when(
      year < 2020 ~ "Pré-COVID (2018-2019)",
      year <= 2021 ~ "COVID (2020-2021)",
      TRUE ~ "Pós-COVID (2022+)"
    )
  ) |>
  group_by(line_number, period, month_num) |>
  summarise(avg = mean(value, na.rm = TRUE), .groups = "drop") |>
  mutate(
    period = factor(
      period,
      levels = c(
        "Pré-COVID (2018-2019)",
        "COVID (2020-2021)",
        "Pós-COVID (2022+)"
      )
    ),
    month_lbl = factor(
      month.abb[month_num],
      levels = month.abb,
      labels = c(
        "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
        "Jul", "Ago", "Set", "Out", "Nov", "Dez"
      )
    ),
    line_label = unname(line_labels[line_number])
  )

## Forecasts (precomputed by data-raw/build_forecasts.R) ----

if (HAS_FORECASTS) {
  forecasts_all <- metrosp::forecasts |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES)

  forecast_acc <- tryCatch(
    metrosp::forecast_accuracy |>
      mutate(line_number = as.character(line_number)) |>
      filter(line_number %in% LINES),
    error = function(e) NULL
  )
} else {
  forecasts_all <- NULL
  forecast_acc <- NULL
}

## Station data ----

sta_avg <- metrosp::station_averages |>
  mutate(line_number = as.character(line_number)) |>
  filter(line_number %in% LINES)

sta_daily_df <- metrosp::station_daily |>
  mutate(
    line_number = as.character(line_number),
    dow_num = as.integer(format(date, "%u"))
  ) |>
  filter(line_number %in% LINES)

sta_years <- sort(unique(sta_daily_df$year), decreasing = TRUE)

latest_sta_avg <- sta_avg |>
  filter(year == max(year, na.rm = TRUE), !is.na(avg_passenger)) |>
  group_by(line_number, station_name) |>
  summarise(avg = mean(avg_passenger, na.rm = TRUE), .groups = "drop")

max_avg_global <- max(latest_sta_avg$avg, na.rm = TRUE)

## Station-level movers — trailing 12m vs prior 12m ----

station_movers <- sta_avg |>
  filter(!is.na(avg_passenger)) |>
  group_by(line_number, station_name) |>
  summarise(
    avg_recent = mean(
      avg_passenger[date > recovery_window_start],
      na.rm = TRUE
    ),
    avg_prior = mean(
      avg_passenger[date > prev_window_start & date <= recovery_window_start],
      na.rm = TRUE
    ),
    n_recent = sum(date > recovery_window_start),
    n_prior = sum(
      date > prev_window_start & date <= recovery_window_start
    ),
    .groups = "drop"
  ) |>
  filter(
    !is.na(avg_recent), !is.na(avg_prior),
    avg_prior > 0, n_recent >= 6, n_prior >= 6
  ) |>
  mutate(
    delta = avg_recent - avg_prior,
    pct = (avg_recent - avg_prior) / avg_prior * 100,
    line_label = unname(line_labels[line_number])
  )

## Pre/post-COVID delta at station level ----

station_covid <- sta_avg |>
  filter(!is.na(avg_passenger)) |>
  group_by(line_number, station_name) |>
  summarise(
    avg_2019 = mean(avg_passenger[year == 2019], na.rm = TRUE),
    n_2019 = sum(year == 2019 & !is.na(avg_passenger)),
    avg_recent = mean(
      avg_passenger[date > recovery_window_start],
      na.rm = TRUE
    ),
    n_recent = sum(date > recovery_window_start),
    .groups = "drop"
  ) |>
  filter(
    !is.na(avg_2019), !is.na(avg_recent),
    avg_2019 > 0, n_2019 >= 6, n_recent >= 6
  ) |>
  mutate(
    pct_2019 = avg_recent / avg_2019 * 100,
    delta = avg_recent - avg_2019,
    line_label = unname(line_labels[line_number])
  )

## Spatial data ----

sf_metro_lines <- tryCatch(
  metrosp::lines |>
    filter(status == "current", type == "metro") |>
    mutate(line_number = as.character(line_number)) |>
    filter(line_number %in% LINES),
  error = function(e) NULL
)

sf_metro_stations <- tryCatch(
  {
    metrosp::stations |>
      filter(status == "current", type == "metro") |>
      mutate(line_number = as.character(line_number)) |>
      filter(line_number %in% LINES) |>
      left_join(latest_sta_avg, by = c("line_number", "station_name")) |>
      mutate(
        radius = ifelse(is.na(avg), 4, 4 + 14 * sqrt(avg / max_avg_global)),
        popup_text = paste0(
          "<b>",
          station_name,
          "</b><br/>",
          line_labels[line_number],
          "<br/>",
          ifelse(
            is.na(avg),
            "<span style='color:#8A8FA3'>Sem dados de demanda</span>",
            paste0("Média dias úteis: <b>", fmt_n(avg), "</b> pass./dia")
          )
        ),
        layer_id = paste0(line_number, "|", station_name)
      )
  },
  error = function(e) NULL
)

# Theme ------------------------------------------------------------------------

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

# echarts4r theme (registered once at startup) ---------------------------------

echart_theme <- list(
  color = unname(line_colors),
  backgroundColor = "transparent",
  textStyle = list(
    fontFamily = "Inter, -apple-system, BlinkMacSystemFont, sans-serif",
    color = "#0E1130"
  ),
  title = list(textStyle = list(color = "#0E1130", fontWeight = "600")),
  legend = list(textStyle = list(color = "#4A4F6B")),
  grid = list(
    left = "3%",
    right = "3%",
    top = "10%",
    bottom = "12%",
    containLabel = TRUE
  ),
  categoryAxis = list(
    axisLine = list(lineStyle = list(color = "#E5E7EE")),
    axisTick = list(lineStyle = list(color = "#E5E7EE")),
    axisLabel = list(color = "#4A4F6B"),
    splitLine = list(show = FALSE)
  ),
  valueAxis = list(
    axisLine = list(show = FALSE),
    axisTick = list(show = FALSE),
    axisLabel = list(color = "#4A4F6B"),
    splitLine = list(lineStyle = list(color = "#EDEEF3"))
  ),
  timeAxis = list(
    axisLine = list(lineStyle = list(color = "#E5E7EE")),
    axisTick = list(lineStyle = list(color = "#E5E7EE")),
    axisLabel = list(color = "#4A4F6B"),
    splitLine = list(show = FALSE)
  )
)

# Pre-format helpers for echarts -----------------------------------------------

covid_mark_area <- list(
  list(
    list(
      name = "COVID-19",
      xAxis = format(covid_start),
      itemStyle = list(color = "rgba(255, 194, 200, 0.22)"),
      label = list(
        show = TRUE,
        position = "insideTop",
        color = "#B33A3A",
        fontWeight = "bold",
        fontSize = 11
      )
    ),
    list(xAxis = format(covid_end))
  )
)

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

# UI ---------------------------------------------------------------------------

## KPI card helper — compact, same-color, clean ----

kpi_card <- function(label, value, sub = NULL) {
  div(
    class = "kpi",
    div(class = "kpi-label", label),
    div(class = "kpi-value", value),
    if (!is.null(sub)) div(class = "kpi-sub", sub)
  )
}

## Spark card for one line ----

spark_ui <- function(line_id) {
  div(
    class = "spark-card",
    div(
      span(
        class = "spark-line-tag",
        style = paste0("background:", line_colors[line_id], ";")
      ),
      span(class = "spark-title", line_labels[line_id])
    ),
    div(
      class = "spark-plot",
      echarts4rOutput(paste0("spark_", line_id), height = "70px")
    )
  )
}

## Forecast mini-card ----

forecast_mini_ui <- function(line_id) {
  div(
    class = "mini-chart",
    div(
      class = "mini-title d-flex align-items-center",
      span(
        class = "mini-tag",
        style = paste0("background:", line_colors[line_id], ";")
      ),
      line_labels[line_id],
      span(
        class = "ms-auto text-muted small",
        style = "font-weight: 400;",
        textOutput(paste0("fc_acc_", line_id), inline = TRUE)
      )
    ),
    echarts4rOutput(paste0("fc_", line_id), height = "180px")
  )
}

## Seasonality mini-card ----

season_mini_ui <- function(line_id) {
  div(
    class = "mini-chart",
    div(
      class = "mini-title",
      span(
        class = "mini-tag",
        style = paste0("background:", line_colors[line_id], ";")
      ),
      line_labels[line_id]
    ),
    echarts4rOutput(paste0("season_", line_id), height = "180px")
  )
}

## UI assembly ----

ui <- function(request) {
  page_navbar(
  title = tags$span(
    bs_icon("train-front-fill", size = "1.05em", class = "me-2"),
    "Metro SP — Demanda"
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

  ## ── Tab 1: Visão geral ──────────────────────────────────────────────────

  nav_panel(
    title = "Visão geral",
    icon = bs_icon("house-door-fill"),

    div(
      class = "section-label",
      sprintf(
        "Últimos 12 meses — %s a %s",
        format(recovery_window_start + 1, "%b/%Y"),
        format(latest_date, "%b/%Y")
      )
    ),

    div(
      class = "kpi-grid kpi-grid-5",
      kpi_card(
        "Embarques (12m)",
        fmt_n(total_recent),
        "rede inteira"
      ),
      kpi_card(
        "Variação anual",
        fmt_pct(yoy_pct),
        "vs. 12 meses anteriores"
      ),
      kpi_card(
        "Pico mensal",
        fmt_n(peak_month$total),
        format(peak_month$date, "%b/%Y")
      ),
      kpi_card(
        "Média mensal",
        fmt_n(mean_month),
        "média dos 12 meses"
      ),
      kpi_card(
        "Linha + cheia",
        paste0("L", busiest_line$line_number, " — ", line_short[busiest_line$line_number]),
        paste0(fmt_n(busiest_line$sum_recent), " embarques")
      )
    ),

    div(class = "section-label mt-4", "Trajetória recente da rede"),

    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center justify-content-between gap-2",
        tags$div(
          tags$span("Embarques mensais totais — últimos 36 meses"),
          tags$small(
            class = "ms-2 text-muted",
            "soma de todas as linhas"
          )
        ),
        downloadButton(
          "dl_overview_trend",
          NULL,
          icon = icon("download"),
          class = "btn-sm btn-link p-1 download-icon",
          title = "Baixar CSV"
        )
      ),
      echarts4rOutput("overview_trend", height = "320px")
    ),

    div(class = "section-label mt-4", "Projeção de demanda"),

    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center justify-content-between gap-2",
        tags$div(
          tags$span("Projeção 6 meses por linha"),
          tags$small(
            class = "ms-2 text-muted",
            "área sombreada = IC 80% · ✓ = menor MAPE em validação"
          )
        ),
        tags$div(
          class = "d-flex align-items-center gap-2",
          if (HAS_FORECASTS) {
            radioButtons(
              "forecast_model",
              NULL,
              choices = setNames(names(forecast_model_labels), forecast_model_labels),
              selected = "arima",
              inline = TRUE
            )
          } else {
            NULL
          },
          if (HAS_FORECASTS) {
            downloadButton(
              "dl_forecasts",
              NULL,
              icon = icon("download"),
              class = "btn-sm btn-link p-1 download-icon",
              title = "Baixar CSV"
            )
          } else {
            NULL
          }
        )
      ),
      if (HAS_FORECASTS) {
        layout_column_wrap(
          width = 1 / 3,
          heights_equal = "row",
          !!!lapply(LINES, forecast_mini_ui)
        )
      } else {
        div(
          class = "station-empty",
          div(class = "empty-icon", bs_icon("graph-up-arrow")),
          div(class = "empty-title", "Previsões não disponíveis"),
          div(
            class = "empty-text",
            "Atualize o pacote para a versão que inclui o dataset ",
            tags$code("forecasts"),
            ", ou regenere localmente:",
            tags$br(),
            tags$code("source(\"data-raw/build_forecasts.R\")")
          )
        )
      }
    )
  ),

  ## ── Tab 2: Recuperação 2019 ─────────────────────────────────────────────

  nav_panel(
    title = "Recuperação 2019",
    icon = bs_icon("graph-up-arrow"),

    div(
      class = "section-label",
      sprintf(
        "Posição vs. patamar pré-pandemia — atualizado em %s",
        format(latest_date, "%b/%Y")
      )
    ),

    div(
      class = "kpi-grid kpi-grid-3",
      kpi_card(
        "% de 2019",
        sprintf("%.0f%%", network_recovery),
        fmt_pct(network_recovery - 100)
      ),
      kpi_card(
        "Linha + recuperada",
        paste0("L", top_recover$line_number, " — ", line_short[top_recover$line_number]),
        sprintf("%.0f%% de 2019", top_recover$pct_2019)
      ),
      kpi_card(
        "Linha - recuperada",
        paste0("L", bot_recover$line_number, " — ", line_short[bot_recover$line_number]),
        sprintf("%.0f%% de 2019", bot_recover$pct_2019)
      )
    ),

    div(class = "section-label mt-4", "Trajetória da rede"),

    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center justify-content-between gap-2",
        tags$div(
          tags$span("Índice de demanda por linha — base 2019 = 100"),
          tags$small(
            class = "ms-2 text-muted",
            "Faixa rosa indica período COVID-19 · clique na legenda para ocultar linhas"
          )
        ),
        downloadButton(
          "dl_hero_index",
          NULL,
          icon = icon("download"),
          class = "btn-sm btn-link p-1 download-icon",
          title = "Baixar CSV"
        )
      ),
      echarts4rOutput("hero_index", height = "420px")
    ),

    div(class = "section-label mt-4", "Por linha"),

    layout_columns(
      col_widths = c(4, 4, 4),
      gap = "0.85rem",
      row_heights = c(1, 1),
      !!!lapply(LINES, spark_ui)
    )
  ),

  ## ── Tab 3: Mudanças ─────────────────────────────────────────────────────

  nav_panel(
    title = "Mudanças",
    icon = bs_icon("arrow-up-right-circle-fill"),

    layout_sidebar(
      sidebar = sidebar(
        title = div(class = "sidebar-title", "Filtros"),
        width = 260,
        checkboxGroupInput(
          "movers_lines",
          "Linhas",
          choices = setNames(LINES, unname(line_labels)),
          selected = LINES
        ),
        hr(),
        radioButtons(
          "movers_metric",
          "Métrica do ranking",
          choices = c(
            "Variação %" = "pct",
            "Variação absoluta (pass./dia útil)" = "abs"
          ),
          selected = "pct"
        ),
        sliderInput(
          "movers_topn",
          "Estações por extremo",
          min = 5, max = 25,
          value = 12, step = 1, ticks = FALSE
        ),
        hr(),
        tags$p(
          class = "text-muted small mb-0",
          "Compara média de embarques em ",
          tags$b("dias úteis"),
          " nos 12 meses recentes vs. 12 meses anteriores. ",
          "Mínimo de 6 meses observados em cada janela."
        )
      ),

      layout_columns(
        col_widths = c(6, 6),
        gap = "1rem",
        card(
          full_screen = TRUE,
          card_header(
            class = "d-flex align-items-center justify-content-between gap-2",
            tags$div(
              tags$span("Crescimento — 12m vs. 12m anteriores"),
              tags$small(
                class = "ms-2 text-muted",
                "topo do ranking"
              )
            ),
            downloadButton(
              "dl_movers_up",
              NULL,
              icon = icon("download"),
              class = "btn-sm btn-link p-1 download-icon",
              title = "Baixar CSV"
            )
          ),
          girafeOutput("movers_up", height = "440px")
        ),
        card(
          full_screen = TRUE,
          card_header(
            class = "d-flex align-items-center justify-content-between gap-2",
            tags$div(
              tags$span("Queda — 12m vs. 12m anteriores"),
              tags$small(
                class = "ms-2 text-muted",
                "fundo do ranking"
              )
            ),
            downloadButton(
              "dl_movers_down",
              NULL,
              icon = icon("download"),
              class = "btn-sm btn-link p-1 download-icon",
              title = "Baixar CSV"
            )
          ),
          girafeOutput("movers_down", height = "440px")
        )
      ),

      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center justify-content-between gap-2",
          tags$div(
            tags$span("Pré-COVID × pós-COVID por estação"),
            tags$small(
              class = "ms-2 text-muted",
              "média de dias úteis — 2019 (eixo x) vs. últimos 12 meses (eixo y) · linha pontilhada = recuperação total"
            )
          ),
          downloadButton(
            "dl_covid_scatter",
            NULL,
            icon = icon("download"),
            class = "btn-sm btn-link p-1 download-icon",
            title = "Baixar CSV"
          )
        ),
        girafeOutput("covid_scatter", height = "520px")
      )
    )
  ),

  ## ── Tab 2: Comparar linhas ──────────────────────────────────────────────

  nav_panel(
    title = "Comparar linhas",
    icon = bs_icon("bar-chart-line-fill"),

    layout_sidebar(
      sidebar = sidebar(
        title = div(class = "sidebar-title", "Filtros"),
        width = 260,
        checkboxGroupInput(
          "lines_compare",
          NULL,
          choices = setNames(LINES, unname(line_labels)),
          selected = LINES
        ),
        hr(),
        radioButtons(
          "compare_metric",
          "Métrica",
          choices = c(
            "Embarques mensais (M)" = "absolute",
            "% do nível de 2019" = "indexed"
          ),
          selected = "indexed"
        ),
        hr(),
        tags$p(
          class = "text-muted small mb-0",
          "Mapa de calor mostra ",
          tags$b("% de 2019"),
          " para cada linha em cada mês — vermelho = mais fraco, azul = mais forte."
        )
      ),

      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center justify-content-between gap-2",
          "Série mensal por linha",
          downloadButton(
            "dl_compare_series",
            NULL,
            icon = icon("download"),
            class = "btn-sm btn-link p-1 download-icon",
            title = "Baixar CSV"
          )
        ),
        echarts4rOutput("compare_series", height = "330px")
      ),
      card(
        full_screen = TRUE,
        card_header(
          class = "d-flex align-items-center justify-content-between gap-2",
          "Mapa de calor — linhas × meses",
          downloadButton(
            "dl_compare_heatmap",
            NULL,
            icon = icon("download"),
            class = "btn-sm btn-link p-1 download-icon",
            title = "Baixar CSV"
          )
        ),
        echarts4rOutput("compare_heatmap", height = "340px")
      ),
      card(
        full_screen = TRUE,
        card_header("Sazonalidade por período (média mensal)"),
        layout_column_wrap(
          width = 1 / 3,
          heights_equal = "row",
          !!!lapply(LINES, season_mini_ui)
        )
      )
    )
  ),

  ## ── Tab 3: Estações ─────────────────────────────────────────────────────

  nav_panel(
    title = "Estações",
    icon = bs_icon("pin-map-fill"),

    layout_columns(
      col_widths = c(7, 5),
      gap = "1rem",
      card(
        full_screen = TRUE,
        card_header(
          "Mapa de estações",
          tags$small(
            class = "ms-2 text-muted",
            "círculos proporcionais à demanda — clique para detalhes"
          )
        ),
        leafletOutput("station_map", height = "520px")
      ),
      uiOutput("station_detail_ui")
    ),

    div(class = "mt-3"),

    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center justify-content-between gap-2",
        "Ranking de estações por linha",
        tags$div(
          class = "d-flex align-items-center gap-2",
          selectInput(
            "line_rank",
            NULL,
            choices = setNames(LINES, unname(line_labels)),
            selected = "1",
            width = "200px"
          ),
          downloadButton(
            "dl_station_rank",
            NULL,
            icon = icon("download"),
            class = "btn-sm btn-link p-1 download-icon",
            title = "Baixar CSV"
          )
        )
      ),
      girafeOutput("station_rank", height = "520px")
    )
  ),

  nav_spacer(),
  nav_item(
    bookmarkButton(
      label = "Compartilhar",
      title = "Copiar link para esta visualização",
      icon = icon("link"),
      class = "btn-sm btn-outline-secondary share-btn"
    )
  ),
  nav_item(
    tags$span(
      class = "source-tag",
      "Fontes: METRO SP · Insper Dataverse · GeoSampa"
    )
  )
  )
}

# Server -----------------------------------------------------------------------

server <- function(input, output, session) {
  ## ── Tab 1: Hero index chart ────────────────────────────────────────────

  output$hero_index <- renderEcharts4r({
    df <- ent_idx |>
      mutate(line_label = factor(
        line_label,
        levels = unname(line_labels[LINES])
      )) |>
      arrange(line_label, date)

    first_line <- levels(df$line_label)[1]

    df |>
      group_by(line_label) |>
      e_charts(date) |>
      e_line(
        index,
        symbol = "none",
        smooth = FALSE,
        lineStyle = list(width = 2.2),
        emphasis = list(focus = "series", lineStyle = list(width = 3))
      ) |>
      e_color(unname(line_colors[LINES])) |>
      e_y_axis(
        name = "Índice (2019 = 100)",
        nameLocation = "middle",
        nameGap = 42,
        nameTextStyle = list(color = "#4A4F6B")
      ) |>
      e_x_axis(type = "time") |>
      e_mark_line(
        serie = first_line,
        data = list(yAxis = 100),
        lineStyle = list(type = "dashed", color = "#8A8FA3", width = 1),
        label = list(
          formatter = "2019",
          color = "#4A4F6B",
          position = "insideEndTop"
        ),
        symbol = "none"
      ) |>
      e_mark_area(
        serie = first_line,
        data = covid_mark_area[[1]],
        silent = TRUE
      ) |>
      e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
      e_legend(bottom = 0, itemWidth = 14, itemHeight = 8) |>
      e_grid(left = 60, right = 24, top = 20, bottom = 60) |>
      e_datazoom(type = "inside")
  })

  ## ── Tab 1: Per-line spark renderers ────────────────────────────────────

  render_spark <- function(line_id) {
    renderEcharts4r({
      df <- ent_idx |>
        filter(line_number == line_id) |>
        arrange(date)
      col <- unname(line_colors[line_id])
      latest <- df |> slice_tail(n = 1)

      df |>
        e_charts(date) |>
        e_line(
          index,
          symbol = "none",
          smooth = FALSE,
          lineStyle = list(width = 1.8),
          legend = FALSE,
          name = line_labels[line_id]
        ) |>
        e_color(col) |>
        e_x_axis(
          type = "time",
          show = FALSE,
          splitLine = list(show = FALSE)
        ) |>
        e_y_axis(
          show = FALSE,
          splitLine = list(show = FALSE)
        ) |>
        e_mark_line(
          data = list(yAxis = 100),
          lineStyle = list(type = "dashed", color = "#D4D6E0", width = 1),
          symbol = "none",
          label = list(show = FALSE),
          silent = TRUE
        ) |>
        e_mark_point(
          data = list(
            list(
              coord = list(format(latest$date), latest$index),
              symbolSize = 8,
              itemStyle = list(color = col),
              label = list(
                show = TRUE,
                formatter = sprintf("%d%%", round(latest$index)),
                position = "left",
                color = col,
                fontWeight = "bold",
                fontSize = 11
              )
            )
          )
        ) |>
        e_grid(left = 4, right = 40, top = 8, bottom = 4) |>
        e_tooltip(
          trigger = "axis",
          formatter = js_tooltip_pt_br,
          confine = TRUE
        )
    })
  }

  for (ln in LINES) {
    local({
      ln_local <- ln
      output[[paste0("spark_", ln_local)]] <- render_spark(ln_local)
    })
  }

  ## ── Tab 1: Forecast small multiples (one chart per line) ───────────────

  forecast_df <- reactive({
    req(HAS_FORECASTS, input$forecast_model)
    forecasts_all |> filter(model == input$forecast_model)
  })

  render_forecast_acc <- function(line_id) {
    renderText({
      req(HAS_FORECASTS, input$forecast_model)
      if (is.null(forecast_acc)) {
        return("")
      }
      row <- forecast_acc |>
        filter(line_number == line_id, model == input$forecast_model)
      if (nrow(row) == 0 || is.na(row$mape)) {
        return("modelo instável")
      }
      best_row <- forecast_acc |>
        filter(line_number == line_id, isTRUE(best))
      mark <- if (nrow(best_row) > 0 && best_row$model == input$forecast_model) {
        " ✓"
      } else {
        ""
      }
      sprintf("MAPE %.1f%%%s", row$mape, mark)
    })
  }

  if (HAS_FORECASTS) {
    for (ln in LINES) {
      local({
        ln_local <- ln
        output[[paste0("fc_acc_", ln_local)]] <- render_forecast_acc(ln_local)
      })
    }
  }

  render_forecast_mini <- function(line_id) {
    renderEcharts4r({
      fc_all <- forecast_df()
      req(!is.null(fc_all), nrow(fc_all) > 0)

      hist_start <- max(ent_all$date, na.rm = TRUE) - (365L * 3L)
      hist <- ent_all |>
        filter(
          line_number == line_id,
          !is.na(value),
          date >= hist_start
        ) |>
        arrange(date) |>
        transmute(
          date,
          historico = value / 1e6,
          previsto = NA_real_,
          lo = NA_real_,
          hi = NA_real_
        )

      fc <- fc_all |>
        filter(line_number == line_id) |>
        arrange(date) |>
        transmute(
          date,
          historico = NA_real_,
          previsto = mean / 1e6,
          lo = lo80 / 1e6,
          hi = hi80 / 1e6
        )

      # Bridge: last historic point also opens the forecast line
      bridge <- tail(hist, 1)
      if (nrow(bridge) > 0 && nrow(fc) > 0) {
        bridge$previsto <- bridge$historico
        bridge$lo <- bridge$historico
        bridge$hi <- bridge$historico
      }

      df <- bind_rows(hist, bridge, fc) |> arrange(date)

      col <- unname(line_colors[line_id])

      df |>
        e_charts(date) |>
        e_band(
          lo, hi,
          areaStyle = list(
            list(color = "rgba(0,0,0,0)"),
            list(color = paste0(col, "33"))
          )
        ) |>
        e_line(
          historico,
          name = "Histórico",
          symbol = "none",
          smooth = FALSE,
          lineStyle = list(width = 2, color = col),
          legend = FALSE,
          connectNulls = FALSE
        ) |>
        e_line(
          previsto,
          name = "Projeção",
          symbol = "circle",
          symbolSize = 4,
          smooth = FALSE,
          lineStyle = list(width = 2, color = col, type = "dashed"),
          itemStyle = list(color = col),
          legend = FALSE,
          connectNulls = FALSE
        ) |>
        e_x_axis(type = "time") |>
        e_y_axis(
          axisLabel = list(formatter = "{value} M"),
          splitLine = list(lineStyle = list(color = "#EDEEF3"))
        ) |>
        e_grid(left = 50, right = 12, top = 10, bottom = 28) |>
        e_tooltip(trigger = "axis") |>
        e_legend(show = FALSE)
    })
  }

  if (HAS_FORECASTS) {
    for (ln in LINES) {
      local({
        ln_local <- ln
        output[[paste0("fc_", ln_local)]] <- render_forecast_mini(ln_local)
      })
    }
  }

  ## ── Tab 2: Compare — monthly series ────────────────────────────────────

  output$compare_series <- renderEcharts4r({
    sel <- input$lines_compare
    req(length(sel) > 0)

    if (input$compare_metric == "indexed") {
      df <- ent_idx |>
        filter(line_number %in% sel) |>
        select(date, line_number, value = index)
      y_axis_label <- list(formatter = "{value}")
      y_name <- "Índice (2019 = 100)"
    } else {
      df <- ent_idx |>
        filter(line_number %in% sel) |>
        mutate(value = value / 1e6) |>
        select(date, line_number, value)
      y_axis_label <- list(formatter = "{value} M")
      y_name <- "Milhões de embarques"
    }

    df <- df |>
      mutate(line_label = factor(
        unname(line_labels[line_number]),
        levels = unname(line_labels[sel])
      )) |>
      arrange(line_label, date)

    cols <- unname(line_colors[sel])
    first_line <- levels(df$line_label)[1]

    df |>
      group_by(line_label) |>
      e_charts(date) |>
      e_line(
        value,
        symbol = "none",
        smooth = FALSE,
        lineStyle = list(width = 2),
        emphasis = list(focus = "series", lineStyle = list(width = 2.8))
      ) |>
      e_color(cols) |>
      e_x_axis(type = "time") |>
      e_y_axis(
        name = y_name,
        nameLocation = "middle",
        nameGap = 46,
        nameTextStyle = list(color = "#4A4F6B"),
        axisLabel = y_axis_label
      ) |>
      e_mark_area(
        serie = first_line,
        data = covid_mark_area[[1]],
        silent = TRUE
      ) |>
      e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
      e_legend(bottom = 0, itemWidth = 14, itemHeight = 8) |>
      e_grid(left = 60, right = 24, top = 20, bottom = 60) |>
      e_datazoom(type = "inside")
  })

  ## ── Tab 2: Compare — line × month heatmap ──────────────────────────────

  output$compare_heatmap <- renderEcharts4r({
    sel <- input$lines_compare
    req(length(sel) > 0)

    df <- heatmap_yr_mo |>
      filter(line_number %in% sel) |>
      mutate(line_label = unname(line_labels[line_number]))

    line_order <- rev(unname(line_labels[sel]))
    ym_order <- sort(unique(df$ym))

    df_w <- df |>
      mutate(
        line_label = factor(line_label, levels = line_order),
        ym = factor(ym, levels = ym_order),
        index_rounded = round(index, 1)
      ) |>
      arrange(line_label, ym)

    df_w |>
      e_charts(ym) |>
      e_heatmap(line_label, index_rounded, name = "% 2019") |>
      e_visual_map(
        index_rounded,
        type = "continuous",
        min = max(0, min(df_w$index_rounded, na.rm = TRUE) * 0.95),
        max = max(df_w$index_rounded, na.rm = TRUE) * 1.05,
        inRange = list(color = c("#C62828", "#FFF4E5", "#1565C0")),
        text = c("alto", "baixo"),
        textStyle = list(color = "#4A4F6B"),
        bottom = 0,
        orient = "horizontal",
        itemWidth = 12,
        itemHeight = 120
      ) |>
      e_x_axis(
        axisLabel = list(
          interval = max(1, floor(length(ym_order) / 8)),
          formatter = htmlwidgets::JS(
            "function(v) { return v ? v.substring(0,4) : ''; }"
          )
        ),
        splitLine = list(show = FALSE)
      ) |>
      e_y_axis(splitLine = list(show = FALSE)) |>
      e_grid(left = 130, right = 24, top = 12, bottom = 60) |>
      e_tooltip(
        formatter = htmlwidgets::JS(
          "function(p) {",
          "  if (!p.data) return '';",
          "  var ym = p.data[0]; var line = p.data[1]; var v = p.data[2];",
          "  return '<b>' + line + '</b><br/>' + ym + '<br/>% 2019: <b>' + v + '</b>';",
          "}"
        )
      )
  })

  ## ── Tab 2: Compare — seasonality (one mini per line) ───────────────────

  render_seasonality_mini <- function(line_id) {
    renderEcharts4r({
      sel <- input$lines_compare
      req(line_id %in% sel)

      df <- seasonality |>
        filter(line_number == line_id) |>
        mutate(avg = avg / 1e6) |>
        select(month_lbl, period, avg) |>
        pivot_wider(names_from = period, values_from = avg)

      period_cols <- c(
        "Pré-COVID (2018-2019)" = "#4A4F6B",
        "COVID (2020-2021)" = "#C62828",
        "Pós-COVID (2022+)" = metro_primary
      )

      e <- df |>
        e_charts(month_lbl)

      for (p_name in names(period_cols)) {
        if (p_name %in% colnames(df)) {
          e <- e |>
            e_line_(
              p_name,
              name = p_name,
              symbol = "circle",
              symbolSize = 5,
              smooth = FALSE,
              lineStyle = list(width = 1.8),
              legend = (line_id == LINES[1])
            )
        }
      }

      e |>
        e_color(unname(period_cols)) |>
        e_x_axis(axisLabel = list(interval = 0, fontSize = 10)) |>
        e_y_axis(
          axisLabel = list(formatter = "{value} M", fontSize = 10),
          splitLine = list(lineStyle = list(color = "#EDEEF3"))
        ) |>
        e_grid(left = 42, right = 8, top = 30, bottom = 22) |>
        e_legend(
          show = (line_id == LINES[1]),
          top = 0,
          textStyle = list(fontSize = 10),
          itemWidth = 12,
          itemHeight = 6
        ) |>
        e_tooltip(trigger = "axis")
    })
  }

  for (ln in LINES) {
    local({
      ln_local <- ln
      output[[paste0("season_", ln_local)]] <- render_seasonality_mini(ln_local)
    })
  }

  ## ── Tab 3: Station map ─────────────────────────────────────────────────

  output$station_map <- renderLeaflet({
    m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      setView(lng = -46.633, lat = -23.555, zoom = 11)

    if (!is.null(sf_metro_lines)) {
      for (ln in LINES) {
        geom <- sf_metro_lines |> filter(line_number == ln)
        if (nrow(geom) > 0) {
          m <- m |>
            addPolylines(
              data = geom,
              color = line_colors[ln],
              weight = 3.5,
              opacity = 0.7,
              label = line_labels[ln]
            )
        }
      }
    }

    if (!is.null(sf_metro_stations)) {
      m <- m |>
        addCircleMarkers(
          data = sf_metro_stations,
          radius = ~radius,
          color = "white",
          fillColor = ~ line_colors[line_number],
          fillOpacity = 0.85,
          weight = 1.5,
          stroke = TRUE,
          popup = ~popup_text,
          label = ~station_name,
          layerId = ~layer_id
        )
    }

    m
  })

  ## ── Tab 3: Reactive station selection state ────────────────────────────

  selected_station <- reactiveVal(NULL)

  observeEvent(input$station_map_marker_click, {
    click <- input$station_map_marker_click
    if (!is.null(click$id)) {
      parts <- strsplit(click$id, "|", fixed = TRUE)[[1]]
      ln_click <- parts[1]
      sta_click <- paste(parts[-1], collapse = "|")
      selected_station(list(line = ln_click, station = sta_click))
      updateSelectInput(session, "line_rank", selected = ln_click)
    }
  })

  observeEvent(input$station_rank_selected, {
    sta <- input$station_rank_selected
    ln <- input$line_rank
    if (is.null(sta) || !nzchar(as.character(sta))) {
      return()
    }
    selected_station(list(line = ln, station = as.character(sta)))
  })

  observeEvent(
    input$line_rank,
    {
      sel <- selected_station()
      if (!is.null(sel) && sel$line != input$line_rank) {
        selected_station(NULL)
      }
    },
    ignoreInit = TRUE
  )

  ## ── Tab 3: Station detail panel ────────────────────────────────────────

  output$station_detail_ui <- renderUI({
    sel <- selected_station()

    if (is.null(sel)) {
      return(card(
        full_screen = FALSE,
        card_header("Detalhes da estação"),
        div(
          class = "station-empty",
          div(class = "empty-icon", bs_icon("cursor-fill")),
          div(class = "empty-title", "Selecione uma estação"),
          div(
            class = "empty-text",
            "Clique em qualquer círculo do mapa para ver série diária, ",
            "padrão semanal e calendário de embarques."
          )
        )
      ))
    }

    sta <- sel$station
    ln <- sel$line

    card(
      full_screen = TRUE,
      card_header(
        class = "d-flex align-items-center justify-content-between gap-2",
        div(
          tags$div(class = "fw-semibold", sta),
          tags$small(class = "text-muted", paste0(line_labels[ln]))
        ),
        selectInput(
          "profile_year",
          NULL,
          choices = sta_years,
          selected = sta_years[1],
          width = "110px"
        )
      ),
      layout_columns(
        col_widths = c(6, 6),
        gap = "0.5rem",
        value_box(
          title = "Dias úteis",
          value = textOutput("vb_sta_weekday"),
          p("média diária"),
          showcase = bs_icon("briefcase"),
          theme = "info"
        ),
        value_box(
          title = "Finais de semana",
          value = textOutput("vb_sta_weekend"),
          p("média diária"),
          showcase = bs_icon("calendar2-week"),
          theme = "success"
        )
      ),
      div(class = "section-label mt-2", "Calendário de embarques"),
      echarts4rOutput("sta_calendar", height = "200px"),
      div(class = "section-label mt-2", "Série diária"),
      echarts4rOutput("sta_timeseries", height = "220px")
    )
  })

  station_daily_slice <- reactive({
    sel <- selected_station()
    req(sel, input$profile_year)
    yr <- as.integer(input$profile_year)
    sta_daily_df |>
      filter(
        line_number == sel$line,
        station_name == sel$station,
        year == yr
      ) |>
      arrange(date)
  })

  output$vb_sta_weekday <- renderText({
    df <- station_daily_slice()
    wd <- df[df$dow_num <= 5L, ]
    if (nrow(wd) == 0) {
      return("—")
    }
    fmt_n(mean(wd$passengers, na.rm = TRUE))
  })

  output$vb_sta_weekend <- renderText({
    df <- station_daily_slice()
    we <- df[df$dow_num >= 6L, ]
    if (nrow(we) == 0) {
      return("—")
    }
    fmt_n(mean(we$passengers, na.rm = TRUE))
  })

  output$sta_calendar <- renderEcharts4r({
    df <- station_daily_slice()
    req(nrow(df) > 0)
    sel <- selected_station()
    col <- unname(line_colors[sel$line])
    yr <- as.integer(input$profile_year)

    df |>
      mutate(date = as.character(date)) |>
      select(date, passengers) |>
      e_charts() |>
      e_calendar(
        range = as.character(yr),
        cellSize = c("auto", 14),
        top = 25,
        left = 30,
        right = 10,
        dayLabel = list(
          firstDay = 1,
          nameMap = c("D", "S", "T", "Q", "Q", "S", "S"),
          color = "#4A4F6B",
          fontSize = 10
        ),
        monthLabel = list(
          nameMap = c(
            "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
            "Jul", "Ago", "Set", "Out", "Nov", "Dez"
          ),
          color = "#4A4F6B",
          fontSize = 10
        ),
        yearLabel = list(show = FALSE),
        itemStyle = list(borderColor = "white", borderWidth = 2),
        splitLine = list(show = FALSE)
      ) |>
      e_heatmap(date, passengers, coord_system = "calendar") |>
      e_visual_map(
        passengers,
        type = "continuous",
        inRange = list(color = c("#F2F3F8", col)),
        orient = "vertical",
        right = 0,
        top = "middle",
        itemWidth = 8,
        itemHeight = 80,
        text = c("alto", "baixo"),
        textStyle = list(color = "#4A4F6B", fontSize = 10),
        formatter = js_axis_label_compact
      ) |>
      e_tooltip(
        formatter = htmlwidgets::JS(
          "function(p) {",
          "  if (!p.data) return '';",
          "  var v = p.data[1];",
          "  var label = v != null ? v.toLocaleString('pt-BR') : '—';",
          "  return '<b>' + p.data[0] + '</b><br/>Embarques: <b>' + label + '</b>';",
          "}"
        )
      )
  })

  output$sta_timeseries <- renderEcharts4r({
    df <- station_daily_slice()
    req(nrow(df) > 0)
    sel <- selected_station()
    col <- unname(line_colors[sel$line])

    df <- df |>
      arrange(date) |>
      mutate(rolling7 = roll_mean(passengers))

    e <- df |>
      e_charts(date) |>
      e_line(
        passengers,
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
      e_x_axis(type = "time") |>
      e_y_axis(axisLabel = list(formatter = js_axis_label_compact)) |>
      e_grid(left = 50, right = 16, top = 30, bottom = 50) |>
      e_legend(top = 0, itemWidth = 12, itemHeight = 6) |>
      e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
      e_datazoom(type = "slider", bottom = 8, height = 18)
  })

  ## ── Tab 3: Station ranking ─────────────────────────────────────────────

  output$station_rank <- renderGirafe({
    ln <- input$line_rank
    req(ln)

    latest_yr_line <- sta_avg |>
      filter(line_number == ln, !is.na(avg_passenger)) |>
      pull(year) |>
      max(na.rm = TRUE)

    df <- sta_avg |>
      filter(
        line_number == ln,
        year == latest_yr_line,
        !is.na(avg_passenger)
      ) |>
      group_by(station_name) |>
      summarise(avg = mean(avg_passenger, na.rm = TRUE), .groups = "drop") |>
      arrange(avg) |>
      mutate(
        avg_k = avg / 1e3,
        station_f = factor(station_name, levels = station_name),
        tooltip = sprintf(
          "<b>%s</b><br/>Média dias úteis: <b>%s</b> pass./dia",
          station_name,
          formatC(round(avg), big.mark = ".", format = "d", decimal.mark = ",")
        )
      )

    col <- unname(line_colors[ln])

    p <- ggplot(df, aes(x = avg_k, y = station_f)) +
      geom_col_interactive(
        aes(tooltip = tooltip, data_id = station_name),
        fill = col, width = 0.62
      ) +
      scale_x_continuous(
        expand = expansion(mult = c(0, 0.05)),
        labels = scales::label_number(big.mark = ".", decimal.mark = ",")
      ) +
      labs(
        x = sprintf("mil embarques / dia útil — %s", latest_yr_line),
        y = NULL
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.major.y = element_blank(),
        panel.grid.minor   = element_blank(),
        panel.grid.major.x = element_line(color = "#EDEEF3"),
        axis.text.y        = element_text(size = 11, color = "#0E1130"),
        axis.title.x       = element_text(
          color = "#4A4F6B", size = 10, margin = margin(t = 10)
        ),
        plot.margin        = margin(6, 12, 6, 6)
      )

    svg_h <- max(4.2, nrow(df) * 0.32)

    girafe(
      ggobj = p,
      width_svg = 11,
      height_svg = svg_h,
      options = list(
        opts_hover(css = "stroke:#0E1130;stroke-width:1px;fill-opacity:1;"),
        opts_hover_inv(css = "fill-opacity:0.35;"),
        opts_selection(
          type = "single",
          css = "fill:#0E1130;stroke:#0E1130;stroke-width:1px;"
        ),
        opts_tooltip(
          css = girafe_tooltip_css,
          opacity = 1, offx = 12, offy = -20
        ),
        opts_sizing(rescale = TRUE, width = 1),
        opts_toolbar(saveaspng = FALSE)
      )
    )
  })

  ## ── Tab Visão geral: absolute monthly trend ────────────────────────────

  output$overview_trend <- renderEcharts4r({
    df <- monthly_abs_36 |>
      mutate(
        line_label = factor(line_label, levels = unname(line_labels[LINES])),
        value_m = value / 1e6
      ) |>
      arrange(line_label, date)

    df |>
      group_by(line_label) |>
      e_charts(date) |>
      e_line(
        value_m,
        stack = "total",
        areaStyle = list(opacity = 0.85),
        symbol = "none",
        smooth = FALSE,
        lineStyle = list(width = 0),
        emphasis = list(focus = "series")
      ) |>
      e_color(unname(line_colors[LINES])) |>
      e_x_axis(type = "time") |>
      e_y_axis(
        name = "Milhões de embarques / mês",
        nameLocation = "middle",
        nameGap = 46,
        nameTextStyle = list(color = "#4A4F6B"),
        axisLabel = list(formatter = "{value} M")
      ) |>
      e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
      e_legend(bottom = 0, itemWidth = 14, itemHeight = 8) |>
      e_grid(left = 60, right = 24, top = 20, bottom = 60)
  })

  ## ── Tab Mudanças: movers + scatter ─────────────────────────────────────

  movers_filtered <- reactive({
    req(input$movers_lines)
    df <- station_movers |>
      filter(line_number %in% input$movers_lines)
    metric <- input$movers_metric %||% "pct"
    if (metric == "pct") {
      df <- df |> mutate(rank_val = pct)
    } else {
      df <- df |> mutate(rank_val = delta)
    }
    df
  })

  movers_slice <- function(direction = c("up", "down")) {
    direction <- match.arg(direction)
    df <- movers_filtered()
    n <- as.integer(input$movers_topn %||% 12)
    if (direction == "up") {
      df |> slice_max(rank_val, n = n, with_ties = FALSE)
    } else {
      df |> slice_min(rank_val, n = n, with_ties = FALSE)
    }
  }

  render_movers <- function(direction = c("up", "down")) {
    direction <- match.arg(direction)
    renderGirafe({
      df <- movers_slice(direction)
      req(nrow(df) > 0)
      metric <- input$movers_metric %||% "pct"

      df <- df |>
        arrange(rank_val) |>
        mutate(
          station_f = factor(
            paste0(station_name, " · L", line_number),
            levels = paste0(station_name, " · L", line_number)
          ),
          fill_col = unname(line_colors[line_number]),
          tooltip = sprintf(
            paste0(
              "<b>%s</b> · %s<br/>",
              "Últimos 12m: <b>%s</b> pass./dia útil<br/>",
              "12m anteriores: <b>%s</b> pass./dia útil<br/>",
              "Variação: <b>%+.1f%%</b> (%s pass./dia)"
            ),
            station_name, line_labels[line_number],
            formatC(round(avg_recent), big.mark = ".", format = "d"),
            formatC(round(avg_prior), big.mark = ".", format = "d"),
            pct,
            formatC(round(delta), big.mark = ".", format = "d", flag = "+")
          )
        )

      if (metric == "pct") {
        x_lab <- "Variação % vs. 12 meses anteriores"
        df <- df |> mutate(x_val = pct)
        x_scale <- scale_x_continuous(
          labels = scales::label_number(suffix = "%", accuracy = 0.1)
        )
      } else {
        x_lab <- "Variação absoluta (pass./dia útil)"
        df <- df |> mutate(x_val = delta)
        x_scale <- scale_x_continuous(
          labels = scales::label_number(big.mark = ".", decimal.mark = ",")
        )
      }

      p <- ggplot(df, aes(x = x_val, y = station_f)) +
        geom_col_interactive(
          aes(tooltip = tooltip, data_id = station_name, fill = fill_col),
          width = 0.62
        ) +
        scale_fill_identity() +
        geom_vline(xintercept = 0, color = "#8A8FA3", linewidth = 0.4) +
        x_scale +
        labs(x = x_lab, y = NULL) +
        theme_minimal(base_size = 12) +
        theme(
          panel.grid.major.y = element_blank(),
          panel.grid.minor   = element_blank(),
          panel.grid.major.x = element_line(color = "#EDEEF3"),
          axis.text.y        = element_text(size = 10, color = "#0E1130"),
          axis.title.x       = element_text(
            color = "#4A4F6B", size = 10, margin = margin(t = 10)
          ),
          legend.position    = "none",
          plot.margin        = margin(6, 12, 6, 6)
        )

      svg_h <- max(4, nrow(df) * 0.34)

      girafe(
        ggobj = p,
        width_svg = 6.5,
        height_svg = svg_h,
        options = list(
          opts_hover(css = "stroke:#0E1130;stroke-width:1px;fill-opacity:1;"),
          opts_hover_inv(css = "fill-opacity:0.35;"),
          opts_tooltip(
            css = girafe_tooltip_css,
            opacity = 1, offx = 12, offy = -20
          ),
          opts_sizing(rescale = TRUE, width = 1),
          opts_toolbar(saveaspng = FALSE)
        )
      )
    })
  }

  output$movers_up <- render_movers("up")
  output$movers_down <- render_movers("down")

  output$covid_scatter <- renderGirafe({
    req(input$movers_lines)
    df <- station_covid |>
      filter(line_number %in% input$movers_lines)
    req(nrow(df) > 0)

    df <- df |>
      mutate(
        line_label = factor(line_label, levels = unname(line_labels[LINES])),
        tooltip = sprintf(
          paste0(
            "<b>%s</b> · %s<br/>",
            "Média 2019: <b>%s</b> pass./dia útil<br/>",
            "Média 12m recentes: <b>%s</b> pass./dia útil<br/>",
            "Recuperação: <b>%.0f%%</b> de 2019"
          ),
          station_name, line_labels[line_number],
          formatC(round(avg_2019), big.mark = ".", format = "d"),
          formatC(round(avg_recent), big.mark = ".", format = "d"),
          pct_2019
        )
      )

    max_val <- max(c(df$avg_2019, df$avg_recent), na.rm = TRUE) * 1.05

    p <- ggplot(df, aes(x = avg_2019, y = avg_recent)) +
      geom_abline(
        slope = 1, intercept = 0,
        color = "#8A8FA3", linetype = "dashed", linewidth = 0.5
      ) +
      annotate(
        "text",
        x = max_val * 0.92, y = max_val * 0.97,
        label = "recuperação total (y = x)",
        color = "#8A8FA3", size = 3, hjust = 1
      ) +
      geom_point_interactive(
        aes(
          color = line_label,
          tooltip = tooltip,
          data_id = paste0(line_number, "|", station_name)
        ),
        size = 2.6, alpha = 0.85
      ) +
      scale_color_manual(
        values = setNames(
          unname(line_colors[LINES]),
          unname(line_labels[LINES])
        ),
        drop = FALSE,
        name = NULL
      ) +
      scale_x_continuous(
        labels = scales::label_number(scale_cut = scales::cut_short_scale()),
        limits = c(0, max_val)
      ) +
      scale_y_continuous(
        labels = scales::label_number(scale_cut = scales::cut_short_scale()),
        limits = c(0, max_val)
      ) +
      labs(
        x = "Média 2019 (pass./dia útil)",
        y = "Média últimos 12m (pass./dia útil)"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "#EDEEF3"),
        legend.position  = "top",
        legend.text      = element_text(size = 10, color = "#4A4F6B"),
        axis.title       = element_text(color = "#4A4F6B", size = 10),
        plot.margin      = margin(6, 12, 6, 6)
      )

    girafe(
      ggobj = p,
      width_svg = 9,
      height_svg = 6,
      options = list(
        opts_hover(css = "stroke:#0E1130;stroke-width:1.2px;"),
        opts_hover_inv(css = "opacity:0.25;"),
        opts_tooltip(
          css = girafe_tooltip_css,
          opacity = 1, offx = 12, offy = -20
        ),
        opts_sizing(rescale = TRUE, width = 1),
        opts_toolbar(saveaspng = FALSE)
      )
    )
  })

  ## Downloads ----

  csv_dl <- function(stem, data_fn) {
    downloadHandler(
      filename = function() {
        sprintf("metrosp-%s-%s.csv", stem, format(latest_date, "%Y-%m"))
      },
      content = function(file) {
        utils::write.csv(data_fn(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }
    )
  }

  output$dl_overview_trend <- csv_dl("rede-mensal-36m", function() {
    monthly_abs_36 |>
      transmute(
        date, line_number,
        line_name = line_label,
        embarques_mes = value
      )
  })

  output$dl_hero_index <- csv_dl("indice-recuperacao-2019", function() {
    ent_idx |>
      transmute(
        date, line_number,
        line_name = line_label,
        embarques_mes = value,
        base_mensal_2019 = base,
        indice_2019 = round(index, 2)
      )
  })

  output$dl_forecasts <- csv_dl("projecao-6m", function() {
    if (!HAS_FORECASTS) return(data.frame())
    forecasts_all |>
      filter(model == (input$forecast_model %||% "arima"))
  })

  output$dl_compare_series <- csv_dl("comparar-linhas", function() {
    sel <- input$lines_compare %||% LINES
    if (input$compare_metric == "indexed") {
      ent_idx |>
        filter(line_number %in% sel) |>
        transmute(
          date, line_number,
          line_name = line_label,
          embarques_mes = value,
          indice_2019 = round(index, 2)
        )
    } else {
      ent_idx |>
        filter(line_number %in% sel) |>
        transmute(
          date, line_number,
          line_name = line_label,
          embarques_mes = value
        )
    }
  })

  output$dl_compare_heatmap <- csv_dl("heatmap-linhas-meses", function() {
    sel <- input$lines_compare %||% LINES
    heatmap_yr_mo |>
      filter(line_number %in% sel) |>
      transmute(
        ym, date, line_number,
        line_name = line_label,
        indice_2019 = round(index, 2)
      )
  })

  output$dl_movers_up <- csv_dl("movers-crescimento", function() {
    movers_slice("up") |>
      transmute(
        line_number, line_name = line_label, station_name,
        avg_recent_dia_util = round(avg_recent),
        avg_prior_dia_util = round(avg_prior),
        delta_dia_util = round(delta),
        variacao_pct = round(pct, 2)
      )
  })

  output$dl_movers_down <- csv_dl("movers-queda", function() {
    movers_slice("down") |>
      transmute(
        line_number, line_name = line_label, station_name,
        avg_recent_dia_util = round(avg_recent),
        avg_prior_dia_util = round(avg_prior),
        delta_dia_util = round(delta),
        variacao_pct = round(pct, 2)
      )
  })

  output$dl_covid_scatter <- csv_dl("estacoes-2019-vs-12m", function() {
    sel <- input$movers_lines %||% LINES
    station_covid |>
      filter(line_number %in% sel) |>
      transmute(
        line_number, line_name = line_label, station_name,
        avg_2019_dia_util = round(avg_2019),
        avg_recent_dia_util = round(avg_recent),
        delta_dia_util = round(delta),
        pct_de_2019 = round(pct_2019, 2)
      )
  })

  output$dl_station_rank <- csv_dl("ranking-estacoes", function() {
    ln <- input$line_rank %||% "1"
    latest_yr_line <- sta_avg |>
      filter(line_number == ln, !is.na(avg_passenger)) |>
      pull(year) |>
      max(na.rm = TRUE)
    sta_avg |>
      filter(
        line_number == ln,
        year == latest_yr_line,
        !is.na(avg_passenger)
      ) |>
      group_by(line_number, station_name) |>
      summarise(
        media_dia_util = round(mean(avg_passenger, na.rm = TRUE)),
        ano = latest_yr_line,
        .groups = "drop"
      ) |>
      arrange(desc(media_dia_util))
  })
}

shinyApp(ui, server, enableBookmarking = "url")
