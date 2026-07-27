# Read and concatenate every journal in a directory

Tolerant by construction: a last line truncated by a crash is dropped
(mandatory columns missing), and a journal written by an earlier version
(fewer columns) is filled with `NA`. Two workstations' journals merge by
plain concatenation.

## Usage

``` r
landmark_journal_read(journal_dir)
```

## Arguments

- journal_dir:

  Journal directory, or a vector of directories.

## Value

A LONG `data.frame`, one row per point and per record, with the columns
listed in `intraitR:::.INTRAITR_JOURNAL_COLS`. Coordinates, `replicate`,
`quality`, `img_w`, `img_h`, `ruler_mm` and `mm_per_px` are returned
numeric; everything else is character.

## See also

[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_demo3")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/Rtmpz5Qhjp/journal_demo3/landmarks_AT_20260727T141154Z.tsv
landmark_journal_append(jr, "fish_01", cbind(c(10, 60), c(20, 22)), 1:2,
                        specimen = "fish_01", individual = "fish_01")
str(landmark_journal_read(d)[c("specimen", "landmark", "x", "y", "status")])
#> 'data.frame':    2 obs. of  5 variables:
#>  $ specimen: chr  "fish_01" "fish_01"
#>  $ landmark: num  1 2
#>  $ x       : num  10 60
#>  $ y       : num  20 22
#>  $ status  : chr  "clicked" "clicked"
unlink(d, recursive = TRUE)
```
