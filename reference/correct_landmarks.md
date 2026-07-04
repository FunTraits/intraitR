# Manually correct a misplaced landmark using an alignment rule

Applies a documented, reproducible correction to one or more landmark
coordinates for a single specimen, after visual quality-control (e.g.
with
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
has identified a misplaced point – rather than editing digitized
coordinates by hand outside the package, leaving no record of what
changed or why. Currently implements one rule, `"align"`: some landmark
groups are expected, by the digitization protocol, to share the same X
or Y coordinate (e.g. points 9, 8, 11, 4, the ventral reference line
drawn by
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)'s
`outline`); when one of them is visibly off, `correct_landmarks()` snaps
*only* the specified point(s) to the median position of the other,
trusted points in the group – it never silently decides on its own which
point is wrong.

## Usage

``` r
correct_landmarks(
  landmarks,
  specimen = NULL,
  rule = c("align", "check_geometry"),
  points = NULL,
  correct = NULL,
  axis = c("y", "x"),
  tolerance = 2,
  tolerance_coord = 0.02
)

# S3 method for class 'intrait_geometry_check'
print(x, ...)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"`, or a raw `p x k x n`
  landmark array.

- specimen:

  For `rule = "align"`, an integer index or character specimen
  identifier of the single specimen to correct (as in
  [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)).
  For `rule = "check_geometry"`, `NULL` (default) to check every
  specimen, or an integer/character vector to restrict the check to a
  subset.

- rule:

  Character, the operation to perform: `"align"` (default, see Details)
  manually corrects one or more landmark coordinates; `"check_geometry"`
  instead *audits* (without modifying anything) a fixed battery of
  geometric conventions expected of the FISHMORPH landmark scheme (see
  Details) and returns a diagnostic report – a natural first pass to run
  *before* deciding which points, if any, need `rule = "align"`.

- points:

  Integer vector of landmark indices that are expected, for this
  specimen, to share the same `axis` coordinate. Only used by
  `rule = "align"`.

- correct:

  Integer vector, a non-empty subset of `points`: the landmark(s) to
  actually move (i.e. the one(s) visually identified as misplaced).
  Every other point in `points` is treated as a trusted reference for
  computing the corrected value, but is never itself modified. Only used
  by `rule = "align"`.

- axis:

  Character, `"y"` (default) or `"x"`, the coordinate expected to be
  shared across `points`. Only used by `rule = "align"`.

- tolerance:

  Numeric, degrees of angular deviation tolerated before the two
  orientation-based `rule = "check_geometry"` checks
  (`eye_axis_vertical_alignment`, `parallel_vertical_segments`; see
  Details) are flagged as non-conforming. Defaults to `2`. Only used by
  `rule = "check_geometry"`.

- tolerance_coord:

  Numeric, proportion of body length (Bl, the distance between landmarks
  1 and 2) tolerated before one of the five landmark-coordinate-scatter
  `rule = "check_geometry"` checks (see Details) is flagged as
  non-conforming – the same checks
  [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
  acts on, using the identical criterion, so a check flagged here is
  exactly the set
  [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
  will correct. Defaults to `0.02` (2% of body length); tighten or
  loosen based on the digitization precision you expect, e.g. by
  inspecting the distribution of `deviation` for `unit == "rel_bl"` rows
  across your own data set before settling on a final value. Only used
  by `rule = "check_geometry"`.

- x:

  An object of class `"intrait_geometry_check"`, as returned by
  `correct_landmarks(rule = "check_geometry")`.

- ...:

  Currently unused.

## Value

For `rule = "align"`: an object of the same class as `landmarks`, with
`correct`'s `axis` coordinate, for `specimen` only, set to the median
`axis` value of `setdiff(points, correct)`. The returned `coords` array
carries two attributes, both merged with any pre-existing ones from an
earlier `correct_landmarks()` call on the same object, so a full audit
trail accumulates across successive corrections:

- `corrected`:

  a `p x n` logical matrix (as in
  [`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)'s
  `imputed` attribute), `TRUE` where that point has been manually
  corrected; used by
  [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
  to highlight corrected points in blue. Shared with, and merged across,
  [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
  calls on the same object, so a point corrected by either function is
  highlighted the same way.

- `correction_log`:

  a `data.frame`, one row per corrected point across all calls (from
  this function *and* from
  [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md),
  which logs to the same attribute), with columns `specimen`, `check`
  (`"align"` for rows from this function), `landmark`, `axis`,
  `old_value`, `new_value`, `reference_points`, `reference_value`,
  recording exactly what was changed and from what reference, for
  reproducibility (e.g. reporting in a manuscript's methods or a QC log,
  as `data-raw/t26_saudrune_prepare.R` does for the bundled real data
  set).

For `rule = "check_geometry"`: an object of class
`"intrait_geometry_check"` (and `"data.frame"`), one row per
specimen/check combination, with columns `specimen`, `check`,
`deviation` (the measured deviation from the expected convention, in
whatever `unit` this row uses), `unit` (`"deg"` for the two
orientation-based checks, `"rel_bl"` – a proportion of body length – for
the five landmark-coordinate-scatter checks; see Details), `tolerance`
(the `tolerance` or `tolerance_coord` value applicable to this row's
`unit`), and `ok` (logical; `NA` if the check could not be computed
because a required landmark was missing for that specimen). Has a
dedicated print method.

Invisibly returns `x`.

## Details

`rule = "align"` computes the reference value as the *median* (not mean)
of `setdiff(points, correct)`'s `axis` coordinate, for robustness if one
of the trusted reference points also happens to be slightly off; with
very few reference points (e.g. two), this offers little protection and
the correction should be visually re-checked afterwards. Only `specimen`
is modified; every other specimen's landmarks are left untouched. As
with
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
this is not a substitute for re-digitizing from the original photograph
when that is possible.

`rule = "check_geometry"` runs a fixed set of seven checks, of two
different kinds:

Five checks ask whether a landmark group shares the raw coordinate the
FISHMORPH protocol expects of it (`unit = "rel_bl"`, gated by
`tolerance_coord`; identical to the criterion
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
uses to decide what to correct): (1)-(3) each of the segments (1, 9),
(3, 4), (10, 11) should share a common X (i.e. be vertical,
perpendicular to the main body axis) – reported as
`perpendicular_seg_1_9_vs_axis`, `perpendicular_seg_3_4_vs_axis`,
`perpendicular_seg_10_11_vs_axis`; (4) the eye-socket line (5, 13, 7,
14, 6, 8) should likewise share a common X, reported as
`perpendicular_eye_vertical_vs_axis`; (5) the ventral line (9, 8, 11, 4)
should share a common Y (i.e. be horizontal, parallel to the main axis),
reported as `axis_horizontal_parallel`. For each, the deviation is the
absolute difference between the most deviant point's coordinate and the
shared reference value the other point(s) agree on (median, for the two
multi-point groups; a fixed anatomical anchor, for the three two-point
segments – see
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)'s
Details for why), expressed as a proportion of body length (Bl, the
distance between landmarks 1 and 2) so the same default tolerance is
meaningful across specimens/data sets digitized at different scales.

Two further checks remain angular (`unit = "deg"`, gated by
`tolerance`), because they compare the *orientation* of two lines rather
than asking whether a single group of points shares a coordinate, and
are deliberately sensitive to how the photograph itself was oriented:
(6) `eye_axis_vertical_alignment`, whether the eye-socket line's own
best-fit orientation is close to vertical *in the image's own frame*
(i.e. the photograph itself looks reasonably level – this can, and
should, fail for a validly measured but visibly rotated photograph,
which is why it is excluded from
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)'s
`geometry_check` trait-NA-ing); and (7) `parallel_vertical_segments`,
whether segments (1,9), (3,4), (10,11), and the eye-socket line are
mutually parallel to each other (reported as the single largest pairwise
deviation among them). A line's orientation, for these two checks, is
estimated by its first principal axis (via
[`stats::prcomp()`](https://rdrr.io/r/stats/prcomp.html)), which reduces
to the exact two-point direction for two-landmark segments and is a
robust fit for the longer, multi-landmark lines.

Specimens missing a landmark needed by a given check yield `NA` for that
check rather than an error (mirroring the rest of the package's
tolerance of missing landmarks, e.g. `outline` in
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md));
the five coordinate checks additionally yield `NA` if landmark 1 or 2
(needed to compute Bl) is missing.

## See also

[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
(automatic correction of whatever `rule = "check_geometry"` flags,
rather than a manually named point)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
plot_fishmorph_points(fish, specimen = "T-26-0010_Operator_1") # point 11 looks off

fish_fixed <- correct_landmarks(
  fish, specimen = "T-26-0010_Operator_1",
  points = c(9, 8, 11, 4), correct = 11, axis = "y"
)
#> correct_landmarks(): specimen 'T-26-0010_Operator_1', landmark(s) 11: y set to 1664.167 (median of point(s) 4, 8, 9).
plot_fishmorph_points(fish_fixed, specimen = "T-26-0010_Operator_1") # point 11 now in blue


# Audit the FISHMORPH geometric conventions across the whole data set
# before deciding which specimens/points need rule = "align" -- or use
# correct_geometry() to correct every flagged specimen automatically:
geom_check <- correct_landmarks(fish, rule = "check_geometry")
geom_check
#> <intrait_geometry_check>
#>   3906 check(s) across 558 specimen(s): 816 non-conforming, 4 skipped (missing landmark(s))
#>   tolerance = 2.0 deg (orientation checks), 2.0% of body length (coordinate checks)
#> 
#>   Non-conforming:
#>                specimen                              check   deviation   unit
#>    T-26-0001_Operator_1         parallel_vertical_segments  3.94697803    deg
#>    T-26-0001_Operator_2        eye_axis_vertical_alignment  2.28200603    deg
#>    T-26-0002_Operator_1           axis_horizontal_parallel  0.02821111 rel_bl
#>    T-26-0002_Operator_2        eye_axis_vertical_alignment  4.25319850    deg
#>    T-26-0003_Operator_2        eye_axis_vertical_alignment  2.06245324    deg
#>    T-26-0005_Operator_2         parallel_vertical_segments  2.47820697    deg
#>    T-26-0006_Operator_1        eye_axis_vertical_alignment  4.09018689    deg
#>    T-26-0006_Operator_1           axis_horizontal_parallel  0.03378258 rel_bl
#>    T-26-0006_Operator_1         parallel_vertical_segments  3.20423801    deg
#>    T-26-0006_Operator_2        eye_axis_vertical_alignment  4.77894613    deg
#>    T-26-0007_Operator_1         parallel_vertical_segments  2.24034296    deg
#>    T-26-0007_Operator_2        eye_axis_vertical_alignment  3.22705269    deg
#>    T-26-0008_Operator_1           axis_horizontal_parallel  0.02318076 rel_bl
#>    T-26-0008_Operator_1         parallel_vertical_segments  2.93772407    deg
#>    T-26-0009_Operator_2        eye_axis_vertical_alignment  2.09500646    deg
#>    T-26-0010_Operator_1        eye_axis_vertical_alignment  2.26859830    deg
#>    T-26-0010_Operator_1           axis_horizontal_parallel  0.05950329 rel_bl
#>    T-26-0010_Operator_1         parallel_vertical_segments  2.36584189    deg
#>    T-26-0010_Operator_2        eye_axis_vertical_alignment 12.56948418    deg
#>    T-26-0010_Operator_2      perpendicular_seg_3_4_vs_axis  0.02324656 rel_bl
#>    T-26-0010_Operator_2 perpendicular_eye_vertical_vs_axis  0.06934422 rel_bl
#>    T-26-0010_Operator_2         parallel_vertical_segments  9.34496157    deg
#>    T-26-0011_Operator_1         parallel_vertical_segments  3.19793371    deg
#>    T-26-0011_Operator_2        eye_axis_vertical_alignment  2.61665394    deg
#>    T-26-0011_Operator_2      perpendicular_seg_3_4_vs_axis  0.02456198 rel_bl
#>    T-26-0011_Operator_2         parallel_vertical_segments  2.65401682    deg
#>    T-26-0012_Operator_1        eye_axis_vertical_alignment  8.65675239    deg
#>    T-26-0012_Operator_1      perpendicular_seg_3_4_vs_axis  0.02555507 rel_bl
#>    T-26-0012_Operator_1 perpendicular_eye_vertical_vs_axis  0.02305512 rel_bl
#>    T-26-0012_Operator_1           axis_horizontal_parallel  0.03888816 rel_bl
#>    T-26-0012_Operator_1         parallel_vertical_segments  5.01488070    deg
#>    T-26-0012_Operator_2        eye_axis_vertical_alignment 25.11122376    deg
#>    T-26-0012_Operator_2      perpendicular_seg_3_4_vs_axis  0.02515610 rel_bl
#>    T-26-0012_Operator_2 perpendicular_eye_vertical_vs_axis  0.17101063 rel_bl
#>    T-26-0012_Operator_2           axis_horizontal_parallel  0.02802398 rel_bl
#>    T-26-0012_Operator_2         parallel_vertical_segments 31.51557649    deg
#>    T-26-0013_Operator_2        eye_axis_vertical_alignment  2.55571738    deg
#>    T-26-0014_Operator_1        eye_axis_vertical_alignment  3.76617362    deg
#>    T-26-0015_Operator_2        eye_axis_vertical_alignment  2.20407713    deg
#>    T-26-0016_Operator_1        eye_axis_vertical_alignment  2.85329402    deg
#>    T-26-0016_Operator_2        eye_axis_vertical_alignment  3.22124248    deg
#>    T-26-0016_Operator_2         parallel_vertical_segments  2.36101014    deg
#>    T-26-0017_Operator_2        eye_axis_vertical_alignment  3.18736306    deg
#>    T-26-0018_Operator_1        eye_axis_vertical_alignment  2.11104863    deg
#>    T-26-0018_Operator_2 perpendicular_eye_vertical_vs_axis  0.03830315 rel_bl
#>    T-26-0018_Operator_2         parallel_vertical_segments  5.62192403    deg
#>    T-26-0019_Operator_2        eye_axis_vertical_alignment  2.35075447    deg
#>    T-26-0020_Operator_2        eye_axis_vertical_alignment 19.13620270    deg
#>    T-26-0020_Operator_2 perpendicular_eye_vertical_vs_axis  0.14201665 rel_bl
#>    T-26-0020_Operator_2         parallel_vertical_segments 19.08358083    deg
#>    T-26-0022_Operator_1           axis_horizontal_parallel  0.03417441 rel_bl
#>    T-26-0022_Operator_2        eye_axis_vertical_alignment  6.66698299    deg
#>    T-26-0022_Operator_2      perpendicular_seg_3_4_vs_axis  0.02467105 rel_bl
#>    T-26-0022_Operator_2           axis_horizontal_parallel  0.03015350 rel_bl
#>  T-26-0023-2_Operator_2        eye_axis_vertical_alignment  2.13398457    deg
#>  T-26-0023-2_Operator_2         parallel_vertical_segments  2.42316155    deg
#>    T-26-0024_Operator_1        eye_axis_vertical_alignment 14.16684410    deg
#>    T-26-0024_Operator_1      perpendicular_seg_1_9_vs_axis  0.03559121 rel_bl
#>    T-26-0024_Operator_1      perpendicular_seg_3_4_vs_axis  0.06206868 rel_bl
#>    T-26-0024_Operator_1    perpendicular_seg_10_11_vs_axis  0.03152646 rel_bl
#>    T-26-0024_Operator_1 perpendicular_eye_vertical_vs_axis  0.04802897 rel_bl
#>    T-26-0024_Operator_1           axis_horizontal_parallel  0.04014735 rel_bl
#>    T-26-0024_Operator_2        eye_axis_vertical_alignment  7.26161769    deg
#>    T-26-0024_Operator_2      perpendicular_seg_3_4_vs_axis  0.03248931 rel_bl
#>    T-26-0024_Operator_2 perpendicular_eye_vertical_vs_axis  0.02588972 rel_bl
#>    T-26-0024_Operator_2           axis_horizontal_parallel  0.03807311 rel_bl
#>    T-26-0025_Operator_2        eye_axis_vertical_alignment  2.80012352    deg
#>    T-26-0025_Operator_2           axis_horizontal_parallel  0.02034419 rel_bl
#>    T-26-0026_Operator_1        eye_axis_vertical_alignment  3.05152993    deg
#>    T-26-0026_Operator_2        eye_axis_vertical_alignment  3.91131424    deg
#>    T-26-0027_Operator_2        eye_axis_vertical_alignment  3.01144837    deg
#>    T-26-0028_Operator_2        eye_axis_vertical_alignment  3.27027789    deg
#>    T-26-0029_Operator_1        eye_axis_vertical_alignment 10.77486308    deg
#>    T-26-0029_Operator_1      perpendicular_seg_1_9_vs_axis  0.03982603 rel_bl
#>    T-26-0029_Operator_1      perpendicular_seg_3_4_vs_axis  0.07241096 rel_bl
#>    T-26-0029_Operator_1 perpendicular_eye_vertical_vs_axis  0.04043066 rel_bl
#>    T-26-0029_Operator_1           axis_horizontal_parallel  0.04404940 rel_bl
#>    T-26-0029_Operator_1         parallel_vertical_segments  9.18016816    deg
#>    T-26-0029_Operator_2        eye_axis_vertical_alignment  6.45902321    deg
#>    T-26-0029_Operator_2      perpendicular_seg_1_9_vs_axis  0.02040676 rel_bl
#>    T-26-0029_Operator_2      perpendicular_seg_3_4_vs_axis  0.04353441 rel_bl
#>    T-26-0029_Operator_2 perpendicular_eye_vertical_vs_axis  0.02478922 rel_bl
#>    T-26-0029_Operator_2           axis_horizontal_parallel  0.04353441 rel_bl
#>    T-26-0030_Operator_2         parallel_vertical_segments  3.67173590    deg
#>    T-26-0031_Operator_1           axis_horizontal_parallel  0.03598045 rel_bl
#>    T-26-0031_Operator_2        eye_axis_vertical_alignment 18.09447130    deg
#>    T-26-0031_Operator_2      perpendicular_seg_3_4_vs_axis  0.02661882 rel_bl
#>    T-26-0031_Operator_2 perpendicular_eye_vertical_vs_axis  0.10647528 rel_bl
#>    T-26-0031_Operator_2           axis_horizontal_parallel  0.02972435 rel_bl
#>    T-26-0031_Operator_2         parallel_vertical_segments 13.24765166    deg
#>    T-26-0032_Operator_2        eye_axis_vertical_alignment  4.17053787    deg
#>    T-26-0032_Operator_2           axis_horizontal_parallel  0.02079181 rel_bl
#>    T-26-0033_Operator_1         parallel_vertical_segments  2.20761771    deg
#>    T-26-0034_Operator_1        eye_axis_vertical_alignment  9.48089875    deg
#>    T-26-0034_Operator_1      perpendicular_seg_1_9_vs_axis  0.02636274 rel_bl
#>    T-26-0034_Operator_1      perpendicular_seg_3_4_vs_axis  0.04909913 rel_bl
#>    T-26-0034_Operator_1    perpendicular_seg_10_11_vs_axis  0.02399093 rel_bl
#>    T-26-0034_Operator_1 perpendicular_eye_vertical_vs_axis  0.03403471 rel_bl
#>    T-26-0034_Operator_1           axis_horizontal_parallel  0.04909913 rel_bl
#>    T-26-0034_Operator_2        eye_axis_vertical_alignment 10.15503230    deg
#>    T-26-0034_Operator_2      perpendicular_seg_1_9_vs_axis  0.03101018 rel_bl
#>    T-26-0034_Operator_2      perpendicular_seg_3_4_vs_axis  0.05172952 rel_bl
#>    T-26-0034_Operator_2    perpendicular_seg_10_11_vs_axis  0.02669911 rel_bl
#>    T-26-0034_Operator_2 perpendicular_eye_vertical_vs_axis  0.03817138 rel_bl
#>    T-26-0034_Operator_2           axis_horizontal_parallel  0.04630626 rel_bl
#>    T-26-0035_Operator_2         parallel_vertical_segments  2.02407753    deg
#>    T-26-0037_Operator_2        eye_axis_vertical_alignment  3.84899937    deg
#>    T-26-0040_Operator_1        eye_axis_vertical_alignment  8.11951704    deg
#>    T-26-0040_Operator_1      perpendicular_seg_3_4_vs_axis  0.03583418 rel_bl
#>    T-26-0040_Operator_1 perpendicular_eye_vertical_vs_axis  0.02391159 rel_bl
#>    T-26-0040_Operator_1           axis_horizontal_parallel  0.03715188 rel_bl
#>    T-26-0040_Operator_2        eye_axis_vertical_alignment  7.01534806    deg
#>    T-26-0040_Operator_2      perpendicular_seg_3_4_vs_axis  0.02850116 rel_bl
#>    T-26-0040_Operator_2 perpendicular_eye_vertical_vs_axis  0.02261386 rel_bl
#>    T-26-0040_Operator_2           axis_horizontal_parallel  0.02930401 rel_bl
#>    T-26-0041_Operator_1        eye_axis_vertical_alignment  2.02137210    deg
#>    T-26-0041_Operator_1           axis_horizontal_parallel  0.02040660 rel_bl
#>    T-26-0041_Operator_1         parallel_vertical_segments  2.62485419    deg
#>    T-26-0041_Operator_2        eye_axis_vertical_alignment  3.34613548    deg
#>    T-26-0041_Operator_2         parallel_vertical_segments  2.16193460    deg
#>    T-26-0042_Operator_1        eye_axis_vertical_alignment  2.91622456    deg
#>    T-26-0042_Operator_2        eye_axis_vertical_alignment  3.88064964    deg
#>    T-26-0043_Operator_2        eye_axis_vertical_alignment  3.52886621    deg
#>    T-26-0043_Operator_2           axis_horizontal_parallel  0.02246577 rel_bl
#>    T-26-0044_Operator_1        eye_axis_vertical_alignment  2.12645356    deg
#>    T-26-0044_Operator_2        eye_axis_vertical_alignment  6.70589142    deg
#>    T-26-0044_Operator_2 perpendicular_eye_vertical_vs_axis  0.03912003 rel_bl
#>    T-26-0044_Operator_2         parallel_vertical_segments  3.41035563    deg
#>    T-26-0045_Operator_2        eye_axis_vertical_alignment  2.45635832    deg
#>    T-26-0046_Operator_2        eye_axis_vertical_alignment  2.37207268    deg
#>    T-26-0047_Operator_2        eye_axis_vertical_alignment  2.71315972    deg
#>    T-26-0048_Operator_1           axis_horizontal_parallel  0.02106421 rel_bl
#>    T-26-0048_Operator_1         parallel_vertical_segments  2.39327667    deg
#>    T-26-0048_Operator_2        eye_axis_vertical_alignment  3.53379334    deg
#>    T-26-0048_Operator_2         parallel_vertical_segments  2.18431183    deg
#>    T-26-0049_Operator_1        eye_axis_vertical_alignment  2.46165855    deg
#>    T-26-0049_Operator_1           axis_horizontal_parallel  0.03899065 rel_bl
#>    T-26-0049_Operator_2        eye_axis_vertical_alignment  3.94845583    deg
#>    T-26-0049_Operator_2           axis_horizontal_parallel  0.03043320 rel_bl
#>    T-26-0050_Operator_1         parallel_vertical_segments  2.63536778    deg
#>    T-26-0050_Operator_2        eye_axis_vertical_alignment 45.00000000    deg
#>    T-26-0050_Operator_2           axis_horizontal_parallel  0.22007925 rel_bl
#>    T-26-0051_Operator_1        eye_axis_vertical_alignment  2.12594486    deg
#>    T-26-0052_Operator_1        eye_axis_vertical_alignment  2.47607111    deg
#>    T-26-0052_Operator_1           axis_horizontal_parallel  0.17349589 rel_bl
#>    T-26-0052_Operator_1         parallel_vertical_segments  6.99188758    deg
#>    T-26-0052_Operator_2        eye_axis_vertical_alignment  6.36773820    deg
#>    T-26-0052_Operator_2      perpendicular_seg_3_4_vs_axis  0.02808398 rel_bl
#>    T-26-0052_Operator_2           axis_horizontal_parallel  0.03446670 rel_bl
#>    T-26-0053_Operator_1        eye_axis_vertical_alignment  2.60442503    deg
#>    T-26-0053_Operator_2        eye_axis_vertical_alignment  5.15277791    deg
#>    T-26-0053_Operator_2      perpendicular_seg_3_4_vs_axis  0.02334124 rel_bl
#>    T-26-0053_Operator_2           axis_horizontal_parallel  0.02216669 rel_bl
#>    T-26-0054_Operator_2        eye_axis_vertical_alignment  2.83987734    deg
#>    T-26-0055_Operator_2        eye_axis_vertical_alignment  2.71947019    deg
#>  T-26-0056-2_Operator_2        eye_axis_vertical_alignment  4.71313225    deg
#>  T-26-0056-2_Operator_2      perpendicular_seg_3_4_vs_axis  0.02332223 rel_bl
#>  T-26-0056-2_Operator_2           axis_horizontal_parallel  0.02190858 rel_bl
#>    T-26-0058_Operator_1        eye_axis_vertical_alignment  4.88838220    deg
#>    T-26-0058_Operator_1      perpendicular_seg_3_4_vs_axis  0.04173741 rel_bl
#>    T-26-0058_Operator_1 perpendicular_eye_vertical_vs_axis  0.02192983 rel_bl
#>    T-26-0058_Operator_1           axis_horizontal_parallel  0.03395586 rel_bl
#>    T-26-0058_Operator_1         parallel_vertical_segments  3.90534815    deg
#>    T-26-0058_Operator_2        eye_axis_vertical_alignment  4.93466560    deg
#>    T-26-0058_Operator_2      perpendicular_seg_3_4_vs_axis  0.02417451 rel_bl
#>    T-26-0058_Operator_2           axis_horizontal_parallel  0.03235118 rel_bl
#>    T-26-0059_Operator_1         parallel_vertical_segments  2.71002505    deg
#>    T-26-0059_Operator_2        eye_axis_vertical_alignment  2.40688716    deg
#>    T-26-0060_Operator_1        eye_axis_vertical_alignment  2.43941566    deg
#>    T-26-0061_Operator_2        eye_axis_vertical_alignment  4.18495318    deg
#>    T-26-0061_Operator_2           axis_horizontal_parallel  0.02479981 rel_bl
#>    T-26-0062_Operator_2        eye_axis_vertical_alignment  2.38847839    deg
#>    T-26-0063_Operator_1        eye_axis_vertical_alignment  3.30779874    deg
#>    T-26-0063_Operator_1           axis_horizontal_parallel  0.02016057 rel_bl
#>    T-26-0064_Operator_2        eye_axis_vertical_alignment  2.81048498    deg
#>    T-26-0064_Operator_2         parallel_vertical_segments  2.15526636    deg
#>    T-26-0065_Operator_1        eye_axis_vertical_alignment  2.82391657    deg
#>    T-26-0067_Operator_1        eye_axis_vertical_alignment  2.16534710    deg
#>    T-26-0068_Operator_1        eye_axis_vertical_alignment  2.01777256    deg
#>    T-26-0068_Operator_1           axis_horizontal_parallel  0.02815827 rel_bl
#>    T-26-0068_Operator_2        eye_axis_vertical_alignment  4.57155395    deg
#>    T-26-0068_Operator_2           axis_horizontal_parallel  0.03292460 rel_bl
#>    T-26-0069_Operator_1        eye_axis_vertical_alignment  4.67930146    deg
#>    T-26-0069_Operator_1      perpendicular_seg_3_4_vs_axis  0.02447469 rel_bl
#>    T-26-0069_Operator_1           axis_horizontal_parallel  0.03897866 rel_bl
#>    T-26-0069_Operator_1         parallel_vertical_segments  4.41476165    deg
#>    T-26-0069_Operator_2        eye_axis_vertical_alignment  8.48631960    deg
#>    T-26-0069_Operator_2      perpendicular_seg_1_9_vs_axis  0.02279747 rel_bl
#>    T-26-0069_Operator_2      perpendicular_seg_3_4_vs_axis  0.03742868 rel_bl
#>    T-26-0069_Operator_2           axis_horizontal_parallel  0.04446050 rel_bl
#>    T-26-0070_Operator_1           axis_horizontal_parallel  0.02024682 rel_bl
#>    T-26-0070_Operator_2        eye_axis_vertical_alignment  4.52486426    deg
#>    T-26-0070_Operator_2      perpendicular_seg_3_4_vs_axis  0.02088347 rel_bl
#>    T-26-0070_Operator_2           axis_horizontal_parallel  0.02028680 rel_bl
#>    T-26-0073_Operator_1           axis_horizontal_parallel  0.02124137 rel_bl
#>    T-26-0073_Operator_2        eye_axis_vertical_alignment  3.40459086    deg
#>    T-26-0073_Operator_2           axis_horizontal_parallel  0.02842332 rel_bl
#>    T-26-0076_Operator_1        eye_axis_vertical_alignment  5.02821091    deg
#>    T-26-0076_Operator_1      perpendicular_seg_3_4_vs_axis  0.03548778 rel_bl
#>    T-26-0076_Operator_1           axis_horizontal_parallel  0.05224590 rel_bl
#>    T-26-0076_Operator_1         parallel_vertical_segments  6.77055322    deg
#>    T-26-0076_Operator_2        eye_axis_vertical_alignment  9.60334903    deg
#>    T-26-0076_Operator_2      perpendicular_seg_1_9_vs_axis  0.02671371 rel_bl
#>    T-26-0076_Operator_2      perpendicular_seg_3_4_vs_axis  0.04102208 rel_bl
#>    T-26-0076_Operator_2 perpendicular_eye_vertical_vs_axis  0.02448066 rel_bl
#>    T-26-0076_Operator_2           axis_horizontal_parallel  0.06285584 rel_bl
#>    T-26-0076_Operator_2         parallel_vertical_segments  2.15425231    deg
#>    T-26-0077_Operator_1        eye_axis_vertical_alignment  2.21499565    deg
#>    T-26-0077_Operator_1           axis_horizontal_parallel  0.02670172 rel_bl
#>    T-26-0077_Operator_2        eye_axis_vertical_alignment  3.85744468    deg
#>    T-26-0077_Operator_2           axis_horizontal_parallel  0.02732622 rel_bl
#>    T-26-0077_Operator_2         parallel_vertical_segments  2.19631795    deg
#>    T-26-0080_Operator_2        eye_axis_vertical_alignment  2.01138397    deg
#>    T-26-0081_Operator_1        eye_axis_vertical_alignment  3.24776193    deg
#>    T-26-0081_Operator_1      perpendicular_seg_3_4_vs_axis  0.02367669 rel_bl
#>    T-26-0081_Operator_1           axis_horizontal_parallel  0.04197136 rel_bl
#>    T-26-0081_Operator_1         parallel_vertical_segments  4.73093125    deg
#>    T-26-0081_Operator_2        eye_axis_vertical_alignment  6.50205554    deg
#>    T-26-0081_Operator_2      perpendicular_seg_3_4_vs_axis  0.02409123 rel_bl
#>    T-26-0081_Operator_2           axis_horizontal_parallel  0.04095509 rel_bl
#>    T-26-0081_Operator_2         parallel_vertical_segments  2.10470041    deg
#>    T-26-0082_Operator_1           axis_horizontal_parallel  0.04604035 rel_bl
#>    T-26-0082_Operator_2        eye_axis_vertical_alignment  9.83565762    deg
#>    T-26-0082_Operator_2      perpendicular_seg_1_9_vs_axis  0.03138591 rel_bl
#>    T-26-0082_Operator_2      perpendicular_seg_3_4_vs_axis  0.04347630 rel_bl
#>    T-26-0082_Operator_2 perpendicular_eye_vertical_vs_axis  0.02686777 rel_bl
#>    T-26-0082_Operator_2           axis_horizontal_parallel  0.05129255 rel_bl
#>    T-26-0083_Operator_1        eye_axis_vertical_alignment  4.62758698    deg
#>    T-26-0083_Operator_1      perpendicular_seg_3_4_vs_axis  0.02394757 rel_bl
#>    T-26-0083_Operator_1           axis_horizontal_parallel  0.03911476 rel_bl
#>    T-26-0083_Operator_1         parallel_vertical_segments  4.43309549    deg
#>    T-26-0083_Operator_2        eye_axis_vertical_alignment  8.02577808    deg
#>    T-26-0083_Operator_2      perpendicular_seg_1_9_vs_axis  0.02028232 rel_bl
#>    T-26-0083_Operator_2      perpendicular_seg_3_4_vs_axis  0.03280964 rel_bl
#>    T-26-0083_Operator_2 perpendicular_eye_vertical_vs_axis  0.02594944 rel_bl
#>    T-26-0083_Operator_2           axis_horizontal_parallel  0.03996810 rel_bl
#>    T-26-0084_Operator_1        eye_axis_vertical_alignment  5.71583634    deg
#>    T-26-0084_Operator_1      perpendicular_seg_3_4_vs_axis  0.02169043 rel_bl
#>    T-26-0084_Operator_1 perpendicular_eye_vertical_vs_axis  0.03158012 rel_bl
#>    T-26-0084_Operator_1           axis_horizontal_parallel  0.05040015 rel_bl
#>    T-26-0084_Operator_1         parallel_vertical_segments  5.63412100    deg
#>    T-26-0084_Operator_2        eye_axis_vertical_alignment  8.13210756    deg
#>    T-26-0084_Operator_2      perpendicular_seg_3_4_vs_axis  0.03836664 rel_bl
#>    T-26-0084_Operator_2 perpendicular_eye_vertical_vs_axis  0.02736006 rel_bl
#>    T-26-0084_Operator_2           axis_horizontal_parallel  0.04654244 rel_bl
#>    T-26-0084_Operator_2         parallel_vertical_segments  3.50662903    deg
#>    T-26-0085_Operator_2        eye_axis_vertical_alignment  2.04781455    deg
#>    T-26-0085_Operator_2         parallel_vertical_segments  2.41147776    deg
#>    T-26-0086_Operator_2        eye_axis_vertical_alignment  3.48443044    deg
#>    T-26-0087_Operator_1        eye_axis_vertical_alignment  2.48487995    deg
#>    T-26-0087_Operator_1         parallel_vertical_segments  2.71112950    deg
#>    T-26-0087_Operator_2        eye_axis_vertical_alignment 16.56975592    deg
#>    T-26-0087_Operator_2 perpendicular_eye_vertical_vs_axis  0.13075066 rel_bl
#>    T-26-0087_Operator_2         parallel_vertical_segments 17.73889525    deg
#>    T-26-0088_Operator_1        eye_axis_vertical_alignment  4.05024607    deg
#>    T-26-0088_Operator_1      perpendicular_seg_3_4_vs_axis  0.02297832 rel_bl
#>    T-26-0088_Operator_2        eye_axis_vertical_alignment  6.04763744    deg
#>    T-26-0088_Operator_2      perpendicular_seg_3_4_vs_axis  0.03005284 rel_bl
#>    T-26-0088_Operator_2           axis_horizontal_parallel  0.03492560 rel_bl
#>    T-26-0089_Operator_1        eye_axis_vertical_alignment  5.99146521    deg
#>    T-26-0089_Operator_1      perpendicular_seg_3_4_vs_axis  0.02903216 rel_bl
#>    T-26-0089_Operator_1           axis_horizontal_parallel  0.06008982 rel_bl
#>    T-26-0089_Operator_1         parallel_vertical_segments  9.78004837    deg
#>    T-26-0089_Operator_2        eye_axis_vertical_alignment  8.10883495    deg
#>    T-26-0089_Operator_2      perpendicular_seg_3_4_vs_axis  0.03144470 rel_bl
#>    T-26-0089_Operator_2           axis_horizontal_parallel  0.04238199 rel_bl
#>    T-26-0090_Operator_1         parallel_vertical_segments  3.75019748    deg
#>    T-26-0091_Operator_1        eye_axis_vertical_alignment  3.34361016    deg
#>    T-26-0091_Operator_2        eye_axis_vertical_alignment  2.43533595    deg
#>    T-26-0091_Operator_2         parallel_vertical_segments  2.42246654    deg
#>    T-26-0092_Operator_1        eye_axis_vertical_alignment  3.61131498    deg
#>    T-26-0092_Operator_1      perpendicular_seg_3_4_vs_axis  0.02118528 rel_bl
#>    T-26-0092_Operator_1           axis_horizontal_parallel  0.03656233 rel_bl
#>    T-26-0092_Operator_2        eye_axis_vertical_alignment  7.99761904    deg
#>    T-26-0092_Operator_2      perpendicular_seg_1_9_vs_axis  0.02263311 rel_bl
#>    T-26-0092_Operator_2      perpendicular_seg_3_4_vs_axis  0.04266471 rel_bl
#>    T-26-0092_Operator_2 perpendicular_eye_vertical_vs_axis  0.02549477 rel_bl
#>    T-26-0092_Operator_2           axis_horizontal_parallel  0.04734742 rel_bl
#>    T-26-0093_Operator_1        eye_axis_vertical_alignment  3.50702991    deg
#>    T-26-0093_Operator_1           axis_horizontal_parallel  0.02475559 rel_bl
#>    T-26-0093_Operator_2        eye_axis_vertical_alignment  4.46844811    deg
#>    T-26-0093_Operator_2      perpendicular_seg_3_4_vs_axis  0.02133377 rel_bl
#>    T-26-0093_Operator_2           axis_horizontal_parallel  0.02694793 rel_bl
#>    T-26-0094_Operator_1        eye_axis_vertical_alignment  6.69613043    deg
#>    T-26-0094_Operator_1      perpendicular_seg_1_9_vs_axis  0.02174779 rel_bl
#>    T-26-0094_Operator_1      perpendicular_seg_3_4_vs_axis  0.02877401 rel_bl
#>    T-26-0094_Operator_1 perpendicular_eye_vertical_vs_axis  0.02007489 rel_bl
#>    T-26-0094_Operator_1           axis_horizontal_parallel  0.03948061 rel_bl
#>    T-26-0094_Operator_1         parallel_vertical_segments  8.42533655    deg
#>    T-26-0094_Operator_2        eye_axis_vertical_alignment  5.15115871    deg
#>    T-26-0094_Operator_2      perpendicular_seg_3_4_vs_axis  0.02422050 rel_bl
#>    T-26-0094_Operator_2           axis_horizontal_parallel  0.02960284 rel_bl
#>    T-26-0095_Operator_1        eye_axis_vertical_alignment  4.58606775    deg
#>    T-26-0095_Operator_1           axis_horizontal_parallel  0.03893721 rel_bl
#>    T-26-0095_Operator_1         parallel_vertical_segments  2.71994811    deg
#>    T-26-0095_Operator_2        eye_axis_vertical_alignment  5.59617666    deg
#>    T-26-0095_Operator_2      perpendicular_seg_3_4_vs_axis  0.02497145 rel_bl
#>    T-26-0095_Operator_2           axis_horizontal_parallel  0.03654359 rel_bl
#>    T-26-0095_Operator_2         parallel_vertical_segments  4.84019974    deg
#>    T-26-0096_Operator_1        eye_axis_vertical_alignment  4.54055350    deg
#>    T-26-0096_Operator_1      perpendicular_seg_3_4_vs_axis  0.02983129 rel_bl
#>    T-26-0096_Operator_1           axis_horizontal_parallel  0.06179338 rel_bl
#>    T-26-0096_Operator_1         parallel_vertical_segments  5.46562017    deg
#>    T-26-0096_Operator_2        eye_axis_vertical_alignment 12.53258096    deg
#>    T-26-0096_Operator_2      perpendicular_seg_1_9_vs_axis  0.02281177 rel_bl
#>    T-26-0096_Operator_2      perpendicular_seg_3_4_vs_axis  0.05358956 rel_bl
#>    T-26-0096_Operator_2    perpendicular_seg_10_11_vs_axis  0.02027713 rel_bl
#>    T-26-0096_Operator_2 perpendicular_eye_vertical_vs_axis  0.04127844 rel_bl
#>    T-26-0096_Operator_2           axis_horizontal_parallel  0.05793465 rel_bl
#>    T-26-0096_Operator_2         parallel_vertical_segments  3.94135552    deg
#>    T-26-0098_Operator_2        eye_axis_vertical_alignment  5.78886803    deg
#>    T-26-0098_Operator_2      perpendicular_seg_3_4_vs_axis  0.02741126 rel_bl
#>    T-26-0098_Operator_2           axis_horizontal_parallel  0.02323998 rel_bl
#>    T-26-0098_Operator_2         parallel_vertical_segments  2.34123433    deg
#>    T-26-0099_Operator_2        eye_axis_vertical_alignment  4.77376813    deg
#>    T-26-0099_Operator_2         parallel_vertical_segments  3.57691354    deg
#>    T-26-0100_Operator_1        eye_axis_vertical_alignment  3.12127767    deg
#>    T-26-0100_Operator_2        eye_axis_vertical_alignment 17.03670102    deg
#>    T-26-0100_Operator_2 perpendicular_eye_vertical_vs_axis  0.12956675 rel_bl
#>    T-26-0100_Operator_2         parallel_vertical_segments 19.88135663    deg
#>    T-26-0101_Operator_1        eye_axis_vertical_alignment  7.37948326    deg
#>    T-26-0101_Operator_1      perpendicular_seg_3_4_vs_axis  0.05518756 rel_bl
#>    T-26-0101_Operator_1 perpendicular_eye_vertical_vs_axis  0.03425434 rel_bl
#>    T-26-0101_Operator_1           axis_horizontal_parallel  0.02093321 rel_bl
#>    T-26-0101_Operator_1         parallel_vertical_segments 17.40739203    deg
#>    T-26-0102_Operator_1        eye_axis_vertical_alignment  5.40005948    deg
#>    T-26-0102_Operator_1      perpendicular_seg_1_9_vs_axis  0.07049423 rel_bl
#>    T-26-0102_Operator_1 perpendicular_eye_vertical_vs_axis  0.03698576 rel_bl
#>    T-26-0102_Operator_1         parallel_vertical_segments 30.36454430    deg
#>    T-26-0102_Operator_2         parallel_vertical_segments  3.76409522    deg
#>    T-26-0103_Operator_1        eye_axis_vertical_alignment  2.21262798    deg
#>    T-26-0103_Operator_1         parallel_vertical_segments  8.55281973    deg
#>    T-26-0104_Operator_1        eye_axis_vertical_alignment  3.62250759    deg
#>    T-26-0104_Operator_1 perpendicular_eye_vertical_vs_axis  0.03122564 rel_bl
#>    T-26-0104_Operator_1         parallel_vertical_segments  5.01968862    deg
#>    T-26-0104_Operator_2        eye_axis_vertical_alignment  2.45519827    deg
#>    T-26-0107_Operator_1        eye_axis_vertical_alignment  7.21059771    deg
#>    T-26-0107_Operator_1 perpendicular_eye_vertical_vs_axis  0.04131456 rel_bl
#>    T-26-0107_Operator_1         parallel_vertical_segments  8.11118271    deg
#>    T-26-0107_Operator_2        eye_axis_vertical_alignment  2.62687073    deg
#>    T-26-0108_Operator_1        eye_axis_vertical_alignment 17.03412600    deg
#>    T-26-0108_Operator_1 perpendicular_eye_vertical_vs_axis  0.05473784 rel_bl
#>    T-26-0108_Operator_1         parallel_vertical_segments 17.03412600    deg
#>    T-26-0108_Operator_2         parallel_vertical_segments  2.06382687    deg
#>    T-26-0109_Operator_1        eye_axis_vertical_alignment  8.81311798    deg
#>    T-26-0109_Operator_1    perpendicular_seg_10_11_vs_axis  0.20430603 rel_bl
#>    T-26-0109_Operator_1 perpendicular_eye_vertical_vs_axis  0.03236531 rel_bl
#>    T-26-0109_Operator_1           axis_horizontal_parallel  0.09911877 rel_bl
#>    T-26-0109_Operator_1         parallel_vertical_segments 86.27899715    deg
#>    T-26-0111_Operator_1        eye_axis_vertical_alignment 22.53650256    deg
#>    T-26-0111_Operator_1      perpendicular_seg_1_9_vs_axis  0.04879751 rel_bl
#>    T-26-0111_Operator_1    perpendicular_seg_10_11_vs_axis  0.03787270 rel_bl
#>    T-26-0111_Operator_1 perpendicular_eye_vertical_vs_axis  0.08594189 rel_bl
#>    T-26-0111_Operator_1           axis_horizontal_parallel  0.02039299 rel_bl
#>    T-26-0111_Operator_1         parallel_vertical_segments 40.91438322    deg
#>    T-26-0111_Operator_2        eye_axis_vertical_alignment  3.39522749    deg
#>    T-26-0111_Operator_2           axis_horizontal_parallel  0.02278401 rel_bl
#>    T-26-0111_Operator_2         parallel_vertical_segments  2.46811791    deg
#>  T-26-0112-2_Operator_1           axis_horizontal_parallel  0.02079454 rel_bl
#>  T-26-0112-2_Operator_2        eye_axis_vertical_alignment  3.08013764    deg
#>    T-26-0112_Operator_1           axis_horizontal_parallel  0.03210157 rel_bl
#>    T-26-0112_Operator_2        eye_axis_vertical_alignment  5.20342771    deg
#>    T-26-0112_Operator_2           axis_horizontal_parallel  0.02194244 rel_bl
#>    T-26-0112_Operator_2         parallel_vertical_segments  2.54270624    deg
#>    T-26-0113_Operator_1           axis_horizontal_parallel  0.02292337 rel_bl
#>    T-26-0113_Operator_2        eye_axis_vertical_alignment  7.85704435    deg
#>    T-26-0113_Operator_2      perpendicular_seg_3_4_vs_axis  0.03094785 rel_bl
#>    T-26-0113_Operator_2           axis_horizontal_parallel  0.04155847 rel_bl
#>    T-26-0114_Operator_2        eye_axis_vertical_alignment  3.24428388    deg
#>    T-26-0115_Operator_2        eye_axis_vertical_alignment  3.33671348    deg
#>    T-26-0116_Operator_2        eye_axis_vertical_alignment  2.89146868    deg
#>    T-26-0116_Operator_2           axis_horizontal_parallel  0.02418897 rel_bl
#>    T-26-0117_Operator_2        eye_axis_vertical_alignment  2.13262522    deg
#>    T-26-0118_Operator_2        eye_axis_vertical_alignment  5.40005741    deg
#>    T-26-0118_Operator_2      perpendicular_seg_3_4_vs_axis  0.02169925 rel_bl
#>    T-26-0118_Operator_2           axis_horizontal_parallel  0.02169983 rel_bl
#>    T-26-0118_Operator_2         parallel_vertical_segments  3.03404089    deg
#>    T-26-0120_Operator_2        eye_axis_vertical_alignment  3.28777277    deg
#>    T-26-0120_Operator_2           axis_horizontal_parallel  0.02232568 rel_bl
#>    T-26-0120_Operator_2         parallel_vertical_segments  4.50226979    deg
#>    T-26-0121_Operator_2        eye_axis_vertical_alignment 45.00000000    deg
#>    T-26-0121_Operator_2      perpendicular_seg_1_9_vs_axis  4.08652620 rel_bl
#>    T-26-0121_Operator_2      perpendicular_seg_3_4_vs_axis  7.58532729 rel_bl
#>    T-26-0121_Operator_2    perpendicular_seg_10_11_vs_axis  2.58966380 rel_bl
#>    T-26-0121_Operator_2 perpendicular_eye_vertical_vs_axis  5.00484670 rel_bl
#>    T-26-0121_Operator_2           axis_horizontal_parallel  0.25712974 rel_bl
#>    T-26-0122_Operator_1        eye_axis_vertical_alignment  4.62979605    deg
#>    T-26-0122_Operator_1         parallel_vertical_segments  4.35292792    deg
#>    T-26-0122_Operator_2        eye_axis_vertical_alignment  3.89508258    deg
#>    T-26-0123_Operator_1        eye_axis_vertical_alignment  7.23230578    deg
#>    T-26-0123_Operator_1      perpendicular_seg_3_4_vs_axis  0.03099258 rel_bl
#>    T-26-0123_Operator_1           axis_horizontal_parallel  0.05739366 rel_bl
#>    T-26-0123_Operator_2        eye_axis_vertical_alignment  7.23957755    deg
#>    T-26-0123_Operator_2      perpendicular_seg_3_4_vs_axis  0.03004489 rel_bl
#>    T-26-0123_Operator_2 perpendicular_eye_vertical_vs_axis  0.02002954 rel_bl
#>    T-26-0123_Operator_2           axis_horizontal_parallel  0.04564513 rel_bl
#>    T-26-0123_Operator_2         parallel_vertical_segments  2.22439456    deg
#>    T-26-0125_Operator_2        eye_axis_vertical_alignment  2.71983388    deg
#>    T-26-0127_Operator_1        eye_axis_vertical_alignment  2.19475597    deg
#>    T-26-0127_Operator_2        eye_axis_vertical_alignment  5.46401864    deg
#>    T-26-0127_Operator_2      perpendicular_seg_3_4_vs_axis  0.02765882 rel_bl
#>    T-26-0127_Operator_2           axis_horizontal_parallel  0.02021222 rel_bl
#>    T-26-0128_Operator_1        eye_axis_vertical_alignment  2.80819718    deg
#>    T-26-0128_Operator_1           axis_horizontal_parallel  0.02066617 rel_bl
#>    T-26-0128_Operator_1         parallel_vertical_segments  2.21753997    deg
#>    T-26-0128_Operator_2        eye_axis_vertical_alignment  2.62655875    deg
#>    T-26-0128_Operator_2         parallel_vertical_segments  2.23892954    deg
#>    T-26-0130_Operator_1        eye_axis_vertical_alignment  3.31443403    deg
#>    T-26-0130_Operator_1           axis_horizontal_parallel  0.03180565 rel_bl
#>    T-26-0130_Operator_1         parallel_vertical_segments  2.10148993    deg
#>    T-26-0130_Operator_2        eye_axis_vertical_alignment  5.30264963    deg
#>    T-26-0130_Operator_2      perpendicular_seg_3_4_vs_axis  0.02270459 rel_bl
#>    T-26-0130_Operator_2           axis_horizontal_parallel  0.02486694 rel_bl
#>    T-26-0131_Operator_1           axis_horizontal_parallel  0.02819743 rel_bl
#>    T-26-0131_Operator_2        eye_axis_vertical_alignment  5.74999843    deg
#>    T-26-0131_Operator_2      perpendicular_seg_3_4_vs_axis  0.02544042 rel_bl
#>    T-26-0131_Operator_2           axis_horizontal_parallel  0.02805929 rel_bl
#>    T-26-0133_Operator_1         parallel_vertical_segments  4.36922970    deg
#>    T-26-0133_Operator_2        eye_axis_vertical_alignment  2.04727109    deg
#>    T-26-0135_Operator_2         parallel_vertical_segments  4.00884913    deg
#>    T-26-0136_Operator_2         parallel_vertical_segments  2.65060362    deg
#>    T-26-0137_Operator_2        eye_axis_vertical_alignment  2.49213330    deg
#>    T-26-0138_Operator_2         parallel_vertical_segments  2.89716041    deg
#>    T-26-0140_Operator_2        eye_axis_vertical_alignment  3.09052817    deg
#>    T-26-0142_Operator_2        eye_axis_vertical_alignment  2.06258167    deg
#>    T-26-0145_Operator_1           axis_horizontal_parallel  0.02835781 rel_bl
#>    T-26-0145_Operator_1         parallel_vertical_segments  2.24653651    deg
#>    T-26-0145_Operator_2        eye_axis_vertical_alignment  3.19549552    deg
#>    T-26-0147_Operator_2         parallel_vertical_segments  4.02623197    deg
#>    T-26-0148_Operator_2        eye_axis_vertical_alignment  2.28381020    deg
#>    T-26-0150_Operator_2         parallel_vertical_segments  5.75246975    deg
#>    T-26-0152_Operator_1           axis_horizontal_parallel  0.02356416 rel_bl
#>    T-26-0152_Operator_2        eye_axis_vertical_alignment  4.82760761    deg
#>    T-26-0152_Operator_2           axis_horizontal_parallel  0.02143899 rel_bl
#>    T-26-0152_Operator_2         parallel_vertical_segments  2.71812052    deg
#>    T-26-0153_Operator_1        eye_axis_vertical_alignment  2.28810340    deg
#>    T-26-0154_Operator_1        eye_axis_vertical_alignment  3.23905687    deg
#>    T-26-0154_Operator_1      perpendicular_seg_3_4_vs_axis  0.03416939 rel_bl
#>    T-26-0154_Operator_1           axis_horizontal_parallel  0.02460147 rel_bl
#>    T-26-0154_Operator_1         parallel_vertical_segments  7.22044512    deg
#>    T-26-0154_Operator_2        eye_axis_vertical_alignment  5.36865760    deg
#>    T-26-0154_Operator_2      perpendicular_seg_3_4_vs_axis  0.02232424 rel_bl
#>    T-26-0154_Operator_2           axis_horizontal_parallel  0.02561265 rel_bl
#>    T-26-0157_Operator_1           axis_horizontal_parallel  0.02397433 rel_bl
#>    T-26-0157_Operator_2        eye_axis_vertical_alignment  4.10998402    deg
#>    T-26-0159_Operator_1        eye_axis_vertical_alignment  2.45539701    deg
#>    T-26-0159_Operator_2         parallel_vertical_segments  2.54535130    deg
#>    T-26-0160_Operator_1        eye_axis_vertical_alignment  3.27710118    deg
#>    T-26-0160_Operator_1           axis_horizontal_parallel  0.02050066 rel_bl
#>    T-26-0160_Operator_2        eye_axis_vertical_alignment  4.49882543    deg
#>    T-26-0160_Operator_2      perpendicular_seg_3_4_vs_axis  0.02078851 rel_bl
#>    T-26-0160_Operator_2           axis_horizontal_parallel  0.02038873 rel_bl
#>    T-26-0161_Operator_2        eye_axis_vertical_alignment  2.63207004    deg
#>    T-26-0163_Operator_1         parallel_vertical_segments  2.64254529    deg
#>    T-26-0164_Operator_1        eye_axis_vertical_alignment 11.41624322    deg
#>    T-26-0164_Operator_1      perpendicular_seg_3_4_vs_axis  0.04739704 rel_bl
#>    T-26-0164_Operator_1 perpendicular_eye_vertical_vs_axis  0.02695079 rel_bl
#>    T-26-0164_Operator_1           axis_horizontal_parallel  0.03345673 rel_bl
#>    T-26-0164_Operator_1         parallel_vertical_segments  2.17171474    deg
#>    T-26-0164_Operator_2        eye_axis_vertical_alignment  4.57095598    deg
#>    T-26-0164_Operator_2           axis_horizontal_parallel  0.03423885 rel_bl
#>    T-26-0165_Operator_1        eye_axis_vertical_alignment  2.03608781    deg
#>    T-26-0165_Operator_1           axis_horizontal_parallel  0.03970688 rel_bl
#>    T-26-0165_Operator_2        eye_axis_vertical_alignment  6.82468889    deg
#>    T-26-0165_Operator_2      perpendicular_seg_3_4_vs_axis  0.03213137 rel_bl
#>    T-26-0165_Operator_2 perpendicular_eye_vertical_vs_axis  0.02303841 rel_bl
#>    T-26-0165_Operator_2           axis_horizontal_parallel  0.04425713 rel_bl
#>    T-26-0165_Operator_2         parallel_vertical_segments  2.03882600    deg
#>    T-26-0166_Operator_1           axis_horizontal_parallel  0.04888907 rel_bl
#>    T-26-0166_Operator_2        eye_axis_vertical_alignment  6.54373191    deg
#>    T-26-0166_Operator_2      perpendicular_seg_3_4_vs_axis  0.02608449 rel_bl
#>    T-26-0166_Operator_2           axis_horizontal_parallel  0.04471444 rel_bl
#>    T-26-0169_Operator_2        eye_axis_vertical_alignment  4.68076154    deg
#>    T-26-0169_Operator_2      perpendicular_seg_3_4_vs_axis  0.02040312 rel_bl
#>    T-26-0173_Operator_2        eye_axis_vertical_alignment  2.54690677    deg
#>    T-26-0174_Operator_2         parallel_vertical_segments  2.50193583    deg
#>    T-26-0177_Operator_1        eye_axis_vertical_alignment 14.82132302    deg
#>    T-26-0177_Operator_1      perpendicular_seg_1_9_vs_axis  0.04592682 rel_bl
#>    T-26-0177_Operator_1      perpendicular_seg_3_4_vs_axis  0.07547663 rel_bl
#>    T-26-0177_Operator_1    perpendicular_seg_10_11_vs_axis  0.02776970 rel_bl
#>    T-26-0177_Operator_1 perpendicular_eye_vertical_vs_axis  0.05375930 rel_bl
#>    T-26-0177_Operator_1           axis_horizontal_parallel  0.04628284 rel_bl
#>    T-26-0177_Operator_2        eye_axis_vertical_alignment  5.65055247    deg
#>    T-26-0177_Operator_2      perpendicular_seg_3_4_vs_axis  0.02801072 rel_bl
#>    T-26-0177_Operator_2 perpendicular_eye_vertical_vs_axis  0.02029556 rel_bl
#>    T-26-0177_Operator_2           axis_horizontal_parallel  0.03560625 rel_bl
#>    T-26-0178_Operator_1           axis_horizontal_parallel  0.02412409 rel_bl
#>    T-26-0178_Operator_2        eye_axis_vertical_alignment  4.18939710    deg
#>    T-26-0178_Operator_2           axis_horizontal_parallel  0.02555728 rel_bl
#>  T-26-0179-3_Operator_1        eye_axis_vertical_alignment  3.67760762    deg
#>  T-26-0179-3_Operator_2        eye_axis_vertical_alignment  4.01404912    deg
#>  T-26-0179-3_Operator_2      perpendicular_seg_3_4_vs_axis  0.02017696 rel_bl
#>  T-26-0179-3_Operator_2           axis_horizontal_parallel  0.02257946 rel_bl
#>    T-26-0179_Operator_1           axis_horizontal_parallel  0.02680898 rel_bl
#>    T-26-0179_Operator_2        eye_axis_vertical_alignment  5.61951176    deg
#>    T-26-0179_Operator_2      perpendicular_seg_3_4_vs_axis  0.02342528 rel_bl
#>    T-26-0179_Operator_2           axis_horizontal_parallel  0.03018270 rel_bl
#>    T-26-0180_Operator_1        eye_axis_vertical_alignment  4.65459540    deg
#>    T-26-0180_Operator_1      perpendicular_seg_3_4_vs_axis  0.02123535 rel_bl
#>    T-26-0180_Operator_1           axis_horizontal_parallel  0.02052751 rel_bl
#>    T-26-0180_Operator_1         parallel_vertical_segments  2.26270499    deg
#>    T-26-0180_Operator_2        eye_axis_vertical_alignment  5.02311005    deg
#>    T-26-0180_Operator_2      perpendicular_seg_3_4_vs_axis  0.02179240 rel_bl
#>    T-26-0180_Operator_2           axis_horizontal_parallel  0.02060780 rel_bl
#>    T-26-0182_Operator_2        eye_axis_vertical_alignment  2.17904782    deg
#>    T-26-0184_Operator_1        eye_axis_vertical_alignment  3.83297829    deg
#>    T-26-0184_Operator_1      perpendicular_seg_3_4_vs_axis  0.02024219 rel_bl
#>    T-26-0184_Operator_1           axis_horizontal_parallel  0.03852545 rel_bl
#>    T-26-0184_Operator_2        eye_axis_vertical_alignment  6.04677433    deg
#>    T-26-0184_Operator_2      perpendicular_seg_3_4_vs_axis  0.02837512 rel_bl
#>    T-26-0184_Operator_2           axis_horizontal_parallel  0.03274001 rel_bl
#>    T-26-0185_Operator_2        eye_axis_vertical_alignment  3.56060168    deg
#>    T-26-0185_Operator_2           axis_horizontal_parallel  0.02007448 rel_bl
#>    T-26-0186_Operator_2        eye_axis_vertical_alignment  4.13007068    deg
#>    T-26-0187_Operator_1        eye_axis_vertical_alignment  2.20094492    deg
#>    T-26-0187_Operator_1           axis_horizontal_parallel  0.02611204 rel_bl
#>    T-26-0187_Operator_2        eye_axis_vertical_alignment  6.13969222    deg
#>    T-26-0187_Operator_2      perpendicular_seg_3_4_vs_axis  0.02623834 rel_bl
#>    T-26-0187_Operator_2 perpendicular_eye_vertical_vs_axis  0.02001196 rel_bl
#>    T-26-0187_Operator_2           axis_horizontal_parallel  0.02657121 rel_bl
#>    T-26-0188_Operator_2        eye_axis_vertical_alignment  2.92644717    deg
#>    T-26-0190_Operator_1        eye_axis_vertical_alignment 89.28211987    deg
#>    T-26-0190_Operator_1      perpendicular_seg_1_9_vs_axis  0.11571905 rel_bl
#>    T-26-0190_Operator_1      perpendicular_seg_3_4_vs_axis  0.25048599 rel_bl
#>    T-26-0190_Operator_1    perpendicular_seg_10_11_vs_axis  0.06679600 rel_bl
#>    T-26-0190_Operator_1 perpendicular_eye_vertical_vs_axis  0.15342267 rel_bl
#>    T-26-0190_Operator_1           axis_horizontal_parallel  0.34546246 rel_bl
#>    T-26-0190_Operator_2        eye_axis_vertical_alignment  2.28374260    deg
#>    T-26-0191_Operator_1        eye_axis_vertical_alignment  2.69777595    deg
#>    T-26-0191_Operator_2        eye_axis_vertical_alignment  4.48241911    deg
#>    T-26-0191_Operator_2      perpendicular_seg_3_4_vs_axis  0.02002686 rel_bl
#>    T-26-0191_Operator_2           axis_horizontal_parallel  0.02041954 rel_bl
#>    T-26-0192_Operator_1        eye_axis_vertical_alignment  2.33382914    deg
#>    T-26-0192_Operator_1           axis_horizontal_parallel  0.02161128 rel_bl
#>    T-26-0192_Operator_2        eye_axis_vertical_alignment  2.69056949    deg
#>    T-26-0192_Operator_2           axis_horizontal_parallel  0.02066492 rel_bl
#>    T-26-0193_Operator_2        eye_axis_vertical_alignment  3.48763778    deg
#>    T-26-0193_Operator_2           axis_horizontal_parallel  0.02060086 rel_bl
#>    T-26-0193_Operator_2         parallel_vertical_segments  2.16272013    deg
#>    T-26-0194_Operator_2        eye_axis_vertical_alignment  4.71661678    deg
#>    T-26-0194_Operator_2      perpendicular_seg_1_9_vs_axis  0.02269843 rel_bl
#>    T-26-0194_Operator_2      perpendicular_seg_3_4_vs_axis  0.02057991 rel_bl
#>    T-26-0194_Operator_2         parallel_vertical_segments  2.62505940    deg
#>    T-26-0195_Operator_1        eye_axis_vertical_alignment 14.33634556    deg
#>    T-26-0195_Operator_1      perpendicular_seg_1_9_vs_axis  0.03397678 rel_bl
#>    T-26-0195_Operator_1      perpendicular_seg_3_4_vs_axis  0.06442659 rel_bl
#>    T-26-0195_Operator_1 perpendicular_eye_vertical_vs_axis  0.03703326 rel_bl
#>    T-26-0195_Operator_1           axis_horizontal_parallel  0.03221329 rel_bl
#>    T-26-0195_Operator_2        eye_axis_vertical_alignment  2.54669154    deg
#>    T-26-0195_Operator_2           axis_horizontal_parallel  0.02440200 rel_bl
#>    T-26-0195_Operator_2         parallel_vertical_segments  2.87579438    deg
#>    T-26-0196_Operator_2        eye_axis_vertical_alignment  3.75203379    deg
#>    T-26-0196_Operator_2         parallel_vertical_segments  2.06433845    deg
#>    T-26-0197_Operator_2        eye_axis_vertical_alignment  2.70746616    deg
#>    T-26-0198_Operator_2        eye_axis_vertical_alignment  2.43875270    deg
#>    T-26-0199_Operator_2         parallel_vertical_segments  2.49996306    deg
#>    T-26-0200_Operator_1        eye_axis_vertical_alignment  2.52652670    deg
#>    T-26-0200_Operator_2        eye_axis_vertical_alignment  2.06965563    deg
#>    T-26-0201_Operator_2        eye_axis_vertical_alignment  3.39145649    deg
#>    T-26-0202_Operator_1        eye_axis_vertical_alignment  2.88638973    deg
#>    T-26-0202_Operator_1           axis_horizontal_parallel  0.02007277 rel_bl
#>    T-26-0202_Operator_2        eye_axis_vertical_alignment  4.44929898    deg
#>    T-26-0202_Operator_2      perpendicular_seg_3_4_vs_axis  0.02383667 rel_bl
#>    T-26-0202_Operator_2           axis_horizontal_parallel  0.02750385 rel_bl
#>    T-26-0203_Operator_2        eye_axis_vertical_alignment  3.46088697    deg
#>    T-26-0204_Operator_2        eye_axis_vertical_alignment  2.80985798    deg
#>    T-26-0205_Operator_2        eye_axis_vertical_alignment  3.63481024    deg
#>    T-26-0206_Operator_2         parallel_vertical_segments  2.31314504    deg
#>    T-26-0207_Operator_2         parallel_vertical_segments  2.93507083    deg
#>    T-26-0208_Operator_1         parallel_vertical_segments  2.22846671    deg
#>    T-26-0208_Operator_2         parallel_vertical_segments  2.83130309    deg
#>    T-26-0209_Operator_1        eye_axis_vertical_alignment 89.11864446    deg
#>    T-26-0209_Operator_1      perpendicular_seg_1_9_vs_axis  0.14801766 rel_bl
#>    T-26-0209_Operator_1      perpendicular_seg_3_4_vs_axis  0.27024263 rel_bl
#>    T-26-0209_Operator_1    perpendicular_seg_10_11_vs_axis  0.10134116 rel_bl
#>    T-26-0209_Operator_1 perpendicular_eye_vertical_vs_axis  0.17985762 rel_bl
#>    T-26-0209_Operator_1           axis_horizontal_parallel  0.36564986 rel_bl
#>    T-26-0210_Operator_2         parallel_vertical_segments  4.14613116    deg
#>    T-26-0212_Operator_1        eye_axis_vertical_alignment  4.96197318    deg
#>    T-26-0212_Operator_1      perpendicular_seg_3_4_vs_axis  0.02335622 rel_bl
#>    T-26-0212_Operator_1           axis_horizontal_parallel  0.04471144 rel_bl
#>    T-26-0212_Operator_2        eye_axis_vertical_alignment  8.72932694    deg
#>    T-26-0212_Operator_2      perpendicular_seg_3_4_vs_axis  0.03439558 rel_bl
#>    T-26-0212_Operator_2 perpendicular_eye_vertical_vs_axis  0.02225596 rel_bl
#>    T-26-0212_Operator_2           axis_horizontal_parallel  0.03574409 rel_bl
#>    T-26-0212_Operator_2         parallel_vertical_segments  2.38856350    deg
#>    T-26-0213_Operator_1        eye_axis_vertical_alignment  2.82709045    deg
#>    T-26-0213_Operator_1           axis_horizontal_parallel  0.02573432 rel_bl
#>    T-26-0213_Operator_2        eye_axis_vertical_alignment  3.99644901    deg
#>    T-26-0214_Operator_1           axis_horizontal_parallel  0.03044470 rel_bl
#>    T-26-0214_Operator_2        eye_axis_vertical_alignment  5.56669970    deg
#>    T-26-0214_Operator_2         parallel_vertical_segments  2.02168851    deg
#>    T-26-0215_Operator_2        eye_axis_vertical_alignment  4.84030822    deg
#>    T-26-0215_Operator_2      perpendicular_seg_3_4_vs_axis  0.02247708 rel_bl
#>    T-26-0217_Operator_2        eye_axis_vertical_alignment  5.28998154    deg
#>    T-26-0217_Operator_2      perpendicular_seg_3_4_vs_axis  0.02194261 rel_bl
#>    T-26-0217_Operator_2           axis_horizontal_parallel  0.02765661 rel_bl
#>    T-26-0218_Operator_1         parallel_vertical_segments  2.12659540    deg
#>    T-26-0218_Operator_2        eye_axis_vertical_alignment  2.85445351    deg
#>    T-26-0219_Operator_2        eye_axis_vertical_alignment  2.45724217    deg
#>    T-26-0219_Operator_2         parallel_vertical_segments  2.06354037    deg
#>    T-26-0220_Operator_1        eye_axis_vertical_alignment  2.33698579    deg
#>    T-26-0220_Operator_2        eye_axis_vertical_alignment  4.65935717    deg
#>    T-26-0220_Operator_2      perpendicular_seg_3_4_vs_axis  0.02076792 rel_bl
#>    T-26-0221_Operator_1        eye_axis_vertical_alignment  2.89389549    deg
#>    T-26-0221_Operator_1           axis_horizontal_parallel  0.05015633 rel_bl
#>    T-26-0221_Operator_1         parallel_vertical_segments  2.74613948    deg
#>    T-26-0221_Operator_2        eye_axis_vertical_alignment  5.19064520    deg
#>    T-26-0221_Operator_2           axis_horizontal_parallel  0.03147897 rel_bl
#>    T-26-0221_Operator_2         parallel_vertical_segments  2.88803708    deg
#>    T-26-0222_Operator_1        eye_axis_vertical_alignment  5.07793926    deg
#>    T-26-0222_Operator_1      perpendicular_seg_3_4_vs_axis  0.02167703 rel_bl
#>    T-26-0222_Operator_1           axis_horizontal_parallel  0.03928963 rel_bl
#>    T-26-0222_Operator_2        eye_axis_vertical_alignment  5.13760453    deg
#>    T-26-0222_Operator_2      perpendicular_seg_3_4_vs_axis  0.02456452 rel_bl
#>    T-26-0222_Operator_2           axis_horizontal_parallel  0.03172917 rel_bl
#>    T-26-0224_Operator_2         parallel_vertical_segments  2.22772732    deg
#>    T-26-0225_Operator_2        eye_axis_vertical_alignment  2.09654425    deg
#>    T-26-0225_Operator_2         parallel_vertical_segments  3.24730874    deg
#>    T-26-0226_Operator_2         parallel_vertical_segments  3.28501393    deg
#>    T-26-0227_Operator_2         parallel_vertical_segments  9.61588543    deg
#>    T-26-0228_Operator_1        eye_axis_vertical_alignment  3.23771294    deg
#>    T-26-0228_Operator_1           axis_horizontal_parallel  0.02106202 rel_bl
#>    T-26-0228_Operator_2        eye_axis_vertical_alignment  2.80847495    deg
#>    T-26-0229_Operator_1           axis_horizontal_parallel  0.02193588 rel_bl
#>    T-26-0229_Operator_2        eye_axis_vertical_alignment  3.06562784    deg
#>  T-26-0230-1_Operator_1        eye_axis_vertical_alignment  2.33082867    deg
#>  T-26-0230-1_Operator_2        eye_axis_vertical_alignment 45.00000000    deg
#>  T-26-0230-1_Operator_2      perpendicular_seg_1_9_vs_axis  2.32335085 rel_bl
#>  T-26-0230-1_Operator_2      perpendicular_seg_3_4_vs_axis  3.95081884 rel_bl
#>  T-26-0230-1_Operator_2    perpendicular_seg_10_11_vs_axis  1.77337891 rel_bl
#>  T-26-0230-1_Operator_2 perpendicular_eye_vertical_vs_axis  3.45696649 rel_bl
#>  T-26-0230-1_Operator_2           axis_horizontal_parallel  0.15713484 rel_bl
#>  T-26-0230-2_Operator_1        eye_axis_vertical_alignment  2.57572734    deg
#>  T-26-0230-2_Operator_1           axis_horizontal_parallel  0.02839340 rel_bl
#>  T-26-0230-2_Operator_1         parallel_vertical_segments  5.39863946    deg
#>  T-26-0230-2_Operator_2        eye_axis_vertical_alignment  4.49139367    deg
#>  T-26-0230-2_Operator_2           axis_horizontal_parallel  0.03227189 rel_bl
#>  T-26-0230-3_Operator_1        eye_axis_vertical_alignment  4.40397520    deg
#>  T-26-0230-3_Operator_1           axis_horizontal_parallel  0.03220435 rel_bl
#>  T-26-0230-3_Operator_1         parallel_vertical_segments  2.67755325    deg
#>  T-26-0230-3_Operator_2        eye_axis_vertical_alignment  6.60529658    deg
#>  T-26-0230-3_Operator_2           axis_horizontal_parallel  0.02675356 rel_bl
#>  T-26-0230-3_Operator_2         parallel_vertical_segments  2.51269170    deg
#>  T-26-0230-4_Operator_1        eye_axis_vertical_alignment  6.65533932    deg
#>  T-26-0230-4_Operator_1      perpendicular_seg_3_4_vs_axis  0.02212231 rel_bl
#>  T-26-0230-4_Operator_1           axis_horizontal_parallel  0.02777056 rel_bl
#>  T-26-0230-4_Operator_2        eye_axis_vertical_alignment  3.66299296    deg
#>  T-26-0230-4_Operator_2         parallel_vertical_segments  2.30373188    deg
#>    T-26-0231_Operator_2         parallel_vertical_segments  2.26217622    deg
#>    T-26-0232_Operator_2         parallel_vertical_segments  2.92057497    deg
#>    T-26-0233_Operator_2         parallel_vertical_segments  2.10860168    deg
#>    T-26-0234_Operator_2         parallel_vertical_segments  2.75555457    deg
#>    T-26-0235_Operator_2        eye_axis_vertical_alignment  4.87853434    deg
#>    T-26-0235_Operator_2      perpendicular_seg_3_4_vs_axis  0.02261858 rel_bl
#>    T-26-0235_Operator_2         parallel_vertical_segments  4.50514449    deg
#>    T-26-0238_Operator_2         parallel_vertical_segments  2.97527390    deg
#>    T-26-0239_Operator_1        eye_axis_vertical_alignment  3.45729971    deg
#>    T-26-0239_Operator_2        eye_axis_vertical_alignment  5.04185771    deg
#>    T-26-0239_Operator_2      perpendicular_seg_3_4_vs_axis  0.02625884 rel_bl
#>    T-26-0239_Operator_2           axis_horizontal_parallel  0.02500842 rel_bl
#>    T-26-0239_Operator_2         parallel_vertical_segments  3.74517773    deg
#>    T-26-0241_Operator_2        eye_axis_vertical_alignment  2.21210170    deg
#>    T-26-0241_Operator_2         parallel_vertical_segments  2.36254243    deg
#>    T-26-0242_Operator_1        eye_axis_vertical_alignment  2.42225863    deg
#>    T-26-0242_Operator_1           axis_horizontal_parallel  0.03479065 rel_bl
#>    T-26-0242_Operator_2        eye_axis_vertical_alignment  3.74980313    deg
#>    T-26-0242_Operator_2           axis_horizontal_parallel  0.03041762 rel_bl
#>    T-26-0243_Operator_2         parallel_vertical_segments  2.05942267    deg
#>    T-26-0246_Operator_1        eye_axis_vertical_alignment  3.44685455    deg
#>    T-26-0246_Operator_2        eye_axis_vertical_alignment  4.89569377    deg
#>    T-26-0246_Operator_2      perpendicular_seg_3_4_vs_axis  0.02056579 rel_bl
#>    T-26-0246_Operator_2           axis_horizontal_parallel  0.02313688 rel_bl
#>    T-26-0246_Operator_2         parallel_vertical_segments  4.26719086    deg
#>    T-26-0247_Operator_2         parallel_vertical_segments  3.34499121    deg
#>    T-26-0248_Operator_1           axis_horizontal_parallel  0.02078000 rel_bl
#>    T-26-0248_Operator_2        eye_axis_vertical_alignment  2.82040258    deg
#>    T-26-0248_Operator_2         parallel_vertical_segments  4.07519547    deg
#>    T-26-0249_Operator_1        eye_axis_vertical_alignment  2.05013779    deg
#>    T-26-0249_Operator_1           axis_horizontal_parallel  0.02577412 rel_bl
#>    T-26-0249_Operator_2        eye_axis_vertical_alignment  3.75521115    deg
#>    T-26-0249_Operator_2         parallel_vertical_segments  4.65191324    deg
#>    T-26-0250_Operator_1           axis_horizontal_parallel  0.06534797 rel_bl
#>    T-26-0250_Operator_2        eye_axis_vertical_alignment  7.97047026    deg
#>    T-26-0250_Operator_2      perpendicular_seg_3_4_vs_axis  0.03574040 rel_bl
#>    T-26-0250_Operator_2           axis_horizontal_parallel  0.05422617 rel_bl
#>    T-26-0251_Operator_1        eye_axis_vertical_alignment  4.61252559    deg
#>    T-26-0251_Operator_1           axis_horizontal_parallel  0.04874968 rel_bl
#>    T-26-0251_Operator_2        eye_axis_vertical_alignment  6.99669281    deg
#>    T-26-0251_Operator_2      perpendicular_seg_3_4_vs_axis  0.02519918 rel_bl
#>    T-26-0251_Operator_2           axis_horizontal_parallel  0.03905873 rel_bl
#>    T-26-0251_Operator_2         parallel_vertical_segments  2.12152304    deg
#>    T-26-0252_Operator_1        eye_axis_vertical_alignment 11.86582159    deg
#>    T-26-0252_Operator_1      perpendicular_seg_1_9_vs_axis  0.02039167 rel_bl
#>    T-26-0252_Operator_1      perpendicular_seg_3_4_vs_axis  0.04698949 rel_bl
#>    T-26-0252_Operator_1 perpendicular_eye_vertical_vs_axis  0.02039167 rel_bl
#>    T-26-0252_Operator_1           axis_horizontal_parallel  0.08068007 rel_bl
#>    T-26-0252_Operator_2        eye_axis_vertical_alignment 12.12287093    deg
#>    T-26-0252_Operator_2      perpendicular_seg_3_4_vs_axis  0.04108765 rel_bl
#>    T-26-0252_Operator_2 perpendicular_eye_vertical_vs_axis  0.02620141 rel_bl
#>    T-26-0252_Operator_2           axis_horizontal_parallel  0.06431110 rel_bl
#>    T-26-0252_Operator_2         parallel_vertical_segments  2.88531830    deg
#>  T-26-0261-1_Operator_1        eye_axis_vertical_alignment 12.83402864    deg
#>  T-26-0261-1_Operator_1      perpendicular_seg_1_9_vs_axis  0.02281525 rel_bl
#>  T-26-0261-1_Operator_1      perpendicular_seg_3_4_vs_axis  0.05514973 rel_bl
#>  T-26-0261-1_Operator_1 perpendicular_eye_vertical_vs_axis  0.03676665 rel_bl
#>  T-26-0261-1_Operator_1           axis_horizontal_parallel  0.05383697 rel_bl
#>  T-26-0261-1_Operator_2        eye_axis_vertical_alignment  5.80168844    deg
#>  T-26-0261-1_Operator_2      perpendicular_seg_3_4_vs_axis  0.02663426 rel_bl
#>  T-26-0261-1_Operator_2           axis_horizontal_parallel  0.04340398 rel_bl
#>  T-26-0261-2_Operator_2        eye_axis_vertical_alignment  2.91776460    deg
#>  T-26-0261-3_Operator_1        eye_axis_vertical_alignment  3.70003685    deg
#>  T-26-0261-4_Operator_1           axis_horizontal_parallel  0.02741716 rel_bl
#>  T-26-0261-4_Operator_2        eye_axis_vertical_alignment  4.40147149    deg
#>  T-26-0261-4_Operator_2      perpendicular_seg_3_4_vs_axis  0.02451059 rel_bl
#>  T-26-0261-4_Operator_2           axis_horizontal_parallel  0.02297868 rel_bl
#>  T-26-0261-5_Operator_1        eye_axis_vertical_alignment  3.90160222    deg
#>  T-26-0262-1_Operator_1           axis_horizontal_parallel  0.03729052 rel_bl
#>  T-26-0262-1_Operator_2        eye_axis_vertical_alignment  7.65859364    deg
#>  T-26-0262-1_Operator_2      perpendicular_seg_3_4_vs_axis  0.02978091 rel_bl
#>  T-26-0262-1_Operator_2 perpendicular_eye_vertical_vs_axis  0.02388677 rel_bl
#>  T-26-0262-1_Operator_2           axis_horizontal_parallel  0.03805380 rel_bl
#>    T-26-0263_Operator_1        eye_axis_vertical_alignment  2.99210196    deg
#>    T-26-0263_Operator_2        eye_axis_vertical_alignment  2.16186258    deg
#>    T-26-0263_Operator_2         parallel_vertical_segments  3.34700625    deg
#>  T-26-0264-1_Operator_1         parallel_vertical_segments  2.53735681    deg
#>  T-26-0264-2_Operator_1        eye_axis_vertical_alignment  7.41719973    deg
#>  T-26-0264-2_Operator_1      perpendicular_seg_3_4_vs_axis  0.02823204 rel_bl
#>  T-26-0264-2_Operator_1           axis_horizontal_parallel  0.03863308 rel_bl
#>  T-26-0264-2_Operator_1         parallel_vertical_segments  2.46946230    deg
#>  T-26-0264-2_Operator_2        eye_axis_vertical_alignment  6.61204955    deg
#>  T-26-0264-2_Operator_2      perpendicular_seg_3_4_vs_axis  0.02692866 rel_bl
#>  T-26-0264-2_Operator_2           axis_horizontal_parallel  0.02991998 rel_bl
#>  T-26-0264-2_Operator_2         parallel_vertical_segments  4.10077042    deg
#>  T-26-0264-3_Operator_1        eye_axis_vertical_alignment 10.76286302    deg
#>  T-26-0264-3_Operator_1      perpendicular_seg_1_9_vs_axis  0.02369259 rel_bl
#>  T-26-0264-3_Operator_1      perpendicular_seg_3_4_vs_axis  0.04352487 rel_bl
#>  T-26-0264-3_Operator_1 perpendicular_eye_vertical_vs_axis  0.02948411 rel_bl
#>  T-26-0264-3_Operator_1           axis_horizontal_parallel  0.03650449 rel_bl
#>  T-26-0264-3_Operator_1         parallel_vertical_segments  4.07019623    deg
#>  T-26-0264-3_Operator_2        eye_axis_vertical_alignment  7.08729518    deg
#>  T-26-0264-3_Operator_2      perpendicular_seg_3_4_vs_axis  0.02948464 rel_bl
#>  T-26-0264-3_Operator_2           axis_horizontal_parallel  0.03229200 rel_bl
#>  T-26-0264-4_Operator_1        eye_axis_vertical_alignment 19.60755161    deg
#>  T-26-0264-4_Operator_1      perpendicular_seg_1_9_vs_axis  0.02216591 rel_bl
#>  T-26-0264-4_Operator_1      perpendicular_seg_3_4_vs_axis  0.07247200 rel_bl
#>  T-26-0264-4_Operator_1    perpendicular_seg_10_11_vs_axis  0.02467080 rel_bl
#>  T-26-0264-4_Operator_1 perpendicular_eye_vertical_vs_axis  0.03546406 rel_bl
#>  T-26-0264-4_Operator_1           axis_horizontal_parallel  0.10022709 rel_bl
#>  T-26-0264-4_Operator_1         parallel_vertical_segments  4.35460511    deg
#>  T-26-0264-4_Operator_2        eye_axis_vertical_alignment 15.81089736    deg
#>  T-26-0264-4_Operator_2      perpendicular_seg_3_4_vs_axis  0.05701443 rel_bl
#>  T-26-0264-4_Operator_2 perpendicular_eye_vertical_vs_axis  0.03081858 rel_bl
#>  T-26-0264-4_Operator_2           axis_horizontal_parallel  0.06009548 rel_bl
#>  T-26-0264-4_Operator_2         parallel_vertical_segments  2.75383187    deg
#>    T-26-0265_Operator_1         parallel_vertical_segments  4.51398846    deg
#>    T-26-0267_Operator_1         parallel_vertical_segments  2.14784776    deg
#>    T-26-0268_Operator_1        eye_axis_vertical_alignment  2.44390168    deg
#>    T-26-0269_Operator_1        eye_axis_vertical_alignment  8.36810063    deg
#>    T-26-0269_Operator_1      perpendicular_seg_3_4_vs_axis  0.03600715 rel_bl
#>    T-26-0269_Operator_1           axis_horizontal_parallel  0.03228227 rel_bl
#>    T-26-0269_Operator_2        eye_axis_vertical_alignment  3.32403961    deg
#>    T-26-0269_Operator_2      perpendicular_seg_3_4_vs_axis  0.03147178 rel_bl
#>    T-26-0269_Operator_2           axis_horizontal_parallel  0.03021291 rel_bl
#>    T-26-0269_Operator_2         parallel_vertical_segments  3.76589054    deg
#>  T-26-0270-1_Operator_1        eye_axis_vertical_alignment  2.46970250    deg
#>  T-26-0270-1_Operator_2        eye_axis_vertical_alignment  4.41680675    deg
#>  T-26-0270-1_Operator_2      perpendicular_seg_3_4_vs_axis  0.02044563 rel_bl
#>  T-26-0270-1_Operator_2           axis_horizontal_parallel  0.02172391 rel_bl
#>  T-26-0270-1_Operator_2         parallel_vertical_segments  2.16968147    deg
#>  T-26-0270-2_Operator_1        eye_axis_vertical_alignment 10.73023236    deg
#>  T-26-0270-2_Operator_1      perpendicular_seg_1_9_vs_axis  0.02519273 rel_bl
#>  T-26-0270-2_Operator_1      perpendicular_seg_3_4_vs_axis  0.04674939 rel_bl
#>  T-26-0270-2_Operator_1 perpendicular_eye_vertical_vs_axis  0.02493301 rel_bl
#>  T-26-0270-2_Operator_1           axis_horizontal_parallel  0.06856577 rel_bl
#>  T-26-0270-2_Operator_2        eye_axis_vertical_alignment 10.99253979    deg
#>  T-26-0270-2_Operator_2      perpendicular_seg_1_9_vs_axis  0.02655879 rel_bl
#>  T-26-0270-2_Operator_2      perpendicular_seg_3_4_vs_axis  0.04515830 rel_bl
#>  T-26-0270-2_Operator_2 perpendicular_eye_vertical_vs_axis  0.02629926 rel_bl
#>  T-26-0270-2_Operator_2           axis_horizontal_parallel  0.06090298 rel_bl
#>    T-26-0271_Operator_1        eye_axis_vertical_alignment  4.09198917    deg
#>    T-26-0271_Operator_1      perpendicular_seg_3_4_vs_axis  0.02338246 rel_bl
#>    T-26-0271_Operator_2        eye_axis_vertical_alignment  3.52002310    deg
#>    T-26-0271_Operator_2           axis_horizontal_parallel  0.02149934 rel_bl
#>    T-26-0271_Operator_2         parallel_vertical_segments  2.42449116    deg
#>    T-26-0272_Operator_1           axis_horizontal_parallel  0.02586498 rel_bl
#>    T-26-0272_Operator_2        eye_axis_vertical_alignment  4.15198314    deg
#>    T-26-0272_Operator_2           axis_horizontal_parallel  0.03214071 rel_bl
#>    T-26-0273_Operator_1        eye_axis_vertical_alignment  2.47513233    deg
#>    T-26-0273_Operator_1         parallel_vertical_segments  2.47513233    deg
#>    T-26-0274_Operator_1        eye_axis_vertical_alignment  8.27109501    deg
#>    T-26-0274_Operator_1      perpendicular_seg_3_4_vs_axis  0.02249630 rel_bl
#>    T-26-0274_Operator_1           axis_horizontal_parallel  0.04499260 rel_bl
#>    T-26-0274_Operator_2        eye_axis_vertical_alignment  5.66219328    deg
#>    T-26-0274_Operator_2           axis_horizontal_parallel  0.03396267 rel_bl
#>    T-26-0275_Operator_1        eye_axis_vertical_alignment  3.34501064    deg
#>    T-26-0276_Operator_2        eye_axis_vertical_alignment  3.29193987    deg
#>    T-26-0277_Operator_1        eye_axis_vertical_alignment 16.43933200    deg
#>    T-26-0277_Operator_1      perpendicular_seg_1_9_vs_axis  0.03276966 rel_bl
#>    T-26-0277_Operator_1      perpendicular_seg_3_4_vs_axis  0.05428509 rel_bl
#>    T-26-0277_Operator_1 perpendicular_eye_vertical_vs_axis  0.02912858 rel_bl
#>    T-26-0277_Operator_1           axis_horizontal_parallel  0.05958119 rel_bl
#>    T-26-0277_Operator_1         parallel_vertical_segments  2.15527562    deg
#>    T-26-0277_Operator_2        eye_axis_vertical_alignment  8.69378060    deg
#>    T-26-0277_Operator_2      perpendicular_seg_3_4_vs_axis  0.02814185 rel_bl
#>    T-26-0277_Operator_2           axis_horizontal_parallel  0.04422291 rel_bl
#>  T-26-0278-1_Operator_2        eye_axis_vertical_alignment  3.43903102    deg
#>  T-26-0278-1_Operator_2           axis_horizontal_parallel  0.02322560 rel_bl
#>  T-26-0278-1_Operator_2         parallel_vertical_segments  7.61578735    deg
#>  T-26-0278-2_Operator_1        eye_axis_vertical_alignment  4.64463164    deg
#>  T-26-0278-2_Operator_1           axis_horizontal_parallel  0.02684484 rel_bl
#>  T-26-0278-2_Operator_1         parallel_vertical_segments  2.44203347    deg
#>  T-26-0278-2_Operator_2        eye_axis_vertical_alignment  3.73279144    deg
#>  T-26-0278-2_Operator_2         parallel_vertical_segments  4.00462840    deg
#>    T-26-0279_Operator_1           axis_horizontal_parallel  0.02625135 rel_bl
#>    T-26-0279_Operator_2        eye_axis_vertical_alignment  2.62801570    deg
#>  tolerance
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       0.02
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       0.02
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       0.02
#>       2.00
#>       2.00
#>       2.00
#>       0.02
#>       2.00
```
