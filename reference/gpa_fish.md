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
  [`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md),
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

[`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md),
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
#> fishmorph_shape_landmarks(): dropping 230 specimen(s) with a missing landmark or unresolved species identification.
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 84 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0011_Operator_2, T-26-0052_Operator_1, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0072_Operator_2, T-26-0073_Operator_2, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0077_Operator_2, T-26-0078_Operator_2, T-26-0079_Operator_2, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0085_Operator_1, T-26-0086_Operator_2, T-26-0090_Operator_2, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0094_Operator_1, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0098_Operator_2, T-26-0099_Operator_2, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0104_Operator_2, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0116_Operator_1, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0122_Operator_1, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0277_Operator_1, T-26-0278-1_Operator_1, T-26-0278-2_Operator_2; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
gpa   # flags any Procrustes-distance outliers found, see gpa$outlier_screen
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   328 specimens, 19 landmarks, 2 dimensions
#>   Converged in 3 iteration(s)
#>   Centroid size: mean = 2755.102, range = [437.284, 7511.212]
#>   84 potential Procrustes-distance outlier(s) flagged (see $outlier_screen); most atypical:
#>     T-26-0230-1_Operator_2: distance = 0.9864 (threshold 0.2325)
#>     T-26-0052_Operator_1: distance = 0.3963 (threshold 0.2325)
#>     T-26-0075_Operator_1: distance = 0.3631 (threshold 0.2325)
#>     T-26-0271_Operator_2: distance = 0.3619 (threshold 0.2325)
#>     T-26-0075_Operator_2: distance = 0.3581 (threshold 0.2325)

# Once a flagged specimen has been visually confirmed as a digitization
# error (not just a genuinely extreme morphology), exclude it and
# re-align without it:
gpa_clean <- gpa_fish(fish_shape, remove_outliers = TRUE)
#> remove_outliers: removing 84 specimen(s) flagged as Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): T-26-0011_Operator_2, T-26-0052_Operator_1, T-26-0067_Operator_1, T-26-0067_Operator_2, T-26-0068_Operator_1, T-26-0068_Operator_2, T-26-0070_Operator_1, T-26-0070_Operator_2, T-26-0071_Operator_1, T-26-0071_Operator_2, T-26-0072_Operator_2, T-26-0073_Operator_2, T-26-0074_Operator_1, T-26-0074_Operator_2, T-26-0075_Operator_1, T-26-0075_Operator_2, T-26-0076_Operator_1, T-26-0076_Operator_2, T-26-0077_Operator_2, T-26-0078_Operator_2, T-26-0079_Operator_2, T-26-0080_Operator_1, T-26-0080_Operator_2, T-26-0082_Operator_1, T-26-0082_Operator_2, T-26-0085_Operator_1, T-26-0086_Operator_2, T-26-0090_Operator_2, T-26-0091_Operator_1, T-26-0091_Operator_2, T-26-0094_Operator_1, T-26-0096_Operator_1, T-26-0096_Operator_2, T-26-0097_Operator_1, T-26-0097_Operator_2, T-26-0098_Operator_2, T-26-0099_Operator_2, T-26-0103_Operator_1, T-26-0103_Operator_2, T-26-0104_Operator_2, T-26-0112-2_Operator_1, T-26-0112-2_Operator_2, T-26-0113_Operator_1, T-26-0116_Operator_1, T-26-0120_Operator_1, T-26-0120_Operator_2, T-26-0122_Operator_1, T-26-0128_Operator_1, T-26-0128_Operator_2, T-26-0130_Operator_1, T-26-0130_Operator_2, T-26-0230-1_Operator_2, T-26-0261-3_Operator_1, T-26-0261-5_Operator_1, T-26-0263_Operator_1, T-26-0263_Operator_2, T-26-0264-2_Operator_1, T-26-0264-2_Operator_2, T-26-0264-3_Operator_1, T-26-0264-4_Operator_1, T-26-0264-4_Operator_2, T-26-0265_Operator_1, T-26-0265_Operator_2, T-26-0266_Operator_1, T-26-0266_Operator_2, T-26-0268_Operator_1, T-26-0268_Operator_2, T-26-0269_Operator_1, T-26-0269_Operator_2, T-26-0270-1_Operator_1, T-26-0270-1_Operator_2, T-26-0270-2_Operator_1, T-26-0270-2_Operator_2, T-26-0271_Operator_1, T-26-0271_Operator_2, T-26-0272_Operator_1, T-26-0272_Operator_2, T-26-0273_Operator_1, T-26-0273_Operator_2, T-26-0276_Operator_1, T-26-0276_Operator_2, T-26-0277_Operator_1, T-26-0278-1_Operator_1, T-26-0278-2_Operator_2. Re-running GPA without them; see $removed_outliers for the record, and always confirm each removal corresponds to a real digitization error (e.g. via plot_landmarks()/plot_fishmorph_points()), not just genuine morphological variation, before relying on this in a publication.
gpa_clean$removed_outliers   # exactly which specimen(s) were excluded, and why
#>                   specimen procrustes_distance threshold_value flagged
#> 9     T-26-0011_Operator_2           0.3463604       0.2325364    TRUE
#> 44    T-26-0052_Operator_1           0.3962557       0.2325364    TRUE
#> 61    T-26-0067_Operator_1           0.3213217       0.2325364    TRUE
#> 62    T-26-0067_Operator_2           0.3190436       0.2325364    TRUE
#> 63    T-26-0068_Operator_1           0.3355137       0.2325364    TRUE
#> 64    T-26-0068_Operator_2           0.3284683       0.2325364    TRUE
#> 67    T-26-0070_Operator_1           0.3257850       0.2325364    TRUE
#> 68    T-26-0070_Operator_2           0.3234939       0.2325364    TRUE
#> 69    T-26-0071_Operator_1           0.3386597       0.2325364    TRUE
#> 70    T-26-0071_Operator_2           0.3394248       0.2325364    TRUE
#> 71    T-26-0072_Operator_2           0.3277817       0.2325364    TRUE
#> 72    T-26-0073_Operator_2           0.3478779       0.2325364    TRUE
#> 73    T-26-0074_Operator_1           0.3258806       0.2325364    TRUE
#> 74    T-26-0074_Operator_2           0.3340780       0.2325364    TRUE
#> 75    T-26-0075_Operator_1           0.3631352       0.2325364    TRUE
#> 76    T-26-0075_Operator_2           0.3580501       0.2325364    TRUE
#> 77    T-26-0076_Operator_1           0.3306104       0.2325364    TRUE
#> 78    T-26-0076_Operator_2           0.3204437       0.2325364    TRUE
#> 79    T-26-0077_Operator_2           0.3094581       0.2325364    TRUE
#> 80    T-26-0078_Operator_2           0.2986210       0.2325364    TRUE
#> 81    T-26-0079_Operator_2           0.3378013       0.2325364    TRUE
#> 82    T-26-0080_Operator_1           0.3167964       0.2325364    TRUE
#> 83    T-26-0080_Operator_2           0.3140570       0.2325364    TRUE
#> 84    T-26-0082_Operator_1           0.3356298       0.2325364    TRUE
#> 85    T-26-0082_Operator_2           0.3278560       0.2325364    TRUE
#> 86    T-26-0085_Operator_1           0.3158206       0.2325364    TRUE
#> 87    T-26-0086_Operator_2           0.3269910       0.2325364    TRUE
#> 90    T-26-0090_Operator_2           0.2899287       0.2325364    TRUE
#> 91    T-26-0091_Operator_1           0.3217769       0.2325364    TRUE
#> 92    T-26-0091_Operator_2           0.3394140       0.2325364    TRUE
#> 93    T-26-0094_Operator_1           0.3183452       0.2325364    TRUE
#> 94    T-26-0096_Operator_1           0.3262419       0.2325364    TRUE
#> 95    T-26-0096_Operator_2           0.3351959       0.2325364    TRUE
#> 96    T-26-0097_Operator_1           0.3114415       0.2325364    TRUE
#> 97    T-26-0097_Operator_2           0.3145106       0.2325364    TRUE
#> 98    T-26-0098_Operator_2           0.3270798       0.2325364    TRUE
#> 99    T-26-0099_Operator_2           0.2961522       0.2325364    TRUE
#> 100   T-26-0103_Operator_1           0.3468157       0.2325364    TRUE
#> 101   T-26-0103_Operator_2           0.3502652       0.2325364    TRUE
#> 102   T-26-0104_Operator_2           0.3386872       0.2325364    TRUE
#> 103 T-26-0112-2_Operator_1           0.3359467       0.2325364    TRUE
#> 104 T-26-0112-2_Operator_2           0.3395459       0.2325364    TRUE
#> 105   T-26-0113_Operator_1           0.2948654       0.2325364    TRUE
#> 106   T-26-0116_Operator_1           0.2994178       0.2325364    TRUE
#> 107   T-26-0120_Operator_1           0.3179663       0.2325364    TRUE
#> 108   T-26-0120_Operator_2           0.3161522       0.2325364    TRUE
#> 109   T-26-0122_Operator_1           0.3337122       0.2325364    TRUE
#> 110   T-26-0128_Operator_1           0.2886520       0.2325364    TRUE
#> 111   T-26-0128_Operator_2           0.2917041       0.2325364    TRUE
#> 112   T-26-0130_Operator_1           0.2802346       0.2325364    TRUE
#> 113   T-26-0130_Operator_2           0.2748848       0.2325364    TRUE
#> 250 T-26-0230-1_Operator_2           0.9864082       0.2325364    TRUE
#> 293 T-26-0261-3_Operator_1           0.3171940       0.2325364    TRUE
#> 294 T-26-0261-5_Operator_1           0.2958014       0.2325364    TRUE
#> 296   T-26-0263_Operator_1           0.2672095       0.2325364    TRUE
#> 297   T-26-0263_Operator_2           0.2630597       0.2325364    TRUE
#> 298 T-26-0264-2_Operator_1           0.2787561       0.2325364    TRUE
#> 299 T-26-0264-2_Operator_2           0.2833448       0.2325364    TRUE
#> 300 T-26-0264-3_Operator_1           0.2977977       0.2325364    TRUE
#> 301 T-26-0264-4_Operator_1           0.2816355       0.2325364    TRUE
#> 302 T-26-0264-4_Operator_2           0.2806622       0.2325364    TRUE
#> 303   T-26-0265_Operator_1           0.3012237       0.2325364    TRUE
#> 304   T-26-0265_Operator_2           0.2999735       0.2325364    TRUE
#> 305   T-26-0266_Operator_1           0.3202343       0.2325364    TRUE
#> 306   T-26-0266_Operator_2           0.3126475       0.2325364    TRUE
#> 309   T-26-0268_Operator_1           0.2975292       0.2325364    TRUE
#> 310   T-26-0268_Operator_2           0.2907089       0.2325364    TRUE
#> 311   T-26-0269_Operator_1           0.3188060       0.2325364    TRUE
#> 312   T-26-0269_Operator_2           0.3135413       0.2325364    TRUE
#> 313 T-26-0270-1_Operator_1           0.3025837       0.2325364    TRUE
#> 314 T-26-0270-1_Operator_2           0.3002619       0.2325364    TRUE
#> 315 T-26-0270-2_Operator_1           0.2849063       0.2325364    TRUE
#> 316 T-26-0270-2_Operator_2           0.2859566       0.2325364    TRUE
#> 317   T-26-0271_Operator_1           0.3477989       0.2325364    TRUE
#> 318   T-26-0271_Operator_2           0.3619167       0.2325364    TRUE
#> 319   T-26-0272_Operator_1           0.2583793       0.2325364    TRUE
#> 320   T-26-0272_Operator_2           0.2624810       0.2325364    TRUE
#> 321   T-26-0273_Operator_1           0.3103109       0.2325364    TRUE
#> 322   T-26-0273_Operator_2           0.3041236       0.2325364    TRUE
#> 323   T-26-0276_Operator_1           0.2806949       0.2325364    TRUE
#> 324   T-26-0276_Operator_2           0.2796489       0.2325364    TRUE
#> 325   T-26-0277_Operator_1           0.2658014       0.2325364    TRUE
#> 326 T-26-0278-1_Operator_1           0.2716006       0.2325364    TRUE
#> 328 T-26-0278-2_Operator_2           0.2329394       0.2325364    TRUE
```
