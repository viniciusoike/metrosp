# CRAN submission comments — metrosp 0.2.0

## Test environments

* Local: macOS aarch64 (Apple M), R 4.5.1
* win-builder: R-devel (Windows Server 2022) — 0 errors, 0 warnings, 1 note

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility: NOTE
  New submission.

* Possibly misspelled words in DESCRIPTION: GeoSampa, Paulo, Sao.
  These are proper Portuguese geographic names (São Paulo, Brazil);
  GeoSampa is the name of the city's official geospatial data portal.
  All three words are listed in inst/WORDLIST.

## Downstream dependencies

None (new package).

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
