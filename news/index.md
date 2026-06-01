# Changelog

## metrosp (development version)

### Data pipeline

- The `data-raw/` ETL pipeline can now be run as a
  [targets](https://docs.ropensci.org/targets/) pipeline
  ([`targets::tar_make()`](https://docs.ropensci.org/targets/reference/tar_make.html)),
  replacing the flag-driven `run_pipeline.R` orchestrator. Pipeline
  functions live in `data-raw/R/`; the legacy scripts remain and produce
  identical output. See `CLAUDE.md` for the workflow.

### Datasets

- `metro_lines$line_number` and `station_daily$line_number` /
  `station_daily$year` are now `integer` (previously `double`), matching
  the other datasets. Values are unchanged.

## metrosp 1.0.0

CRAN release: 2026-05-05

- Initial CRAN submission.
