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
#> Warning: 23 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
ratios <- fishmorph_ratios(segments)
ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: individual, population, operator
#> na_action = "omit": removing 293 row(s) out of 1036 with missing values.
#> flag_outliers: 31 specimen(s) flagged as within-group outlier(s) across 4 group(s) (Barbatula barbatula, Gobio occitaniae, Phoxinus phoxinus, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
# \donttest{
td <- trait_disparity(ts, iter = 199)
td
#> <intrait_disparity> (199 permutations)
#> -- Trait variance (dispersion) by group --
#>     Barbatula barbatula        Gobio occitaniae        Lepomis gibbosus 
#>                 12.5272                  9.8045                  3.2810 
#> Leuciscus burdigalensis       Perca fluviatilis       Phoxinus phoxinus 
#>                  3.1341                  6.1294                  7.1644 
#>       Squalius cephalus 
#>                  7.9265 
#> 
#> -- Pairwise absolute differences (lower triangle) / p-values (upper triangle) --
#>                         Barbatula barbatula Gobio occitaniae Lepomis gibbosus
#> Barbatula barbatula                      NA           0.6750           0.1450
#> Gobio occitaniae                     2.7227               NA           0.2900
#> Lepomis gibbosus                     9.2462           6.5235               NA
#> Leuciscus burdigalensis              9.3932           6.6705           0.1469
#> Perca fluviatilis                    6.3978           3.6751           2.8484
#> Phoxinus phoxinus                    5.3629           2.6402           3.8833
#> Squalius cephalus                    4.6007           1.8780           4.6455
#>                         Leuciscus burdigalensis Perca fluviatilis
#> Barbatula barbatula                      0.2000            0.2300
#> Gobio occitaniae                         0.2750            0.5450
#> Lepomis gibbosus                         0.9700            0.4450
#> Leuciscus burdigalensis                      NA            0.4800
#> Perca fluviatilis                        2.9953                NA
#> Phoxinus phoxinus                        4.0303            1.0349
#> Squalius cephalus                        4.7924            1.7971
#>                         Phoxinus phoxinus Squalius cephalus
#> Barbatula barbatula                0.3600             0.385
#> Gobio occitaniae                   0.6500             0.790
#> Lepomis gibbosus                   0.4100             0.375
#> Leuciscus burdigalensis            0.4850             0.365
#> Perca fluviatilis                  0.7650             0.695
#> Phoxinus phoxinus                      NA             0.845
#> Squalius cephalus                  0.7621                NA
# }
```
