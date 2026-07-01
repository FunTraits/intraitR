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
  used by, `morpho_space()`, which ordinates Procrustes shape coordinates
  rather than trait ratios.
* `plot.intrait_morphospace()` and `plot.intrait_traitspace()` gain a
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
  any numeric trait table, with group convex-hull plotting; `morpho_space()`
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
* Morphological space construction and plotting (`morpho_space()`).
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
