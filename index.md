# metrosp: metro ridership in São Paulo

This package distributes demand data from the São Paulo metro system
inside R. The data covers 2012 to 2026 and comes from several operators.
Most of it is already
[public](https://transparencia.metrosp.com.br/dataset/demanda), but it
is scattered across poorly structured CSV and PDF files.

METRÔ publishes lines 1, 2, 3, 15, and line 5 through July 2018 on its
open data portal. Line 4, and line 5 from August 2018 onward, come from
the Insper Dataverse.

All datasets are `tibble` objects bundled with the package, so they load
without a download. The data is cleaned and standardized to make it
easier to work with.

## Line coverage

The package covers every metro line in São Paulo. Commuter train (CPTM)
demand is not included, though train lines and stations do appear in the
spatial datasets.

| Line | Name             | Operator              | Coverage            |
|-----:|------------------|-----------------------|---------------------|
|    1 | Azul (Blue)      | METRÔ                 | Jan 2016 – Jul 2026 |
|    2 | Verde (Green)    | METRÔ                 | Jan 2016 – Jul 2026 |
|    3 | Vermelha (Red)   | METRÔ                 | Jan 2016 – Jul 2026 |
|    4 | Amarela (Yellow) | ViaQuatro             | Jan 2012 – Mar 2026 |
|    5 | Lilás (Lilac)    | METRÔ / ViaMobilidade | Jan 2016 – Apr 2026 |
|   15 | Prata (Silver)   | METRÔ                 | Jan 2016 – Jul 2026 |

Coverage refers to `passengers_entrance`, which is missing July 2017 for
every METRO-sourced line. The other datasets start later for some lines.
The data dictionary vignette gives the coverage window of every dataset
by line.

## Installation

Currently, the best option is to install the package from R-Universe
which is more up to date.

``` r

install.packages('metrosp', repos = c('https://viniciusoike.r-universe.dev', 'https://cloud.r-project.org'))
```

The package is also available on CRAN.

``` r

install.packages("metrosp")
```

## Datasets

Four datasets carry the demand data: `passengers_entrance`,
`passengers_transported`, `station_averages`, and `station_daily`. The
rest are auxiliary tables that support analysis and visualization.

| Dataset | Description | Frequency | Spatial |
|----|----|----|----|
| `passengers_entrance` | Monthly passenger entries by line and day-type metric | Monthly | No |
| `passengers_transported` | Monthly passengers transported by line, in thousands | Monthly | No |
| `station_averages` | Average weekday passenger entries by station | Monthly | No |
| `station_daily` | Daily passenger entries by station | Daily | No |
| `station_inauguration` | Station opening dates and ramp-up window flag | — | No |
| `calendar_spo` | São Paulo holiday and business-day calendar | Daily | No |
| `metro_colors` | Named vector of official metro line colors | — | No |
| `lines` | Metro and train line routes (current + planned) | — | Yes |
| `stations` | Metro and train station locations (current + planned) | — | Yes |

`passengers_entrance` and the two station datasets count individual
passengers. `passengers_transported` reports thousands of passengers, as
the METRÔ source does. For more details on the data, see the [data
dictionary](https://viniciusoike.github.io/metrosp/articles/data-dictionary.html).

## Data vintage

The bundled data is a fixed snapshot, current through July 2026. It is
regenerated when the column schema changes, not when new months are
published, so examples and analyses stay reproducible across package
versions. METRÔ publishes on an irregular schedule and revises past
years, so these numbers drift from the source over time. Freshly rebuilt
data is published on every pipeline run to the [`data-latest`
release](https://github.com/viniciusoike/metrosp/releases).

## Usage

The data is bundled with the package, meaning it works out of the box
and doesn’t rely on internet connection. To use a dataset simply call
its name.

``` r

library(metrosp)
# To work with spatial datasets (lines, stations)
library(sf)
# For better tables load dplyr or tibble
library(dplyr)

# Passenger entries by line
passengers_entrance

# Station-level weekday averages
station_averages

# Spatial line routes
lines
```

## Explorer dashboard

An interactive dashboard for browsing and downloading these datasets
lives in a separate repository:
[metrosp-explorer](https://viniciusoike-metrosp-explorer.share.connect.posit.cloud).

## Data sources

- METRÔ: [Companhia do Metropolitano de São Paulo
  (METRO)](https://transparencia.metrosp.com.br/dataset/demanda).
- Lines 4/5 data: [Insper
  Dataverse](https://doi.org/10.60873/FK2/UTGQ0I) (ViaQuatro /
  ViaMobilidade).
- Spatial data: [GeoSampa, Prefeitura de São
  Paulo](https://geosampa.prefeitura.sp.gov.br/).

## Next steps

This package is still in development. While the datasets are stable and
checked on every new release, there may still be errors. If you find
any, please [open an
issue](https://github.com/viniciusoike/metrosp/issues/new).
