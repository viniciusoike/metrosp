read_station_dimension <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = ""
  )
}

validate_station_dimensions <- function(dim_station, dim_station_alias) {
  problems <- character()
  missing_station_cols <- setdiff(
    c("station_id", "station_name", "station_code", "notes"),
    names(dim_station)
  )
  missing_alias_cols <- setdiff(
    c("station_name_raw", "station_id", "source", "notes"),
    names(dim_station_alias)
  )
  if (length(missing_station_cols) > 0 || length(missing_alias_cols) > 0) {
    cli::cli_abort("Station dimension columns are incomplete.")
  }

  if (anyNA(dim_station$station_id) || anyDuplicated(dim_station$station_id)) {
    problems <- c(problems, "dim_station has duplicate station_id values")
  }
  if (anyNA(dim_station$station_name)) {
    problems <- c(problems, "dim_station has missing station_name values")
  }
  if (anyNA(dim_station_alias[c("station_name_raw", "station_id", "source")])) {
    problems <- c(problems, "dim_station_alias has missing key values")
  }
  if (anyDuplicated(dim_station_alias[c("source", "station_name_raw")])) {
    problems <- c(problems, "dim_station_alias has duplicate source/name keys")
  }
  missing_ids <- setdiff(dim_station_alias$station_id, dim_station$station_id)
  if (length(missing_ids) > 0) {
    problems <- c(
      problems,
      sprintf(
        "aliases reference unknown station_id values: %s",
        paste(missing_ids, collapse = ", ")
      )
    )
  }
  invalid_ids <- !grepl("^[a-z0-9]+(?:-[a-z0-9]+)*$", dim_station$station_id)
  if (any(invalid_ids)) {
    problems <- c(problems, "dim_station has invalid station_id slugs")
  }

  if (length(problems) > 0) {
    cli::cli_abort(c(
      "Invalid station dimensions.",
      stats::setNames(problems, rep("x", length(problems)))
    ))
  }

  return(invisible(TRUE))
}

resolve_stations <- function(dat, source, dim_station, dim_station_alias) {
  validate_station_dimensions(dim_station, dim_station_alias)

  dat$.station_source <- source
  resolved <- dat |>
    dplyr::left_join(
      dim_station_alias,
      by = c("station_name" = "station_name_raw", ".station_source" = "source")
    )

  missing <- resolved |>
    dplyr::filter(is.na(station_id)) |>
    dplyr::distinct(
      .station_source,
      station_name,
      dplyr::across(dplyr::any_of(c("line_number", "station_code")))
    )

  if (nrow(missing) > 0) {
    examples <- paste0(missing$.station_source, ": ", missing$station_name)
    known_codes <- if ("station_code" %in% names(missing)) {
      missing$station_code %in% stats::na.omit(dim_station$station_code)
    } else {
      rep(FALSE, nrow(missing))
    }
    probable_alias <- examples[known_codes]
    probable_new <- examples[!known_codes]
    findings <- character()
    if (length(probable_alias) > 0) {
      findings <- c(
        findings,
        sprintf(
          "Probable rename/variant (known station code): %s",
          paste(utils::head(probable_alias, 10), collapse = ", ")
        )
      )
    }
    if (length(probable_new) > 0) {
      findings <- c(
        findings,
        sprintf(
          "Probable new station or uncoded variant: %s",
          paste(utils::head(probable_new, 10), collapse = ", ")
        )
      )
    }
    cli::cli_abort(c(
      "Station aliases are missing for {nrow(missing)} source value{?s}.",
      stats::setNames(findings, rep("x", length(findings))),
      "i" = "For a rename, add an alias pointing to the existing station_id.",
      "i" = "For a new station, add it to dim_station.csv and then add its alias."
    ))
  }

  resolved <- resolved |>
    dplyr::select(-station_name, -.station_source, -notes) |>
    dplyr::left_join(
      dim_station |>
        dplyr::select(-notes) |>
        dplyr::rename(station_code_dim = station_code),
      by = dplyr::join_by(station_id)
    )

  if ("station_code" %in% names(resolved)) {
    resolved <- resolved |>
      dplyr::select(-station_code_dim)
  } else {
    resolved <- resolved |>
      dplyr::rename(station_code = station_code_dim)
  }

  return(resolved)
}
