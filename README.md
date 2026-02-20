# metrosp: metro ridership in São Paulo

This package makes demand data from the metro system (METRÔ) easily available inside R. The data is monthly and spans 2017-2025 across all METRO operated lines (i.e. 1, 2, 3, 5, and 15).
While this information is already [public](https://transparencia.metrosp.com.br/dataset/demanda) it's scattered across multiple poorly structured csv/pdf files. For more details on data cleaning process see the R scripts inside `data-raw`.

## Installation

The package is still in development but all of the main tables can already be accessed. The best way to download is via GitHub. A CRAN package is in the workings.

```r
# install.packages("remotes")
remotes::install_github("viniciusoike/metrosp")
```

## Datasets

| Dataset | Description | Rows |
|---|---|---|
| `passengers_entrance` | Monthly passenger entries by metro line (2017-2025) | 2,425 |
| `passengers_transported` | Monthly passengers transported by metro line (2017-2025) | 2,425 |
| `station_averages` | Average weekday station entries (2017-2025) | 6,222 |
| `metro_lines` | Reference table: line numbers and names | 13 |

## Usage

```r
library(metrosp)
# library(sf) -> to better load the metro stations and lines shapefile

# Passenger entries by line
head(passengers_entrance)

# Station-level averages
head(station_averages)

# Reference table for metro lines
metro_lines
```

## Data source

All data from [Companhia do Metropolitano de Sao Paulo (METRO)](https://transparencia.metrosp.com.br/dataset/demanda).
