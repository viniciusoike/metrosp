# import_historic.R
# -----------------------------------------------------------------------------
# Gated refresh of the 2016-2019 historical processed CSVs from the raw files
# (data-raw/metro_sp/metro/{Demanda 2016,2017,2018,demanda_2019}/). These
# rarely change, so the committed CSVs in data-raw/processed/ are the normal
# pipeline input (read by assemble_*). refresh_historic_*() regenerate them.
#
# 2016 was published retroactively by METRO in 2026 as annual files that
# follow the current-era layout, not the 2017-2019 monthly one; see the
# "2016 retroactive publication" section below.
#
# Refactored from import_passengers_2017_2019.R and
# import_station_averages_2017_2019.R.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(stringr)

# Shared metric labels (rows of the line-level tables) and Portuguese month
# names used to key the per-month list that .stack_passengers() expects.
.metric_labels <- c(
  "Total",
  "Média dos Dias Úteis",
  "Média dos Sábados",
  "Média dos Domingos",
  "Máxima Diária"
)

.months_pt <- c(
  Jan = "Janeiro", Fev = "Fevereiro", Mar = "Março", Abr = "Abril",
  Mai = "Maio", Jun = "Junho", Jul = "Julho", Ago = "Agosto",
  Set = "Setembro", Out = "Outubro", Nov = "Novembro", Dez = "Dezembro"
)

# --- Passengers (entrance + transported) 2016-2019 ---------------------------

.read_psg_line <- function(path, force_names = FALSE) {
  encoding <- ifelse(
    stringr::str_detect(path, "Junho - 2018"),
    "UTF-8",
    "Latin-1"
  )

  skip <- case_when(
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Out") &
      stringr::str_detect(path, "Transporta") ~ 5,
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Out") &
      stringr::str_detect(path, "Entrada") ~ 4,
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Nov") &
      stringr::str_detect(path, "Entrada") ~ 4,
    stringr::str_detect(path, "2017") &
      stringr::str_detect(path, "Nov") &
      stringr::str_detect(path, "Transporta") ~ 2,
    stringr::str_detect(path, "2017") & stringr::str_detect(path, "Dez") ~ 4,
    TRUE ~ 4
  )

  dat <- data.table::fread(
    path,
    skip = skip,
    nrows = 5,
    na.strings = c("-", "0<b3>", "0\xb3"),
    encoding = encoding,
    colClasses = "character"
  )

  if (force_names) {
    col_names <- c(
      "demanda_milhares",
      "linha_1_azul",
      "linha_2_verde",
      "linha_3_vermelha",
      "linha_5_lilas",
      "linha_15_prata",
      "rede"
    )

    if (ncol(dat) == 16) {
      data.table::setnames(dat, names(dat)[1:7], col_names)
    } else {
      data.table::setnames(dat, names(dat)[1:6], col_names[-5])
    }
  } else {
    dat <- janitor::clean_names(dat)
  }

  dat <- as_tibble(dat)

  return(dat)
}

.clean_psg_line <- function(dat) {
  cols_rename <- c(
    "linha_5_lilas" = "linha_5_lilas2"
  )

  clean_dat <- dat |>
    rename(any_of(cols_rename)) |>
    filter(!if_all(2:last_col(), ~ . == "")) |>
    mutate(across(2:last_col(), as_numeric_pt)) |>
    select(where(~ !all(is.na(.x))))

  return(clean_dat)
}

.stack_passengers <- function(ls, year = 2018, unite = TRUE) {
  tbl <- bind_rows(ls, .id = "month")

  if (year == 2017) {
    tbl <- tbl |>
      filter(!is.na(linha_1_azul)) |>
      distinct() |>
      mutate(year = local(year)) |>
      rename(variable = demanda_milhares) |>
      pivot_longer(
        cols = -c(variable, year, month),
        names_to = "metro_line",
        values_transform = as.numeric
      )
  } else {
    tbl <- tbl |>
      filter(!is.na(linha_1_azul)) |>
      distinct() |>
      mutate(variable = rep(.metric_labels, 12), year = year) |>
      select(-demanda_milhares) |>
      pivot_longer(
        cols = -c(variable, year, month),
        names_to = "metro_line",
        values_transform = as.numeric
      )
  }

  tbl <- tbl |>
    mutate(
      date = glue::glue("{year}-{month}-01"),
      date = readr::parse_date(date, format = "%Y-%B-%d", locale = readr::locale("pt"))
    ) |>
    select(date, year, variable, metro_line, value)

  return(tbl)
}

.import_psg_line <- function(year, variable = "transport") {
  valid_vars <- c("transport", "entrance")

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  df_path <- get_path_flds(year, variable)

  if (nrow(df_path) == 0) {
    cli::cli_abort("No paths found. Check basedir.")
  }

  files_psg_line <- purrr::map(df_path$path, \(p) {
    psg_line <- .read_psg_line(p)
    psg_line <- .clean_psg_line(psg_line)
    return(psg_line)
  })

  files_psg_line <- rlang::set_names(files_psg_line, df_path$name)
  .stack_passengers(files_psg_line, year = year)
}

# --- 2016 retroactive publication ---------------------------------------------
# METRO began publishing pre-2017 data retroactively in 2026, one annual file
# per measure in data-raw/metro_sp/metro/Demanda 2016/. The line-level files
# follow the current-era layout (three sections of side-by-side
# "Mês;Total;MDU;MSA;MDO;MAX" blocks) but 2016 still reports Line 5 (Lilás):
# sections are (L1,L2), (L3,L5), (L15,REDE) instead of (L1,L2), (L3,L15),
# (REDE). The station file has one section per line with months as columns
# (transposed relative to the 2017-2019 monthly files).

#' Locate one of the annual 2016 raw CSVs by pattern.
.path_2016 <- function(pattern) {
  dir <- here::here("data-raw/metro_sp/metro/Demanda 2016")
  path <- list.files(dir, pattern = "\\.csv$", full.names = TRUE)
  path <- path[stringr::str_detect(path, pattern)]

  if (length(path) != 1) {
    cli::cli_abort("Expected 1 file matching {pattern} in {.path {dir}}.")
  }

  path
}

#' Read one annual 2016 line-level file (entrance or transported).
#'
#' Returns a named list of 12 monthly tibbles with the same shape as the
#' 2017-2019 per-month files after .clean_psg_line() (rows = the 5 metrics,
#' columns = lines), so .stack_passengers() can be reused unchanged.
.read_psg_line_2016 <- function(path) {
  raw_lines <- readLines(path, encoding = "latin1")
  starts <- grep("^Jan;", raw_lines)

  if (length(starts) != 3) {
    cli::cli_abort(
      "Expected 3 line blocks (found {length(starts)}) while parsing {path}."
    )
  }

  # Lines appear left-to-right, two per section (blocks at cols 1:6 and 8:13).
  section_lines <- list(
    c("linha_1_azul", "linha_2_verde"),
    c("linha_3_vermelha", "linha_5_lilas"),
    c("linha_15_prata", "rede")
  )
  block_cols <- list(2:6, 9:13)

  sections <- purrr::imap(starts, \(start, i) {
    dat <- data.table::fread(
      path,
      skip = start - 1,
      nrows = 12,
      na.strings = c("-", "0<b3>", "0\xb3"),
      encoding = "Latin-1",
      colClasses = "character"
    )

    if (!identical(dat[[1]], names(.months_pt))) {
      cli::cli_abort("Unexpected month labels in section {i} of {.path {path}}.")
    }

    long <- tibble(
      month = rep(unname(.months_pt[dat[[1]]]), each = 5),
      demanda_milhares = rep(.metric_labels, 12)
    )

    for (j in seq_along(section_lines[[i]])) {
      vals <- t(as.matrix(dat[, block_cols[[j]], with = FALSE]))
      long[[section_lines[[i]][j]]] <- unname(as_numeric_pt(vals))
    }

    long
  })

  wide <- bind_rows(sections) |>
    pivot_longer(
      cols = -c(month, demanda_milhares),
      names_to = "metro_line",
      values_drop_na = TRUE
    ) |>
    pivot_wider(names_from = metro_line, values_from = value)

  purrr::map(
    unname(.months_pt),
    \(m) wide |> filter(month == m) |> select(-month)
  ) |>
    rlang::set_names(unname(.months_pt))
}

#' Import one 2016 line-level measure, stacked like .import_psg_line().
.import_psg_line_2016 <- function(variable = "transport") {
  valid_vars <- c("transport", "entrance")

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  pattern <- c(
    transport = "Transportados por Linha",
    entrance = "Entrada de Passageiros por Linha"
  )[[variable]]

  files_psg_line <- .read_psg_line_2016(.path_2016(pattern))
  .stack_passengers(files_psg_line, year = 2016)
}

# --- Jan-Sep 2017, transcribed from PDF ---------------------------------------
# METRO published Jan-Sep 2017 only as PDFs whose pages are pasted screenshots
# with no text layer, so those months were transcribed by hand into
# data-raw/pdf2017/. See data-raw/pdf2017/README.md for the procedure and
# report_2017.md for the source defects the checksums exposed. The transcribed
# CSVs are committed and are the input here; the PDFs themselves are not read.

.path_pdf2017 <- function(file) {
  path <- here::here("data-raw/pdf2017", file)

  if (!file.exists(path)) {
    cli::cli_abort("Missing transcription {.path {path}}.")
  }

  path
}

#' Import one Jan-Sep 2017 line-level measure, stacked like .import_psg_line().
.import_psg_line_2017_pdf <- function(variable = "transport") {
  valid_vars <- c("transport", "entrance")

  if (!variable %in% valid_vars) {
    cli::cli_abort("Invalid input {variable}. Valid values: {valid_vars}")
  }

  readr::read_csv(
    .path_pdf2017("transcribed_passengers_line_2017.csv"),
    show_col_types = FALSE
  ) |>
    filter(measure == variable) |>
    select(-measure) |>
    pivot_longer(
      cols = -c(date, metric),
      names_to = "metro_line",
      values_to = "value"
    ) |>
    mutate(year = 2017) |>
    select(date, year, variable = metric, metro_line, value)
}

#' Import Jan-Sep 2017 station averages, shaped like .import_stn_avg().
.import_stn_avg_2017_pdf <- function() {
  readr::read_csv(
    .path_pdf2017("transcribed_station_averages_2017.csv"),
    show_col_types = FALSE
  ) |>
    filter(station != "TOTAL") |>
    pivot_longer(
      cols = -c(line, station),
      names_to = "year_month",
      values_to = "value"
    ) |>
    mutate(
      date = as.Date(paste0(year_month, "-01")),
      year = 2017,
      month = unname(.months_pt[as.integer(format(date, "%m"))]),
      line_name_full = line,
      name_station = clean_station_name(station),
      metric_abb = "mdu"
    ) |>
    select(date, year, month, line_name_full, name_station, metric_abb, value)
}

#' Regenerate metro_sp_passengers_historic.csv from raw. Returns the path.
refresh_historic_passengers <- function(
  proc_dir = here::here("data-raw/processed")
) {
  passengers_line <- expand_grid(
    year = 2016:2019,
    measure = c("entrance", "transport")
  ) |>
    mutate(dat = purrr::pmap(list(year, measure), \(year, measure) {
      if (year == 2016) {
        .import_psg_line_2016(variable = measure)
      } else if (year == 2017) {
        bind_rows(
          .import_psg_line_2017_pdf(variable = measure),
          .import_psg_line(year, variable = measure)
        )
      } else {
        .import_psg_line(year, variable = measure)
      }
    })) |>
    unnest(cols = dat, names_repair = janitor::make_clean_names) |>
    select(-year_2)

  passengers_line <- passengers_line |>
    mutate(
      line_number = as.numeric(str_extract(metro_line, "[0-9]{1,2}")),
      line_number = if_else(is.na(line_number), 99L, line_number)
    ) |>
    select(-metro_line) |>
    left_join(dim_line, by = join_by(line_number))

  out <- file.path(proc_dir, "metro_sp_passengers_historic.csv")
  readr::write_csv(passengers_line, out)
  cli::cli_alert_success("Wrote {.path {out}}.")
  invisible(out)
}

# --- Station averages 2016-2019 ------------------------------------------------

.read_clean_stn_avg <- function(path) {
  rawfile <- readr::read_lines(path)

  i_stop <- which(str_detect(rawfile, "TOTAL"))

  skip <- 5

  enc <- ifelse(
    str_detect(path, "(Junho - 2018)|(Julho - 2018)"),
    "UTF-8",
    "ISO-8859-1"
  )

  dat <- readr::read_csv2(
    path,
    skip = skip,
    locale = readr::locale(encoding = enc),
    name_repair = janitor::make_clean_names,
    na = c("- ", "-", " - "),
    n_max = i_stop - skip - 2,
    col_types = readr::cols(.default = readr::col_character())
  )

  names(dat)[1:2] <- c("estacao_1", "entradas_1")

  header <- readr::read_csv2(
    path,
    skip = skip - 1,
    n_max = 1,
    col_names = FALSE,
    locale = readr::locale(encoding = enc),
    name_repair = janitor::make_clean_names,
    col_types = readr::cols(.default = readr::col_character())
  )

  header <- unlist(header)
  header <- header[which(header != "NA")]

  df_code <- tibble(
    code = as.character(seq_along(header)),
    line_name_full = header
  )

  clean_dat <- dat |>
    mutate(across(starts_with("entradas"), as.numeric)) |>
    pivot_longer(
      everything(),
      cols_vary = "slowest",
      names_to = c(".value", "code"),
      names_pattern = "(.*)_(.*)",
      values_drop_na = TRUE
    ) |>
    filter(!is.na(entradas)) |>
    left_join(df_code, by = join_by(code)) |>
    mutate(
      name_station = clean_station_name(estacao),
      metric_abb = "mdu"
    ) |>
    select(line_name_full, name_station, metric_abb, value = entradas)

  return(clean_dat)
}

.import_stn_avg <- function(year) {
  df_path <- get_path_flds(year = year, variable = "daily")

  dat <- purrr::map(df_path$path, \(x) suppressMessages(.read_clean_stn_avg(x)))
  dat <- rlang::set_names(dat, df_path$name)
  dat <- bind_rows(dat, .id = "month")

  dat <- dat |>
    mutate(
      year = local(year),
      date = readr::parse_date(
        glue::glue("{year}-{month}-01"),
        format = "%Y-%B-%d",
        locale = readr::locale("pt")
      )
    )

  return(dat)
}

#' Import 2016 station averages (annual file, one section per line).
#'
#' Sections hold stations in rows and months in columns, ending in a "Total"
#' row that is excluded. Returns the same schema as .import_stn_avg(): date,
#' year, month, line_name_full, name_station, metric_abb, value.
.import_stn_avg_2016 <- function() {
  path <- .path_2016("Esta")

  raw_lines <- readLines(path, encoding = "latin1")
  section_starts <- grep("^LINHA ", raw_lines)
  section_labels <- stringr::str_remove(raw_lines[section_starts], ";.*$")

  line_lookup <- c(
    "LINHA 1-AZUL" = "Linha 1 - Azul",
    "LINHA 2-VERDE" = "Linha 2 - Verde",
    "LINHA 3-VERMELHA" = "Linha 3 - Vermelha",
    "LINHA 5-LILÁS" = "Linha 5 - Lilás",
    "LINHA 15-PRATA" = "Linha 15 - Prata"
  )
  line_name_full <- line_lookup[section_labels]

  if (any(is.na(line_name_full))) {
    cli::cli_abort("Unrecognized line section in {.path {path}}.")
  }

  sections <- purrr::imap(section_starts, \(start, i) {
    header_row <- start + 1

    if (!stringr::str_detect(raw_lines[header_row], "^Esta")) {
      cli::cli_abort(
        "Expected station header after section {i} in {.path {path}}."
      )
    }

    window <- raw_lines[(start + 1):min(start + 40, length(raw_lines))]
    total_row <- start + which(stringr::str_detect(window, "^Total;"))[1]

    dat <- suppressMessages(readr::read_delim(
      path,
      delim = ";",
      skip = header_row - 1,
      n_max = total_row - header_row - 1,
      na = c("- ", "-", " - ", ""),
      locale = readr::locale(encoding = "ISO-8859-1"),
      col_types = readr::cols(.default = readr::col_character()),
      name_repair = janitor::make_clean_names,
      show_col_types = FALSE
    ))

    names(dat)[1] <- "estacao"

    dat |>
      select(-any_of("media")) |>
      pivot_longer(
        cols = -estacao,
        names_to = "month_abb",
        values_to = "value",
        values_transform = as_numeric_pt
      ) |>
      mutate(
        value = unname(value),
        line_name_full = line_name_full[i],
        name_station = clean_station_name(estacao),
        metric_abb = "mdu",
        # make_clean_names() lowercases the month headers ("jan", "fev", ...)
        month = unname(.months_pt[stringr::str_to_title(month_abb)]),
        year = 2016,
        date = readr::parse_date(
          glue::glue("2016-{month_abb}-01"),
          format = "%Y-%b-%d",
          locale = readr::locale("pt")
        )
      ) |>
      select(date, year, month, line_name_full, name_station, metric_abb, value)
  })

  bind_rows(sections)
}

#' Regenerate metro_sp_station_averages_historic.csv from raw. Returns the path.
refresh_historic_averages <- function(
  proc_dir = here::here("data-raw/processed")
) {
  years <- 2017:2019
  stations_files <- lapply(years, .import_stn_avg)
  stations_files <- rlang::set_names(stations_files, years)
  stations_files[["2017"]] <- bind_rows(
    .import_stn_avg_2017_pdf(),
    stations_files[["2017"]]
  )
  stations_files <- c(
    list(`2016` = .import_stn_avg_2016()),
    stations_files
  )

  avg_psg_station <- bind_rows(stations_files, .id = "year") |>
    select(date, year, month, line_name_full, name_station, metric_abb, value)

  out <- file.path(proc_dir, "metro_sp_station_averages_historic.csv")
  readr::write_csv(avg_psg_station, out)
  cli::cli_alert_success("Wrote {.path {out}}.")
  invisible(out)
}
