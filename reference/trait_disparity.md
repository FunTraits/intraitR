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
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA.
ratios <- fishmorph_ratios(segments)
ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 230 row(s) out of 558 with missing values.
#> flag_outliers: 21 specimen(s) flagged as within-group outlier(s) across 5 group(s) (Barbatula barbatula, Gobio occitaniae, Leuciscus burdigalensis, Phoxinus phoxinus/bigerri, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 2 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
# \donttest{
td <- trait_disparity(ts, iter = 199)
td
#> <intrait_disparity> (199 permutations)
#> -- Trait variance (dispersion) by group --
#>                                 Barbatula barbatula             Barbus barbus 
#>                        NA                   17.4580                    4.6661 
#>          Gobio occitaniae          Lepomis gibbosus   Leuciscus burdigalensis 
#>                    7.5312                    4.5870                    3.9722 
#>         Perca fluviatilis         Phoxinus phoxinus Phoxinus phoxinus/bigerri 
#>                    6.6001                    5.7698                    5.6101 
#>         Squalius cephalus 
#>                   10.2752 
#> 
#> -- Pairwise absolute differences (lower triangle) / p-values (upper triangle) --
#>                              Barbatula barbatula Barbus barbus Gobio occitaniae
#>                           NA              0.0050        0.0050           0.0050
#> Barbatula barbatula       NA                  NA        0.1700           0.1250
#> Barbus barbus             NA             12.7918            NA           0.6100
#> Gobio occitaniae          NA              9.9268        2.8650               NA
#> Lepomis gibbosus          NA             12.8709        0.0791           2.9441
#> Leuciscus burdigalensis   NA             13.4857        0.6939           3.5589
#> Perca fluviatilis         NA             10.8579        1.9340           0.9310
#> Phoxinus phoxinus         NA             11.6881        1.1037           1.7613
#> Phoxinus phoxinus/bigerri NA             11.8479        0.9440           1.9211
#> Squalius cephalus         NA              7.1827        5.6091           2.7441
#>                           Lepomis gibbosus Leuciscus burdigalensis
#>                                     0.0050                  0.0050
#> Barbatula barbatula                 0.1400                  0.1850
#> Barbus barbus                       0.9900                  0.8650
#> Gobio occitaniae                    0.7250                  0.5050
#> Lepomis gibbosus                        NA                  0.9200
#> Leuciscus burdigalensis             0.6148                      NA
#> Perca fluviatilis                   2.0131                  2.6279
#> Phoxinus phoxinus                   1.1828                  1.7976
#> Phoxinus phoxinus/bigerri           1.0230                  1.6378
#> Squalius cephalus                   5.6882                  6.3030
#>                           Perca fluviatilis Phoxinus phoxinus
#>                                      0.0050            0.0050
#> Barbatula barbatula                  0.2000            0.2050
#> Barbus barbus                        0.5600            0.7450
#> Gobio occitaniae                     0.9000            0.7200
#> Lepomis gibbosus                     0.7100            0.8700
#> Leuciscus burdigalensis              0.4300            0.6150
#> Perca fluviatilis                        NA            0.7850
#> Phoxinus phoxinus                    0.8303                NA
#> Phoxinus phoxinus/bigerri            0.9900            0.1597
#> Squalius cephalus                    3.6751            4.5054
#>                           Phoxinus phoxinus/bigerri Squalius cephalus
#>                                              0.0050             0.005
#> Barbatula barbatula                          0.1850             0.260
#> Barbus barbus                                0.8100             0.360
#> Gobio occitaniae                             0.7100             0.555
#> Lepomis gibbosus                             0.8200             0.405
#> Leuciscus burdigalensis                      0.6650             0.320
#> Perca fluviatilis                            0.8100             0.495
#> Phoxinus phoxinus                            0.9450             0.460
#> Phoxinus phoxinus/bigerri                        NA             0.445
#> Squalius cephalus                            4.6652                NA
# }
```
