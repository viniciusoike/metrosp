# Source defects in the Jan-Sep 2017 PDFs

The checksums described in `README.md` flagged four problems. All four sit in
the published PDFs, not in the transcription. Each entry records what the source
says, how it was detected, and what the transcription stores.

## July: the entrance-by-line report is a duplicate

`20-Entrada de Passageiros por Linha - Julho - 2017.pdf` is titled
"Entrada de Passageiros por Linha" in its filename, but the page it contains is
headed `PASSAGEIROS TRANSPORTADOS POR LINHA²` and reproduces file 21 cell for
cell. July entrance by line was never published.

Stored as absent: `transcribed_passengers_line_2017.csv` has no
`2017-07-01,entrance` rows. July still appears in `passengers_entrance` because
Line 4 comes from the Insper Dataverse, which is unaffected; Lines 1, 2, 3, 5
and 15 have no entrance value for that month.

## June: the transported `Rede` column repeats May

June's transported table prints a `Rede` column identical to May's in all five
rows — 99.239, 3.844, 2.223, 1.138, 3.951 — while the five line columns hold
genuine June figures. Summing them gives 92.004 against a printed 99.239, and
the same gap appears in every other row.

Stored as `NA`, since the printed values demonstrably belong to another month
and the correct network totals were never published. `passengers_transported`
consequently has `NA` for line 99 across all five June 2017 metrics. The five
line-level values are unaffected and are stored as printed.

## May: the station `TOTAL` row repeats April

May's station table prints the `TOTAL` row from April — 1.458, 697, 1.474, 264,
18 — above station columns holding genuine May figures. The cross-check against
the transported weekday average settles which half is wrong: summing May's
stations gives 1.433, 690, 1.450 and 252, and May's transported weekday averages
are 1.435, 690, 1.449 and 251. The station values are right; the printed total
is stale.

Stored as printed, so the CSV still reflects the source. Nothing downstream
consumes the `TOTAL` row — `.import_stn_avg_2017_pdf()` filters it out — so the
defect does not reach any exported dataset.

## May, Line 15: a two-unit disagreement between the two tables

May's station table gives Vila Prudente 10 and Oratório 7, summing to 17, while
the transported weekday average for Line 15 that month is 19. Every other month
agrees within one unit. Two stations allow only one unit of rounding slack, so
this is the single cross-check failure that no other evidence resolves.

Both values are stored as printed. The disagreement is small in absolute terms
and confined to the least-used line.

## Not a 2017 problem: Line 1 stations, February to June 2016

The sanity checks flagged eighteen station-months where 2017 departs from the
mean of 2016 and 2018 by more than a quarter. All of them sit on Line 1 in
February to June, and in all of them 2017 matches 2018 and 2019 while 2016 is
the outlier — São Joaquim reads 33 in 2016 against 57, 57 and 55 in the three
following years, and Santa Cruz reads 97 against 63, 63 and then 119.

Summing each line's stations and comparing to that line's transported weekday
average locates the fault. Line 1 reconciles to within 0.1% in January and in
July to December 2016, and in every month of 2017 to 2019, but sits 13 to 14%
short from February to June 2016:

| Month | Station sum | Line total | Ratio |
|---|---|---|---|
| 2016-01 | 1203 | 1202 | 1.001 |
| 2016-02 | 1174 | 1356 | 0.866 |
| 2016-03 | 1229 | 1432 | 0.858 |
| 2016-04 | 1245 | 1437 | 0.866 |
| 2016-05 | 1227 | 1423 | 0.862 |
| 2016-06 | 1177 | 1374 | 0.857 |
| 2016-07 | 1266 | 1267 | 0.999 |

Those five months are also allocated differently across stations, not merely
scaled down: against January 2016, São Bento loses 24 and Portuguesa-Tietê 20,
while Santa Cruz gains 44 and Sé 32. No other line or year in the file shows
anything comparable — the remaining disagreements are all Line 15, where two or
three stations carrying single-digit values make rounding worth several percent.

This predates the transcription and lives in the 2016 retroactive publication.
It is recorded here because the 2017 checks are what exposed it.

## Rounding

Every figure is printed in thousands, already rounded. Totals therefore differ
from the sum of their printed parts by a few units throughout, which is expected
rather than a defect; September's table carries the footnote "O total da linha
pode ser diferente das soma das estações devido o arredondamento".
