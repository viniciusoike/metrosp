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

| Dataset                | Description                                          | Frequency | Spatial |
|------------------------|------------------------------------------------------|-----------|---------|
| passengers_entrance    | Daily average passenger entries across lines         | Monthly   | No      |
| passengers_transported | Daily average passengers transported across lines    | Monthly   | No      |
| station_averages       | Daily average passenger entries across stations      | Monthly   | No      |
| station_daily          | Daily count of passenger entries across stations     | Daily     | No      |
| lines                  | Shapefile of current and future metro/train lines    |           | Yes     |
| stations               | Shapefile of current and future metro/train stations |           | Yes     |

## Usage

```r
library(metrosp)
# To load the spatial files (lines, stations)
library(sf)

# Passenger entries by line
head(passengers_entrance)

# Station-level averages
head(station_averages)

# Reference table for metro lines
lines
```

## Data source

All data from [Companhia do Metropolitano de Sao Paulo (METRO)](https://transparencia.metrosp.com.br/dataset/demanda).
