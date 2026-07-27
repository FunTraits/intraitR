# Write a workbook atomically

[`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
overwrites its target in place: while it is being rewritten (seconds,
for a workbook of several Mb) the file is in an intermediate state, and
an interruption destroys it. This writes to a temporary file in the SAME
directory – a necessary condition for the rename to be atomic, a
cross-volume rename being in fact a copy – then switches by renaming.

## Usage

``` r
write_xlsx_atomic(x, path, keep_prev = TRUE)
```

## Arguments

- x:

  A named list of `data.frame`s (one per sheet), as
  [`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
  takes.

- path:

  Target path.

- keep_prev:

  Keep the previous generation (default `TRUE`).

## Value

`TRUE`, invisibly, if the write succeeded.

## Details

The old file is not deleted but moved to `"<name>.prev.xlsx"`, which
gives a one-generation backup for free. If the final rename fails, the
old file is restored.

## See also

[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)

## Examples

``` r
f <- file.path(tempdir(), "demo_atomic.xlsx")
if (requireNamespace("writexl", quietly = TRUE)) {
  write_xlsx_atomic(list(measurements = data.frame(specimen = "fish_01")), f)
  file.exists(f)
}
#> [1] TRUE
unlink(c(f, sub("\\.xlsx$", ".prev.xlsx", f)))
```
