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
    c(
      "station_member_id",
      "station_id",
      "station_name",
      "station_code",
      "complex_source",
      "notes"
    ),
    names(dim_station)
  )
  missing_alias_cols <- setdiff(
    c("station_name_raw", "station_member_id", "source", "notes"),
    names(dim_station_alias)
  )
  if (length(missing_station_cols) > 0 || length(missing_alias_cols) > 0) {
    cli::cli_abort("Station dimension columns are incomplete.")
  }

  if (anyNA(dim_station$station_member_id)) {
    problems <- c(problems, "dim_station has missing station_member_id values")
  }
  if (anyDuplicated(dim_station$station_member_id)) {
    problems <- c(
      problems,
      "dim_station has duplicate station_member_id values"
    )
  }
  if (anyNA(dim_station$station_id)) {
    problems <- c(problems, "dim_station has missing station_id values")
  }
  if (anyNA(dim_station$station_name)) {
    problems <- c(problems, "dim_station has missing station_name values")
  }
  if (
    anyNA(
      dim_station_alias[c("station_name_raw", "station_member_id", "source")]
    )
  ) {
    problems <- c(problems, "dim_station_alias has missing key values")
  }
  if (anyDuplicated(dim_station_alias[c("source", "station_name_raw")])) {
    problems <- c(problems, "dim_station_alias has duplicate source/name keys")
  }
  missing_members <- setdiff(
    dim_station_alias$station_member_id,
    dim_station$station_member_id
  )
  if (length(missing_members) > 0) {
    problems <- c(
      problems,
      sprintf(
        "aliases reference unknown station_member_id values: %s",
        paste(missing_members, collapse = ", ")
      )
    )
  }

  invalid_member_ids <- !grepl(
    "^[a-z0-9]+(?:-[a-z0-9]+)*$",
    dim_station$station_member_id
  )
  if (any(invalid_member_ids, na.rm = TRUE)) {
    problems <- c(problems, "dim_station has invalid station_member_id slugs")
  }
  invalid_station_ids <- !grepl(
    "^[a-z0-9]+(?:-[a-z0-9]+)*$",
    dim_station$station_id
  )
  if (any(invalid_station_ids, na.rm = TRUE)) {
    problems <- c(problems, "dim_station has invalid station_id slugs")
  }

  complex_sources <- dim_station |>
    dplyr::group_by(station_id) |>
    dplyr::summarise(
      member_count = dplyr::n(),
      source_count = sum(!is.na(complex_source)),
      .groups = "drop"
    ) |>
    dplyr::filter(member_count > 1L, source_count == 0L)
  if (nrow(complex_sources) > 0) {
    problems <- c(
      problems,
      sprintf(
        "multi-name complexes lack an official source: %s",
        paste(complex_sources$station_id, collapse = ", ")
      )
    )
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

  if (!length(source) %in% c(1L, nrow(dat))) {
    cli::cli_abort(
      "{.arg source} must have length 1 or match the {nrow(dat)} data rows."
    )
  }

  dat$.station_source <- source
  resolved <- dat |>
    dplyr::left_join(
      dim_station_alias |>
        dplyr::select(station_name_raw, station_member_id, source),
      by = c("station_name" = "station_name_raw", ".station_source" = "source")
    )

  missing <- resolved |>
    dplyr::filter(is.na(station_member_id)) |>
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
      "i" = "For a rename, add an alias pointing to the existing station_member_id.",
      "i" = "For a new station, add it to dim_station.csv and then add its alias.",
      "i" = "For a footnote marker, fix the source cleaning rather than adding an alias."
    ))
  }

  resolved <- resolved |>
    dplyr::select(-station_name, -.station_source) |>
    dplyr::left_join(
      dim_station |>
        dplyr::select(
          station_member_id,
          station_id,
          station_name,
          station_code
        ) |>
        dplyr::rename(station_code_dim = station_code),
      by = dplyr::join_by(station_member_id)
    )

  if ("station_code" %in% names(resolved)) {
    resolved <- resolved |>
      dplyr::select(-station_code_dim)
  } else {
    resolved <- resolved |>
      dplyr::rename(station_code = station_code_dim)
  }

  resolved <- resolved |>
    dplyr::select(-station_member_id)

  return(resolved)
}
