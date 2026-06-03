# Shared metadata and helpers for Metro SP dashboards ----

# Line metadata ----

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

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

metro_primary <- "#171796"

# Formatting helpers ----

fmt_n <- function(x) {
  if (!length(x) || all(is.na(x))) return("—")
  x <- x[!is.na(x)][1]
  if (x >= 1e9) sprintf("%.2f bi", x / 1e9)
  else if (x >= 1e6) sprintf("%.1f M", x / 1e6)
  else if (x >= 1e3) sprintf("%.1f K", x / 1e3)
  else formatC(round(x), format = "d", big.mark = ".")
}

fmt_pct <- function(x, signed = TRUE) {
  if (is.na(x)) return("—")
  if (signed) sprintf("%+.1f%%", x) else sprintf("%.1f%%", x)
}

kpi_card <- function(label, value, sub = NULL) {
  div(
    class = "kpi",
    div(class = "kpi-label", label),
    div(class = "kpi-value", value),
    if (!is.null(sub)) div(class = "kpi-sub", sub)
  )
}

roll_mean <- function(x, k = 7L) {
  n <- length(x)
  out <- rep(NA_real_, n)
  for (i in seq(k, n)) out[i] <- mean(x[(i - k + 1L):i], na.rm = TRUE)
  out
}

# echarts4r JS formatters ----

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

# echarts4r shared defaults ----

e_metro_defaults <- function(e, grid_bottom = 70) {
  e |>
    e_x_axis(type = "time") |>
    e_y_axis(
      axisLabel = list(formatter = js_axis_label_compact),
      splitLine = list(lineStyle = list(color = "#EDEEF3"))
    ) |>
    e_tooltip(trigger = "axis", formatter = js_tooltip_pt_br) |>
    e_legend(bottom = 0, itemWidth = 14, itemHeight = 8) |>
    e_grid(left = 60, right = 24, top = 20, bottom = grid_bottom) |>
    e_datazoom(type = "inside") |>
    e_datazoom(type = "slider", bottom = 8, height = 20) |>
    e_toolbox_feature(feature = "saveAsImage", title = "Salvar")
}

# bslib theme ----

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
