# Daily Passenger Entries by Metro SP Station

Daily passenger entries at each station in the Sao Paulo metro system.
Data covers 2020 through 2025. Lines 1, 2, 3, and 15 come from the METRO
SP transparency portal; Lines 4 and 5 come from the Insper Dataverse
source.

## Usage

``` r
station_daily
```

## Format

A data frame with the following columns:

- date:

  Date of observation (Date).

- line_number:

  Metro line number: 1, 2, 3, 4, 5, or 15 (integer).

- station_name:

  Full station name (character).

- passengers:

  Daily passenger entries in thousands (numeric).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- station_code:

  Three-letter station abbreviation used internally by METRO
  (character). `NA` for Lines 4 and 5 (Dataverse source).

- year:

  Calendar year (integer).

## Source

Companhia do Metropolitano de Sao Paulo (METRO).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Values represent thousands of passengers (e.g., a value of 50 means
50,000 passengers entering the station that day).

Station coverage by line:

- Line 1 (Azul/Blue): 23 stations

- Line 2 (Verde/Green): 14 stations

- Line 3 (Vermelha/Red): 18 stations

- Line 4 (Amarela/Yellow): available 2020-2025 (Insper Dataverse);
  `station_code` is `NA`

- Line 5 (Lilas/Lilac): available 2020-2025 (Insper Dataverse);
  `station_code` is `NA`

- Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
  (Jardim Colonial added)

Some stations appear on multiple lines (e.g., Ana Rosa on Lines 1 and 2,
Paraiso on Lines 1 and 2, Se on Lines 1 and 3). These are recorded
separately for each line.

## See also

[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for monthly weekday averages,
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
for monthly line-level totals.
