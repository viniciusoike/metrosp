# metrosp (development version)

## Data pipeline

* The `data-raw/` ETL pipeline can now be run as a
  [targets](https://docs.ropensci.org/targets/) pipeline
  (`targets::tar_make()`), replacing the flag-driven `run_pipeline.R`
  orchestrator. Pipeline functions live in `data-raw/R/`; the legacy scripts
  remain and produce identical output. See `CLAUDE.md` for the workflow.

## Datasets

* `metro_lines` is no longer exported. Its line-name columns
  (`line_name`, `line_name_pt`) are already denormalized onto every
  passenger/station dataset, and the full line list (including planned and
  CPTM lines) is available in `lines`. It remains an internal join dimension
  in the ETL pipeline.
* `station_daily$line_number` / `station_daily$year` are now `integer`
  (previously `double`), matching the other datasets. Values are unchanged.

# metrosp 1.0.0

* Initial CRAN submission.
