# Average Weekday Passenger Entries by Station

Monthly average of weekday (business day) passenger entries for each
station in the Sao Paulo metro system. Data covers October 2017 through
2025, sourced from the METRO SP transparency portal.

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

  Average weekday passenger entries in thousands (numeric).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- year:

  Calendar year (integer).

## Source

Companhia do Metropolitano de Sao Paulo (METRO).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Only the weekday average (mdu) metric is available at the station level.
For line-level data with all 5 metrics, see
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md).

Station coverage varies by line:

- Line 1 (Azul/Blue): 23 stations

- Line 2 (Verde/Green): 14 stations

- Line 3 (Vermelha/Red): 18 stations

- Line 4 (Amarela/Yellow): available 2020-2025 (Insper Dataverse source)

- Line 5 (Lilas/Lilac): October 2017 - December 2019 (METRO portal) and
  2020-2025 (Insper Dataverse source)

- Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
