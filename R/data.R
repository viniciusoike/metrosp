#' Passengers Entering Metro SP Stations by Line
#'
#' Monthly count of passengers entering São Paulo metro stations, aggregated
#' by metro line. Data covers January 2016 through 2026 for Lines 1, 2, 3,
#' and 15; Line 4 from January 2012; Line 5 from January 2016. July 2017 is
#' the one missing month, absent for every line the METRO portal covers.
#' Sourced from the METRO SP transparency portal and the Insper Dataverse.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{metric}{Metric code (character). One of:
#'     \code{"total"}, \code{"mdu"}, \code{"msa"}, \code{"mdo"},
#'     \code{"max"}.}
#'   \item{metric_name}{Measurement type in English (character). One of:
#'     \code{"Total"}, \code{"Average on Business Days"},
#'     \code{"Average on Saturdays"}, \code{"Average on Sundays"},
#'     \code{"Daily Peak"}.}
#'   \item{metric_name_pt}{Measurement type in Portuguese (character). One of:
#'     \code{"Total"}, \code{"Média dos Dias Úteis"},
#'     \code{"Média dos Sábados"}, \code{"Média dos Domingos"},
#'     \code{"Máxima Diária"}.}
#'   \item{value}{Passenger count, in individual passengers (numeric).}
#' }
#'
#' @details
#' Data by source and line:
#' \itemize{
#'   \item Lines 1, 2, 3, and 15: METRO SP transparency portal,
#'     January 2016–2026, except July 2017.
#'   \item Line 4 (Amarela/ViaQuatro): Insper Dataverse,
#'     January 2012–2026.
#'   \item Line 5 (Lilás/ViaMobilidade): METRO SP transparency portal,
#'     January 2016–July 2018, except July 2017; Insper Dataverse,
#'     August 2018–2026.
#' }
#'
#' METRO published January–September 2017 only as PDFs, with no
#' machine-readable equivalent. Those months were transcribed from the
#' reports and reconciled against the published totals. July
#' 2017 has no entrance table at all, because the file METRO published under
#' that name repeats the transported figures. Lines 1, 2, 3, 5, and 15
#' therefore carry no value for that month; Line 4 comes from the Dataverse
#' and is unaffected.
#'
#' Summing across lines does not give a clean network total. METRO line entries
#' include transfers arriving from Lines 4 and 5, while Lines 4 and 5 count
#' turnstiles only, so a Line 4 → Line 1 journey counts twice. Do not sum
#' `max`: individual lines may peak on different days. See the Metro Demand
#' Data article for details:
#' \url{https://viniciusoike.github.io/metrosp/articles/metro-demand-data.html}.
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
#' Months beyond the last published data point for each line are trimmed
#' during assembly; interior \code{NA}s (e.g. operational outages) are
#' preserved.
#'
#' @section Data vintage:
#' This dataset is a fixed snapshot, current through July 2026. It ships with
#' the package so examples, vignettes, and offline analysis always have data
#' to hand. The snapshot moves only when the column schema changes or a
#' release deliberately carries new data, not when new months are published
#' upstream.
#'
#' METRO SP publishes on an irregular schedule and revises already-published
#' years, so the numbers here will drift from the source over time. Freshly
#' rebuilt data is published on every pipeline run at
#' \url{https://github.com/viniciusoike/metrosp/releases}.
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{line_transported_monthly}} for transported counts,
#'   \code{\link{station_transported_monthly}} for station-level weekday averages.
"line_entries_monthly"

#' Passengers Transported by Metro SP Line
#'
#' Monthly count of passengers transported by São Paulo metro, aggregated
#' by metro line. Data covers January 2016 through 2026 for Lines 1, 2, 3,
#' and 15; January 2016 through August 2018 for Line 5; and January 2012
#' through 2026 for Line 4. Sourced from the METRO SP transparency portal
#' and the Insper Dataverse.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{metric}{Metric code (character). One of:
#'     \code{"total"}, \code{"mdu"}, \code{"msa"}, \code{"mdo"},
#'     \code{"max"}.}
#'   \item{metric_name}{Measurement type in English (character). One of:
#'     \code{"Total"}, \code{"Average on Business Days"},
#'     \code{"Average on Saturdays"}, \code{"Average on Sundays"},
#'     \code{"Daily Peak"}.}
#'   \item{metric_name_pt}{Measurement type in Portuguese (character). One of:
#'     \code{"Total"}, \code{"Média dos Dias Úteis"},
#'     \code{"Média dos Sábados"}, \code{"Média dos Domingos"},
#'     \code{"Máxima Diária"}.}
#'   \item{value}{Passengers transported (numeric).}
#' }
#'
#' @details
#' A transported passenger is one who boarded a train on that line, whether
#' through a turnstile or by transferring from another line at an interchange
#' station. METRO's term is \emph{passageiros transportados}: turnstile
#' entries plus transfers between lines. Transported counts therefore run
#' above entry counts for the same line and month. Do not sum this dataset
#' to estimate unique network passengers: a journey using multiple lines is
#' counted once on each line. See the Metro Demand Data article for details:
#' \url{https://viniciusoike.github.io/metrosp/articles/metro-demand-data.html}.
#'
#' Line 4 (Amarela/ViaQuatro) comes from the Insper Dataverse, January
#' 2012–2026, all five metrics, summing both \code{Bloqueio} (turnstile) and
#' \code{Integracao} (transfer) boarding types. Line 5 (Lilás) is available
#' from the METRO portal only for January 2016–August 2018: the line was
#' handed over to ViaMobilidade in August 2018 and the portal stopped
#' reporting its transported counts afterwards. The Dataverse feed for Line 5
#' records turnstiles only, so no transported measure exists for it after the
#' handover. August 2018 covers only the days before the handover: its
#' \code{total} is a partial month, and \code{msa} and \code{mdo} are
#' \code{NA}.
#'
#' METRO SP publishes these counts in thousands of passengers. They are
#' multiplied by 1000 here, so \code{value} counts individual passengers like
#' every other demand dataset and carries METRO's rounding to the thousand.
#' Line 4 comes from the Dataverse in individual passengers.
#'
#' METRO published January–September 2017 only as PDFs, with no
#' machine-readable equivalent. Those months were transcribed from the
#' reports and reconciled against the published totals.
#'
#' Metrics:
#' \itemize{
#'   \item \code{total}: Total passengers in the month.
#'   \item \code{mdu}: Average daily transported passengers on business days
#'     (Média dos Dias Úteis).
#'   \item \code{msa}: Average daily transported passengers on Saturdays
#'     (Média dos Sábados).
#'   \item \code{mdo}: Average daily transported passengers on Sundays
#'     (Média dos Domingos).
#'   \item \code{max}: Daily maximum (Máxima Diária).
#' }
#'
#' Months beyond the last published data point for each line are trimmed
#' during assembly; interior \code{NA}s (e.g. operational outages) are
#' preserved.
#'
#' @inheritSection line_entries_monthly Data vintage
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{line_entries_monthly}} for entry counts,
#'   \code{\link{station_transported_monthly}} for station-level weekday averages.
"line_transported_monthly"

#' Average Weekday Passengers Transported by Station
#'
#' Monthly average of weekday (business day) passengers transported for each
#' station in the São Paulo metro system. This is METRO's transported
#' measure — \emph{Demanda de Passageiros por Estação}: boardings on that
#' line plus transfers from the other lines — not turnstile entries. Summed
#' over a line's stations it usually comes within 2\% of the line's
#' \code{mdu} in \code{\link{line_transported_monthly}}. Line 15 station
#' values are rounded to the thousand, and a few source months differ by
#' more, notably Line 1 from February to June 2016. Data covers January 2016 through
#' 2026 for Lines 1, 2, 3, and 15; Line 4 from January 2012; Line 5 from
#' January 2016 through July 2018. Sourced from the METRO SP transparency
#' portal and the Insper Dataverse.
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{First day of the month (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number (integer).}
#'   \item{station_id}{Stable identifier for the physical station complex
#'     (character). Treat as opaque. An interchange complex keeps one id
#'     across the lines that serve it while each line keeps its own official
#'     \code{station_name}. Grouping by \code{station_id} on this table gives
#'     boardings across the complex's platforms, not people entering it.}
#'   \item{station_name}{Name of the metro station (character).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{metric}{Metric code: \code{"mdu"} (character).}
#'   \item{metric_name}{Metric name in English (character).}
#'   \item{metric_name_pt}{Metric name in Portuguese (character).}
#'   \item{value}{Average weekday passengers transported (numeric).}
#' }
#'
#' @details
#' Only the weekday average (mdu) metric is available at the station level.
#' For line-level data with all five metrics, see
#' \code{\link{line_transported_monthly}}. Months beyond the last published data
#' point for each line are trimmed during assembly; interior \code{NA}s
#' (e.g. operational outages) are preserved.
#'
#' Station coverage by line and source:
#' \itemize{
#'   \item Line 1 (Azul/Blue): 23 stations, January 2016–2026 (METRO SP
#'     portal).
#'   \item Line 2 (Verde/Green): 14 stations, January 2016–2026 (METRO SP
#'     portal).
#'   \item Line 3 (Vermelha/Red): 18 stations, January 2016–2026 (METRO SP
#'     portal).
#'   \item Line 4 (Amarela/Yellow): January 2012–2026 (Insper Dataverse,
#'     \code{Bloqueio} plus \code{Integracao}).
#'   \item Line 5 (Lilás/Lilac): January 2016–July 2018 (METRO SP portal).
#'     From August 2018 the Dataverse feed records turnstiles only, so those
#'     rows are dropped here; station data for that era lives in
#'     \code{\link{station_entries_daily}}.
#'   \item Line 15 (Prata/Silver): 2 stations in 2016–2017 (assisted
#'     operation: Vila Prudente and Oratório), 10 stations in 2020, 11 from
#'     January 2021 onward (Jardim Colonial added), January 2016–2026
#'     (METRO SP portal).
#' }
#'
#' METRO published January–September 2017 only as PDFs, with no
#' machine-readable equivalent. Those months were transcribed from the
#' reports and reconciled against the published line totals.
#'
#' February–June 2016 carries a defect in the Line 1 values. Across those
#' five months the station sum runs about 14% below the transported
#' \code{mdu} in \code{\link{line_transported_monthly}}, and the figures are
#' misallocated across stations, with Santa Cruz and Sé too high and
#' São Bento and Portuguesa-Tietê too low. The defect comes from METRO's
#' retroactive publication of 2016 and is not corrected here, so exclude
#' those five months from station-level baselines.
#'
#' @inheritSection line_entries_monthly Data vintage
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{station_entries_daily}} for daily station entries,
#'   \code{\link{line_transported_monthly}} for monthly line-level totals.
"station_transported_monthly"

#' Daily Passenger Entries by Metro SP Station
#'
#' Daily passenger entries at each station in the São Paulo metro system.
#' Data covers January 2012 through 2026 for Line 4 and August 2018 through
#' 2026 for Line 5 (Insper Dataverse), and 2020 through 2026 for Lines 1, 2,
#' 3, and 15 (METRO SP transparency portal).
#'
#' @format A data frame with the following columns:
#' \describe{
#'   \item{date}{Date of observation (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{line_number}{Metro line number: 1, 2, 3, 4, 5, or 15 (integer).}
#'   \item{station_id}{Stable identifier for the physical station complex
#'     (character). Treat as opaque. An interchange complex keeps one id
#'     across the lines that serve it while each line keeps its own official
#'     \code{station_name}, so group by \code{station_id} alone to total a
#'     complex.}
#'   \item{station_name}{Full station name (character).}
#'   \item{station_code}{Three-letter station abbreviation used internally
#'     by METRO SP (character). \code{NA} for Lines 4 and 5 (Dataverse
#'     source).}
#'   \item{line_name}{English name of the metro line (character).}
#'   \item{line_name_pt}{Portuguese name of the metro line (character).}
#'   \item{value}{Daily passenger entries (numeric).}
#' }
#'
#' @details
#' This is an entries measure — METRO's \emph{Entrada de Passageiros por
#' Estação}: turnstile entries plus transfers arriving from other operators
#' (CPTM, Line 4, Line 5), excluding transfers between METRO lines. Monthly
#' station sums usually match the line's \code{total} in
#' \code{\link{line_entries_monthly}}; when they differ, the gap is a
#' fraction of a percent.
#'
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
#' Days beyond the last published data point for each line are trimmed
#' during assembly; interior \code{NA}s (e.g. operational outages) are
#' preserved.
#'
#' @inheritSection line_entries_monthly Data vintage
#'
#' @source Companhia do Metropolitano de São Paulo (METRO SP).
#'   \url{https://transparencia.metrosp.com.br/dataset/demanda}
#'
#' @seealso \code{\link{station_transported_monthly}} for monthly weekday averages,
#'   \code{\link{line_entries_monthly}} for monthly line-level totals.
"station_entries_daily"

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
#'   \item{line_name}{English color name of the line (character).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{company_name}{Operating company name (character).}
#'   \item{type}{Either \code{"metro"} (METRO SP) or \code{"train"} (CPTM)
#'     (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"future"}
#'     (planned expansion) (character).}
#'   \item{geom}{Line route geometry (sfc_LINESTRING).}
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
#' @seealso \code{\link{rail_stations}} for station point locations.
"rail_lines"

#' Metro and Train Station Locations
#'
#' Spatial point locations for São Paulo metro (METRO SP) and commuter train
#' (CPTM) stations, including both currently operating stations and planned
#' future stations.
#'
#' @format An sf data frame with POINT geometry (CRS: WGS84 / EPSG:4326)
#'   and the following columns:
#' \describe{
#'   \item{station_id}{Stable identifier for the physical station complex
#'     (character). Shared across lines and modes; treat as opaque.}
#'   \item{station_name}{Station name in title case (character).}
#'   \item{station_code}{Three-letter METRO abbreviation when available
#'     (character).}
#'   \item{line_number}{Line number the station belongs to (integer).}
#'   \item{line_name}{English color name of the line (character).}
#'   \item{line_name_pt}{Portuguese color name of the line (character).}
#'   \item{company_name}{Operating company name (character).}
#'   \item{type}{Either \code{"metro"} (METRO SP) or \code{"train"} (CPTM)
#'     (character).}
#'   \item{status}{Either \code{"current"} (operating) or \code{"future"}
#'     (planned expansion) (character).}
#'   \item{geom}{Station location (sfc_POINT).}
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
#' @seealso \code{\link{rail_lines}} for line route geometries,
#'   \code{\link{station_transported_monthly}} for passenger data by station.
"rail_stations"

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
#' @seealso \code{\link{rail_lines}} for the full line reference (numbers, names,
#'   and route geometries).
"metro_colors"

#' São Paulo Holiday and Business-Day Calendar
#'
#' A daily calendar for São Paulo (city) covering 2012–2030, classifying each
#' date as a holiday or business day. Includes national, state, and municipal
#' holidays in São Paulo, with flags for optional work days
#' (\code{is_optional_holiday}) and extended holiday weekends
#' (\code{is_long_weekend}).
#'
#' @format A data frame with one row per day and the following columns:
#' \describe{
#'   \item{date}{Calendar date (Date).}
#'   \item{year}{Calendar year (integer).}
#'   \item{weekday}{Day of week from \code{lubridate::wday()}: 1 = Sunday,
#'     2 = Monday, \ldots, 7 = Saturday (integer).}
#'   \item{is_weekend}{\code{TRUE} for Saturdays and Sundays (logical).}
#'   \item{is_holiday}{\code{TRUE} when the date is a gazetted holiday
#'     at any scope (logical).}
#'   \item{is_business_day}{\code{TRUE} when the date is neither a weekend
#'     nor a holiday (logical).}
#'   \item{holiday_name}{Name of the holiday in Portuguese (character).
#'     \code{NA} on non-holiday dates.}
#'   \item{holiday_scope}{Scope of the holiday (character).
#'     One of \code{"national"}, \code{"state"}, or \code{"municipal"};
#'     \code{NA} on non-holiday dates.}
#'   \item{is_optional_holiday}{\code{TRUE} for holidays that are technically
#'     optional at the federal level (Carnaval, Corpus Christi) but observed
#'     as holidays in São Paulo (logical).}
#'   \item{is_long_weekend}{\code{TRUE} when a holiday falls on Monday, Tuesday,
#'     Thursday, or Friday, creating a potential extended weekend with the
#'     adjacent Saturday/Sunday (logical).}
#' }
#'
#' @details
#' The calendar covers the full date range of the
#' \code{\link{station_entries_daily}} dataset (Lines 4/5 from January 2012) and
#' extends through 2030 for forecasting use.
#'
#' @seealso \code{\link{station_entries_daily}} for daily passenger data that can be
#'   joined on \code{date}.
"calendar_spo"
