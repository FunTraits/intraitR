# Extract complete-case body-shape landmarks from a FISHMORPH configuration

Prepares a FISHMORPH-scheme `"intrait_landmarks"` object (21+ points;
see
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md))
for Generalised Procrustes Analysis
([`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md))
or any other function that expects a single, complete set of homologous
shape landmarks. Two adjustments are needed before such a configuration
can be treated as pure shape data, and this function applies both at
once: the embedded scale bar (landmarks 20-21) is dropped, since it is a
fixed calibration segment rather than a body landmark and mixing it into
a Procrustes superimposition (which treats every point as part of the
shape) would distort the alignment; and, by default, any specimen
missing one or more of the remaining landmarks (or with a
missing/unresolved species identification, if `species` is supplied) is
dropped, since GPA requires complete configurations.

## Usage

``` r
fishmorph_shape_landmarks(landmarks, species = NULL, drop_incomplete = TRUE)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` with at least the 21
  FISHMORPH landmarks (see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).

- species:

  Optional character vector (or factor), one value per specimen, used
  only to additionally drop specimens with a missing (`NA`) value – e.g.
  an unresolved identification – so that a downstream grouped analysis
  ([`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md),
  [`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
  [`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md))
  never encounters an `NA` group. Defaults to
  `landmarks$metadata$species` if present, otherwise `NULL` (no
  filtering on species).

- drop_incomplete:

  Logical, drop specimens missing one or more of landmarks 1-19 (plus
  22, if present). Defaults to `TRUE`; set to `FALSE` to keep every
  specimen and inspect missingness yourself (e.g. via
  [`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)
  instead of dropping).

## Value

An object of the same class as `landmarks`, with landmarks 20-21 removed
and, if `drop_incomplete`, incomplete/unidentified specimens removed
from `coords`, `metadata`, and `scale` alike.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
fish_shape <- fishmorph_shape_landmarks(fish)
#> fishmorph_shape_landmarks(): dropping 230 specimen(s) with a missing landmark or unresolved species identification.
dim(fish$coords)
#> [1]  21   2 558
dim(fish_shape$coords)
#> [1]  19   2 328
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 84 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0011_Operator_2, T-26-0052_Operator_1, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0072_Operator_2, T-26-0073_Operator_2, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0077_Operator_2, T-26-0078_Operator_2, T-26-0079_Operator_2, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0085_Operator_1, T-26-0086_Operator_2, T-26-0090_Operator_2, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0094_Operator_1, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0098_Operator_2, T-26-0099_Operator_2, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0104_Operator_2, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0116_Operator_1, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0122_Operator_1, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0277_Operator_1, T-26-0278-1_Operator_1, T-26-0278-2_Operator_2; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
gpa
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   328 specimens, 19 landmarks, 2 dimensions
#>   Converged in 3 iteration(s)
#>   Centroid size: mean = 2755.102, range = [437.284, 7511.212]
#>   84 potential Procrustes-distance outlier(s) flagged (see $outlier_screen); most atypical:
#>     T-26-0230-1_Operator_2: distance = 0.9864 (threshold 0.2325)
#>     T-26-0052_Operator_1: distance = 0.3963 (threshold 0.2325)
#>     T-26-0075_Operator_1: distance = 0.3631 (threshold 0.2325)
#>     T-26-0271_Operator_2: distance = 0.3619 (threshold 0.2325)
#>     T-26-0075_Operator_2: distance = 0.3581 (threshold 0.2325)
```
