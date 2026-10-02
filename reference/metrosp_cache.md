# Inspect cached Metro SP data

Lists the files downloaded by
[`read_metro_demand()`](https://viniciusoike.github.io/metrosp/reference/read_metro_demand.md).
The cache directory is resolved from the `metrosp.cache_dir` option,
then the `METROSP_CACHE_DIR` environment variable, and finally
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html). Printing
the result also shows the resolved directory.

## Usage

``` r
metrosp_cache()

# S3 method for class 'metrosp_cache'
print(x, ...)
```

## Arguments

- x:

  A cache listing returned by `metrosp_cache()`.

- ...:

  Additional arguments passed to the data-frame print method.

## Value

A data frame with one row per cached file, holding the vintage tag, file
name, size in bytes, and modification time. Zero rows when the cache is
empty.

`x`, invisibly.

## Details

Each read marks its vintage as used. A vintage left unused for 90 days
is deleted the next time
[`read_metro_demand()`](https://viniciusoike.github.io/metrosp/reference/read_metro_demand.md)
touches the cache.

## See also

[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md)
to remove cached files.

## Examples

``` r
metrosp_cache()
#> Cache directory: /home/runner/.cache/R/metrosp
#> [1] vintage  file     bytes    modified
#> <0 rows> (or 0-length row.names)
```
