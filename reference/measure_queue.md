# Photographs of a folder, with their species and their measured state

Lists the photographs under `photo_dir` (sub-folders included), attaches
a species to each, and says whether the landmark journal already holds a
measurement of it. This is the table
[`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md)
is built on, exported so that a selection can be prepared or checked at
the console.

## Usage

``` r
measure_queue(photo_dir, species = NULL, journal_dir = NULL, exclude = NULL)
```

## Arguments

- photo_dir:

  Root folder of the photographs.

- species:

  Where the species come from. `NULL`: unknown (`NA`). `"folder"`: the
  name of the folder holding the photograph (one folder per species). A
  data.frame, or the path of a CSV / Excel file, with a column `species`
  and a column naming the photograph (`photo`, `code`, `specimen`,
  `specimen_code` or `file`, with or without extension), and optionally
  a column `source` (or `data_source`, `provenance`: campaign, museum,
  ...), which the hub's Results page filters on. Or a named character
  vector, code -\> species.

- journal_dir:

  Landmark journal of
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
  or a journal already read with
  [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md).
  `NULL`: no measured state (everything is "to measure").

- exclude:

  Folders under `photo_dir` to leave out (for example the output of
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md),
  whose control thumbnails are images too).

## Value

A data.frame, one row per photograph: `code`, `folder`, `subfolder`,
`species`, `source` (provenance, `NA` when the species table has none),
`file`, `path` (absolute), `measured`, `n_records` (records in the
journal: individuals, repeats), `operator`, `timestamp`, `n_missing`
(expected points absent, worst individual), `n_seeded` (points never
moved from their seed) and `has_scale`.

## Details

The photograph's file name without its extension is the specimen code,
as in
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).
Sub-folders are reported as two levels: `folder` (the first one under
`photo_dir`) and `subfolder` (the rest of the path), so that a tree such
as `site/date/` or `species/` can be browsed level by level.

## See also

[`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md)

## Examples

``` r
d <- file.path(tempdir(), "mq_demo", "Gobio occitaniae")
dir.create(d, recursive = TRUE, showWarnings = FALSE)
for (f in file.path(d, c("GOBOCC_001.jpg", "GOBOCC_002.jpg"))) writeLines("x", f)
measure_queue(dirname(d), species = "folder")[c("code", "species", "measured")]
#>         code          species measured
#> 1 GOBOCC_001 Gobio occitaniae    FALSE
#> 2 GOBOCC_002 Gobio occitaniae    FALSE
```
