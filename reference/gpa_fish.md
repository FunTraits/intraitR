# Generalised Procrustes Analysis for fish landmark configurations

Superimposes a sample of landmark configurations using Generalised
Procrustes Analysis (GPA), removing differences in position, orientation
and scale so that residual variation reflects shape alone. This is a
fish-oriented wrapper around
[`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html).

## Usage

``` r
gpa_fish(landmarks, ...)

# S3 method for class 'intrait_gpa'
print(x, ...)

# S3 method for class 'intrait_gpa'
summary(object, ...)

# S3 method for class 'summary.intrait_gpa'
print(x, ...)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` (from
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
  or
  [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)),
  or a raw `p x k x n` landmark array.

- ...:

  Additional arguments passed on to
  [`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html)
  (e.g. `curves`, `surfaces`, `ProcD`).

- x:

  An object to print: an `"intrait_gpa"` (from `gpa_fish()`) or
  `"summary.intrait_gpa"` (from
  [`summary()`](https://rdrr.io/r/base/summary.html) on one) object.

- object:

  An object of class `"intrait_gpa"`, as returned by `gpa_fish()`.

## Value

An object of class `"intrait_gpa"`, a list with elements:

- coords:

  `p x k x n` array of Procrustes-aligned shape coordinates.

- Csize:

  named numeric vector of centroid sizes, one per specimen; the standard
  measure of overall specimen size in geometric morphometrics.

- consensus:

  `p x k` matrix, the sample mean (consensus) shape.

- iter:

  number of iterations used by
  [`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html)
  to converge.

- metadata:

  specimen metadata carried over from `landmarks`, if present.

Invisibly returns `x`.

A list of class `"summary.intrait_gpa"` (see
`print.summary.intrait_gpa()`), returned visibly.

Invisibly returns `x`.

## Details

Centroid size (`Csize`) is retained explicitly because, unlike
Procrustes shape coordinates, it captures the size component of
morphology and is required for allometry correction
([`correct_allometry()`](https://funtraits.github.io/intraitR/reference/correct_allometry.md))
and to relate shape to body size.

## References

Rohlf FJ, Slice D (1990). Extensions of the Procrustes method for the
optimal superimposition of landmarks. Systematic Zoology, 39(1), 40-59.

## See also

[`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md),
[`correct_allometry()`](https://funtraits.github.io/intraitR/reference/correct_allometry.md),
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
[`fishmorph_shape_landmarks()`](https://funtraits.github.io/intraitR/reference/fishmorph_shape_landmarks.md)

## Examples

``` r
# real T-26 Saudrune data; GPA aligns *shape* only, so the FISHMORPH
# scale bar (points 20-21, a calibration segment, not a body landmark)
# must first be dropped, along with any specimen missing a landmark --
# fishmorph_shape_landmarks() does both:
fish <- load_t26_saudrune_landmarks()
fish_shape <- fishmorph_shape_landmarks(fish)
#> fishmorph_shape_landmarks(): dropping 230 specimen(s) with a missing landmark or unresolved species identification.
gpa <- gpa_fish(fish_shape)
gpa
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   328 specimens, 19 landmarks, 2 dimensions
#>   Converged in 3 iteration(s)
#>   Centroid size: mean = 2755.102, range = [437.284, 7511.212]
```
