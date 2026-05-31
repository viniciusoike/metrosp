# download_metro.R
# -----------------------------------------------------------------------------
# download_metro() scrapes the METRO SP transparency portal and downloads new
# raw files into data-raw/metro_sp/metro/ (gitignored, ~46MB). It re-downloads
# the latest year in place (the portal updates it as new months are published)
# and skips already-present older files. Side-effecting; gated by the `download`
# flag in _targets.R. Returns the raw csv directory path.
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

download_metro <- function() {
  url <- "https://transparencia.metrosp.com.br/dataset/demanda"

  page <- rvest::read_html(url)

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

  # Always re-download files from the most recent year (updated in-place).
  max_year <- max(params$year, na.rm = TRUE)

  params <- params |>
    mutate(file_exists = fs::file_exists(dest_path) & year != max_year)

  to_download <- params |>
    filter(!file_exists) |>
    arrange(year)

  if (nrow(to_download) > 0) {
    cli::cli_progress_bar("Downloading", total = nrow(to_download))
    for (i in seq_len(nrow(to_download))) {
      download.file(to_download$url[[i]], destfile = to_download$dest_path[[i]])
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
