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
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 11 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
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
#>     Barbatula barbatula           Barbus barbus             Gobio gobio 
#>             0.006040160             0.004154417             0.004043715 
#>        Lepomis gibbosus Leuciscus burdigalensis       Perca fluviatilis 
#>             0.014434314             0.005134001             0.012281008 
#>       Squalius cephalus 
#>             0.004935003 
#> 
#> 
#> Pairwise absolute differences between variances
#>                         Barbatula barbatula Barbus barbus  Gobio gobio
#> Barbatula barbatula            0.0000000000  0.0018857430 0.0019964453
#> Barbus barbus                  0.0018857430  0.0000000000 0.0001107023
#> Gobio gobio                    0.0019964453  0.0001107023 0.0000000000
#> Lepomis gibbosus               0.0083941540  0.0102798969 0.0103905992
#> Leuciscus burdigalensis        0.0009061589  0.0009795841 0.0010902863
#> Perca fluviatilis              0.0062408477  0.0081265906 0.0082372929
#> Squalius cephalus              0.0011051573  0.0007805857 0.0008912880
#>                         Lepomis gibbosus Leuciscus burdigalensis
#> Barbatula barbatula          0.008394154            0.0009061589
#> Barbus barbus                0.010279897            0.0009795841
#> Gobio gobio                  0.010390599            0.0010902863
#> Lepomis gibbosus             0.000000000            0.0093003129
#> Leuciscus burdigalensis      0.009300313            0.0000000000
#> Perca fluviatilis            0.002153306            0.0071470066
#> Squalius cephalus            0.009499311            0.0001989984
#>                         Perca fluviatilis Squalius cephalus
#> Barbatula barbatula           0.006240848      0.0011051573
#> Barbus barbus                 0.008126591      0.0007805857
#> Gobio gobio                   0.008237293      0.0008912880
#> Lepomis gibbosus              0.002153306      0.0094993112
#> Leuciscus burdigalensis       0.007147007      0.0001989984
#> Perca fluviatilis             0.000000000      0.0073460049
#> Squalius cephalus             0.007346005      0.0000000000
#> 
#> 
#> P-Values
#>                         Barbatula barbatula Barbus barbus Gobio gobio
#> Barbatula barbatula                    1.00          0.05        0.03
#> Barbus barbus                          0.05          1.00        0.88
#> Gobio gobio                            0.03          0.88        1.00
#> Lepomis gibbosus                       0.01          0.01        0.01
#> Leuciscus burdigalensis                0.61          0.52        0.46
#> Perca fluviatilis                      0.01          0.01        0.01
#> Squalius cephalus                      0.19          0.23        0.03
#>                         Lepomis gibbosus Leuciscus burdigalensis
#> Barbatula barbatula                 0.01                    0.61
#> Barbus barbus                       0.01                    0.52
#> Gobio gobio                         0.01                    0.46
#> Lepomis gibbosus                    1.00                    0.01
#> Leuciscus burdigalensis             0.01                    1.00
#> Perca fluviatilis                   0.08                    0.01
#> Squalius cephalus                   0.01                    0.91
#>                         Perca fluviatilis Squalius cephalus
#> Barbatula barbatula                  0.01              0.19
#> Barbus barbus                        0.01              0.23
#> Gobio gobio                          0.01              0.03
#> Lepomis gibbosus                     0.08              0.01
#> Leuciscus burdigalensis              0.01              0.91
#> Perca fluviatilis                    1.00              0.01
#> Squalius cephalus                    0.01              1.00
#> 
#> 
#> -- Coefficient of variation (%) of linear traits --
#>                    group    trait   n      mean         sd cv_percent
#>      Barbatula barbatula BD_ratio  17 0.1916235 0.01972887  10.295639
#>            Barbus barbus BD_ratio  30 0.2380433 0.01499487   6.299217
#>              Gobio gobio BD_ratio 288 0.2585097 0.02040952   7.895067
#>         Lepomis gibbosus BD_ratio   9 0.3898333 0.02093006   5.368977
#>  Leuciscus burdigalensis BD_ratio   4 0.2447750 0.01711712   6.993002
#>        Perca fluviatilis BD_ratio  20 0.3212650 0.05064929  15.765581
#>        Squalius cephalus BD_ratio 126 0.2508476 0.02175640   8.673154
# }
```
