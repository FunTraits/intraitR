# Correct Procrustes shape coordinates for allometry

Removes the component of shape variation linearly associated with size
(allometry) by regressing Procrustes shape coordinates on log centroid
size and retaining the residuals, re-expressed as shape coordinates at
the sample's mean size. This is useful when comparing shape among
specimens or species that differ substantially in body size, so that
subsequent morphospace or disparity analyses are not simply driven by
size-related shape change.

## Usage

``` r
correct_allometry(gpa, method = c("common", "group"), groups = NULL)
```

## Arguments

- gpa:

  An object of class `"intrait_gpa"`, as returned by
  [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md).

- method:

  Character, one of `"common"` (a single common allometric trajectory
  fitted across all specimens) or `"group"` (allometric trajectories
  allowed to differ by group, e.g. species; requires a `species` column
  in `gpa$metadata`, or the `groups` argument).

- groups:

  Optional factor (or character vector) of group membership, required
  when `method = "group"` if `gpa$metadata` has no `species` column.

## Value

A `p x k x n` array of allometry-corrected shape coordinates, with the
same `dimnames` as `gpa$coords`.

## Details

This implements the "common allometric component" correction described
by Mosimann (1970) and widely used in the geometric morphometrics
literature (e.g. Adams & Nistri, 2010): shape is regressed on log
centroid size, and the residuals are added back to the value predicted
at the mean log centroid size, yielding a size-standardised shape for
every specimen. It is a simplification intended for exploratory use; for
formal hypothesis testing of allometric trajectories, use
[`geomorph::procD.lm()`](https://rdrr.io/pkg/geomorph/man/procD.lm.html)
directly.

## References

Mosimann JE (1970). Size allometry: size and shape variables with
characterizations of the lognormal and generalized gamma distributions.
Journal of the American Statistical Association, 65(330), 930-945.

Adams DC, Nistri A (2010). Ontogenetic convergence and evolution of foot
morphology in European cave salamanders. BMC Evolutionary Biology, 10,
216.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md)

## Examples

``` r
# real T-26 Saudrune data (see ?fishmorph_shape_landmarks for why the
# scale bar and incomplete specimens are dropped before GPA):
fish <- load_t26_saudrune_landmarks()
gpa <- gpa_fish(fishmorph_shape_landmarks(fish))
#> fishmorph_shape_landmarks(): dropping 230 specimen(s) with a missing landmark or unresolved species identification.
corrected <- correct_allometry(gpa)
dim(corrected)
#> [1]  19   2 328
```
