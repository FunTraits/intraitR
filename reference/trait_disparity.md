# Test differences in functional trait dispersion between groups

Tests whether groups (e.g. species) differ in the multivariate
dispersion of their functional traits, using a permutation approach
analogous to
[`geomorph::morphol.disparity()`](https://rdrr.io/pkg/geomorph/man/morphol.disparity.html)
but applied to the standardised trait space built by
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
instead of to Procrustes shape coordinates. For each group, dispersion
is measured as trait variance (the sum of the per-trait variances, i.e.
the trace of the group's trait covariance matrix), computed on the same
log-transformed and standardised data used to build the ordination, so
that the result does not depend on how many axes were retained for
plotting. Pairwise differences in dispersion between groups are tested
against a null distribution obtained by randomly permuting group labels.

## Usage

``` r
trait_disparity(
  x,
  groups = NULL,
  iter = 999,
  log_transform = TRUE,
  scale = TRUE
)
```

## Arguments

- x:

  Either an object of class `"intrait_traitspace"` (from
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
  built with `groups` supplied), or a `data.frame`/matrix of numeric
  traits (one row per specimen), in which case `groups` must also be
  supplied and the same `log_transform`/`scale` preprocessing as
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  is applied before computing dispersion.

- groups:

  Required when `x` is a raw trait table; ignored (taken from
  `x$groups`) when `x` is an `"intrait_traitspace"` object.

- iter:

  Integer, number of random permutations of group labels used to build
  the null distribution. Defaults to `999`.

- log_transform, scale:

  As in
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md);
  only used when `x` is a raw trait table (ignored, and taken from `x`,
  when `x` is an `"intrait_traitspace"` object).

## Value

An object of class `"intrait_disparity"`, a list with elements
`disparity` (named numeric vector of per-group trait variance),
`pairwise_diff` (symmetric matrix of observed absolute pairwise
differences in disparity), `pairwise_p` (symmetric matrix of permutation
p-values for these differences), and `iter`.

## Details

The permutation procedure reassigns the `n` specimens to groups at
random (preserving observed group sizes), recomputes each group's trait
variance, and derives the null distribution of the pairwise differences
from `iter` such permutations plus the observed assignment (the standard
`(iter + 1)`-permutation correction; Anderson, 2001). A group with
significantly higher trait variance than another occupies, on average, a
larger region of standardised functional trait space, consistent with
greater morphological or ecological generalism within that group. Groups
with fewer than two specimens receive a disparity of `NA` and are
excluded from the permutation test.

This function complements
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
which reports shape disparity (from Procrustes coordinates) and
univariate coefficients of variation, but does not test for group
differences in the dispersion of a multivariate *trait* space.

As in
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
and
[`species_sensitivity()`](https://funtraits.github.io/intraitR/reference/species_sensitivity.md),
the `iter` permutations are independent of one another and are
distributed automatically across `future.apply`'s workers when that
(Suggested) package is installed and a parallel
[`future::plan()`](https://future.futureverse.org/reference/plan.html)
has been set beforehand; otherwise this runs sequentially, with
identical results.

## References

Anderson MJ (2001). A new method for non-parametric multivariate
analysis of variance. Austral Ecology, 26(1), 32-46.
[doi:10.1111/j.1442-9993.2001.01070.pp.x](https://doi.org/10.1111/j.1442-9993.2001.01070.pp.x)

## See also

[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
segments <- fishmorph_segments(fish)
#> Warning: 6 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. Use scale_action = "pixels" to measure them in pixels instead (the 9 unitless ratios are unaffected), or see fishmorph_ratios()'s `landmarks` argument to recover those ratios from an existing cm table.
ratios <- fishmorph_ratios(segments)
traits <- ratios[, c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")]
ts <- trait_space(traits, groups = fish$metadata$species, na_action = "omit")
#> na_action = "omit": removing 6 row(s) out of 494 with missing values.
#> flag_outliers: 10 specimen(s) flagged as within-group outlier(s) across 2 group(s) (Gobio gobio, Lepomis gibbosus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 1 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
# \donttest{
td <- trait_disparity(ts, iter = 199)
td
#> <intrait_disparity> (199 permutations)
#> -- Trait variance (dispersion) by group --
#>     Barbatula barbatula           Barbus barbus             Gobio gobio 
#>                 10.1972                  4.3759                  5.9461 
#>        Lepomis gibbosus Leuciscus burdigalensis       Perca fluviatilis 
#>                  2.1658                  3.9887                  9.8138 
#>       Squalius cephalus 
#>                  7.3011 
#> 
#> -- Pairwise absolute differences (lower triangle) / p-values (upper triangle) --
#>                         Barbatula barbatula Barbus barbus Gobio gobio
#> Barbatula barbatula                      NA        0.0050      0.0150
#> Barbus barbus                        5.8213            NA      0.2400
#> Gobio gobio                          4.2511        1.5702          NA
#> Lepomis gibbosus                     8.0314        2.2101      3.7803
#> Leuciscus burdigalensis              6.2085        0.3872      1.9574
#> Perca fluviatilis                    0.3834        5.4379      3.8677
#> Squalius cephalus                    2.8961        2.9252      1.3550
#>                         Lepomis gibbosus Leuciscus burdigalensis
#> Barbatula barbatula               0.0100                  0.0900
#> Barbus barbus                     0.3750                  0.9500
#> Gobio gobio                       0.0650                  0.5950
#> Lepomis gibbosus                      NA                  0.6400
#> Leuciscus burdigalensis           1.8229                      NA
#> Perca fluviatilis                 7.6480                  5.8251
#> Squalius cephalus                 5.1353                  3.3124
#>                         Perca fluviatilis Squalius cephalus
#> Barbatula barbatula                0.8550             0.090
#> Barbus barbus                      0.0050             0.020
#> Gobio gobio                        0.0200             0.065
#> Lepomis gibbosus                   0.0050             0.030
#> Leuciscus burdigalensis            0.1100             0.365
#> Perca fluviatilis                      NA             0.095
#> Squalius cephalus                  2.5127                NA
# }
```
