library(echarts4r)
library(metrosp)
library(dplyr)

dat <- passengers_entrance |>
  filter(line_number == 1, date >= "2019-01-01", metric_abb == "total") |>
  mutate(
    trunc_val = value / 1000
  )

e_charts(dat, x = date) |>
  e_line(value) |>
  e_title("Total Passengers Entrance", subtext = "2019") |>
  e_tooltip(
    axisPointer = list(snap = TRUE),
    textStyle = list(fontSize = 10, fontFamily = "Poppins", fontWeight = "bold")
  )

coldat <- station_averages |>
  filter(date == max(date), line_number == 1) |>
  mutate(
    station_name = factor(station_name),
    station_name = forcats::fct_reorder(station_name, avg_passenger)
  ) |>
  arrange(station_name)

e_charts(coldat, station_name) |>
  e_bar(serie = avg_passenger)

e_charts(coldat, station_name) |>
  e_bar(serie = avg_passenger) |>
  e_labels(position = c("50%", "25%")) |>
  e_flip_coords()

subdat <- passengers_entrance |>
  filter(
    line_number %in% c(1, 2),
    date >= "2019-01-01",
    metric_abb %in% c("mdu", "mdo")
  )

subdat <- subdat |>
  tidyr::pivot_wider(
    id_cols = c(date, line_number, line_name),
    names_from = metric_abb,
    values_from = value
  ) |>
  mutate(year = lubridate::year(date)) |>
  group_by(year, line_name)

e_charts(subdat, x = mdo) |>
  e_scatter(serie = mdu, symbol_size = 15)

brigs <- station_daily |>
  filter(
    station_name == "Brigadeiro",
    date >= "2025-01-01",
    date <= "2025-12-31"
  )

e_charts(brigs, date) |>
  e_calendar(range = 2025) |>
  e_heatmap(passengers, coord_system = "calendar", bind = station_name) |>
  e_tooltip(
    trigger = "item",
    formatter = htmlwidgets::JS(
      "function(params){
        return('<strong>' + params.name + '</strong><br>Dia: ' + params.value[0] + '<br> Total: ' + params.value[1])
      }"
    )
  ) |>
  e_visual_map(max = max(brigs$passengers))

library(gapminder)

gapminder <- gapminder |>
  group_by(year) |>
  mutate(lgdp = log(gdpPercap), lpop = log(pop))

e_charts(gapminder, lgdp, timeline = TRUE) |>
  e_scatter(serie = lifeExp, size = lpop)

brigs <- station_daily |>
  mutate(
    year = lubridate::year(date),
    month = lubridate::month(date)
  ) |>
  filter(
    year >= 2019,
    month <= 3,
    station_name == "Brigadeiro"
  ) |>
  group_by(year)

e_charts(brigs, x = date, timeline = TRUE) |>
  e_calendar(range = 2021) |>
  e_heatmap(passengers, coord_system = "calendar") |>
  e_tooltip(
    trigger = "item",
    formatter = htmlwidgets::JS(
      "function(params){
        return('Dia: ' + params.value[0] + '<br> Total: ' + params.value[1])
      }"
    )
  ) |>
  e_visual_map(max = max(brigs$passengers))

verde <- station_daily |>
  mutate(
    year = lubridate::year(date),
    year = as.character(year),
    month = lubridate::month(date, label = TRUE, locale = "pt_BR"),
  ) |>
  filter(station_name %in% c("Consolação", "Trianon-Masp", "Brigadeiro")) |>
  group_by(station_name)

e_charts(verde, x = month, timeline = TRUE) |>
  e_heatmap(y = year, z = passengers) |>
  e_tooltip(
    trigger = "item",
    formatter = htmlwidgets::JS(
      "function(params){
      return('<strong>' + params.value[1] + '/' + params.value[0] + '</strong><br> Passgeiros: ' + params.value[2])
      }"
    )
  ) |>
  e_visual_map(passengers)


ekioplot::show_ekio_palette("contrast")
