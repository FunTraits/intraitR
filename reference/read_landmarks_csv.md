# Import landmark coordinates from a generic long-format CSV file

Reads landmark coordinates stored in a "long" (tidy) CSV file, with one
row per specimen/landmark combination, and reshapes them into a
geomorph-style `p x k x n` array. Useful when landmarks were digitized
outside `tpsDig` (e.g. in ImageJ/Fiji, or exported from a database), or
for three-dimensional landmark configurations.

## Usage

``` r
read_landmarks_csv(
  file,
  specimen = "specimen",
  landmark = "landmark",
  coords = c("X", "Y"),
  metadata = NULL,
  ...
)
```

## Arguments

- file:

  Character. Path to a CSV file, or a `data.frame` already loaded in R.

- specimen:

  Character. Name of the column identifying specimens. Defaults to
  `"specimen"`.

- landmark:

  Character. Name of the column identifying landmarks (used only to
  order coordinates consistently within a specimen). Defaults to
  `"landmark"`.

- coords:

  Character vector of column names holding the coordinate values, in
  order (e.g. `c("X", "Y")` for 2D or `c("X", "Y", "Z")` for 3D).
  Defaults to `c("X", "Y")`.

- metadata:

  Optional `data.frame` of specimen-level metadata, as in
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md).

- ...:

  Additional arguments passed to
  [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) when
  `file` is a path (ignored when `file` is already a `data.frame`).

## Value

An object of class `"intrait_landmarks"` (see
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
for details); `scale` is set to `NULL` since long-format CSV files do
not carry a digitization scale.

## See also

[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)

## Examples

``` r
df <- data.frame(
  specimen = rep(c("fish_01", "fish_02"), each = 3),
  landmark = rep(1:3, times = 2),
  X = c(10, 15, 20, 11, 16, 21),
  Y = c(20, 25, 20, 21, 26, 21)
)
lm <- read_landmarks_csv(df)
dim(lm$coords)
#> [1] 3 2 2
```
