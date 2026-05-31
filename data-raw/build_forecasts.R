# build_forecasts.R
# -----------------------------------------------------------------------------
# Fit ARIMA / ETS / STLF models (all with Box-Cox variance stabilization) on
# the monthly entrance totals for each of the six METRO SP lines, run rolling-
# origin cross-validation on the most recent CV_WINDOW months to compare
# accuracy, and write two .rda datasets:
#
#   forecasts          6-month-ahead point forecasts and 80% / 95% intervals,
#                      one row per (line_number, model, date).
#   forecast_accuracy  MAPE / RMSE / MAE per (line_number, model) from CV,
#                      with `best = TRUE` flagging the lowest-MAPE model per
#                      line.
#
# Run with: source("data-raw/build_forecasts.R") from the project root.
#
# Inputs:  passengers_entrance (in-memory or data-raw/cache/*.rds)
# Outputs: data/forecasts.rda, data/forecast_accuracy.rda
# -----------------------------------------------------------------------------

if (!requireNamespace("forecast", quietly = TRUE)) {
  cli::cli_abort(c(
    "Package {.pkg forecast} is required.",
    "i" = "Install with {.code install.packages(\"forecast\")}."
  ))
}

library(dplyr)
import::from(here, here)

if (!exists("passengers_entrance")) {
  passengers_entrance <- readr::read_rds(
    here("data-raw/cache/passengers_entrance.rds")
  )
}

# Config ----------------------------------------------------------------------

LINES <- c(1L, 2L, 3L, 4L, 5L, 15L)
H <- 6L          # forecast horizon (months)
CV_WINDOW <- 12L # rolling-origin evaluations used in tsCV

# Model helpers ---------------------------------------------------------------

build_ts <- function(df_line) {
  df_line <- df_line[!is.na(df_line$value), ]
  df_line <- df_line[order(df_line$date), ]
  start_d <- min(df_line$date)
  list(
    y = stats::ts(
      df_line$value,
      start = c(
        as.integer(format(start_d, "%Y")),
        as.integer(format(start_d, "%m"))
      ),
      frequency = 12L
    ),
    last_date = max(df_line$date)
  )
}

fit_arima <- function(y, h, fast = FALSE) {
  fit <- forecast::auto.arima(
    y,
    lambda = "auto",
    biasadj = TRUE,
    seasonal = TRUE,
    stepwise = TRUE,
    approximation = fast
  )
  forecast::forecast(fit, h = h, level = c(80, 95))
}

fit_ets <- function(y, h) {
  fit <- forecast::ets(y, lambda = "auto", biasadj = TRUE)
  forecast::forecast(fit, h = h, level = c(80, 95))
}

fit_stlf <- function(y, h) {
  forecast::stlf(
    y,
    h = h,
    level = c(80, 95),
    robust = TRUE,
    lambda = "auto",
    biasadj = TRUE,
    method = "ets"
  )
}

## tsCV-compatible wrappers (faster ARIMA for repeated CV fits) ----

ff_arima <- function(x, h) fit_arima(x, h, fast = TRUE)
ff_ets <- function(x, h) fit_ets(x, h)
ff_stlf <- function(x, h) fit_stlf(x, h)

models <- list(
  arima = list(fit = function(y) fit_arima(y, H, fast = FALSE), ff = ff_arima),
  ets = list(fit = function(y) fit_ets(y, H), ff = ff_ets),
  stlf = list(fit = function(y) fit_stlf(y, H), ff = ff_stlf)
)

# Cross-validation ------------------------------------------------------------

## Rolling-origin tsCV over the last CV_WINDOW months. tsCV stores
## e[i, j] = y[i + j] - forecast(y[i + j] | y[1:i]), so we reconstruct the
## matching actuals from y and compute summary metrics. ----

cv_metrics <- function(y, ff, h = H, window = CV_WINDOW) {
  n <- length(y)
  initial <- max(24L, n - window - h + 1L)
  e <- tryCatch(
    suppressWarnings(
      forecast::tsCV(y, forecastfunction = ff, h = h, initial = initial)
    ),
    error = function(err) NULL
  )
  if (is.null(e) || all(is.na(e))) {
    return(data.frame(mape = NA_real_, rmse = NA_real_, mae = NA_real_))
  }

  y_vec <- as.numeric(y)
  actual_mat <- matrix(NA_real_, nrow = n, ncol = h)
  for (j in seq_len(h)) {
    idx <- seq_len(n) + j
    in_range <- idx <= n
    actual_mat[in_range, j] <- y_vec[idx[in_range]]
  }

  errs <- as.numeric(e)
  acts <- as.numeric(actual_mat)
  ok <- is.finite(errs) & is.finite(acts) & acts != 0

  data.frame(
    mape = mean(abs(errs[ok] / acts[ok])) * 100,
    rmse = sqrt(mean(errs[ok]^2)),
    mae = mean(abs(errs[ok]))
  )
}

# Build -----------------------------------------------------------------------

cli::cli_h2(
  "Fitting forecasts ({length(LINES)} lines x {length(models)} models)"
)

fc_rows <- list()
acc_rows <- list()

for (ln in LINES) {
  cli::cli_h3("Line {ln}")

  df <- passengers_entrance |>
    filter(line_number == ln, metric_abb == "total") |>
    select(date, value)

  ts_info <- build_ts(df)
  y <- ts_info$y

  if (length(y) < 36L) {
    cli::cli_alert_warning("  skipping (only {length(y)} obs)")
    next
  }

  fc_dates <- seq(ts_info$last_date, by = "month", length.out = H + 1L)[-1L]

  for (mod_name in names(models)) {
    mod <- models[[mod_name]]
    cli::cli_alert_info("  {mod_name}: fitting full model")

    fc <- tryCatch(
      mod$fit(y),
      error = function(e) {
        cli::cli_alert_danger("    fit failed: {conditionMessage(e)}")
        NULL
      }
    )

    if (!is.null(fc)) {
      fc_rows[[length(fc_rows) + 1L]] <- data.frame(
        line_number = ln,
        model = mod_name,
        date = fc_dates,
        mean = as.numeric(fc$mean),
        lo80 = as.numeric(fc$lower[, 1]),
        hi80 = as.numeric(fc$upper[, 1]),
        lo95 = as.numeric(fc$lower[, 2]),
        hi95 = as.numeric(fc$upper[, 2])
      )
    }

    cli::cli_alert_info("  {mod_name}: cross-validating")
    acc <- cv_metrics(y, mod$ff)
    acc_rows[[length(acc_rows) + 1L]] <- data.frame(
      line_number = ln,
      model = mod_name,
      mape = acc$mape,
      rmse = acc$rmse,
      mae = acc$mae
    )
  }
}

forecasts <- bind_rows(fc_rows) |>
  mutate(line_number = as.integer(line_number)) |>
  arrange(line_number, model, date)

# Cap pathological CV results (Box-Cox back-transform on the COVID dip can
# explode the inverse for some series; treat anything above 200% MAPE or
# non-finite as a model failure and surface as NA).
forecast_accuracy <- bind_rows(acc_rows) |>
  mutate(
    line_number = as.integer(line_number),
    failed = !is.finite(mape) | mape > 200,
    mape = if_else(failed, NA_real_, mape),
    rmse = if_else(failed, NA_real_, rmse),
    mae = if_else(failed, NA_real_, mae)
  ) |>
  select(-failed) |>
  group_by(line_number) |>
  mutate(best = !is.na(mape) & mape == min(mape, na.rm = TRUE)) |>
  ungroup() |>
  arrange(line_number, mape)

# Save ------------------------------------------------------------------------

usethis::use_data(forecasts, overwrite = TRUE)
usethis::use_data(forecast_accuracy, overwrite = TRUE)

cli::cli_alert_success(
  "Saved forecasts ({nrow(forecasts)} rows) and forecast_accuracy ({nrow(forecast_accuracy)} rows)."
)

print(
  forecast_accuracy |>
    mutate(across(c(mape, rmse, mae), \(x) round(x, 2))),
  n = nrow(forecast_accuracy)
)
