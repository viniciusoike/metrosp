library(echarts4r)
library(metrosp)
library(dplyr)

dat <- passengers_entrance |>
  filter(line_number == 1, date >= "2019-01-01", metric_abb == "total") |>
  mutate(
    trunc_val = value / 1000
  )

library(echarts4r)
library(jsonlite)

ekio_echarts_theme <- function(
  palette = c("#0B3D5B", "#C8553D", "#E1A730", "#3C8C7E", "#7A7D85", "#A23B5E"),
  font = "Avenir, 'Helvetica Neue', Arial, sans-serif",
  ink = "#1B2A3A",
  muted = "#6B7280",
  grid = "#E6E8EB",
  bg = "transparent"
) {
  axis_label <- list(color = muted, fontFamily = font, fontSize = 12)

  list(
    color = palette, # drives the default series palette
    backgroundColor = bg,
    textStyle = list(fontFamily = font, color = ink),

    title = list(
      left = "left",
      textStyle = list(
        fontFamily = font,
        color = ink,
        fontWeight = "bold",
        fontSize = 18
      ),
      subtextStyle = list(fontFamily = font, color = muted, fontSize = 13)
    ),

    line = list(
      symbol = "circle",
      symbolSize = 7,
      smooth = FALSE,
      lineStyle = list(width = 2.5),
      itemStyle = list(borderWidth = 0)
    ),
    bar = list(itemStyle = list(borderWidth = 0, borderRadius = c(3, 3, 0, 0))),
    pie = list(itemStyle = list(borderColor = "#fff", borderWidth = 1)),
    scatter = list(itemStyle = list(opacity = 0.85)),

    # category axis = clean baseline, no gridlines
    categoryAxis = list(
      axisLine = list(show = TRUE, lineStyle = list(color = muted)),
      axisTick = list(show = FALSE),
      axisLabel = axis_label,
      splitLine = list(show = FALSE),
      splitArea = list(show = FALSE)
    ),
    # value axis = no spine, light dashed horizontal gridlines
    valueAxis = list(
      axisLine = list(show = FALSE),
      axisTick = list(show = FALSE),
      axisLabel = axis_label,
      splitLine = list(
        show = TRUE,
        lineStyle = list(color = grid, type = "dashed")
      ),
      splitArea = list(show = FALSE)
    ),
    timeAxis = list(
      axisLine = list(show = TRUE, lineStyle = list(color = muted)),
      axisTick = list(show = FALSE),
      axisLabel = axis_label,
      splitLine = list(show = FALSE)
    ),

    legend = list(
      textStyle = list(color = ink, fontFamily = font),
      icon = "roundRect",
      itemWidth = 12,
      itemHeight = 12
    ),
    tooltip = list(
      backgroundColor = "rgba(255,255,255,0.96)",
      borderColor = grid,
      borderWidth = 1,
      textStyle = list(color = ink, fontFamily = font),
      axisPointer = list(
        type = "line",
        lineStyle = list(color = muted, type = "dashed")
      )
    ),
    toolbox = list(iconStyle = list(borderColor = muted)),
    dataZoom = list(textStyle = list(color = muted)),
    visualMap = list(textStyle = list(color = ink))
  )
}

ekio_echarts_theme <- function(
  palette = c("#0B3D5B", "#C8553D", "#E1A730", "#3C8C7E", "#7A7D85", "#A23B5E"),
  font = "Avenir, 'Helvetica Neue', Arial, sans-serif",
  ink = "#1B2A3A",
  muted = "#6B7280",
  grid = "#E6E8EB",
  bg = "transparent"
) {
  axis_label <- list(color = muted, fontFamily = font, fontSize = 12)

  list(
    color = palette
  )
}

theme <- jsonlite::toJSON(ekio_echarts_theme(), auto_unbox = TRUE)

e_charts(dat, x = date) |>
  e_line(serie = value) |>
  e_theme_ekio()

e_charts(dat, x = date) |>
  e_line(serie = value) |>
  e_theme_ekio()

e_theme_ekio <- function(e, ...) {
  theme <- jsonlite::toJSON(ekio_echarts_theme(...), auto_unbox = TRUE)
  print(theme)
  echarts4r::e_theme_custom(e, as.character(theme), name = "ekio")
}

e_theme_ekio()

mtcars |>
  tibble::rownames_to_column("model") |>
  head(8) |>
  e_charts(model) |>
  e_bar(mpg) |>
  e_theme_ekio() |>
  e_title("Fuel efficiency", "mpg by model") |>
  e_tooltip(trigger = "axis") |>
  e_x_axis(axisLabel = list(rotate = 30))
