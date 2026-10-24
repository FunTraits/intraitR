# Read and concatenate every journal in a directory

Tolerant by construction: a last line truncated by a crash is dropped
(mandatory columns missing), and a journal written by an earlier version
(fewer columns) is filled with `NA`. Two workstations' journals merge by
plain concatenation. Columns are matched by NAME, never by position.

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
`quality_score`, `img_w`, `img_h`, `ruler_mm` and `mm_per_px` are
returned numeric; everything else is character.

## Details

Journals written by
[`Rfishmorph::launch_fishmorph_digitizer()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html)
(Rfishmorph up to 0.17) are read too, and translated on the fly – the
files themselves are never modified: `collapse` becomes
`collapse_rules`, `reviewed` `TRUE`/`FALSE` becomes `"yes"`/`"no"`, and
the status `"placed"` becomes `"clicked"` (both mean "put there by
hand").

The quality of an entry is `quality_score`, 1 (unusable) to 5
(excellent), `NA` when not scored. Journals written by intraitR up to
1.40.0 carry a `quality` column on the REVERSED scale (1 = very good);
it is converted on reading, `quality_score = 6 - quality`.

## See also

[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_demo3")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/RtmpgJS8xD/journal_demo3/landmarks_AT_20261024T184945Z.tsv
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
