# Data Dictionary

This vignette documents the core datasets shipped with `metrosp`. It
details what each dataset contains, where the data comes from, and the
caveats you should know before making any data analysis. For auxiliary
lookup tables (`metro_colors`, `station_inauguration`), see the help
pages (e.g.,
[`?metro_colors`](https://viniciusoike.github.io/metrosp/reference/metro_colors.md)).

## Overview

This package ships four core datasets: two of them measure passengers at
the line level, and two measure passengers at the station level. The
datasets are organized by line and by station, respectively.

The key aspects of the datasets are described below. Each further
section contains a more detailed description of each dataset.

| Dataset | Description | Unit | Time span | Frequency | Package name |
|----|----|----|----|----|----|
| Passenger entries by line | Passenger entries, measured by the station’s turnstiles, aggregated by day-type metrics. | Passengers | 2012–2026 | Monthly | `passengers_entrance` |
| Transported passengers per line | Number of transported passengers, measured by the station’s turnstiles plus transfers between lines at interchange stations. | Thousand passengers | 2017–2026 | Monthly | `passengers_transported` |
| Station-level averages | Average business day passenger entries per station, aggregated by month. | Passengers | 2012–2026 | Monthly | `station_averages` |
| Station-level daily | Daily passenger entries at each station | Passengers | 2012–2026 | Daily | `station_daily` |

The core datasets bundled with the package are:
`passengers_transported`, `passengers_entrance`, `station_averages`, and
`station_daily`. All of these are measured in **individual passengers**
and contain information for all metro lines, with the exception of
`passengers_transported`, which is measured in **thousands of
passengers** and contains no information for Line 4 and only limited
information for Line 5.

Across all datasets, “passenger entry” means a passenger that crossed
the station’s turnstile gates; a “transported passenger”, on the other
hand, is a passenger that either entered the station by passing through
the turnstile gates, or that changed between lines at an interchange
station. This means that the number of transported passengers is always
equal or greater than the number of passenger entries.

The table above contains at least two important simplifications. The
time span availability of the data varies by line. Also, the producer of
the information changes over time: Line 5’s initial operation was
managed by the METRO company and was later passed on to ViaMobilidade.
These will be discussed in more detail in the next sections.

## Data producers

This package aggregates and harmonizes data from three different data
producers: 1) the METRO transparency website; 2) Insper’s Dataverse; and
3) São Paulo’s public geodata repository, GeoSampa.

Note that I use the term **data producer** instead of source to
emphasize the data processing that this package ships. A significant
amount of cleaning and processing is needed to combine these datasets.
The full data pipeline is orchestrated with the `targets` package and is
currently hosted in the package’s [GitHub
repository](https://github.com/viniciusoike/metrosp/tree/main/data-raw)[^1].

| Dataset | Granularity | Producer | Time span | Line Coverage |
|----|----|----|----|----|
| `passengers_entrance` | line $`\times`$ month $`\times`$ metric | METRO + Dataverse | 2012–2026 | All |
| `passengers_transported` | line $`\times`$ month $`\times`$ metric | METRO | 2017–2026 | Lines 1, 2, 3, 5, and 15 |
| `station_averages` | station $`\times`$ month | METRO + Dataverse | 2012–2026 | All |
| `station_daily` | station $`\times`$ day | METRO + Dataverse | 2012–2026 | All |
| `lines` | line (spatial) | GeoSampa | Last updated: 2026/04/10 | All |
| `stations` | station (spatial) | GeoSampa | Last updated: 2026/04/10 | All |

### METRO SP transparency portal

The Companhia do Metropolitano de São Paulo (a.k.a. METRÔ) publishes
monthly demand reports at its [data transparency
portal](https://transparencia.metrosp.com.br/dataset/demanda). Reports
cover Lines 1 (Azul/Blue), 2 (Verde/Green), 3 (Vermelha/Red), 5
(Lilás/Lilac, until Jul 2018), and 15 (Prata/Silver), and are available
from October 2017 onward. Values are reported in thousands (*milhares*).

Before 2020, these monthly reports were published as monthly PDF and
`csv` files. Each individual file contains a table (metric) from a
specific year-month. There were three pieces of information available
for each month: 1) the average number of entries in each station, on
business days (`station_averages`); 2) the number of passenger entries
per line (`passengers_entrance`); and 3) the number of transported
passengers per line (`passengers_transported`).

From 2020 onwards, the monthly reports started to be published in annual
PDF and `csv` files that are updated monthly. Also, a new report was
published that contained the daily number of entrances per station
(`station_daily`).

Both the PDF files and the `csv` files are very poorly structured. In
fact, this is partly the reason why `metrosp` was created in the first
place. While this data is public, it’s very hard to access properly. The
format, encoding, and patterns of the `csv` files change randomly and
require a very specific import strategy for each year and report. This
process has lead to several unintended data processing errors. The
current version of the dataset has been thoroughly cleaned and tested
(plus, several sanity checks have been added to the data pipeline). Even
so, some errors might have slipped through and if you encounter one,
please open an issue on the [GitHub
repository](https://github.com/viniciusoike/metrosp/issues).

Going back to the datasets, it’s important to note that each monthly
passenger report breaks demand into five day-type metrics: total
(monthly aggregate), average on business days, average on Saturdays,
average on Sundays, and daily peak (maximum within the month). These are
aggregated by METRO.

Daily station-level data (one row per station per day) is available from
2020 onwards. Stations with integrations to other lines always present
the total daily entrance plus the transfers from other lines. For
example, Paraíso from Line 1 presents all station entries plus transfers
from Line 2. Paraíso from Line 2 presents all entries in the station
plus transfers from Line 1.

Finally, METRO produces data for lines 1, 2, 3, 5, and 15. Line 5 was
initially operated by METRO SP and later passed on to ViaMobilidade (see
below).

### Insper Dataverse

Lines 4 (Amarela/Yellow, operated by ViaQuatro) and 5 (Lilás/Lilac,
operated by ViaMobilidade from August 2018) are not published on the
METRO portal. Ridership data for these lines comes from the [Insper
Dataverse](https://doi.org/10.60873/FK2/UTGQ0I), starting January 2012
(Line 4) and August 2018 (Line 5). Transported counts are **not
available** for Lines 4 or 5.

Unlike the METRO data, Dataverse counts are not rounded to the nearest
thousand. For consistency, METRO values are multiplied by 1,000 during
the ETL so that datasets, that combine both sources, report individual
passengers.

The `station_averages` dataset for Lines 4 and 5 is derived from
`station_daily` using the `bizdays` package. Specifically, we use the
“Brazil/ANBIMA” calendar, which tracks days when the B3 stock exchange
operates in São Paulo. This closely mirrors the city’s business-day
schedule; however, since 2022 B3 only closes for national holidays (not
municipal or state holidays such as the 9th of July). A more precise São
Paulo business-day calendar is planned for a future release.

### GeoSampa

Spatial geometries for metro and commuter train (CPTM) lines and
stations come from [GeoSampa](https://geosampa.prefeitura.sp.gov.br/),
the City of São Paulo’s open geospatial platform. The data includes both
currently operating infrastructure and planned future expansions.

## Core datasets

### `passengers_entrance`

This table shows the number of monthly passenger entries aggregated by
metro line and day-type metrics.

------------------------------------------------------------------------

#### Columns and definitions

| Column | Type | Description |
|----|----|----|
| `date` | Date | First day of the month |
| `line_number` | integer | Line identifier (1, 2, 3, 4, 5, 15, or 99 for network total) |
| `metric_abb` | character | Metric code: `total`, `mdu`, `msa`, `mdo`, `max` |
| `value` | numeric | Passenger count |
| `metric` | character | Metric label in English |
| `metric_pt` | character | Metric label in Portuguese |
| `line_name` | character | Line color in English |
| `line_name_pt` | character | Line color in Portuguese |
| `year` | integer | Calendar year |

Column descriptions and column types {.table .caption-top}

The table below shows the first few rows of each column.

``` r

dplyr::glimpse(passengers_entrance)
#> Rows: 3,830
#> Columns: 9
#> $ date         <date> 2012-01-01, 2012-01-01, 2012-01-01, 2012-01-01, 2012-01-…
#> $ line_number  <dbl> 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, …
#> $ metric_abb   <chr> "max", "mdo", "mdu", "msa", "total", "max", "mdo", "mdu",…
#> $ value        <dbl> 48112.00, 4932.68, 19867.93, 9775.25, 2504294.00, 53328.0…
#> $ metric       <chr> "Daily Peak", "Average on Sundays", "Average on Business …
#> $ metric_pt    <chr> "Máxima Diária", "Média dos Domingos", "Média dos Dias Út…
#> $ line_name    <chr> "Yellow", "Yellow", "Yellow", "Yellow", "Yellow", "Yellow…
#> $ line_name_pt <chr> "Amarela", "Amarela", "Amarela", "Amarela", "Amarela", "A…
#> $ year         <dbl> 2012, 2012, 2012, 2012, 2012, 2012, 2012, 2012, 2012, 201…
```

This table is organized by day-type metrics that are defined below.

#### Metrics

| Code    | English                       | Portuguese           |
|---------|-------------------------------|----------------------|
| `total` | Total passengers in the month | Total                |
| `mdu`   | Average on business days      | Média dos Dias Úteis |
| `msa`   | Average on Saturdays          | Média dos Sábados    |
| `mdo`   | Average on Sundays            | Média dos Domingos   |
| `max`   | Daily peak                    | Máxima Diária        |

Metric definitions {.table .caption-top}

#### Time coverage by line

The time coverage of this dataset varies by line.

![Horizontal bar chart showing each metro line's data coverage window in
the passengers_entrance dataset. Lines 1, 2, 3, 5, and 15 run from
October 2017 to April 2026; Line 4 runs from January 2012 to April
2026.](../reference/figures/timespan_passengers_entrance.png)

Time coverage by line for the passengers_entrance dataset

| Line | Source | From | To |
|----|----|----|----|
| 1 – Blue | METRO portal | Oct 2017 | present |
| 2 – Green | METRO portal | Oct 2017 | present |
| 3 – Red | METRO portal | Oct 2017 | present |
| 4 – Yellow | Dataverse | Jan 2012 | present |
| 5 – Lilac | METRO (Oct 2017–Jul 2018), Dataverse (Aug 2018+) | Oct 2017 | present |
| 15 – Silver | METRO portal | Oct 2017 | present |
| 99 – System | METRO portal | Oct 2017 | present |

Time coverage by line {.table .caption-top}

### `passengers_transported`

This table shows the number of monthly passengers transported,
aggregated by metro line and day-type metric. This counts both the
number of passengers that enter the station, by passing through the
turnstile gates, as well as the number of passengers changing between
lines.

------------------------------------------------------------------------

#### Columns and definitions

| Column | Type | Description |
|----|----|----|
| `date` | Date | First day of the month |
| `line_number` | integer | Line identifier (1, 2, 3, 5, 15, or 99 for network total) |
| `metric_abb` | character | Metric code: `total`, `mdu`, `msa`, `mdo`, `max` |
| `value` | numeric | Passenger count (in thousands) |
| `metric` | character | Metric label in English |
| `metric_pt` | character | Metric label in Portuguese |
| `line_name` | character | Line color in English |
| `line_name_pt` | character | Line color in Portuguese |
| `year` | integer | Calendar year |

Column descriptions and column types {.table .caption-top}

The table below shows the first few rows of each column.

``` r

dplyr::glimpse(passengers_transported)
#> Rows: 2,630
#> Columns: 9
#> $ date         <date> 2017-10-01, 2017-10-01, 2017-10-01, 2017-10-01, 2017-10-…
#> $ line_number  <dbl> 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 5, 5, 5, 5, …
#> $ metric_abb   <chr> "max", "mdo", "mdu", "msa", "total", "max", "mdo", "mdu",…
#> $ value        <dbl> 1506, 422, 1432, 788, 35446, 718, 179, 696, 301, 16637, 1…
#> $ metric       <chr> "Daily Peak", "Average on Sundays", "Average on Business …
#> $ metric_pt    <chr> "Máxima Diária", "Média dos Domingos", "Média dos Dias Út…
#> $ line_name    <chr> "Blue", "Blue", "Blue", "Blue", "Blue", "Green", "Green",…
#> $ line_name_pt <chr> "Azul", "Azul", "Azul", "Azul", "Azul", "Verde", "Verde",…
#> $ year         <dbl> 2017, 2017, 2017, 2017, 2017, 2017, 2017, 2017, 2017, 201…
```

This dataset uses the same day-type metrics as `passengers_entrance`
(see Metrics above).

#### Time coverage by line

The time coverage of this dataset varies by line.

![Horizontal bar chart showing each metro line's data coverage window in
the passengers_transported dataset. Lines 1, 2, 3, and 15 run from
October 2017 to April 2026. Line 5 only covers October 2017 to August
2018. Line 4 has no bar at all, showing it is entirely absent from this
dataset.](../reference/figures/timespan_passengers_transported.png)

Time coverage by line for the passengers_transported dataset

| Line        | Source       | From     | To       |
|-------------|--------------|----------|----------|
| 1 – Blue    | METRO portal | Oct 2017 | present  |
| 2 – Green   | METRO portal | Oct 2017 | present  |
| 3 – Red     | METRO portal | Oct 2017 | present  |
| 5 – Lilac   | METRO portal | Oct 2017 | Aug 2018 |
| 15 – Silver | METRO portal | Oct 2017 | present  |
| 99 – System | METRO portal | Oct 2017 | present  |

Time coverage by line {.table .caption-top}

Line 4 is absent entirely. The Dataverse source does not include
transported counts for Lines 4 or 5.

### `station_averages`

Monthly average weekday passenger entries per station.

------------------------------------------------------------------------

#### Columns and definitions

| Column          | Type      | Description                            |
|-----------------|-----------|----------------------------------------|
| `date`          | Date      | First day of the month                 |
| `line_number`   | integer   | Line identifier                        |
| `station_name`  | character | Full station name                      |
| `avg_passenger` | numeric   | Average weekday (business day) entries |
| `line_name`     | character | Line color in English                  |
| `line_name_pt`  | character | Line color in Portuguese               |
| `year`          | integer   | Calendar year                          |

Column descriptions and column types {.table .caption-top}

The table below shows the first few rows of each column.

``` r

dplyr::glimpse(station_averages)
#> Rows: 9,415
#> Columns: 7
#> $ date          <date> 2012-01-01, 2012-01-01, 2012-01-01, 2012-01-01, 2012-01…
#> $ line_number   <dbl> 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,…
#> $ station_name  <chr> "Butantã", "Faria Lima", "Luz", "Paulista", "Pinheiros",…
#> $ avg_passenger <dbl> 37066.82, 31989.09, 100889.32, 127844.59, 97537.45, 9919…
#> $ line_name     <chr> "Yellow", "Yellow", "Yellow", "Yellow", "Yellow", "Yello…
#> $ line_name_pt  <chr> "Amarela", "Amarela", "Amarela", "Amarela", "Amarela", "…
#> $ year          <dbl> 2012, 2012, 2012, 2012, 2012, 2012, 2012, 2012, 2012, 20…
```

Only the weekday average metric is available at the station level. For
line-level data with all five metrics, see `passengers_entrance`.

#### Time coverage by line

The time coverage of this dataset varies by line.

![Horizontal bar chart showing each metro line's data coverage window in
the station_averages dataset, aggregated by line. Lines 1, 2, 3, 5, and
15 run from October 2017 to April 2026; Line 4 runs from January 2012 to
April 2026.](../reference/figures/timespan_station_averages.png)

Time coverage by line for the station_averages dataset

| Line | Source | From | To |
|----|----|----|----|
| 1 – Blue | METRO portal | Oct 2017 | present |
| 2 – Green | METRO portal | Oct 2017 | present |
| 3 – Red | METRO portal | Oct 2017 | present |
| 4 – Yellow | Dataverse | Jan 2012 | present |
| 5 – Lilac | METRO (Oct 2017–Jul 2018), Dataverse (Aug 2018+) | Oct 2017 | present |
| 15 – Silver | METRO portal | Oct 2017 | present |

Time coverage by line {.table .caption-top}

### `station_daily`

Daily passenger entries at each station.

------------------------------------------------------------------------

#### Columns and definitions

| Column | Type | Description |
|----|----|----|
| `date` | Date | Date of observation |
| `line_number` | integer | Line identifier |
| `station_name` | character | Full station name |
| `passengers` | numeric | Daily passenger entries |
| `line_name` | character | Line color in English |
| `line_name_pt` | character | Line color in Portuguese |
| `station_code` | character | Three-letter METRO abbreviation (`NA` for Lines 4–5) |
| `year` | integer | Calendar year |

Column descriptions and column types {.table .caption-top}

The table below shows the first few rows of each column.

``` r

dplyr::glimpse(station_daily)
#> Rows: 228,802
#> Columns: 8
#> $ date         <date> 2012-01-01, 2012-01-01, 2012-01-01, 2012-01-01, 2012-01-…
#> $ line_number  <dbl> 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, …
#> $ station_name <chr> "Butantã", "Faria Lima", "Luz", "Paulista", "Pinheiros", …
#> $ passengers   <dbl> 7742, 4737, 695, 2277, 332, 25317, 21930, 3923, 14356, 39…
#> $ line_name    <chr> "Yellow", "Yellow", "Yellow", "Yellow", "Yellow", "Yellow…
#> $ line_name_pt <chr> "Amarela", "Amarela", "Amarela", "Amarela", "Amarela", "A…
#> $ station_code <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, N…
#> $ year         <dbl> 2012, 2012, 2012, 2012, 2012, 2012, 2012, 2012, 2012, 201…
```

#### Time coverage by line

The time coverage of this dataset varies by line.

![Horizontal bar chart showing each metro line's data coverage window in
the station_daily dataset, aggregated by line. Lines 1, 2, 3, and 15 run
from January 2020 to April 2026; Line 4 runs from January 2012 to April
2026; Line 5 runs from August 2018 to April
2026.](../reference/figures/timespan_station_daily.png)

Time coverage by line for the station_daily dataset

| Line        | Source       | From     | To      |
|-------------|--------------|----------|---------|
| 1 – Blue    | METRO portal | Jan 2020 | present |
| 2 – Green   | METRO portal | Jan 2020 | present |
| 3 – Red     | METRO portal | Jan 2020 | present |
| 4 – Yellow  | Dataverse    | Jan 2012 | present |
| 5 – Lilac   | Dataverse    | Aug 2018 | present |
| 15 – Silver | METRO portal | Jan 2020 | present |

Time coverage by line {.table .caption-top}

## Spatial datasets

The `lines` and `stations` datasets are `sf` objects in WGS 84
(EPSG:4326), sourced from [GeoSampa](#source-geosampa). Both include
currently operating and planned future infrastructure for METRO SP and
CPTM.

### lines

``` r

dplyr::glimpse(lines)
#> Rows: 55
#> Columns: 7
#> $ status       <chr> "current", "current", "current", "current", "current", "c…
#> $ company_name <chr> "Metrô", "Metrô", "Metrô", "Metrô", "Metrô", "ViaQuatro",…
#> $ line_number  <dbl> 1, 2, 3, 5, 15, 4, 2, 2, 2, 15, 15, 19, 20, 22, 16, 4, 5,…
#> $ type         <chr> "metro", "metro", "metro", "metro", "metro", "metro", "me…
#> $ line_name_pt <chr> "Azul", "Verde", "Vermelha", "Lilás", "Prata", "Amarela",…
#> $ line_name    <chr> "Blue", "Green", "Red", "Lilac", "Silver", "Yellow", "Gre…
#> $ geom         <GEOMETRY [°]> LINESTRING (-46.60291 -23.4..., LINESTRING (-46.…
```

| Column | Type | Description |
|----|----|----|
| `line_number` | integer | Official line number |
| `line_name_pt` | character | Line color in Portuguese |
| `line_name` | character | Line color in English |
| `company_name` | character | Operator (Metrô, ViaQuatro, ViaMobilidade, CPTM) |
| `type` | character | `"metro"` (underground) or `"train"` (CPTM commuter rail) |
| `status` | character | `"current"` (operating) or `"future"` (planned) |
| `geometry` | LINESTRING | Route geometry |

### stations

``` r

dplyr::glimpse(stations)
#> Rows: 407
#> Columns: 8
#> $ type         <chr> "metro", "metro", "metro", "metro", "metro", "metro", "me…
#> $ status       <chr> "current", "current", "current", "current", "current", "c…
#> $ company_name <chr> "Metrô", "Metrô", "Metrô", "Metrô", "Metrô", "Metrô", "Me…
#> $ station_name <chr> "Ana Rosa", "Armênia", "Carandiru", "Conceição", "Jabaqua…
#> $ line_number  <int> 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, …
#> $ line_name    <chr> "Blue", "Blue", "Blue", "Blue", "Blue", "Blue", "Blue", "…
#> $ line_name_pt <chr> "Azul", "Azul", "Azul", "Azul", "Azul", "Azul", "Azul", "…
#> $ geom         <POINT [°]> POINT (-46.63845 -23.58126), POINT (-46.62934 -23.5…
```

| Column         | Type      | Description               |
|----------------|-----------|---------------------------|
| `station_name` | character | Station name (title case) |
| `line_number`  | integer   | Line number               |
| `line_name_pt` | character | Line color in Portuguese  |
| `line_name`    | character | Line color in English     |
| `company_name` | character | Operator                  |
| `type`         | character | `"metro"` or `"train"`    |
| `status`       | character | `"current"` or `"future"` |
| `geometry`     | POINT     | Station location          |

Transfer stations (e.g., Sé, Paraíso, Ana Rosa) appear once per line
they serve.

## Auxiliary datasets

The package also ships a convenience lookup vector with colors for each
line.

- **`metro_colors`** — named character vector of official hex color
  codes for the six lines with ridership data (e.g.,
  `metro_colors["Blue"]` returns `"#171796"`). Useful for consistent
  plot styling with `scale_color_manual()`.

Line numbers and their Portuguese/English names are already included as
columns on every passenger and station dataset, and the full network
line list (including planned and CPTM lines) is available in `lines`.

## Data notes and caveats

### Entrance vs. transported

The METRO source files define these terms as:

- **Entrada de passageiros** (*passenger entries*): passengers entering
  through the turnstile gates (*linha de bloqueios*). This is a
  station-level measurement.
- **Passageiros transportados** (*passengers transported*): the sum of
  turnstile entries **plus** transfer passengers between lines at
  interchange stations (e.g. Sé, Paraíso, Ana Rosa, and Vila Prudente).
  This is a system-level measurement that better captures total demand
  but double-counts passengers who transfer.

The original Portuguese footnote reads:

> Corresponde à soma das entradas pela linha de bloqueios com as
> transferências entre linhas nas estações \[…\].

### Station-level transfer counting

At interchange stations, the METRO source reports separate figures per
line. For example, at Paraíso (Lines 1 and 2):

- Line 1 figure = passengers boarding Line 1 + transfers from Line 2
- Line 2 figure = passengers boarding Line 2 + transfers from Line 1

This means station-level totals at interchange stations are **not**
double-counted within a single line, but summing across lines at the
same interchange would overcount. The affected stations and their lines
are listed below. Note that some of these stations have interchange with
the train (CPTM) network.

| Station               | Lines                |
|-----------------------|----------------------|
| Ana Rosa              | 1, 2                 |
| Luz                   | 1, 4, 10, 11 (CPTM)  |
| Paraíso               | 1, 2                 |
| Santa Cruz            | 1, 5                 |
| Sé                    | 1, 3                 |
| Chácara Klabin        | 2, 5                 |
| Consolação            | 2, 4                 |
| Tamanduateí           | 2, 10 (CPTM)         |
| Vila Prudente         | 2, 15                |
| Brás                  | 3, 10, 11, 12 (CPTM) |
| Corinthians-Itaquera  | 3, 11 (CPTM)         |
| Palmeiras-Barra Funda | 3, 7, 8 (CPTM)       |
| República             | 3, 4                 |
| Tatuapé               | 3, 11, 12 (CPTM)     |

Interchange stations and their lines {.table .caption-top}

### Line 5 ownership change

Line 5 (Lilás) was originally operated by METRO SP. On August 4, 2018,
it was handed over to ViaMobilidade under a concession contract. This
affects the data in two ways:

1.  **Source switch**: from October 2017 through July 2018, Line 5 data
    comes from the METRO transparency portal. From August 2018 onward,
    it comes from the Insper Dataverse (ViaMobilidade/Insper
    partnership).
2.  **Transported counts end**: the METRO portal has Line 5 transported
    data through August 2018, the month of the ownership handover. The
    Dataverse does not provide transported counts, so
    `passengers_transported` has no Line 5 data afterward.

### Station openings during the data window

Several stations opened during the time coverage of the datasets. This
creates both step changes in data as well as ramping up periods when the
station or line operates at a much lower level. Several of the METRO
lines operate at reduced rates during their first months: this includes
stations/lines that operate in shorter time-windows and days (e.g. some
close on weekends for testing).

A comprehensive yet still incomplete list of stations, and their opening
dates, is available in the `station_inauguration` dataset (see
[`?station_inauguration`](https://viniciusoike.github.io/metrosp/reference/station_inauguration.md)).

#### Line 15 Sunday closures

In February and March 2018, Line 15 (Prata) was closed on Sundays for
control system testing. Sunday averages (`mdo`) for these months reflect
zero or near-zero ridership, which is a testing artifact rather than
demand.

### Rounding in station averages

The METRO source rounds station-level averages to the nearest thousand.
The sum of individual station values may not equal the line total due to
this rounding. The original note states:

> O total da linha pode ser diferente da soma das estações devido ao
> arredondamento.

### Lines 4 and 5: station codes

The `station_code` column (three-letter abbreviation) is only available
for METRO-operated lines (1, 2, 3, 15). Lines 4 and 5 have
`station_code = NA` because these abbreviations are internal to METRO SP
and not used by ViaQuatro/ViaMobilidade.

### 2017 partial year

Only October through December 2017 is available. The METRO transparency
portal does not provide machine-readable data before October 2017
(earlier months exist only as PDFs).

### Trailing months and NA values

Months (or days, for `station_daily`) beyond the last published data
point for each line are trimmed during assembly, so the datasets do not
contain unpublished trailing `NA` rows. Interior `NA` values — for
example, days when Line 15 (Silver) was not operating — are preserved
as-is.

## Source attribution

As mentioned previously, the datasets provided by this package are
heavily processed and curated. As such, they should be cited by using
`citation("metrosp")`.

[^1]: In the future, this data pipeline will be split into its own
    repository.
