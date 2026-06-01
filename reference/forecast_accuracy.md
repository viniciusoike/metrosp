# Cross-Validated Accuracy of Forecast Models by Line

Out-of-sample error metrics for the three model families shipped in
[`forecasts`](https://viniciusoike.github.io/metrosp/reference/forecasts.md),
computed by rolling-origin cross-validation
([`forecast::tsCV`](https://pkg.robjhyndman.com/forecast/reference/tsCV.html))
over the most recent 12 months of each series with a 6-month horizon.

## Usage

``` r
forecast_accuracy
```

## Format

A data frame with one row per (line, model):

- line_number:

  Metro line number: 1, 2, 3, 4, 5, or 15 (integer).

- model:

  Model identifier (character). One of `"arima"`, `"ets"`, `"stlf"` —
  see
  [`forecasts`](https://viniciusoike.github.io/metrosp/reference/forecasts.md).

- mape:

  Mean absolute percentage error across all rolling-origin forecasts and
  horizons (numeric, in percent).

- rmse:

  Root mean squared error on the original scale (numeric).

- mae:

  Mean absolute error on the original scale (numeric).

- best:

  `TRUE` for the model with the lowest MAPE on the line (logical).

## Details

Rows are sorted by `line_number`, then `mape` ascending, so the first
row for each line is the cross-validation winner. The accuracy reported
here is meant to guide model selection in the dashboard; it is not a
guarantee of future forecast accuracy.

For speed, ARIMA fits inside the CV loop use `approximation = TRUE`,
while the final fit stored in
[`forecasts`](https://viniciusoike.github.io/metrosp/reference/forecasts.md)
uses `approximation = FALSE` for the best attainable model.

## See also

[`forecasts`](https://viniciusoike.github.io/metrosp/reference/forecasts.md)
for the point forecasts and intervals.
