# Release fixtures shared by the published-data reader tests.

# Builds a directory shaped like a release: one .rds per dataset plus the
# manifest.json the reader navigates by.
local_fake_release <- function(
  datasets = list(
    line_entries_monthly = data.frame(date = as.Date("2026-01-01"), value = 1)
  ),
  corrupt = character(0),
  env = parent.frame()
) {
  dir <- withr::local_tempdir(.local_envir = env)
  entries <- list()

  for (nm in names(datasets)) {
    path <- file.path(dir, paste0(nm, ".rds"))
    saveRDS(datasets[[nm]], path)
    entries[[nm]] <- list(
      file = basename(path),
      bytes = as.numeric(file.size(path)),
      sha256 = digest::digest(path, algo = "sha256", file = TRUE),
      kind = "data.frame",
      rows = nrow(datasets[[nm]])
    )
  }

  # Rewrite the payload after hashing so the manifest advertises a hash the
  # asset no longer has.
  for (nm in corrupt) {
    saveRDS(data.frame(tampered = TRUE), file.path(dir, paste0(nm, ".rds")))
  }

  jsonlite::write_json(
    list(built_at = "2026-08-13T23:07:37Z", datasets = entries),
    file.path(dir, "manifest.json"),
    auto_unbox = TRUE
  )

  dir
}

# Points the cache at a scratch directory and serves downloads from `release`.
local_release_source <- function(release, env = parent.frame()) {
  cache <- withr::local_tempdir(.local_envir = env)
  withr::local_options(metrosp.cache_dir = cache, .local_envir = env)

  testthat::local_mocked_bindings(
    fetch_url = function(url, path, quiet = FALSE) {
      src <- file.path(release, basename(url))
      if (!file.exists(src)) {
        stop("404: ", url)
      }
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      file.copy(src, path, overwrite = TRUE)
      invisible(path)
    },
    .env = env
  )

  cache
}
