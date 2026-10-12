# Read Metro SP service data

Reads
[line_service_monthly](https://viniciusoike.github.io/metrosp/reference/line_service_monthly.md),
the minimum interval between trains and the commercial speed of each
METRO-operated line, preferring the most recently published version over
the frozen snapshot bundled with the package. It reads from the same
GitHub releases and cache as
[`read_metro_demand()`](https://viniciusoike.github.io/metrosp/reference/read_metro_demand.md).

## Usage

``` r
read_metro_service(
  source = c("auto", "cache", "remote", "bundled"),
  vintage = "latest",
  cache = TRUE,
  quiet = FALSE
)
```

## Arguments

- source:

  Where to read from.

  - `"auto"` (default) uses the cache, downloads when it is stale or
    empty, and falls back to the bundled snapshot with a warning if the
    download fails. When a stale manifest cannot be refreshed, it reads
    the cached copy with a warning instead.

  - `"cache"` reads only what is already on disk and errors otherwise.

  - `"remote"` downloads and errors if that fails.

  - `"bundled"` reads the frozen snapshot and never touches the network.

- vintage:

  Which published batch to read. `"latest"` tracks the rolling release;
  a year-month string such as `"2026-09"` reads the last batch published
  in that month. A month's batch can be republished until the month
  ends, so a monthly vintage is revisable rather than an exact pin.

- cache:

  Whether to store downloads in the persistent cache. Set to `FALSE` to
  use session-temporary storage instead.

- quiet:

  Whether to suppress progress messages.

## Value

A data frame. See
[line_service_monthly](https://viniciusoike.github.io/metrosp/reference/line_service_monthly.md)
for the column definitions, which are identical across sources.

## Details

Vintages published before metrosp 2.1.0 do not contain service data, and
reading one is an error.

## See also

[`read_metro_demand()`](https://viniciusoike.github.io/metrosp/reference/read_metro_demand.md)
for passenger demand, and
[`metrosp_cache()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache.md)
and
[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md)
for cache management.

## Examples

``` r
# The bundled snapshot, read without touching the network.
head(read_metro_service(source = "bundled"))
#> # A tibble: 6 × 9
#>   date        year line_number line_name line_name_pt metric  metric_name       
#>   <date>     <int>       <int> <chr>     <chr>        <chr>   <chr>             
#> 1 2021-01-01  2021           1 Blue      Azul         headway Minimum Interval …
#> 2 2021-01-01  2021           1 Blue      Azul         speed   Commercial Speed …
#> 3 2021-01-01  2021           2 Green     Verde        headway Minimum Interval …
#> 4 2021-01-01  2021           2 Green     Verde        speed   Commercial Speed …
#> 5 2021-01-01  2021           3 Red       Vermelha     headway Minimum Interval …
#> 6 2021-01-01  2021           3 Red       Vermelha     speed   Commercial Speed …
#> # ℹ 2 more variables: metric_name_pt <chr>, value <dbl>

# \donttest{
# Keep this example's downloads out of your persistent cache.
old <- options(metrosp.cache_dir = tempfile("metrosp-cache"))

# The most recently published data, cached between calls.
service <- read_metro_service()
#> ℹ Downloading line_service_monthly.rds (1.0 KB).

options(old)
# }
```
