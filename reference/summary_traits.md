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
#>                        group    trait   n      mean          sd    min     max
#> 1                            BD_ratio   2 0.2115000 0.001838478 0.2102  0.2128
#> 2        Barbatula barbatula BD_ratio  36 0.3396667 0.899758647 0.1628  5.5873
#> 3              Barbus barbus BD_ratio  10 0.2312400 0.005458775 0.2247  0.2411
#> 4           Gobio occitaniae BD_ratio 338 0.2890476 0.569884042 0.0163 10.7273
#> 5           Lepomis gibbosus BD_ratio   4 0.4071000 0.023965948 0.3858  0.4337
#> 6    Leuciscus burdigalensis BD_ratio  14 0.2593286 0.027835601 0.2161  0.3091
#> 7          Perca fluviatilis BD_ratio  16 0.2827000 0.010066777 0.2628  0.3001
#> 8          Phoxinus phoxinus BD_ratio  34 0.2373794 0.017063691 0.1959  0.2699
#> 9  Phoxinus phoxinus/bigerri BD_ratio   8 0.2441125 0.018669489 0.2246  0.2738
#> 10         Squalius cephalus BD_ratio  96 0.2537021 0.023546241 0.0934  0.2995
```
