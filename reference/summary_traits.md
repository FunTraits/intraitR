# Summarise morphological traits by group

Produces a tidy summary (n, mean, standard deviation, min, max) of one
or more morphological traits (e.g. linear distances or ratios), broken
down by a grouping variable such as species or population.

## Usage

``` r
summary_traits(traits, groups)
```

## Arguments

- traits:

  A numeric `data.frame` (or matrix) of traits, one row per specimen, as
  returned by e.g.
  [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)
  or
  [`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md).
  Non-numeric columns are dropped with a warning.

- groups:

  A factor or character vector of the same length as `nrow(traits)`,
  giving the grouping variable.

## Value

A tidy `data.frame` with one row per group/trait combination and columns
`group`, `trait`, `n`, `mean`, `sd`, `min`, `max`.

## See also

[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
[`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md)

## Examples

``` r
# real T-26 Saudrune data; landmark indices follow the FISHMORPH scheme
# (see ?fishmorph_segments)
fish <- load_t26_saudrune_landmarks()
distances <- list(SL = c(1, 2), BD = c(3, 4))
ratios <- morpho_ratios(fish, distances, norm_by = "SL")
summary_traits(ratios[, "BD_ratio", drop = FALSE], fish$metadata$species)
#>                     group    trait   n      mean         sd    min    max
#> 1     Barbatula barbatula BD_ratio  17 0.1916235 0.01972887 0.1604 0.2338
#> 2           Barbus barbus BD_ratio  30 0.2380433 0.01499487 0.2093 0.2745
#> 3             Gobio gobio BD_ratio 288 0.2585097 0.02040952 0.2014 0.3013
#> 4        Lepomis gibbosus BD_ratio   9 0.3898333 0.02093006 0.3586 0.4272
#> 5 Leuciscus burdigalensis BD_ratio   4 0.2447750 0.01711712 0.2215 0.2613
#> 6       Perca fluviatilis BD_ratio  20 0.3212650 0.05064929 0.2295 0.3947
#> 7       Squalius cephalus BD_ratio 126 0.2508476 0.02175640 0.1914 0.3119
```
