# write_data.R
# -----------------------------------------------------------------------------
# write_all_data() is the single side-effecting writer: it persists each
# assembled object to data/<name>.rda via usethis::use_data(), replacing the
# scattered use_data() calls in the former make_datasets.R / import_geosampa.R /
# build_*.R. Run as the terminal target of the graph.
# -----------------------------------------------------------------------------

#' Write all package datasets to data/*.rda.
#' Each argument is an assembled dataset; the parameter name becomes the .rda
#' name. Returns the character vector of dataset names written.
write_all_data <- function(
  passengers_entrance,
  passengers_transported,
  station_averages,
  station_daily,
  lines,
  stations,
  metro_colors,
  station_inauguration,
  calendar_spo
) {
  usethis::use_data(passengers_entrance, overwrite = TRUE)
  usethis::use_data(passengers_transported, overwrite = TRUE)
  usethis::use_data(station_averages, overwrite = TRUE)
  usethis::use_data(station_daily, overwrite = TRUE)
  usethis::use_data(lines, overwrite = TRUE)
  usethis::use_data(stations, overwrite = TRUE)
  usethis::use_data(metro_colors, overwrite = TRUE)
  usethis::use_data(station_inauguration, overwrite = TRUE)
  usethis::use_data(calendar_spo, overwrite = TRUE)

  c(
    "passengers_entrance", "passengers_transported", "station_averages",
    "station_daily", "lines", "stations", "metro_colors",
    "station_inauguration", "calendar_spo"
  )
}
