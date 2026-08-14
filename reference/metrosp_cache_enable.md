# Allow metrosp to cache data across sessions

Records consent to store downloaded datasets under
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html), so that
[`read_metro_demand()`](https://viniciusoike.github.io/metrosp/reference/read_metro_demand.md)
reuses them in later sessions instead of re-downloading into a temporary
directory.

## Usage

``` r
metrosp_cache_enable(persist = TRUE)
```

## Arguments

- persist:

  Set `FALSE` to withdraw consent and fall back to a session-temporary
  cache.

## Value

The resulting cache directory, invisibly.

## See also

Other cache:
[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md),
[`metrosp_cache_dir()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_dir.md),
[`metrosp_cache_list()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_list.md)

## Examples

``` r
if (FALSE) { # \dontrun{
metrosp_cache_enable()
} # }
```
