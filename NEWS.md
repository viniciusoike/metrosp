# metrosp 1.1.0

## Datasets

* Added `calendar_spo`: a São Paulo holiday and business-day calendar
  (2012–2030) covering national, state, and municipal holidays, for use in
  demand seasonality and business-day adjustments.
* Removed the `forecasts` and `forecast_accuracy` exports. These were exported
  in 1.0.0 by mistake: `metrosp` is an observed-demand data package and
  forecasting belongs downstream, so they should never have shipped.
* Removed the `metro_lines` export. Its line-name columns (`line_name`,
  `line_name_pt`) are already denormalized onto every passenger/station
  dataset, and the full line list (including planned and CPTM lines) is
  available in `lines`. It remains an internal join dimension in the ETL
  pipeline.
* `station_daily$line_number` / `station_daily$year` are now `integer`
  (previously `double`), matching the other datasets. Values are unchanged.

## Data quality

* Station names are now canonicalized consistently across the demand datasets
  (`station_averages`, `station_daily`) and the geometry datasets (`stations`),
  so a station joins cleanly across sources.
* Fixed footnote-digit and sponsor-name contamination in station names
  (e.g. stray trailing digits and parenthesized line numbers).
* Trailing unpublished `NA` rows are now trimmed per line during assembly;
  interior `NA`s (e.g. station outages) are preserved. All datasets rebuilt.
* Refreshed the 2017–2019 source CSV.
* Fixed a duplicate row in `stations` (Vila Mariana, Line 1) caused by the
  GeoSampa import not deduplicating after the name/join cleanup step. Added a
  regression test asserting `stations` has no duplicate rows.

## Data pipeline

* The `data-raw/` ETL now runs as a
  [targets](https://docs.ropensci.org/targets/) pipeline
  (`targets::tar_make()`), replacing the flag-driven `run_pipeline.R`
  orchestrator. Pipeline functions live in `data-raw/R/`; the legacy scripts
  remain and produce identical output. See `CLAUDE.md` for the workflow.
* Gated refreshes (download, historical re-import, Dataverse) are controlled by
  environment-variable flags via `tarchetypes::tar_force()` and skip cleanly
  when the flags are off.

# metrosp 1.0.0

* Initial CRAN submission.
