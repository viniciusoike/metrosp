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

# passengers_entrance ----

timespan_passengers <- compute_line_timespan(passengers_entrance)

plot_passengers_entrance <- plot_line_timespan(
  timespan_passengers,
  "Passenger entries by line: time coverage",
  "Detailed time coverage for each line of the <b>passengers_entrance</b> dataset"
)

plot_passengers_entrance

# passengers_transported ----

timespan_transported <- compute_line_timespan(passengers_transported)

# Line 5 (Lilac) only ran Oct 2017-Aug 2018: its bar is too short to fit both
# labels, so only the end date is shown for this line.
plot_passengers_transported <- plot_line_timespan(
  timespan_transported,
  "Passengers transported by line: time coverage",
  "Detailed time coverage for each line of the <b>passengers_transported</b> dataset",
  hide_d0_label_for = "Lilac"
)

plot_passengers_transported

# station_averages ----

timespan_station_averages <- compute_line_timespan(station_averages)

plot_station_averages <- plot_line_timespan(
  timespan_station_averages,
  "Station averages by line: time coverage",
  "Time coverage aggregated by line for the <b>station_averages</b> dataset (station-level weekday averages)"
)

plot_station_averages

# station_daily ----

timespan_station_daily <- compute_line_timespan(station_daily)

plot_station_daily <- plot_line_timespan(
  timespan_station_daily,
  "Daily station entries by line: time coverage",
  "Time coverage aggregated by line for the <b>station_daily</b> dataset (station-level daily entries)"
)

plot_station_daily

# Export ----

ggsave(
  "man/figures/timespan_passengers_entrance.png",
  plot_passengers_entrance,
  width = 8,
  height = 4.5,
  dpi = 300
)
ggsave(
  "man/figures/timespan_passengers_transported.png",
  plot_passengers_transported,
  width = 8,
  height = 4.5,
  dpi = 300
)
ggsave(
  "man/figures/timespan_station_averages.png",
  plot_station_averages,
  width = 8,
  height = 4.5,
  dpi = 300
)
ggsave(
  "man/figures/timespan_station_daily.png",
  plot_station_daily,
  width = 8,
  height = 4.5,
  dpi = 300
)
