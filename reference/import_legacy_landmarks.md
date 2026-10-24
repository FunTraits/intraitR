# Fold an earlier digitization into the workbook of the landmarking app

Copies specimens digitized with an EARLIER tool – another workbook,
another application, a hand-kept spreadsheet – into the `measurements`
sheet that
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
reads, so that a specimen already measured somewhere else stops
reappearing in the app's "new" queue.

## Usage

``` r
import_legacy_landmarks(
  from,
  into,
  sheet_from = 1L,
  sheet_into = "measurements",
  id_from = "Code",
  operator_from = "operator",
  x_pattern = "x_{i}",
  y_pattern = "y_{i}",
  points = 1:25,
  consensus = c("median", "mean", "first"),
  operator_keep = NULL,
  ruler_mm = NA_real_,
  label = "legacy",
  journal_dir = NULL,
  overwrite = FALSE,
  dry_run = FALSE,
  tol_bl = 0.05
)
```

## Arguments

- from:

  The earlier digitization: a path to a spreadsheet (`.xlsx`, `.xls`,
  `.csv`) or a `data.frame` already loaded. WIDE layout, one row per
  digitization, with an identifier column and one column per coordinate
  (see `x_pattern`).

- into:

  Path to the workbook of the landmarking app – the `xlsx_path` given to
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).
  It is rewritten in place through
  [`write_xlsx_atomic()`](https://funtraits.github.io/intraitR/reference/write_xlsx_atomic.md),
  which keeps the previous state in a `.prev.xlsx` file; its other
  sheets are carried over untouched. The file may not exist yet, in
  which case it is created.

- sheet_from, sheet_into:

  Sheets to read from and write into. Default the first sheet of `from`,
  and `"measurements"` in `into`.

- id_from:

  Character, the column of `from` holding the specimen identifier. It
  must match the photograph file name without its extension, which is
  what the app uses as `specimen`. Defaults to `"Code"`.

- operator_from:

  Character or `NULL`, the column of `from` naming the operator. When
  several rows share an identifier they are taken to be repeated
  digitizations of ONE specimen and are reduced to a single row (see
  `consensus`). `NULL` treats every row as a distinct specimen and
  errors on duplicated identifiers. Defaults to `"operator"`.

- x_pattern, y_pattern:

  Character templates naming the coordinate columns of `from`, `{i}`
  standing for the landmark number. Defaults `"x_{i}"` and `"y_{i}"`;
  the app's own layout is `"{i}_X"` / `"{i}_Y"`, and the published
  FISHMORPH tables use the latter.

- points:

  Integer landmarks to import. Defaults to `1:25` (the 19 anatomical
  points, the scale bar 20-21, the curvature point 22, the derived head
  base 23 and the two spare hinges 24-25). Points whose columns are
  absent from `from` are silently skipped and stay `NA` in the workbook.

- consensus:

  How several digitizations of one specimen are reduced to the single
  row the workbook holds: `"median"` (default) takes the coordinate-
  wise median over the operators, `"mean"` their centroid, `"first"` the
  first row in file order. See Details.

- operator_keep:

  Character or `NULL`. When given, only the rows of that operator are
  read, and `consensus` is not applied. Use it when one operator is the
  reference and the others are a repeatability set.

- ruler_mm:

  Numeric, the real-world length of the calibration bar (landmarks
  20-21) in millimetres, used to fill `mm_per_px` exactly as the app
  does: `ruler_mm / dist(20, 21)`. `NA` (default) leaves both columns
  empty, and the imported specimens then carry no scale – their pixel
  distances cannot be converted to length units downstream. The T-26
  protocol uses a 10 mm bar.

- label:

  Character, the operator label written on the imported rows. Defaults
  to `"legacy"`; the number of digitizations the consensus was taken
  over is appended (`"legacy_n4"`), so the sheet says how each row was
  obtained.

- journal_dir:

  Optional path to the journal directory of the app (`journal_dir` of
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)).
  When supplied, every imported specimen is also appended to the journal
  with the per-point status `"imported"`, so that
  [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  can rebuild a workbook that still contains them. `NULL` (default)
  writes the sheet only.

- overwrite:

  Logical. `FALSE` (default) imports only the identifiers ABSENT from
  `into`: a row measured with the app is always authoritative over an
  earlier one. `TRUE` replaces the existing rows as well, which discards
  work done in the app and is never what a routine import wants.

- dry_run:

  Logical. `TRUE` reports what would be written and returns it without
  touching any file. Run it first.

- tol_bl:

  Numeric, the relative spread of the standard length (landmarks 1-2)
  tolerated between the digitizations of one specimen before a warning
  is raised. Defaults to `0.05` (5 %). See Details.

## Value

Invisibly, the `data.frame` of the rows that were added (or, under
`dry_run`, that would be), in the schema of the `measurements` sheet.
Zero rows when there was nothing to import.

## Details

The queue of
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
is the set difference between the photographs on disk and the `specimen`
column of the workbook: a specimen measured into a DIFFERENT file is,
from the app's point of view, a specimen that has never been measured.
It is offered again, digitized again, and the corpus quietly acquires
two independent measurements of one fish – the most expensive kind of
error, because nothing in either file says it happened. This function
removes the cause rather than the symptom: after it has run, one
specimen is one row in one workbook.

## What a consensus over operators does, and does not, assume

Reducing several digitizations to one row by a coordinate-wise median
assumes that they are expressed in the SAME frame – the same photograph,
the same pixels. That is the case for a repeatability set, where two
operators clicked one image, and it is the reason no Procrustes fit is
involved: superimposing would remove exactly the differences (position,
size) that are here identical by construction, and would return
coordinates in a frame no photograph is in.

The assumption is testable, and it is tested. The standard length (1-2)
is the same physical quantity for every operator of one specimen, so a
spread between them beyond `tol_bl` means the rows are NOT in one frame
– two shots of the same fish, a resized image, an identifier reused.
Those specimens are listed in a warning and imported all the same: the
function's job is to report the anomaly, not to decide for the analyst
what it means.

`"median"` is the default because a coordinate-wise median tolerates one
operator misplacing one point, which a mean does not. It is not the
geometric median and the resulting configuration is not one operator's
work: it is an estimate, and `mode` says so. `"mean"` gives the
centroid, the classical choice when the digitizations are equally
trustworthy; `"first"` keeps one operator's actual clicks and estimates
nothing.

## Provenance

Imported rows are recognisable in the sheet without any extra column:
`mode` is `"imported(<source file>)"`, `operator` is `<label>_n<k>`,
`app_version` names this function and the package version, and
`timestamp` is the moment of the import. `n_clicked` counts the
landmarks that arrived with finite coordinates and `n_na` those that did
not; `n_seeded`, `n_predicted` and `n_adjusted` are zero, since an
imported configuration went through none of the app's seeding,
prediction or snapping.

Landmark 23, the head base, is DERIVED by the app from landmarks 1, 6
and 9 and the head axis. It is not recomputed here – that geometry lives
in the app – so it stays `NA` unless `from` already carries it.
Reopening an imported specimen in `mode = "correct"` re-derives it on
the spot.

## Idempotence

With `overwrite = FALSE` the function is idempotent: a second call
imports nothing, because every identifier is by then present in `into`.
Running it at the head of a digitizing session is therefore safe, and is
the intended use.

## See also

[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
for the app whose queue this feeds,
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
to rebuild a workbook from the journal,
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)
to read the result back as landmarks

## Examples

``` r
# An earlier digitization of two fish, each measured by two operators.
old <- data.frame(
  Code     = c("F-01", "F-01", "F-02", "F-02"),
  operator = c("op1", "op2", "op1", "op2"),
  x_1 = c(10, 11, 20, 21), y_1 = c(5, 5, 6, 6),
  x_2 = c(90, 91, 80, 81), y_2 = c(5, 6, 6, 5)
)

wb <- file.path(tempdir(), "landmarks.xlsx")
# What would be imported, without writing anything:
add <- import_legacy_landmarks(old, wb, points = 1:2, dry_run = TRUE)
#> <data.frame>: 2 specimen(s) to import into landmarks.xlsx (measurements), 0 already present and left alone.
#> Dry run: nothing written.
add[c("specimen", "operator", "mode", "1_X", "2_X")]
#>   specimen  operator                   mode  1_X  2_X
#> 1     F-01 legacy_n2 imported(<data.frame>) 10.5 90.5
#> 2     F-02 legacy_n2 imported(<data.frame>) 20.5 80.5
```
