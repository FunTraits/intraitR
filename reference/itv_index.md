# Partition trait variance into interspecific and intraspecific (ITV) components

Decomposes the total variance of one or more numeric traits into an
interspecific (between-group, e.g. between-species) component and an
intraspecific trait variability (ITV, within-group) component, following
the variance-partitioning approach reviewed by Violle et al. (2012) and
de Bello et al. (2011). Optionally splits the ITV component further into
a between-population (within-species) and a within-population (residual)
part when a finer, nested grouping factor is supplied, following the
within-/among-population distinction used in ITV meta-analyses (e.g.
Siefert et al., 2015).

## Usage

``` r
itv_index(traits, groups, nested = NULL, scale = TRUE, digits = 4)

# S3 method for class 'intrait_itv'
print(x, ...)
```

## Arguments

- traits:

  A `data.frame` or matrix of numeric traits, one row per **individual**
  observation. Unlike
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
  `traits` must not already be averaged to group (e.g. species) means:
  ITV is, by definition, the variability *within* groups, and cannot be
  estimated once individuals have been collapsed to a single value per
  group. Non-numeric columns are dropped with a warning.

- groups:

  Factor or character vector, one value per row of `traits`: the
  coarser, interspecific grouping variable (typically species). Must
  have at least two levels.

- nested:

  Optional factor or character vector, one value per row of `traits`: a
  finer grouping variable nested *within* `groups` (typically population
  or site), used to split the ITV component into a between-population
  and a within-population (residual) part. Levels of `nested` do not
  need to be globally unique: labels such as `"Pop_1"`/`"Pop_2"` may be
  (and commonly are) reused identically across different levels of
  `groups` — each *combination* of `groups` and `nested` is treated as a
  distinct population, exactly as the nesting operator in
  `aov(y ~ Error(species/population))` would.

- scale:

  Logical, standardise (z-score) each numeric trait before combining
  sums of squares across traits in the multivariate summary (see
  Details). Does not affect the per-trait percentages, which are
  invariant to linear rescaling of each trait on its own. Defaults to
  `TRUE`.

- digits:

  Integer, number of decimal places to round percentages and sums of
  squares to in the returned tables. Defaults to `4`.

- x:

  An object of class `"intrait_itv"`, as returned by `itv_index()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_itv"`, a list with elements:

- per_trait:

  a `data.frame`, one row per numeric trait, with columns `trait`,
  `ss_total`, `ss_between` (interspecific), `ss_within`
  (intraspecific/ITV) — plus `ss_population` and `ss_residual` if
  `nested` is supplied — and the corresponding percentages
  `pct_interspecific`, `pct_itv` (and `pct_itv_between_pop`,
  `pct_itv_within_pop` if `nested` is supplied).

- multivariate:

  a one-row `data.frame` with the same columns, summed across all
  (optionally standardised) traits, summarising the overall balance of
  interspecific vs. intraspecific variability across the whole trait
  set.

- groups, nested, scale, traits_used:

  the grouping factors, the `scale` setting, and the numeric trait
  columns used.

Has a dedicated print method and a
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method (stacked
bar chart of percent interspecific vs. intraspecific variance per
trait).

Invisibly returns `x`.

## Details

For a single grouping level, this is the classical one-way ANOVA
sum-of-squares identity \\SS\_{total} = SS\_{between} + SS\_{within}\\,
with \\\\ITV = 100 \times SS\_{within} / SS\_{total}\\: the percentage
of total trait variance that lies *within* groups rather than *between*
them (Violle et al., 2012). When `nested` is supplied, the within-group
sum of squares is itself decomposed exactly (for any, including
unbalanced, design) into a between-population-within-species term and a
within-population residual term, following the same orthogonal
sum-of-squares identity one level down; this holds exactly regardless of
group-size imbalance.

Per-trait percentages are invariant to how each trait is individually
rescaled (multiplying a trait by a constant scales `ss_total` and
`ss_within` by the same factor, leaving their ratio unchanged), so
`scale` has no effect on `per_trait`. It matters only for
`multivariate`, where sums of squares from traits with different units
and raw variances are added together: without standardising first, a
trait with a larger raw variance would dominate the aggregate regardless
of its actual relative ITV, which is rarely the intended comparison.

A within-group sum of squares of (near) zero for every trait indicates
that `groups` has essentially no replication (e.g. exactly one
observation per species); in that case ITV cannot be estimated, and a
warning is issued.

## References

Violle, C., Enquist, B. J., McGill, B. J., Jiang, L., Albert, C. H.,
Hulshof, C., Jung, V., & Messier, J. (2012). The return of the variance:
intraspecific variability in community ecology. Trends in Ecology &
Evolution, 27(4), 244-252.

de Bello, F., Lavorel, S., Albert, C. H., Thuiller, W., Grigulis, K.,
Dolezal, J., Janecek, S., & Leps, J. (2011). Quantifying the relative
importance of intraspecific trait variability and interspecific trait
turnover for functional diversity. Methods in Ecology and Evolution,
2(2), 163-174.

Siefert, A., Violle, C., Chalmandrier, L., et al. (2015). A global
meta-analysis of the relative extent of intraspecific trait variation in
plant communities. Ecology Letters, 18(12), 1406-1419.

## See also

[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md),
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)

## Examples

``` r
# real T-26 Saudrune data; itv_index() requires complete cases, unlike
# trait_space()'s na_action, so incomplete rows are filtered explicitly
fish <- load_t26_saudrune_landmarks()
segments <- fishmorph_segments(fish)
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
ratios <- fishmorph_ratios(segments)
complete <- stats::complete.cases(ratios[, c("BEl", "VEp", "REs")])
itv <- itv_index(
  ratios[complete, c("BEl", "VEp", "REs")],
  groups = fish$metadata$species[complete]
)
itv
#> <intrait_itv> (species-level) 
#>   3 trait(s), 10 groups
#> 
#> -- Per trait --
#>  trait  ss_total ss_between ss_within pct_interspecific pct_itv
#>    BEl 3396.4163    39.7962 3356.6201            1.1717 98.8283
#>    VEp    2.7724     1.0303    1.7421           37.1638 62.8362
#>    REs    2.7233     1.1540    1.5692           42.3766 57.6234
#> 
#> -- Multivariate summary (standardised traits) --
#>  ss_total ss_between ss_within pct_interspecific pct_itv
#>      1041   280.0711  760.9289            26.904  73.096

# split ITV into between-/within-population components: the real T-26
# survey sampled a single site (no population structure to report), so
# the nested = argument is illustrated here on simulated data instead
fish_sim <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
segments_sim <- fishmorph_segments(fish_sim)
ratios_sim <- fishmorph_ratios(segments_sim)
itv_nested <- itv_index(
  ratios_sim[, c("BEl", "VEp", "REs")],
  groups = fish_sim$metadata$species,
  nested = fish_sim$metadata$population
)
itv_nested
#> <intrait_itv> (nested: species / population) 
#>   3 trait(s), 3 groups, 6 nested levels
#> 
#> -- Per trait --
#>  trait ss_total ss_between ss_population ss_residual ss_within
#>    BEl  36.2459    35.7716        0.0368      0.4375    0.4744
#>    VEp   0.0529     0.0038        0.0020      0.0470    0.0491
#>    REs   0.1461     0.0059        0.0147      0.1255    0.1401
#>  pct_interspecific pct_itv pct_itv_between_pop pct_itv_within_pop
#>            98.6912  1.3088              0.1016             1.2071
#>             7.1246 92.8754              3.8706            89.0047
#>             4.0605 95.9395             10.0496            85.8899
#> 
#> -- Multivariate summary (standardised traits) --
#>  ss_total ss_between ss_population ss_residual ss_within pct_interspecific
#>       132    48.3456        6.1696     77.4848   83.6544           36.6255
#>  pct_itv pct_itv_between_pop pct_itv_within_pop
#>  63.3745               4.674            58.7006
```
