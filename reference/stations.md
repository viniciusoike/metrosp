# Metro and Train Station Locations

Spatial point locations for Sao Paulo metro (METRO SP) and commuter
train (CPTM) stations, including both currently operating stations and
planned future stations.

## Usage

``` r
stations
```

## Format

An sf data frame with POINT geometry (CRS: WGS84 / EPSG:4326) and the
following columns:

- station_name:

  Station name in title case (character).

- line_number:

  Line number the station belongs to (integer).

- line_name_pt:

  Portuguese color name of the line (character).

- line_name:

  English color name of the line (character).

- company_name:

  Operating company name (character).

- type:

  Either `"metro"` (METRO SP) or `"train"` (CPTM) (character).

- status:

  Either `"current"` (operating) or `"future"` (planned expansion)
  (character).

- geometry:

  Station location (sfc_POINT).

## Source

GeoSampa, Prefeitura de Sao Paulo.
<https://geosampa.prefeitura.sp.gov.br/>

## Details

Requires the sf package to work with spatial features. The distinction
between types isn't always consistent, but we follow GeoSampa's
classification. Broadly speaking, the "metro" runs undergrounds as a
subway, and "train" runs above grounds as a commuter rail (although
there are exceptions)

## See also

[`lines`](https://viniciusoike.github.io/metrosp/reference/lines.md) for
line route geometries,
[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for passenger data by station.
