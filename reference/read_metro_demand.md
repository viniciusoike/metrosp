# Read Metro SP demand data

Reads one of the four passenger demand datasets, preferring the most
recently published version over the frozen snapshot bundled with the
package. Published data lives in the repository's GitHub releases and is
rebuilt from the upstream sources on every pipeline run.

## Usage

``` r
read_metro_demand(
  dataset = c("passengers_entrance", "passengers_transported", "station_averages",
    "station_daily"),
  source = c("auto", "cache", "remote", "bundled"),
  vintage = "latest",
  cache = TRUE,
  quiet = FALSE
)
```

## Arguments

- dataset:

  Dataset to read. One of `"passengers_entrance"`,
  `"passengers_transported"`, `"station_averages"`, or
  `"station_daily"`.

- source:

  Where to read from.

  - `"auto"` (default) uses the cache, downloads when it is stale or
    empty, and falls back to the bundled snapshot with a warning if the
    download fails.

  - `"cache"` reads only what is already on disk and errors otherwise.

  - `"remote"` downloads and errors if that fails.

  - `"bundled"` reads the frozen snapshot and never touches the network.

- vintage:

  Which published batch to read. `"latest"` tracks the rolling release;
  a year-month string such as `"2026-08"` pins an immutable batch.

- cache:

  Whether to write downloads to
  [`metrosp_cache_dir()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_dir.md).

- quiet:

  Whether to suppress progress messages.

## Value

A data frame. See
[passengers_entrance](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md),
[passengers_transported](https://viniciusoike.github.io/metrosp/reference/passengers_transported.md),
[station_averages](https://viniciusoike.github.io/metrosp/reference/station_averages.md),
and
[station_daily](https://viniciusoike.github.io/metrosp/reference/station_daily.md)
for the column definitions, which are identical across sources.

## Details

Only the demand datasets are published separately. The reference
datasets
([lines](https://viniciusoike.github.io/metrosp/reference/lines.md),
[stations](https://viniciusoike.github.io/metrosp/reference/stations.md),
[station_inauguration](https://viniciusoike.github.io/metrosp/reference/station_inauguration.md),
[calendar_spo](https://viniciusoike.github.io/metrosp/reference/calendar_spo.md),
and
[metro_colors](https://viniciusoike.github.io/metrosp/reference/metro_colors.md))
do not change with new months, so read them directly.

Downloads verify the manifest's SHA-256 when the digest package is
installed and skip verification otherwise.

## See also

[`metrosp_cache_dir()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_dir.md)
and
[`metrosp_cache_clear()`](https://viniciusoike.github.io/metrosp/reference/metrosp_cache_clear.md)
for cache management.

## Examples

``` r
# The bundled snapshot needs no network access.
entrance <- read_metro_demand("passengers_entrance", source = "bundled")
head(entrance)
#> # A tibble: 6 × 9
#>   date       line_number metric_abb    value metric          metric_pt line_name
#>   <date>           <dbl> <chr>         <dbl> <chr>           <chr>     <chr>    
#> 1 2012-01-01           4 max         122637  Daily Peak      Máxima D… Yellow   
#> 2 2012-01-01           4 mdo          24663. Average on Sun… Média do… Yellow   
#> 3 2012-01-01           4 mdu          99340. Average on Bus… Média do… Yellow   
#> 4 2012-01-01           4 msa          48876. Average on Sat… Média do… Yellow   
#> 5 2012-01-01           4 total      2504294  Total           Total     Yellow   
#> 6 2012-02-01           4 max         131405  Daily Peak      Máxima D… Yellow   
#> # ℹ 2 more variables: line_name_pt <chr>, year <dbl>

if (FALSE) { # \dontrun{
# The most recently published build.
daily <- read_metro_demand("station_daily")

# A pinned vintage, for a reproducible analysis.
daily_aug <- read_metro_demand("station_daily", vintage = "2026-08")
} # }
```
