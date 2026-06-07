## Initial CRAN Release

R data package providing São Paulo Metro passenger demand data, similar to [nycflights13](https://github.com/hadley/nycflights13). Install from CRAN:

```r
install.packages("metrosp")
```

### Datasets

All datasets are lazy-loaded `tibble` objects — no internet connection required.

| Dataset | Description | Frequency |
|---|---|---|
| `passengers_entrance` | Monthly passenger entries by metro line (2017–2025) | Monthly |
| `passengers_transported` | Monthly passengers transported by metro line (2017–2025) | Monthly |
| `station_averages` | Average weekday entries by station (2017–2025) | Monthly |
| `station_daily` | Daily passenger entries by station (2020–2025) | Daily |
| `lines` | Metro + CPTM train line route geometries (`sf`) | — |
| `stations` | Metro + CPTM train station point locations (`sf`) | — |
| `metro_colors` | Named vector of official line hex colors | — |

### Line coverage

All six São Paulo metro lines: Line 1 Azul, Line 2 Verde, Line 3 Vermelha, Line 4 Amarela, Line 5 Lilás, and Line 15 Prata.

### Data sources

- **Lines 1–3, 15**: [METRÔ Transparency Portal](https://transparencia.metrosp.com.br/dataset/demanda)
- **Lines 4–5**: [Insper Dataverse](https://doi.org/10.60873/FK2/UTGQ0I) (ViaQuatro / ViaMobilidade)
- **Spatial data**: [GeoSampa](https://geosampa.prefeitura.sp.gov.br/) (Prefeitura de São Paulo)

### Documentation

- [pkgdown site](https://viniciusoike.github.io/metrosp/)
- [Getting started vignette](https://viniciusoike.github.io/metrosp/articles/getting_started.html)
