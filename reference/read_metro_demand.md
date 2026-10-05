# Read Metro SP demand data

Reads one of the four passenger demand datasets, preferring the most
recently published version over the frozen snapshot bundled with the
package. Published data lives in the repository's GitHub releases and is
rebuilt from the upstream sources on every pipeline run.

## Usage

``` r
read_metro_demand(
  dataset = c("line_entries_monthly", "line_transported_monthly",
    "station_transported_monthly", "station_entries_daily"),
  source = c("auto", "cache", "remote", "bundled"),
  vintage = "latest",
  cache = TRUE,
  quiet = FALSE
)
```

## Arguments

- dataset:

  Dataset to read. One of `"line_entries_monthly"`,
  `"line_transported_monthly"`, `"station_transported_monthly"`, or
  `"station_entries_daily"`.

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
[line_entries_monthly](https://viniciusoike.github.io/metrosp/reference/line_entries_monthly.md),
[line_transported_monthly](https://viniciusoike.github.io/metrosp/reference/line_transported_monthly.md),
[station_transported_monthly](https://viniciusoike.github.io/metrosp/reference/station_transported_monthly.md),
and
[station_entries_daily](https://viniciusoike.github.io/metrosp/reference/station_entries_daily.md)
for the column definitions, which are identical across sources.

## Details

Only the demand datasets are published separately. The reference
datasets
([rail_lines](https://viniciusoike.github.io/metrosp/reference/rail_lines.md),
[rail_stations](https://viniciusoike.github.io/metrosp/reference/rail_stations.md),
[calendar_spo](https://viniciusoike.github.io/metrosp/reference/calendar_spo.md),
and
[metro_colors](https://viniciusoike.github.io/metrosp/reference/metro_colors.md))
do not change with new months, so read them directly.

Each vintage's `manifest.json` is cached and checked again once it is
older than `getOption("metrosp.cache_ttl")` seconds (six hours by
default). This applies to dated vintages too, so a month republished
after your first read is picked up; cached assets whose checksum is
unchanged are not downloaded again.

Downloads verify the manifest's SHA-256 when the digest package is
installed and skip verification otherwise.

## See also

[`metrosp_cache()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache.md)
and
[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md)
for cache management.

## Examples

``` r
# The bundled snapshot, read without touching the network.
head(read_metro_demand("line_entries_monthly", source = "bundled"))
#> # A tibble: 6 × 9
#>   date        year line_number line_name line_name_pt metric metric_name        
#>   <date>     <int>       <int> <chr>     <chr>        <chr>  <chr>              
#> 1 2012-01-01  2012           4 Yellow    Amarela      max    Daily Peak         
#> 2 2012-01-01  2012           4 Yellow    Amarela      mdo    Average on Sundays 
#> 3 2012-01-01  2012           4 Yellow    Amarela      mdu    Average on Busines…
#> 4 2012-01-01  2012           4 Yellow    Amarela      msa    Average on Saturda…
#> 5 2012-01-01  2012           4 Yellow    Amarela      total  Total              
#> 6 2012-02-01  2012           4 Yellow    Amarela      max    Daily Peak         
#> # ℹ 2 more variables: metric_name_pt <chr>, value <dbl>

# \donttest{
# Keep this example's downloads out of your persistent cache.
old <- options(metrosp.cache_dir = tempfile("metrosp-cache"))

# The most recently published data, cached between calls.
entrance <- read_metro_demand("line_entries_monthly")
#> ℹ Downloading line_entries_monthly.rds (12.1 KB).

# A monthly vintage, so an analysis can name the batch it used.
entrance_sep <- read_metro_demand(
  "line_entries_monthly",
  vintage = "2026-09"
)
#> ℹ Downloading passengers_entrance.rds (14.1 KB).

options(old)
# }
```
