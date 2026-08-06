# download_metro.R
# -----------------------------------------------------------------------------
# download_metro() scrapes the METRO SP transparency portal and downloads new
# raw files into data-raw/metro_sp/metro/ (gitignored, ~46MB). It re-downloads
# the latest year in place (the portal updates it as new months are published)
# and skips already-present older files; force_all = TRUE re-fetches every year.
# Side-effecting; gated by METROSP_DOWNLOAD in _targets.R. Returns the raw csv
# directory path.
#
# Hardened for unattended use: the scrape aborts if the portal yields
# implausibly few links (a layout change must fail the run, not quietly serve
# stale data), and every network call retries with backoff.
#
# Refactored from download_metro.R.
# -----------------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(stringr)

.str_simplify <- function(x) {
  y <- stringi::stri_trans_general(x, id = "latin-ascii")
  y <- stringr::str_replace_all(y, " ", "_")
  y <- stringr::str_to_lower(y)
  return(y)
}

# Minimum plausible number of resource links on the portal page. The dataset
# has carried 28+ files for years; anything near zero means the page markup
# moved, not that METRO deleted its data.
.min_expected_links <- 20L

#' @param force_all Re-download every file, including older years already on
#'   disk. METRO restates already-published years (the 2026-07-29 batch revised
#'   "Demanda - 2016"), and the default incremental logic below would never
#'   notice. CI starts from an empty gitignored raw dir so it always fetches
#'   everything; set this to get the same guarantee locally.
download_metro <- function(force_all = FALSE) {
  url <- "https://transparencia.metrosp.com.br/dataset/demanda"

  # Large yearly CSVs regularly exceed the 60s default.
  old_timeout <- getOption("timeout")
  options(timeout = max(600, old_timeout))
  on.exit(options(timeout = old_timeout), add = TRUE)

  page <- with_retry(rvest::read_html(url), what = "METRO portal fetch")

  link_download <- page |>
    rvest::html_elements(
      xpath = "//*[@id='data-and-resources']/div/div/ul/li/div/span/a"
    ) |>
    rvest::html_attr(name = "href")

  link_download <- link_download[str_detect(link_download, "^https")]

  link_title <- page |>
    rvest::html_elements(
      xpath = "//*[@id='data-and-resources']/div/div/ul/li/div/a"
    ) |>
    rvest::html_attr(name = "title")

  # Fail loudly on a layout change. Without this the scrape returns zero links,
  # `params` is empty, max(year) is -Inf, nothing downloads, and the run reports
  # "All files are up to date" while serving stale data -- the worst outcome for
  # an unattended pipeline.
  n_links <- length(link_download)
  # Local copy: cli treats a `{.name}` expression as a style, not a value.
  min_links <- .min_expected_links

  if (n_links < min_links) {
    cli::cli_abort(c(
      "Found only {n_links} download link{?s} on the METRO portal
       (expected at least {min_links}).",
      "i" = "The page layout at {.url {url}} has probably changed; the XPath
             selectors in {.file data-raw/R/download_metro.R} need updating.",
      "x" = "Refusing to continue -- a partial scrape would silently publish
             stale data."
    ))
  }

  if (length(link_title) != length(link_download)) {
    cli::cli_abort(
      "Scraped {length(link_download)} link{?s} but {length(link_title)}
       title{?s}; the portal markup no longer pairs them reliably."
    )
  }

  params <- tibble(
    url = link_download,
    title = link_title
  )

  fld <- here::here("data-raw/metro_sp/metro")

  params <- params |>
    mutate(
      name_file = str_remove_all(title, " -"),
      name_file = .str_simplify(name_file),
      name_file = str_remove_all(name_file, "/"),
      type_file = str_extract(url, "\\.[a-z]{3}$"),
      year = as.numeric(str_extract(url, "(?<=20)[0-9]{4}")),
      year = if_else(
        is.na(year),
        as.numeric(str_extract(name_file, "[0-9]{4}")),
        year
      ),
      dest_path = case_when(
        type_file == ".zip" ~ here::here(fld, paste0(name_file, ".zip")),
        type_file == ".csv" ~ here::here(fld, "csv", paste0(name_file, ".csv")),
        type_file == ".pdf" ~ here::here(fld, "pdf", paste0(name_file, ".pdf")),
        .default = NA_character_
      )
    )

  fs::dir_create(c(fld, here::here(fld, "csv"), here::here(fld, "pdf")))

  # Always re-download files from the most recent year (updated in-place);
  # force_all extends that to every year, for restatements of older data.
  max_year <- max(params$year, na.rm = TRUE)

  params <- params |>
    mutate(
      file_exists = if (force_all) {
        FALSE
      } else {
        fs::file_exists(dest_path) & year != max_year
      }
    )

  to_download <- params |>
    filter(!file_exists) |>
    arrange(year)

  if (nrow(to_download) > 0) {
    cli::cli_progress_bar("Downloading", total = nrow(to_download))
    for (i in seq_len(nrow(to_download))) {
      with_retry(
        download.file(
          to_download$url[[i]],
          destfile = to_download$dest_path[[i]],
          quiet = TRUE
        ),
        what = "Download of {.file {basename(to_download$dest_path[[i]])}}"
      )
      # Politeness delay between requests to the transparency portal.
      Sys.sleep(2)
      cli::cli_progress_update()
    }
    cli::cli_progress_done()
    cli::cli_alert_success("Downloaded {nrow(to_download)} file{?s}.")
  } else {
    cli::cli_alert_success("All files are up to date.")
  }

  invisible(here::here(fld, "csv"))
}
