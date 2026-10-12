# Roadmap: Additional METRO SP Datasets

Internal planning document for candidate datasets from the METRO SP transparency
portal not yet in the package.

## Summary

The portal hosts 156 datasets. Most are contracts, governance PDFs, and
COVID-era procurement docs with no transit-analytics value. Six candidates
beyond the current `demanda`/`oferta` feed are worth considering.

## Tier 1 — Build next

### Infraestrutura - Dados de linhas e estações

- **URL:** `/dataset/infraestrutura-dados-de-linhas-e-estações`
- **Description:** Monthly CSVs (2019-2026) with line extension (km), station
  counts, and inauguration dates. Also includes station code (sigla) reference.
- **Format:** CSV (machine-readable), one file per month.
- **Why it fits:** Structured, monthly frequency, complements existing demand and
  service data. Adds supply-side infrastructure metrics (network length, station
  count over time).
- **Status:** FEASIBLE. Inspected CSVs from 2019, 2020, 2021, 2022, 2024.
- **Findings:**
  - Schema is stable across all years: same 14 rows of characteristics, 5 columns
    (Lines 1/2/3/15 + Rede).
  - Rows include: stations, extension (km), transfer stations, integration with
    Lines 4/5/CPTM, bus terminals, fleet cars, headway (s), max speed, commercial
    speed.
  - Files are latin1/cp1252 encoded (mojibake when read as UTF-8). Must specify
    encoding.
  - Brazilian decimal comma (e.g. `20,2`).
  - Footnote markers (`*`, `-` for N/A, `-------------------------` in 2024 fleet row).
  - One CSV per month, but only December snapshots are consistently named.
    Other months exist with varying filename patterns.
  - Latest available CSV is 2024; 2025-2026 are PDF-only.
- **Challenges remaining:**
  - Need to handle encoding + decimal comma + footnote markers.
  - Must discover/parse all monthly filenames (inconsistent naming).
  - 2025-2026 data is PDF-only — may need to skip or do one-time extraction.
- **Recommendation:** Proceed. This is the most tractable candidate.

## Tier 2 — Conditional (inspect PDFs first)

These datasets have potential but require a feasibility assessment before
committing. The primary risk is that most are PDF-only or have inconsistent
formats that would require heavy parsing.

### Pesquisa de Caracterização Socioeconômica dos Passageiros

- **URL:** `/dataset/pesquisa-de-caracterização-socioeconômica-dos-passageiros-e-seus-hábitos-de-viagem`
- **Description:** Biennial survey of passenger socioeconomic profile and travel
  habits. 8 PDFs.
- **Value:** Demographic complement to demand data. Could enable
  income-mode-choice analysis.
- **Challenge:** PDF-only. Would need table extraction or OCR. Survey microdata
  (if available) would be ideal but likely only published as summary tables.
- **Gate:** Inspect 1-2 PDFs. If they are clean data tables, proceed. If they
  are graphical reports, drop.

### Pesquisa de Mobilidade Urbana

- **URL:** `/dataset/pesquisa-de-mobilidade-urbana`
- **Description:** Smaller-sample interim survey to check for shifts in the full
  OD survey. 2 zips.
- **Value:** More frequent mobility snapshot than the biennial OD survey.
- **Challenge:** Zip contents unknown. May be PDF reports or microdata. If
  microdata, same weight/stratification complexity as the full OD survey.
- **Gate:** Unzip and inspect contents. If summary tables in clean format,
  proceed. If microdata with weights, assess whether to include or defer.

### Ouvidoria

- **URL:** `/dataset/ouvidoria`
- **Description:** Ombudsman/complaint records. 16 data files + 85 PDFs + 59
  docx.
- **Value:** Service quality signal. Complaint volume by category over time.
- **Challenge:** Mixed formats. Data files may be structured but inconsistent
  across 85 PDFs. Free-text fields likely. Requires NLP for categorization.
- **Gate:** Inspect the 16 data files. If they are structured and span a useful
  time range, this becomes viable. If they are monthly PDFs requiring OCR,
  deprioritize.

### Relatório de Expansão, Obras e Modernização

- **URL:** `/dataset/relatório-de-expansão-obras-e-modernização`
- **Description:** 92 PDFs on expansion works and modernization.
- **Value:** Qualitative + quantitative tracking of infrastructure projects.
- **Challenge:** 92 PDFs, no structured data format. Would need extraction of
  project status tables. High effort, uncertain yield.
- **Gate:** Inspect 2-3 PDFs. If they contain consistent tabular data on project
  milestones, consider a curated extraction. If they are narrative reports,
  drop.

### SIC - Serviço de Informações ao Cidadão

- **URL:** `/dataset/sic-serviço-de-informações-ao-cidadão`
- **Description:** Information access requests. 1 data file + 37 PDFs + 33 docx.
- **Value:** Low. Metrics on information requests are marginal for transit
  analysis.
- **Challenge:** Same mixed-format issues as Ouvidoria.
- **Gate:** Low priority. Only revisit if Ouvidoria proves tractable and there
  is demand.

### Canais de Atendimento - Gerência de Operações

- **URL:** `/dataset/canais-de-atendimento-gerência-de-operações`
- **Description:** Customer service channel statistics. 69 PDFs + 4 zips.
- **Value:** Moderate. Info on service desk usage, lost-and-found, accessibility
  services.
- **Challenge:** 69 PDFs. Unknown structure.
- **Gate:** Inspect 1-2 PDFs. Only if they contain clean monthly time series.

## Dropped

### Pesquisa Origem e Destino

- **URL:** `/dataset/pesquisa-origem-e-destino`
- **Reason:** Full OD survey is a standalone package. Microdata with sampling
  weights, stratification, and trip-level detail. Would need its own
  infrastructure (survey weights, expansion factors, geographic crosswalks).
  Out of scope for metrosp.

## Principles for inclusion

1. **Structured data preferred.** CSV/XLSX over PDF. PDF-only datasets require a
   strong justification.
2. **Time series over cross-section.** The package's value is in longitudinal
   data. One-off surveys are less useful.
3. **Complements existing datasets.** Demand + service + spatial + infrastructure
   is the core. New datasets should extend, not duplicate.
4. **Parsable without OCR.** If a dataset requires OCR as the primary extraction
   path, it is unlikely to be maintainable.
5. **Clear provenance.** The dataset must have a stable source URL and update
   cadence.
