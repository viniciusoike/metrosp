# schema.R
# -----------------------------------------------------------------------------
# The schema contract between the frozen package data and the fresh data
# published to GitHub Releases.
#
# data/*.rda is a frozen snapshot: it ships with the package, backs the offline
# examples and vignettes, and is regenerated ONLY when a schema changes -- never
# because new months arrived. Fresh data comes from get_data(). For that split
# to be safe, something has to notice when a rebuilt dataset stops matching the
# shape of the shipped one; data-raw/schema.json is that something, and
# check_schema() is the gate the scheduled pipeline runs on every refresh.
#
# Column *values* change every month and that is fine. Column names and types
# changing is what invalidates the snapshot.
# -----------------------------------------------------------------------------

.schema_path <- function() here::here("data-raw/schema.json")

# Record the class that actually matters for downstream code. typeof() alone
# loses Date (double) and factor (integer); class()[1] alone is noisy for plain
# atomics.
.col_type <- function(x) {
  cl <- class(x)[[1]]
  if (cl %in% c("Date", "POSIXct", "factor", "difftime")) {
    return(cl)
  }
  if (inherits(x, "sfc")) {
    return("sfc")
  }
  typeof(x)
}

#' Describe one dataset as a schema entry.
#' Data frames record an ordered column -> type map; bare vectors (metro_colors)
#' record their type, length, and names.
dataset_schema <- function(x) {
  if (is.data.frame(x)) {
    return(list(
      kind = "data.frame",
      columns = lapply(x, .col_type)
    ))
  }

  list(
    kind = "vector",
    type = .col_type(x),
    length = length(x),
    names = names(x)
  )
}

#' Build the full schema for a named list of datasets.
build_schema <- function(datasets) {
  lapply(datasets[order(names(datasets))], dataset_schema)
}

#' Write the schema contract to data-raw/schema.json.
write_schema <- function(datasets, path = .schema_path()) {
  jsonlite::write_json(
    build_schema(datasets),
    path,
    auto_unbox = TRUE,
    pretty = TRUE
  )
  cli::cli_alert_success("Schema written to {.path {path}}.")
  invisible(path)
}

read_schema <- function(path = .schema_path()) {
  jsonlite::read_json(path, simplifyVector = FALSE)
}

# --- The gate ----------------------------------------------------------------

.plural <- function(word, x) {
  if (length(x) == 1) word else paste0(word, "s")
}

# Compare one dataset against its recorded entry, returning character() when it
# conforms or one message per problem otherwise.
#
# Messages are built with sprintf, not glue: cli's `{?s}` pluralization is not
# glue syntax, and inside glue() it evaluates `?s` and silently collapses the
# whole string to character(0) -- i.e. it drops the finding instead of
# reporting it.
.diff_entry <- function(name, observed, expected) {
  if (is.null(expected)) {
    return(sprintf("%s: new dataset, absent from schema.json", name))
  }

  if (!identical(observed$kind, expected$kind)) {
    return(sprintf(
      "%s: kind changed (%s -> %s)",
      name,
      expected$kind,
      observed$kind
    ))
  }

  if (observed$kind == "vector") {
    problems <- character()
    if (!identical(observed$type, expected$type)) {
      problems <- c(
        problems,
        sprintf(
          "%s: type changed (%s -> %s)",
          name,
          expected$type,
          observed$type
        )
      )
    }
    if (!identical(as.character(observed$names), as.character(expected$names))) {
      problems <- c(problems, sprintf("%s: names changed", name))
    }
    return(problems)
  }

  obs_cols <- names(observed$columns)
  exp_cols <- names(expected$columns)

  problems <- character()

  added <- setdiff(obs_cols, exp_cols)
  if (length(added) > 0) {
    problems <- c(
      problems,
      sprintf(
        "%s: new %s %s",
        name,
        .plural("column", added),
        paste(added, collapse = ", ")
      )
    )
  }

  dropped <- setdiff(exp_cols, obs_cols)
  if (length(dropped) > 0) {
    problems <- c(
      problems,
      sprintf(
        "%s: missing %s %s",
        name,
        .plural("column", dropped),
        paste(dropped, collapse = ", ")
      )
    )
  }

  # Column order matters: assemble_*() uses select(all_of(...)) and downstream
  # consumers index positionally in places.
  if (length(added) == 0 && length(dropped) == 0) {
    if (!identical(obs_cols, exp_cols)) {
      problems <- c(problems, sprintf("%s: column order changed", name))
    }
  }

  for (col in intersect(obs_cols, exp_cols)) {
    obs_type <- observed$columns[[col]]
    exp_type <- expected$columns[[col]]
    if (!identical(obs_type, exp_type)) {
      problems <- c(
        problems,
        sprintf("%s$%s: type changed (%s -> %s)", name, col, exp_type, obs_type)
      )
    }
  }

  problems
}

#' Check rebuilt datasets against the recorded schema.
#'
#' Hard-fails on any divergence. That failure is the signal to regenerate the
#' frozen snapshot (METROSP_FREEZE=true), bump the version, and note the change
#' -- not something to work around.
#'
#' @param datasets Named list of freshly built datasets.
#' @param path Path to schema.json.
#' @return Invisibly TRUE when everything conforms.
check_schema <- function(datasets, path = .schema_path()) {
  if (!file.exists(path)) {
    cli::cli_abort(c(
      "No schema contract at {.path {path}}.",
      "i" = "Create one with {.code write_schema(datasets)} after a freeze."
    ))
  }

  expected <- read_schema(path)
  observed <- build_schema(datasets)

  problems <- unlist(lapply(
    names(observed),
    function(nm) .diff_entry(nm, observed[[nm]], expected[[nm]])
  ))

  dropped_datasets <- setdiff(names(expected), names(observed))
  if (length(dropped_datasets) > 0) {
    problems <- c(
      problems,
      sprintf("%s: dataset missing from the build", dropped_datasets)
    )
  }

  if (length(problems) > 0) {
    cli::cli_abort(c(
      "Schema drift: the rebuilt data no longer matches the frozen snapshot.",
      stats::setNames(as.character(problems), rep("x", length(problems))),
      "i" = "Regenerate the snapshot with {.code METROSP_FREEZE=true} and
             {.code targets::tar_make()}, then bump the package version and
             update {.file data-raw/schema.json}."
    ))
  }

  cli::cli_alert_success(
    "Schema check passed ({length(observed)} dataset{?s})."
  )
  invisible(TRUE)
}
