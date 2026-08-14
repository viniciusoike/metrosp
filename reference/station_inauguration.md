# Station Commercial Opening Dates

Inauguration (commercial opening) dates for São Paulo metro stations,
covering stations whose opening falls within or near the
[`station_daily`](https://viniciusoike.github.io/metrosp/reference/station_daily.md)
/
[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
window. Used to flag ramp-up periods in which monthly ridership is still
climbing toward steady-state and should generally be excluded from
year-on-year or baseline comparisons.

## Usage

``` r
station_inauguration
```

## Format

A data frame with one row per (line, station):

- line_number:

  Metro line number (integer).

- station_name:

  Full station name (character).

- inauguration_date:

  Date of commercial opening (Date). `NA` for stations whose opening
  predates the dataset window (i.e., they were already operating when
  the data record begins).

- phase:

  Short label identifying the expansion phase, e.g. `"L15 Fase 4"`
  (character).

- verified:

  Whether the inauguration date has been cross-checked against the
  operator's announcement or an equivalently reliable source (logical).
  Stations with `verified = FALSE` carry best-effort dates and should
  not be relied on for legal or publication purposes without
  re-checking.

- notes:

  Free-text annotations about the source or any caveats (character,
  possibly `NA`).

- pre_data_window:

  `TRUE` when `inauguration_date` is `NA` because the station opened
  before the data starts (logical).

- ramp_up_end:

  `inauguration_date + 180` days — a heuristic end of the initial
  ramp-up period (Date). `NA` when `pre_data_window` is `TRUE`.

## Source

Compiled from operator announcements (Companhia do Metropolitano de São
Paulo, ViaQuatro, ViaMobilidade).

## Details

The table is compiled by hand from `data-raw/station_inauguration.csv`
in the package repository. Contributions that extend the table or verify
uncertain dates are welcome.

When computing pre/post comparisons (e.g.\\ 12m-vs-prior-12m or
recovery-vs-2019), exclude stations where either window overlaps
`ramp_up_end` to avoid mistaking ramp-up growth for organic demand
change.

## See also

[`stations`](https://viniciusoike.github.io/metrosp/reference/stations.md)
for spatial point locations,
[`station_averages`](https://viniciusoike.github.io/metrosp/reference/station_averages.md)
for monthly weekday averages.
