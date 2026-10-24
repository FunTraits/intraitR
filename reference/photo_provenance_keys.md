# Provenance keys: which photographs came from the same original

[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)
recognises a row by the file it still names, which is exactly what a
rename destroys. For a correction made BEFORE `photo_hash` was recorded
– the whole of any workbook digitized with intraitR 1.30.0 or earlier –
the old name is nowhere and nothing in the table connects the row to any
image. No amount of hashing the current folder can recover that link,
because the link was never written down there.

## Usage

``` r
photo_provenance_keys(dir, field = "source_path")
```

## Arguments

- dir:

  Directory of import journals: tab-separated, one row per (record,
  specimen, field, value), with columns `record_id`, `timestamp`,
  `operator`, `app_version`, `action`, `specimen`, `field`, `value` and
  no header – the format written by the FishInTrait campaign journal.
  Rows with `action == "import"` and `field == "source_path"` are the
  ones read. A directory with nothing of that shape yields an empty map
  rather than an error: absent provenance is a normal state, not a
  failure.

- field:

  Name of the field holding the identifier of the original. Defaults to
  `"source_path"`.

## Value

A named character vector, names = specimen (photograph) codes, values =
the key of the original they were imported from, ready to pass as the
`provenance` argument of
[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md).
A code imported more than once keeps the original it was LAST built
from.

## Details

It was, however, written down by whatever did the renaming. A pipeline
that imports photographs under a naming convention records which
ORIGINAL image became which specimen, and that record is the missing
edge: two specimen codes pointing at the same original are the same
fish. This function reads such a journal and returns the map
[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)
needs.

THE KEY IS AN IDENTIFIER, NOT A MEASUREMENT. What matters is only that
two codes from one original get the same string and codes from different
originals do not; the recorded path of the original does that, costs no
file read, and keeps working after the originals have been archived off
the machine. It is deliberately NOT a fingerprint of the original: the
photographs a digitizing session runs over are usually cropped working
copies, which share no fingerprint with the camera files at all, so a
fingerprint would have to be matched against something that is not
there. Grouping the CODES sidesteps that entirely – and
[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)
still checks the pixel dimensions before it moves any coordinates, so a
grouping that is right about the fish but wrong about the picture is
caught rather than believed.

## See also

[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md),
[`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)

## Examples

``` r
# Two codes, one original: the determination was corrected and the file
# renamed, so the second import is the same fish as the first.
d <- file.path(tempdir(), "provenance_demo")
dir.create(d, showWarnings = FALSE)
writeLines(c(
  paste("r1", "2026-07-28T10:07:55Z", "AT", "0.17.0", "import",
        "SITE_20260427_SQUCEP_004_AT", "source_path", "/raw/T-26-0011.jpeg",
        sep = "\t"),
  paste("r2", "2026-07-31T20:03:36Z", "AT", "0.17.0", "import",
        "SITE_20260427_BARBAR_025_AT", "source_path", "/raw/T-26-0011.jpeg",
        sep = "\t")),
  file.path(d, "campaign_AT_1.tsv"))
photo_provenance_keys(d)
#> SITE_20260427_SQUCEP_004_AT SITE_20260427_BARBAR_025_AT 
#>       "/raw/T-26-0011.jpeg"       "/raw/T-26-0011.jpeg" 
unlink(d, recursive = TRUE)
```
