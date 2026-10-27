# Append one record (one digitization) to a landmark journal

A "record" is one press of the app's *Save* button: one row per
landmark, all sharing the same `record_id`. Writing is a plain
`cat(append = TRUE)` of a text block built beforehand – the existing
file is never re-read nor rewritten, so an interruption can only
truncate the last line, which
[`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md)
then discards.

## Usage

``` r
landmark_journal_append(
  journal,
  row_key,
  coords,
  points,
  status = NULL,
  specimen = NA,
  individual = NA,
  replicate = 1L,
  photo_file = NA,
  mode = NA,
  target_sheet = NA,
  img_w = NA,
  img_h = NA,
  quality_score = NA,
  ruler_mm = NA,
  mm_per_px = NA,
  photo_hash = NA,
  reviewed = NA,
  reviewed_by = NA,
  review_date = NA,
  collapse_rules = NA,
  species = NA
)
```

## Arguments

- journal:

  A handle from
  [`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md).

- row_key:

  Deduplication key: the saved identifier (an individual, or
  `"<individual>_<operator>_rep<N>"` for a repeated digitization).

- coords:

  Two-column matrix (X, Y) indexed by landmark number.

- points:

  Landmark numbers to record.

- status:

  Optional named character vector (names = point numbers) of per-point
  statuses; see the `status` values in the package `NEWS`. Points
  without a finite coordinate are recorded as `"na"` whatever is passed.

- specimen, individual, replicate, photo_file, mode, target_sheet:

  Record-level metadata, recycled over the points.

- img_w, img_h, ruler_mm, mm_per_px:

  Further record-level metadata.

- quality_score:

  Score of the entry, 1 (unusable) to 5 (excellent); `NA` when not
  scored. (Until intraitR 1.40.0 this was `quality`, on the reversed
  scale.)

- photo_hash:

  Optional MD5 of the image FILE, as returned by
  [`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md).
  This is the identity a rename cannot change: a specimen re-determined,
  and therefore renamed, is matched back to its own measurements on this
  column rather than on `photo_file`.

- reviewed, reviewed_by, review_date:

  Optional review of the ENTRY as a whole – whether anyone has looked at
  it, who, and when. `quality_score` says how good the entry is; these
  say whether the judgement has been made at all, which is a different
  statement: a specimen can be checked AND poor, and that is the state a
  re-photographing list is built from.

- collapse_rules:

  Optional character string listing the coincidence rules DECLARED on
  the specimen, separated by `";"` (for example `"Mo;Hd6"`). A declared
  zero is a measurement, and recording only the geometry it produced
  leaves a reader unable to tell it from an accidental coincidence.

- species:

  Optional species name (`"Genus species"`), recorded by the FISHMORPH
  reference target, whose `row_key` is the species itself.

## Value

The `record_id` written (invisibly), or `NULL` if there was nothing to
write.

## See also

[`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md),
[`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md)

## Examples

``` r
d <- file.path(tempdir(), "journal_demo2")
jr <- landmark_journal_open(d, operator = "AT")
#> Session journal: /tmp/RtmpFjKqwk/journal_demo2/landmarks_AT_20261027T065930Z.tsv
P <- cbind(X = c(10, 60), Y = c(20, 22))
landmark_journal_append(jr, row_key = "fish_01", coords = P, points = 1:2,
                        specimen = "fish_01", individual = "fish_01")
nrow(landmark_journal_read(d))
#> [1] 2
unlink(d, recursive = TRUE)
```
