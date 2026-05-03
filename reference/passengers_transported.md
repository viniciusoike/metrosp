# Passengers Transported by Metro SP Line

Monthly count of passengers transported by Sao Paulo metro, aggregated
by metro line. Data covers October 2017 through 2025, sourced from the
METRO SP transparency portal.

## Usage

``` r
passengers_transported
```

## Format

A data frame with the following columns:

- date:

  First day of the month (Date).

- line_number:

  Metro line number: 1, 2, 3, 5, 15, or 99 for network total (integer).

- metric_abb:

  Abbreviated metric code (character).

- value:

  Passenger count in thousands (numeric).

- metric:

  Measurement type in Portuguese (character).

- line_name:

  English name of the metro line (character).

- line_name_pt:

  Portuguese name of the metro line (character).

- year:

  Calendar year (integer).

## Source

Companhia do Metropolitano de Sao Paulo (METRO).
<https://transparencia.metrosp.com.br/dataset/demanda>

## Details

Lines 1, 2, 3, and 15 come from the METRO transparency portal
(2017-2025). Line 5 (Lilas) is available October 2017 - December 2019
only. Line 4 (Amarela) is not available in this dataset (the Dataverse
source does not include transported data for Lines 4/5). The network
total (line_number = 99) may not be available for all years.

Values represent thousands of passengers (e.g., a value of 900 means
900,000 passengers).

Metrics:

- `total`: Total passengers in the month

- `mdu`: Average on business days (Media dos Dias Uteis)

- `msa`: Average on Saturdays (Media dos Sabados)

- `mdo`: Average on Sundays (Media dos Domingos)

- `max`: Daily maximum (Maxima Diaria)
