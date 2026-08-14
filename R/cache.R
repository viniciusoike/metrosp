# Cache management for remotely published data -------------------------------
#
# `read_metro_demand()` fetches datasets from the `data-latest` GitHub release
# and keeps them on disk between sessions. CRAN forbids writing to a user's
# home filesystem without consent, so the persistent cache is opt-in: until the
# user agrees, downloads land in the session's temporary directory and vanish
# on exit.

the <- new.env(parent = emptyenv())

#' Where metrosp stores downloaded data
#'
#' Resolves the directory that [read_metro_demand()] downloads into. The
#' persistent location is [tools::R_user_dir()]; until you consent to it,
#' downloads go to a session-temporary directory instead.
#'
#' The resolution order is the `metrosp.cache_dir` option, then the
#' `METROSP_CACHE_DIR` environment variable, then the persistent user cache
#' once consent is on record, then a temporary directory.
#'
#' @param create Whether to create the directory if it does not exist.
#'
#' @return The cache directory path, as a string.
#'
#' @family cache
#' @export
#'
#' @examples
#' metrosp_cache_dir()
metrosp_cache_dir <- function(create = FALSE) {
  dir <- getOption("metrosp.cache_dir")

  if (is.null(dir)) {
    dir <- Sys.getenv("METROSP_CACHE_DIR", unset = "")
    if (!nzchar(dir)) dir <- NULL
  }

  if (is.null(dir)) {
    dir <- if (cache_consented()) {
      tools::R_user_dir("metrosp", "cache")
    } else {
      file.path(tempdir(), "metrosp-cache")
    }
  }

  if (isTRUE(create) && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }

  dir
}

#' Allow metrosp to cache data across sessions
#'
#' Records consent to store downloaded datasets under [tools::R_user_dir()], so
#' that [read_metro_demand()] reuses them in later sessions instead of
#' re-downloading into a temporary directory.
#'
#' @param persist Set `FALSE` to withdraw consent and fall back to a
#'   session-temporary cache.
#'
#' @return The resulting cache directory, invisibly.
#'
#' @family cache
#' @export
#'
#' @examples
#' \dontrun{
#' metrosp_cache_enable()
#' }
metrosp_cache_enable <- function(persist = TRUE) {
  marker <- consent_marker()

  if (isTRUE(persist)) {
    dir.create(dirname(marker), recursive = TRUE, showWarnings = FALSE)
    file.create(marker, showWarnings = FALSE)
    the$consent <- TRUE
    cli::cli_alert_success(
      "Caching to {.path {tools::R_user_dir('metrosp', 'cache')}}."
    )
  } else {
    if (file.exists(marker)) file.remove(marker)
    the$consent <- FALSE
    cli::cli_alert_info("Caching to a temporary directory for this session.")
  }

  invisible(metrosp_cache_dir())
}

#' List cached datasets
#'
#' @return A data frame with one row per cached file, holding the vintage tag,
#'   file name, size in bytes, and modification time. Zero rows when the cache
#'   is empty.
#'
#' @family cache
#' @export
#'
#' @examples
#' metrosp_cache_list()
metrosp_cache_list <- function() {
  dir <- metrosp_cache_dir()
  empty <- data.frame(
    vintage = character(0),
    file = character(0),
    bytes = numeric(0),
    modified = as.POSIXct(character(0))
  )

  if (!dir.exists(dir)) {
    return(empty)
  }

  files <- list.files(dir, recursive = TRUE, full.names = TRUE)
  if (length(files) == 0) {
    return(empty)
  }

  info <- file.info(files)
  data.frame(
    vintage = basename(dirname(files)),
    file = basename(files),
    bytes = as.numeric(info$size),
    modified = info$mtime,
    row.names = NULL
  )
}

#' Delete cached datasets
#'
#' @param vintage Vintage to remove, such as `"latest"` or `"2026-08"`. When
#'   `NULL`, removes every cached vintage.
#'
#' @return The number of files removed, invisibly.
#'
#' @family cache
#' @export
#'
#' @examples
#' \dontrun{
#' metrosp_cache_clear()
#' }
metrosp_cache_clear <- function(vintage = NULL) {
  dir <- metrosp_cache_dir()
  target <- if (is.null(vintage)) dir else file.path(dir, vintage_tag(vintage))

  if (!dir.exists(target)) {
    cli::cli_alert_info("Nothing cached in {.path {target}}.")
    return(invisible(0L))
  }

  files <- list.files(target, recursive = TRUE)
  unlink(target, recursive = TRUE)
  cli::cli_alert_success("Removed {length(files)} cached file{?s}.")
  invisible(length(files))
}

# Consent ---------------------------------------------------------------------

consent_marker <- function() {
  file.path(tools::R_user_dir("metrosp", "config"), "cache-consent")
}

cache_consented <- function() {
  if (!is.null(the$consent)) {
    return(the$consent)
  }

  opt <- getOption("metrosp.cache")
  if (!is.null(opt)) {
    return(isTRUE(opt))
  }

  env <- Sys.getenv("METROSP_CACHE", unset = "")
  if (nzchar(env)) {
    return(isTRUE(as.logical(env)))
  }

  file.exists(consent_marker())
}

# Asked at most once per session, and only when a download is about to happen.
# Declining is remembered for the session so the prompt does not repeat.
ask_cache_consent <- function() {
  if (cache_consented() || !interactive() || isTRUE(the$asked)) {
    return(invisible(cache_consented()))
  }

  the$asked <- TRUE
  cli::cli_inform(c(
    "metrosp can keep downloaded data between sessions.",
    "i" = "Location: {.path {tools::R_user_dir('metrosp', 'cache')}}",
    "i" = "Declining uses a temporary directory that is cleared on exit."
  ))

  answer <- utils::askYesNo("Cache downloaded data across sessions?")
  if (isTRUE(answer)) {
    metrosp_cache_enable()
  } else {
    the$consent <- FALSE
  }

  invisible(cache_consented())
}
