# Build a functional trait space from a numeric trait table

Constructs a low-dimensional functional trait space from any table of
numeric traits (e.g. the FISHMORPH ecomorphological ratios produced by
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
or linear traits/ratios from
[`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md)),
by Principal Component Analysis or by metric multidimensional scaling
(Principal Coordinate Analysis) of a Euclidean distance matrix, the two
standard approaches used to build functional trait spaces in comparative
ecology (e.g. Villéger et al., 2017).

## Usage

``` r
trait_space(
  traits,
  groups = NULL,
  method = c("pca", "pcoa"),
  log_transform = TRUE,
  scale = TRUE,
  axes = c(1, 2),
  na_action = c("fail", "omit", "impute_mean", "impute_group_mean", "missforest",
    "missforest_phylo"),
  missforest_ntree = 100,
  missforest_maxiter = 10,
  tree = NULL,
  missforest_phylo_k = 10,
  flag_outliers = TRUE,
  outlier_threshold = 3,
  outlier_min_n = 5,
  remove_outliers = FALSE
)

# S3 method for class 'intrait_traitspace'
print(x, ...)
```

## Arguments

- traits:

  A `data.frame` or matrix of numeric traits, one row per specimen or
  species. Non-numeric columns are dropped with a warning (they are not
  included in the ordination, but grouping is still auto-detected from a
  `species` column if present; see `groups`). Constant (zero-variance)
  numeric columns are also dropped with a warning, since they carry no
  information for an ordination and cannot be rescaled to unit variance;
  this commonly happens when incidental numeric metadata (e.g. a
  digitization replicate counter) is carried over from
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)/[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  and passed to `trait_space()` unfiltered. A non-finite value (`Inf`/
  `-Inf`, as from a ratio with a zero-length denominator segment) is
  always an error regardless of `na_action` (it is not treated as an
  ordinary missing value – see Details).

- groups:

  Optional factor (or character vector), one value per row of `traits`,
  used to colour/group observations when plotting. If `NULL` and
  `traits` contains a `species` column, it is used automatically.

- method:

  Character, one of `"pca"` (default, Principal Component Analysis via
  [`stats::prcomp()`](https://rdrr.io/r/stats/prcomp.html)) or `"pcoa"`
  (Principal Coordinate Analysis / classical multidimensional scaling,
  via [`stats::cmdscale()`](https://rdrr.io/r/stats/cmdscale.html), of a
  Euclidean distance matrix on the same, optionally transformed and
  standardised, trait data — equivalent to PCA up to an arbitrary
  rotation and sign).

- log_transform:

  Logical, apply a `log10(x + 1)` transformation to every numeric trait
  before centring/scaling and ordination. Defaults to `TRUE`. Ratio
  traits (e.g. from
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  or
  [`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md))
  are bounded at zero and often right-skewed, so a log(x + 1)
  transformation (the `+ 1` accommodating traits that can legitimately
  equal zero, e.g. under the Villéger et al., 2010, exception rules) is
  common practice before ordination. Requires all trait values to be
  non-negative; set to `FALSE` to skip (e.g. for traits that can be
  negative, such as PCA scores fed back into a second ordination).

- scale:

  Logical, standardise (centre and scale to unit variance) traits before
  building the trait space, after the optional log transformation
  (recommended when traits are on different scales or have different
  variances). Defaults to `TRUE`.

- axes:

  Integer vector of length 2, the ordination axes to retain for
  plotting. Defaults to `c(1, 2)`.

- na_action:

  Character, how to handle missing values in the numeric trait columns:
  `"fail"` (default) stops with an error, as in previous versions;
  `"omit"` removes affected rows (specimens/species) and reports how
  many were dropped; `"impute_mean"` replaces missing values with the
  corresponding column mean; `"impute_group_mean"` replaces missing
  values with the mean of the same trait within the same group
  (`groups`, or the auto-detected `species` column), falling back to the
  column mean, with a warning, for a group entirely missing a trait;
  `"missforest"` uses random-forest-based iterative imputation
  ([`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html),
  Stekhoven & Bühlmann, 2012) on the numeric trait matrix, using
  `groups` (when available) as an additional predictor;
  `"missforest_phylo"` does the same but also augments the predictor
  matrix with phylogenetic PCoA axes (see
  [`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md),
  `tree`/`missforest_phylo_k`) for the species in `groups`, so that
  phylogenetically related species can inform each other's imputed
  values in addition to shared species identity – falling back to plain
  `"missforest"`, with a warning explaining why, if phylogenetic axes
  cannot be used (no `groups`, fewer than 3 species matched to `tree`,
  "ape" not installed, etc.). `"omit"` and every imputation option print
  a [`message()`](https://rdrr.io/r/base/message.html) reporting the
  number of rows removed or values imputed (plus, for `"missforest"`/
  `"missforest_phylo"`, the out-of-bag normalised RMSE of the
  imputation, and, for `"missforest_phylo"`, how many phylogenetic axes
  and matched species were actually used), so this is never a silent
  operation.

- missforest_ntree, missforest_maxiter:

  Number of trees per forest and maximum number of iterations passed to
  [`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html)
  when `na_action` is `"missforest"`/ `"missforest_phylo"`; ignored
  otherwise. Default to `missForest`'s own defaults (`100` and `10`).

- tree:

  Used only by `na_action = "missforest_phylo"`: an object of class
  `"phylo"` (e.g. from
  [`ape::read.tree()`](https://rdrr.io/pkg/ape/man/read.tree.html)), or
  `NULL` (default) to use the bundled
  [`load_fishmorph_phylogeny()`](https://funtraits.github.io/intraitR/reference/load_fishmorph_phylogeny.md)
  tree.

- missforest_phylo_k:

  Used only by `na_action = "missforest_phylo"`: maximum number of
  phylogenetic PCoA axes to add as predictors. Defaults to `10`.

- flag_outliers:

  Logical, screen for potential within-group (e.g. within-species)
  outliers – specimens unusually far from other members of their own
  group in the standardised trait space – and report them (see Details
  and `outlier_threshold`/`outlier_min_n`). Requires `groups` (or an
  auto-detected `species` column); has no effect (no `$outlier_screen`
  element, no message) if no grouping is available, since "distance from
  other individuals of the same species" is undefined without species
  labels. Defaults to `TRUE`. This never removes any observation: it
  only flags candidates for visual/manual review (e.g. with
  [`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
  or
  [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
  before deciding whether an exclusion is warranted.

- outlier_threshold:

  Numeric, the number of median absolute deviations (MAD) above a
  group's median within-group distance beyond which a specimen is
  flagged; same convention as
  [`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)'s
  `threshold`. Defaults to `3`.

- outlier_min_n:

  Integer, the minimum number of specimens a group must have for outlier
  flagging to be attempted in it; groups smaller than this still get a
  computed distance (in `$outlier_screen`) but are never flagged (`NA`),
  since a median/MAD computed from very few points is not a reliable
  reference. Defaults to `5`.

- remove_outliers:

  Logical, actually exclude every specimen flagged by `flag_outliers`
  from the trait matrix *before* building the ordination (rather than
  only flagging them for review, the default). Requires
  `flag_outliers = TRUE` (an error is raised otherwise, since there
  would be nothing to remove). Defaults to `FALSE`: removing specimens
  changes the ordination and any statistic derived from it (e.g.
  [`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md),
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)),
  so this is opt-in rather than automatic, and every removal is still
  recorded in `$removed_outliers` (see Return) for transparency and
  reproducibility – always confirm flagged specimens genuinely reflect
  an error (e.g. via
  [`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)/[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
  before turning this on for a given data set, rather than treating it
  as a default cleaning step.

- x:

  An object of class `"intrait_traitspace"`, as returned by
  `trait_space()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_traitspace"`, a list with elements `scores`
(data.frame of ordination scores), `var_explained` (percent variance
explained by the two selected axes), `loadings` (PCA variable loadings,
`NULL` for `method = "pcoa"`), `groups`, `axes`, `method`, `traits_used`
(names of the numeric columns used), `X` (the full standardised trait
matrix actually analysed, i.e. after log-transformation, removal of
constant columns, and any outlier removal, centred/scaled as requested;
used internally by
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)
so that dispersion statistics are not truncated to the two plotting
axes), and, when `flag_outliers = TRUE` and `groups` is available,
`outlier_screen` (a `data.frame`, one row per specimen *actually used in
the ordination* – i.e. excluding any row removed by
`remove_outliers = TRUE` – with columns `group`, `n_group`, `distance`
(to the specimen's own group centroid, in the full standardised trait
space `X`), `median_distance`, `mad_distance`, `threshold_value`, and
`flagged`; see Details), and `removed_outliers` (`NULL` unless
`remove_outliers = TRUE` removed at least one specimen, in which case a
`data.frame` with the same columns as `outlier_screen`, one row per
*excluded* specimen, for the record). Has a dedicated
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method.

Invisibly returns `x`.

## Details

A non-finite trait value (`Inf`/`-Inf`) is rejected with an error
regardless of `na_action`, before any missing-value handling: unlike
`NA`,
[`is.na()`](https://rdrr.io/r/base/NA.html)/[`anyNA()`](https://rdrr.io/r/base/NA.html)
do not detect `Inf`/`-Inf`, so such a value would otherwise silently
pass through every `na_action` unimputed and corrupt the ordination
(and, specifically for `na_action = "missforest"`, can crash
[`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html)
itself with a cryptic "missing value where TRUE/FALSE needed" error,
because its internal convergence check computes `Inf - Inf = NaN`). This
most commonly arises from a ratio with a zero-length denominator
segment, e.g. from a degenerate or duplicated landmark (see
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)/[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md));
investigate and correct the underlying measurement, or replace it with
`NA` yourself first if you want it handled like any other missing value.

By default (`na_action = "fail"`), rows with `NA` in any numeric trait
cause an error; set `na_action` to `"omit"` or one of the imputation
options to handle missing values automatically (see `na_action`). Mean
imputation (`"impute_mean"`, `"impute_group_mean"`) is a simple,
commonly used approach for small amounts of missing data in functional
trait matrices, but it shrinks the imputed trait's variance, ignores
correlations among traits, and can understate group dispersion (see
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)).
`na_action = "missforest"` addresses these limitations with
nonparametric random-forest imputation (Stekhoven & Bühlmann, 2012),
which uses the correlation structure among all numeric traits (and
`groups`, when available, as an auxiliary predictor) to predict each
missing value, and is generally preferred over mean imputation once more
than a few values are missing; it requires the `missForest` package (not
installed by default; see `Suggests`) and is stochastic, so results vary
run to run unless [`set.seed()`](https://rdrr.io/r/base/Random.html) is
called beforehand. `na_action = "missforest_phylo"` extends this further
with phylogenetic PCoA axes (see
[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md))
as additional predictors, so species can also borrow information from
their close relatives, not only from shared species identity; this can
help when a species has very few (or zero) complete specimens of its own
for `missForest` to learn from, but adds a phylogenetic assumption
(trait similarity correlates with relatedness) that should be reasonable
for the trait in question. If a very large fraction of values is
missing, no automated imputation method is a substitute for reviewing
the missing-data mechanism directly. This function does not implement
Gower distance for mixed (numeric and categorical) trait tables; for
mixed-trait functional spaces, standard tools such as the `mFD` or `FD`
packages should be used instead.

Note that this log-transform-then-standardise treatment applies to
*trait* data (ratios, linear measurements, etc.) only. It is not applied
by, and should not be applied to,
[`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md),
which ordinates Procrustes shape coordinates: those are already a
homogeneous, size-free coordinate system in which log-transforming or
rescaling individual columns would distort shape geometry.

When `flag_outliers = TRUE` (the default), every specimen's Euclidean
distance to its own group's centroid is computed on the full
standardised trait matrix `X` (all traits, not just the two plotting
axes), and, within each group with at least `outlier_min_n` specimens,
flagged if that distance exceeds `median + outlier_threshold * MAD`
(median absolute deviation) of that group's own within-group distances –
the same robust rule used by
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
but computed *within* each group rather than pooled across the whole
sample. Pooling across species, as a naive global outlier screen would,
mostly flags genuine interspecific morphological diversity rather than
digitization or identification errors (see the worked pooled-vs-within-
species comparison in `demo(pipeline_T26_saudrune)`); computing this
automatically, per group, inside `trait_space()` removes the need to
subset by hand. A single extreme specimen in an otherwise tight species
can also visibly distort the ordination for every *other* group, by
inflating the axis ranges/variance explained: a species-level outlier is
therefore often the right first thing to check when a functional space
"does not look right" (widely spread groups collapsed into one corner of
the plot), before considering, e.g., a different `na_action` or
transformation. As with
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
this only *flags* candidates – it never removes anything automatically,
since ad hoc, undocumented removal of "bad-looking" specimens is itself
a threat to reproducibility; always inspect a flagged specimen (e.g.
with
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)/[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
and its original photograph if available) before deciding whether to
exclude it, and record that decision (e.g. in a QC log, as
`data-raw/t26_saudrune_prepare.R` does for the bundled real data set)
rather than silently dropping rows. This is a Euclidean, not
Mahalanobis, distance (like
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)),
so it does not account for correlations among traits; it is intended as
a fast, transparent first pass, not a definitive statistical test.

Setting `remove_outliers = TRUE` goes one step further and actually
excludes every flagged specimen before the ordination is built (rather
than only flagging it): `X`, `groups`, and `scores` in the returned
object then describe the *cleaned* data set, and `$removed_outliers`
records exactly which specimens were dropped and why, so the exclusion
remains fully reproducible and auditable (e.g. reportable in a
manuscript's methods) rather than an undocumented, ad hoc edit made
before calling `trait_space()`. This is deliberately opt-in (`FALSE` by
default): removing data always changes downstream results and should be
a conscious, visually-confirmed decision (see above), not something that
happens silently just because a threshold was crossed.

## References

Villéger, S., Brosse, S., Mouchet, M., Mouillot, D., & Vanni, M. J.
(2017). Functional ecology of fish: current approaches and future
challenges. Aquatic Sciences, 79(4), 783-801.

## See also

[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md),
[`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)

## Examples

``` r
# real T-26 Saudrune data; na_action = "omit" is required here because,
# unlike simulate_fishmorph_points(), real specimens have some missing
# landmarks (see ?load_t26_saudrune_landmarks)
fish <- load_t26_saudrune_landmarks()
segments <- fishmorph_segments(fish)
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
ratios <- fishmorph_ratios(segments)
ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 230 row(s) out of 558 with missing values.
#> flag_outliers: 21 specimen(s) flagged as within-group outlier(s) across 5 group(s) (Barbatula barbatula, Gobio occitaniae, Leuciscus burdigalensis, Phoxinus phoxinus/bigerri, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 2 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
ts   # flags any within-species outliers found, see ts$outlier_screen
#> <intrait_traitspace> (pca)
#>   Axes PC1/PC2, variance explained: 28.1% / 21.2%
#>   328 observations, 10 traits (replicate, BEl, VEp, REs, OGp, RMl, BLs, PFv, PFs, CPt)
#>   10 groups
#>   21 potential within-group outlier(s) flagged (see $outlier_screen); most atypical:
#>     T-26-0052_Operator_1 (Squalius cephalus): distance = 20.889 (group median 2.196)
#>     T-26-0050_Operator_2 (Gobio occitaniae): distance = 16.687 (group median 1.901)
#>     T-26-0230-1_Operator_2 (Barbatula barbatula): distance = 14.075 (group median 2.237)
#>     T-26-0012_Operator_2 (Gobio occitaniae): distance = 8.386 (group median 1.901)
#>     T-26-0087_Operator_2 (Gobio occitaniae): distance = 7.918 (group median 1.901)
# \donttest{
plot(ts)

# }

# Once a flagged specimen has been visually confirmed as an error (not
# just genuine morphological variation), exclude it from the ordination:
ts_clean <- trait_space(
  ratios, groups = fish$metadata$species, na_action = "omit",
  remove_outliers = TRUE
)
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 230 row(s) out of 558 with missing values.
#> remove_outliers: removing 21 specimen(s) flagged as within-group outlier(s) across 5 group(s) (Barbatula barbatula, Gobio occitaniae, Leuciscus burdigalensis, Phoxinus phoxinus/bigerri, Squalius cephalus) before building the ordination; see $removed_outliers for exactly which ones, and why, before relying on this in a publication -- always confirm each removal corresponds to a real error (e.g. via plot_landmarks()/ plot_fishmorph_points()), not just genuine morphological variation.
#> flag_outliers: 2 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
ts_clean$removed_outliers   # exactly which specimen(s) were excluded, and why
#>                                            group n_group  distance
#> T-26-0010_Operator_2            Gobio occitaniae     147  4.921450
#> T-26-0011_Operator_2           Squalius cephalus      95  4.862514
#> T-26-0012_Operator_2            Gobio occitaniae     147  8.385553
#> T-26-0018_Operator_2     Leuciscus burdigalensis      13  3.098036
#> T-26-0020_Operator_2            Gobio occitaniae     147  4.886399
#> T-26-0030_Operator_1     Leuciscus burdigalensis      13  2.432703
#> T-26-0050_Operator_2            Gobio occitaniae     147 16.686651
#> T-26-0052_Operator_1           Squalius cephalus      95 20.889444
#> T-26-0087_Operator_2            Gobio occitaniae     147  7.917643
#> T-26-0099_Operator_2   Phoxinus phoxinus/bigerri       5  3.140377
#> T-26-0144_Operator_1     Leuciscus burdigalensis      13  2.530585
#> T-26-0144_Operator_2     Leuciscus burdigalensis      13  2.360030
#> T-26-0230-1_Operator_2       Barbatula barbatula      19 14.074593
#> T-26-0261-5_Operator_1          Gobio occitaniae     147  3.422987
#> T-26-0262-2_Operator_1          Gobio occitaniae     147  3.879094
#> T-26-0263_Operator_1            Gobio occitaniae     147  4.078501
#> T-26-0263_Operator_2            Gobio occitaniae     147  4.098610
#> T-26-0264-4_Operator_1          Gobio occitaniae     147  4.307720
#> T-26-0264-4_Operator_2          Gobio occitaniae     147  4.352840
#> T-26-0276_Operator_1           Squalius cephalus      95  4.599041
#> T-26-0278-1_Operator_1       Barbatula barbatula      19  3.990754
#>                        median_distance mad_distance threshold_value flagged
#> T-26-0010_Operator_2          1.900974    0.4985865        3.396734    TRUE
#> T-26-0011_Operator_2          2.195731    0.5997552        3.994996    TRUE
#> T-26-0012_Operator_2          1.900974    0.4985865        3.396734    TRUE
#> T-26-0018_Operator_2          1.549083    0.2521450        2.305518    TRUE
#> T-26-0020_Operator_2          1.900974    0.4985865        3.396734    TRUE
#> T-26-0030_Operator_1          1.549083    0.2521450        2.305518    TRUE
#> T-26-0050_Operator_2          1.900974    0.4985865        3.396734    TRUE
#> T-26-0052_Operator_1          2.195731    0.5997552        3.994996    TRUE
#> T-26-0087_Operator_2          1.900974    0.4985865        3.396734    TRUE
#> T-26-0099_Operator_2          1.901078    0.2606203        2.682939    TRUE
#> T-26-0144_Operator_1          1.549083    0.2521450        2.305518    TRUE
#> T-26-0144_Operator_2          1.549083    0.2521450        2.305518    TRUE
#> T-26-0230-1_Operator_2        2.236905    0.5268630        3.817494    TRUE
#> T-26-0261-5_Operator_1        1.900974    0.4985865        3.396734    TRUE
#> T-26-0262-2_Operator_1        1.900974    0.4985865        3.396734    TRUE
#> T-26-0263_Operator_1          1.900974    0.4985865        3.396734    TRUE
#> T-26-0263_Operator_2          1.900974    0.4985865        3.396734    TRUE
#> T-26-0264-4_Operator_1        1.900974    0.4985865        3.396734    TRUE
#> T-26-0264-4_Operator_2        1.900974    0.4985865        3.396734    TRUE
#> T-26-0276_Operator_1          2.195731    0.5997552        3.994996    TRUE
#> T-26-0278-1_Operator_1        2.236905    0.5268630        3.817494    TRUE
```
