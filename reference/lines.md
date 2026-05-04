# Metro and Train Line Routes

Spatial line geometries for São Paulo metro (METRO SP) and commuter
train (CPTM) lines, including both currently operating lines and planned
future expansions.

## Usage

``` r
lines
```

## Format

An sf data frame with LINESTRING geometry (CRS: WGS84 / EPSG:4326) and
the following columns:

- line_number:

  Official line number (integer).

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

  Line route geometry (sfc_LINESTRING).

## Source

GeoSampa, Prefeitura de São Paulo.
<https://geosampa.prefeitura.sp.gov.br/>

## Details

Requires the sf package to work with spatial features. The distinction
between types follows GeoSampa's classification. Broadly, `"metro"`
lines run underground as a subway and `"train"` lines run above ground
as commuter rail, though exceptions exist.

## See also

[`stations`](https://viniciusoike.github.io/metrosp/reference/stations.md)
for station point locations.
