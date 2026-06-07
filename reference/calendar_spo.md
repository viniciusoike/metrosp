# São Paulo Holiday and Business-Day Calendar

A daily calendar for São Paulo (city) covering 2012–2030, classifying
each date as a holiday or business day. Includes national, state, and
municipal holidays in São Paulo, with flags for optional work days
(is_ponto_facultativo) and extended holiday weekends (is_feriadao).

## Usage

``` r
calendar_spo
```

## Format

A data frame with one row per day and the following columns:

- date:

  Calendar date (Date).

- year:

  Calendar year (integer).

- weekday:

  Day of week from `lubridate::wday()`: 1 = Sunday, 2 = Monday, ..., 7 =
  Saturday (integer).

- is_weekend:

  `TRUE` for Saturdays and Sundays (logical).

- is_holiday:

  `TRUE` when the date is a gazetted holiday at any scope (logical).

- is_business_day:

  `TRUE` when the date is neither a weekend nor a holiday (logical).

- holiday_name:

  Name of the holiday in Portuguese (character). `NA` on non-holiday
  dates.

- holiday_scope:

  Scope of the holiday (character). One of `"national"`, `"state"`, or
  `"municipal"`; `NA` on non-holiday dates.

- is_ponto_facultativo:

  `TRUE` for holidays that are technically optional at the federal level
  (Carnaval, Corpus Christi) but observed as holidays in São Paulo
  (logical).

- is_feriadao:

  `TRUE` when a holiday falls on Monday, Tuesday, Thursday, or Friday,
  creating a potential extended weekend with the adjacent
  Saturday/Sunday (logical).

## Details

The calendar covers the full date range of the
[`station_daily`](https://viniciusoike.github.io/metrosp/reference/station_daily.md)
dataset (Lines 4/5 from January 2012) and extends through 2030 for
forecasting use.

## See also

[`station_daily`](https://viniciusoike.github.io/metrosp/reference/station_daily.md)
for daily passenger data that can be joined on `date`.
