# History of the records of one key

Every press of *Save* is kept in the journals, so the successive passes
over one specimen (digitization, then corrections) can be listed and
compared – to check that a correction was taken into account, or to see
who changed what and when.

## Usage

``` r
landmark_journal_history(journal_dir, row_key = NULL)
```

## Arguments

- journal_dir:

  Journal directory, or a journal already read with
  [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md).

- row_key:

  Key(s) to inspect (the saved identifier; the species for the FISHMORPH
  reference target). `NULL` (default) summarises every key.

## Value

A `data.frame`, one row per record, ordered by key then time:
`record_id`, `timestamp`, `operator`, `mode`, `row_key`, `specimen`,
`species`, `photo_file`, `n_points` and the per-status counts
(`n_clicked`, `n_seeded`, `n_predicted`, `n_validated`, `n_adjusted`,
`n_na`).

## See also

[`landmark_journal_status()`](https://funtraits.github.io/intraitR/reference/landmark_journal_status.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
with `history = TRUE` for the coordinates of every pass.

## Examples

``` r
d <- file.path(tempdir(), "journal_history_demo")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/RtmpgJS8xD/journal_history_demo/landmarks_AT_20261024T184944Z.tsv
landmark_journal_append(jr, "fish_01", cbind(c(10, 60), c(20, 22)), 1:2)
landmark_journal_append(jr, "fish_01", cbind(c(11, 60), c(20, 23)), 1:2)
landmark_journal_history(d, "fish_01")
#>                   record_id                timestamp operator mode row_key
#> 1 AT_20261024T184944Z-00001 2026-10-24T18:49:44.977Z       AT      fish_01
#> 2 AT_20261024T184944Z-00002 2026-10-24T18:49:44.979Z       AT      fish_01
#>   specimen species photo_file n_points n_clicked n_seeded n_predicted
#> 1                                    2         2        0           0
#> 2                                    2         2        0           0
#>   n_validated n_adjusted n_na
#> 1           0          0    0
#> 2           0          0    0
unlink(d, recursive = TRUE)
```
