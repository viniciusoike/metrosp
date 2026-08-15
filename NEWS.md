# metrosp 1.2.0

## Datasets

* Extended METRO coverage back to January 2016 for `passengers_entrance`,
  `passengers_transported`, and `station_averages`.
* Added January–September 2017 to `passengers_entrance`,
  `passengers_transported`, and `station_averages`. METRO published those
  months only as PDFs without a text layer; they were transcribed from the
  rendered pages and reconciled against the totals printed beside them.
* July 2017 remains absent from `passengers_entrance` for Lines 1, 2, 3, 5,
  and 15, and for the network total. The file METRO published under that
  name repeats the transported table, so no entrance figures exist for that
  month. Line 4 comes from the Dataverse and is unaffected.
* June 2017 has no network total (`line_number = 99`) in
  `passengers_transported`. The report reprinted May's network column; the
  per-line values for June are unaffected.
* Refroze the shipped snapshot through June 2026 (Lines 4 and 5 end earlier,
  in March and April 2026, since the Dataverse source lags METRO).

## Bug fixes

* Corrected `mdu`, `msa`, `mdo`, and `max` for Lines 4 and 5 in
  `passengers_entrance`, across the whole series. The Dataverse source is
  station-level, and the averages and daily peak were taken over
  station-days rather than over line-day totals, so each was divided by the
  number of stations reporting that month. Values rise by roughly 5 to 17
  times depending on the line and the year. `total` is unchanged. Anyone
  comparing Line 4 or 5 averages against an earlier release should expect a
  break.
* Fixed metric labels resolving to `NA` for 2016–2019 in
  `passengers_entrance` and `passengers_transported`. The lookup keyed a
  named vector on accented Portuguese text, which stops matching outside a
  UTF-8 locale, so a build could drop every label without erroring. Station
  names and line numbers in `station_averages` were affected the same way.
  The pipeline now refuses to run outside a UTF-8 locale.

## Pipeline

No exported value changes. The snapshot was refrozen for two structural
differences: `metric_abb` in `passengers_entrance` and
`passengers_transported` no longer carries a stray `names` attribute, and
`station_averages` drops one all-`NA` row (Jardim Colonial, January 2022).

* Replaced the per-year, per-line row-offset tables in the station-average
  and passenger readers with block detection over the file's own text. The
  readers locate each line's table by its `LINHA …` / `DEMANDA …` header and
  take the line roster from that header, so a source that adds a title row
  or drops a line no longer needs a hand-edited offset. One reader now
  serves 2016 and 2020 onward, and another serves the 2017–2019 monthly
  files.
* Removed `.import_stn_avg_2016()`, `get_skip_offset()`,
  `read_csv_stations_average()`, and `clean_stations_average()`, all
  superseded by the shared readers.
* Fixed the 2016 line-level reader placing Line 5 in Line 15's column. The
  committed CSVs were already correct, so no exported value changes; the fix
  is what keeps a future re-import of the 2016 files correct.
* Collapsed three copies of the line-name lookup into
  `dim_line$line_name_full`, and derived `metro_lines` from `dim_line`
  instead of restating it.
* Renamed the pipeline's functions onto one vocabulary (`psg_line`,
  `stn_avg`, `stn_daily`, suffixed by era) and dropped the `.` prefix.
* Required dplyr 1.2.0, for `filter_out()` and `replace_values()`.
* `data-publish.yaml` now writes each batch to a dated `data-YYYY-MM` release
  tag as well as the rolling `data-latest` tag, so a batch stays retrievable
  after `data-latest` moves on.

## Documentation

* Documented that `passengers_transported` reports thousands of passengers,
  while the other demand datasets count individual passengers.
* Documented a defect in the Line 1 station averages for February–June 2016.
  The values run short and are misallocated across stations, so those five
  months should be excluded from station-level baselines.
* Corrected the end of Line 5 coverage in `passengers_transported` to
  August 2018, the month of the ViaMobilidade handover.
* Added the frozen-snapshot vintage and the `data-latest` release to the
  package landing page and both vignettes.
* Regenerated the time-coverage figures and their alt text against the new
  snapshot.

# metrosp 1.1.1

## Datasets

* `passengers_entrance`, `passengers_transported`, and `station_daily`
  rebuilt through April 2026.

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
