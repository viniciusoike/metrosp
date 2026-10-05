# Delete cached Metro SP data

Delete cached Metro SP data

## Usage

``` r
metrosp_cache_clear(vintage = NULL)
```

## Arguments

- vintage:

  Vintage to remove, such as `"latest"` or `"2026-09"`. When `NULL`,
  removes every package-managed `data-latest` or `data-YYYY-MM` vintage
  directory. The cache root and unrelated files are preserved.

## Value

The number of files removed, invisibly.

## See also

[`metrosp_cache()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache.md)
to inspect cached files.

## Examples

``` r
# Point the cache at a temporary directory so the example leaves yours alone.
old <- options(metrosp.cache_dir = tempfile("metrosp-cache"))

metrosp_cache_clear("2026-09")
#> ℹ Nothing cached in /tmp/RtmpwjeFdJ/metrosp-cache1ead2f898d32.
metrosp_cache_clear()
#> ℹ Nothing cached in /tmp/RtmpwjeFdJ/metrosp-cache1ead2f898d32.

options(old)
```
