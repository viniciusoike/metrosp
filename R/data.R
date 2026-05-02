#' Passengers Entering Metro SP Stations by Line
#'
#' Monthly count of passengers entering Sao Paulo metro stations, aggregated
#' by metro line. Data covers October 2017 through 2025, sourced from the
#' METRO SP transparency portal.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, 15, or 99 for
#'     network total (integer).}
#'   \item{metric_abb}{Abbreviated metric code (character). One of:
#'     "total", "mdu", "msa", "mdo", "max".}
#'   \item{value}{Passenger count in thousands (numeric).}
#'   \item{metric}{Measurement type in Portuguese (character). One of:
#'     "Total", "Media dos Dias Uteis", "Media dos Sabados",
#'     "Media dos Domingos", "Maxima Diaria".}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{year}{Calendar year (integer).}
#' }
#'
#' @details
#' Lines 1, 2, 3, and 15 come from the METRO transparency portal (2017-2025).
#' Lines 4 (Amarela) and 5 (Lilas) come from the Insper Dataverse source
#' (2020-2025). The network total (line_number = 99) may not be available for
#' all years.
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
#'   \item{line_number}{Metro line number: 1, 2, 3, 5, 15, or 99 for
#'     network total (integer).}
#'   \item{metric_abb}{Abbreviated metric code (character).}
#'   \item{value}{Passenger count in thousands (numeric).}
#'   \item{metric}{Measurement type in Portuguese (character).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{year}{Calendar year (integer).}
#' }
#'
#' @details
#' Lines 1, 2, 3, and 15 come from the METRO transparency portal (2017-2025).
#' Line 5 (Lilas) is available October 2017 - December 2019 only. Line 4
#' (Amarela) is not available in this dataset (the Dataverse source does not
#' include transported data for Lines 4/5). The network total (line_number = 99)
#' may not be available for all years.
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
#'   \item{line_number}{Metro line number (integer).}
#'   \item{station_name}{Name of the metro station (character).}
#'   \item{avg_passenger}{Average weekday passenger entries in thousands
#'     (numeric).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{year}{Calendar year (integer).}
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
#'   \item Line 4 (Amarela/Yellow): available 2020-2025 (Insper Dataverse source)
#'   \item Line 5 (Lilas/Lilac): October 2017 - December 2019 (METRO portal)
#'     and 2020-2025 (Insper Dataverse source)
#'   \item Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
#' }
#'
#' @source Companhia do Metropolitano de Sao Paulo (METRO).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
"station_averages"

#' Daily Passenger Entries by Metro SP Station
#'
#' Daily passenger entries at each station in the Sao Paulo metro system.
#' Data covers 2020 through 2025. Lines 1, 2, 3, and 15 come from the METRO SP
#' transparency portal; Lines 4 and 5 come from the Insper Dataverse source.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{Date of observation (Date).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{station_name}{Full station name (character).}
#'   \item{passengers}{Daily passenger entries in thousands (numeric).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{station_code}{Three-letter station abbreviation used internally
#'     by METRO (character). \code{NA} for Lines 4 and 5 (Dataverse source).}
#'   \item{year}{Calendar year (integer).}
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
#'   \item Line 4 (Amarela/Yellow): available 2020-2025 (Insper Dataverse);
#'     \code{station_code} is \code{NA}
#'   \item Line 5 (Lilas/Lilac): available 2020-2025 (Insper Dataverse);
#'     \code{station_code} is \code{NA}
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

#' Metro and Train Line Routes
#'
#' Spatial line geometries for Sao Paulo metro (METRO SP) and commuter train
#' (CPTM) lines, including both currently operating lines and planned future
#' expansions.
#'
#' @format An sf data frame with LINESTRING geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{line_number}{Official line number (integer).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#'   \item{company_name}{Operating company name (character).}
#'   \item{type}{Either \code{"metro"} (METRO SP) or \code{"train"} (CPTM)
#'     (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"future"}
#'     (planned expansion) (character).}
#'   \item{geometry}{Line route geometry (sfc_LINESTRING).}
#' }
#'
#' @details
#' Requires the \pkg{sf} package to work with spatial features. The distinction
#' between types isn't always consistent, but we follow GeoSampa's classification.
#' Broadly speaking, the "metro" runs undergrounds as a subway, and "train" runs
#' above grounds as a commuter rail (although there are exceptions)
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{stations}} for station point locations.
"lines"

#' Metro and Train Station Locations
#'
#' Spatial point locations for Sao Paulo metro (METRO SP) and commuter train
#' (CPTM) stations, including both currently operating stations and planned
#' future stations.
#'
#' @format An sf data frame with POINT geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{station_name}{Station name in title case (character).}
#'   \item{line_number}{Line number the station belongs to (integer).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#'   \item{company_name}{Operating company name (character).}
#'   \item{type}{Either \code{"metro"} (METRO SP) or \code{"train"} (CPTM)
#'     (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"future"}
#'     (planned expansion) (character).}
#'   \item{geometry}{Station location (sfc_POINT).}
#' }
#'
#' @details
#' Requires the \pkg{sf} package to work with spatial features. The distinction
#' between types isn't always consistent, but we follow GeoSampa's classification.
#' Broadly speaking, the "metro" runs undergrounds as a subway, and "train" runs
#' above grounds as a commuter rail (although there are exceptions)
#'
#' @source GeoSampa, Prefeitura de Sao Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{lines}} for line route geometries,
#'   \code{\link{station_averages}} for passenger data by station.
"stations"

#' Metro SP Line Reference Table
#'
#' A reference tibble mapping metro line numbers to their Portuguese and English
#' color names. Covers all METRO SP and ViaMobilidade lines including planned
#' future lines and the network total.
#'
#' @format A tibble with 13 rows and 3 columns:
#' \describe{
#'   \item{line_number}{Official line number (integer). Includes 1, 2, 3, 4, 5,
#'     6, 15, 16, 17, 19, 20, 22, and 99 (network total).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#' }
#'
#' @details
#' This dataset serves as a dimension/lookup table for joining line names onto
#' passenger and station datasets. Not all lines have passenger data — some
#' (e.g., Lines 6, 16, 17) are planned future lines with only spatial geometry
#' available in \code{\link{lines}}.
#'
#' @seealso \code{\link{metro_colors}} for official hex color codes,
#'   \code{\link{lines}} for spatial line geometries.
"metro_lines"

#' Metro SP Official Line Colors
#'
#' A named character vector of official hex color codes for the six metro lines
#' operated by METRO SP (Lines 1-3, 5, 15) and ViaMobilidade Line 4.
#'
#' @format A named character vector of length 6. Names are English color names;
#'   values are hex color codes:
#' \describe{
#'   \item{Blue}{Line 1 — \code{"#171796"}}
#'   \item{Green}{Line 2 — \code{"#007A5E"}}
#'   \item{Red}{Line 3 — \code{"#ED2E38"}}
#'   \item{Yellow}{Line 4 — \code{"#FFD525"}}
#'   \item{Lilac}{Line 5 — \code{"#874ABF"}}
#'   \item{Silver}{Line 15 — \code{"#8F8F8C"}}
#' }
#'
#' @details
#' Colors follow the official METRO SP and ViaMobilidade branding. Only the six
#' currently operating metro lines are included; CPTM train lines and planned
#' future lines (e.g., Line 6 Orange, Line 17 Gold) are not covered.
#'
#' @seealso \code{\link{metro_lines}} for the full line reference table.
"metro_colors"
