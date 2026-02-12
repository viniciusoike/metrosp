# Plan: Restructure metrosp into a CRAN-ready Data Package

## Context

metrosp is an R data package providing Sao Paulo Metro (METRO SP) passenger demand data, similar to nycflights13. The ETL pipeline already works and 6 processed CSVs exist, but the package structure is wrong: all scripts live in `R/` instead of `data-raw/`, the `data/` directory is empty (no `.rda` files), there are no tests/docs/README, and no git repo exists. The datasets from different time periods have different column schemas that must be harmonized before merging.

**Author**: Vinicius Oike (viniciusoike@gmail.com)
**License**: MIT
**API**: Datasets only (lazy-loaded `.rda`, no user-facing functions)

---

## Final Exported Datasets

| Dataset | Description | Merge from |
|---|---|---|
| `passengers_entrance` | Monthly passenger entries by line, 2017-2025 | 2017-2019 (filtered) + entrance 2020-2025 |
| `passengers_transported` | Monthly passengers transported by line, 2017-2025 | 2017-2019 (filtered) + transported 2020-2025 |
| `station_averages` | Avg weekday station entries, 2017-2025 | stations 2017-2019 + stations 2020-2025 |
| `metro_lines` | Reference table: line number, PT/EN names | Built from `dim_line` in utils.R |

---

## Schema Harmonization (Critical)

### Passengers: 2017-2019 vs 2020-2025

**2017-2019** (`metro_sp_passengers_2017_2019.csv`, 1500 rows):
```
year, measure, date, variable, value, line_number, line_name_pt, line_name
```
- `measure` = entrance | transport (both types in one file)
- `variable` = Portuguese full names ("Total", "Media dos dias uteis", etc.)
- `line_number` = 1, 2, 3, 5, 15, 99

**2020-2025** (entrance/transported separate files, 1800 rows each):
```
date, line_number, metric_abb, metric, value, year
```
- `metric_abb` = total, mdu, msa, mdo, max
- `line_number` = 1, 2, 3, 15, NA (no line 5; NA = network total)
- No `line_name_pt` / `line_name` columns

**Harmonization steps:**
1. Map `variable` -> `metric_abb` (e.g., "Media dos dias uteis" -> "mdu")
2. Split 2017-2019 by `measure` into entrance/transported
3. Set `line_number = 99` for NA rows in 2020-2025 (network total)
4. Add `line_name_pt` / `line_name` to 2020-2025 via join to `metro_lines`
5. Standardize to unified columns: `date, year, line_number, line_name_pt, line_name, metric, metric_abb, value`

**Note:** `metro_sp_passengers_2020_2025.csv` is an exact duplicate of `metro_sp_passengers_tranported_2020_2025.csv` -- delete the duplicate.

### Station Averages: 2017-2019 vs 2020-2025

**2017-2019** (`metro_sp_stations_averages_2017_2019.csv`, 1711 rows):
```
date, year, month, line_name_full, name_station, metric_abb, value
```
- `line_name_full` = "Linha 1 - Azul" (string, not numeric)
- `name_station` (not `station_name`)
- Has "Linha 5 - Lilas9" typo
- `metric_abb` always "mdu"
- `month` = Portuguese month name

**2020-2025** (`metro_sp_stations_averages_2020_2025.csv`, 4512 rows):
```
date, line_number, station_name, avg_passenger, year
```
- `line_number` = numeric
- `station_name` (not `name_station`)
- No metric column (implicitly mdu)
- No month column

**Harmonization steps:**
1. Parse `line_name_full` -> `line_number` (lookup table)
2. Fix "Lilas9" typo -> "Lilas"
3. Rename `name_station` -> `station_name`
4. Rename `value` -> `avg_passenger`
5. Drop `month` and `metric_abb` columns
6. Standardize to unified columns: `date, year, line_number, station_name, avg_passenger`

---

## Data Coverage Audit

### Raw data inventory (data-raw/metro_sp/metro/)
- **106 raw CSV files** across 2017-2025
- **2017**: 10 files (Oct-Dec only, partial year)
- **2018**: 36 files (12 months x 3 metrics)
- **2019**: 36 files (12 months x 3 metrics)
- **2020-2025**: 24 files (6 years x 4 types)

### Processed data (data-raw/processed/)
| Processed CSV | Rows | Source files | Status |
|---|---|---|---|
| `metro_sp_passengers_2017_2019.csv` | 1500 | 2017-2019 raw | Complete |
| `metro_sp_passengers_entrance_2020_2025.csv` | 1800 | 6 entrance CSVs | Complete (2025 partial) |
| `metro_sp_passengers_tranported_2020_2025.csv` | 1800 | 6 transported CSVs | Complete (2025 partial) |
| `metro_sp_passengers_2020_2025.csv` | 1800 | DUPLICATE of above | Delete |
| `metro_sp_stations_averages_2017_2019.csv` | 1711 | 2017-2019 station CSVs | Complete |
| `metro_sp_stations_averages_2020_2025.csv` | 4512 | 6 station avg CSVs | Complete |

### Unprocessed raw data
| Raw data type | Files | Status | Notes |
|---|---|---|---|
| Daily station entries 2020-2025 | 5 CSVs (2024 missing) | NOT PROCESSED | `import_station_daily.R` is incomplete |
| Assisted operations 2018 | PDFs only | NOT PROCESSED | Line 5 and Line 15 supervised ops |
| Indicators (indicadores) | PDFs only | NOT PROCESSED | Additional system metrics |

### Known data gaps
- **Line 5 (Lilas)**: Present in 2017-2019, missing from 2020-2025 raw data
- **Network total (line 99)**: Present in 2017-2019, stored as NA in 2020-2025
- **2017**: Only Oct-Dec available (not full year)
- **2025**: Trailing months have NA values (data not yet published)
- **Station metrics**: Only weekday average (mdu) available at station level
- **Daily station 2024**: Raw CSV file is missing from data-raw/metro_sp/metro/csv/

---

## Phase 1: Fix Package Structure

### 1.1 Move ETL scripts from R/ to data-raw/

| File | Action |
|---|---|
| `R/hello.R` | Delete |
| `man/hello.Rd` | Delete |
| `R/download_metro.R` | Move to `data-raw/` |
| `R/utils.R` | Move to `data-raw/` |
| `R/import_station_averages.R` | Move to `data-raw/` |
| `R/import_passengers_entrance.R` | Move to `data-raw/` |
| `R/import_passengers_transported.R` | Move to `data-raw/` |
| `R/import_daily_2017_19.R` | Move to `data-raw/` |
| `R/import_passenger_2017_19.R` | Move to `data-raw/` |
| `R/import_station_daily.R` | Move to `data-raw/` (incomplete) |
| `R/clean_metro.R` | Move to `data-raw/` (archive) |

### 1.2 Fix `source()` paths in moved scripts

Update `source("R/utils.R")` -> `source(here::here("data-raw/utils.R"))` in all import scripts.

### 1.3 Create `R/data.R`

Sole file in `R/` -- roxygen2 documentation blocks for all 4 exported datasets. No functions.

### 1.4 Create `data-raw/make_datasets.R`

Master script that:
1. Reads processed CSVs
2. Harmonizes schemas (see above)
3. Merges 2017-2019 + 2020-2025 by topic
4. Builds `metro_lines` reference table
5. Runs sanity checks (no unexpected NAs, valid line numbers, date ranges)
6. Calls `usethis::use_data()` for each dataset

### 1.5 Update DESCRIPTION

```
Package: metrosp
Title: Sao Paulo Metro Passenger Demand Data
Version: 0.1.0
Authors@R: person("Vinicius", "Oike", email = "viniciusoike@gmail.com", role = c("aut", "cre"))
Description: Monthly passenger demand data for the Sao Paulo metro system
    (METRO SP), sourced from the METRO transparency portal. Includes
    passengers entering and transported by line, and average station
    entries from 2017 to 2025.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
Depends: R (>= 3.5.0)
Suggests: dplyr, ggplot2, knitr, rmarkdown
Roxygen: list(markdown = TRUE)
URL: https://github.com/viniciusoike/metrosp
BugReports: https://github.com/viniciusoike/metrosp/issues
```

### 1.6 Update NAMESPACE

Replace wildcard export with roxygen2-managed (empty -- data-only package uses `LazyData: true`).

### 1.7 Update .Rbuildignore

Add: `^data-raw$`, `^\.github$`, `^LICENSE\.md$`, `^README\.Rmd$`, `^CLAUDE\.md$`, `^PLAN\.md$`, `^\.DS_Store$`

---

## Phase 2: Setup GitHub

1. Create `.gitignore` (exclude `.Rproj.user`, `.DS_Store`, `data-raw/metro_sp/` [46MB raw data])
2. `usethis::use_mit_license("Vinicius Oike")` -> creates LICENSE + LICENSE.md
3. `git init` + initial commit
4. Create `README.md` (install instructions, usage example, data source attribution)
5. Create `CLAUDE.md` (project-level development instructions)
6. Create GitHub repo + push (`gh repo create`)
7. Add GitHub Actions R-CMD-check workflow (`usethis::use_github_action("check-standard")`)

**Note:** `data-raw/processed/` (~600KB) IS committed. `data-raw/metro_sp/` (46MB) is gitignored.

---

## Phase 3: Cleanup & Comment Codebase

### 3.1 Deduplicate shared functions

`read_csv_passengers()` and `clean_csv_passengers()` are defined identically in both `import_passengers_entrance.R` and `import_passengers_transported.R`. Move to `data-raw/utils.R`.

### 3.2 Add header comments to each script

Each `data-raw/import_*.R` file gets a descriptive header: what it processes, years covered, output file, known quirks.

### 3.3 Comment `data-raw/utils.R`

Add section headers and explanations for dimension tables and utility functions.

### 3.4 Archive `clean_metro.R`

Rename to `clean_metro_ARCHIVE.R` with header noting it's kept for reference only (duplicated/scratch code).

### 3.5 Mark `import_station_daily.R` as incomplete

Add header comment explaining it's a WIP stub, not needed for current release.

### 3.6 Fix naming inconsistencies

- Remove inline copies of `as_numeric_pt()` (use the one in utils.R)
- Standardize dim table names across files

---

## Phase 4: CRAN Preparation

1. `devtools::document()` -- generates man/ pages from R/data.R
2. `usethis::use_testthat()` -- creates test infrastructure
3. Create `tests/testthat/test-datasets.R` -- basic tests (datasets load, expected columns, no unexpected NAs, metro_lines has 13 rows)
4. Create `vignettes/introduction.Rmd` -- overview, usage examples with ggplot2, data source notes
5. Create `NEWS.md` -- initial release changelog
6. `devtools::check(cran = TRUE)` -- target 0 errors, 0 warnings, 0 notes
7. Use `compress = "xz"` in `usethis::use_data()` if data size is a concern (expected <200KB total)

---

## Execution Order

```
Phase 1 (Structure):  Move files -> fix paths -> make_datasets.R -> DESCRIPTION -> NAMESPACE -> .Rbuildignore
Phase 2 (GitHub):     .gitignore -> LICENSE -> git init -> README -> CLAUDE.md -> push -> CI
Phase 3 (Cleanup):    Deduplicate -> comment -> archive -> fix names
Phase 4 (CRAN):       document() -> tests -> vignette -> NEWS -> R CMD check
```

---

## Verification

- `devtools::load_all()` loads without errors
- `devtools::check()` passes with 0 errors, 0 warnings
- `data(passengers_entrance)` loads a data.frame with expected columns
- `nrow(passengers_entrance) > 0` and date range spans 2017-2025
- All 4 datasets have consistent column naming
- Package installs from GitHub: `remotes::install_github("viniciusoike/metrosp")`

---

## Key Files

| File | Status | Role |
|---|---|---|
| `R/data.R` | CREATE | Only file in R/ -- roxygen2 dataset docs |
| `data-raw/make_datasets.R` | CREATE | Master builder: harmonize + merge + use_data() |
| `data-raw/utils.R` | MOVE + EDIT | Shared utilities + deduped functions |
| `DESCRIPTION` | REWRITE | Package metadata |
| `README.md` | CREATE | Package intro for GitHub |
| `CLAUDE.md` | CREATE | Development instructions |
| `.gitignore` | CREATE | Exclude raw data and build artifacts |
| `.Rbuildignore` | EDIT | Exclude data-raw/ from package build |
| `tests/testthat/test-datasets.R` | CREATE | Dataset integrity tests |
| `vignettes/introduction.Rmd` | CREATE | Usage examples |
