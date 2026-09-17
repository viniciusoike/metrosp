# build_calendar_spo.R
# -----------------------------------------------------------------------------
# Builds a São Paulo holiday/business-day calendar (2012–2030).
# Holidays are defined algorithmically: fixed-date holidays from legislation,
# moveable holidays computed from Easter. No external API dependency.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(lubridate, warn.conflicts = FALSE)

# --- Easter (Anonymous Gregorian algorithm) -----------------------------------

compute_easter <- function(year) {
  a <- year %% 19
  b <- year %/% 100
  c <- year %% 100
  d <- b %/% 4
  e <- b %% 4
  f <- (b + 8) %/% 25
  g <- (b - f + 1) %/% 3
  h <- (19 * a + b - d - g + 15) %% 30
  i <- c %/% 4
  k <- c %% 4
  l <- (32 + 2 * e + 2 * i - h - k) %% 7
  m <- (a + 11 * h + 22 * l) %/% 451
  month <- (h + l - 7 * m + 114) %/% 31
  day <- ((h + l - 7 * m + 114) %% 31) + 1
  as.Date(paste(year, month, day, sep = "-"))
}

# --- Holiday definitions for a single year ------------------------------------

holidays_for_year <- function(yr) {
  easter <- compute_easter(yr)

  # National fixed holidays (legislated)
  national_fixed <- tibble::tibble(
    date = as.Date(c(
      paste0(yr, "-01-01"),
      paste0(yr, "-04-21"),
      paste0(yr, "-05-01"),
      paste0(yr, "-09-07"),
      paste0(yr, "-10-12"),
      paste0(yr, "-11-02"),
      paste0(yr, "-11-15"),
      paste0(yr, "-12-25")
    )),
    holiday_name = c(
      "Confraterniza\u00e7\u00e3o Universal",
      "Tiradentes",
      "Dia do Trabalho",
      "Independ\u00eancia do Brasil",
      "Nossa Senhora Aparecida",
      "Finados",
      "Proclama\u00e7\u00e3o da Rep\u00fablica",
      "Natal"
    ),
    holiday_scope = "national",
    is_ponto_facultativo = FALSE
  )

  # Consciência Negra: municipal in SP until 2023, national from 2024
  # (Lei 14.759/2023)
  consciencia_negra <- tibble::tibble(
    date = as.Date(paste0(yr, "-11-20")),
    holiday_name = "Dia da Consci\u00eancia Negra",
    holiday_scope = if (yr >= 2024) "national" else "municipal",
    is_ponto_facultativo = FALSE
  )

  # São Paulo municipal holiday
  municipal <- tibble::tibble(
    date = as.Date(paste0(yr, "-01-25")),
    holiday_name = "Anivers\u00e1rio de S\u00e3o Paulo",
    holiday_scope = "municipal",
    is_ponto_facultativo = FALSE
  )

  # São Paulo state holiday
  state <- tibble::tibble(
    date = as.Date(paste0(yr, "-07-09")),
    holiday_name = "Revolu\u00e7\u00e3o Constitucionalista",
    holiday_scope = "state",
    is_ponto_facultativo = FALSE
  )

  # Easter-relative holidays
  moveable <- tibble::tibble(
    date = as.Date(c(
      easter - 48,
      easter - 47,
      easter - 2,
      easter + 60
    )),
    holiday_name = c(
      "Carnaval (segunda-feira)",
      "Carnaval (ter\u00e7a-feira)",
      "Sexta-Feira Santa",
      "Corpus Christi"
    ),
    holiday_scope = c("national", "national", "national", "national"),
    is_ponto_facultativo = c(TRUE, TRUE, FALSE, TRUE)
  )

  bind_rows(national_fixed, consciencia_negra, municipal, state, moveable)
}

# --- Main builder -------------------------------------------------------------

build_calendar_spo <- function(
  start_date = "2012-01-01",
  end_date = "2030-12-31"
) {
  start <- as.Date(start_date)
  end <- as.Date(end_date)
  years <- seq(year(start), year(end))

  holidays <- purrr::map_dfr(years, holidays_for_year)

  calendar <- tibble::tibble(date = seq(start, end, by = "day")) |>
    left_join(holidays, by = "date") |>
    mutate(
      year = year(date),
      weekday = wday(date),
      weekday_label = wday(date, label = TRUE),
      weekday_label_pt = wday(date, label = TRUE, locale = "pt_BR"),
      is_weekend = weekday %in% c(1L, 7L),
      is_holiday = !is.na(holiday_name),
      is_ponto_facultativo = tidyr::replace_na(is_ponto_facultativo, FALSE),
      is_business_day = !is_weekend & !is_holiday
    )

  # Feriadão: holiday on Mon/Tue/Thu/Fri creates potential extended weekend
  # wday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
  calendar <- calendar |>
    mutate(
      is_feriadao = is_holiday & weekday %in% c(2L, 3L, 5L, 6L)
    )

  calendar |>
    select(
      date,
      year,
      weekday,
      is_weekend,
      is_holiday,
      is_business_day,
      holiday_name,
      holiday_scope,
      is_ponto_facultativo,
      is_feriadao
    )
}
