# Passengers Entering Metro SP Stations by Line

Monthly count of passengers entering São Paulo metro stations,
aggregated by metro line. Data covers October 2017 through 2026 for
Lines 1, 2, 3, and 15; Line 4 from January 2012; Line 5 from October
2017. Sourced from the METRO SP transparency portal and the Insper
Dataverse.

## Usage

``` r
passengers_entrance
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- line_number:

  Metro line number: 1, 2, 3, 4, 5, 15, or 99 for the network total
  (integer).

- metric_abb:

  Abbreviated metric code (character). One of: `"total"`, `"mdu"`,
  `"msa"`, `"mdo"`, `"max"`.

- value:

  Passenger count (numeric).

- metric:

  Measurement type in English (character). One of: `"Total"`,
  `"Average on Business Days"`, `"Average on Saturdays"`,
  `"Average on Sundays"`, `"Daily Peak"`.

- metric_pt:

  Measurement type in Portuguese (character). One of: `"Total"`,
  `"Média dos Dias Úteis"`, `"Média dos Sábados"`,
  `"Média dos Domingos"`, `"Máxima Diária"`.

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

Data by source and line:

- Lines 1, 2, 3, and 15: METRO SP transparency portal, October
  2017–2026.

- Line 4 (Amarela/ViaQuatro): Insper Dataverse, January 2012–2026.

- Line 5 (Lilás/ViaMobilidade): METRO SP transparency portal, October
  2017–July 2018; Insper Dataverse, August 2018–2026.

- Network total (`line_number = 99`): METRO SP transparency portal only;
  may not be available for all years.

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

This dataset is a fixed snapshot, current through June 2026. It ships
with the package so examples, vignettes, and offline analysis always
have data to hand, and it is regenerated only when the column schema
changes – not when new months are published upstream.

METRO SP publishes on an irregular schedule and revises
already-published years, so the numbers here will drift from the source
over time. Freshly rebuilt data is published on every pipeline run at
<https://github.com/viniciusoike/metrosp/releases>.

## See also

[`passengers_transported`](https://viniciusoike.github.io/metrosp/reference/passengers_transported.md)
for transported counts,
[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for station-level weekday averages.
