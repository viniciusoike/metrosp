# Cache management for remotely published data -------------------------------
#
# `read_metro_demand()` fetches datasets from the `data-latest` GitHub release
# and keeps them on disk between sessions. The default location follows R's
# platform-specific user cache convention. Users can override it through an
# option or environment variable, or disable persistent caching per read.

#' Inspect cached Metro SP data
#'
#' Lists the files downloaded by [read_metro_demand()]. The cache directory is
#' resolved from the `metrosp.cache_dir` option, then the `METROSP_CACHE_DIR`
#' environment variable, and finally [tools::R_user_dir()]. Printing the
#' result also shows the resolved directory.
#'
#' @return A data frame with one row per cached file, holding the vintage tag,
#'   file name, size in bytes, and modification time. Zero rows when the cache
#'   is empty.
#'
#' @seealso [metrosp_cache_clear()] to remove cached files.
#'
#' @examples
#' metrosp_cache()
#'
#' @export
metrosp_cache <- function() {
  dir <- cache_dir()
  empty <- data.frame(
    vintage = character(0),
    file = character(0),
    bytes = numeric(0),
    modified = as.POSIXct(character(0))
  )

  if (!dir.exists(dir)) {
    return(new_cache_listing(empty, dir))
  }

  files <- list.files(dir, recursive = TRUE, full.names = TRUE)
  if (length(files) == 0) {
    return(new_cache_listing(empty, dir))
  }

  info <- file.info(files)
  listing <- data.frame(
    vintage = basename(dirname(files)),
    file = basename(files),
    bytes = as.numeric(info$size),
    modified = info$mtime,
    row.names = NULL
  )

  return(new_cache_listing(listing, dir))
}

#' Print a Metro SP cache listing
#'
#' @param x A cache listing returned by [metrosp_cache()].
#' @param ... Additional arguments passed to the data-frame print method.
#'
#' @return `x`, invisibly.
#'
#' @rdname metrosp_cache
#' @export
print.metrosp_cache <- function(x, ...) {
  cli::cli_text("Cache directory: {.path {attr(x, 'directory')}}")
  NextMethod("print")
  return(invisible(x))
}

#' Delete cached Metro SP data
#'
#' @param vintage Vintage to remove, such as `"latest"` or `"2026-09"`. When
#'   `NULL`, removes every cached vintage.
#'
#' @return The number of files removed, invisibly.
#'
#' @seealso [metrosp_cache()] to inspect cached files.
#'
#' @examples
#' \dontrun{
#' metrosp_cache_clear("2026-09")
#' metrosp_cache_clear()
#' }
#'
#' @export
metrosp_cache_clear <- function(vintage = NULL) {
  dir <- cache_dir()
  target <- if (is.null(vintage)) dir else file.path(dir, vintage_tag(vintage))

  if (!dir.exists(target)) {
    cli::cli_alert_info("Nothing cached in {.path {target}}.")
    return(invisible(0L))
  }

  files <- list.files(target, recursive = TRUE)
  unlink(target, recursive = TRUE)
  cli::cli_alert_success("Removed {length(files)} cached file{?s}.")
  return(invisible(length(files)))
}

# Internal helpers ------------------------------------------------------------

cache_dir <- function(create = FALSE) {
  dir <- getOption("metrosp.cache_dir")

  if (is.null(dir)) {
    dir <- Sys.getenv("METROSP_CACHE_DIR", unset = "")
    if (!nzchar(dir)) {
      dir <- tools::R_user_dir("metrosp", "cache")
    }
  }

  if (isTRUE(create) && !dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }

  return(dir)
}

new_cache_listing <- function(dat, dir) {
  listing <- structure(
    dat,
    directory = dir,
    class = c("metrosp_cache", class(dat))
  )

  return(listing)
}
