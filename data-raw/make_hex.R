# Hex sticker for metrosp package
# Recreates the Sao Paulo Metro logo symbol using ggplot2 geometry.
#
# Required packages: hexSticker, ggplot2, showtext, sysfonts
# Install if needed:
#   install.packages(c("hexSticker", "ggplot2", "showtext", "sysfonts"))
#
# Run this script from the package root to regenerate man/figures/logo.png

library(ggplot2)
library(tibble)

find_slope <- function(p1, p2) {
  (p2[2] - p1[2]) / (p2[1] - p1[1])
}
compute_y <- function(x, p0, slope) {
  slope * (x - p0[1]) + p0[2]
}

font_text <- "Helvetica"

metro_blue <- "#1D5EA8"
metro_white <- "#FFFFFF"

dots <- tibble::tribble(
  ~x    , ~y    , ~line     ,
   3.75 ,  3.15 , "verde"   ,
   3.75 ,  1.3  , "verde"   ,
  -1.85 ,  2.5  , "verde"   ,
   0.25 , -0.25 , "verde"   ,
   2.75 , -0.25 , "verde"   ,
   2    ,  3.14 , "lilac"   ,
   2    ,  1.3  , "lilac"   ,
   0.25 , -1    , "lilac"   ,
   0    ,  1.35 , "laranja" ,
  -2.25 ,  4.75 , "laranja" ,
  -4    ,  2.5  , "emerald" ,
  -4    , -1    , "emerald" ,
   0    ,  4.5  , "yellow"  ,
  -3.05 , -1    , "brown"   ,
  -0.5  ,  1.2  , "brown"   ,
  -0.5  ,  3.15 , "brown"   ,
   1    ,  4.8  , "brown"   ,
   0    ,  5    , "azul"    ,
   0.25 , -4    , "azul"    ,
)

azul <- tibble::tibble(
  x = c(0, 0, 0.25, 0.25),
  y = c(5, 0, 0, -4),
  group = c(1, 1, 1, 1)
)

yellow <- tibble(
  x = c(-5, -1.8, -1.8, 0),
  y = c(2.5, 2.5, 2.5, 4.5),
  group = c(4, 4, 5, 5)
)

verde <- tibble(
  x = c(-2.5, -0.1, -0.15, 2.75, 2.73, 3.75, 3.75, 3.75),
  y = c(3.46, -0.28, -0.25, -0.25, -0.26, 1.3, 1.25, 3.14),
  group = c(2, 2, 3, 3, 4, 4, 5, 5)
)

laranja <- tibble(
  x = c(-2.25, 0, -0.1, 3.75, -2.25, -2.25),
  y = c(4.77, 1.3, 1.3, 1.3, 4.75, 5.5),
  group = c(2, 2, 3, 3, 4, 4)
)
vermelha <- tibble(
  x = c(-2.5, 0, 0, 5),
  y = c(7, 3.139, 3.139, 3.139)
)

lilac <- tibble(
  x = c(-5, 0.25, 0.24, 2, 2, 2),
  y = c(-1, -1, -1, 0.5, 0.5, 3.14)
)

emerald <- tibble(
  x = c(-4, -4),
  y = c(4, -2.3)
)

brown <- tibble(
  x = c(-0.5, 1, -0.51, -0.51, -0.49, -3.05),
  y = c(3.15, 4.8, 3.17, 1.2, 1.21, -1),
  group = c(1, 1, 2, 2, 3, 3)
)

find_slope(c(0.25, -1), c(2, 0.5))
compute_y(1, c(-0.5, 3.15), find_slope(c(0, 4.5), c(-1.8, 2.5)))

lwd = 1.5

base_plot <- ggplot() +
  stat_connect(
    data = azul,
    aes(x, y, group = group),
    lwd = lwd,
    color = "#171796"
  ) +
  stat_connect(
    data = yellow,
    aes(x, y, group = group),
    lwd = lwd,
    color = "#FFD525",
    connection = "linear"
  ) +
  stat_connect(
    data = verde,
    aes(x, y, group = group),
    lwd = lwd,
    color = "#007A5E",
    connection = "linear",
  ) +
  stat_connect(
    data = laranja,
    aes(x, y, group = group),
    lwd = lwd,
    color = "orange",
    connection = "linear"
  ) +
  stat_connect(
    data = vermelha,
    aes(x, y),
    lwd = lwd,
    color = "#ED2E38",
    connection = "linear"
  ) +
  stat_connect(
    data = lilac,
    aes(x, y),
    lwd = lwd,
    color = "#874ABF",
    connection = "linear"
  ) +
  stat_connect(
    data = emerald,
    aes(x, y),
    lwd = lwd,
    color = "#38aea4",
    connection = "linear"
  ) +
  stat_connect(
    data = brown,
    aes(x, y, group = group),
    lwd = lwd,
    color = "brown",
    connection = "linear"
  ) +
  coord_fixed(xlim = c(-5, 5), ylim = c(-5, 5)) +
  theme_void() +
  theme(
    plot.margin = margin(15, 15, 15, 15)
  )

metro_plot <- base_plot +
  geom_point(
    data = dots,
    size = 3,
    aes(x, y, color = line)
  ) +
  scale_color_manual(
    values = c(
      verde = "#007A5E",
      lilac = "#874ABF",
      azul = "#171796",
      vermelha = "#ED2E38",
      laranja = "orange",
      yellow = "#FFD525",
      emerald = "#38aea4",
      brown = "brown"
    )
  ) +
  guides(color = "none")

final_plot <- metro_plot +
  geom_label(
    data = tibble(x = 0, y = -2.15, label = "METROSP"),
    aes(x, y, label = label),
    family = "Helvetica",
    size = 9,
    color = "#ffffff",
    fill = "#171796"
  )

ggsave(
  "man/figures/metro_plot.png",
  plot = final_plot,
  dpi = 600,
  width = 4,
  height = 4,
  bg = "transparent"
)

# Sticker ----------------------------------------------------------------

hexSticker::sticker(
  subplot = "man/figures/metro_plot.png",
  package = "",
  s_x = 1, # subplot centre x (1 = hex centre)
  s_y = 0.8, # subplot centre y (slightly above mid)
  s_width = 1, # subplot width relative to hex
  s_height = 1,
  h_fill = "#f5f0e8",
  h_color = "#000000", # darker blue border
  h_size = 1.2,
  spotlight = FALSE,
  filename = "man/figures/logo.png",
  dpi = 600
)

message("Hex sticker saved to man/figures/logo.png")
