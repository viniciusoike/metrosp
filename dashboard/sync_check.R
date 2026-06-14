# Guard against drift between the deployable explorer app and the shared
# dashboard sources it copies. The explorer/ directory must stay self-contained
# (deployment bundles only that directory), so shared.R and www/styles.css are
# duplicated there. Run check_explorer_sync() before deploying; call
# sync_explorer_shared() to refresh the copies from the originals.

# Paths relative to the repo root ----

.sync_pairs <- function(root = ".") {
  dash <- file.path(root, "dashboard")
  list(
    c(
      file.path(dash, "shared.R"),
      file.path(dash, "explorer", "shared.R")
    ),
    c(
      file.path(dash, "www", "styles.css"),
      file.path(dash, "explorer", "www", "styles.css")
    )
  )
}

# Error if any copy differs from its source ----

check_explorer_sync <- function(root = ".") {
  drifted <- Filter(
    function(p) {
      !file.exists(p[2]) ||
        !identical(readLines(p[1], warn = FALSE), readLines(p[2], warn = FALSE))
    },
    .sync_pairs(root)
  )
  if (length(drifted) > 0) {
    files <- vapply(drifted, function(p) p[2], character(1))
    stop(
      "Explorer shared files are out of sync with dashboard/:\n  ",
      paste(files, collapse = "\n  "),
      "\nRun sync_explorer_shared() to refresh them.",
      call. = FALSE
    )
  }
  message("Explorer shared files are in sync.")
  invisible(TRUE)
}

# Copy the originals into the explorer app directory ----

sync_explorer_shared <- function(root = ".") {
  for (p in .sync_pairs(root)) {
    dir.create(dirname(p[2]), showWarnings = FALSE, recursive = TRUE)
    file.copy(p[1], p[2], overwrite = TRUE)
  }
  message("Explorer shared files refreshed from dashboard/.")
  invisible(TRUE)
}

# Run the check when sourced non-interactively ----

if (!interactive() && identical(environment(), globalenv())) {
  check_explorer_sync()
}
