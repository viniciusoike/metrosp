# Where metrosp stores downloaded data

Resolves the directory that
[`read_metro_demand()`](https://viniciusoike.github.io/metrosp/reference/read_metro_demand.md)
downloads into. The persistent location is
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html); until you
consent to it, downloads go to a session-temporary directory instead.

## Usage

``` r
metrosp_cache_dir(create = FALSE)
```

## Arguments

- create:

  Whether to create the directory if it does not exist.

## Value

The cache directory path, as a string.

## Details

The resolution order is the `metrosp.cache_dir` option, then the
`METROSP_CACHE_DIR` environment variable, then the persistent user cache
once consent is on record, then a temporary directory.

## See also

Other cache:
[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md),
[`metrosp_cache_enable()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_enable.md),
[`metrosp_cache_list()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_list.md)

## Examples

``` r
metrosp_cache_dir()
#> [1] "/tmp/Rtmp0u4APV/metrosp-cache"
```
