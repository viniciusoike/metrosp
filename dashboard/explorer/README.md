# metrosp explorer

Data-exploration dashboard for the [metrosp](https://github.com/viniciusoike/metrosp)
R data package — passenger demand for the São Paulo metro. This is a **hosted
standalone app**, deployed separately from the package (it is not shipped inside
it and is `.Rbuildignore`d).

Tabs: line-level demand (with KPIs and optional STL trend), per-station monthly +
daily series (with ramp-up shading), an interactive map (click a station to open
it), and dataset downloads (the package datasets verbatim, in CSV/Excel/GPKG/GeoJSON).

## Run locally

From the repository root:

```r
shiny::runApp("dashboard/explorer")
```

## Dependencies

```r
install.packages(c(
  "shiny", "bslib", "bsicons", "dplyr", "leaflet", "echarts4r",
  "sf", "htmltools", "htmlwidgets", "writexl", "readr",
  # optional: enables the STL trend overlay (degrades gracefully if absent)
  "trendseries"
))
# the data package itself (GitHub-only)
pak::pak("viniciusoike/metrosp")
```

## Deploy

The app directory is self-contained (`app.R`, `shared.R`, `www/`), so it deploys
as a unit:

```r
rsconnect::deployApp(
  appDir  = "dashboard/explorer",
  appName = "metrosp-explorer"
)
```

`rsconnect` infers the package set from the loaded namespaces. `metrosp` is
GitHub-only — make sure your deploy target can install from GitHub (set the
`remotes`/`pak` source), or vendor it. `trendseries` is on CRAN.

## Keeping shared files in sync

`shared.R` and `www/styles.css` are **copies** of `dashboard/shared.R` and
`dashboard/www/styles.css` — duplicated because deployment bundles only this
directory. They must not drift. Before deploying, run:

```r
source("dashboard/sync_check.R")   # errors if the copies differ from the originals
```

To pull the latest originals into this app dir:

```r
source("dashboard/sync_check.R"); sync_explorer_shared()
```
