# write_data.R
# -----------------------------------------------------------------------------
# write_all_data() is the single side-effecting writer: it persists each
# assembled object to data/<name>.rda via usethis::use_data(), replacing the
# scattered use_data() calls in the former dataset builders. Run as the terminal
# target of the graph.
# -----------------------------------------------------------------------------

#' Write all package datasets to data/*.rda.
#' Each argument is an assembled dataset; the parameter name becomes the .rda
#' name. Returns the character vector of dataset names written.
write_all_data <- function(
  line_entries_monthly,
  line_transported_monthly,
  station_entries_monthly,
  station_entries_daily,
  rail_lines,
  rail_stations,
  metro_colors,
  calendar_spo
) {
  usethis::use_data(line_entries_monthly, overwrite = TRUE)
  usethis::use_data(line_transported_monthly, overwrite = TRUE)
  usethis::use_data(station_entries_monthly, overwrite = TRUE)
  usethis::use_data(station_entries_daily, overwrite = TRUE)
  usethis::use_data(rail_lines, overwrite = TRUE)
  usethis::use_data(rail_stations, overwrite = TRUE)
  usethis::use_data(metro_colors, overwrite = TRUE)
  usethis::use_data(calendar_spo, overwrite = TRUE)

  c(
    "line_entries_monthly",
    "line_transported_monthly",
    "station_entries_monthly",
    "station_entries_daily",
    "rail_lines",
    "rail_stations",
    "metro_colors",
    "calendar_spo"
  )
}
