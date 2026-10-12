# Train Service by Metro SP Line

Monthly minimum interval between trains and commercial speed for the
lines METRO SP operates: Lines 1, 2, 3, and 15, from January 2021.
Sourced from the "oferta" (service supply) tables on the METRO SP
transparency portal.

## Usage

``` r
line_service_monthly
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- year:

  Calendar year (integer).

- line_number:

  Metro line number: 1, 2, 3, or 15 (integer).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- metric:

  Metric code (character). One of `"headway"` or `"speed"`.

- metric_name:

  Measurement type in English, with its unit (character). One of
  `"Minimum Interval Between Trains (seconds)"` or
  `"Commercial Speed (km/h)"`.

- metric_name_pt:

  Measurement type in Portuguese, with its unit (character). One of
  `"Intervalo Mínimo entre Trens (segundos)"` or
  `"Velocidade Comercial (km/h)"`.

- value:

  Seconds for `headway`, km/h for `speed` (numeric).

## Source

Companhia do Metropolitano de São Paulo (METRO SP).
<https://transparencia.metrosp.com.br/dataset/oferta>

## Details

Metrics:

- `headway`: Minimum interval between trains, in seconds (Intervalo
  mínimo entre trens).

- `speed`: Commercial speed, in km/h (Velocidade comercial).

METRO publishes these figures with their titles and units only; the
source gives no further definition. Speed is published as a whole
number.

Lines 4 and 5 are run by concessionaires and do not appear in METRO's
tables. METRO marks every month of 2021 and 2022 as affected by the
COVID-19 pandemic.

Months beyond the last published data point for each line are trimmed
during assembly.

## Data vintage

This dataset is a fixed snapshot, current through August 2026. Freshly
rebuilt data is published with the demand datasets and read with
[`read_metro_service()`](https://viniciusoike.github.io/metrosp/reference/read_metro_service.md).

## See also

[`line_transported_monthly`](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md)
for passengers transported by line.
