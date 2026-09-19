# Delete cached datasets

Delete cached datasets

## Usage

``` r
metrosp_cache_clear(vintage = NULL)
```

## Arguments

- vintage:

  Vintage to remove, such as `"latest"` or `"2026-09"`. When `NULL`,
  removes every cached vintage.

## Value

The number of files removed, invisibly.

## See also

[`metrosp_cache_dir()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_dir.md),
[`metrosp_cache_list()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_list.md).

## Examples

``` r
if (FALSE) { # \dontrun{
metrosp_cache_clear("2026-09")
metrosp_cache_clear()
} # }
```
