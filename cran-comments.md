# CRAN submission comments — metrosp 2.1.0

## Test environments

* Local: macOS aarch64 (Apple M), R 4.5.1, `R CMD check --as-cran` on the
  built source tarball, with vignettes built

## R CMD check results

0 errors | 0 warnings | 1 note

The note is from the incoming feasibility check: the URL
<https://transparencia.metrosp.com.br/dataset/demanda> returned HTTP 503 when
the check ran. The portal was showing a maintenance page at that time. It is the METRO transparency portal, the upstream source of the
demand data, and the same URL appears in the help pages for the four demand
datasets and in README.md.

## Changes in this version

The current CRAN version is 2.0.0. This release adds:

* `line_service_monthly`, a dataset of monthly minimum headway (seconds) and
  commercial speed (km/h) for Lines 1, 2, 3, and 15 from January 2021.
* `read_metro_service()`, which reads the published version of that dataset
  from the same GitHub releases and cache as `read_metro_demand()`.
* Lines 4 and 5 monthly data keep only months the Insper Dataverse feed covers
  day by day. Line 5 transported ends in July 2018 in
  `line_transported_monthly`. The bundled snapshot keeps these months until
  its next refreeze. NEWS.md lists each change.

## Title and Description

The Title changed from "São Paulo Metro Passenger Demand Data" to "São Paulo
Metro System Data". Until 2.0.0 the package held passenger demand only. This
release adds train service data (headway and commercial speed), which the old
title did not cover. The Description now names both and no longer lists each
dataset or a year range.

## Cache

`read_metro_demand()` and `read_metro_service()` cache downloads under
`tools::R_user_dir("metrosp", "cache")`. The cache holds a few small `.rds`
files per monthly batch. Each read deletes batches left unused for 90 days, and
`metrosp_cache_clear()` removes the rest. Examples, vignettes, and tests point
the cache at a temporary directory or do not download.

## URLs

`urlchecker::url_check()` may time out on
<https://geosampa.prefeitura.sp.gov.br/> and on the Insper Dataverse DOI
<https://doi.org/10.60873/FK2/UTGQ0I>. Both are data sources and resolve in a
browser; the servers reject or throttle some automated requests.

## Downstream dependencies

None.
