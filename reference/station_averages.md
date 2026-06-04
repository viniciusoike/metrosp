# Average Weekday Passenger Entries by Station

Monthly average of weekday (business day) passenger entries for each
station in the São Paulo metro system. Data covers October 2017 through
2026 for Lines 1, 2, 3, and 15; Line 4 from January 2012; Line 5 from
October 2017. Sourced from the METRO SP transparency portal and the
Insper Dataverse.

## Usage

``` r
station_averages
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- line_number:

  Metro line number (integer).

- station_name:

  Name of the metro station (character).

- avg_passenger:

  Average weekday passenger entries (numeric).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- year:

  Calendar year (integer).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Only the weekday average (mdu) metric is available at the station level.
For line-level data with all five metrics, see
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md).
Trailing months whose data has not yet been published by the source are
excluded (rows with `NA` values are dropped during assembly).

Station coverage by line and source:

- Line 1 (Azul/Blue): 23 stations, October 2017–2026 (METRO SP portal).

- Line 2 (Verde/Green): 14 stations, October 2017–2026 (METRO SP
  portal).

- Line 3 (Vermelha/Red): 18 stations, October 2017–2026 (METRO SP
  portal).

- Line 4 (Amarela/Yellow): January 2012–2026 (Insper Dataverse).

- Line 5 (Lilás/Lilac): October 2017–July 2018 (METRO SP portal) and
  August 2018–2026 (Insper Dataverse).

- Line 15 (Prata/Silver): 10 stations in 2020, 11 from January 2021
  onward (Jardim Colonial added), October 2017–2026 (METRO SP portal).

## See also

[`station_daily`](https://viniciusoike.github.io/metrosp/reference/station_daily.md)
for daily station entries,
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
for monthly line-level totals.
