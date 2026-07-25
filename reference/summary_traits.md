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
#>                     group    trait   n      mean         sd    min     max
#> 1     Barbatula barbatula BD_ratio  58 0.2839431 0.70899456 0.1203  5.5873
#> 2        Gobio occitaniae BD_ratio 637 0.2725691 0.41578074 0.0027 10.7273
#> 3        Lepomis gibbosus BD_ratio   8 0.4069125 0.02060745 0.3827  0.4337
#> 4 Leuciscus burdigalensis BD_ratio  27 0.2587185 0.02699531 0.2161  0.3091
#> 5       Perca fluviatilis BD_ratio  36 0.2773917 0.02248770 0.2172  0.3082
#> 6       Phoxinus phoxinus BD_ratio  90 0.2376356 0.02757381 0.0469  0.2767
#> 7       Squalius cephalus BD_ratio 180 0.2552672 0.02652021 0.0618  0.3517
```
