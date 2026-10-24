# Fingerprint of an image file

The MD5 sum of the file's bytes: the identity of a photograph that
survives renaming, moving and re-importing, and that changes if and only
if the pixels do.
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
records it next to the coordinates, in the `photo_hash` column of the
workbook and of the journal, so that a specimen renamed – because its
determination was corrected, or its numbering redone – is matched back
to its own measurements instead of re-entering the "new" queue as if it
had never been digitized.

## Usage

``` r
photo_hash(path)
```

## Arguments

- path:

  Character vector of file paths.

## Value

A character vector of MD5 sums, `NA` for a path that does not exist or
cannot be read. Names are dropped, so the result lines up positionally
with `path`.

## See also

[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)

## Examples

``` r
f <- tempfile(fileext = ".txt")
writeLines("not really an image", f)
photo_hash(f)
#> [1] "4b2fa4a7a3bff7b2106e618b8c1f370c"
identical(photo_hash(f), photo_hash(f))   # stable
#> [1] TRUE
unlink(f)
```
