# Hex sticker for metrosp package
# Recreates the Sao Paulo Metro logo symbol using ggplot2 geometry.
#
# Required packages: hexSticker, ggplot2, showtext, sysfonts
# Install if needed:
#   install.packages(c("hexSticker", "ggplot2", "showtext", "sysfonts"))
#
# Run this script from the package root to regenerate man/figures/logo.png

library(ggplot2)
library(hexSticker)
library(showtext)
library(sysfonts)

# ---------------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------------
font_add_google("Barlow", "barlow")  # clean sans-serif close to Metro SP signage
showtext_auto()

# ---------------------------------------------------------------------------
# Metro SP brand color
# ---------------------------------------------------------------------------
metro_blue  <- "#1D5EA8"
metro_white <- "#FFFFFF"

# ---------------------------------------------------------------------------
# Helper: rotate a 2-column matrix of (x, y) coords by `angle` degrees
# around a centre point (cx, cy).
# ---------------------------------------------------------------------------
rotate_coords <- function(mat, angle_deg, cx = 0, cy = 0) {
  rad <- angle_deg * pi / 180
  x   <- mat[, 1] - cx
  y   <- mat[, 2] - cy
  data.frame(
    x = cx + x * cos(rad) - y * sin(rad),
    y = cy + x * sin(rad) + y * cos(rad)
  )
}

# ---------------------------------------------------------------------------
# 1.  Two overlapping hollow diamonds
#
#     Each diamond is drawn as TWO filled polygons:
#       outer square → filled white
#       inner square → filled metro_blue  (creates hollow "frame" look)
#
#     The two diamonds share the same centre (0, 0).
#     upper diamond : upward-pointing  → no extra rotation needed
#     lower diamond : downward-pointing → rotate 180° (same shape, different half)
#
#     We use a single centre for both; the visual separation comes from the
#     logo's proportions: the diamonds are tall, so the top half of the
#     combined shape is the upper diamond and the bottom half is the lower one.
# ---------------------------------------------------------------------------

# Size parameters (in plot-unit space, roughly -1 to 1)
outer_r <- 0.72   # outer "radius" (half-diagonal of outer square)
inner_r <- 0.47   # inner "radius" (half-diagonal of inner square = defines line thickness)

# A square with corners at distance r from origin, rotated 45° → diamond
diamond_outer <- function(r) {
  rotate_coords(matrix(c(-r, 0,  0, r,  r, 0,  0, -r), ncol = 2, byrow = TRUE), 0)
}
diamond_inner <- function(r) {
  rotate_coords(matrix(c(-r, 0,  0, r,  r, 0,  0, -r), ncol = 2, byrow = TRUE), 0)
}

do <- diamond_outer(outer_r)
di <- diamond_inner(inner_r)
do$group <- "outer"
di$group <- "inner"

# ---------------------------------------------------------------------------
# 2.  Double vertical arrow  (up arrow + down arrow)
#
#     Drawn as two separate polygons (arrowheads) plus a shared shaft.
#     The shaft is a thin vertical rectangle; arrowheads are triangles.
# ---------------------------------------------------------------------------

shaft_w  <- 0.10   # half-width of the shaft
shaft_top    <-  0.60  # top of shaft (where upper head meets)
shaft_bot    <- -0.60  # bottom of shaft (where lower head meets)
head_w   <- 0.30   # half-width of arrowhead base
head_h   <- 0.22   # height of arrowhead

# Shaft rectangle
shaft <- data.frame(
  x = c(-shaft_w, shaft_w, shaft_w, -shaft_w),
  y = c(shaft_bot, shaft_bot, shaft_top, shaft_top)
)

# Upper arrowhead (points up)
arrow_up <- data.frame(
  x = c(-head_w,  0,  head_w),
  y = c(shaft_top, shaft_top + head_h, shaft_top)
)

# Lower arrowhead (points down)
arrow_dn <- data.frame(
  x = c(-head_w,  0,  head_w),
  y = c(shaft_bot, shaft_bot - head_h, shaft_bot)
)

# ---------------------------------------------------------------------------
# 3.  Build the ggplot2 subplot
# ---------------------------------------------------------------------------

p <- ggplot() +
  # ---- Diamond outlines (white outer, blue inner = hollow frame) ----
  geom_polygon(data = do, aes(x, y), fill = metro_white, colour = NA) +
  geom_polygon(data = di, aes(x, y), fill = metro_blue,  colour = NA) +
  # ---- Double arrow ----
  geom_polygon(data = shaft,    aes(x, y), fill = metro_white, colour = NA) +
  geom_polygon(data = arrow_up, aes(x, y), fill = metro_white, colour = NA) +
  geom_polygon(data = arrow_dn, aes(x, y), fill = metro_white, colour = NA) +
  # ---- Cosmetics ----
  coord_fixed(xlim = c(-1, 1), ylim = c(-1, 1)) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA)
  )

# ---------------------------------------------------------------------------
# 4.  Build the hex sticker
# ---------------------------------------------------------------------------

sticker(
  subplot   = p,
  package   = "metrosp",
  p_size    = 20,          # package name font size
  p_color   = metro_white,
  p_family  = "barlow",
  p_fontface = "bold",
  p_y       = 1.50,        # push text to bottom third of hex
  s_x       = 1.00,        # subplot centre x (1 = hex centre)
  s_y       = 0.95,        # subplot centre y (slightly above mid)
  s_width   = 0.90,        # subplot width relative to hex
  s_height  = 0.90,
  h_fill    = metro_blue,
  h_color   = "#0F3D73",   # darker blue border
  h_size    = 1.5,
  spotlight = FALSE,
  filename  = "man/figures/logo.png",
  dpi       = 600
)

message("Hex sticker saved to man/figures/logo.png")
