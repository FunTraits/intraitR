# Bootstrap-based estimate of functional space volume from individual data

Compares the functional richness obtained when species are represented
by real individuals to the functional richness obtained when species are
collapsed to their centroid (mean trait position), in a PCA-based trait
space, following the bootstrap procedure of Bertrand (2026, Section
"Bootstrap-based functional space estimates"). For each of `n_boot`
bootstrap "communities", one individual is drawn at random per species
and the functional richness of these individual-level points is computed
(`fd_boot`); this distribution is compared to a single centroid-based
reference richness (`fd_ref`), obtained by replacing each species with
the mean position of its individuals before recomputing the same
richness measure. Because a single randomly chosen individual
necessarily sits somewhere within (or at the edge of) its species' own
dispersion, `fd_boot` is expected to equal or exceed `fd_ref` whenever
species show non-trivial intraspecific trait variability (ITV); this
function also tests whether `fd_ref` sits unusually low relative to the
bootstrap distribution (see Details).

## Usage

``` r
bootstrap_functional_space(
  x,
  groups = NULL,
  method = c("convexhull", "dendrogram", "tpd", "hypervolume"),
  n_axes = NULL,
  var_threshold = 0.98,
  n_boot = 100,
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

- method:

  Character, the functional richness measure to compute in the PCA-based
  trait space for `fd_ref` and every `fd_boot` draw. One of:

  `"convexhull"`

  :   (default) n-dimensional convex-hull volume (Villeger, Mason &
      Mouillot, 2008), via
      [`geometry::convhulln()`](https://rdrr.io/pkg/geometry/man/convhulln.html)
      (Qhull; Barber, Dobkin & Huhdanpaa, 1996) – the measure used by
      Bertrand (2026) and the only one that strictly requires
      `nlevels(groups) > n_axes` (see `n_axes`). Requires the
      (Suggested) `geometry` package.

  `"dendrogram"`

  :   Total branch length of a UPGMA functional dendrogram (Petchey &
      Gaston, 2002), via
      [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html). A
      distance-based (non-volumetric) alternative that needs no
      additional Suggested package and places no restriction on the
      number of species relative to `n_axes`.

  `"tpd"`

  :   Functional richness from Trait Probability Density (Carmona, de
      Bello, Mason & Leps, 2019), via
      [`TPD::TPDsMean()`](https://rdrr.io/pkg/TPD/man/TPDsMean.html)/[`TPD::TPDc()`](https://rdrr.io/pkg/TPD/man/TPDc.html)/[`TPD::REND()`](https://rdrr.io/pkg/TPD/man/REND.html):
      each species is represented by a fixed-bandwidth Gaussian kernel
      rather than a single point, so `FRichness` is the proportion of a
      shared evaluation grid occupied by the union of these kernels.
      Requires the (Suggested) `TPD` package.

  `"hypervolume"`

  :   Gaussian-kernel hypervolume (Blonder et al., 2014, 2018), via
      [`hypervolume::hypervolume_gaussian()`](https://rdrr.io/pkg/hypervolume/man/hypervolume_gaussian.html)/
      [`hypervolume::get_volume()`](https://rdrr.io/pkg/hypervolume/man/get_volume.html):
      conceptually similar to `"tpd"` (a smoothed, kernel-based volume
      rather than a hard-edged hull), but estimated by Monte Carlo
      sampling rather than on a fixed grid, and by far the most
      computationally expensive of the four – consider a smaller
      `n_boot` (e.g. 20-50) and/or a smaller `hv_samples_per_point` than
      for the other methods. Requires the (Suggested) `hypervolume`
      package.

  `"tpd"` and `"hypervolume"` both represent each species (or each
  bootstrap-drawn individual) as a *kernel* rather than a bare point,
  using a bandwidth computed once from the full individual-level PCA
  scores and reused, unchanged, for `fd_ref` and every `fd_boot` draw
  (see Details for why this fixed-bandwidth/fixed-grid design is
  required for the draws to be comparable at all).

- n_axes:

  Integer, the number of PCA axes to retain. If `NULL` (default), the
  smallest number of axes whose cumulative proportion of variance
  reaches `var_threshold` is used automatically – Bertrand (2026) used 8
  axes, capturing 98% of total variance, for a similar ten-trait
  morphological data set. For `method = "convexhull"` only, must leave
  strictly more species than axes (`nlevels(groups) > n_axes`), since a
  non-degenerate n-dimensional convex hull requires at least
  `n_axes + 1` affinely independent points; lower `n_axes` (or
  `var_threshold`) if this is not satisfied. The other methods do not
  need this and only get a warning instead.

- var_threshold:

  Cumulative proportion of variance used to automatically choose
  `n_axes` when `n_axes = NULL`. Defaults to `0.98`, as in Bertrand
  (2026).

- n_boot:

  Integer, number of bootstrap "communities". For each, one individual
  is drawn at random (independently across species) for every species,
  and the functional richness of the resulting
  one-individual-per-species point set is computed. This is also the
  number of draws the significance test is based on (see Details), so
  larger values give a finer-grained p-value floor of
  `1 / (n_boot + 1)`. Defaults to `100`, as in Bertrand (2026).

- log_transform, scale:

  As in
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md);
  only used when `x` is a raw trait table (ignored, and taken from `x`,
  when `x` is an `"intrait_traitspace"` object).

- dendrogram_linkage:

  Character, clustering method passed to `stats::hclust(method =)` when
  `method = "dendrogram"`. Defaults to `"average"` (UPGMA), as in
  Petchey & Gaston (2002).

- tpd_alpha:

  Numeric, greater than 0 and at most 1, passed to
  [`TPD::TPDsMean()`](https://rdrr.io/pkg/TPD/man/TPDsMean.html)'s
  `alpha` when `method = "tpd"`: the proportion of each species' kernel
  probability mass included. Defaults to `0.95` (the `TPD` package's own
  default).

- tpd_bw_factor:

  Numeric, when `method = "tpd"`, the fixed per-axis kernel standard
  deviation is `tpd_bw_factor` times that axis's overall
  (between-species) standard deviation across the full individual-level
  PCA scores – a plug-in bandwidth, since a single bootstrap-drawn
  individual carries no within-species variance of its own to estimate a
  kernel from (see Details). Defaults to `0.5`.

- tpd_n_divisions:

  Passed to
  [`TPD::TPDsMean()`](https://rdrr.io/pkg/TPD/man/TPDsMean.html)'s
  `n_divisions` when `method = "tpd"` (grid resolution); `NULL`
  (default) uses that function's own default.

- hv_bw_method:

  Character, `method` passed to
  [`hypervolume::estimate_bandwidth()`](https://rdrr.io/pkg/hypervolume/man/estimate_bandwidth.html)
  when `method = "hypervolume"`. Defaults to `"silverman"`.

- hv_samples_per_point:

  Integer, passed to
  [`hypervolume::hypervolume_gaussian()`](https://rdrr.io/pkg/hypervolume/man/hypervolume_gaussian.html)'s
  `samples.per.point` when `method = "hypervolume"`. Defaults to a more
  conservative `500` (rather than that function's own
  dimensionality-scaled default), since this value is paid `n_boot`
  times over; increase it for a more precise (but slower) estimate.

## Value

An object of class `"intrait_bootstrap_fspace"`, a list with elements
`fd_ref` (centroid-based reference richness), `fd_boot` (numeric vector
of length `n_boot`, the bootstrap richness values), `fd_boot_mean`,
`fd_boot_sd`, `fd_boot_q05`, `fd_boot_q95` (summary of `fd_boot`),
`diff` (`fd_boot_mean - fd_ref`), `p_value` (one-sided bootstrap
p-value, see Details), `method`, `n_axes` (actual number of PCA axes
used), `var_explained` (cumulative proportion of variance captured by
those `n_axes` axes), `n_boot`, and `groups`. Has dedicated
[`print()`](https://rdrr.io/r/base/print.html) and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

## Details

A fresh Principal Component Analysis is always performed inside this
function (on `x$X`, the standardised trait matrix, when `x` is an
`"intrait_traitspace"` object, or on freshly standardised `x`
otherwise), so that `n_axes` PCA dimensions – rather than only the two
axes
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
retains for plotting – are available for the functional-richness
computation, exactly as in Bertrand (2026) (who used convex-hull volume
specifically; the `"dendrogram"`/`"tpd"`/ `"hypervolume"` alternatives
are provided here as different, commonly used ways of quantifying
functional richness from the same PCA scores, not as a reproduction of
Bertrand (2026)'s own results).

For `method = "tpd"` and `"hypervolume"`, each call needs a kernel
bandwidth (and, for `"tpd"`, an evaluation grid). If this were
re-estimated separately from each bootstrap draw's own small,
single-individual-per-species point set, differences between draws would
partly reflect differences in the *estimated bandwidth/grid* rather than
genuine differences in point configuration – making `fd_ref` and
`fd_boot` not actually comparable. Both are therefore computed **once**,
from the full individual-level PCA scores, before any bootstrap draw,
and reused unchanged for `fd_ref` and every `fd_boot` draw.

Bertrand (2026) compares the bootstrap distribution to `fd_ref` with a
one-sided permutation test (H0: mean(FD_boot) \<= FD_ref, using 9,999
permutations of an unspecified scheme). Reproducing that test exactly is
not possible from the report's description alone, so two candidate
designs were evaluated by simulation before choosing an implementation,
and it is worth recording why the first one was rejected. The initial
candidate reassigned species labels to individuals at random (preserving
sample sizes, as in
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)'s
permutation test) and compared a permuted centroid volume to a permuted
single-draw volume. Simulation showed this null is not informative here:
shuffling labels collapses every permuted centroid toward the *global*
mean of all individuals (a permuted "species" is just a random subsample
of the whole data set), while a permuted single-individual draw still
spans the data's full range, so the permuted difference is typically far
larger than the real, structure-preserving difference regardless of
whether genuine ITV is present – the test was essentially always
non-significant by construction, which does not match Bertrand (2026)'s
reported result and would silently mislead users.

The implementation used here instead treats `fd_boot` itself as the
reference (empirical, resampling-based) distribution and asks how
extreme `fd_ref` is relative to it, which requires no separate
permutation scheme: `p_value` is the proportion of `fd_boot` draws less
than or equal to `fd_ref`, plus one, divided by `n_boot + 1` (the same
`+ 1` correction convention as
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md);
Davison & Hinkley, 1997). A small `p_value` means `fd_ref` sits in the
low tail of the bootstrap distribution, i.e. that individual-based
functional richness exceeds the centroid-based reference by more than
would be expected from the bootstrap resampling variability alone. This
design was verified by simulation (clustered points with known, tunable
intraspecific dispersion) to correctly stay non-significant when
intraspecific variability is negligible and to correctly detect a
strong, real excess when it is not.

Species represented by a single individual necessarily contribute the
same point to every bootstrap draw (there is nothing to resample for
that species); this is expected behaviour, not an error.

The `n_boot` bootstrap draws are independent of one another (each is
just one random individual per species plus a functional-richness
recomputation), so they parallelise trivially. If the `future.apply`
package is installed and a parallel
[`future::plan()`](https://future.futureverse.org/reference/plan.html)
(e.g. `future::plan("multisession")`) has been set before calling this
function, the draws are distributed across that plan's workers
automatically; otherwise (no plan set, or `future.apply` not installed)
they simply run sequentially, with identical results either way. This
matters mainly for large `n_axes`/many-species data sets
(`method = "convexhull"`, see
[`species_sensitivity()`](https://funtraits.github.io/intraitR/reference/species_sensitivity.md)
for a discussion of that per-call cost) or for `method = "hypervolume"`,
whose per-draw cost is high regardless of data set size.

## References

Bertrand P (2026). Intraspecific trait variability shapes the functional
space of freshwater fish in French Guiana assemblages. M2 Biodiversity
Ecology Evolution (BEE) internship report, Lille University / Centre de
Recherche sur la Biodiversite et l'Environnement (CRBE, AQUAECO team),
unpublished, supervised by A. Toussaint and S. Brosse.

Villeger S, Mason NWH, Mouillot D (2008). New multidimensional
functional diversity indices for a multifaceted framework in functional
ecology. Ecology, 89(8), 2290-2301.

Barber CB, Dobkin DP, Huhdanpaa H (1996). The Quickhull algorithm for
convex hulls. ACM Transactions on Mathematical Software, 22(4), 469-483.

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

Davison AC, Hinkley DV (1997). Bootstrap Methods and their Application.
Cambridge University Press.

## See also

[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)

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

# method = "dendrogram" needs no extra Suggested package
bf_dendro <- bootstrap_functional_space(ts, method = "dendrogram", n_axes = 2, n_boot = 200)
bf_dendro
#> <intrait_bootstrap_fspace> (method = "dendrogram")
#>   2 PCA axes retained (49.2% of variance), 10 species
#>   Centroid-based reference richness (FD_ref): 13.55
#>   Bootstrap richness (FD_boot, 200 draws): mean = 18.2, SD = 6.372, 5-95% = [12.92, 35.76]
#>   Difference (mean FD_boot - FD_ref): 4.646 (one-sided bootstrap p = 0.1144)
plot(bf_dendro)


if (requireNamespace("geometry", quietly = TRUE)) {
  # n_axes = 2 here only to keep the example fast; Bertrand (2026) used 8
  bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 200)
  bf
}
#> <intrait_bootstrap_fspace> (method = "convexhull")
#>   2 PCA axes retained (49.2% of variance), 10 species
#>   Centroid-based reference richness (FD_ref): 6.104
#>   Bootstrap richness (FD_boot, 200 draws): mean = 11.19, SD = 9.051, 5-95% = [5.474, 17.99]
#>   Difference (mean FD_boot - FD_ref): 5.086 (one-sided bootstrap p = 0.1194)
if (requireNamespace("TPD", quietly = TRUE)) {
  bf_tpd <- bootstrap_functional_space(ts, method = "tpd", n_axes = 2, n_boot = 50)
  bf_tpd
}
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
#> <intrait_bootstrap_fspace> (method = "tpd")
#>   2 PCA axes retained (49.2% of variance), 10 species
#>   Centroid-based reference richness (FD_ref): 36.67
#>   Bootstrap richness (FD_boot, 50 draws): mean = 43.29, SD = 5.62, 5-95% = [35.83, 55.67]
#>   Difference (mean FD_boot - FD_ref): 6.615 (one-sided bootstrap p = 0.09804)
if (requireNamespace("hypervolume", quietly = TRUE)) {
  # small n_boot: method = "hypervolume" is comparatively slow
  bf_hv <- bootstrap_functional_space(ts, method = "hypervolume", n_axes = 2, n_boot = 20)
  bf_hv
}
#> Note that the formula used for the Silverman estimator differs in version 3 compared to prior versions of this package.
#> Use method='silverman-1d' to replicate prior behavior.
#> <intrait_bootstrap_fspace> (method = "hypervolume")
#>   2 PCA axes retained (49.2% of variance), 10 species
#>   Centroid-based reference richness (FD_ref): 19.14
#>   Bootstrap richness (FD_boot, 20 draws): mean = 23.93, SD = 3.291, 5-95% = [19.33, 29.76]
#>   Difference (mean FD_boot - FD_ref): 4.787 (one-sided bootstrap p = 0.09524)
# }
```
