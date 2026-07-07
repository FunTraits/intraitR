# Impute missing (NA) landmark coordinates

Estimates missing 2D coordinates directly in `landmarks$coords` (or a
raw `p x k x n` array), rather than leaving gaps in individual
specimens' digitized configurations or discarding them. Two families of
method are available: `"tps"`/`"regression"` use
[`geomorph::estimate.missing()`](https://rdrr.io/pkg/geomorph/man/estimate.missing.html)
to exploit the geometric covariation among landmark positions across the
sample (thin-plate spline warping or multivariate regression) – the
standard approach for missing landmark data in geometric morphometrics;
`"impute_mean"`, `"impute_group_mean"`, `"missforest"`, and
`"missforest_phylo"` instead treat each landmark coordinate as an
ordinary numeric variable and impute it statistically, mirroring the
equivalent `na_action` options of
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
(applied there to the *derived* trait matrix rather than to raw
coordinates).

## Usage

``` r
impute_landmarks(
  landmarks,
  method = c("tps", "regression", "impute_mean", "impute_group_mean", "missforest",
    "missforest_phylo"),
  groups = NULL,
  missforest_ntree = 100,
  missforest_maxiter = 10,
  tree = NULL,
  missforest_phylo_k = 10
)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` (from
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
  [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
  or
  [`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)/
  [`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)),
  or a raw `p x k x n` landmark array, with at least one `NA`
  coordinate. Landmarks are expected to follow the FISHMORPH
  digitization scheme (see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)):
  landmarks 1-19 are anatomical (shape) landmarks; 20-21 are a scale
  bar; the optional 22 is a body-curvature correction point.

- method:

  Character, `"tps"` (default) for thin-plate spline interpolation, or
  `"regression"` for multivariate regression on the other landmarks;
  passed to `method = "TPS"`/`"Reg"` in
  [`geomorph::estimate.missing()`](https://rdrr.io/pkg/geomorph/man/estimate.missing.html).
  `"tps"` uses local geometric relationships to the nearest complete
  landmarks and is the more commonly used default; `"regression"` can
  perform better when a missing landmark is strongly correlated with
  overall shape (e.g. a near-symmetric point) but needs a reasonably
  large, complete-enough sample to estimate that relationship reliably.
  `"impute_mean"` replaces a missing coordinate with the mean of that
  same coordinate (landmark x dimension) across all specimens;
  `"impute_group_mean"` uses the mean within the specimen's own `groups`
  instead (falling back to the overall mean, with a warning, for a group
  entirely missing that coordinate); `"missforest"` uses
  random-forest-based iterative imputation
  ([`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html),
  Stekhoven & Buhlmann, 2012) across all landmark coordinates jointly,
  using `groups` (when available) as an additional predictor;
  `"missforest_phylo"` does the same but also augments the predictor
  matrix with phylogenetic PCoA axes (see
  [`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md),
  `tree`/`missforest_phylo_k`) for the species in `groups`, falling back
  to plain `"missforest"` (with a warning) if phylogenetic axes cannot
  be used. Unlike `"tps"`/`"regression"`, these four options ignore the
  geometric/shape covariation among landmarks altogether and treat each
  coordinate independently (or, for `"missforest"`/`"missforest_phylo"`,
  via generic non-linear association) – they are simpler and match
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)'s
  own `na_action` behaviour, but are not a geometric-morphometric
  estimate of the missing point's true position, so prefer
  `"tps"`/`"regression"` for actual shape landmarks when enough complete
  specimens are available, and reserve the statistical options for
  exploratory use or when too few complete configurations remain for
  [`geomorph::estimate.missing()`](https://rdrr.io/pkg/geomorph/man/estimate.missing.html)
  to work reliably.

- groups:

  Optional factor (or character vector), one value per specimen in the
  same order as `dimnames(A)[[3]]`, used by
  `method = "impute_group_mean"` (required) and, optionally, by
  `method = "missforest"`/`"missforest_phylo"` (as an auxiliary
  predictor; required by `"missforest_phylo"` for phylogenetic matching
  specifically – without it, `"missforest_phylo"` falls back to plain
  `"missforest"`). If `NULL` and `landmarks` is an
  `"intrait_landmarks"`/`"intrait_gpa"` object whose `metadata` contains
  a `species` column, it is used automatically. Ignored by `"tps"`,
  `"regression"`, and `"impute_mean"`.

- missforest_ntree, missforest_maxiter:

  Number of trees per forest and maximum number of iterations passed to
  [`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html)
  when `method` is `"missforest"`/`"missforest_phylo"`; ignored
  otherwise. Default to `missForest`'s own defaults (`100` and `10`).

- tree:

  Used only by `method = "missforest_phylo"`: an object of class
  `"phylo"`, or `NULL` (default) to use the bundled
  [`load_fishmorph_phylogeny()`](https://funtraits.github.io/intraitR/reference/load_fishmorph_phylogeny.md)
  tree.

- missforest_phylo_k:

  Used only by `method = "missforest_phylo"`: maximum number of
  phylogenetic PCoA axes to add as predictors. Defaults to `10`.

## Value

An object of the same class as `landmarks` (`"intrait_landmarks"` or a
raw array), with `NA` coordinates in landmarks 1-19 replaced by their
estimated value. Everything else (`scale`, `metadata`, landmarks 20 and
up) is left unchanged. The returned `coords` array also carries an
`"imputed"` attribute (a `p x n` logical matrix, one row per landmark
and one column per specimen, `TRUE` where that point was estimated
rather than digitized), which
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
uses to highlight imputed points in red.

## Details

Only landmarks 1-19 (the anatomical/shape landmarks used for Generalised
Procrustes Analysis elsewhere in this package, e.g.
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md))
are eligible for imputation here. Landmarks 20-21 (the scale bar) are
*not* homologous shape landmarks – their position simply reflects
wherever a ruler was placed in the picture – so their covariation with
the rest of the configuration is meaningless, and a missing scale bar
point cannot be estimated by any of these methods; if either is missing
for a specimen, a warning is issued and that specimen's scale bar is
left as `NA` (matching
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)'s
own "zero-length or missing scale bar" warning – that specimen's
segments/ratios will still be `NA` downstream unless the scale bar is
fixed some other way). Landmark 22 (optional body- curvature correction)
is deliberately "0 if not needed" under the original protocol rather
than a routinely digitized point, so it is also left untouched.

As with any imputation, this is not a substitute for re-digitizing a
specimen from its original photograph when that is possible, and results
should be treated with more caution as the fraction of missing landmarks
grows, or when very few specimens are available to learn the imputation
model from (be it the covariation structure used by `"tps"`/
`"regression"`, or the column/group means and random forests used by the
statistical options). Always compare an imputed specimen against its
non-imputed neighbours (e.g. with
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
which highlights imputed landmarks directly, or the more generic
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md))
before relying on it in an analysis.

## References

Stekhoven, D. J., & Buhlmann, P. (2012). MissForest – non-parametric
missing value imputation for mixed-type data. Bioinformatics, 28(1),
112-118.
[doi:10.1093/bioinformatics/btr597](https://doi.org/10.1093/bioinformatics/btr597)

## See also

[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md),
[`load_fishmorph_phylogeny()`](https://funtraits.github.io/intraitR/reference/load_fishmorph_phylogeny.md)

## Examples

``` r
# \donttest{
fish <- load_t26_saudrune_landmarks()
anyNA(fish$coords) # some real specimens are missing landmark 5
#> [1] TRUE
fish_imputed <- impute_landmarks(fish)
#> Warning: 3 specimen(s) have a missing scale bar landmark (20 or 21); these cannot be estimated from shape covariation (they are not homologous shape landmarks) and are left as NA -- see fishmorph_segments()'s "zero-length or missing scale bar" warning.
#> impute_landmarks(): estimated 260 missing anatomical landmark coordinate(s) using method = "tps".
anyNA(fish_imputed$coords[1:19, , ]) # anatomical landmarks now complete
#> [1] TRUE

# plot_fishmorph_points() highlights the imputed point(s) in red:
plot_fishmorph_points(fish_imputed, specimen = 1)


# statistical alternatives, mirroring trait_space()'s na_action options;
# `groups` is auto-detected here from fish$metadata$species
fish_mean <- impute_landmarks(fish, method = "impute_mean")
#> Warning: 3 specimen(s) have a missing scale bar landmark (20 or 21); these cannot be estimated from shape covariation (they are not homologous shape landmarks) and are left as NA -- see fishmorph_segments()'s "zero-length or missing scale bar" warning.
#> impute_landmarks(): imputed 505 missing landmark coordinate value(s) using column means (method = "impute_mean").
fish_gmean <- impute_landmarks(fish, method = "impute_group_mean")
#> Warning: 3 specimen(s) have a missing scale bar landmark (20 or 21); these cannot be estimated from shape covariation (they are not homologous shape landmarks) and are left as NA -- see fishmorph_segments()'s "zero-length or missing scale bar" warning.
#> impute_landmarks(): imputed 505 missing landmark coordinate value(s) using within-group means (method = "impute_group_mean").
if (requireNamespace("missForest", quietly = TRUE)) {
  fish_rf <- impute_landmarks(fish, method = "missforest")

  # phylogenetically-augmented missForest: adds phylogenetic PCoA axes
  # (from the bundled FISHMORPH tree, see load_fishmorph_phylogeny()) as
  # extra predictors, so close relatives can inform each other's
  # imputed coordinates in addition to shared species identity
  if (requireNamespace("ape", quietly = TRUE)) {
    fish_rf_phylo <- impute_landmarks(fish, method = "missforest_phylo")
  }
}
#> Warning: 3 specimen(s) have a missing scale bar landmark (20 or 21); these cannot be estimated from shape covariation (they are not homologous shape landmarks) and are left as NA -- see fishmorph_segments()'s "zero-length or missing scale bar" warning.
#> impute_landmarks(): imputed 505 missing landmark coordinate value(s) using random-forest imputation (missForest), using `groups` as an auxiliary predictor (out-of-bag NRMSE = 0.061).
#> Warning: 3 specimen(s) have a missing scale bar landmark (20 or 21); these cannot be estimated from shape covariation (they are not homologous shape landmarks) and are left as NA -- see fishmorph_segments()'s "zero-length or missing scale bar" warning.
#> Warning: 3 species not found in `tree$tip.label` and dropped: Gobio_occitaniae, Phoxinus_phoxinus/bigerri, 
#> impute_landmarks(): imputed 505 missing landmark coordinate value(s) using random-forest imputation (missForest), using `groups` as an auxiliary predictor, augmented with 6 phylogenetic PCoA axis/axes (7 species matched to the tree) (out-of-bag NRMSE = 0.051).
# }
```
