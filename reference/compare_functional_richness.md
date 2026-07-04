# Compare bootstrap-based functional richness estimates across methods

Runs
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
once per requested `method` (`"convexhull"`, `"dendrogram"`, `"tpd"`,
`"hypervolume"`) on the same data, and tabulates the results side by
side. Convex-hull volume, dendrogram branch length, TPD richness, and
hypervolume are not on the same scale, so raw `fd_ref`/`fd_boot_mean`
values are not directly comparable across rows; what *is* comparable is
whether each method agrees, qualitatively, that individual-based
richness exceeds the centroid-based reference, and by roughly how much
in relative (percentage) terms – exactly the triangulation this function
is for.

## Usage

``` r
compare_functional_richness(
  x,
  groups = NULL,
  methods = c("convexhull", "dendrogram", "tpd", "hypervolume"),
  n_axes = NULL,
  var_threshold = 0.98,
  n_boot = 100,
  log_transform = TRUE,
  scale = TRUE,
  alpha = 0.05,
  seed = NULL,
  ...
)
```

## Arguments

- x, groups, n_axes, var_threshold, n_boot, log_transform, scale:

  As in
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md).

- methods:

  Character vector, one or more of `"convexhull"`, `"dendrogram"`,
  `"tpd"`, `"hypervolume"` (see
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
  for what each measures). Defaults to all four. A method whose
  Suggested package is not installed, or that errors for any other
  reason (e.g. `n_axes` too large for `"convexhull"`'s
  affine-independence requirement), is not fatal: it is recorded as
  `status != "ok"` in `$summary` with `NA` numeric columns, and the
  comparison proceeds with the remaining methods.

- alpha:

  Numeric, the significance threshold used to flag
  `$summary$significant` and summarised in
  [`print()`](https://rdrr.io/r/base/print.html). Defaults to `0.05`.
  Purely a display/summary convenience: the underlying `p_value` for
  each method is always reported in full.

- seed:

  Optional single integer. If supplied, `set.seed(seed)` is called
  immediately before *each* method's
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
  call, so every method draws the same sequence of one-individual-per-
  species bootstrap "communities" (community 1 is the same draw under
  every method, community 2 the same under every method, and so on) –
  useful if you want the per-draw richness values to be directly paired
  across methods (e.g. to correlate them), rather than merely comparing
  summary statistics. Defaults to `NULL` (no explicit seeding; each
  method's draws continue the ambient RNG stream, as a single ordinary
  call to
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
  would).

- ...:

  Further method-specific tuning arguments forwarded as-is to every
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
  call: `dendrogram_linkage`, `tpd_alpha`, `tpd_bw_factor`,
  `tpd_n_divisions`, `hv_bw_method`, `hv_samples_per_point`. Irrelevant
  arguments are simply ignored by whichever method does not use them.

## Value

An object of class `"intrait_richness_comparison"`, a list with
elements: `summary` (a `data.frame`, one row per requested method, in
the order of `methods`, with columns `method`, `status` (`"ok"` or a
`"skipped: <error message>"` note), `n_axes`, `var_explained`, `fd_ref`,
`fd_boot_mean`, `fd_boot_sd`, `diff`, `pct_diff` (`100 * diff / fd_ref`,
the cross-method-comparable quantity), `p_value`, and `significant`
(`p_value < alpha`); `NA` in every numeric column for a skipped method),
`results` (a named list of the full `"intrait_bootstrap_fspace"` object
for every method that succeeded, e.g. for
[`plot()`](https://rdrr.io/r/graphics/plot.default.html)-ing an
individual method's bootstrap histogram), `n_boot`, and `alpha`. Has
dedicated [`print()`](https://rdrr.io/r/base/print.html) and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

## Details

Each method gets its own, independent call to
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
– including its own fresh PCA and its own `n_boot` bootstrap draws –
rather than sharing internal computation across methods; this keeps the
comparison exactly as trustworthy as calling
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
directly four times, at the cost of repeating the (comparatively cheap)
PCA step. Use `seed` if you specifically want the same draws reused
across methods rather than four independent bootstrap samples.

`pct_diff` is the one quantity meaningfully compared across rows:
consistent, similarly sized, statistically significant `pct_diff` across
most or all methods is stronger evidence that intraspecific trait
variability genuinely inflates the estimated functional space than a
single method's result taken alone, since the four measures make
different assumptions (hard-edged hull vs. kernel-smoothed density vs.
distance-based dendrogram) and so are unlikely to agree spuriously for
the same reason.

## References

Bertrand P (2026). Intraspecific trait variability shapes the functional
space of freshwater fish in French Guiana assemblages. M2 Biodiversity
Ecology Evolution (BEE) internship report, Lille University / Centre de
Recherche sur la Biodiversite et l'Environnement (CRBE, AQUAECO team),
unpublished, supervised by A. Toussaint and S. Brosse.

## See also

[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md),
[`species_sensitivity()`](https://funtraits.github.io/intraitR/reference/species_sensitivity.md)

## Examples

``` r
# \donttest{
fish <- load_t26_saudrune_landmarks()
segments <- fishmorph_segments(fish)
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA.
ratios <- fishmorph_ratios(segments)
ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 230 row(s) out of 558 with missing values.
#> flag_outliers: 21 specimen(s) flagged as within-group outlier(s) across 5 group(s) (Barbatula barbatula, Gobio occitaniae, Leuciscus burdigalensis, Phoxinus phoxinus/bigerri, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 2 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).

# "dendrogram" always runs; "convexhull"/"tpd"/"hypervolume" are
# skipped gracefully (not fatal) if their package is not installed
cmp <- compare_functional_richness(ts, n_axes = 2, n_boot = 100)
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> -------Calculating densities for One population_Multiple species-----------
#> Calculating FRichness of communities
#> Calculating FEvenness of communities
#> Calculating FDivergence of communities
#> Note that the formula used for the Silverman estimator differs in version 3 compared to prior versions of this package.
#> Use method='silverman-1d' to replicate prior behavior.
cmp
#> <intrait_richness_comparison>
#>   4 method(s) requested, 4 succeeded
#>       method status fd_ref fd_boot_mean pct_diff p_value significant
#>   convexhull     ok  6.104         10.3   +68.7% 0.07921       FALSE
#>   dendrogram     ok  13.55        18.75   +38.3%  0.1089       FALSE
#>          tpd     ok  36.67        43.68   +19.1% 0.07921       FALSE
#>  hypervolume     ok  19.48        23.77   +22.0%  0.1089       FALSE
#> 
#>   0/4 method(s) agree that individual-based richness significantly
#>   exceeds the centroid-based reference (p < 0.05).
plot(cmp)

# }
```
