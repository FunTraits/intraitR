# Import landmark coordinates from a generic "wide"-format Excel sheet

Reads landmark coordinates stored in a "wide" spreadsheet layout, one
row per specimen (or per replicate digitization) with one pair of X/Y
columns per landmark (e.g. `X_1, Y_1, X_2, Y_2, ...`, or
`1_X, 1_Y, 2_X, 2_Y, ...`), and reshapes them into a geomorph-style
`p x k x n` array. This is the layout produced directly by most manual
digitization spreadsheets (one column per landmark coordinate, filled in
by hand or copy-pasted from image analysis software), as opposed to the
"long" (tidy) layout expected by
[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md).
An optional second spreadsheet of specimen-level
identifications/metadata (e.g. taxonomic identification, capture date)
can be joined in directly via `species_file`.

## Usage

``` r
read_landmarks_xlsx(
  file,
  sheet = 1,
  n_landmarks,
  x_pattern = "X_{i}",
  y_pattern = "Y_{i}",
  id_cols = "Code",
  specimen = NULL,
  species_file = NULL,
  species_sheet = 1,
  species_by = NULL,
  metadata = NULL,
  ...
)
```

## Arguments

- file:

  Character. Path to an `.xlsx`/`.xls` file.

- sheet:

  Sheet to read: a name or 1-based index, passed to
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html).
  Defaults to the first sheet.

- n_landmarks:

  Integer, the number of landmarks digitized per specimen (i.e. the
  number of X/Y column pairs to look for).

- x_pattern, y_pattern:

  Character, a template for the X/Y column names of landmark `i`, with
  `"{i}"` as a placeholder for the landmark number. Defaults to
  `"X_{i}"`/`"Y_{i}"` (e.g. `X_1, X_2, ..., Y_1, Y_2, ...`, the layout
  of a single-digitization sheet); use `"{i}_X"`/`"{i}_Y"` for a sheet
  organised the other way round (e.g. `1_X, 1_Y, 2_X, 2_Y, ...`, as is
  common in replicate-digitization/repeatability sheets).

- id_cols:

  Character vector of one or more column names that together identify
  each row (e.g. a specimen code, and, if the sheet records more than
  one digitization per specimen, an operator or replicate/measurement
  column). Kept as-is in `metadata`. Rows with a missing value in
  `id_cols[1]` (typically a blank spreadsheet row) are dropped with a
  message.

- specimen:

  `NULL` (default), or a single existing column name to use directly as
  the specimen identifier. When `NULL`, specimen identifiers are built
  by pasting together every column in `id_cols` with `"_"` (e.g.
  `code_operator`, or `code_replicate`), which is almost always the
  desired behaviour when a sheet records more than one digitization per
  specimen (each row must resolve to a unique identifier). Duplicated
  identifiers are made unique (with a warning) via
  [`make.unique()`](https://rdrr.io/r/base/make.unique.html).

- species_file, species_sheet:

  Optional path (and sheet, as `sheet` above) to a second spreadsheet of
  one-row-per-specimen metadata (e.g. species identification) to
  left-join onto the landmark data.

- species_by:

  Character, the column name shared by `file` and `species_file` to join
  on. Defaults to `id_cols[1]` (typically the specimen code column).
  Every column of `species_file` other than `species_by` is added to
  `metadata` as-is (no renaming, no attempt to resolve
  conflicting/uncertain identifications – see Details).

- metadata:

  Optional further `data.frame` of specimen-level metadata, merged in on
  top of `id_cols`/`species_file`, as in
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md).

- ...:

  Additional arguments passed to
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html)
  (e.g. `skip`, `na`, `col_types`).

## Value

An object of class `"intrait_landmarks"` (see
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
for details); `scale` is set to `NULL` since a wide landmark sheet does
not, by itself, carry a digitization scale (see
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)'s
`scale_cm` argument if landmarks 20-21 encode a calibration segment, as
in the FISHMORPH scheme).

## Details

This function generalises the private, one-off cleaning script
originally written to import the real T-26 Saudrune field data
(`Code`/`Utilisateur` columns, `X_1..X_21`/`Y_1..Y_21`; see
`data-raw/t26_saudrune_prepare.R` and
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md))
so that the same "wide spreadsheet" import can be reused directly on new
field seasons or other surveys, without hand-written reshaping code,
whatever the specific column-naming convention (`x_pattern`/`y_pattern`)
or number of landmarks (`n_landmarks`) involved.

Coordinate cells are coerced with
[`as.numeric()`](https://rdrr.io/r/base/numeric.html); spreadsheet cells
that are blank or contain the literal text `"NA"` become `NA` silently
(the normal, expected case for genuinely missing digitizations), while
any other non-numeric cell content triggers a warning naming the
offending column(s), since that usually indicates a data-entry problem
(a stray comment, a mistyped value) rather than an intentionally missing
landmark.

`species_file` performs a plain left-join (via
[`match()`](https://rdrr.io/r/base/match.html), so `file`'s row order
and length are always preserved even if `species_file` has duplicated or
missing keys) and does **not** attempt to reproduce any project-specific
identification-resolution logic (e.g. falling back from a
preliminary/AI-assisted call to a curated one, or flagging uncertain
identifications) – if your identification sheet needs that kind of
resolution before use, do it in R first (e.g. with
[`dplyr::coalesce()`](https://dplyr.tidyverse.org/reference/coalesce.html)
or a custom `data.frame` you then pass to `species_file`/`metadata`), or
inspect the FISHMORPH T-26 case study in
`data-raw/t26_saudrune_prepare.R` for a worked, non-generic example of
exactly that kind of resolution. Likewise, `species_by` values are
matched exactly (after
[`trimws()`](https://rdrr.io/r/base/trimws.html)): inconsistent codes
across the two files (extra whitespace, a stray `"_"` vs `"-"`, a
parenthetical annotation) will not be matched, and should be normalised
in `file`/`species_file` beforehand if needed.

## See also

[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)

## Examples

``` r
if (requireNamespace("readxl", quietly = TRUE) &&
    requireNamespace("writexl", quietly = TRUE)) {
  wide <- data.frame(
    Code = c("fish_01", "fish_02", "fish_03"),
    Utilisateur = c("Op1", "Op1", "Op2"),
    X_1 = c(10, 11, 9), Y_1 = c(20, 21, 19),
    X_2 = c(15, 16, 14), Y_2 = c(25, 26, 24),
    X_3 = c(20, 21, 19), Y_3 = c(20, 21, 19)
  )
  ident <- data.frame(
    Code = c("fish_01", "fish_02", "fish_03"),
    species = c("Gobio occitaniae", "Gobio occitaniae", "Squalius cephalus")
  )
  xlsx_path <- tempfile(fileext = ".xlsx")
  ident_path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(wide, xlsx_path)
  writexl::write_xlsx(ident, ident_path)

  lm <- read_landmarks_xlsx(
    xlsx_path, n_landmarks = 3, id_cols = c("Code", "Utilisateur"),
    species_file = ident_path, species_by = "Code"
  )
  dim(lm$coords)
  lm$metadata
}
#>                Code Utilisateur           species
#> fish_01_Op1 fish_01         Op1  Gobio occitaniae
#> fish_02_Op1 fish_02         Op1  Gobio occitaniae
#> fish_03_Op2 fish_03         Op2 Squalius cephalus
```
