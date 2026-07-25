# Quantify intraspecific morphological variability

Combines two complementary approaches to intraspecific variability
commonly used in fish ecomorphology: (i) shape-based morphological
disparity per group, via a permutation test on Procrustes variance
([`geomorph::morphol.disparity()`](https://rdrr.io/pkg/geomorph/man/morphol.disparity.html)),
and (ii) classical coefficients of variation (CV%) of linear traits or
ratios per group.

## Usage

``` r
intraspecific_variability(gpa = NULL, groups, traits = NULL, iter = 999)

# S3 method for class 'intrait_variability'
print(x, ...)
```

## Arguments

- gpa:

  Optional object of class `"intrait_gpa"` (from
  [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)).
  Required for the shape-based disparity analysis.

- groups:

  A factor or character vector giving the grouping variable (e.g.
  species or population), of the same length and order as the specimens
  in `gpa` and/or `traits`.

- traits:

  Optional `data.frame` of linear traits or ratios (e.g. from
  [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)
  or
  [`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md)),
  one row per specimen in the same order as `groups`. Non-numeric
  columns are ignored.

- iter:

  Integer, number of permutations for the disparity test. Defaults to
  `999`.

- x:

  An object of class `"intrait_variability"`, as returned by
  `intraspecific_variability()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_variability"`, a list optionally
containing:

- shape_disparity:

  the `geomorph` `"morphol.disparity"` object (Procrustes variance per
  group, with pairwise permutation p-values), when `gpa` is supplied.

- trait_cv:

  a tidy `data.frame` with columns `group`, `trait`, `n`, `mean`, `sd`,
  `cv_percent`, when `traits` is supplied.

Invisibly returns `x`.

## Details

Procrustes variance (mean squared Procrustes distance to the group mean
shape) is a standard, unit-free measure of shape disparity and is
preferred over CV for shape data because Procrustes coordinates do not
have an interpretable scale on their own axes. Coefficients of variation
remain informative and widely reported for univariate, biologically
interpretable traits (e.g. body depth ratio) and are provided alongside
shape disparity for that reason.

## References

Zelditch ML, Swiderski DL, Sheets HD (2012). Geometric Morphometrics for
Biologists: A Primer (2nd ed). Academic Press.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md),
[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)

## Examples

``` r
# real T-26 Saudrune data (see ?fishmorph_shape_landmarks for why the
# scale bar and incomplete/unidentified specimens are dropped first):
fish <- load_t26_saudrune_landmarks()
fish_shape <- fishmorph_shape_landmarks(fish)
#> fishmorph_shape_landmarks(): dropping 274 specimen(s) with a missing landmark or unresolved species identification.
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 183 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0009_Operator_2, T-26-0009_Operator_3, T-26-0009_Operator_4, T-26-0011_Operator_2, T-26-0011_Operator_3, T-26-0052_Operator_1, T-26-0052_Operator_4, T-26-0056_Operator_4, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0067_Operator_3, T-26-0067_Operator_4, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0068_Operator_3, T-26-0068_Operator_4, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0070_Operator_3, T-26-0070_Operator_4, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0071_Operator_4, T-26-0072_Operator_2, T-26-0072_Operator_4, T-26-0073_Operator_2, T-26-0073_Operator_4, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0074_Operator_4, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0075_Operator_4, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0076_Operator_3, T-26-0076_Operator_4, T-26-0077_Operator_2, T-26-0077_Operator_4, T-26-0078_Operator_2, T-26-0078_Operator_4, T-26-0079_Operator_2, T-26-0079_Operator_4, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0080_Operator_3, T-26-0080_Operator_4, T-26-0081_Operator_3, T-26-0081_Operator_4, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0082_Operator_3, T-26-0082_Operator_4, T-26-0083_Operator_3, T-26-0083_Operator_4, T-26-0084_Operator_3, T-26-0084_Operator_4, T-26-0085_Operator_1, T-26-0085_Operator_3, T-26-0085_Operator_4, T-26-0086_Operator_2, T-26-0086_Operator_3, T-26-0086_Operator_4, T-26-0088_Operator_3, T-26-0088_Operator_4, T-26-0090_Operator_2, T-26-0090_Operator_3, T-26-0090_Operator_4, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0091_Operator_3, T-26-0091_Operator_4, T-26-0092_Operator_3, T-26-0092_Operator_4, T-26-0093_Operator_3, T-26-0093_Operator_4, T-26-0094_Operator_1, T-26-0094_Operator_3, T-26-0094_Operator_4, T-26-0095_Operator_4, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0096_Operator_4, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0097_Operator_4, T-26-0098_Operator_2, T-26-0098_Operator_4, T-26-0099_Operator_2, T-26-0099_Operator_4, T-26-0100_Operator_4, T-26-0101_Operator_4, T-26-0102_Operator_4, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0103_Operator_4, T-26-0104_Operator_2, T-26-0104_Operator_4, T-26-0107_Operator_4, T-26-0108_Operator_4, T-26-0109_Operator_4, T-26-0111_Operator_4, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0113_Operator_4, T-26-0114_Operator_4, T-26-0115_Operator_4, T-26-0116_Operator_1, T-26-0116_Operator_4, T-26-0117_Operator_4, T-26-0118_Operator_4, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0120_Operator_4, T-26-0121_Operator_4, T-26-0122_Operator_1, T-26-0122_Operator_4, T-26-0123_Operator_4, T-26-0125_Operator_4, T-26-0126_Operator_4, T-26-0127_Operator_4, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0128_Operator_4, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0130_Operator_4, T-26-0138_Operator_3, T-26-0140_Operator_3, T-26-0141_Operator_3, T-26-0142_Operator_3, T-26-0167_Operator_3, T-26-0168_Operator_3, T-26-0190_Operator_4, T-26-0209_Operator_4, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0263_Operator_4, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0265_Operator_4, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0266_Operator_4, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0268_Operator_4, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0269_Operator_4, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0271_Operator_4, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0272_Operator_4, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0273_Operator_4, T-26-0274_Operator_4, T-26-0275_Operator_4, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0276_Operator_4, T-26-0277_Operator_1, T-26-0277_Operator_4, T-26-0278-1_Operator_1, T-26-0278-2_Operator_1, T-26-0278-2_Operator_2, T-26-0279_Operator_4; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
distances <- list(SL = c(1, 2), BD = c(3, 4))
ratios <- morpho_ratios(fish_shape, distances, norm_by = "SL")
# \donttest{
iv <- intraspecific_variability(
  gpa = gpa, groups = fish_shape$metadata$species,
  traits = ratios[, "BD_ratio", drop = FALSE], iter = 99
)
iv
#> <intrait_variability>
#> -- Shape (Procrustes variance) disparity --
#> 
#> Call:
#> geomorph::morphol.disparity(f1 = coords ~ 1, groups = ~groups,  
#>     iter = iter, data = gdf, print.progress = FALSE) 
#> 
#> 
#> 
#> Randomized Residual Permutation Procedure Used
#> 100 Permutations
#> 
#> Procrustes variances for defined groups
#>     Barbatula barbatula        Gobio occitaniae        Lepomis gibbosus 
#>              0.05003387              0.03729353              0.04020467 
#> Leuciscus burdigalensis       Perca fluviatilis       Phoxinus phoxinus 
#>              0.01157969              0.03407003              0.05472135 
#>       Squalius cephalus 
#>              0.02571753 
#> 
#> 
#> Pairwise absolute differences between variances
#>                         Barbatula barbatula Gobio occitaniae Lepomis gibbosus
#> Barbatula barbatula             0.000000000      0.012740337      0.009829195
#> Gobio occitaniae                0.012740337      0.000000000      0.002911142
#> Lepomis gibbosus                0.009829195      0.002911142      0.000000000
#> Leuciscus burdigalensis         0.038454176      0.025713839      0.028624981
#> Perca fluviatilis               0.015963842      0.003223505      0.006134647
#> Phoxinus phoxinus               0.004687484      0.017427821      0.014516679
#> Squalius cephalus               0.024316339      0.011576002      0.014487144
#>                         Leuciscus burdigalensis Perca fluviatilis
#> Barbatula barbatula                  0.03845418       0.015963842
#> Gobio occitaniae                     0.02571384       0.003223505
#> Lepomis gibbosus                     0.02862498       0.006134647
#> Leuciscus burdigalensis              0.00000000       0.022490334
#> Perca fluviatilis                    0.02249033       0.000000000
#> Phoxinus phoxinus                    0.04314166       0.020651326
#> Squalius cephalus                    0.01413784       0.008352497
#>                         Phoxinus phoxinus Squalius cephalus
#> Barbatula barbatula           0.004687484       0.024316339
#> Gobio occitaniae              0.017427821       0.011576002
#> Lepomis gibbosus              0.014516679       0.014487144
#> Leuciscus burdigalensis       0.043141660       0.014137837
#> Perca fluviatilis             0.020651326       0.008352497
#> Phoxinus phoxinus             0.000000000       0.029003823
#> Squalius cephalus             0.029003823       0.000000000
#> 
#> 
#> P-Values
#>                         Barbatula barbatula Gobio occitaniae Lepomis gibbosus
#> Barbatula barbatula                    1.00             0.08             0.50
#> Gobio occitaniae                       0.08             1.00             0.89
#> Lepomis gibbosus                       0.50             0.89             1.00
#> Leuciscus burdigalensis                0.04             0.04             0.15
#> Perca fluviatilis                      0.14             0.65             0.75
#> Phoxinus phoxinus                      0.56             0.01             0.44
#> Squalius cephalus                      0.04             0.02             0.40
#>                         Leuciscus burdigalensis Perca fluviatilis
#> Barbatula barbatula                        0.04              0.14
#> Gobio occitaniae                           0.04              0.65
#> Lepomis gibbosus                           0.15              0.75
#> Leuciscus burdigalensis                    1.00              0.08
#> Perca fluviatilis                          0.08              1.00
#> Phoxinus phoxinus                          0.01              0.04
#> Squalius cephalus                          0.17              0.28
#>                         Phoxinus phoxinus Squalius cephalus
#> Barbatula barbatula                  0.56              0.04
#> Gobio occitaniae                     0.01              0.02
#> Lepomis gibbosus                     0.44              0.40
#> Leuciscus burdigalensis              0.01              0.17
#> Perca fluviatilis                    0.04              0.28
#> Phoxinus phoxinus                    1.00              0.01
#> Squalius cephalus                    0.01              1.00
#> 
#> 
#> -- Coefficient of variation (%) of linear traits --
#>                    group    trait   n      mean         sd cv_percent
#>      Barbatula barbatula BD_ratio  39 0.3261308 0.86496555 265.220469
#>         Gobio occitaniae BD_ratio 406 0.2550200 0.03108347  12.188643
#>         Lepomis gibbosus BD_ratio   6 0.4080833 0.02154181   5.278778
#>  Leuciscus burdigalensis BD_ratio  26 0.2569731 0.02592970  10.090434
#>        Perca fluviatilis BD_ratio  34 0.2767676 0.02297231   8.300216
#>        Phoxinus phoxinus BD_ratio  72 0.2378667 0.02895935  12.174617
#>        Squalius cephalus BD_ratio 179 0.2551777 0.02656728  10.411288
# }
```
