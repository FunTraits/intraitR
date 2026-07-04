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
  `itv_index()`, `measurement_error()`, `morpho_space()`, `read_tps()`,
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
  `plot.intrait_morphospace()`, via the shared internal
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
  `plot.intrait_morphospace()`: a non-parametric kernel-density contour
  (highest-density-region construction, Hyndman 1996) per group, as an
  alternative to the parametric bivariate-normal "spider" ellipse — useful
  when a group's points are visibly skewed or multimodal (as can happen
  with real digitization data). Implemented with a small, dependency-free
  bivariate Gaussian kernel density estimator (the same formula underlying
  `MASS::kde2d()`), so no new package dependency is introduced.
* **Legend placement overhauled.** `plot.intrait_traitspace()`,
  `plot.intrait_morphospace()`, `plot.intrait_itv()`, and
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
