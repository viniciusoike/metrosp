# List cached datasets

List cached datasets

## Usage

``` r
metrosp_cache_list()
```

## Value

A data frame with one row per cached file, holding the vintage tag, file
name, size in bytes, and modification time. Zero rows when the cache is
empty.

## See also

Other cache:
[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md),
[`metrosp_cache_dir()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_dir.md),
[`metrosp_cache_enable()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_enable.md)

## Examples

``` r
metrosp_cache_list()
#> [1] vintage  file     bytes    modified
#> <0 rows> (or 0-length row.names)
```
