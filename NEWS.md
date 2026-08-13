# metrosp 1.1.1

## Datasets

* Refroze the shipped snapshot through June 2026 (Lines 4 and 5 end earlier,
  in March and April 2026, since the Dataverse source lags METRO).
* Extended METRO coverage back to January 2017 for `passengers_entrance`,
  `passengers_transported`, and `station_averages`. The first nine months of
  2017 are extracted from the source PDFs, since the portal's machine-readable
  files begin in October 2017.

## Documentation

* Documented that `passengers_transported` reports thousands of passengers,
  while the other demand datasets count individual passengers.
* Corrected the end of Line 5 coverage in `passengers_transported` to
  August 2018, the month of the ViaMobilidade handover.
* Added the frozen-snapshot vintage and the `data-latest` release to the
  package landing page and both vignettes.

## Vignettes

* Added time-coverage-by-line charts and tables to the data dictionary for
  all four core datasets (previously only `passengers_entrance` had one).
* Rewrote the "Core datasets" sections of the data dictionary to follow a
  single consistent structure (columns table, glimpse, time coverage).
* Reordered the interchange-stations table by reference line and station
  name, and fixed assorted typos and wording issues.

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
* Fixed a row-skip bug in the passenger-by-line CSV parser
  (`passengers_entrance`, `passengers_transported`): a hardcoded per-year
  header offset was one row short of where the source's "Jan" row actually
  landed, which shifted every month's figures up one slot (February's numbers
  were recorded as January's, and so on) and mistook the annual total row for
  December. The offset is now detected dynamically per file instead of
  hardcoded, since the header length has drifted release to release.
* Fixed a `targets` caching gap where the METRO CSV download target returned
  a constant directory path, so a fresh download never invalidated the
  downstream parsers (`entrance_current`, `transported_current`,
  `averages_current`, `daily_current`) -- they kept serving stale cached data
  even right after a real re-download. The target is now content-hashed
  against the downloaded files themselves.

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
