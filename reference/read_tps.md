# Import landmark coordinates from a tpsDig (`.tps`) file

Reads a `tpsDig`/`tpsUtil`-formatted `.tps` file containing
two-dimensional landmark coordinates for a set of specimens, and returns
them as a geomorph-style array, optionally merged with specimen-level
metadata (species, population, standard length, etc.) and together with
the digitization scale (units per pixel) when present in the file.

## Usage

``` r
read_tps(
  file,
  specID = c("imageID", "ID", "None"),
  metadata = NULL,
  negNA = FALSE
)
```

## Arguments

- file:

  Character. Path to a `.tps` file.

- specID:

  Character, one of `"imageID"` (default), `"ID"`, or `"None"`. Controls
  how specimen identifiers are built: from the `IMAGE=` field, from the
  `ID=` field, or as sequential `specimen_1, specimen_2, ...` labels.

- metadata:

  Optional `data.frame` of specimen-level metadata. Row names, or a
  column named `specimen`, must match the specimen identifiers described
  by `specID`.

- negNA:

  Logical, defaults to `FALSE`. If `TRUE`, negative coordinates
  (commonly used to flag missing landmarks in `tpsDig`) are converted to
  `NA`.

## Value

An object of class `"intrait_landmarks"`, a list with elements:

- coords:

  a `p x k x n` numeric array of raw (un-aligned) landmark coordinates,
  `p` landmarks by `k` (2) dimensions by `n` specimens, following the
  geomorph array convention.

- scale:

  a named numeric vector of scale factors (real-world units per pixel),
  one per specimen, taken from the `SCALE=` field of the TPS file (`NA`
  where absent).

- metadata:

  the merged specimen metadata `data.frame`, or `NULL` if `metadata` was
  not supplied.

## Details

TPS files are the de facto exchange format for digitized landmark data
in geometric morphometrics (Rohlf, 2015). All specimens in the file must
share the same number of landmarks (`LM=`); `read_tps()` throws an
informative error otherwise, since a common landmark configuration is
required for any downstream Procrustes analysis. Three-dimensional
(`LM3=`) TPS files are not currently supported; use
[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)
for 3D data.

## References

Rohlf FJ (2015). The tps series of software. Hystrix, 26(1), 9-12.

## See also

[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md)

## Examples

``` r
tps_path <- tempfile(fileext = ".tps")
writeLines(c(
  "LM=3", "10.0 20.0", "15.0 25.0", "20.0 20.0",
  "IMAGE=fish_01.jpg", "ID=1", "SCALE=0.05",
  "LM=3", "11.0 21.0", "16.0 26.0", "21.0 21.0",
  "IMAGE=fish_02.jpg", "ID=2", "SCALE=0.05"
), tps_path)
lm <- read_tps(tps_path)
dim(lm$coords)
#> [1] 3 2 2
lm$scale
#> fish_01.jpg fish_02.jpg 
#>        0.05        0.05 
```
