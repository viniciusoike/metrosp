# Passengers Transported by Metro SP Line

Monthly count of passengers transported by São Paulo metro, aggregated
by metro line and reported in **thousands of passengers**. Data covers
January 2016 through 2026 for Lines 1, 2, 3, and 15, and January 2016
through August 2018 for Line 5. Sourced from the METRO SP transparency
portal.

## Usage

``` r
passengers_transported
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- line_number:

  Metro line number: 1, 2, 3, 5, 15, or 99 for the network total
  (integer).

- metric_abb:

  Abbreviated metric code (character). One of: `"total"`, `"mdu"`,
  `"msa"`, `"mdo"`, `"max"`.

- value:

  Passenger count, in thousands of passengers (numeric).

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

Values are in thousands of passengers, as published by METRO SP. The
other demand datasets count individual passengers, so multiply by 1000
before comparing `value` with
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md).

A transported passenger is one who crossed a turnstile plus one who
transferred between lines at an interchange station, so transported
counts run above entry counts for the same line and month.

All data comes from the METRO SP transparency portal. Line 4 (Amarela)
is not available in this dataset — the Insper Dataverse source does not
include transported counts for Lines 4 or 5. Line 5 (Lilás) is available
from the METRO portal only for January 2016–August 2018: the line was
handed over to ViaMobilidade in August 2018 and the portal stopped
reporting its transported counts afterwards. The network total
(`line_number = 99`) may not be available for all years.

METRO published January–September 2017 only as PDFs, with no
machine-readable equivalent. Those months were transcribed from the
reports and reconciled against the printed line and network totals. June
2017 is the one month whose network total is missing, because the report
reprinted May's network column; the per-line values for June are sound.

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
have data to hand. The snapshot moves only when the column schema
changes or a release deliberately carries new data, not when new months
are published upstream.

METRO SP publishes on an irregular schedule and revises
already-published years, so the numbers here will drift from the source
over time. Freshly rebuilt data is published on every pipeline run at
<https://github.com/viniciusoike/metrosp/releases>.

## See also

[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
for entry counts,
[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for station-level weekday averages.
