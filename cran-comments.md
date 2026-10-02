# CRAN submission comments — metrosp 2.0.0

## Test environments

* Local: macOS aarch64 (Apple M), R 4.5.1
* GitHub Actions: macOS, Windows, and Ubuntu (R release), Ubuntu (R devel
  and oldrel-1)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Changes in this version

This is a major release with breaking changes. The exported datasets are
renamed to one naming convention, the demand datasets share one column
contract, and two data errors are fixed: METRO's network-total rows are
removed and the Line 5 operator is corrected. NEWS.md carries a migration
table from the 1.x names and columns.

The bundled datasets are a fixed snapshot. `read_metro_demand()` reads newer
data from the package's GitHub releases, so new months no longer require a
CRAN submission.

## Cache

`read_metro_demand()` caches downloads under `tools::R_user_dir("metrosp",
"cache")`. The cache holds a few small `.rds` files per monthly batch. Each
read deletes batches left unused for 90 days, and `metrosp_cache_clear()`
removes the rest. Examples, vignettes, and tests point the cache at a
temporary directory or do not download.

## URLs

`urlchecker::url_check()` may time out on
<https://geosampa.prefeitura.sp.gov.br/> and on the Insper Dataverse DOI
<https://doi.org/10.60873/FK2/UTGQ0I>. Both are the data sources and resolve
in a browser; the servers reject or throttle some automated requests.

## Downstream dependencies

None.
