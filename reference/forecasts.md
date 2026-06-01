# Six-Month Demand Forecasts by Line and Model

## Format

A data frame with one row per (line, model, forecast date):

line_number

:   Metro line number: 1, 2, 3, 4, 5, or 15 (integer).

model

:   Model identifier (character). One of: `"arima"` (Box-Cox
    `auto.arima` with seasonal search), `"ets"` (Box-Cox state-space
    exponential smoothing), `"stlf"` (robust STL decomposition + ETS on
    the seasonally adjusted remainder).

date

:   First day of the forecast month (Date). Six rows per (line, model),
    starting one month after the last observed value.

mean

:   Point forecast — back-transformed and bias-adjusted (numeric).

lo80, hi80

:   80\\ lo95, hi9595\\
