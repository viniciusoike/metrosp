# metrosp 2.0.0 — schema overhaul

Internal planning document. Not shipped: `dev/` is build-ignored.

Status: decided, not started. Each phase becomes a GitHub issue.

## Why now

2.0.0 is the last breaking change before the API is declared stable. Every
rename, type change and dataset removal lands here; after it, the dataset names
and column contract are fixed.

Distribution is R-universe and GitHub, not CRAN, so the install base is small
enough to break cleanly. No deprecated aliases.

## Decisions

| Question | Decision |
|---|---|
| Line 99 (SISTEMA) | Drop the rows |
| Station key | `station_id`, an opaque slug from a committed crosswalk |
| Complexes | One `station_id` per physical complex, shared across modes and lines |
| Renames | Current name applied retroactively; `station_id` frozen at first assignment |
| Crosswalk scope | Metro and CPTM, all 407 station rows |
| `station_inauguration` | Unshipped |
| Cache API | Two functions |
| Break style | Hard break, no aliases |

## Phase 1 — Data correctness

Fixes that stand alone, before any renaming churn.

**Drop line 99.** The published SISTEMA row is not the network. It covers the
lines Companhia do Metropolitano operated that month, so it never included
Line 4 and it lost Line 5 to the ViaMobilidade concession in August 2018 — the
series changes definition mid-stream. In `passengers_transported` it equals the
sum of the per-line rows to within 2.6e-5, so it adds nothing. In
`passengers_entrance` our own per-line sum runs about 5% above it in 2016–2018
because our Line 4 comes from Dataverse and was never in SISTEMA.

The only months where a 99 value sits next to a missing per-line value are
March, April and May 2020, where Line 15 is `NA`. No month loses its only
figure.

- `assemble.R`: drop the rows
- `dims.R:50`: drop `99L` from `dim_line`
- `dims.R:90`: drop the `line_name_full` special case
- `helpers.R:229` `label_line_number()`: drop the total row instead of mapping
  `NA` to `99`

**Document how the two line tables aggregate.** Entrance sums cleanly: a
passenger enters once at a turnstile and a transfer does not re-enter, so
summing lines gives a true network figure — a better one than SISTEMA, which
never covered all six lines. Transported does not: each line counts the
passengers it carries, so a trip using lines 1 and 3 counts twice, and METRO's
own SISTEMA row inherits that double counting because it is a plain sum.

Goes in `R/data.R`, and replaces the line-99 paragraphs in
`getting_started.qmd:122,157` and `data-dictionary.qmd:90,120`.

**Line 5's operator is ViaMobilidade.** Current rows in both `lines` and
`stations` say `company_name = "Metrô"`; only the future rows are right.
ViaMobilidade has run the line since 2018.

**Remove the June 2017 network-total note** in
`vignettes/articles/metro-demand-data.qmd:331`. The defect it describes is a
property of the 99 rows.

Ends with `METROSP_FREEZE=true`. `schema.json` does not change — no column
moves in this phase.

## Phase 2 — Column contract

The one phase that rewrites `schema.json`.

| Item | Decision |
|---|---|
| Measure column | `value` in all four demand tables; `avg_passenger` and `passengers` go |
| Metric columns | `metric` (code), `metric_name`, `metric_name_pt` — parallel to `line_number` / `line_name` / `line_name_pt`; `metric_abb` goes |
| `station_averages` | Goes long with `metric = "mdu"`, sharing the line tables' vocabulary |
| `station_daily` | No `metric` column; the grain is in the table name and a constant column is noise |
| Types | `line_number` and `year` integer everywhere (the docs already claim integer) |
| Column order | Keys, then labels, then `value` |
| `year` | Kept, relocated next to `date` |
| `calendar_spo` | `is_ponto_facultativo` → `is_optional_holiday`, `is_feriadao` → `is_long_weekend`; document that `weekday` is 1 = Sunday |

Canonical order: `date`, `year`, `line_number`, `station_id`, `station_name`,
`station_code`, `line_name`, `line_name_pt`, `metric`, `metric_name`,
`metric_name_pt`, `value`.

Units stay as published — transported in thousands, entrance in individual
passengers — per the existing documentation.

`check_schema()` fails until `write_schema(tar_read(datasets))` reruns. That
failure is the gate. `helper-checks.R` needs the new column names.

## Phase 3 — Station identity

### Why

Joins run on `station_name` today. That works because `dims.R` canonicalizes
the variants, but it cannot group the two Sé rows into one station, and names
collide across modes: 52 names repeat in `stations`.

### Files

`data-raw/inputs/dim_station.csv` — one row per physical station.

| Column | Meaning |
|---|---|
| `station_id` | Opaque ASCII slug, assigned once, never changes |
| `station_name` | Current canonical name |
| `station_code` | METRO's three letters; `NA` for lines 4, 5 and every CPTM station |
| `notes` | Why a merge or split was decided; free text |

`data-raw/inputs/dim_station_alias.csv` — one row per raw name variant.

| Column | Meaning |
|---|---|
| `station_name_raw` | Exactly as the source writes it |
| `station_id` | Target |
| `source` | Which upstream file the variant comes from |
| `notes` | Sponsor name, typo, honorific rename |

It absorbs `dim_station_name_change` (`dims.R:96`) whole, including the
existing policy: sponsor names collapse back to the plain name
(Carrão-Assaí Atacadista → Carrão), honorific renames map forward to the
current official name (Liberdade → Japão-Liberdade).

Line membership is derived, not stored — a station's lines follow from the data
and the geometry.

### Complexes

One `station_id` per physical complex, shared across lines and modes. Metro Luz
and CPTM Luz are one station, as Sé on lines 1 and 3 already is. `type` and
`line_number` keep the rows apart, so nothing is lost and interchange analysis
becomes a `group_by`.

Assignment is screened by distance. Of the 52 repeated names, all but one sit
within 550 m, and most within 100 m. Only Santo Antônio is two different
stations — metro Line 22 and a train line, 12.7 km apart. Rule: merge under
400 m, hand-review above, record every reviewed case in `notes`.

### Renames

`station_id` is frozen at first assignment and never follows a rename. The slug
may therefore read stale — `liberdade` for a station now called
Japão-Liberdade. The documentation says the id is opaque and must not be
parsed. That is the price of a key that survives in someone's saved analysis.

`station_name` always shows the current name, applied to the whole history, as
the pipeline does today. Superseded names live in the alias table.

### Guardrail

The refresh aborts on a station name absent from the alias table. The error
distinguishes the two cases: add the variant to `dim_station_alias.csv`
pointing at the existing `station_id` when a station was renamed, or add a row
to `dim_station.csv` when a station opened. A new station must stop the
pipeline, not appear unmapped.

### Wiring

`station_id` joins into both station demand tables and the station geometry
table. `station_code` moves onto the geometry table, where a per-station
attribute belongs, and stays in the daily table.

Open item for the review: Line 4's República appears in `station_averages` but
not in `station_daily`. The crosswalk will show whether that is a source gap or
a name variant.

## Phase 4 — Renames and unshipping

| Old | New |
|---|---|
| `passengers_entrance` | `line_entries_monthly` |
| `passengers_transported` | `line_transported_monthly` |
| `station_averages` | `station_entries_monthly` |
| `station_daily` | `station_entries_daily` |
| `lines` | `rail_lines` |
| `stations` | `rail_stations` |
| `station_inauguration` | unshipped |
| `calendar_spo`, `metro_colors` | unchanged |

`lines` and `stations` are renamed because they shadow common user variables
and `graphics::lines()`; `lapply(x, lines)` fails today. `rail_` rather than
`metro_` because both tables carry CPTM train lines.

The demand tables are renamed because each was named on a different axis —
measure, statistic, frequency. `<grain>_<measure>_<freq>` names them all the
same way.

`station_inauguration` leaves `data/` and `_pkgdown.yml`; the builder and the
CSV stay under `data-raw/`. Reasons: no row is `verified`, and three Line 4
stations that opened inside the data window (Fradique Coutinho 2014,
Higienópolis-Mackenzie 2018, São Paulo-Morumbi 2018) are flagged
`pre_data_window = TRUE` with no date, so the ramp-up filter the table exists
for silently misses them. `phase`, `notes` and `verified` are curation columns,
not user columns. Revisit as an `opened` column on `rail_stations` once the
dates are checked.

Touched beyond package `R/`: `_pkgdown.yml`, all three vignettes, `README.Rmd`,
every test file, `data-raw/scripts/vignette_plots.R`, and the five
`dashboard/*.R` scripts.

**Release assets.** Vintages published before 2.0.0 carry the old asset names,
so `read_metro_demand()` needs a legacy map from new name to old asset for tags
up to `data-2026-09`. The hard break covers the R API, not archived releases;
without the map, pinned analyses fail.

## Phase 5 — Cache API

Two exported functions.

- `metrosp_cache()` returns the listing; its print method shows the directory.
  Replaces `metrosp_cache_dir()` and `metrosp_cache_list()`.
- `metrosp_cache_clear(vintage = NULL)` unchanged.

Delete the consent machinery: the marker file, `cache_consented()`,
`ask_cache_consent()` and `metrosp_cache_enable()`. Default to
`tools::R_user_dir("metrosp", "cache")`. Opting out keeps working through
`cache = FALSE`, `options(metrosp.cache_dir = )` and `METROSP_CACHE_DIR`.

CRAN policy permits an `R_user_dir` cache without consent when it stays small
and is actively managed. Confirm the current wording before deleting the code,
even though the package ships via R-universe.

`test-cache.R` shrinks accordingly.

## Phase 6 — Release

- `METROSP_FREEZE=true`, then `devtools::document()`
- Regenerate `schema.json` via `write_schema(tar_read(datasets))`
- Update the data-vintage line in the `passengers_entrance` roxygen block
- Version 2.0.0, NEWS entry leading with the full old-to-new mapping table and
  the line-99 removal
- Update `CLAUDE.md`: the dataset table, the naming section, the cache-API
  bullet, the `station_inauguration` gap note
- Follow-up in `metrosp-explorer`, which reads these release assets and breaks
  on the renamed ones

## Sequencing

Phases 1–4 change `data/*.rda` and each ends with a refreeze. Only phase 2
changes `schema.json`. Renames come after the semantic work so the large
mechanical diff stays separate.

## Deferred

- `opened` date on `rail_stations`, once the inauguration dates are verified
- `metro_colors` stays as is: an auxiliary vector for maps and plots, not a
  join table
