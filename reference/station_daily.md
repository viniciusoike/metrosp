# Daily Passenger Entries by Metro SP Station

Daily passenger entries at each station in the São Paulo metro system.
Data covers January 2012 through 2026 for Lines 4 and 5 (Insper
Dataverse), and 2020 through 2026 for Lines 1, 2, 3, and 15 (METRO SP
transparency portal).

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

  Daily passenger entries (numeric).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- station_code:

  Three-letter station abbreviation used internally by METRO SP
  (character). `NA` for Lines 4 and 5 (Dataverse source).

- year:

  Calendar year (integer).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Station coverage and date range by line:

- Line 1 (Azul/Blue): 23 stations, 2020–2026 (METRO SP portal).

- Line 2 (Verde/Green): 14 stations, 2020–2026 (METRO SP portal).

- Line 3 (Vermelha/Red): 18 stations, 2020–2026 (METRO SP portal).

- Line 4 (Amarela/Yellow): January 2012–2026 (Insper Dataverse);
  `station_code` is `NA`.

- Line 5 (Lilás/Lilac): August 2018–2026 (Insper Dataverse);
  `station_code` is `NA`.

- Line 15 (Prata/Silver): 10 stations in 2020, 11 from 2021 onward
  (Jardim Colonial added), 2020–2026 (METRO SP portal).

Some stations appear on multiple lines (e.g., Ana Rosa on Lines 1 and 2,
Paraíso on Lines 1 and 2, Sé on Lines 1 and 3). These are recorded
separately for each line. Days beyond the last published data point for
each line are trimmed during assembly; interior `NA`s (e.g. operational
outages) are preserved.

## See also

[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for monthly weekday averages,
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
for monthly line-level totals.
