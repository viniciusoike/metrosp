#' Passengers Entering Metro SP Stations by Line
#'
#' Monthly count of passengers entering Sao Paulo metro stations, aggregated
#' by metro line. Data covers October 2017 through 2025, sourced from the
#' METRO SP transparency portal.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 5, 15, or 99 for
#'     network total (integer).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{metric}{Measurement type in Portuguese (character). One of:
#'     "Total", "Media dos Dias Uteis", "Media dos Sabados",
#'     "Media dos Domingos", "Maxima Diaria".}
#'   \item{metric_abb}{Abbreviated metric code (character). One of:
#'     "total", "mdu", "msa", "mdo", "max".}
#'   \item{value}{Passenger count in thousands (numeric).}
#' }
#'
#' @details
#' Line 5 (Lilas) is only available for the 2017-2019 period. The network
#' total (line_number = 99) may not be available for all years.
#'
#' Values represent thousands of passengers (e.g., a value of 900 means
#' 900,000 passengers).
#'
#' Metrics:
#' \itemize{
#'   \item \code{total}: Total passengers in the month
#'   \item \code{mdu}: Average on business days (Media dos Dias Uteis)
#'   \item \code{msa}: Average on Saturdays (Media dos Sabados)
#'   \item \code{mdo}: Average on Sundays (Media dos Domingos)
#'   \item \code{max}: Daily maximum (Maxima Diaria)
#' }
#'
#' @source Companhia do Metropolitano de Sao Paulo (METRO).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
"passengers_entrance"

#' Passengers Transported by Metro SP Line
#'
#' Monthly count of passengers transported by Sao Paulo metro, aggregated
#' by metro line. Data covers October 2017 through 2025, sourced from the
#' METRO SP transparency portal.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 5, 15, or 99 for
#'     network total (integer).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{metric}{Measurement type in Portuguese (character).}
#'   \item{metric_abb}{Abbreviated metric code (character).}
#'   \item{value}{Passenger count in thousands (numeric).}
#' }
#'
#' @inherit passengers_entrance details
#'
#' @source Companhia do Metropolitano de Sao Paulo (METRO).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
"passengers_transported"

#' Average Weekday Passenger Entries by Station
#'
#' Monthly average of weekday (business day) passenger entries for each
#' station in the Sao Paulo metro system. Data covers October 2017 through
#' 2025, sourced from the METRO SP transparency portal.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number (integer).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{station_name}{Name of the metro station (character).}
#'   \item{avg_passenger}{Average weekday passenger entries in thousands
#'     (numeric).}
#' }
#'
#' @details
#' Only the weekday average (mdu) metric is available at the station level.
#' For line-level data with all 5 metrics, see \code{\link{passengers_entrance}}.
#'
#' Station coverage varies by line:
#' \itemize{
#'   \item Line 1 (Azul/Blue): 23 stations
#'   \item Line 2 (Verde/Green): 14 stations
#'   \item Line 3 (Vermelha/Red): 18 stations
#'   \item Line 5 (Lilas/Lilac): available October 2017 - December 2019 only
#'   \item Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
#' }
#'
#' @source Companhia do Metropolitano de Sao Paulo (METRO).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
"station_averages"

#' Daily Passenger Entries by Metro SP Station
#'
#' Daily passenger entries at each station in the Sao Paulo metro system.
#' Data covers 2020 through 2025, sourced from the METRO SP transparency
#' portal. Covers Lines 1, 2, 3, and 15 only (the lines operated by METRO).
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{Date of observation (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number: 1, 2, 3, or 15 (integer).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{station_code}{Three-letter station abbreviation used internally
#'     by METRO (character).}
#'   \item{station_name}{Full station name (character).}
#'   \item{passengers}{Daily passenger entries in thousands (numeric).}
#' }
#'
#' @details
#' Values represent thousands of passengers (e.g., a value of 50 means
#' 50,000 passengers entering the station that day).
#'
#' Station coverage by line:
#' \itemize{
#'   \item Line 1 (Azul/Blue): 23 stations
#'   \item Line 2 (Verde/Green): 14 stations
#'   \item Line 3 (Vermelha/Red): 18 stations
#'   \item Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
#'     (Jardim Colonial added)
#' }
#'
#' Some stations appear on multiple lines (e.g., Ana Rosa on Lines 1 and 2,
#' Paraiso on Lines 1 and 2, Se on Lines 1 and 3). These are recorded
#' separately for each line.
#'
#' @source Companhia do Metropolitano de Sao Paulo (METRO).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{station_averages}} for monthly weekday averages,
#'   \code{\link{passengers_entrance}} for monthly line-level totals.
"station_daily"

#' Metro SP Lines Reference Table
#'
#' Reference table mapping line numbers to Portuguese and English names
#' for all Sao Paulo metro lines.
#'
#' @format A data frame with 13 rows and 3 columns:
#' \describe{
#'   \item{line_number}{Official line number (integer). 99 represents the
#'     network total.}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#' }
#'
#' @source Companhia do Metropolitano de Sao Paulo (METRO).
"metro_lines"

#' Metro SP Line Routes (Spatial)
#'
#' Spatial line geometries for Sao Paulo metro lines, including both
#' currently operating lines and planned future expansions. Sourced from
#' GeoSampa (Prefeitura de Sao Paulo).
#'
#' @format An sf data frame with LINESTRING geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{line_number}{Official line number (integer).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#'   \item{company}{Operating company name (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"planned"}
#'     (future expansion) (character).}
#'   \item{geometry}{Line route geometry (sfc_LINESTRING).}
#' }
#'
#' @details
#' Current lines: Azul (1), Verde (2), Vermelha (3), Amarela (4),
#' Lilas (5), and Prata (15). Planned lines include future extensions and
#' new lines (Laranja, Violeta, Ouro, Celeste, Rosa, Marrom).
#'
#' Some lines have multiple geometry segments (rows) representing
#' different route sections.
#'
#' Requires the \pkg{sf} package to work with spatial features.
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{metro_lines}} for the non-spatial reference table,
#'   \code{\link{metro_stations_geo}} for station point locations.
"metro_lines_geo"

#' Metro SP Station Locations (Spatial)
#'
#' Spatial point locations for Sao Paulo metro stations, including both
#' currently operating stations and planned future stations. Sourced from
#' GeoSampa (Prefeitura de Sao Paulo).
#'
#' @format An sf data frame with POINT geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{station_name}{Station name in title case (character).}
#'   \item{line_number}{Line number the station belongs to (integer).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#'   \item{company}{Operating company name (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"planned"}
#'     (future expansion) (character).}
#'   \item{geometry}{Station location (sfc_POINT).}
#' }
#'
#' @details
#' Requires the \pkg{sf} package to work with spatial features.
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{metro_lines_geo}} for line route geometries,
#'   \code{\link{station_averages}} for passenger data by station.
"metro_stations_geo"

#' CPTM Train Line Routes (Spatial)
#'
#' Spatial line geometries for Sao Paulo CPTM commuter train lines,
#' including both currently operating lines and planned future expansions.
#' Sourced from GeoSampa (Prefeitura de Sao Paulo).
#'
#' @format An sf data frame with LINESTRING geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{line_number}{Official line number (integer). \code{NA} for planned
#'     lines without an assigned number.}
#'   \item{line_name_pt}{Portuguese name of the line (character).}
#'   \item{line_name}{English name of the line (character). \code{NA} for
#'     planned lines not in the reference table.}
#'   \item{company}{Operating company name (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"planned"}
#'     (future expansion) (character).}
#'   \item{geometry}{Line route geometry (sfc_LINESTRING).}
#' }
#'
#' @details
#' Current CPTM lines: Rubi (7), Diamante (8), Esmeralda (9),
#' Turquesa (10), Coral (11), Safira (12), Jade (13).
#'
#' Some lines have multiple geometry segments (rows).
#'
#' Requires the \pkg{sf} package to work with spatial features.
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{train_lines}} for the non-spatial reference table,
#'   \code{\link{train_stations_geo}} for station point locations.
"train_lines_geo"

#' CPTM Train Station Locations (Spatial)
#'
#' Spatial point locations for Sao Paulo CPTM commuter train stations,
#' including both currently operating and planned future stations.
#' Sourced from GeoSampa (Prefeitura de Sao Paulo).
#'
#' @format An sf data frame with POINT geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{station_name}{Station name in title case (character).}
#'   \item{line_number}{Line number the station belongs to (integer).
#'     \code{NA} for planned stations on lines without assigned numbers.}
#'   \item{line_name_pt}{Portuguese name of the line (character).}
#'   \item{line_name}{English name of the line (character). \code{NA} for
#'     planned lines not in the reference table.}
#'   \item{company}{Operating company name (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"planned"}
#'     (future expansion) (character).}
#'   \item{geometry}{Station location (sfc_POINT).}
#' }
#'
#' @details
#' Requires the \pkg{sf} package to work with spatial features.
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{train_lines_geo}} for line route geometries.
"train_stations_geo"

#' CPTM Train Lines Reference Table
#'
#' Reference table mapping line numbers to Portuguese and English names
#' for Sao Paulo CPTM commuter train lines.
#'
#' @format A data frame with 8 rows and 3 columns:
#' \describe{
#'   \item{line_number}{Official line number (integer).}
#'   \item{line_name_pt}{Portuguese gemstone/color name (character).}
#'   \item{line_name}{English gemstone/color name (character).}
#' }
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'
#' @seealso \code{\link{metro_lines}} for metro line reference table.
"train_lines"
