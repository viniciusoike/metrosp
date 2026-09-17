# gh_release.R
# -----------------------------------------------------------------------------
# Release I/O for the two CI scripts, shelling out to the `gh` CLI.
#
# This replaced piggyback, which reaches every release through one memoised
# listing and broke on it twice over. A release created in the same session
# stayed invisible until the memo was cleared, so the first publish created
# `data-latest` and then aborted with "release not found". Worse, any draft
# release killed the listing outright: a draft has no `published_at`, and
# piggyback types that column as character, so building its data.frame failed
# with "values must be length 1, but FUN(X[[1]]) result is length 0".
#
# Drafts are not an edge case here, since usethis drafts one for every version.
# These helpers therefore address releases one tag at a time and never list
# them, which is what makes the publish path immune to both faults.
#
# `gh` ships on GitHub-hosted runners and authenticates from GITHUB_TOKEN.
# Locally it uses whatever `gh auth status` reports.
# -----------------------------------------------------------------------------

github_repo <- function() {
  return(Sys.getenv("GITHUB_REPOSITORY", unset = "viniciusoike/metrosp"))
}

# Runs gh and returns its combined output, tagged with whether it failed.
# Callers that expect failure to be meaningful (a missing release) pass
# `allow_failure = TRUE` and read that attribute; everyone else gets gh's own
# message in the abort, which is what makes a CI log readable.
run_gh <- function(args, allow_failure = FALSE) {
  out <- suppressWarnings(
    system2("gh", args = args, stdout = TRUE, stderr = TRUE)
  )

  status <- attr(out, "status")
  failed <- !is.null(status) && !identical(as.integer(status), 0L)

  if (failed && !allow_failure) {
    cli::cli_abort(c(
      "{.code gh} failed: {.code gh {paste(args, collapse = ' ')}}",
      "x" = paste(out, collapse = "\n")
    ))
  }

  attr(out, "failed") <- failed
  return(out)
}

#' Does a release exist under this tag?
#'
#' @param tag Release tag, such as `"data-latest"`.
#' @param repo Repository in `owner/name` form.
#' @return `TRUE` when the tag resolves to a release, `FALSE` otherwise.
release_exists <- function(tag, repo = github_repo()) {
  out <- run_gh(
    c(
      "release",
      "view",
      shQuote(tag),
      "--repo",
      shQuote(repo),
      "--json",
      "tagName"
    ),
    allow_failure = TRUE
  )

  return(!isTRUE(attr(out, "failed")))
}

#' Create a release, unless the tag already has one.
#'
#' The rolling tag exists after the first run, so an existing release is the
#' steady state rather than an error.
#'
#' @param tag Release tag.
#' @param title Release title.
#' @param notes Release body, as a single string.
#' @param repo Repository in `owner/name` form.
#' @return Invisibly, `TRUE` when a release was created.
create_release <- function(tag, title, notes, repo = github_repo()) {
  if (release_exists(tag, repo)) {
    cli::cli_alert_info("Release {.val {tag}} exists; updating its assets.")
    return(invisible(FALSE))
  }

  # --notes-file rather than --notes: the bodies carry newlines and backticks.
  notes_file <- tempfile(fileext = ".md")
  writeLines(notes, notes_file)
  on.exit(unlink(notes_file), add = TRUE)

  run_gh(c(
    "release",
    "create",
    shQuote(tag),
    "--repo",
    shQuote(repo),
    "--title",
    shQuote(title),
    "--notes-file",
    shQuote(notes_file)
  ))

  cli::cli_alert_success("Created release {.val {tag}}.")
  return(invisible(TRUE))
}

#' Upload assets to a release, replacing any of the same name.
#'
#' @param files Paths to upload.
#' @param tag Release tag.
#' @param repo Repository in `owner/name` form.
#' @return Invisibly, the uploaded paths.
upload_release_assets <- function(files, tag, repo = github_repo()) {
  run_gh(c(
    "release",
    "upload",
    shQuote(tag),
    shQuote(files),
    "--repo",
    shQuote(repo),
    "--clobber"
  ))

  cli::cli_alert_success(
    "Published {length(files)} asset{?s} to {.val {tag}}."
  )
  return(invisible(files))
}

#' Names of the assets attached to a release.
#'
#' @param tag Release tag.
#' @param repo Repository in `owner/name` form.
#' @return Asset names, or a zero-length vector when the release has none.
release_asset_names <- function(tag, repo = github_repo()) {
  out <- run_gh(c(
    "release",
    "view",
    shQuote(tag),
    "--repo",
    shQuote(repo),
    "--json",
    "assets",
    "--jq",
    shQuote(".assets[].name")
  ))

  return(out[nzchar(out)])
}

#' Download every asset attached to a release.
#'
#' @param tag Release tag.
#' @param dest Directory to download into; created when absent.
#' @param repo Repository in `owner/name` form.
#' @return Invisibly, the file names now in `dest`.
download_release_assets <- function(tag, dest, repo = github_repo()) {
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  run_gh(c(
    "release",
    "download",
    shQuote(tag),
    "--repo",
    shQuote(repo),
    "--dir",
    shQuote(dest),
    "--clobber"
  ))

  return(invisible(list.files(dest)))
}
