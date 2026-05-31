#' Passengers Entering Metro SP Stations by Line
#'
#' Monthly count of passengers entering São Paulo metro stations, aggregated
#' by metro line. Data covers October 2017 through 2026 for Lines 1, 2, 3,
#' and 15; Line 4 from January 2012; Line 5 from October 2017. Sourced from
#' the METRO SP transparency portal and the Insper Dataverse.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, 15, or 99 for
#'     the network total (integer).}
#'   \item{metric_abb}{Abbreviated metric code (character). One of:
#'     \code{"total"}, \code{"mdu"}, \code{"msa"}, \code{"mdo"},
#'     \code{"max"}.}
#'   \item{value}{Passenger count (numeric).}
#'   \item{metric}{Measurement type in English (character). One of:
#'     \code{"Total"}, \code{"Average on Business Days"},
#'     \code{"Average on Saturdays"}, \code{"Average on Sundays"},
#'     \code{"Daily Peak"}.}
#'   \item{metric_pt}{Measurement type in Portuguese (character). One of:
#'     \code{"Total"}, \code{"Média dos Dias Úteis"},
#'     \code{"Média dos Sábados"}, \code{"Média dos Domingos"},
#'     \code{"Máxima Diária"}.}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{year}{Calendar year (integer).}
#' }
#'
#' @details
#' Data by source and line:
#' \itemize{
#'   \item Lines 1, 2, 3, and 15: METRO SP transparency portal,
#'     October 2017–2026.
#'   \item Line 4 (Amarela/ViaQuatro): Insper Dataverse,
#'     January 2012–2026.
#'   \item Line 5 (Lilás/ViaMobilidade): METRO SP transparency portal,
#'     October 2017–July 2018; Insper Dataverse, August 2018–2026.
#'   \item Network total (\code{line_number = 99}): METRO SP transparency
#'     portal only; may not be available for all years.
#' }
#'
#' Metrics:
#' \itemize{
#'   \item \code{total}: Total passengers in the month.
#'   \item \code{mdu}: Average daily entries on business days
#'     (Média dos Dias Úteis).
#'   \item \code{msa}: Average daily entries on Saturdays
#'     (Média dos Sábados).
#'   \item \code{mdo}: Average daily entries on Sundays
#'     (Média dos Domingos).
#'   \item \code{max}: Daily maximum (Máxima Diária).
#' }
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{passengers_transported}} for transported counts,
#'   \code{\link{station_averages}} for station-level weekday averages.
"passengers_entrance"

#' Passengers Transported by Metro SP Line
#'
#' Monthly count of passengers transported by São Paulo metro, aggregated
#' by metro line. Data covers October 2017 through 2026 for Lines 1, 2, 3,
#' and 15, and October 2017 through December 2019 for Line 5. Sourced from
#' the METRO SP transparency portal.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 5, 15, or 99 for
#'     the network total (integer).}
#'   \item{metric_abb}{Abbreviated metric code (character). One of:
#'     \code{"total"}, \code{"mdu"}, \code{"msa"}, \code{"mdo"},
#'     \code{"max"}.}
#'   \item{value}{Passenger count (numeric).}
#'   \item{metric}{Measurement type in English (character). One of:
#'     \code{"Total"}, \code{"Average on Business Days"},
#'     \code{"Average on Saturdays"}, \code{"Average on Sundays"},
#'     \code{"Daily Peak"}.}
#'   \item{metric_pt}{Measurement type in Portuguese (character). One of:
#'     \code{"Total"}, \code{"Média dos Dias Úteis"},
#'     \code{"Média dos Sábados"}, \code{"Média dos Domingos"},
#'     \code{"Máxima Diária"}.}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{year}{Calendar year (integer).}
#' }
#'
#' @details
#' All data comes from the METRO SP transparency portal. Line 4 (Amarela)
#' is not available in this dataset — the Insper Dataverse source does not
#' include transported counts for Lines 4 or 5. Line 5 (Lilás) is available
#' from the METRO portal only for October 2017–December 2019. The network
#' total (\code{line_number = 99}) may not be available for all years.
#'
#' Metrics:
#' \itemize{
#'   \item \code{total}: Total passengers in the month.
#'   \item \code{mdu}: Average daily entries on business days
#'     (Média dos Dias Úteis).
#'   \item \code{msa}: Average daily entries on Saturdays
#'     (Média dos Sábados).
#'   \item \code{mdo}: Average daily entries on Sundays
#'     (Média dos Domingos).
#'   \item \code{max}: Daily maximum (Máxima Diária).
#' }
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{passengers_entrance}} for entry counts,
#'   \code{\link{station_averages}} for station-level weekday averages.
"passengers_transported"

#' Average Weekday Passenger Entries by Station
#'
#' Monthly average of weekday (business day) passenger entries for each
#' station in the São Paulo metro system. Data covers October 2017 through
#' 2026 for Lines 1, 2, 3, and 15; Line 4 from January 2012; Line 5 from
#' October 2017. Sourced from the METRO SP transparency portal and the
#' Insper Dataverse.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{line_number}{Metro line number (integer).}
#'   \item{station_name}{Name of the metro station (character).}
#'   \item{avg_passenger}{Average weekday passenger entries (numeric).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{year}{Calendar year (integer).}
#' }
#'
#' @details
#' Only the weekday average (mdu) metric is available at the station level.
#' For line-level data with all five metrics, see
#' \code{\link{passengers_entrance}}.
#'
#' Station coverage by line and source:
#' \itemize{
#'   \item Line 1 (Azul/Blue): 23 stations, October 2017–2026 (METRO SP
#'     portal).
#'   \item Line 2 (Verde/Green): 14 stations, October 2017–2026 (METRO SP
#'     portal).
#'   \item Line 3 (Vermelha/Red): 18 stations, October 2017–2026 (METRO SP
#'     portal).
#'   \item Line 4 (Amarela/Yellow): January 2012–2026 (Insper Dataverse).
#'   \item Line 5 (Lilás/Lilac): October 2017–July 2018 (METRO SP portal)
#'     and August 2018–2026 (Insper Dataverse).
#'   \item Line 15 (Prata/Silver): 10 stations in 2020, 11 from January
#'     2021 onward (Jardim Colonial added), October 2017–2026 (METRO SP
#'     portal).
#' }
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{station_daily}} for daily station entries,
#'   \code{\link{passengers_entrance}} for monthly line-level totals.
"station_averages"

#' Daily Passenger Entries by Metro SP Station
#'
#' Daily passenger entries at each station in the São Paulo metro system.
#' Data covers January 2012 through 2026 for Lines 4 and 5 (Insper
#' Dataverse), and 2020 through 2026 for Lines 1, 2, 3, and 15 (METRO SP
#' transparency portal).
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{Date of observation (Date).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{station_name}{Full station name (character).}
#'   \item{passengers}{Daily passenger entries (numeric).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{station_code}{Three-letter station abbreviation used internally
#'     by METRO SP (character). \code{NA} for Lines 4 and 5 (Dataverse
#'     source).}
#'   \item{year}{Calendar year (integer).}
#' }
#'
#' @details
#' Station coverage and date range by line:
#' \itemize{
#'   \item Line 1 (Azul/Blue): 23 stations, 2020–2026 (METRO SP portal).
#'   \item Line 2 (Verde/Green): 14 stations, 2020–2026 (METRO SP portal).
#'   \item Line 3 (Vermelha/Red): 18 stations, 2020–2026 (METRO SP portal).
#'   \item Line 4 (Amarela/Yellow): January 2012–2026 (Insper Dataverse);
#'     \code{station_code} is \code{NA}.
#'   \item Line 5 (Lilás/Lilac): August 2018–2026 (Insper Dataverse);
#'     \code{station_code} is \code{NA}.
#'   \item Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
#'     (Jardim Colonial added), 2020–2026 (METRO SP portal).
#' }
#'
#' Some stations appear on multiple lines (e.g., Ana Rosa on Lines 1 and 2,
#' Paraíso on Lines 1 and 2, Sé on Lines 1 and 3). These are recorded
#' separately for each line.
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{station_averages}} for monthly weekday averages,
#'   \code{\link{passengers_entrance}} for monthly line-level totals.
"station_daily"

#' Metro and Train Line Routes
#'
#' Spatial line geometries for São Paulo metro (METRO SP) and commuter train
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
#' Requires the \pkg{sf} package to work with spatial features. The
#' distinction between types follows GeoSampa's classification. Broadly,
#' \code{"metro"} lines run underground as a subway and \code{"train"} lines
#' run above ground as commuter rail, though exceptions exist.
#'
#' @source GeoSampa, Prefeitura de São Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{stations}} for station point locations.
"lines"

#' Metro and Train Station Locations
#'
#' Spatial point locations for São Paulo metro (METRO SP) and commuter train
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
#' Requires the \pkg{sf} package to work with spatial features. The
#' distinction between types follows GeoSampa's classification. Broadly,
#' \code{"metro"} lines run underground as a subway and \code{"train"} lines
#' run above ground as commuter rail, though exceptions exist.
#'
#' @source GeoSampa, Prefeitura de São Paulo.
#'   \url{https://geosampa.prefeitura.sp.gov.br/}
#'
#' @seealso \code{\link{lines}} for line route geometries,
#'   \code{\link{station_averages}} for passenger data by station.
"stations"

#' Metro SP Line Reference Table
#'
#' A reference tibble mapping metro line numbers to their Portuguese and
#' English color names. Covers all METRO SP and ViaMobilidade lines,
#' including planned future lines and the network total.
#'
#' @format A tibble with 13 rows and 3 columns:
#' \describe{
#'   \item{line_number}{Official line number (integer). Includes 1, 2, 3, 4,
#'     5, 6, 15, 16, 17, 19, 20, 22, and 99 (network total).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{line_name}{English color name of the line (character).}
#' }
#'
#' @details
#' Serves as a dimension/lookup table for joining line names onto passenger
#' and station datasets. Not all lines have passenger data — Lines 6, 16,
#' 17, 19, 20, and 22 are planned future lines with spatial geometry
#' available in \code{\link{lines}} but no ridership records.
#'
#' @seealso \code{\link{metro_colors}} for official hex color codes,
#'   \code{\link{lines}} for spatial line geometries.
"metro_lines"

#' Six-Month Demand Forecasts by Line and Model
#'
#' Pre-computed 6-month-ahead forecasts of total monthly passenger entries
#' for each of the six METRO SP lines, fit with three model families
#' (`auto.arima`, `ets`, robust `stlf`). All models use Box-Cox variance
#' stabilization with `lambda = "auto"`, which both compresses the COVID-era
#' shock and guarantees non-negative forecast intervals.
#'
#' @format A data frame with one row per (line, model, forecast date):
#' \describe{
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{model}{Model identifier (character). One of:
#'     \code{"arima"} (Box-Cox `auto.arima` with seasonal search),
#'     \code{"ets"} (Box-Cox state-space exponential smoothing),
#'     \code{"stlf"} (robust STL decomposition + ETS on the seasonally
#'     adjusted remainder).}
#'   \item{date}{First day of the forecast month (Date). Six rows per
#'     (line, model), starting one month after the last observed value.}
#'   \item{mean}{Point forecast — back-transformed and bias-adjusted (numeric).}
#'   \item{lo80, hi80}{80% prediction interval (numeric).}
#'   \item{lo95, hi95}{95% prediction interval (numeric).}
#' }
#'
#' @details
#' Forecasts are built by `data-raw/build_forecasts.R` from
#' \code{\link{passengers_entrance}} (`metric_abb == "total"`) and refreshed
#' whenever the underlying data is updated. The build script also produces
#' \code{\link{forecast_accuracy}}, which reports out-of-sample error for
#' each (line, model) so the consumer can pick a preferred model per line.
#'
#' Modelling choices:
#' \itemize{
#'   \item All three models use \code{lambda = "auto"} (Guerrero estimate)
#'     and \code{biasadj = TRUE}, so point forecasts are means rather than
#'     medians on the original scale.
#'   \item `stlf` uses `robust = TRUE`, which down-weights the 2020–2021
#'     COVID period during seasonal extraction without requiring an explicit
#'     intervention dummy.
#' }
#'
#' @seealso \code{\link{forecast_accuracy}} for cross-validated error metrics,
#'   \code{\link{passengers_entrance}} for the underlying historical series.
"forecasts"

#' Cross-Validated Accuracy of Forecast Models by Line
#'
#' Out-of-sample error metrics for the three model families shipped in
#' \code{\link{forecasts}}, computed by rolling-origin cross-validation
#' (`forecast::tsCV`) over the most recent 12 months of each series with a
#' 6-month horizon.
#'
#' @format A data frame with one row per (line, model):
#' \describe{
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{model}{Model identifier (character). One of \code{"arima"},
#'     \code{"ets"}, \code{"stlf"} — see \code{\link{forecasts}}.}
#'   \item{mape}{Mean absolute percentage error across all rolling-origin
#'     forecasts and horizons (numeric, in percent).}
#'   \item{rmse}{Root mean squared error on the original scale (numeric).}
#'   \item{mae}{Mean absolute error on the original scale (numeric).}
#'   \item{best}{`TRUE` for the model with the lowest MAPE on the line
#'     (logical).}
#' }
#'
#' @details
#' Rows are sorted by `line_number`, then `mape` ascending, so the first row
#' for each line is the cross-validation winner. The accuracy reported here
#' is meant to guide model selection in the dashboard; it is not a guarantee
#' of future forecast accuracy.
#'
#' For speed, ARIMA fits inside the CV loop use
#' `approximation = TRUE`, while the final fit stored in
#' \code{\link{forecasts}} uses `approximation = FALSE` for the best
#' attainable model.
#'
#' @seealso \code{\link{forecasts}} for the point forecasts and intervals.
"forecast_accuracy"

#' Metro SP Official Line Colors
#'
#' A named character vector of official hex color codes for the six metro
#' lines operated by METRO SP (Lines 1–3 and 15) and ViaMobilidade
#' (Lines 4 and 5).
#'
#' @format A named character vector of length 6. Names are English color
#'   names; values are hex color codes:
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
#' Colors follow official METRO SP and ViaMobilidade branding. Only the six
#' currently operating metro lines are included; CPTM train lines and planned
#' future lines (e.g., Line 6 Orange, Line 17 Gold) are not covered.
#'
#' @seealso \code{\link{metro_lines}} for the full line reference table.
"metro_colors"

#' Station Commercial Opening Dates
#'
#' Inauguration (commercial opening) dates for São Paulo metro stations,
#' covering stations whose opening falls within or near the
#' \code{\link{station_daily}} / \code{\link{station_averages}} window. Used
#' to flag ramp-up periods in which monthly ridership is still climbing
#' toward steady-state and should generally be excluded from year-on-year or
#' baseline comparisons.
#'
#' @format A data frame with one row per (line, station):
#' \describe{
#'   \item{line_number}{Metro line number (integer).}
#'   \item{station_name}{Full station name (character).}
#'   \item{inauguration_date}{Date of commercial opening (Date). \code{NA}
#'     for stations whose opening predates the dataset window (i.e., they
#'     were already operating when the data record begins).}
#'   \item{phase}{Short label identifying the expansion phase, e.g.
#'     \code{"L15 Fase 4"} (character).}
#'   \item{verified}{Whether the inauguration date has been cross-checked
#'     against the operator's announcement or an equivalently reliable
#'     source (logical). Stations with \code{verified = FALSE} carry
#'     best-effort dates and should not be relied on for legal or
#'     publication purposes without re-checking.}
#'   \item{notes}{Free-text annotations about the source or any caveats
#'     (character, possibly \code{NA}).}
#'   \item{pre_data_window}{\code{TRUE} when \code{inauguration_date} is
#'     \code{NA} because the station opened before the data starts
#'     (logical).}
#'   \item{ramp_up_end}{\code{inauguration_date + 180} days — a heuristic
#'     end of the initial ramp-up period (Date). \code{NA} when
#'     \code{pre_data_window} is \code{TRUE}.}
#' }
#'
#' @details
#' The table is assembled by \code{data-raw/build_station_inauguration.R}
#' from \code{data-raw/station_inauguration.csv}. To extend the table or
#' verify uncertain dates, edit the CSV (setting \code{verified = TRUE}
#' once cross-checked) and re-run the build script.
#'
#' Suggested use: when computing pre/post comparisons (e.g.\ 12m-vs-prior-12m
#' or recovery-vs-2019), exclude stations where either window overlaps
#' \code{ramp_up_end} to avoid mistaking ramp-up growth for organic demand
#' change.
#'
#' @source Compiled from operator announcements (Companhia do Metropolitano
#'   de São Paulo, ViaQuatro, ViaMobilidade).
#'
#' @seealso \code{\link{stations}} for spatial point locations,
#'   \code{\link{station_averages}} for monthly weekday averages.
"station_inauguration"
