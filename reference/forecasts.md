# Six-Month Demand Forecasts by Line and Model

Pre-computed 6-month-ahead forecasts of total monthly passenger entries
for each of the six METRO SP lines, fit with three model families
(`auto.arima`, `ets`, robust `stlf`). All models use Box-Cox variance
stabilization with `lambda = "auto"`, which both compresses the
COVID-era shock and guarantees non-negative forecast intervals.

## Usage

``` r
forecasts
```

## Format

A data frame with one row per (line, model, forecast date):

- line_number:

  Metro line number: 1, 2, 3, 4, 5, or 15 (integer).

- model:

  Model identifier (character). One of: `"arima"` (Box-Cox `auto.arima`
  with seasonal search), `"ets"` (Box-Cox state-space exponential
  smoothing), `"stlf"` (robust STL decomposition + ETS on the seasonally
  adjusted remainder).

- date:

  First day of the forecast month (Date). Six rows per (line, model),
  starting one month after the last observed value.

- mean:

  Point forecast — back-transformed and bias-adjusted (numeric).

- lo80, hi80:

  80% prediction interval (numeric).

- lo95, hi95:

  95% prediction interval (numeric).

## Details

Forecasts are built by `data-raw/build_forecasts.R` from
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
(`metric_abb == "total"`) and refreshed whenever the underlying data is
updated. The build script also produces
[`forecast_accuracy`](https://viniciusoike.github.io/metrosp/reference/forecast_accuracy.md),
which reports out-of-sample error for each (line, model) so the consumer
can pick a preferred model per line.

Modelling choices:

- All three models use `lambda = "auto"` (Guerrero estimate) and
  `biasadj = TRUE`, so point forecasts are means rather than medians on
  the original scale.

- `stlf` uses `robust = TRUE`, which down-weights the 2020–2021 COVID
  period during seasonal extraction without requiring an explicit
  intervention dummy.

## See also

[`forecast_accuracy`](https://viniciusoike.github.io/metrosp/reference/forecast_accuracy.md)
for cross-validated error metrics,
[`passengers_entrance`](https://viniciusoike.github.io/metrosp/reference/passengers_entrance.md)
for the underlying historical series.
