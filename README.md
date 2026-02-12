# metrosp

Monthly passenger demand data for the Sao Paulo metro system (METRO SP), sourced from the [METRO transparency portal](https://transparencia.metrosp.com.br/dataset/demanda).

## Installation

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

# Passenger entries by line
head(passengers_entrance)

# Station-level averages
head(station_averages)

# Reference table for metro lines
metro_lines
```

## Data source

All data from [Companhia do Metropolitano de Sao Paulo (METRO)](https://transparencia.metrosp.com.br/dataset/demanda).

## License

MIT
