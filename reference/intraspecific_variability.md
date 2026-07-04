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
#> fishmorph_shape_landmarks(): dropping 230 specimen(s) with a missing landmark or unresolved species identification.
gpa <- gpa_fish(fish_shape)
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
#>                                 Barbatula barbatula             Barbus barbus 
#>               0.008872289               0.075758555               0.054149386 
#>          Gobio occitaniae          Lepomis gibbosus   Leuciscus burdigalensis 
#>               0.038237871               0.044575344               0.012927875 
#>         Perca fluviatilis         Phoxinus phoxinus Phoxinus phoxinus/bigerri 
#>               0.039559048               0.058977497               0.069338245 
#>         Squalius cephalus 
#>               0.030266358 
#> 
#> 
#> Pairwise absolute differences between variances
#>                                       Barbatula barbatula Barbus barbus
#>                           0.000000000          0.06688627   0.045277097
#> Barbatula barbatula       0.066886266          0.00000000   0.021609169
#> Barbus barbus             0.045277097          0.02160917   0.000000000
#> Gobio occitaniae          0.029365582          0.03752068   0.015911516
#> Lepomis gibbosus          0.035703055          0.03118321   0.009574042
#> Leuciscus burdigalensis   0.004055586          0.06283068   0.041221511
#> Perca fluviatilis         0.030686759          0.03619951   0.014590338
#> Phoxinus phoxinus         0.050105208          0.01678106   0.004828111
#> Phoxinus phoxinus/bigerri 0.060465956          0.00642031   0.015188859
#> Squalius cephalus         0.021394069          0.04549220   0.023883028
#>                           Gobio occitaniae Lepomis gibbosus
#>                                0.029365582      0.035703055
#> Barbatula barbatula            0.037520685      0.031183211
#> Barbus barbus                  0.015911516      0.009574042
#> Gobio occitaniae               0.000000000      0.006337473
#> Lepomis gibbosus               0.006337473      0.000000000
#> Leuciscus burdigalensis        0.025309995      0.031647469
#> Perca fluviatilis              0.001321177      0.005016296
#> Phoxinus phoxinus              0.020739626      0.014402153
#> Phoxinus phoxinus/bigerri      0.031100374      0.024762901
#> Squalius cephalus              0.007971512      0.014308986
#>                           Leuciscus burdigalensis Perca fluviatilis
#>                                       0.004055586       0.030686759
#> Barbatula barbatula                   0.062830680       0.036199507
#> Barbus barbus                         0.041221511       0.014590338
#> Gobio occitaniae                      0.025309995       0.001321177
#> Lepomis gibbosus                      0.031647469       0.005016296
#> Leuciscus burdigalensis               0.000000000       0.026631173
#> Perca fluviatilis                     0.026631173       0.000000000
#> Phoxinus phoxinus                     0.046049622       0.019418449
#> Phoxinus phoxinus/bigerri             0.056410370       0.029779197
#> Squalius cephalus                     0.017338483       0.009292690
#>                           Phoxinus phoxinus Phoxinus phoxinus/bigerri
#>                                 0.050105208                0.06046596
#> Barbatula barbatula             0.016781058                0.00642031
#> Barbus barbus                   0.004828111                0.01518886
#> Gobio occitaniae                0.020739626                0.03110037
#> Lepomis gibbosus                0.014402153                0.02476290
#> Leuciscus burdigalensis         0.046049622                0.05641037
#> Perca fluviatilis               0.019418449                0.02977920
#> Phoxinus phoxinus               0.000000000                0.01036075
#> Phoxinus phoxinus/bigerri       0.010360748                0.00000000
#> Squalius cephalus               0.028711139                0.03907189
#>                           Squalius cephalus
#>                                 0.021394069
#> Barbatula barbatula             0.045492197
#> Barbus barbus                   0.023883028
#> Gobio occitaniae                0.007971512
#> Lepomis gibbosus                0.014308986
#> Leuciscus burdigalensis         0.017338483
#> Perca fluviatilis               0.009292690
#> Phoxinus phoxinus               0.028711139
#> Phoxinus phoxinus/bigerri       0.039071887
#> Squalius cephalus               0.000000000
#> 
#> 
#> P-Values
#>                                Barbatula barbatula Barbus barbus
#>                           1.00                0.13          0.28
#> Barbatula barbatula       0.13                1.00          0.24
#> Barbus barbus             0.28                0.24          1.00
#> Gobio occitaniae          0.43                0.08          0.32
#> Lepomis gibbosus          0.49                0.32          0.79
#> Leuciscus burdigalensis   0.98                0.04          0.08
#> Perca fluviatilis         0.32                0.13          0.53
#> Phoxinus phoxinus         0.24                0.26          0.80
#> Phoxinus phoxinus/bigerri 0.13                0.75          0.50
#> Squalius cephalus         0.76                0.04          0.15
#>                           Gobio occitaniae Lepomis gibbosus
#>                                       0.43             0.49
#> Barbatula barbatula                   0.08             0.32
#> Barbus barbus                         0.32             0.79
#> Gobio occitaniae                      1.00             0.87
#> Lepomis gibbosus                      0.87             1.00
#> Leuciscus burdigalensis               0.08             0.30
#> Perca fluviatilis                     0.90             0.94
#> Phoxinus phoxinus                     0.06             0.71
#> Phoxinus phoxinus/bigerri             0.12             0.48
#> Squalius cephalus                     0.42             0.77
#>                           Leuciscus burdigalensis Perca fluviatilis
#>                                              0.98              0.32
#> Barbatula barbatula                          0.04              0.13
#> Barbus barbus                                0.08              0.53
#> Gobio occitaniae                             0.08              0.90
#> Lepomis gibbosus                             0.30              0.94
#> Leuciscus burdigalensis                      1.00              0.16
#> Perca fluviatilis                            0.16              1.00
#> Phoxinus phoxinus                            0.06              0.21
#> Phoxinus phoxinus/bigerri                    0.06              0.21
#> Squalius cephalus                            0.28              0.51
#>                           Phoxinus phoxinus Phoxinus phoxinus/bigerri
#>                                        0.24                      0.13
#> Barbatula barbatula                    0.26                      0.75
#> Barbus barbus                          0.80                      0.50
#> Gobio occitaniae                       0.06                      0.12
#> Lepomis gibbosus                       0.71                      0.48
#> Leuciscus burdigalensis                0.06                      0.06
#> Perca fluviatilis                      0.21                      0.21
#> Phoxinus phoxinus                      1.00                      0.62
#> Phoxinus phoxinus/bigerri              0.62                      1.00
#> Squalius cephalus                      0.06                      0.03
#>                           Squalius cephalus
#>                                        0.76
#> Barbatula barbatula                    0.04
#> Barbus barbus                          0.15
#> Gobio occitaniae                       0.42
#> Lepomis gibbosus                       0.77
#> Leuciscus burdigalensis                0.28
#> Perca fluviatilis                      0.51
#> Phoxinus phoxinus                      0.06
#> Phoxinus phoxinus/bigerri              0.03
#> Squalius cephalus                      1.00
#> 
#> 
#> -- Coefficient of variation (%) of linear traits --
#>                      group    trait   n      mean          sd cv_percent
#>                            BD_ratio   1 0.2128000          NA         NA
#>        Barbatula barbatula BD_ratio  19 0.4715211 1.238933160 262.752459
#>              Barbus barbus BD_ratio   5 0.2288200 0.003401764   1.486655
#>           Gobio occitaniae BD_ratio 147 0.2563986 0.027052273  10.550865
#>           Lepomis gibbosus BD_ratio   2 0.4108000 0.032385491   7.883518
#>    Leuciscus burdigalensis BD_ratio  13 0.2558846 0.025680727  10.036057
#>          Perca fluviatilis BD_ratio  14 0.2819429 0.010413801   3.693586
#>          Phoxinus phoxinus BD_ratio  27 0.2415000 0.015366222   6.362825
#>  Phoxinus phoxinus/bigerri BD_ratio   5 0.2528400 0.018433204   7.290462
#>          Squalius cephalus BD_ratio  95 0.2535168 0.023600729   9.309334
# }
```
