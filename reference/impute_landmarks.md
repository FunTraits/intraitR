# Impute missing (NA) landmark coordinates using geometric morphometric methods

Estimates missing 2D coordinates directly in `landmarks$coords` (or a
raw `p x k x n` array), rather than leaving gaps in individual
specimens' digitized configurations or discarding them. Unlike the
`na_action` options of
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)/[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
– which impute the *derived* linear measurements/ratios after the fact,
as a simple fallback – this operates on the landmark geometry itself,
using
[`geomorph::estimate.missing()`](https://rdrr.io/pkg/geomorph/man/estimate.missing.html),
so the estimate reflects the covariation among landmark positions across
the sample (thin-plate spline warping or multivariate regression), the
standard approach for missing landmark data in geometric morphometrics.

## Usage

``` r
impute_landmarks(landmarks, method = c("tps", "regression"))
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

## Value

An object of the same class as `landmarks` (`"intrait_landmarks"` or a
raw array), with `NA` coordinates in landmarks 1-19 replaced by their
geometric morphometric estimate. Everything else (`scale`, `metadata`,
landmarks 20 and up) is left unchanged. The returned `coords` array also
carries an `"imputed"` attribute (a `p x n` logical matrix, one row per
landmark and one column per specimen, `TRUE` where that point was
estimated rather than digitized), which
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
point cannot be geometrically estimated; if either is missing for a
specimen, a warning is issued and that specimen's scale bar is left as
`NA` (matching
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)'s
own "zero-length or missing scale bar" warning – that specimen's
segments/ratios will still be `NA` downstream unless the scale bar is
fixed some other way). Landmark 22 (optional body- curvature correction)
is deliberately "0 if not needed" under the original protocol rather
than a routinely digitized point, so it is also left untouched.

As with any imputation, this is not a substitute for re-digitizing a
specimen from its original photograph when that is possible, and results
should be treated with more caution as the fraction of missing landmarks
grows, or when very few specimens have a complete configuration to learn
the covariation structure from. Always compare an imputed specimen
against its non-imputed neighbours (e.g. with
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
which highlights imputed landmarks directly, or the more generic
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md))
before relying on it in an analysis.

## See also

[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)

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

# }
```
