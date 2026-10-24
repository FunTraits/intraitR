# Match digitized specimens back to renamed photographs

Reconciles a landmark table with a folder of photographs on the
FINGERPRINT of the image files rather than on their names, and re-keys
the rows whose photograph has been renamed since it was digitized. This
is what makes a correction of determination – which renames the file,
and therefore the specimen code – cost a rename and nothing else,
instead of stranding the measurements under a name nothing points to any
more.

## Usage

``` r
reconcile_photo_names(x, photos, hashes = NULL, provenance = NULL)
```

## Arguments

- x:

  A `data.frame` of digitizations in the wide layout written by
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  – one row per digitization, with at least `specimen` and `photo_file`.
  A `photo_hash` column is used when present and created when it is not.

- photos:

  Character vector of image paths – the folder the digitizing session is
  run over.

- hashes:

  Optional pre-computed fingerprints of `photos`, in the same order (see
  [`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md)).
  Supplying them avoids re-reading every file, which matters on a batch
  of several hundred.

- provenance:

  Optional named character vector, names = photograph codes, values = an
  arbitrary key identifying the PHYSICAL SPECIMEN behind the photograph
  (see
  [`photo_provenance_keys()`](https://funtraits.github.io/intraitR/reference/photo_provenance_keys.md)).
  Two codes sharing a key are the same fish, whatever they are called
  now.

  This is the only route to a rename that happened BEFORE `photo_hash`
  was recorded. The fingerprint route needs the old file to still be
  somewhere; after such a rename it is nowhere, and nothing in the table
  connects the row to any image. Matching is therefore done CODE TO CODE
  here – the key groups the codes, and the one whose file is in `photos`
  is the target – which also makes it independent of *which* rendering
  of the photograph the session is run over. A digitizer pointed at
  cropped working copies and a provenance journal recording the original
  camera files have no fingerprint in common, and the grouping does not
  need one.

  Because a key match says the two codes name one fish but nothing about
  the pixels, the COORDINATE FRAME is checked before anything is
  re-keyed: the row's `img_w`/`img_h`, when recorded, must equal the
  dimensions of the target image (a row digitized before those columns
  existed records nothing, so nothing can contradict it and the
  re-keying proceeds). Landmarks are recorded in the pixels of a
  particular rendering, so carrying them onto a differently cropped or
  rescaled copy would move every one of them without changing a single
  recorded number. A frame that does not match is reported, never
  applied.

## Value

A list of two elements: `data`, the table with `photo_hash` filled in
and the renamed rows re-keyed, and `changes`, a `data.frame` with one
row per re-keying (`specimen_old`, `specimen_new`, `photo_file_old`,
`photo_file_new`, `photo_hash`, `status`). `status` is `"renamed"` for a
re-keying that was applied, `"ambiguous"` for a match found and
deliberately not applied (the same image twice, a target code already
taken), and `"frame_changed"` for a provenance match whose target image
has different pixel dimensions from the ones the row was digitized in –
the same fish, but not the same picture, so the coordinates do not
transfer. `changes` has zero rows when the table and the folder already
agree.

## Details

Three things happen, in this order. Rows that carry no `photo_hash`
(written by a version before the column existed) are back-filled from
the file they still name, when it is still there under that name. Rows
whose `photo_hash` matches a photograph now called something else are
re-keyed: `photo_file` takes the new name and `specimen`/`individual`
have their leading photograph code replaced, so the `_i<k>` of a plate
and the `_<operator>_rep<N>` of a repeat are carried across untouched.
Everything else is left exactly as it was.

AMBIGUITY IS NEVER RESOLVED SILENTLY. A fingerprint matching more than
one file in the folder (the same photograph copied twice), or a target
name that another row already occupies, is reported and left alone: a
wrong automatic merge is far more expensive than a rename done by hand,
because it is invisible afterwards.

## See also

[`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)

## Examples

``` r
# Two photographs, one of them digitized and then renamed.
d <- file.path(tempdir(), "photos_demo")
dir.create(d, showWarnings = FALSE)
f1 <- file.path(d, "SITE_20260427_BARBAR_025_AT.jpeg")
writeLines("pixels of fish one", f1)

meas <- data.frame(specimen = "SITE_20260427_SQUCEP_004_AT",
                   individual = "SITE_20260427_SQUCEP_004_AT",
                   photo_file = "SITE_20260427_SQUCEP_004_AT.jpeg",
                   photo_hash = photo_hash(f1),
                   stringsAsFactors = FALSE)

r <- reconcile_photo_names(meas, f1)
r$changes[, c("specimen_old", "specimen_new", "status")]
#>                  specimen_old                specimen_new  status
#> 1 SITE_20260427_SQUCEP_004_AT SITE_20260427_BARBAR_025_AT renamed
r$data$specimen
#> [1] "SITE_20260427_BARBAR_025_AT"
unlink(d, recursive = TRUE)
```
