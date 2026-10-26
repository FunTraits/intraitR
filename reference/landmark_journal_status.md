# State of the journals in a directory

The first thing to call when a consolidation comes back empty: it says
at once whether the directory is the right one, which journal files it
holds, and how many records each contains. A journal with 0 records is
the normal trace of a session opened and closed without saving anything
– the app creates the file at LAUNCH, not at the first save.

## Usage

``` r
landmark_journal_status(journal_dir)
```

## Arguments

- journal_dir:

  Journal directory.

## Value

A `data.frame` (invisibly `NULL` if the directory does not exist or
holds no journal), one row per file: `file`, `bytes`, `n_lines`,
`n_records`, `n_points`, `start`, `end`. A summary is also printed as
messages.

## See also

[`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md),
[`landmark_journal_history()`](https://funtraits.github.io/intraitR/reference/landmark_journal_history.md),
[`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_status_demo")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/RtmpwneMMD/journal_status_demo/landmarks_AT_20261026T083948Z.tsv
landmark_journal_append(jr, "fish_01", cbind(c(10, 60), c(20, 22)), 1:2)
landmark_journal_status(d)
#> Directory: /tmp/RtmpwneMMD/journal_status_demo
#> 1 file(s), 1 record(s), 2 point(s) in total.
#>                                file bytes n_lines n_records n_points
#> 1 landmarks_AT_20261026T083948Z.tsv   438       2         1        2
#>                      start                      end
#> 1 2026-10-26T08:39:48.808Z 2026-10-26T08:39:48.808Z
unlink(d, recursive = TRUE)
```
