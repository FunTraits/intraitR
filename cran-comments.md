# cran-comments

## Test environments

* [to complete before submission] local install, R x.y.z, <OS>
* [to complete before submission] R-hub / win-builder (devel and release)

## R CMD check results

0 errors | 0 warnings | 0 notes

(replace with the actual results of `devtools::check()` /
`R CMD check --as-cran` run locally before submission; see
`SUBMISSION_NOTES.md` for the step-by-step procedure used to produce this
package, including the environment constraints under which it was
authored)

## Downstream dependencies

This is a new submission; there are no downstream dependencies.

## Additional notes for CRAN maintainers

* `intraitR` depends on `geomorph`, the reference implementation of
  geometric morphometric methods (Procrustes superimposition, shape PCA,
  Procrustes ANOVA, morphological disparity) used throughout the package.
* Examples that require `geomorph` are wrapped where useful with
  `\donttest{}` only if their runtime exceeds CRAN's guidance; most
  examples run in well under 5 seconds using the bundled
  `simulate_fish_landmarks()` generator, which needs no external data.
