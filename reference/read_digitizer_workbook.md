# Read a workbook of the digitizer, every landmark included

Reads a sheet of the workbook written by
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
(or rebuilt by
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md))
into an `"intrait_landmarks"` object, with one row of the coordinate
array per landmark NUMBER, from 1 to the largest present (up to 25): the
hinges 22, 24 and 25 of curved specimens are found by their position, so
that
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
measures standard length along them; a landmark absent from the sheet
(23, the derived head base, often) is `NA`. Every other column of the
sheet becomes metadata.

## Usage

``` r
read_digitizer_workbook(path, sheet = "measurements", max_landmark = 25L)
```

## Arguments

- path:

  The workbook (`.xlsx`).

- sheet:

  `"measurements"` (default) or `"bias"` (repeated digitizations: the
  specimen identifier is then built from `individual`, `operator` and
  `replicate` when there is no `specimen` column).

- max_landmark:

  Largest landmark number read.

## Value

An `"intrait_landmarks"` object.

## See also

[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md)

## Examples

``` r
if (FALSE) { # \dontrun{
fish <- read_digitizer_workbook("landmarks.xlsx")
rat  <- fishmorph_ratios(fishmorph_segments(fish, scale_cm = 1))
} # }
```
