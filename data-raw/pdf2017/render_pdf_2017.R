# render_pdf_2017.R
# -----------------------------------------------------------------------------
# Step 1 of the one-time Jan-Sep 2017 extraction (see README.md).
#
# METRO published Jan-Sep 2017 only as PDFs, and those PDFs carry no text layer:
# each page is a pasted screenshot of a table. pdftools::pdf_data() returns 13
# boxes per page (the caption), and tesseract misreads digits at this source
# resolution. The numbers therefore have to be read off the image by eye.
#
# This script renders each PDF to a trimmed 300 DPI PNG for that reading. It is
# the only automated step before transcription; nothing here writes data.
# -----------------------------------------------------------------------------

library(magick)

pdf_dir <- here::here("data-raw/metro_sp/metro/2017")
img_dir <- here::here("data-raw/pdf2017/img")

dir.create(img_dir, showWarnings = FALSE, recursive = TRUE)

# The 2017 folder names files "<n>-<report> - <Month> - 2017.pdf" with n running
# 1..27 over Jan-Sep in a fixed three-report cycle. Both the cycle position and
# the month token are asserted below, so a renamed or reordered upstream file
# fails loudly instead of silently mislabelling a month.
.kinds <- c("station", "entrance", "transport")

.month_tokens <- c(
  "Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set"
)

.kind_patterns <- c(
  station = "por Esta",
  entrance = "Entrada de Passageiros por Linha",
  transport = "Transportados por Linha"
)

#' Map the 2017 PDFs to month/kind, asserting the filename agrees.
index_pdf_2017 <- function(dir = pdf_dir) {
  files <- list.files(dir, pattern = "\\.pdf$", full.names = TRUE)
  n <- as.integer(stringr::str_extract(basename(files), "^[0-9]+"))

  keep <- !is.na(n) & n <= 27
  files <- files[keep]
  n <- n[keep]

  idx <- tibble::tibble(
    n = n,
    path = files,
    month = ((n - 1L) %/% 3L) + 1L,
    kind = .kinds[((n - 1L) %% 3L) + 1L]
  )
  idx <- idx[order(idx$n), ]

  if (nrow(idx) != 27) {
    cli::cli_abort("Expected 27 Jan-Sep PDFs, found {nrow(idx)} in {.path {dir}}.")
  }

  base <- basename(idx$path)
  bad_month <- !stringr::str_detect(base, stringr::fixed(.month_tokens[idx$month]))
  bad_kind <- !stringr::str_detect(base, stringr::fixed(.kind_patterns[idx$kind]))

  if (any(bad_month | bad_kind)) {
    cli::cli_abort(c(
      "Filename does not match its expected month/report slot:",
      rlang::set_names(base[bad_month | bad_kind], "x")
    ))
  }

  idx
}

#' Render one PDF page to a trimmed 300 DPI PNG.
render_one <- function(path, out) {
  img <- magick::image_read_pdf(path, density = 300)
  img <- magick::image_trim(img, fuzz = 5)
  img <- magick::image_border(img, "white", "20x20")
  magick::image_write(img, out, format = "png")
  invisible(out)
}

render_pdf_2017 <- function() {
  idx <- index_pdf_2017()

  idx$img <- file.path(
    img_dir,
    sprintf("2017-%02d_%s.png", idx$month, idx$kind)
  )

  purrr::walk2(idx$path, idx$img, render_one)
  cli::cli_alert_success("Rendered {nrow(idx)} page{?s} to {.path {img_dir}}.")

  invisible(idx)
}

if (!interactive()) {
  render_pdf_2017()
}
