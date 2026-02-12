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
