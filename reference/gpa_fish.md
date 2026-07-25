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
#> fishmorph_shape_landmarks(): dropping 274 specimen(s) with a missing landmark or unresolved species identification.
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 183 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0009_Operator_2, T-26-0009_Operator_3, T-26-0009_Operator_4, T-26-0011_Operator_2, T-26-0011_Operator_3, T-26-0052_Operator_1, T-26-0052_Operator_4, T-26-0056_Operator_4, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0067_Operator_3, T-26-0067_Operator_4, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0068_Operator_3, T-26-0068_Operator_4, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0070_Operator_3, T-26-0070_Operator_4, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0071_Operator_4, T-26-0072_Operator_2, T-26-0072_Operator_4, T-26-0073_Operator_2, T-26-0073_Operator_4, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0074_Operator_4, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0075_Operator_4, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0076_Operator_3, T-26-0076_Operator_4, T-26-0077_Operator_2, T-26-0077_Operator_4, T-26-0078_Operator_2, T-26-0078_Operator_4, T-26-0079_Operator_2, T-26-0079_Operator_4, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0080_Operator_3, T-26-0080_Operator_4, T-26-0081_Operator_3, T-26-0081_Operator_4, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0082_Operator_3, T-26-0082_Operator_4, T-26-0083_Operator_3, T-26-0083_Operator_4, T-26-0084_Operator_3, T-26-0084_Operator_4, T-26-0085_Operator_1, T-26-0085_Operator_3, T-26-0085_Operator_4, T-26-0086_Operator_2, T-26-0086_Operator_3, T-26-0086_Operator_4, T-26-0088_Operator_3, T-26-0088_Operator_4, T-26-0090_Operator_2, T-26-0090_Operator_3, T-26-0090_Operator_4, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0091_Operator_3, T-26-0091_Operator_4, T-26-0092_Operator_3, T-26-0092_Operator_4, T-26-0093_Operator_3, T-26-0093_Operator_4, T-26-0094_Operator_1, T-26-0094_Operator_3, T-26-0094_Operator_4, T-26-0095_Operator_4, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0096_Operator_4, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0097_Operator_4, T-26-0098_Operator_2, T-26-0098_Operator_4, T-26-0099_Operator_2, T-26-0099_Operator_4, T-26-0100_Operator_4, T-26-0101_Operator_4, T-26-0102_Operator_4, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0103_Operator_4, T-26-0104_Operator_2, T-26-0104_Operator_4, T-26-0107_Operator_4, T-26-0108_Operator_4, T-26-0109_Operator_4, T-26-0111_Operator_4, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0113_Operator_4, T-26-0114_Operator_4, T-26-0115_Operator_4, T-26-0116_Operator_1, T-26-0116_Operator_4, T-26-0117_Operator_4, T-26-0118_Operator_4, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0120_Operator_4, T-26-0121_Operator_4, T-26-0122_Operator_1, T-26-0122_Operator_4, T-26-0123_Operator_4, T-26-0125_Operator_4, T-26-0126_Operator_4, T-26-0127_Operator_4, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0128_Operator_4, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0130_Operator_4, T-26-0138_Operator_3, T-26-0140_Operator_3, T-26-0141_Operator_3, T-26-0142_Operator_3, T-26-0167_Operator_3, T-26-0168_Operator_3, T-26-0190_Operator_4, T-26-0209_Operator_4, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0263_Operator_4, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0265_Operator_4, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0266_Operator_4, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0268_Operator_4, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0269_Operator_4, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0271_Operator_4, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0272_Operator_4, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0273_Operator_4, T-26-0274_Operator_4, T-26-0275_Operator_4, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0276_Operator_4, T-26-0277_Operator_1, T-26-0277_Operator_4, T-26-0278-1_Operator_1, T-26-0278-2_Operator_1, T-26-0278-2_Operator_2, T-26-0279_Operator_4; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
gpa   # flags any Procrustes-distance outliers found, see gpa$outlier_screen
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   762 specimens, 19 landmarks, 2 dimensions
#>   Converged in 3 iteration(s)
#>   Centroid size: mean = 2385.123, range = [437.284, 7515.979]
#>   183 potential Procrustes-distance outlier(s) flagged (see $outlier_screen); most atypical:
#>     T-26-0230-1_Operator_2: distance = 0.9854 (threshold 0.2138)
#>     T-26-0056_Operator_4: distance = 0.5313 (threshold 0.2138)
#>     T-26-0052_Operator_1: distance = 0.4036 (threshold 0.2138)
#>     T-26-0075_Operator_1: distance = 0.3740 (threshold 0.2138)
#>     T-26-0271_Operator_2: distance = 0.3715 (threshold 0.2138)

# Once a flagged specimen has been visually confirmed as a digitization
# error (not just a genuinely extreme morphology), exclude it and
# re-align without it:
gpa_clean <- gpa_fish(fish_shape, remove_outliers = TRUE)
#> remove_outliers: removing 183 specimen(s) flagged as Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0009_Operator_2, T-26-0009_Operator_3, T-26-0009_Operator_4, T-26-0011_Operator_2, T-26-0011_Operator_3, T-26-0052_Operator_1, T-26-0052_Operator_4, T-26-0056_Operator_4, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0067_Operator_3, T-26-0067_Operator_4, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0068_Operator_3, T-26-0068_Operator_4, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0070_Operator_3, T-26-0070_Operator_4, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0071_Operator_4, T-26-0072_Operator_2, T-26-0072_Operator_4, T-26-0073_Operator_2, T-26-0073_Operator_4, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0074_Operator_4, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0075_Operator_4, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0076_Operator_3, T-26-0076_Operator_4, T-26-0077_Operator_2, T-26-0077_Operator_4, T-26-0078_Operator_2, T-26-0078_Operator_4, T-26-0079_Operator_2, T-26-0079_Operator_4, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0080_Operator_3, T-26-0080_Operator_4, T-26-0081_Operator_3, T-26-0081_Operator_4, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0082_Operator_3, T-26-0082_Operator_4, T-26-0083_Operator_3, T-26-0083_Operator_4, T-26-0084_Operator_3, T-26-0084_Operator_4, T-26-0085_Operator_1, T-26-0085_Operator_3, T-26-0085_Operator_4, T-26-0086_Operator_2, T-26-0086_Operator_3, T-26-0086_Operator_4, T-26-0088_Operator_3, T-26-0088_Operator_4, T-26-0090_Operator_2, T-26-0090_Operator_3, T-26-0090_Operator_4, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0091_Operator_3, T-26-0091_Operator_4, T-26-0092_Operator_3, T-26-0092_Operator_4, T-26-0093_Operator_3, T-26-0093_Operator_4, T-26-0094_Operator_1, T-26-0094_Operator_3, T-26-0094_Operator_4, T-26-0095_Operator_4, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0096_Operator_4, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0097_Operator_4, T-26-0098_Operator_2, T-26-0098_Operator_4, T-26-0099_Operator_2, T-26-0099_Operator_4, T-26-0100_Operator_4, T-26-0101_Operator_4, T-26-0102_Operator_4, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0103_Operator_4, T-26-0104_Operator_2, T-26-0104_Operator_4, T-26-0107_Operator_4, T-26-0108_Operator_4, T-26-0109_Operator_4, T-26-0111_Operator_4, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0113_Operator_4, T-26-0114_Operator_4, T-26-0115_Operator_4, T-26-0116_Operator_1, T-26-0116_Operator_4, T-26-0117_Operator_4, T-26-0118_Operator_4, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0120_Operator_4, T-26-0121_Operator_4, T-26-0122_Operator_1, T-26-0122_Operator_4, T-26-0123_Operator_4, T-26-0125_Operator_4, T-26-0126_Operator_4, T-26-0127_Operator_4, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0128_Operator_4, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0130_Operator_4, T-26-0138_Operator_3, T-26-0140_Operator_3, T-26-0141_Operator_3, T-26-0142_Operator_3, T-26-0167_Operator_3, T-26-0168_Operator_3, T-26-0190_Operator_4, T-26-0209_Operator_4, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0263_Operator_4, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0265_Operator_4, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0266_Operator_4, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0268_Operator_4, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0269_Operator_4, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0271_Operator_4, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0272_Operator_4, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0273_Operator_4, T-26-0274_Operator_4, T-26-0275_Operator_4, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0276_Operator_4, T-26-0277_Operator_1, T-26-0277_Operator_4, T-26-0278-1_Operator_1, T-26-0278-2_Operator_1, T-26-0278-2_Operator_2, T-26-0279_Operator_4. Re-running GPA without them; see $removed_outliers for the record, and always confirm each removal corresponds to a real digitization error (e.g. via plot_landmarks()/plot_fishmorph_points()), not just genuine morphological variation, before relying on this in a publication.
gpa_clean$removed_outliers   # exactly which specimen(s) were excluded, and why
#>                   specimen procrustes_distance threshold_value flagged
#> 19    T-26-0009_Operator_2           0.2169184       0.2138104    TRUE
#> 20    T-26-0009_Operator_3           0.2152154       0.2138104    TRUE
#> 21    T-26-0009_Operator_4           0.2254866       0.2138104    TRUE
#> 24    T-26-0011_Operator_2           0.3569473       0.2138104    TRUE
#> 25    T-26-0011_Operator_3           0.3398940       0.2138104    TRUE
#> 115   T-26-0052_Operator_1           0.4036186       0.2138104    TRUE
#> 118   T-26-0052_Operator_4           0.2189519       0.2138104    TRUE
#> 129   T-26-0056_Operator_4           0.5312928       0.2138104    TRUE
#> 152   T-26-0067_Operator_1           0.3320415       0.2138104    TRUE
#> 153   T-26-0067_Operator_2           0.3293087       0.2138104    TRUE
#> 154   T-26-0067_Operator_3           0.3263442       0.2138104    TRUE
#> 155   T-26-0067_Operator_4           0.3320286       0.2138104    TRUE
#> 156   T-26-0068_Operator_1           0.3469983       0.2138104    TRUE
#> 157   T-26-0068_Operator_2           0.3390582       0.2138104    TRUE
#> 158   T-26-0068_Operator_3           0.3402494       0.2138104    TRUE
#> 159   T-26-0068_Operator_4           0.3252735       0.2138104    TRUE
#> 164   T-26-0070_Operator_1           0.3373282       0.2138104    TRUE
#> 165   T-26-0070_Operator_2           0.3340424       0.2138104    TRUE
#> 166   T-26-0070_Operator_3           0.3288934       0.2138104    TRUE
#> 167   T-26-0070_Operator_4           0.3275047       0.2138104    TRUE
#> 168   T-26-0071_Operator_1           0.3492358       0.2138104    TRUE
#> 169   T-26-0071_Operator_2           0.3496046       0.2138104    TRUE
#> 170   T-26-0071_Operator_4           0.3440175       0.2138104    TRUE
#> 171   T-26-0072_Operator_2           0.3381967       0.2138104    TRUE
#> 172   T-26-0072_Operator_4           0.3497263       0.2138104    TRUE
#> 173   T-26-0073_Operator_2           0.3584628       0.2138104    TRUE
#> 174   T-26-0073_Operator_4           0.3555241       0.2138104    TRUE
#> 175   T-26-0074_Operator_1           0.3366322       0.2138104    TRUE
#> 176   T-26-0074_Operator_2           0.3446239       0.2138104    TRUE
#> 177   T-26-0074_Operator_4           0.3324899       0.2138104    TRUE
#> 178   T-26-0075_Operator_1           0.3739731       0.2138104    TRUE
#> 179   T-26-0075_Operator_2           0.3685537       0.2138104    TRUE
#> 180   T-26-0075_Operator_4           0.3619471       0.2138104    TRUE
#> 181   T-26-0076_Operator_1           0.3418884       0.2138104    TRUE
#> 182   T-26-0076_Operator_2           0.3313651       0.2138104    TRUE
#> 183   T-26-0076_Operator_3           0.3327416       0.2138104    TRUE
#> 184   T-26-0076_Operator_4           0.3256051       0.2138104    TRUE
#> 185   T-26-0077_Operator_2           0.3202665       0.2138104    TRUE
#> 186   T-26-0077_Operator_4           0.3162419       0.2138104    TRUE
#> 187   T-26-0078_Operator_2           0.3092779       0.2138104    TRUE
#> 188   T-26-0078_Operator_4           0.3079180       0.2138104    TRUE
#> 189   T-26-0079_Operator_2           0.3483585       0.2138104    TRUE
#> 190   T-26-0079_Operator_4           0.3447643       0.2138104    TRUE
#> 191   T-26-0080_Operator_1           0.3283351       0.2138104    TRUE
#> 192   T-26-0080_Operator_2           0.3243482       0.2138104    TRUE
#> 193   T-26-0080_Operator_3           0.3302513       0.2138104    TRUE
#> 194   T-26-0080_Operator_4           0.3203199       0.2138104    TRUE
#> 195   T-26-0081_Operator_3           0.3356972       0.2138104    TRUE
#> 196   T-26-0081_Operator_4           0.3347826       0.2138104    TRUE
#> 197   T-26-0082_Operator_1           0.3467250       0.2138104    TRUE
#> 198   T-26-0082_Operator_2           0.3386781       0.2138104    TRUE
#> 199   T-26-0082_Operator_3           0.3432858       0.2138104    TRUE
#> 200   T-26-0082_Operator_4           0.3401864       0.2138104    TRUE
#> 201   T-26-0083_Operator_3           0.3200580       0.2138104    TRUE
#> 202   T-26-0083_Operator_4           0.3271436       0.2138104    TRUE
#> 203   T-26-0084_Operator_3           0.3369645       0.2138104    TRUE
#> 204   T-26-0084_Operator_4           0.3415566       0.2138104    TRUE
#> 205   T-26-0085_Operator_1           0.3269401       0.2138104    TRUE
#> 206   T-26-0085_Operator_3           0.3317177       0.2138104    TRUE
#> 207   T-26-0085_Operator_4           0.3366750       0.2138104    TRUE
#> 208   T-26-0086_Operator_2           0.3372410       0.2138104    TRUE
#> 209   T-26-0086_Operator_3           0.3285532       0.2138104    TRUE
#> 210   T-26-0086_Operator_4           0.3356652       0.2138104    TRUE
#> 214   T-26-0088_Operator_3           0.3357576       0.2138104    TRUE
#> 215   T-26-0088_Operator_4           0.3414011       0.2138104    TRUE
#> 219   T-26-0090_Operator_2           0.3000025       0.2138104    TRUE
#> 220   T-26-0090_Operator_3           0.3024610       0.2138104    TRUE
#> 221   T-26-0090_Operator_4           0.3130606       0.2138104    TRUE
#> 222   T-26-0091_Operator_1           0.3324700       0.2138104    TRUE
#> 223   T-26-0091_Operator_2           0.3493182       0.2138104    TRUE
#> 224   T-26-0091_Operator_3           0.3416998       0.2138104    TRUE
#> 225   T-26-0091_Operator_4           0.3412928       0.2138104    TRUE
#> 226   T-26-0092_Operator_3           0.3407953       0.2138104    TRUE
#> 227   T-26-0092_Operator_4           0.3484922       0.2138104    TRUE
#> 228   T-26-0093_Operator_3           0.3481229       0.2138104    TRUE
#> 229   T-26-0093_Operator_4           0.3569263       0.2138104    TRUE
#> 230   T-26-0094_Operator_1           0.3294359       0.2138104    TRUE
#> 231   T-26-0094_Operator_3           0.3342638       0.2138104    TRUE
#> 232   T-26-0094_Operator_4           0.3487422       0.2138104    TRUE
#> 234   T-26-0095_Operator_4           0.3393638       0.2138104    TRUE
#> 235   T-26-0096_Operator_1           0.3371026       0.2138104    TRUE
#> 236   T-26-0096_Operator_2           0.3453236       0.2138104    TRUE
#> 238   T-26-0096_Operator_4           0.3449559       0.2138104    TRUE
#> 239   T-26-0097_Operator_1           0.3223430       0.2138104    TRUE
#> 240   T-26-0097_Operator_2           0.3250353       0.2138104    TRUE
#> 242   T-26-0097_Operator_4           0.3299933       0.2138104    TRUE
#> 243   T-26-0098_Operator_2           0.3376108       0.2138104    TRUE
#> 245   T-26-0098_Operator_4           0.3266830       0.2138104    TRUE
#> 246   T-26-0099_Operator_2           0.3069595       0.2138104    TRUE
#> 248   T-26-0099_Operator_4           0.2993052       0.2138104    TRUE
#> 250   T-26-0100_Operator_4           0.3432374       0.2138104    TRUE
#> 252   T-26-0101_Operator_4           0.3700846       0.2138104    TRUE
#> 254   T-26-0102_Operator_4           0.3436770       0.2138104    TRUE
#> 255   T-26-0103_Operator_1           0.3571320       0.2138104    TRUE
#> 256   T-26-0103_Operator_2           0.3607578       0.2138104    TRUE
#> 258   T-26-0103_Operator_4           0.3514299       0.2138104    TRUE
#> 259   T-26-0104_Operator_2           0.3492865       0.2138104    TRUE
#> 261   T-26-0104_Operator_4           0.3455049       0.2138104    TRUE
#> 263   T-26-0107_Operator_4           0.3321683       0.2138104    TRUE
#> 265   T-26-0108_Operator_4           0.3112471       0.2138104    TRUE
#> 267   T-26-0109_Operator_4           0.3276942       0.2138104    TRUE
#> 269   T-26-0111_Operator_4           0.3190915       0.2138104    TRUE
#> 270 T-26-0112-2_Operator_1           0.3470516       0.2138104    TRUE
#> 271 T-26-0112-2_Operator_2           0.3500128       0.2138104    TRUE
#> 273   T-26-0113_Operator_1           0.3060737       0.2138104    TRUE
#> 275   T-26-0113_Operator_4           0.3013028       0.2138104    TRUE
#> 277   T-26-0114_Operator_4           0.3253441       0.2138104    TRUE
#> 279   T-26-0115_Operator_4           0.2204038       0.2138104    TRUE
#> 280   T-26-0116_Operator_1           0.3102436       0.2138104    TRUE
#> 282   T-26-0116_Operator_4           0.2794646       0.2138104    TRUE
#> 283   T-26-0117_Operator_4           0.3372824       0.2138104    TRUE
#> 284   T-26-0118_Operator_4           0.2646654       0.2138104    TRUE
#> 285   T-26-0120_Operator_1           0.3289768       0.2138104    TRUE
#> 286   T-26-0120_Operator_2           0.3266213       0.2138104    TRUE
#> 287   T-26-0120_Operator_4           0.3238899       0.2138104    TRUE
#> 288   T-26-0121_Operator_4           0.2842487       0.2138104    TRUE
#> 289   T-26-0122_Operator_1           0.3446609       0.2138104    TRUE
#> 291   T-26-0122_Operator_4           0.3438073       0.2138104    TRUE
#> 293   T-26-0123_Operator_4           0.3284481       0.2138104    TRUE
#> 295   T-26-0125_Operator_4           0.3154192       0.2138104    TRUE
#> 296   T-26-0126_Operator_4           0.3332062       0.2138104    TRUE
#> 298   T-26-0127_Operator_4           0.3408674       0.2138104    TRUE
#> 299   T-26-0128_Operator_1           0.3001011       0.2138104    TRUE
#> 300   T-26-0128_Operator_2           0.3024759       0.2138104    TRUE
#> 302   T-26-0128_Operator_4           0.2968858       0.2138104    TRUE
#> 303   T-26-0130_Operator_1           0.2916388       0.2138104    TRUE
#> 304   T-26-0130_Operator_2           0.2853287       0.2138104    TRUE
#> 306   T-26-0130_Operator_4           0.2977650       0.2138104    TRUE
#> 331   T-26-0138_Operator_3           0.3180431       0.2138104    TRUE
#> 335   T-26-0140_Operator_3           0.3060372       0.2138104    TRUE
#> 337   T-26-0141_Operator_3           0.2467927       0.2138104    TRUE
#> 339   T-26-0142_Operator_3           0.2576651       0.2138104    TRUE
#> 422   T-26-0167_Operator_3           0.2831355       0.2138104    TRUE
#> 426   T-26-0168_Operator_3           0.2578261       0.2138104    TRUE
#> 506   T-26-0190_Operator_4           0.2369293       0.2138104    TRUE
#> 562   T-26-0209_Operator_4           0.2377763       0.2138104    TRUE
#> 620 T-26-0230-1_Operator_2           0.9853878       0.2138104    TRUE
#> 702 T-26-0261-3_Operator_1           0.3280397       0.2138104    TRUE
#> 703 T-26-0261-5_Operator_1           0.3063541       0.2138104    TRUE
#> 705   T-26-0263_Operator_1           0.2787721       0.2138104    TRUE
#> 706   T-26-0263_Operator_2           0.2737523       0.2138104    TRUE
#> 708   T-26-0263_Operator_4           0.2851316       0.2138104    TRUE
#> 709 T-26-0264-2_Operator_1           0.2899186       0.2138104    TRUE
#> 710 T-26-0264-2_Operator_2           0.2934060       0.2138104    TRUE
#> 711 T-26-0264-3_Operator_1           0.3087629       0.2138104    TRUE
#> 712 T-26-0264-4_Operator_1           0.2929315       0.2138104    TRUE
#> 713 T-26-0264-4_Operator_2           0.2902188       0.2138104    TRUE
#> 714   T-26-0265_Operator_1           0.3128748       0.2138104    TRUE
#> 715   T-26-0265_Operator_2           0.3108411       0.2138104    TRUE
#> 717   T-26-0265_Operator_4           0.3255351       0.2138104    TRUE
#> 718   T-26-0266_Operator_1           0.3319919       0.2138104    TRUE
#> 719   T-26-0266_Operator_2           0.3234671       0.2138104    TRUE
#> 721   T-26-0266_Operator_4           0.3204168       0.2138104    TRUE
#> 726   T-26-0268_Operator_1           0.3089295       0.2138104    TRUE
#> 727   T-26-0268_Operator_2           0.3014394       0.2138104    TRUE
#> 729   T-26-0268_Operator_4           0.3044083       0.2138104    TRUE
#> 730   T-26-0269_Operator_1           0.3302789       0.2138104    TRUE
#> 731   T-26-0269_Operator_2           0.3246287       0.2138104    TRUE
#> 733   T-26-0269_Operator_4           0.3253462       0.2138104    TRUE
#> 734 T-26-0270-1_Operator_1           0.3143527       0.2138104    TRUE
#> 735 T-26-0270-1_Operator_2           0.3111802       0.2138104    TRUE
#> 736 T-26-0270-2_Operator_1           0.2966706       0.2138104    TRUE
#> 737 T-26-0270-2_Operator_2           0.2973876       0.2138104    TRUE
#> 738   T-26-0271_Operator_1           0.3571512       0.2138104    TRUE
#> 739   T-26-0271_Operator_2           0.3714985       0.2138104    TRUE
#> 741   T-26-0271_Operator_4           0.3226998       0.2138104    TRUE
#> 742   T-26-0272_Operator_1           0.2698837       0.2138104    TRUE
#> 743   T-26-0272_Operator_2           0.2735693       0.2138104    TRUE
#> 744   T-26-0272_Operator_4           0.2661221       0.2138104    TRUE
#> 745   T-26-0273_Operator_1           0.3219874       0.2138104    TRUE
#> 746   T-26-0273_Operator_2           0.3154199       0.2138104    TRUE
#> 748   T-26-0273_Operator_4           0.3097351       0.2138104    TRUE
#> 750   T-26-0274_Operator_4           0.2661669       0.2138104    TRUE
#> 752   T-26-0275_Operator_4           0.2753404       0.2138104    TRUE
#> 753   T-26-0276_Operator_1           0.2917111       0.2138104    TRUE
#> 754   T-26-0276_Operator_2           0.2902235       0.2138104    TRUE
#> 756   T-26-0276_Operator_4           0.2978515       0.2138104    TRUE
#> 757   T-26-0277_Operator_1           0.2772476       0.2138104    TRUE
#> 758   T-26-0277_Operator_4           0.2776325       0.2138104    TRUE
#> 759 T-26-0278-1_Operator_1           0.2827326       0.2138104    TRUE
#> 760 T-26-0278-2_Operator_1           0.2419526       0.2138104    TRUE
#> 761 T-26-0278-2_Operator_2           0.2429996       0.2138104    TRUE
#> 762   T-26-0279_Operator_4           0.2949781       0.2138104    TRUE
```
