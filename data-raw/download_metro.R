# download_metro.R
# -------------------------------------------------------
# Downloads raw data files (zip, csv, pdf) from the METRO SP
# transparency portal: https://transparencia.metrosp.com.br/dataset/demanda
#
# Scrapes download links from the portal page using rvest, then
# downloads files to data-raw/metro_sp/metro/ organized by type.
#
# Safe to re-run: skips files that already exist locally and only
# downloads new ones. The downloaded files (~46MB total) are gitignored.
# -------------------------------------------------------

library(dplyr)
library(stringr)

import::from(rvest, read_html, html_elements, html_attr)
import::from(stringi, stri_trans_general)
import::from(here, here)

str_simplify <- function(x) {

  y <- stringi::stri_trans_general(x, id = "latin-ascii")
  y <- stringr::str_replace_all(y, " ", "_")
  y <- stringr::str_to_lower(y)

  return(y)

}

url <- "https://transparencia.metrosp.com.br/dataset/demanda"

page <- read_html(url)

link_download <- page |>
  html_elements(xpath = "//*[@id='data-and-resources']/div/div/ul/li/div/span/a") |>
  html_attr(name = "href")

# Subset only https links
link_download = link_download[str_detect(link_download, "^https")]

link_title = page |>
  html_elements(xpath = "//*[@id='data-and-resources']/div/div/ul/li/div/a") |>
  html_attr(name = "title")

params = tibble(
  url = link_download,
  title = link_title
)

fld <- here("data-raw/metro_sp/metro")

params <- params |>
  mutate(
    name_file = str_remove_all(title, " -"),
    name_file = str_simplify(name_file),
    name_file = str_remove_all(name_file, "/"),
    type_file = str_extract(url, "\\.[a-z]{3}$"),
    year = as.numeric(str_extract(url, "(?<=20)[0-9]{4}")),
    year = if_else(is.na(year), as.numeric(str_extract(name_file, "[0-9]{4}")), year),
    dest_path = case_when(
      type_file == ".zip" ~ here(fld, paste0(name_file, ".zip")),
      type_file == ".csv" ~ here(fld, "csv", paste0(name_file, ".csv")),
      type_file == ".pdf" ~ here(fld, "pdf", paste0(name_file, ".pdf")),
      .default = NA_character_
    )
  )

# Create all output directories
fs::dir_create(c(fld, here(fld, "csv"), here(fld, "pdf")))

# Check which files already exist locally
# Always re-download files from the most recent year since they are updated
# in-place on the portal as new months are published
max_year <- max(params$year, na.rm = TRUE)

params <- params |>
  mutate(file_exists = fs::file_exists(dest_path) & year != max_year)

n_total <- nrow(params)
n_existing <- sum(params$file_exists)
n_new <- n_total - n_existing
n_refreshed <- sum(params$year == max_year, na.rm = TRUE)

cli::cli_alert_info("Found {n_total} file{?s} on portal")
cli::cli_alert_success("{n_existing} file{?s} already downloaded (skipping)")
cli::cli_alert_info("Refreshing {n_refreshed} file{?s} from {max_year} (latest year)")
cli::cli_alert_warning("{n_new} new file{?s} to download")

# Download only new files
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
  cli::cli_alert_success("Done! Downloaded {nrow(to_download)} file{?s}.")

} else {
  cli::cli_alert_success("All files are up to date.")
}

# Zip files need to be unzipped manually or using terminal
list.files(fld, pattern = "\\.csv$", recursive = TRUE)
