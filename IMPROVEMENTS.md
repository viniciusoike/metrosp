# metrosp — Improvements & TODO

## Current Status (v0.1.1)

Package restructured into a CRAN-ready data package. R CMD check passes with 0 errors, 0 warnings, 0 notes. 53 tests passing. `station_averages` now includes `line_name_pt` and `line_name` columns.

**Exported datasets**: `passengers_entrance` (2,425 rows), `passengers_transported` (2,425 rows), `station_averages` (6,222 rows), `metro_lines` (13 rows). Total .rda size: ~23KB.

---

## HIGH — Code quality (v0.1.x)

### ~~1. Move duplicated functions to utils.R~~ DONE
Moved `read_csv_passengers()` and `clean_csv_passengers()` to `data-raw/utils.R`. Removed duplicates from both import scripts.

### ~~2. Remove inline `as_numeric_pt()` duplicate~~ DONE
Removed inline copy from `clean_psg_line()` in `import_passenger_2017_19.R`.

### ~~3. Clean up commented-out code~~ DONE
Removed ~60 lines of dead code from `import_daily_2017_19.R` and `import_passenger_2017_19.R`.

### ~~4. Fix metric mapping robustness in make_datasets.R~~ DONE
Replaced exact-match `metric_map[variable]` with case-insensitive `map_metric()` using `tolower(trimws(...))`.

### ~~5. Delete duplicate processed CSV~~ DONE
Removed `data-raw/processed/metro_sp_passengers_2020_2025.csv`.

---

## MEDIUM — Data & consistency (v0.2.0)

### ~~6. Add line_name columns to station_averages~~ DONE
Added `line_name_pt` and `line_name` via `left_join()` to `metro_lines` in `make_datasets.R`. Updated `R/data.R` docs.

### ~~7. Apply station name standardization~~ DONE
Applied `station_renames` mapping (Carrão, Penha, Saúde, Patriarca) to 2017-2019 station data in `make_datasets.R`.

### ~~8. Improve R/data.R documentation~~ DONE
Added Line 15 station count details, mdu metric clarification, cross-reference to `passengers_entrance`.

### ~~9. Add more tests~~ DONE
Added 6 new test blocks (21 new assertions): date range validation, column type checks, non-negative values, no duplicates, no trailing whitespace, Line 5 pre-2020 only.

---

## LOW — Future features (v0.3.0+)

### 10. Complete import_station_daily.R (daily station data)

**What it does**: Imports daily passenger entrance counts per station (2020-2025). Raw CSVs exist for all 6 years (~127-141 KB each, all present including 2024).

**Why it's complex**: The CSVs have a non-standard parallel layout — 4 metro lines are presented side-by-side within each monthly section, separated by `;;`. Each month has a variable number of rows (28-31 days), with header rows and blank rows between months. The skip offsets are fragile and year-dependent.

**Output schema** (estimated):
```
date (Date), year (int), line_number (int), station_code (char),
station_name (char), daily_entries (numeric)
```

**Estimated size**: ~100K rows/year x 6 years = ~600K rows. As .rda this would be ~2-5 MB — close to CRAN's 5 MB package limit.

**Steps to complete**:
1. Finalize skip offset calculation for all years
2. Write parallel-line parser to split the 4-line horizontal layout
3. Build station code -> station name lookup table
4. Clean, reshape to long format, construct dates
5. Handle edge cases: leap years, missing days, encoding
6. Test and validate across all years

**CRAN concern**: The resulting dataset may be too large for CRAN (5 MB limit). Consider: (a) providing only a subset, (b) hosting externally, or (c) offering a download helper function.

### 11. Push to GitHub and add CI
- Create GitHub repo: `gh repo create viniciusoike/metrosp --public --source=. --push`
- Add GitHub Actions: `usethis::use_github_action("check-standard")`
- Add R-CMD-check badge to README

### 12. Generalize skip offset logic
The import scripts use hardcoded `case_when()` with magic numbers for skip/n_max values. Could extract to a config data frame or YAML file, making it easier to add new years.

### 13. Archive or remove clean_metro.R
Currently 1,065 lines of scratch/exploration code marked with an ARCHIVE header. Could be moved to a `data-raw/archive/` subfolder or deleted entirely since all working code is in the other scripts.

---

## Raw Data Audit

### CSV import coverage: 101 of 107 raw CSVs imported

| Location | Total | Imported | Script |
|---|---|---|---|
| `2017/` | 10 | 9 | `import_passenger_2017_19.R`, `import_daily_2017_19.R` |
| `2018/*/` | 36 | 36 | same scripts |
| `demanda_2019/*/` | 36 | 36 | same scripts |
| `csv/` (2020-2025) | 24 | 18 | `import_passengers_entrance.R`, `import_passengers_transported.R`, `import_station_averages.R` |

### NOT imported (7 CSVs)

1. **`2017/29-Demanda Diária de Visitantes - Operação Assistida...Linha 5-Lilás.csv`**
   Special Line 5 assisted operation daily visitor data. Low priority — niche data about a temporary operational mode.

2. **`csv/entrada_de_passageiros_por_estacao_diaria_*.csv` (6 files, 2020-2025)**
   Daily station entrance data. All 6 files exist (including 2024). Script `import_station_daily.R` is incomplete. See item #10 above.

### Daily station CSV format
- Semicolon-delimited, ISO-8859-1 encoding
- 4 metro lines side-by-side per section: Linha 1-Azul, Linha 2-Verde, Linha 3-Vermelha, Linha 15-Prata
- Each monthly block: header with station codes (2-letter abbreviations), then 28-31 daily rows, then Total row
- Months separated by blank rows and new header sections
- Values in thousands, Portuguese decimal format

### Non-CSV raw data (not processable)
- `pdf/indicadores_*.pdf` (6 files, 2020-2025): System indicators — PDF only, no CSV equivalent
- `operacao_assistida_*` (Line 5 and Line 15, 2018): Assisted operation PDFs — only PDFs
- 2017 Jan-Sep: All data is PDF only (CSVs start from October 2017)

---

## Known Data Gaps

- **Line 5 (Lilas)**: Available Oct 2017 - Dec 2019 only. Absent from 2020-2025 raw data.
- **2017**: Only Oct-Dec available (data starts October 2017).
- **2025**: Trailing months may have NA values (data not yet published at time of download).
- **Network total (line 99)**: Available in 2017-2019; in 2020-2025 stored as NA then mapped to 99.
- **Station metrics**: Only weekday average (mdu) at station level. Line-level has all 5 metrics.
- **Line 15 stations**: 10 stations in 2020, 11 from 2021 onward.
