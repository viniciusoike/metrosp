# Changelog

## metrosp 1.0.0

CRAN release: 2026-05-05

### New datasets

- `station_daily`: Daily passenger entries by station for Lines 1, 2, 3,
  and 15 (2020–2025).
- `lines`: Spatial line geometries for all METRO SP and CPTM commuter
  train lines, covering both currently operating and planned routes (sf,
  EPSG:4326). Replaces the previous separate `metro_lines_geo`,
  `train_lines_geo`, and `train_lines` objects.
- `stations`: Spatial point locations for all METRO SP and CPTM
  stations, covering current and planned stations (sf, EPSG:4326).
  Replaces the previous separate `metro_stations_geo` and
  `train_stations_geo` objects.

### New datasets (continued)

- `metro_lines`: Line reference table mapping line numbers to Portuguese
  and English color names (replaces the old spatial `metro_lines`
  object).
- `metro_colors`: Named character vector of official hex color codes for
  the six currently operating metro lines.

### Breaking changes

- `metro_lines_geo`, `metro_stations_geo`, `train_lines`,
  `train_lines_geo`, and `train_stations_geo` have been removed. Use
  `lines` and `stations` instead, filtering on the `type` column
  (`"metro"` or `"train"`).
- The previous `metro_lines` spatial dataset has been replaced by a new
  `metro_lines` dimension table (non-spatial). Use `lines` for route
  geometries.

### Other changes

- `lines` and `stations` include a `type` column (`"metro"` / `"train"`)
  and a `status` column (`"current"` / `"future"`).
- Documentation updated throughout to reflect new dataset structure.

## metrosp 0.1.0

- Initial release.
- Datasets: `passengers_entrance`, `passengers_transported`,
  `station_averages`, `metro_lines`.
- Coverage: October 2017 through 2025.
- Data source: METRO SP transparency portal.
