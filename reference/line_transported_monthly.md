# Passengers Transported by Metro SP Line

Monthly count of passengers transported by São Paulo metro, aggregated
by metro line. Data covers January 2016 through 2026 for Lines 1, 2, 3,
and 15; January 2016 through August 2018 for Line 5; and January 2012
through 2026 for Line 4. Sourced from the METRO SP transparency portal
and the Insper Dataverse.

## Usage

``` r
line_transported_monthly
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

  Passengers transported (numeric).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

A transported passenger is one who boarded a train on that line, whether
through a turnstile or by transferring from another line at an
interchange station. METRO's term is *passageiros transportados*:
turnstile entries plus transfers between lines. Transported counts
therefore run above entry counts for the same line and month. Do not sum
this dataset to estimate unique network passengers: a journey using
multiple lines is counted once on each line. See the Metro Demand Data
article for details:
<https://viniciusoike.github.io/metrosp/articles/metro-demand-data.html>.

Line 4 (Amarela/ViaQuatro) comes from the Insper Dataverse, January
2012–2026, all five metrics, summing both `Bloqueio` (turnstile) and
`Integracao` (transfer) boarding types. Line 5 (Lilás) is available from
the METRO portal only for January 2016–August 2018: the line was handed
over to ViaMobilidade in August 2018 and the portal stopped reporting
its transported counts afterwards. The Dataverse feed for Line 5 records
turnstiles only, so no transported measure exists for it after the
handover. August 2018 covers only the days before the handover: its
`total` is a partial month, and `msa` and `mdo` are `NA`.

METRO SP publishes these counts in thousands of passengers. They are
multiplied by 1000 here, so `value` counts individual passengers like
every other demand dataset and carries METRO's rounding to the thousand.
Line 4 comes from the Dataverse in individual passengers.

METRO published January–September 2017 only as PDFs, with no
machine-readable equivalent. Those months were transcribed from the
reports and reconciled against the published totals.

Metrics:

- `total`: Total passengers in the month.

- `mdu`: Average daily transported passengers on business days (Média
  dos Dias Úteis).

- `msa`: Average daily transported passengers on Saturdays (Média dos
  Sábados).

- `mdo`: Average daily transported passengers on Sundays (Média dos
  Domingos).

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

[`line_entries_monthly`](https://viniciusoike.github.io/metrosp/reference/line_entries_monthly.md)
for entry counts,
[`station_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/station_transported_monthly.md)
for station-level weekday averages.
