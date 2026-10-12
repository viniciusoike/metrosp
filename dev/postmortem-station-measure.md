# Post-mortem: the station table that measured transported passengers, not entries

Written 2026-10-09. Internal log; not shipped (`dev/` is build-ignored).

## Summary

The monthly station table (`station_averages` in 1.x, briefly
`station_entries_monthly` during 2.0 development, now
`station_transported_monthly`) was documented as "entries" from the first
commit on 2026-02-12. Its data was always METRO's *transported* measure. The
error was found on 2026-09-30, about seven and a half months later. In that
time it shipped in 1.1.0, 1.1.1, the 1.2.x line and the 1.2.1 CRAN release.
The values were never wrong; the label and every piece of documentation built
on it were.

## What was wrong

METRO publishes two different station measures, and the package labelled both
"entries".

- **Monthly station table.** Source: *Demanda de Passageiros por Estação*. Each
  interchange value is boardings on that line plus transfers from the other
  lines, which is the transported measure. Summed over a line's stations it
  matches `mdu` in `line_transported_monthly` (median ratio 1.00 on every
  line).
- **`station_entries_daily`.** Source: *Entrada de Passageiros por Estação*.
  This one is entries; its sums match `line_entries_monthly`.

The source states the definition in its own header. Lines 2-3 of the 2016 CSV
read:

```
Demanda* de Passageiros por Estação - Média Dias Úteis (em milhares)
* Corresponde a soma das entradas com as transferências entre linhas
```

## Timeline

| Date | Commit | Event |
|---|---|---|
| 2026-02-12 | `c93b3a2` | Initial commit. `R/data.R` documents `station_averages` as "Average weekday passenger entries in thousands." Unit right, measure wrong. |
| 2026-02-18 | `dcf9a73` | `station_daily` added from the real entries file. Two station tables now share the "entries" label and read as one measure at two frequencies. |
| 2026-06-12 | `d657e31` | Footnote digits stripped from station names ("Sé4", "Luz (3)"). Those markers point to the footnotes that define the measure; the markers were removed, the footnotes were not read. |
| Jun-Aug | | 1.1.0, 1.1.1, 1.2.x and the 1.2.1 CRAN release ship with the mislabel. |
| 2026-08-14 | `5d7a934` | Closest miss. Diagnosing the Feb-Jun 2016 Line 1 defect, we compared station sums with *entrance* `mdu` and got ~1.34. We explained it as "interchange stations are counted under every line they serve", which is the definition of transported, and wrote it into CLAUDE.md as a rule: "never expect the two to match". |
| 2026-09-19 | #25 | 2.0 renames turn `station_averages` into `station_entries_monthly`. The `<grain>_<measure>_<frequency>` convention now encodes the wrong measure in the name. |
| 2026-09-30 18:52 | `87a4997` | `line_transported_monthly` rescaled x1000, so both line tables count individual passengers. |
| 2026-09-30 19:49 | `fc270be` | One hour later, Phase 7 of `dev/plan-2.0.0.md` records the finding: station sums equal transported `mdu`, ratio 1.00. |
| 2026-10-02 | `903353d` | Fix merged in PR #33: rename to `station_transported_monthly`, drop Line 5 turnstile-only rows from Aug 2018, add Line 4 transported. |
| 2026-10-04/05 | `5b7fb8c`, `c9d97e0`, `35ba1be` | Reconciliation checks in `tests/testthat/helper-checks.R`; DESCRIPTION and the article corrected. |
| 2026-10-09 | (untracked) | CLAUDE.md, the last place still carrying the old label and the 1.34 rule, corrected. Phase 7 step 7 had planned this but it was not done. |

**Trigger.** The commits do not record what prompted the discovery. The timing
points to the unit fix: once both line tables used one scale, comparing station
sums against both became a natural step. This is an inference from the
one-hour gap.

## Why it took so long

1. **The label came from the title, not the definition.** METRO calls the whole
   portal "demanda", so *Demanda de Passageiros por Estação* read as generic
   "demand". The definition sits in a header footnote. The readers skip the
   header by design (they locate blocks by `^LINHA`), so the code never looked
   at the one line that said what the numbers were.
2. **Checks ran within each table, not across tables.** The only cross-measure
   check was transported >= entries at line level. A test comparing station
   sums against *both* line tables would have shown 1.00 against 1.34 on day
   one.
3. **The anomaly was explained away and then written down as a rule.** This is
   the main cause. In August the data showed the problem directly. The chosen
   explanation was plausible, internally consistent, and described exactly what
   transported means. Putting it in CLAUDE.md turned a ratio that should have
   raised questions into the expected value; every later session, human or
   agent, would treat 1.34 as normal.
4. **The two line tables used different units.** Transported was in thousands,
   entries in persons. Comparing the station table with each line table took
   extra work, so in practice it was compared only with entries. The mismatch
   was removed on 2026-09-30 and the finding followed within the hour.
5. **Every docs pass repeated the original label.** Roxygen, both vignettes,
   DESCRIPTION, NEWS and the 2.0 rename each reworded the docs without checking
   the definition. Agent-assisted documentation repeats the framing it is
   given, and the naming convention then made the label look authoritative.
6. **The two tables looked like a matched pair.** A monthly and a daily table,
   both called "entries", look like one measure at two frequencies. Nothing
   about that pairing invites suspicion.

## What went right

- Caught before 2.0 was published. `station_entries_monthly` was never uploaded
  to a release, so only the 1.x name `station_averages` needed a legacy mapping
  in `read_metro_demand()`.
- The fix was structural, not only a rename.
  `check_station_transported_agreement()` in `helper-checks.R` runs on the
  snapshot and on every fresh build, with a 2% tolerance and named exclusions
  for the known source defects.
- The same pass found and dropped the Line 5 Dataverse-era rows, which are
  turnstile-only and so neither measure.
- The 2016 Line 1 defect now has a sharper diagnostic: against transported
  `mdu`, healthy months sit at ~1.00 and Feb-Jun 2016 at ~0.86.

## Lessons

- **Take a measure's definition from the source's own text.** When a reader
  skips header rows, read the skipped rows for definitions once. Footnote
  markers point at something; read what they point to before stripping them.
- **Reconcile every new table against every related table, not only the
  closest one.** A ratio that should be 1.0 but is not is a finding, not a
  constant.
- **Do not write an unverified explanation for an anomaly into agent
  instructions.** A rule in CLAUDE.md outlives the reasoning behind it and tells
  future sessions not to look again.
- **Close out the plan's last step.** The CLAUDE.md update was listed in Phase 7
  and skipped, because CLAUDE.md is untracked and no diff or check flags it.
