# Generalised Procrustes Analysis for fish landmark configurations

Superimposes a sample of landmark configurations using Generalised
Procrustes Analysis (GPA), removing differences in position, orientation
and scale so that residual variation reflects shape alone. This is a
fish-oriented wrapper around
[`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html).

## Usage

``` r
gpa_fish(
  landmarks,
  flag_outliers = TRUE,
  outlier_threshold = 3,
  remove_outliers = FALSE,
  ...
)

# S3 method for class 'intrait_gpa'
print(x, ...)

# S3 method for class 'intrait_gpa'
summary(object, ...)

# S3 method for class 'summary.intrait_gpa'
print(x, ...)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` (from
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
  or
  [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)),
  or a raw `p x k x n` landmark array.

- flag_outliers:

  Logical, screen the Procrustes-aligned sample for specimens whose
  distance to the consensus shape is unusually large – the same rule as
  [`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)
  (median + `outlier_threshold` x MAD of Procrustes distances) – and
  report them (see Details and `outlier_threshold`). Defaults to `TRUE`.
  This never removes any observation on its own: it only flags
  candidates for visual/manual review (e.g. with
  [`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
  or
  [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
  before deciding whether an exclusion is warranted.

- outlier_threshold:

  Numeric, the number of median absolute deviations (MAD) above the
  median Procrustes distance beyond which a specimen is flagged; same
  convention as
  [`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)'s
  `threshold`. Defaults to `3`.

- remove_outliers:

  Logical, actually exclude every specimen flagged by `flag_outliers`
  and re-run GPA on the cleaned sample (rather than only flagging them
  for review, the default). Requires `flag_outliers = TRUE` (an error is
  raised otherwise, since there would be nothing to remove). Defaults to
  `FALSE`: removing specimens changes the consensus shape and every
  downstream statistic (e.g.
  [`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md),
  [`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)),
  so this is opt-in rather than automatic, and every removal is still
  recorded in `$removed_outliers` (see Return) for transparency and
  reproducibility – always confirm flagged specimens genuinely reflect a
  digitization error (e.g. via
  [`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)/[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
  before turning this on for a given data set, rather than treating it
  as a default cleaning step.

- ...:

  Additional arguments passed on to
  [`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html)
  (e.g. `curves`, `surfaces`, `ProcD`).

- x:

  An object to print: an `"intrait_gpa"` (from `gpa_fish()`) or
  `"summary.intrait_gpa"` (from
  [`summary()`](https://rdrr.io/r/base/summary.html) on one) object.

- object:

  An object of class `"intrait_gpa"`, as returned by `gpa_fish()`.

## Value

An object of class `"intrait_gpa"`, a list with elements:

- coords:

  `p x k x n` array of Procrustes-aligned shape coordinates – of the
  *cleaned* sample if `remove_outliers = TRUE` removed any specimen.

- Csize:

  named numeric vector of centroid sizes, one per specimen; the standard
  measure of overall specimen size in geometric morphometrics.

- consensus:

  `p x k` matrix, the sample mean (consensus) shape.

- iter:

  number of iterations used by
  [`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html)
  to converge.

- metadata:

  specimen metadata carried over from `landmarks`, if present (subset to
  match, if `remove_outliers = TRUE` removed any specimen).

- outlier_screen:

  `NULL` unless `flag_outliers = TRUE` (the default); otherwise a
  `data.frame`, one row per specimen *actually used* (i.e. excluding any
  row removed by `remove_outliers = TRUE`), with columns `specimen`,
  `procrustes_distance` (to the consensus shape), `threshold_value`,
  `flagged`; see Details.

- removed_outliers:

  `NULL` unless `remove_outliers = TRUE` removed at least one specimen,
  in which case a `data.frame` with the same columns as
  `outlier_screen`, one row per *excluded* specimen, for the record.

Invisibly returns `x`.

A list of class `"summary.intrait_gpa"` (see
`print.summary.intrait_gpa()`), returned visibly.

Invisibly returns `x`.

## Details

Centroid size (`Csize`) is retained explicitly because, unlike
Procrustes shape coordinates, it captures the size component of
morphology and is required for allometry correction
([`correct_allometry()`](https://funtraits.github.io/intraitR/reference/correct_allometry.md))
and to relate shape to body size.

When `flag_outliers = TRUE` (the default), every specimen's Euclidean
(Procrustes) distance to the sample consensus shape is computed, and
flagged if it exceeds `median + outlier_threshold * MAD` (median
absolute deviation) of those distances – the same rule used by
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)
(which can be run on the result afterwards for the ordered dot-plot
view; both share the same screening code, so results agree). This never
removes anything automatically: it only flags candidates – always
inspect a flagged specimen (e.g. with
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)/[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
and its original photograph if available) before deciding whether to
exclude it.

Setting `remove_outliers = TRUE` goes one step further and actually
excludes every flagged specimen, then re-runs
[`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html) on
the cleaned sample – a genuinely mis-digitized specimen can distort the
consensus shape (and hence every other specimen's alignment to it), so
simply dropping it from a plot after the fact is not equivalent to
re-aligning without it. `coords`, `Csize`, `consensus`, and `metadata`
in the returned object then describe the *cleaned* sample, and
`$removed_outliers` records exactly which specimens were dropped and
why, so the exclusion remains fully reproducible and auditable rather
than an undocumented, ad hoc edit made before calling `gpa_fish()`. This
is deliberately opt-in (`FALSE` by default): removing data always
changes the alignment and should be a conscious, visually-confirmed
decision (see above), not something that happens silently just because a
threshold was crossed.

## References

Rohlf FJ, Slice D (1990). Extensions of the Procrustes method for the
optimal superimposition of landmarks. Systematic Zoology, 39(1), 40-59.

## See also

[`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md),
[`correct_allometry()`](https://funtraits.github.io/intraitR/reference/correct_allometry.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
[`fishmorph_shape_landmarks()`](https://funtraits.github.io/intraitR/reference/fishmorph_shape_landmarks.md)

## Examples

``` r
# real T-26 Saudrune data; GPA aligns *shape* only, so the FISHMORPH
# scale bar (points 20-21, a calibration segment, not a body landmark)
# must first be dropped, along with any specimen missing a landmark --
# fishmorph_shape_landmarks() does both:
fish <- load_t26_saudrune_landmarks()
fish_shape <- fishmorph_shape_landmarks(fish)
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 11 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
gpa   # flags any Procrustes-distance outliers found, see gpa$outlier_screen
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   494 specimens, 20 landmarks, 2 dimensions
#>   Converged in 3 iteration(s)
#>   Centroid size: mean = 2159.321, range = [316.008, 7576.064]
#>   11 potential Procrustes-distance outlier(s) flagged (see $outlier_screen); most atypical:
#>     SAUDRUNESUDTOULOUSE_20260518_0050_i1: distance = 0.1568 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260518_0012: distance = 0.1499 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260427_0009: distance = 0.1431 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260518_0055: distance = 0.1309 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260518_0039_i2: distance = 0.1275 (threshold 0.1159)

# Once a flagged specimen has been visually confirmed as a digitization
# error (not just a genuinely extreme morphology), exclude it and
# re-align without it:
gpa_clean <- gpa_fish(fish_shape, remove_outliers = TRUE)
#> remove_outliers: removing 11 specimen(s) flagged as Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055. Re-running GPA without them; see $removed_outliers for the record, and always confirm each removal corresponds to a real digitization error (e.g. via plot_landmarks()/plot_fishmorph_points()), not just genuine morphological variation, before relying on this in a publication.
gpa_clean$removed_outliers   # exactly which specimen(s) were excluded, and why
#>                                 specimen procrustes_distance threshold_value
#> 9      SAUDRUNESUDTOULOUSE_20260427_0009           0.1430509       0.1159469
#> 290    SAUDRUNESUDTOULOUSE_20260518_0012           0.1499422       0.1159469
#> 293    SAUDRUNESUDTOULOUSE_20260518_0015           0.1175751       0.1159469
#> 295    SAUDRUNESUDTOULOUSE_20260518_0017           0.1252708       0.1159469
#> 302    SAUDRUNESUDTOULOUSE_20260518_0024           0.1223858       0.1159469
#> 308    SAUDRUNESUDTOULOUSE_20260518_0030           0.1168078       0.1159469
#> 314    SAUDRUNESUDTOULOUSE_20260518_0036           0.1195046       0.1159469
#> 318 SAUDRUNESUDTOULOUSE_20260518_0039_i2           0.1275017       0.1159469
#> 323    SAUDRUNESUDTOULOUSE_20260518_0044           0.1186573       0.1159469
#> 329 SAUDRUNESUDTOULOUSE_20260518_0050_i1           0.1567729       0.1159469
#> 335    SAUDRUNESUDTOULOUSE_20260518_0055           0.1309012       0.1159469
#>     flagged
#> 9      TRUE
#> 290    TRUE
#> 293    TRUE
#> 295    TRUE
#> 302    TRUE
#> 308    TRUE
#> 314    TRUE
#> 318    TRUE
#> 323    TRUE
#> 329    TRUE
#> 335    TRUE
```
