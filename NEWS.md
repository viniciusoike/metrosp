# metrosp 0.2.0

## New datasets

* `station_daily`: Daily passenger entries by station for Lines 1, 2, 3,
  and 15 (2020–2025).
* `lines`: Spatial line geometries for all METRO SP and CPTM commuter train
  lines, covering both currently operating and planned routes (sf,
  EPSG:4326). Replaces the previous separate `metro_lines_geo`,
  `train_lines_geo`, and `train_lines` objects.
* `stations`: Spatial point locations for all METRO SP and CPTM stations,
  covering current and planned stations (sf, EPSG:4326). Replaces the
  previous separate `metro_stations_geo` and `train_stations_geo` objects.

## Breaking changes

* `metro_lines`, `metro_lines_geo`, `metro_stations_geo`, `train_lines`,
  `train_lines_geo`, and `train_stations_geo` have been removed. Use
  `lines` and `stations` instead, filtering on the `type` column
  (`"metro"` or `"train"`).

## Other changes

* `lines` and `stations` include a `type` column (`"metro"` / `"train"`)
  and a `status` column (`"current"` / `"future"`).
* Documentation updated throughout to reflect new dataset structure.

# metrosp 0.1.0

* Initial release.
* Datasets: `passengers_entrance`, `passengers_transported`,
  `station_averages`, `metro_lines`.
* Coverage: October 2017 through 2025.
* Data source: METRO SP transparency portal.
