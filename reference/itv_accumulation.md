# Rarefaction of intraspecific trait variability against sample size

Builds, for each group (typically a species), a rarefaction/accumulation
curve of an intraspecific variability metric as a function of the number
of individuals sampled, and estimates the sample size `n*` at which that
variability *stabilises* – the trait-based analogue of a species
accumulation (rarefaction) curve. For each sub-sample size `n` = 2, 3,
..., N_g, `n_perm` sub-samples of `n` individuals are drawn at random
**without replacement** from the group's N_g individuals, the metric is
computed on each, and the draws are summarised by their mean and a
resampling quantile band.

## Usage

``` r
itv_accumulation(
  x,
  groups = NULL,
  metric = c("variance", "sd", "cv", "range"),
  n_perm = 99,
  sizes = NULL,
  conv_tol = 0.05,
  asymptote_prop = 0.95,
  model = c("michaelis", "exponential"),
  probs = c(0.025, 0.975),
  min_n = 5,
  log_transform = FALSE,
  scale = NULL,
  seed = NULL
)

# S3 method for class 'intrait_itv_accumulation'
print(x, ...)
```

## Arguments

- x:

  An object of class `"intrait_itv_accumulation"`.

- groups:

  Factor or character vector, one value per row of `x`: the grouping
  variable (typically species). Required when `x` is a raw trait table;
  taken from `x$groups` when `x` is an `"intrait_traitspace"`. Rows with
  a missing group are dropped with a message.

- metric:

  Character, the variability metric to rarefy. One of `"variance"`
  (default; multivariate trait variance / trace of the covariance –
  dispersion), `"sd"` (per-trait standard deviation – dispersion),
  `"cv"` (per-trait coefficient of variation in percent – dispersion) or
  `"range"` (per-trait observed range – accumulation).

- n_perm:

  Integer, number of random sub-samples drawn at each sub-sample size.
  Defaults to `99`.

- sizes:

  Optional integer vector of sub-sample sizes to evaluate. If `NULL`
  (default), every size from `2` to each group's own N_g is used; if
  supplied, it is intersected per group with `2:N_g`.

- conv_tol:

  Numeric in (0, 1), the precision tolerance defining convergence for
  dispersion metrics: `n*` is the smallest `n` beyond which the
  resampling band's half-width `(upper - lower) / 2`, relative to
  `|V(N_g)|`, stays at or below `conv_tol` for all larger sizes. With
  the default `probs = c(0.025, 0.975)` band this is a 95% resampling
  interval, so `conv_tol = 0.05` means "estimate pinned down to within
  +/-5% of the full-sample value". Defaults to `0.05`.

- asymptote_prop:

  Numeric in (0, 1), the fraction of the fitted asymptote Vmax defining
  `n*` for accumulation metrics. Defaults to `0.95`.

- model:

  Character, the saturating model fitted for accumulation metrics:
  `"michaelis"` (default, Michaelis-Menten) or `"exponential"` (negative
  exponential). Ignored for dispersion metrics.

- probs:

  Numeric length-2 vector of lower/upper probabilities for the
  resampling quantile band. Defaults to `c(0.025, 0.975)`.

- min_n:

  Integer, the minimum group size N_g required for a group to be
  rarefied; smaller groups are skipped with a message. Defaults to `5`.

- log_transform:

  Logical, apply a `log10(x + 1)` transformation to a raw trait table
  before computing the metric (as in
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)).
  Ignored when `x` is an `"intrait_traitspace"`. Defaults to `FALSE`.

- scale:

  Logical or `NULL`. Standardise each trait (z-score) before computing
  the metric, so traits with different units contribute comparably to
  the multivariate `"variance"`. `NULL` (default) resolves to `TRUE` for
  `metric = "variance"` and `FALSE` otherwise; it is always forced to
  `FALSE` for `metric = "cv"` (centring would make a CV meaningless).
  Ignored when `x` is an `"intrait_traitspace"` (already pre-processed).

- seed:

  Optional integer passed to
  [`set.seed()`](https://rdrr.io/r/base/Random.html) for reproducibility
  under a sequential plan (see Details). Defaults to `NULL`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_itv_accumulation"`, a list with elements:

- curve:

  a tidy `data.frame` with columns `group`, `trait` (the trait name, or
  `"multivariate"` for `metric = "variance"`), `n`, `mean`, `lower`,
  `upper` (the resampling mean and quantile band at each sub-sample
  size).

- summary:

  a `data.frame`, one row per (`group`, `trait`) series, with columns
  `group`, `trait`, `metric`, `framing` (`"convergence"` or
  `"accumulation"`), `n_max` (N_g), `v_full` (the full-sample metric
  value), `asymptote` and `prop_reached` and `k` (accumulation only;
  `NA` for convergence – `k` is the fitted half-saturation `K` for
  `model = "michaelis"` or the rate `b` for `model = "exponential"`,
  used to redraw and extrapolate the fitted curve), and `n_star` (the
  estimated stabilisation sample size).

- metric, framing, model, conv_tol, asymptote_prop, n_perm, probs:

  the settings used.

Has dedicated [`print()`](https://rdrr.io/r/base/print.html) and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

Invisibly returns `x`.

## Details

The behaviour of the curve, and therefore the meaning of "stabilises",
depends fundamentally on the *kind* of metric (see also Violle et al.,
2012; Gotelli & Colwell, 2001):

- **Dispersion metrics** (`"variance"`, `"sd"`, `"cv"`):

  The sample variance is an *unbiased* estimator of the population
  variance: `E[s^2(n)] = sigma^2` for every `n >= 2`. The expected curve
  is therefore essentially **flat**; what changes with `n` is not its
  level but its *precision* – the resampling band narrows as `n` grows.
  "Stabilisation" here is therefore convergence of the estimate in
  *precision*, not in level: `n*` is defined as the smallest `n` beyond
  which the resampling band's half-width, relative to the full-sample
  value `V(N_g)`, stays at or below `conv_tol` for all larger sub-sample
  sizes (framing `"convergence"`). Basing this on the band rather than
  the mean is deliberate: because `E[s^2(n)]` is flat, a criterion on
  the mean would return `n* = 2` trivially, whereas the band width is
  what actually decreases with sampling effort. This answers: *how many
  individuals are needed for a reliable (well-pinned-down) estimate of
  intraspecific variability?*

- **Accumulation metrics** (`"range"`):

  The observed range (and, more generally, the amount of trait space
  occupied) genuinely *increases* with `n` and saturates, exactly like
  species richness in a rarefaction curve. Here a saturating model is
  fitted to the curve (Michaelis-Menten `V(n) = Vmax * n / (K + n)` or
  negative exponential `V(n) = Vmax * (1 - exp(-b*n))`) and `n*` is the
  sample size reaching a fraction `asymptote_prop` of the estimated
  asymptote `Vmax` (framing `"accumulation"`). For Michaelis-Menten this
  is available in closed form, `n* = K * p / (1 - p)`; for the
  exponential model, `n* = -log(1 - p) / b`. When the metric has not
  saturated within the observed range (e.g. the range of an unbounded,
  approximately Gaussian trait, which grows without a true asymptote),
  `n*` may exceed `n_max` – this is a legitimate *extrapolation*
  signalling that more individuals than were sampled would be needed to
  reach `asymptote_prop` of the fitted asymptote, and should be read
  alongside `prop_reached` (the fraction of the asymptote actually
  attained at N_g).

`"variance"` is multivariate: it uses the trace of the group trait
covariance matrix (the sum of the per-trait variances), the same
dispersion measure returned by
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md),
so a single curve is produced per group. `"sd"`, `"cv"` and `"range"`
are univariate and produce one curve per group *and* trait.

The `n_perm` random draws at each sub-sample size are independent of one
another and are distributed automatically across `future.apply`'s
workers when that (Suggested) package is installed and a parallel
[`future::plan()`](https://future.futureverse.org/reference/plan.html)
has been set beforehand; otherwise this runs sequentially, with
identical results (see
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md),
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)).
Exact reproducibility across runs therefore requires either a sequential
plan together with `seed`, or reliance on `future.apply`'s own
parallel-safe streams.

## References

Gotelli, N. J., & Colwell, R. K. (2001). Quantifying biodiversity:
procedures and pitfalls in the measurement and comparison of species
richness. Ecology Letters, 4(4), 379-391.

Violle, C., Enquist, B. J., McGill, B. J., Jiang, L., Albert, C. H.,
Hulshof, C., Jung, V., & Messier, J. (2012). The return of the variance:
intraspecific variability in community ecology. Trends in Ecology &
Evolution, 27(4), 244-252.

## See also

[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
[`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md),
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md),
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)

## Examples

``` r
# The T-26 campaign: real specimens, and therefore genuinely unequal
# sample sizes -- which is the question this function is asked.
fish <- load_t26_saudrune_landmarks()
ratios <- fishmorph_ratios(fishmorph_segments(fish, scale_action = "pixels"))
#> scale_action = "pixels": 6 specimen(s) have a zero-length or missing scale bar (points 20-21); their measurements are returned in PIXELS (scale_units == "px"), the other 488 in centimetres. The nine ratios are unaffected; absolute values are not comparable across the two units.

# multivariate trait variance: how many individuals until the
# intraspecific-variability estimate converges (resampling band within
# +/-5% of the full-sample value)?
acc <- itv_accumulation(
  ratios[, c("BEl", "VEp", "REs")],
  groups = fish$metadata$species, n_perm = 30, seed = 1
)
#> Skipped 1 group(s) with fewer than 5 individuals (or too few distinct sub-sample sizes): Leuciscus burdigalensis.
acc
#> <intrait_itv_accumulation>
#>   metric = variance (convergence), 30 permutation(s) per sub-sample size
#>   n* = smallest n staying within 5% of the full-sample value
#> 
#> -- Stabilisation sample size per group/trait --
#>                group        trait   metric     framing n_max v_full n_star
#>  Barbatula barbatula multivariate variance convergence    17 4.0593     17
#>        Barbus barbus multivariate variance convergence    30 1.0111     30
#>          Gobio gobio multivariate variance convergence   288 1.4171    263
#>     Lepomis gibbosus multivariate variance convergence     9 0.3058      9
#>    Perca fluviatilis multivariate variance convergence    20 1.5765     20
#>    Squalius cephalus multivariate variance convergence   126 1.8399    116
plot(acc)


# per-trait range: a genuinely saturating accumulation curve, with n*
# taken at 95% of a fitted Michaelis-Menten asymptote
acc_range <- itv_accumulation(
  ratios[, c("BEl", "VEp")], groups = fish$metadata$species,
  metric = "range", n_perm = 30, seed = 1
)
#> Skipped 1 group(s) with fewer than 5 individuals (or too few distinct sub-sample sizes): Leuciscus burdigalensis.
acc_range
#> <intrait_itv_accumulation>
#>   metric = range (accumulation), 30 permutation(s) per sub-sample size
#>   n* = n reaching 95% of the fitted michaelis asymptote
#> 
#> -- Stabilisation sample size per group/trait --
#>                group trait metric      framing n_max v_full asymptote
#>  Barbatula barbatula   BEl  range accumulation    17 1.9703    2.5022
#>  Barbatula barbatula   VEp  range accumulation    17 0.4249    0.5994
#>        Barbus barbus   BEl  range accumulation    30 1.1242    1.3431
#>        Barbus barbus   VEp  range accumulation    30 0.1564    0.1779
#>          Gobio gobio   BEl  range accumulation   288 1.6591    1.6658
#>          Gobio gobio   VEp  range accumulation   288 0.3932    0.4036
#>     Lepomis gibbosus   BEl  range accumulation     9 0.4461    0.8484
#>     Lepomis gibbosus   VEp  range accumulation     9 0.1240    0.4190
#>    Perca fluviatilis   BEl  range accumulation    20 1.9059    2.3360
#>    Perca fluviatilis   VEp  range accumulation    20 0.1694    0.1989
#>    Squalius cephalus   BEl  range accumulation   126 1.9931    2.1224
#>    Squalius cephalus   VEp  range accumulation   126 0.4367    0.4551
#>  prop_reached n_star       k
#>        0.7874     87  4.5470
#>        0.7089    151  7.9472
#>        0.8370    110  5.7651
#>        0.8793     83  4.3306
#>        0.9960    171  8.9975
#>        0.9742    225 11.7935
#>        0.5258    151  7.9190
#>        0.2960    408 21.4222
#>        0.8159    103  5.3841
#>        0.8518     62  3.2378
#>        0.9391    198 10.4176
#>        0.9596    122  6.4011
```
