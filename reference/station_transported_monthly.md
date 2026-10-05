# Average Weekday Passengers Transported by Station

Monthly average of weekday (business day) passengers transported for
each station in the São Paulo metro system. This is METRO's transported
measure — *Demanda de Passageiros por Estação*: boardings on that line
plus transfers from the other lines — not turnstile entries. Summed over
a line's stations it usually comes within 2\\ `mdu` in
[`line_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md).
Line 15 station values are rounded to the thousand, and a few source
months differ by more, notably Line 1 from February to June 2016. Data
covers January 2016 through 2026 for Lines 1, 2, 3, and 15; Line 4 from
January 2012; Line 5 from January 2016 through July 2018. Sourced from
the METRO SP transparency portal and the Insper Dataverse.

## Usage

``` r
station_transported_monthly
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- year:

  Calendar year (integer).

- line_number:

  Metro line number (integer).

- station_id:

  Stable identifier for the physical station complex (character). Treat
  as opaque. An interchange complex keeps one id across the lines that
  serve it while each line keeps its own official `station_name`.
  Grouping by `station_id` on this table gives boardings across the
  complex's platforms, not people entering it.

- station_name:

  Name of the metro station (character).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- metric:

  Metric code: `"mdu"` (character).

- metric_name:

  Metric name in English (character).

- metric_name_pt:

  Metric name in Portuguese (character).

- value:

  Average weekday passengers transported (numeric).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Only the weekday average (mdu) metric is available at the station level.
For line-level data with all five metrics, see
[`line_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md).
Months beyond the last published data point for each line are trimmed
during assembly; interior `NA`s (e.g. operational outages) are
preserved.

Station coverage by line and source:

- Line 1 (Azul/Blue): 23 stations, January 2016–2026 (METRO SP portal).

- Line 2 (Verde/Green): 14 stations, January 2016–2026 (METRO SP
  portal).

- Line 3 (Vermelha/Red): 18 stations, January 2016–2026 (METRO SP
  portal).

- Line 4 (Amarela/Yellow): January 2012–2026 (Insper Dataverse,
  `Bloqueio` plus `Integracao`).

- Line 5 (Lilás/Lilac): January 2016–July 2018 (METRO SP portal). From
  August 2018 the Dataverse feed records turnstiles only, so those rows
  are dropped here; station data for that era lives in
  [`station_entries_daily`](https://viniciusoike.github.io/metrosp/reference/station_entries_daily.md).

- Line 15 (Prata/Silver): 2 stations in 2016–2017 (assisted operation:
  Vila Prudente and Oratório), 10 stations in 2020, 11 from January 2021
  onward (Jardim Colonial added), January 2016–2026 (METRO SP portal).

METRO published January–September 2017 only as PDFs, with no
machine-readable equivalent. Those months were transcribed from the
reports and reconciled against the published line totals.

February–June 2016 carries a defect in the Line 1 values. Across those
five months the station sum runs about 14% below the transported `mdu`
in
[`line_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md),
and the figures are misallocated across stations, with Santa Cruz and Sé
too high and São Bento and Portuguesa-Tietê too low. The defect comes
from METRO's retroactive publication of 2016 and is not corrected here,
so exclude those five months from station-level baselines.

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

[`station_entries_daily`](https://viniciusoike.github.io/metrosp/reference/station_entries_daily.md)
for daily station entries,
[`line_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md)
for monthly line-level totals.
