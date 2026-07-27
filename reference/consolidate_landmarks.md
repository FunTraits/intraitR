# Rebuild the landmark table from the journals

Reconstructs, from every journal in `journal_dir`, one row per
digitization in the "wide" layout of the workbook written by
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
(`1_X, 1_Y, ... 24_X, 24_Y`), keeping for each key the LAST record – so
a specimen digitized, then corrected, appears once, corrected. This is
the recovery path: the workbook can be deleted, corrupted, or left
behind by a crashed session, and the data are still there.

## Usage

``` r
consolidate_landmarks(
  journal_dir,
  points = 1:24,
  history = FALSE,
  xlsx_path = NULL
)
```

## Arguments

- journal_dir:

  Journal directory, or a vector of directories.

- points:

  Landmark numbers to lay out as columns. Defaults to `1:24`, what
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  records: the 19 FISHMORPH landmarks, the scale bar (20-21), the
  curvature point (22) and the two entry hinges (23-24). The hinges are
  not landmarks and belong in no shape analysis; they are rebuilt here
  because they define the axis a specimen was digitized under. Pass
  `1:22` to leave them out.

- history:

  Logical. `FALSE` (default) keeps only the last record per key; `TRUE`
  keeps every record, adding `record_id` so the successive corrections
  of one specimen can be told apart and compared. `timestamp` is
  returned either way.

- xlsx_path:

  Optional path; when supplied, the result is also written there with
  [`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html),
  one sheet per group of `target_sheet` (typically `measurements` and
  `bias`).

## Value

A `data.frame`, one row per digitization, with the identification
columns (`specimen`, `individual`, `replicate`, `operator`,
`photo_file`, ...), the coordinate columns, and the per-record status
counts (`n_clicked`, `n_seeded`, `n_predicted`, `n_adjusted`, `n_na`).

## See also

[`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_demo4")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/Rtmpz5Qhjp/journal_demo4/landmarks_AT_20260727T140958Z.tsv
P <- cbind(c(10, 60), c(20, 22))
landmark_journal_append(jr, "fish_01", P, 1:2, specimen = "fish_01",
                        individual = "fish_01", target_sheet = "measurements")
consolidate_landmarks(d, points = 1:2)[c("specimen", "1_X", "2_X")]
#>   specimen 1_X 2_X
#> 1  fish_01  10  60
unlink(d, recursive = TRUE)
```
