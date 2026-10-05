# Daily Passenger Entries by Metro SP Station

Daily passenger entries at each station in the São Paulo metro system.
Data covers January 2012 through 2026 for Line 4 and August 2018 through
2026 for Line 5 (Insper Dataverse), and 2020 through 2026 for Lines 1,
2, 3, and 15 (METRO SP transparency portal).

## Usage

``` r
station_entries_daily
```

## Format

A data frame with the following columns:

- date:

  Date of observation (Date).

- year:

  Calendar year (integer).

- line_number:

  Metro line number: 1, 2, 3, 4, 5, or 15 (integer).

- station_id:

  Stable identifier for the physical station complex (character). Treat
  as opaque. An interchange complex keeps one id across the lines that
  serve it while each line keeps its own official `station_name`, so
  group by `station_id` alone to total a complex.

- station_name:

  Full station name (character).

- station_code:

  Three-letter station abbreviation used internally by METRO SP
  (character). `NA` for Lines 4 and 5 (Dataverse source).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- value:

  Daily passenger entries (numeric).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

This is an entries measure — METRO's *Entrada de Passageiros por
Estação*: turnstile entries plus transfers arriving from other operators
(CPTM, Line 4, Line 5), excluding transfers between METRO lines. Monthly
station sums usually match the line's `total` in
[`line_entries_monthly`](https://viniciusoike.github.io/metrosp/reference/line_entries_monthly.md);
when they differ, the gap is a fraction of a percent.

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
separately for each line.

Days beyond the last published data point for each line are trimmed
during assembly; interior `NA`s (e.g. operational outages) are
preserved.

## Data vintage

This dataset is a fixed snapshot, current through July 2026. It ships
with the package so examples, vignettes, and offline analysis always
have data to hand. The snapshot moves only when the column schema
changes or a release deliberately carries new data, not when new months
are published upstream.

METRO SP publishes on an irregular schedule and revises
already-published years, so the numbers here will drift from the source
over time. Freshly rebuilt data is published on every pipeline run at
<https://github.com/viniciusoike/metrosp/releases>.

## See also

[`station_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/station_transported_monthly.md)
for monthly weekday averages,
[`line_entries_monthly`](https://viniciusoike.github.io/metrosp/reference/line_entries_monthly.md)
for monthly line-level totals.
