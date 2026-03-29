# metrosp: metro ridership in São Paulo

This package makes demand data from the São Paulo metro and train system easily
available inside R. Data is sourced from multiple operators and spans 2017–2025.
While this information is already [public](https://transparencia.metrosp.com.br/dataset/demanda)
it's scattered across multiple poorly structured CSV/PDF files. For more details
on the data cleaning process see the R scripts inside `data-raw`.

## Line Coverage

| Line | Name             | Operator      | Period    | Status      |
|-----:|------------------|---------------|-----------|-------------|
|    1 | Azul (Blue)      | METRÔ         | 2017–2025 | Available   |
|    2 | Verde (Green)    | METRÔ         | 2017–2025 | Available   |
|    3 | Vermelha (Red)   | METRÔ         | 2017–2025 | Available   |
|    5 | Lilás (Lilac)    | ViaMobilidade | 2017–2019 | Available   |
|   15 | Prata (Silver)   | METRÔ         | 2017–2025 | Available   |
|    4 | Amarela (Yellow) | ViaQuatro     | —         | Coming soon |
|    5 | Lilás (Lilac)    | ViaMobilidade | 2020–2025 | Coming soon |

## Installation

The package is still in development but all of the main tables can already be
accessed. The best way to install is via GitHub. A CRAN release is in the works.

```r
# install.packages("remotes")
remotes::install_github("viniciusoike/metrosp")
```

## Datasets

| Dataset                  | Description                                           | Frequency | Spatial |
|--------------------------|-------------------------------------------------------|-----------|---------|
| `passengers_entrance`    | Average passenger entries by line                     | Monthly   | No      |
| `passengers_transported` | Average passengers transported by line                | Monthly   | No      |
| `station_averages`       | Average weekday passenger entries by station          | Monthly   | No      |
| `station_daily`          | Daily passenger entries by station                    | Daily     | No      |
| `lines`                  | Metro and train line routes (current + planned)       | —         | Yes     |
| `stations`               | Metro and train station locations (current + planned) | —         | Yes     |

## Usage

```r
library(metrosp)
# To work with spatial datasets (lines, stations)
library(sf)

# Passenger entries by line
head(passengers_entrance)

# Station-level weekday averages
head(station_averages)

# Spatial line routes
lines
```

## Data sources

Passenger data: [Companhia do Metropolitano de São Paulo (METRO)](https://transparencia.metrosp.com.br/dataset/demanda).
Spatial data: [GeoSampa, Prefeitura de São Paulo](https://geosampa.prefeitura.sp.gov.br/).
