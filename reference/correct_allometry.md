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
#> flag_outliers: 84 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0011_Operator_2, T-26-0052_Operator_1, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0072_Operator_2, T-26-0073_Operator_2, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0077_Operator_2, T-26-0078_Operator_2, T-26-0079_Operator_2, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0085_Operator_1, T-26-0086_Operator_2, T-26-0090_Operator_2, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0094_Operator_1, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0098_Operator_2, T-26-0099_Operator_2, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0104_Operator_2, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0116_Operator_1, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0122_Operator_1, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0277_Operator_1, T-26-0278-1_Operator_1, T-26-0278-2_Operator_2; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
corrected <- correct_allometry(gpa)
dim(corrected)
#> [1]  19   2 328
```
