# cran-comments

## Test environments

* Local install, `devtools::test()` (v1.0.0 run): 465 passed, 0 failed,
  5 expected warnings (documented data/test-design artifacts, not bugs),
  6 expected skips (environment-dependent negative-path tests). [fill in
  R version / OS before submission]
* **v1.1.0 has not yet had a real `devtools::test()`/`devtools::check()`
  run** -- see "Changes since the v1.0.0 real test run" below for exactly
  what is new and unverified; run both before submitting and replace this
  whole section with the actual, current results.
* [to complete before submission] `devtools::check(cran = TRUE)` locally
* [to complete before submission] R-hub / win-builder (devel and release)

## R CMD check results

[to complete before submission -- do not submit with a result that was
not actually produced by a real `devtools::check()` run]

(see `SUBMISSION_NOTES.md` for the step-by-step procedure used to
produce this package, including the environment constraints under which
it was authored, and its "Mise à jour v1.1.0" section for what changed
since the last real test run)

## Downstream dependencies

This is a new submission; there are no downstream dependencies.

## Changes since the v1.0.0 real test run

v1.1.0 adds a `method` argument to `bootstrap_functional_space()` and
`species_sensitivity()` (`"convexhull"`, the previous and still default
behaviour; `"dendrogram"`, `"tpd"`, `"hypervolume"`), and a new
`compare_functional_richness()` that runs several methods on the same
data and tabulates the results. Specifically worth re-checking on a real
R installation before submission:

* The `TPD::TPDsMean()`/`TPD::TPDc()`/`TPD::REND()` and
  `hypervolume::hypervolume_gaussian()`/`estimate_bandwidth()`/
  `get_volume()` call signatures were written against the CRAN reference
  manuals for those packages (read at authoring time), not executed --
  this authoring environment has no R interpreter (see
  `SUBMISSION_NOTES.md`). Run the `method = "tpd"`/`"hypervolume"` tests
  and examples with both packages installed to confirm.
* `method = "dendrogram"` needs no additional package (base
  `stats::hclust()`) and was reasoned through by hand (total UPGMA branch
  length, Petchey & Gaston 2002); still worth a real test run rather than
  trusting the static check alone.
* New tests in `test-bootstrap_functional_space.R`,
  `test-species_sensitivity.R`, and `test-compare_functional_richness.R`
  are guarded with `testthat::skip_if_not_installed("TPD")`/
  `skip_if_not_installed("hypervolume")` so they do not fail on a machine
  without those (Suggested, optional) packages installed.

## Additional notes for CRAN maintainers

* `intraitR` depends on `geomorph`, the reference implementation of
  geometric morphometric methods (Procrustes superimposition, shape PCA,
  Procrustes ANOVA, morphological disparity) used throughout the package.
* Examples that require `geomorph` are wrapped where useful with
  `\donttest{}` only if their runtime exceeds CRAN's guidance; most
  examples run in well under 5 seconds using the bundled
  `simulate_fish_landmarks()` generator, which needs no external data.
* Two Suggested packages are new in 1.1.0: `TPD` and `hypervolume`. Both
  are used only inside `bootstrap_functional_space()`/
  `species_sensitivity()`/`compare_functional_richness()`, gated behind
  `requireNamespace(..., quietly = TRUE)`, and only when the caller
  explicitly requests `method = "tpd"`/`"hypervolume"` -- the package's
  default behaviour (`method = "convexhull"`) is unaffected and does not
  require either. Examples that exercise them are wrapped in
  `if (requireNamespace(...))` so they do not fail when either is absent.
