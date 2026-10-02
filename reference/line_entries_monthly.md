# Passengers Entering Metro SP Stations by Line

Monthly count of passengers entering São Paulo metro stations,
aggregated by metro line. Data covers January 2016 through 2026 for
Lines 1, 2, 3, and 15; Line 4 from January 2012; Line 5 from January
2016. July 2017 is the one missing month, absent for every line the
METRO portal covers. Sourced from the METRO SP transparency portal and
the Insper Dataverse.

## Usage

``` r
line_entries_monthly
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- year:

  Calendar year (integer).

- line_number:

  Metro line number: 1, 2, 3, 4, 5, or 15 (integer).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- metric:

  Metric code (character). One of: `"total"`, `"mdu"`, `"msa"`, `"mdo"`,
  `"max"`.

- metric_name:

  Measurement type in English (character). One of: `"Total"`,
  `"Average on Business Days"`, `"Average on Saturdays"`,
  `"Average on Sundays"`, `"Daily Peak"`.

- metric_name_pt:

  Measurement type in Portuguese (character). One of: `"Total"`,
  `"Média dos Dias Úteis"`, `"Média dos Sábados"`,
  `"Média dos Domingos"`, `"Máxima Diária"`.

- value:

  Passenger count, in individual passengers (numeric).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Data by source and line:

- Lines 1, 2, 3, and 15: METRO SP transparency portal, January
  2016–2026, except July 2017.

- Line 4 (Amarela/ViaQuatro): Insper Dataverse, January 2012–2026.

- Line 5 (Lilás/ViaMobilidade): METRO SP transparency portal, January
  2016–July 2018, except July 2017; Insper Dataverse, August 2018–2026.

METRO published January–September 2017 only as PDFs, with no
machine-readable equivalent. Those months were transcribed from the
reports and reconciled against the published totals. July 2017 has no
entrance table at all, because the file METRO published under that name
repeats the transported figures. Lines 1, 2, 3, 5, and 15 therefore
carry no value for that month; Line 4 comes from the Dataverse and is
unaffected.

Summing across lines does not give a clean network total. METRO line
entries include transfers arriving from Lines 4 and 5, while Lines 4 and
5 count turnstiles only, so a Line 4 → Line 1 journey counts twice. Do
not sum `max`: individual lines may peak on different days. See the
Metro Demand Data article for details:
<https://viniciusoike.github.io/metrosp/articles/metro-demand-data.html>.

Metrics:

- `total`: Total passengers in the month.

- `mdu`: Average daily entries on business days (Média dos Dias Úteis).

- `msa`: Average daily entries on Saturdays (Média dos Sábados).

- `mdo`: Average daily entries on Sundays (Média dos Domingos).

- `max`: Daily maximum (Máxima Diária).

Months beyond the last published data point for each line are trimmed
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

[`line_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md)
for transported counts,
[`station_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/station_transported_monthly.md)
for station-level weekday averages.
