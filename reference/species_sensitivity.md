# Species-level sensitivity index for functional space estimates

For each species, quantifies how much replacing that species' centroid
with one of its real individuals changes the estimated functional
richness in PCA space, while every other species stays fixed at its own
centroid, following the species-level sensitivity index of Bertrand
(2026, Section "Species-level sensitivity index"). This complements
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)'s
community-wide comparison by asking a finer-grained question: *which*
species drive the difference between individual-based and centroid-based
functional richness, and are their individual effects consistent or
highly variable?

## Usage

``` r
species_sensitivity(
  x,
  groups = NULL,
  method = c("convexhull", "dendrogram", "tpd", "hypervolume"),
  n_axes = NULL,
  var_threshold = 0.98,
  log_transform = TRUE,
  scale = TRUE,
  dendrogram_linkage = "average",
  tpd_alpha = 0.95,
  tpd_bw_factor = 0.5,
  tpd_n_divisions = NULL,
  hv_bw_method = "silverman",
  hv_samples_per_point = 500
)
```

## Arguments

- x:

  Either an object of class `"intrait_traitspace"` (from
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
  built with `groups` supplied), or a `data.frame`/matrix of numeric
  traits (one row per individual), in which case `groups` must also be
  supplied and the same `log_transform`/`scale` preprocessing as
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  is applied before the PCA described below.

- groups:

  Required when `x` is a raw trait table (one value per individual,
  typically species identity); ignored (taken from `x$groups`) when `x`
  is an `"intrait_traitspace"` object.

- method, n_axes, var_threshold, log_transform, scale,
  dendrogram_linkage, tpd_alpha, tpd_bw_factor, tpd_n_divisions,
  hv_bw_method, hv_samples_per_point:

  As in
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md):
  `method` selects the functional-richness measure recomputed for the
  reference configuration and every single-individual replacement
  (`"convexhull"`, the default, an n-dimensional convex-hull volume;
  `"dendrogram"`, total branch length of a UPGMA functional dendrogram;
  `"tpd"`, Trait Probability Density functional richness;
  `"hypervolume"`, a Gaussian-kernel hypervolume), and `n_axes` PCA axes
  are used (auto-selected via `var_threshold` if `NULL`), computed from
  a fresh PCA on `x$X` (or on freshly standardised `x`). As there, only
  `method = "convexhull"` strictly requires `nlevels(groups) > n_axes`;
  the other methods only warn instead. For `"tpd"`/`"hypervolume"`, the
  kernel bandwidth (and, for `"tpd"`, the evaluation grid) is likewise
  computed once from the full individual-level PCA scores and reused,
  unchanged, for `fd_ref` and every one of the `nrow(x)`
  single-individual replacements, for the same comparability reason
  explained there.

## Value

An object of class `"intrait_species_sensitivity"`, a list with
elements: `summary` (a `data.frame`, one row per species, with columns
`species`, `n_individuals`, `mean_dFD`, `min_dFD`, `max_dFD` – the
species-level index, i.e. Bertrand (2026)'s `mu_k` and range, in the
original `levels(groups)` order), `individual` (a long-format
`data.frame` with one row per individual, columns `species` and `dFD`,
for full transparency beyond the per-species summary), `fd_ref` (the
community-wide centroid-based reference richness), `method`, `n_axes`,
and `var_explained`. Has dedicated
[`print()`](https://rdrr.io/r/base/print.html) and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

## Details

For a focal species k with individuals `i = 1, ..., n_k`, its centroid
in the `n_axes`-dimensional PCA space is replaced, one individual at a
time, by that individual's own PCA scores, while every other species
remains at its centroid; the functional richness of this modified
`n_species`-point configuration is `FD_{k,i}`. Each replacement is
expressed as a percentage change relative to the (unmodified)
centroid-based reference richness `fd_ref`: \$\$\Delta FD\_{k,i} (\\) =
100 \times (FD\_{k,i} - FD\_{ref}) / FD\_{ref}\$\$ A positive `dFD`
means that individual, if it alone stood in for its species' centroid,
would expand the estimated functional space; a negative `dFD` means it
would contract it. `mean_dFD` (`mu_k`) summarises the average tendency
of a species' individuals, and `min_dFD`/`max_dFD` describe the
heterogeneity of individual effects within that species – a wide range
indicates a few unusual individuals rather than a consistent
species-level tendency (see Bertrand, 2026, for worked examples of both
patterns in real data).

Unlike
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md),
this index requires no resampling or significance test: every
replacement is deterministic (one individual, one recomputed richness
value), so `species_sensitivity()` is exact given
`x`/`groups`/`n_axes`/`method`, not simulation-based. Species with only
one individual still receive a (single-valued) `mean_dFD`, with
`min_dFD == max_dFD` and no useful "range" to speak of, which is
expected, not an error.

Every individual, across every species, requires its own
functional-richness recomputation (one call per individual in
`x`/`groups`, not per species), so this is the most computationally
demanding of the two functional-space functions on a large data set –
Bertrand (2026)'s regional panel, for instance, had 1,302 individuals –
and especially so for `method = "hypervolume"` (by far the most
expensive of the four measures per call, see
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)).
Each individual's replacement is independent of every other's, so,
exactly as in
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md),
this is distributed automatically across `future.apply`'s workers when
that package is installed and a parallel
[`future::plan()`](https://future.futureverse.org/reference/plan.html)
has been set beforehand; with no plan set, or without `future.apply`, it
runs sequentially with identical results.

## References

Bertrand P (2026). Intraspecific trait variability shapes the functional
space of freshwater fish in French Guiana assemblages. M2 Biodiversity
Ecology Evolution (BEE) internship report, Lille University / Centre de
Recherche sur la Biodiversite et l'Environnement (CRBE, AQUAECO team),
unpublished, supervised by A. Toussaint and S. Brosse.

Villeger S, Mason NWH, Mouillot D (2008). New multidimensional
functional diversity indices for a multifaceted framework in functional
ecology. Ecology, 89(8), 2290-2301.

Petchey OL, Gaston KJ (2002). Functional diversity (FD), species
richness and community composition. Ecology Letters, 5(3), 402-411.

Carmona CP, de Bello F, Mason NWH, Leps J (2019). Trait probability
density (TPD): measuring functional diversity across scales based on TPD
with R. Ecology, 100(12), e02876.

Blonder B, Lamanna C, Violle C, Enquist BJ (2014). The n-dimensional
hypervolume. Global Ecology and Biogeography, 23(5), 595-609.

Blonder B, Morrow CB, Maitner B, Harris DJ, Lamanna C, Violle C, Enquist
BJ, Kerkhoff AJ (2018). New approaches for delineating n-dimensional
hypervolumes. Methods in Ecology and Evolution, 9(2), 305-319.

## See also

[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)

## Examples

``` r
# \donttest{
fish <- load_t26_saudrune_landmarks()
segments <- fishmorph_segments(fish)
#> Warning: 23 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
ratios <- fishmorph_ratios(segments)
ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: individual, population, operator
#> na_action = "omit": removing 293 row(s) out of 1036 with missing values.
#> flag_outliers: 31 specimen(s) flagged as within-group outlier(s) across 4 group(s) (Barbatula barbatula, Gobio occitaniae, Phoxinus phoxinus, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.

# method = "dendrogram" needs no extra Suggested package
ss_dendro <- species_sensitivity(ts, method = "dendrogram", n_axes = 2)
ss_dendro
#> <intrait_species_sensitivity> (method = "dendrogram")
#>   2 PCA axes retained (53.4% of variance), 7 species, FD_ref = 7.234
#>   Top 7 species by |mean %change in functional richness|:
#>                  species   n mean_dFD            range_dFD
#>      Barbatula barbatula  38  +17.43%   [-7.57%, +259.19%]
#>        Phoxinus phoxinus  71  +15.19%   [-9.31%, +182.46%]
#>         Gobio occitaniae 396  +14.39% [-12.15%, +1105.02%]
#>        Squalius cephalus 174  +14.27%   [-1.01%, +410.53%]
#>  Leuciscus burdigalensis  25   +9.19%    [+0.83%, +26.61%]
#>        Perca fluviatilis  34   +6.30%   [-11.07%, +46.14%]
#>         Lepomis gibbosus   5   +5.51%    [-9.58%, +22.73%]
plot(ss_dendro)


if (requireNamespace("geometry", quietly = TRUE)) {
  ss <- species_sensitivity(ts, n_axes = 2)
  ss
}
#> <intrait_species_sensitivity> (method = "convexhull")
#>   2 PCA axes retained (53.4% of variance), 7 species, FD_ref = 2.488
#>   Top 7 species by |mean %change in functional richness|:
#>                  species   n mean_dFD            range_dFD
#>      Barbatula barbatula  38  +19.70%  [-21.07%, +334.06%]
#>        Squalius cephalus 174  +14.87%   [+0.00%, +621.74%]
#>         Gobio occitaniae 396  +13.95% [-19.68%, +1383.96%]
#>        Phoxinus phoxinus  71  +11.97%  [-19.56%, +182.93%]
#>  Leuciscus burdigalensis  25   +7.91%    [+0.00%, +28.27%]
#>         Lepomis gibbosus   5   +6.33%   [-26.84%, +40.23%]
#>        Perca fluviatilis  34   +6.03%   [-22.10%, +57.88%]
# }
```
