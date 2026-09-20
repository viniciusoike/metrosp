library(metrosp)
library(ggplot2)
library(dplyr)
library(ggtext)
library(lubridate)

# Helpers ----

line_text_color <- function(line_name) {
  rgb <- grDevices::col2rgb(metro_colors[as.character(line_name)])
  luminance <- (0.299 * rgb[1, ] + 0.587 * rgb[2, ] + 0.114 * rgb[3, ]) / 255
  ifelse(luminance > 0.6, "#000000", "#ffffff")
}

compute_line_timespan <- function(data) {
  data |>
    filter(line_name %in% names(metro_colors)) |>
    summarise(
      d0 = min(date, na.rm = TRUE),
      d1 = max(date, na.rm = TRUE),
      .by = c("line_number", "line_name")
    ) |>
    mutate(
      line_name = factor(line_name, levels = rev(names(metro_colors))),
      row_number = as.numeric(line_name)
    ) |>
    arrange(line_name)
}

plot_line_timespan <- function(
  data,
  title,
  subtitle,
  hide_d0_label_for = character(0)
) {
  d0_labels <- filter(data, !line_name %in% hide_d0_label_for)

  ggplot(data) +
    geom_rect(
      aes(
        xmin = d0,
        xmax = d1,
        ymin = row_number - 0.3,
        ymax = row_number + 0.3,
        fill = line_name
      ),
    ) +
    geom_text(
      data = d0_labels,
      aes(
        x = d0 %m+% months(2),
        y = row_number,
        label = format(d0, "%Y-%m"),
        color = I(line_text_color(line_name))
      ),
      family = "Lato",
      fontface = "bold",
      hjust = 0,
      size = 3
    ) +
    geom_text(
      aes(
        x = d1 %m-% months(2),
        y = row_number,
        label = format(d1, "%Y-%m"),
        color = I(line_text_color(line_name))
      ),
      family = "Lato",
      fontface = "bold",
      hjust = 1,
      size = 3
    ) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    scale_y_continuous(
      breaks = 1:6,
      labels = rev(names(metro_colors)),
      limits = c(0.5, 6.5)
    ) +
    scale_fill_manual(values = metro_colors) +
    guides(fill = "none") +
    labs(
      title = title,
      subtitle = subtitle,
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_family = "Avenir", base_size = 12) +
    theme_sub_plot(
      background = element_rect(fill = "#f5f5f5"),
      margin = margin(15, 10, 15, 10),
      subtitle = element_textbox(),
      title.position = "plot"
    ) +
    theme_sub_panel(
      grid.minor = element_blank(),
      grid.major.y = element_blank()
    ) +
    theme_sub_axis(
      line = element_line(color = "gray20")
    )
}

# line_entries_monthly ----

timespan_passengers <- compute_line_timespan(line_entries_monthly)

plot_line_entries_monthly <- plot_line_timespan(
  timespan_passengers,
  "Passenger entries by line: time coverage",
  "Detailed time coverage for each line of the <b>line_entries_monthly</b> dataset"
)

plot_line_entries_monthly

# line_transported_monthly ----

timespan_transported <- compute_line_timespan(line_transported_monthly)

plot_line_transported_monthly <- plot_line_timespan(
  timespan_transported,
  "Passengers transported by line: time coverage",
  "Detailed time coverage for each line of the <b>line_transported_monthly</b> dataset"
)

plot_line_transported_monthly

# station_entries_monthly ----

timespan_station_entries_monthly <- compute_line_timespan(
  station_entries_monthly
)

plot_station_entries_monthly <- plot_line_timespan(
  timespan_station_entries_monthly,
  "Station averages by line: time coverage",
  "Time coverage aggregated by line for the <b>station_entries_monthly</b> dataset (station-level weekday averages)"
)

plot_station_entries_monthly

# station_entries_daily ----

timespan_station_entries_daily <- compute_line_timespan(station_entries_daily)

plot_station_entries_daily <- plot_line_timespan(
  timespan_station_entries_daily,
  "Daily station entries by line: time coverage",
  "Time coverage aggregated by line for the <b>station_entries_daily</b> dataset (station-level daily entries)"
)

plot_station_entries_daily

# Export ----

ggsave(
  "man/figures/timespan_line_entries_monthly.png",
  plot_line_entries_monthly,
  width = 8,
  height = 4.5,
  dpi = 300
)
ggsave(
  "man/figures/timespan_line_transported_monthly.png",
  plot_line_transported_monthly,
  width = 8,
  height = 4.5,
  dpi = 300
)
ggsave(
  "man/figures/timespan_station_entries_monthly.png",
  plot_station_entries_monthly,
  width = 8,
  height = 4.5,
  dpi = 300
)
ggsave(
  "man/figures/timespan_station_entries_daily.png",
  plot_station_entries_daily,
  width = 8,
  height = 4.5,
  dpi = 300
)
