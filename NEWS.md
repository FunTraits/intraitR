# intraitR 1.3.0

* New `fd_accumulation()`: rarefies community **functional diversity
  indices** against intraspecific sampling effort -- the community-level
  companion to `itv_accumulation()`. It draws balanced sub-samples of `n`
  individuals per species, pools them into one assemblage in a fixed trait
  space built exactly as in `trait_space()` (shared PCA machinery, with
  `n_axes`/`var_threshold` axis selection), and recomputes each requested
  index, estimating the effort
  `n*` at which the index stabilises. Functional dispersion (FDis), Rao's
  quadratic entropy and functional richness (FRic) are computed directly;
  functional evenness (FEve) and divergence (FDiv) are delegated to
  `FD::dbFD()` when the Suggested `FD` package is installed. Functional
  richness honours a `method` argument (`"convexhull"`, `"dendrogram"`,
  `"tpd"`, `"hypervolume"`), reusing the same richness engines and tuning
  arguments as `bootstrap_functional_space()`. As in `itv_accumulation()`,
  richness uses the accumulation/asymptote framing (with a guard that
  rejects an implausible extrapolated asymptote) while the
  dispersion/regularity indices use the convergence/precision framing.
  Dedicated `print()` and `plot()` methods; parallelised via `future.apply`.

* New `tpd_dissimilarity()`: intraspecific-variability-aware functional
  dissimilarity between species, computed as `1 - overlap` of their Trait
  Probability Density kernels (Carmona et al., 2016, 2019) via the Suggested
  `TPD` package. Unlike a Euclidean distance between species means, it lets
  within-species spread shape the distances (species whose individuals
  overlap in trait space are treated as functionally closer). Returns a
  species-by-species dissimilarity matrix (with its shared/non-shared
  decomposition) as an `"intrait_tpd_dissim"` object with `print()`,
  `plot()` (a heat map) and `as.dist()` methods, usable directly for
  ordination, clustering, or distance-based diversity indices.

# intraitR 1.2.0

* New `itv_accumulation()`: builds a rarefaction/accumulation curve of
  intraspecific trait variability against the number of individuals
  sampled, and estimates the sample size `n*` at which that variability
  stabilises -- the trait-based analogue of a species accumulation curve.
  For each sub-sample size `n`, `n_perm` sub-samples of `n` individuals are
  drawn without replacement per group and the metric is recomputed. The
  meaning of "stabilises" adapts to the metric: for *dispersion* metrics
  (`"variance"`, the multivariate trace of the trait covariance; `"sd"`;
  `"cv"`) the sample estimator is unbiased, so the expected curve is flat
  and `n*` is a *precision* threshold (smallest `n` at which the resampling
  band's relative half-width stays below `conv_tol`); for the *accumulation*
  metric (`"range"`) the curve genuinely saturates and `n*` is taken at a
  fraction (`asymptote_prop`) of a fitted Michaelis-Menten or negative-
  exponential asymptote. Parallelised via `future.apply` like
  `bootstrap_functional_space()`/`trait_disparity()`, with dedicated
  `print()` and `plot()` methods. For accumulation metrics the `plot()`
  method draws a rarefaction/extrapolation curve: the observed portion
  solid, the fitted saturating model extended in a dashed line beyond the
  sampled range up to `n*` (controllable via `extrapolate`/`xmax`), and the
  fitted asymptote as a horizontal reference. The fitted half-saturation/
  rate parameter is returned as a new `k` column of `$summary`.

# intraitR 1.1.0

* `plot_fishmorph_shapes()` gains per-specimen colouring: `color_by`
  (a metadata column name such as `"operator"`/`"species"`, the special
  value `"specimen"` for one colour per shape, or a grouping vector), the
  `operator = TRUE` shortcut for `color_by = "operator"`, a custom
  `palette`, and a `legend`. To keep overcrowded overlays legible,
  `max_colors` (default `10`) reverts to the single `color` -- with a
  message -- when the requested colouring would need more than that many
  distinct colours.

* `plot()` for `itv_index()` results now draws the mean (multivariate)
  %ITV reference line bold and in colour, and labels it with its value,
  instead of the previous faint dotted grey line.

* **Breaking rename**: `morpho_space()` is now `shape_space()`, and its
  output class `"intrait_morphospace"` is now `"intrait_shapespace"` (with
  the corresponding `print()`/`plot()` methods renamed accordingly). The
  term "morphological space" was ambiguous for what is, specifically, the
  ordination of Procrustes (GPA) shape coordinates; "shape space" names it
  unambiguously. Figure titles now read "Shape space" instead of
  "Morphological space". The linear-ratio function `morpho_ratios()` is
  unchanged, as it concerns classical morphometric ratios rather than the
  shape space.

* New function `exclude_specimens()`: removes one or more known-bad (e.g.
  mismeasured/mis-digitized) specimens from an `"intrait_landmarks"` object
  (as returned by `read_tps()`, `read_landmarks_csv()`,
  `read_landmarks_xlsx()`, or `load_t26_saudrune_landmarks()`) or a raw
  landmark array, right after loading, so every downstream step
  (`fishmorph_segments()`, `gpa_fish()`, `correct_geometry()`, ...) simply
  never sees it -- rather than repeating an ad hoc `dplyr::filter()` on
  derived output (`segments`/`ratios`/`trait_space()`) at every stage of a
  pipeline, which is easy to apply inconsistently and, in the case of a
  typo/formatting mismatch (e.g. a leading zero), can silently filter out
  nothing at all. `coords`, `scale`, and `metadata` are filtered
  consistently by specimen name; any pre-existing per-specimen audit-trail
  attribute (`standardization_log`, `correction_log`, `corrected`,
  `orientation_log`) is filtered the same way, so it never refers to a
  specimen no longer in the data. Every exclusion is recorded, with an
  optional `reason`, in a `$removed_specimens` data.frame that accumulates
  across successive calls (mirroring `gpa_fish()`'s own
  `remove_outliers`/`$removed_outliers`), and is now surfaced by
  `print.intrait_landmarks()`. Explicitly errors, rather than silently
  doing the wrong thing, for an `"intrait_gpa"` object (Procrustes
  alignment is computed jointly across all specimens, so deleting a row
  after the fact does not undo its effect on the consensus shape) or an
  unknown specimen name (a typo no longer just matches, and removes,
  nothing).

* `correct_geometry()`'s pipeline is now also available as two separate
  functions, for workflows that want to inspect or use its value-preserving
  standardization on its own before deciding whether its value-changing
  correction is appropriate: `standardize_geometry()` performs steps 1-3
  only (isotropic rescale, scale-bar repositioning, rotation to a
  horizontal axis anchored at `Y = 0.5`) and, because these are all rigid/
  isotropic transforms, never changes any FISHMORPH segment or ratio
  value; `correct_geometry_conventions()` performs step 4 only (active
  correction of landmarks still violating the five geometric-scatter
  conventions once the axis is horizontal), and does change values, so it
  requires already-standardized input (the output of
  `standardize_geometry()` or `correct_geometry()`). `standardize_geometry()`
  gains an `orient` argument (default `TRUE`) that calls
  `standardize_orientation()` first, internalizing the manual chaining
  earlier versions of this package's documentation already recommended
  (`fish %>% standardize_orientation() %>% standardize_geometry(orient =
  FALSE)` is equivalent to the default `standardize_geometry(fish)`).
  `correct_geometry()` itself is unaffected and remains the same one-call
  pipeline as before, with identical messages, warnings, and numerical
  output (implemented by extracting the shared per-specimen geometry math
  into internal helpers, `.geometry_standardize_one()`/
  `.geometry_correct_one()`, reused by all three functions, so its
  orchestration/messaging code is untouched) -- confirmed equivalent to
  `standardize_geometry(landmarks, ..., orient = FALSE)` followed by
  `correct_geometry_conventions()` (see `test-standardize_geometry.R`'s
  reproduction test).

* `fishmorph_ratios()` gains a `landmarks` argument: the same
  `"intrait_landmarks"` object/array originally passed to
  `fishmorph_segments()`. A missing or zero-length scale bar (landmarks
  20-21) makes every one of `fishmorph_segments()`'s 11 measurements `NA`
  for that specimen, since the pixel-to-centimetre conversion factor is a
  single per-specimen scalar applied to all of them -- which previously
  also made all nine ratios `NA` for that specimen, even when every
  anatomical landmark (1-19) was perfectly digitized. Because a ratio is
  always (segment / segment) computed *within* the same specimen, the
  unknown/missing scale factor cancels out of the division exactly, so
  `landmarks` lets these nine ratios (only -- not the absolute segments,
  nor `MBl`) be recomputed directly from raw pixel-space landmark
  distances instead. Only applied to specimens whose `segments` row is
  entirely `NA` (the missing-scale-bar signature); a specimen with just
  one missing anatomical landmark, or a single `geometry_check`-flagged
  segment, is left untouched, since mixing pixel-space and calibrated
  values for the same specimen would defeat that quality control. New
  internal helper `.fishmorph_pixel_segments()` (`R/utils-internal.R`)
  extracts the shared pixel-distance geometry engine out of
  `fishmorph_segments()` (a pure refactor, no behaviour change there) so
  both functions compute the same 11 raw measurements identically.

* Fixed a bug where the `expect_equal()` reference value in two
  `impute_landmarks()` regression tests (`method = "impute_mean"` and
  `"impute_group_mean"`) was computed from the column/group mean
  *including* the very point about to be deleted and imputed, rather than
  excluding it as `impute_landmarks()` itself does (`mean(x, na.rm =
  TRUE)` computed *after* the value is set to `NA`). This was a test-only
  defect, caught by a real `devtools::test()` run; `impute_landmarks()`'s
  own imputation logic was unaffected.

* Fixed a bug where `trait_space()` could crash with a cryptic
  `Error in while (stopCriterion(...)) : missing value where TRUE/FALSE
  needed` under `na_action = "missforest"` (and could otherwise silently
  corrupt the ordination under any `na_action`) if a trait column
  contained a non-finite value (`Inf`/`-Inf`), typically from a ratio
  with a zero-length denominator segment (e.g. a degenerate or
  duplicated landmark; see `fishmorph_segments()`/`fishmorph_ratios()`).
  `Inf`/`-Inf` are not detected by `is.na()`/`anyNA()`, so such a value
  used to pass straight through every `na_action` unimputed;
  `missForest::missForest()`'s internal convergence check then computed
  `Inf - Inf = NaN`, crashing its `while()` loop. `trait_space()` now
  checks for non-finite trait values unconditionally, before any
  missing-value handling, and stops with an informative error naming the
  offending column(s) and row(s), regardless of `na_action`.

* `bootstrap_functional_space()` gains a `composition` argument: a
  communities x species matrix (presence/absence or abundance; only
  presence is used) giving the species composition of one or more
  communities/sites. When supplied, the same centroid-based-reference-vs-
  bootstrap-distribution principle used for the whole species pool is
  repeated independently for each community, restricted to that
  community's own species, using the same shared PCA space and
  method-specific auxiliary quantities (kernel bandwidth/grid) so results
  stay comparable across communities. Results are returned in a new
  `$communities` data.frame (`community`, `n_species`, `fd_obs`,
  `fd_expected`, `fd_sd`, `ses` -- Standardized Effect Size, `(fd_obs -
  fd_expected) / fd_sd` -- and `p_value`) and a new `$community_boot` list
  of the raw per-community bootstrap vectors, in addition to the unchanged
  whole-pool `fd_ref`/`fd_boot` outputs. `print()` now reports a
  per-community summary when present, and `plot()` gains a `type =
  c("pool", "communities")` argument: `"communities"` draws a dot ("forest")
  plot of `ses` per community, coloured by significance -- chosen over a
  per-community histogram grid (impractical for more than a handful of
  communities) or a raw obs-vs-expected scatter (not directly comparable
  across communities with different species richness, unlike `ses`).
  Species-column matching is defensive against a mismatch between
  `composition`'s column names and `groups`'s species labels: duplicated
  column names now error immediately (rather than silently using the
  first match), and unmatched columns are reported by name, not just by
  count, to make a spelling/case/whitespace mismatch easy to spot. Fixed
  a bug where a genuine `""` species label (e.g. an unresolved/
  unidentified specimen, as can occur in real field data) caused
  `composition[, matched_sp]` to fail with "subscript out of bounds" --
  `[`-indexing never matches a `""`-named column even when one exists
  (see `?Extract`); column selection now goes through `match()` instead
  (the same fix already used in `group_colors()`'s own `""`-label
  handling). `plot(type = "communities")` now always keeps `SES = 0` (the
  dashed reference line and every point's connecting segment) inside the
  plotted x-range, even when every community's `ses` sits far from 0
  relative to their own spread -- previously the x-axis limits were
  computed only from `range(ses)`, which could push 0 off-screen and
  silently truncate the reference line/segments at the plot edge.

* `impute_landmarks()` gains three statistical imputation methods
  alongside the existing geometric-morphometric `"tps"`/`"regression"`:
  `"impute_mean"`, `"impute_group_mean"`, and `"missforest"`, mirroring
  `trait_space()`'s `na_action` options but applied directly to raw
  landmark coordinates rather than derived traits. `"impute_mean"`
  replaces a missing coordinate with its column mean across all
  specimens; `"impute_group_mean"` uses the within-group mean instead
  (new `groups` argument, auto-detected from `landmarks$metadata$species`
  when available; falls back to the overall mean, with a warning, for a
  group entirely missing that coordinate); `"missforest"` uses
  `missForest::missForest()` across all landmark coordinates jointly, with
  `groups` as an optional auxiliary predictor (new `missforest_ntree`/
  `missforest_maxiter` arguments). These treat each coordinate as an
  ordinary numeric variable and ignore shape covariation, so
  `"tps"`/`"regression"` remain preferable whenever enough complete
  specimens are available; the statistical options are meant for
  exploratory use or when too few complete configurations remain for
  `geomorph::estimate.missing()` to work reliably.

* New function `phylo_pcoa()`: derives phylogenetic ordination axes from a
  tree (`ape::drop.tip()` + `ape::cophenetic.phylo()` + `ape::pcoa()`, with
  optional `phytools::force.ultrametric()` coercion and Cailliez/Lingoes
  negative-eigenvalue correction), returning a `species` + `PCoA1..k`
  `data.frame` deliberately shaped to be passed directly as `traits` to
  [trait_space()]. This lets a phylogenetic space be built with the exact
  same ordination/bootstrap machinery already used for morphological trait
  spaces ([bootstrap_functional_space()], [species_sensitivity()]), so
  functional and phylogenetic diversity loss can be compared using the same
  statistics. Deliberately scoped to the generic tree-to-axes step only:
  taxonomic name resolution, tree sourcing, and external trait/occurrence
  data assembly are considered out of scope and are left to the user's own
  data-preparation code. Adds `ape` and `phytools` to `Suggests`.

* New `na_action`/`method` option, `"missforest_phylo"`, added everywhere
  `"missforest"` was already available -- `trait_space()`,
  `fishmorph_segments()`, `fishmorph_ratios()`, and
  `impute_landmarks()` -- augmenting `missForest::missForest()`'s
  predictors with phylogenetic PCoA axes ([phylo_pcoa()]) computed from a
  `tree` (a user-supplied `ape::phylo` object, or, by default, the
  package's own newly bundled `load_fishmorph_phylogeny()` tree), matched
  to each row's `groups` (species) label. This lets imputation borrow
  information from phylogenetically related species, not just from
  correlations among traits/coordinates and the raw species factor, as in
  plain `"missforest"`. Matching is robust to whether species labels use a
  space, underscore, or dot as the genus/species separator (new internal
  `.canon_species_name()` helper), since the bundled tree's tip labels use
  the `"Genus.species"` convention. Phylogenetic augmentation is designed
  to never turn a working `"missforest"` call into a hard error: if no
  `groups`/`tree` is available, fewer than 3 species can be matched to the
  tree, or the `ape` package is missing, `"missforest_phylo"` falls back
  to plain `"missforest"` (no phylogenetic predictors) with an explanatory
  `warning()` rather than stopping. New shared arguments `tree` (default
  `NULL`, meaning "use the bundled phylogeny") and `missforest_phylo_k`
  (default `10`, the number of phylogenetic PCoA axes used as auxiliary
  predictors) added alongside the existing `missforest_ntree`/
  `missforest_maxiter`.

* New function `load_fishmorph_phylogeny()` and bundled data file
  `inst/extdata/Phylogeny/FishMORPH_Phylogeny.rds`: loads the package's
  default phylogenetic tree (an `ape::phylo` object, 10,705 tips) used as
  the default `tree` for `"missforest_phylo"` (above) and available
  directly as input to `phylo_pcoa()`. **Provenance note**: the exact
  source/citation of this tree has not been independently verified in
  this package's documentation; users relying on it for publication
  should confirm and cite its original source themselves (e.g. the
  phylogeny associated with the FISHMORPH trait database, Brosse et al.
  2021) rather than citing `?load_fishmorph_phylogeny`.

* `phylo_pcoa()` bug fix: species-name matching between `species`/`tree`
  only normalised spaces and underscores (`gsub(" ", "_", ...)`), so it
  silently failed to match any species against a tree using dot-separated
  tip labels (`"Genus.species"`), as the newly bundled
  `load_fishmorph_phylogeny()` tree does. Matching now goes through the
  same `.canon_species_name()` helper used by `"missforest_phylo"`
  (above), collapsing runs of spaces, dots, and underscores to a single
  underscore before comparison; matched species are consequently returned
  in this canonical underscore form.

* `correct_geometry()` bug fix: step 1's isotropic rescale to `[0, 1]` left
  an `intrait_landmarks` object's `$scale` element (real-world units per
  digitization pixel, see `read_tps()`) uncorrected, silently making
  `linear_distances()`/`morpho_ratios()` return wrong real-world distances
  from the rescaled coordinates afterwards (the visual, on-screen size of
  every specimen is intentionally equalized by this step, but each
  specimen's true, individual real-world size must still be recoverable
  downstream). `$scale` is now divided by the same per-specimen
  `scale_factor` applied to the coordinates, so real-world distances
  computed before and after `correct_geometry()` are now identical;
  `fishmorph_segments()` was never affected, since it always re-derives its
  own pixel-to-real-world factor fresh from the scale bar's current length
  rather than trusting a stored value. A new `message()` reports how many
  specimens' `$scale` was updated this way.

* `plot_fishmorph_points()`: the digitization scale bar (landmarks 20-21)
  is now drawn as a solid, filled bar with its own border (not two
  triangle point markers, nor a thin open line), placed lower down near
  the plot's origin, with its caption placed directly below it rather
  than above. The caption is now built automatically as `"1 <unit> =
  <length>"` (e.g. `"1 cm = 3.2"`), where `<length>` is that specimen's own
  digitized scale-bar length, rather than the previous fixed `"scale (1
  cm)"` text. The `scale_label` argument is replaced by `scale_unit`
  (default `"cm"`, matching the FISHMORPH protocol's standard 1 cm
  calibration segment), letting users specify the real-world unit a data
  set was actually digitized against (e.g. `"mm"`, `"dm"`, `"m"`, or any
  other label); set `scale_unit = NULL` to omit the caption entirely (the
  bar itself is still drawn). This is a breaking change for any code
  calling `plot_fishmorph_points(..., scale_label = ...)`.

* New `plot_correlation_circle()`: draws the classical correlation circle
  (variable factor map) of a `trait_space()` ordination -- each trait as
  an arrow to its Pearson correlation with the two plotted axes, inside a
  unit circle, with an optional inner circle at radius `sqrt(0.5)`
  marking the conventional "well represented" threshold. Unlike a plot of
  raw `loadings`, arrow length is directly comparable across traits and
  meaningful regardless of `method` (`"pca"`/`"pcoa"`) or `scale`. Drawn
  without a surrounding box: tick values run along the `y = 0`/`x = 0`
  reference lines through the origin, each labelled with its axis name
  only (e.g. `"PC1"`), in a small italic font, just outside the circle
  and centred on its own reference line.

* `bootstrap_functional_space()` gains a `method` argument for the
  functional-richness measure computed in the PCA-based trait space:
  `"convexhull"` (default, unchanged behaviour: n-dimensional convex-hull
  volume via `geometry::convhulln()`), `"dendrogram"` (total branch
  length of a UPGMA functional dendrogram, Petchey & Gaston 2002 -- needs
  no extra Suggested package), `"tpd"` (Trait Probability Density
  richness via the `TPD` package, Carmona et al. 2019), and
  `"hypervolume"` (Gaussian-kernel hypervolume via the `hypervolume`
  package, Blonder et al. 2014, 2018). For `"tpd"`/`"hypervolume"`, the
  kernel bandwidth (and, for `"tpd"`, the evaluation grid) is computed
  once from the full individual-level data and reused, unchanged, for the
  centroid-based reference and every bootstrap draw, so richness values
  stay comparable across draws; new `dendrogram_linkage`, `tpd_alpha`,
  `tpd_bw_factor`, `tpd_n_divisions`, `hv_bw_method`,
  `hv_samples_per_point` arguments tune these. `TPD` and `hypervolume`
  are new Suggested dependencies, only required when their respective
  `method` is used. `print()`/`plot()` methods for
  `"intrait_bootstrap_fspace"` now report which `method` was used.
  `plot.intrait_bootstrap_fspace()` also drops the previous FD_ref
  text annotation above the histogram in favour of marking `fd_ref` (red)
  and the bootstrap mean `fd_boot_mean` (blue) directly on the x-axis,
  each with a matching dashed vertical line.

* `species_sensitivity()` gains the same `method` argument (and matching
  `dendrogram_linkage`/`tpd_*`/`hv_*` tuning arguments) as
  `bootstrap_functional_space()`, for computing the species-level
  sensitivity index with `"convexhull"` (default), `"dendrogram"`,
  `"tpd"`, or `"hypervolume"` functional richness instead of only
  convex-hull volume. `print()`/`plot()` methods report which `method`
  was used.

* New `compare_functional_richness()`: runs `bootstrap_functional_space()`
  once per requested `method` (`"convexhull"`, `"dendrogram"`, `"tpd"`,
  `"hypervolume"`; all four by default) on the same data and tabulates the
  results side by side (`fd_ref`, `fd_boot_mean`, `pct_diff`, `p_value`,
  `significant`), for methodological triangulation across richness
  measures. A method whose package is missing, or that otherwise errors,
  is recorded as a skipped row rather than failing the whole comparison.
  Optional `seed` argument pairs the bootstrap draws across methods. Has
  dedicated `print()` (summary table + agreement count) and `plot()`
  (dot-and-whisker comparison, one row per method) methods.

* Fixed group/species colours not staying consistent between
  `plot.intrait_shapespace()` and `plot.intrait_traitspace()` built from
  the same dataset: colours were previously derived from each call's own
  `nlevels(groups)`/position within its *observed* factor levels, so the
  same species could get a different colour whenever the two objects
  happened to retain a different subset of species after their own
  upstream missing-data or outlier filtering. Colours are now looked up
  by label from a session-persistent cache, so a given species always
  gets the same colour once assigned, regardless of which other species
  are present in a later call. New `reset_group_colors()` clears this
  cache (e.g. before an unrelated dataset, or for full reproducibility
  irrespective of call history).

* New `plot_fishmorph_shapes()`: overlays the landmark points and body
  outline (the same FISHMORPH outline path used by
  `plot_fishmorph_points()`) of every specimen in a given species, or of
  an explicit vector of individuals, on a single figure -- no landmark
  numbers, measurement segments, eye, or internal reference lines -- for
  a fast visual read of shape variability across many specimens at once.
  By default (`align = TRUE`) each specimen is independently centred on
  its own centroid and rescaled to unit centroid size (translation and
  scale only, no rotation) before being drawn, so the overlay compares
  shape rather than raw digitization position/size; set `align = FALSE`
  for already-comparable coordinates (e.g. `gpa_fish()` output). Axis
  tick labels use `grDevices::axisTicks()` (the same "round numbers"
  computation behind R's own default axes) rather than evenly spaced raw
  fractions of the data range, since that range is data-driven here and
  generally not already round -- unlike `plot_fishmorph_points()`'s fixed
  `[0, 1]` convention, whose quarter increments are round by construction.

* Fixed a crash ("attempt to use zero-length variable name") in
  `plot.intrait_shapespace()`/`plot.intrait_traitspace()` whenever a
  group level was an empty string `""` (e.g. an unresolved species
  identification stored as `""` rather than `NA` in the source data): the
  session-level colour cache previously stored one colour per group by
  `assign()`ing an environment variable named after the raw label, which
  errors on `""`. Colours are now stored in a single named vector instead,
  which has no such restriction; `""` is now treated like any other
  distinct label.

* Fixed a follow-on bug from the `""`-label fix above: the colour cache's
  own lookup, `cache[uniq]`, relied on `[`'s character-name matching,
  which R documents as never matching a `""` index to a `""` name even
  when that name is genuinely present (`?Extract`: "Neither empty ('')
  nor NA indices match any names, not even empty nor missing names.").
  A `""`-labelled group was therefore still assigned `NA` instead of its
  cached colour on lookup, even though storage worked correctly. Lookup
  now uses `match()`, which has no such exception.

* New `group_colors()`: returns the exact group/species colours
  `plot.intrait_shapespace()`/`plot.intrait_traitspace()` use (or would
  use), as a `group`/`color` `data.frame`, in the same order as their own
  legend -- for building a single shared legend across several panels
  (e.g. `par(mfrow = c(2, 2))`, each plotted with `legend = FALSE`)
  without reimplementing or guessing at the underlying colour
  assignment. Accepts either an object with a `$groups` element (e.g.
  `shape_space()`/`trait_space()` output) or a raw label vector.

* Fixed a bug in `group_colors()` where passing a list without a
  `$groups` element (anything other than the intended
  `shape_space()`/`trait_space()` output or a raw label vector) silently
  used the list itself as if it were the label vector instead of raising
  the documented "no `groups` element" error.

# intraitR 1.0.0

First stable release. Functionally identical to 0.13.0, promoted to
1.0.0 after the first real (non-static) validation of the package: the
maintainer ran `devtools::test()` on an actual R installation for the
first time in this project's history (every prior version was validated
only by manual code reading, independent Python reimplementation of the
statistical logic, and static analysis, for lack of an R interpreter in
the authoring environment).

Result: **465 tests passed, 0 failures**, 5 expected warnings, and 6
expected skips (all environment-dependent negative-path tests, e.g.
"package already installed, cannot test the missing-package error" or
"cannot run the interactive digitizer non-interactively"). Only one
issue surfaced, and it was in a test, not in the package:

* **Fixed `test-trait_disparity.R`'s regression test** for the
  exactly-2-groups permutation reshape fix (see 0.13.0 below). `%in%`
  binds *tighter* than `/` in R's operator precedence (`?Syntax`), so
  `x %in% ((0:5) + 1) / 6` parsed as `(x %in% ((0:5) + 1)) / 6` instead
  of the intended `x %in% (((0:5) + 1) / 6)` — silently turning the
  assertion into `FALSE / 6 = 0`, which then failed `expect_true()`
  regardless of whether `trait_disparity()` itself was correct. Fixed by
  parenthesising the denominator explicitly. `trait_disparity()`'s own
  logic was not at fault: its other tests, including a real statistical
  power check, already passed under this same test run.

No changes to any exported function's behaviour, arguments, or return
values relative to 0.13.0.

# intraitR 0.13.0

* **`background_image` overlay** for `plot_landmarks()` and
  `plot_fishmorph_points()` (closing the long-pending image-overlay task).
  Both functions gain `background_image` (a path to a `.jpg`/`.jpeg` or
  `.png` photograph of the specimen) and `flip_y` (default `TRUE`)
  arguments: the photograph is drawn as a background layer, sized to its
  full pixel extent, with the digitized landmarks plotted on top, for
  visual quality control (e.g. spotting a landmark placed off the body
  outline). Requires the `jpeg` package for `.jpg`/`.jpeg` files or `png`
  for `.png` files (both newly Suggested, neither installed by default);
  a clear error is raised if the relevant package is missing. `tools`
  (for `tools::file_ext()`, dispatching on the file extension) is now
  declared in `DESCRIPTION`'s `Imports`. Only
  meaningful for the original, un-aligned digitized coordinates: a
  warning is issued if `background_image` is combined with an
  `"intrait_gpa"` (Procrustes-aligned) object, since the photograph will
  not line up with aligned coordinates. New internal helpers
  `.read_background_image()`, `.draw_background_image()`, and
  `.background_image_dims()` in `R/utils-internal.R`.
* **Parallelization**: `bootstrap_functional_space()`,
  `species_sensitivity()`, and `trait_disparity()` now distribute their
  independent resampling loops (bootstrap draws, per-individual
  sensitivity replacements, and label permutations, respectively) across
  worker processes via the (Suggested) `future.apply` package, through a
  new internal `.papply()` helper that falls back to a plain `vapply()`
  when `future.apply` is not installed or no `future::plan()` has been
  set — i.e. purely opt-in, with identical results either way (reproducible
  across workers via `future.seed = TRUE`, L'Ecuyer-CMRG streams). See the
  new "Performance on large data sets" section of the README for details,
  including a note on convex-hull complexity in higher dimensions
  (McMullen, 1970). While refactoring `trait_disparity()`'s permutation
  loop, fixed a latent shape bug where reshaping the loop's output with
  `t()` would have silently corrupted p-values for the common
  exactly-two-groups case (a plain vector, not a matrix, is returned by
  `vapply()`/`future_vapply()` when `FUN.VALUE` has length 1, and `t()` of
  a vector produces a `1 x n` matrix, not `n x 1`); replaced with an
  explicit `matrix(..., byrow = TRUE)` reshape that handles both cases
  correctly, with a new regression test.
* **CRAN-readiness audit**: added missing `@return`/`\value` documentation
  to 17 exported `print()`/`plot()`/`summary()` methods that lacked one
  (an `R CMD check --as-cran` NOTE), spanning
  `bootstrap_functional_space()`, `detect_outliers()`,
  `digitization_error()`, `gpa_fish()`, `intraspecific_variability()`,
  `itv_index()`, `measurement_error()`, `shape_space()`, `read_tps()`,
  `species_sensitivity()`, `trait_disparity()`, and `trait_space()`.
  Fixed `plot.intrait_digitization_error()`, which — unlike every other
  `plot()` method in the package — did not explicitly return
  `invisible(x)`.
* **Infrastructure**: added a `pkgdown` site configuration
  (`_pkgdown.yml`, with a thematic reference index) and two new GitHub
  Actions workflows, `pkgdown.yaml` (builds and deploys the site to
  `gh-pages` on pushes to the default branch) and `test-coverage.yaml`
  (runs `covr::package_coverage()` and uploads results to Codecov;
  requires a `CODECOV_TOKEN` repository secret to actually upload).
  Status badges added to `README.md`.

# intraitR 0.12.0

* **`species_sensitivity()`** (new function). Implements the
  "species-level sensitivity index" of Bertrand (2026): for each species,
  its centroid (in the same `n_axes`-dimensional PCA space as
  `bootstrap_functional_space()`) is replaced, one individual at a time,
  by that individual's own position, with every other species held fixed
  at its centroid; each replacement's convex-hull volume is expressed as
  a percent change relative to the unmodified centroid-based reference
  (`fd_ref`). Per species, this yields a mean effect (`mean_dFD`, `mu_k`
  in Bertrand, 2026) and a min-max range, exposed both as a `summary`
  table and a full `individual`-level long table. Unlike
  `bootstrap_functional_space()`, this index is exact and deterministic
  (no resampling, no significance test): every replacement is a single,
  reproducible recomputation. Has `print()` (top species by
  `|mean_dFD|`, 12 by default, matching Bertrand, 2026's figure) and
  `plot()` (dot-and-range plot reproducing the report's Fig. 7 style,
  species names italicised and abbreviated by default) methods.
  Demonstrated in `demo(pipeline_T26_saudrune)`, Section 11. Requires the
  `geometry` package, as `bootstrap_functional_space()` does.
* **Internal refactor**: the `x`/`groups` resolution, preprocessing, PCA,
  and `n_axes` selection logic shared by `bootstrap_functional_space()`
  and the new `species_sensitivity()` was extracted into a single internal
  helper, `.fspace_pca_scores()` (`R/utils-internal.R`), together with
  `.group_centroids()`; `bootstrap_functional_space()`'s own behaviour and
  error messages are unchanged (verified by re-reading the refactored code
  path line by line, since this package still cannot be executed in this
  environment -- see below).

# intraitR 0.11.1

* Fixed `devtools::document()` warnings surfaced by the user immediately
  after 0.11.0: several `@noRd` (internal, undocumented-on-purpose)
  helpers in `R/utils-internal.R` -- `.plot_ordination()`,
  `.covariance_ellipse()`, `.kde2d()`, `.abbreviate_species_name()` -- were
  cross-referenced using markdown link syntax (e.g. `` [.kde2d()] ``),
  which roxygen2 can never resolve for a function with no generated `.Rd`
  page, producing a permanent "Could not resolve link to topic" warning on
  every `document()` run. Replaced with plain code-formatted text (e.g.
  `` `.kde2d()` ``), which was always the intent (pointing a reader at the
  helper's name, not producing a clickable cross-reference that cannot
  exist). The one warning that will *not* recur (`bootstrap_functional_space`
  in `.convex_hull_volume()`'s doc) was, per roxygen2's own message, a
  transient first-run artifact: that link target is a normal, exported,
  documented function and resolves correctly starting on the next
  `document()` call. No code behaviour changed.

# intraitR 0.11.0

* **`bootstrap_functional_space()`** (new function). Implements the
  "bootstrap-based functional space estimate" of Bertrand (2026, M2
  internship report supervised by A. Toussaint and S. Brosse): for
  `n_boot` bootstrap "communities", one individual is drawn at random per
  species and the n-dimensional convex-hull volume (functional richness)
  of these points is computed (`fd_boot`), and compared to a
  centroid-based reference volume (`fd_ref`, each species replaced by its
  mean position). A fresh PCA is performed internally (on as many axes as
  needed to reach a variance threshold, or a user-specified `n_axes`;
  Bertrand, 2026, used 8 axes for 98% of variance), and convex-hull
  volumes are computed with `geometry::convhulln()` (new Suggested
  dependency, gated with the same `requireNamespace()` pattern as
  `missForest` for `trait_space(na_action = "missforest")`). Reports a
  one-sided significance test of whether `fd_ref` sits unusually low
  relative to the bootstrap distribution. The source report describes a
  "one-sided permutation test" without fully specifying its scheme; a
  label-permutation design (reassigning species labels to individuals, as
  in `trait_disparity()`) was implemented and then simulation-tested
  before being rejected: it collapses every permuted centroid toward the
  global mean while permuted single-individual draws keep the data's full
  spread, so the resulting null was found to be uninformative regardless
  of whether real intraspecific variability is present, which does not
  match Bertrand (2026)'s reported result. The shipped implementation
  instead uses the bootstrap distribution itself as the null (a standard
  bootstrap percentile p-value), verified by simulation to correctly stay
  non-significant when intraspecific variability is negligible and to
  detect a strong, real effect when it is not (see `?bootstrap_functional_space`
  for the full reasoning). Has `print()` and `plot()` methods; demonstrated
  in `demo(pipeline_T26_saudrune)`, Section 10.
* **Ordination plot improvements** (`plot.intrait_traitspace()`,
  `plot.intrait_shapespace()`, via the shared internal
  `.plot_ordination()`): new `legend_title`, `legend_italic`, and
  `abbreviate_species` arguments (e.g. `legend_title = "Species",
  legend_italic = TRUE, abbreviate_species = TRUE` renders
  `"Barbatula barbatula"` as italic *B. barbatula* in the legend, used
  throughout `demo(pipeline_T26_saudrune)` and the vignette); axis ticks
  are now short and point inward (`par(tcl = 0.3)`); the qualitative
  colour palette was replaced with a higher-contrast, curated 10-colour
  set (falling back to `hcl.colors()` beyond 10 groups); and axis limits
  are now computed from the group ellipses/hulls/density contours in
  addition to the raw points, so this geometry is never clipped at the
  plot box edge (previously possible whenever a group's dispersion
  ellipse extended beyond its own points, which is the rule rather than
  the exception). Unused factor levels in `groups` are now dropped
  defensively before colouring/legending.

# intraitR 0.10.1

* **`species` argument** added to `load_t26_saudrune()`. The
  `"operators"`/`"repeatability"` landmark tables are keyed by `code` only
  (species identity lives in the separate `"identifications"` table by
  design: a landmark measurement does not need a species, and
  identifications can be revised independently of the coordinates), so
  `species` was never a column of those two tables and its absence is not
  a regression. `species = TRUE` restores convenient access by left-joining
  `species`/`id_status` from `"identifications"` via `code`. Implemented
  with a vectorised `match()` lookup (new internal helper `.join_species()`
  in `R/utils-internal.R`), not `merge()`, specifically because the
  long-format tables have many rows sharing the same `code` (one per
  landmark, and per operator/replicate): `match()` preserves the original
  row order by construction, removing any need to verify a duplicate-key
  join's ordering behaviour. Modular by design, matching the existing
  `operator` argument's convention: a no-op (with a warning) if `dataset`
  has no `code` column, and a harmless no-op on `"identifications"` itself.

# intraitR 0.10.0

* **Operator anonymisation (T-26 Saudrune data).** The `operator` column
  and `specimen` identifiers of `load_t26_saudrune("operators")` /
  `load_t26_saudrune("repeatability")` no longer contain the real names of
  the two field digitizers; they are replaced with anonymous labels
  (`"Operator_1"`, `"Operator_2"`), consistently across both tables
  (matched case-insensitively against the original spreadsheets, where the
  same person was recorded with different capitalisation in each). Operator
  identity is not itself a biological variable of interest, so nothing
  about the package's statistical results changes. `data-raw/t26_saudrune_prepare.R`
  documents the anonymisation step for full provenance. Note: this fixes
  the *shipped data*; if the package's git history has ever been pushed
  publicly with an earlier version of these files, the real names may
  still be recoverable from that history, which is outside what this
  in-place data fix can address (git history rewriting is a separate,
  deliberate operation the maintainer should consider if that applies).
* **`operator` argument** added to `load_t26_saudrune()` and
  `load_t26_saudrune_landmarks()`, restricting the returned rows/specimens
  to one or more (anonymous) operators. This is the natural way to build
  **two separate functional trait spaces**, one per operator, to check
  whether downstream results (e.g. `trait_space()`, `fishmorph_ratios()`)
  are sensitive to who did the digitizing. Modular by design: on a table
  with no `operator` column, `operator` is ignored with a warning and all
  rows are returned, rather than raising an error.
* **`style = "density"`** added to `plot.intrait_traitspace()` and
  `plot.intrait_shapespace()`: a non-parametric kernel-density contour
  (highest-density-region construction, Hyndman 1996) per group, as an
  alternative to the parametric bivariate-normal "spider" ellipse — useful
  when a group's points are visibly skewed or multimodal (as can happen
  with real digitization data). Implemented with a small, dependency-free
  bivariate Gaussian kernel density estimator (the same formula underlying
  `MASS::kde2d()`), so no new package dependency is introduced.
* **Legend placement overhauled.** `plot.intrait_traitspace()`,
  `plot.intrait_shapespace()`, `plot.intrait_itv()`, and
  `plot_fishmorph_points()` all gained a `legend_position` argument,
  defaulting to `"outside"`: the group/measurement legend is now drawn
  just outside the plot box (in the margin) by default, so it no longer
  risks overlapping data points or bars, whatever corner they happen to
  cluster in. Any standard `graphics::legend()` position keyword (e.g.
  `"topright"`) can still be passed to recover the previous, inside-the-box
  placement.

# intraitR 0.9.4

* Completed the 0.9.3 fix, which was itself incomplete. 0.9.3 added the
  correct inner assignment (`expect_message(x <- f(...), regexp)`) to the
  three regression tests but left the pre-existing *outer* assignment in
  place as well (`x <- expect_message(x <- f(...), regexp)`); the outer
  assignment executes after the quosure and unconditionally overwrites `x`
  with `expect_message()`'s own return value, silently discarding the
  correct one just captured by the inner assignment. This reproduced
  exactly the same failures as 0.9.2, which is why re-running
  `devtools::test()` after 0.9.3 still failed identically. The outer
  assignment has now been removed from `test-trait_space.R`,
  `test-itv_index.R`, and `test-trait_disparity.R`, matching the pattern
  already used correctly elsewhere in the same test files (e.g.
  `test-trait_space.R`'s `na_action = "omit"` tests). `trait_space()`,
  `itv_index()`, and `trait_disparity()` themselves are unchanged. As
  before, this development environment has no R installation available to
  verify with an actual `devtools::test()` run; please re-run locally to
  confirm.

# intraitR 0.9.3

* Fixed three regression tests (`test-trait_space.R`, `test-itv_index.R`,
  `test-trait_disparity.R`, all added in 0.9.0 for the NA/unresolved-`groups`
  fix) that used the pattern `x <- expect_message(f(...), regexp)`, which
  does not reliably capture `f()`'s return value in testthat (it can return
  the captured message condition instead). Corrected to the idiom already
  used elsewhere in the suite, `expect_message(x <- f(...), regexp)`
  (assignment *inside* the call). This was a test-only defect: confirmed by
  running `devtools::test()` under a real R installation for the first time
  (previous validation in this development environment relied on static
  code review and an independent Python re-implementation, R itself not
  being available); the underlying `trait_space()`/`itv_index()`/
  `trait_disparity()` NA-handling logic added in 0.9.0 was unaffected and
  is unchanged here; only the three test files were edited. This
  development environment still has no R installation available to the
  assistant, so this fix (like all preceding R code in this package) has
  been verified by careful manual trace of the R semantics involved, not
  by re-running `devtools::test()` directly; please re-run the full suite
  locally to confirm before relying on it.

# intraitR 0.9.2

* Added an `exclude_landmarks` argument to `digitization_error()`, allowing
  one or more landmark indices to be dropped from the per-landmark bias
  decomposition (`landmark_individual`, `by_landmark`, and all downstream
  aggregates). This is intended for landmarks that are not homologous
  biological points and so are not meaningfully comparable to the others
  in a landmark-by-landmark decomposition — most notably the embedded
  scale-bar calibration points (landmarks 20-21) of the FISHMORPH
  digitization scheme, which encode a fixed 1 cm real-world distance
  rather than a body landmark. `demo/pipeline_T26_saudrune.R` and the
  manuscript's real-data validation (Section 4.5) now call
  `digitization_error(..., exclude_landmarks = c(20, 21))` on the T-26
  repeatability trial accordingly; the resulting community-level bias
  estimate (now computed over the 19 anatomical landmarks only) and the
  ranking of least/most precise landmarks are both revised in the
  manuscript relative to 0.9.1, where the scale bar's placement was
  incorrectly pooled with genuine anatomical landmark bias.

# intraitR 0.9.1

* Added `load_t26_saudrune_landmarks()`, which loads the real T-26 Saudrune
  data (see 0.9.0, below) directly as an object of class
  `"intrait_landmarks"`, in exactly the same format returned by
  `simulate_fishmorph_points()` (`coords`, `scale = NULL`, and a `metadata`
  data.frame with `specimen`, `individual`, `species`, `population`,
  `replicate`). This makes the real data set a drop-in replacement for the
  simulated one, and the runnable `@examples` of `fishmorph_segments()`,
  `fishmorph_ratios()`, `trait_space()`, `itv_index()`, `trait_disparity()`,
  and `plot_fishmorph_points()` now use it instead of
  `simulate_fishmorph_points()`. `simulate_fishmorph_points()` itself is
  unchanged and remains available for teaching, testing, and the one
  demonstration (nested population structure in `itv_index()`) that the
  real, single-site T-26 survey cannot illustrate honestly.

# intraitR 0.9.0

* Added the package's first **real** (non-simulated) data set: `T26_Saudrune`,
  a 279-fish landmark data set from an electric-fishing survey of the
  Saudrune (Adour-Garonne basin, France, 21 April 2026), covering 8
  freshwater fish species (dominated by *Gobio occitaniae* and *Squalius
  cephalus*), digitized on the 21-landmark FISHMORPH scheme by two
  independent operators, plus a dedicated intra-operator repeatability
  trial (25 individuals x 9-10 replicate digitizations). Accessible via
  the new `load_t26_saudrune()` function (`?load_t26_saudrune`); raw
  spreadsheets and photographs are not distributed with the package, only
  the cleaned, analysis-ready tables (see `data-raw/t26_saudrune_prepare.R`
  for the full, transparent cleaning/QC pipeline, including every excluded
  specimen and why).
* Added `demo/pipeline_T26_saudrune.R` (`demo("pipeline_T26_saudrune")`), a
  complete worked pipeline running every stage of the intraitR workflow on
  this real data set: import, Generalised Procrustes Analysis, digitization
  quality control (including a worked illustration of why `detect_outliers()`
  should be run within, not across, taxonomically distinct species),
  FISHMORPH linear measurements and ratios, functional trait space,
  `itv_index()`, `measurement_error()`, `digitization_error()`, and
  `trait_disparity()`.
* Species identifications in `T26_Saudrune` are exposed with an explicit
  `id_status` field (`"curated"`, `"preliminary"`, or `"unresolved"`),
  since a small number of AI-vision-assisted calls have not yet been
  manually audited; per the data owner's instruction, this release does
  not attempt to resolve or correct them.
* **Bug fix**, found precisely because of the above: `trait_space()`,
  `itv_index()`, and `trait_disparity()` previously mishandled a `groups`
  vector containing `NA` (e.g. a specimen with an unresolved
  identification but otherwise-complete trait values, as in
  `T26_Saudrune`). In `trait_disparity()` this was a real correctness bug,
  not just an edge case: `Xmat[g == lv, ]` with an `NA` entry in `g`
  inserts an `NA`-valued row into the subset for *every* group level
  (since `NA == lv` is `NA`, not `FALSE`), turning every group's
  dispersion into `NA`. `itv_index()`/`trait_space()` instead silently
  treated the `NA` label as its own size-1 pseudo-group. All three
  functions now drop rows with a missing/unresolved `groups` value up
  front, with an explicit `message()`.

# intraitR 0.8.0

* Added `digitization_error()`, a new function quantifying hierarchical
  digitization (operator) error from repeated landmark placement,
  implementing the protocol developed by L. Boutic (2026, unpublished
  internship report, CRBE / INTRAIT project, supervised by A. Toussaint)
  to quantify operator bias in freshwater fish landmark digitization from
  French Guiana. For each landmark and individual, the dispersion of
  repeated digitizations around their consensus position is normalised by
  a reference distance (by default, the mean inter-landmark distance
  between two anchor landmarks per species, exactly as in the original
  protocol; `standard_length_mm` and centroid size are also available as
  alternative, individual-level normalizations, the latter addressing a
  methodological improvement suggested in the original report's
  discussion) and aggregated hierarchically from landmark to individual,
  species, and overall community bias. Includes `print()` and `plot()`
  methods (the latter reproducing the report's by-landmark boxplot,
  ordered by increasing median bias). This complements the existing
  `measurement_error()` (Bailey & Byrnes, 1990 / Procrustes ANOVA
  approach): `digitization_error()` is deliberately GPA-free and
  landmark-by-landmark, to directly flag which specific landmarks need a
  stricter operational definition, whereas `measurement_error()` gives an
  overall, rotation/scale-invariant repeatability estimate.

# intraitR 0.7.5

* Fixed stale package-level help (`man/intraitR-package.Rd`, `?intraitR`):
  its "Useful links" section still hard-coded the old
  `aureletoussaint/intraitR` URLs, because this file is generated by
  roxygen2 from `DESCRIPTION`'s `URL`/`BugReports` fields and had not
  been regenerated since those fields were updated to
  `FunTraits/intraitR` in 0.7.3. Fixed directly in the generated `.Rd`
  file; running `devtools::document()` again will now also regenerate it
  correctly from the (already-correct) `DESCRIPTION`.

# intraitR 0.7.4

* Fixed a real `R CMD check` WARNING found by the maintainer:
  `demo/00Index` separated the demo name and description with two
  spaces, but "Writing R Extensions" requires a tab or at least three
  spaces, which was silently treated as missing/empty index information.
* Fixed a real `R CMD check` NOTE ("Non-standard files/directories found
  at top level"): `GITHUB_SETUP.md` and the leftover local testing
  artefacts `specimens.tps`/`P5180033.jpg` are now excluded from the
  built package via `.Rbuildignore` (they were already excluded from git
  via `.gitignore`, which does not affect `R CMD build`/`check`).
* The remaining NOTE ("checking for future file timestamps ... unable to
  verify current time") is not a package issue: it means the checking
  machine could not reach a time-verification service over the network,
  and is unrelated to any file in this package.

# intraitR 0.7.3

* Repository moved to https://github.com/FunTraits/intraitR; `URL`,
  `BugReports` (`DESCRIPTION`), `inst/CITATION`, and the
  `remotes::install_github()` example in `README.md` updated
  accordingly.
* Added a standard GitHub Actions `R CMD check` workflow
  (`.github/workflows/R-CMD-check.yaml`, Linux release/devel/oldrel,
  macOS, Windows).
* `.gitignore` extended to exclude `.DS_Store` and two local testing
  artefacts that are not part of the package source.

# intraitR 0.7.2

* Test suite only: two `test-itv_index.R` failures reported by
  `devtools::test()` were bugs in the tests, not in `itv_index()` itself.
  (1) Hand-computed-precision tests compared unrounded expected values
  against `itv_index()`'s default `digits = 4`-rounded percentages with a
  tolerance too tight for that rounding (rounding a small percentage
  shifts its *relative* difference far more than a large one) — fixed by
  passing `digits = 12` in those tests. (2) A FISHMORPH test called
  `nlevels()` directly on `fish$metadata$species`, a plain character
  vector rather than a factor, which always returns 0 — fixed by wrapping
  it in `factor()` first. `itv_index()`'s own code was unaffected by
  either issue.

# intraitR 0.7.1

* Bug fix: `itv_index(nested = ...)` incorrectly errored ("Each level of
  `nested` must belong to a single level of `groups`") whenever
  population labels were reused identically across species — which is
  exactly what `simulate_fishmorph_points()`/`simulate_fish_landmarks()`
  do (`population` is `"Pop_1"`/`"Pop_2"` for every species), and is
  common in real data too. Found by the maintainer running the
  `itv_nested` vignette/help example verbatim. Fixed: `nested` levels no
  longer need to be globally unique; each *combination* of `groups` and
  `nested` is now automatically treated as a distinct population (via
  `interaction(groups, nested)`), exactly as the nesting operator in
  `aov(y ~ Error(groups/nested))` would handle it. The strict "must
  belong to a single group" validation and its error were removed as no
  longer necessary.

# intraitR 0.7.0

* New function `itv_index()`: decomposes total trait variance into an
  interspecific (between-group, e.g. between-species) component and an
  intraspecific trait variability (ITV) component, following the
  variance-partitioning approach of Violle et al. (2012) and de Bello et
  al. (2011) (`%ITV = 100 x SS_within / SS_total`). Accepts an optional
  `nested` grouping factor (e.g. population within species) to further
  split the ITV component into between-population and within-population
  (residual) parts, following the within-/among-population distinction
  used in ITV meta-analyses (Siefert et al., 2015); this nested
  decomposition is exact for any design, including unbalanced group and
  population sizes. Returns both a per-trait breakdown and a multivariate
  summary aggregated across (optionally standardised) traits, with
  dedicated print and stacked-bar-chart plot methods.

# intraitR 0.6.1

* New demo, `demo("na_handling", package = "intraitR")`: simulates a
  FISHMORPH data set, deletes a known set of trait values, and compares
  `"impute_mean"`, `"impute_group_mean"`, and `"missforest"` by RMSE
  against the true (deleted) values, alongside `"omit"` and the default
  `"fail"` behaviour of `trait_space()`.

# intraitR 0.6.0

* `trait_space()` gains `na_action = "missforest"`: nonparametric
  random-forest imputation of missing trait values via
  `missForest::missForest()` (Stekhoven & Bühlmann, 2012), using `groups`
  (when supplied) as an auxiliary predictor. Unlike `"impute_mean"`/
  `"impute_group_mean"`, this exploits correlations among traits and is
  generally preferable once more than a few values are missing. Reports
  the number of values imputed and the out-of-bag normalised RMSE via
  `message()`. Requires the (new, `Suggests`-only) `missForest` package;
  results are stochastic unless `set.seed()` is called beforehand. New
  arguments `missforest_ntree` (default `100`) and `missforest_maxiter`
  (default `10`) control the underlying random forests.

# intraitR 0.5.1

* Bug fix: `digitize_landmarks()` called `geomorph::digitize2d()` with an
  incorrect argument name (`image.list`, which does not exist in
  `geomorph`) instead of the actual argument name, `filelist`, causing an
  immediate "unused argument" error on every call. Found by the
  maintainer testing against a real photograph. Fixed by using
  `filelist`, and the `...` documentation corrected from a non-existent
  `MultCurvatures` argument to the real `scale`/`MultScale`/`verbose`
  arguments of `geomorph::digitize2d()`.

# intraitR 0.5.0

* New function `digitize_landmarks()`: a convenience wrapper around
  `geomorph::digitize2d()` for point-and-click digitization of landmarks
  directly from specimen photographs, following either the fixed
  21/22-point FISHMORPH scheme (`scheme = "fishmorph"`) or a
  user-specified number of generic landmarks (`scheme = "generic"`).
  Digitized coordinates are written to a `tpsDig` file and immediately
  re-read with `read_tps()`, so the result is a ready-to-use
  `"intrait_landmarks"` object. Requires an interactive graphics device;
  stops with an informative error rather than hanging when called
  non-interactively (e.g. in scripts, knitted vignettes, or automated
  tests).

# intraitR 0.4.0

* New function `trait_disparity()`: tests whether groups (e.g. species)
  differ in the multivariate dispersion of their functional traits, using
  a permutation test on trait variance (the trace of the group's trait
  covariance matrix), computed on the full standardised trait matrix built
  by `trait_space()` (i.e. not truncated to the two plotting axes). This
  complements `intraspecific_variability()`, which reports shape disparity
  and univariate coefficients of variation but does not test for group
  differences in multivariate trait dispersion. Accepts either an
  `"intrait_traitspace"` object or a raw trait table with `groups`.
* `trait_space()` now returns an additional (previously internal) element
  `X`, the standardised trait matrix actually analysed (post
  log-transformation and removal of constant columns, centred/scaled as
  requested), used by `trait_disparity()`. This is an additive change and
  does not affect any existing use of `trait_space()`'s output.
* `trait_space()` gains an `na_action` argument (`"fail"` (default,
  unchanged behaviour), `"omit"`, `"impute_mean"`, or
  `"impute_group_mean"`) for handling missing values in the numeric trait
  columns, instead of always erroring. `"omit"` and both imputation modes
  report, via `message()`, how many rows were dropped or values imputed,
  so the operation is never silent.
* New function `detect_outliers()`: a quality-control screen for
  landmark digitization errors, flagging specimens whose Procrustes
  distance to the sample consensus shape exceeds a robust (median +
  `threshold` x MAD) cut-off, in the spirit of
  `geomorph::plotOutliers()`. Includes a diagnostic plot and a ranked
  table of the most atypical specimens.

# intraitR 0.3.0

* `trait_space()` gains a `log_transform` argument (default `TRUE`):
  numeric traits are `log10(x + 1)`-transformed before centring/scaling
  and ordination, standard practice for ratio-type functional traits that
  are bounded at zero and often right-skewed (the `+ 1` accommodates
  traits that legitimately equal 0 under the Villéger et al., 2010,
  exception rules implemented in `fishmorph_ratios()`). Set
  `log_transform = FALSE` to disable. This does not apply to, and is not
  used by, `shape_space()`, which ordinates Procrustes shape coordinates
  rather than trait ratios.
* `plot.intrait_shapespace()` and `plot.intrait_traitspace()` gain a
  `style` argument (`"spider"`, `"hull"`, or `"none"`), replacing the
  previous `convex_hull` logical. The new default, `style = "spider"`,
  displays each group as its individual points, dashed segments linking
  every point to its group mean, the group mean itself, and a
  `ellipse_level` (default 95%) dispersion ellipse under a
  bivariate-normal approximation — the classical "spider"/"star" plot
  used to depict group structure in ordination diagrams. `style = "hull"`
  reproduces the previous convex-hull display.

# intraitR 0.2.2

* `trait_space()`'s "fewer than two numeric columns" error message now
  reads "... at least two numeric columns after removing constant
  (zero-variance) columns." (kept the original wording intact so
  downstream code/tests matching on "at least two numeric columns" still
  work) instead of a reworded message that accidentally broke that match.
* Test suite: warnings that are an expected, documented side effect of
  `trait_space()` (dropping non-numeric/constant columns) are now
  suppressed with `suppressWarnings()` in the tests that don't
  specifically test for them, and a dedicated test asserts both warnings
  are raised when expected.

# intraitR 0.2.1

Bug fixes found by `devtools::test()` on a real R installation:

* `trait_space()` now drops constant (zero-variance) numeric columns
  automatically, with a warning, instead of erroring inside
  `stats::prcomp()`/`stats::cmdscale()` ("cannot rescale a constant/zero
  column to unit variance"). This most commonly occurred when incidental
  numeric metadata carried over from `fishmorph_segments()` /
  `fishmorph_ratios()` (e.g. a digitization `replicate` counter that is
  constant when `n_replicates = 1`) was passed to `trait_space()`
  unfiltered.
* `summary_traits()` and `trait_space()` now check for "no usable numeric
  columns" before warning about dropped non-numeric columns, instead of
  emitting a spurious warning right before erroring.
* Fixed unit tests in `test-fishmorph_ratios.R` that compared rounded
  output (default `digits = 4`) against un-rounded expected values for
  ratios with repeating decimals (`REs`, `RMl`).

# intraitR 0.2.0

* Implements the FISHMORPH digitization and trait protocol of Brosse et al.
  (2021, Global Ecology and Biogeography): a fixed scheme of 21 (optionally
  22) landmarks per specimen (snout, caudal fin basis, body depth, head
  depth, eye position/diameter, mouth, pectoral fin, caudal peduncle and
  caudal fin depth, plus an embedded scale bar and an optional body-curvature
  correction point).
* `fishmorph_segments()` computes the 11 linear measurements of the protocol
  (`Bl`, `Bd`, `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`, `CFd`)
  directly from digitized points, automatically converting pixel units to
  centimetres using an embedded scale bar, and applying the optional
  body-curvature correction for standard length.
* `fishmorph_ratios()` computes the 9 unitless FISHMORPH ratios (`BEl`,
  `VEp`, `REs`, `OGp`, `RMl`, `BLs`, `PFv`, `PFs`, `CPt`) from these
  measurements, optionally adds maximum body length (`MBl`), and implements
  the special-case rules of Villeger et al. (2010) for species without a
  visible caudal fin, with a ventrally positioned mouth, or without
  pectoral fins.
* `trait_space()` builds a generic functional trait space (PCA or PCoA) from
  any numeric trait table, with group convex-hull plotting; `shape_space()`
  now shares its plotting code with `trait_space()`.
* `plot_fishmorph_points()` visualises the 21/22-point digitization scheme
  on a specimen, following the colour scheme of the original protocol
  figure.
* `simulate_fishmorph_points()` generates simulated multi-species landmark
  data following the FISHMORPH point scheme, for examples, teaching and
  testing of the functions above.

# intraitR 0.1.0

* Initial release.
* Landmark import from TPS files (`read_tps()`) and generic long-format CSV
  files (`read_landmarks_csv()`).
* Generalised Procrustes Analysis wrapper (`gpa_fish()`) built on
  `geomorph::gpagen()`.
* Linear inter-landmark distances (`linear_distances()`) and classical
  fish morphometric ratios (`morpho_ratios()`).
* Shape space construction and plotting (`shape_space()`).
* Allometry correction (`correct_allometry()`).
* Intraspecific morphological variability, combining shape disparity
  (`geomorph::morphol.disparity()`) and coefficients of variation of linear
  traits (`intraspecific_variability()`).
* Measurement error / repeatability analysis for replicated digitization,
  both for univariate traits (ANOVA-based percent measurement error and
  repeatability, Bailey & Byrnes 1990) and for shape data (Procrustes ANOVA,
  Fruciano 2016) via `measurement_error()`.
* Landmark configuration plotting (`plot_landmarks()`) and trait summary
  tables (`summary_traits()`).
* Simulated example data set `fish_landmarks` and generator function
  `simulate_fish_landmarks()`.
