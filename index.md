# metrosp: metro ridership in São Paulo

This packages helps distribute demand data from the São Paulo metro
system inside R. Data is sourced from multiple operators and spans
2012-2025. While most of the data is already
[public](https://transparencia.metrosp.com.br/dataset/demanda), it’s
scattered across multiple poorly structured CSV/PDF files.

Information on lines 1, 2, 3, 5, and 15 are sourced from the open data
portal from METRÔ, while lines 4 and 5 (post-2018) are sourced from
Dataverse (Insper).

All datasets are returned as `tibble` objects and are “lazy” datasets,
meaning they are bundled with the package and don’t need to be
downloaded. The data is also cleaned and standardized to make it easier
to work with.

## Line Coverage

The package currently covers all metro lines in São Paulo. In the future
it may be expanded to include trains as well.

| Line | Name             | Operator      | Period    | Status    |
|-----:|------------------|---------------|-----------|-----------|
|    1 | Azul (Blue)      | METRÔ         | 2017–2025 | Available |
|    2 | Verde (Green)    | METRÔ         | 2017–2025 | Available |
|    3 | Vermelha (Red)   | METRÔ         | 2017–2025 | Available |
|    4 | Amarela (Yellow) | ViaQuatro     | 2012–2025 | Available |
|    5 | Lilás (Lilac)    | ViaMobilidade | 2017–2025 | Available |
|   15 | Prata (Silver)   | METRÔ         | 2017–2025 | Available |

## Installation

The package will be available on CRAN. Once released, install with:

``` r

install.packages("metrosp")
```

To install the development version from GitHub, use:

``` r

# install.packages("remotes")
remotes::install_github("viniciusoike/metrosp")
```

## Datasets

The table below describes all datasets that are shipped with the
package. The main datasets are: `passengers_entrance`,
`passengers_transported`, `station_averages`, and `station_daily`. Other
datasets are auxiliary tables aimed at facilitating analysis and
visualization.

| Dataset | Description | Frequency | Spatial |
|----|----|----|----|
| `passengers_entrance` | Average passenger entries by line | Monthly | No |
| `passengers_transported` | Average passengers transported by line | Monthly | No |
| `station_averages` | Average weekday passenger entries by station | Monthly | No |
| `station_daily` | Daily passenger entries by station | Daily | No |
| `metro_lines` | Metro line reference table (names, colors, operators) | — | No |
| `metro_colors` | Named vector of official metro line colors | — | No |
| `lines` | Metro and train line routes (current + planned) | — | Yes |
| `stations` | Metro and train station locations (current + planned) | — | Yes |

## Usage

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

## Data sources

- METRÔ: [Companhia do Metropolitano de São Paulo
  (METRO)](https://transparencia.metrosp.com.br/dataset/demanda).
- Lines 4/5 data: [Insper
  Dataverse](https://doi.org/10.60873/FK2/UTGQ0I) (ViaQuatro /
  ViaMobilidade).
- Spatial data: [GeoSampa, Prefeitura de São
  Paulo](https://geosampa.prefeitura.sp.gov.br/).
