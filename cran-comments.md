# CRAN submission comments — metrosp 1.2.1

## Test environments

* Local: macOS aarch64 (Apple M), R 4.5.1
* win-builder: R-devel (Windows Server 2022, R-devel 2026-08-31) — 0 errors,
  0 warnings, 1 note

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility: NOTE
  Maintainer: 'Vinicius Oike <viniciusoike@gmail.com>'

* Possibly misspelled word in DESCRIPTION: Paulo.
  This is part of the proper geographic name São Paulo, Brazil, and is listed
  in inst/WORDLIST.

## Changes in this version

This update improves the dataset documentation, fixes data and pipeline issues,
and adds observations to the bundled static datasets. METRO has published
previously unavailable data for 2016–2017, and newer observations are now
included as well.

The long-term plan is to keep the lazy-loaded datasets as a frozen snapshot and
provide `read_metro_demand()` for users who need more up-to-date data. This
will let the package receive current data without requiring a new CRAN
submission every time the upstream sources are updated.

## Downstream dependencies

None.

## Notes for reviewers

* All datasets are lazy-loaded `.rda` files; the package contains no
  user-facing functions.
* Spatial datasets (`lines`, `stations`) require the `sf` package, which
  is listed in `Suggests`.
* Several Portuguese words and São Paulo Metro line names appear in
  documentation. These are added to `inst/WORDLIST`.
* Data sources: METRO SP transparency portal
  <https://transparencia.metrosp.com.br/dataset/demanda> and GeoSampa
  <https://geosampa.prefeitura.sp.gov.br/>.
