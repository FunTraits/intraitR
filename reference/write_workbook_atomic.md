# Write an openxlsx workbook atomically

The openxlsx counterpart of
[`write_xlsx_atomic()`](https://funtraits.github.io/intraitR/reference/write_xlsx_atomic.md),
for a workbook EDITED in place (loaded with
[`openxlsx::loadWorkbook()`](https://rdrr.io/pkg/openxlsx/man/loadWorkbook.html),
so its other sheets and columns are carried along): written to a
temporary file in the same directory, then renamed over the target; the
previous generation is kept as `"<name>.prev.xlsx"` and restored if the
rename fails. Used by
[`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
for the FISHMORPH workbook, and by FishInTrait (it replaces
[`Rfishmorph::fm_save_workbook_atomic()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html)).

## Usage

``` r
write_workbook_atomic(wb, path, keep_prev = TRUE)
```

## Arguments

- wb:

  An openxlsx `Workbook` object.

- path:

  Target path.

- keep_prev:

  Keep the previous generation (default `TRUE`).

## Value

`TRUE`, invisibly.

## See also

[`write_xlsx_atomic()`](https://funtraits.github.io/intraitR/reference/write_xlsx_atomic.md)
