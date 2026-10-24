# Fingerprint a batch of images, remembering the answer

[`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md)
reads every byte of every file. On a folder of several hundred
photographs of a few megabytes each that is a second or two from a local
disk, and considerably more from a synchronised folder, where reading a
file can mean fetching it from the cloud. Since a digitizing session
starts by fingerprinting the whole batch, and the batch barely changes
between sessions, the answers are kept in a small table beside the
journals.

## Usage

``` r
photo_hash_cached(path, cache_file)
```

## Arguments

- path:

  Character vector of image paths.

- cache_file:

  Path of the cache (a TSV). Its directory is created if needed. `NULL`
  disables the cache and falls back to
  [`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md).

## Value

A character vector of fingerprints, one per element of `path`.

## Details

A cached fingerprint is reused only when the file's SIZE and
MODIFICATION TIME both still match. That is the usual heuristic and it
has the usual limit – a file rewritten within the timestamp's
resolution, keeping its size, would be missed – but a photograph edited
in place after digitization is a protocol violation of its own, not a
case to be silently absorbed. A rename, which is what the cache exists
to survive, changes neither size nor mtime and is therefore free.

## See also

[`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md),
[`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)

## Examples

``` r
d <- file.path(tempdir(), "hash_cache_demo")
dir.create(d, showWarnings = FALSE)
f <- file.path(d, "a.txt"); writeLines("x", f)
cache <- file.path(d, "cache.tsv")
h1 <- photo_hash_cached(f, cache)
h2 <- photo_hash_cached(f, cache)      # second call reads the cache
identical(h1, h2)
#> [1] TRUE
unlink(d, recursive = TRUE)
```
