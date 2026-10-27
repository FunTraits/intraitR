# Quick quality control of the journals

Reports, for the LAST record of every key, what a coordinate table does
not show: expected points never placed, points still at their seed
(never checked), points snapped by a convention (`adjusted`: 3 or 4
brought back to the maximum body depth), points declared non-measurable,
and whether the scale is known. Sorted worst first.

## Usage

``` r
landmark_journal_qc(journal_dir, expect = c(1:19, 23L))
```

## Arguments

- journal_dir:

  Journal directory, or a journal already read with
  [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md).

- expect:

  Points a complete specimen must carry. Defaults to the 19 FISHMORPH
  landmarks and the derived head-base point 23; for the FISHMORPH
  reference target, whose records always carry the axis point 22, use
  `c(1:19, 22, 23)`.

## Value

A `data.frame`, one row per key: `row_key`, `specimen`, `species`,
`photo_file`, `timestamp`, `n_missing`/`missing`, `n_seeded`/`seeded`,
`n_adjusted`/`adjusted`, `n_na`, `has_scale`.

## See also

[`landmark_journal_status()`](https://funtraits.github.io/intraitR/reference/landmark_journal_status.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_qc_demo")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/RtmpraTv6S/journal_qc_demo/landmarks_AT_20261027T065629Z.tsv
landmark_journal_append(jr, "fish_01", cbind(c(10, 60), c(20, 22)), 1:2,
                        status = c("1" = "clicked", "2" = "seeded"))
landmark_journal_qc(d, expect = 1:3)
#>   row_key specimen species photo_file                timestamp n_missing
#> 1 fish_01                             2026-10-27T06:56:29.342Z         1
#>   missing n_seeded seeded n_adjusted adjusted n_na has_scale
#> 1       3        1      2          0             0     FALSE
unlink(d, recursive = TRUE)
```
