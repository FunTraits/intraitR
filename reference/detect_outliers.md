# Detect potential digitization outliers from a GPA-aligned sample

Flags specimens whose Procrustes distance to the sample consensus shape
is unusually large, a fast, general-purpose quality-control screen for
landmark digitization errors (mislabelled points, landmarks digitized
out of order, or gross measurement mistakes), in the spirit of the
exploratory outlier screening implemented by
[`geomorph::plotOutliers()`](https://rdrr.io/pkg/geomorph/man/plotOutliers.html).

## Usage

``` r
detect_outliers(gpa, threshold = 3, plot = TRUE)

# S3 method for class 'intrait_outliers'
print(x, ...)
```

## Arguments

- gpa:

  An object of class `"intrait_gpa"` (from
  [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)).

- threshold:

  Numeric, the number of median absolute deviations (MAD) above the
  median Procrustes distance beyond which a specimen is flagged.
  Defaults to `3`. The median and MAD are used, rather than the mean and
  standard deviation, because they are themselves robust to the outliers
  being screened for.

- plot:

  Logical, draw an ordered dot plot of Procrustes distances with flagged
  specimens highlighted and the threshold marked as a dashed line.
  Defaults to `TRUE`.

- x:

  An object of class `"intrait_outliers"`, as returned by
  `detect_outliers()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_outliers"`, a list with elements
`procrustes_distance` (named numeric vector, one value per specimen),
`threshold_value` (the numeric Procrustes-distance cut-off implied by
`threshold`), `outliers` (character vector of flagged specimen names),
and `rank` (a `data.frame` with columns `specimen`,
`procrustes_distance`, `outlier`, ordered from most to least atypical).
Has a dedicated print method; if `plot = TRUE`, a base R plot is also
drawn as a side effect.

Invisibly returns `x`.

## Details

This is a coarse, univariate screen based on overall Procrustes distance
to the consensus shape, intended as a fast first pass rather than a
definitive statistical test: a genuinely unusual but correctly digitized
specimen (e.g. a naturally extreme morphology) will also be flagged,
while a digitization error affecting only a subset of landmarks in a way
that partly cancels out in the overall Procrustes distance could be
missed. Always visually inspect flagged specimens (e.g. with
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
or
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
before excluding them from downstream analyses.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)

## Examples

``` r
# real T-26 Saudrune data (see ?fishmorph_shape_landmarks for why the
# scale bar and incomplete specimens are dropped before GPA):
fish <- load_t26_saudrune_landmarks()
gpa <- gpa_fish(fishmorph_shape_landmarks(fish))
#> fishmorph_shape_landmarks(): dropping 274 specimen(s) with a missing landmark or unresolved species identification.
#> flag_outliers: 183 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0009_Operator_2, T-26-0009_Operator_3, T-26-0009_Operator_4, T-26-0011_Operator_2, T-26-0011_Operator_3, T-26-0052_Operator_1, T-26-0052_Operator_4, T-26-0056_Operator_4, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0067_Operator_3, T-26-0067_Operator_4, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0068_Operator_3, T-26-0068_Operator_4, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0070_Operator_3, T-26-0070_Operator_4, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0071_Operator_4, T-26-0072_Operator_2, T-26-0072_Operator_4, T-26-0073_Operator_2, T-26-0073_Operator_4, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0074_Operator_4, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0075_Operator_4, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0076_Operator_3, T-26-0076_Operator_4, T-26-0077_Operator_2, T-26-0077_Operator_4, T-26-0078_Operator_2, T-26-0078_Operator_4, T-26-0079_Operator_2, T-26-0079_Operator_4, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0080_Operator_3, T-26-0080_Operator_4, T-26-0081_Operator_3, T-26-0081_Operator_4, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0082_Operator_3, T-26-0082_Operator_4, T-26-0083_Operator_3, T-26-0083_Operator_4, T-26-0084_Operator_3, T-26-0084_Operator_4, T-26-0085_Operator_1, T-26-0085_Operator_3, T-26-0085_Operator_4, T-26-0086_Operator_2, T-26-0086_Operator_3, T-26-0086_Operator_4, T-26-0088_Operator_3, T-26-0088_Operator_4, T-26-0090_Operator_2, T-26-0090_Operator_3, T-26-0090_Operator_4, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0091_Operator_3, T-26-0091_Operator_4, T-26-0092_Operator_3, T-26-0092_Operator_4, T-26-0093_Operator_3, T-26-0093_Operator_4, T-26-0094_Operator_1, T-26-0094_Operator_3, T-26-0094_Operator_4, T-26-0095_Operator_4, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0096_Operator_4, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0097_Operator_4, T-26-0098_Operator_2, T-26-0098_Operator_4, T-26-0099_Operator_2, T-26-0099_Operator_4, T-26-0100_Operator_4, T-26-0101_Operator_4, T-26-0102_Operator_4, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0103_Operator_4, T-26-0104_Operator_2, T-26-0104_Operator_4, T-26-0107_Operator_4, T-26-0108_Operator_4, T-26-0109_Operator_4, T-26-0111_Operator_4, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0113_Operator_4, T-26-0114_Operator_4, T-26-0115_Operator_4, T-26-0116_Operator_1, T-26-0116_Operator_4, T-26-0117_Operator_4, T-26-0118_Operator_4, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0120_Operator_4, T-26-0121_Operator_4, T-26-0122_Operator_1, T-26-0122_Operator_4, T-26-0123_Operator_4, T-26-0125_Operator_4, T-26-0126_Operator_4, T-26-0127_Operator_4, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0128_Operator_4, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0130_Operator_4, T-26-0138_Operator_3, T-26-0140_Operator_3, T-26-0141_Operator_3, T-26-0142_Operator_3, T-26-0167_Operator_3, T-26-0168_Operator_3, T-26-0190_Operator_4, T-26-0209_Operator_4, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0263_Operator_4, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0265_Operator_4, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0266_Operator_4, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0268_Operator_4, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0269_Operator_4, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0271_Operator_4, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0272_Operator_4, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0273_Operator_4, T-26-0274_Operator_4, T-26-0275_Operator_4, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0276_Operator_4, T-26-0277_Operator_1, T-26-0277_Operator_4, T-26-0278-1_Operator_1, T-26-0278-2_Operator_1, T-26-0278-2_Operator_2, T-26-0279_Operator_4; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
out <- detect_outliers(gpa, plot = FALSE)
out
#> <intrait_outliers>
#>   183 specimen(s) flagged out of 762 (threshold Procrustes distance = 0.2138)
#>   Flagged: T-26-0009_Operator_2, T-26-0009_Operator_3, T-26-0009_Operator_4, T-26-0011_Operator_2, T-26-0011_Operator_3, T-26-0052_Operator_1, T-26-0052_Operator_4, T-26-0056_Operator_4, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0067_Operator_3, T-26-0067_Operator_4, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0068_Operator_3, T-26-0068_Operator_4, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0070_Operator_3, T-26-0070_Operator_4, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0071_Operator_4, T-26-0072_Operator_2, T-26-0072_Operator_4, T-26-0073_Operator_2, T-26-0073_Operator_4, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0074_Operator_4, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0075_Operator_4, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0076_Operator_3, T-26-0076_Operator_4, T-26-0077_Operator_2, T-26-0077_Operator_4, T-26-0078_Operator_2, T-26-0078_Operator_4, T-26-0079_Operator_2, T-26-0079_Operator_4, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0080_Operator_3, T-26-0080_Operator_4, T-26-0081_Operator_3, T-26-0081_Operator_4, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0082_Operator_3, T-26-0082_Operator_4, T-26-0083_Operator_3, T-26-0083_Operator_4, T-26-0084_Operator_3, T-26-0084_Operator_4, T-26-0085_Operator_1, T-26-0085_Operator_3, T-26-0085_Operator_4, T-26-0086_Operator_2, T-26-0086_Operator_3, T-26-0086_Operator_4, T-26-0088_Operator_3, T-26-0088_Operator_4, T-26-0090_Operator_2, T-26-0090_Operator_3, T-26-0090_Operator_4, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0091_Operator_3, T-26-0091_Operator_4, T-26-0092_Operator_3, T-26-0092_Operator_4, T-26-0093_Operator_3, T-26-0093_Operator_4, T-26-0094_Operator_1, T-26-0094_Operator_3, T-26-0094_Operator_4, T-26-0095_Operator_4, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0096_Operator_4, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0097_Operator_4, T-26-0098_Operator_2, T-26-0098_Operator_4, T-26-0099_Operator_2, T-26-0099_Operator_4, T-26-0100_Operator_4, T-26-0101_Operator_4, T-26-0102_Operator_4, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0103_Operator_4, T-26-0104_Operator_2, T-26-0104_Operator_4, T-26-0107_Operator_4, T-26-0108_Operator_4, T-26-0109_Operator_4, T-26-0111_Operator_4, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0113_Operator_4, T-26-0114_Operator_4, T-26-0115_Operator_4, T-26-0116_Operator_1, T-26-0116_Operator_4, T-26-0117_Operator_4, T-26-0118_Operator_4, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0120_Operator_4, T-26-0121_Operator_4, T-26-0122_Operator_1, T-26-0122_Operator_4, T-26-0123_Operator_4, T-26-0125_Operator_4, T-26-0126_Operator_4, T-26-0127_Operator_4, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0128_Operator_4, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0130_Operator_4, T-26-0138_Operator_3, T-26-0140_Operator_3, T-26-0141_Operator_3, T-26-0142_Operator_3, T-26-0167_Operator_3, T-26-0168_Operator_3, T-26-0190_Operator_4, T-26-0209_Operator_4, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0263_Operator_4, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0265_Operator_4, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0266_Operator_4, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0268_Operator_4, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0269_Operator_4, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0271_Operator_4, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0272_Operator_4, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0273_Operator_4, T-26-0274_Operator_4, T-26-0275_Operator_4, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0276_Operator_4, T-26-0277_Operator_1, T-26-0277_Operator_4, T-26-0278-1_Operator_1, T-26-0278-2_Operator_1, T-26-0278-2_Operator_2, T-26-0279_Operator_4
#> 
#>   Most atypical specimen(s):
#>                specimen procrustes_distance outlier
#>  T-26-0230-1_Operator_2           0.9853878    TRUE
#>    T-26-0056_Operator_4           0.5312928    TRUE
#>    T-26-0052_Operator_1           0.4036186    TRUE
#>    T-26-0075_Operator_1           0.3739731    TRUE
#>    T-26-0271_Operator_2           0.3714985    TRUE
```
