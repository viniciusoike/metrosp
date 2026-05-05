# Passengers Transported by Metro SP Line

Monthly count of passengers transported by São Paulo metro, aggregated
by metro line. Data covers October 2017 through 2026 for Lines 1, 2, 3,
and 15, and October 2017 through December 2019 for Line 5. Sourced from
the METRO SP transparency portal.

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

All data comes from the METRO SP transparency portal. Line 4 (Amarela)
is not available in this dataset — the Insper Dataverse source does not
include transported counts for Lines 4 or 5. Line 5 (Lilás) is available
from the METRO portal only for October 2017–December 2019. The network
total (`line_number = 99`) may not be available for all years.

Metrics:

- `total`: Total passengers in the month.

- `mdu`: Average daily entries on business days (Média dos Dias Úteis).

- `msa`: Average daily entries on Saturdays (Média dos Sábados).

- `mdo`: Average daily entries on Sundays (Média dos Domingos).

- `max`: Daily maximum (Máxima Diária).

## See also

[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
for entry counts,
[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for station-level weekday averages.
