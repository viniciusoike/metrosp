# Jan-Sep 2017, transcribed from PDF

METRO published January to September 2017 only as PDFs, and those PDFs hold no
text layer: every page is a screenshot of a table pasted into a document.
`pdftools::pdf_data()` returns 13 boxes per page, all of them the caption. The
numbers were therefore read off the page by eye, once, into the two CSVs in this
directory. Everything downstream reads those CSVs; nothing re-reads the PDFs.

This is a finished one-time job. The notes below exist so the result can be
audited or redone, not because the pipeline runs any of it.

## Why not OCR

Tesseract was tried first and misread the tables. On the January line-level
page it returned `63` for `863`, `aie` for `218`, and dropped three of the five
rows. Rendering at higher DPI does not help, because the embedded rasters are
low-resolution screenshots and the extra pixels carry no extra detail. With
1,086 values to recover and a checksum on every table, reading them directly was
both more accurate and easier to verify than repairing OCR output.

## The three steps

1. **Render.** `render_pdf_2017.R` writes each of the 27 pages to a trimmed
   300 DPI PNG under `img/` (gitignored). It maps files to month and report
   type from the `<n>-<report> - <Month> - 2017.pdf` naming, and aborts if a
   filename disagrees with the slot it lands in.
2. **Transcribe.** Read each PNG and fill in the CSVs below. Both keep the
   shape of the printed table, so a value can be checked against the image
   without pivoting anything.
   - `transcribed_passengers_line_2017.csv` — one row per month, measure and
     metric; one column per line plus `rede`.
   - `transcribed_station_averages_2017.csv` — one row per station plus a
     `TOTAL` row per line; one column per month.
3. **Validate.** `validate_2017.R` checks the transcription against the totals
   printed in the sources. Run it after any edit.
4. **Sanity-check.** `sanity_2017.R` compares the result to the months around
   it, which came from a different source path. Run it to see whether a
   transcribed value is out of line with its own history.

## What validation checks

Each source table prints a total that its other cells have to reproduce, so
each table is its own checksum:

- `Rede` against the sum of the five lines, per metric row.
- Each line's printed `TOTAL` against the sum of its stations.
- Each line's station sum against that line's transported weekday average,
  which comes from the *other* transcribed file and so spans both.
- The station roster against the one the October 2017 data already uses.

Two allowances are built in. Components are rounded to thousands before
printing, so a total over `n` components may drift from the sum of the printed
parts by up to `n/2` — the September source states this in a footnote.
`Máxima Diária` is bounded rather than equated, because each line peaks on its
own day and the network peak is not the sum of the five.

Current state: 80/85 line rows, 42/45 printed station totals and 44/45
cross-checks pass, and the roster matches exactly. Every failure traces to a
defect in the source rather than the transcription; `report_2017.md` lists them.

## What the sanity checks show

`sanity_2017.R` compares each transcribed month to the same calendar month in
2016 and 2018, to its own value six months either side, and to its
month-over-month step in other years. Across the whole window the transcribed
2017 tracks 2018 about two and a half times more closely than 2016 tracks 2017
(median absolute log difference 0.020 against 0.052), and every station it
flags resolves to a neighbouring year being the outlier rather than 2017.

The flags are worth reading anyway, because they surface a defect in the 2016
data — see the last section of `report_2017.md`.

## Feeding the package

`import_historic.R` reads both CSVs through `.import_psg_line_2017_pdf()` and
`.import_stn_avg_2017_pdf()` and binds them ahead of the October-December months
that come from the regular CSV path. Regenerating the processed files therefore
keeps the transcribed months:

```sh
Rscript -e 'targets::tar_source("data-raw/R"); refresh_historic_passengers(); refresh_historic_averages()'
```

Run this under a UTF-8 locale. Under `LC_ALL=C` the accented month names in
`import_historic.R` are mangled as they are sourced, `parse_date()` fails on
every March, and the refresh silently writes `NA` dates for the whole file.
