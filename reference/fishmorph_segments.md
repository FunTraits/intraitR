# Compute linear morphological measurements following the FISHMORPH protocol

Computes the 11 linear morphological measurements used by Brosse et al.
(2021) to build the FISHMORPH database, from a fixed 21- (or 22-)
landmark digitization scheme (see Details), including automatic
conversion from digitization (pixel) units to centimetres using a scale
bar digitized directly on the picture.

## Usage

``` r
fishmorph_segments(
  landmarks,
  scale_cm = 1,
  groups = NULL,
  na_action = c("keep", "omit", "impute_mean", "impute_group_mean", "missforest"),
  missforest_ntree = 100,
  missforest_maxiter = 10,
  geometry_check = NULL
)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` (from
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
  [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
  or
  [`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)),
  or a raw `p x k x n` landmark array, digitized following the point
  scheme described in Details. Must contain at least 21 landmarks, in 2
  dimensions.

- scale_cm:

  Numeric, the real-world distance, in centimetres, represented by the
  scale bar digitized at points 20-21 (typically the width of a 1 cm
  section of a ruler placed in the picture). Defaults to `1`.

- groups:

  Optional factor (or character vector), one value per specimen, used
  only by `na_action = "impute_group_mean"` (and optionally by
  `"missforest"`, as an auxiliary predictor). If `NULL` and
  `landmarks$metadata` has a `species` column, it is used automatically
  (as in
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)).

- na_action:

  Character, how to handle missing values in the 11 computed segment
  columns (e.g. because a landmark used by that measurement – commonly
  landmark 5 – was not digitized for a given specimen): `"keep"`
  (default) leaves `NA` in place, exactly as in previous package
  versions; `"omit"` removes affected specimens and reports how many;
  `"impute_mean"` replaces missing segment values with the column mean;
  `"impute_group_mean"` uses the within-group (e.g. within-species) mean
  instead, falling back to the column mean, with a warning, for a group
  entirely missing a segment; `"missforest"` uses random-forest-based
  iterative imputation
  ([`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html)).
  Same convention, options, and messages as
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)'s
  `na_action` – see there for details – except that here imputation
  operates on the derived linear *measurements*, not on landmark
  coordinates: this is not a substitute for a proper
  geometric-morphometric estimate of a missing landmark's position (see
  [`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
  run on `landmarks` *before* calling this function), and is best
  reserved for a small number of missing values.

- missforest_ntree, missforest_maxiter:

  Number of trees per forest and maximum number of iterations passed to
  [`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html)
  when `na_action = "missforest"`; ignored otherwise. Default to
  `missForest`'s own defaults (`100` and `10`).

- geometry_check:

  Optional object of class `"intrait_geometry_check"`, as returned by
  `correct_landmarks(landmarks, rule = "check_geometry")` – typically
  computed once beforehand and passed in here, rather than recomputed.
  Any measurement whose underlying landmark line failed a check for a
  given specimen (e.g. `Bd`, if segment (3, 4) was flagged as
  non-perpendicular to the main body axis) is set to `NA` for that
  specimen *before* `na_action` runs, so the usual `na_action` machinery
  (`"omit"`, `"impute_mean"`, ...) then handles it exactly like any
  other missing value; only checks that are invariant to the picture's
  own rotation are used for this (see
  `correct_landmarks(rule = "check_geometry")`'s Details), and only
  `Bl`, `Bd`, `Mo`, `PFi`, `Hd`, `Eh`, `Ed` can be affected (`PFl`,
  `Jl`, `CPd`, `CFd` involve landmarks outside the checked battery).
  `NULL` (default) leaves every measurement as computed, regardless of
  `geometry_check`.

## Value

A `data.frame` (class `"intrait_segments"`) with one row per specimen
(fewer, if `na_action = "omit"` dropped any) and columns `Bl`, `Bd`,
`Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`, `CFd` (all in
centimetres), preceded by any metadata columns carried over from
`landmarks`.

## Details

`fishmorph_segments()` implements the digitization scheme of Brosse et
al. (2021) (their figure 1a), in which 21 (optionally 22) landmarks are
placed on a lateral-view picture of a fish, in the following fixed
order:

- 1:

  snout tip (top of the mouth)

- 2:

  posterior insertion of the caudal fin (caudal fin basis)

- 3-4:

  top and bottom of the body at its deepest point (body depth)

- 5-6:

  top of the head and bottom of the head/jaw at the vertical of the eye
  (head depth)

- 7-8:

  centre of the eye and bottom of the body at the same vertical (eye
  position)

- 9:

  bottom of the body at the vertical of the snout/mouth

- 10:

  upper insertion of the pectoral fin

- 11:

  bottom of the body at the vertical of the pectoral fin insertion

- 12:

  tip of the longest pectoral fin ray

- 13-14:

  top and bottom of the eye (eye diameter)

- 15:

  corner of the mouth

- 16-17:

  top and bottom of the caudal peduncle, at its minimum depth

- 18-19:

  tip of the upper and lower rays of the caudal fin (caudal fin depth)

- 20-21:

  two points a known distance apart (`scale_cm` centimetres) on a scale
  bar/ruler included in the picture

- 22:

  optional: a point along the body midline used to correct standard
  length for body curvature in the picture (see below)

From these landmarks, 11 linear measurements are derived (segment names
follow Brosse et al., 2021, table in their figure 1a): body length
(`Bl`, standard length from snout to caudal fin basis), body depth
(`Bd`), head depth (`Hd`), eye position (`Eh`), mouth height (`Mo`,
points 1-9), pectoral fin position (`PFi`, points 10-11), pectoral fin
length (`PFl`, points 10-12), eye diameter (`Ed`), maxillary jaw length
(`Jl`, points 1-15), caudal peduncle depth (`CPd`), and caudal fin depth
(`CFd`).

All measurements are converted from digitization units to centimetres
using the scale bar (points 20-21), separately for every specimen, so
that pictures with different resolutions or magnifications remain
comparable.

If body length cannot be measured as a straight line because the fish is
curved in the picture, a 22nd landmark can be placed along the body
midline between the snout and the caudal fin basis; `Bl` is then
computed as the sum of the two segments (1-22 and 22-2) instead of the
direct distance (1-2). This correction is applied automatically,
specimen by specimen, whenever landmark 22 is present in `landmarks` and
has non-zero, non-missing coordinates for that specimen; otherwise the
direct distance (1-2) is used, matching the original protocol ("+22 if
needed, otherwise 22 = 0").

## References

Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
morphological traits of freshwater fishes. Global Ecology and
Biogeography, 30(11), 2330-2336.

## See also

[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
[`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md)

## Examples

``` r
# real T-26 Saudrune data, in the same "intrait_landmarks" format as
# simulate_fishmorph_points()
fish <- load_t26_saudrune_landmarks()
fishmorph_segments(fish)
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA.
#>                                      specimen  individual
#> T-26-0001_Operator_1     T-26-0001_Operator_1   T-26-0001
#> T-26-0001_Operator_2     T-26-0001_Operator_2   T-26-0001
#> T-26-0002_Operator_1     T-26-0002_Operator_1   T-26-0002
#> T-26-0002_Operator_2     T-26-0002_Operator_2   T-26-0002
#> T-26-0003_Operator_1     T-26-0003_Operator_1   T-26-0003
#> T-26-0003_Operator_2     T-26-0003_Operator_2   T-26-0003
#> T-26-0004_Operator_1     T-26-0004_Operator_1   T-26-0004
#> T-26-0004_Operator_2     T-26-0004_Operator_2   T-26-0004
#> T-26-0005_Operator_1     T-26-0005_Operator_1   T-26-0005
#> T-26-0005_Operator_2     T-26-0005_Operator_2   T-26-0005
#> T-26-0006_Operator_1     T-26-0006_Operator_1   T-26-0006
#> T-26-0006_Operator_2     T-26-0006_Operator_2   T-26-0006
#> T-26-0007_Operator_1     T-26-0007_Operator_1   T-26-0007
#> T-26-0007_Operator_2     T-26-0007_Operator_2   T-26-0007
#> T-26-0008_Operator_1     T-26-0008_Operator_1   T-26-0008
#> T-26-0008_Operator_2     T-26-0008_Operator_2   T-26-0008
#> T-26-0009_Operator_1     T-26-0009_Operator_1   T-26-0009
#> T-26-0009_Operator_2     T-26-0009_Operator_2   T-26-0009
#> T-26-0010_Operator_1     T-26-0010_Operator_1   T-26-0010
#> T-26-0010_Operator_2     T-26-0010_Operator_2   T-26-0010
#> T-26-0011_Operator_1     T-26-0011_Operator_1   T-26-0011
#> T-26-0011_Operator_2     T-26-0011_Operator_2   T-26-0011
#> T-26-0012_Operator_1     T-26-0012_Operator_1   T-26-0012
#> T-26-0012_Operator_2     T-26-0012_Operator_2   T-26-0012
#> T-26-0013_Operator_1     T-26-0013_Operator_1   T-26-0013
#> T-26-0013_Operator_2     T-26-0013_Operator_2   T-26-0013
#> T-26-0014_Operator_1     T-26-0014_Operator_1   T-26-0014
#> T-26-0014_Operator_2     T-26-0014_Operator_2   T-26-0014
#> T-26-0015_Operator_1     T-26-0015_Operator_1   T-26-0015
#> T-26-0015_Operator_2     T-26-0015_Operator_2   T-26-0015
#> T-26-0016_Operator_1     T-26-0016_Operator_1   T-26-0016
#> T-26-0016_Operator_2     T-26-0016_Operator_2   T-26-0016
#> T-26-0017_Operator_1     T-26-0017_Operator_1   T-26-0017
#> T-26-0017_Operator_2     T-26-0017_Operator_2   T-26-0017
#> T-26-0018_Operator_1     T-26-0018_Operator_1   T-26-0018
#> T-26-0018_Operator_2     T-26-0018_Operator_2   T-26-0018
#> T-26-0019_Operator_1     T-26-0019_Operator_1   T-26-0019
#> T-26-0019_Operator_2     T-26-0019_Operator_2   T-26-0019
#> T-26-0020_Operator_1     T-26-0020_Operator_1   T-26-0020
#> T-26-0020_Operator_2     T-26-0020_Operator_2   T-26-0020
#> T-26-0021_Operator_1     T-26-0021_Operator_1   T-26-0021
#> T-26-0021_Operator_2     T-26-0021_Operator_2   T-26-0021
#> T-26-0022_Operator_1     T-26-0022_Operator_1   T-26-0022
#> T-26-0022_Operator_2     T-26-0022_Operator_2   T-26-0022
#> T-26-0023-2_Operator_1 T-26-0023-2_Operator_1 T-26-0023-2
#> T-26-0023-2_Operator_2 T-26-0023-2_Operator_2 T-26-0023-2
#> T-26-0024_Operator_1     T-26-0024_Operator_1   T-26-0024
#> T-26-0024_Operator_2     T-26-0024_Operator_2   T-26-0024
#> T-26-0025_Operator_1     T-26-0025_Operator_1   T-26-0025
#> T-26-0025_Operator_2     T-26-0025_Operator_2   T-26-0025
#> T-26-0026_Operator_1     T-26-0026_Operator_1   T-26-0026
#> T-26-0026_Operator_2     T-26-0026_Operator_2   T-26-0026
#> T-26-0027_Operator_1     T-26-0027_Operator_1   T-26-0027
#> T-26-0027_Operator_2     T-26-0027_Operator_2   T-26-0027
#> T-26-0028_Operator_1     T-26-0028_Operator_1   T-26-0028
#> T-26-0028_Operator_2     T-26-0028_Operator_2   T-26-0028
#> T-26-0029_Operator_1     T-26-0029_Operator_1   T-26-0029
#> T-26-0029_Operator_2     T-26-0029_Operator_2   T-26-0029
#> T-26-0030_Operator_1     T-26-0030_Operator_1   T-26-0030
#> T-26-0030_Operator_2     T-26-0030_Operator_2   T-26-0030
#> T-26-0031_Operator_1     T-26-0031_Operator_1   T-26-0031
#> T-26-0031_Operator_2     T-26-0031_Operator_2   T-26-0031
#> T-26-0032_Operator_1     T-26-0032_Operator_1   T-26-0032
#> T-26-0032_Operator_2     T-26-0032_Operator_2   T-26-0032
#> T-26-0033_Operator_1     T-26-0033_Operator_1   T-26-0033
#> T-26-0033_Operator_2     T-26-0033_Operator_2   T-26-0033
#> T-26-0034_Operator_1     T-26-0034_Operator_1   T-26-0034
#> T-26-0034_Operator_2     T-26-0034_Operator_2   T-26-0034
#> T-26-0035_Operator_1     T-26-0035_Operator_1   T-26-0035
#> T-26-0035_Operator_2     T-26-0035_Operator_2   T-26-0035
#> T-26-0036_Operator_1     T-26-0036_Operator_1   T-26-0036
#> T-26-0036_Operator_2     T-26-0036_Operator_2   T-26-0036
#> T-26-0037_Operator_1     T-26-0037_Operator_1   T-26-0037
#> T-26-0037_Operator_2     T-26-0037_Operator_2   T-26-0037
#> T-26-0038_Operator_1     T-26-0038_Operator_1   T-26-0038
#> T-26-0038_Operator_2     T-26-0038_Operator_2   T-26-0038
#> T-26-0039_Operator_1     T-26-0039_Operator_1   T-26-0039
#> T-26-0039_Operator_2     T-26-0039_Operator_2   T-26-0039
#> T-26-0040_Operator_1     T-26-0040_Operator_1   T-26-0040
#> T-26-0040_Operator_2     T-26-0040_Operator_2   T-26-0040
#> T-26-0041_Operator_1     T-26-0041_Operator_1   T-26-0041
#> T-26-0041_Operator_2     T-26-0041_Operator_2   T-26-0041
#> T-26-0042_Operator_1     T-26-0042_Operator_1   T-26-0042
#> T-26-0042_Operator_2     T-26-0042_Operator_2   T-26-0042
#> T-26-0043_Operator_1     T-26-0043_Operator_1   T-26-0043
#> T-26-0043_Operator_2     T-26-0043_Operator_2   T-26-0043
#> T-26-0044_Operator_1     T-26-0044_Operator_1   T-26-0044
#> T-26-0044_Operator_2     T-26-0044_Operator_2   T-26-0044
#> T-26-0045_Operator_1     T-26-0045_Operator_1   T-26-0045
#> T-26-0045_Operator_2     T-26-0045_Operator_2   T-26-0045
#> T-26-0046_Operator_1     T-26-0046_Operator_1   T-26-0046
#> T-26-0046_Operator_2     T-26-0046_Operator_2   T-26-0046
#> T-26-0047_Operator_1     T-26-0047_Operator_1   T-26-0047
#> T-26-0047_Operator_2     T-26-0047_Operator_2   T-26-0047
#> T-26-0048_Operator_1     T-26-0048_Operator_1   T-26-0048
#> T-26-0048_Operator_2     T-26-0048_Operator_2   T-26-0048
#> T-26-0049_Operator_1     T-26-0049_Operator_1   T-26-0049
#> T-26-0049_Operator_2     T-26-0049_Operator_2   T-26-0049
#> T-26-0050_Operator_1     T-26-0050_Operator_1   T-26-0050
#> T-26-0050_Operator_2     T-26-0050_Operator_2   T-26-0050
#> T-26-0051_Operator_1     T-26-0051_Operator_1   T-26-0051
#> T-26-0051_Operator_2     T-26-0051_Operator_2   T-26-0051
#> T-26-0052_Operator_1     T-26-0052_Operator_1   T-26-0052
#> T-26-0052_Operator_2     T-26-0052_Operator_2   T-26-0052
#> T-26-0053_Operator_1     T-26-0053_Operator_1   T-26-0053
#> T-26-0053_Operator_2     T-26-0053_Operator_2   T-26-0053
#> T-26-0054_Operator_1     T-26-0054_Operator_1   T-26-0054
#> T-26-0054_Operator_2     T-26-0054_Operator_2   T-26-0054
#> T-26-0055_Operator_1     T-26-0055_Operator_1   T-26-0055
#> T-26-0055_Operator_2     T-26-0055_Operator_2   T-26-0055
#> T-26-0056-2_Operator_1 T-26-0056-2_Operator_1 T-26-0056-2
#> T-26-0056-2_Operator_2 T-26-0056-2_Operator_2 T-26-0056-2
#> T-26-0057_Operator_1     T-26-0057_Operator_1   T-26-0057
#> T-26-0057_Operator_2     T-26-0057_Operator_2   T-26-0057
#> T-26-0058_Operator_1     T-26-0058_Operator_1   T-26-0058
#> T-26-0058_Operator_2     T-26-0058_Operator_2   T-26-0058
#> T-26-0059_Operator_1     T-26-0059_Operator_1   T-26-0059
#> T-26-0059_Operator_2     T-26-0059_Operator_2   T-26-0059
#> T-26-0060_Operator_1     T-26-0060_Operator_1   T-26-0060
#> T-26-0060_Operator_2     T-26-0060_Operator_2   T-26-0060
#> T-26-0061_Operator_1     T-26-0061_Operator_1   T-26-0061
#> T-26-0061_Operator_2     T-26-0061_Operator_2   T-26-0061
#> T-26-0062_Operator_1     T-26-0062_Operator_1   T-26-0062
#> T-26-0062_Operator_2     T-26-0062_Operator_2   T-26-0062
#> T-26-0063_Operator_1     T-26-0063_Operator_1   T-26-0063
#> T-26-0063_Operator_2     T-26-0063_Operator_2   T-26-0063
#> T-26-0064_Operator_1     T-26-0064_Operator_1   T-26-0064
#> T-26-0064_Operator_2     T-26-0064_Operator_2   T-26-0064
#> T-26-0065_Operator_1     T-26-0065_Operator_1   T-26-0065
#> T-26-0065_Operator_2     T-26-0065_Operator_2   T-26-0065
#> T-26-0067_Operator_1     T-26-0067_Operator_1   T-26-0067
#> T-26-0067_Operator_2     T-26-0067_Operator_2   T-26-0067
#> T-26-0068_Operator_1     T-26-0068_Operator_1   T-26-0068
#> T-26-0068_Operator_2     T-26-0068_Operator_2   T-26-0068
#> T-26-0069_Operator_1     T-26-0069_Operator_1   T-26-0069
#> T-26-0069_Operator_2     T-26-0069_Operator_2   T-26-0069
#> T-26-0070_Operator_1     T-26-0070_Operator_1   T-26-0070
#> T-26-0070_Operator_2     T-26-0070_Operator_2   T-26-0070
#> T-26-0071_Operator_1     T-26-0071_Operator_1   T-26-0071
#> T-26-0071_Operator_2     T-26-0071_Operator_2   T-26-0071
#> T-26-0072_Operator_1     T-26-0072_Operator_1   T-26-0072
#> T-26-0072_Operator_2     T-26-0072_Operator_2   T-26-0072
#> T-26-0073_Operator_1     T-26-0073_Operator_1   T-26-0073
#> T-26-0073_Operator_2     T-26-0073_Operator_2   T-26-0073
#> T-26-0074_Operator_1     T-26-0074_Operator_1   T-26-0074
#> T-26-0074_Operator_2     T-26-0074_Operator_2   T-26-0074
#> T-26-0075_Operator_1     T-26-0075_Operator_1   T-26-0075
#> T-26-0075_Operator_2     T-26-0075_Operator_2   T-26-0075
#> T-26-0076_Operator_1     T-26-0076_Operator_1   T-26-0076
#> T-26-0076_Operator_2     T-26-0076_Operator_2   T-26-0076
#> T-26-0077_Operator_1     T-26-0077_Operator_1   T-26-0077
#> T-26-0077_Operator_2     T-26-0077_Operator_2   T-26-0077
#> T-26-0078_Operator_1     T-26-0078_Operator_1   T-26-0078
#> T-26-0078_Operator_2     T-26-0078_Operator_2   T-26-0078
#> T-26-0079_Operator_1     T-26-0079_Operator_1   T-26-0079
#> T-26-0079_Operator_2     T-26-0079_Operator_2   T-26-0079
#> T-26-0080_Operator_1     T-26-0080_Operator_1   T-26-0080
#> T-26-0080_Operator_2     T-26-0080_Operator_2   T-26-0080
#> T-26-0081_Operator_1     T-26-0081_Operator_1   T-26-0081
#> T-26-0081_Operator_2     T-26-0081_Operator_2   T-26-0081
#> T-26-0082_Operator_1     T-26-0082_Operator_1   T-26-0082
#> T-26-0082_Operator_2     T-26-0082_Operator_2   T-26-0082
#> T-26-0083_Operator_1     T-26-0083_Operator_1   T-26-0083
#> T-26-0083_Operator_2     T-26-0083_Operator_2   T-26-0083
#> T-26-0084_Operator_1     T-26-0084_Operator_1   T-26-0084
#> T-26-0084_Operator_2     T-26-0084_Operator_2   T-26-0084
#> T-26-0085_Operator_1     T-26-0085_Operator_1   T-26-0085
#> T-26-0085_Operator_2     T-26-0085_Operator_2   T-26-0085
#> T-26-0086_Operator_1     T-26-0086_Operator_1   T-26-0086
#> T-26-0086_Operator_2     T-26-0086_Operator_2   T-26-0086
#> T-26-0087_Operator_1     T-26-0087_Operator_1   T-26-0087
#> T-26-0087_Operator_2     T-26-0087_Operator_2   T-26-0087
#> T-26-0088_Operator_1     T-26-0088_Operator_1   T-26-0088
#> T-26-0088_Operator_2     T-26-0088_Operator_2   T-26-0088
#> T-26-0089_Operator_1     T-26-0089_Operator_1   T-26-0089
#> T-26-0089_Operator_2     T-26-0089_Operator_2   T-26-0089
#> T-26-0090_Operator_1     T-26-0090_Operator_1   T-26-0090
#> T-26-0090_Operator_2     T-26-0090_Operator_2   T-26-0090
#> T-26-0091_Operator_1     T-26-0091_Operator_1   T-26-0091
#> T-26-0091_Operator_2     T-26-0091_Operator_2   T-26-0091
#> T-26-0092_Operator_1     T-26-0092_Operator_1   T-26-0092
#> T-26-0092_Operator_2     T-26-0092_Operator_2   T-26-0092
#> T-26-0093_Operator_1     T-26-0093_Operator_1   T-26-0093
#> T-26-0093_Operator_2     T-26-0093_Operator_2   T-26-0093
#> T-26-0094_Operator_1     T-26-0094_Operator_1   T-26-0094
#> T-26-0094_Operator_2     T-26-0094_Operator_2   T-26-0094
#> T-26-0095_Operator_1     T-26-0095_Operator_1   T-26-0095
#> T-26-0095_Operator_2     T-26-0095_Operator_2   T-26-0095
#> T-26-0096_Operator_1     T-26-0096_Operator_1   T-26-0096
#> T-26-0096_Operator_2     T-26-0096_Operator_2   T-26-0096
#> T-26-0097_Operator_1     T-26-0097_Operator_1   T-26-0097
#> T-26-0097_Operator_2     T-26-0097_Operator_2   T-26-0097
#> T-26-0098_Operator_1     T-26-0098_Operator_1   T-26-0098
#> T-26-0098_Operator_2     T-26-0098_Operator_2   T-26-0098
#> T-26-0099_Operator_1     T-26-0099_Operator_1   T-26-0099
#> T-26-0099_Operator_2     T-26-0099_Operator_2   T-26-0099
#> T-26-0100_Operator_1     T-26-0100_Operator_1   T-26-0100
#> T-26-0100_Operator_2     T-26-0100_Operator_2   T-26-0100
#> T-26-0101_Operator_1     T-26-0101_Operator_1   T-26-0101
#> T-26-0101_Operator_2     T-26-0101_Operator_2   T-26-0101
#> T-26-0102_Operator_1     T-26-0102_Operator_1   T-26-0102
#> T-26-0102_Operator_2     T-26-0102_Operator_2   T-26-0102
#> T-26-0103_Operator_1     T-26-0103_Operator_1   T-26-0103
#> T-26-0103_Operator_2     T-26-0103_Operator_2   T-26-0103
#> T-26-0104_Operator_1     T-26-0104_Operator_1   T-26-0104
#> T-26-0104_Operator_2     T-26-0104_Operator_2   T-26-0104
#> T-26-0107_Operator_1     T-26-0107_Operator_1   T-26-0107
#> T-26-0107_Operator_2     T-26-0107_Operator_2   T-26-0107
#> T-26-0108_Operator_1     T-26-0108_Operator_1   T-26-0108
#> T-26-0108_Operator_2     T-26-0108_Operator_2   T-26-0108
#> T-26-0109_Operator_1     T-26-0109_Operator_1   T-26-0109
#> T-26-0109_Operator_2     T-26-0109_Operator_2   T-26-0109
#> T-26-0111_Operator_1     T-26-0111_Operator_1   T-26-0111
#> T-26-0111_Operator_2     T-26-0111_Operator_2   T-26-0111
#> T-26-0112-2_Operator_1 T-26-0112-2_Operator_1 T-26-0112-2
#> T-26-0112-2_Operator_2 T-26-0112-2_Operator_2 T-26-0112-2
#> T-26-0112_Operator_1     T-26-0112_Operator_1   T-26-0112
#> T-26-0112_Operator_2     T-26-0112_Operator_2   T-26-0112
#> T-26-0113_Operator_1     T-26-0113_Operator_1   T-26-0113
#> T-26-0113_Operator_2     T-26-0113_Operator_2   T-26-0113
#> T-26-0114_Operator_1     T-26-0114_Operator_1   T-26-0114
#> T-26-0114_Operator_2     T-26-0114_Operator_2   T-26-0114
#> T-26-0115_Operator_1     T-26-0115_Operator_1   T-26-0115
#> T-26-0115_Operator_2     T-26-0115_Operator_2   T-26-0115
#> T-26-0116_Operator_1     T-26-0116_Operator_1   T-26-0116
#> T-26-0116_Operator_2     T-26-0116_Operator_2   T-26-0116
#> T-26-0117_Operator_1     T-26-0117_Operator_1   T-26-0117
#> T-26-0117_Operator_2     T-26-0117_Operator_2   T-26-0117
#> T-26-0118_Operator_1     T-26-0118_Operator_1   T-26-0118
#> T-26-0118_Operator_2     T-26-0118_Operator_2   T-26-0118
#> T-26-0120_Operator_1     T-26-0120_Operator_1   T-26-0120
#> T-26-0120_Operator_2     T-26-0120_Operator_2   T-26-0120
#> T-26-0121_Operator_1     T-26-0121_Operator_1   T-26-0121
#> T-26-0121_Operator_2     T-26-0121_Operator_2   T-26-0121
#> T-26-0122_Operator_1     T-26-0122_Operator_1   T-26-0122
#> T-26-0122_Operator_2     T-26-0122_Operator_2   T-26-0122
#> T-26-0123_Operator_1     T-26-0123_Operator_1   T-26-0123
#> T-26-0123_Operator_2     T-26-0123_Operator_2   T-26-0123
#> T-26-0125_Operator_1     T-26-0125_Operator_1   T-26-0125
#> T-26-0125_Operator_2     T-26-0125_Operator_2   T-26-0125
#> T-26-0126_Operator_1     T-26-0126_Operator_1   T-26-0126
#> T-26-0126_Operator_2     T-26-0126_Operator_2   T-26-0126
#> T-26-0127_Operator_1     T-26-0127_Operator_1   T-26-0127
#> T-26-0127_Operator_2     T-26-0127_Operator_2   T-26-0127
#> T-26-0128_Operator_1     T-26-0128_Operator_1   T-26-0128
#> T-26-0128_Operator_2     T-26-0128_Operator_2   T-26-0128
#> T-26-0130_Operator_1     T-26-0130_Operator_1   T-26-0130
#> T-26-0130_Operator_2     T-26-0130_Operator_2   T-26-0130
#> T-26-0131_Operator_1     T-26-0131_Operator_1   T-26-0131
#> T-26-0131_Operator_2     T-26-0131_Operator_2   T-26-0131
#> T-26-0132_Operator_1     T-26-0132_Operator_1   T-26-0132
#> T-26-0132_Operator_2     T-26-0132_Operator_2   T-26-0132
#> T-26-0133_Operator_1     T-26-0133_Operator_1   T-26-0133
#> T-26-0133_Operator_2     T-26-0133_Operator_2   T-26-0133
#> T-26-0134_Operator_1     T-26-0134_Operator_1   T-26-0134
#> T-26-0134_Operator_2     T-26-0134_Operator_2   T-26-0134
#> T-26-0135_Operator_1     T-26-0135_Operator_1   T-26-0135
#> T-26-0135_Operator_2     T-26-0135_Operator_2   T-26-0135
#> T-26-0136_Operator_1     T-26-0136_Operator_1   T-26-0136
#> T-26-0136_Operator_2     T-26-0136_Operator_2   T-26-0136
#> T-26-0137_Operator_1     T-26-0137_Operator_1   T-26-0137
#> T-26-0137_Operator_2     T-26-0137_Operator_2   T-26-0137
#> T-26-0138_Operator_1     T-26-0138_Operator_1   T-26-0138
#> T-26-0138_Operator_2     T-26-0138_Operator_2   T-26-0138
#> T-26-0139_Operator_1     T-26-0139_Operator_1   T-26-0139
#> T-26-0139_Operator_2     T-26-0139_Operator_2   T-26-0139
#> T-26-0140_Operator_1     T-26-0140_Operator_1   T-26-0140
#> T-26-0140_Operator_2     T-26-0140_Operator_2   T-26-0140
#> T-26-0141_Operator_1     T-26-0141_Operator_1   T-26-0141
#> T-26-0141_Operator_2     T-26-0141_Operator_2   T-26-0141
#> T-26-0142_Operator_1     T-26-0142_Operator_1   T-26-0142
#> T-26-0142_Operator_2     T-26-0142_Operator_2   T-26-0142
#> T-26-0143_Operator_1     T-26-0143_Operator_1   T-26-0143
#> T-26-0143_Operator_2     T-26-0143_Operator_2   T-26-0143
#> T-26-0144_Operator_1     T-26-0144_Operator_1   T-26-0144
#> T-26-0144_Operator_2     T-26-0144_Operator_2   T-26-0144
#> T-26-0145_Operator_1     T-26-0145_Operator_1   T-26-0145
#> T-26-0145_Operator_2     T-26-0145_Operator_2   T-26-0145
#> T-26-0146_Operator_1     T-26-0146_Operator_1   T-26-0146
#> T-26-0146_Operator_2     T-26-0146_Operator_2   T-26-0146
#> T-26-0147_Operator_1     T-26-0147_Operator_1   T-26-0147
#> T-26-0147_Operator_2     T-26-0147_Operator_2   T-26-0147
#> T-26-0148_Operator_1     T-26-0148_Operator_1   T-26-0148
#> T-26-0148_Operator_2     T-26-0148_Operator_2   T-26-0148
#> T-26-0149_Operator_1     T-26-0149_Operator_1   T-26-0149
#> T-26-0149_Operator_2     T-26-0149_Operator_2   T-26-0149
#> T-26-0150_Operator_1     T-26-0150_Operator_1   T-26-0150
#> T-26-0150_Operator_2     T-26-0150_Operator_2   T-26-0150
#> T-26-0151_Operator_1     T-26-0151_Operator_1   T-26-0151
#> T-26-0151_Operator_2     T-26-0151_Operator_2   T-26-0151
#> T-26-0152_Operator_1     T-26-0152_Operator_1   T-26-0152
#> T-26-0152_Operator_2     T-26-0152_Operator_2   T-26-0152
#> T-26-0153_Operator_1     T-26-0153_Operator_1   T-26-0153
#> T-26-0153_Operator_2     T-26-0153_Operator_2   T-26-0153
#> T-26-0154_Operator_1     T-26-0154_Operator_1   T-26-0154
#> T-26-0154_Operator_2     T-26-0154_Operator_2   T-26-0154
#> T-26-0155_Operator_1     T-26-0155_Operator_1   T-26-0155
#> T-26-0155_Operator_2     T-26-0155_Operator_2   T-26-0155
#> T-26-0156_Operator_1     T-26-0156_Operator_1   T-26-0156
#> T-26-0156_Operator_2     T-26-0156_Operator_2   T-26-0156
#> T-26-0157_Operator_1     T-26-0157_Operator_1   T-26-0157
#> T-26-0157_Operator_2     T-26-0157_Operator_2   T-26-0157
#> T-26-0158_Operator_1     T-26-0158_Operator_1   T-26-0158
#> T-26-0158_Operator_2     T-26-0158_Operator_2   T-26-0158
#> T-26-0159_Operator_1     T-26-0159_Operator_1   T-26-0159
#> T-26-0159_Operator_2     T-26-0159_Operator_2   T-26-0159
#> T-26-0160_Operator_1     T-26-0160_Operator_1   T-26-0160
#> T-26-0160_Operator_2     T-26-0160_Operator_2   T-26-0160
#> T-26-0161_Operator_1     T-26-0161_Operator_1   T-26-0161
#> T-26-0161_Operator_2     T-26-0161_Operator_2   T-26-0161
#> T-26-0162_Operator_1     T-26-0162_Operator_1   T-26-0162
#> T-26-0162_Operator_2     T-26-0162_Operator_2   T-26-0162
#> T-26-0163_Operator_1     T-26-0163_Operator_1   T-26-0163
#> T-26-0163_Operator_2     T-26-0163_Operator_2   T-26-0163
#> T-26-0164_Operator_1     T-26-0164_Operator_1   T-26-0164
#> T-26-0164_Operator_2     T-26-0164_Operator_2   T-26-0164
#> T-26-0165_Operator_1     T-26-0165_Operator_1   T-26-0165
#> T-26-0165_Operator_2     T-26-0165_Operator_2   T-26-0165
#> T-26-0166_Operator_1     T-26-0166_Operator_1   T-26-0166
#> T-26-0166_Operator_2     T-26-0166_Operator_2   T-26-0166
#> T-26-0167_Operator_1     T-26-0167_Operator_1   T-26-0167
#> T-26-0167_Operator_2     T-26-0167_Operator_2   T-26-0167
#> T-26-0168_Operator_1     T-26-0168_Operator_1   T-26-0168
#> T-26-0168_Operator_2     T-26-0168_Operator_2   T-26-0168
#> T-26-0169_Operator_1     T-26-0169_Operator_1   T-26-0169
#> T-26-0169_Operator_2     T-26-0169_Operator_2   T-26-0169
#> T-26-0170_Operator_1     T-26-0170_Operator_1   T-26-0170
#> T-26-0170_Operator_2     T-26-0170_Operator_2   T-26-0170
#> T-26-0171_Operator_1     T-26-0171_Operator_1   T-26-0171
#> T-26-0171_Operator_2     T-26-0171_Operator_2   T-26-0171
#> T-26-0172_Operator_1     T-26-0172_Operator_1   T-26-0172
#> T-26-0172_Operator_2     T-26-0172_Operator_2   T-26-0172
#> T-26-0173_Operator_1     T-26-0173_Operator_1   T-26-0173
#> T-26-0173_Operator_2     T-26-0173_Operator_2   T-26-0173
#> T-26-0174_Operator_1     T-26-0174_Operator_1   T-26-0174
#> T-26-0174_Operator_2     T-26-0174_Operator_2   T-26-0174
#> T-26-0175_Operator_1     T-26-0175_Operator_1   T-26-0175
#> T-26-0175_Operator_2     T-26-0175_Operator_2   T-26-0175
#> T-26-0176_Operator_1     T-26-0176_Operator_1   T-26-0176
#> T-26-0176_Operator_2     T-26-0176_Operator_2   T-26-0176
#> T-26-0177_Operator_1     T-26-0177_Operator_1   T-26-0177
#> T-26-0177_Operator_2     T-26-0177_Operator_2   T-26-0177
#> T-26-0178_Operator_1     T-26-0178_Operator_1   T-26-0178
#> T-26-0178_Operator_2     T-26-0178_Operator_2   T-26-0178
#> T-26-0179-3_Operator_1 T-26-0179-3_Operator_1 T-26-0179-3
#> T-26-0179-3_Operator_2 T-26-0179-3_Operator_2 T-26-0179-3
#> T-26-0179_Operator_1     T-26-0179_Operator_1   T-26-0179
#> T-26-0179_Operator_2     T-26-0179_Operator_2   T-26-0179
#> T-26-0180_Operator_1     T-26-0180_Operator_1   T-26-0180
#> T-26-0180_Operator_2     T-26-0180_Operator_2   T-26-0180
#> T-26-0181_Operator_1     T-26-0181_Operator_1   T-26-0181
#> T-26-0181_Operator_2     T-26-0181_Operator_2   T-26-0181
#> T-26-0182_Operator_1     T-26-0182_Operator_1   T-26-0182
#> T-26-0182_Operator_2     T-26-0182_Operator_2   T-26-0182
#> T-26-0183_Operator_1     T-26-0183_Operator_1   T-26-0183
#> T-26-0183_Operator_2     T-26-0183_Operator_2   T-26-0183
#> T-26-0184_Operator_1     T-26-0184_Operator_1   T-26-0184
#> T-26-0184_Operator_2     T-26-0184_Operator_2   T-26-0184
#> T-26-0185_Operator_1     T-26-0185_Operator_1   T-26-0185
#> T-26-0185_Operator_2     T-26-0185_Operator_2   T-26-0185
#> T-26-0186_Operator_1     T-26-0186_Operator_1   T-26-0186
#> T-26-0186_Operator_2     T-26-0186_Operator_2   T-26-0186
#> T-26-0187_Operator_1     T-26-0187_Operator_1   T-26-0187
#> T-26-0187_Operator_2     T-26-0187_Operator_2   T-26-0187
#> T-26-0188_Operator_1     T-26-0188_Operator_1   T-26-0188
#> T-26-0188_Operator_2     T-26-0188_Operator_2   T-26-0188
#> T-26-0189_Operator_1     T-26-0189_Operator_1   T-26-0189
#> T-26-0189_Operator_2     T-26-0189_Operator_2   T-26-0189
#> T-26-0190_Operator_1     T-26-0190_Operator_1   T-26-0190
#> T-26-0190_Operator_2     T-26-0190_Operator_2   T-26-0190
#> T-26-0191_Operator_1     T-26-0191_Operator_1   T-26-0191
#> T-26-0191_Operator_2     T-26-0191_Operator_2   T-26-0191
#> T-26-0192_Operator_1     T-26-0192_Operator_1   T-26-0192
#> T-26-0192_Operator_2     T-26-0192_Operator_2   T-26-0192
#> T-26-0193_Operator_1     T-26-0193_Operator_1   T-26-0193
#> T-26-0193_Operator_2     T-26-0193_Operator_2   T-26-0193
#> T-26-0194_Operator_1     T-26-0194_Operator_1   T-26-0194
#> T-26-0194_Operator_2     T-26-0194_Operator_2   T-26-0194
#> T-26-0195_Operator_1     T-26-0195_Operator_1   T-26-0195
#> T-26-0195_Operator_2     T-26-0195_Operator_2   T-26-0195
#> T-26-0196_Operator_1     T-26-0196_Operator_1   T-26-0196
#> T-26-0196_Operator_2     T-26-0196_Operator_2   T-26-0196
#> T-26-0197_Operator_1     T-26-0197_Operator_1   T-26-0197
#> T-26-0197_Operator_2     T-26-0197_Operator_2   T-26-0197
#> T-26-0198_Operator_1     T-26-0198_Operator_1   T-26-0198
#> T-26-0198_Operator_2     T-26-0198_Operator_2   T-26-0198
#> T-26-0199_Operator_1     T-26-0199_Operator_1   T-26-0199
#> T-26-0199_Operator_2     T-26-0199_Operator_2   T-26-0199
#> T-26-0200_Operator_1     T-26-0200_Operator_1   T-26-0200
#> T-26-0200_Operator_2     T-26-0200_Operator_2   T-26-0200
#> T-26-0201_Operator_1     T-26-0201_Operator_1   T-26-0201
#> T-26-0201_Operator_2     T-26-0201_Operator_2   T-26-0201
#> T-26-0202_Operator_1     T-26-0202_Operator_1   T-26-0202
#> T-26-0202_Operator_2     T-26-0202_Operator_2   T-26-0202
#> T-26-0203_Operator_1     T-26-0203_Operator_1   T-26-0203
#> T-26-0203_Operator_2     T-26-0203_Operator_2   T-26-0203
#> T-26-0204_Operator_1     T-26-0204_Operator_1   T-26-0204
#> T-26-0204_Operator_2     T-26-0204_Operator_2   T-26-0204
#> T-26-0205_Operator_1     T-26-0205_Operator_1   T-26-0205
#> T-26-0205_Operator_2     T-26-0205_Operator_2   T-26-0205
#> T-26-0206_Operator_1     T-26-0206_Operator_1   T-26-0206
#> T-26-0206_Operator_2     T-26-0206_Operator_2   T-26-0206
#> T-26-0207_Operator_1     T-26-0207_Operator_1   T-26-0207
#> T-26-0207_Operator_2     T-26-0207_Operator_2   T-26-0207
#> T-26-0208_Operator_1     T-26-0208_Operator_1   T-26-0208
#> T-26-0208_Operator_2     T-26-0208_Operator_2   T-26-0208
#> T-26-0209_Operator_1     T-26-0209_Operator_1   T-26-0209
#> T-26-0209_Operator_2     T-26-0209_Operator_2   T-26-0209
#> T-26-0210_Operator_1     T-26-0210_Operator_1   T-26-0210
#> T-26-0210_Operator_2     T-26-0210_Operator_2   T-26-0210
#> T-26-0211_Operator_1     T-26-0211_Operator_1   T-26-0211
#> T-26-0211_Operator_2     T-26-0211_Operator_2   T-26-0211
#> T-26-0212_Operator_1     T-26-0212_Operator_1   T-26-0212
#> T-26-0212_Operator_2     T-26-0212_Operator_2   T-26-0212
#> T-26-0213_Operator_1     T-26-0213_Operator_1   T-26-0213
#> T-26-0213_Operator_2     T-26-0213_Operator_2   T-26-0213
#> T-26-0214_Operator_1     T-26-0214_Operator_1   T-26-0214
#> T-26-0214_Operator_2     T-26-0214_Operator_2   T-26-0214
#> T-26-0215_Operator_1     T-26-0215_Operator_1   T-26-0215
#> T-26-0215_Operator_2     T-26-0215_Operator_2   T-26-0215
#> T-26-0216_Operator_1     T-26-0216_Operator_1   T-26-0216
#> T-26-0216_Operator_2     T-26-0216_Operator_2   T-26-0216
#> T-26-0217_Operator_1     T-26-0217_Operator_1   T-26-0217
#> T-26-0217_Operator_2     T-26-0217_Operator_2   T-26-0217
#> T-26-0218_Operator_1     T-26-0218_Operator_1   T-26-0218
#> T-26-0218_Operator_2     T-26-0218_Operator_2   T-26-0218
#> T-26-0219_Operator_1     T-26-0219_Operator_1   T-26-0219
#> T-26-0219_Operator_2     T-26-0219_Operator_2   T-26-0219
#> T-26-0220_Operator_1     T-26-0220_Operator_1   T-26-0220
#> T-26-0220_Operator_2     T-26-0220_Operator_2   T-26-0220
#> T-26-0221_Operator_1     T-26-0221_Operator_1   T-26-0221
#> T-26-0221_Operator_2     T-26-0221_Operator_2   T-26-0221
#> T-26-0222_Operator_1     T-26-0222_Operator_1   T-26-0222
#> T-26-0222_Operator_2     T-26-0222_Operator_2   T-26-0222
#> T-26-0223_Operator_1     T-26-0223_Operator_1   T-26-0223
#> T-26-0223_Operator_2     T-26-0223_Operator_2   T-26-0223
#> T-26-0224_Operator_1     T-26-0224_Operator_1   T-26-0224
#> T-26-0224_Operator_2     T-26-0224_Operator_2   T-26-0224
#> T-26-0225_Operator_1     T-26-0225_Operator_1   T-26-0225
#> T-26-0225_Operator_2     T-26-0225_Operator_2   T-26-0225
#> T-26-0226_Operator_1     T-26-0226_Operator_1   T-26-0226
#> T-26-0226_Operator_2     T-26-0226_Operator_2   T-26-0226
#> T-26-0227_Operator_1     T-26-0227_Operator_1   T-26-0227
#> T-26-0227_Operator_2     T-26-0227_Operator_2   T-26-0227
#> T-26-0228_Operator_1     T-26-0228_Operator_1   T-26-0228
#> T-26-0228_Operator_2     T-26-0228_Operator_2   T-26-0228
#> T-26-0229_Operator_1     T-26-0229_Operator_1   T-26-0229
#> T-26-0229_Operator_2     T-26-0229_Operator_2   T-26-0229
#> T-26-0230-1_Operator_1 T-26-0230-1_Operator_1 T-26-0230-1
#> T-26-0230-1_Operator_2 T-26-0230-1_Operator_2 T-26-0230-1
#> T-26-0230-2_Operator_1 T-26-0230-2_Operator_1 T-26-0230-2
#> T-26-0230-2_Operator_2 T-26-0230-2_Operator_2 T-26-0230-2
#> T-26-0230-3_Operator_1 T-26-0230-3_Operator_1 T-26-0230-3
#> T-26-0230-3_Operator_2 T-26-0230-3_Operator_2 T-26-0230-3
#> T-26-0230-4_Operator_1 T-26-0230-4_Operator_1 T-26-0230-4
#> T-26-0230-4_Operator_2 T-26-0230-4_Operator_2 T-26-0230-4
#> T-26-0231_Operator_1     T-26-0231_Operator_1   T-26-0231
#> T-26-0231_Operator_2     T-26-0231_Operator_2   T-26-0231
#> T-26-0232_Operator_1     T-26-0232_Operator_1   T-26-0232
#> T-26-0232_Operator_2     T-26-0232_Operator_2   T-26-0232
#> T-26-0233_Operator_1     T-26-0233_Operator_1   T-26-0233
#> T-26-0233_Operator_2     T-26-0233_Operator_2   T-26-0233
#> T-26-0234_Operator_1     T-26-0234_Operator_1   T-26-0234
#> T-26-0234_Operator_2     T-26-0234_Operator_2   T-26-0234
#> T-26-0235_Operator_1     T-26-0235_Operator_1   T-26-0235
#> T-26-0235_Operator_2     T-26-0235_Operator_2   T-26-0235
#> T-26-0236_Operator_1     T-26-0236_Operator_1   T-26-0236
#> T-26-0236_Operator_2     T-26-0236_Operator_2   T-26-0236
#> T-26-0237_Operator_1     T-26-0237_Operator_1   T-26-0237
#> T-26-0237_Operator_2     T-26-0237_Operator_2   T-26-0237
#> T-26-0238_Operator_1     T-26-0238_Operator_1   T-26-0238
#> T-26-0238_Operator_2     T-26-0238_Operator_2   T-26-0238
#> T-26-0239_Operator_1     T-26-0239_Operator_1   T-26-0239
#> T-26-0239_Operator_2     T-26-0239_Operator_2   T-26-0239
#> T-26-0240_Operator_1     T-26-0240_Operator_1   T-26-0240
#> T-26-0240_Operator_2     T-26-0240_Operator_2   T-26-0240
#> T-26-0241_Operator_1     T-26-0241_Operator_1   T-26-0241
#> T-26-0241_Operator_2     T-26-0241_Operator_2   T-26-0241
#> T-26-0242_Operator_1     T-26-0242_Operator_1   T-26-0242
#> T-26-0242_Operator_2     T-26-0242_Operator_2   T-26-0242
#> T-26-0243_Operator_1     T-26-0243_Operator_1   T-26-0243
#> T-26-0243_Operator_2     T-26-0243_Operator_2   T-26-0243
#> T-26-0244_Operator_1     T-26-0244_Operator_1   T-26-0244
#> T-26-0244_Operator_2     T-26-0244_Operator_2   T-26-0244
#> T-26-0245_Operator_1     T-26-0245_Operator_1   T-26-0245
#> T-26-0245_Operator_2     T-26-0245_Operator_2   T-26-0245
#> T-26-0246_Operator_1     T-26-0246_Operator_1   T-26-0246
#> T-26-0246_Operator_2     T-26-0246_Operator_2   T-26-0246
#> T-26-0247_Operator_1     T-26-0247_Operator_1   T-26-0247
#> T-26-0247_Operator_2     T-26-0247_Operator_2   T-26-0247
#> T-26-0248_Operator_1     T-26-0248_Operator_1   T-26-0248
#> T-26-0248_Operator_2     T-26-0248_Operator_2   T-26-0248
#> T-26-0249_Operator_1     T-26-0249_Operator_1   T-26-0249
#> T-26-0249_Operator_2     T-26-0249_Operator_2   T-26-0249
#> T-26-0250_Operator_1     T-26-0250_Operator_1   T-26-0250
#> T-26-0250_Operator_2     T-26-0250_Operator_2   T-26-0250
#> T-26-0251_Operator_1     T-26-0251_Operator_1   T-26-0251
#> T-26-0251_Operator_2     T-26-0251_Operator_2   T-26-0251
#> T-26-0252_Operator_1     T-26-0252_Operator_1   T-26-0252
#> T-26-0252_Operator_2     T-26-0252_Operator_2   T-26-0252
#> T-26-0261-1_Operator_1 T-26-0261-1_Operator_1 T-26-0261-1
#> T-26-0261-1_Operator_2 T-26-0261-1_Operator_2 T-26-0261-1
#> T-26-0261-2_Operator_1 T-26-0261-2_Operator_1 T-26-0261-2
#> T-26-0261-2_Operator_2 T-26-0261-2_Operator_2 T-26-0261-2
#> T-26-0261-3_Operator_1 T-26-0261-3_Operator_1 T-26-0261-3
#> T-26-0261-3_Operator_2 T-26-0261-3_Operator_2 T-26-0261-3
#> T-26-0261-4_Operator_1 T-26-0261-4_Operator_1 T-26-0261-4
#> T-26-0261-4_Operator_2 T-26-0261-4_Operator_2 T-26-0261-4
#> T-26-0261-5_Operator_1 T-26-0261-5_Operator_1 T-26-0261-5
#> T-26-0261-5_Operator_2 T-26-0261-5_Operator_2 T-26-0261-5
#> T-26-0262-1_Operator_1 T-26-0262-1_Operator_1 T-26-0262-1
#> T-26-0262-1_Operator_2 T-26-0262-1_Operator_2 T-26-0262-1
#> T-26-0262-2_Operator_1 T-26-0262-2_Operator_1 T-26-0262-2
#> T-26-0262-2_Operator_2 T-26-0262-2_Operator_2 T-26-0262-2
#> T-26-0263_Operator_1     T-26-0263_Operator_1   T-26-0263
#> T-26-0263_Operator_2     T-26-0263_Operator_2   T-26-0263
#> T-26-0264-1_Operator_1 T-26-0264-1_Operator_1 T-26-0264-1
#> T-26-0264-1_Operator_2 T-26-0264-1_Operator_2 T-26-0264-1
#> T-26-0264-2_Operator_1 T-26-0264-2_Operator_1 T-26-0264-2
#> T-26-0264-2_Operator_2 T-26-0264-2_Operator_2 T-26-0264-2
#> T-26-0264-3_Operator_1 T-26-0264-3_Operator_1 T-26-0264-3
#> T-26-0264-3_Operator_2 T-26-0264-3_Operator_2 T-26-0264-3
#> T-26-0264-4_Operator_1 T-26-0264-4_Operator_1 T-26-0264-4
#> T-26-0264-4_Operator_2 T-26-0264-4_Operator_2 T-26-0264-4
#> T-26-0265_Operator_1     T-26-0265_Operator_1   T-26-0265
#> T-26-0265_Operator_2     T-26-0265_Operator_2   T-26-0265
#> T-26-0266_Operator_1     T-26-0266_Operator_1   T-26-0266
#> T-26-0266_Operator_2     T-26-0266_Operator_2   T-26-0266
#> T-26-0267_Operator_1     T-26-0267_Operator_1   T-26-0267
#> T-26-0267_Operator_2     T-26-0267_Operator_2   T-26-0267
#> T-26-0268_Operator_1     T-26-0268_Operator_1   T-26-0268
#> T-26-0268_Operator_2     T-26-0268_Operator_2   T-26-0268
#> T-26-0269_Operator_1     T-26-0269_Operator_1   T-26-0269
#> T-26-0269_Operator_2     T-26-0269_Operator_2   T-26-0269
#> T-26-0270-1_Operator_1 T-26-0270-1_Operator_1 T-26-0270-1
#> T-26-0270-1_Operator_2 T-26-0270-1_Operator_2 T-26-0270-1
#> T-26-0270-2_Operator_1 T-26-0270-2_Operator_1 T-26-0270-2
#> T-26-0270-2_Operator_2 T-26-0270-2_Operator_2 T-26-0270-2
#> T-26-0271_Operator_1     T-26-0271_Operator_1   T-26-0271
#> T-26-0271_Operator_2     T-26-0271_Operator_2   T-26-0271
#> T-26-0272_Operator_1     T-26-0272_Operator_1   T-26-0272
#> T-26-0272_Operator_2     T-26-0272_Operator_2   T-26-0272
#> T-26-0273_Operator_1     T-26-0273_Operator_1   T-26-0273
#> T-26-0273_Operator_2     T-26-0273_Operator_2   T-26-0273
#> T-26-0274_Operator_1     T-26-0274_Operator_1   T-26-0274
#> T-26-0274_Operator_2     T-26-0274_Operator_2   T-26-0274
#> T-26-0275_Operator_1     T-26-0275_Operator_1   T-26-0275
#> T-26-0275_Operator_2     T-26-0275_Operator_2   T-26-0275
#> T-26-0276_Operator_1     T-26-0276_Operator_1   T-26-0276
#> T-26-0276_Operator_2     T-26-0276_Operator_2   T-26-0276
#> T-26-0277_Operator_1     T-26-0277_Operator_1   T-26-0277
#> T-26-0277_Operator_2     T-26-0277_Operator_2   T-26-0277
#> T-26-0278-1_Operator_1 T-26-0278-1_Operator_1 T-26-0278-1
#> T-26-0278-1_Operator_2 T-26-0278-1_Operator_2 T-26-0278-1
#> T-26-0278-2_Operator_1 T-26-0278-2_Operator_1 T-26-0278-2
#> T-26-0278-2_Operator_2 T-26-0278-2_Operator_2 T-26-0278-2
#> T-26-0279_Operator_1     T-26-0279_Operator_1   T-26-0279
#> T-26-0279_Operator_2     T-26-0279_Operator_2   T-26-0279
#>                                          species population replicate
#> T-26-0001_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0001_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0002_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0002_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0003_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0003_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0004_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0004_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0005_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0005_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0006_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0006_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0007_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0007_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0008_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0008_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0009_Operator_1            Lepomis gibbosus       <NA>         1
#> T-26-0009_Operator_2            Lepomis gibbosus       <NA>         2
#> T-26-0010_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0010_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0011_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0011_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0012_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0012_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0013_Operator_1               Barbus barbus       <NA>         1
#> T-26-0013_Operator_2               Barbus barbus       <NA>         2
#> T-26-0014_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0014_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0015_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0015_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0016_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0016_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0017_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0017_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0018_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0018_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0019_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0019_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0020_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0020_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0021_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0021_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0022_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0022_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0023-2_Operator_1         Phoxinus phoxinus       <NA>         1
#> T-26-0023-2_Operator_2         Phoxinus phoxinus       <NA>         2
#> T-26-0024_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0024_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0025_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0025_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0026_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0026_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0027_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0027_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0028_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0028_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0029_Operator_1            Lepomis gibbosus       <NA>         1
#> T-26-0029_Operator_2            Lepomis gibbosus       <NA>         2
#> T-26-0030_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0030_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0031_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0031_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0032_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0032_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0033_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0033_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0034_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0034_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0035_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0035_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0036_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0036_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0037_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0037_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0038_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0038_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0039_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0039_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0040_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0040_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0041_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0041_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0042_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0042_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0043_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0043_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0044_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0044_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0045_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0045_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0046_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0046_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0047_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0047_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0048_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0048_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0049_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0049_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0050_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0050_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0051_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0051_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0052_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0052_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0053_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0053_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0054_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0054_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0055_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0055_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0056-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0056-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0057_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0057_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0058_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0058_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0059_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0059_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0060_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0060_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0061_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0061_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0062_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0062_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0063_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0063_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0064_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0064_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0065_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0065_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0067_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0067_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0068_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0068_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0069_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0069_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0070_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0070_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0071_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0071_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0072_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0072_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0073_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0073_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0074_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0074_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0075_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0075_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0076_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0076_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0077_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0077_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0078_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0078_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0079_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0079_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0080_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0080_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0081_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0081_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0082_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0082_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0083_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0083_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0084_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0084_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0085_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0085_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0086_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0086_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0087_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0087_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0088_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0088_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0089_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0089_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0090_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0090_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0091_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0091_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0092_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0092_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0093_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0093_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0094_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0094_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0095_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0095_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0096_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0096_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0097_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0097_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0098_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0098_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0099_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0099_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0100_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0100_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0101_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0101_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0102_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0102_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0103_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0103_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0104_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0104_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0107_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0107_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0108_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0108_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0109_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0109_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0111_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0111_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0112-2_Operator_1 Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0112-2_Operator_2 Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0112_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0112_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0113_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0113_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0114_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0114_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0115_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0115_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0116_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0116_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0117_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0117_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0118_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0118_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0120_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0120_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0121_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0121_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0122_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0122_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0123_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0123_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0125_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0125_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0126_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0126_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0127_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0127_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0128_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0128_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0130_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0130_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0131_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0131_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0132_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0132_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0133_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0133_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0134_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0134_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0135_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0135_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0136_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0136_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0137_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0137_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0138_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0138_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0139_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0139_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0140_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0140_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0141_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0141_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0142_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0142_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0143_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0143_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0144_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0144_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0145_Operator_1                                   <NA>         1
#> T-26-0145_Operator_2                                   <NA>         2
#> T-26-0146_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0146_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0147_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0147_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0148_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0148_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0149_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0149_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0150_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0150_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0151_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0151_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0152_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0152_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0153_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0153_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0154_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0154_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0155_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0155_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0156_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0156_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0157_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0157_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0158_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0158_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0159_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0159_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0160_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0160_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0161_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0161_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0162_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0162_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0163_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0163_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0164_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0164_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0165_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0165_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0166_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0166_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0167_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0167_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0168_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0168_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0169_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0169_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0170_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0170_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0171_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0171_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0172_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0172_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0173_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0173_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0174_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0174_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0175_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0175_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0176_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0176_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0177_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0177_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0178_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0178_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0179-3_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0179-3_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0179_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0179_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0180_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0180_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0181_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0181_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0182_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0182_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0183_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0183_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0184_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0184_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0185_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0185_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0186_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0186_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0187_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0187_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0188_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0188_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0189_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0189_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0190_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0190_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0191_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0191_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0192_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0192_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0193_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0193_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0194_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0194_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0195_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0195_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0196_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0196_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0197_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0197_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0198_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0198_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0199_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0199_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0200_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0200_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0201_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0201_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0202_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0202_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0203_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0203_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0204_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0204_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0205_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0205_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0206_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0206_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0207_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0207_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0208_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0208_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0209_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0209_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0210_Operator_1               Barbus barbus       <NA>         1
#> T-26-0210_Operator_2               Barbus barbus       <NA>         2
#> T-26-0211_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0211_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0212_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0212_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0213_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0213_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0214_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0214_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0215_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0215_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0216_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0216_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0217_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0217_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0218_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0218_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0219_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0219_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0220_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0220_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0221_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0221_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0222_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0222_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0223_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0223_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0224_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0224_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0225_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0225_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0226_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0226_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0227_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0227_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0228_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0228_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0229_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0229_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0230-1_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-1_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-2_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-2_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-3_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-3_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-4_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-4_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0231_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0231_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0232_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0232_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0233_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0233_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0234_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0234_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0235_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0235_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0236_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0236_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0237_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0237_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0238_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0238_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0239_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0239_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0240_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0240_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0241_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0241_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0242_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0242_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0243_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0243_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0244_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0244_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0245_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0245_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0246_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0246_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0247_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0247_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0248_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0248_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0249_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0249_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0250_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0250_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0251_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0251_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0252_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0252_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0261-1_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-1_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-3_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-3_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-4_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-4_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-5_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-5_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0262-1_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0262-1_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0262-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0262-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0263_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0263_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0264-1_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-1_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-2_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-2_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-3_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-3_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-4_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0264-4_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0265_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0265_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0266_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0266_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0267_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0267_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0268_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0268_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0269_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0269_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0270-1_Operator_1         Squalius cephalus       <NA>         1
#> T-26-0270-1_Operator_2         Squalius cephalus       <NA>         2
#> T-26-0270-2_Operator_1         Squalius cephalus       <NA>         1
#> T-26-0270-2_Operator_2         Squalius cephalus       <NA>         2
#> T-26-0271_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0271_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0272_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0272_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0273_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0273_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0274_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0274_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0275_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0275_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0276_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0276_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0277_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0277_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0278-1_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0278-1_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0278-2_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0278-2_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0279_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0279_Operator_2         Barbatula barbatula       <NA>         2
#>                          operator        Bl         Bd          Hd          Eh
#> T-26-0001_Operator_1   Operator_1  6.956905  1.8123997          NA  1.34404475
#> T-26-0001_Operator_2   Operator_2  6.909410  1.7949041          NA  1.36365235
#> T-26-0002_Operator_1   Operator_1  8.302798  1.9909529          NA  1.52249892
#> T-26-0002_Operator_2   Operator_2  8.216624  2.0207893          NA  1.53560616
#> T-26-0003_Operator_1   Operator_1  6.967443  1.6928692          NA  1.21165768
#> T-26-0003_Operator_2   Operator_2  6.913182  1.7159790          NA  1.16657065
#> T-26-0004_Operator_1   Operator_1 18.176255  4.5559409  2.07742509  2.77003273
#> T-26-0004_Operator_2   Operator_2 17.783260  4.5636753  2.03145378  2.77399122
#> T-26-0005_Operator_1   Operator_1  5.596071  1.2880802          NA  1.05787210
#> T-26-0005_Operator_2   Operator_2  6.332844  1.2700604          NA  1.09361071
#> T-26-0006_Operator_1   Operator_1  7.668080  1.8662513          NA  1.30295851
#> T-26-0006_Operator_2   Operator_2  7.712358  1.9168742          NA  1.32881958
#> T-26-0007_Operator_1   Operator_1 17.379257  4.7743456  2.17509366  2.97608629
#> T-26-0007_Operator_2   Operator_2 17.574467  4.9769778  2.19813968  3.10917326
#> T-26-0008_Operator_1   Operator_1 14.181427  3.6643534  1.71913958  2.69166771
#> T-26-0008_Operator_2   Operator_2 13.996664  3.8567416  1.70080238  2.59696033
#> T-26-0009_Operator_1   Operator_1  5.642172  2.3754338  1.20142779  1.42326286
#> T-26-0009_Operator_2   Operator_2  5.510208  2.3900134  1.19458556  1.47378738
#> T-26-0010_Operator_1   Operator_1  8.594692  2.2922567          NA  1.83231627
#> T-26-0010_Operator_2   Operator_2  8.468550  2.2858828  2.03327424  1.82503963
#> T-26-0011_Operator_1   Operator_1 25.392853  6.8890836          NA  5.30891678
#> T-26-0011_Operator_2   Operator_2 25.140844  7.3332416  5.68314347  5.47275133
#> T-26-0012_Operator_1   Operator_1  6.184369  1.4550365          NA  1.03884218
#> T-26-0012_Operator_2   Operator_2  6.141980  1.4850224  2.04434357  1.09392491
#> T-26-0013_Operator_1   Operator_1  8.109554  1.9417022          NA  1.27322269
#> T-26-0013_Operator_2   Operator_2  8.220899  1.9820605          NA  1.33120290
#> T-26-0014_Operator_1   Operator_1  8.493603  2.1291592          NA  1.70885906
#> T-26-0014_Operator_2   Operator_2  8.214899  2.1427808          NA  1.75136827
#> T-26-0015_Operator_1   Operator_1  7.819466  1.8346854          NA  1.38288573
#> T-26-0015_Operator_2   Operator_2  7.517800  1.8792245          NA  1.32901134
#> T-26-0016_Operator_1   Operator_1 10.753049  3.0456843  1.64945945  1.78101836
#> T-26-0016_Operator_2   Operator_2 10.305716  3.0171921          NA  1.85339814
#> T-26-0017_Operator_1   Operator_1  6.726832  1.6402465          NA  1.15552726
#> T-26-0017_Operator_2   Operator_2  6.452745  1.6092342          NA  1.16751601
#> T-26-0018_Operator_1   Operator_1 20.278560  6.1662950          NA  4.35988423
#> T-26-0018_Operator_2   Operator_2 19.167795  5.9244848  3.21772348  4.11887779
#> T-26-0019_Operator_1   Operator_1 13.241658  3.2726988  1.56572789  1.82243630
#> T-26-0019_Operator_2   Operator_2 12.895929  3.2011626  1.52452280  1.79193965
#> T-26-0020_Operator_1   Operator_1  9.224436  2.6190706          NA  2.01936043
#> T-26-0020_Operator_2   Operator_2  9.140239  2.6055508  2.30552072  2.02564505
#> T-26-0021_Operator_1   Operator_1  9.330086  2.6421536  1.37595784  1.28579612
#> T-26-0021_Operator_2   Operator_2  8.823626  2.5099881  1.35584392  1.28691637
#> T-26-0022_Operator_1   Operator_1 11.489489  2.8127576  1.43508258  1.69688740
#> T-26-0022_Operator_2   Operator_2 11.399654  2.8368035  1.38535785  1.65246897
#> T-26-0023-2_Operator_1 Operator_1  3.967063  0.8906095  0.49833079  0.44111884
#> T-26-0023-2_Operator_2 Operator_2  3.954428  0.9126688          NA  0.43264353
#> T-26-0024_Operator_1   Operator_1  9.185208  2.3286996          NA  1.87107369
#> T-26-0024_Operator_2   Operator_2  8.638556  2.1887872          NA  1.82598108
#> T-26-0025_Operator_1   Operator_1  9.465836  2.6764249          NA  2.16027527
#> T-26-0025_Operator_2   Operator_2  9.257391  2.6127906          NA  2.19584397
#> T-26-0026_Operator_1   Operator_1  9.533145  2.5835183  1.39915422  1.76514292
#> T-26-0026_Operator_2   Operator_2  9.306362  2.5743509          NA  1.80660019
#> T-26-0027_Operator_1   Operator_1  9.895108  2.6291326          NA  2.27495920
#> T-26-0027_Operator_2   Operator_2  9.731939  2.6157876          NA  2.11798437
#> T-26-0028_Operator_1   Operator_1  7.189649  1.9311310          NA  1.49756238
#> T-26-0028_Operator_2   Operator_2  6.991455  1.9535092          NA  1.53814672
#> T-26-0029_Operator_1   Operator_1  3.792798  1.4632856  0.78281775  0.79311048
#> T-26-0029_Operator_2   Operator_2  3.774153  1.4640376  0.77164747  0.81777134
#> T-26-0030_Operator_1   Operator_1 12.584474  3.1025686  1.57554583  2.19843278
#> T-26-0030_Operator_2   Operator_2 12.573432  3.1914753  1.56823318  2.00154821
#> T-26-0031_Operator_1   Operator_1  7.901356  2.0818330          NA  1.63243659
#> T-26-0031_Operator_2   Operator_2  7.698888  2.0799672  1.59535771  1.63712543
#> T-26-0032_Operator_1   Operator_1 26.719407  7.1288922  3.67607362  5.69614510
#> T-26-0032_Operator_2   Operator_2 25.703313  7.3226715  3.45258256  5.14724449
#> T-26-0033_Operator_1   Operator_1  8.960122  2.4672505          NA  2.08049685
#> T-26-0033_Operator_2   Operator_2  8.999446  2.5083200          NA  2.02284351
#> T-26-0034_Operator_1   Operator_1  8.654831  2.5514849          NA  1.86082647
#> T-26-0034_Operator_2   Operator_2  8.591478  2.5197275          NA  1.97699532
#> T-26-0035_Operator_1   Operator_1  5.944340  1.4017315          NA  1.18015056
#> T-26-0035_Operator_2   Operator_2  5.950211  1.4178243          NA  1.13736318
#> T-26-0036_Operator_1   Operator_1 13.393856  3.3361232  1.56328709  2.25435727
#> T-26-0036_Operator_2   Operator_2 13.153902  3.2912097  1.46860041  2.11626628
#> T-26-0037_Operator_1   Operator_1 16.294212  4.2577825  1.96223025  2.98959727
#> T-26-0037_Operator_2   Operator_2 16.231102  4.2484537  1.93040404  2.69652460
#> T-26-0038_Operator_1   Operator_1  6.891866  1.8297464          NA  1.43863180
#> T-26-0038_Operator_2   Operator_2  6.614041  1.7895605          NA  1.34668818
#> T-26-0039_Operator_1   Operator_1  7.783351  2.1312844  0.99975888  1.21787668
#> T-26-0039_Operator_2   Operator_2  7.758650  2.1034719  1.01586592  1.24973000
#> T-26-0040_Operator_1   Operator_1  8.663642  2.2088181          NA  1.57332776
#> T-26-0040_Operator_2   Operator_2  8.442752  2.1486681  1.27849720  1.56892908
#> T-26-0041_Operator_1   Operator_1  6.533798  1.5643513          NA  1.17400843
#> T-26-0041_Operator_2   Operator_2  6.310595  1.5495743          NA  1.16239801
#> T-26-0042_Operator_1   Operator_1  9.260328  2.2660578          NA  1.75665220
#> T-26-0042_Operator_2   Operator_2  9.120995  2.2907217          NA  1.74495525
#> T-26-0043_Operator_1   Operator_1  8.333438  1.8802280          NA  1.16912256
#> T-26-0043_Operator_2   Operator_2  8.026394  1.8520647  1.08582428  1.27777313
#> T-26-0044_Operator_1   Operator_1  8.762759  2.5332347          NA  1.91559352
#> T-26-0044_Operator_2   Operator_2  8.450378  2.5126301  1.51396747  1.90428864
#> T-26-0045_Operator_1   Operator_1 14.432664  3.7250346  1.76427017  2.12983583
#> T-26-0045_Operator_2   Operator_2 13.710136  3.5214603  1.72043935  2.12659074
#> T-26-0046_Operator_1   Operator_1  8.891113  2.2362600          NA  1.70509712
#> T-26-0046_Operator_2   Operator_2  8.359665  2.2282532          NA  1.64792400
#> T-26-0047_Operator_1   Operator_1 27.397544  7.7959037  3.31061099  6.04144575
#> T-26-0047_Operator_2   Operator_2 26.849874  8.0428196  3.36750035  5.75093060
#> T-26-0048_Operator_1   Operator_1  9.765520  2.2772458          NA  1.70011877
#> T-26-0048_Operator_2   Operator_2  9.485998  2.3282226  1.52968082  1.75044441
#> T-26-0049_Operator_1   Operator_1 13.395474  3.3167758  1.60846599  1.86967216
#> T-26-0049_Operator_2   Operator_2 13.112018  3.2862615  1.59587345  1.95172922
#> T-26-0050_Operator_1   Operator_1  7.731364  2.0225162          NA  1.54507034
#> T-26-0050_Operator_2   Operator_2  7.371336  0.1205212  0.06514658  0.09120521
#> T-26-0051_Operator_1   Operator_1 10.026297  2.6230682          NA  2.03731683
#> T-26-0051_Operator_2   Operator_2 10.218053  2.7299023  1.64139642  2.11832458
#> T-26-0052_Operator_1   Operator_1  7.515557  0.7017406  0.86677115  0.44772991
#> T-26-0052_Operator_2   Operator_2 14.866571  3.7870239  1.73670006  2.10064314
#> T-26-0053_Operator_1   Operator_1 15.200389  4.0809297  1.89904444  2.21047371
#> T-26-0053_Operator_2   Operator_2 14.482921  3.8863519  1.78051131  2.10160343
#> T-26-0054_Operator_1   Operator_1 13.532245  3.5261626  1.75430079  2.23024756
#> T-26-0054_Operator_2   Operator_2 13.577729  3.5227031  1.72522014  2.26343323
#> T-26-0055_Operator_1   Operator_1  9.657703  2.6389034          NA  2.11231002
#> T-26-0055_Operator_2   Operator_2  9.446884  2.6510382          NA  2.08574503
#> T-26-0056-2_Operator_1 Operator_1 10.608752  3.0334717          NA  2.34440505
#> T-26-0056-2_Operator_2 Operator_2 10.365377  2.9766864  1.58446403  2.24120574
#> T-26-0057_Operator_1   Operator_1  8.628830  2.4016155  1.18082484  1.71359902
#> T-26-0057_Operator_2   Operator_2  8.383760  2.3603073  1.18179042  1.77103372
#> T-26-0058_Operator_1   Operator_1  9.598353  2.6245375          NA  2.03989712
#> T-26-0058_Operator_2   Operator_2        NA         NA          NA          NA
#> T-26-0059_Operator_1   Operator_1 10.032306  2.6663582          NA  1.98219147
#> T-26-0059_Operator_2   Operator_2  9.850798  2.6606743  1.40231096  2.01363978
#> T-26-0060_Operator_1   Operator_1  8.845626  2.1341875          NA  1.61725054
#> T-26-0060_Operator_2   Operator_2  8.716633  2.0954773  1.26243237  1.58495110
#> T-26-0061_Operator_1   Operator_1 14.819986  3.5949012  1.88789725  2.50377888
#> T-26-0061_Operator_2   Operator_2 14.773245  3.6136218  1.89748820  2.35734263
#> T-26-0062_Operator_1   Operator_1 18.349125  4.4785865  2.33284686  2.94564968
#> T-26-0062_Operator_2   Operator_2 18.859337  4.6198213  2.33060606  2.75290337
#> T-26-0063_Operator_1   Operator_1  6.699613  1.8139889          NA  1.54240609
#> T-26-0063_Operator_2   Operator_2  6.651589  1.8494779  0.94158897  1.55375077
#> T-26-0064_Operator_1   Operator_1  8.282579  2.1990608          NA  1.43857329
#> T-26-0064_Operator_2   Operator_2  8.269170  2.2426590  1.23575968  1.50700200
#> T-26-0065_Operator_1   Operator_1  8.860755  2.3958781          NA  1.87383949
#> T-26-0065_Operator_2   Operator_2  8.774428  2.4387755  1.30509848  1.85999365
#> T-26-0067_Operator_1   Operator_1  9.098319  2.6308665  1.33399329  1.92008053
#> T-26-0067_Operator_2   Operator_2  9.223213  2.6375057  1.35963502  1.96874870
#> T-26-0068_Operator_1   Operator_1 11.707055  2.9026090  1.52801260  1.81390960
#> T-26-0068_Operator_2   Operator_2 11.810203  2.9635730  1.49207967  1.78437465
#> T-26-0069_Operator_1   Operator_1  8.111636  1.9366804  1.06455447  1.06089148
#> T-26-0069_Operator_2   Operator_2  8.132650  1.9772293  1.07914792  1.03210893
#> T-26-0070_Operator_1   Operator_1  9.236925  2.4823162  1.20784079  1.32652685
#> T-26-0070_Operator_2   Operator_2  9.156101  2.3569347  1.19962438  1.36516012
#> T-26-0071_Operator_1   Operator_1  8.119705  1.9232598  1.22083818  1.55517847
#> T-26-0071_Operator_2   Operator_2  8.082817  1.9567676  1.21952080  1.47836837
#> T-26-0072_Operator_1   Operator_1  8.931884  2.1876938          NA  1.76923668
#> T-26-0072_Operator_2   Operator_2  8.891576  2.2295930  1.33411781  1.77645676
#> T-26-0073_Operator_1   Operator_1  9.728765  2.6030857          NA  2.08375790
#> T-26-0073_Operator_2   Operator_2  9.373260  2.5754048  1.44737708  2.03058241
#> T-26-0074_Operator_1   Operator_1  9.333662  2.4549746  1.39966547  1.62737601
#> T-26-0074_Operator_2   Operator_2  9.228916  2.5103115  1.39214648  1.73015492
#> T-26-0075_Operator_1   Operator_1 11.256087  3.0982388  1.66213559  2.50057094
#> T-26-0075_Operator_2   Operator_2 11.463401  3.1431894  1.68809751  2.43793978
#> T-26-0076_Operator_1   Operator_1 11.260369  2.7816905  1.41612902  1.77883205
#> T-26-0076_Operator_2   Operator_2 11.130889  2.8355818  1.40325897  1.63572244
#> T-26-0077_Operator_1   Operator_1  5.874145  1.4128496          NA  1.00464849
#> T-26-0077_Operator_2   Operator_2  5.947631  1.4565088  0.85648600  1.01084761
#> T-26-0078_Operator_1   Operator_1  9.678709  2.4885850          NA  1.59817486
#> T-26-0078_Operator_2   Operator_2  9.606177  2.4278515  1.43951638  1.64075152
#> T-26-0079_Operator_1   Operator_1  7.794510  2.1829866          NA  1.62704563
#> T-26-0079_Operator_2   Operator_2  7.822441  2.2136848  1.07733715  1.67877053
#> T-26-0080_Operator_1   Operator_1  6.414039  1.7310801  0.85067042  0.93987846
#> T-26-0080_Operator_2   Operator_2  6.454427  1.7066608  0.86472915  0.96368793
#> T-26-0081_Operator_1   Operator_1  5.482068  1.2750692          NA  0.82025779
#> T-26-0081_Operator_2   Operator_2  5.639310  1.3653552          NA  0.87121078
#> T-26-0082_Operator_1   Operator_1  8.768688  2.2752182  1.07658830  1.46769024
#> T-26-0082_Operator_2   Operator_2  8.784480  2.2808016  1.09774775  1.40601394
#> T-26-0083_Operator_1   Operator_1  5.330012  1.3590002          NA  1.03641749
#> T-26-0083_Operator_2   Operator_2  5.303435  1.3589245          NA  1.05411688
#> T-26-0084_Operator_1   Operator_1  6.613543  1.7652692          NA  1.21541024
#> T-26-0084_Operator_2   Operator_2  6.750088  1.8186322          NA  1.36473878
#> T-26-0085_Operator_1   Operator_1  8.012648  2.2408643  1.18633526  1.37464245
#> T-26-0085_Operator_2   Operator_2  8.194352  2.2723100  1.19128512  1.46455888
#> T-26-0086_Operator_1   Operator_1  9.286351  2.2272747          NA  1.82469148
#> T-26-0086_Operator_2   Operator_2  8.979844  2.2511138  1.38595421  1.81411865
#> T-26-0087_Operator_1   Operator_1  7.799946  2.1208703          NA  1.72198932
#> T-26-0087_Operator_2   Operator_2  7.615699  2.1173923  2.73059968  1.67602019
#> T-26-0088_Operator_1   Operator_1  8.003724  2.2435349          NA  1.34893971
#> T-26-0088_Operator_2   Operator_2  8.033052  2.2833829          NA  1.53616836
#> T-26-0089_Operator_1   Operator_1  3.365617  0.6594441  0.45091726  0.34778861
#> T-26-0089_Operator_2   Operator_2  3.309281  0.7178999  0.45205288  0.36729283
#> T-26-0090_Operator_1   Operator_1  4.446949  0.9875485  0.60164680  0.67767514
#> T-26-0090_Operator_2   Operator_2  4.488751  1.0001464  0.61798873  0.68768913
#> T-26-0091_Operator_1   Operator_1  8.879337  2.0752306  1.28835082  1.50508103
#> T-26-0091_Operator_2   Operator_2  8.857758  2.2208200  1.32210905  1.63781119
#> T-26-0092_Operator_1   Operator_1  8.798930  2.5024304          NA  1.53638218
#> T-26-0092_Operator_2   Operator_2  8.673963  2.4739225          NA  1.70157879
#> T-26-0093_Operator_1   Operator_1  8.271604  2.2652431          NA  1.75124810
#> T-26-0093_Operator_2   Operator_2  8.245474  2.2658557          NA  1.81069552
#> T-26-0094_Operator_1   Operator_1  6.816662  1.7308191  1.02762452  1.28451799
#> T-26-0094_Operator_2   Operator_2  6.744345  1.7319854          NA  1.30308781
#> T-26-0095_Operator_1   Operator_1  7.591034  1.8502765          NA  1.35041409
#> T-26-0095_Operator_2   Operator_2  7.432418  1.9102882          NA  1.41887164
#> T-26-0096_Operator_1   Operator_1  6.393025  1.7089214  0.86850980  1.17503235
#> T-26-0096_Operator_2   Operator_2  6.271418  1.6647321  0.86946320  1.24883147
#> T-26-0097_Operator_1   Operator_1  8.917207  2.2481345  1.30475710  1.46413549
#> T-26-0097_Operator_2   Operator_2  8.856381  2.2439584  1.31672598  1.55290147
#> T-26-0098_Operator_1   Operator_1  7.763619  1.9028971          NA  1.41233954
#> T-26-0098_Operator_2   Operator_2  7.555446  1.9380677  1.03947538  1.28484317
#> T-26-0099_Operator_1   Operator_1  4.141031  0.9300604  0.51973084  0.41636252
#> T-26-0099_Operator_2   Operator_2  4.160279  0.9683299  0.52783711  0.46294377
#> T-26-0100_Operator_1   Operator_1  6.383691  1.6760671          NA  1.16468213
#> T-26-0100_Operator_2   Operator_2  6.312897  1.6876373  1.28611430  1.24648937
#> T-26-0101_Operator_1   Operator_1  6.990892  2.2156723          NA  1.66382649
#> T-26-0101_Operator_2   Operator_2  7.395853  2.1342374          NA  1.62111073
#> T-26-0102_Operator_1   Operator_1  7.519589  1.9682694          NA  1.39771987
#> T-26-0102_Operator_2   Operator_2  7.416510  1.9901418          NA  1.41525917
#> T-26-0103_Operator_1   Operator_1  9.426845  2.5461368  1.41818546  1.59256083
#> T-26-0103_Operator_2   Operator_2  9.574033  2.7140325  1.41771092  1.73952291
#> T-26-0104_Operator_1   Operator_1  8.412130  2.3556548          NA  1.44136798
#> T-26-0104_Operator_2   Operator_2  9.063534  2.5229216  1.21153105  1.65867214
#> T-26-0107_Operator_1   Operator_1  8.448413  2.3870000          NA  1.67822228
#> T-26-0107_Operator_2   Operator_2        NA         NA          NA          NA
#> T-26-0108_Operator_1   Operator_1  8.389500  2.0275135          NA  1.21316601
#> T-26-0108_Operator_2   Operator_2  8.949133  2.1748433          NA  1.38633914
#> T-26-0109_Operator_1   Operator_1  9.367584  2.4645421          NA  1.82551240
#> T-26-0109_Operator_2   Operator_2  8.995382  2.4414451          NA  1.71812815
#> T-26-0111_Operator_1   Operator_1  3.063680  0.6515520          NA  0.50371044
#> T-26-0111_Operator_2   Operator_2  3.164542  0.7050612          NA  0.44669338
#> T-26-0112-2_Operator_1 Operator_1  6.557598  1.5911264  0.90463889  1.05923602
#> T-26-0112-2_Operator_2 Operator_2  6.526428  1.5917784  0.88005813  1.11339756
#> T-26-0112_Operator_1   Operator_1  3.797588  0.8669887  0.53887976  0.53580545
#> T-26-0112_Operator_2   Operator_2  3.851295  0.9083065  0.53665224  0.58702676
#> T-26-0113_Operator_1   Operator_1  6.709608  1.5969789  0.98169094  0.86856780
#> T-26-0113_Operator_2   Operator_2  6.862344  1.5918620          NA  1.02373623
#> T-26-0114_Operator_1   Operator_1  7.372738  1.9359052          NA  1.33139294
#> T-26-0114_Operator_2   Operator_2  9.056416  2.3650560          NA  1.52250388
#> T-26-0115_Operator_1   Operator_1  9.004481  2.3915973          NA  1.40914962
#> T-26-0115_Operator_2   Operator_2  7.251247  1.7833073          NA  1.18222026
#> T-26-0116_Operator_1   Operator_1  7.304079  1.7850164  0.99974990  1.08191947
#> T-26-0116_Operator_2   Operator_2  7.734555  1.9960502          NA  1.46332794
#> T-26-0117_Operator_1   Operator_1  7.806228  2.0016502          NA  1.36327739
#> T-26-0117_Operator_2   Operator_2  8.625387  2.2073313          NA  1.72767542
#> T-26-0118_Operator_1   Operator_1  8.728475  2.1743177          NA  1.69327867
#> T-26-0118_Operator_2   Operator_2  7.669691  1.9329878          NA  1.39107999
#> T-26-0120_Operator_1   Operator_1  6.896045  1.5939239  1.00306863  1.22753369
#> T-26-0120_Operator_2   Operator_2  6.668463  1.5926964  0.97623721  1.12963043
#> T-26-0121_Operator_1   Operator_1  7.285077  1.8572006          NA  1.34455105
#> T-26-0121_Operator_2   Operator_2  3.208333 34.4166667          NA 25.00000000
#> T-26-0122_Operator_1   Operator_1  8.757708  2.3177521  1.29916437  1.53529855
#> T-26-0122_Operator_2   Operator_2  8.604047  2.3067879          NA  1.49829738
#> T-26-0123_Operator_1   Operator_1  7.937351  1.9471496          NA  1.25384065
#> T-26-0123_Operator_2   Operator_2  7.852605  1.9741881          NA  1.39039907
#> T-26-0125_Operator_1   Operator_1  6.883640  1.4799444          NA  1.05030093
#> T-26-0125_Operator_2   Operator_2  7.067181  1.5246391          NA  1.18013384
#> T-26-0126_Operator_1   Operator_1  6.831146  1.8914700          NA  1.30322478
#> T-26-0126_Operator_2   Operator_2  6.812574  1.8494426          NA  1.36752653
#> T-26-0127_Operator_1   Operator_1  8.633812  2.4628407          NA  1.74637804
#> T-26-0127_Operator_2   Operator_2  8.506932  2.4907511          NA  1.72713822
#> T-26-0128_Operator_1   Operator_1  7.059841  1.6927304  0.92691005  0.97638684
#> T-26-0128_Operator_2   Operator_2  6.945708  1.6581190  0.92486371  1.02845206
#> T-26-0130_Operator_1   Operator_1  5.140970  1.1801542  0.69592828  0.74110598
#> T-26-0130_Operator_2   Operator_2  5.252193  1.2266916  0.69047153  0.75737485
#> T-26-0131_Operator_1   Operator_1  9.225005  2.4041048          NA  1.60957784
#> T-26-0131_Operator_2   Operator_2  9.144279  2.3890129  1.19620885  1.60947041
#> T-26-0132_Operator_1   Operator_1  8.788302  2.5143954          NA  1.80818974
#> T-26-0132_Operator_2   Operator_2  8.806004  2.5747811  1.26227432  1.85327814
#> T-26-0133_Operator_1   Operator_1  8.709623  2.3630401  1.30811438  1.08896047
#> T-26-0133_Operator_2   Operator_2  8.431688  2.3874379  1.30626562  1.15661652
#> T-26-0134_Operator_1   Operator_1  8.446534  2.1772030          NA  1.70098102
#> T-26-0134_Operator_2   Operator_2  8.287391  2.1760949          NA  1.68464547
#> T-26-0135_Operator_1   Operator_1  8.920931  2.3447820  1.30341728  1.14482113
#> T-26-0135_Operator_2   Operator_2  8.699713  2.3038453  1.33454082  1.19812723
#> T-26-0136_Operator_1   Operator_1  8.621097  2.3489091  1.19154898  1.65724103
#> T-26-0136_Operator_2   Operator_2  8.478081  2.3503021  1.18421759  1.63616218
#> T-26-0137_Operator_1   Operator_1 15.465536  3.9723848  1.74305979  2.19257975
#> T-26-0137_Operator_2   Operator_2 15.549965  3.9557902  1.74593123  2.23720566
#> T-26-0138_Operator_1   Operator_1  7.887967  2.1021399          NA  1.47625317
#> T-26-0138_Operator_2   Operator_2  7.820357  2.1457654          NA  1.53560819
#> T-26-0139_Operator_1   Operator_1  8.565085  2.2107216          NA  1.59174756
#> T-26-0139_Operator_2   Operator_2  8.659723  2.2799644          NA  1.62839821
#> T-26-0140_Operator_1   Operator_1  6.661244  1.6529605          NA  1.16893899
#> T-26-0140_Operator_2   Operator_2  6.496649  1.6172620          NA  1.19291497
#> T-26-0141_Operator_1   Operator_1  8.729264  2.2536320          NA  1.61653103
#> T-26-0141_Operator_2   Operator_2  8.654856  2.2346306          NA  1.61961657
#> T-26-0142_Operator_1   Operator_1  6.800358  1.6981936          NA  1.20519983
#> T-26-0142_Operator_2   Operator_2  6.782372  1.6508407          NA  1.23156166
#> T-26-0143_Operator_1   Operator_1  7.958629  1.9903115  1.02710318  1.14576837
#> T-26-0143_Operator_2   Operator_2  7.825501  1.9928111  1.04060077  1.15916159
#> T-26-0144_Operator_1   Operator_1 11.211236  2.4429442  1.43577710  1.21119006
#> T-26-0144_Operator_2   Operator_2 11.159604  2.4118264  1.48352101  1.36521013
#> T-26-0145_Operator_1   Operator_1  3.476759  0.7309580  0.46238094  0.42838425
#> T-26-0145_Operator_2   Operator_2  3.451907  0.7344281  0.47008515  0.48343001
#> T-26-0146_Operator_1   Operator_1 10.308065  2.7416093          NA  2.15639981
#> T-26-0146_Operator_2   Operator_2 10.188815  2.7121380          NA  2.25731232
#> T-26-0147_Operator_1   Operator_1 10.774301  2.8913951  1.38201660  1.95237168
#> T-26-0147_Operator_2   Operator_2 10.752577  2.8905814  1.33279036  2.03060430
#> T-26-0148_Operator_1   Operator_1 14.048013  3.9101272  1.80229398  2.33367123
#> T-26-0148_Operator_2   Operator_2 14.198808  3.9743894  1.87017709  2.34447817
#> T-26-0149_Operator_1   Operator_1 25.516170  7.3873446  3.26289624  5.27619945
#> T-26-0149_Operator_2   Operator_2 24.925403  7.2806500  3.17045875  4.84407632
#> T-26-0150_Operator_1   Operator_1 16.870102  4.1728676  1.95040794  2.64946319
#> T-26-0150_Operator_2   Operator_2 16.424974  4.0354734  1.92887094  2.70217459
#> T-26-0151_Operator_1   Operator_1  9.272882  2.4256385  1.35809803  1.53370683
#> T-26-0151_Operator_2   Operator_2  9.127870  2.4361745          NA  1.61047642
#> T-26-0152_Operator_1   Operator_1  3.270295  0.7321141  0.45786119  0.48278351
#> T-26-0152_Operator_2   Operator_2  3.251710  0.7099794  0.46244497  0.48645379
#> T-26-0153_Operator_1   Operator_1  7.981994  1.9261933  1.15027773  1.11686946
#> T-26-0153_Operator_2   Operator_2  7.845549  1.9238201  1.16042804  1.19813944
#> T-26-0154_Operator_1   Operator_1  6.615922  1.6521925          NA  1.21221021
#> T-26-0154_Operator_2   Operator_2  6.518228  1.6443351  0.91792209  1.20999415
#> T-26-0155_Operator_1   Operator_1  4.815762  1.1612617          NA  0.78663794
#> T-26-0155_Operator_2   Operator_2  4.776994  1.1448388          NA  0.80712228
#> T-26-0156_Operator_1   Operator_1 20.121423  5.2837334  2.67573848  3.68924833
#> T-26-0156_Operator_2   Operator_2 19.641689  5.4229035  2.63977767  3.48798958
#> T-26-0157_Operator_1   Operator_1  9.358347  2.3869948  1.39416632  1.62542262
#> T-26-0157_Operator_2   Operator_2  8.907494  2.3171223  1.33104906  1.63929513
#> T-26-0158_Operator_1   Operator_1  8.318043  2.1277062  1.16775718  1.57726758
#> T-26-0158_Operator_2   Operator_2  8.175117  2.1488449  1.14739781  1.59071719
#> T-26-0159_Operator_1   Operator_1  8.960234  2.3460201  1.34569258  1.42667893
#> T-26-0159_Operator_2   Operator_2  8.582365  2.2620205          NA  1.42360628
#> T-26-0160_Operator_1   Operator_1  8.453321  2.1711909          NA  1.38869473
#> T-26-0160_Operator_2   Operator_2  8.336273  2.1665103          NA  1.45771702
#> T-26-0161_Operator_1   Operator_1  7.743955  1.9731189          NA  1.43310875
#> T-26-0161_Operator_2   Operator_2  7.469785  1.9398479          NA  1.45093211
#> T-26-0162_Operator_1   Operator_1  7.579910  2.0401309          NA  1.44291029
#> T-26-0162_Operator_2   Operator_2  7.333056  2.0065741          NA  1.49013163
#> T-26-0163_Operator_1   Operator_1  9.098792  2.3133718          NA  1.45334862
#> T-26-0163_Operator_2   Operator_2  8.855654  2.2926088  1.20526922  1.53277924
#> T-26-0164_Operator_1   Operator_1  4.803193  1.1345773  0.64169565  0.62509792
#> T-26-0164_Operator_2   Operator_2  4.770349  1.1269188  0.62200509  0.66367252
#> T-26-0165_Operator_1   Operator_1  7.452509  1.9783993  0.96896036  1.34167217
#> T-26-0165_Operator_2   Operator_2  7.428954  1.9647288  0.98880451  1.41112327
#> T-26-0166_Operator_1   Operator_1  4.240233  1.0499275  0.61195469  0.68878260
#> T-26-0166_Operator_2   Operator_2  4.173335  1.0033843  0.60206659  0.70044203
#> T-26-0167_Operator_1   Operator_1 27.786992  7.3615627  3.23855253  4.93945011
#> T-26-0167_Operator_2   Operator_2 26.260097  7.3047829  3.18272253  4.80890050
#> T-26-0168_Operator_1   Operator_1  8.493020  2.4630116  1.15014470  1.59243517
#> T-26-0168_Operator_2   Operator_2  8.139477  2.3948990  1.10971799  1.60845617
#> T-26-0169_Operator_1   Operator_1 10.428105  2.6561016  1.49379347  1.79099943
#> T-26-0169_Operator_2   Operator_2 20.204788  5.2176107  2.91026208  3.63548664
#> T-26-0170_Operator_1   Operator_1  9.826011  2.7498987  1.46423279  1.78566490
#> T-26-0170_Operator_2   Operator_2  9.493054  2.6706016  1.43743258  1.88025209
#> T-26-0171_Operator_1   Operator_1  9.916260  2.4626247  1.36215657  1.70436577
#> T-26-0171_Operator_2   Operator_2  9.538539  2.4687427  1.32771316  1.79989362
#> T-26-0172_Operator_1   Operator_1  9.883746  2.4073587  1.38730828  1.49610670
#> T-26-0172_Operator_2   Operator_2  9.265153  2.3111692  1.31930035  1.51678775
#> T-26-0173_Operator_1   Operator_1  6.836187  1.7343700  0.91898100  1.27485268
#> T-26-0173_Operator_2   Operator_2  6.593399  1.7306618  0.90380530  1.32568293
#> T-26-0174_Operator_1   Operator_1  8.147046  2.2818316          NA  1.76499271
#> T-26-0174_Operator_2   Operator_2  7.861860  2.2813141  1.34683851  1.79581239
#> T-26-0175_Operator_1   Operator_1  8.580691  2.1543244  1.22817860  1.60399072
#> T-26-0175_Operator_2   Operator_2  8.193555  2.0898922  1.21989210  1.61797936
#> T-26-0176_Operator_1   Operator_1  8.483066  2.3173658  1.33773276  1.46609793
#> T-26-0176_Operator_2   Operator_2  8.310732  2.2794353  1.31562208  1.53127661
#> T-26-0177_Operator_1   Operator_1  9.422164  2.7438138          NA  2.12365836
#> T-26-0177_Operator_2   Operator_2  9.297821  2.6920128          NA  2.05819935
#> T-26-0178_Operator_1   Operator_1  9.333639  2.3197344  1.37850192  1.70943047
#> T-26-0178_Operator_2   Operator_2  9.095360  2.3271231  1.38591595  1.78523142
#> T-26-0179-3_Operator_1 Operator_1  9.405112  2.5376131          NA  1.70792291
#> T-26-0179-3_Operator_2 Operator_2  9.035738  2.4723096          NA  1.67098368
#> T-26-0179_Operator_1   Operator_1  4.973261  1.2267470  0.65780744  0.67998765
#> T-26-0179_Operator_2   Operator_2  4.921452  1.2380851  0.66450281  0.77201983
#> T-26-0180_Operator_1   Operator_1  9.537697  2.5667124          NA  1.70613404
#> T-26-0180_Operator_2   Operator_2  9.072134  2.4748811  1.29776265  1.67108612
#> T-26-0181_Operator_1   Operator_1  8.217100  2.3505103  1.24742461  1.54014273
#> T-26-0181_Operator_2   Operator_2  7.993417  2.2672207  1.23054458  1.53358636
#> T-26-0182_Operator_1   Operator_1  7.892748  1.8398827          NA  1.31101639
#> T-26-0182_Operator_2   Operator_2  7.661711  1.7920132  1.19880897  1.31291624
#> T-26-0183_Operator_1   Operator_1  9.518076  2.4053677          NA  1.41256452
#> T-26-0183_Operator_2   Operator_2  9.361312  2.3909196  1.25476110  1.53224973
#> T-26-0184_Operator_1   Operator_1 10.269898  2.9913909  1.57286200  1.61300645
#> T-26-0184_Operator_2   Operator_2  9.658755  2.7081642  1.53764013  1.56031126
#> T-26-0185_Operator_1   Operator_1  7.273865  1.6675667  0.92878843  1.12792203
#> T-26-0185_Operator_2   Operator_2  6.952826  1.6485574  0.89777574  1.15451043
#> T-26-0186_Operator_1   Operator_1  9.774102  2.5524726  1.41280021  1.85260413
#> T-26-0186_Operator_2   Operator_2  9.593719  2.5653717  1.41275700  1.80321885
#> T-26-0187_Operator_1   Operator_1 10.136772  2.5030524  1.49008194  1.70854396
#> T-26-0187_Operator_2   Operator_2  9.599981  2.4379535  1.41674099  1.73966971
#> T-26-0188_Operator_1   Operator_1  7.082200  1.4585851          NA  0.90704980
#> T-26-0188_Operator_2   Operator_2  6.862648  1.4151438  0.69846150  0.90469732
#> T-26-0189_Operator_1   Operator_1  7.800557  2.0604721          NA  1.46284131
#> T-26-0189_Operator_2   Operator_2  7.495119  1.9729380  1.01262317  1.45213002
#> T-26-0190_Operator_1   Operator_1  8.623126  2.1599911  1.28711168  1.32310554
#> T-26-0190_Operator_2   Operator_2  8.233771  2.0736471  1.20941208  1.25748156
#> T-26-0191_Operator_1   Operator_1  8.613953  2.2135302          NA  1.47144644
#> T-26-0191_Operator_2   Operator_2  8.300240  2.1640947  1.26491167  1.45489771
#> T-26-0192_Operator_1   Operator_1  9.308992  2.3755984          NA  1.47645881
#> T-26-0192_Operator_2   Operator_2  8.765336  2.2708618  1.29522899  1.46816464
#> T-26-0193_Operator_1   Operator_1  8.856398  2.3068841          NA  1.78671127
#> T-26-0193_Operator_2   Operator_2  8.625857  2.2899181  1.34929007  1.86939879
#> T-26-0194_Operator_1   Operator_1 11.161935  2.9301445          NA  2.32413732
#> T-26-0194_Operator_2   Operator_2 10.636577  2.8412651  1.53075551  2.31243541
#> T-26-0195_Operator_1   Operator_1  9.319351  2.4288127          NA  1.50086031
#> T-26-0195_Operator_2   Operator_2  8.895387  2.3686426  1.22702850  1.51673449
#> T-26-0196_Operator_1   Operator_1  6.772870  1.6158914  0.91521989  0.98528067
#> T-26-0196_Operator_2   Operator_2  6.567802  1.5912703  0.87353315  0.96203803
#> T-26-0197_Operator_1   Operator_1  8.826393  2.4399619  1.26936172  1.65724360
#> T-26-0197_Operator_2   Operator_2  8.293598  2.3475460  1.21290481  1.64426807
#> T-26-0198_Operator_1   Operator_1  8.414324  2.2914596          NA  1.51871264
#> T-26-0198_Operator_2   Operator_2  7.911831  2.1652155  1.08512781  1.49592503
#> T-26-0199_Operator_1   Operator_1  6.406357  1.1933637          NA  0.83799600
#> T-26-0199_Operator_2   Operator_2  6.404326  1.1861374  0.65711171  0.87620481
#> T-26-0200_Operator_1   Operator_1  9.238281  2.6756751          NA  1.84141985
#> T-26-0200_Operator_2   Operator_2  8.957535  2.6161542  1.35013131  1.89608162
#> T-26-0201_Operator_1   Operator_1  7.622473  1.9509538          NA  1.27583515
#> T-26-0201_Operator_2   Operator_2  7.431919  1.9428145  1.01818080  1.30756557
#> T-26-0202_Operator_1   Operator_1 11.256176  3.2301116  1.95367549  1.61074700
#> T-26-0202_Operator_2   Operator_2 10.826783  3.0416890  1.87834447  1.57992674
#> T-26-0203_Operator_1   Operator_1  8.647504  2.0695971  1.20951532  1.49761784
#> T-26-0203_Operator_2   Operator_2  8.247246  2.0065113  1.16156779  1.46111268
#> T-26-0204_Operator_1   Operator_1  8.900694  2.1559594  1.22825891  1.35236131
#> T-26-0204_Operator_2   Operator_2  8.541752  2.1076327  1.18517801  1.35231541
#> T-26-0205_Operator_1   Operator_1  8.123299  2.0590722          NA  1.49336206
#> T-26-0205_Operator_2   Operator_2  7.870648  2.0330476  1.12194483  1.53616631
#> T-26-0206_Operator_1   Operator_1  7.269843  1.8387050          NA  1.15628802
#> T-26-0206_Operator_2   Operator_2  7.087511  1.8022614  0.98734084  1.24620193
#> T-26-0207_Operator_1   Operator_1  6.211687  1.5128630  0.82876487  0.90337076
#> T-26-0207_Operator_2   Operator_2  6.080203  1.4801871  0.79526831  0.92186204
#> T-26-0208_Operator_1   Operator_1  7.205718  1.3520205          NA  0.93363602
#> T-26-0208_Operator_2   Operator_2  6.940365  1.2926770  0.68150278  0.93253784
#> T-26-0209_Operator_1   Operator_1  9.433548  2.5500597          NA  1.81745558
#> T-26-0209_Operator_2   Operator_2  9.685861  2.5570727  1.32139160  1.83019064
#> T-26-0210_Operator_1   Operator_1  5.160863  1.1868964  0.70820412  0.74422718
#> T-26-0210_Operator_2   Operator_2  5.032432  1.1595538  0.69057538  0.74709424
#> T-26-0211_Operator_1   Operator_1  7.356858  1.9206923          NA  1.40432932
#> T-26-0211_Operator_2   Operator_2  7.235018  1.8829919  1.02629299  1.38703730
#> T-26-0212_Operator_1   Operator_1  6.572344  1.5689139  0.91568369  1.01256651
#> T-26-0212_Operator_2   Operator_2  6.376584  1.5466119  0.88674094  1.02053911
#> T-26-0213_Operator_1   Operator_1  7.360342  1.9093622          NA  1.34931277
#> T-26-0213_Operator_2   Operator_2  7.254137  1.8332162  0.93799713  1.39727194
#> T-26-0214_Operator_1   Operator_1 11.688933  3.3507354  1.52770518  1.90101240
#> T-26-0214_Operator_2   Operator_2 11.320762  3.2251508  1.50443252  2.02156965
#> T-26-0215_Operator_1   Operator_1  7.461961  2.0993214  1.12632815  1.45497744
#> T-26-0215_Operator_2   Operator_2  7.376821  2.1097127  1.12550865  1.46251112
#> T-26-0216_Operator_1   Operator_1  7.072794  1.7624946          NA  1.38756396
#> T-26-0216_Operator_2   Operator_2  6.916795  1.7464553          NA  1.43372630
#> T-26-0217_Operator_1   Operator_1  9.487054  2.3655374  1.32043444  1.32917214
#> T-26-0217_Operator_2   Operator_2  9.407924  2.3486821  1.34030857  1.48972545
#> T-26-0218_Operator_1   Operator_1  7.261583  1.3666618  0.76323101  0.90682185
#> T-26-0218_Operator_2   Operator_2  7.101069  1.3653048  0.75484486  0.92672723
#> T-26-0219_Operator_1   Operator_1  4.512962  1.1177239  0.64022293  0.85079585
#> T-26-0219_Operator_2   Operator_2  4.436315  1.1210196  0.62817826  0.85472543
#> T-26-0220_Operator_1   Operator_1  6.841571  1.6564660          NA  1.09225928
#> T-26-0220_Operator_2   Operator_2  6.668780  1.6461014          NA  1.08974030
#> T-26-0221_Operator_1   Operator_1  7.715062  1.6194926  0.93166116  0.99245296
#> T-26-0221_Operator_2   Operator_2  7.732815  1.7368670  0.94409614  1.03104931
#> T-26-0222_Operator_1   Operator_1 18.680301  4.2836386  2.13435807  1.99575209
#> T-26-0222_Operator_2   Operator_2 18.939625  4.4056699  2.23610474  2.10870494
#> T-26-0223_Operator_1   Operator_1  9.244512  2.5771837          NA  1.91503759
#> T-26-0223_Operator_2   Operator_2  9.288159  2.5612497          NA  1.90132235
#> T-26-0224_Operator_1   Operator_1  9.317499  2.3460688          NA  1.63625932
#> T-26-0224_Operator_2   Operator_2  9.015197  2.2163807          NA  1.63046306
#> T-26-0225_Operator_1   Operator_1 10.456399  2.7859867  1.29235462  1.48723982
#> T-26-0225_Operator_2   Operator_2 10.369535  2.6649290  1.26810543  1.51320026
#> T-26-0226_Operator_1   Operator_1  5.292204  1.2193337  0.70643691  0.69033836
#> T-26-0226_Operator_2   Operator_2  5.280947  1.2293682  0.69829219  0.71153636
#> T-26-0227_Operator_1   Operator_1  7.683103  1.8003888  0.99927905  0.93896110
#> T-26-0227_Operator_2   Operator_2  7.559928  1.7936678  1.01259950  0.89254100
#> T-26-0228_Operator_1   Operator_1  8.375755  2.0329669  1.08221938  1.12569675
#> T-26-0228_Operator_2   Operator_2  8.290491  2.0544708  1.07005910  1.13935802
#> T-26-0229_Operator_1   Operator_1 10.128588  2.6270761  1.29393495  1.36576619
#> T-26-0229_Operator_2   Operator_2  9.931765  2.4938970  1.25303991  1.37611492
#> T-26-0230-1_Operator_1 Operator_1  7.020527  1.1674250          NA  0.96729351
#> T-26-0230-1_Operator_2 Operator_2  4.500000 25.1428571 14.85714286 22.00000000
#> T-26-0230-2_Operator_1 Operator_1  6.481869  1.1674789          NA  0.69438688
#> T-26-0230-2_Operator_2 Operator_2  6.580282  1.0709842  0.65217111  0.76054299
#> T-26-0230-3_Operator_1 Operator_1  6.756530  1.1841250  0.66146915  0.74770813
#> T-26-0230-3_Operator_2 Operator_2  6.676468  1.1358630  0.65382994  0.77167662
#> T-26-0230-4_Operator_1 Operator_1  7.028431  1.3488106  0.76901830  0.93927681
#> T-26-0230-4_Operator_2 Operator_2  6.888051  1.3332958  0.73693269  0.94430189
#> T-26-0231_Operator_1   Operator_1  7.209116  1.4032010  0.74368320  0.77920855
#> T-26-0231_Operator_2   Operator_2  7.131006  1.3873253  0.75307159  0.78609856
#> T-26-0232_Operator_1   Operator_1  6.237482  1.2958170          NA  0.94061204
#> T-26-0232_Operator_2   Operator_2  6.252687  1.3067692          NA  0.97984884
#> T-26-0233_Operator_1   Operator_1        NA         NA          NA          NA
#> T-26-0233_Operator_2   Operator_2  5.864201  1.1414887          NA  0.90702825
#> T-26-0234_Operator_1   Operator_1 19.146759  4.6794293  2.76822113  3.17045248
#> T-26-0234_Operator_2   Operator_2 19.246358  4.8227336  2.80978478  3.40418913
#> T-26-0235_Operator_1   Operator_1  6.670236  1.6497761  0.92427600  1.01704526
#> T-26-0235_Operator_2   Operator_2  6.710467  1.7120253  0.92149091  1.04879469
#> T-26-0236_Operator_1   Operator_1 15.760022  3.9159712  1.89160038  2.16371203
#> T-26-0236_Operator_2   Operator_2 15.561209  3.8908433  1.84734335  2.13540670
#> T-26-0237_Operator_1   Operator_1 15.957457  4.0795179  1.83180403  2.04416326
#> T-26-0237_Operator_2   Operator_2 15.737949  3.9885622  1.69816792  2.17202836
#> T-26-0238_Operator_1   Operator_1 11.790394  3.0597929  1.45706664  1.50993204
#> T-26-0238_Operator_2   Operator_2 11.627595  3.0783785  1.47732777  1.56821415
#> T-26-0239_Operator_1   Operator_1 11.462241  3.1695178  1.69224864  1.53274628
#> T-26-0239_Operator_2   Operator_2 10.519130  3.0509514  1.58501853  1.62431780
#> T-26-0240_Operator_1   Operator_1  7.386872  1.8731401  0.94171737  1.05132142
#> T-26-0240_Operator_2   Operator_2  7.214895  1.8386326  0.90130396  1.07267972
#> T-26-0241_Operator_1   Operator_1  5.033140  1.0916912  0.64128364  0.67570267
#> T-26-0241_Operator_2   Operator_2  4.902804  1.0905421  0.65164664  0.71526912
#> T-26-0242_Operator_1   Operator_1 16.876097  4.6372419  1.95620295  3.04845959
#> T-26-0242_Operator_2   Operator_2 16.146342  4.5101884  1.86307710  3.05864178
#> T-26-0243_Operator_1   Operator_1  5.184221  1.2525468  0.66778409  0.60551360
#> T-26-0243_Operator_2   Operator_2  5.107055  1.2538402  0.65080199  0.62360029
#> T-26-0244_Operator_1   Operator_1  3.933057  0.8350921  0.53452318  0.57585697
#> T-26-0244_Operator_2   Operator_2  3.889758  0.8797204  0.53720134  0.60691325
#> T-26-0245_Operator_1   Operator_1  7.026237  1.7300032  1.04004230  0.86333497
#> T-26-0245_Operator_2   Operator_2  7.074091  1.8377188  1.08102412  0.90958002
#> T-26-0246_Operator_1   Operator_1  7.008886  1.7058019  0.96806267  0.84811395
#> T-26-0246_Operator_2   Operator_2  6.791431  1.6557928  0.91996734  0.91996734
#> T-26-0247_Operator_1   Operator_1  4.886358  1.0883334  0.66089952  0.65650107
#> T-26-0247_Operator_2   Operator_2  4.743978  1.0362778  0.63480244  0.65397918
#> T-26-0248_Operator_1   Operator_1  3.520639  0.8047509  0.49883038  0.34144143
#> T-26-0248_Operator_2   Operator_2  3.500932  0.8369558  0.51178827  0.37800027
#> T-26-0249_Operator_1   Operator_1  3.596662  0.8148732  0.52339529  0.34016517
#> T-26-0249_Operator_2   Operator_2  3.527529  0.8140743  0.50952613  0.38375989
#> T-26-0250_Operator_1   Operator_1  3.570711  0.7969029  0.51951985  0.42713887
#> T-26-0250_Operator_2   Operator_2  3.589940  0.8590797  0.51747661  0.46925608
#> T-26-0251_Operator_1   Operator_1  5.467661  1.1900620  0.73573210  0.66517467
#> T-26-0251_Operator_2   Operator_2  5.196350  1.1922536  0.69920171  0.71795526
#> T-26-0252_Operator_1   Operator_1  3.772280  0.8481608  0.49194585  0.37584891
#> T-26-0252_Operator_2   Operator_2  3.715339  0.8696951  0.45719342  0.36989851
#> T-26-0261-1_Operator_1 Operator_1  9.518765  2.4321337          NA  1.69193973
#> T-26-0261-1_Operator_2 Operator_2  9.327214  2.3684863          NA  1.70293121
#> T-26-0261-2_Operator_1 Operator_1  8.184326  2.2074599          NA  1.64626927
#> T-26-0261-2_Operator_2 Operator_2  8.157834  2.1793231          NA  1.59261575
#> T-26-0261-3_Operator_1 Operator_1  8.043753  2.2259858  1.05736232  1.69287614
#> T-26-0261-3_Operator_2 Operator_2  8.038553  2.2124613          NA  1.74488118
#> T-26-0261-4_Operator_1 Operator_1  6.078656  1.4633690          NA  1.21379413
#> T-26-0261-4_Operator_2 Operator_2  6.125062  1.5274508          NA  1.28147430
#> T-26-0261-5_Operator_1 Operator_1  8.606900  1.9685455  1.31149831  1.49708570
#> T-26-0261-5_Operator_2 Operator_2  8.511532  2.0000849          NA  1.51152074
#> T-26-0262-1_Operator_1 Operator_1  7.375714  1.7971661          NA  1.35700871
#> T-26-0262-1_Operator_2 Operator_2  7.551466  1.8503154          NA  1.44183897
#> T-26-0262-2_Operator_1 Operator_1  6.890140  1.8333483  0.94458549  1.50922297
#> T-26-0262-2_Operator_2 Operator_2  7.004796  1.8505830          NA  1.48046642
#> T-26-0263_Operator_1   Operator_1  4.060243  0.9476308  0.57304189  0.48884594
#> T-26-0263_Operator_2   Operator_2  4.298883  0.9397287  0.55801174  0.48511061
#> T-26-0264-1_Operator_1 Operator_1  4.373042  0.9880860          NA  0.63416442
#> T-26-0264-1_Operator_2 Operator_2  4.324746  0.9998373          NA  0.62794412
#> T-26-0264-2_Operator_1 Operator_1  4.078400  0.9162874  0.56907441  0.52542151
#> T-26-0264-2_Operator_2 Operator_2  4.049603  0.9152726  0.54258768  0.53656965
#> T-26-0264-3_Operator_1 Operator_1  4.316654  1.0055849  0.59791347  0.69061514
#> T-26-0264-3_Operator_2 Operator_2  4.290269  0.9899715          NA  0.67990429
#> T-26-0264-4_Operator_1 Operator_1  3.930195  0.8320322  0.52914469  0.41213734
#> T-26-0264-4_Operator_2 Operator_2  3.932485  0.8190329  0.52774291  0.41789355
#> T-26-0265_Operator_1   Operator_1  9.686131  2.4338470  1.33374993  1.36666667
#> T-26-0265_Operator_2   Operator_2  9.783818  2.4480736  1.38123800  1.41497129
#> T-26-0266_Operator_1   Operator_1 25.178168  6.1950118  3.64656873  4.07783608
#> T-26-0266_Operator_2   Operator_2 25.307554  6.1585002  3.59201122  4.23242139
#> T-26-0267_Operator_1   Operator_1 25.296738  6.7556626  3.67792830  5.03660721
#> T-26-0267_Operator_2   Operator_2 24.821796  6.7841903  3.62875294  4.94358843
#> T-26-0268_Operator_1   Operator_1  7.432405  2.0015607  1.14788513  1.01037090
#> T-26-0268_Operator_2   Operator_2  7.402496  1.9418745  1.13586880  0.97082803
#> T-26-0269_Operator_1   Operator_1  7.810178  1.9693438  1.10812819  1.06833473
#> T-26-0269_Operator_2   Operator_2  7.706447  1.9650116  1.07843023  1.08867972
#> T-26-0270-1_Operator_1 Operator_1 12.624763  3.1075008  1.70386837  1.70293864
#> T-26-0270-1_Operator_2 Operator_2 12.012742  2.9881128  1.64709039  1.58475120
#> T-26-0270-2_Operator_1 Operator_1 13.093592  3.0811938  1.70467350  1.68465178
#> T-26-0270-2_Operator_2 Operator_2 13.251133  3.1930080  1.61871851  1.83095759
#> T-26-0271_Operator_1   Operator_1  9.951061  2.8973315  1.49590424  1.49496470
#> T-26-0271_Operator_2   Operator_2  9.494828  2.8489312  1.48560880  1.48641889
#> T-26-0272_Operator_1   Operator_1  6.676933  1.1272330  0.70903200  0.70012037
#> T-26-0272_Operator_2   Operator_2  6.591580  1.1662132  0.70382229  0.77111478
#> T-26-0273_Operator_1   Operator_1  8.647458  2.0142577  1.16112220  1.04127407
#> T-26-0273_Operator_2   Operator_2  8.854456  2.0888984  1.20589120  1.08401063
#> T-26-0274_Operator_1   Operator_1  7.197885  1.1717107          NA  0.96436466
#> T-26-0274_Operator_2   Operator_2  7.098355  1.2310557          NA  1.00571597
#> T-26-0275_Operator_1   Operator_1  7.124035  1.2145781          NA  0.87506638
#> T-26-0275_Operator_2   Operator_2  7.015681  1.2187128          NA  0.89329981
#> T-26-0276_Operator_1   Operator_1  6.125893  1.5328261  0.83775337  0.93300118
#> T-26-0276_Operator_2   Operator_2  6.243626  1.5737396  0.84585963  1.01960000
#> T-26-0277_Operator_1   Operator_1  7.320327  1.4139146  0.80952526  0.83224134
#> T-26-0277_Operator_2   Operator_2  7.298711  1.4717597  0.81364053  0.85771439
#> T-26-0278-1_Operator_1 Operator_1  5.889839  1.3573901  0.62483966  0.84791016
#> T-26-0278-1_Operator_2 Operator_2  5.792278  1.3230123  0.61091969  0.87741051
#> T-26-0278-2_Operator_1 Operator_1  5.985832  1.0653645  0.60137447  0.58136232
#> T-26-0278-2_Operator_2 Operator_2  5.943979  1.0892998  0.60796448  0.61348550
#> T-26-0279_Operator_1   Operator_1  6.233187  1.3004547          NA  0.94545918
#> T-26-0279_Operator_2   Operator_2  6.115752  1.3481306          NA  0.93469408
#>                                 Mo         PFi       PFl         Ed        Jl
#> T-26-0001_Operator_1    0.89489033  0.74887664 1.3571782 0.35304739 0.3141390
#> T-26-0001_Operator_2    0.91630925  0.74976919 1.3421683 0.33565977 0.4084968
#> T-26-0002_Operator_1    1.06867215  0.86977177 1.5406889 0.38287629 0.5184372
#> T-26-0002_Operator_2    1.04827182  0.90873810 1.4602249 0.34405677 0.4487938
#> T-26-0003_Operator_1    0.80881935  0.71316923 1.2416526 0.36517494 0.4902852
#> T-26-0003_Operator_2    0.77681447  0.68516914 1.4002251 0.33559087 0.4491814
#> T-26-0004_Operator_1    2.48872580  1.30312261 3.0706500 0.77446974 0.9075409
#> T-26-0004_Operator_2    2.51429225  1.30646051 3.0181977 0.84133255 0.9065431
#> T-26-0005_Operator_1    0.80566515  0.62309150 0.9818339 0.27046813 0.4423693
#> T-26-0005_Operator_2    0.82527173  0.61598029 1.0853408 0.26134381 0.3446107
#> T-26-0006_Operator_1    0.85296195  0.88177356 1.3023562 0.37335909 0.5165191
#> T-26-0006_Operator_2    0.77314909  0.91054204 1.2126575 0.34889089 0.4290090
#> T-26-0007_Operator_1    2.55790654  1.80235146 3.5085919 0.87482800 1.4552358
#> T-26-0007_Operator_2    2.71425139  1.85419042 3.3737915 0.89604957 0.9653270
#> T-26-0008_Operator_1    2.60096767  1.60258937 2.4716972 0.70554624 1.1387038
#> T-26-0008_Operator_2    2.47822015  1.54145985 2.5145902 0.67198150 0.8010362
#> T-26-0009_Operator_1    1.24225715  0.94587064        NA 0.51205283 0.3210083
#> T-26-0009_Operator_2    1.24952219  0.85749531 1.3915307 0.52415842 0.4281807
#> T-26-0010_Operator_1    1.37709223  0.71690429 1.7151405 0.35185898 0.5284874
#> T-26-0010_Operator_2    1.43178899  1.10961626 1.7116300 0.33329580 0.4853231
#> T-26-0011_Operator_1    5.05333121  2.74509028 4.7540294 1.01007139 2.1168580
#> T-26-0011_Operator_2    4.89376502  2.62586719 4.6498639 0.98826704 1.8148178
#> T-26-0012_Operator_1    0.59085979  0.58871830 1.4527794 0.31293136 0.4688812
#> T-26-0012_Operator_2    0.66455572  0.67223569 1.3071221 0.30997905 0.4130777
#> T-26-0013_Operator_1    0.88318584  0.76117261 1.6037205 0.43691643 0.6524061
#> T-26-0013_Operator_2    0.92426944  0.74701185 1.4788647 0.42178006 0.5522316
#> T-26-0014_Operator_1    1.18549544  1.17982255 1.9419989 0.35006280 0.5694982
#> T-26-0014_Operator_2    1.28512669  1.12271599 1.7437919 0.32540342 0.4691140
#> T-26-0015_Operator_1    0.90252299  0.94930026 1.7040126 0.34229099 0.5291597
#> T-26-0015_Operator_2    0.90015057  0.90386104 1.4868953 0.29916479 0.4724612
#> T-26-0016_Operator_1    1.54880037  1.32975506 2.0587947 0.58772448 0.8083894
#> T-26-0016_Operator_2    1.48587881  1.09073190 1.9438910 0.64275494 0.9522891
#> T-26-0017_Operator_1    0.65403196  0.63708998 1.5041843 0.28466129 0.4748494
#> T-26-0017_Operator_2    0.68130657  0.64589390 1.3683530 0.25497927 0.3989513
#> T-26-0018_Operator_1    3.94755566  2.45630553 3.5382196 0.95164946 1.0136353
#> T-26-0018_Operator_2    3.74558332  2.35895011 3.4195100 0.88376562 1.0892905
#> T-26-0019_Operator_1    1.65616013  1.03140475 2.1818256 0.74373115 0.6282757
#> T-26-0019_Operator_2    1.58916398  1.00302998 2.1373223 0.70084539 0.8233946
#> T-26-0020_Operator_1    1.42336918  1.32493115 1.8425853 0.39596127 0.5424703
#> T-26-0020_Operator_2    1.43121311  1.24100404 1.8913813 0.33313257 0.5127092
#> T-26-0021_Operator_1    0.96435058  0.99181424        NA 0.63898700 0.4753667
#> T-26-0021_Operator_2    0.88749677  0.84530619 1.5534761 0.65622110 0.8717501
#> T-26-0022_Operator_1    1.67745924  0.94258427 2.0524048 0.67044113 0.6392783
#> T-26-0022_Operator_2    1.62375071  0.92608948 1.9687519 0.66913514 0.7569836
#> T-26-0023-2_Operator_1  0.43941300  0.22895104        NA 0.28619375        NA
#> T-26-0023-2_Operator_2  0.44722380  0.20281528 0.5413950 0.28058851 0.3176394
#> T-26-0024_Operator_1    1.36655063  1.18958516 1.6447189 0.30728145 0.5526650
#> T-26-0024_Operator_2    1.33905022  1.08139434 1.4166748 0.29977292 0.4686662
#> T-26-0025_Operator_1    1.46321555  1.33351716 1.9929660 0.32422744 0.4526759
#> T-26-0025_Operator_2    1.54123693  1.36954226 1.7702606 0.28264358 0.4163414
#> T-26-0026_Operator_1    1.44391579  0.90046998 1.9779864 0.48454672 0.7799872
#> T-26-0026_Operator_2    1.49825464  0.86785633 1.8145795 0.45835890 0.6883890
#> T-26-0027_Operator_1    1.94469811  1.35317782 1.9343852 0.44955766 0.6343375
#> T-26-0027_Operator_2    1.77951827  1.25741612 1.7964636 0.41033674 0.6486446
#> T-26-0028_Operator_1    1.08521010  0.97247912 1.3516274 0.32857973 0.4478013
#> T-26-0028_Operator_2    1.12415413  0.95316938 1.2689236 0.29557560 0.3804169
#> T-26-0029_Operator_1    0.66061237  0.58506254        NA 0.35415383        NA
#> T-26-0029_Operator_2    0.65831989  0.52280105 0.6518025 0.36542253 0.4789340
#> T-26-0030_Operator_1    2.15398429  1.21224700 2.2943736 0.66424335 0.7654466
#> T-26-0030_Operator_2    1.94469792  1.03865570 2.3701462 0.70150377 0.8667674
#> T-26-0031_Operator_1    1.16587322  0.97215211 1.4975270 0.35311241 0.5868150
#> T-26-0031_Operator_2    1.17232331  0.93055199 1.5038251 0.33986392 0.4689442
#> T-26-0032_Operator_1    5.27919142  2.98317119 5.0649982 1.03357431 1.3379604
#> T-26-0032_Operator_2    4.64272918  2.60311595 4.9632190 0.97335265 1.4283261
#> T-26-0033_Operator_1    1.57452040  1.32118805 1.8324657 0.41605839 0.4750978
#> T-26-0033_Operator_2    1.52411964  1.25957741 1.8287800 0.41152488 0.4131745
#> T-26-0034_Operator_1    1.38668060  1.28209685 1.7130311 0.39614482 0.5011719
#> T-26-0034_Operator_2    1.52285299  1.24705318 1.7396400 0.36777161 0.4859225
#> T-26-0035_Operator_1    0.88961927  0.66914311 1.1874279 0.28483050 0.4047512
#> T-26-0035_Operator_2    0.84892047  0.62246964 1.1777644 0.27586919 0.3906018
#> T-26-0036_Operator_1    2.16219518  1.33697618 2.1035961 0.71814770 0.7159875
#> T-26-0036_Operator_2    1.99307552  1.06806199 2.1304110 0.69427239 0.7167420
#> T-26-0037_Operator_1    2.73859762  1.77711639 3.1439850 0.77747788 0.8296678
#> T-26-0037_Operator_2    2.51345443  1.46778476 2.8955734 0.77363638 0.9686656
#> T-26-0038_Operator_1    1.02371234  0.94549656 1.4624606 0.29249449 0.4922926
#> T-26-0038_Operator_2    0.95613361  0.86003197 1.5489551 0.25049166 0.3814196
#> T-26-0039_Operator_1    1.18724500  0.76344261 1.1498481 0.48169820 0.3792569
#> T-26-0039_Operator_2    1.18195401  0.65392363 1.3913741 0.51158343 0.4693982
#> T-26-0040_Operator_1    1.14137435  0.99997655 1.8360659 0.37045819 0.6323202
#> T-26-0040_Operator_2    1.16235287  0.91695843 1.8403005 0.32593841 0.5602112
#> T-26-0041_Operator_1    0.77232983  0.73036875 1.4292887 0.32681788 0.4785252
#> T-26-0041_Operator_2    0.80586549  0.63666016 1.4533812 0.29735173 0.3980374
#> T-26-0042_Operator_1    1.32920371  1.02780954 2.0139522 0.41262037 0.5433299
#> T-26-0042_Operator_2    1.28244246  0.96698688 1.8525883 0.35782554 0.5255243
#> T-26-0043_Operator_1    0.64350880  0.73771034 1.7601271 0.41348298 0.4832472
#> T-26-0043_Operator_2    0.73889948  0.76119106 1.7975675 0.30419315 0.4048686
#> T-26-0044_Operator_1    1.37557563  1.21678061 1.8359927 0.42798152 0.4937488
#> T-26-0044_Operator_2    1.31590708  1.14820938 1.7696610 0.40659523 0.4584049
#> T-26-0045_Operator_1    1.86251732  1.18307922 2.6606648 0.67595224 0.7530524
#> T-26-0045_Operator_2    1.82784404  1.03105720 2.4334719 0.70972839 0.7875717
#> T-26-0046_Operator_1    1.17289864  1.11144133 1.9413411 0.37494105 0.4967074
#> T-26-0046_Operator_2    1.13080591  0.96825358 1.9213842 0.29673532 0.5897032
#> T-26-0047_Operator_1    5.49443483  3.49366083 5.1035153 0.86973302 1.1569351
#> T-26-0047_Operator_2    5.09847909  3.20831407 4.9375199 0.93701531 1.3141156
#> T-26-0048_Operator_1    1.05480266  1.20804466 1.6156628 0.32224579 0.5627273
#> T-26-0048_Operator_2    1.09342936  1.10475056 1.8292777 0.29042771 0.5101605
#> T-26-0049_Operator_1    1.71324814  1.01167002 2.2633024 0.69051370 0.7043522
#> T-26-0049_Operator_2    1.85453957  0.99854255 2.2111136 0.75169806 0.8467069
#> T-26-0050_Operator_1    1.09617894  0.96847207 1.6572127 0.29279849 0.4871916
#> T-26-0050_Operator_2    0.06188925  0.04343322 1.4006515 0.01791531 0.2508143
#> T-26-0051_Operator_1    1.58966604  1.24421578 2.1744593 0.41444289 0.6283662
#> T-26-0051_Operator_2    1.59664952  1.23032306 2.1620499 0.41464188 0.7006842
#> T-26-0052_Operator_1    3.39803006  0.55276962 1.1290314 0.27469233 4.0716062
#> T-26-0052_Operator_2    2.08821902  1.10096927 2.7000014 0.76984464 1.0379663
#> T-26-0053_Operator_1    2.14723477  1.22614176 2.7139476 0.69788999 0.8296945
#> T-26-0053_Operator_2    1.97647700  1.17380203 2.5809823 0.70837184 0.8287973
#> T-26-0054_Operator_1    2.17195527  1.28713454 2.4491505 0.68780757 0.7506219
#> T-26-0054_Operator_2    2.07462225  1.16812374 2.5610878 0.70840527 0.7519099
#> T-26-0055_Operator_1    1.57601313  1.37003756 1.9466903 0.47945785 0.5115428
#> T-26-0055_Operator_2    1.55642634  1.27273737 1.7686611 0.38876858 0.5341243
#> T-26-0056-2_Operator_1  1.91948876  1.47785363 2.0298051 0.52266256 0.6807006
#> T-26-0056-2_Operator_2  1.79200905  1.26358899 1.9606677 0.47026855 0.7227897
#> T-26-0057_Operator_1    1.23767209  1.06991858 1.6914708 0.27980683 0.5027355
#> T-26-0057_Operator_2    1.21145149  1.06937847 1.6359525 0.36670248 0.4125956
#> T-26-0058_Operator_1    1.67522698  1.24360976 2.0801927 0.46574697 0.6154796
#> T-26-0058_Operator_2            NA          NA        NA         NA        NA
#> T-26-0059_Operator_1    1.54360345  1.21131985 0.8329248 0.34018607 0.5212983
#> T-26-0059_Operator_2    1.40198963          NA        NA 0.34596313 0.4652900
#> T-26-0060_Operator_1    1.15734043  0.96172531 1.7425274 0.33800795 0.5746917
#> T-26-0060_Operator_2    1.13123337  0.89123955 1.6335112 0.31350388 0.5242985
#> T-26-0061_Operator_1    2.45346204  1.23176834 2.3939069 0.75689551 0.8050211
#> T-26-0061_Operator_2    2.15607821  1.05604822 2.5626686 0.82359573 0.7867538
#> T-26-0062_Operator_1    2.90262484  1.51969366 3.3331083 0.87978825 1.1064440
#> T-26-0062_Operator_2    2.53914014  1.29418239 3.4885413 1.00116004 1.1302766
#> T-26-0063_Operator_1    1.16096169  0.99151697 1.4287984 0.33465972 0.4692763
#> T-26-0063_Operator_2    1.11287069  0.92371433 1.1981869 0.29809621 0.4141536
#> T-26-0064_Operator_1    0.96233793  0.94573132 1.8202765 0.38630372 0.5180883
#> T-26-0064_Operator_2    0.94387694  0.80889856 1.8979116 0.37156508 0.5396891
#> T-26-0065_Operator_1    1.49141693  1.00748069 1.5576676 0.45346736 0.5837907
#> T-26-0065_Operator_2    1.38955003  0.96859863 1.5515453 0.38677211 0.4764707
#> T-26-0067_Operator_1    1.49740891  1.06956639 1.8778103 0.34431892 0.5123565
#> T-26-0067_Operator_2    1.56135387  1.01844731 1.8475157 0.33983901 0.4994724
#> T-26-0068_Operator_1    1.56945476  1.08834576 1.9250632 0.68207462 0.4680862
#> T-26-0068_Operator_2    1.83118280  0.89682711 2.0197788 0.67400524 1.0209698
#> T-26-0069_Operator_1    1.24041383  0.57371902 1.4059721 0.43388302 0.4940410
#> T-26-0069_Operator_2    1.07957669  0.42108507 1.4888260 0.52135503 0.5467153
#> T-26-0070_Operator_1    1.32576288  0.68897247 1.4100550 0.53348055 0.6782875
#> T-26-0070_Operator_2    1.35046019  0.66248752 1.3849447 0.51496048 0.6877203
#> T-26-0071_Operator_1    1.11777343  0.79726891 1.7545520 0.28990578 0.3674879
#> T-26-0071_Operator_2    1.10255329  0.76866932 1.7294743 0.30489140 0.5138507
#> T-26-0072_Operator_1    1.39379547  0.99117535 1.9751873 0.39644021 0.7597339
#> T-26-0072_Operator_2    1.39718384  0.91377600 1.8084275 0.36744782 0.5151795
#> T-26-0073_Operator_1    1.65061732  1.19524539 1.9013395 0.41345556 0.6013497
#> T-26-0073_Operator_2    1.51317888  1.09291486 1.9732215 0.38202285 0.5462946
#> T-26-0074_Operator_1    1.13044367  1.03864732 2.0462477 0.39450351 0.6070726
#> T-26-0074_Operator_2    1.18027671  1.01448264 1.9553582 0.38320461 0.6037259
#> T-26-0075_Operator_1    2.07671029  1.63297393 1.9851945 0.49575558 0.6472792
#> T-26-0075_Operator_2    1.92953385  1.16607194 1.9608088 0.48309695 0.6568013
#> T-26-0076_Operator_1    2.02923814  0.96673351 2.0294772 0.64619674 0.4951869
#> T-26-0076_Operator_2    1.67174115  0.74383239 2.0005536 0.68831486 0.6841691
#> T-26-0077_Operator_1    0.75120319  0.61028019 1.2435845 0.34533131 0.2377478
#> T-26-0077_Operator_2    0.68165193  0.54063134 1.2338145 0.32255175 0.3678623
#> T-26-0078_Operator_1    1.08886123  0.89075319 1.9862341 0.43641259 0.6535970
#> T-26-0078_Operator_2    1.01208435  0.87158544 2.0337646 0.43940402 0.5956261
#> T-26-0079_Operator_1    1.27675005  0.93550441 1.4834435 0.41135491 0.5588320
#> T-26-0079_Operator_2    1.29763907  0.85108588 1.5106486 0.40660657 0.4855327
#> T-26-0080_Operator_1    1.00159385  0.50594336 1.0968826 0.47603729 0.4765894
#> T-26-0080_Operator_2    0.98836029  0.45044066 1.0490358 0.45928088 0.5289646
#> T-26-0081_Operator_1    0.57016822  0.46701065 1.1833056 0.33227344 0.3466291
#> T-26-0081_Operator_2    0.58280953  0.49659946 1.1448039 0.29208575 0.3781989
#> T-26-0082_Operator_1    1.48351791  0.78830667 1.5644288 0.51906017 0.2392996
#> T-26-0082_Operator_2    1.52597117  0.68644632 1.6278193 0.53696859 0.5609133
#> T-26-0083_Operator_1    0.82871496  0.66865253 1.1772954 0.27313211 0.3779979
#> T-26-0083_Operator_2    0.82642975  0.59255105 1.2021122 0.25154937 0.3887368
#> T-26-0084_Operator_1    0.90160562  0.71316920 1.2376895 0.36862398 0.4996879
#> T-26-0084_Operator_2    0.99618352  0.72841099 1.2322492 0.36444256 0.4789447
#> T-26-0085_Operator_1    1.10160150  0.79719179 1.7350736 0.35800383 0.6112334
#> T-26-0085_Operator_2    1.18140309  0.86271228 1.6116718 0.38408293 0.6080920
#> T-26-0086_Operator_1    1.46514875  1.07794175 1.8678994 0.40914308 0.6576322
#> T-26-0086_Operator_2    1.50685742  0.95839062 1.8276425 0.37892073 0.6952433
#> T-26-0087_Operator_1    1.42550275  1.02258322 1.6968310 0.39355949 0.5206477
#> T-26-0087_Operator_2    1.40098786  0.94761726 1.5834633 0.34809147 0.5306167
#> T-26-0088_Operator_1    0.89087028  0.86343853 1.6990085 0.38827083 0.4599713
#> T-26-0088_Operator_2    1.19194262  0.93312178 1.6379129 0.40141645 0.4092631
#> T-26-0089_Operator_1    0.39562420  0.20683394 0.2923484 0.25741844        NA
#> T-26-0089_Operator_2    0.37859256  0.13948559 0.3330603 0.25291715 0.2777671
#> T-26-0090_Operator_1    0.58037499  0.42241343 0.6199527 0.26740010        NA
#> T-26-0090_Operator_2    0.53404492  0.39987506 0.7016709 0.27573959 0.2683026
#> T-26-0091_Operator_1    1.23748928  0.77729032 1.6913150 0.31308479 0.5438174
#> T-26-0091_Operator_2    1.34742625  0.78082381 1.7716113 0.33776122 0.5827074
#> T-26-0092_Operator_1    1.17295805  0.88559604 1.5547705 0.41560754 0.5284779
#> T-26-0092_Operator_2    1.36138228  0.95226946 1.5981192 0.38236158 0.4731739
#> T-26-0093_Operator_1    1.43934188  1.01584189 1.4985562 0.40416181 0.5011183
#> T-26-0093_Operator_2    1.48408679  0.99495147 1.5946005 0.40998551 0.4547263
#> T-26-0094_Operator_1    0.97156360  0.74353151 1.3764721 0.35268059 0.3918740
#> T-26-0094_Operator_2    1.00443231  0.68358902 1.3615341 0.32474330 0.3722027
#> T-26-0095_Operator_1    0.90766514  0.82064358 1.6742417 0.35202581 0.4428063
#> T-26-0095_Operator_2    1.05288927  0.84733188 1.6568351 0.33647766 0.3870999
#> T-26-0096_Operator_1    0.77765839  0.75464199 1.1841566 0.27339032 0.4480082
#> T-26-0096_Operator_2    0.95768111  0.68706080 1.2075632 0.28364205 0.4025171
#> T-26-0097_Operator_1    1.13859838  0.84553531 1.9055686 0.36161617 0.8663626
#> T-26-0097_Operator_2    1.15154896  0.75830384 1.8480345 0.34506121 0.4686642
#> T-26-0098_Operator_1    1.15682275  0.81208111 1.4599957 0.42490168 0.5876444
#> T-26-0098_Operator_2    1.04016454  0.63671669 1.4132532 0.38293097 0.5259417
#> T-26-0099_Operator_1    0.43874751  0.28582741 0.3697782 0.29789761        NA
#> T-26-0099_Operator_2    0.45138393  0.14292677 0.7553707 0.27986604 0.3589007
#> T-26-0100_Operator_1    0.86548165  0.65330832 1.1723034 0.27016768 0.1511832
#> T-26-0100_Operator_2    0.92573543  0.73250588 1.2681025 0.34538299 0.3507666
#> T-26-0101_Operator_1    1.23694759  0.95787375 1.4769617 0.29298585 0.2685223
#> T-26-0101_Operator_2    1.27154424  0.95814468 1.5250756 0.36337479 0.4148034
#> T-26-0102_Operator_1    1.25596398  0.58493426 1.7186693 0.35684633 7.5079027
#> T-26-0102_Operator_2    1.12142276  0.73174458 1.3554031 0.36515978 0.4251821
#> T-26-0103_Operator_1    1.51907468  0.64031242 2.1083910 0.58363088 0.6653315
#> T-26-0103_Operator_2    1.49528076  0.65414115 1.8186860 0.51484989 0.5722079
#> T-26-0104_Operator_1    1.30316643  0.81344249 1.8014609 0.53857514 0.6400121
#> T-26-0104_Operator_2    1.30388524  0.84539732 1.7963575 0.48395908 0.4713370
#> T-26-0107_Operator_1    1.55211701  0.96935812 1.6002662 0.60842629 0.3727630
#> T-26-0107_Operator_2            NA          NA        NA         NA        NA
#> T-26-0108_Operator_1    0.76499647  0.52246815 2.0553892 0.39894756 0.7584422
#> T-26-0108_Operator_2    1.03287963  0.71477198 1.9177357 0.39257028 0.5255359
#> T-26-0109_Operator_1    1.30745429  1.92143722 1.7322581 0.00000000 0.6847351
#> T-26-0109_Operator_2    1.28679403  0.93454531 1.7231443 0.42804513 0.4837936
#> T-26-0111_Operator_1    0.28930111  0.17716354 1.1830072 0.16287272 0.1808627
#> T-26-0111_Operator_2    0.32352989  0.18947951 0.3798422 0.18612754 0.1368515
#> T-26-0112-2_Operator_1  0.78889343  0.59097291 1.1687621 0.34102676 0.3096387
#> T-26-0112-2_Operator_2  0.79835979  0.60746448 1.2117847 0.36217176 0.4182496
#> T-26-0112_Operator_1    0.47200451  0.35229595 0.6100681 0.23480605        NA
#> T-26-0112_Operator_2    0.43884278  0.35357540 0.6182181 0.22123662        NA
#> T-26-0113_Operator_1    0.44106940  0.44334855 1.3759575 0.31669336 0.5331575
#> T-26-0113_Operator_2    0.67859424  0.51487060 1.3832709 0.34173904 0.4584871
#> T-26-0114_Operator_1    0.97476734  0.77703696 1.4083986 0.37269954 0.3084577
#> T-26-0114_Operator_2    1.10923796  0.82018270 2.0213691 0.37642507 0.4402109
#> T-26-0115_Operator_1    1.01744585  0.84797296 2.1192550 0.41474689 0.4722676
#> T-26-0115_Operator_2    0.87886941  0.52883631 1.5678789 0.37650426 0.3352555
#> T-26-0116_Operator_1    0.92444200  0.56608094 1.5664673 0.38813413 0.4524785
#> T-26-0116_Operator_2    1.09660596  0.70820908 1.5959183 0.33154360 0.3961208
#> T-26-0117_Operator_1    1.02831257  0.79766724 1.6938219 0.32838208 0.6200159
#> T-26-0117_Operator_2    1.32098841  0.82430524 1.6308200 0.35579038 0.4030355
#> T-26-0118_Operator_1    1.28125480  0.82828532 1.7138154 0.38373797 0.4460225
#> T-26-0118_Operator_2    1.08447254  0.71981898 1.6322325 0.32184759 0.3999241
#> T-26-0120_Operator_1    0.95962484  0.68246846 1.3382559 0.29316999 0.4871104
#> T-26-0120_Operator_2    0.84722282  0.60549351 1.2518287 0.28454362 0.3321514
#> T-26-0121_Operator_1    1.00505768  0.65203616 1.4483889 0.42721977 0.4167373
#> T-26-0121_Operator_2   18.54166667 11.75000000 6.0000000 7.50000000 5.7083333
#> T-26-0122_Operator_1    1.09572967  0.84727801 1.9967863 0.36342383 0.7767666
#> T-26-0122_Operator_2    1.02037079  0.80849585 1.8983368 0.39762585 0.6085192
#> T-26-0123_Operator_1    0.89597693  0.62105853 1.7045562 0.38084397 0.4396152
#> T-26-0123_Operator_2    1.02856317  0.66274845 1.6530308 0.39284860 0.3575250
#> T-26-0125_Operator_1    0.83048986  0.47056664 1.4955752 0.38460657 0.5039151
#> T-26-0125_Operator_2    0.97964149  0.54221317 1.4079212 0.34888067 0.4000436
#> T-26-0126_Operator_1    1.05214463  0.70140867 1.3986442 0.35749104 0.5056193
#> T-26-0126_Operator_2    1.06254821  0.73533739 1.3302349 0.31627989 0.3359975
#> T-26-0127_Operator_1    1.37718799  1.04298015 1.8398135 0.50919781 0.4738615
#> T-26-0127_Operator_2    1.33385745  1.00407629 1.7344488 0.38726397 0.4359544
#> T-26-0128_Operator_1    0.66342367  0.63434265 1.2116350 0.37032082 0.4295619
#> T-26-0128_Operator_2    0.78662304  0.57953558 1.1562563 0.37453875 0.5492232
#> T-26-0130_Operator_1    0.52167266  0.46548164 0.8351162 0.31607735 0.2862719
#> T-26-0130_Operator_2    0.48737776  0.39382896 0.8405935 0.31314344 0.3342377
#> T-26-0131_Operator_1    1.23808221  0.92474939 1.5657946 0.40393083 0.5579866
#> T-26-0131_Operator_2    1.20767957  0.85693038 1.6651262 0.38347532 0.5199723
#> T-26-0132_Operator_1    1.37325973  1.02737316 1.8088123 0.39725096 0.6069332
#> T-26-0132_Operator_2    1.30923446  1.00875847 1.6842995 0.35605999 0.5262678
#> T-26-0133_Operator_1    0.64923465  0.86304144 1.8250010 0.66432123 0.6416771
#> T-26-0133_Operator_2    0.93768226  0.69303052 1.8524395 0.64582860 0.7568850
#> T-26-0134_Operator_1    1.30985126  0.90476654 1.6411247 0.44917529 0.5635258
#> T-26-0134_Operator_2    1.33235690  0.83393188 1.5896988 0.31863281 0.5309549
#> T-26-0135_Operator_1    0.69999185  0.76553010 1.7409794 0.62082813 0.7547213
#> T-26-0135_Operator_2    1.02048352  0.53671587 1.8711602 0.64505119 0.7242575
#> T-26-0136_Operator_1    1.31137149  0.92448775 1.7625783 0.41087217 0.4871382
#> T-26-0136_Operator_2    1.37969850  0.87184569 1.7830444 0.39322034 0.5571091
#> T-26-0137_Operator_1    2.13650395  1.16508785 2.7263705 0.82564956 0.6909041
#> T-26-0137_Operator_2    2.23220936  1.10450381 2.6728921 0.86306150 0.7225434
#> T-26-0138_Operator_1    1.05787234  0.74152780 1.7502041 0.39455782 0.6282305
#> T-26-0138_Operator_2    1.12544415  0.72945183 1.6478691 0.34930061 0.4479196
#> T-26-0139_Operator_1    1.22778224  0.80264680 1.7309018 0.44898957 0.4785937
#> T-26-0139_Operator_2    1.23141829  0.76327160 1.7028098 0.42104031 0.4682776
#> T-26-0140_Operator_1    0.95772648  0.58461559 1.3035875 0.38357278 0.5405312
#> T-26-0140_Operator_2    0.93400000  0.54723063 1.2460288 0.33681013        NA
#> T-26-0141_Operator_1    1.26378499  0.81516448 1.6547478 0.43155108 0.4748445
#> T-26-0141_Operator_2    1.26509198  0.74829343 1.6749086 0.36560528 0.5065169
#> T-26-0142_Operator_1    0.91648303  0.62547890 1.4499866 0.39261592 0.4696423
#> T-26-0142_Operator_2    0.88665223  0.51871195 1.3843087 0.34092689 0.3995250
#> T-26-0143_Operator_1    1.12635963  0.58441382 1.3609304 0.53863226 0.2495543
#> T-26-0143_Operator_2    1.25736708  0.47449025 1.4005965 0.53548247 0.4185266
#> T-26-0144_Operator_1    1.03061786  0.58519220 1.6933311 0.68737785 0.4769916
#> T-26-0144_Operator_2    1.37547552  0.47326687 1.7859188 0.69630113 0.7570442
#> T-26-0145_Operator_1    0.46578062  0.22788591        NA 0.26178213        NA
#> T-26-0145_Operator_2    0.48781700  0.14849495 0.3313965 0.26116918 0.2936343
#> T-26-0146_Operator_1    1.69750133  1.17014074 2.0618277 0.46948714 0.6171036
#> T-26-0146_Operator_2    1.80131544  1.10163817 1.9765569 0.44601877 0.4925305
#> T-26-0147_Operator_1    1.57358376  1.18072770 1.9726283 0.52994174 0.7422911
#> T-26-0147_Operator_2    1.77940791  1.16158478 1.9097073 0.51325839 0.6860712
#> T-26-0148_Operator_1    2.00135172  1.19845887 2.6187162 0.85600618 0.7057742
#> T-26-0148_Operator_2    2.32519867  1.22650429 2.6430922 0.82916326 0.8894052
#> T-26-0149_Operator_1    4.45613040  2.48550152 4.6610643 1.18018202 0.9154846
#> T-26-0149_Operator_2    4.81529744  2.27228736 4.6842182 1.02101156 1.4805068
#> T-26-0150_Operator_1    2.09859855  1.60581487 3.1373845 0.68956951 1.2742445
#> T-26-0150_Operator_2    2.27122437  1.51173326 3.2137429 0.67560343 1.1452198
#> T-26-0151_Operator_1    1.16569761  0.66202617 2.1201530 0.42564186 0.5897905
#> T-26-0151_Operator_2    1.15934569  0.75065285 2.1000065 0.42765647 0.5111609
#> T-26-0152_Operator_1    0.36951435  0.23119210        NA 0.20852848        NA
#> T-26-0152_Operator_2    0.36561759  0.20259585 0.4330594 0.20135768        NA
#> T-26-0153_Operator_1    0.77944075  0.45594314 1.6735357 0.41515054 0.5898829
#> T-26-0153_Operator_2    0.88667101  0.50323227 1.6267507 0.41418687 0.5485082
#> T-26-0154_Operator_1    0.90541736  0.57081221 1.3245165 0.40993114 0.4712445
#> T-26-0154_Operator_2    0.95467615  0.57626439 1.4466320 0.38959674 0.4530759
#> T-26-0155_Operator_1    0.57404021  0.37809143 1.1021899 0.30051051 0.3714060
#> T-26-0155_Operator_2    0.60478165  0.36666508 1.0732178 0.27332032 0.3103235
#> T-26-0156_Operator_1    3.09134931  1.56765741 3.4591436 1.00027384 0.7460718
#> T-26-0156_Operator_2    3.52495325  1.48358018 3.3637998 0.95413513 1.1742310
#> T-26-0157_Operator_1    1.27532133  0.74789773 2.0377549 0.37418056 0.5610752
#> T-26-0157_Operator_2    1.30297386  0.74608987 1.8698796 0.38125659 0.5626915
#> T-26-0158_Operator_1    1.24507587  0.71134532 1.6106631 0.44291312 0.5237223
#> T-26-0158_Operator_2    1.32813715  0.70855925 1.5814370 0.42534176 0.4989785
#> T-26-0159_Operator_1    1.11241259  0.64865615 2.0269034 0.38529299 0.5968666
#> T-26-0159_Operator_2    1.11483905  0.63137449 1.9376328 0.39890924 0.5574770
#> T-26-0160_Operator_1    0.97811360  0.74758783 1.8198314 0.49435932 0.4114460
#> T-26-0160_Operator_2    0.99662343  0.68582527 1.7374832 0.39134365 0.4265857
#> T-26-0161_Operator_1    0.96328486  0.77995798 1.7599637 0.39331117 0.4779793
#> T-26-0161_Operator_2    1.18045334  0.76946218 1.6843952 0.37613892 0.3915056
#> T-26-0162_Operator_1    1.03026030  0.79860865 1.5367332 0.42294608 0.4396235
#> T-26-0162_Operator_2    1.12852170  0.76974202 1.4738128 0.33555420 0.3930051
#> T-26-0163_Operator_1    1.08448657  0.62666667 1.9140765 0.45338235 0.5594640
#> T-26-0163_Operator_2    1.09428113  0.64199519 1.9626074 0.42090158 0.4830145
#> T-26-0164_Operator_1    0.39757583  0.27841333 0.9141268 0.28278287 0.3429676
#> T-26-0164_Operator_2    0.43555390  0.30646803 0.8430016 0.24568191 0.2848364
#> T-26-0165_Operator_1    1.04680269  0.65515874 1.6052070 0.41718922 0.4548932
#> T-26-0165_Operator_2    1.15233179  0.66757535 1.6112125 0.38969241 0.3944191
#> T-26-0166_Operator_1    0.47479807  0.32099970 0.8996614 0.24417186 0.3288444
#> T-26-0166_Operator_2    0.50513412  0.32900374 0.8536298 0.23036949 0.3397496
#> T-26-0167_Operator_1    4.47517978  2.06820622 4.9419416 1.38802185 1.3709551
#> T-26-0167_Operator_2    4.73389358  2.05247526 4.7053834 1.31408684 1.5838309
#> T-26-0168_Operator_1    1.29693769  0.78942028 1.8497799 0.47613992 0.5218201
#> T-26-0168_Operator_2    1.30615862  0.81578524 1.6802366 0.44312228 0.4396708
#> T-26-0169_Operator_1    1.49708293  0.81106415 2.1131480 0.50041072 0.7455278
#> T-26-0169_Operator_2    2.71901077  1.55522649 4.2240358 0.95930233 1.2810266
#> T-26-0170_Operator_1    1.45431226  0.79461516 1.9492449 0.45542760 0.5649041
#> T-26-0170_Operator_2    1.48393551  0.74252886 1.8532452 0.44944179 0.5756702
#> T-26-0171_Operator_1    1.49317071  0.73810544 2.0210731 0.46970346 0.6944982
#> T-26-0171_Operator_2    1.53102332  0.80379201 1.8979906 0.44592384 0.6307252
#> T-26-0172_Operator_1    1.14624292  0.57805734 1.9413004 0.50321510 0.5994410
#> T-26-0172_Operator_2    1.14030929  0.61547302 1.9368500 0.50413554 0.6269670
#> T-26-0173_Operator_1    1.10034485  0.54509960 1.1544633 0.40098355 0.5809544
#> T-26-0173_Operator_2    1.05556286  0.58066965 1.3105541 0.38205909 0.3858349
#> T-26-0174_Operator_1    1.37976009  0.83216686 1.6253037 0.41612402 0.4882082
#> T-26-0174_Operator_2    1.40118790  0.77496201 1.5413558 0.38577549 0.3684738
#> T-26-0175_Operator_1    1.27849910  0.66444846 1.9128146 0.40273142 0.4400099
#> T-26-0175_Operator_2    1.28898582  0.63946848 1.8555608 0.41092825 0.3911753
#> T-26-0176_Operator_1    1.13845468  0.75668767 1.5805614 0.41888067 0.6526760
#> T-26-0176_Operator_2    1.21415128  0.76586585 1.5570886 0.44460612 0.6520168
#> T-26-0177_Operator_1    1.65110058  1.03331550 1.8525810 0.51427828 0.5973829
#> T-26-0177_Operator_2    1.67688525  1.03191306 1.8095329 0.51477714 0.5993567
#> T-26-0178_Operator_1    1.38222725  0.73557648 2.0775078 0.46362346 0.5083617
#> T-26-0178_Operator_2    1.40330809  0.72255802 1.9375593 0.43545240 0.4960975
#> T-26-0179-3_Operator_1  1.22506356  0.80233774 1.7499735 0.50204681 0.4939318
#> T-26-0179-3_Operator_2  1.31588369  0.72215564 1.6927206 0.46069936 0.5518222
#> T-26-0179_Operator_1    0.55891871  0.37331857 0.7474939 0.32887366 0.3105607
#> T-26-0179_Operator_2    0.59829058  0.37497161 0.7164019 0.29823348 0.2260697
#> T-26-0180_Operator_1    1.25399089  0.74569564 1.8098409 0.51526383 0.5071279
#> T-26-0180_Operator_2    1.30748784  0.77127710 1.7205466 0.47876058 0.5089066
#> T-26-0181_Operator_1    1.23955998  0.65743078 1.6951960 0.49083469 0.5810812
#> T-26-0181_Operator_2    1.23028075  0.67144757 1.6067623 0.45065789 0.4677650
#> T-26-0182_Operator_1    1.01668471  0.47128119 1.7386097 0.39995652 0.5609361
#> T-26-0182_Operator_2    1.00425174  0.49511921 1.6613910 0.32939553 0.5221259
#> T-26-0183_Operator_1    1.09606298  0.62635425 2.0524639 0.55972881 0.6699678
#> T-26-0183_Operator_2    1.11287006  0.71773476 1.9019272 0.52838079 0.5296090
#> T-26-0184_Operator_1    1.34137093  0.96798600 1.9138480 0.73291731 0.6432320
#> T-26-0184_Operator_2    1.35852499  0.66959169 1.6733664 0.66732230 0.7507929
#> T-26-0185_Operator_1    0.90769467  0.48650475 1.3703162 0.38473934 0.5026215
#> T-26-0185_Operator_2    0.87109136  0.47461450 1.3109198 0.33533617 0.3615955
#> T-26-0186_Operator_1    1.48935550  0.77968092 1.9759486 0.49990010 0.5921612
#> T-26-0186_Operator_2    1.55992046  0.75253917 1.9173256 0.52542462 0.6067416
#> T-26-0187_Operator_1    1.34118214  0.64903484 2.2884840 0.49647353 0.6240112
#> T-26-0187_Operator_2    1.37413645  0.68849921 2.0650409 0.45754782 0.5747221
#> T-26-0188_Operator_1    0.63060597  0.53349472 1.2406975 0.23114716 0.4371280
#> T-26-0188_Operator_2    0.62685530  0.55963671 1.3050264 0.20528354 0.3585239
#> T-26-0189_Operator_1    1.20995988  0.71804104 1.5505552 0.42814604 0.5755045
#> T-26-0189_Operator_2    1.14271641  0.70649571 1.6238506 0.39441189 0.3877312
#> T-26-0190_Operator_1    0.99804319  0.57627142 1.8817531 0.49507319 0.6325312
#> T-26-0190_Operator_2    0.97396959  0.49631022 1.8395520 0.43354598 0.5491635
#> T-26-0191_Operator_1    1.12123439  0.56928790 1.6712928 0.47126019 0.6046321
#> T-26-0191_Operator_2    1.12417934  0.57098496 1.6106552 0.41822902 0.5631919
#> T-26-0192_Operator_1    1.04566281  0.63522784 1.8183212 0.41139467 0.5388809
#> T-26-0192_Operator_2    1.06332695  0.63469048 1.7509180 0.37967617 0.5007292
#> T-26-0193_Operator_1    1.52072962  0.81418070 1.5232833 0.44776007 0.5855988
#> T-26-0193_Operator_2    1.52849805  0.88247112 1.5299589 0.39540036 0.4475567
#> T-26-0194_Operator_1    1.90794976  1.21867372 2.1248661 0.51277528 0.7554993
#> T-26-0194_Operator_2    1.96886122  1.18856381 1.9385909 0.43708169 0.6666753
#> T-26-0195_Operator_1    1.16892570  0.59099223 1.9539009 0.52510002 0.5133692
#> T-26-0195_Operator_2    1.22473675  0.60533178 1.9142249 0.42989961 0.5051615
#> T-26-0196_Operator_1    0.83309243  0.34157849 1.2992435 0.41170742 0.4142519
#> T-26-0196_Operator_2    0.87428525  0.41699518 1.2896523 0.38433976 0.4429503
#> T-26-0197_Operator_1    1.35124546  0.69075260 1.8154242 0.48664089 0.5497112
#> T-26-0197_Operator_2    1.30626356  0.74872050 1.8556002 0.49211988 0.4957135
#> T-26-0198_Operator_1    1.19574133  0.71268232 1.4852297 0.48618322 0.5840770
#> T-26-0198_Operator_2    1.19827325  0.71588844 1.5475114 0.41609367 0.5616308
#> T-26-0199_Operator_1    0.65032268  0.45633009 1.1930113 0.19318444 0.3796212
#> T-26-0199_Operator_2    0.58192659  0.46699961 1.1314433 0.15930702 0.2365680
#> T-26-0200_Operator_1    1.39807082  1.01471332 1.7108162 0.48738588 0.5156327
#> T-26-0200_Operator_2    1.50024260  0.94355639 1.7779299 0.42313519 0.5097908
#> T-26-0201_Operator_1    0.91080842  0.52176211 1.5403679 0.43847971 0.4739839
#> T-26-0201_Operator_2    0.90149798  0.57782187 1.4438951 0.40145861 0.4145701
#> T-26-0202_Operator_1    0.97739546  1.12420149 2.2328896 0.74058881 0.8937692
#> T-26-0202_Operator_2    1.19167354  0.83640092 2.1509872 0.64354679 1.0081444
#> T-26-0203_Operator_1    1.17111409  0.62436941 1.6849489 0.42793158 0.5379585
#> T-26-0203_Operator_2    1.10575422  0.59171985 1.6112486 0.37042637 0.4806165
#> T-26-0204_Operator_1    1.00286566  0.57489363 1.9540903 0.45078710 0.5516933
#> T-26-0204_Operator_2    1.00281000  0.62841232 1.7986907 0.41302332 0.4779014
#> T-26-0205_Operator_1    1.10857585  0.72381233 1.5656090 0.46048363 0.4298443
#> T-26-0205_Operator_2    1.10107068  0.73639503 1.4802236 0.43213670 0.3343871
#> T-26-0206_Operator_1    0.85088839  0.56508723 1.5824366 0.41296750 0.5279214
#> T-26-0206_Operator_2    0.84733560  0.56914117 1.4032833 0.36654760 0.4039247
#> T-26-0207_Operator_1    0.61273749  0.43414891 1.3098587 0.32009031 0.3949563
#> T-26-0207_Operator_2    0.62391500  0.42847109 1.2344209 0.26619123 0.3305180
#> T-26-0208_Operator_1    0.65114769  0.45798863 1.2821715 0.20261623 0.3668108
#> T-26-0208_Operator_2    0.65490605  0.49726626 1.4417030 0.15233927 0.2798919
#> T-26-0209_Operator_1    1.39633554  0.95635583 1.8863343 0.49122456 0.5830526
#> T-26-0209_Operator_2    1.45699599  0.83231026 1.9514264 0.46109523 0.5943812
#> T-26-0210_Operator_1    0.62620999  0.34752656 0.8183221 0.34423269 0.3153071
#> T-26-0210_Operator_2    0.65278352  0.29560866 0.8333186 0.30846584 0.2595998
#> T-26-0211_Operator_1    1.05571339  0.66438725 1.4869249 0.37496757 0.4958174
#> T-26-0211_Operator_2    1.05367315  0.67886186 1.4654562 0.33926367 0.3859855
#> T-26-0212_Operator_1    0.80431123  0.37488955 1.2765070 0.39592536 0.4399292
#> T-26-0212_Operator_2    0.77239649  0.42837158 1.1913589 0.34498537 0.4029324
#> T-26-0213_Operator_1    1.16471303  0.56445216 1.3226731 0.41905006 0.4815068
#> T-26-0213_Operator_2    1.17937887  0.64992646 1.3801268 0.37598373 0.3784277
#> T-26-0214_Operator_1    1.88021814  0.84209875 2.2107112 0.66838829 0.6048622
#> T-26-0214_Operator_2    1.90196282  0.96379233 2.1501490 0.67056880 0.5603791
#> T-26-0215_Operator_1    1.16463915  0.66187910 1.6010172 0.41198017 0.4682769
#> T-26-0215_Operator_2    1.17196439  0.69576367 1.5114789 0.35475746 0.3368139
#> T-26-0216_Operator_1    1.13761018  0.60886178 1.4469641 0.36531707 0.4248397
#> T-26-0216_Operator_2    1.16678387  0.66373695 1.4390191 0.34463063 0.3496519
#> T-26-0217_Operator_1    1.08285766  0.41726035 1.9441385 0.46878528 0.6918708
#> T-26-0217_Operator_2    1.07566393  0.48064269 1.8418349 0.40509227 0.5070143
#> T-26-0218_Operator_1    0.59998571  0.49570761 1.1751555 0.19574461 0.4275490
#> T-26-0218_Operator_2    0.59873581  0.43402237 1.3450401 0.17994750 0.2886943
#> T-26-0219_Operator_1    0.74034947  0.43623503 0.9211762 0.28854941 0.2984846
#> T-26-0219_Operator_2    0.75942102  0.41680493 0.8824022 0.24622288 0.2665267
#> T-26-0220_Operator_1    0.71477893  0.47892786 1.3413517 0.34439356 0.4962232
#> T-26-0220_Operator_2    0.69197190  0.49527384 1.2213921 0.31032247 0.4141562
#> T-26-0221_Operator_1    1.04923576  0.37431358 0.8763393 0.52696657 0.1794037
#> T-26-0221_Operator_2    1.05161341  0.39741417 1.1357024 0.51002756 0.3046628
#> T-26-0222_Operator_1    1.96340112  0.78822398 3.3745859 1.00167993 1.2315004
#> T-26-0222_Operator_2    2.12082274  0.84359285 3.6416051 1.06255268 1.2661727
#> T-26-0223_Operator_1    1.54171858  0.88281914 1.7407626 0.51930537 0.5645767
#> T-26-0223_Operator_2    1.54522710  0.93432127 1.8308515 0.51944063 0.5559612
#> T-26-0224_Operator_1    1.07456357  0.71420266 2.0841112 0.40261406 0.5174085
#> T-26-0224_Operator_2    0.99462772  0.65409730 2.0340292 0.37529012 0.3216723
#> T-26-0225_Operator_1    1.60081069  0.70782199 1.9962120 0.73388115 0.5787059
#> T-26-0225_Operator_2    1.53574060  0.64851966 2.0171032 0.67243678 0.5717007
#> T-26-0226_Operator_1    0.51612837  0.39354020 0.7839078 0.35483133 0.2165094
#> T-26-0226_Operator_2    0.52910483  0.33664992 0.8476074 0.32784489 0.2097156
#> T-26-0227_Operator_1    0.97447889  0.32745471 1.3189114 0.54707112 0.3711530
#> T-26-0227_Operator_2    1.03219266  0.23304752 1.3484787 0.50186632 0.5914446
#> T-26-0228_Operator_1    1.14371004  0.46245712 1.5967962 0.51900420 0.3151778
#> T-26-0228_Operator_2    1.13556269  0.39733208 1.4649202 0.49198522 0.5316171
#> T-26-0229_Operator_1    1.01656995  0.66013324 1.9265707 0.57505286 0.6356646
#> T-26-0229_Operator_2    0.97843307  0.71141854 1.9639867 0.54566002 0.6683721
#> T-26-0230-1_Operator_1  0.65424338  0.50932160 1.4255353 0.19345870 0.5346862
#> T-26-0230-1_Operator_2 14.78571429 11.28571429 2.7142857 3.46428571 0.9642857
#> T-26-0230-2_Operator_1  0.37788690  0.30608313 1.4134916 0.17421392 0.4297743
#> T-26-0230-2_Operator_2  0.39314069  0.34049972 1.3129773 0.14768377 0.2264480
#> T-26-0230-3_Operator_1  0.50980282  0.30029965 1.2717880 0.21140772 0.4545539
#> T-26-0230-3_Operator_2  0.50336471  0.31211277 1.3530797 0.20061610 0.2428629
#> T-26-0230-4_Operator_1  0.65324909  0.50858046 1.2651412 0.21337215 0.4558231
#> T-26-0230-4_Operator_2  0.63770687  0.54188042 1.2130640 0.17338400 0.2803835
#> T-26-0231_Operator_1    0.54540466  0.39832358 1.3453008 0.18589120 0.4922311
#> T-26-0231_Operator_2    0.53845059  0.43642219 1.2683511 0.18205810 0.4268692
#> T-26-0232_Operator_1    0.66437686  0.54923514 1.2630361 0.21708790 0.3504884
#> T-26-0232_Operator_2    0.73649242  0.60077692 1.2430980 0.14167091 0.2963734
#> T-26-0233_Operator_1            NA          NA        NA         NA        NA
#> T-26-0233_Operator_2    0.65591276  0.53105499 1.0044948 0.17754705 0.2914795
#> T-26-0234_Operator_1    2.81861504  1.24136099 3.2357406 0.90196009 0.8574090
#> T-26-0234_Operator_2    2.80861959  1.24308305 3.1746314 0.90547806 0.6560534
#> T-26-0235_Operator_1    1.06658894  0.44057474 0.9735126 0.49044458 0.2979985
#> T-26-0235_Operator_2    1.04940373  0.43571191 1.0667255 0.46280881 0.2999464
#> T-26-0236_Operator_1    2.14712171  0.84958157 2.6929018 0.91595122 0.7561259
#> T-26-0236_Operator_2    2.18449550  0.89092407 2.5132647 0.81264778 0.8475999
#> T-26-0237_Operator_1    2.08066647  0.85836937 2.6636192 0.82297482 0.7084239
#> T-26-0237_Operator_2    2.10308829  0.82904383 2.4745352 0.83060856 0.9459992
#> T-26-0238_Operator_1    1.49333827  0.66894662 2.0470459 0.64925370 0.4398730
#> T-26-0238_Operator_2    1.57347951  0.68604010 2.0753058 0.71873837 0.3881104
#> T-26-0239_Operator_1    1.18386821  0.99404402 1.5136591 0.72488839 0.6525848
#> T-26-0239_Operator_2    1.17636948  0.15254474 2.1669605 0.63915629 0.6381912
#> T-26-0240_Operator_1    1.07868766  0.47603201 1.0817543 0.43147996 0.3402350
#> T-26-0240_Operator_2    1.06573783  0.45954773 1.0355680 0.40580571 0.2727971
#> T-26-0241_Operator_1    0.55382169  0.30341121 0.7749065 0.32634274 0.3352962
#> T-26-0241_Operator_2    0.57598805  0.29849153 0.8277468 0.27150657 0.2047270
#> T-26-0242_Operator_1    2.86337392  1.34018386 2.6095346 0.91813310 0.8058141
#> T-26-0242_Operator_2    2.78933431  1.44983285 2.7076427 0.74523084 0.5510857
#> T-26-0243_Operator_1    0.62626384  0.31834075 0.5025614 0.37022227        NA
#> T-26-0243_Operator_2    0.61299772  0.28312780 0.6218678 0.35169993 0.3087071
#> T-26-0244_Operator_1    0.46591387  0.26160274        NA 0.24565178        NA
#> T-26-0244_Operator_2    0.47338326  0.17135709 0.4646828 0.21874473 0.2506922
#> T-26-0245_Operator_1    0.83666866  0.33334815 0.9329054 0.50337468 0.2092302
#> T-26-0245_Operator_2    0.92486850  0.32433093 0.8572459 0.44136989 0.3426519
#> T-26-0246_Operator_1    0.90818858  0.32386315 0.9138203 0.48060936 0.2992697
#> T-26-0246_Operator_2    0.94702540  0.32970798 0.9891673 0.45251446 0.2640474
#> T-26-0247_Operator_1    0.51548776  0.26214909 0.8334120 0.31503569 0.3011354
#> T-26-0247_Operator_2    0.45657597  0.21446292 0.8430318 0.27554343 0.2898066
#> T-26-0248_Operator_1    0.43008693  0.15741371 0.4076571 0.21504060 0.2392820
#> T-26-0248_Operator_2    0.43779791  0.10231234 0.4225775 0.24544538 0.2441442
#> T-26-0249_Operator_1    0.42165583  0.17228589 0.4106802 0.27162431 0.2436490
#> T-26-0249_Operator_2    0.41543453  0.11737304 0.3791004 0.26549880 0.2320982
#> T-26-0250_Operator_1    0.48100611  0.23777752 0.3611692 0.27296152 0.1838095
#> T-26-0250_Operator_2    0.50691290  0.18332159 0.3917656 0.26948539 0.1739732
#> T-26-0251_Operator_1    0.49832927  0.32048021 0.8569294 0.29744903 0.3245761
#> T-26-0251_Operator_2    0.53720868  0.35740693 0.8120889 0.27069603 0.3395488
#> T-26-0252_Operator_1    0.37912321  0.19087001 0.5778989 0.25719912 0.1497566
#> T-26-0252_Operator_2    0.38794716  0.08855067 0.6409236 0.23507771 0.2071919
#> T-26-0261-1_Operator_1  0.99424220  0.77956742 2.1859352 0.35791341 0.7287484
#> T-26-0261-1_Operator_2  1.07907389  0.80474724 2.2016044 0.33135900 0.5476256
#> T-26-0261-2_Operator_1  1.27891375  0.92676017 1.8828159 0.41478989 0.6933126
#> T-26-0261-2_Operator_2  1.23145738  0.64853706 1.9604526 0.37325455 0.5913947
#> T-26-0261-3_Operator_1  1.41453169  0.76515933 1.6612556 0.36673120 0.5545724
#> T-26-0261-3_Operator_2  1.35400779  0.75017996 1.4980387 0.38429814 0.3610260
#> T-26-0261-4_Operator_1  0.98694869  0.50957400 1.3066810 0.36121432 0.4950245
#> T-26-0261-4_Operator_2  1.02893237  0.50885237 1.2284369 0.29181906 0.4429458
#> T-26-0261-5_Operator_1  1.31293175  0.54545272 1.8428619 0.34766362 0.6839897
#> T-26-0261-5_Operator_2  1.35026187  0.58080972 1.7761817 0.36877878 0.6478548
#> T-26-0262-1_Operator_1  1.01308992  0.62343357 1.4744468 0.41266819 0.4469410
#> T-26-0262-1_Operator_2  1.06753668  0.68249693 1.5593549 0.36270217        NA
#> T-26-0262-2_Operator_1  1.22722719  0.78705776 1.3347221 0.36109563 0.3809096
#> T-26-0262-2_Operator_2  1.20758519  0.71253455 1.3738320 0.36317692 0.4323511
#> T-26-0263_Operator_1    0.33117490  0.28938703 0.7108980 0.27715268 0.2845440
#> T-26-0263_Operator_2    0.33902823  0.20079156 0.6839560 0.24851926 0.2185070
#> T-26-0264-1_Operator_1  0.41999345  0.31102910 0.9098239 0.26856589 0.3467906
#> T-26-0264-1_Operator_2  0.36969742  0.29873447 0.6347761 0.24692125 0.2076427
#> T-26-0264-2_Operator_1  0.43837449  0.25206315 0.6391976 0.28041253 0.3681865
#> T-26-0264-2_Operator_2  0.45697410  0.22813365 0.6842708 0.25103966 0.2611183
#> T-26-0264-3_Operator_1  0.53486887  0.25032746 0.7972604 0.24611109 0.3590712
#> T-26-0264-3_Operator_2  0.51076847  0.20621551 0.8954858 0.23983074        NA
#> T-26-0264-4_Operator_1  0.25544630  0.23874204 0.6242245 0.26829381 0.2590520
#> T-26-0264-4_Operator_2  0.29007898  0.18667089 0.5470114 0.26252610 0.1712749
#> T-26-0265_Operator_1    1.38055835  0.65192024 1.3583078 0.58357138 0.7686066
#> T-26-0265_Operator_2    1.37843346  0.49422899 1.4787695 0.55024928 0.6294201
#> T-26-0266_Operator_1    3.40458062  1.56881602 4.0784015 1.02242346 1.4374242
#> T-26-0266_Operator_2    3.27445249  1.38585372 4.2207100 1.01745140 1.3056970
#> T-26-0267_Operator_1    4.11409055  2.11868306 4.3351966 1.11981856 1.4368203
#> T-26-0267_Operator_2    4.17766885  1.86696709 4.3489138 1.15699369 1.0019104
#> T-26-0268_Operator_1    0.92011977  0.42160157 1.3826433 0.45185160 0.4182984
#> T-26-0268_Operator_2    0.97325813  0.39803949 1.2562755 0.42727464 0.4173573
#> T-26-0269_Operator_1    1.00803734  0.55001838 1.3065135 0.47999279 0.7618184
#> T-26-0269_Operator_2    1.16000507  0.52531223 1.2117464 0.43699509 0.7263527
#> T-26-0270-1_Operator_1  1.54978550  0.82987215 2.0703684 0.72324057 0.9454317
#> T-26-0270-1_Operator_2  1.60812305  0.69146000 2.1342190 0.62940434 1.1270447
#> T-26-0270-2_Operator_1  1.70199173  0.66836448 2.2068322 0.68831087 1.1332390
#> T-26-0270-2_Operator_2  1.76529053  0.79495891 2.2839159 0.69969558 1.0694007
#> T-26-0271_Operator_1    1.28707456  1.05612453 1.4288417 0.70018464 0.9437855
#> T-26-0271_Operator_2    1.27971713  0.13676711 1.9600977 0.65449873 1.2271158
#> T-26-0272_Operator_1    0.62500000  0.34551704 1.4820194 0.26374947 0.3822552
#> T-26-0272_Operator_2    0.70749356  0.38210986 1.3993141 0.22749323 0.3727187
#> T-26-0273_Operator_1    1.05186529  0.43996089 1.4668393 0.54807941 0.6778086
#> T-26-0273_Operator_2    1.17163552  0.46140110 1.4977092 0.52368515 0.6130181
#> T-26-0274_Operator_1    0.73472825  0.52670069 1.2431572 0.22561543 0.4288991
#> T-26-0274_Operator_2    0.74046412  0.48127522 1.3150777 0.17242980 0.3296068
#> T-26-0275_Operator_1    0.63842637  0.41817531 1.4296359 0.19427088 0.3611908
#> T-26-0275_Operator_2    0.65770747  0.37391143 1.2887249 0.17111278 0.4098693
#> T-26-0276_Operator_1    0.76873760  0.52359585 1.0499575 0.34284948 0.5673048
#> T-26-0276_Operator_2    0.79456636  0.55321089 1.0213977 0.34111700 0.4341671
#> T-26-0277_Operator_1    0.85573384  0.30649766 1.1166362 0.36779720 0.4560666
#> T-26-0277_Operator_2    0.85624224  0.39561356 1.1290499 0.33768957        NA
#> T-26-0278-1_Operator_1  0.86401663  0.41056703 1.0048873 0.20547745 0.2735921
#> T-26-0278-1_Operator_2  0.88155297  0.47729830 1.0907479 0.17349314        NA
#> T-26-0278-2_Operator_1  0.44507228  0.23227747 1.1752007 0.20551839 0.4002435
#> T-26-0278-2_Operator_2  0.46467053  0.25906856 1.1282148 0.13863854 0.2873251
#> T-26-0279_Operator_1    0.73406409  0.64568390 1.1053879 0.20927980 0.4565335
#> T-26-0279_Operator_2    0.70631205  0.56038309 1.2345728 0.13925098 0.3074775
#>                                CPd        CFd
#> T-26-0001_Operator_1    0.74661661  2.3881553
#> T-26-0001_Operator_2    0.88204160  2.3555187
#> T-26-0002_Operator_1    0.86744898  2.9887710
#> T-26-0002_Operator_2    0.84131281  2.9463784
#> T-26-0003_Operator_1    0.84316511  1.6661061
#> T-26-0003_Operator_2    0.75136772  1.6219693
#> T-26-0004_Operator_1    1.98212136  6.9970171
#> T-26-0004_Operator_2    1.92616619  6.9441999
#> T-26-0005_Operator_1    0.67852772  1.3777322
#> T-26-0005_Operator_2    0.60294313  1.3602311
#> T-26-0006_Operator_1    0.75898188  2.8119275
#> T-26-0006_Operator_2    0.82683299  2.8132208
#> T-26-0007_Operator_1    2.04786778  6.6249103
#> T-26-0007_Operator_2    2.00595819  6.7471584
#> T-26-0008_Operator_1    1.57519468  5.1621230
#> T-26-0008_Operator_2    1.48020167  5.1817373
#> T-26-0009_Operator_1    0.79557461  2.4649486
#> T-26-0009_Operator_2    0.79387286  2.4462978
#> T-26-0010_Operator_1    0.89507494  3.2100664
#> T-26-0010_Operator_2    0.85906212  3.1779213
#> T-26-0011_Operator_1    2.69358908  6.4940660
#> T-26-0011_Operator_2    2.64979636  6.7154595
#> T-26-0012_Operator_1    0.64992797  2.3813561
#> T-26-0012_Operator_2    0.62490733  2.3480907
#> T-26-0013_Operator_1    0.87018717  3.0692624
#> T-26-0013_Operator_2    0.85918646  3.1755699
#> T-26-0014_Operator_1    0.87995790  3.2781578
#> T-26-0014_Operator_2    0.87361926  3.2468369
#> T-26-0015_Operator_1    0.83986095  3.2807552
#> T-26-0015_Operator_2    0.82078919  3.1747721
#> T-26-0016_Operator_1    0.91906871  3.7056342
#> T-26-0016_Operator_2    0.86026901  3.5868047
#> T-26-0017_Operator_1    0.72855360  2.6726891
#> T-26-0017_Operator_2    0.70414033  2.6121760
#> T-26-0018_Operator_1    2.14607318  6.4822496
#> T-26-0018_Operator_2    2.06087815  6.3293571
#> T-26-0019_Operator_1    1.41393476  4.4712612
#> T-26-0019_Operator_2    1.38760649  4.4044201
#> T-26-0020_Operator_1    0.95642433  3.4848776
#> T-26-0020_Operator_2    1.04691321  3.5395061
#> T-26-0021_Operator_1    0.89791500  2.4039626
#> T-26-0021_Operator_2    0.87721304  2.3828054
#> T-26-0022_Operator_1    1.24130427  4.0739721
#> T-26-0022_Operator_2    1.20715123  4.1010720
#> T-26-0023-2_Operator_1  0.39402038  0.9158103
#> T-26-0023-2_Operator_2  0.42295894  0.9631697
#> T-26-0024_Operator_1    0.85051728  2.9368704
#> T-26-0024_Operator_2    0.81469432  2.8974944
#> T-26-0025_Operator_1    0.94529490  3.6004115
#> T-26-0025_Operator_2    0.96418946  3.5249485
#> T-26-0026_Operator_1    0.98714689  3.3994856
#> T-26-0026_Operator_2    0.99608091  3.3831603
#> T-26-0027_Operator_1    1.02166995  3.0321515
#> T-26-0027_Operator_2    1.07698580  2.9963935
#> T-26-0028_Operator_1    0.73958518  2.1741848
#> T-26-0028_Operator_2    0.75594186  2.2006804
#> T-26-0029_Operator_1    0.54001147  1.5831947
#> T-26-0029_Operator_2    0.53096732  1.5686845
#> T-26-0030_Operator_1    1.34909983  3.2185060
#> T-26-0030_Operator_2    1.31589905  3.4722759
#> T-26-0031_Operator_1    0.82542841  2.1630255
#> T-26-0031_Operator_2    0.81679600  2.1806618
#> T-26-0032_Operator_1    2.73647143  7.4349779
#> T-26-0032_Operator_2    2.61320235  7.5128231
#> T-26-0033_Operator_1    0.89125851  3.1456551
#> T-26-0033_Operator_2    0.88976082  3.1437432
#> T-26-0034_Operator_1    0.91393689  2.7748779
#> T-26-0034_Operator_2    0.97581388  2.8123216
#> T-26-0035_Operator_1    0.61076946  1.5660901
#> T-26-0035_Operator_2    0.64985944  1.6103029
#> T-26-0036_Operator_1    1.34522540  3.3372124
#> T-26-0036_Operator_2    1.37571298  3.4356045
#> T-26-0037_Operator_1    1.78656147  4.2604351
#> T-26-0037_Operator_2    1.85075923  4.5821328
#> T-26-0038_Operator_1    0.75159969  1.8861551
#> T-26-0038_Operator_2    0.77625521  1.8473321
#> T-26-0039_Operator_1    0.84979877  2.6692090
#> T-26-0039_Operator_2    0.84227964  2.7185547
#> T-26-0040_Operator_1    0.88569211  1.8204049
#> T-26-0040_Operator_2    0.95972227  1.8945356
#> T-26-0041_Operator_1    0.66020674  2.1580169
#> T-26-0041_Operator_2    0.69296749  2.1713621
#> T-26-0042_Operator_1    0.94024767  3.5479846
#> T-26-0042_Operator_2    1.01297431  3.5318681
#> T-26-0043_Operator_1    0.85348786  2.7862582
#> T-26-0043_Operator_2    0.87329601  2.7804717
#> T-26-0044_Operator_1    0.96634059  3.3917235
#> T-26-0044_Operator_2    1.05279955  3.3311251
#> T-26-0045_Operator_1    1.54817839  5.8389634
#> T-26-0045_Operator_2    1.47815431  5.6214807
#> T-26-0046_Operator_1    0.89272572  3.1513142
#> T-26-0046_Operator_2    0.86872525  3.1279829
#> T-26-0047_Operator_1    2.83768077  9.6624416
#> T-26-0047_Operator_2    2.88405579 10.0136552
#> T-26-0048_Operator_1    1.04700214  3.1011184
#> T-26-0048_Operator_2    1.18130210  3.1493540
#> T-26-0049_Operator_1    1.45381636  4.9975595
#> T-26-0049_Operator_2    1.50664459  5.0148786
#> T-26-0050_Operator_1    0.78376397  2.8838907
#> T-26-0050_Operator_2    0.08143322  0.1628664
#> T-26-0051_Operator_1    1.04491646  4.1096629
#> T-26-0051_Operator_2    1.11659528  4.2243517
#> T-26-0052_Operator_1    1.04033850  1.4969613
#> T-26-0052_Operator_2    1.72679819  5.7026300
#> T-26-0053_Operator_1    1.77835121  4.5813119
#> T-26-0053_Operator_2    1.70813358  4.5167976
#> T-26-0054_Operator_1    1.47213186  4.3374223
#> T-26-0054_Operator_2    1.55105328  4.4662890
#> T-26-0055_Operator_1    0.94478386  2.8418018
#> T-26-0055_Operator_2    1.00091438  2.8544145
#> T-26-0056-2_Operator_1  1.09998822  4.0491518
#> T-26-0056-2_Operator_2  1.19404463  4.0139593
#> T-26-0057_Operator_1    0.84792056  2.9038447
#> T-26-0057_Operator_2    0.91610418  2.8548034
#> T-26-0058_Operator_1    1.09506626  3.1454666
#> T-26-0058_Operator_2            NA         NA
#> T-26-0059_Operator_1    1.04775421  3.3956498
#> T-26-0059_Operator_2    1.03874805  3.3736203
#> T-26-0060_Operator_1    0.93461988  2.6292141
#> T-26-0060_Operator_2    0.97315038  2.7660483
#> T-26-0061_Operator_1    1.49947044  4.6079693
#> T-26-0061_Operator_2    1.59240855  4.7368871
#> T-26-0062_Operator_1    1.94615746  6.6733016
#> T-26-0062_Operator_2    2.00176444  7.0168582
#> T-26-0063_Operator_1    0.70409733  2.2468482
#> T-26-0063_Operator_2    0.72040147  2.2398611
#> T-26-0064_Operator_1    0.90570550  2.0421302
#> T-26-0064_Operator_2    0.94080931  2.1884567
#> T-26-0065_Operator_1    0.87995967  2.8812857
#> T-26-0065_Operator_2    0.92874863  2.9102122
#> T-26-0067_Operator_1    0.93043596  1.6071451
#> T-26-0067_Operator_2    1.02255663  1.7659190
#> T-26-0068_Operator_1    1.19853609  4.1259160
#> T-26-0068_Operator_2    1.26869179  4.2187464
#> T-26-0069_Operator_1    0.86558967  2.6553140
#> T-26-0069_Operator_2    0.88447243  2.7477265
#> T-26-0070_Operator_1    0.98532578  3.0144802
#> T-26-0070_Operator_2    1.05490236  3.0431116
#> T-26-0071_Operator_1    0.88086347  2.8643887
#> T-26-0071_Operator_2    0.90780782  2.8390204
#> T-26-0072_Operator_1    0.99095792  2.2465413
#> T-26-0072_Operator_2    1.03541889  2.3446777
#> T-26-0073_Operator_1    0.98305829  2.9215924
#> T-26-0073_Operator_2    0.97977434  2.9286063
#> T-26-0074_Operator_1    1.03864732  2.8445721
#> T-26-0074_Operator_2    1.07534459  2.9306498
#> T-26-0075_Operator_1    1.14507518  3.8286863
#> T-26-0075_Operator_2    1.32485512  3.9159532
#> T-26-0076_Operator_1    1.19933035  3.6514106
#> T-26-0076_Operator_2    1.28934391  3.6683041
#> T-26-0077_Operator_1    0.64109402  1.4798535
#> T-26-0077_Operator_2    0.72460423  1.5373085
#> T-26-0078_Operator_1    1.07916131  1.7517570
#> T-26-0078_Operator_2    1.10578879  1.8856283
#> T-26-0079_Operator_1    0.80448479  2.1296275
#> T-26-0079_Operator_2    0.78224941  2.1786610
#> T-26-0080_Operator_1    0.67221829  1.6498208
#> T-26-0080_Operator_2    0.68144450  1.7343666
#> T-26-0081_Operator_1    0.57663588  2.0594499
#> T-26-0081_Operator_2    0.61618884  2.1454370
#> T-26-0082_Operator_1    0.91004758  2.8854969
#> T-26-0082_Operator_2    0.92261717  2.8847856
#> T-26-0083_Operator_1    0.55932413  1.4254284
#> T-26-0083_Operator_2    0.57650674  1.4731171
#> T-26-0084_Operator_1    0.69300384  2.0254025
#> T-26-0084_Operator_2    0.69142606  2.0378669
#> T-26-0085_Operator_1    0.80344399  1.9696287
#> T-26-0085_Operator_2    0.82545103         NA
#> T-26-0086_Operator_1    0.98054094  2.1420406
#> T-26-0086_Operator_2    0.97921177  2.3509634
#> T-26-0087_Operator_1    0.84671534  2.0895244
#> T-26-0087_Operator_2    0.82056096  2.0739657
#> T-26-0088_Operator_1    0.78696873  1.8058329
#> T-26-0088_Operator_2    0.82057768         NA
#> T-26-0089_Operator_1    0.31151945  0.9462838
#> T-26-0089_Operator_2    0.31217805  1.0180950
#> T-26-0090_Operator_1    0.46499826  0.7266579
#> T-26-0090_Operator_2    0.42554710  0.7285386
#> T-26-0091_Operator_1    0.91491771  2.7065916
#> T-26-0091_Operator_2    1.00108794  2.9396444
#> T-26-0092_Operator_1    0.86242964  2.7905426
#> T-26-0092_Operator_2    0.93490388  2.8462478
#> T-26-0093_Operator_1    0.85141207  2.6579084
#> T-26-0093_Operator_2    0.85438558  2.7546495
#> T-26-0094_Operator_1    0.67282653  1.7084773
#> T-26-0094_Operator_2    0.69307110  1.8304740
#> T-26-0095_Operator_1    0.83458512  3.0876213
#> T-26-0095_Operator_2    0.80006403  3.0676959
#> T-26-0096_Operator_1    0.61503499  1.9894827
#> T-26-0096_Operator_2    0.65256182  2.0084186
#> T-26-0097_Operator_1    0.96180342  2.5495034
#> T-26-0097_Operator_2    0.96703238  2.5193426
#> T-26-0098_Operator_1    0.85450415  2.4580658
#> T-26-0098_Operator_2    0.79276981  2.5048147
#> T-26-0099_Operator_1    0.40729495  1.2417925
#> T-26-0099_Operator_2    0.42328260  1.2924933
#> T-26-0100_Operator_1    0.71411210  1.9585391
#> T-26-0100_Operator_2    0.61956915         NA
#> T-26-0101_Operator_1    0.77207914  2.8471380
#> T-26-0101_Operator_2    0.82233011  2.9197267
#> T-26-0102_Operator_1    7.17720036  2.4448764
#> T-26-0102_Operator_2    0.73237071  2.4643298
#> T-26-0103_Operator_1    1.19085054  3.4684741
#> T-26-0103_Operator_2    1.07513234  3.5252356
#> T-26-0104_Operator_1    1.02580155  2.9546155
#> T-26-0104_Operator_2    0.96332047  3.0936431
#> T-26-0107_Operator_1    1.03806850  1.8771877
#> T-26-0107_Operator_2            NA         NA
#> T-26-0108_Operator_1    1.04895200  2.8055072
#> T-26-0108_Operator_2    0.97966313  2.9711929
#> T-26-0109_Operator_1    1.00875877  1.2746669
#> T-26-0109_Operator_2    0.85573835  1.3006195
#> T-26-0111_Operator_1    0.30359381  0.6624044
#> T-26-0111_Operator_2    0.26611091  0.6108420
#> T-26-0112-2_Operator_1  0.72739304  2.5341086
#> T-26-0112-2_Operator_2  0.71154338  2.5326900
#> T-26-0112_Operator_1    0.40937992  0.7516845
#> T-26-0112_Operator_2    0.41702433  0.8048003
#> T-26-0113_Operator_1    0.71480648  1.8336902
#> T-26-0113_Operator_2    0.74379703  1.8435405
#> T-26-0114_Operator_1    0.75893119  2.0858802
#> T-26-0114_Operator_2    1.04459895  2.2982704
#> T-26-0115_Operator_1    0.98794364  2.3051897
#> T-26-0115_Operator_2    0.73180688  1.8105997
#> T-26-0116_Operator_1    0.76697778  1.8505683
#> T-26-0116_Operator_2    0.81845000  2.2662616
#> T-26-0117_Operator_1    0.82980787  2.2834658
#> T-26-0117_Operator_2    1.00872651  2.8269347
#> T-26-0118_Operator_1    0.92580436  2.8196495
#> T-26-0118_Operator_2    0.80855984  2.2180214
#> T-26-0120_Operator_1    0.66419537  2.0108479
#> T-26-0120_Operator_2    0.69181351  1.9971281
#> T-26-0121_Operator_1            NA  2.4889053
#> T-26-0121_Operator_2            NA 46.2500000
#> T-26-0122_Operator_1    0.99523256  3.0324028
#> T-26-0122_Operator_2    0.94805104  3.0003691
#> T-26-0123_Operator_1    0.84531911  1.8359718
#> T-26-0123_Operator_2    0.91205363  1.9105812
#> T-26-0125_Operator_1    0.64714158  2.2002373
#> T-26-0125_Operator_2    0.62256089  2.2787559
#> T-26-0126_Operator_1    0.70140867  1.9737072
#> T-26-0126_Operator_2    0.72913926  2.0402390
#> T-26-0127_Operator_1    0.92211763  2.3774479
#> T-26-0127_Operator_2    0.92361074  2.5952002
#> T-26-0128_Operator_1    0.73475215  1.5237441
#> T-26-0128_Operator_2    0.70867070  1.5457207
#> T-26-0130_Operator_1    0.55843568  0.7953048
#> T-26-0130_Operator_2    0.59059332  0.7842463
#> T-26-0131_Operator_1    0.89738751  2.6258582
#> T-26-0131_Operator_2    0.96346128  2.6815355
#> T-26-0132_Operator_1    0.94520812  3.5100029
#> T-26-0132_Operator_2    0.96658013  3.5897979
#> T-26-0133_Operator_1    0.78771644  2.4214586
#> T-26-0133_Operator_2    0.91299852  2.4706085
#> T-26-0134_Operator_1    0.83682594  2.9771613
#> T-26-0134_Operator_2    0.87116571  2.9564417
#> T-26-0135_Operator_1    0.76549904  2.4105810
#> T-26-0135_Operator_2    0.79814605  2.4750311
#> T-26-0136_Operator_1    0.84913583  2.6508421
#> T-26-0136_Operator_2    0.89998973  2.6127350
#> T-26-0137_Operator_1    1.55955569  3.8441334
#> T-26-0137_Operator_2    1.60053499  4.1462961
#> T-26-0138_Operator_1    0.83676235  2.4000015
#> T-26-0138_Operator_2    0.88708697  2.4592981
#> T-26-0139_Operator_1    0.79587378  1.6135731
#> T-26-0139_Operator_2    0.91277777  1.7291064
#> T-26-0140_Operator_1    0.65752271  2.5026000
#> T-26-0140_Operator_2    0.73315404  2.4776456
#> T-26-0141_Operator_1    0.86299346  3.2191099
#> T-26-0141_Operator_2    0.92591179  3.2079963
#> T-26-0142_Operator_1    0.72589556  2.2281950
#> T-26-0142_Operator_2    0.74093314  2.2425744
#> T-26-0143_Operator_1    0.85360522  2.6120792
#> T-26-0143_Operator_2    0.85502843  2.6302135
#> T-26-0144_Operator_1    1.06822218  2.8988373
#> T-26-0144_Operator_2    1.16244876  3.0024063
#> T-26-0145_Operator_1    0.33999379  0.6120432
#> T-26-0145_Operator_2    0.32801951  0.6517895
#> T-26-0146_Operator_1    1.02735731  3.6745242
#> T-26-0146_Operator_2    1.08787758  3.6807453
#> T-26-0147_Operator_1    1.06700885  3.2792833
#> T-26-0147_Operator_2    1.05449177  3.2957084
#> T-26-0148_Operator_1    1.47766697  5.2675328
#> T-26-0148_Operator_2    1.53211259  5.4033873
#> T-26-0149_Operator_1    2.56939163  8.9125365
#> T-26-0149_Operator_2    2.62101820  8.7900698
#> T-26-0150_Operator_1    1.71473188  6.3131456
#> T-26-0150_Operator_2    1.68219658  6.2134242
#> T-26-0151_Operator_1    0.99324603  3.5499705
#> T-26-0151_Operator_2    1.04407626  3.5890075
#> T-26-0152_Operator_1    0.32412453  1.0854926
#> T-26-0152_Operator_2    0.32078987  1.1213906
#> T-26-0153_Operator_1    0.83055181  2.7890400
#> T-26-0153_Operator_2    0.89249282  2.8189162
#> T-26-0154_Operator_1    0.71613763  1.9667001
#> T-26-0154_Operator_2    0.73999209  1.9944878
#> T-26-0155_Operator_1    0.48613070  1.6487981
#> T-26-0155_Operator_2    0.49305395  1.6444771
#> T-26-0156_Operator_1    2.01351105  6.5074921
#> T-26-0156_Operator_2    2.12346276  6.4784613
#> T-26-0157_Operator_1    1.02697733  3.1586578
#> T-26-0157_Operator_2    1.08570917  3.0392820
#> T-26-0158_Operator_1    0.87921789  3.2281692
#> T-26-0158_Operator_2    0.92869913  3.2029995
#> T-26-0159_Operator_1    0.99386610  3.2132416
#> T-26-0159_Operator_2    0.99290579  3.1348309
#> T-26-0160_Operator_1    0.91511901  3.1518291
#> T-26-0160_Operator_2    0.96480562  3.1183684
#> T-26-0161_Operator_1    0.81319803  2.5316513
#> T-26-0161_Operator_2    0.89239574  2.5077029
#> T-26-0162_Operator_1    0.79852408  2.6361187
#> T-26-0162_Operator_2    0.83617159  2.5944157
#> T-26-0163_Operator_1    1.04668790  2.7435095
#> T-26-0163_Operator_2    1.09604410  2.7052521
#> T-26-0164_Operator_1    0.48674340  1.6430883
#> T-26-0164_Operator_2    0.50675901  1.6330442
#> T-26-0165_Operator_1    0.78956511  2.0182109
#> T-26-0165_Operator_2    0.80776941  2.0194991
#> T-26-0166_Operator_1    0.42130251  1.6089361
#> T-26-0166_Operator_2    0.44153185  1.6533006
#> T-26-0167_Operator_1    2.81640047 10.9241640
#> T-26-0167_Operator_2    2.70414424 10.4805669
#> T-26-0168_Operator_1    0.89818435  3.1844346
#> T-26-0168_Operator_2    0.86591454  3.0997330
#> T-26-0169_Operator_1    1.07451554  3.6356437
#> T-26-0169_Operator_2    2.14600361  7.1654512
#> T-26-0170_Operator_1    1.04460351  3.1696411
#> T-26-0170_Operator_2    1.21316105  3.0969766
#> T-26-0171_Operator_1    1.07362888  3.1554360
#> T-26-0171_Operator_2    1.08184235  3.2030868
#> T-26-0172_Operator_1    1.03372048  3.5798343
#> T-26-0172_Operator_2    1.06724121  3.5172135
#> T-26-0173_Operator_1    0.71169482  2.1216551
#> T-26-0173_Operator_2    0.72085019  2.1410302
#> T-26-0174_Operator_1    0.89256228  3.2518680
#> T-26-0174_Operator_2    0.95331328  3.1863202
#> T-26-0175_Operator_1    0.93288904  3.2010521
#> T-26-0175_Operator_2    0.90974780  3.0700439
#> T-26-0176_Operator_1    0.89859201  2.9762694
#> T-26-0176_Operator_2    0.87540742  2.9327261
#> T-26-0177_Operator_1    0.97971964  3.3085401
#> T-26-0177_Operator_2    0.99791806  3.3157905
#> T-26-0178_Operator_1    1.00054807  3.5868983
#> T-26-0178_Operator_2    0.99631423  3.5790157
#> T-26-0179-3_Operator_1  0.99503383  2.9464178
#> T-26-0179-3_Operator_2  0.99884489  2.9335416
#> T-26-0179_Operator_1    0.52449466  1.6627169
#> T-26-0179_Operator_2    0.52475488  1.6351626
#> T-26-0180_Operator_1    1.02320390  2.9707247
#> T-26-0180_Operator_2    1.03478927  2.9149734
#> T-26-0181_Operator_1    0.91185421  3.0396183
#> T-26-0181_Operator_2    0.88816399  2.9376842
#> T-26-0182_Operator_1    0.82648038  2.6596087
#> T-26-0182_Operator_2    0.84685720  2.6004194
#> T-26-0183_Operator_1    1.05274864  2.8606558
#> T-26-0183_Operator_2    1.08731532  2.8561641
#> T-26-0184_Operator_1    0.96129625  2.2332909
#> T-26-0184_Operator_2    1.17590252  2.1989375
#> T-26-0185_Operator_1    0.72091024  2.2312527
#> T-26-0185_Operator_2    0.77583481  2.1629098
#> T-26-0186_Operator_1    1.10623297  3.5062715
#> T-26-0186_Operator_2    1.10280140  3.5266749
#> T-26-0187_Operator_1    1.07934953  2.9902705
#> T-26-0187_Operator_2    1.06973386  2.8675641
#> T-26-0188_Operator_1    0.85374148  1.4430073
#> T-26-0188_Operator_2    0.77846076  1.4678234
#> T-26-0189_Operator_1    0.82062091  2.7096297
#> T-26-0189_Operator_2    0.80951323  2.6608072
#> T-26-0190_Operator_1    0.91803235  3.1422466
#> T-26-0190_Operator_2    0.89936654  3.0265674
#> T-26-0191_Operator_1    0.89795257  2.8681991
#> T-26-0191_Operator_2    0.90612754  2.8372637
#> T-26-0192_Operator_1    1.00645486  3.0791598
#> T-26-0192_Operator_2    1.05781244  3.0051291
#> T-26-0193_Operator_1    0.94086971  2.9338289
#> T-26-0193_Operator_2    0.90710090  2.8656576
#> T-26-0194_Operator_1    1.09882435  3.7203691
#> T-26-0194_Operator_2    1.09592021  3.6195673
#> T-26-0195_Operator_1    0.98327086  3.4557332
#> T-26-0195_Operator_2    0.95339652  3.3574004
#> T-26-0196_Operator_1    0.67871992  2.1642101
#> T-26-0196_Operator_2    0.69314556  2.1547211
#> T-26-0197_Operator_1    0.95377157  3.1698940
#> T-26-0197_Operator_2    0.90926404  3.0777669
#> T-26-0198_Operator_1    0.86595499  2.9369247
#> T-26-0198_Operator_2    0.85756604  2.7925573
#> T-26-0199_Operator_1    0.71064132  1.5896634
#> T-26-0199_Operator_2    0.68991287  1.6290135
#> T-26-0200_Operator_1    0.97413326  3.7784049
#> T-26-0200_Operator_2    1.03204377  3.7381998
#> T-26-0201_Operator_1    0.77161382  2.8315407
#> T-26-0201_Operator_2    0.77685102  2.8224485
#> T-26-0202_Operator_1    0.98025701  4.2461142
#> T-26-0202_Operator_2    1.03136434  4.0630081
#> T-26-0203_Operator_1    0.85579184  2.7530320
#> T-26-0203_Operator_2    0.84183380  2.6897598
#> T-26-0204_Operator_1    0.93416468  3.1448217
#> T-26-0204_Operator_2    1.03225450  3.1187043
#> T-26-0205_Operator_1    0.80250225  2.6000509
#> T-26-0205_Operator_2    0.82079045  2.5416547
#> T-26-0206_Operator_1    0.73031548  2.8255736
#> T-26-0206_Operator_2    0.73721903  2.8114563
#> T-26-0207_Operator_1    0.66649799  2.2322844
#> T-26-0207_Operator_2    0.66549984  2.2341607
#> T-26-0208_Operator_1    0.82795773  1.3885782
#> T-26-0208_Operator_2    0.80060172  1.4386457
#> T-26-0209_Operator_1    0.93020856  2.2393635
#> T-26-0209_Operator_2    1.01730626  2.2987996
#> T-26-0210_Operator_1    0.53442050  1.7290386
#> T-26-0210_Operator_2    0.52419719  1.7342168
#> T-26-0211_Operator_1    0.79368318  2.1989571
#> T-26-0211_Operator_2    0.80580800  2.2155026
#> T-26-0212_Operator_1    0.66074746  1.9789651
#> T-26-0212_Operator_2    0.65217452  1.9387125
#> T-26-0213_Operator_1    0.72789078  2.1905256
#> T-26-0213_Operator_2    0.71981779  2.2159798
#> T-26-0214_Operator_1    1.35413009  4.1483965
#> T-26-0214_Operator_2    1.35263088  4.1218400
#> T-26-0215_Operator_1    0.81081824  2.6951345
#> T-26-0215_Operator_2    0.84988027  2.6903156
#> T-26-0216_Operator_1    0.74986136  2.5774111
#> T-26-0216_Operator_2    0.73254584  2.5915043
#> T-26-0217_Operator_1    1.01500355  3.8429466
#> T-26-0217_Operator_2    0.97932510  3.8976176
#> T-26-0218_Operator_1    0.80892068  2.2346672
#> T-26-0218_Operator_2    0.82731315  2.1690987
#> T-26-0219_Operator_1    0.46441415  1.0109583
#> T-26-0219_Operator_2    0.46012507  1.0398407
#> T-26-0220_Operator_1    0.68539441  1.9827539
#> T-26-0220_Operator_2    0.67923439  1.9825952
#> T-26-0221_Operator_1    0.75752976  2.5002975
#> T-26-0221_Operator_2    0.78996695  2.5179755
#> T-26-0222_Operator_1    1.59030288  6.7887016
#> T-26-0222_Operator_2    1.76569455  6.9655747
#> T-26-0223_Operator_1    0.94144242  2.6305537
#> T-26-0223_Operator_2    1.03234768  2.6201501
#> T-26-0224_Operator_1    1.00638635  3.2187543
#> T-26-0224_Operator_2    0.99179287  3.1800766
#> T-26-0225_Operator_1    1.09108301  3.8509176
#> T-26-0225_Operator_2    1.05156136  3.8184733
#> T-26-0226_Operator_1    0.55160142  1.6322400
#> T-26-0226_Operator_2    0.53941361  1.6381295
#> T-26-0227_Operator_1    0.75374979  2.6367184
#> T-26-0227_Operator_2    0.76447266  2.6530645
#> T-26-0228_Operator_1    0.88323650  3.0647303
#> T-26-0228_Operator_2    0.84580115  3.0669149
#> T-26-0229_Operator_1    1.04557108  4.1205778
#> T-26-0229_Operator_2    1.03266925  4.0394089
#> T-26-0230-1_Operator_1  0.76119760  1.4825842
#> T-26-0230-1_Operator_2 17.23814286 32.9524286
#> T-26-0230-2_Operator_1  0.73992303  1.6782507
#> T-26-0230-2_Operator_2  0.71700636  1.6990649
#> T-26-0230-3_Operator_1  0.74060975  1.5735781
#> T-26-0230-3_Operator_2  0.70913449  1.5686017
#> T-26-0230-4_Operator_1  0.77268126  1.8070497
#> T-26-0230-4_Operator_2  0.80272844  1.7965344
#> T-26-0231_Operator_1    0.84996206  1.9126364
#> T-26-0231_Operator_2    0.80385593  1.8950976
#> T-26-0232_Operator_1    0.69394380  0.9091051
#> T-26-0232_Operator_2    0.66924583  0.9772442
#> T-26-0233_Operator_1            NA         NA
#> T-26-0233_Operator_2    0.63728291  1.2317546
#> T-26-0234_Operator_1    2.04482733  5.1096278
#> T-26-0234_Operator_2    1.98580731  5.2451098
#> T-26-0235_Operator_1    0.67917006  1.9081159
#> T-26-0235_Operator_2    0.68771589  2.0235563
#> T-26-0236_Operator_1    1.60178859  5.0011264
#> T-26-0236_Operator_2    1.61193588  5.0099427
#> T-26-0237_Operator_1    1.75216231  5.4790483
#> T-26-0237_Operator_2    1.75042833  5.4343017
#> T-26-0238_Operator_1    1.29805143  3.8671481
#> T-26-0238_Operator_2    1.28342192  3.8102989
#> T-26-0239_Operator_1    1.02196774  1.9529501
#> T-26-0239_Operator_2    0.95382131  1.9611826
#> T-26-0240_Operator_1    0.77623429  2.2115968
#> T-26-0240_Operator_2    0.75675676  2.2205722
#> T-26-0241_Operator_1    0.48496481  1.3278484
#> T-26-0241_Operator_2    0.51628988  1.3115326
#> T-26-0242_Operator_1    1.78126071  4.4602793
#> T-26-0242_Operator_2    1.69209366  4.3648338
#> T-26-0243_Operator_1    0.52592322         NA
#> T-26-0243_Operator_2    0.53203871  1.6391988
#> T-26-0244_Operator_1    0.37857636  1.0212588
#> T-26-0244_Operator_2    0.39535142  1.0105534
#> T-26-0245_Operator_1    0.77335777  1.8103214
#> T-26-0245_Operator_2    0.78603004  1.8615893
#> T-26-0246_Operator_1    0.70760524  1.7531888
#> T-26-0246_Operator_2    0.65028447  1.7156355
#> T-26-0247_Operator_1    0.48913471  1.4800813
#> T-26-0247_Operator_2    0.48542480  1.2332955
#> T-26-0248_Operator_1    0.35694987  0.8958600
#> T-26-0248_Operator_2    0.31998735  0.9510795
#> T-26-0249_Operator_1    0.36892175  0.7915911
#> T-26-0249_Operator_2    0.35776455  0.7629833
#> T-26-0250_Operator_1    0.36103027         NA
#> T-26-0250_Operator_2    0.36135765  1.1619087
#> T-26-0251_Operator_1    0.54840819  1.7701324
#> T-26-0251_Operator_2    0.51736990  1.7625174
#> T-26-0252_Operator_1    0.37654764  1.3572539
#> T-26-0252_Operator_2    0.38627280  1.3581170
#> T-26-0261-1_Operator_1  1.05206634  2.1585273
#> T-26-0261-1_Operator_2  1.07713044  2.2159578
#> T-26-0261-2_Operator_1  0.93903966  2.2522764
#> T-26-0261-2_Operator_2  0.91455845  2.3571911
#> T-26-0261-3_Operator_1  0.86275344  1.4535208
#> T-26-0261-3_Operator_2  0.65358051  1.5304062
#> T-26-0261-4_Operator_1  0.65763999  1.6767746
#> T-26-0261-4_Operator_2  0.60177874  1.7171569
#> T-26-0261-5_Operator_1  0.89196997  1.3477131
#> T-26-0261-5_Operator_2  0.82465753  1.4869528
#> T-26-0262-1_Operator_1  0.77017839  0.8893569
#> T-26-0262-1_Operator_2  0.76276219  0.8686862
#> T-26-0262-2_Operator_1  0.66670239  0.8426073
#> T-26-0262-2_Operator_2  0.73571823  0.9969905
#> T-26-0263_Operator_1    0.45241713  0.6934284
#> T-26-0263_Operator_2    0.45451078  0.7434583
#> T-26-0264-1_Operator_1  0.45125314  0.7930407
#> T-26-0264-1_Operator_2  0.42533335  0.8505807
#> T-26-0264-2_Operator_1  0.46454098  0.5646399
#> T-26-0264-2_Operator_2  0.44133036  0.7328010
#> T-26-0264-3_Operator_1  0.39580338  1.0584567
#> T-26-0264-3_Operator_2  0.39114438  1.0835165
#> T-26-0264-4_Operator_1  0.38940848  0.7662178
#> T-26-0264-4_Operator_2  0.39387127  0.8113735
#> T-26-0265_Operator_1    1.00000000  2.3205004
#> T-26-0265_Operator_2    1.04489391  2.4451873
#> T-26-0266_Operator_1    2.54883132  6.9647184
#> T-26-0266_Operator_2    2.54363508  7.1326607
#> T-26-0267_Operator_1    2.67815682  8.6800605
#> T-26-0267_Operator_2    2.52558216  8.7359023
#> T-26-0268_Operator_1    0.81410037  1.2806203
#> T-26-0268_Operator_2    0.74753759  1.3659381
#> T-26-0269_Operator_1    0.83385665  2.4437436
#> T-26-0269_Operator_2    0.81699593  2.4546331
#> T-26-0270-1_Operator_1  1.36288887  3.2769592
#> T-26-0270-1_Operator_2  1.31969034  3.3987308
#> T-26-0270-2_Operator_1  1.39255783  2.5969944
#> T-26-0270-2_Operator_2  1.39255035  2.8347499
#> T-26-0271_Operator_1    0.86402215  3.0574002
#> T-26-0271_Operator_2    0.85763267  3.0611648
#> T-26-0272_Operator_1    0.75447552  1.2102572
#> T-26-0272_Operator_2    0.75634144  1.2828177
#> T-26-0273_Operator_1    0.82702315  2.7111506
#> T-26-0273_Operator_2    0.85847915  2.7862445
#> T-26-0274_Operator_1    0.80159265  1.2234723
#> T-26-0274_Operator_2    0.78299754  1.3660243
#> T-26-0275_Operator_1    0.75770551  1.4072418
#> T-26-0275_Operator_2    0.79790647  1.4686380
#> T-26-0276_Operator_1    0.69495450  0.5426357
#> T-26-0276_Operator_2    0.64664237  0.6806938
#> T-26-0277_Operator_1    0.85605626  0.9903243
#> T-26-0277_Operator_2    0.79442475  1.0390353
#> T-26-0278-1_Operator_1  0.60699079  0.3225506
#> T-26-0278-1_Operator_2  0.57988149  0.2719205
#> T-26-0278-2_Operator_1  0.64430266  0.4397017
#> T-26-0278-2_Operator_2  0.63632438  0.4284270
#> T-26-0279_Operator_1    0.75473329  1.4642815
#> T-26-0279_Operator_2    0.73251748  1.4642914

# some real specimens are missing landmark 5, leaving Hd/RMl-related
# segments as NA; impute them using the within-species mean instead of
# carrying the NA forward (na_action defaults to "keep"):
fishmorph_segments(fish, groups = fish$metadata$species, na_action = "impute_group_mean")
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA.
#> na_action = "impute_group_mean": imputed 273 missing value(s) using within-group means.
#>                                      specimen  individual
#> T-26-0001_Operator_1     T-26-0001_Operator_1   T-26-0001
#> T-26-0001_Operator_2     T-26-0001_Operator_2   T-26-0001
#> T-26-0002_Operator_1     T-26-0002_Operator_1   T-26-0002
#> T-26-0002_Operator_2     T-26-0002_Operator_2   T-26-0002
#> T-26-0003_Operator_1     T-26-0003_Operator_1   T-26-0003
#> T-26-0003_Operator_2     T-26-0003_Operator_2   T-26-0003
#> T-26-0004_Operator_1     T-26-0004_Operator_1   T-26-0004
#> T-26-0004_Operator_2     T-26-0004_Operator_2   T-26-0004
#> T-26-0005_Operator_1     T-26-0005_Operator_1   T-26-0005
#> T-26-0005_Operator_2     T-26-0005_Operator_2   T-26-0005
#> T-26-0006_Operator_1     T-26-0006_Operator_1   T-26-0006
#> T-26-0006_Operator_2     T-26-0006_Operator_2   T-26-0006
#> T-26-0007_Operator_1     T-26-0007_Operator_1   T-26-0007
#> T-26-0007_Operator_2     T-26-0007_Operator_2   T-26-0007
#> T-26-0008_Operator_1     T-26-0008_Operator_1   T-26-0008
#> T-26-0008_Operator_2     T-26-0008_Operator_2   T-26-0008
#> T-26-0009_Operator_1     T-26-0009_Operator_1   T-26-0009
#> T-26-0009_Operator_2     T-26-0009_Operator_2   T-26-0009
#> T-26-0010_Operator_1     T-26-0010_Operator_1   T-26-0010
#> T-26-0010_Operator_2     T-26-0010_Operator_2   T-26-0010
#> T-26-0011_Operator_1     T-26-0011_Operator_1   T-26-0011
#> T-26-0011_Operator_2     T-26-0011_Operator_2   T-26-0011
#> T-26-0012_Operator_1     T-26-0012_Operator_1   T-26-0012
#> T-26-0012_Operator_2     T-26-0012_Operator_2   T-26-0012
#> T-26-0013_Operator_1     T-26-0013_Operator_1   T-26-0013
#> T-26-0013_Operator_2     T-26-0013_Operator_2   T-26-0013
#> T-26-0014_Operator_1     T-26-0014_Operator_1   T-26-0014
#> T-26-0014_Operator_2     T-26-0014_Operator_2   T-26-0014
#> T-26-0015_Operator_1     T-26-0015_Operator_1   T-26-0015
#> T-26-0015_Operator_2     T-26-0015_Operator_2   T-26-0015
#> T-26-0016_Operator_1     T-26-0016_Operator_1   T-26-0016
#> T-26-0016_Operator_2     T-26-0016_Operator_2   T-26-0016
#> T-26-0017_Operator_1     T-26-0017_Operator_1   T-26-0017
#> T-26-0017_Operator_2     T-26-0017_Operator_2   T-26-0017
#> T-26-0018_Operator_1     T-26-0018_Operator_1   T-26-0018
#> T-26-0018_Operator_2     T-26-0018_Operator_2   T-26-0018
#> T-26-0019_Operator_1     T-26-0019_Operator_1   T-26-0019
#> T-26-0019_Operator_2     T-26-0019_Operator_2   T-26-0019
#> T-26-0020_Operator_1     T-26-0020_Operator_1   T-26-0020
#> T-26-0020_Operator_2     T-26-0020_Operator_2   T-26-0020
#> T-26-0021_Operator_1     T-26-0021_Operator_1   T-26-0021
#> T-26-0021_Operator_2     T-26-0021_Operator_2   T-26-0021
#> T-26-0022_Operator_1     T-26-0022_Operator_1   T-26-0022
#> T-26-0022_Operator_2     T-26-0022_Operator_2   T-26-0022
#> T-26-0023-2_Operator_1 T-26-0023-2_Operator_1 T-26-0023-2
#> T-26-0023-2_Operator_2 T-26-0023-2_Operator_2 T-26-0023-2
#> T-26-0024_Operator_1     T-26-0024_Operator_1   T-26-0024
#> T-26-0024_Operator_2     T-26-0024_Operator_2   T-26-0024
#> T-26-0025_Operator_1     T-26-0025_Operator_1   T-26-0025
#> T-26-0025_Operator_2     T-26-0025_Operator_2   T-26-0025
#> T-26-0026_Operator_1     T-26-0026_Operator_1   T-26-0026
#> T-26-0026_Operator_2     T-26-0026_Operator_2   T-26-0026
#> T-26-0027_Operator_1     T-26-0027_Operator_1   T-26-0027
#> T-26-0027_Operator_2     T-26-0027_Operator_2   T-26-0027
#> T-26-0028_Operator_1     T-26-0028_Operator_1   T-26-0028
#> T-26-0028_Operator_2     T-26-0028_Operator_2   T-26-0028
#> T-26-0029_Operator_1     T-26-0029_Operator_1   T-26-0029
#> T-26-0029_Operator_2     T-26-0029_Operator_2   T-26-0029
#> T-26-0030_Operator_1     T-26-0030_Operator_1   T-26-0030
#> T-26-0030_Operator_2     T-26-0030_Operator_2   T-26-0030
#> T-26-0031_Operator_1     T-26-0031_Operator_1   T-26-0031
#> T-26-0031_Operator_2     T-26-0031_Operator_2   T-26-0031
#> T-26-0032_Operator_1     T-26-0032_Operator_1   T-26-0032
#> T-26-0032_Operator_2     T-26-0032_Operator_2   T-26-0032
#> T-26-0033_Operator_1     T-26-0033_Operator_1   T-26-0033
#> T-26-0033_Operator_2     T-26-0033_Operator_2   T-26-0033
#> T-26-0034_Operator_1     T-26-0034_Operator_1   T-26-0034
#> T-26-0034_Operator_2     T-26-0034_Operator_2   T-26-0034
#> T-26-0035_Operator_1     T-26-0035_Operator_1   T-26-0035
#> T-26-0035_Operator_2     T-26-0035_Operator_2   T-26-0035
#> T-26-0036_Operator_1     T-26-0036_Operator_1   T-26-0036
#> T-26-0036_Operator_2     T-26-0036_Operator_2   T-26-0036
#> T-26-0037_Operator_1     T-26-0037_Operator_1   T-26-0037
#> T-26-0037_Operator_2     T-26-0037_Operator_2   T-26-0037
#> T-26-0038_Operator_1     T-26-0038_Operator_1   T-26-0038
#> T-26-0038_Operator_2     T-26-0038_Operator_2   T-26-0038
#> T-26-0039_Operator_1     T-26-0039_Operator_1   T-26-0039
#> T-26-0039_Operator_2     T-26-0039_Operator_2   T-26-0039
#> T-26-0040_Operator_1     T-26-0040_Operator_1   T-26-0040
#> T-26-0040_Operator_2     T-26-0040_Operator_2   T-26-0040
#> T-26-0041_Operator_1     T-26-0041_Operator_1   T-26-0041
#> T-26-0041_Operator_2     T-26-0041_Operator_2   T-26-0041
#> T-26-0042_Operator_1     T-26-0042_Operator_1   T-26-0042
#> T-26-0042_Operator_2     T-26-0042_Operator_2   T-26-0042
#> T-26-0043_Operator_1     T-26-0043_Operator_1   T-26-0043
#> T-26-0043_Operator_2     T-26-0043_Operator_2   T-26-0043
#> T-26-0044_Operator_1     T-26-0044_Operator_1   T-26-0044
#> T-26-0044_Operator_2     T-26-0044_Operator_2   T-26-0044
#> T-26-0045_Operator_1     T-26-0045_Operator_1   T-26-0045
#> T-26-0045_Operator_2     T-26-0045_Operator_2   T-26-0045
#> T-26-0046_Operator_1     T-26-0046_Operator_1   T-26-0046
#> T-26-0046_Operator_2     T-26-0046_Operator_2   T-26-0046
#> T-26-0047_Operator_1     T-26-0047_Operator_1   T-26-0047
#> T-26-0047_Operator_2     T-26-0047_Operator_2   T-26-0047
#> T-26-0048_Operator_1     T-26-0048_Operator_1   T-26-0048
#> T-26-0048_Operator_2     T-26-0048_Operator_2   T-26-0048
#> T-26-0049_Operator_1     T-26-0049_Operator_1   T-26-0049
#> T-26-0049_Operator_2     T-26-0049_Operator_2   T-26-0049
#> T-26-0050_Operator_1     T-26-0050_Operator_1   T-26-0050
#> T-26-0050_Operator_2     T-26-0050_Operator_2   T-26-0050
#> T-26-0051_Operator_1     T-26-0051_Operator_1   T-26-0051
#> T-26-0051_Operator_2     T-26-0051_Operator_2   T-26-0051
#> T-26-0052_Operator_1     T-26-0052_Operator_1   T-26-0052
#> T-26-0052_Operator_2     T-26-0052_Operator_2   T-26-0052
#> T-26-0053_Operator_1     T-26-0053_Operator_1   T-26-0053
#> T-26-0053_Operator_2     T-26-0053_Operator_2   T-26-0053
#> T-26-0054_Operator_1     T-26-0054_Operator_1   T-26-0054
#> T-26-0054_Operator_2     T-26-0054_Operator_2   T-26-0054
#> T-26-0055_Operator_1     T-26-0055_Operator_1   T-26-0055
#> T-26-0055_Operator_2     T-26-0055_Operator_2   T-26-0055
#> T-26-0056-2_Operator_1 T-26-0056-2_Operator_1 T-26-0056-2
#> T-26-0056-2_Operator_2 T-26-0056-2_Operator_2 T-26-0056-2
#> T-26-0057_Operator_1     T-26-0057_Operator_1   T-26-0057
#> T-26-0057_Operator_2     T-26-0057_Operator_2   T-26-0057
#> T-26-0058_Operator_1     T-26-0058_Operator_1   T-26-0058
#> T-26-0058_Operator_2     T-26-0058_Operator_2   T-26-0058
#> T-26-0059_Operator_1     T-26-0059_Operator_1   T-26-0059
#> T-26-0059_Operator_2     T-26-0059_Operator_2   T-26-0059
#> T-26-0060_Operator_1     T-26-0060_Operator_1   T-26-0060
#> T-26-0060_Operator_2     T-26-0060_Operator_2   T-26-0060
#> T-26-0061_Operator_1     T-26-0061_Operator_1   T-26-0061
#> T-26-0061_Operator_2     T-26-0061_Operator_2   T-26-0061
#> T-26-0062_Operator_1     T-26-0062_Operator_1   T-26-0062
#> T-26-0062_Operator_2     T-26-0062_Operator_2   T-26-0062
#> T-26-0063_Operator_1     T-26-0063_Operator_1   T-26-0063
#> T-26-0063_Operator_2     T-26-0063_Operator_2   T-26-0063
#> T-26-0064_Operator_1     T-26-0064_Operator_1   T-26-0064
#> T-26-0064_Operator_2     T-26-0064_Operator_2   T-26-0064
#> T-26-0065_Operator_1     T-26-0065_Operator_1   T-26-0065
#> T-26-0065_Operator_2     T-26-0065_Operator_2   T-26-0065
#> T-26-0067_Operator_1     T-26-0067_Operator_1   T-26-0067
#> T-26-0067_Operator_2     T-26-0067_Operator_2   T-26-0067
#> T-26-0068_Operator_1     T-26-0068_Operator_1   T-26-0068
#> T-26-0068_Operator_2     T-26-0068_Operator_2   T-26-0068
#> T-26-0069_Operator_1     T-26-0069_Operator_1   T-26-0069
#> T-26-0069_Operator_2     T-26-0069_Operator_2   T-26-0069
#> T-26-0070_Operator_1     T-26-0070_Operator_1   T-26-0070
#> T-26-0070_Operator_2     T-26-0070_Operator_2   T-26-0070
#> T-26-0071_Operator_1     T-26-0071_Operator_1   T-26-0071
#> T-26-0071_Operator_2     T-26-0071_Operator_2   T-26-0071
#> T-26-0072_Operator_1     T-26-0072_Operator_1   T-26-0072
#> T-26-0072_Operator_2     T-26-0072_Operator_2   T-26-0072
#> T-26-0073_Operator_1     T-26-0073_Operator_1   T-26-0073
#> T-26-0073_Operator_2     T-26-0073_Operator_2   T-26-0073
#> T-26-0074_Operator_1     T-26-0074_Operator_1   T-26-0074
#> T-26-0074_Operator_2     T-26-0074_Operator_2   T-26-0074
#> T-26-0075_Operator_1     T-26-0075_Operator_1   T-26-0075
#> T-26-0075_Operator_2     T-26-0075_Operator_2   T-26-0075
#> T-26-0076_Operator_1     T-26-0076_Operator_1   T-26-0076
#> T-26-0076_Operator_2     T-26-0076_Operator_2   T-26-0076
#> T-26-0077_Operator_1     T-26-0077_Operator_1   T-26-0077
#> T-26-0077_Operator_2     T-26-0077_Operator_2   T-26-0077
#> T-26-0078_Operator_1     T-26-0078_Operator_1   T-26-0078
#> T-26-0078_Operator_2     T-26-0078_Operator_2   T-26-0078
#> T-26-0079_Operator_1     T-26-0079_Operator_1   T-26-0079
#> T-26-0079_Operator_2     T-26-0079_Operator_2   T-26-0079
#> T-26-0080_Operator_1     T-26-0080_Operator_1   T-26-0080
#> T-26-0080_Operator_2     T-26-0080_Operator_2   T-26-0080
#> T-26-0081_Operator_1     T-26-0081_Operator_1   T-26-0081
#> T-26-0081_Operator_2     T-26-0081_Operator_2   T-26-0081
#> T-26-0082_Operator_1     T-26-0082_Operator_1   T-26-0082
#> T-26-0082_Operator_2     T-26-0082_Operator_2   T-26-0082
#> T-26-0083_Operator_1     T-26-0083_Operator_1   T-26-0083
#> T-26-0083_Operator_2     T-26-0083_Operator_2   T-26-0083
#> T-26-0084_Operator_1     T-26-0084_Operator_1   T-26-0084
#> T-26-0084_Operator_2     T-26-0084_Operator_2   T-26-0084
#> T-26-0085_Operator_1     T-26-0085_Operator_1   T-26-0085
#> T-26-0085_Operator_2     T-26-0085_Operator_2   T-26-0085
#> T-26-0086_Operator_1     T-26-0086_Operator_1   T-26-0086
#> T-26-0086_Operator_2     T-26-0086_Operator_2   T-26-0086
#> T-26-0087_Operator_1     T-26-0087_Operator_1   T-26-0087
#> T-26-0087_Operator_2     T-26-0087_Operator_2   T-26-0087
#> T-26-0088_Operator_1     T-26-0088_Operator_1   T-26-0088
#> T-26-0088_Operator_2     T-26-0088_Operator_2   T-26-0088
#> T-26-0089_Operator_1     T-26-0089_Operator_1   T-26-0089
#> T-26-0089_Operator_2     T-26-0089_Operator_2   T-26-0089
#> T-26-0090_Operator_1     T-26-0090_Operator_1   T-26-0090
#> T-26-0090_Operator_2     T-26-0090_Operator_2   T-26-0090
#> T-26-0091_Operator_1     T-26-0091_Operator_1   T-26-0091
#> T-26-0091_Operator_2     T-26-0091_Operator_2   T-26-0091
#> T-26-0092_Operator_1     T-26-0092_Operator_1   T-26-0092
#> T-26-0092_Operator_2     T-26-0092_Operator_2   T-26-0092
#> T-26-0093_Operator_1     T-26-0093_Operator_1   T-26-0093
#> T-26-0093_Operator_2     T-26-0093_Operator_2   T-26-0093
#> T-26-0094_Operator_1     T-26-0094_Operator_1   T-26-0094
#> T-26-0094_Operator_2     T-26-0094_Operator_2   T-26-0094
#> T-26-0095_Operator_1     T-26-0095_Operator_1   T-26-0095
#> T-26-0095_Operator_2     T-26-0095_Operator_2   T-26-0095
#> T-26-0096_Operator_1     T-26-0096_Operator_1   T-26-0096
#> T-26-0096_Operator_2     T-26-0096_Operator_2   T-26-0096
#> T-26-0097_Operator_1     T-26-0097_Operator_1   T-26-0097
#> T-26-0097_Operator_2     T-26-0097_Operator_2   T-26-0097
#> T-26-0098_Operator_1     T-26-0098_Operator_1   T-26-0098
#> T-26-0098_Operator_2     T-26-0098_Operator_2   T-26-0098
#> T-26-0099_Operator_1     T-26-0099_Operator_1   T-26-0099
#> T-26-0099_Operator_2     T-26-0099_Operator_2   T-26-0099
#> T-26-0100_Operator_1     T-26-0100_Operator_1   T-26-0100
#> T-26-0100_Operator_2     T-26-0100_Operator_2   T-26-0100
#> T-26-0101_Operator_1     T-26-0101_Operator_1   T-26-0101
#> T-26-0101_Operator_2     T-26-0101_Operator_2   T-26-0101
#> T-26-0102_Operator_1     T-26-0102_Operator_1   T-26-0102
#> T-26-0102_Operator_2     T-26-0102_Operator_2   T-26-0102
#> T-26-0103_Operator_1     T-26-0103_Operator_1   T-26-0103
#> T-26-0103_Operator_2     T-26-0103_Operator_2   T-26-0103
#> T-26-0104_Operator_1     T-26-0104_Operator_1   T-26-0104
#> T-26-0104_Operator_2     T-26-0104_Operator_2   T-26-0104
#> T-26-0107_Operator_1     T-26-0107_Operator_1   T-26-0107
#> T-26-0107_Operator_2     T-26-0107_Operator_2   T-26-0107
#> T-26-0108_Operator_1     T-26-0108_Operator_1   T-26-0108
#> T-26-0108_Operator_2     T-26-0108_Operator_2   T-26-0108
#> T-26-0109_Operator_1     T-26-0109_Operator_1   T-26-0109
#> T-26-0109_Operator_2     T-26-0109_Operator_2   T-26-0109
#> T-26-0111_Operator_1     T-26-0111_Operator_1   T-26-0111
#> T-26-0111_Operator_2     T-26-0111_Operator_2   T-26-0111
#> T-26-0112-2_Operator_1 T-26-0112-2_Operator_1 T-26-0112-2
#> T-26-0112-2_Operator_2 T-26-0112-2_Operator_2 T-26-0112-2
#> T-26-0112_Operator_1     T-26-0112_Operator_1   T-26-0112
#> T-26-0112_Operator_2     T-26-0112_Operator_2   T-26-0112
#> T-26-0113_Operator_1     T-26-0113_Operator_1   T-26-0113
#> T-26-0113_Operator_2     T-26-0113_Operator_2   T-26-0113
#> T-26-0114_Operator_1     T-26-0114_Operator_1   T-26-0114
#> T-26-0114_Operator_2     T-26-0114_Operator_2   T-26-0114
#> T-26-0115_Operator_1     T-26-0115_Operator_1   T-26-0115
#> T-26-0115_Operator_2     T-26-0115_Operator_2   T-26-0115
#> T-26-0116_Operator_1     T-26-0116_Operator_1   T-26-0116
#> T-26-0116_Operator_2     T-26-0116_Operator_2   T-26-0116
#> T-26-0117_Operator_1     T-26-0117_Operator_1   T-26-0117
#> T-26-0117_Operator_2     T-26-0117_Operator_2   T-26-0117
#> T-26-0118_Operator_1     T-26-0118_Operator_1   T-26-0118
#> T-26-0118_Operator_2     T-26-0118_Operator_2   T-26-0118
#> T-26-0120_Operator_1     T-26-0120_Operator_1   T-26-0120
#> T-26-0120_Operator_2     T-26-0120_Operator_2   T-26-0120
#> T-26-0121_Operator_1     T-26-0121_Operator_1   T-26-0121
#> T-26-0121_Operator_2     T-26-0121_Operator_2   T-26-0121
#> T-26-0122_Operator_1     T-26-0122_Operator_1   T-26-0122
#> T-26-0122_Operator_2     T-26-0122_Operator_2   T-26-0122
#> T-26-0123_Operator_1     T-26-0123_Operator_1   T-26-0123
#> T-26-0123_Operator_2     T-26-0123_Operator_2   T-26-0123
#> T-26-0125_Operator_1     T-26-0125_Operator_1   T-26-0125
#> T-26-0125_Operator_2     T-26-0125_Operator_2   T-26-0125
#> T-26-0126_Operator_1     T-26-0126_Operator_1   T-26-0126
#> T-26-0126_Operator_2     T-26-0126_Operator_2   T-26-0126
#> T-26-0127_Operator_1     T-26-0127_Operator_1   T-26-0127
#> T-26-0127_Operator_2     T-26-0127_Operator_2   T-26-0127
#> T-26-0128_Operator_1     T-26-0128_Operator_1   T-26-0128
#> T-26-0128_Operator_2     T-26-0128_Operator_2   T-26-0128
#> T-26-0130_Operator_1     T-26-0130_Operator_1   T-26-0130
#> T-26-0130_Operator_2     T-26-0130_Operator_2   T-26-0130
#> T-26-0131_Operator_1     T-26-0131_Operator_1   T-26-0131
#> T-26-0131_Operator_2     T-26-0131_Operator_2   T-26-0131
#> T-26-0132_Operator_1     T-26-0132_Operator_1   T-26-0132
#> T-26-0132_Operator_2     T-26-0132_Operator_2   T-26-0132
#> T-26-0133_Operator_1     T-26-0133_Operator_1   T-26-0133
#> T-26-0133_Operator_2     T-26-0133_Operator_2   T-26-0133
#> T-26-0134_Operator_1     T-26-0134_Operator_1   T-26-0134
#> T-26-0134_Operator_2     T-26-0134_Operator_2   T-26-0134
#> T-26-0135_Operator_1     T-26-0135_Operator_1   T-26-0135
#> T-26-0135_Operator_2     T-26-0135_Operator_2   T-26-0135
#> T-26-0136_Operator_1     T-26-0136_Operator_1   T-26-0136
#> T-26-0136_Operator_2     T-26-0136_Operator_2   T-26-0136
#> T-26-0137_Operator_1     T-26-0137_Operator_1   T-26-0137
#> T-26-0137_Operator_2     T-26-0137_Operator_2   T-26-0137
#> T-26-0138_Operator_1     T-26-0138_Operator_1   T-26-0138
#> T-26-0138_Operator_2     T-26-0138_Operator_2   T-26-0138
#> T-26-0139_Operator_1     T-26-0139_Operator_1   T-26-0139
#> T-26-0139_Operator_2     T-26-0139_Operator_2   T-26-0139
#> T-26-0140_Operator_1     T-26-0140_Operator_1   T-26-0140
#> T-26-0140_Operator_2     T-26-0140_Operator_2   T-26-0140
#> T-26-0141_Operator_1     T-26-0141_Operator_1   T-26-0141
#> T-26-0141_Operator_2     T-26-0141_Operator_2   T-26-0141
#> T-26-0142_Operator_1     T-26-0142_Operator_1   T-26-0142
#> T-26-0142_Operator_2     T-26-0142_Operator_2   T-26-0142
#> T-26-0143_Operator_1     T-26-0143_Operator_1   T-26-0143
#> T-26-0143_Operator_2     T-26-0143_Operator_2   T-26-0143
#> T-26-0144_Operator_1     T-26-0144_Operator_1   T-26-0144
#> T-26-0144_Operator_2     T-26-0144_Operator_2   T-26-0144
#> T-26-0145_Operator_1     T-26-0145_Operator_1   T-26-0145
#> T-26-0145_Operator_2     T-26-0145_Operator_2   T-26-0145
#> T-26-0146_Operator_1     T-26-0146_Operator_1   T-26-0146
#> T-26-0146_Operator_2     T-26-0146_Operator_2   T-26-0146
#> T-26-0147_Operator_1     T-26-0147_Operator_1   T-26-0147
#> T-26-0147_Operator_2     T-26-0147_Operator_2   T-26-0147
#> T-26-0148_Operator_1     T-26-0148_Operator_1   T-26-0148
#> T-26-0148_Operator_2     T-26-0148_Operator_2   T-26-0148
#> T-26-0149_Operator_1     T-26-0149_Operator_1   T-26-0149
#> T-26-0149_Operator_2     T-26-0149_Operator_2   T-26-0149
#> T-26-0150_Operator_1     T-26-0150_Operator_1   T-26-0150
#> T-26-0150_Operator_2     T-26-0150_Operator_2   T-26-0150
#> T-26-0151_Operator_1     T-26-0151_Operator_1   T-26-0151
#> T-26-0151_Operator_2     T-26-0151_Operator_2   T-26-0151
#> T-26-0152_Operator_1     T-26-0152_Operator_1   T-26-0152
#> T-26-0152_Operator_2     T-26-0152_Operator_2   T-26-0152
#> T-26-0153_Operator_1     T-26-0153_Operator_1   T-26-0153
#> T-26-0153_Operator_2     T-26-0153_Operator_2   T-26-0153
#> T-26-0154_Operator_1     T-26-0154_Operator_1   T-26-0154
#> T-26-0154_Operator_2     T-26-0154_Operator_2   T-26-0154
#> T-26-0155_Operator_1     T-26-0155_Operator_1   T-26-0155
#> T-26-0155_Operator_2     T-26-0155_Operator_2   T-26-0155
#> T-26-0156_Operator_1     T-26-0156_Operator_1   T-26-0156
#> T-26-0156_Operator_2     T-26-0156_Operator_2   T-26-0156
#> T-26-0157_Operator_1     T-26-0157_Operator_1   T-26-0157
#> T-26-0157_Operator_2     T-26-0157_Operator_2   T-26-0157
#> T-26-0158_Operator_1     T-26-0158_Operator_1   T-26-0158
#> T-26-0158_Operator_2     T-26-0158_Operator_2   T-26-0158
#> T-26-0159_Operator_1     T-26-0159_Operator_1   T-26-0159
#> T-26-0159_Operator_2     T-26-0159_Operator_2   T-26-0159
#> T-26-0160_Operator_1     T-26-0160_Operator_1   T-26-0160
#> T-26-0160_Operator_2     T-26-0160_Operator_2   T-26-0160
#> T-26-0161_Operator_1     T-26-0161_Operator_1   T-26-0161
#> T-26-0161_Operator_2     T-26-0161_Operator_2   T-26-0161
#> T-26-0162_Operator_1     T-26-0162_Operator_1   T-26-0162
#> T-26-0162_Operator_2     T-26-0162_Operator_2   T-26-0162
#> T-26-0163_Operator_1     T-26-0163_Operator_1   T-26-0163
#> T-26-0163_Operator_2     T-26-0163_Operator_2   T-26-0163
#> T-26-0164_Operator_1     T-26-0164_Operator_1   T-26-0164
#> T-26-0164_Operator_2     T-26-0164_Operator_2   T-26-0164
#> T-26-0165_Operator_1     T-26-0165_Operator_1   T-26-0165
#> T-26-0165_Operator_2     T-26-0165_Operator_2   T-26-0165
#> T-26-0166_Operator_1     T-26-0166_Operator_1   T-26-0166
#> T-26-0166_Operator_2     T-26-0166_Operator_2   T-26-0166
#> T-26-0167_Operator_1     T-26-0167_Operator_1   T-26-0167
#> T-26-0167_Operator_2     T-26-0167_Operator_2   T-26-0167
#> T-26-0168_Operator_1     T-26-0168_Operator_1   T-26-0168
#> T-26-0168_Operator_2     T-26-0168_Operator_2   T-26-0168
#> T-26-0169_Operator_1     T-26-0169_Operator_1   T-26-0169
#> T-26-0169_Operator_2     T-26-0169_Operator_2   T-26-0169
#> T-26-0170_Operator_1     T-26-0170_Operator_1   T-26-0170
#> T-26-0170_Operator_2     T-26-0170_Operator_2   T-26-0170
#> T-26-0171_Operator_1     T-26-0171_Operator_1   T-26-0171
#> T-26-0171_Operator_2     T-26-0171_Operator_2   T-26-0171
#> T-26-0172_Operator_1     T-26-0172_Operator_1   T-26-0172
#> T-26-0172_Operator_2     T-26-0172_Operator_2   T-26-0172
#> T-26-0173_Operator_1     T-26-0173_Operator_1   T-26-0173
#> T-26-0173_Operator_2     T-26-0173_Operator_2   T-26-0173
#> T-26-0174_Operator_1     T-26-0174_Operator_1   T-26-0174
#> T-26-0174_Operator_2     T-26-0174_Operator_2   T-26-0174
#> T-26-0175_Operator_1     T-26-0175_Operator_1   T-26-0175
#> T-26-0175_Operator_2     T-26-0175_Operator_2   T-26-0175
#> T-26-0176_Operator_1     T-26-0176_Operator_1   T-26-0176
#> T-26-0176_Operator_2     T-26-0176_Operator_2   T-26-0176
#> T-26-0177_Operator_1     T-26-0177_Operator_1   T-26-0177
#> T-26-0177_Operator_2     T-26-0177_Operator_2   T-26-0177
#> T-26-0178_Operator_1     T-26-0178_Operator_1   T-26-0178
#> T-26-0178_Operator_2     T-26-0178_Operator_2   T-26-0178
#> T-26-0179-3_Operator_1 T-26-0179-3_Operator_1 T-26-0179-3
#> T-26-0179-3_Operator_2 T-26-0179-3_Operator_2 T-26-0179-3
#> T-26-0179_Operator_1     T-26-0179_Operator_1   T-26-0179
#> T-26-0179_Operator_2     T-26-0179_Operator_2   T-26-0179
#> T-26-0180_Operator_1     T-26-0180_Operator_1   T-26-0180
#> T-26-0180_Operator_2     T-26-0180_Operator_2   T-26-0180
#> T-26-0181_Operator_1     T-26-0181_Operator_1   T-26-0181
#> T-26-0181_Operator_2     T-26-0181_Operator_2   T-26-0181
#> T-26-0182_Operator_1     T-26-0182_Operator_1   T-26-0182
#> T-26-0182_Operator_2     T-26-0182_Operator_2   T-26-0182
#> T-26-0183_Operator_1     T-26-0183_Operator_1   T-26-0183
#> T-26-0183_Operator_2     T-26-0183_Operator_2   T-26-0183
#> T-26-0184_Operator_1     T-26-0184_Operator_1   T-26-0184
#> T-26-0184_Operator_2     T-26-0184_Operator_2   T-26-0184
#> T-26-0185_Operator_1     T-26-0185_Operator_1   T-26-0185
#> T-26-0185_Operator_2     T-26-0185_Operator_2   T-26-0185
#> T-26-0186_Operator_1     T-26-0186_Operator_1   T-26-0186
#> T-26-0186_Operator_2     T-26-0186_Operator_2   T-26-0186
#> T-26-0187_Operator_1     T-26-0187_Operator_1   T-26-0187
#> T-26-0187_Operator_2     T-26-0187_Operator_2   T-26-0187
#> T-26-0188_Operator_1     T-26-0188_Operator_1   T-26-0188
#> T-26-0188_Operator_2     T-26-0188_Operator_2   T-26-0188
#> T-26-0189_Operator_1     T-26-0189_Operator_1   T-26-0189
#> T-26-0189_Operator_2     T-26-0189_Operator_2   T-26-0189
#> T-26-0190_Operator_1     T-26-0190_Operator_1   T-26-0190
#> T-26-0190_Operator_2     T-26-0190_Operator_2   T-26-0190
#> T-26-0191_Operator_1     T-26-0191_Operator_1   T-26-0191
#> T-26-0191_Operator_2     T-26-0191_Operator_2   T-26-0191
#> T-26-0192_Operator_1     T-26-0192_Operator_1   T-26-0192
#> T-26-0192_Operator_2     T-26-0192_Operator_2   T-26-0192
#> T-26-0193_Operator_1     T-26-0193_Operator_1   T-26-0193
#> T-26-0193_Operator_2     T-26-0193_Operator_2   T-26-0193
#> T-26-0194_Operator_1     T-26-0194_Operator_1   T-26-0194
#> T-26-0194_Operator_2     T-26-0194_Operator_2   T-26-0194
#> T-26-0195_Operator_1     T-26-0195_Operator_1   T-26-0195
#> T-26-0195_Operator_2     T-26-0195_Operator_2   T-26-0195
#> T-26-0196_Operator_1     T-26-0196_Operator_1   T-26-0196
#> T-26-0196_Operator_2     T-26-0196_Operator_2   T-26-0196
#> T-26-0197_Operator_1     T-26-0197_Operator_1   T-26-0197
#> T-26-0197_Operator_2     T-26-0197_Operator_2   T-26-0197
#> T-26-0198_Operator_1     T-26-0198_Operator_1   T-26-0198
#> T-26-0198_Operator_2     T-26-0198_Operator_2   T-26-0198
#> T-26-0199_Operator_1     T-26-0199_Operator_1   T-26-0199
#> T-26-0199_Operator_2     T-26-0199_Operator_2   T-26-0199
#> T-26-0200_Operator_1     T-26-0200_Operator_1   T-26-0200
#> T-26-0200_Operator_2     T-26-0200_Operator_2   T-26-0200
#> T-26-0201_Operator_1     T-26-0201_Operator_1   T-26-0201
#> T-26-0201_Operator_2     T-26-0201_Operator_2   T-26-0201
#> T-26-0202_Operator_1     T-26-0202_Operator_1   T-26-0202
#> T-26-0202_Operator_2     T-26-0202_Operator_2   T-26-0202
#> T-26-0203_Operator_1     T-26-0203_Operator_1   T-26-0203
#> T-26-0203_Operator_2     T-26-0203_Operator_2   T-26-0203
#> T-26-0204_Operator_1     T-26-0204_Operator_1   T-26-0204
#> T-26-0204_Operator_2     T-26-0204_Operator_2   T-26-0204
#> T-26-0205_Operator_1     T-26-0205_Operator_1   T-26-0205
#> T-26-0205_Operator_2     T-26-0205_Operator_2   T-26-0205
#> T-26-0206_Operator_1     T-26-0206_Operator_1   T-26-0206
#> T-26-0206_Operator_2     T-26-0206_Operator_2   T-26-0206
#> T-26-0207_Operator_1     T-26-0207_Operator_1   T-26-0207
#> T-26-0207_Operator_2     T-26-0207_Operator_2   T-26-0207
#> T-26-0208_Operator_1     T-26-0208_Operator_1   T-26-0208
#> T-26-0208_Operator_2     T-26-0208_Operator_2   T-26-0208
#> T-26-0209_Operator_1     T-26-0209_Operator_1   T-26-0209
#> T-26-0209_Operator_2     T-26-0209_Operator_2   T-26-0209
#> T-26-0210_Operator_1     T-26-0210_Operator_1   T-26-0210
#> T-26-0210_Operator_2     T-26-0210_Operator_2   T-26-0210
#> T-26-0211_Operator_1     T-26-0211_Operator_1   T-26-0211
#> T-26-0211_Operator_2     T-26-0211_Operator_2   T-26-0211
#> T-26-0212_Operator_1     T-26-0212_Operator_1   T-26-0212
#> T-26-0212_Operator_2     T-26-0212_Operator_2   T-26-0212
#> T-26-0213_Operator_1     T-26-0213_Operator_1   T-26-0213
#> T-26-0213_Operator_2     T-26-0213_Operator_2   T-26-0213
#> T-26-0214_Operator_1     T-26-0214_Operator_1   T-26-0214
#> T-26-0214_Operator_2     T-26-0214_Operator_2   T-26-0214
#> T-26-0215_Operator_1     T-26-0215_Operator_1   T-26-0215
#> T-26-0215_Operator_2     T-26-0215_Operator_2   T-26-0215
#> T-26-0216_Operator_1     T-26-0216_Operator_1   T-26-0216
#> T-26-0216_Operator_2     T-26-0216_Operator_2   T-26-0216
#> T-26-0217_Operator_1     T-26-0217_Operator_1   T-26-0217
#> T-26-0217_Operator_2     T-26-0217_Operator_2   T-26-0217
#> T-26-0218_Operator_1     T-26-0218_Operator_1   T-26-0218
#> T-26-0218_Operator_2     T-26-0218_Operator_2   T-26-0218
#> T-26-0219_Operator_1     T-26-0219_Operator_1   T-26-0219
#> T-26-0219_Operator_2     T-26-0219_Operator_2   T-26-0219
#> T-26-0220_Operator_1     T-26-0220_Operator_1   T-26-0220
#> T-26-0220_Operator_2     T-26-0220_Operator_2   T-26-0220
#> T-26-0221_Operator_1     T-26-0221_Operator_1   T-26-0221
#> T-26-0221_Operator_2     T-26-0221_Operator_2   T-26-0221
#> T-26-0222_Operator_1     T-26-0222_Operator_1   T-26-0222
#> T-26-0222_Operator_2     T-26-0222_Operator_2   T-26-0222
#> T-26-0223_Operator_1     T-26-0223_Operator_1   T-26-0223
#> T-26-0223_Operator_2     T-26-0223_Operator_2   T-26-0223
#> T-26-0224_Operator_1     T-26-0224_Operator_1   T-26-0224
#> T-26-0224_Operator_2     T-26-0224_Operator_2   T-26-0224
#> T-26-0225_Operator_1     T-26-0225_Operator_1   T-26-0225
#> T-26-0225_Operator_2     T-26-0225_Operator_2   T-26-0225
#> T-26-0226_Operator_1     T-26-0226_Operator_1   T-26-0226
#> T-26-0226_Operator_2     T-26-0226_Operator_2   T-26-0226
#> T-26-0227_Operator_1     T-26-0227_Operator_1   T-26-0227
#> T-26-0227_Operator_2     T-26-0227_Operator_2   T-26-0227
#> T-26-0228_Operator_1     T-26-0228_Operator_1   T-26-0228
#> T-26-0228_Operator_2     T-26-0228_Operator_2   T-26-0228
#> T-26-0229_Operator_1     T-26-0229_Operator_1   T-26-0229
#> T-26-0229_Operator_2     T-26-0229_Operator_2   T-26-0229
#> T-26-0230-1_Operator_1 T-26-0230-1_Operator_1 T-26-0230-1
#> T-26-0230-1_Operator_2 T-26-0230-1_Operator_2 T-26-0230-1
#> T-26-0230-2_Operator_1 T-26-0230-2_Operator_1 T-26-0230-2
#> T-26-0230-2_Operator_2 T-26-0230-2_Operator_2 T-26-0230-2
#> T-26-0230-3_Operator_1 T-26-0230-3_Operator_1 T-26-0230-3
#> T-26-0230-3_Operator_2 T-26-0230-3_Operator_2 T-26-0230-3
#> T-26-0230-4_Operator_1 T-26-0230-4_Operator_1 T-26-0230-4
#> T-26-0230-4_Operator_2 T-26-0230-4_Operator_2 T-26-0230-4
#> T-26-0231_Operator_1     T-26-0231_Operator_1   T-26-0231
#> T-26-0231_Operator_2     T-26-0231_Operator_2   T-26-0231
#> T-26-0232_Operator_1     T-26-0232_Operator_1   T-26-0232
#> T-26-0232_Operator_2     T-26-0232_Operator_2   T-26-0232
#> T-26-0233_Operator_1     T-26-0233_Operator_1   T-26-0233
#> T-26-0233_Operator_2     T-26-0233_Operator_2   T-26-0233
#> T-26-0234_Operator_1     T-26-0234_Operator_1   T-26-0234
#> T-26-0234_Operator_2     T-26-0234_Operator_2   T-26-0234
#> T-26-0235_Operator_1     T-26-0235_Operator_1   T-26-0235
#> T-26-0235_Operator_2     T-26-0235_Operator_2   T-26-0235
#> T-26-0236_Operator_1     T-26-0236_Operator_1   T-26-0236
#> T-26-0236_Operator_2     T-26-0236_Operator_2   T-26-0236
#> T-26-0237_Operator_1     T-26-0237_Operator_1   T-26-0237
#> T-26-0237_Operator_2     T-26-0237_Operator_2   T-26-0237
#> T-26-0238_Operator_1     T-26-0238_Operator_1   T-26-0238
#> T-26-0238_Operator_2     T-26-0238_Operator_2   T-26-0238
#> T-26-0239_Operator_1     T-26-0239_Operator_1   T-26-0239
#> T-26-0239_Operator_2     T-26-0239_Operator_2   T-26-0239
#> T-26-0240_Operator_1     T-26-0240_Operator_1   T-26-0240
#> T-26-0240_Operator_2     T-26-0240_Operator_2   T-26-0240
#> T-26-0241_Operator_1     T-26-0241_Operator_1   T-26-0241
#> T-26-0241_Operator_2     T-26-0241_Operator_2   T-26-0241
#> T-26-0242_Operator_1     T-26-0242_Operator_1   T-26-0242
#> T-26-0242_Operator_2     T-26-0242_Operator_2   T-26-0242
#> T-26-0243_Operator_1     T-26-0243_Operator_1   T-26-0243
#> T-26-0243_Operator_2     T-26-0243_Operator_2   T-26-0243
#> T-26-0244_Operator_1     T-26-0244_Operator_1   T-26-0244
#> T-26-0244_Operator_2     T-26-0244_Operator_2   T-26-0244
#> T-26-0245_Operator_1     T-26-0245_Operator_1   T-26-0245
#> T-26-0245_Operator_2     T-26-0245_Operator_2   T-26-0245
#> T-26-0246_Operator_1     T-26-0246_Operator_1   T-26-0246
#> T-26-0246_Operator_2     T-26-0246_Operator_2   T-26-0246
#> T-26-0247_Operator_1     T-26-0247_Operator_1   T-26-0247
#> T-26-0247_Operator_2     T-26-0247_Operator_2   T-26-0247
#> T-26-0248_Operator_1     T-26-0248_Operator_1   T-26-0248
#> T-26-0248_Operator_2     T-26-0248_Operator_2   T-26-0248
#> T-26-0249_Operator_1     T-26-0249_Operator_1   T-26-0249
#> T-26-0249_Operator_2     T-26-0249_Operator_2   T-26-0249
#> T-26-0250_Operator_1     T-26-0250_Operator_1   T-26-0250
#> T-26-0250_Operator_2     T-26-0250_Operator_2   T-26-0250
#> T-26-0251_Operator_1     T-26-0251_Operator_1   T-26-0251
#> T-26-0251_Operator_2     T-26-0251_Operator_2   T-26-0251
#> T-26-0252_Operator_1     T-26-0252_Operator_1   T-26-0252
#> T-26-0252_Operator_2     T-26-0252_Operator_2   T-26-0252
#> T-26-0261-1_Operator_1 T-26-0261-1_Operator_1 T-26-0261-1
#> T-26-0261-1_Operator_2 T-26-0261-1_Operator_2 T-26-0261-1
#> T-26-0261-2_Operator_1 T-26-0261-2_Operator_1 T-26-0261-2
#> T-26-0261-2_Operator_2 T-26-0261-2_Operator_2 T-26-0261-2
#> T-26-0261-3_Operator_1 T-26-0261-3_Operator_1 T-26-0261-3
#> T-26-0261-3_Operator_2 T-26-0261-3_Operator_2 T-26-0261-3
#> T-26-0261-4_Operator_1 T-26-0261-4_Operator_1 T-26-0261-4
#> T-26-0261-4_Operator_2 T-26-0261-4_Operator_2 T-26-0261-4
#> T-26-0261-5_Operator_1 T-26-0261-5_Operator_1 T-26-0261-5
#> T-26-0261-5_Operator_2 T-26-0261-5_Operator_2 T-26-0261-5
#> T-26-0262-1_Operator_1 T-26-0262-1_Operator_1 T-26-0262-1
#> T-26-0262-1_Operator_2 T-26-0262-1_Operator_2 T-26-0262-1
#> T-26-0262-2_Operator_1 T-26-0262-2_Operator_1 T-26-0262-2
#> T-26-0262-2_Operator_2 T-26-0262-2_Operator_2 T-26-0262-2
#> T-26-0263_Operator_1     T-26-0263_Operator_1   T-26-0263
#> T-26-0263_Operator_2     T-26-0263_Operator_2   T-26-0263
#> T-26-0264-1_Operator_1 T-26-0264-1_Operator_1 T-26-0264-1
#> T-26-0264-1_Operator_2 T-26-0264-1_Operator_2 T-26-0264-1
#> T-26-0264-2_Operator_1 T-26-0264-2_Operator_1 T-26-0264-2
#> T-26-0264-2_Operator_2 T-26-0264-2_Operator_2 T-26-0264-2
#> T-26-0264-3_Operator_1 T-26-0264-3_Operator_1 T-26-0264-3
#> T-26-0264-3_Operator_2 T-26-0264-3_Operator_2 T-26-0264-3
#> T-26-0264-4_Operator_1 T-26-0264-4_Operator_1 T-26-0264-4
#> T-26-0264-4_Operator_2 T-26-0264-4_Operator_2 T-26-0264-4
#> T-26-0265_Operator_1     T-26-0265_Operator_1   T-26-0265
#> T-26-0265_Operator_2     T-26-0265_Operator_2   T-26-0265
#> T-26-0266_Operator_1     T-26-0266_Operator_1   T-26-0266
#> T-26-0266_Operator_2     T-26-0266_Operator_2   T-26-0266
#> T-26-0267_Operator_1     T-26-0267_Operator_1   T-26-0267
#> T-26-0267_Operator_2     T-26-0267_Operator_2   T-26-0267
#> T-26-0268_Operator_1     T-26-0268_Operator_1   T-26-0268
#> T-26-0268_Operator_2     T-26-0268_Operator_2   T-26-0268
#> T-26-0269_Operator_1     T-26-0269_Operator_1   T-26-0269
#> T-26-0269_Operator_2     T-26-0269_Operator_2   T-26-0269
#> T-26-0270-1_Operator_1 T-26-0270-1_Operator_1 T-26-0270-1
#> T-26-0270-1_Operator_2 T-26-0270-1_Operator_2 T-26-0270-1
#> T-26-0270-2_Operator_1 T-26-0270-2_Operator_1 T-26-0270-2
#> T-26-0270-2_Operator_2 T-26-0270-2_Operator_2 T-26-0270-2
#> T-26-0271_Operator_1     T-26-0271_Operator_1   T-26-0271
#> T-26-0271_Operator_2     T-26-0271_Operator_2   T-26-0271
#> T-26-0272_Operator_1     T-26-0272_Operator_1   T-26-0272
#> T-26-0272_Operator_2     T-26-0272_Operator_2   T-26-0272
#> T-26-0273_Operator_1     T-26-0273_Operator_1   T-26-0273
#> T-26-0273_Operator_2     T-26-0273_Operator_2   T-26-0273
#> T-26-0274_Operator_1     T-26-0274_Operator_1   T-26-0274
#> T-26-0274_Operator_2     T-26-0274_Operator_2   T-26-0274
#> T-26-0275_Operator_1     T-26-0275_Operator_1   T-26-0275
#> T-26-0275_Operator_2     T-26-0275_Operator_2   T-26-0275
#> T-26-0276_Operator_1     T-26-0276_Operator_1   T-26-0276
#> T-26-0276_Operator_2     T-26-0276_Operator_2   T-26-0276
#> T-26-0277_Operator_1     T-26-0277_Operator_1   T-26-0277
#> T-26-0277_Operator_2     T-26-0277_Operator_2   T-26-0277
#> T-26-0278-1_Operator_1 T-26-0278-1_Operator_1 T-26-0278-1
#> T-26-0278-1_Operator_2 T-26-0278-1_Operator_2 T-26-0278-1
#> T-26-0278-2_Operator_1 T-26-0278-2_Operator_1 T-26-0278-2
#> T-26-0278-2_Operator_2 T-26-0278-2_Operator_2 T-26-0278-2
#> T-26-0279_Operator_1     T-26-0279_Operator_1   T-26-0279
#> T-26-0279_Operator_2     T-26-0279_Operator_2   T-26-0279
#>                                          species population replicate
#> T-26-0001_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0001_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0002_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0002_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0003_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0003_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0004_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0004_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0005_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0005_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0006_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0006_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0007_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0007_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0008_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0008_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0009_Operator_1            Lepomis gibbosus       <NA>         1
#> T-26-0009_Operator_2            Lepomis gibbosus       <NA>         2
#> T-26-0010_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0010_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0011_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0011_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0012_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0012_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0013_Operator_1               Barbus barbus       <NA>         1
#> T-26-0013_Operator_2               Barbus barbus       <NA>         2
#> T-26-0014_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0014_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0015_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0015_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0016_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0016_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0017_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0017_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0018_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0018_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0019_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0019_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0020_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0020_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0021_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0021_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0022_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0022_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0023-2_Operator_1         Phoxinus phoxinus       <NA>         1
#> T-26-0023-2_Operator_2         Phoxinus phoxinus       <NA>         2
#> T-26-0024_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0024_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0025_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0025_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0026_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0026_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0027_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0027_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0028_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0028_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0029_Operator_1            Lepomis gibbosus       <NA>         1
#> T-26-0029_Operator_2            Lepomis gibbosus       <NA>         2
#> T-26-0030_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0030_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0031_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0031_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0032_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0032_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0033_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0033_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0034_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0034_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0035_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0035_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0036_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0036_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0037_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0037_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0038_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0038_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0039_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0039_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0040_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0040_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0041_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0041_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0042_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0042_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0043_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0043_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0044_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0044_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0045_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0045_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0046_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0046_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0047_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0047_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0048_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0048_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0049_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0049_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0050_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0050_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0051_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0051_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0052_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0052_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0053_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0053_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0054_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0054_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0055_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0055_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0056-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0056-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0057_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0057_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0058_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0058_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0059_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0059_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0060_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0060_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0061_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0061_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0062_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0062_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0063_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0063_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0064_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0064_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0065_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0065_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0067_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0067_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0068_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0068_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0069_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0069_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0070_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0070_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0071_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0071_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0072_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0072_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0073_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0073_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0074_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0074_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0075_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0075_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0076_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0076_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0077_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0077_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0078_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0078_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0079_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0079_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0080_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0080_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0081_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0081_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0082_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0082_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0083_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0083_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0084_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0084_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0085_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0085_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0086_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0086_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0087_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0087_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0088_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0088_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0089_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0089_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0090_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0090_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0091_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0091_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0092_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0092_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0093_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0093_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0094_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0094_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0095_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0095_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0096_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0096_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0097_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0097_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0098_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0098_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0099_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0099_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0100_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0100_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0101_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0101_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0102_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0102_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0103_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0103_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0104_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0104_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0107_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0107_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0108_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0108_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0109_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0109_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0111_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0111_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0112-2_Operator_1 Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0112-2_Operator_2 Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0112_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0112_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0113_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0113_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0114_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0114_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0115_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0115_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0116_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0116_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0117_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0117_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0118_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0118_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0120_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0120_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0121_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0121_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0122_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0122_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0123_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0123_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0125_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0125_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0126_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0126_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0127_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0127_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0128_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0128_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0130_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0130_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0131_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0131_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0132_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0132_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0133_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0133_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0134_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0134_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0135_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0135_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0136_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0136_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0137_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0137_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0138_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0138_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0139_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0139_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0140_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0140_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0141_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0141_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0142_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0142_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0143_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0143_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0144_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0144_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0145_Operator_1                                   <NA>         1
#> T-26-0145_Operator_2                                   <NA>         2
#> T-26-0146_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0146_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0147_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0147_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0148_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0148_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0149_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0149_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0150_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0150_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0151_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0151_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0152_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0152_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0153_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0153_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0154_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0154_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0155_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0155_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0156_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0156_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0157_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0157_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0158_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0158_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0159_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0159_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0160_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0160_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0161_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0161_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0162_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0162_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0163_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0163_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0164_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0164_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0165_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0165_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0166_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0166_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0167_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0167_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0168_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0168_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0169_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0169_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0170_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0170_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0171_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0171_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0172_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0172_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0173_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0173_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0174_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0174_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0175_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0175_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0176_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0176_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0177_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0177_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0178_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0178_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0179-3_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0179-3_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0179_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0179_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0180_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0180_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0181_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0181_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0182_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0182_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0183_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0183_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0184_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0184_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0185_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0185_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0186_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0186_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0187_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0187_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0188_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0188_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0189_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0189_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0190_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0190_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0191_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0191_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0192_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0192_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0193_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0193_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0194_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0194_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0195_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0195_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0196_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0196_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0197_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0197_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0198_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0198_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0199_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0199_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0200_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0200_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0201_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0201_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0202_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0202_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0203_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0203_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0204_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0204_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0205_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0205_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0206_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0206_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0207_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0207_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0208_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0208_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0209_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0209_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0210_Operator_1               Barbus barbus       <NA>         1
#> T-26-0210_Operator_2               Barbus barbus       <NA>         2
#> T-26-0211_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0211_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0212_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0212_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0213_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0213_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0214_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0214_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0215_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0215_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0216_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0216_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0217_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0217_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0218_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0218_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0219_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0219_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0220_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0220_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0221_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0221_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0222_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0222_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0223_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0223_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0224_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0224_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0225_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0225_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0226_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0226_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0227_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0227_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0228_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0228_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0229_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0229_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0230-1_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-1_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-2_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-2_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-3_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-3_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-4_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-4_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0231_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0231_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0232_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0232_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0233_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0233_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0234_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0234_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0235_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0235_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0236_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0236_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0237_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0237_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0238_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0238_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0239_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0239_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0240_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0240_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0241_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0241_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0242_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0242_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0243_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0243_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0244_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0244_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0245_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0245_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0246_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0246_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0247_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0247_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0248_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0248_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0249_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0249_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0250_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0250_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0251_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0251_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0252_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0252_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0261-1_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-1_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-3_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-3_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-4_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-4_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-5_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-5_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0262-1_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0262-1_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0262-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0262-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0263_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0263_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0264-1_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-1_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-2_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-2_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-3_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-3_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-4_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0264-4_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0265_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0265_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0266_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0266_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0267_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0267_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0268_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0268_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0269_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0269_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0270-1_Operator_1         Squalius cephalus       <NA>         1
#> T-26-0270-1_Operator_2         Squalius cephalus       <NA>         2
#> T-26-0270-2_Operator_1         Squalius cephalus       <NA>         1
#> T-26-0270-2_Operator_2         Squalius cephalus       <NA>         2
#> T-26-0271_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0271_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0272_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0272_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0273_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0273_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0274_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0274_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0275_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0275_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0276_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0276_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0277_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0277_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0278-1_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0278-1_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0278-2_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0278-2_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0279_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0279_Operator_2         Barbatula barbatula       <NA>         2
#>                          operator        Bl         Bd          Hd          Eh
#> T-26-0001_Operator_1   Operator_1  6.956905  1.8123997  1.18095345  1.34404475
#> T-26-0001_Operator_2   Operator_2  6.909410  1.7949041  1.18095345  1.36365235
#> T-26-0002_Operator_1   Operator_1  8.302798  1.9909529  1.18095345  1.52249892
#> T-26-0002_Operator_2   Operator_2  8.216624  2.0207893  1.18095345  1.53560616
#> T-26-0003_Operator_1   Operator_1  6.967443  1.6928692  1.18095345  1.21165768
#> T-26-0003_Operator_2   Operator_2  6.913182  1.7159790  1.18095345  1.16657065
#> T-26-0004_Operator_1   Operator_1 18.176255  4.5559409  2.07742509  2.77003273
#> T-26-0004_Operator_2   Operator_2 17.783260  4.5636753  2.03145378  2.77399122
#> T-26-0005_Operator_1   Operator_1  5.596071  1.2880802  1.18095345  1.05787210
#> T-26-0005_Operator_2   Operator_2  6.332844  1.2700604  1.18095345  1.09361071
#> T-26-0006_Operator_1   Operator_1  7.668080  1.8662513  1.18095345  1.30295851
#> T-26-0006_Operator_2   Operator_2  7.712358  1.9168742  1.18095345  1.32881958
#> T-26-0007_Operator_1   Operator_1 17.379257  4.7743456  2.17509366  2.97608629
#> T-26-0007_Operator_2   Operator_2 17.574467  4.9769778  2.19813968  3.10917326
#> T-26-0008_Operator_1   Operator_1 14.181427  3.6643534  1.71913958  2.69166771
#> T-26-0008_Operator_2   Operator_2 13.996664  3.8567416  1.70080238  2.59696033
#> T-26-0009_Operator_1   Operator_1  5.642172  2.3754338  1.20142779  1.42326286
#> T-26-0009_Operator_2   Operator_2  5.510208  2.3900134  1.19458556  1.47378738
#> T-26-0010_Operator_1   Operator_1  8.594692  2.2922567  1.18095345  1.83231627
#> T-26-0010_Operator_2   Operator_2  8.468550  2.2858828  2.03327424  1.82503963
#> T-26-0011_Operator_1   Operator_1 25.392853  6.8890836  1.81189442  5.30891678
#> T-26-0011_Operator_2   Operator_2 25.140844  7.3332416  5.68314347  5.47275133
#> T-26-0012_Operator_1   Operator_1  6.184369  1.4550365  1.18095345  1.03884218
#> T-26-0012_Operator_2   Operator_2  6.141980  1.4850224  2.04434357  1.09392491
#> T-26-0013_Operator_1   Operator_1  8.109554  1.9417022  0.62167101  1.27322269
#> T-26-0013_Operator_2   Operator_2  8.220899  1.9820605  0.62167101  1.33120290
#> T-26-0014_Operator_1   Operator_1  8.493603  2.1291592  1.18095345  1.70885906
#> T-26-0014_Operator_2   Operator_2  8.214899  2.1427808  1.18095345  1.75136827
#> T-26-0015_Operator_1   Operator_1  7.819466  1.8346854  1.18095345  1.38288573
#> T-26-0015_Operator_2   Operator_2  7.517800  1.8792245  1.18095345  1.32901134
#> T-26-0016_Operator_1   Operator_1 10.753049  3.0456843  1.64945945  1.78101836
#> T-26-0016_Operator_2   Operator_2 10.305716  3.0171921  1.52232677  1.85339814
#> T-26-0017_Operator_1   Operator_1  6.726832  1.6402465  1.18095345  1.15552726
#> T-26-0017_Operator_2   Operator_2  6.452745  1.6092342  1.18095345  1.16751601
#> T-26-0018_Operator_1   Operator_1 20.278560  6.1662950  1.61229877  4.35988423
#> T-26-0018_Operator_2   Operator_2 19.167795  5.9244848  3.21772348  4.11887779
#> T-26-0019_Operator_1   Operator_1 13.241658  3.2726988  1.56572789  1.82243630
#> T-26-0019_Operator_2   Operator_2 12.895929  3.2011626  1.52452280  1.79193965
#> T-26-0020_Operator_1   Operator_1  9.224436  2.6190706  1.18095345  2.01936043
#> T-26-0020_Operator_2   Operator_2  9.140239  2.6055508  2.30552072  2.02564505
#> T-26-0021_Operator_1   Operator_1  9.330086  2.6421536  1.37595784  1.28579612
#> T-26-0021_Operator_2   Operator_2  8.823626  2.5099881  1.35584392  1.28691637
#> T-26-0022_Operator_1   Operator_1 11.489489  2.8127576  1.43508258  1.69688740
#> T-26-0022_Operator_2   Operator_2 11.399654  2.8368035  1.38535785  1.65246897
#> T-26-0023-2_Operator_1 Operator_1  3.967063  0.8906095  0.49833079  0.44111884
#> T-26-0023-2_Operator_2 Operator_2  3.954428  0.9126688  0.81533462  0.43264353
#> T-26-0024_Operator_1   Operator_1  9.185208  2.3286996  1.18095345  1.87107369
#> T-26-0024_Operator_2   Operator_2  8.638556  2.1887872  1.18095345  1.82598108
#> T-26-0025_Operator_1   Operator_1  9.465836  2.6764249  1.18095345  2.16027527
#> T-26-0025_Operator_2   Operator_2  9.257391  2.6127906  1.18095345  2.19584397
#> T-26-0026_Operator_1   Operator_1  9.533145  2.5835183  1.39915422  1.76514292
#> T-26-0026_Operator_2   Operator_2  9.306362  2.5743509  1.18095345  1.80660019
#> T-26-0027_Operator_1   Operator_1  9.895108  2.6291326  1.18095345  2.27495920
#> T-26-0027_Operator_2   Operator_2  9.731939  2.6157876  1.18095345  2.11798437
#> T-26-0028_Operator_1   Operator_1  7.189649  1.9311310  1.18095345  1.49756238
#> T-26-0028_Operator_2   Operator_2  6.991455  1.9535092  1.18095345  1.53814672
#> T-26-0029_Operator_1   Operator_1  3.792798  1.4632856  0.78281775  0.79311048
#> T-26-0029_Operator_2   Operator_2  3.774153  1.4640376  0.77164747  0.81777134
#> T-26-0030_Operator_1   Operator_1 12.584474  3.1025686  1.57554583  2.19843278
#> T-26-0030_Operator_2   Operator_2 12.573432  3.1914753  1.56823318  2.00154821
#> T-26-0031_Operator_1   Operator_1  7.901356  2.0818330  1.18095345  1.63243659
#> T-26-0031_Operator_2   Operator_2  7.698888  2.0799672  1.59535771  1.63712543
#> T-26-0032_Operator_1   Operator_1 26.719407  7.1288922  3.67607362  5.69614510
#> T-26-0032_Operator_2   Operator_2 25.703313  7.3226715  3.45258256  5.14724449
#> T-26-0033_Operator_1   Operator_1  8.960122  2.4672505  1.18095345  2.08049685
#> T-26-0033_Operator_2   Operator_2  8.999446  2.5083200  1.18095345  2.02284351
#> T-26-0034_Operator_1   Operator_1  8.654831  2.5514849  1.18095345  1.86082647
#> T-26-0034_Operator_2   Operator_2  8.591478  2.5197275  1.18095345  1.97699532
#> T-26-0035_Operator_1   Operator_1  5.944340  1.4017315  1.18095345  1.18015056
#> T-26-0035_Operator_2   Operator_2  5.950211  1.4178243  1.18095345  1.13736318
#> T-26-0036_Operator_1   Operator_1 13.393856  3.3361232  1.56328709  2.25435727
#> T-26-0036_Operator_2   Operator_2 13.153902  3.2912097  1.46860041  2.11626628
#> T-26-0037_Operator_1   Operator_1 16.294212  4.2577825  1.96223025  2.98959727
#> T-26-0037_Operator_2   Operator_2 16.231102  4.2484537  1.93040404  2.69652460
#> T-26-0038_Operator_1   Operator_1  6.891866  1.8297464  1.18095345  1.43863180
#> T-26-0038_Operator_2   Operator_2  6.614041  1.7895605  1.18095345  1.34668818
#> T-26-0039_Operator_1   Operator_1  7.783351  2.1312844  0.99975888  1.21787668
#> T-26-0039_Operator_2   Operator_2  7.758650  2.1034719  1.01586592  1.24973000
#> T-26-0040_Operator_1   Operator_1  8.663642  2.2088181  1.18095345  1.57332776
#> T-26-0040_Operator_2   Operator_2  8.442752  2.1486681  1.27849720  1.56892908
#> T-26-0041_Operator_1   Operator_1  6.533798  1.5643513  1.18095345  1.17400843
#> T-26-0041_Operator_2   Operator_2  6.310595  1.5495743  1.18095345  1.16239801
#> T-26-0042_Operator_1   Operator_1  9.260328  2.2660578  1.18095345  1.75665220
#> T-26-0042_Operator_2   Operator_2  9.120995  2.2907217  1.18095345  1.74495525
#> T-26-0043_Operator_1   Operator_1  8.333438  1.8802280  1.18095345  1.16912256
#> T-26-0043_Operator_2   Operator_2  8.026394  1.8520647  1.08582428  1.27777313
#> T-26-0044_Operator_1   Operator_1  8.762759  2.5332347  1.18095345  1.91559352
#> T-26-0044_Operator_2   Operator_2  8.450378  2.5126301  1.51396747  1.90428864
#> T-26-0045_Operator_1   Operator_1 14.432664  3.7250346  1.76427017  2.12983583
#> T-26-0045_Operator_2   Operator_2 13.710136  3.5214603  1.72043935  2.12659074
#> T-26-0046_Operator_1   Operator_1  8.891113  2.2362600  1.18095345  1.70509712
#> T-26-0046_Operator_2   Operator_2  8.359665  2.2282532  1.18095345  1.64792400
#> T-26-0047_Operator_1   Operator_1 27.397544  7.7959037  3.31061099  6.04144575
#> T-26-0047_Operator_2   Operator_2 26.849874  8.0428196  3.36750035  5.75093060
#> T-26-0048_Operator_1   Operator_1  9.765520  2.2772458  1.18095345  1.70011877
#> T-26-0048_Operator_2   Operator_2  9.485998  2.3282226  1.52968082  1.75044441
#> T-26-0049_Operator_1   Operator_1 13.395474  3.3167758  1.60846599  1.86967216
#> T-26-0049_Operator_2   Operator_2 13.112018  3.2862615  1.59587345  1.95172922
#> T-26-0050_Operator_1   Operator_1  7.731364  2.0225162  1.18095345  1.54507034
#> T-26-0050_Operator_2   Operator_2  7.371336  0.1205212  0.06514658  0.09120521
#> T-26-0051_Operator_1   Operator_1 10.026297  2.6230682  1.18095345  2.03731683
#> T-26-0051_Operator_2   Operator_2 10.218053  2.7299023  1.64139642  2.11832458
#> T-26-0052_Operator_1   Operator_1  7.515557  0.7017406  0.86677115  0.44772991
#> T-26-0052_Operator_2   Operator_2 14.866571  3.7870239  1.73670006  2.10064314
#> T-26-0053_Operator_1   Operator_1 15.200389  4.0809297  1.89904444  2.21047371
#> T-26-0053_Operator_2   Operator_2 14.482921  3.8863519  1.78051131  2.10160343
#> T-26-0054_Operator_1   Operator_1 13.532245  3.5261626  1.75430079  2.23024756
#> T-26-0054_Operator_2   Operator_2 13.577729  3.5227031  1.72522014  2.26343323
#> T-26-0055_Operator_1   Operator_1  9.657703  2.6389034  1.18095345  2.11231002
#> T-26-0055_Operator_2   Operator_2  9.446884  2.6510382  1.18095345  2.08574503
#> T-26-0056-2_Operator_1 Operator_1 10.608752  3.0334717  1.18095345  2.34440505
#> T-26-0056-2_Operator_2 Operator_2 10.365377  2.9766864  1.58446403  2.24120574
#> T-26-0057_Operator_1   Operator_1  8.628830  2.4016155  1.18082484  1.71359902
#> T-26-0057_Operator_2   Operator_2  8.383760  2.3603073  1.18179042  1.77103372
#> T-26-0058_Operator_1   Operator_1  9.598353  2.6245375  1.18095345  2.03989712
#> T-26-0058_Operator_2   Operator_2  7.976647  2.1710173  1.18095345  1.55748898
#> T-26-0059_Operator_1   Operator_1 10.032306  2.6663582  1.18095345  1.98219147
#> T-26-0059_Operator_2   Operator_2  9.850798  2.6606743  1.40231096  2.01363978
#> T-26-0060_Operator_1   Operator_1  8.845626  2.1341875  1.18095345  1.61725054
#> T-26-0060_Operator_2   Operator_2  8.716633  2.0954773  1.26243237  1.58495110
#> T-26-0061_Operator_1   Operator_1 14.819986  3.5949012  1.88789725  2.50377888
#> T-26-0061_Operator_2   Operator_2 14.773245  3.6136218  1.89748820  2.35734263
#> T-26-0062_Operator_1   Operator_1 18.349125  4.4785865  2.33284686  2.94564968
#> T-26-0062_Operator_2   Operator_2 18.859337  4.6198213  2.33060606  2.75290337
#> T-26-0063_Operator_1   Operator_1  6.699613  1.8139889  1.18095345  1.54240609
#> T-26-0063_Operator_2   Operator_2  6.651589  1.8494779  0.94158897  1.55375077
#> T-26-0064_Operator_1   Operator_1  8.282579  2.1990608  1.18095345  1.43857329
#> T-26-0064_Operator_2   Operator_2  8.269170  2.2426590  1.23575968  1.50700200
#> T-26-0065_Operator_1   Operator_1  8.860755  2.3958781  1.18095345  1.87383949
#> T-26-0065_Operator_2   Operator_2  8.774428  2.4387755  1.30509848  1.85999365
#> T-26-0067_Operator_1   Operator_1  9.098319  2.6308665  1.33399329  1.92008053
#> T-26-0067_Operator_2   Operator_2  9.223213  2.6375057  1.35963502  1.96874870
#> T-26-0068_Operator_1   Operator_1 11.707055  2.9026090  1.52801260  1.81390960
#> T-26-0068_Operator_2   Operator_2 11.810203  2.9635730  1.49207967  1.78437465
#> T-26-0069_Operator_1   Operator_1  8.111636  1.9366804  1.06455447  1.06089148
#> T-26-0069_Operator_2   Operator_2  8.132650  1.9772293  1.07914792  1.03210893
#> T-26-0070_Operator_1   Operator_1  9.236925  2.4823162  1.20784079  1.32652685
#> T-26-0070_Operator_2   Operator_2  9.156101  2.3569347  1.19962438  1.36516012
#> T-26-0071_Operator_1   Operator_1  8.119705  1.9232598  1.22083818  1.55517847
#> T-26-0071_Operator_2   Operator_2  8.082817  1.9567676  1.21952080  1.47836837
#> T-26-0072_Operator_1   Operator_1  8.931884  2.1876938  1.18095345  1.76923668
#> T-26-0072_Operator_2   Operator_2  8.891576  2.2295930  1.33411781  1.77645676
#> T-26-0073_Operator_1   Operator_1  9.728765  2.6030857  1.18095345  2.08375790
#> T-26-0073_Operator_2   Operator_2  9.373260  2.5754048  1.44737708  2.03058241
#> T-26-0074_Operator_1   Operator_1  9.333662  2.4549746  1.39966547  1.62737601
#> T-26-0074_Operator_2   Operator_2  9.228916  2.5103115  1.39214648  1.73015492
#> T-26-0075_Operator_1   Operator_1 11.256087  3.0982388  1.66213559  2.50057094
#> T-26-0075_Operator_2   Operator_2 11.463401  3.1431894  1.68809751  2.43793978
#> T-26-0076_Operator_1   Operator_1 11.260369  2.7816905  1.41612902  1.77883205
#> T-26-0076_Operator_2   Operator_2 11.130889  2.8355818  1.40325897  1.63572244
#> T-26-0077_Operator_1   Operator_1  5.874145  1.4128496  1.18095345  1.00464849
#> T-26-0077_Operator_2   Operator_2  5.947631  1.4565088  0.85648600  1.01084761
#> T-26-0078_Operator_1   Operator_1  9.678709  2.4885850  1.18095345  1.59817486
#> T-26-0078_Operator_2   Operator_2  9.606177  2.4278515  1.43951638  1.64075152
#> T-26-0079_Operator_1   Operator_1  7.794510  2.1829866  1.18095345  1.62704563
#> T-26-0079_Operator_2   Operator_2  7.822441  2.2136848  1.07733715  1.67877053
#> T-26-0080_Operator_1   Operator_1  6.414039  1.7310801  0.85067042  0.93987846
#> T-26-0080_Operator_2   Operator_2  6.454427  1.7066608  0.86472915  0.96368793
#> T-26-0081_Operator_1   Operator_1  5.482068  1.2750692  1.18095345  0.82025779
#> T-26-0081_Operator_2   Operator_2  5.639310  1.3653552  1.18095345  0.87121078
#> T-26-0082_Operator_1   Operator_1  8.768688  2.2752182  1.07658830  1.46769024
#> T-26-0082_Operator_2   Operator_2  8.784480  2.2808016  1.09774775  1.40601394
#> T-26-0083_Operator_1   Operator_1  5.330012  1.3590002  1.18095345  1.03641749
#> T-26-0083_Operator_2   Operator_2  5.303435  1.3589245  1.18095345  1.05411688
#> T-26-0084_Operator_1   Operator_1  6.613543  1.7652692  1.18095345  1.21541024
#> T-26-0084_Operator_2   Operator_2  6.750088  1.8186322  1.18095345  1.36473878
#> T-26-0085_Operator_1   Operator_1  8.012648  2.2408643  1.18633526  1.37464245
#> T-26-0085_Operator_2   Operator_2  8.194352  2.2723100  1.19128512  1.46455888
#> T-26-0086_Operator_1   Operator_1  9.286351  2.2272747  1.18095345  1.82469148
#> T-26-0086_Operator_2   Operator_2  8.979844  2.2511138  1.38595421  1.81411865
#> T-26-0087_Operator_1   Operator_1  7.799946  2.1208703  1.18095345  1.72198932
#> T-26-0087_Operator_2   Operator_2  7.615699  2.1173923  2.73059968  1.67602019
#> T-26-0088_Operator_1   Operator_1  8.003724  2.2435349  1.18095345  1.34893971
#> T-26-0088_Operator_2   Operator_2  8.033052  2.2833829  1.18095345  1.53616836
#> T-26-0089_Operator_1   Operator_1  3.365617  0.6594441  0.45091726  0.34778861
#> T-26-0089_Operator_2   Operator_2  3.309281  0.7178999  0.45205288  0.36729283
#> T-26-0090_Operator_1   Operator_1  4.446949  0.9875485  0.60164680  0.67767514
#> T-26-0090_Operator_2   Operator_2  4.488751  1.0001464  0.61798873  0.68768913
#> T-26-0091_Operator_1   Operator_1  8.879337  2.0752306  1.28835082  1.50508103
#> T-26-0091_Operator_2   Operator_2  8.857758  2.2208200  1.32210905  1.63781119
#> T-26-0092_Operator_1   Operator_1  8.798930  2.5024304  1.18095345  1.53638218
#> T-26-0092_Operator_2   Operator_2  8.673963  2.4739225  1.18095345  1.70157879
#> T-26-0093_Operator_1   Operator_1  8.271604  2.2652431  1.18095345  1.75124810
#> T-26-0093_Operator_2   Operator_2  8.245474  2.2658557  1.18095345  1.81069552
#> T-26-0094_Operator_1   Operator_1  6.816662  1.7308191  1.02762452  1.28451799
#> T-26-0094_Operator_2   Operator_2  6.744345  1.7319854  1.18095345  1.30308781
#> T-26-0095_Operator_1   Operator_1  7.591034  1.8502765  1.18095345  1.35041409
#> T-26-0095_Operator_2   Operator_2  7.432418  1.9102882  1.18095345  1.41887164
#> T-26-0096_Operator_1   Operator_1  6.393025  1.7089214  0.86850980  1.17503235
#> T-26-0096_Operator_2   Operator_2  6.271418  1.6647321  0.86946320  1.24883147
#> T-26-0097_Operator_1   Operator_1  8.917207  2.2481345  1.30475710  1.46413549
#> T-26-0097_Operator_2   Operator_2  8.856381  2.2439584  1.31672598  1.55290147
#> T-26-0098_Operator_1   Operator_1  7.763619  1.9028971  1.18095345  1.41233954
#> T-26-0098_Operator_2   Operator_2  7.555446  1.9380677  1.03947538  1.28484317
#> T-26-0099_Operator_1   Operator_1  4.141031  0.9300604  0.51973084  0.41636252
#> T-26-0099_Operator_2   Operator_2  4.160279  0.9683299  0.52783711  0.46294377
#> T-26-0100_Operator_1   Operator_1  6.383691  1.6760671  1.18095345  1.16468213
#> T-26-0100_Operator_2   Operator_2  6.312897  1.6876373  1.28611430  1.24648937
#> T-26-0101_Operator_1   Operator_1  6.990892  2.2156723  1.18095345  1.66382649
#> T-26-0101_Operator_2   Operator_2  7.395853  2.1342374  1.18095345  1.62111073
#> T-26-0102_Operator_1   Operator_1  7.519589  1.9682694  1.18095345  1.39771987
#> T-26-0102_Operator_2   Operator_2  7.416510  1.9901418  1.18095345  1.41525917
#> T-26-0103_Operator_1   Operator_1  9.426845  2.5461368  1.41818546  1.59256083
#> T-26-0103_Operator_2   Operator_2  9.574033  2.7140325  1.41771092  1.73952291
#> T-26-0104_Operator_1   Operator_1  8.412130  2.3556548  1.18095345  1.44136798
#> T-26-0104_Operator_2   Operator_2  9.063534  2.5229216  1.21153105  1.65867214
#> T-26-0107_Operator_1   Operator_1  8.448413  2.3870000  1.18095345  1.67822228
#> T-26-0107_Operator_2   Operator_2  7.976647  2.1710173  1.18095345  1.55748898
#> T-26-0108_Operator_1   Operator_1  8.389500  2.0275135  1.18095345  1.21316601
#> T-26-0108_Operator_2   Operator_2  8.949133  2.1748433  1.18095345  1.38633914
#> T-26-0109_Operator_1   Operator_1  9.367584  2.4645421  1.18095345  1.82551240
#> T-26-0109_Operator_2   Operator_2  8.995382  2.4414451  1.18095345  1.71812815
#> T-26-0111_Operator_1   Operator_1  3.063680  0.6515520  1.18095345  0.50371044
#> T-26-0111_Operator_2   Operator_2  3.164542  0.7050612  1.18095345  0.44669338
#> T-26-0112-2_Operator_1 Operator_1  6.557598  1.5911264  0.90463889  1.05923602
#> T-26-0112-2_Operator_2 Operator_2  6.526428  1.5917784  0.88005813  1.11339756
#> T-26-0112_Operator_1   Operator_1  3.797588  0.8669887  0.53887976  0.53580545
#> T-26-0112_Operator_2   Operator_2  3.851295  0.9083065  0.53665224  0.58702676
#> T-26-0113_Operator_1   Operator_1  6.709608  1.5969789  0.98169094  0.86856780
#> T-26-0113_Operator_2   Operator_2  6.862344  1.5918620  1.18095345  1.02373623
#> T-26-0114_Operator_1   Operator_1  7.372738  1.9359052  1.18095345  1.33139294
#> T-26-0114_Operator_2   Operator_2  9.056416  2.3650560  1.18095345  1.52250388
#> T-26-0115_Operator_1   Operator_1  9.004481  2.3915973  1.18095345  1.40914962
#> T-26-0115_Operator_2   Operator_2  7.251247  1.7833073  1.18095345  1.18222026
#> T-26-0116_Operator_1   Operator_1  7.304079  1.7850164  0.99974990  1.08191947
#> T-26-0116_Operator_2   Operator_2  7.734555  1.9960502  1.18095345  1.46332794
#> T-26-0117_Operator_1   Operator_1  7.806228  2.0016502  1.18095345  1.36327739
#> T-26-0117_Operator_2   Operator_2  8.625387  2.2073313  1.18095345  1.72767542
#> T-26-0118_Operator_1   Operator_1  8.728475  2.1743177  1.18095345  1.69327867
#> T-26-0118_Operator_2   Operator_2  7.669691  1.9329878  1.18095345  1.39107999
#> T-26-0120_Operator_1   Operator_1  6.896045  1.5939239  1.00306863  1.22753369
#> T-26-0120_Operator_2   Operator_2  6.668463  1.5926964  0.97623721  1.12963043
#> T-26-0121_Operator_1   Operator_1  7.285077  1.8572006  1.18095345  1.34455105
#> T-26-0121_Operator_2   Operator_2  3.208333 34.4166667  1.18095345 25.00000000
#> T-26-0122_Operator_1   Operator_1  8.757708  2.3177521  1.29916437  1.53529855
#> T-26-0122_Operator_2   Operator_2  8.604047  2.3067879  1.18095345  1.49829738
#> T-26-0123_Operator_1   Operator_1  7.937351  1.9471496  1.18095345  1.25384065
#> T-26-0123_Operator_2   Operator_2  7.852605  1.9741881  1.18095345  1.39039907
#> T-26-0125_Operator_1   Operator_1  6.883640  1.4799444  1.18095345  1.05030093
#> T-26-0125_Operator_2   Operator_2  7.067181  1.5246391  1.18095345  1.18013384
#> T-26-0126_Operator_1   Operator_1  6.831146  1.8914700  1.18095345  1.30322478
#> T-26-0126_Operator_2   Operator_2  6.812574  1.8494426  1.18095345  1.36752653
#> T-26-0127_Operator_1   Operator_1  8.633812  2.4628407  1.18095345  1.74637804
#> T-26-0127_Operator_2   Operator_2  8.506932  2.4907511  1.18095345  1.72713822
#> T-26-0128_Operator_1   Operator_1  7.059841  1.6927304  0.92691005  0.97638684
#> T-26-0128_Operator_2   Operator_2  6.945708  1.6581190  0.92486371  1.02845206
#> T-26-0130_Operator_1   Operator_1  5.140970  1.1801542  0.69592828  0.74110598
#> T-26-0130_Operator_2   Operator_2  5.252193  1.2266916  0.69047153  0.75737485
#> T-26-0131_Operator_1   Operator_1  9.225005  2.4041048  1.18095345  1.60957784
#> T-26-0131_Operator_2   Operator_2  9.144279  2.3890129  1.19620885  1.60947041
#> T-26-0132_Operator_1   Operator_1  8.788302  2.5143954  1.18095345  1.80818974
#> T-26-0132_Operator_2   Operator_2  8.806004  2.5747811  1.26227432  1.85327814
#> T-26-0133_Operator_1   Operator_1  8.709623  2.3630401  1.30811438  1.08896047
#> T-26-0133_Operator_2   Operator_2  8.431688  2.3874379  1.30626562  1.15661652
#> T-26-0134_Operator_1   Operator_1  8.446534  2.1772030  1.18095345  1.70098102
#> T-26-0134_Operator_2   Operator_2  8.287391  2.1760949  1.18095345  1.68464547
#> T-26-0135_Operator_1   Operator_1  8.920931  2.3447820  1.30341728  1.14482113
#> T-26-0135_Operator_2   Operator_2  8.699713  2.3038453  1.33454082  1.19812723
#> T-26-0136_Operator_1   Operator_1  8.621097  2.3489091  1.19154898  1.65724103
#> T-26-0136_Operator_2   Operator_2  8.478081  2.3503021  1.18421759  1.63616218
#> T-26-0137_Operator_1   Operator_1 15.465536  3.9723848  1.74305979  2.19257975
#> T-26-0137_Operator_2   Operator_2 15.549965  3.9557902  1.74593123  2.23720566
#> T-26-0138_Operator_1   Operator_1  7.887967  2.1021399  1.18095345  1.47625317
#> T-26-0138_Operator_2   Operator_2  7.820357  2.1457654  1.18095345  1.53560819
#> T-26-0139_Operator_1   Operator_1  8.565085  2.2107216  1.18095345  1.59174756
#> T-26-0139_Operator_2   Operator_2  8.659723  2.2799644  1.18095345  1.62839821
#> T-26-0140_Operator_1   Operator_1  6.661244  1.6529605  1.18095345  1.16893899
#> T-26-0140_Operator_2   Operator_2  6.496649  1.6172620  1.18095345  1.19291497
#> T-26-0141_Operator_1   Operator_1  8.729264  2.2536320  1.18095345  1.61653103
#> T-26-0141_Operator_2   Operator_2  8.654856  2.2346306  1.18095345  1.61961657
#> T-26-0142_Operator_1   Operator_1  6.800358  1.6981936  1.18095345  1.20519983
#> T-26-0142_Operator_2   Operator_2  6.782372  1.6508407  1.18095345  1.23156166
#> T-26-0143_Operator_1   Operator_1  7.958629  1.9903115  1.02710318  1.14576837
#> T-26-0143_Operator_2   Operator_2  7.825501  1.9928111  1.04060077  1.15916159
#> T-26-0144_Operator_1   Operator_1 11.211236  2.4429442  1.43577710  1.21119006
#> T-26-0144_Operator_2   Operator_2 11.159604  2.4118264  1.48352101  1.36521013
#> T-26-0145_Operator_1   Operator_1  3.476759  0.7309580  0.46238094  0.42838425
#> T-26-0145_Operator_2   Operator_2  3.451907  0.7344281  0.47008515  0.48343001
#> T-26-0146_Operator_1   Operator_1 10.308065  2.7416093  1.18095345  2.15639981
#> T-26-0146_Operator_2   Operator_2 10.188815  2.7121380  1.18095345  2.25731232
#> T-26-0147_Operator_1   Operator_1 10.774301  2.8913951  1.38201660  1.95237168
#> T-26-0147_Operator_2   Operator_2 10.752577  2.8905814  1.33279036  2.03060430
#> T-26-0148_Operator_1   Operator_1 14.048013  3.9101272  1.80229398  2.33367123
#> T-26-0148_Operator_2   Operator_2 14.198808  3.9743894  1.87017709  2.34447817
#> T-26-0149_Operator_1   Operator_1 25.516170  7.3873446  3.26289624  5.27619945
#> T-26-0149_Operator_2   Operator_2 24.925403  7.2806500  3.17045875  4.84407632
#> T-26-0150_Operator_1   Operator_1 16.870102  4.1728676  1.95040794  2.64946319
#> T-26-0150_Operator_2   Operator_2 16.424974  4.0354734  1.92887094  2.70217459
#> T-26-0151_Operator_1   Operator_1  9.272882  2.4256385  1.35809803  1.53370683
#> T-26-0151_Operator_2   Operator_2  9.127870  2.4361745  1.18095345  1.61047642
#> T-26-0152_Operator_1   Operator_1  3.270295  0.7321141  0.45786119  0.48278351
#> T-26-0152_Operator_2   Operator_2  3.251710  0.7099794  0.46244497  0.48645379
#> T-26-0153_Operator_1   Operator_1  7.981994  1.9261933  1.15027773  1.11686946
#> T-26-0153_Operator_2   Operator_2  7.845549  1.9238201  1.16042804  1.19813944
#> T-26-0154_Operator_1   Operator_1  6.615922  1.6521925  1.18095345  1.21221021
#> T-26-0154_Operator_2   Operator_2  6.518228  1.6443351  0.91792209  1.20999415
#> T-26-0155_Operator_1   Operator_1  4.815762  1.1612617  1.18095345  0.78663794
#> T-26-0155_Operator_2   Operator_2  4.776994  1.1448388  1.18095345  0.80712228
#> T-26-0156_Operator_1   Operator_1 20.121423  5.2837334  2.67573848  3.68924833
#> T-26-0156_Operator_2   Operator_2 19.641689  5.4229035  2.63977767  3.48798958
#> T-26-0157_Operator_1   Operator_1  9.358347  2.3869948  1.39416632  1.62542262
#> T-26-0157_Operator_2   Operator_2  8.907494  2.3171223  1.33104906  1.63929513
#> T-26-0158_Operator_1   Operator_1  8.318043  2.1277062  1.16775718  1.57726758
#> T-26-0158_Operator_2   Operator_2  8.175117  2.1488449  1.14739781  1.59071719
#> T-26-0159_Operator_1   Operator_1  8.960234  2.3460201  1.34569258  1.42667893
#> T-26-0159_Operator_2   Operator_2  8.582365  2.2620205  1.18095345  1.42360628
#> T-26-0160_Operator_1   Operator_1  8.453321  2.1711909  1.18095345  1.38869473
#> T-26-0160_Operator_2   Operator_2  8.336273  2.1665103  1.18095345  1.45771702
#> T-26-0161_Operator_1   Operator_1  7.743955  1.9731189  1.18095345  1.43310875
#> T-26-0161_Operator_2   Operator_2  7.469785  1.9398479  1.18095345  1.45093211
#> T-26-0162_Operator_1   Operator_1  7.579910  2.0401309  1.18095345  1.44291029
#> T-26-0162_Operator_2   Operator_2  7.333056  2.0065741  1.18095345  1.49013163
#> T-26-0163_Operator_1   Operator_1  9.098792  2.3133718  1.18095345  1.45334862
#> T-26-0163_Operator_2   Operator_2  8.855654  2.2926088  1.20526922  1.53277924
#> T-26-0164_Operator_1   Operator_1  4.803193  1.1345773  0.64169565  0.62509792
#> T-26-0164_Operator_2   Operator_2  4.770349  1.1269188  0.62200509  0.66367252
#> T-26-0165_Operator_1   Operator_1  7.452509  1.9783993  0.96896036  1.34167217
#> T-26-0165_Operator_2   Operator_2  7.428954  1.9647288  0.98880451  1.41112327
#> T-26-0166_Operator_1   Operator_1  4.240233  1.0499275  0.61195469  0.68878260
#> T-26-0166_Operator_2   Operator_2  4.173335  1.0033843  0.60206659  0.70044203
#> T-26-0167_Operator_1   Operator_1 27.786992  7.3615627  3.23855253  4.93945011
#> T-26-0167_Operator_2   Operator_2 26.260097  7.3047829  3.18272253  4.80890050
#> T-26-0168_Operator_1   Operator_1  8.493020  2.4630116  1.15014470  1.59243517
#> T-26-0168_Operator_2   Operator_2  8.139477  2.3948990  1.10971799  1.60845617
#> T-26-0169_Operator_1   Operator_1 10.428105  2.6561016  1.49379347  1.79099943
#> T-26-0169_Operator_2   Operator_2 20.204788  5.2176107  2.91026208  3.63548664
#> T-26-0170_Operator_1   Operator_1  9.826011  2.7498987  1.46423279  1.78566490
#> T-26-0170_Operator_2   Operator_2  9.493054  2.6706016  1.43743258  1.88025209
#> T-26-0171_Operator_1   Operator_1  9.916260  2.4626247  1.36215657  1.70436577
#> T-26-0171_Operator_2   Operator_2  9.538539  2.4687427  1.32771316  1.79989362
#> T-26-0172_Operator_1   Operator_1  9.883746  2.4073587  1.38730828  1.49610670
#> T-26-0172_Operator_2   Operator_2  9.265153  2.3111692  1.31930035  1.51678775
#> T-26-0173_Operator_1   Operator_1  6.836187  1.7343700  0.91898100  1.27485268
#> T-26-0173_Operator_2   Operator_2  6.593399  1.7306618  0.90380530  1.32568293
#> T-26-0174_Operator_1   Operator_1  8.147046  2.2818316  1.18095345  1.76499271
#> T-26-0174_Operator_2   Operator_2  7.861860  2.2813141  1.34683851  1.79581239
#> T-26-0175_Operator_1   Operator_1  8.580691  2.1543244  1.22817860  1.60399072
#> T-26-0175_Operator_2   Operator_2  8.193555  2.0898922  1.21989210  1.61797936
#> T-26-0176_Operator_1   Operator_1  8.483066  2.3173658  1.33773276  1.46609793
#> T-26-0176_Operator_2   Operator_2  8.310732  2.2794353  1.31562208  1.53127661
#> T-26-0177_Operator_1   Operator_1  9.422164  2.7438138  1.18095345  2.12365836
#> T-26-0177_Operator_2   Operator_2  9.297821  2.6920128  1.18095345  2.05819935
#> T-26-0178_Operator_1   Operator_1  9.333639  2.3197344  1.37850192  1.70943047
#> T-26-0178_Operator_2   Operator_2  9.095360  2.3271231  1.38591595  1.78523142
#> T-26-0179-3_Operator_1 Operator_1  9.405112  2.5376131  1.18095345  1.70792291
#> T-26-0179-3_Operator_2 Operator_2  9.035738  2.4723096  1.18095345  1.67098368
#> T-26-0179_Operator_1   Operator_1  4.973261  1.2267470  0.65780744  0.67998765
#> T-26-0179_Operator_2   Operator_2  4.921452  1.2380851  0.66450281  0.77201983
#> T-26-0180_Operator_1   Operator_1  9.537697  2.5667124  1.18095345  1.70613404
#> T-26-0180_Operator_2   Operator_2  9.072134  2.4748811  1.29776265  1.67108612
#> T-26-0181_Operator_1   Operator_1  8.217100  2.3505103  1.24742461  1.54014273
#> T-26-0181_Operator_2   Operator_2  7.993417  2.2672207  1.23054458  1.53358636
#> T-26-0182_Operator_1   Operator_1  7.892748  1.8398827  1.18095345  1.31101639
#> T-26-0182_Operator_2   Operator_2  7.661711  1.7920132  1.19880897  1.31291624
#> T-26-0183_Operator_1   Operator_1  9.518076  2.4053677  1.18095345  1.41256452
#> T-26-0183_Operator_2   Operator_2  9.361312  2.3909196  1.25476110  1.53224973
#> T-26-0184_Operator_1   Operator_1 10.269898  2.9913909  1.57286200  1.61300645
#> T-26-0184_Operator_2   Operator_2  9.658755  2.7081642  1.53764013  1.56031126
#> T-26-0185_Operator_1   Operator_1  7.273865  1.6675667  0.92878843  1.12792203
#> T-26-0185_Operator_2   Operator_2  6.952826  1.6485574  0.89777574  1.15451043
#> T-26-0186_Operator_1   Operator_1  9.774102  2.5524726  1.41280021  1.85260413
#> T-26-0186_Operator_2   Operator_2  9.593719  2.5653717  1.41275700  1.80321885
#> T-26-0187_Operator_1   Operator_1 10.136772  2.5030524  1.49008194  1.70854396
#> T-26-0187_Operator_2   Operator_2  9.599981  2.4379535  1.41674099  1.73966971
#> T-26-0188_Operator_1   Operator_1  7.082200  1.4585851  1.37445662  0.90704980
#> T-26-0188_Operator_2   Operator_2  6.862648  1.4151438  0.69846150  0.90469732
#> T-26-0189_Operator_1   Operator_1  7.800557  2.0604721  1.18095345  1.46284131
#> T-26-0189_Operator_2   Operator_2  7.495119  1.9729380  1.01262317  1.45213002
#> T-26-0190_Operator_1   Operator_1  8.623126  2.1599911  1.28711168  1.32310554
#> T-26-0190_Operator_2   Operator_2  8.233771  2.0736471  1.20941208  1.25748156
#> T-26-0191_Operator_1   Operator_1  8.613953  2.2135302  1.18095345  1.47144644
#> T-26-0191_Operator_2   Operator_2  8.300240  2.1640947  1.26491167  1.45489771
#> T-26-0192_Operator_1   Operator_1  9.308992  2.3755984  1.18095345  1.47645881
#> T-26-0192_Operator_2   Operator_2  8.765336  2.2708618  1.29522899  1.46816464
#> T-26-0193_Operator_1   Operator_1  8.856398  2.3068841  1.18095345  1.78671127
#> T-26-0193_Operator_2   Operator_2  8.625857  2.2899181  1.34929007  1.86939879
#> T-26-0194_Operator_1   Operator_1 11.161935  2.9301445  1.18095345  2.32413732
#> T-26-0194_Operator_2   Operator_2 10.636577  2.8412651  1.53075551  2.31243541
#> T-26-0195_Operator_1   Operator_1  9.319351  2.4288127  1.18095345  1.50086031
#> T-26-0195_Operator_2   Operator_2  8.895387  2.3686426  1.22702850  1.51673449
#> T-26-0196_Operator_1   Operator_1  6.772870  1.6158914  0.91521989  0.98528067
#> T-26-0196_Operator_2   Operator_2  6.567802  1.5912703  0.87353315  0.96203803
#> T-26-0197_Operator_1   Operator_1  8.826393  2.4399619  1.26936172  1.65724360
#> T-26-0197_Operator_2   Operator_2  8.293598  2.3475460  1.21290481  1.64426807
#> T-26-0198_Operator_1   Operator_1  8.414324  2.2914596  1.18095345  1.51871264
#> T-26-0198_Operator_2   Operator_2  7.911831  2.1652155  1.08512781  1.49592503
#> T-26-0199_Operator_1   Operator_1  6.406357  1.1933637  1.37445662  0.83799600
#> T-26-0199_Operator_2   Operator_2  6.404326  1.1861374  0.65711171  0.87620481
#> T-26-0200_Operator_1   Operator_1  9.238281  2.6756751  1.18095345  1.84141985
#> T-26-0200_Operator_2   Operator_2  8.957535  2.6161542  1.35013131  1.89608162
#> T-26-0201_Operator_1   Operator_1  7.622473  1.9509538  1.18095345  1.27583515
#> T-26-0201_Operator_2   Operator_2  7.431919  1.9428145  1.01818080  1.30756557
#> T-26-0202_Operator_1   Operator_1 11.256176  3.2301116  1.95367549  1.61074700
#> T-26-0202_Operator_2   Operator_2 10.826783  3.0416890  1.87834447  1.57992674
#> T-26-0203_Operator_1   Operator_1  8.647504  2.0695971  1.20951532  1.49761784
#> T-26-0203_Operator_2   Operator_2  8.247246  2.0065113  1.16156779  1.46111268
#> T-26-0204_Operator_1   Operator_1  8.900694  2.1559594  1.22825891  1.35236131
#> T-26-0204_Operator_2   Operator_2  8.541752  2.1076327  1.18517801  1.35231541
#> T-26-0205_Operator_1   Operator_1  8.123299  2.0590722  1.18095345  1.49336206
#> T-26-0205_Operator_2   Operator_2  7.870648  2.0330476  1.12194483  1.53616631
#> T-26-0206_Operator_1   Operator_1  7.269843  1.8387050  1.18095345  1.15628802
#> T-26-0206_Operator_2   Operator_2  7.087511  1.8022614  0.98734084  1.24620193
#> T-26-0207_Operator_1   Operator_1  6.211687  1.5128630  0.82876487  0.90337076
#> T-26-0207_Operator_2   Operator_2  6.080203  1.4801871  0.79526831  0.92186204
#> T-26-0208_Operator_1   Operator_1  7.205718  1.3520205  1.37445662  0.93363602
#> T-26-0208_Operator_2   Operator_2  6.940365  1.2926770  0.68150278  0.93253784
#> T-26-0209_Operator_1   Operator_1  9.433548  2.5500597  1.18095345  1.81745558
#> T-26-0209_Operator_2   Operator_2  9.685861  2.5570727  1.32139160  1.83019064
#> T-26-0210_Operator_1   Operator_1  5.160863  1.1868964  0.70820412  0.74422718
#> T-26-0210_Operator_2   Operator_2  5.032432  1.1595538  0.69057538  0.74709424
#> T-26-0211_Operator_1   Operator_1  7.356858  1.9206923  1.18095345  1.40432932
#> T-26-0211_Operator_2   Operator_2  7.235018  1.8829919  1.02629299  1.38703730
#> T-26-0212_Operator_1   Operator_1  6.572344  1.5689139  0.91568369  1.01256651
#> T-26-0212_Operator_2   Operator_2  6.376584  1.5466119  0.88674094  1.02053911
#> T-26-0213_Operator_1   Operator_1  7.360342  1.9093622  1.18095345  1.34931277
#> T-26-0213_Operator_2   Operator_2  7.254137  1.8332162  0.93799713  1.39727194
#> T-26-0214_Operator_1   Operator_1 11.688933  3.3507354  1.52770518  1.90101240
#> T-26-0214_Operator_2   Operator_2 11.320762  3.2251508  1.50443252  2.02156965
#> T-26-0215_Operator_1   Operator_1  7.461961  2.0993214  1.12632815  1.45497744
#> T-26-0215_Operator_2   Operator_2  7.376821  2.1097127  1.12550865  1.46251112
#> T-26-0216_Operator_1   Operator_1  7.072794  1.7624946  1.18095345  1.38756396
#> T-26-0216_Operator_2   Operator_2  6.916795  1.7464553  1.18095345  1.43372630
#> T-26-0217_Operator_1   Operator_1  9.487054  2.3655374  1.32043444  1.32917214
#> T-26-0217_Operator_2   Operator_2  9.407924  2.3486821  1.34030857  1.48972545
#> T-26-0218_Operator_1   Operator_1  7.261583  1.3666618  0.76323101  0.90682185
#> T-26-0218_Operator_2   Operator_2  7.101069  1.3653048  0.75484486  0.92672723
#> T-26-0219_Operator_1   Operator_1  4.512962  1.1177239  0.64022293  0.85079585
#> T-26-0219_Operator_2   Operator_2  4.436315  1.1210196  0.62817826  0.85472543
#> T-26-0220_Operator_1   Operator_1  6.841571  1.6564660  1.18095345  1.09225928
#> T-26-0220_Operator_2   Operator_2  6.668780  1.6461014  1.18095345  1.08974030
#> T-26-0221_Operator_1   Operator_1  7.715062  1.6194926  0.93166116  0.99245296
#> T-26-0221_Operator_2   Operator_2  7.732815  1.7368670  0.94409614  1.03104931
#> T-26-0222_Operator_1   Operator_1 18.680301  4.2836386  2.13435807  1.99575209
#> T-26-0222_Operator_2   Operator_2 18.939625  4.4056699  2.23610474  2.10870494
#> T-26-0223_Operator_1   Operator_1  9.244512  2.5771837  1.18095345  1.91503759
#> T-26-0223_Operator_2   Operator_2  9.288159  2.5612497  1.18095345  1.90132235
#> T-26-0224_Operator_1   Operator_1  9.317499  2.3460688  1.18095345  1.63625932
#> T-26-0224_Operator_2   Operator_2  9.015197  2.2163807  1.18095345  1.63046306
#> T-26-0225_Operator_1   Operator_1 10.456399  2.7859867  1.29235462  1.48723982
#> T-26-0225_Operator_2   Operator_2 10.369535  2.6649290  1.26810543  1.51320026
#> T-26-0226_Operator_1   Operator_1  5.292204  1.2193337  0.70643691  0.69033836
#> T-26-0226_Operator_2   Operator_2  5.280947  1.2293682  0.69829219  0.71153636
#> T-26-0227_Operator_1   Operator_1  7.683103  1.8003888  0.99927905  0.93896110
#> T-26-0227_Operator_2   Operator_2  7.559928  1.7936678  1.01259950  0.89254100
#> T-26-0228_Operator_1   Operator_1  8.375755  2.0329669  1.08221938  1.12569675
#> T-26-0228_Operator_2   Operator_2  8.290491  2.0544708  1.07005910  1.13935802
#> T-26-0229_Operator_1   Operator_1 10.128588  2.6270761  1.29393495  1.36576619
#> T-26-0229_Operator_2   Operator_2  9.931765  2.4938970  1.25303991  1.37611492
#> T-26-0230-1_Operator_1 Operator_1  7.020527  1.1674250  1.37445662  0.96729351
#> T-26-0230-1_Operator_2 Operator_2  4.500000 25.1428571 14.85714286 22.00000000
#> T-26-0230-2_Operator_1 Operator_1  6.481869  1.1674789  1.37445662  0.69438688
#> T-26-0230-2_Operator_2 Operator_2  6.580282  1.0709842  0.65217111  0.76054299
#> T-26-0230-3_Operator_1 Operator_1  6.756530  1.1841250  0.66146915  0.74770813
#> T-26-0230-3_Operator_2 Operator_2  6.676468  1.1358630  0.65382994  0.77167662
#> T-26-0230-4_Operator_1 Operator_1  7.028431  1.3488106  0.76901830  0.93927681
#> T-26-0230-4_Operator_2 Operator_2  6.888051  1.3332958  0.73693269  0.94430189
#> T-26-0231_Operator_1   Operator_1  7.209116  1.4032010  0.74368320  0.77920855
#> T-26-0231_Operator_2   Operator_2  7.131006  1.3873253  0.75307159  0.78609856
#> T-26-0232_Operator_1   Operator_1  6.237482  1.2958170  1.37445662  0.94061204
#> T-26-0232_Operator_2   Operator_2  6.252687  1.3067692  1.37445662  0.97984884
#> T-26-0233_Operator_1   Operator_1  6.633580  1.9489761  1.37445662  1.46124610
#> T-26-0233_Operator_2   Operator_2  5.864201  1.1414887  1.37445662  0.90702825
#> T-26-0234_Operator_1   Operator_1 19.146759  4.6794293  2.76822113  3.17045248
#> T-26-0234_Operator_2   Operator_2 19.246358  4.8227336  2.80978478  3.40418913
#> T-26-0235_Operator_1   Operator_1  6.670236  1.6497761  0.92427600  1.01704526
#> T-26-0235_Operator_2   Operator_2  6.710467  1.7120253  0.92149091  1.04879469
#> T-26-0236_Operator_1   Operator_1 15.760022  3.9159712  1.89160038  2.16371203
#> T-26-0236_Operator_2   Operator_2 15.561209  3.8908433  1.84734335  2.13540670
#> T-26-0237_Operator_1   Operator_1 15.957457  4.0795179  1.83180403  2.04416326
#> T-26-0237_Operator_2   Operator_2 15.737949  3.9885622  1.69816792  2.17202836
#> T-26-0238_Operator_1   Operator_1 11.790394  3.0597929  1.45706664  1.50993204
#> T-26-0238_Operator_2   Operator_2 11.627595  3.0783785  1.47732777  1.56821415
#> T-26-0239_Operator_1   Operator_1 11.462241  3.1695178  1.69224864  1.53274628
#> T-26-0239_Operator_2   Operator_2 10.519130  3.0509514  1.58501853  1.62431780
#> T-26-0240_Operator_1   Operator_1  7.386872  1.8731401  0.94171737  1.05132142
#> T-26-0240_Operator_2   Operator_2  7.214895  1.8386326  0.90130396  1.07267972
#> T-26-0241_Operator_1   Operator_1  5.033140  1.0916912  0.64128364  0.67570267
#> T-26-0241_Operator_2   Operator_2  4.902804  1.0905421  0.65164664  0.71526912
#> T-26-0242_Operator_1   Operator_1 16.876097  4.6372419  1.95620295  3.04845959
#> T-26-0242_Operator_2   Operator_2 16.146342  4.5101884  1.86307710  3.05864178
#> T-26-0243_Operator_1   Operator_1  5.184221  1.2525468  0.66778409  0.60551360
#> T-26-0243_Operator_2   Operator_2  5.107055  1.2538402  0.65080199  0.62360029
#> T-26-0244_Operator_1   Operator_1  3.933057  0.8350921  0.53452318  0.57585697
#> T-26-0244_Operator_2   Operator_2  3.889758  0.8797204  0.53720134  0.60691325
#> T-26-0245_Operator_1   Operator_1  7.026237  1.7300032  1.04004230  0.86333497
#> T-26-0245_Operator_2   Operator_2  7.074091  1.8377188  1.08102412  0.90958002
#> T-26-0246_Operator_1   Operator_1  7.008886  1.7058019  0.96806267  0.84811395
#> T-26-0246_Operator_2   Operator_2  6.791431  1.6557928  0.91996734  0.91996734
#> T-26-0247_Operator_1   Operator_1  4.886358  1.0883334  0.66089952  0.65650107
#> T-26-0247_Operator_2   Operator_2  4.743978  1.0362778  0.63480244  0.65397918
#> T-26-0248_Operator_1   Operator_1  3.520639  0.8047509  0.49883038  0.34144143
#> T-26-0248_Operator_2   Operator_2  3.500932  0.8369558  0.51178827  0.37800027
#> T-26-0249_Operator_1   Operator_1  3.596662  0.8148732  0.52339529  0.34016517
#> T-26-0249_Operator_2   Operator_2  3.527529  0.8140743  0.50952613  0.38375989
#> T-26-0250_Operator_1   Operator_1  3.570711  0.7969029  0.51951985  0.42713887
#> T-26-0250_Operator_2   Operator_2  3.589940  0.8590797  0.51747661  0.46925608
#> T-26-0251_Operator_1   Operator_1  5.467661  1.1900620  0.73573210  0.66517467
#> T-26-0251_Operator_2   Operator_2  5.196350  1.1922536  0.69920171  0.71795526
#> T-26-0252_Operator_1   Operator_1  3.772280  0.8481608  0.49194585  0.37584891
#> T-26-0252_Operator_2   Operator_2  3.715339  0.8696951  0.45719342  0.36989851
#> T-26-0261-1_Operator_1 Operator_1  9.518765  2.4321337  1.18095345  1.69193973
#> T-26-0261-1_Operator_2 Operator_2  9.327214  2.3684863  1.18095345  1.70293121
#> T-26-0261-2_Operator_1 Operator_1  8.184326  2.2074599  1.18095345  1.64626927
#> T-26-0261-2_Operator_2 Operator_2  8.157834  2.1793231  1.18095345  1.59261575
#> T-26-0261-3_Operator_1 Operator_1  8.043753  2.2259858  1.05736232  1.69287614
#> T-26-0261-3_Operator_2 Operator_2  8.038553  2.2124613  1.18095345  1.74488118
#> T-26-0261-4_Operator_1 Operator_1  6.078656  1.4633690  1.18095345  1.21379413
#> T-26-0261-4_Operator_2 Operator_2  6.125062  1.5274508  1.18095345  1.28147430
#> T-26-0261-5_Operator_1 Operator_1  8.606900  1.9685455  1.31149831  1.49708570
#> T-26-0261-5_Operator_2 Operator_2  8.511532  2.0000849  1.18095345  1.51152074
#> T-26-0262-1_Operator_1 Operator_1  7.375714  1.7971661  1.18095345  1.35700871
#> T-26-0262-1_Operator_2 Operator_2  7.551466  1.8503154  1.18095345  1.44183897
#> T-26-0262-2_Operator_1 Operator_1  6.890140  1.8333483  0.94458549  1.50922297
#> T-26-0262-2_Operator_2 Operator_2  7.004796  1.8505830  1.18095345  1.48046642
#> T-26-0263_Operator_1   Operator_1  4.060243  0.9476308  0.57304189  0.48884594
#> T-26-0263_Operator_2   Operator_2  4.298883  0.9397287  0.55801174  0.48511061
#> T-26-0264-1_Operator_1 Operator_1  4.373042  0.9880860  0.62167101  0.63416442
#> T-26-0264-1_Operator_2 Operator_2  4.324746  0.9998373  0.62167101  0.62794412
#> T-26-0264-2_Operator_1 Operator_1  4.078400  0.9162874  0.56907441  0.52542151
#> T-26-0264-2_Operator_2 Operator_2  4.049603  0.9152726  0.54258768  0.53656965
#> T-26-0264-3_Operator_1 Operator_1  4.316654  1.0055849  0.59791347  0.69061514
#> T-26-0264-3_Operator_2 Operator_2  4.290269  0.9899715  0.62167101  0.67990429
#> T-26-0264-4_Operator_1 Operator_1  3.930195  0.8320322  0.52914469  0.41213734
#> T-26-0264-4_Operator_2 Operator_2  3.932485  0.8190329  0.52774291  0.41789355
#> T-26-0265_Operator_1   Operator_1  9.686131  2.4338470  1.33374993  1.36666667
#> T-26-0265_Operator_2   Operator_2  9.783818  2.4480736  1.38123800  1.41497129
#> T-26-0266_Operator_1   Operator_1 25.178168  6.1950118  3.64656873  4.07783608
#> T-26-0266_Operator_2   Operator_2 25.307554  6.1585002  3.59201122  4.23242139
#> T-26-0267_Operator_1   Operator_1 25.296738  6.7556626  3.67792830  5.03660721
#> T-26-0267_Operator_2   Operator_2 24.821796  6.7841903  3.62875294  4.94358843
#> T-26-0268_Operator_1   Operator_1  7.432405  2.0015607  1.14788513  1.01037090
#> T-26-0268_Operator_2   Operator_2  7.402496  1.9418745  1.13586880  0.97082803
#> T-26-0269_Operator_1   Operator_1  7.810178  1.9693438  1.10812819  1.06833473
#> T-26-0269_Operator_2   Operator_2  7.706447  1.9650116  1.07843023  1.08867972
#> T-26-0270-1_Operator_1 Operator_1 12.624763  3.1075008  1.70386837  1.70293864
#> T-26-0270-1_Operator_2 Operator_2 12.012742  2.9881128  1.64709039  1.58475120
#> T-26-0270-2_Operator_1 Operator_1 13.093592  3.0811938  1.70467350  1.68465178
#> T-26-0270-2_Operator_2 Operator_2 13.251133  3.1930080  1.61871851  1.83095759
#> T-26-0271_Operator_1   Operator_1  9.951061  2.8973315  1.49590424  1.49496470
#> T-26-0271_Operator_2   Operator_2  9.494828  2.8489312  1.48560880  1.48641889
#> T-26-0272_Operator_1   Operator_1  6.676933  1.1272330  0.70903200  0.70012037
#> T-26-0272_Operator_2   Operator_2  6.591580  1.1662132  0.70382229  0.77111478
#> T-26-0273_Operator_1   Operator_1  8.647458  2.0142577  1.16112220  1.04127407
#> T-26-0273_Operator_2   Operator_2  8.854456  2.0888984  1.20589120  1.08401063
#> T-26-0274_Operator_1   Operator_1  7.197885  1.1717107  1.37445662  0.96436466
#> T-26-0274_Operator_2   Operator_2  7.098355  1.2310557  1.37445662  1.00571597
#> T-26-0275_Operator_1   Operator_1  7.124035  1.2145781  1.37445662  0.87506638
#> T-26-0275_Operator_2   Operator_2  7.015681  1.2187128  1.37445662  0.89329981
#> T-26-0276_Operator_1   Operator_1  6.125893  1.5328261  0.83775337  0.93300118
#> T-26-0276_Operator_2   Operator_2  6.243626  1.5737396  0.84585963  1.01960000
#> T-26-0277_Operator_1   Operator_1  7.320327  1.4139146  0.80952526  0.83224134
#> T-26-0277_Operator_2   Operator_2  7.298711  1.4717597  0.81364053  0.85771439
#> T-26-0278-1_Operator_1 Operator_1  5.889839  1.3573901  0.62483966  0.84791016
#> T-26-0278-1_Operator_2 Operator_2  5.792278  1.3230123  0.61091969  0.87741051
#> T-26-0278-2_Operator_1 Operator_1  5.985832  1.0653645  0.60137447  0.58136232
#> T-26-0278-2_Operator_2 Operator_2  5.943979  1.0892998  0.60796448  0.61348550
#> T-26-0279_Operator_1   Operator_1  6.233187  1.3004547  1.37445662  0.94545918
#> T-26-0279_Operator_2   Operator_2  6.115752  1.3481306  1.37445662  0.93469408
#>                                 Mo         PFi       PFl         Ed        Jl
#> T-26-0001_Operator_1    0.89489033  0.74887664 1.3571782 0.35304739 0.3141390
#> T-26-0001_Operator_2    0.91630925  0.74976919 1.3421683 0.33565977 0.4084968
#> T-26-0002_Operator_1    1.06867215  0.86977177 1.5406889 0.38287629 0.5184372
#> T-26-0002_Operator_2    1.04827182  0.90873810 1.4602249 0.34405677 0.4487938
#> T-26-0003_Operator_1    0.80881935  0.71316923 1.2416526 0.36517494 0.4902852
#> T-26-0003_Operator_2    0.77681447  0.68516914 1.4002251 0.33559087 0.4491814
#> T-26-0004_Operator_1    2.48872580  1.30312261 3.0706500 0.77446974 0.9075409
#> T-26-0004_Operator_2    2.51429225  1.30646051 3.0181977 0.84133255 0.9065431
#> T-26-0005_Operator_1    0.80566515  0.62309150 0.9818339 0.27046813 0.4423693
#> T-26-0005_Operator_2    0.82527173  0.61598029 1.0853408 0.26134381 0.3446107
#> T-26-0006_Operator_1    0.85296195  0.88177356 1.3023562 0.37335909 0.5165191
#> T-26-0006_Operator_2    0.77314909  0.91054204 1.2126575 0.34889089 0.4290090
#> T-26-0007_Operator_1    2.55790654  1.80235146 3.5085919 0.87482800 1.4552358
#> T-26-0007_Operator_2    2.71425139  1.85419042 3.3737915 0.89604957 0.9653270
#> T-26-0008_Operator_1    2.60096767  1.60258937 2.4716972 0.70554624 1.1387038
#> T-26-0008_Operator_2    2.47822015  1.54145985 2.5145902 0.67198150 0.8010362
#> T-26-0009_Operator_1    1.24225715  0.94587064 1.0216666 0.51205283 0.3210083
#> T-26-0009_Operator_2    1.24952219  0.85749531 1.3915307 0.52415842 0.4281807
#> T-26-0010_Operator_1    1.37709223  0.71690429 1.7151405 0.35185898 0.5284874
#> T-26-0010_Operator_2    1.43178899  1.10961626 1.7116300 0.33329580 0.4853231
#> T-26-0011_Operator_1    5.05333121  2.74509028 4.7540294 1.01007139 2.1168580
#> T-26-0011_Operator_2    4.89376502  2.62586719 4.6498639 0.98826704 1.8148178
#> T-26-0012_Operator_1    0.59085979  0.58871830 1.4527794 0.31293136 0.4688812
#> T-26-0012_Operator_2    0.66455572  0.67223569 1.3071221 0.30997905 0.4130777
#> T-26-0013_Operator_1    0.88318584  0.76117261 1.6037205 0.43691643 0.6524061
#> T-26-0013_Operator_2    0.92426944  0.74701185 1.4788647 0.42178006 0.5522316
#> T-26-0014_Operator_1    1.18549544  1.17982255 1.9419989 0.35006280 0.5694982
#> T-26-0014_Operator_2    1.28512669  1.12271599 1.7437919 0.32540342 0.4691140
#> T-26-0015_Operator_1    0.90252299  0.94930026 1.7040126 0.34229099 0.5291597
#> T-26-0015_Operator_2    0.90015057  0.90386104 1.4868953 0.29916479 0.4724612
#> T-26-0016_Operator_1    1.54880037  1.32975506 2.0587947 0.58772448 0.8083894
#> T-26-0016_Operator_2    1.48587881  1.09073190 1.9438910 0.64275494 0.9522891
#> T-26-0017_Operator_1    0.65403196  0.63708998 1.5041843 0.28466129 0.4748494
#> T-26-0017_Operator_2    0.68130657  0.64589390 1.3683530 0.25497927 0.3989513
#> T-26-0018_Operator_1    3.94755566  2.45630553 3.5382196 0.95164946 1.0136353
#> T-26-0018_Operator_2    3.74558332  2.35895011 3.4195100 0.88376562 1.0892905
#> T-26-0019_Operator_1    1.65616013  1.03140475 2.1818256 0.74373115 0.6282757
#> T-26-0019_Operator_2    1.58916398  1.00302998 2.1373223 0.70084539 0.8233946
#> T-26-0020_Operator_1    1.42336918  1.32493115 1.8425853 0.39596127 0.5424703
#> T-26-0020_Operator_2    1.43121311  1.24100404 1.8913813 0.33313257 0.5127092
#> T-26-0021_Operator_1    0.96435058  0.99181424 1.8590928 0.63898700 0.4753667
#> T-26-0021_Operator_2    0.88749677  0.84530619 1.5534761 0.65622110 0.8717501
#> T-26-0022_Operator_1    1.67745924  0.94258427 2.0524048 0.67044113 0.6392783
#> T-26-0022_Operator_2    1.62375071  0.92608948 1.9687519 0.66913514 0.7569836
#> T-26-0023-2_Operator_1  0.43941300  0.22895104 0.9741679 0.28619375 0.4072843
#> T-26-0023-2_Operator_2  0.44722380  0.20281528 0.5413950 0.28058851 0.3176394
#> T-26-0024_Operator_1    1.36655063  1.18958516 1.6447189 0.30728145 0.5526650
#> T-26-0024_Operator_2    1.33905022  1.08139434 1.4166748 0.29977292 0.4686662
#> T-26-0025_Operator_1    1.46321555  1.33351716 1.9929660 0.32422744 0.4526759
#> T-26-0025_Operator_2    1.54123693  1.36954226 1.7702606 0.28264358 0.4163414
#> T-26-0026_Operator_1    1.44391579  0.90046998 1.9779864 0.48454672 0.7799872
#> T-26-0026_Operator_2    1.49825464  0.86785633 1.8145795 0.45835890 0.6883890
#> T-26-0027_Operator_1    1.94469811  1.35317782 1.9343852 0.44955766 0.6343375
#> T-26-0027_Operator_2    1.77951827  1.25741612 1.7964636 0.41033674 0.6486446
#> T-26-0028_Operator_1    1.08521010  0.97247912 1.3516274 0.32857973 0.4478013
#> T-26-0028_Operator_2    1.12415413  0.95316938 1.2689236 0.29557560 0.3804169
#> T-26-0029_Operator_1    0.66061237  0.58506254 1.0216666 0.35415383 0.4093744
#> T-26-0029_Operator_2    0.65831989  0.52280105 0.6518025 0.36542253 0.4789340
#> T-26-0030_Operator_1    2.15398429  1.21224700 2.2943736 0.66424335 0.7654466
#> T-26-0030_Operator_2    1.94469792  1.03865570 2.3701462 0.70150377 0.8667674
#> T-26-0031_Operator_1    1.16587322  0.97215211 1.4975270 0.35311241 0.5868150
#> T-26-0031_Operator_2    1.17232331  0.93055199 1.5038251 0.33986392 0.4689442
#> T-26-0032_Operator_1    5.27919142  2.98317119 5.0649982 1.03357431 1.3379604
#> T-26-0032_Operator_2    4.64272918  2.60311595 4.9632190 0.97335265 1.4283261
#> T-26-0033_Operator_1    1.57452040  1.32118805 1.8324657 0.41605839 0.4750978
#> T-26-0033_Operator_2    1.52411964  1.25957741 1.8287800 0.41152488 0.4131745
#> T-26-0034_Operator_1    1.38668060  1.28209685 1.7130311 0.39614482 0.5011719
#> T-26-0034_Operator_2    1.52285299  1.24705318 1.7396400 0.36777161 0.4859225
#> T-26-0035_Operator_1    0.88961927  0.66914311 1.1874279 0.28483050 0.4047512
#> T-26-0035_Operator_2    0.84892047  0.62246964 1.1777644 0.27586919 0.3906018
#> T-26-0036_Operator_1    2.16219518  1.33697618 2.1035961 0.71814770 0.7159875
#> T-26-0036_Operator_2    1.99307552  1.06806199 2.1304110 0.69427239 0.7167420
#> T-26-0037_Operator_1    2.73859762  1.77711639 3.1439850 0.77747788 0.8296678
#> T-26-0037_Operator_2    2.51345443  1.46778476 2.8955734 0.77363638 0.9686656
#> T-26-0038_Operator_1    1.02371234  0.94549656 1.4624606 0.29249449 0.4922926
#> T-26-0038_Operator_2    0.95613361  0.86003197 1.5489551 0.25049166 0.3814196
#> T-26-0039_Operator_1    1.18724500  0.76344261 1.1498481 0.48169820 0.3792569
#> T-26-0039_Operator_2    1.18195401  0.65392363 1.3913741 0.51158343 0.4693982
#> T-26-0040_Operator_1    1.14137435  0.99997655 1.8360659 0.37045819 0.6323202
#> T-26-0040_Operator_2    1.16235287  0.91695843 1.8403005 0.32593841 0.5602112
#> T-26-0041_Operator_1    0.77232983  0.73036875 1.4292887 0.32681788 0.4785252
#> T-26-0041_Operator_2    0.80586549  0.63666016 1.4533812 0.29735173 0.3980374
#> T-26-0042_Operator_1    1.32920371  1.02780954 2.0139522 0.41262037 0.5433299
#> T-26-0042_Operator_2    1.28244246  0.96698688 1.8525883 0.35782554 0.5255243
#> T-26-0043_Operator_1    0.64350880  0.73771034 1.7601271 0.41348298 0.4832472
#> T-26-0043_Operator_2    0.73889948  0.76119106 1.7975675 0.30419315 0.4048686
#> T-26-0044_Operator_1    1.37557563  1.21678061 1.8359927 0.42798152 0.4937488
#> T-26-0044_Operator_2    1.31590708  1.14820938 1.7696610 0.40659523 0.4584049
#> T-26-0045_Operator_1    1.86251732  1.18307922 2.6606648 0.67595224 0.7530524
#> T-26-0045_Operator_2    1.82784404  1.03105720 2.4334719 0.70972839 0.7875717
#> T-26-0046_Operator_1    1.17289864  1.11144133 1.9413411 0.37494105 0.4967074
#> T-26-0046_Operator_2    1.13080591  0.96825358 1.9213842 0.29673532 0.5897032
#> T-26-0047_Operator_1    5.49443483  3.49366083 5.1035153 0.86973302 1.1569351
#> T-26-0047_Operator_2    5.09847909  3.20831407 4.9375199 0.93701531 1.3141156
#> T-26-0048_Operator_1    1.05480266  1.20804466 1.6156628 0.32224579 0.5627273
#> T-26-0048_Operator_2    1.09342936  1.10475056 1.8292777 0.29042771 0.5101605
#> T-26-0049_Operator_1    1.71324814  1.01167002 2.2633024 0.69051370 0.7043522
#> T-26-0049_Operator_2    1.85453957  0.99854255 2.2111136 0.75169806 0.8467069
#> T-26-0050_Operator_1    1.09617894  0.96847207 1.6572127 0.29279849 0.4871916
#> T-26-0050_Operator_2    0.06188925  0.04343322 1.4006515 0.01791531 0.2508143
#> T-26-0051_Operator_1    1.58966604  1.24421578 2.1744593 0.41444289 0.6283662
#> T-26-0051_Operator_2    1.59664952  1.23032306 2.1620499 0.41464188 0.7006842
#> T-26-0052_Operator_1    3.39803006  0.55276962 1.1290314 0.27469233 4.0716062
#> T-26-0052_Operator_2    2.08821902  1.10096927 2.7000014 0.76984464 1.0379663
#> T-26-0053_Operator_1    2.14723477  1.22614176 2.7139476 0.69788999 0.8296945
#> T-26-0053_Operator_2    1.97647700  1.17380203 2.5809823 0.70837184 0.8287973
#> T-26-0054_Operator_1    2.17195527  1.28713454 2.4491505 0.68780757 0.7506219
#> T-26-0054_Operator_2    2.07462225  1.16812374 2.5610878 0.70840527 0.7519099
#> T-26-0055_Operator_1    1.57601313  1.37003756 1.9466903 0.47945785 0.5115428
#> T-26-0055_Operator_2    1.55642634  1.27273737 1.7686611 0.38876858 0.5341243
#> T-26-0056-2_Operator_1  1.91948876  1.47785363 2.0298051 0.52266256 0.6807006
#> T-26-0056-2_Operator_2  1.79200905  1.26358899 1.9606677 0.47026855 0.7227897
#> T-26-0057_Operator_1    1.23767209  1.06991858 1.6914708 0.27980683 0.5027355
#> T-26-0057_Operator_2    1.21145149  1.06937847 1.6359525 0.36670248 0.4125956
#> T-26-0058_Operator_1    1.67522698  1.24360976 2.0801927 0.46574697 0.6154796
#> T-26-0058_Operator_2    1.18032017  0.80418840 1.6265885 0.40259604 0.5295692
#> T-26-0059_Operator_1    1.54360345  1.21131985 0.8329248 0.34018607 0.5212983
#> T-26-0059_Operator_2    1.40198963  0.80418840 1.6265885 0.34596313 0.4652900
#> T-26-0060_Operator_1    1.15734043  0.96172531 1.7425274 0.33800795 0.5746917
#> T-26-0060_Operator_2    1.13123337  0.89123955 1.6335112 0.31350388 0.5242985
#> T-26-0061_Operator_1    2.45346204  1.23176834 2.3939069 0.75689551 0.8050211
#> T-26-0061_Operator_2    2.15607821  1.05604822 2.5626686 0.82359573 0.7867538
#> T-26-0062_Operator_1    2.90262484  1.51969366 3.3331083 0.87978825 1.1064440
#> T-26-0062_Operator_2    2.53914014  1.29418239 3.4885413 1.00116004 1.1302766
#> T-26-0063_Operator_1    1.16096169  0.99151697 1.4287984 0.33465972 0.4692763
#> T-26-0063_Operator_2    1.11287069  0.92371433 1.1981869 0.29809621 0.4141536
#> T-26-0064_Operator_1    0.96233793  0.94573132 1.8202765 0.38630372 0.5180883
#> T-26-0064_Operator_2    0.94387694  0.80889856 1.8979116 0.37156508 0.5396891
#> T-26-0065_Operator_1    1.49141693  1.00748069 1.5576676 0.45346736 0.5837907
#> T-26-0065_Operator_2    1.38955003  0.96859863 1.5515453 0.38677211 0.4764707
#> T-26-0067_Operator_1    1.49740891  1.06956639 1.8778103 0.34431892 0.5123565
#> T-26-0067_Operator_2    1.56135387  1.01844731 1.8475157 0.33983901 0.4994724
#> T-26-0068_Operator_1    1.56945476  1.08834576 1.9250632 0.68207462 0.4680862
#> T-26-0068_Operator_2    1.83118280  0.89682711 2.0197788 0.67400524 1.0209698
#> T-26-0069_Operator_1    1.24041383  0.57371902 1.4059721 0.43388302 0.4940410
#> T-26-0069_Operator_2    1.07957669  0.42108507 1.4888260 0.52135503 0.5467153
#> T-26-0070_Operator_1    1.32576288  0.68897247 1.4100550 0.53348055 0.6782875
#> T-26-0070_Operator_2    1.35046019  0.66248752 1.3849447 0.51496048 0.6877203
#> T-26-0071_Operator_1    1.11777343  0.79726891 1.7545520 0.28990578 0.3674879
#> T-26-0071_Operator_2    1.10255329  0.76866932 1.7294743 0.30489140 0.5138507
#> T-26-0072_Operator_1    1.39379547  0.99117535 1.9751873 0.39644021 0.7597339
#> T-26-0072_Operator_2    1.39718384  0.91377600 1.8084275 0.36744782 0.5151795
#> T-26-0073_Operator_1    1.65061732  1.19524539 1.9013395 0.41345556 0.6013497
#> T-26-0073_Operator_2    1.51317888  1.09291486 1.9732215 0.38202285 0.5462946
#> T-26-0074_Operator_1    1.13044367  1.03864732 2.0462477 0.39450351 0.6070726
#> T-26-0074_Operator_2    1.18027671  1.01448264 1.9553582 0.38320461 0.6037259
#> T-26-0075_Operator_1    2.07671029  1.63297393 1.9851945 0.49575558 0.6472792
#> T-26-0075_Operator_2    1.92953385  1.16607194 1.9608088 0.48309695 0.6568013
#> T-26-0076_Operator_1    2.02923814  0.96673351 2.0294772 0.64619674 0.4951869
#> T-26-0076_Operator_2    1.67174115  0.74383239 2.0005536 0.68831486 0.6841691
#> T-26-0077_Operator_1    0.75120319  0.61028019 1.2435845 0.34533131 0.2377478
#> T-26-0077_Operator_2    0.68165193  0.54063134 1.2338145 0.32255175 0.3678623
#> T-26-0078_Operator_1    1.08886123  0.89075319 1.9862341 0.43641259 0.6535970
#> T-26-0078_Operator_2    1.01208435  0.87158544 2.0337646 0.43940402 0.5956261
#> T-26-0079_Operator_1    1.27675005  0.93550441 1.4834435 0.41135491 0.5588320
#> T-26-0079_Operator_2    1.29763907  0.85108588 1.5106486 0.40660657 0.4855327
#> T-26-0080_Operator_1    1.00159385  0.50594336 1.0968826 0.47603729 0.4765894
#> T-26-0080_Operator_2    0.98836029  0.45044066 1.0490358 0.45928088 0.5289646
#> T-26-0081_Operator_1    0.57016822  0.46701065 1.1833056 0.33227344 0.3466291
#> T-26-0081_Operator_2    0.58280953  0.49659946 1.1448039 0.29208575 0.3781989
#> T-26-0082_Operator_1    1.48351791  0.78830667 1.5644288 0.51906017 0.2392996
#> T-26-0082_Operator_2    1.52597117  0.68644632 1.6278193 0.53696859 0.5609133
#> T-26-0083_Operator_1    0.82871496  0.66865253 1.1772954 0.27313211 0.3779979
#> T-26-0083_Operator_2    0.82642975  0.59255105 1.2021122 0.25154937 0.3887368
#> T-26-0084_Operator_1    0.90160562  0.71316920 1.2376895 0.36862398 0.4996879
#> T-26-0084_Operator_2    0.99618352  0.72841099 1.2322492 0.36444256 0.4789447
#> T-26-0085_Operator_1    1.10160150  0.79719179 1.7350736 0.35800383 0.6112334
#> T-26-0085_Operator_2    1.18140309  0.86271228 1.6116718 0.38408293 0.6080920
#> T-26-0086_Operator_1    1.46514875  1.07794175 1.8678994 0.40914308 0.6576322
#> T-26-0086_Operator_2    1.50685742  0.95839062 1.8276425 0.37892073 0.6952433
#> T-26-0087_Operator_1    1.42550275  1.02258322 1.6968310 0.39355949 0.5206477
#> T-26-0087_Operator_2    1.40098786  0.94761726 1.5834633 0.34809147 0.5306167
#> T-26-0088_Operator_1    0.89087028  0.86343853 1.6990085 0.38827083 0.4599713
#> T-26-0088_Operator_2    1.19194262  0.93312178 1.6379129 0.40141645 0.4092631
#> T-26-0089_Operator_1    0.39562420  0.20683394 0.2923484 0.25741844 0.4072843
#> T-26-0089_Operator_2    0.37859256  0.13948559 0.3330603 0.25291715 0.2777671
#> T-26-0090_Operator_1    0.58037499  0.42241343 0.6199527 0.26740010 0.4072843
#> T-26-0090_Operator_2    0.53404492  0.39987506 0.7016709 0.27573959 0.2683026
#> T-26-0091_Operator_1    1.23748928  0.77729032 1.6913150 0.31308479 0.5438174
#> T-26-0091_Operator_2    1.34742625  0.78082381 1.7716113 0.33776122 0.5827074
#> T-26-0092_Operator_1    1.17295805  0.88559604 1.5547705 0.41560754 0.5284779
#> T-26-0092_Operator_2    1.36138228  0.95226946 1.5981192 0.38236158 0.4731739
#> T-26-0093_Operator_1    1.43934188  1.01584189 1.4985562 0.40416181 0.5011183
#> T-26-0093_Operator_2    1.48408679  0.99495147 1.5946005 0.40998551 0.4547263
#> T-26-0094_Operator_1    0.97156360  0.74353151 1.3764721 0.35268059 0.3918740
#> T-26-0094_Operator_2    1.00443231  0.68358902 1.3615341 0.32474330 0.3722027
#> T-26-0095_Operator_1    0.90766514  0.82064358 1.6742417 0.35202581 0.4428063
#> T-26-0095_Operator_2    1.05288927  0.84733188 1.6568351 0.33647766 0.3870999
#> T-26-0096_Operator_1    0.77765839  0.75464199 1.1841566 0.27339032 0.4480082
#> T-26-0096_Operator_2    0.95768111  0.68706080 1.2075632 0.28364205 0.4025171
#> T-26-0097_Operator_1    1.13859838  0.84553531 1.9055686 0.36161617 0.8663626
#> T-26-0097_Operator_2    1.15154896  0.75830384 1.8480345 0.34506121 0.4686642
#> T-26-0098_Operator_1    1.15682275  0.81208111 1.4599957 0.42490168 0.5876444
#> T-26-0098_Operator_2    1.04016454  0.63671669 1.4132532 0.38293097 0.5259417
#> T-26-0099_Operator_1    0.43874751  0.28582741 0.3697782 0.29789761 0.3870888
#> T-26-0099_Operator_2    0.45138393  0.14292677 0.7553707 0.27986604 0.3589007
#> T-26-0100_Operator_1    0.86548165  0.65330832 1.1723034 0.27016768 0.1511832
#> T-26-0100_Operator_2    0.92573543  0.73250588 1.2681025 0.34538299 0.3507666
#> T-26-0101_Operator_1    1.23694759  0.95787375 1.4769617 0.29298585 0.2685223
#> T-26-0101_Operator_2    1.27154424  0.95814468 1.5250756 0.36337479 0.4148034
#> T-26-0102_Operator_1    1.25596398  0.58493426 1.7186693 0.35684633 7.5079027
#> T-26-0102_Operator_2    1.12142276  0.73174458 1.3554031 0.36515978 0.4251821
#> T-26-0103_Operator_1    1.51907468  0.64031242 2.1083910 0.58363088 0.6653315
#> T-26-0103_Operator_2    1.49528076  0.65414115 1.8186860 0.51484989 0.5722079
#> T-26-0104_Operator_1    1.30316643  0.81344249 1.8014609 0.53857514 0.6400121
#> T-26-0104_Operator_2    1.30388524  0.84539732 1.7963575 0.48395908 0.4713370
#> T-26-0107_Operator_1    1.55211701  0.96935812 1.6002662 0.60842629 0.3727630
#> T-26-0107_Operator_2    1.18032017  0.80418840 1.6265885 0.40259604 0.5295692
#> T-26-0108_Operator_1    0.76499647  0.52246815 2.0553892 0.39894756 0.7584422
#> T-26-0108_Operator_2    1.03287963  0.71477198 1.9177357 0.39257028 0.5255359
#> T-26-0109_Operator_1    1.30745429  1.92143722 1.7322581 0.00000000 0.6847351
#> T-26-0109_Operator_2    1.28679403  0.93454531 1.7231443 0.42804513 0.4837936
#> T-26-0111_Operator_1    0.28930111  0.17716354 1.1830072 0.16287272 0.1808627
#> T-26-0111_Operator_2    0.32352989  0.18947951 0.3798422 0.18612754 0.1368515
#> T-26-0112-2_Operator_1  0.78889343  0.59097291 1.1687621 0.34102676 0.3096387
#> T-26-0112-2_Operator_2  0.79835979  0.60746448 1.2117847 0.36217176 0.4182496
#> T-26-0112_Operator_1    0.47200451  0.35229595 0.6100681 0.23480605 0.3870888
#> T-26-0112_Operator_2    0.43884278  0.35357540 0.6182181 0.22123662 0.3870888
#> T-26-0113_Operator_1    0.44106940  0.44334855 1.3759575 0.31669336 0.5331575
#> T-26-0113_Operator_2    0.67859424  0.51487060 1.3832709 0.34173904 0.4584871
#> T-26-0114_Operator_1    0.97476734  0.77703696 1.4083986 0.37269954 0.3084577
#> T-26-0114_Operator_2    1.10923796  0.82018270 2.0213691 0.37642507 0.4402109
#> T-26-0115_Operator_1    1.01744585  0.84797296 2.1192550 0.41474689 0.4722676
#> T-26-0115_Operator_2    0.87886941  0.52883631 1.5678789 0.37650426 0.3352555
#> T-26-0116_Operator_1    0.92444200  0.56608094 1.5664673 0.38813413 0.4524785
#> T-26-0116_Operator_2    1.09660596  0.70820908 1.5959183 0.33154360 0.3961208
#> T-26-0117_Operator_1    1.02831257  0.79766724 1.6938219 0.32838208 0.6200159
#> T-26-0117_Operator_2    1.32098841  0.82430524 1.6308200 0.35579038 0.4030355
#> T-26-0118_Operator_1    1.28125480  0.82828532 1.7138154 0.38373797 0.4460225
#> T-26-0118_Operator_2    1.08447254  0.71981898 1.6322325 0.32184759 0.3999241
#> T-26-0120_Operator_1    0.95962484  0.68246846 1.3382559 0.29316999 0.4871104
#> T-26-0120_Operator_2    0.84722282  0.60549351 1.2518287 0.28454362 0.3321514
#> T-26-0121_Operator_1    1.00505768  0.65203616 1.4483889 0.42721977 0.4167373
#> T-26-0121_Operator_2   18.54166667 11.75000000 6.0000000 7.50000000 5.7083333
#> T-26-0122_Operator_1    1.09572967  0.84727801 1.9967863 0.36342383 0.7767666
#> T-26-0122_Operator_2    1.02037079  0.80849585 1.8983368 0.39762585 0.6085192
#> T-26-0123_Operator_1    0.89597693  0.62105853 1.7045562 0.38084397 0.4396152
#> T-26-0123_Operator_2    1.02856317  0.66274845 1.6530308 0.39284860 0.3575250
#> T-26-0125_Operator_1    0.83048986  0.47056664 1.4955752 0.38460657 0.5039151
#> T-26-0125_Operator_2    0.97964149  0.54221317 1.4079212 0.34888067 0.4000436
#> T-26-0126_Operator_1    1.05214463  0.70140867 1.3986442 0.35749104 0.5056193
#> T-26-0126_Operator_2    1.06254821  0.73533739 1.3302349 0.31627989 0.3359975
#> T-26-0127_Operator_1    1.37718799  1.04298015 1.8398135 0.50919781 0.4738615
#> T-26-0127_Operator_2    1.33385745  1.00407629 1.7344488 0.38726397 0.4359544
#> T-26-0128_Operator_1    0.66342367  0.63434265 1.2116350 0.37032082 0.4295619
#> T-26-0128_Operator_2    0.78662304  0.57953558 1.1562563 0.37453875 0.5492232
#> T-26-0130_Operator_1    0.52167266  0.46548164 0.8351162 0.31607735 0.2862719
#> T-26-0130_Operator_2    0.48737776  0.39382896 0.8405935 0.31314344 0.3342377
#> T-26-0131_Operator_1    1.23808221  0.92474939 1.5657946 0.40393083 0.5579866
#> T-26-0131_Operator_2    1.20767957  0.85693038 1.6651262 0.38347532 0.5199723
#> T-26-0132_Operator_1    1.37325973  1.02737316 1.8088123 0.39725096 0.6069332
#> T-26-0132_Operator_2    1.30923446  1.00875847 1.6842995 0.35605999 0.5262678
#> T-26-0133_Operator_1    0.64923465  0.86304144 1.8250010 0.66432123 0.6416771
#> T-26-0133_Operator_2    0.93768226  0.69303052 1.8524395 0.64582860 0.7568850
#> T-26-0134_Operator_1    1.30985126  0.90476654 1.6411247 0.44917529 0.5635258
#> T-26-0134_Operator_2    1.33235690  0.83393188 1.5896988 0.31863281 0.5309549
#> T-26-0135_Operator_1    0.69999185  0.76553010 1.7409794 0.62082813 0.7547213
#> T-26-0135_Operator_2    1.02048352  0.53671587 1.8711602 0.64505119 0.7242575
#> T-26-0136_Operator_1    1.31137149  0.92448775 1.7625783 0.41087217 0.4871382
#> T-26-0136_Operator_2    1.37969850  0.87184569 1.7830444 0.39322034 0.5571091
#> T-26-0137_Operator_1    2.13650395  1.16508785 2.7263705 0.82564956 0.6909041
#> T-26-0137_Operator_2    2.23220936  1.10450381 2.6728921 0.86306150 0.7225434
#> T-26-0138_Operator_1    1.05787234  0.74152780 1.7502041 0.39455782 0.6282305
#> T-26-0138_Operator_2    1.12544415  0.72945183 1.6478691 0.34930061 0.4479196
#> T-26-0139_Operator_1    1.22778224  0.80264680 1.7309018 0.44898957 0.4785937
#> T-26-0139_Operator_2    1.23141829  0.76327160 1.7028098 0.42104031 0.4682776
#> T-26-0140_Operator_1    0.95772648  0.58461559 1.3035875 0.38357278 0.5405312
#> T-26-0140_Operator_2    0.93400000  0.54723063 1.2460288 0.33681013 0.5295692
#> T-26-0141_Operator_1    1.26378499  0.81516448 1.6547478 0.43155108 0.4748445
#> T-26-0141_Operator_2    1.26509198  0.74829343 1.6749086 0.36560528 0.5065169
#> T-26-0142_Operator_1    0.91648303  0.62547890 1.4499866 0.39261592 0.4696423
#> T-26-0142_Operator_2    0.88665223  0.51871195 1.3843087 0.34092689 0.3995250
#> T-26-0143_Operator_1    1.12635963  0.58441382 1.3609304 0.53863226 0.2495543
#> T-26-0143_Operator_2    1.25736708  0.47449025 1.4005965 0.53548247 0.4185266
#> T-26-0144_Operator_1    1.03061786  0.58519220 1.6933311 0.68737785 0.4769916
#> T-26-0144_Operator_2    1.37547552  0.47326687 1.7859188 0.69630113 0.7570442
#> T-26-0145_Operator_1    0.46578062  0.22788591 0.3313965 0.26178213 0.2936343
#> T-26-0145_Operator_2    0.48781700  0.14849495 0.3313965 0.26116918 0.2936343
#> T-26-0146_Operator_1    1.69750133  1.17014074 2.0618277 0.46948714 0.6171036
#> T-26-0146_Operator_2    1.80131544  1.10163817 1.9765569 0.44601877 0.4925305
#> T-26-0147_Operator_1    1.57358376  1.18072770 1.9726283 0.52994174 0.7422911
#> T-26-0147_Operator_2    1.77940791  1.16158478 1.9097073 0.51325839 0.6860712
#> T-26-0148_Operator_1    2.00135172  1.19845887 2.6187162 0.85600618 0.7057742
#> T-26-0148_Operator_2    2.32519867  1.22650429 2.6430922 0.82916326 0.8894052
#> T-26-0149_Operator_1    4.45613040  2.48550152 4.6610643 1.18018202 0.9154846
#> T-26-0149_Operator_2    4.81529744  2.27228736 4.6842182 1.02101156 1.4805068
#> T-26-0150_Operator_1    2.09859855  1.60581487 3.1373845 0.68956951 1.2742445
#> T-26-0150_Operator_2    2.27122437  1.51173326 3.2137429 0.67560343 1.1452198
#> T-26-0151_Operator_1    1.16569761  0.66202617 2.1201530 0.42564186 0.5897905
#> T-26-0151_Operator_2    1.15934569  0.75065285 2.1000065 0.42765647 0.5111609
#> T-26-0152_Operator_1    0.36951435  0.23119210 1.6265885 0.20852848 0.5295692
#> T-26-0152_Operator_2    0.36561759  0.20259585 0.4330594 0.20135768 0.5295692
#> T-26-0153_Operator_1    0.77944075  0.45594314 1.6735357 0.41515054 0.5898829
#> T-26-0153_Operator_2    0.88667101  0.50323227 1.6267507 0.41418687 0.5485082
#> T-26-0154_Operator_1    0.90541736  0.57081221 1.3245165 0.40993114 0.4712445
#> T-26-0154_Operator_2    0.95467615  0.57626439 1.4466320 0.38959674 0.4530759
#> T-26-0155_Operator_1    0.57404021  0.37809143 1.1021899 0.30051051 0.3714060
#> T-26-0155_Operator_2    0.60478165  0.36666508 1.0732178 0.27332032 0.3103235
#> T-26-0156_Operator_1    3.09134931  1.56765741 3.4591436 1.00027384 0.7460718
#> T-26-0156_Operator_2    3.52495325  1.48358018 3.3637998 0.95413513 1.1742310
#> T-26-0157_Operator_1    1.27532133  0.74789773 2.0377549 0.37418056 0.5610752
#> T-26-0157_Operator_2    1.30297386  0.74608987 1.8698796 0.38125659 0.5626915
#> T-26-0158_Operator_1    1.24507587  0.71134532 1.6106631 0.44291312 0.5237223
#> T-26-0158_Operator_2    1.32813715  0.70855925 1.5814370 0.42534176 0.4989785
#> T-26-0159_Operator_1    1.11241259  0.64865615 2.0269034 0.38529299 0.5968666
#> T-26-0159_Operator_2    1.11483905  0.63137449 1.9376328 0.39890924 0.5574770
#> T-26-0160_Operator_1    0.97811360  0.74758783 1.8198314 0.49435932 0.4114460
#> T-26-0160_Operator_2    0.99662343  0.68582527 1.7374832 0.39134365 0.4265857
#> T-26-0161_Operator_1    0.96328486  0.77995798 1.7599637 0.39331117 0.4779793
#> T-26-0161_Operator_2    1.18045334  0.76946218 1.6843952 0.37613892 0.3915056
#> T-26-0162_Operator_1    1.03026030  0.79860865 1.5367332 0.42294608 0.4396235
#> T-26-0162_Operator_2    1.12852170  0.76974202 1.4738128 0.33555420 0.3930051
#> T-26-0163_Operator_1    1.08448657  0.62666667 1.9140765 0.45338235 0.5594640
#> T-26-0163_Operator_2    1.09428113  0.64199519 1.9626074 0.42090158 0.4830145
#> T-26-0164_Operator_1    0.39757583  0.27841333 0.9141268 0.28278287 0.3429676
#> T-26-0164_Operator_2    0.43555390  0.30646803 0.8430016 0.24568191 0.2848364
#> T-26-0165_Operator_1    1.04680269  0.65515874 1.6052070 0.41718922 0.4548932
#> T-26-0165_Operator_2    1.15233179  0.66757535 1.6112125 0.38969241 0.3944191
#> T-26-0166_Operator_1    0.47479807  0.32099970 0.8996614 0.24417186 0.3288444
#> T-26-0166_Operator_2    0.50513412  0.32900374 0.8536298 0.23036949 0.3397496
#> T-26-0167_Operator_1    4.47517978  2.06820622 4.9419416 1.38802185 1.3709551
#> T-26-0167_Operator_2    4.73389358  2.05247526 4.7053834 1.31408684 1.5838309
#> T-26-0168_Operator_1    1.29693769  0.78942028 1.8497799 0.47613992 0.5218201
#> T-26-0168_Operator_2    1.30615862  0.81578524 1.6802366 0.44312228 0.4396708
#> T-26-0169_Operator_1    1.49708293  0.81106415 2.1131480 0.50041072 0.7455278
#> T-26-0169_Operator_2    2.71901077  1.55522649 4.2240358 0.95930233 1.2810266
#> T-26-0170_Operator_1    1.45431226  0.79461516 1.9492449 0.45542760 0.5649041
#> T-26-0170_Operator_2    1.48393551  0.74252886 1.8532452 0.44944179 0.5756702
#> T-26-0171_Operator_1    1.49317071  0.73810544 2.0210731 0.46970346 0.6944982
#> T-26-0171_Operator_2    1.53102332  0.80379201 1.8979906 0.44592384 0.6307252
#> T-26-0172_Operator_1    1.14624292  0.57805734 1.9413004 0.50321510 0.5994410
#> T-26-0172_Operator_2    1.14030929  0.61547302 1.9368500 0.50413554 0.6269670
#> T-26-0173_Operator_1    1.10034485  0.54509960 1.1544633 0.40098355 0.5809544
#> T-26-0173_Operator_2    1.05556286  0.58066965 1.3105541 0.38205909 0.3858349
#> T-26-0174_Operator_1    1.37976009  0.83216686 1.6253037 0.41612402 0.4882082
#> T-26-0174_Operator_2    1.40118790  0.77496201 1.5413558 0.38577549 0.3684738
#> T-26-0175_Operator_1    1.27849910  0.66444846 1.9128146 0.40273142 0.4400099
#> T-26-0175_Operator_2    1.28898582  0.63946848 1.8555608 0.41092825 0.3911753
#> T-26-0176_Operator_1    1.13845468  0.75668767 1.5805614 0.41888067 0.6526760
#> T-26-0176_Operator_2    1.21415128  0.76586585 1.5570886 0.44460612 0.6520168
#> T-26-0177_Operator_1    1.65110058  1.03331550 1.8525810 0.51427828 0.5973829
#> T-26-0177_Operator_2    1.67688525  1.03191306 1.8095329 0.51477714 0.5993567
#> T-26-0178_Operator_1    1.38222725  0.73557648 2.0775078 0.46362346 0.5083617
#> T-26-0178_Operator_2    1.40330809  0.72255802 1.9375593 0.43545240 0.4960975
#> T-26-0179-3_Operator_1  1.22506356  0.80233774 1.7499735 0.50204681 0.4939318
#> T-26-0179-3_Operator_2  1.31588369  0.72215564 1.6927206 0.46069936 0.5518222
#> T-26-0179_Operator_1    0.55891871  0.37331857 0.7474939 0.32887366 0.3105607
#> T-26-0179_Operator_2    0.59829058  0.37497161 0.7164019 0.29823348 0.2260697
#> T-26-0180_Operator_1    1.25399089  0.74569564 1.8098409 0.51526383 0.5071279
#> T-26-0180_Operator_2    1.30748784  0.77127710 1.7205466 0.47876058 0.5089066
#> T-26-0181_Operator_1    1.23955998  0.65743078 1.6951960 0.49083469 0.5810812
#> T-26-0181_Operator_2    1.23028075  0.67144757 1.6067623 0.45065789 0.4677650
#> T-26-0182_Operator_1    1.01668471  0.47128119 1.7386097 0.39995652 0.5609361
#> T-26-0182_Operator_2    1.00425174  0.49511921 1.6613910 0.32939553 0.5221259
#> T-26-0183_Operator_1    1.09606298  0.62635425 2.0524639 0.55972881 0.6699678
#> T-26-0183_Operator_2    1.11287006  0.71773476 1.9019272 0.52838079 0.5296090
#> T-26-0184_Operator_1    1.34137093  0.96798600 1.9138480 0.73291731 0.6432320
#> T-26-0184_Operator_2    1.35852499  0.66959169 1.6733664 0.66732230 0.7507929
#> T-26-0185_Operator_1    0.90769467  0.48650475 1.3703162 0.38473934 0.5026215
#> T-26-0185_Operator_2    0.87109136  0.47461450 1.3109198 0.33533617 0.3615955
#> T-26-0186_Operator_1    1.48935550  0.77968092 1.9759486 0.49990010 0.5921612
#> T-26-0186_Operator_2    1.55992046  0.75253917 1.9173256 0.52542462 0.6067416
#> T-26-0187_Operator_1    1.34118214  0.64903484 2.2884840 0.49647353 0.6240112
#> T-26-0187_Operator_2    1.37413645  0.68849921 2.0650409 0.45754782 0.5747221
#> T-26-0188_Operator_1    0.63060597  0.53349472 1.2406975 0.23114716 0.4371280
#> T-26-0188_Operator_2    0.62685530  0.55963671 1.3050264 0.20528354 0.3585239
#> T-26-0189_Operator_1    1.20995988  0.71804104 1.5505552 0.42814604 0.5755045
#> T-26-0189_Operator_2    1.14271641  0.70649571 1.6238506 0.39441189 0.3877312
#> T-26-0190_Operator_1    0.99804319  0.57627142 1.8817531 0.49507319 0.6325312
#> T-26-0190_Operator_2    0.97396959  0.49631022 1.8395520 0.43354598 0.5491635
#> T-26-0191_Operator_1    1.12123439  0.56928790 1.6712928 0.47126019 0.6046321
#> T-26-0191_Operator_2    1.12417934  0.57098496 1.6106552 0.41822902 0.5631919
#> T-26-0192_Operator_1    1.04566281  0.63522784 1.8183212 0.41139467 0.5388809
#> T-26-0192_Operator_2    1.06332695  0.63469048 1.7509180 0.37967617 0.5007292
#> T-26-0193_Operator_1    1.52072962  0.81418070 1.5232833 0.44776007 0.5855988
#> T-26-0193_Operator_2    1.52849805  0.88247112 1.5299589 0.39540036 0.4475567
#> T-26-0194_Operator_1    1.90794976  1.21867372 2.1248661 0.51277528 0.7554993
#> T-26-0194_Operator_2    1.96886122  1.18856381 1.9385909 0.43708169 0.6666753
#> T-26-0195_Operator_1    1.16892570  0.59099223 1.9539009 0.52510002 0.5133692
#> T-26-0195_Operator_2    1.22473675  0.60533178 1.9142249 0.42989961 0.5051615
#> T-26-0196_Operator_1    0.83309243  0.34157849 1.2992435 0.41170742 0.4142519
#> T-26-0196_Operator_2    0.87428525  0.41699518 1.2896523 0.38433976 0.4429503
#> T-26-0197_Operator_1    1.35124546  0.69075260 1.8154242 0.48664089 0.5497112
#> T-26-0197_Operator_2    1.30626356  0.74872050 1.8556002 0.49211988 0.4957135
#> T-26-0198_Operator_1    1.19574133  0.71268232 1.4852297 0.48618322 0.5840770
#> T-26-0198_Operator_2    1.19827325  0.71588844 1.5475114 0.41609367 0.5616308
#> T-26-0199_Operator_1    0.65032268  0.45633009 1.1930113 0.19318444 0.3796212
#> T-26-0199_Operator_2    0.58192659  0.46699961 1.1314433 0.15930702 0.2365680
#> T-26-0200_Operator_1    1.39807082  1.01471332 1.7108162 0.48738588 0.5156327
#> T-26-0200_Operator_2    1.50024260  0.94355639 1.7779299 0.42313519 0.5097908
#> T-26-0201_Operator_1    0.91080842  0.52176211 1.5403679 0.43847971 0.4739839
#> T-26-0201_Operator_2    0.90149798  0.57782187 1.4438951 0.40145861 0.4145701
#> T-26-0202_Operator_1    0.97739546  1.12420149 2.2328896 0.74058881 0.8937692
#> T-26-0202_Operator_2    1.19167354  0.83640092 2.1509872 0.64354679 1.0081444
#> T-26-0203_Operator_1    1.17111409  0.62436941 1.6849489 0.42793158 0.5379585
#> T-26-0203_Operator_2    1.10575422  0.59171985 1.6112486 0.37042637 0.4806165
#> T-26-0204_Operator_1    1.00286566  0.57489363 1.9540903 0.45078710 0.5516933
#> T-26-0204_Operator_2    1.00281000  0.62841232 1.7986907 0.41302332 0.4779014
#> T-26-0205_Operator_1    1.10857585  0.72381233 1.5656090 0.46048363 0.4298443
#> T-26-0205_Operator_2    1.10107068  0.73639503 1.4802236 0.43213670 0.3343871
#> T-26-0206_Operator_1    0.85088839  0.56508723 1.5824366 0.41296750 0.5279214
#> T-26-0206_Operator_2    0.84733560  0.56914117 1.4032833 0.36654760 0.4039247
#> T-26-0207_Operator_1    0.61273749  0.43414891 1.3098587 0.32009031 0.3949563
#> T-26-0207_Operator_2    0.62391500  0.42847109 1.2344209 0.26619123 0.3305180
#> T-26-0208_Operator_1    0.65114769  0.45798863 1.2821715 0.20261623 0.3668108
#> T-26-0208_Operator_2    0.65490605  0.49726626 1.4417030 0.15233927 0.2798919
#> T-26-0209_Operator_1    1.39633554  0.95635583 1.8863343 0.49122456 0.5830526
#> T-26-0209_Operator_2    1.45699599  0.83231026 1.9514264 0.46109523 0.5943812
#> T-26-0210_Operator_1    0.62620999  0.34752656 0.8183221 0.34423269 0.3153071
#> T-26-0210_Operator_2    0.65278352  0.29560866 0.8333186 0.30846584 0.2595998
#> T-26-0211_Operator_1    1.05571339  0.66438725 1.4869249 0.37496757 0.4958174
#> T-26-0211_Operator_2    1.05367315  0.67886186 1.4654562 0.33926367 0.3859855
#> T-26-0212_Operator_1    0.80431123  0.37488955 1.2765070 0.39592536 0.4399292
#> T-26-0212_Operator_2    0.77239649  0.42837158 1.1913589 0.34498537 0.4029324
#> T-26-0213_Operator_1    1.16471303  0.56445216 1.3226731 0.41905006 0.4815068
#> T-26-0213_Operator_2    1.17937887  0.64992646 1.3801268 0.37598373 0.3784277
#> T-26-0214_Operator_1    1.88021814  0.84209875 2.2107112 0.66838829 0.6048622
#> T-26-0214_Operator_2    1.90196282  0.96379233 2.1501490 0.67056880 0.5603791
#> T-26-0215_Operator_1    1.16463915  0.66187910 1.6010172 0.41198017 0.4682769
#> T-26-0215_Operator_2    1.17196439  0.69576367 1.5114789 0.35475746 0.3368139
#> T-26-0216_Operator_1    1.13761018  0.60886178 1.4469641 0.36531707 0.4248397
#> T-26-0216_Operator_2    1.16678387  0.66373695 1.4390191 0.34463063 0.3496519
#> T-26-0217_Operator_1    1.08285766  0.41726035 1.9441385 0.46878528 0.6918708
#> T-26-0217_Operator_2    1.07566393  0.48064269 1.8418349 0.40509227 0.5070143
#> T-26-0218_Operator_1    0.59998571  0.49570761 1.1751555 0.19574461 0.4275490
#> T-26-0218_Operator_2    0.59873581  0.43402237 1.3450401 0.17994750 0.2886943
#> T-26-0219_Operator_1    0.74034947  0.43623503 0.9211762 0.28854941 0.2984846
#> T-26-0219_Operator_2    0.75942102  0.41680493 0.8824022 0.24622288 0.2665267
#> T-26-0220_Operator_1    0.71477893  0.47892786 1.3413517 0.34439356 0.4962232
#> T-26-0220_Operator_2    0.69197190  0.49527384 1.2213921 0.31032247 0.4141562
#> T-26-0221_Operator_1    1.04923576  0.37431358 0.8763393 0.52696657 0.1794037
#> T-26-0221_Operator_2    1.05161341  0.39741417 1.1357024 0.51002756 0.3046628
#> T-26-0222_Operator_1    1.96340112  0.78822398 3.3745859 1.00167993 1.2315004
#> T-26-0222_Operator_2    2.12082274  0.84359285 3.6416051 1.06255268 1.2661727
#> T-26-0223_Operator_1    1.54171858  0.88281914 1.7407626 0.51930537 0.5645767
#> T-26-0223_Operator_2    1.54522710  0.93432127 1.8308515 0.51944063 0.5559612
#> T-26-0224_Operator_1    1.07456357  0.71420266 2.0841112 0.40261406 0.5174085
#> T-26-0224_Operator_2    0.99462772  0.65409730 2.0340292 0.37529012 0.3216723
#> T-26-0225_Operator_1    1.60081069  0.70782199 1.9962120 0.73388115 0.5787059
#> T-26-0225_Operator_2    1.53574060  0.64851966 2.0171032 0.67243678 0.5717007
#> T-26-0226_Operator_1    0.51612837  0.39354020 0.7839078 0.35483133 0.2165094
#> T-26-0226_Operator_2    0.52910483  0.33664992 0.8476074 0.32784489 0.2097156
#> T-26-0227_Operator_1    0.97447889  0.32745471 1.3189114 0.54707112 0.3711530
#> T-26-0227_Operator_2    1.03219266  0.23304752 1.3484787 0.50186632 0.5914446
#> T-26-0228_Operator_1    1.14371004  0.46245712 1.5967962 0.51900420 0.3151778
#> T-26-0228_Operator_2    1.13556269  0.39733208 1.4649202 0.49198522 0.5316171
#> T-26-0229_Operator_1    1.01656995  0.66013324 1.9265707 0.57505286 0.6356646
#> T-26-0229_Operator_2    0.97843307  0.71141854 1.9639867 0.54566002 0.6683721
#> T-26-0230-1_Operator_1  0.65424338  0.50932160 1.4255353 0.19345870 0.5346862
#> T-26-0230-1_Operator_2 14.78571429 11.28571429 2.7142857 3.46428571 0.9642857
#> T-26-0230-2_Operator_1  0.37788690  0.30608313 1.4134916 0.17421392 0.4297743
#> T-26-0230-2_Operator_2  0.39314069  0.34049972 1.3129773 0.14768377 0.2264480
#> T-26-0230-3_Operator_1  0.50980282  0.30029965 1.2717880 0.21140772 0.4545539
#> T-26-0230-3_Operator_2  0.50336471  0.31211277 1.3530797 0.20061610 0.2428629
#> T-26-0230-4_Operator_1  0.65324909  0.50858046 1.2651412 0.21337215 0.4558231
#> T-26-0230-4_Operator_2  0.63770687  0.54188042 1.2130640 0.17338400 0.2803835
#> T-26-0231_Operator_1    0.54540466  0.39832358 1.3453008 0.18589120 0.4922311
#> T-26-0231_Operator_2    0.53845059  0.43642219 1.2683511 0.18205810 0.4268692
#> T-26-0232_Operator_1    0.66437686  0.54923514 1.2630361 0.21708790 0.3504884
#> T-26-0232_Operator_2    0.73649242  0.60077692 1.2430980 0.14167091 0.2963734
#> T-26-0233_Operator_1    1.04462046  0.75248086 1.2957291 0.29240182 0.3844492
#> T-26-0233_Operator_2    0.65591276  0.53105499 1.0044948 0.17754705 0.2914795
#> T-26-0234_Operator_1    2.81861504  1.24136099 3.2357406 0.90196009 0.8574090
#> T-26-0234_Operator_2    2.80861959  1.24308305 3.1746314 0.90547806 0.6560534
#> T-26-0235_Operator_1    1.06658894  0.44057474 0.9735126 0.49044458 0.2979985
#> T-26-0235_Operator_2    1.04940373  0.43571191 1.0667255 0.46280881 0.2999464
#> T-26-0236_Operator_1    2.14712171  0.84958157 2.6929018 0.91595122 0.7561259
#> T-26-0236_Operator_2    2.18449550  0.89092407 2.5132647 0.81264778 0.8475999
#> T-26-0237_Operator_1    2.08066647  0.85836937 2.6636192 0.82297482 0.7084239
#> T-26-0237_Operator_2    2.10308829  0.82904383 2.4745352 0.83060856 0.9459992
#> T-26-0238_Operator_1    1.49333827  0.66894662 2.0470459 0.64925370 0.4398730
#> T-26-0238_Operator_2    1.57347951  0.68604010 2.0753058 0.71873837 0.3881104
#> T-26-0239_Operator_1    1.18386821  0.99404402 1.5136591 0.72488839 0.6525848
#> T-26-0239_Operator_2    1.17636948  0.15254474 2.1669605 0.63915629 0.6381912
#> T-26-0240_Operator_1    1.07868766  0.47603201 1.0817543 0.43147996 0.3402350
#> T-26-0240_Operator_2    1.06573783  0.45954773 1.0355680 0.40580571 0.2727971
#> T-26-0241_Operator_1    0.55382169  0.30341121 0.7749065 0.32634274 0.3352962
#> T-26-0241_Operator_2    0.57598805  0.29849153 0.8277468 0.27150657 0.2047270
#> T-26-0242_Operator_1    2.86337392  1.34018386 2.6095346 0.91813310 0.8058141
#> T-26-0242_Operator_2    2.78933431  1.44983285 2.7076427 0.74523084 0.5510857
#> T-26-0243_Operator_1    0.62626384  0.31834075 0.5025614 0.37022227 0.4072843
#> T-26-0243_Operator_2    0.61299772  0.28312780 0.6218678 0.35169993 0.3087071
#> T-26-0244_Operator_1    0.46591387  0.26160274 0.9741679 0.24565178 0.4072843
#> T-26-0244_Operator_2    0.47338326  0.17135709 0.4646828 0.21874473 0.2506922
#> T-26-0245_Operator_1    0.83666866  0.33334815 0.9329054 0.50337468 0.2092302
#> T-26-0245_Operator_2    0.92486850  0.32433093 0.8572459 0.44136989 0.3426519
#> T-26-0246_Operator_1    0.90818858  0.32386315 0.9138203 0.48060936 0.2992697
#> T-26-0246_Operator_2    0.94702540  0.32970798 0.9891673 0.45251446 0.2640474
#> T-26-0247_Operator_1    0.51548776  0.26214909 0.8334120 0.31503569 0.3011354
#> T-26-0247_Operator_2    0.45657597  0.21446292 0.8430318 0.27554343 0.2898066
#> T-26-0248_Operator_1    0.43008693  0.15741371 0.4076571 0.21504060 0.2392820
#> T-26-0248_Operator_2    0.43779791  0.10231234 0.4225775 0.24544538 0.2441442
#> T-26-0249_Operator_1    0.42165583  0.17228589 0.4106802 0.27162431 0.2436490
#> T-26-0249_Operator_2    0.41543453  0.11737304 0.3791004 0.26549880 0.2320982
#> T-26-0250_Operator_1    0.48100611  0.23777752 0.3611692 0.27296152 0.1838095
#> T-26-0250_Operator_2    0.50691290  0.18332159 0.3917656 0.26948539 0.1739732
#> T-26-0251_Operator_1    0.49832927  0.32048021 0.8569294 0.29744903 0.3245761
#> T-26-0251_Operator_2    0.53720868  0.35740693 0.8120889 0.27069603 0.3395488
#> T-26-0252_Operator_1    0.37912321  0.19087001 0.5778989 0.25719912 0.1497566
#> T-26-0252_Operator_2    0.38794716  0.08855067 0.6409236 0.23507771 0.2071919
#> T-26-0261-1_Operator_1  0.99424220  0.77956742 2.1859352 0.35791341 0.7287484
#> T-26-0261-1_Operator_2  1.07907389  0.80474724 2.2016044 0.33135900 0.5476256
#> T-26-0261-2_Operator_1  1.27891375  0.92676017 1.8828159 0.41478989 0.6933126
#> T-26-0261-2_Operator_2  1.23145738  0.64853706 1.9604526 0.37325455 0.5913947
#> T-26-0261-3_Operator_1  1.41453169  0.76515933 1.6612556 0.36673120 0.5545724
#> T-26-0261-3_Operator_2  1.35400779  0.75017996 1.4980387 0.38429814 0.3610260
#> T-26-0261-4_Operator_1  0.98694869  0.50957400 1.3066810 0.36121432 0.4950245
#> T-26-0261-4_Operator_2  1.02893237  0.50885237 1.2284369 0.29181906 0.4429458
#> T-26-0261-5_Operator_1  1.31293175  0.54545272 1.8428619 0.34766362 0.6839897
#> T-26-0261-5_Operator_2  1.35026187  0.58080972 1.7761817 0.36877878 0.6478548
#> T-26-0262-1_Operator_1  1.01308992  0.62343357 1.4744468 0.41266819 0.4469410
#> T-26-0262-1_Operator_2  1.06753668  0.68249693 1.5593549 0.36270217 0.5295692
#> T-26-0262-2_Operator_1  1.22722719  0.78705776 1.3347221 0.36109563 0.3809096
#> T-26-0262-2_Operator_2  1.20758519  0.71253455 1.3738320 0.36317692 0.4323511
#> T-26-0263_Operator_1    0.33117490  0.28938703 0.7108980 0.27715268 0.2845440
#> T-26-0263_Operator_2    0.33902823  0.20079156 0.6839560 0.24851926 0.2185070
#> T-26-0264-1_Operator_1  0.41999345  0.31102910 0.9098239 0.26856589 0.3467906
#> T-26-0264-1_Operator_2  0.36969742  0.29873447 0.6347761 0.24692125 0.2076427
#> T-26-0264-2_Operator_1  0.43837449  0.25206315 0.6391976 0.28041253 0.3681865
#> T-26-0264-2_Operator_2  0.45697410  0.22813365 0.6842708 0.25103966 0.2611183
#> T-26-0264-3_Operator_1  0.53486887  0.25032746 0.7972604 0.24611109 0.3590712
#> T-26-0264-3_Operator_2  0.51076847  0.20621551 0.8954858 0.23983074 0.3691504
#> T-26-0264-4_Operator_1  0.25544630  0.23874204 0.6242245 0.26829381 0.2590520
#> T-26-0264-4_Operator_2  0.29007898  0.18667089 0.5470114 0.26252610 0.1712749
#> T-26-0265_Operator_1    1.38055835  0.65192024 1.3583078 0.58357138 0.7686066
#> T-26-0265_Operator_2    1.37843346  0.49422899 1.4787695 0.55024928 0.6294201
#> T-26-0266_Operator_1    3.40458062  1.56881602 4.0784015 1.02242346 1.4374242
#> T-26-0266_Operator_2    3.27445249  1.38585372 4.2207100 1.01745140 1.3056970
#> T-26-0267_Operator_1    4.11409055  2.11868306 4.3351966 1.11981856 1.4368203
#> T-26-0267_Operator_2    4.17766885  1.86696709 4.3489138 1.15699369 1.0019104
#> T-26-0268_Operator_1    0.92011977  0.42160157 1.3826433 0.45185160 0.4182984
#> T-26-0268_Operator_2    0.97325813  0.39803949 1.2562755 0.42727464 0.4173573
#> T-26-0269_Operator_1    1.00803734  0.55001838 1.3065135 0.47999279 0.7618184
#> T-26-0269_Operator_2    1.16000507  0.52531223 1.2117464 0.43699509 0.7263527
#> T-26-0270-1_Operator_1  1.54978550  0.82987215 2.0703684 0.72324057 0.9454317
#> T-26-0270-1_Operator_2  1.60812305  0.69146000 2.1342190 0.62940434 1.1270447
#> T-26-0270-2_Operator_1  1.70199173  0.66836448 2.2068322 0.68831087 1.1332390
#> T-26-0270-2_Operator_2  1.76529053  0.79495891 2.2839159 0.69969558 1.0694007
#> T-26-0271_Operator_1    1.28707456  1.05612453 1.4288417 0.70018464 0.9437855
#> T-26-0271_Operator_2    1.27971713  0.13676711 1.9600977 0.65449873 1.2271158
#> T-26-0272_Operator_1    0.62500000  0.34551704 1.4820194 0.26374947 0.3822552
#> T-26-0272_Operator_2    0.70749356  0.38210986 1.3993141 0.22749323 0.3727187
#> T-26-0273_Operator_1    1.05186529  0.43996089 1.4668393 0.54807941 0.6778086
#> T-26-0273_Operator_2    1.17163552  0.46140110 1.4977092 0.52368515 0.6130181
#> T-26-0274_Operator_1    0.73472825  0.52670069 1.2431572 0.22561543 0.4288991
#> T-26-0274_Operator_2    0.74046412  0.48127522 1.3150777 0.17242980 0.3296068
#> T-26-0275_Operator_1    0.63842637  0.41817531 1.4296359 0.19427088 0.3611908
#> T-26-0275_Operator_2    0.65770747  0.37391143 1.2887249 0.17111278 0.4098693
#> T-26-0276_Operator_1    0.76873760  0.52359585 1.0499575 0.34284948 0.5673048
#> T-26-0276_Operator_2    0.79456636  0.55321089 1.0213977 0.34111700 0.4341671
#> T-26-0277_Operator_1    0.85573384  0.30649766 1.1166362 0.36779720 0.4560666
#> T-26-0277_Operator_2    0.85624224  0.39561356 1.1290499 0.33768957 0.3844492
#> T-26-0278-1_Operator_1  0.86401663  0.41056703 1.0048873 0.20547745 0.2735921
#> T-26-0278-1_Operator_2  0.88155297  0.47729830 1.0907479 0.17349314 0.3844492
#> T-26-0278-2_Operator_1  0.44507228  0.23227747 1.1752007 0.20551839 0.4002435
#> T-26-0278-2_Operator_2  0.46467053  0.25906856 1.1282148 0.13863854 0.2873251
#> T-26-0279_Operator_1    0.73406409  0.64568390 1.1053879 0.20927980 0.4565335
#> T-26-0279_Operator_2    0.70631205  0.56038309 1.2345728 0.13925098 0.3074775
#>                                CPd        CFd
#> T-26-0001_Operator_1    0.74661661  2.3881553
#> T-26-0001_Operator_2    0.88204160  2.3555187
#> T-26-0002_Operator_1    0.86744898  2.9887710
#> T-26-0002_Operator_2    0.84131281  2.9463784
#> T-26-0003_Operator_1    0.84316511  1.6661061
#> T-26-0003_Operator_2    0.75136772  1.6219693
#> T-26-0004_Operator_1    1.98212136  6.9970171
#> T-26-0004_Operator_2    1.92616619  6.9441999
#> T-26-0005_Operator_1    0.67852772  1.3777322
#> T-26-0005_Operator_2    0.60294313  1.3602311
#> T-26-0006_Operator_1    0.75898188  2.8119275
#> T-26-0006_Operator_2    0.82683299  2.8132208
#> T-26-0007_Operator_1    2.04786778  6.6249103
#> T-26-0007_Operator_2    2.00595819  6.7471584
#> T-26-0008_Operator_1    1.57519468  5.1621230
#> T-26-0008_Operator_2    1.48020167  5.1817373
#> T-26-0009_Operator_1    0.79557461  2.4649486
#> T-26-0009_Operator_2    0.79387286  2.4462978
#> T-26-0010_Operator_1    0.89507494  3.2100664
#> T-26-0010_Operator_2    0.85906212  3.1779213
#> T-26-0011_Operator_1    2.69358908  6.4940660
#> T-26-0011_Operator_2    2.64979636  6.7154595
#> T-26-0012_Operator_1    0.64992797  2.3813561
#> T-26-0012_Operator_2    0.62490733  2.3480907
#> T-26-0013_Operator_1    0.87018717  3.0692624
#> T-26-0013_Operator_2    0.85918646  3.1755699
#> T-26-0014_Operator_1    0.87995790  3.2781578
#> T-26-0014_Operator_2    0.87361926  3.2468369
#> T-26-0015_Operator_1    0.83986095  3.2807552
#> T-26-0015_Operator_2    0.82078919  3.1747721
#> T-26-0016_Operator_1    0.91906871  3.7056342
#> T-26-0016_Operator_2    0.86026901  3.5868047
#> T-26-0017_Operator_1    0.72855360  2.6726891
#> T-26-0017_Operator_2    0.70414033  2.6121760
#> T-26-0018_Operator_1    2.14607318  6.4822496
#> T-26-0018_Operator_2    2.06087815  6.3293571
#> T-26-0019_Operator_1    1.41393476  4.4712612
#> T-26-0019_Operator_2    1.38760649  4.4044201
#> T-26-0020_Operator_1    0.95642433  3.4848776
#> T-26-0020_Operator_2    1.04691321  3.5395061
#> T-26-0021_Operator_1    0.89791500  2.4039626
#> T-26-0021_Operator_2    0.87721304  2.3828054
#> T-26-0022_Operator_1    1.24130427  4.0739721
#> T-26-0022_Operator_2    1.20715123  4.1010720
#> T-26-0023-2_Operator_1  0.39402038  0.9158103
#> T-26-0023-2_Operator_2  0.42295894  0.9631697
#> T-26-0024_Operator_1    0.85051728  2.9368704
#> T-26-0024_Operator_2    0.81469432  2.8974944
#> T-26-0025_Operator_1    0.94529490  3.6004115
#> T-26-0025_Operator_2    0.96418946  3.5249485
#> T-26-0026_Operator_1    0.98714689  3.3994856
#> T-26-0026_Operator_2    0.99608091  3.3831603
#> T-26-0027_Operator_1    1.02166995  3.0321515
#> T-26-0027_Operator_2    1.07698580  2.9963935
#> T-26-0028_Operator_1    0.73958518  2.1741848
#> T-26-0028_Operator_2    0.75594186  2.2006804
#> T-26-0029_Operator_1    0.54001147  1.5831947
#> T-26-0029_Operator_2    0.53096732  1.5686845
#> T-26-0030_Operator_1    1.34909983  3.2185060
#> T-26-0030_Operator_2    1.31589905  3.4722759
#> T-26-0031_Operator_1    0.82542841  2.1630255
#> T-26-0031_Operator_2    0.81679600  2.1806618
#> T-26-0032_Operator_1    2.73647143  7.4349779
#> T-26-0032_Operator_2    2.61320235  7.5128231
#> T-26-0033_Operator_1    0.89125851  3.1456551
#> T-26-0033_Operator_2    0.88976082  3.1437432
#> T-26-0034_Operator_1    0.91393689  2.7748779
#> T-26-0034_Operator_2    0.97581388  2.8123216
#> T-26-0035_Operator_1    0.61076946  1.5660901
#> T-26-0035_Operator_2    0.64985944  1.6103029
#> T-26-0036_Operator_1    1.34522540  3.3372124
#> T-26-0036_Operator_2    1.37571298  3.4356045
#> T-26-0037_Operator_1    1.78656147  4.2604351
#> T-26-0037_Operator_2    1.85075923  4.5821328
#> T-26-0038_Operator_1    0.75159969  1.8861551
#> T-26-0038_Operator_2    0.77625521  1.8473321
#> T-26-0039_Operator_1    0.84979877  2.6692090
#> T-26-0039_Operator_2    0.84227964  2.7185547
#> T-26-0040_Operator_1    0.88569211  1.8204049
#> T-26-0040_Operator_2    0.95972227  1.8945356
#> T-26-0041_Operator_1    0.66020674  2.1580169
#> T-26-0041_Operator_2    0.69296749  2.1713621
#> T-26-0042_Operator_1    0.94024767  3.5479846
#> T-26-0042_Operator_2    1.01297431  3.5318681
#> T-26-0043_Operator_1    0.85348786  2.7862582
#> T-26-0043_Operator_2    0.87329601  2.7804717
#> T-26-0044_Operator_1    0.96634059  3.3917235
#> T-26-0044_Operator_2    1.05279955  3.3311251
#> T-26-0045_Operator_1    1.54817839  5.8389634
#> T-26-0045_Operator_2    1.47815431  5.6214807
#> T-26-0046_Operator_1    0.89272572  3.1513142
#> T-26-0046_Operator_2    0.86872525  3.1279829
#> T-26-0047_Operator_1    2.83768077  9.6624416
#> T-26-0047_Operator_2    2.88405579 10.0136552
#> T-26-0048_Operator_1    1.04700214  3.1011184
#> T-26-0048_Operator_2    1.18130210  3.1493540
#> T-26-0049_Operator_1    1.45381636  4.9975595
#> T-26-0049_Operator_2    1.50664459  5.0148786
#> T-26-0050_Operator_1    0.78376397  2.8838907
#> T-26-0050_Operator_2    0.08143322  0.1628664
#> T-26-0051_Operator_1    1.04491646  4.1096629
#> T-26-0051_Operator_2    1.11659528  4.2243517
#> T-26-0052_Operator_1    1.04033850  1.4969613
#> T-26-0052_Operator_2    1.72679819  5.7026300
#> T-26-0053_Operator_1    1.77835121  4.5813119
#> T-26-0053_Operator_2    1.70813358  4.5167976
#> T-26-0054_Operator_1    1.47213186  4.3374223
#> T-26-0054_Operator_2    1.55105328  4.4662890
#> T-26-0055_Operator_1    0.94478386  2.8418018
#> T-26-0055_Operator_2    1.00091438  2.8544145
#> T-26-0056-2_Operator_1  1.09998822  4.0491518
#> T-26-0056-2_Operator_2  1.19404463  4.0139593
#> T-26-0057_Operator_1    0.84792056  2.9038447
#> T-26-0057_Operator_2    0.91610418  2.8548034
#> T-26-0058_Operator_1    1.09506626  3.1454666
#> T-26-0058_Operator_2    0.87236043  2.6892875
#> T-26-0059_Operator_1    1.04775421  3.3956498
#> T-26-0059_Operator_2    1.03874805  3.3736203
#> T-26-0060_Operator_1    0.93461988  2.6292141
#> T-26-0060_Operator_2    0.97315038  2.7660483
#> T-26-0061_Operator_1    1.49947044  4.6079693
#> T-26-0061_Operator_2    1.59240855  4.7368871
#> T-26-0062_Operator_1    1.94615746  6.6733016
#> T-26-0062_Operator_2    2.00176444  7.0168582
#> T-26-0063_Operator_1    0.70409733  2.2468482
#> T-26-0063_Operator_2    0.72040147  2.2398611
#> T-26-0064_Operator_1    0.90570550  2.0421302
#> T-26-0064_Operator_2    0.94080931  2.1884567
#> T-26-0065_Operator_1    0.87995967  2.8812857
#> T-26-0065_Operator_2    0.92874863  2.9102122
#> T-26-0067_Operator_1    0.93043596  1.6071451
#> T-26-0067_Operator_2    1.02255663  1.7659190
#> T-26-0068_Operator_1    1.19853609  4.1259160
#> T-26-0068_Operator_2    1.26869179  4.2187464
#> T-26-0069_Operator_1    0.86558967  2.6553140
#> T-26-0069_Operator_2    0.88447243  2.7477265
#> T-26-0070_Operator_1    0.98532578  3.0144802
#> T-26-0070_Operator_2    1.05490236  3.0431116
#> T-26-0071_Operator_1    0.88086347  2.8643887
#> T-26-0071_Operator_2    0.90780782  2.8390204
#> T-26-0072_Operator_1    0.99095792  2.2465413
#> T-26-0072_Operator_2    1.03541889  2.3446777
#> T-26-0073_Operator_1    0.98305829  2.9215924
#> T-26-0073_Operator_2    0.97977434  2.9286063
#> T-26-0074_Operator_1    1.03864732  2.8445721
#> T-26-0074_Operator_2    1.07534459  2.9306498
#> T-26-0075_Operator_1    1.14507518  3.8286863
#> T-26-0075_Operator_2    1.32485512  3.9159532
#> T-26-0076_Operator_1    1.19933035  3.6514106
#> T-26-0076_Operator_2    1.28934391  3.6683041
#> T-26-0077_Operator_1    0.64109402  1.4798535
#> T-26-0077_Operator_2    0.72460423  1.5373085
#> T-26-0078_Operator_1    1.07916131  1.7517570
#> T-26-0078_Operator_2    1.10578879  1.8856283
#> T-26-0079_Operator_1    0.80448479  2.1296275
#> T-26-0079_Operator_2    0.78224941  2.1786610
#> T-26-0080_Operator_1    0.67221829  1.6498208
#> T-26-0080_Operator_2    0.68144450  1.7343666
#> T-26-0081_Operator_1    0.57663588  2.0594499
#> T-26-0081_Operator_2    0.61618884  2.1454370
#> T-26-0082_Operator_1    0.91004758  2.8854969
#> T-26-0082_Operator_2    0.92261717  2.8847856
#> T-26-0083_Operator_1    0.55932413  1.4254284
#> T-26-0083_Operator_2    0.57650674  1.4731171
#> T-26-0084_Operator_1    0.69300384  2.0254025
#> T-26-0084_Operator_2    0.69142606  2.0378669
#> T-26-0085_Operator_1    0.80344399  1.9696287
#> T-26-0085_Operator_2    0.82545103  2.6892875
#> T-26-0086_Operator_1    0.98054094  2.1420406
#> T-26-0086_Operator_2    0.97921177  2.3509634
#> T-26-0087_Operator_1    0.84671534  2.0895244
#> T-26-0087_Operator_2    0.82056096  2.0739657
#> T-26-0088_Operator_1    0.78696873  1.8058329
#> T-26-0088_Operator_2    0.82057768  2.6892875
#> T-26-0089_Operator_1    0.31151945  0.9462838
#> T-26-0089_Operator_2    0.31217805  1.0180950
#> T-26-0090_Operator_1    0.46499826  0.7266579
#> T-26-0090_Operator_2    0.42554710  0.7285386
#> T-26-0091_Operator_1    0.91491771  2.7065916
#> T-26-0091_Operator_2    1.00108794  2.9396444
#> T-26-0092_Operator_1    0.86242964  2.7905426
#> T-26-0092_Operator_2    0.93490388  2.8462478
#> T-26-0093_Operator_1    0.85141207  2.6579084
#> T-26-0093_Operator_2    0.85438558  2.7546495
#> T-26-0094_Operator_1    0.67282653  1.7084773
#> T-26-0094_Operator_2    0.69307110  1.8304740
#> T-26-0095_Operator_1    0.83458512  3.0876213
#> T-26-0095_Operator_2    0.80006403  3.0676959
#> T-26-0096_Operator_1    0.61503499  1.9894827
#> T-26-0096_Operator_2    0.65256182  2.0084186
#> T-26-0097_Operator_1    0.96180342  2.5495034
#> T-26-0097_Operator_2    0.96703238  2.5193426
#> T-26-0098_Operator_1    0.85450415  2.4580658
#> T-26-0098_Operator_2    0.79276981  2.5048147
#> T-26-0099_Operator_1    0.40729495  1.2417925
#> T-26-0099_Operator_2    0.42328260  1.2924933
#> T-26-0100_Operator_1    0.71411210  1.9585391
#> T-26-0100_Operator_2    0.61956915  2.6892875
#> T-26-0101_Operator_1    0.77207914  2.8471380
#> T-26-0101_Operator_2    0.82233011  2.9197267
#> T-26-0102_Operator_1    7.17720036  2.4448764
#> T-26-0102_Operator_2    0.73237071  2.4643298
#> T-26-0103_Operator_1    1.19085054  3.4684741
#> T-26-0103_Operator_2    1.07513234  3.5252356
#> T-26-0104_Operator_1    1.02580155  2.9546155
#> T-26-0104_Operator_2    0.96332047  3.0936431
#> T-26-0107_Operator_1    1.03806850  1.8771877
#> T-26-0107_Operator_2    0.87236043  2.6892875
#> T-26-0108_Operator_1    1.04895200  2.8055072
#> T-26-0108_Operator_2    0.97966313  2.9711929
#> T-26-0109_Operator_1    1.00875877  1.2746669
#> T-26-0109_Operator_2    0.85573835  1.3006195
#> T-26-0111_Operator_1    0.30359381  0.6624044
#> T-26-0111_Operator_2    0.26611091  0.6108420
#> T-26-0112-2_Operator_1  0.72739304  2.5341086
#> T-26-0112-2_Operator_2  0.71154338  2.5326900
#> T-26-0112_Operator_1    0.40937992  0.7516845
#> T-26-0112_Operator_2    0.41702433  0.8048003
#> T-26-0113_Operator_1    0.71480648  1.8336902
#> T-26-0113_Operator_2    0.74379703  1.8435405
#> T-26-0114_Operator_1    0.75893119  2.0858802
#> T-26-0114_Operator_2    1.04459895  2.2982704
#> T-26-0115_Operator_1    0.98794364  2.3051897
#> T-26-0115_Operator_2    0.73180688  1.8105997
#> T-26-0116_Operator_1    0.76697778  1.8505683
#> T-26-0116_Operator_2    0.81845000  2.2662616
#> T-26-0117_Operator_1    0.82980787  2.2834658
#> T-26-0117_Operator_2    1.00872651  2.8269347
#> T-26-0118_Operator_1    0.92580436  2.8196495
#> T-26-0118_Operator_2    0.80855984  2.2180214
#> T-26-0120_Operator_1    0.66419537  2.0108479
#> T-26-0120_Operator_2    0.69181351  1.9971281
#> T-26-0121_Operator_1    0.87236043  2.4889053
#> T-26-0121_Operator_2    0.87236043 46.2500000
#> T-26-0122_Operator_1    0.99523256  3.0324028
#> T-26-0122_Operator_2    0.94805104  3.0003691
#> T-26-0123_Operator_1    0.84531911  1.8359718
#> T-26-0123_Operator_2    0.91205363  1.9105812
#> T-26-0125_Operator_1    0.64714158  2.2002373
#> T-26-0125_Operator_2    0.62256089  2.2787559
#> T-26-0126_Operator_1    0.70140867  1.9737072
#> T-26-0126_Operator_2    0.72913926  2.0402390
#> T-26-0127_Operator_1    0.92211763  2.3774479
#> T-26-0127_Operator_2    0.92361074  2.5952002
#> T-26-0128_Operator_1    0.73475215  1.5237441
#> T-26-0128_Operator_2    0.70867070  1.5457207
#> T-26-0130_Operator_1    0.55843568  0.7953048
#> T-26-0130_Operator_2    0.59059332  0.7842463
#> T-26-0131_Operator_1    0.89738751  2.6258582
#> T-26-0131_Operator_2    0.96346128  2.6815355
#> T-26-0132_Operator_1    0.94520812  3.5100029
#> T-26-0132_Operator_2    0.96658013  3.5897979
#> T-26-0133_Operator_1    0.78771644  2.4214586
#> T-26-0133_Operator_2    0.91299852  2.4706085
#> T-26-0134_Operator_1    0.83682594  2.9771613
#> T-26-0134_Operator_2    0.87116571  2.9564417
#> T-26-0135_Operator_1    0.76549904  2.4105810
#> T-26-0135_Operator_2    0.79814605  2.4750311
#> T-26-0136_Operator_1    0.84913583  2.6508421
#> T-26-0136_Operator_2    0.89998973  2.6127350
#> T-26-0137_Operator_1    1.55955569  3.8441334
#> T-26-0137_Operator_2    1.60053499  4.1462961
#> T-26-0138_Operator_1    0.83676235  2.4000015
#> T-26-0138_Operator_2    0.88708697  2.4592981
#> T-26-0139_Operator_1    0.79587378  1.6135731
#> T-26-0139_Operator_2    0.91277777  1.7291064
#> T-26-0140_Operator_1    0.65752271  2.5026000
#> T-26-0140_Operator_2    0.73315404  2.4776456
#> T-26-0141_Operator_1    0.86299346  3.2191099
#> T-26-0141_Operator_2    0.92591179  3.2079963
#> T-26-0142_Operator_1    0.72589556  2.2281950
#> T-26-0142_Operator_2    0.74093314  2.2425744
#> T-26-0143_Operator_1    0.85360522  2.6120792
#> T-26-0143_Operator_2    0.85502843  2.6302135
#> T-26-0144_Operator_1    1.06822218  2.8988373
#> T-26-0144_Operator_2    1.16244876  3.0024063
#> T-26-0145_Operator_1    0.33999379  0.6120432
#> T-26-0145_Operator_2    0.32801951  0.6517895
#> T-26-0146_Operator_1    1.02735731  3.6745242
#> T-26-0146_Operator_2    1.08787758  3.6807453
#> T-26-0147_Operator_1    1.06700885  3.2792833
#> T-26-0147_Operator_2    1.05449177  3.2957084
#> T-26-0148_Operator_1    1.47766697  5.2675328
#> T-26-0148_Operator_2    1.53211259  5.4033873
#> T-26-0149_Operator_1    2.56939163  8.9125365
#> T-26-0149_Operator_2    2.62101820  8.7900698
#> T-26-0150_Operator_1    1.71473188  6.3131456
#> T-26-0150_Operator_2    1.68219658  6.2134242
#> T-26-0151_Operator_1    0.99324603  3.5499705
#> T-26-0151_Operator_2    1.04407626  3.5890075
#> T-26-0152_Operator_1    0.32412453  1.0854926
#> T-26-0152_Operator_2    0.32078987  1.1213906
#> T-26-0153_Operator_1    0.83055181  2.7890400
#> T-26-0153_Operator_2    0.89249282  2.8189162
#> T-26-0154_Operator_1    0.71613763  1.9667001
#> T-26-0154_Operator_2    0.73999209  1.9944878
#> T-26-0155_Operator_1    0.48613070  1.6487981
#> T-26-0155_Operator_2    0.49305395  1.6444771
#> T-26-0156_Operator_1    2.01351105  6.5074921
#> T-26-0156_Operator_2    2.12346276  6.4784613
#> T-26-0157_Operator_1    1.02697733  3.1586578
#> T-26-0157_Operator_2    1.08570917  3.0392820
#> T-26-0158_Operator_1    0.87921789  3.2281692
#> T-26-0158_Operator_2    0.92869913  3.2029995
#> T-26-0159_Operator_1    0.99386610  3.2132416
#> T-26-0159_Operator_2    0.99290579  3.1348309
#> T-26-0160_Operator_1    0.91511901  3.1518291
#> T-26-0160_Operator_2    0.96480562  3.1183684
#> T-26-0161_Operator_1    0.81319803  2.5316513
#> T-26-0161_Operator_2    0.89239574  2.5077029
#> T-26-0162_Operator_1    0.79852408  2.6361187
#> T-26-0162_Operator_2    0.83617159  2.5944157
#> T-26-0163_Operator_1    1.04668790  2.7435095
#> T-26-0163_Operator_2    1.09604410  2.7052521
#> T-26-0164_Operator_1    0.48674340  1.6430883
#> T-26-0164_Operator_2    0.50675901  1.6330442
#> T-26-0165_Operator_1    0.78956511  2.0182109
#> T-26-0165_Operator_2    0.80776941  2.0194991
#> T-26-0166_Operator_1    0.42130251  1.6089361
#> T-26-0166_Operator_2    0.44153185  1.6533006
#> T-26-0167_Operator_1    2.81640047 10.9241640
#> T-26-0167_Operator_2    2.70414424 10.4805669
#> T-26-0168_Operator_1    0.89818435  3.1844346
#> T-26-0168_Operator_2    0.86591454  3.0997330
#> T-26-0169_Operator_1    1.07451554  3.6356437
#> T-26-0169_Operator_2    2.14600361  7.1654512
#> T-26-0170_Operator_1    1.04460351  3.1696411
#> T-26-0170_Operator_2    1.21316105  3.0969766
#> T-26-0171_Operator_1    1.07362888  3.1554360
#> T-26-0171_Operator_2    1.08184235  3.2030868
#> T-26-0172_Operator_1    1.03372048  3.5798343
#> T-26-0172_Operator_2    1.06724121  3.5172135
#> T-26-0173_Operator_1    0.71169482  2.1216551
#> T-26-0173_Operator_2    0.72085019  2.1410302
#> T-26-0174_Operator_1    0.89256228  3.2518680
#> T-26-0174_Operator_2    0.95331328  3.1863202
#> T-26-0175_Operator_1    0.93288904  3.2010521
#> T-26-0175_Operator_2    0.90974780  3.0700439
#> T-26-0176_Operator_1    0.89859201  2.9762694
#> T-26-0176_Operator_2    0.87540742  2.9327261
#> T-26-0177_Operator_1    0.97971964  3.3085401
#> T-26-0177_Operator_2    0.99791806  3.3157905
#> T-26-0178_Operator_1    1.00054807  3.5868983
#> T-26-0178_Operator_2    0.99631423  3.5790157
#> T-26-0179-3_Operator_1  0.99503383  2.9464178
#> T-26-0179-3_Operator_2  0.99884489  2.9335416
#> T-26-0179_Operator_1    0.52449466  1.6627169
#> T-26-0179_Operator_2    0.52475488  1.6351626
#> T-26-0180_Operator_1    1.02320390  2.9707247
#> T-26-0180_Operator_2    1.03478927  2.9149734
#> T-26-0181_Operator_1    0.91185421  3.0396183
#> T-26-0181_Operator_2    0.88816399  2.9376842
#> T-26-0182_Operator_1    0.82648038  2.6596087
#> T-26-0182_Operator_2    0.84685720  2.6004194
#> T-26-0183_Operator_1    1.05274864  2.8606558
#> T-26-0183_Operator_2    1.08731532  2.8561641
#> T-26-0184_Operator_1    0.96129625  2.2332909
#> T-26-0184_Operator_2    1.17590252  2.1989375
#> T-26-0185_Operator_1    0.72091024  2.2312527
#> T-26-0185_Operator_2    0.77583481  2.1629098
#> T-26-0186_Operator_1    1.10623297  3.5062715
#> T-26-0186_Operator_2    1.10280140  3.5266749
#> T-26-0187_Operator_1    1.07934953  2.9902705
#> T-26-0187_Operator_2    1.06973386  2.8675641
#> T-26-0188_Operator_1    0.85374148  1.4430073
#> T-26-0188_Operator_2    0.77846076  1.4678234
#> T-26-0189_Operator_1    0.82062091  2.7096297
#> T-26-0189_Operator_2    0.80951323  2.6608072
#> T-26-0190_Operator_1    0.91803235  3.1422466
#> T-26-0190_Operator_2    0.89936654  3.0265674
#> T-26-0191_Operator_1    0.89795257  2.8681991
#> T-26-0191_Operator_2    0.90612754  2.8372637
#> T-26-0192_Operator_1    1.00645486  3.0791598
#> T-26-0192_Operator_2    1.05781244  3.0051291
#> T-26-0193_Operator_1    0.94086971  2.9338289
#> T-26-0193_Operator_2    0.90710090  2.8656576
#> T-26-0194_Operator_1    1.09882435  3.7203691
#> T-26-0194_Operator_2    1.09592021  3.6195673
#> T-26-0195_Operator_1    0.98327086  3.4557332
#> T-26-0195_Operator_2    0.95339652  3.3574004
#> T-26-0196_Operator_1    0.67871992  2.1642101
#> T-26-0196_Operator_2    0.69314556  2.1547211
#> T-26-0197_Operator_1    0.95377157  3.1698940
#> T-26-0197_Operator_2    0.90926404  3.0777669
#> T-26-0198_Operator_1    0.86595499  2.9369247
#> T-26-0198_Operator_2    0.85756604  2.7925573
#> T-26-0199_Operator_1    0.71064132  1.5896634
#> T-26-0199_Operator_2    0.68991287  1.6290135
#> T-26-0200_Operator_1    0.97413326  3.7784049
#> T-26-0200_Operator_2    1.03204377  3.7381998
#> T-26-0201_Operator_1    0.77161382  2.8315407
#> T-26-0201_Operator_2    0.77685102  2.8224485
#> T-26-0202_Operator_1    0.98025701  4.2461142
#> T-26-0202_Operator_2    1.03136434  4.0630081
#> T-26-0203_Operator_1    0.85579184  2.7530320
#> T-26-0203_Operator_2    0.84183380  2.6897598
#> T-26-0204_Operator_1    0.93416468  3.1448217
#> T-26-0204_Operator_2    1.03225450  3.1187043
#> T-26-0205_Operator_1    0.80250225  2.6000509
#> T-26-0205_Operator_2    0.82079045  2.5416547
#> T-26-0206_Operator_1    0.73031548  2.8255736
#> T-26-0206_Operator_2    0.73721903  2.8114563
#> T-26-0207_Operator_1    0.66649799  2.2322844
#> T-26-0207_Operator_2    0.66549984  2.2341607
#> T-26-0208_Operator_1    0.82795773  1.3885782
#> T-26-0208_Operator_2    0.80060172  1.4386457
#> T-26-0209_Operator_1    0.93020856  2.2393635
#> T-26-0209_Operator_2    1.01730626  2.2987996
#> T-26-0210_Operator_1    0.53442050  1.7290386
#> T-26-0210_Operator_2    0.52419719  1.7342168
#> T-26-0211_Operator_1    0.79368318  2.1989571
#> T-26-0211_Operator_2    0.80580800  2.2155026
#> T-26-0212_Operator_1    0.66074746  1.9789651
#> T-26-0212_Operator_2    0.65217452  1.9387125
#> T-26-0213_Operator_1    0.72789078  2.1905256
#> T-26-0213_Operator_2    0.71981779  2.2159798
#> T-26-0214_Operator_1    1.35413009  4.1483965
#> T-26-0214_Operator_2    1.35263088  4.1218400
#> T-26-0215_Operator_1    0.81081824  2.6951345
#> T-26-0215_Operator_2    0.84988027  2.6903156
#> T-26-0216_Operator_1    0.74986136  2.5774111
#> T-26-0216_Operator_2    0.73254584  2.5915043
#> T-26-0217_Operator_1    1.01500355  3.8429466
#> T-26-0217_Operator_2    0.97932510  3.8976176
#> T-26-0218_Operator_1    0.80892068  2.2346672
#> T-26-0218_Operator_2    0.82731315  2.1690987
#> T-26-0219_Operator_1    0.46441415  1.0109583
#> T-26-0219_Operator_2    0.46012507  1.0398407
#> T-26-0220_Operator_1    0.68539441  1.9827539
#> T-26-0220_Operator_2    0.67923439  1.9825952
#> T-26-0221_Operator_1    0.75752976  2.5002975
#> T-26-0221_Operator_2    0.78996695  2.5179755
#> T-26-0222_Operator_1    1.59030288  6.7887016
#> T-26-0222_Operator_2    1.76569455  6.9655747
#> T-26-0223_Operator_1    0.94144242  2.6305537
#> T-26-0223_Operator_2    1.03234768  2.6201501
#> T-26-0224_Operator_1    1.00638635  3.2187543
#> T-26-0224_Operator_2    0.99179287  3.1800766
#> T-26-0225_Operator_1    1.09108301  3.8509176
#> T-26-0225_Operator_2    1.05156136  3.8184733
#> T-26-0226_Operator_1    0.55160142  1.6322400
#> T-26-0226_Operator_2    0.53941361  1.6381295
#> T-26-0227_Operator_1    0.75374979  2.6367184
#> T-26-0227_Operator_2    0.76447266  2.6530645
#> T-26-0228_Operator_1    0.88323650  3.0647303
#> T-26-0228_Operator_2    0.84580115  3.0669149
#> T-26-0229_Operator_1    1.04557108  4.1205778
#> T-26-0229_Operator_2    1.03266925  4.0394089
#> T-26-0230-1_Operator_1  0.76119760  1.4825842
#> T-26-0230-1_Operator_2 17.23814286 32.9524286
#> T-26-0230-2_Operator_1  0.73992303  1.6782507
#> T-26-0230-2_Operator_2  0.71700636  1.6990649
#> T-26-0230-3_Operator_1  0.74060975  1.5735781
#> T-26-0230-3_Operator_2  0.70913449  1.5686017
#> T-26-0230-4_Operator_1  0.77268126  1.8070497
#> T-26-0230-4_Operator_2  0.80272844  1.7965344
#> T-26-0231_Operator_1    0.84996206  1.9126364
#> T-26-0231_Operator_2    0.80385593  1.8950976
#> T-26-0232_Operator_1    0.69394380  0.9091051
#> T-26-0232_Operator_2    0.66924583  0.9772442
#> T-26-0233_Operator_1    1.21970041  2.2635260
#> T-26-0233_Operator_2    0.63728291  1.2317546
#> T-26-0234_Operator_1    2.04482733  5.1096278
#> T-26-0234_Operator_2    1.98580731  5.2451098
#> T-26-0235_Operator_1    0.67917006  1.9081159
#> T-26-0235_Operator_2    0.68771589  2.0235563
#> T-26-0236_Operator_1    1.60178859  5.0011264
#> T-26-0236_Operator_2    1.61193588  5.0099427
#> T-26-0237_Operator_1    1.75216231  5.4790483
#> T-26-0237_Operator_2    1.75042833  5.4343017
#> T-26-0238_Operator_1    1.29805143  3.8671481
#> T-26-0238_Operator_2    1.28342192  3.8102989
#> T-26-0239_Operator_1    1.02196774  1.9529501
#> T-26-0239_Operator_2    0.95382131  1.9611826
#> T-26-0240_Operator_1    0.77623429  2.2115968
#> T-26-0240_Operator_2    0.75675676  2.2205722
#> T-26-0241_Operator_1    0.48496481  1.3278484
#> T-26-0241_Operator_2    0.51628988  1.3115326
#> T-26-0242_Operator_1    1.78126071  4.4602793
#> T-26-0242_Operator_2    1.69209366  4.3648338
#> T-26-0243_Operator_1    0.52592322  1.7867144
#> T-26-0243_Operator_2    0.53203871  1.6391988
#> T-26-0244_Operator_1    0.37857636  1.0212588
#> T-26-0244_Operator_2    0.39535142  1.0105534
#> T-26-0245_Operator_1    0.77335777  1.8103214
#> T-26-0245_Operator_2    0.78603004  1.8615893
#> T-26-0246_Operator_1    0.70760524  1.7531888
#> T-26-0246_Operator_2    0.65028447  1.7156355
#> T-26-0247_Operator_1    0.48913471  1.4800813
#> T-26-0247_Operator_2    0.48542480  1.2332955
#> T-26-0248_Operator_1    0.35694987  0.8958600
#> T-26-0248_Operator_2    0.31998735  0.9510795
#> T-26-0249_Operator_1    0.36892175  0.7915911
#> T-26-0249_Operator_2    0.35776455  0.7629833
#> T-26-0250_Operator_1    0.36103027  1.7867144
#> T-26-0250_Operator_2    0.36135765  1.1619087
#> T-26-0251_Operator_1    0.54840819  1.7701324
#> T-26-0251_Operator_2    0.51736990  1.7625174
#> T-26-0252_Operator_1    0.37654764  1.3572539
#> T-26-0252_Operator_2    0.38627280  1.3581170
#> T-26-0261-1_Operator_1  1.05206634  2.1585273
#> T-26-0261-1_Operator_2  1.07713044  2.2159578
#> T-26-0261-2_Operator_1  0.93903966  2.2522764
#> T-26-0261-2_Operator_2  0.91455845  2.3571911
#> T-26-0261-3_Operator_1  0.86275344  1.4535208
#> T-26-0261-3_Operator_2  0.65358051  1.5304062
#> T-26-0261-4_Operator_1  0.65763999  1.6767746
#> T-26-0261-4_Operator_2  0.60177874  1.7171569
#> T-26-0261-5_Operator_1  0.89196997  1.3477131
#> T-26-0261-5_Operator_2  0.82465753  1.4869528
#> T-26-0262-1_Operator_1  0.77017839  0.8893569
#> T-26-0262-1_Operator_2  0.76276219  0.8686862
#> T-26-0262-2_Operator_1  0.66670239  0.8426073
#> T-26-0262-2_Operator_2  0.73571823  0.9969905
#> T-26-0263_Operator_1    0.45241713  0.6934284
#> T-26-0263_Operator_2    0.45451078  0.7434583
#> T-26-0264-1_Operator_1  0.45125314  0.7930407
#> T-26-0264-1_Operator_2  0.42533335  0.8505807
#> T-26-0264-2_Operator_1  0.46454098  0.5646399
#> T-26-0264-2_Operator_2  0.44133036  0.7328010
#> T-26-0264-3_Operator_1  0.39580338  1.0584567
#> T-26-0264-3_Operator_2  0.39114438  1.0835165
#> T-26-0264-4_Operator_1  0.38940848  0.7662178
#> T-26-0264-4_Operator_2  0.39387127  0.8113735
#> T-26-0265_Operator_1    1.00000000  2.3205004
#> T-26-0265_Operator_2    1.04489391  2.4451873
#> T-26-0266_Operator_1    2.54883132  6.9647184
#> T-26-0266_Operator_2    2.54363508  7.1326607
#> T-26-0267_Operator_1    2.67815682  8.6800605
#> T-26-0267_Operator_2    2.52558216  8.7359023
#> T-26-0268_Operator_1    0.81410037  1.2806203
#> T-26-0268_Operator_2    0.74753759  1.3659381
#> T-26-0269_Operator_1    0.83385665  2.4437436
#> T-26-0269_Operator_2    0.81699593  2.4546331
#> T-26-0270-1_Operator_1  1.36288887  3.2769592
#> T-26-0270-1_Operator_2  1.31969034  3.3987308
#> T-26-0270-2_Operator_1  1.39255783  2.5969944
#> T-26-0270-2_Operator_2  1.39255035  2.8347499
#> T-26-0271_Operator_1    0.86402215  3.0574002
#> T-26-0271_Operator_2    0.85763267  3.0611648
#> T-26-0272_Operator_1    0.75447552  1.2102572
#> T-26-0272_Operator_2    0.75634144  1.2828177
#> T-26-0273_Operator_1    0.82702315  2.7111506
#> T-26-0273_Operator_2    0.85847915  2.7862445
#> T-26-0274_Operator_1    0.80159265  1.2234723
#> T-26-0274_Operator_2    0.78299754  1.3660243
#> T-26-0275_Operator_1    0.75770551  1.4072418
#> T-26-0275_Operator_2    0.79790647  1.4686380
#> T-26-0276_Operator_1    0.69495450  0.5426357
#> T-26-0276_Operator_2    0.64664237  0.6806938
#> T-26-0277_Operator_1    0.85605626  0.9903243
#> T-26-0277_Operator_2    0.79442475  1.0390353
#> T-26-0278-1_Operator_1  0.60699079  0.3225506
#> T-26-0278-1_Operator_2  0.57988149  0.2719205
#> T-26-0278-2_Operator_1  0.64430266  0.4397017
#> T-26-0278-2_Operator_2  0.63632438  0.4284270
#> T-26-0279_Operator_1    0.75473329  1.4642815
#> T-26-0279_Operator_2    0.73251748  1.4642914

# measurements resting on a geometrically non-conforming landmark line
# (e.g. Bd if segment (3,4) isn't perpendicular to the body axis) are
# set to NA before na_action runs:
geom_check <- correct_landmarks(fish, rule = "check_geometry")
fishmorph_segments(fish, geometry_check = geom_check, na_action = "impute_group_mean")
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA.
#> geometry_check: set 1140 measurement value(s) to NA because their underlying landmark line was flagged as non-conforming by correct_landmarks(rule = "check_geometry").
#> na_action = "impute_group_mean": imputed 1413 missing value(s) using within-group means.
#>                                      specimen  individual
#> T-26-0001_Operator_1     T-26-0001_Operator_1   T-26-0001
#> T-26-0001_Operator_2     T-26-0001_Operator_2   T-26-0001
#> T-26-0002_Operator_1     T-26-0002_Operator_1   T-26-0002
#> T-26-0002_Operator_2     T-26-0002_Operator_2   T-26-0002
#> T-26-0003_Operator_1     T-26-0003_Operator_1   T-26-0003
#> T-26-0003_Operator_2     T-26-0003_Operator_2   T-26-0003
#> T-26-0004_Operator_1     T-26-0004_Operator_1   T-26-0004
#> T-26-0004_Operator_2     T-26-0004_Operator_2   T-26-0004
#> T-26-0005_Operator_1     T-26-0005_Operator_1   T-26-0005
#> T-26-0005_Operator_2     T-26-0005_Operator_2   T-26-0005
#> T-26-0006_Operator_1     T-26-0006_Operator_1   T-26-0006
#> T-26-0006_Operator_2     T-26-0006_Operator_2   T-26-0006
#> T-26-0007_Operator_1     T-26-0007_Operator_1   T-26-0007
#> T-26-0007_Operator_2     T-26-0007_Operator_2   T-26-0007
#> T-26-0008_Operator_1     T-26-0008_Operator_1   T-26-0008
#> T-26-0008_Operator_2     T-26-0008_Operator_2   T-26-0008
#> T-26-0009_Operator_1     T-26-0009_Operator_1   T-26-0009
#> T-26-0009_Operator_2     T-26-0009_Operator_2   T-26-0009
#> T-26-0010_Operator_1     T-26-0010_Operator_1   T-26-0010
#> T-26-0010_Operator_2     T-26-0010_Operator_2   T-26-0010
#> T-26-0011_Operator_1     T-26-0011_Operator_1   T-26-0011
#> T-26-0011_Operator_2     T-26-0011_Operator_2   T-26-0011
#> T-26-0012_Operator_1     T-26-0012_Operator_1   T-26-0012
#> T-26-0012_Operator_2     T-26-0012_Operator_2   T-26-0012
#> T-26-0013_Operator_1     T-26-0013_Operator_1   T-26-0013
#> T-26-0013_Operator_2     T-26-0013_Operator_2   T-26-0013
#> T-26-0014_Operator_1     T-26-0014_Operator_1   T-26-0014
#> T-26-0014_Operator_2     T-26-0014_Operator_2   T-26-0014
#> T-26-0015_Operator_1     T-26-0015_Operator_1   T-26-0015
#> T-26-0015_Operator_2     T-26-0015_Operator_2   T-26-0015
#> T-26-0016_Operator_1     T-26-0016_Operator_1   T-26-0016
#> T-26-0016_Operator_2     T-26-0016_Operator_2   T-26-0016
#> T-26-0017_Operator_1     T-26-0017_Operator_1   T-26-0017
#> T-26-0017_Operator_2     T-26-0017_Operator_2   T-26-0017
#> T-26-0018_Operator_1     T-26-0018_Operator_1   T-26-0018
#> T-26-0018_Operator_2     T-26-0018_Operator_2   T-26-0018
#> T-26-0019_Operator_1     T-26-0019_Operator_1   T-26-0019
#> T-26-0019_Operator_2     T-26-0019_Operator_2   T-26-0019
#> T-26-0020_Operator_1     T-26-0020_Operator_1   T-26-0020
#> T-26-0020_Operator_2     T-26-0020_Operator_2   T-26-0020
#> T-26-0021_Operator_1     T-26-0021_Operator_1   T-26-0021
#> T-26-0021_Operator_2     T-26-0021_Operator_2   T-26-0021
#> T-26-0022_Operator_1     T-26-0022_Operator_1   T-26-0022
#> T-26-0022_Operator_2     T-26-0022_Operator_2   T-26-0022
#> T-26-0023-2_Operator_1 T-26-0023-2_Operator_1 T-26-0023-2
#> T-26-0023-2_Operator_2 T-26-0023-2_Operator_2 T-26-0023-2
#> T-26-0024_Operator_1     T-26-0024_Operator_1   T-26-0024
#> T-26-0024_Operator_2     T-26-0024_Operator_2   T-26-0024
#> T-26-0025_Operator_1     T-26-0025_Operator_1   T-26-0025
#> T-26-0025_Operator_2     T-26-0025_Operator_2   T-26-0025
#> T-26-0026_Operator_1     T-26-0026_Operator_1   T-26-0026
#> T-26-0026_Operator_2     T-26-0026_Operator_2   T-26-0026
#> T-26-0027_Operator_1     T-26-0027_Operator_1   T-26-0027
#> T-26-0027_Operator_2     T-26-0027_Operator_2   T-26-0027
#> T-26-0028_Operator_1     T-26-0028_Operator_1   T-26-0028
#> T-26-0028_Operator_2     T-26-0028_Operator_2   T-26-0028
#> T-26-0029_Operator_1     T-26-0029_Operator_1   T-26-0029
#> T-26-0029_Operator_2     T-26-0029_Operator_2   T-26-0029
#> T-26-0030_Operator_1     T-26-0030_Operator_1   T-26-0030
#> T-26-0030_Operator_2     T-26-0030_Operator_2   T-26-0030
#> T-26-0031_Operator_1     T-26-0031_Operator_1   T-26-0031
#> T-26-0031_Operator_2     T-26-0031_Operator_2   T-26-0031
#> T-26-0032_Operator_1     T-26-0032_Operator_1   T-26-0032
#> T-26-0032_Operator_2     T-26-0032_Operator_2   T-26-0032
#> T-26-0033_Operator_1     T-26-0033_Operator_1   T-26-0033
#> T-26-0033_Operator_2     T-26-0033_Operator_2   T-26-0033
#> T-26-0034_Operator_1     T-26-0034_Operator_1   T-26-0034
#> T-26-0034_Operator_2     T-26-0034_Operator_2   T-26-0034
#> T-26-0035_Operator_1     T-26-0035_Operator_1   T-26-0035
#> T-26-0035_Operator_2     T-26-0035_Operator_2   T-26-0035
#> T-26-0036_Operator_1     T-26-0036_Operator_1   T-26-0036
#> T-26-0036_Operator_2     T-26-0036_Operator_2   T-26-0036
#> T-26-0037_Operator_1     T-26-0037_Operator_1   T-26-0037
#> T-26-0037_Operator_2     T-26-0037_Operator_2   T-26-0037
#> T-26-0038_Operator_1     T-26-0038_Operator_1   T-26-0038
#> T-26-0038_Operator_2     T-26-0038_Operator_2   T-26-0038
#> T-26-0039_Operator_1     T-26-0039_Operator_1   T-26-0039
#> T-26-0039_Operator_2     T-26-0039_Operator_2   T-26-0039
#> T-26-0040_Operator_1     T-26-0040_Operator_1   T-26-0040
#> T-26-0040_Operator_2     T-26-0040_Operator_2   T-26-0040
#> T-26-0041_Operator_1     T-26-0041_Operator_1   T-26-0041
#> T-26-0041_Operator_2     T-26-0041_Operator_2   T-26-0041
#> T-26-0042_Operator_1     T-26-0042_Operator_1   T-26-0042
#> T-26-0042_Operator_2     T-26-0042_Operator_2   T-26-0042
#> T-26-0043_Operator_1     T-26-0043_Operator_1   T-26-0043
#> T-26-0043_Operator_2     T-26-0043_Operator_2   T-26-0043
#> T-26-0044_Operator_1     T-26-0044_Operator_1   T-26-0044
#> T-26-0044_Operator_2     T-26-0044_Operator_2   T-26-0044
#> T-26-0045_Operator_1     T-26-0045_Operator_1   T-26-0045
#> T-26-0045_Operator_2     T-26-0045_Operator_2   T-26-0045
#> T-26-0046_Operator_1     T-26-0046_Operator_1   T-26-0046
#> T-26-0046_Operator_2     T-26-0046_Operator_2   T-26-0046
#> T-26-0047_Operator_1     T-26-0047_Operator_1   T-26-0047
#> T-26-0047_Operator_2     T-26-0047_Operator_2   T-26-0047
#> T-26-0048_Operator_1     T-26-0048_Operator_1   T-26-0048
#> T-26-0048_Operator_2     T-26-0048_Operator_2   T-26-0048
#> T-26-0049_Operator_1     T-26-0049_Operator_1   T-26-0049
#> T-26-0049_Operator_2     T-26-0049_Operator_2   T-26-0049
#> T-26-0050_Operator_1     T-26-0050_Operator_1   T-26-0050
#> T-26-0050_Operator_2     T-26-0050_Operator_2   T-26-0050
#> T-26-0051_Operator_1     T-26-0051_Operator_1   T-26-0051
#> T-26-0051_Operator_2     T-26-0051_Operator_2   T-26-0051
#> T-26-0052_Operator_1     T-26-0052_Operator_1   T-26-0052
#> T-26-0052_Operator_2     T-26-0052_Operator_2   T-26-0052
#> T-26-0053_Operator_1     T-26-0053_Operator_1   T-26-0053
#> T-26-0053_Operator_2     T-26-0053_Operator_2   T-26-0053
#> T-26-0054_Operator_1     T-26-0054_Operator_1   T-26-0054
#> T-26-0054_Operator_2     T-26-0054_Operator_2   T-26-0054
#> T-26-0055_Operator_1     T-26-0055_Operator_1   T-26-0055
#> T-26-0055_Operator_2     T-26-0055_Operator_2   T-26-0055
#> T-26-0056-2_Operator_1 T-26-0056-2_Operator_1 T-26-0056-2
#> T-26-0056-2_Operator_2 T-26-0056-2_Operator_2 T-26-0056-2
#> T-26-0057_Operator_1     T-26-0057_Operator_1   T-26-0057
#> T-26-0057_Operator_2     T-26-0057_Operator_2   T-26-0057
#> T-26-0058_Operator_1     T-26-0058_Operator_1   T-26-0058
#> T-26-0058_Operator_2     T-26-0058_Operator_2   T-26-0058
#> T-26-0059_Operator_1     T-26-0059_Operator_1   T-26-0059
#> T-26-0059_Operator_2     T-26-0059_Operator_2   T-26-0059
#> T-26-0060_Operator_1     T-26-0060_Operator_1   T-26-0060
#> T-26-0060_Operator_2     T-26-0060_Operator_2   T-26-0060
#> T-26-0061_Operator_1     T-26-0061_Operator_1   T-26-0061
#> T-26-0061_Operator_2     T-26-0061_Operator_2   T-26-0061
#> T-26-0062_Operator_1     T-26-0062_Operator_1   T-26-0062
#> T-26-0062_Operator_2     T-26-0062_Operator_2   T-26-0062
#> T-26-0063_Operator_1     T-26-0063_Operator_1   T-26-0063
#> T-26-0063_Operator_2     T-26-0063_Operator_2   T-26-0063
#> T-26-0064_Operator_1     T-26-0064_Operator_1   T-26-0064
#> T-26-0064_Operator_2     T-26-0064_Operator_2   T-26-0064
#> T-26-0065_Operator_1     T-26-0065_Operator_1   T-26-0065
#> T-26-0065_Operator_2     T-26-0065_Operator_2   T-26-0065
#> T-26-0067_Operator_1     T-26-0067_Operator_1   T-26-0067
#> T-26-0067_Operator_2     T-26-0067_Operator_2   T-26-0067
#> T-26-0068_Operator_1     T-26-0068_Operator_1   T-26-0068
#> T-26-0068_Operator_2     T-26-0068_Operator_2   T-26-0068
#> T-26-0069_Operator_1     T-26-0069_Operator_1   T-26-0069
#> T-26-0069_Operator_2     T-26-0069_Operator_2   T-26-0069
#> T-26-0070_Operator_1     T-26-0070_Operator_1   T-26-0070
#> T-26-0070_Operator_2     T-26-0070_Operator_2   T-26-0070
#> T-26-0071_Operator_1     T-26-0071_Operator_1   T-26-0071
#> T-26-0071_Operator_2     T-26-0071_Operator_2   T-26-0071
#> T-26-0072_Operator_1     T-26-0072_Operator_1   T-26-0072
#> T-26-0072_Operator_2     T-26-0072_Operator_2   T-26-0072
#> T-26-0073_Operator_1     T-26-0073_Operator_1   T-26-0073
#> T-26-0073_Operator_2     T-26-0073_Operator_2   T-26-0073
#> T-26-0074_Operator_1     T-26-0074_Operator_1   T-26-0074
#> T-26-0074_Operator_2     T-26-0074_Operator_2   T-26-0074
#> T-26-0075_Operator_1     T-26-0075_Operator_1   T-26-0075
#> T-26-0075_Operator_2     T-26-0075_Operator_2   T-26-0075
#> T-26-0076_Operator_1     T-26-0076_Operator_1   T-26-0076
#> T-26-0076_Operator_2     T-26-0076_Operator_2   T-26-0076
#> T-26-0077_Operator_1     T-26-0077_Operator_1   T-26-0077
#> T-26-0077_Operator_2     T-26-0077_Operator_2   T-26-0077
#> T-26-0078_Operator_1     T-26-0078_Operator_1   T-26-0078
#> T-26-0078_Operator_2     T-26-0078_Operator_2   T-26-0078
#> T-26-0079_Operator_1     T-26-0079_Operator_1   T-26-0079
#> T-26-0079_Operator_2     T-26-0079_Operator_2   T-26-0079
#> T-26-0080_Operator_1     T-26-0080_Operator_1   T-26-0080
#> T-26-0080_Operator_2     T-26-0080_Operator_2   T-26-0080
#> T-26-0081_Operator_1     T-26-0081_Operator_1   T-26-0081
#> T-26-0081_Operator_2     T-26-0081_Operator_2   T-26-0081
#> T-26-0082_Operator_1     T-26-0082_Operator_1   T-26-0082
#> T-26-0082_Operator_2     T-26-0082_Operator_2   T-26-0082
#> T-26-0083_Operator_1     T-26-0083_Operator_1   T-26-0083
#> T-26-0083_Operator_2     T-26-0083_Operator_2   T-26-0083
#> T-26-0084_Operator_1     T-26-0084_Operator_1   T-26-0084
#> T-26-0084_Operator_2     T-26-0084_Operator_2   T-26-0084
#> T-26-0085_Operator_1     T-26-0085_Operator_1   T-26-0085
#> T-26-0085_Operator_2     T-26-0085_Operator_2   T-26-0085
#> T-26-0086_Operator_1     T-26-0086_Operator_1   T-26-0086
#> T-26-0086_Operator_2     T-26-0086_Operator_2   T-26-0086
#> T-26-0087_Operator_1     T-26-0087_Operator_1   T-26-0087
#> T-26-0087_Operator_2     T-26-0087_Operator_2   T-26-0087
#> T-26-0088_Operator_1     T-26-0088_Operator_1   T-26-0088
#> T-26-0088_Operator_2     T-26-0088_Operator_2   T-26-0088
#> T-26-0089_Operator_1     T-26-0089_Operator_1   T-26-0089
#> T-26-0089_Operator_2     T-26-0089_Operator_2   T-26-0089
#> T-26-0090_Operator_1     T-26-0090_Operator_1   T-26-0090
#> T-26-0090_Operator_2     T-26-0090_Operator_2   T-26-0090
#> T-26-0091_Operator_1     T-26-0091_Operator_1   T-26-0091
#> T-26-0091_Operator_2     T-26-0091_Operator_2   T-26-0091
#> T-26-0092_Operator_1     T-26-0092_Operator_1   T-26-0092
#> T-26-0092_Operator_2     T-26-0092_Operator_2   T-26-0092
#> T-26-0093_Operator_1     T-26-0093_Operator_1   T-26-0093
#> T-26-0093_Operator_2     T-26-0093_Operator_2   T-26-0093
#> T-26-0094_Operator_1     T-26-0094_Operator_1   T-26-0094
#> T-26-0094_Operator_2     T-26-0094_Operator_2   T-26-0094
#> T-26-0095_Operator_1     T-26-0095_Operator_1   T-26-0095
#> T-26-0095_Operator_2     T-26-0095_Operator_2   T-26-0095
#> T-26-0096_Operator_1     T-26-0096_Operator_1   T-26-0096
#> T-26-0096_Operator_2     T-26-0096_Operator_2   T-26-0096
#> T-26-0097_Operator_1     T-26-0097_Operator_1   T-26-0097
#> T-26-0097_Operator_2     T-26-0097_Operator_2   T-26-0097
#> T-26-0098_Operator_1     T-26-0098_Operator_1   T-26-0098
#> T-26-0098_Operator_2     T-26-0098_Operator_2   T-26-0098
#> T-26-0099_Operator_1     T-26-0099_Operator_1   T-26-0099
#> T-26-0099_Operator_2     T-26-0099_Operator_2   T-26-0099
#> T-26-0100_Operator_1     T-26-0100_Operator_1   T-26-0100
#> T-26-0100_Operator_2     T-26-0100_Operator_2   T-26-0100
#> T-26-0101_Operator_1     T-26-0101_Operator_1   T-26-0101
#> T-26-0101_Operator_2     T-26-0101_Operator_2   T-26-0101
#> T-26-0102_Operator_1     T-26-0102_Operator_1   T-26-0102
#> T-26-0102_Operator_2     T-26-0102_Operator_2   T-26-0102
#> T-26-0103_Operator_1     T-26-0103_Operator_1   T-26-0103
#> T-26-0103_Operator_2     T-26-0103_Operator_2   T-26-0103
#> T-26-0104_Operator_1     T-26-0104_Operator_1   T-26-0104
#> T-26-0104_Operator_2     T-26-0104_Operator_2   T-26-0104
#> T-26-0107_Operator_1     T-26-0107_Operator_1   T-26-0107
#> T-26-0107_Operator_2     T-26-0107_Operator_2   T-26-0107
#> T-26-0108_Operator_1     T-26-0108_Operator_1   T-26-0108
#> T-26-0108_Operator_2     T-26-0108_Operator_2   T-26-0108
#> T-26-0109_Operator_1     T-26-0109_Operator_1   T-26-0109
#> T-26-0109_Operator_2     T-26-0109_Operator_2   T-26-0109
#> T-26-0111_Operator_1     T-26-0111_Operator_1   T-26-0111
#> T-26-0111_Operator_2     T-26-0111_Operator_2   T-26-0111
#> T-26-0112-2_Operator_1 T-26-0112-2_Operator_1 T-26-0112-2
#> T-26-0112-2_Operator_2 T-26-0112-2_Operator_2 T-26-0112-2
#> T-26-0112_Operator_1     T-26-0112_Operator_1   T-26-0112
#> T-26-0112_Operator_2     T-26-0112_Operator_2   T-26-0112
#> T-26-0113_Operator_1     T-26-0113_Operator_1   T-26-0113
#> T-26-0113_Operator_2     T-26-0113_Operator_2   T-26-0113
#> T-26-0114_Operator_1     T-26-0114_Operator_1   T-26-0114
#> T-26-0114_Operator_2     T-26-0114_Operator_2   T-26-0114
#> T-26-0115_Operator_1     T-26-0115_Operator_1   T-26-0115
#> T-26-0115_Operator_2     T-26-0115_Operator_2   T-26-0115
#> T-26-0116_Operator_1     T-26-0116_Operator_1   T-26-0116
#> T-26-0116_Operator_2     T-26-0116_Operator_2   T-26-0116
#> T-26-0117_Operator_1     T-26-0117_Operator_1   T-26-0117
#> T-26-0117_Operator_2     T-26-0117_Operator_2   T-26-0117
#> T-26-0118_Operator_1     T-26-0118_Operator_1   T-26-0118
#> T-26-0118_Operator_2     T-26-0118_Operator_2   T-26-0118
#> T-26-0120_Operator_1     T-26-0120_Operator_1   T-26-0120
#> T-26-0120_Operator_2     T-26-0120_Operator_2   T-26-0120
#> T-26-0121_Operator_1     T-26-0121_Operator_1   T-26-0121
#> T-26-0121_Operator_2     T-26-0121_Operator_2   T-26-0121
#> T-26-0122_Operator_1     T-26-0122_Operator_1   T-26-0122
#> T-26-0122_Operator_2     T-26-0122_Operator_2   T-26-0122
#> T-26-0123_Operator_1     T-26-0123_Operator_1   T-26-0123
#> T-26-0123_Operator_2     T-26-0123_Operator_2   T-26-0123
#> T-26-0125_Operator_1     T-26-0125_Operator_1   T-26-0125
#> T-26-0125_Operator_2     T-26-0125_Operator_2   T-26-0125
#> T-26-0126_Operator_1     T-26-0126_Operator_1   T-26-0126
#> T-26-0126_Operator_2     T-26-0126_Operator_2   T-26-0126
#> T-26-0127_Operator_1     T-26-0127_Operator_1   T-26-0127
#> T-26-0127_Operator_2     T-26-0127_Operator_2   T-26-0127
#> T-26-0128_Operator_1     T-26-0128_Operator_1   T-26-0128
#> T-26-0128_Operator_2     T-26-0128_Operator_2   T-26-0128
#> T-26-0130_Operator_1     T-26-0130_Operator_1   T-26-0130
#> T-26-0130_Operator_2     T-26-0130_Operator_2   T-26-0130
#> T-26-0131_Operator_1     T-26-0131_Operator_1   T-26-0131
#> T-26-0131_Operator_2     T-26-0131_Operator_2   T-26-0131
#> T-26-0132_Operator_1     T-26-0132_Operator_1   T-26-0132
#> T-26-0132_Operator_2     T-26-0132_Operator_2   T-26-0132
#> T-26-0133_Operator_1     T-26-0133_Operator_1   T-26-0133
#> T-26-0133_Operator_2     T-26-0133_Operator_2   T-26-0133
#> T-26-0134_Operator_1     T-26-0134_Operator_1   T-26-0134
#> T-26-0134_Operator_2     T-26-0134_Operator_2   T-26-0134
#> T-26-0135_Operator_1     T-26-0135_Operator_1   T-26-0135
#> T-26-0135_Operator_2     T-26-0135_Operator_2   T-26-0135
#> T-26-0136_Operator_1     T-26-0136_Operator_1   T-26-0136
#> T-26-0136_Operator_2     T-26-0136_Operator_2   T-26-0136
#> T-26-0137_Operator_1     T-26-0137_Operator_1   T-26-0137
#> T-26-0137_Operator_2     T-26-0137_Operator_2   T-26-0137
#> T-26-0138_Operator_1     T-26-0138_Operator_1   T-26-0138
#> T-26-0138_Operator_2     T-26-0138_Operator_2   T-26-0138
#> T-26-0139_Operator_1     T-26-0139_Operator_1   T-26-0139
#> T-26-0139_Operator_2     T-26-0139_Operator_2   T-26-0139
#> T-26-0140_Operator_1     T-26-0140_Operator_1   T-26-0140
#> T-26-0140_Operator_2     T-26-0140_Operator_2   T-26-0140
#> T-26-0141_Operator_1     T-26-0141_Operator_1   T-26-0141
#> T-26-0141_Operator_2     T-26-0141_Operator_2   T-26-0141
#> T-26-0142_Operator_1     T-26-0142_Operator_1   T-26-0142
#> T-26-0142_Operator_2     T-26-0142_Operator_2   T-26-0142
#> T-26-0143_Operator_1     T-26-0143_Operator_1   T-26-0143
#> T-26-0143_Operator_2     T-26-0143_Operator_2   T-26-0143
#> T-26-0144_Operator_1     T-26-0144_Operator_1   T-26-0144
#> T-26-0144_Operator_2     T-26-0144_Operator_2   T-26-0144
#> T-26-0145_Operator_1     T-26-0145_Operator_1   T-26-0145
#> T-26-0145_Operator_2     T-26-0145_Operator_2   T-26-0145
#> T-26-0146_Operator_1     T-26-0146_Operator_1   T-26-0146
#> T-26-0146_Operator_2     T-26-0146_Operator_2   T-26-0146
#> T-26-0147_Operator_1     T-26-0147_Operator_1   T-26-0147
#> T-26-0147_Operator_2     T-26-0147_Operator_2   T-26-0147
#> T-26-0148_Operator_1     T-26-0148_Operator_1   T-26-0148
#> T-26-0148_Operator_2     T-26-0148_Operator_2   T-26-0148
#> T-26-0149_Operator_1     T-26-0149_Operator_1   T-26-0149
#> T-26-0149_Operator_2     T-26-0149_Operator_2   T-26-0149
#> T-26-0150_Operator_1     T-26-0150_Operator_1   T-26-0150
#> T-26-0150_Operator_2     T-26-0150_Operator_2   T-26-0150
#> T-26-0151_Operator_1     T-26-0151_Operator_1   T-26-0151
#> T-26-0151_Operator_2     T-26-0151_Operator_2   T-26-0151
#> T-26-0152_Operator_1     T-26-0152_Operator_1   T-26-0152
#> T-26-0152_Operator_2     T-26-0152_Operator_2   T-26-0152
#> T-26-0153_Operator_1     T-26-0153_Operator_1   T-26-0153
#> T-26-0153_Operator_2     T-26-0153_Operator_2   T-26-0153
#> T-26-0154_Operator_1     T-26-0154_Operator_1   T-26-0154
#> T-26-0154_Operator_2     T-26-0154_Operator_2   T-26-0154
#> T-26-0155_Operator_1     T-26-0155_Operator_1   T-26-0155
#> T-26-0155_Operator_2     T-26-0155_Operator_2   T-26-0155
#> T-26-0156_Operator_1     T-26-0156_Operator_1   T-26-0156
#> T-26-0156_Operator_2     T-26-0156_Operator_2   T-26-0156
#> T-26-0157_Operator_1     T-26-0157_Operator_1   T-26-0157
#> T-26-0157_Operator_2     T-26-0157_Operator_2   T-26-0157
#> T-26-0158_Operator_1     T-26-0158_Operator_1   T-26-0158
#> T-26-0158_Operator_2     T-26-0158_Operator_2   T-26-0158
#> T-26-0159_Operator_1     T-26-0159_Operator_1   T-26-0159
#> T-26-0159_Operator_2     T-26-0159_Operator_2   T-26-0159
#> T-26-0160_Operator_1     T-26-0160_Operator_1   T-26-0160
#> T-26-0160_Operator_2     T-26-0160_Operator_2   T-26-0160
#> T-26-0161_Operator_1     T-26-0161_Operator_1   T-26-0161
#> T-26-0161_Operator_2     T-26-0161_Operator_2   T-26-0161
#> T-26-0162_Operator_1     T-26-0162_Operator_1   T-26-0162
#> T-26-0162_Operator_2     T-26-0162_Operator_2   T-26-0162
#> T-26-0163_Operator_1     T-26-0163_Operator_1   T-26-0163
#> T-26-0163_Operator_2     T-26-0163_Operator_2   T-26-0163
#> T-26-0164_Operator_1     T-26-0164_Operator_1   T-26-0164
#> T-26-0164_Operator_2     T-26-0164_Operator_2   T-26-0164
#> T-26-0165_Operator_1     T-26-0165_Operator_1   T-26-0165
#> T-26-0165_Operator_2     T-26-0165_Operator_2   T-26-0165
#> T-26-0166_Operator_1     T-26-0166_Operator_1   T-26-0166
#> T-26-0166_Operator_2     T-26-0166_Operator_2   T-26-0166
#> T-26-0167_Operator_1     T-26-0167_Operator_1   T-26-0167
#> T-26-0167_Operator_2     T-26-0167_Operator_2   T-26-0167
#> T-26-0168_Operator_1     T-26-0168_Operator_1   T-26-0168
#> T-26-0168_Operator_2     T-26-0168_Operator_2   T-26-0168
#> T-26-0169_Operator_1     T-26-0169_Operator_1   T-26-0169
#> T-26-0169_Operator_2     T-26-0169_Operator_2   T-26-0169
#> T-26-0170_Operator_1     T-26-0170_Operator_1   T-26-0170
#> T-26-0170_Operator_2     T-26-0170_Operator_2   T-26-0170
#> T-26-0171_Operator_1     T-26-0171_Operator_1   T-26-0171
#> T-26-0171_Operator_2     T-26-0171_Operator_2   T-26-0171
#> T-26-0172_Operator_1     T-26-0172_Operator_1   T-26-0172
#> T-26-0172_Operator_2     T-26-0172_Operator_2   T-26-0172
#> T-26-0173_Operator_1     T-26-0173_Operator_1   T-26-0173
#> T-26-0173_Operator_2     T-26-0173_Operator_2   T-26-0173
#> T-26-0174_Operator_1     T-26-0174_Operator_1   T-26-0174
#> T-26-0174_Operator_2     T-26-0174_Operator_2   T-26-0174
#> T-26-0175_Operator_1     T-26-0175_Operator_1   T-26-0175
#> T-26-0175_Operator_2     T-26-0175_Operator_2   T-26-0175
#> T-26-0176_Operator_1     T-26-0176_Operator_1   T-26-0176
#> T-26-0176_Operator_2     T-26-0176_Operator_2   T-26-0176
#> T-26-0177_Operator_1     T-26-0177_Operator_1   T-26-0177
#> T-26-0177_Operator_2     T-26-0177_Operator_2   T-26-0177
#> T-26-0178_Operator_1     T-26-0178_Operator_1   T-26-0178
#> T-26-0178_Operator_2     T-26-0178_Operator_2   T-26-0178
#> T-26-0179-3_Operator_1 T-26-0179-3_Operator_1 T-26-0179-3
#> T-26-0179-3_Operator_2 T-26-0179-3_Operator_2 T-26-0179-3
#> T-26-0179_Operator_1     T-26-0179_Operator_1   T-26-0179
#> T-26-0179_Operator_2     T-26-0179_Operator_2   T-26-0179
#> T-26-0180_Operator_1     T-26-0180_Operator_1   T-26-0180
#> T-26-0180_Operator_2     T-26-0180_Operator_2   T-26-0180
#> T-26-0181_Operator_1     T-26-0181_Operator_1   T-26-0181
#> T-26-0181_Operator_2     T-26-0181_Operator_2   T-26-0181
#> T-26-0182_Operator_1     T-26-0182_Operator_1   T-26-0182
#> T-26-0182_Operator_2     T-26-0182_Operator_2   T-26-0182
#> T-26-0183_Operator_1     T-26-0183_Operator_1   T-26-0183
#> T-26-0183_Operator_2     T-26-0183_Operator_2   T-26-0183
#> T-26-0184_Operator_1     T-26-0184_Operator_1   T-26-0184
#> T-26-0184_Operator_2     T-26-0184_Operator_2   T-26-0184
#> T-26-0185_Operator_1     T-26-0185_Operator_1   T-26-0185
#> T-26-0185_Operator_2     T-26-0185_Operator_2   T-26-0185
#> T-26-0186_Operator_1     T-26-0186_Operator_1   T-26-0186
#> T-26-0186_Operator_2     T-26-0186_Operator_2   T-26-0186
#> T-26-0187_Operator_1     T-26-0187_Operator_1   T-26-0187
#> T-26-0187_Operator_2     T-26-0187_Operator_2   T-26-0187
#> T-26-0188_Operator_1     T-26-0188_Operator_1   T-26-0188
#> T-26-0188_Operator_2     T-26-0188_Operator_2   T-26-0188
#> T-26-0189_Operator_1     T-26-0189_Operator_1   T-26-0189
#> T-26-0189_Operator_2     T-26-0189_Operator_2   T-26-0189
#> T-26-0190_Operator_1     T-26-0190_Operator_1   T-26-0190
#> T-26-0190_Operator_2     T-26-0190_Operator_2   T-26-0190
#> T-26-0191_Operator_1     T-26-0191_Operator_1   T-26-0191
#> T-26-0191_Operator_2     T-26-0191_Operator_2   T-26-0191
#> T-26-0192_Operator_1     T-26-0192_Operator_1   T-26-0192
#> T-26-0192_Operator_2     T-26-0192_Operator_2   T-26-0192
#> T-26-0193_Operator_1     T-26-0193_Operator_1   T-26-0193
#> T-26-0193_Operator_2     T-26-0193_Operator_2   T-26-0193
#> T-26-0194_Operator_1     T-26-0194_Operator_1   T-26-0194
#> T-26-0194_Operator_2     T-26-0194_Operator_2   T-26-0194
#> T-26-0195_Operator_1     T-26-0195_Operator_1   T-26-0195
#> T-26-0195_Operator_2     T-26-0195_Operator_2   T-26-0195
#> T-26-0196_Operator_1     T-26-0196_Operator_1   T-26-0196
#> T-26-0196_Operator_2     T-26-0196_Operator_2   T-26-0196
#> T-26-0197_Operator_1     T-26-0197_Operator_1   T-26-0197
#> T-26-0197_Operator_2     T-26-0197_Operator_2   T-26-0197
#> T-26-0198_Operator_1     T-26-0198_Operator_1   T-26-0198
#> T-26-0198_Operator_2     T-26-0198_Operator_2   T-26-0198
#> T-26-0199_Operator_1     T-26-0199_Operator_1   T-26-0199
#> T-26-0199_Operator_2     T-26-0199_Operator_2   T-26-0199
#> T-26-0200_Operator_1     T-26-0200_Operator_1   T-26-0200
#> T-26-0200_Operator_2     T-26-0200_Operator_2   T-26-0200
#> T-26-0201_Operator_1     T-26-0201_Operator_1   T-26-0201
#> T-26-0201_Operator_2     T-26-0201_Operator_2   T-26-0201
#> T-26-0202_Operator_1     T-26-0202_Operator_1   T-26-0202
#> T-26-0202_Operator_2     T-26-0202_Operator_2   T-26-0202
#> T-26-0203_Operator_1     T-26-0203_Operator_1   T-26-0203
#> T-26-0203_Operator_2     T-26-0203_Operator_2   T-26-0203
#> T-26-0204_Operator_1     T-26-0204_Operator_1   T-26-0204
#> T-26-0204_Operator_2     T-26-0204_Operator_2   T-26-0204
#> T-26-0205_Operator_1     T-26-0205_Operator_1   T-26-0205
#> T-26-0205_Operator_2     T-26-0205_Operator_2   T-26-0205
#> T-26-0206_Operator_1     T-26-0206_Operator_1   T-26-0206
#> T-26-0206_Operator_2     T-26-0206_Operator_2   T-26-0206
#> T-26-0207_Operator_1     T-26-0207_Operator_1   T-26-0207
#> T-26-0207_Operator_2     T-26-0207_Operator_2   T-26-0207
#> T-26-0208_Operator_1     T-26-0208_Operator_1   T-26-0208
#> T-26-0208_Operator_2     T-26-0208_Operator_2   T-26-0208
#> T-26-0209_Operator_1     T-26-0209_Operator_1   T-26-0209
#> T-26-0209_Operator_2     T-26-0209_Operator_2   T-26-0209
#> T-26-0210_Operator_1     T-26-0210_Operator_1   T-26-0210
#> T-26-0210_Operator_2     T-26-0210_Operator_2   T-26-0210
#> T-26-0211_Operator_1     T-26-0211_Operator_1   T-26-0211
#> T-26-0211_Operator_2     T-26-0211_Operator_2   T-26-0211
#> T-26-0212_Operator_1     T-26-0212_Operator_1   T-26-0212
#> T-26-0212_Operator_2     T-26-0212_Operator_2   T-26-0212
#> T-26-0213_Operator_1     T-26-0213_Operator_1   T-26-0213
#> T-26-0213_Operator_2     T-26-0213_Operator_2   T-26-0213
#> T-26-0214_Operator_1     T-26-0214_Operator_1   T-26-0214
#> T-26-0214_Operator_2     T-26-0214_Operator_2   T-26-0214
#> T-26-0215_Operator_1     T-26-0215_Operator_1   T-26-0215
#> T-26-0215_Operator_2     T-26-0215_Operator_2   T-26-0215
#> T-26-0216_Operator_1     T-26-0216_Operator_1   T-26-0216
#> T-26-0216_Operator_2     T-26-0216_Operator_2   T-26-0216
#> T-26-0217_Operator_1     T-26-0217_Operator_1   T-26-0217
#> T-26-0217_Operator_2     T-26-0217_Operator_2   T-26-0217
#> T-26-0218_Operator_1     T-26-0218_Operator_1   T-26-0218
#> T-26-0218_Operator_2     T-26-0218_Operator_2   T-26-0218
#> T-26-0219_Operator_1     T-26-0219_Operator_1   T-26-0219
#> T-26-0219_Operator_2     T-26-0219_Operator_2   T-26-0219
#> T-26-0220_Operator_1     T-26-0220_Operator_1   T-26-0220
#> T-26-0220_Operator_2     T-26-0220_Operator_2   T-26-0220
#> T-26-0221_Operator_1     T-26-0221_Operator_1   T-26-0221
#> T-26-0221_Operator_2     T-26-0221_Operator_2   T-26-0221
#> T-26-0222_Operator_1     T-26-0222_Operator_1   T-26-0222
#> T-26-0222_Operator_2     T-26-0222_Operator_2   T-26-0222
#> T-26-0223_Operator_1     T-26-0223_Operator_1   T-26-0223
#> T-26-0223_Operator_2     T-26-0223_Operator_2   T-26-0223
#> T-26-0224_Operator_1     T-26-0224_Operator_1   T-26-0224
#> T-26-0224_Operator_2     T-26-0224_Operator_2   T-26-0224
#> T-26-0225_Operator_1     T-26-0225_Operator_1   T-26-0225
#> T-26-0225_Operator_2     T-26-0225_Operator_2   T-26-0225
#> T-26-0226_Operator_1     T-26-0226_Operator_1   T-26-0226
#> T-26-0226_Operator_2     T-26-0226_Operator_2   T-26-0226
#> T-26-0227_Operator_1     T-26-0227_Operator_1   T-26-0227
#> T-26-0227_Operator_2     T-26-0227_Operator_2   T-26-0227
#> T-26-0228_Operator_1     T-26-0228_Operator_1   T-26-0228
#> T-26-0228_Operator_2     T-26-0228_Operator_2   T-26-0228
#> T-26-0229_Operator_1     T-26-0229_Operator_1   T-26-0229
#> T-26-0229_Operator_2     T-26-0229_Operator_2   T-26-0229
#> T-26-0230-1_Operator_1 T-26-0230-1_Operator_1 T-26-0230-1
#> T-26-0230-1_Operator_2 T-26-0230-1_Operator_2 T-26-0230-1
#> T-26-0230-2_Operator_1 T-26-0230-2_Operator_1 T-26-0230-2
#> T-26-0230-2_Operator_2 T-26-0230-2_Operator_2 T-26-0230-2
#> T-26-0230-3_Operator_1 T-26-0230-3_Operator_1 T-26-0230-3
#> T-26-0230-3_Operator_2 T-26-0230-3_Operator_2 T-26-0230-3
#> T-26-0230-4_Operator_1 T-26-0230-4_Operator_1 T-26-0230-4
#> T-26-0230-4_Operator_2 T-26-0230-4_Operator_2 T-26-0230-4
#> T-26-0231_Operator_1     T-26-0231_Operator_1   T-26-0231
#> T-26-0231_Operator_2     T-26-0231_Operator_2   T-26-0231
#> T-26-0232_Operator_1     T-26-0232_Operator_1   T-26-0232
#> T-26-0232_Operator_2     T-26-0232_Operator_2   T-26-0232
#> T-26-0233_Operator_1     T-26-0233_Operator_1   T-26-0233
#> T-26-0233_Operator_2     T-26-0233_Operator_2   T-26-0233
#> T-26-0234_Operator_1     T-26-0234_Operator_1   T-26-0234
#> T-26-0234_Operator_2     T-26-0234_Operator_2   T-26-0234
#> T-26-0235_Operator_1     T-26-0235_Operator_1   T-26-0235
#> T-26-0235_Operator_2     T-26-0235_Operator_2   T-26-0235
#> T-26-0236_Operator_1     T-26-0236_Operator_1   T-26-0236
#> T-26-0236_Operator_2     T-26-0236_Operator_2   T-26-0236
#> T-26-0237_Operator_1     T-26-0237_Operator_1   T-26-0237
#> T-26-0237_Operator_2     T-26-0237_Operator_2   T-26-0237
#> T-26-0238_Operator_1     T-26-0238_Operator_1   T-26-0238
#> T-26-0238_Operator_2     T-26-0238_Operator_2   T-26-0238
#> T-26-0239_Operator_1     T-26-0239_Operator_1   T-26-0239
#> T-26-0239_Operator_2     T-26-0239_Operator_2   T-26-0239
#> T-26-0240_Operator_1     T-26-0240_Operator_1   T-26-0240
#> T-26-0240_Operator_2     T-26-0240_Operator_2   T-26-0240
#> T-26-0241_Operator_1     T-26-0241_Operator_1   T-26-0241
#> T-26-0241_Operator_2     T-26-0241_Operator_2   T-26-0241
#> T-26-0242_Operator_1     T-26-0242_Operator_1   T-26-0242
#> T-26-0242_Operator_2     T-26-0242_Operator_2   T-26-0242
#> T-26-0243_Operator_1     T-26-0243_Operator_1   T-26-0243
#> T-26-0243_Operator_2     T-26-0243_Operator_2   T-26-0243
#> T-26-0244_Operator_1     T-26-0244_Operator_1   T-26-0244
#> T-26-0244_Operator_2     T-26-0244_Operator_2   T-26-0244
#> T-26-0245_Operator_1     T-26-0245_Operator_1   T-26-0245
#> T-26-0245_Operator_2     T-26-0245_Operator_2   T-26-0245
#> T-26-0246_Operator_1     T-26-0246_Operator_1   T-26-0246
#> T-26-0246_Operator_2     T-26-0246_Operator_2   T-26-0246
#> T-26-0247_Operator_1     T-26-0247_Operator_1   T-26-0247
#> T-26-0247_Operator_2     T-26-0247_Operator_2   T-26-0247
#> T-26-0248_Operator_1     T-26-0248_Operator_1   T-26-0248
#> T-26-0248_Operator_2     T-26-0248_Operator_2   T-26-0248
#> T-26-0249_Operator_1     T-26-0249_Operator_1   T-26-0249
#> T-26-0249_Operator_2     T-26-0249_Operator_2   T-26-0249
#> T-26-0250_Operator_1     T-26-0250_Operator_1   T-26-0250
#> T-26-0250_Operator_2     T-26-0250_Operator_2   T-26-0250
#> T-26-0251_Operator_1     T-26-0251_Operator_1   T-26-0251
#> T-26-0251_Operator_2     T-26-0251_Operator_2   T-26-0251
#> T-26-0252_Operator_1     T-26-0252_Operator_1   T-26-0252
#> T-26-0252_Operator_2     T-26-0252_Operator_2   T-26-0252
#> T-26-0261-1_Operator_1 T-26-0261-1_Operator_1 T-26-0261-1
#> T-26-0261-1_Operator_2 T-26-0261-1_Operator_2 T-26-0261-1
#> T-26-0261-2_Operator_1 T-26-0261-2_Operator_1 T-26-0261-2
#> T-26-0261-2_Operator_2 T-26-0261-2_Operator_2 T-26-0261-2
#> T-26-0261-3_Operator_1 T-26-0261-3_Operator_1 T-26-0261-3
#> T-26-0261-3_Operator_2 T-26-0261-3_Operator_2 T-26-0261-3
#> T-26-0261-4_Operator_1 T-26-0261-4_Operator_1 T-26-0261-4
#> T-26-0261-4_Operator_2 T-26-0261-4_Operator_2 T-26-0261-4
#> T-26-0261-5_Operator_1 T-26-0261-5_Operator_1 T-26-0261-5
#> T-26-0261-5_Operator_2 T-26-0261-5_Operator_2 T-26-0261-5
#> T-26-0262-1_Operator_1 T-26-0262-1_Operator_1 T-26-0262-1
#> T-26-0262-1_Operator_2 T-26-0262-1_Operator_2 T-26-0262-1
#> T-26-0262-2_Operator_1 T-26-0262-2_Operator_1 T-26-0262-2
#> T-26-0262-2_Operator_2 T-26-0262-2_Operator_2 T-26-0262-2
#> T-26-0263_Operator_1     T-26-0263_Operator_1   T-26-0263
#> T-26-0263_Operator_2     T-26-0263_Operator_2   T-26-0263
#> T-26-0264-1_Operator_1 T-26-0264-1_Operator_1 T-26-0264-1
#> T-26-0264-1_Operator_2 T-26-0264-1_Operator_2 T-26-0264-1
#> T-26-0264-2_Operator_1 T-26-0264-2_Operator_1 T-26-0264-2
#> T-26-0264-2_Operator_2 T-26-0264-2_Operator_2 T-26-0264-2
#> T-26-0264-3_Operator_1 T-26-0264-3_Operator_1 T-26-0264-3
#> T-26-0264-3_Operator_2 T-26-0264-3_Operator_2 T-26-0264-3
#> T-26-0264-4_Operator_1 T-26-0264-4_Operator_1 T-26-0264-4
#> T-26-0264-4_Operator_2 T-26-0264-4_Operator_2 T-26-0264-4
#> T-26-0265_Operator_1     T-26-0265_Operator_1   T-26-0265
#> T-26-0265_Operator_2     T-26-0265_Operator_2   T-26-0265
#> T-26-0266_Operator_1     T-26-0266_Operator_1   T-26-0266
#> T-26-0266_Operator_2     T-26-0266_Operator_2   T-26-0266
#> T-26-0267_Operator_1     T-26-0267_Operator_1   T-26-0267
#> T-26-0267_Operator_2     T-26-0267_Operator_2   T-26-0267
#> T-26-0268_Operator_1     T-26-0268_Operator_1   T-26-0268
#> T-26-0268_Operator_2     T-26-0268_Operator_2   T-26-0268
#> T-26-0269_Operator_1     T-26-0269_Operator_1   T-26-0269
#> T-26-0269_Operator_2     T-26-0269_Operator_2   T-26-0269
#> T-26-0270-1_Operator_1 T-26-0270-1_Operator_1 T-26-0270-1
#> T-26-0270-1_Operator_2 T-26-0270-1_Operator_2 T-26-0270-1
#> T-26-0270-2_Operator_1 T-26-0270-2_Operator_1 T-26-0270-2
#> T-26-0270-2_Operator_2 T-26-0270-2_Operator_2 T-26-0270-2
#> T-26-0271_Operator_1     T-26-0271_Operator_1   T-26-0271
#> T-26-0271_Operator_2     T-26-0271_Operator_2   T-26-0271
#> T-26-0272_Operator_1     T-26-0272_Operator_1   T-26-0272
#> T-26-0272_Operator_2     T-26-0272_Operator_2   T-26-0272
#> T-26-0273_Operator_1     T-26-0273_Operator_1   T-26-0273
#> T-26-0273_Operator_2     T-26-0273_Operator_2   T-26-0273
#> T-26-0274_Operator_1     T-26-0274_Operator_1   T-26-0274
#> T-26-0274_Operator_2     T-26-0274_Operator_2   T-26-0274
#> T-26-0275_Operator_1     T-26-0275_Operator_1   T-26-0275
#> T-26-0275_Operator_2     T-26-0275_Operator_2   T-26-0275
#> T-26-0276_Operator_1     T-26-0276_Operator_1   T-26-0276
#> T-26-0276_Operator_2     T-26-0276_Operator_2   T-26-0276
#> T-26-0277_Operator_1     T-26-0277_Operator_1   T-26-0277
#> T-26-0277_Operator_2     T-26-0277_Operator_2   T-26-0277
#> T-26-0278-1_Operator_1 T-26-0278-1_Operator_1 T-26-0278-1
#> T-26-0278-1_Operator_2 T-26-0278-1_Operator_2 T-26-0278-1
#> T-26-0278-2_Operator_1 T-26-0278-2_Operator_1 T-26-0278-2
#> T-26-0278-2_Operator_2 T-26-0278-2_Operator_2 T-26-0278-2
#> T-26-0279_Operator_1     T-26-0279_Operator_1   T-26-0279
#> T-26-0279_Operator_2     T-26-0279_Operator_2   T-26-0279
#>                                          species population replicate
#> T-26-0001_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0001_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0002_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0002_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0003_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0003_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0004_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0004_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0005_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0005_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0006_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0006_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0007_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0007_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0008_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0008_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0009_Operator_1            Lepomis gibbosus       <NA>         1
#> T-26-0009_Operator_2            Lepomis gibbosus       <NA>         2
#> T-26-0010_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0010_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0011_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0011_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0012_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0012_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0013_Operator_1               Barbus barbus       <NA>         1
#> T-26-0013_Operator_2               Barbus barbus       <NA>         2
#> T-26-0014_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0014_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0015_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0015_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0016_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0016_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0017_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0017_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0018_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0018_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0019_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0019_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0020_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0020_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0021_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0021_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0022_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0022_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0023-2_Operator_1         Phoxinus phoxinus       <NA>         1
#> T-26-0023-2_Operator_2         Phoxinus phoxinus       <NA>         2
#> T-26-0024_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0024_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0025_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0025_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0026_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0026_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0027_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0027_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0028_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0028_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0029_Operator_1            Lepomis gibbosus       <NA>         1
#> T-26-0029_Operator_2            Lepomis gibbosus       <NA>         2
#> T-26-0030_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0030_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0031_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0031_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0032_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0032_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0033_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0033_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0034_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0034_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0035_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0035_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0036_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0036_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0037_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0037_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0038_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0038_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0039_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0039_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0040_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0040_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0041_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0041_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0042_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0042_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0043_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0043_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0044_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0044_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0045_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0045_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0046_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0046_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0047_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0047_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0048_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0048_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0049_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0049_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0050_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0050_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0051_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0051_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0052_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0052_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0053_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0053_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0054_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0054_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0055_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0055_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0056-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0056-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0057_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0057_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0058_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0058_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0059_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0059_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0060_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0060_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0061_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0061_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0062_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0062_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0063_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0063_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0064_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0064_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0065_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0065_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0067_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0067_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0068_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0068_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0069_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0069_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0070_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0070_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0071_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0071_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0072_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0072_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0073_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0073_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0074_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0074_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0075_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0075_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0076_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0076_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0077_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0077_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0078_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0078_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0079_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0079_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0080_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0080_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0081_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0081_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0082_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0082_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0083_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0083_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0084_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0084_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0085_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0085_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0086_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0086_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0087_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0087_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0088_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0088_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0089_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0089_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0090_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0090_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0091_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0091_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0092_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0092_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0093_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0093_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0094_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0094_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0095_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0095_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0096_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0096_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0097_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0097_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0098_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0098_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0099_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0099_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0100_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0100_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0101_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0101_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0102_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0102_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0103_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0103_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0104_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0104_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0107_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0107_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0108_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0108_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0109_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0109_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0111_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0111_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0112-2_Operator_1 Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0112-2_Operator_2 Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0112_Operator_1   Phoxinus phoxinus/bigerri       <NA>         1
#> T-26-0112_Operator_2   Phoxinus phoxinus/bigerri       <NA>         2
#> T-26-0113_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0113_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0114_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0114_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0115_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0115_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0116_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0116_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0117_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0117_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0118_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0118_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0120_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0120_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0121_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0121_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0122_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0122_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0123_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0123_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0125_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0125_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0126_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0126_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0127_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0127_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0128_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0128_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0130_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0130_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0131_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0131_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0132_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0132_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0133_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0133_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0134_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0134_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0135_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0135_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0136_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0136_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0137_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0137_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0138_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0138_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0139_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0139_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0140_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0140_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0141_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0141_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0142_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0142_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0143_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0143_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0144_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0144_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0145_Operator_1                                   <NA>         1
#> T-26-0145_Operator_2                                   <NA>         2
#> T-26-0146_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0146_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0147_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0147_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0148_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0148_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0149_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0149_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0150_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0150_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0151_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0151_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0152_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0152_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0153_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0153_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0154_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0154_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0155_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0155_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0156_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0156_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0157_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0157_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0158_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0158_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0159_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0159_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0160_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0160_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0161_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0161_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0162_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0162_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0163_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0163_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0164_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0164_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0165_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0165_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0166_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0166_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0167_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0167_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0168_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0168_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0169_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0169_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0170_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0170_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0171_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0171_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0172_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0172_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0173_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0173_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0174_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0174_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0175_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0175_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0176_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0176_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0177_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0177_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0178_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0178_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0179-3_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0179-3_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0179_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0179_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0180_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0180_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0181_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0181_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0182_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0182_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0183_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0183_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0184_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0184_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0185_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0185_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0186_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0186_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0187_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0187_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0188_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0188_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0189_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0189_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0190_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0190_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0191_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0191_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0192_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0192_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0193_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0193_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0194_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0194_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0195_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0195_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0196_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0196_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0197_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0197_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0198_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0198_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0199_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0199_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0200_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0200_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0201_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0201_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0202_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0202_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0203_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0203_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0204_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0204_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0205_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0205_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0206_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0206_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0207_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0207_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0208_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0208_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0209_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0209_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0210_Operator_1               Barbus barbus       <NA>         1
#> T-26-0210_Operator_2               Barbus barbus       <NA>         2
#> T-26-0211_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0211_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0212_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0212_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0213_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0213_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0214_Operator_1     Leuciscus burdigalensis       <NA>         1
#> T-26-0214_Operator_2     Leuciscus burdigalensis       <NA>         2
#> T-26-0215_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0215_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0216_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0216_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0217_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0217_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0218_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0218_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0219_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0219_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0220_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0220_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0221_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0221_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0222_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0222_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0223_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0223_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0224_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0224_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0225_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0225_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0226_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0226_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0227_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0227_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0228_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0228_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0229_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0229_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0230-1_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-1_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-2_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-2_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-3_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-3_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0230-4_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0230-4_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0231_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0231_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0232_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0232_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0233_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0233_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0234_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0234_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0235_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0235_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0236_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0236_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0237_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0237_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0238_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0238_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0239_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0239_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0240_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0240_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0241_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0241_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0242_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0242_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0243_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0243_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0244_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0244_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0245_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0245_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0246_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0246_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0247_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0247_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0248_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0248_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0249_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0249_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0250_Operator_1           Phoxinus phoxinus       <NA>         1
#> T-26-0250_Operator_2           Phoxinus phoxinus       <NA>         2
#> T-26-0251_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0251_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0252_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0252_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0261-1_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-1_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-3_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-3_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-4_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-4_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0261-5_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0261-5_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0262-1_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0262-1_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0262-2_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0262-2_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0263_Operator_1            Gobio occitaniae       <NA>         1
#> T-26-0263_Operator_2            Gobio occitaniae       <NA>         2
#> T-26-0264-1_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-1_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-2_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-2_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-3_Operator_1             Barbus barbus       <NA>         1
#> T-26-0264-3_Operator_2             Barbus barbus       <NA>         2
#> T-26-0264-4_Operator_1          Gobio occitaniae       <NA>         1
#> T-26-0264-4_Operator_2          Gobio occitaniae       <NA>         2
#> T-26-0265_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0265_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0266_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0266_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0267_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0267_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0268_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0268_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0269_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0269_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0270-1_Operator_1         Squalius cephalus       <NA>         1
#> T-26-0270-1_Operator_2         Squalius cephalus       <NA>         2
#> T-26-0270-2_Operator_1         Squalius cephalus       <NA>         1
#> T-26-0270-2_Operator_2         Squalius cephalus       <NA>         2
#> T-26-0271_Operator_1           Perca fluviatilis       <NA>         1
#> T-26-0271_Operator_2           Perca fluviatilis       <NA>         2
#> T-26-0272_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0272_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0273_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0273_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0274_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0274_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0275_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0275_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0276_Operator_1           Squalius cephalus       <NA>         1
#> T-26-0276_Operator_2           Squalius cephalus       <NA>         2
#> T-26-0277_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0277_Operator_2         Barbatula barbatula       <NA>         2
#> T-26-0278-1_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0278-1_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0278-2_Operator_1       Barbatula barbatula       <NA>         1
#> T-26-0278-2_Operator_2       Barbatula barbatula       <NA>         2
#> T-26-0279_Operator_1         Barbatula barbatula       <NA>         1
#> T-26-0279_Operator_2         Barbatula barbatula       <NA>         2
#>                          operator        Bl        Bd         Hd         Eh
#> T-26-0001_Operator_1   Operator_1  6.956905 2.1171553 1.18314680 1.52184775
#> T-26-0001_Operator_2   Operator_2  6.909410 1.7949041 1.18314680 1.36365235
#> T-26-0002_Operator_1   Operator_1  8.206057 1.9909529 1.18314680 1.52249892
#> T-26-0002_Operator_2   Operator_2  8.216624 2.0207893 1.18314680 1.53560616
#> T-26-0003_Operator_1   Operator_1  6.967443 1.6928692 1.18314680 1.21165768
#> T-26-0003_Operator_2   Operator_2  6.913182 1.7159790 1.18314680 1.16657065
#> T-26-0004_Operator_1   Operator_1 18.176255 4.5559409 2.07742509 2.77003273
#> T-26-0004_Operator_2   Operator_2 17.783260 4.5636753 2.03145378 2.77399122
#> T-26-0005_Operator_1   Operator_1  5.596071 1.2880802 1.18314680 1.05787210
#> T-26-0005_Operator_2   Operator_2  6.332844 2.1171553 1.18314680 1.52184775
#> T-26-0006_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0006_Operator_2   Operator_2  7.712358 1.9168742 1.18314680 1.32881958
#> T-26-0007_Operator_1   Operator_1 17.379257 3.9181478 1.89111372 2.43503266
#> T-26-0007_Operator_2   Operator_2 17.574467 4.9769778 2.19813968 3.10917326
#> T-26-0008_Operator_1   Operator_1 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0008_Operator_2   Operator_2 13.996664 3.8567416 1.70080238 2.59696033
#> T-26-0009_Operator_1   Operator_1  5.642172 2.3754338 1.20142779 1.42326286
#> T-26-0009_Operator_2   Operator_2  5.510208 2.3900134 1.19458556 1.47378738
#> T-26-0010_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0010_Operator_2   Operator_2  8.468550 2.1171553 1.18314680 1.52184775
#> T-26-0011_Operator_1   Operator_1 25.392853 3.9181478 1.89111372 2.43503266
#> T-26-0011_Operator_2   Operator_2 25.140844 3.9181478 1.89111372 2.43503266
#> T-26-0012_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0012_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0013_Operator_1   Operator_1  8.109554 1.9417022 0.70820412 1.27322269
#> T-26-0013_Operator_2   Operator_2  8.220899 1.9820605 0.70820412 1.33120290
#> T-26-0014_Operator_1   Operator_1  8.493603 2.1291592 1.18314680 1.70885906
#> T-26-0014_Operator_2   Operator_2  8.214899 2.1427808 1.18314680 1.75136827
#> T-26-0015_Operator_1   Operator_1  7.819466 1.8346854 1.18314680 1.38288573
#> T-26-0015_Operator_2   Operator_2  7.517800 1.8792245 1.18314680 1.32901134
#> T-26-0016_Operator_1   Operator_1 10.753049 3.0456843 1.64945945 1.78101836
#> T-26-0016_Operator_2   Operator_2 10.305716 2.7613822 1.55651082 1.45880645
#> T-26-0017_Operator_1   Operator_1  6.726832 1.6402465 1.18314680 1.15552726
#> T-26-0017_Operator_2   Operator_2  6.452745 1.6092342 1.18314680 1.16751601
#> T-26-0018_Operator_1   Operator_1 20.278560 6.1662950 1.46694948 4.35988423
#> T-26-0018_Operator_2   Operator_2 19.167795 3.2599572 1.46694948 1.94407463
#> T-26-0019_Operator_1   Operator_1 13.241658 3.2726988 1.56572789 1.82243630
#> T-26-0019_Operator_2   Operator_2 12.895929 3.2011626 1.52452280 1.79193965
#> T-26-0020_Operator_1   Operator_1  9.224436 2.6190706 1.18314680 2.01936043
#> T-26-0020_Operator_2   Operator_2  9.140239 2.1171553 1.18314680 1.52184775
#> T-26-0021_Operator_1   Operator_1  9.330086 2.6421536 1.37595784 1.28579612
#> T-26-0021_Operator_2   Operator_2  8.823626 2.5099881 1.35584392 1.28691637
#> T-26-0022_Operator_1   Operator_1 15.160318 2.8127576 1.43508258 1.69688740
#> T-26-0022_Operator_2   Operator_2 15.160318 3.9181478 1.38535785 1.65246897
#> T-26-0023-2_Operator_1 Operator_1  3.967063 0.8906095 0.49833079 0.44111884
#> T-26-0023-2_Operator_2 Operator_2  3.954428 1.4949622 0.80085837 0.84847994
#> T-26-0024_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0024_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0025_Operator_1   Operator_1  9.465836 2.6764249 1.18314680 2.16027527
#> T-26-0025_Operator_2   Operator_2  8.206057 2.6127906 1.18314680 2.19584397
#> T-26-0026_Operator_1   Operator_1  9.533145 2.5835183 1.39915422 1.76514292
#> T-26-0026_Operator_2   Operator_2  9.306362 2.5743509 1.18314680 1.80660019
#> T-26-0027_Operator_1   Operator_1  9.895108 2.6291326 1.18314680 2.27495920
#> T-26-0027_Operator_2   Operator_2  9.731939 2.6157876 1.18314680 2.11798437
#> T-26-0028_Operator_1   Operator_1  7.189649 1.9311310 1.18314680 1.49756238
#> T-26-0028_Operator_2   Operator_2  6.991455 1.9535092 1.18314680 1.53814672
#> T-26-0029_Operator_1   Operator_1  5.576190 2.3827236 1.19800668 1.44852512
#> T-26-0029_Operator_2   Operator_2  5.576190 2.3827236 1.19800668 1.44852512
#> T-26-0030_Operator_1   Operator_1 12.584474 3.1025686 1.57554583 2.19843278
#> T-26-0030_Operator_2   Operator_2 12.573432 3.2599572 1.46694948 1.94407463
#> T-26-0031_Operator_1   Operator_1  8.206057 2.0818330 1.18314680 1.63243659
#> T-26-0031_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0032_Operator_1   Operator_1 26.719407 7.1288922 3.67607362 5.69614510
#> T-26-0032_Operator_2   Operator_2 15.160318 7.3226715 3.45258256 5.14724449
#> T-26-0033_Operator_1   Operator_1  8.960122 2.1171553 1.18314680 1.52184775
#> T-26-0033_Operator_2   Operator_2  8.999446 2.5083200 1.18314680 2.02284351
#> T-26-0034_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0034_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0035_Operator_1   Operator_1  5.944340 1.4017315 1.18314680 1.18015056
#> T-26-0035_Operator_2   Operator_2  5.950211 2.1171553 1.18314680 1.52184775
#> T-26-0036_Operator_1   Operator_1 13.393856 3.3361232 1.56328709 2.25435727
#> T-26-0036_Operator_2   Operator_2 13.153902 3.2912097 1.46860041 2.11626628
#> T-26-0037_Operator_1   Operator_1 16.294212 4.2577825 1.96223025 2.98959727
#> T-26-0037_Operator_2   Operator_2 16.231102 4.2484537 1.93040404 2.69652460
#> T-26-0038_Operator_1   Operator_1  6.891866 1.8297464 1.18314680 1.43863180
#> T-26-0038_Operator_2   Operator_2  6.614041 1.7895605 1.18314680 1.34668818
#> T-26-0039_Operator_1   Operator_1  7.783351 2.1312844 0.99975888 1.21787668
#> T-26-0039_Operator_2   Operator_2  7.758650 2.1034719 1.01586592 1.24973000
#> T-26-0040_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0040_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0041_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0041_Operator_2   Operator_2  6.310595 2.1171553 1.18314680 1.52184775
#> T-26-0042_Operator_1   Operator_1  9.260328 2.2660578 1.18314680 1.75665220
#> T-26-0042_Operator_2   Operator_2  9.120995 2.2907217 1.18314680 1.74495525
#> T-26-0043_Operator_1   Operator_1  8.333438 1.8802280 1.18314680 1.16912256
#> T-26-0043_Operator_2   Operator_2  8.206057 1.8520647 1.08582428 1.27777313
#> T-26-0044_Operator_1   Operator_1  8.762759 2.5332347 1.18314680 1.91559352
#> T-26-0044_Operator_2   Operator_2  8.450378 2.1171553 1.18314680 1.52184775
#> T-26-0045_Operator_1   Operator_1 14.432664 3.7250346 1.76427017 2.12983583
#> T-26-0045_Operator_2   Operator_2 13.710136 3.5214603 1.72043935 2.12659074
#> T-26-0046_Operator_1   Operator_1  8.891113 2.2362600 1.18314680 1.70509712
#> T-26-0046_Operator_2   Operator_2  8.359665 2.2282532 1.18314680 1.64792400
#> T-26-0047_Operator_1   Operator_1 27.397544 7.7959037 3.31061099 6.04144575
#> T-26-0047_Operator_2   Operator_2 26.849874 8.0428196 3.36750035 5.75093060
#> T-26-0048_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0048_Operator_2   Operator_2  9.485998 2.1171553 1.18314680 1.52184775
#> T-26-0049_Operator_1   Operator_1 15.160318 3.3167758 1.60846599 1.86967216
#> T-26-0049_Operator_2   Operator_2 15.160318 3.2862615 1.59587345 1.95172922
#> T-26-0050_Operator_1   Operator_1  7.731364 2.1171553 1.18314680 1.52184775
#> T-26-0050_Operator_2   Operator_2  8.206057 0.1205212 0.06514658 0.09120521
#> T-26-0051_Operator_1   Operator_1 10.026297 2.6230682 1.18314680 2.03731683
#> T-26-0051_Operator_2   Operator_2 10.218053 2.7299023 1.64139642 2.11832458
#> T-26-0052_Operator_1   Operator_1 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0052_Operator_2   Operator_2 15.160318 3.9181478 1.73670006 2.10064314
#> T-26-0053_Operator_1   Operator_1 15.200389 4.0809297 1.89904444 2.21047371
#> T-26-0053_Operator_2   Operator_2 15.160318 3.9181478 1.78051131 2.10160343
#> T-26-0054_Operator_1   Operator_1 13.532245 3.5261626 1.75430079 2.23024756
#> T-26-0054_Operator_2   Operator_2 13.577729 3.5227031 1.72522014 2.26343323
#> T-26-0055_Operator_1   Operator_1  9.657703 2.6389034 1.18314680 2.11231002
#> T-26-0055_Operator_2   Operator_2  9.446884 2.6510382 1.18314680 2.08574503
#> T-26-0056-2_Operator_1 Operator_1 10.608752 3.0334717 1.18314680 2.34440505
#> T-26-0056-2_Operator_2 Operator_2  8.206057 2.1171553 1.58446403 2.24120574
#> T-26-0057_Operator_1   Operator_1  8.628830 2.4016155 1.18082484 1.71359902
#> T-26-0057_Operator_2   Operator_2  8.383760 2.3603073 1.18179042 1.77103372
#> T-26-0058_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0058_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0059_Operator_1   Operator_1 10.032306 2.1171553 1.18314680 1.52184775
#> T-26-0059_Operator_2   Operator_2  9.850798 2.6606743 1.40231096 2.01363978
#> T-26-0060_Operator_1   Operator_1  8.845626 2.1341875 1.18314680 1.61725054
#> T-26-0060_Operator_2   Operator_2  8.716633 2.0954773 1.26243237 1.58495110
#> T-26-0061_Operator_1   Operator_1 14.819986 3.5949012 1.88789725 2.50377888
#> T-26-0061_Operator_2   Operator_2 15.160318 3.6136218 1.89748820 2.35734263
#> T-26-0062_Operator_1   Operator_1 18.349125 4.4785865 2.33284686 2.94564968
#> T-26-0062_Operator_2   Operator_2 18.859337 4.6198213 2.33060606 2.75290337
#> T-26-0063_Operator_1   Operator_1  8.206057 1.8139889 1.18314680 1.54240609
#> T-26-0063_Operator_2   Operator_2  6.651589 1.8494779 0.94158897 1.55375077
#> T-26-0064_Operator_1   Operator_1  8.282579 2.1990608 1.18314680 1.43857329
#> T-26-0064_Operator_2   Operator_2  8.269170 2.1171553 1.18314680 1.52184775
#> T-26-0065_Operator_1   Operator_1  8.860755 2.3958781 1.18314680 1.87383949
#> T-26-0065_Operator_2   Operator_2  8.774428 2.4387755 1.30509848 1.85999365
#> T-26-0067_Operator_1   Operator_1  9.098319 2.6308665 1.33399329 1.92008053
#> T-26-0067_Operator_2   Operator_2  9.223213 2.6375057 1.35963502 1.96874870
#> T-26-0068_Operator_1   Operator_1  4.762950 2.9026090 1.52801260 1.81390960
#> T-26-0068_Operator_2   Operator_2  4.762950 2.9635730 1.49207967 1.78437465
#> T-26-0069_Operator_1   Operator_1  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0069_Operator_2   Operator_2  4.762950 1.4949622 1.07914792 1.03210893
#> T-26-0070_Operator_1   Operator_1  4.762950 2.4823162 1.20784079 1.32652685
#> T-26-0070_Operator_2   Operator_2  4.762950 1.4949622 1.19962438 1.36516012
#> T-26-0071_Operator_1   Operator_1  8.119705 1.9232598 1.22083818 1.55517847
#> T-26-0071_Operator_2   Operator_2  8.082817 1.9567676 1.21952080 1.47836837
#> T-26-0072_Operator_1   Operator_1  8.931884 2.1876938 1.18314680 1.76923668
#> T-26-0072_Operator_2   Operator_2  8.891576 2.2295930 1.33411781 1.77645676
#> T-26-0073_Operator_1   Operator_1  8.206057 2.6030857 1.18314680 2.08375790
#> T-26-0073_Operator_2   Operator_2  8.206057 2.5754048 1.44737708 2.03058241
#> T-26-0074_Operator_1   Operator_1  9.333662 2.4549746 1.39966547 1.62737601
#> T-26-0074_Operator_2   Operator_2  9.228916 2.5103115 1.39214648 1.73015492
#> T-26-0075_Operator_1   Operator_1 11.256087 3.0982388 1.66213559 2.50057094
#> T-26-0075_Operator_2   Operator_2 11.463401 3.1431894 1.68809751 2.43793978
#> T-26-0076_Operator_1   Operator_1  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0076_Operator_2   Operator_2  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0077_Operator_1   Operator_1  8.206057 1.4128496 1.18314680 1.00464849
#> T-26-0077_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0078_Operator_1   Operator_1  9.678709 2.4885850 1.18314680 1.59817486
#> T-26-0078_Operator_2   Operator_2  9.606177 2.4278515 1.43951638 1.64075152
#> T-26-0079_Operator_1   Operator_1  7.794510 2.1829866 1.18314680 1.62704563
#> T-26-0079_Operator_2   Operator_2  7.822441 2.2136848 1.07733715 1.67877053
#> T-26-0080_Operator_1   Operator_1  6.414039 1.7310801 0.85067042 0.93987846
#> T-26-0080_Operator_2   Operator_2  6.454427 1.7066608 0.86472915 0.96368793
#> T-26-0081_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0081_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0082_Operator_1   Operator_1  4.762950 2.2752182 1.07658830 1.46769024
#> T-26-0082_Operator_2   Operator_2  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0083_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0083_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0084_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0084_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0085_Operator_1   Operator_1  8.012648 2.2408643 1.18633526 1.37464245
#> T-26-0085_Operator_2   Operator_2  8.194352 2.1171553 1.18314680 1.52184775
#> T-26-0086_Operator_1   Operator_1  9.286351 2.2272747 1.18314680 1.82469148
#> T-26-0086_Operator_2   Operator_2  8.979844 2.2511138 1.38595421 1.81411865
#> T-26-0087_Operator_1   Operator_1  7.799946 2.1171553 1.18314680 1.52184775
#> T-26-0087_Operator_2   Operator_2  7.615699 2.1171553 1.18314680 1.52184775
#> T-26-0088_Operator_1   Operator_1  8.003724 2.1171553 1.18314680 1.34893971
#> T-26-0088_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.53616836
#> T-26-0089_Operator_1   Operator_1  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0089_Operator_2   Operator_2  4.762950 1.4949622 0.45205288 0.36729283
#> T-26-0090_Operator_1   Operator_1  4.446949 1.4949622 0.80085837 0.84847994
#> T-26-0090_Operator_2   Operator_2  4.488751 1.0001464 0.61798873 0.68768913
#> T-26-0091_Operator_1   Operator_1  8.879337 2.0752306 1.28835082 1.50508103
#> T-26-0091_Operator_2   Operator_2  8.857758 2.1171553 1.18314680 1.52184775
#> T-26-0092_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.53638218
#> T-26-0092_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0093_Operator_1   Operator_1  8.206057 2.2652431 1.18314680 1.75124810
#> T-26-0093_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.81069552
#> T-26-0094_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0094_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.30308781
#> T-26-0095_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0095_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0096_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0096_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0097_Operator_1   Operator_1  8.917207 2.2481345 1.30475710 1.46413549
#> T-26-0097_Operator_2   Operator_2  8.856381 2.2439584 1.31672598 1.55290147
#> T-26-0098_Operator_1   Operator_1  7.763619 1.9028971 1.18314680 1.41233954
#> T-26-0098_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0099_Operator_1   Operator_1  4.141031 0.9300604 0.51973084 0.41636252
#> T-26-0099_Operator_2   Operator_2  4.160279 1.5357850 0.80982207 0.93206804
#> T-26-0100_Operator_1   Operator_1  6.383691 1.6760671 1.18314680 1.16468213
#> T-26-0100_Operator_2   Operator_2  6.312897 2.1171553 1.18314680 1.52184775
#> T-26-0101_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0101_Operator_2   Operator_2  7.395853 2.1342374 1.18314680 1.62111073
#> T-26-0102_Operator_1   Operator_1  7.519589 2.1171553 1.18314680 1.52184775
#> T-26-0102_Operator_2   Operator_2  7.416510 2.1171553 1.18314680 1.52184775
#> T-26-0103_Operator_1   Operator_1  9.426845 2.1171553 1.18314680 1.52184775
#> T-26-0103_Operator_2   Operator_2  9.574033 2.7140325 1.41771092 1.73952291
#> T-26-0104_Operator_1   Operator_1  8.412130 2.1171553 1.18314680 1.52184775
#> T-26-0104_Operator_2   Operator_2  9.063534 2.5229216 1.21153105 1.65867214
#> T-26-0107_Operator_1   Operator_1  8.448413 2.1171553 1.18314680 1.52184775
#> T-26-0107_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0108_Operator_1   Operator_1  8.389500 2.1171553 1.18314680 1.52184775
#> T-26-0108_Operator_2   Operator_2  8.949133 2.1171553 1.18314680 1.52184775
#> T-26-0109_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0109_Operator_2   Operator_2  8.995382 2.4414451 1.18314680 1.71812815
#> T-26-0111_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0111_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0112-2_Operator_1 Operator_1  6.073948 1.5911264 0.90463889 1.05923602
#> T-26-0112-2_Operator_2 Operator_2  6.526428 1.5917784 0.88005813 1.11339756
#> T-26-0112_Operator_1   Operator_1  6.073948 0.8669887 0.53887976 0.53580545
#> T-26-0112_Operator_2   Operator_2  6.073948 1.5357850 0.80982207 0.93206804
#> T-26-0113_Operator_1   Operator_1  8.206057 1.5969789 0.98169094 0.86856780
#> T-26-0113_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.02373623
#> T-26-0114_Operator_1   Operator_1  7.372738 1.9359052 1.18314680 1.33139294
#> T-26-0114_Operator_2   Operator_2  9.056416 2.3650560 1.18314680 1.52250388
#> T-26-0115_Operator_1   Operator_1  9.004481 2.3915973 1.18314680 1.40914962
#> T-26-0115_Operator_2   Operator_2  7.251247 1.7833073 1.18314680 1.18222026
#> T-26-0116_Operator_1   Operator_1  7.304079 1.7850164 0.99974990 1.08191947
#> T-26-0116_Operator_2   Operator_2  8.206057 1.9960502 1.18314680 1.46332794
#> T-26-0117_Operator_1   Operator_1  7.806228 2.0016502 1.18314680 1.36327739
#> T-26-0117_Operator_2   Operator_2  8.625387 2.2073313 1.18314680 1.72767542
#> T-26-0118_Operator_1   Operator_1  8.728475 2.1743177 1.18314680 1.69327867
#> T-26-0118_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0120_Operator_1   Operator_1  6.896045 1.5939239 1.00306863 1.22753369
#> T-26-0120_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0121_Operator_1   Operator_1  7.285077 1.8572006 1.18314680 1.34455105
#> T-26-0121_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0122_Operator_1   Operator_1  8.757708 2.1171553 1.18314680 1.52184775
#> T-26-0122_Operator_2   Operator_2  8.604047 2.3067879 1.18314680 1.49829738
#> T-26-0123_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.25384065
#> T-26-0123_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0125_Operator_1   Operator_1  6.883640 1.4799444 1.18314680 1.05030093
#> T-26-0125_Operator_2   Operator_2  7.067181 1.5246391 1.18314680 1.18013384
#> T-26-0126_Operator_1   Operator_1  6.831146 1.8914700 1.18314680 1.30322478
#> T-26-0126_Operator_2   Operator_2  6.812574 1.8494426 1.18314680 1.36752653
#> T-26-0127_Operator_1   Operator_1  8.633812 2.4628407 1.18314680 1.74637804
#> T-26-0127_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.72713822
#> T-26-0128_Operator_1   Operator_1  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0128_Operator_2   Operator_2  6.945708 1.4949622 0.80085837 0.84847994
#> T-26-0130_Operator_1   Operator_1  4.762950 1.4949622 0.80085837 0.84847994
#> T-26-0130_Operator_2   Operator_2  4.762950 1.4949622 0.69047153 0.75737485
#> T-26-0131_Operator_1   Operator_1  8.206057 2.4041048 1.18314680 1.60957784
#> T-26-0131_Operator_2   Operator_2  8.206057 2.1171553 1.19620885 1.60947041
#> T-26-0132_Operator_1   Operator_1  8.788302 2.5143954 1.18314680 1.80818974
#> T-26-0132_Operator_2   Operator_2  8.806004 2.5747811 1.26227432 1.85327814
#> T-26-0133_Operator_1   Operator_1  8.709623 2.7613822 1.55651082 1.45880645
#> T-26-0133_Operator_2   Operator_2  8.431688 2.3874379 1.30626562 1.15661652
#> T-26-0134_Operator_1   Operator_1  8.446534 2.1772030 1.18314680 1.70098102
#> T-26-0134_Operator_2   Operator_2  8.287391 2.1760949 1.18314680 1.68464547
#> T-26-0135_Operator_1   Operator_1  8.920931 2.3447820 1.30341728 1.14482113
#> T-26-0135_Operator_2   Operator_2  8.699713 2.7613822 1.55651082 1.45880645
#> T-26-0136_Operator_1   Operator_1  8.621097 2.3489091 1.19154898 1.65724103
#> T-26-0136_Operator_2   Operator_2  8.478081 2.1171553 1.18314680 1.52184775
#> T-26-0137_Operator_1   Operator_1 15.465536 3.9723848 1.74305979 2.19257975
#> T-26-0137_Operator_2   Operator_2 15.549965 3.9557902 1.74593123 2.23720566
#> T-26-0138_Operator_1   Operator_1  7.887967 2.1021399 1.18314680 1.47625317
#> T-26-0138_Operator_2   Operator_2  7.820357 2.1171553 1.18314680 1.52184775
#> T-26-0139_Operator_1   Operator_1  8.565085 2.2107216 1.18314680 1.59174756
#> T-26-0139_Operator_2   Operator_2  8.659723 2.2799644 1.18314680 1.62839821
#> T-26-0140_Operator_1   Operator_1  6.661244 1.6529605 1.18314680 1.16893899
#> T-26-0140_Operator_2   Operator_2  6.496649 1.6172620 1.18314680 1.19291497
#> T-26-0141_Operator_1   Operator_1  8.729264 2.2536320 1.18314680 1.61653103
#> T-26-0141_Operator_2   Operator_2  8.654856 2.2346306 1.18314680 1.61961657
#> T-26-0142_Operator_1   Operator_1  6.800358 1.6981936 1.18314680 1.20519983
#> T-26-0142_Operator_2   Operator_2  6.782372 1.6508407 1.18314680 1.23156166
#> T-26-0143_Operator_1   Operator_1  7.958629 1.9903115 1.02710318 1.14576837
#> T-26-0143_Operator_2   Operator_2  7.825501 1.9928111 1.04060077 1.15916159
#> T-26-0144_Operator_1   Operator_1 11.211236 2.4429442 1.43577710 1.21119006
#> T-26-0144_Operator_2   Operator_2 11.159604 2.4118264 1.48352101 1.36521013
#> T-26-0145_Operator_1   Operator_1  3.451907 0.7344281 0.47008515 0.48343001
#> T-26-0145_Operator_2   Operator_2  3.451907 0.7344281 0.47008515 0.48343001
#> T-26-0146_Operator_1   Operator_1 10.308065 2.7416093 1.18314680 2.15639981
#> T-26-0146_Operator_2   Operator_2 10.188815 2.7121380 1.18314680 2.25731232
#> T-26-0147_Operator_1   Operator_1 10.774301 2.8913951 1.38201660 1.95237168
#> T-26-0147_Operator_2   Operator_2 10.752577 3.9181478 1.89111372 2.43503266
#> T-26-0148_Operator_1   Operator_1 14.048013 3.9101272 1.80229398 2.33367123
#> T-26-0148_Operator_2   Operator_2 14.198808 3.9743894 1.87017709 2.34447817
#> T-26-0149_Operator_1   Operator_1 25.516170 7.3873446 3.26289624 5.27619945
#> T-26-0149_Operator_2   Operator_2 24.925403 7.2806500 3.17045875 4.84407632
#> T-26-0150_Operator_1   Operator_1 16.870102 4.1728676 1.95040794 2.64946319
#> T-26-0150_Operator_2   Operator_2 16.424974 3.9181478 1.89111372 2.43503266
#> T-26-0151_Operator_1   Operator_1  9.272882 2.4256385 1.35809803 1.53370683
#> T-26-0151_Operator_2   Operator_2  9.127870 2.4361745 1.18314680 1.61047642
#> T-26-0152_Operator_1   Operator_1  8.206057 0.7321141 0.45786119 0.48278351
#> T-26-0152_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0153_Operator_1   Operator_1  7.981994 1.9261933 1.15027773 1.11686946
#> T-26-0153_Operator_2   Operator_2  7.845549 1.9238201 1.16042804 1.19813944
#> T-26-0154_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0154_Operator_2   Operator_2  8.206057 2.1171553 0.91792209 1.20999415
#> T-26-0155_Operator_1   Operator_1  4.815762 1.1612617 1.18314680 0.78663794
#> T-26-0155_Operator_2   Operator_2  4.776994 1.1448388 1.18314680 0.80712228
#> T-26-0156_Operator_1   Operator_1 20.121423 5.2837334 2.67573848 3.68924833
#> T-26-0156_Operator_2   Operator_2 19.641689 5.4229035 2.63977767 3.48798958
#> T-26-0157_Operator_1   Operator_1  8.206057 2.3869948 1.39416632 1.62542262
#> T-26-0157_Operator_2   Operator_2  8.907494 2.3171223 1.33104906 1.63929513
#> T-26-0158_Operator_1   Operator_1  8.318043 2.1277062 1.16775718 1.57726758
#> T-26-0158_Operator_2   Operator_2  8.175117 2.1488449 1.14739781 1.59071719
#> T-26-0159_Operator_1   Operator_1  8.960234 2.3460201 1.34569258 1.42667893
#> T-26-0159_Operator_2   Operator_2  8.582365 2.1171553 1.18314680 1.52184775
#> T-26-0160_Operator_1   Operator_1  8.206057 2.1711909 1.18314680 1.38869473
#> T-26-0160_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.45771702
#> T-26-0161_Operator_1   Operator_1  7.743955 1.9731189 1.18314680 1.43310875
#> T-26-0161_Operator_2   Operator_2  7.469785 1.9398479 1.18314680 1.45093211
#> T-26-0162_Operator_1   Operator_1  7.579910 2.0401309 1.18314680 1.44291029
#> T-26-0162_Operator_2   Operator_2  7.333056 2.0065741 1.18314680 1.49013163
#> T-26-0163_Operator_1   Operator_1  9.098792 2.1171553 1.18314680 1.52184775
#> T-26-0163_Operator_2   Operator_2  8.855654 2.2926088 1.20526922 1.53277924
#> T-26-0164_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0164_Operator_2   Operator_2  8.206057 1.1269188 0.62200509 0.66367252
#> T-26-0165_Operator_1   Operator_1  8.206057 1.9783993 0.96896036 1.34167217
#> T-26-0165_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0166_Operator_1   Operator_1  8.206057 1.0499275 0.61195469 0.68878260
#> T-26-0166_Operator_2   Operator_2  8.206057 2.1171553 0.60206659 0.70044203
#> T-26-0167_Operator_1   Operator_1 27.786992 7.3615627 3.23855253 4.93945011
#> T-26-0167_Operator_2   Operator_2 26.260097 7.3047829 3.18272253 4.80890050
#> T-26-0168_Operator_1   Operator_1  8.493020 2.4630116 1.15014470 1.59243517
#> T-26-0168_Operator_2   Operator_2  8.139477 2.3948990 1.10971799 1.60845617
#> T-26-0169_Operator_1   Operator_1 10.428105 2.6561016 1.49379347 1.79099943
#> T-26-0169_Operator_2   Operator_2 20.204788 2.1171553 2.91026208 3.63548664
#> T-26-0170_Operator_1   Operator_1  9.826011 2.7498987 1.46423279 1.78566490
#> T-26-0170_Operator_2   Operator_2  9.493054 2.6706016 1.43743258 1.88025209
#> T-26-0171_Operator_1   Operator_1  9.916260 2.4626247 1.36215657 1.70436577
#> T-26-0171_Operator_2   Operator_2  9.538539 2.4687427 1.32771316 1.79989362
#> T-26-0172_Operator_1   Operator_1  9.883746 2.4073587 1.38730828 1.49610670
#> T-26-0172_Operator_2   Operator_2  9.265153 2.3111692 1.31930035 1.51678775
#> T-26-0173_Operator_1   Operator_1  6.836187 1.7343700 0.91898100 1.27485268
#> T-26-0173_Operator_2   Operator_2  6.593399 1.7306618 0.90380530 1.32568293
#> T-26-0174_Operator_1   Operator_1  8.147046 2.2818316 1.18314680 1.76499271
#> T-26-0174_Operator_2   Operator_2  7.861860 2.1171553 1.18314680 1.52184775
#> T-26-0175_Operator_1   Operator_1  8.580691 2.1543244 1.22817860 1.60399072
#> T-26-0175_Operator_2   Operator_2  8.193555 2.0898922 1.21989210 1.61797936
#> T-26-0176_Operator_1   Operator_1  8.483066 2.3173658 1.33773276 1.46609793
#> T-26-0176_Operator_2   Operator_2  8.310732 2.2794353 1.31562208 1.53127661
#> T-26-0177_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0177_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0178_Operator_1   Operator_1  8.206057 2.3197344 1.37850192 1.70943047
#> T-26-0178_Operator_2   Operator_2  8.206057 2.3271231 1.38591595 1.78523142
#> T-26-0179-3_Operator_1 Operator_1  9.405112 2.5376131 1.18314680 1.70792291
#> T-26-0179-3_Operator_2 Operator_2  8.206057 2.1171553 1.18314680 1.67098368
#> T-26-0179_Operator_1   Operator_1  8.206057 1.2267470 0.65780744 0.67998765
#> T-26-0179_Operator_2   Operator_2  8.206057 2.1171553 0.66450281 0.77201983
#> T-26-0180_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0180_Operator_2   Operator_2  8.206057 2.1171553 1.29776265 1.67108612
#> T-26-0181_Operator_1   Operator_1  8.217100 2.3505103 1.24742461 1.54014273
#> T-26-0181_Operator_2   Operator_2  7.993417 2.2672207 1.23054458 1.53358636
#> T-26-0182_Operator_1   Operator_1  7.892748 1.8398827 1.18314680 1.31101639
#> T-26-0182_Operator_2   Operator_2  7.661711 1.7920132 1.19880897 1.31291624
#> T-26-0183_Operator_1   Operator_1  9.518076 2.4053677 1.18314680 1.41256452
#> T-26-0183_Operator_2   Operator_2  9.361312 2.3909196 1.25476110 1.53224973
#> T-26-0184_Operator_1   Operator_1  9.538773 2.7613822 1.57286200 1.61300645
#> T-26-0184_Operator_2   Operator_2  9.538773 2.7613822 1.53764013 1.56031126
#> T-26-0185_Operator_1   Operator_1  7.273865 1.6675667 0.92878843 1.12792203
#> T-26-0185_Operator_2   Operator_2  8.206057 1.6485574 0.89777574 1.15451043
#> T-26-0186_Operator_1   Operator_1  9.774102 2.5524726 1.41280021 1.85260413
#> T-26-0186_Operator_2   Operator_2  9.593719 2.5653717 1.41275700 1.80321885
#> T-26-0187_Operator_1   Operator_1  8.206057 2.5030524 1.49008194 1.70854396
#> T-26-0187_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0188_Operator_1   Operator_1  7.082200 1.4585851 0.71883483 0.90704980
#> T-26-0188_Operator_2   Operator_2  6.862648 1.4151438 0.69846150 0.90469732
#> T-26-0189_Operator_1   Operator_1  7.800557 2.0604721 1.18314680 1.46284131
#> T-26-0189_Operator_2   Operator_2  7.495119 1.9729380 1.01262317 1.45213002
#> T-26-0190_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0190_Operator_2   Operator_2  8.233771 2.0736471 1.20941208 1.25748156
#> T-26-0191_Operator_1   Operator_1  8.613953 2.2135302 1.18314680 1.47144644
#> T-26-0191_Operator_2   Operator_2  8.206057 2.1171553 1.26491167 1.45489771
#> T-26-0192_Operator_1   Operator_1  8.206057 2.3755984 1.18314680 1.47645881
#> T-26-0192_Operator_2   Operator_2  8.206057 2.2708618 1.29522899 1.46816464
#> T-26-0193_Operator_1   Operator_1  8.856398 2.3068841 1.18314680 1.78671127
#> T-26-0193_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0194_Operator_1   Operator_1 11.161935 2.9301445 1.18314680 2.32413732
#> T-26-0194_Operator_2   Operator_2 10.636577 2.1171553 1.18314680 1.52184775
#> T-26-0195_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0195_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0196_Operator_1   Operator_1  6.772870 1.6158914 0.91521989 0.98528067
#> T-26-0196_Operator_2   Operator_2  6.567802 2.1171553 1.18314680 1.52184775
#> T-26-0197_Operator_1   Operator_1  8.826393 2.4399619 1.26936172 1.65724360
#> T-26-0197_Operator_2   Operator_2  8.293598 2.3475460 1.21290481 1.64426807
#> T-26-0198_Operator_1   Operator_1  8.414324 2.2914596 1.18314680 1.51871264
#> T-26-0198_Operator_2   Operator_2  7.911831 2.1652155 1.08512781 1.49592503
#> T-26-0199_Operator_1   Operator_1  6.406357 1.1933637 0.71883483 0.83799600
#> T-26-0199_Operator_2   Operator_2  6.404326 1.2708496 0.71883483 0.88204548
#> T-26-0200_Operator_1   Operator_1  9.238281 2.6756751 1.18314680 1.84141985
#> T-26-0200_Operator_2   Operator_2  8.957535 2.6161542 1.35013131 1.89608162
#> T-26-0201_Operator_1   Operator_1  7.622473 1.9509538 1.18314680 1.27583515
#> T-26-0201_Operator_2   Operator_2  7.431919 1.9428145 1.01818080 1.30756557
#> T-26-0202_Operator_1   Operator_1  9.538773 3.2301116 1.95367549 1.61074700
#> T-26-0202_Operator_2   Operator_2  9.538773 2.7613822 1.87834447 1.57992674
#> T-26-0203_Operator_1   Operator_1  8.647504 2.0695971 1.20951532 1.49761784
#> T-26-0203_Operator_2   Operator_2  8.247246 2.0065113 1.16156779 1.46111268
#> T-26-0204_Operator_1   Operator_1  8.900694 2.1559594 1.22825891 1.35236131
#> T-26-0204_Operator_2   Operator_2  8.541752 2.1076327 1.18517801 1.35231541
#> T-26-0205_Operator_1   Operator_1  8.123299 2.0590722 1.18314680 1.49336206
#> T-26-0205_Operator_2   Operator_2  7.870648 2.0330476 1.12194483 1.53616631
#> T-26-0206_Operator_1   Operator_1  7.269843 1.8387050 1.18314680 1.15628802
#> T-26-0206_Operator_2   Operator_2  7.087511 2.1171553 1.18314680 1.52184775
#> T-26-0207_Operator_1   Operator_1  6.211687 1.5128630 0.82876487 0.90337076
#> T-26-0207_Operator_2   Operator_2  6.080203 2.1171553 1.18314680 1.52184775
#> T-26-0208_Operator_1   Operator_1  7.205718 1.2708496 0.71883483 0.88204548
#> T-26-0208_Operator_2   Operator_2  6.940365 1.2708496 0.71883483 0.88204548
#> T-26-0209_Operator_1   Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0209_Operator_2   Operator_2  9.685861 2.5570727 1.32139160 1.83019064
#> T-26-0210_Operator_1   Operator_1  5.160863 1.1868964 0.70820412 0.74422718
#> T-26-0210_Operator_2   Operator_2  5.032432 1.5276241 0.70820412 0.93130024
#> T-26-0211_Operator_1   Operator_1  7.356858 1.9206923 1.18314680 1.40432932
#> T-26-0211_Operator_2   Operator_2  7.235018 1.8829919 1.02629299 1.38703730
#> T-26-0212_Operator_1   Operator_1  8.206057 2.1171553 0.91568369 1.01256651
#> T-26-0212_Operator_2   Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0213_Operator_1   Operator_1  8.206057 1.9093622 1.18314680 1.34931277
#> T-26-0213_Operator_2   Operator_2  7.254137 1.8332162 0.93799713 1.39727194
#> T-26-0214_Operator_1   Operator_1 13.171775 3.3507354 1.52770518 1.90101240
#> T-26-0214_Operator_2   Operator_2 11.320762 3.2599572 1.46694948 1.94407463
#> T-26-0215_Operator_1   Operator_1  7.461961 2.0993214 1.12632815 1.45497744
#> T-26-0215_Operator_2   Operator_2  7.376821 2.1171553 1.12550865 1.46251112
#> T-26-0216_Operator_1   Operator_1  7.072794 1.7624946 1.18314680 1.38756396
#> T-26-0216_Operator_2   Operator_2  6.916795 1.7464553 1.18314680 1.43372630
#> T-26-0217_Operator_1   Operator_1  9.487054 2.3655374 1.32043444 1.32917214
#> T-26-0217_Operator_2   Operator_2  8.206057 2.1171553 1.34030857 1.48972545
#> T-26-0218_Operator_1   Operator_1  7.261583 1.2708496 0.71883483 0.88204548
#> T-26-0218_Operator_2   Operator_2  7.101069 1.3653048 0.75484486 0.92672723
#> T-26-0219_Operator_1   Operator_1  4.512962 1.1177239 0.64022293 0.85079585
#> T-26-0219_Operator_2   Operator_2  4.436315 2.1171553 1.18314680 1.52184775
#> T-26-0220_Operator_1   Operator_1  6.841571 1.6564660 1.18314680 1.09225928
#> T-26-0220_Operator_2   Operator_2  6.668780 2.1171553 1.18314680 1.08974030
#> T-26-0221_Operator_1   Operator_1 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0221_Operator_2   Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0222_Operator_1   Operator_1 15.160318 3.9181478 2.13435807 1.99575209
#> T-26-0222_Operator_2   Operator_2 15.160318 3.9181478 2.23610474 2.10870494
#> T-26-0223_Operator_1   Operator_1  9.244512 2.5771837 1.18314680 1.91503759
#> T-26-0223_Operator_2   Operator_2  9.288159 2.5612497 1.18314680 1.90132235
#> T-26-0224_Operator_1   Operator_1  9.317499 2.3460688 1.18314680 1.63625932
#> T-26-0224_Operator_2   Operator_2  9.015197 2.1171553 1.18314680 1.52184775
#> T-26-0225_Operator_1   Operator_1 10.456399 2.7859867 1.29235462 1.48723982
#> T-26-0225_Operator_2   Operator_2 10.369535 3.9181478 1.89111372 2.43503266
#> T-26-0226_Operator_1   Operator_1  5.292204 1.2193337 0.70643691 0.69033836
#> T-26-0226_Operator_2   Operator_2  5.280947 2.1171553 1.18314680 1.52184775
#> T-26-0227_Operator_1   Operator_1  7.683103 1.8003888 0.99927905 0.93896110
#> T-26-0227_Operator_2   Operator_2  7.559928 3.9181478 1.89111372 2.43503266
#> T-26-0228_Operator_1   Operator_1 15.160318 2.0329669 1.08221938 1.12569675
#> T-26-0228_Operator_2   Operator_2  8.290491 2.0544708 1.07005910 1.13935802
#> T-26-0229_Operator_1   Operator_1 15.160318 2.6270761 1.29393495 1.36576619
#> T-26-0229_Operator_2   Operator_2  9.931765 2.4938970 1.25303991 1.37611492
#> T-26-0230-1_Operator_1 Operator_1  7.020527 1.1674250 0.71883483 0.96729351
#> T-26-0230-1_Operator_2 Operator_2  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0230-2_Operator_1 Operator_1  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0230-2_Operator_2 Operator_2  6.697831 1.0709842 0.65217111 0.76054299
#> T-26-0230-3_Operator_1 Operator_1  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0230-3_Operator_2 Operator_2  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0230-4_Operator_1 Operator_1  6.697831 1.2708496 0.76901830 0.93927681
#> T-26-0230-4_Operator_2 Operator_2  6.888051 1.2708496 0.71883483 0.88204548
#> T-26-0231_Operator_1   Operator_1  7.209116 1.4032010 0.74368320 0.77920855
#> T-26-0231_Operator_2   Operator_2  7.131006 1.2708496 0.71883483 0.88204548
#> T-26-0232_Operator_1   Operator_1  6.237482 1.2958170 0.71883483 0.94061204
#> T-26-0232_Operator_2   Operator_2  6.252687 1.2708496 0.71883483 0.88204548
#> T-26-0233_Operator_1   Operator_1  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0233_Operator_2   Operator_2  5.864201 1.2708496 0.71883483 0.88204548
#> T-26-0234_Operator_1   Operator_1 19.146759 4.6794293 2.76822113 3.17045248
#> T-26-0234_Operator_2   Operator_2 19.246358 3.9181478 1.89111372 2.43503266
#> T-26-0235_Operator_1   Operator_1  6.670236 1.6497761 0.92427600 1.01704526
#> T-26-0235_Operator_2   Operator_2  6.710467 3.9181478 1.89111372 2.43503266
#> T-26-0236_Operator_1   Operator_1 15.760022 3.9159712 1.89160038 2.16371203
#> T-26-0236_Operator_2   Operator_2 15.561209 3.8908433 1.84734335 2.13540670
#> T-26-0237_Operator_1   Operator_1 15.957457 4.0795179 1.83180403 2.04416326
#> T-26-0237_Operator_2   Operator_2 15.737949 3.9885622 1.69816792 2.17202836
#> T-26-0238_Operator_1   Operator_1 11.790394 3.0597929 1.45706664 1.50993204
#> T-26-0238_Operator_2   Operator_2 11.627595 3.9181478 1.89111372 2.43503266
#> T-26-0239_Operator_1   Operator_1 11.462241 3.1695178 1.69224864 1.53274628
#> T-26-0239_Operator_2   Operator_2  9.538773 2.7613822 1.55651082 1.45880645
#> T-26-0240_Operator_1   Operator_1  7.386872 1.8731401 0.94171737 1.05132142
#> T-26-0240_Operator_2   Operator_2  7.214895 1.8386326 0.90130396 1.07267972
#> T-26-0241_Operator_1   Operator_1  5.033140 1.0916912 0.64128364 0.67570267
#> T-26-0241_Operator_2   Operator_2  4.902804 2.1171553 1.18314680 1.52184775
#> T-26-0242_Operator_1   Operator_1 15.160318 4.6372419 1.95620295 3.04845959
#> T-26-0242_Operator_2   Operator_2 15.160318 4.5101884 1.86307710 3.05864178
#> T-26-0243_Operator_1   Operator_1  5.184221 1.2525468 0.66778409 0.60551360
#> T-26-0243_Operator_2   Operator_2  5.107055 1.4949622 0.80085837 0.84847994
#> T-26-0244_Operator_1   Operator_1  3.933057 0.8350921 0.53452318 0.57585697
#> T-26-0244_Operator_2   Operator_2  3.889758 0.8797204 0.53720134 0.60691325
#> T-26-0245_Operator_1   Operator_1  7.026237 1.7300032 1.04004230 0.86333497
#> T-26-0245_Operator_2   Operator_2  7.074091 1.8377188 1.08102412 0.90958002
#> T-26-0246_Operator_1   Operator_1  7.008886 1.7058019 0.96806267 0.84811395
#> T-26-0246_Operator_2   Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0247_Operator_1   Operator_1  4.886358 1.0883334 0.66089952 0.65650107
#> T-26-0247_Operator_2   Operator_2  4.743978 1.4949622 0.80085837 0.84847994
#> T-26-0248_Operator_1   Operator_1  4.762950 0.8047509 0.49883038 0.34144143
#> T-26-0248_Operator_2   Operator_2  3.500932 1.4949622 0.80085837 0.84847994
#> T-26-0249_Operator_1   Operator_1  4.762950 0.8148732 0.52339529 0.34016517
#> T-26-0249_Operator_2   Operator_2  3.527529 1.4949622 0.80085837 0.84847994
#> T-26-0250_Operator_1   Operator_1  4.762950 0.7969029 0.51951985 0.42713887
#> T-26-0250_Operator_2   Operator_2  4.762950 1.4949622 0.51747661 0.46925608
#> T-26-0251_Operator_1   Operator_1 15.160318 1.1900620 0.73573210 0.66517467
#> T-26-0251_Operator_2   Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0252_Operator_1   Operator_1 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0252_Operator_2   Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0261-1_Operator_1 Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0261-1_Operator_2 Operator_2  8.206057 2.1171553 1.18314680 1.70293121
#> T-26-0261-2_Operator_1 Operator_1  8.184326 2.2074599 1.18314680 1.64626927
#> T-26-0261-2_Operator_2 Operator_2  8.157834 2.1793231 1.18314680 1.59261575
#> T-26-0261-3_Operator_1 Operator_1  8.043753 2.2259858 1.05736232 1.69287614
#> T-26-0261-3_Operator_2 Operator_2  8.038553 2.2124613 1.18314680 1.74488118
#> T-26-0261-4_Operator_1 Operator_1  8.206057 1.4633690 1.18314680 1.21379413
#> T-26-0261-4_Operator_2 Operator_2  8.206057 2.1171553 1.18314680 1.28147430
#> T-26-0261-5_Operator_1 Operator_1  8.606900 1.9685455 1.31149831 1.49708570
#> T-26-0261-5_Operator_2 Operator_2  8.511532 2.0000849 1.18314680 1.51152074
#> T-26-0262-1_Operator_1 Operator_1  8.206057 1.7971661 1.18314680 1.35700871
#> T-26-0262-1_Operator_2 Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0262-2_Operator_1 Operator_1  6.890140 1.8333483 0.94458549 1.50922297
#> T-26-0262-2_Operator_2 Operator_2  7.004796 1.8505830 1.18314680 1.48046642
#> T-26-0263_Operator_1   Operator_1  4.060243 0.9476308 0.57304189 0.48884594
#> T-26-0263_Operator_2   Operator_2  4.298883 2.1171553 1.18314680 1.52184775
#> T-26-0264-1_Operator_1 Operator_1  4.373042 1.5276241 0.70820412 0.93130024
#> T-26-0264-1_Operator_2 Operator_2  4.324746 0.9998373 0.70820412 0.62794412
#> T-26-0264-2_Operator_1 Operator_1  5.870256 1.5276241 0.70820412 0.93130024
#> T-26-0264-2_Operator_2 Operator_2  5.870256 1.5276241 0.70820412 0.93130024
#> T-26-0264-3_Operator_1 Operator_1  5.870256 1.5276241 0.70820412 0.93130024
#> T-26-0264-3_Operator_2 Operator_2  5.870256 1.5276241 0.70820412 0.67990429
#> T-26-0264-4_Operator_1 Operator_1  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0264-4_Operator_2 Operator_2  8.206057 2.1171553 1.18314680 1.52184775
#> T-26-0265_Operator_1   Operator_1  9.686131 3.9181478 1.89111372 2.43503266
#> T-26-0265_Operator_2   Operator_2  9.783818 2.4480736 1.38123800 1.41497129
#> T-26-0266_Operator_1   Operator_1 25.178168 6.1950118 3.64656873 4.07783608
#> T-26-0266_Operator_2   Operator_2 25.307554 6.1585002 3.59201122 4.23242139
#> T-26-0267_Operator_1   Operator_1 25.296738 3.9181478 1.89111372 2.43503266
#> T-26-0267_Operator_2   Operator_2 24.821796 6.7841903 3.62875294 4.94358843
#> T-26-0268_Operator_1   Operator_1  7.432405 2.0015607 1.14788513 1.01037090
#> T-26-0268_Operator_2   Operator_2  7.402496 1.9418745 1.13586880 0.97082803
#> T-26-0269_Operator_1   Operator_1 15.160318 3.9181478 1.10812819 1.06833473
#> T-26-0269_Operator_2   Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0270-1_Operator_1 Operator_1 12.624763 3.1075008 1.70386837 1.70293864
#> T-26-0270-1_Operator_2 Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0270-2_Operator_1 Operator_1 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0270-2_Operator_2 Operator_2 15.160318 3.9181478 1.89111372 2.43503266
#> T-26-0271_Operator_1   Operator_1  9.951061 2.7613822 1.49590424 1.49496470
#> T-26-0271_Operator_2   Operator_2  9.538773 2.7613822 1.55651082 1.45880645
#> T-26-0272_Operator_1   Operator_1  6.697831 1.1272330 0.70903200 0.70012037
#> T-26-0272_Operator_2   Operator_2  6.697831 1.1662132 0.70382229 0.77111478
#> T-26-0273_Operator_1   Operator_1  8.647458 3.9181478 1.89111372 2.43503266
#> T-26-0273_Operator_2   Operator_2  8.854456 2.0888984 1.20589120 1.08401063
#> T-26-0274_Operator_1   Operator_1  6.697831 1.2708496 0.71883483 0.96436466
#> T-26-0274_Operator_2   Operator_2  6.697831 1.2310557 0.71883483 1.00571597
#> T-26-0275_Operator_1   Operator_1  7.124035 1.2145781 0.71883483 0.87506638
#> T-26-0275_Operator_2   Operator_2  7.015681 1.2187128 0.71883483 0.89329981
#> T-26-0276_Operator_1   Operator_1  6.125893 1.5328261 0.83775337 0.93300118
#> T-26-0276_Operator_2   Operator_2  6.243626 1.5737396 0.84585963 1.01960000
#> T-26-0277_Operator_1   Operator_1  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0277_Operator_2   Operator_2  6.697831 1.2708496 0.81364053 0.85771439
#> T-26-0278-1_Operator_1 Operator_1  5.889839 1.3573901 0.62483966 0.84791016
#> T-26-0278-1_Operator_2 Operator_2  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0278-2_Operator_1 Operator_1  6.697831 1.2708496 0.71883483 0.88204548
#> T-26-0278-2_Operator_2 Operator_2  5.943979 1.2708496 0.71883483 0.88204548
#> T-26-0279_Operator_1   Operator_1  6.697831 1.3004547 0.71883483 0.94545918
#> T-26-0279_Operator_2   Operator_2  6.115752 1.3481306 0.71883483 0.93469408
#>                                Mo        PFi       PFl         Ed        Jl
#> T-26-0001_Operator_1   1.16197101 0.77936042 1.3571782 0.39169422 0.3141390
#> T-26-0001_Operator_2   0.91630925 0.74976919 1.3421683 0.33565977 0.4084968
#> T-26-0002_Operator_1   1.06867215 0.86977177 1.5406889 0.38287629 0.5184372
#> T-26-0002_Operator_2   1.04827182 0.90873810 1.4602249 0.34405677 0.4487938
#> T-26-0003_Operator_1   0.80881935 0.71316923 1.2416526 0.36517494 0.4902852
#> T-26-0003_Operator_2   0.77681447 0.68516914 1.4002251 0.33559087 0.4491814
#> T-26-0004_Operator_1   2.48872580 1.30312261 3.0706500 0.77446974 0.9075409
#> T-26-0004_Operator_2   2.51429225 1.30646051 3.0181977 0.84133255 0.9065431
#> T-26-0005_Operator_1   0.80566515 0.62309150 0.9818339 0.27046813 0.4423693
#> T-26-0005_Operator_2   1.16197101 0.77936042 1.0853408 0.39169422 0.3446107
#> T-26-0006_Operator_1   1.16197101 0.77936042 1.3023562 0.39169422 0.5165191
#> T-26-0006_Operator_2   0.77314909 0.91054204 1.2126575 0.34889089 0.4290090
#> T-26-0007_Operator_1   2.24642991 1.14389444 3.5085919 0.74768975 1.4552358
#> T-26-0007_Operator_2   2.71425139 1.85419042 3.3737915 0.89604957 0.9653270
#> T-26-0008_Operator_1   2.24642991 1.14389444 2.4716972 0.74768975 1.1387038
#> T-26-0008_Operator_2   2.47822015 1.54145985 2.5145902 0.67198150 0.8010362
#> T-26-0009_Operator_1   1.24225715 0.94587064 1.0216666 0.51205283 0.3210083
#> T-26-0009_Operator_2   1.24952219 0.85749531 1.3915307 0.52415842 0.4281807
#> T-26-0010_Operator_1   1.16197101 0.77936042 1.7151405 0.39169422 0.5284874
#> T-26-0010_Operator_2   1.16197101 0.77936042 1.7116300 0.39169422 0.4853231
#> T-26-0011_Operator_1   2.24642991 1.14389444 4.7540294 0.74768975 2.1168580
#> T-26-0011_Operator_2   2.24642991 1.14389444 4.6498639 0.74768975 1.8148178
#> T-26-0012_Operator_1   1.16197101 0.77936042 1.4527794 0.39169422 0.4688812
#> T-26-0012_Operator_2   1.16197101 0.77936042 1.3071221 0.39169422 0.4130777
#> T-26-0013_Operator_1   0.88318584 0.76117261 1.6037205 0.43691643 0.6524061
#> T-26-0013_Operator_2   0.92426944 0.74701185 1.4788647 0.42178006 0.5522316
#> T-26-0014_Operator_1   1.18549544 1.17982255 1.9419989 0.35006280 0.5694982
#> T-26-0014_Operator_2   1.28512669 1.12271599 1.7437919 0.32540342 0.4691140
#> T-26-0015_Operator_1   0.90252299 0.94930026 1.7040126 0.34229099 0.5291597
#> T-26-0015_Operator_2   0.90015057 0.90386104 1.4868953 0.29916479 0.4724612
#> T-26-0016_Operator_1   1.54880037 1.32975506 2.0587947 0.58772448 0.8083894
#> T-26-0016_Operator_2   1.12529359 0.93398043 1.9438910 0.66900341 0.9522891
#> T-26-0017_Operator_1   0.65403196 0.63708998 1.5041843 0.28466129 0.4748494
#> T-26-0017_Operator_2   0.68130657 0.64589390 1.3683530 0.25497927 0.3989513
#> T-26-0018_Operator_1   3.94755566 2.45630553 3.5382196 0.95164946 1.0136353
#> T-26-0018_Operator_2   1.85323778 0.99382189 3.4195100 0.71594204 1.0892905
#> T-26-0019_Operator_1   1.65616013 1.03140475 2.1818256 0.74373115 0.6282757
#> T-26-0019_Operator_2   1.58916398 1.00302998 2.1373223 0.70084539 0.8233946
#> T-26-0020_Operator_1   1.42336918 1.32493115 1.8425853 0.39596127 0.5424703
#> T-26-0020_Operator_2   1.16197101 0.77936042 1.8913813 0.39169422 0.5127092
#> T-26-0021_Operator_1   0.96435058 0.99181424 1.8590928 0.63898700 0.4753667
#> T-26-0021_Operator_2   0.88749677 0.84530619 1.5534761 0.65622110 0.8717501
#> T-26-0022_Operator_1   1.67745924 0.94258427 2.0524048 0.67044113 0.6392783
#> T-26-0022_Operator_2   1.62375071 0.92608948 1.9687519 0.66913514 0.7569836
#> T-26-0023-2_Operator_1 0.43941300 0.22895104 0.9741679 0.28619375 0.4072843
#> T-26-0023-2_Operator_2 0.80581429 0.43405924 0.5413950 0.38435072 0.3176394
#> T-26-0024_Operator_1   1.16197101 0.77936042 1.6447189 0.39169422 0.5526650
#> T-26-0024_Operator_2   1.33905022 1.08139434 1.4166748 0.39169422 0.4686662
#> T-26-0025_Operator_1   1.46321555 1.33351716 1.9929660 0.32422744 0.4526759
#> T-26-0025_Operator_2   1.54123693 1.36954226 1.7702606 0.28264358 0.4163414
#> T-26-0026_Operator_1   1.44391579 0.90046998 1.9779864 0.48454672 0.7799872
#> T-26-0026_Operator_2   1.49825464 0.86785633 1.8145795 0.45835890 0.6883890
#> T-26-0027_Operator_1   1.94469811 1.35317782 1.9343852 0.44955766 0.6343375
#> T-26-0027_Operator_2   1.77951827 1.25741612 1.7964636 0.41033674 0.6486446
#> T-26-0028_Operator_1   1.08521010 0.97247912 1.3516274 0.32857973 0.4478013
#> T-26-0028_Operator_2   1.12415413 0.95316938 1.2689236 0.29557560 0.3804169
#> T-26-0029_Operator_1   1.24588967 0.77538900 1.0216666 0.51810563 0.4093744
#> T-26-0029_Operator_2   1.24588967 0.52280105 0.6518025 0.51810563 0.4789340
#> T-26-0030_Operator_1   2.15398429 1.21224700 2.2943736 0.66424335 0.7654466
#> T-26-0030_Operator_2   1.85323778 0.99382189 2.3701462 0.71594204 0.8667674
#> T-26-0031_Operator_1   1.16587322 0.97215211 1.4975270 0.35311241 0.5868150
#> T-26-0031_Operator_2   1.16197101 0.77936042 1.5038251 0.39169422 0.4689442
#> T-26-0032_Operator_1   5.27919142 2.98317119 5.0649982 1.03357431 1.3379604
#> T-26-0032_Operator_2   4.64272918 2.60311595 4.9632190 0.97335265 1.4283261
#> T-26-0033_Operator_1   1.16197101 0.77936042 1.8324657 0.39169422 0.4750978
#> T-26-0033_Operator_2   1.52411964 1.25957741 1.8287800 0.41152488 0.4131745
#> T-26-0034_Operator_1   1.16197101 0.77936042 1.7130311 0.39169422 0.5011719
#> T-26-0034_Operator_2   1.16197101 0.77936042 1.7396400 0.39169422 0.4859225
#> T-26-0035_Operator_1   0.88961927 0.66914311 1.1874279 0.28483050 0.4047512
#> T-26-0035_Operator_2   1.16197101 0.77936042 1.1777644 0.39169422 0.3906018
#> T-26-0036_Operator_1   2.16219518 1.33697618 2.1035961 0.71814770 0.7159875
#> T-26-0036_Operator_2   1.99307552 1.06806199 2.1304110 0.69427239 0.7167420
#> T-26-0037_Operator_1   2.73859762 1.77711639 3.1439850 0.77747788 0.8296678
#> T-26-0037_Operator_2   2.51345443 1.46778476 2.8955734 0.77363638 0.9686656
#> T-26-0038_Operator_1   1.02371234 0.94549656 1.4624606 0.29249449 0.4922926
#> T-26-0038_Operator_2   0.95613361 0.86003197 1.5489551 0.25049166 0.3814196
#> T-26-0039_Operator_1   1.18724500 0.76344261 1.1498481 0.48169820 0.3792569
#> T-26-0039_Operator_2   1.18195401 0.65392363 1.3913741 0.51158343 0.4693982
#> T-26-0040_Operator_1   1.14137435 0.99997655 1.8360659 0.39169422 0.6323202
#> T-26-0040_Operator_2   1.16235287 0.91695843 1.8403005 0.39169422 0.5602112
#> T-26-0041_Operator_1   1.16197101 0.77936042 1.4292887 0.39169422 0.4785252
#> T-26-0041_Operator_2   1.16197101 0.77936042 1.4533812 0.39169422 0.3980374
#> T-26-0042_Operator_1   1.32920371 1.02780954 2.0139522 0.41262037 0.5433299
#> T-26-0042_Operator_2   1.28244246 0.96698688 1.8525883 0.35782554 0.5255243
#> T-26-0043_Operator_1   0.64350880 0.73771034 1.7601271 0.41348298 0.4832472
#> T-26-0043_Operator_2   0.73889948 0.76119106 1.7975675 0.30419315 0.4048686
#> T-26-0044_Operator_1   1.37557563 1.21678061 1.8359927 0.42798152 0.4937488
#> T-26-0044_Operator_2   1.16197101 0.77936042 1.7696610 0.39169422 0.4584049
#> T-26-0045_Operator_1   1.86251732 1.18307922 2.6606648 0.67595224 0.7530524
#> T-26-0045_Operator_2   1.82784404 1.03105720 2.4334719 0.70972839 0.7875717
#> T-26-0046_Operator_1   1.17289864 1.11144133 1.9413411 0.37494105 0.4967074
#> T-26-0046_Operator_2   1.13080591 0.96825358 1.9213842 0.29673532 0.5897032
#> T-26-0047_Operator_1   5.49443483 3.49366083 5.1035153 0.86973302 1.1569351
#> T-26-0047_Operator_2   5.09847909 3.20831407 4.9375199 0.93701531 1.3141156
#> T-26-0048_Operator_1   1.16197101 0.77936042 1.6156628 0.39169422 0.5627273
#> T-26-0048_Operator_2   1.16197101 0.77936042 1.8292777 0.39169422 0.5101605
#> T-26-0049_Operator_1   1.71324814 1.01167002 2.2633024 0.69051370 0.7043522
#> T-26-0049_Operator_2   1.85453957 0.99854255 2.2111136 0.75169806 0.8467069
#> T-26-0050_Operator_1   1.16197101 0.77936042 1.6572127 0.39169422 0.4871916
#> T-26-0050_Operator_2   0.06188925 0.04343322 1.4006515 0.01791531 0.2508143
#> T-26-0051_Operator_1   1.58966604 1.24421578 2.1744593 0.41444289 0.6283662
#> T-26-0051_Operator_2   1.59664952 1.23032306 2.1620499 0.41464188 0.7006842
#> T-26-0052_Operator_1   2.24642991 1.14389444 1.1290314 0.74768975 4.0716062
#> T-26-0052_Operator_2   2.08821902 1.10096927 2.7000014 0.76984464 1.0379663
#> T-26-0053_Operator_1   2.14723477 1.22614176 2.7139476 0.69788999 0.8296945
#> T-26-0053_Operator_2   1.97647700 1.17380203 2.5809823 0.70837184 0.8287973
#> T-26-0054_Operator_1   2.17195527 1.28713454 2.4491505 0.68780757 0.7506219
#> T-26-0054_Operator_2   2.07462225 1.16812374 2.5610878 0.70840527 0.7519099
#> T-26-0055_Operator_1   1.57601313 1.37003756 1.9466903 0.47945785 0.5115428
#> T-26-0055_Operator_2   1.55642634 1.27273737 1.7686611 0.38876858 0.5341243
#> T-26-0056-2_Operator_1 1.91948876 1.47785363 2.0298051 0.52266256 0.6807006
#> T-26-0056-2_Operator_2 1.79200905 1.26358899 1.9606677 0.47026855 0.7227897
#> T-26-0057_Operator_1   1.23767209 1.06991858 1.6914708 0.27980683 0.5027355
#> T-26-0057_Operator_2   1.21145149 1.06937847 1.6359525 0.36670248 0.4125956
#> T-26-0058_Operator_1   1.16197101 0.77936042 2.0801927 0.39169422 0.6154796
#> T-26-0058_Operator_2   1.16197101 0.77936042 1.6265885 0.39169422 0.5295692
#> T-26-0059_Operator_1   1.16197101 0.77936042 0.8329248 0.39169422 0.5212983
#> T-26-0059_Operator_2   1.40198963 0.77936042 1.6265885 0.34596313 0.4652900
#> T-26-0060_Operator_1   1.15734043 0.96172531 1.7425274 0.33800795 0.5746917
#> T-26-0060_Operator_2   1.13123337 0.89123955 1.6335112 0.31350388 0.5242985
#> T-26-0061_Operator_1   2.45346204 1.23176834 2.3939069 0.75689551 0.8050211
#> T-26-0061_Operator_2   2.15607821 1.05604822 2.5626686 0.82359573 0.7867538
#> T-26-0062_Operator_1   2.90262484 1.51969366 3.3331083 0.87978825 1.1064440
#> T-26-0062_Operator_2   2.53914014 1.29418239 3.4885413 1.00116004 1.1302766
#> T-26-0063_Operator_1   1.16096169 0.99151697 1.4287984 0.33465972 0.4692763
#> T-26-0063_Operator_2   1.11287069 0.92371433 1.1981869 0.29809621 0.4141536
#> T-26-0064_Operator_1   0.96233793 0.94573132 1.8202765 0.38630372 0.5180883
#> T-26-0064_Operator_2   1.16197101 0.77936042 1.8979116 0.39169422 0.5396891
#> T-26-0065_Operator_1   1.49141693 1.00748069 1.5576676 0.45346736 0.5837907
#> T-26-0065_Operator_2   1.38955003 0.96859863 1.5515453 0.38677211 0.4764707
#> T-26-0067_Operator_1   1.49740891 1.06956639 1.8778103 0.34431892 0.5123565
#> T-26-0067_Operator_2   1.56135387 1.01844731 1.8475157 0.33983901 0.4994724
#> T-26-0068_Operator_1   1.56945476 1.08834576 1.9250632 0.68207462 0.4680862
#> T-26-0068_Operator_2   1.83118280 0.89682711 2.0197788 0.67400524 1.0209698
#> T-26-0069_Operator_1   0.80581429 0.43405924 1.4059721 0.38435072 0.4940410
#> T-26-0069_Operator_2   0.80581429 0.42108507 1.4888260 0.52135503 0.5467153
#> T-26-0070_Operator_1   1.32576288 0.68897247 1.4100550 0.53348055 0.6782875
#> T-26-0070_Operator_2   1.35046019 0.66248752 1.3849447 0.51496048 0.6877203
#> T-26-0071_Operator_1   1.11777343 0.79726891 1.7545520 0.28990578 0.3674879
#> T-26-0071_Operator_2   1.10255329 0.76866932 1.7294743 0.30489140 0.5138507
#> T-26-0072_Operator_1   1.39379547 0.99117535 1.9751873 0.39644021 0.7597339
#> T-26-0072_Operator_2   1.39718384 0.91377600 1.8084275 0.36744782 0.5151795
#> T-26-0073_Operator_1   1.65061732 1.19524539 1.9013395 0.41345556 0.6013497
#> T-26-0073_Operator_2   1.51317888 1.09291486 1.9732215 0.38202285 0.5462946
#> T-26-0074_Operator_1   1.13044367 1.03864732 2.0462477 0.39450351 0.6070726
#> T-26-0074_Operator_2   1.18027671 1.01448264 1.9553582 0.38320461 0.6037259
#> T-26-0075_Operator_1   2.07671029 1.63297393 1.9851945 0.49575558 0.6472792
#> T-26-0075_Operator_2   1.92953385 1.16607194 1.9608088 0.48309695 0.6568013
#> T-26-0076_Operator_1   0.80581429 0.43405924 2.0294772 0.38435072 0.4951869
#> T-26-0076_Operator_2   0.80581429 0.43405924 2.0005536 0.38435072 0.6841691
#> T-26-0077_Operator_1   0.75120319 0.61028019 1.2435845 0.34533131 0.2377478
#> T-26-0077_Operator_2   1.16197101 0.77936042 1.2338145 0.39169422 0.3678623
#> T-26-0078_Operator_1   1.08886123 0.89075319 1.9862341 0.43641259 0.6535970
#> T-26-0078_Operator_2   1.01208435 0.87158544 2.0337646 0.43940402 0.5956261
#> T-26-0079_Operator_1   1.27675005 0.93550441 1.4834435 0.41135491 0.5588320
#> T-26-0079_Operator_2   1.29763907 0.85108588 1.5106486 0.40660657 0.4855327
#> T-26-0080_Operator_1   1.00159385 0.50594336 1.0968826 0.47603729 0.4765894
#> T-26-0080_Operator_2   0.98836029 0.45044066 1.0490358 0.45928088 0.5289646
#> T-26-0081_Operator_1   1.16197101 0.77936042 1.1833056 0.39169422 0.3466291
#> T-26-0081_Operator_2   1.16197101 0.77936042 1.1448039 0.39169422 0.3781989
#> T-26-0082_Operator_1   1.48351791 0.78830667 1.5644288 0.51906017 0.2392996
#> T-26-0082_Operator_2   0.80581429 0.68644632 1.6278193 0.38435072 0.5609133
#> T-26-0083_Operator_1   1.16197101 0.77936042 1.1772954 0.39169422 0.3779979
#> T-26-0083_Operator_2   1.16197101 0.59255105 1.2021122 0.39169422 0.3887368
#> T-26-0084_Operator_1   1.16197101 0.77936042 1.2376895 0.39169422 0.4996879
#> T-26-0084_Operator_2   1.16197101 0.77936042 1.2322492 0.39169422 0.4789447
#> T-26-0085_Operator_1   1.10160150 0.79719179 1.7350736 0.35800383 0.6112334
#> T-26-0085_Operator_2   1.16197101 0.77936042 1.6116718 0.39169422 0.6080920
#> T-26-0086_Operator_1   1.46514875 1.07794175 1.8678994 0.40914308 0.6576322
#> T-26-0086_Operator_2   1.50685742 0.95839062 1.8276425 0.37892073 0.6952433
#> T-26-0087_Operator_1   1.16197101 0.77936042 1.6968310 0.39169422 0.5206477
#> T-26-0087_Operator_2   1.16197101 0.77936042 1.5834633 0.39169422 0.5306167
#> T-26-0088_Operator_1   0.89087028 0.86343853 1.6990085 0.38827083 0.4599713
#> T-26-0088_Operator_2   1.19194262 0.93312178 1.6379129 0.40141645 0.4092631
#> T-26-0089_Operator_1   0.80581429 0.43405924 0.2923484 0.38435072 0.4072843
#> T-26-0089_Operator_2   0.37859256 0.13948559 0.3330603 0.25291715 0.2777671
#> T-26-0090_Operator_1   0.80581429 0.43405924 0.6199527 0.38435072 0.4072843
#> T-26-0090_Operator_2   0.53404492 0.39987506 0.7016709 0.27573959 0.2683026
#> T-26-0091_Operator_1   1.23748928 0.77729032 1.6913150 0.31308479 0.5438174
#> T-26-0091_Operator_2   1.16197101 0.77936042 1.7716113 0.39169422 0.5827074
#> T-26-0092_Operator_1   1.17295805 0.88559604 1.5547705 0.41560754 0.5284779
#> T-26-0092_Operator_2   1.16197101 0.95226946 1.5981192 0.39169422 0.4731739
#> T-26-0093_Operator_1   1.43934188 1.01584189 1.4985562 0.40416181 0.5011183
#> T-26-0093_Operator_2   1.48408679 0.99495147 1.5946005 0.40998551 0.4547263
#> T-26-0094_Operator_1   1.16197101 0.77936042 1.3764721 0.39169422 0.3918740
#> T-26-0094_Operator_2   1.00443231 0.68358902 1.3615341 0.32474330 0.3722027
#> T-26-0095_Operator_1   1.16197101 0.77936042 1.6742417 0.39169422 0.4428063
#> T-26-0095_Operator_2   1.16197101 0.77936042 1.6568351 0.39169422 0.3870999
#> T-26-0096_Operator_1   1.16197101 0.77936042 1.1841566 0.39169422 0.4480082
#> T-26-0096_Operator_2   1.16197101 0.77936042 1.2075632 0.39169422 0.4025171
#> T-26-0097_Operator_1   1.13859838 0.84553531 1.9055686 0.36161617 0.8663626
#> T-26-0097_Operator_2   1.15154896 0.75830384 1.8480345 0.34506121 0.4686642
#> T-26-0098_Operator_1   1.15682275 0.81208111 1.4599957 0.42490168 0.5876444
#> T-26-0098_Operator_2   1.16197101 0.77936042 1.4132532 0.39169422 0.5259417
#> T-26-0099_Operator_1   0.43874751 0.28582741 0.3697782 0.29789761 0.3870888
#> T-26-0099_Operator_2   0.81120071 0.54232116 0.7553707 0.37153064 0.3589007
#> T-26-0100_Operator_1   0.86548165 0.65330832 1.1723034 0.27016768 0.1511832
#> T-26-0100_Operator_2   1.16197101 0.77936042 1.2681025 0.39169422 0.3507666
#> T-26-0101_Operator_1   1.16197101 0.77936042 1.4769617 0.39169422 0.2685223
#> T-26-0101_Operator_2   1.27154424 0.95814468 1.5250756 0.36337479 0.4148034
#> T-26-0102_Operator_1   1.16197101 0.77936042 1.7186693 0.39169422 7.5079027
#> T-26-0102_Operator_2   1.16197101 0.77936042 1.3554031 0.39169422 0.4251821
#> T-26-0103_Operator_1   1.16197101 0.77936042 2.1083910 0.39169422 0.6653315
#> T-26-0103_Operator_2   1.49528076 0.65414115 1.8186860 0.51484989 0.5722079
#> T-26-0104_Operator_1   1.16197101 0.77936042 1.8014609 0.39169422 0.6400121
#> T-26-0104_Operator_2   1.30388524 0.84539732 1.7963575 0.48395908 0.4713370
#> T-26-0107_Operator_1   1.16197101 0.77936042 1.6002662 0.39169422 0.3727630
#> T-26-0107_Operator_2   1.16197101 0.77936042 1.6265885 0.39169422 0.5295692
#> T-26-0108_Operator_1   1.16197101 0.77936042 2.0553892 0.39169422 0.7584422
#> T-26-0108_Operator_2   1.16197101 0.77936042 1.9177357 0.39169422 0.5255359
#> T-26-0109_Operator_1   1.16197101 0.77936042 1.7322581 0.39169422 0.6847351
#> T-26-0109_Operator_2   1.28679403 0.93454531 1.7231443 0.42804513 0.4837936
#> T-26-0111_Operator_1   1.16197101 0.77936042 1.1830072 0.39169422 0.1808627
#> T-26-0111_Operator_2   1.16197101 0.77936042 0.3798422 0.39169422 0.1368515
#> T-26-0112-2_Operator_1 0.78889343 0.59097291 1.1687621 0.34102676 0.3096387
#> T-26-0112-2_Operator_2 0.79835979 0.60746448 1.2117847 0.36217176 0.4182496
#> T-26-0112_Operator_1   0.47200451 0.35229595 0.6100681 0.23480605 0.3870888
#> T-26-0112_Operator_2   0.81120071 0.54232116 0.6182181 0.37153064 0.3870888
#> T-26-0113_Operator_1   0.44106940 0.44334855 1.3759575 0.31669336 0.5331575
#> T-26-0113_Operator_2   0.67859424 0.51487060 1.3832709 0.34173904 0.4584871
#> T-26-0114_Operator_1   0.97476734 0.77703696 1.4083986 0.37269954 0.3084577
#> T-26-0114_Operator_2   1.10923796 0.82018270 2.0213691 0.37642507 0.4402109
#> T-26-0115_Operator_1   1.01744585 0.84797296 2.1192550 0.41474689 0.4722676
#> T-26-0115_Operator_2   0.87886941 0.52883631 1.5678789 0.37650426 0.3352555
#> T-26-0116_Operator_1   0.92444200 0.56608094 1.5664673 0.38813413 0.4524785
#> T-26-0116_Operator_2   1.09660596 0.70820908 1.5959183 0.33154360 0.3961208
#> T-26-0117_Operator_1   1.02831257 0.79766724 1.6938219 0.32838208 0.6200159
#> T-26-0117_Operator_2   1.32098841 0.82430524 1.6308200 0.35579038 0.4030355
#> T-26-0118_Operator_1   1.28125480 0.82828532 1.7138154 0.38373797 0.4460225
#> T-26-0118_Operator_2   1.16197101 0.77936042 1.6322325 0.39169422 0.3999241
#> T-26-0120_Operator_1   0.95962484 0.68246846 1.3382559 0.29316999 0.4871104
#> T-26-0120_Operator_2   1.16197101 0.77936042 1.2518287 0.39169422 0.3321514
#> T-26-0121_Operator_1   1.00505768 0.65203616 1.4483889 0.42721977 0.4167373
#> T-26-0121_Operator_2   1.16197101 0.77936042 6.0000000 0.39169422 5.7083333
#> T-26-0122_Operator_1   1.16197101 0.77936042 1.9967863 0.39169422 0.7767666
#> T-26-0122_Operator_2   1.02037079 0.80849585 1.8983368 0.39762585 0.6085192
#> T-26-0123_Operator_1   0.89597693 0.62105853 1.7045562 0.38084397 0.4396152
#> T-26-0123_Operator_2   1.16197101 0.77936042 1.6530308 0.39169422 0.3575250
#> T-26-0125_Operator_1   0.83048986 0.47056664 1.4955752 0.38460657 0.5039151
#> T-26-0125_Operator_2   0.97964149 0.54221317 1.4079212 0.34888067 0.4000436
#> T-26-0126_Operator_1   1.05214463 0.70140867 1.3986442 0.35749104 0.5056193
#> T-26-0126_Operator_2   1.06254821 0.73533739 1.3302349 0.31627989 0.3359975
#> T-26-0127_Operator_1   1.37718799 1.04298015 1.8398135 0.50919781 0.4738615
#> T-26-0127_Operator_2   1.33385745 1.00407629 1.7344488 0.38726397 0.4359544
#> T-26-0128_Operator_1   0.80581429 0.43405924 1.2116350 0.38435072 0.4295619
#> T-26-0128_Operator_2   0.80581429 0.43405924 1.1562563 0.38435072 0.5492232
#> T-26-0130_Operator_1   0.80581429 0.43405924 0.8351162 0.38435072 0.2862719
#> T-26-0130_Operator_2   0.48737776 0.39382896 0.8405935 0.31314344 0.3342377
#> T-26-0131_Operator_1   1.23808221 0.92474939 1.5657946 0.40393083 0.5579866
#> T-26-0131_Operator_2   1.20767957 0.85693038 1.6651262 0.38347532 0.5199723
#> T-26-0132_Operator_1   1.37325973 1.02737316 1.8088123 0.39725096 0.6069332
#> T-26-0132_Operator_2   1.30923446 1.00875847 1.6842995 0.35605999 0.5262678
#> T-26-0133_Operator_1   1.12529359 0.93398043 1.8250010 0.66900341 0.6416771
#> T-26-0133_Operator_2   0.93768226 0.69303052 1.8524395 0.64582860 0.7568850
#> T-26-0134_Operator_1   1.30985126 0.90476654 1.6411247 0.44917529 0.5635258
#> T-26-0134_Operator_2   1.33235690 0.83393188 1.5896988 0.31863281 0.5309549
#> T-26-0135_Operator_1   0.69999185 0.76553010 1.7409794 0.62082813 0.7547213
#> T-26-0135_Operator_2   1.12529359 0.93398043 1.8711602 0.66900341 0.7242575
#> T-26-0136_Operator_1   1.31137149 0.92448775 1.7625783 0.41087217 0.4871382
#> T-26-0136_Operator_2   1.16197101 0.77936042 1.7830444 0.39169422 0.5571091
#> T-26-0137_Operator_1   2.13650395 1.16508785 2.7263705 0.82564956 0.6909041
#> T-26-0137_Operator_2   2.23220936 1.10450381 2.6728921 0.86306150 0.7225434
#> T-26-0138_Operator_1   1.05787234 0.74152780 1.7502041 0.39455782 0.6282305
#> T-26-0138_Operator_2   1.16197101 0.77936042 1.6478691 0.39169422 0.4479196
#> T-26-0139_Operator_1   1.22778224 0.80264680 1.7309018 0.44898957 0.4785937
#> T-26-0139_Operator_2   1.23141829 0.76327160 1.7028098 0.42104031 0.4682776
#> T-26-0140_Operator_1   0.95772648 0.58461559 1.3035875 0.38357278 0.5405312
#> T-26-0140_Operator_2   0.93400000 0.54723063 1.2460288 0.33681013 0.5295692
#> T-26-0141_Operator_1   1.26378499 0.81516448 1.6547478 0.43155108 0.4748445
#> T-26-0141_Operator_2   1.26509198 0.74829343 1.6749086 0.36560528 0.5065169
#> T-26-0142_Operator_1   0.91648303 0.62547890 1.4499866 0.39261592 0.4696423
#> T-26-0142_Operator_2   0.88665223 0.51871195 1.3843087 0.34092689 0.3995250
#> T-26-0143_Operator_1   1.12635963 0.58441382 1.3609304 0.53863226 0.2495543
#> T-26-0143_Operator_2   1.25736708 0.47449025 1.4005965 0.53548247 0.4185266
#> T-26-0144_Operator_1   1.03061786 0.58519220 1.6933311 0.68737785 0.4769916
#> T-26-0144_Operator_2   1.37547552 0.47326687 1.7859188 0.69630113 0.7570442
#> T-26-0145_Operator_1   0.48781700 0.14849495 0.3313965 0.26116918 0.2936343
#> T-26-0145_Operator_2   0.48781700 0.14849495 0.3313965 0.26116918 0.2936343
#> T-26-0146_Operator_1   1.69750133 1.17014074 2.0618277 0.46948714 0.6171036
#> T-26-0146_Operator_2   1.80131544 1.10163817 1.9765569 0.44601877 0.4925305
#> T-26-0147_Operator_1   1.57358376 1.18072770 1.9726283 0.52994174 0.7422911
#> T-26-0147_Operator_2   2.24642991 1.14389444 1.9097073 0.74768975 0.6860712
#> T-26-0148_Operator_1   2.00135172 1.19845887 2.6187162 0.85600618 0.7057742
#> T-26-0148_Operator_2   2.32519867 1.22650429 2.6430922 0.82916326 0.8894052
#> T-26-0149_Operator_1   4.45613040 2.48550152 4.6610643 1.18018202 0.9154846
#> T-26-0149_Operator_2   4.81529744 2.27228736 4.6842182 1.02101156 1.4805068
#> T-26-0150_Operator_1   2.09859855 1.60581487 3.1373845 0.68956951 1.2742445
#> T-26-0150_Operator_2   2.24642991 1.14389444 3.2137429 0.74768975 1.1452198
#> T-26-0151_Operator_1   1.16569761 0.66202617 2.1201530 0.42564186 0.5897905
#> T-26-0151_Operator_2   1.15934569 0.75065285 2.1000065 0.42765647 0.5111609
#> T-26-0152_Operator_1   0.36951435 0.23119210 1.6265885 0.20852848 0.5295692
#> T-26-0152_Operator_2   1.16197101 0.77936042 0.4330594 0.39169422 0.5295692
#> T-26-0153_Operator_1   0.77944075 0.45594314 1.6735357 0.41515054 0.5898829
#> T-26-0153_Operator_2   0.88667101 0.50323227 1.6267507 0.41418687 0.5485082
#> T-26-0154_Operator_1   1.16197101 0.77936042 1.3245165 0.39169422 0.4712445
#> T-26-0154_Operator_2   0.95467615 0.57626439 1.4466320 0.38959674 0.4530759
#> T-26-0155_Operator_1   0.57404021 0.37809143 1.1021899 0.30051051 0.3714060
#> T-26-0155_Operator_2   0.60478165 0.36666508 1.0732178 0.27332032 0.3103235
#> T-26-0156_Operator_1   3.09134931 1.56765741 3.4591436 1.00027384 0.7460718
#> T-26-0156_Operator_2   3.52495325 1.48358018 3.3637998 0.95413513 1.1742310
#> T-26-0157_Operator_1   1.27532133 0.74789773 2.0377549 0.37418056 0.5610752
#> T-26-0157_Operator_2   1.30297386 0.74608987 1.8698796 0.38125659 0.5626915
#> T-26-0158_Operator_1   1.24507587 0.71134532 1.6106631 0.44291312 0.5237223
#> T-26-0158_Operator_2   1.32813715 0.70855925 1.5814370 0.42534176 0.4989785
#> T-26-0159_Operator_1   1.11241259 0.64865615 2.0269034 0.38529299 0.5968666
#> T-26-0159_Operator_2   1.16197101 0.77936042 1.9376328 0.39169422 0.5574770
#> T-26-0160_Operator_1   0.97811360 0.74758783 1.8198314 0.49435932 0.4114460
#> T-26-0160_Operator_2   0.99662343 0.68582527 1.7374832 0.39134365 0.4265857
#> T-26-0161_Operator_1   0.96328486 0.77995798 1.7599637 0.39331117 0.4779793
#> T-26-0161_Operator_2   1.18045334 0.76946218 1.6843952 0.37613892 0.3915056
#> T-26-0162_Operator_1   1.03026030 0.79860865 1.5367332 0.42294608 0.4396235
#> T-26-0162_Operator_2   1.12852170 0.76974202 1.4738128 0.33555420 0.3930051
#> T-26-0163_Operator_1   1.16197101 0.77936042 1.9140765 0.39169422 0.5594640
#> T-26-0163_Operator_2   1.09428113 0.64199519 1.9626074 0.42090158 0.4830145
#> T-26-0164_Operator_1   1.16197101 0.77936042 0.9141268 0.39169422 0.3429676
#> T-26-0164_Operator_2   0.43555390 0.30646803 0.8430016 0.24568191 0.2848364
#> T-26-0165_Operator_1   1.04680269 0.65515874 1.6052070 0.41718922 0.4548932
#> T-26-0165_Operator_2   1.16197101 0.77936042 1.6112125 0.39169422 0.3944191
#> T-26-0166_Operator_1   0.47479807 0.32099970 0.8996614 0.24417186 0.3288444
#> T-26-0166_Operator_2   0.50513412 0.32900374 0.8536298 0.23036949 0.3397496
#> T-26-0167_Operator_1   4.47517978 2.06820622 4.9419416 1.38802185 1.3709551
#> T-26-0167_Operator_2   4.73389358 2.05247526 4.7053834 1.31408684 1.5838309
#> T-26-0168_Operator_1   1.29693769 0.78942028 1.8497799 0.47613992 0.5218201
#> T-26-0168_Operator_2   1.30615862 0.81578524 1.6802366 0.44312228 0.4396708
#> T-26-0169_Operator_1   1.49708293 0.81106415 2.1131480 0.50041072 0.7455278
#> T-26-0169_Operator_2   2.71901077 1.55522649 4.2240358 0.95930233 1.2810266
#> T-26-0170_Operator_1   1.45431226 0.79461516 1.9492449 0.45542760 0.5649041
#> T-26-0170_Operator_2   1.48393551 0.74252886 1.8532452 0.44944179 0.5756702
#> T-26-0171_Operator_1   1.49317071 0.73810544 2.0210731 0.46970346 0.6944982
#> T-26-0171_Operator_2   1.53102332 0.80379201 1.8979906 0.44592384 0.6307252
#> T-26-0172_Operator_1   1.14624292 0.57805734 1.9413004 0.50321510 0.5994410
#> T-26-0172_Operator_2   1.14030929 0.61547302 1.9368500 0.50413554 0.6269670
#> T-26-0173_Operator_1   1.10034485 0.54509960 1.1544633 0.40098355 0.5809544
#> T-26-0173_Operator_2   1.05556286 0.58066965 1.3105541 0.38205909 0.3858349
#> T-26-0174_Operator_1   1.37976009 0.83216686 1.6253037 0.41612402 0.4882082
#> T-26-0174_Operator_2   1.16197101 0.77936042 1.5413558 0.39169422 0.3684738
#> T-26-0175_Operator_1   1.27849910 0.66444846 1.9128146 0.40273142 0.4400099
#> T-26-0175_Operator_2   1.28898582 0.63946848 1.8555608 0.41092825 0.3911753
#> T-26-0176_Operator_1   1.13845468 0.75668767 1.5805614 0.41888067 0.6526760
#> T-26-0176_Operator_2   1.21415128 0.76586585 1.5570886 0.44460612 0.6520168
#> T-26-0177_Operator_1   1.16197101 0.77936042 1.8525810 0.39169422 0.5973829
#> T-26-0177_Operator_2   1.67688525 1.03191306 1.8095329 0.39169422 0.5993567
#> T-26-0178_Operator_1   1.38222725 0.73557648 2.0775078 0.46362346 0.5083617
#> T-26-0178_Operator_2   1.40330809 0.72255802 1.9375593 0.43545240 0.4960975
#> T-26-0179-3_Operator_1 1.22506356 0.80233774 1.7499735 0.50204681 0.4939318
#> T-26-0179-3_Operator_2 1.31588369 0.72215564 1.6927206 0.46069936 0.5518222
#> T-26-0179_Operator_1   0.55891871 0.37331857 0.7474939 0.32887366 0.3105607
#> T-26-0179_Operator_2   0.59829058 0.37497161 0.7164019 0.29823348 0.2260697
#> T-26-0180_Operator_1   1.16197101 0.77936042 1.8098409 0.39169422 0.5071279
#> T-26-0180_Operator_2   1.30748784 0.77127710 1.7205466 0.47876058 0.5089066
#> T-26-0181_Operator_1   1.23955998 0.65743078 1.6951960 0.49083469 0.5810812
#> T-26-0181_Operator_2   1.23028075 0.67144757 1.6067623 0.45065789 0.4677650
#> T-26-0182_Operator_1   1.01668471 0.47128119 1.7386097 0.39995652 0.5609361
#> T-26-0182_Operator_2   1.00425174 0.49511921 1.6613910 0.32939553 0.5221259
#> T-26-0183_Operator_1   1.09606298 0.62635425 2.0524639 0.55972881 0.6699678
#> T-26-0183_Operator_2   1.11287006 0.71773476 1.9019272 0.52838079 0.5296090
#> T-26-0184_Operator_1   1.34137093 0.96798600 1.9138480 0.73291731 0.6432320
#> T-26-0184_Operator_2   1.35852499 0.66959169 1.6733664 0.66732230 0.7507929
#> T-26-0185_Operator_1   0.90769467 0.48650475 1.3703162 0.38473934 0.5026215
#> T-26-0185_Operator_2   0.87109136 0.47461450 1.3109198 0.33533617 0.3615955
#> T-26-0186_Operator_1   1.48935550 0.77968092 1.9759486 0.49990010 0.5921612
#> T-26-0186_Operator_2   1.55992046 0.75253917 1.9173256 0.52542462 0.6067416
#> T-26-0187_Operator_1   1.34118214 0.64903484 2.2884840 0.49647353 0.6240112
#> T-26-0187_Operator_2   1.37413645 0.68849921 2.0650409 0.39169422 0.5747221
#> T-26-0188_Operator_1   0.63060597 0.53349472 1.2406975 0.23114716 0.4371280
#> T-26-0188_Operator_2   0.62685530 0.55963671 1.3050264 0.20528354 0.3585239
#> T-26-0189_Operator_1   1.20995988 0.71804104 1.5505552 0.42814604 0.5755045
#> T-26-0189_Operator_2   1.14271641 0.70649571 1.6238506 0.39441189 0.3877312
#> T-26-0190_Operator_1   1.16197101 0.77936042 1.8817531 0.39169422 0.6325312
#> T-26-0190_Operator_2   0.97396959 0.49631022 1.8395520 0.43354598 0.5491635
#> T-26-0191_Operator_1   1.12123439 0.56928790 1.6712928 0.47126019 0.6046321
#> T-26-0191_Operator_2   1.12417934 0.57098496 1.6106552 0.41822902 0.5631919
#> T-26-0192_Operator_1   1.04566281 0.63522784 1.8183212 0.41139467 0.5388809
#> T-26-0192_Operator_2   1.06332695 0.63469048 1.7509180 0.37967617 0.5007292
#> T-26-0193_Operator_1   1.52072962 0.81418070 1.5232833 0.44776007 0.5855988
#> T-26-0193_Operator_2   1.16197101 0.77936042 1.5299589 0.39169422 0.4475567
#> T-26-0194_Operator_1   1.90794976 1.21867372 2.1248661 0.51277528 0.7554993
#> T-26-0194_Operator_2   1.16197101 0.77936042 1.9385909 0.39169422 0.6666753
#> T-26-0195_Operator_1   1.16197101 0.59099223 1.9539009 0.39169422 0.5133692
#> T-26-0195_Operator_2   1.16197101 0.77936042 1.9142249 0.39169422 0.5051615
#> T-26-0196_Operator_1   0.83309243 0.34157849 1.2992435 0.41170742 0.4142519
#> T-26-0196_Operator_2   1.16197101 0.77936042 1.2896523 0.39169422 0.4429503
#> T-26-0197_Operator_1   1.35124546 0.69075260 1.8154242 0.48664089 0.5497112
#> T-26-0197_Operator_2   1.30626356 0.74872050 1.8556002 0.49211988 0.4957135
#> T-26-0198_Operator_1   1.19574133 0.71268232 1.4852297 0.48618322 0.5840770
#> T-26-0198_Operator_2   1.19827325 0.71588844 1.5475114 0.41609367 0.5616308
#> T-26-0199_Operator_1   0.65032268 0.45633009 1.1930113 0.19318444 0.3796212
#> T-26-0199_Operator_2   0.66744154 0.46470429 1.1314433 0.20596978 0.2365680
#> T-26-0200_Operator_1   1.39807082 1.01471332 1.7108162 0.48738588 0.5156327
#> T-26-0200_Operator_2   1.50024260 0.94355639 1.7779299 0.42313519 0.5097908
#> T-26-0201_Operator_1   0.91080842 0.52176211 1.5403679 0.43847971 0.4739839
#> T-26-0201_Operator_2   0.90149798 0.57782187 1.4438951 0.40145861 0.4145701
#> T-26-0202_Operator_1   0.97739546 1.12420149 2.2328896 0.74058881 0.8937692
#> T-26-0202_Operator_2   1.19167354 0.83640092 2.1509872 0.64354679 1.0081444
#> T-26-0203_Operator_1   1.17111409 0.62436941 1.6849489 0.42793158 0.5379585
#> T-26-0203_Operator_2   1.10575422 0.59171985 1.6112486 0.37042637 0.4806165
#> T-26-0204_Operator_1   1.00286566 0.57489363 1.9540903 0.45078710 0.5516933
#> T-26-0204_Operator_2   1.00281000 0.62841232 1.7986907 0.41302332 0.4779014
#> T-26-0205_Operator_1   1.10857585 0.72381233 1.5656090 0.46048363 0.4298443
#> T-26-0205_Operator_2   1.10107068 0.73639503 1.4802236 0.43213670 0.3343871
#> T-26-0206_Operator_1   0.85088839 0.56508723 1.5824366 0.41296750 0.5279214
#> T-26-0206_Operator_2   1.16197101 0.77936042 1.4032833 0.39169422 0.4039247
#> T-26-0207_Operator_1   0.61273749 0.43414891 1.3098587 0.32009031 0.3949563
#> T-26-0207_Operator_2   1.16197101 0.77936042 1.2344209 0.39169422 0.3305180
#> T-26-0208_Operator_1   0.66744154 0.46470429 1.2821715 0.20596978 0.3668108
#> T-26-0208_Operator_2   0.66744154 0.46470429 1.4417030 0.20596978 0.2798919
#> T-26-0209_Operator_1   1.16197101 0.77936042 1.8863343 0.39169422 0.5830526
#> T-26-0209_Operator_2   1.45699599 0.83231026 1.9514264 0.46109523 0.5943812
#> T-26-0210_Operator_1   0.62620999 0.34752656 0.8183221 0.34423269 0.3153071
#> T-26-0210_Operator_2   0.66282623 0.47213220 0.8333186 0.33793623 0.2595998
#> T-26-0211_Operator_1   1.05571339 0.66438725 1.4869249 0.37496757 0.4958174
#> T-26-0211_Operator_2   1.05367315 0.67886186 1.4654562 0.33926367 0.3859855
#> T-26-0212_Operator_1   0.80431123 0.37488955 1.2765070 0.39592536 0.4399292
#> T-26-0212_Operator_2   1.16197101 0.77936042 1.1913589 0.39169422 0.4029324
#> T-26-0213_Operator_1   1.16471303 0.56445216 1.3226731 0.41905006 0.4815068
#> T-26-0213_Operator_2   1.17937887 0.64992646 1.3801268 0.37598373 0.3784277
#> T-26-0214_Operator_1   1.88021814 0.84209875 2.2107112 0.66838829 0.6048622
#> T-26-0214_Operator_2   1.85323778 0.99382189 2.1501490 0.71594204 0.5603791
#> T-26-0215_Operator_1   1.16463915 0.66187910 1.6010172 0.41198017 0.4682769
#> T-26-0215_Operator_2   1.17196439 0.69576367 1.5114789 0.35475746 0.3368139
#> T-26-0216_Operator_1   1.13761018 0.60886178 1.4469641 0.36531707 0.4248397
#> T-26-0216_Operator_2   1.16678387 0.66373695 1.4390191 0.34463063 0.3496519
#> T-26-0217_Operator_1   1.08285766 0.41726035 1.9441385 0.46878528 0.6918708
#> T-26-0217_Operator_2   1.07566393 0.48064269 1.8418349 0.40509227 0.5070143
#> T-26-0218_Operator_1   0.66744154 0.46470429 1.1751555 0.20596978 0.4275490
#> T-26-0218_Operator_2   0.59873581 0.43402237 1.3450401 0.17994750 0.2886943
#> T-26-0219_Operator_1   0.74034947 0.43623503 0.9211762 0.28854941 0.2984846
#> T-26-0219_Operator_2   1.16197101 0.77936042 0.8824022 0.39169422 0.2665267
#> T-26-0220_Operator_1   0.71477893 0.47892786 1.3413517 0.34439356 0.4962232
#> T-26-0220_Operator_2   0.69197190 0.49527384 1.2213921 0.31032247 0.4141562
#> T-26-0221_Operator_1   2.24642991 1.14389444 0.8763393 0.74768975 0.1794037
#> T-26-0221_Operator_2   2.24642991 1.14389444 1.1357024 0.74768975 0.3046628
#> T-26-0222_Operator_1   1.96340112 0.78822398 3.3745859 1.00167993 1.2315004
#> T-26-0222_Operator_2   2.12082274 0.84359285 3.6416051 1.06255268 1.2661727
#> T-26-0223_Operator_1   1.54171858 0.88281914 1.7407626 0.51930537 0.5645767
#> T-26-0223_Operator_2   1.54522710 0.93432127 1.8308515 0.51944063 0.5559612
#> T-26-0224_Operator_1   1.07456357 0.71420266 2.0841112 0.40261406 0.5174085
#> T-26-0224_Operator_2   1.16197101 0.77936042 2.0340292 0.39169422 0.3216723
#> T-26-0225_Operator_1   1.60081069 0.70782199 1.9962120 0.73388115 0.5787059
#> T-26-0225_Operator_2   2.24642991 1.14389444 2.0171032 0.74768975 0.5717007
#> T-26-0226_Operator_1   0.51612837 0.39354020 0.7839078 0.35483133 0.2165094
#> T-26-0226_Operator_2   1.16197101 0.77936042 0.8476074 0.39169422 0.2097156
#> T-26-0227_Operator_1   0.97447889 0.32745471 1.3189114 0.54707112 0.3711530
#> T-26-0227_Operator_2   2.24642991 1.14389444 1.3484787 0.74768975 0.5914446
#> T-26-0228_Operator_1   1.14371004 0.46245712 1.5967962 0.51900420 0.3151778
#> T-26-0228_Operator_2   1.13556269 0.39733208 1.4649202 0.49198522 0.5316171
#> T-26-0229_Operator_1   1.01656995 0.66013324 1.9265707 0.57505286 0.6356646
#> T-26-0229_Operator_2   0.97843307 0.71141854 1.9639867 0.54566002 0.6683721
#> T-26-0230-1_Operator_1 0.65424338 0.50932160 1.4255353 0.19345870 0.5346862
#> T-26-0230-1_Operator_2 0.66744154 0.46470429 2.7142857 0.20596978 0.9642857
#> T-26-0230-2_Operator_1 0.66744154 0.46470429 1.4134916 0.20596978 0.4297743
#> T-26-0230-2_Operator_2 0.39314069 0.34049972 1.3129773 0.14768377 0.2264480
#> T-26-0230-3_Operator_1 0.66744154 0.46470429 1.2717880 0.20596978 0.4545539
#> T-26-0230-3_Operator_2 0.66744154 0.46470429 1.3530797 0.20596978 0.2428629
#> T-26-0230-4_Operator_1 0.65324909 0.50858046 1.2651412 0.21337215 0.4558231
#> T-26-0230-4_Operator_2 0.66744154 0.46470429 1.2130640 0.20596978 0.2803835
#> T-26-0231_Operator_1   0.54540466 0.39832358 1.3453008 0.18589120 0.4922311
#> T-26-0231_Operator_2   0.66744154 0.46470429 1.2683511 0.20596978 0.4268692
#> T-26-0232_Operator_1   0.66437686 0.54923514 1.2630361 0.21708790 0.3504884
#> T-26-0232_Operator_2   0.66744154 0.46470429 1.2430980 0.20596978 0.2963734
#> T-26-0233_Operator_1   0.66744154 0.46470429 1.2957291 0.20596978 0.3844492
#> T-26-0233_Operator_2   0.66744154 0.46470429 1.0044948 0.20596978 0.2914795
#> T-26-0234_Operator_1   2.81861504 1.24136099 3.2357406 0.90196009 0.8574090
#> T-26-0234_Operator_2   2.24642991 1.14389444 3.1746314 0.74768975 0.6560534
#> T-26-0235_Operator_1   1.06658894 0.44057474 0.9735126 0.49044458 0.2979985
#> T-26-0235_Operator_2   2.24642991 1.14389444 1.0667255 0.74768975 0.2999464
#> T-26-0236_Operator_1   2.14712171 0.84958157 2.6929018 0.91595122 0.7561259
#> T-26-0236_Operator_2   2.18449550 0.89092407 2.5132647 0.81264778 0.8475999
#> T-26-0237_Operator_1   2.08066647 0.85836937 2.6636192 0.82297482 0.7084239
#> T-26-0237_Operator_2   2.10308829 0.82904383 2.4745352 0.83060856 0.9459992
#> T-26-0238_Operator_1   1.49333827 0.66894662 2.0470459 0.64925370 0.4398730
#> T-26-0238_Operator_2   2.24642991 1.14389444 2.0753058 0.74768975 0.3881104
#> T-26-0239_Operator_1   1.18386821 0.99404402 1.5136591 0.72488839 0.6525848
#> T-26-0239_Operator_2   1.12529359 0.93398043 2.1669605 0.66900341 0.6381912
#> T-26-0240_Operator_1   1.07868766 0.47603201 1.0817543 0.43147996 0.3402350
#> T-26-0240_Operator_2   1.06573783 0.45954773 1.0355680 0.40580571 0.2727971
#> T-26-0241_Operator_1   0.55382169 0.30341121 0.7749065 0.32634274 0.3352962
#> T-26-0241_Operator_2   1.16197101 0.77936042 0.8277468 0.39169422 0.2047270
#> T-26-0242_Operator_1   2.86337392 1.34018386 2.6095346 0.91813310 0.8058141
#> T-26-0242_Operator_2   2.78933431 1.44983285 2.7076427 0.74523084 0.5510857
#> T-26-0243_Operator_1   0.62626384 0.31834075 0.5025614 0.37022227 0.4072843
#> T-26-0243_Operator_2   0.80581429 0.43405924 0.6218678 0.38435072 0.3087071
#> T-26-0244_Operator_1   0.46591387 0.26160274 0.9741679 0.24565178 0.4072843
#> T-26-0244_Operator_2   0.47338326 0.17135709 0.4646828 0.21874473 0.2506922
#> T-26-0245_Operator_1   0.83666866 0.33334815 0.9329054 0.50337468 0.2092302
#> T-26-0245_Operator_2   0.92486850 0.32433093 0.8572459 0.44136989 0.3426519
#> T-26-0246_Operator_1   0.90818858 0.32386315 0.9138203 0.48060936 0.2992697
#> T-26-0246_Operator_2   2.24642991 1.14389444 0.9891673 0.74768975 0.2640474
#> T-26-0247_Operator_1   0.51548776 0.26214909 0.8334120 0.31503569 0.3011354
#> T-26-0247_Operator_2   0.80581429 0.43405924 0.8430318 0.38435072 0.2898066
#> T-26-0248_Operator_1   0.43008693 0.15741371 0.4076571 0.21504060 0.2392820
#> T-26-0248_Operator_2   0.80581429 0.43405924 0.4225775 0.38435072 0.2441442
#> T-26-0249_Operator_1   0.42165583 0.17228589 0.4106802 0.27162431 0.2436490
#> T-26-0249_Operator_2   0.80581429 0.43405924 0.3791004 0.38435072 0.2320982
#> T-26-0250_Operator_1   0.48100611 0.23777752 0.3611692 0.27296152 0.1838095
#> T-26-0250_Operator_2   0.50691290 0.18332159 0.3917656 0.26948539 0.1739732
#> T-26-0251_Operator_1   0.49832927 0.32048021 0.8569294 0.29744903 0.3245761
#> T-26-0251_Operator_2   2.24642991 1.14389444 0.8120889 0.74768975 0.3395488
#> T-26-0252_Operator_1   2.24642991 0.19087001 0.5778989 0.74768975 0.1497566
#> T-26-0252_Operator_2   2.24642991 1.14389444 0.6409236 0.74768975 0.2071919
#> T-26-0261-1_Operator_1 1.16197101 0.77956742 2.1859352 0.39169422 0.7287484
#> T-26-0261-1_Operator_2 1.07907389 0.80474724 2.2016044 0.33135900 0.5476256
#> T-26-0261-2_Operator_1 1.27891375 0.92676017 1.8828159 0.41478989 0.6933126
#> T-26-0261-2_Operator_2 1.23145738 0.64853706 1.9604526 0.37325455 0.5913947
#> T-26-0261-3_Operator_1 1.41453169 0.76515933 1.6612556 0.36673120 0.5545724
#> T-26-0261-3_Operator_2 1.35400779 0.75017996 1.4980387 0.38429814 0.3610260
#> T-26-0261-4_Operator_1 0.98694869 0.50957400 1.3066810 0.36121432 0.4950245
#> T-26-0261-4_Operator_2 1.02893237 0.50885237 1.2284369 0.29181906 0.4429458
#> T-26-0261-5_Operator_1 1.31293175 0.54545272 1.8428619 0.34766362 0.6839897
#> T-26-0261-5_Operator_2 1.35026187 0.58080972 1.7761817 0.36877878 0.6478548
#> T-26-0262-1_Operator_1 1.01308992 0.62343357 1.4744468 0.41266819 0.4469410
#> T-26-0262-1_Operator_2 1.06753668 0.68249693 1.5593549 0.39169422 0.5295692
#> T-26-0262-2_Operator_1 1.22722719 0.78705776 1.3347221 0.36109563 0.3809096
#> T-26-0262-2_Operator_2 1.20758519 0.71253455 1.3738320 0.36317692 0.4323511
#> T-26-0263_Operator_1   0.33117490 0.28938703 0.7108980 0.27715268 0.2845440
#> T-26-0263_Operator_2   1.16197101 0.77936042 0.6839560 0.39169422 0.2185070
#> T-26-0264-1_Operator_1 0.66282623 0.47213220 0.9098239 0.33793623 0.3467906
#> T-26-0264-1_Operator_2 0.36969742 0.29873447 0.6347761 0.24692125 0.2076427
#> T-26-0264-2_Operator_1 0.66282623 0.47213220 0.6391976 0.33793623 0.3681865
#> T-26-0264-2_Operator_2 0.66282623 0.47213220 0.6842708 0.33793623 0.2611183
#> T-26-0264-3_Operator_1 0.66282623 0.47213220 0.7972604 0.33793623 0.3590712
#> T-26-0264-3_Operator_2 0.51076847 0.20621551 0.8954858 0.23983074 0.3691504
#> T-26-0264-4_Operator_1 1.16197101 0.77936042 0.6242245 0.39169422 0.2590520
#> T-26-0264-4_Operator_2 1.16197101 0.77936042 0.5470114 0.39169422 0.1712749
#> T-26-0265_Operator_1   2.24642991 1.14389444 1.3583078 0.74768975 0.7686066
#> T-26-0265_Operator_2   1.37843346 0.49422899 1.4787695 0.55024928 0.6294201
#> T-26-0266_Operator_1   3.40458062 1.56881602 4.0784015 1.02242346 1.4374242
#> T-26-0266_Operator_2   3.27445249 1.38585372 4.2207100 1.01745140 1.3056970
#> T-26-0267_Operator_1   2.24642991 1.14389444 4.3351966 0.74768975 1.4368203
#> T-26-0267_Operator_2   4.17766885 1.86696709 4.3489138 1.15699369 1.0019104
#> T-26-0268_Operator_1   0.92011977 0.42160157 1.3826433 0.45185160 0.4182984
#> T-26-0268_Operator_2   0.97325813 0.39803949 1.2562755 0.42727464 0.4173573
#> T-26-0269_Operator_1   1.00803734 0.55001838 1.3065135 0.47999279 0.7618184
#> T-26-0269_Operator_2   2.24642991 1.14389444 1.2117464 0.74768975 0.7263527
#> T-26-0270-1_Operator_1 1.54978550 0.82987215 2.0703684 0.72324057 0.9454317
#> T-26-0270-1_Operator_2 2.24642991 1.14389444 2.1342190 0.74768975 1.1270447
#> T-26-0270-2_Operator_1 2.24642991 0.66836448 2.2068322 0.74768975 1.1332390
#> T-26-0270-2_Operator_2 2.24642991 0.79495891 2.2839159 0.74768975 1.0694007
#> T-26-0271_Operator_1   1.28707456 1.05612453 1.4288417 0.70018464 0.9437855
#> T-26-0271_Operator_2   1.12529359 0.93398043 1.9600977 0.66900341 1.2271158
#> T-26-0272_Operator_1   0.62500000 0.34551704 1.4820194 0.26374947 0.3822552
#> T-26-0272_Operator_2   0.70749356 0.38210986 1.3993141 0.22749323 0.3727187
#> T-26-0273_Operator_1   2.24642991 1.14389444 1.4668393 0.74768975 0.6778086
#> T-26-0273_Operator_2   1.17163552 0.46140110 1.4977092 0.52368515 0.6130181
#> T-26-0274_Operator_1   0.73472825 0.52670069 1.2431572 0.22561543 0.4288991
#> T-26-0274_Operator_2   0.74046412 0.48127522 1.3150777 0.17242980 0.3296068
#> T-26-0275_Operator_1   0.63842637 0.41817531 1.4296359 0.19427088 0.3611908
#> T-26-0275_Operator_2   0.65770747 0.37391143 1.2887249 0.17111278 0.4098693
#> T-26-0276_Operator_1   0.76873760 0.52359585 1.0499575 0.34284948 0.5673048
#> T-26-0276_Operator_2   0.79456636 0.55321089 1.0213977 0.34111700 0.4341671
#> T-26-0277_Operator_1   0.66744154 0.46470429 1.1166362 0.20596978 0.4560666
#> T-26-0277_Operator_2   0.85624224 0.39561356 1.1290499 0.33768957 0.3844492
#> T-26-0278-1_Operator_1 0.86401663 0.41056703 1.0048873 0.20547745 0.2735921
#> T-26-0278-1_Operator_2 0.66744154 0.46470429 1.0907479 0.20596978 0.3844492
#> T-26-0278-2_Operator_1 0.66744154 0.46470429 1.1752007 0.20596978 0.4002435
#> T-26-0278-2_Operator_2 0.66744154 0.46470429 1.1282148 0.20596978 0.2873251
#> T-26-0279_Operator_1   0.73406409 0.64568390 1.1053879 0.20927980 0.4565335
#> T-26-0279_Operator_2   0.70631205 0.56038309 1.2345728 0.13925098 0.3074775
#>                                CPd        CFd
#> T-26-0001_Operator_1    0.74661661  2.3881553
#> T-26-0001_Operator_2    0.88204160  2.3555187
#> T-26-0002_Operator_1    0.86744898  2.9887710
#> T-26-0002_Operator_2    0.84131281  2.9463784
#> T-26-0003_Operator_1    0.84316511  1.6661061
#> T-26-0003_Operator_2    0.75136772  1.6219693
#> T-26-0004_Operator_1    1.98212136  6.9970171
#> T-26-0004_Operator_2    1.92616619  6.9441999
#> T-26-0005_Operator_1    0.67852772  1.3777322
#> T-26-0005_Operator_2    0.60294313  1.3602311
#> T-26-0006_Operator_1    0.75898188  2.8119275
#> T-26-0006_Operator_2    0.82683299  2.8132208
#> T-26-0007_Operator_1    2.04786778  6.6249103
#> T-26-0007_Operator_2    2.00595819  6.7471584
#> T-26-0008_Operator_1    1.57519468  5.1621230
#> T-26-0008_Operator_2    1.48020167  5.1817373
#> T-26-0009_Operator_1    0.79557461  2.4649486
#> T-26-0009_Operator_2    0.79387286  2.4462978
#> T-26-0010_Operator_1    0.89507494  3.2100664
#> T-26-0010_Operator_2    0.85906212  3.1779213
#> T-26-0011_Operator_1    2.69358908  6.4940660
#> T-26-0011_Operator_2    2.64979636  6.7154595
#> T-26-0012_Operator_1    0.64992797  2.3813561
#> T-26-0012_Operator_2    0.62490733  2.3480907
#> T-26-0013_Operator_1    0.87018717  3.0692624
#> T-26-0013_Operator_2    0.85918646  3.1755699
#> T-26-0014_Operator_1    0.87995790  3.2781578
#> T-26-0014_Operator_2    0.87361926  3.2468369
#> T-26-0015_Operator_1    0.83986095  3.2807552
#> T-26-0015_Operator_2    0.82078919  3.1747721
#> T-26-0016_Operator_1    0.91906871  3.7056342
#> T-26-0016_Operator_2    0.86026901  3.5868047
#> T-26-0017_Operator_1    0.72855360  2.6726891
#> T-26-0017_Operator_2    0.70414033  2.6121760
#> T-26-0018_Operator_1    2.14607318  6.4822496
#> T-26-0018_Operator_2    2.06087815  6.3293571
#> T-26-0019_Operator_1    1.41393476  4.4712612
#> T-26-0019_Operator_2    1.38760649  4.4044201
#> T-26-0020_Operator_1    0.95642433  3.4848776
#> T-26-0020_Operator_2    1.04691321  3.5395061
#> T-26-0021_Operator_1    0.89791500  2.4039626
#> T-26-0021_Operator_2    0.87721304  2.3828054
#> T-26-0022_Operator_1    1.24130427  4.0739721
#> T-26-0022_Operator_2    1.20715123  4.1010720
#> T-26-0023-2_Operator_1  0.39402038  0.9158103
#> T-26-0023-2_Operator_2  0.42295894  0.9631697
#> T-26-0024_Operator_1    0.85051728  2.9368704
#> T-26-0024_Operator_2    0.81469432  2.8974944
#> T-26-0025_Operator_1    0.94529490  3.6004115
#> T-26-0025_Operator_2    0.96418946  3.5249485
#> T-26-0026_Operator_1    0.98714689  3.3994856
#> T-26-0026_Operator_2    0.99608091  3.3831603
#> T-26-0027_Operator_1    1.02166995  3.0321515
#> T-26-0027_Operator_2    1.07698580  2.9963935
#> T-26-0028_Operator_1    0.73958518  2.1741848
#> T-26-0028_Operator_2    0.75594186  2.2006804
#> T-26-0029_Operator_1    0.54001147  1.5831947
#> T-26-0029_Operator_2    0.53096732  1.5686845
#> T-26-0030_Operator_1    1.34909983  3.2185060
#> T-26-0030_Operator_2    1.31589905  3.4722759
#> T-26-0031_Operator_1    0.82542841  2.1630255
#> T-26-0031_Operator_2    0.81679600  2.1806618
#> T-26-0032_Operator_1    2.73647143  7.4349779
#> T-26-0032_Operator_2    2.61320235  7.5128231
#> T-26-0033_Operator_1    0.89125851  3.1456551
#> T-26-0033_Operator_2    0.88976082  3.1437432
#> T-26-0034_Operator_1    0.91393689  2.7748779
#> T-26-0034_Operator_2    0.97581388  2.8123216
#> T-26-0035_Operator_1    0.61076946  1.5660901
#> T-26-0035_Operator_2    0.64985944  1.6103029
#> T-26-0036_Operator_1    1.34522540  3.3372124
#> T-26-0036_Operator_2    1.37571298  3.4356045
#> T-26-0037_Operator_1    1.78656147  4.2604351
#> T-26-0037_Operator_2    1.85075923  4.5821328
#> T-26-0038_Operator_1    0.75159969  1.8861551
#> T-26-0038_Operator_2    0.77625521  1.8473321
#> T-26-0039_Operator_1    0.84979877  2.6692090
#> T-26-0039_Operator_2    0.84227964  2.7185547
#> T-26-0040_Operator_1    0.88569211  1.8204049
#> T-26-0040_Operator_2    0.95972227  1.8945356
#> T-26-0041_Operator_1    0.66020674  2.1580169
#> T-26-0041_Operator_2    0.69296749  2.1713621
#> T-26-0042_Operator_1    0.94024767  3.5479846
#> T-26-0042_Operator_2    1.01297431  3.5318681
#> T-26-0043_Operator_1    0.85348786  2.7862582
#> T-26-0043_Operator_2    0.87329601  2.7804717
#> T-26-0044_Operator_1    0.96634059  3.3917235
#> T-26-0044_Operator_2    1.05279955  3.3311251
#> T-26-0045_Operator_1    1.54817839  5.8389634
#> T-26-0045_Operator_2    1.47815431  5.6214807
#> T-26-0046_Operator_1    0.89272572  3.1513142
#> T-26-0046_Operator_2    0.86872525  3.1279829
#> T-26-0047_Operator_1    2.83768077  9.6624416
#> T-26-0047_Operator_2    2.88405579 10.0136552
#> T-26-0048_Operator_1    1.04700214  3.1011184
#> T-26-0048_Operator_2    1.18130210  3.1493540
#> T-26-0049_Operator_1    1.45381636  4.9975595
#> T-26-0049_Operator_2    1.50664459  5.0148786
#> T-26-0050_Operator_1    0.78376397  2.8838907
#> T-26-0050_Operator_2    0.08143322  0.1628664
#> T-26-0051_Operator_1    1.04491646  4.1096629
#> T-26-0051_Operator_2    1.11659528  4.2243517
#> T-26-0052_Operator_1    1.04033850  1.4969613
#> T-26-0052_Operator_2    1.72679819  5.7026300
#> T-26-0053_Operator_1    1.77835121  4.5813119
#> T-26-0053_Operator_2    1.70813358  4.5167976
#> T-26-0054_Operator_1    1.47213186  4.3374223
#> T-26-0054_Operator_2    1.55105328  4.4662890
#> T-26-0055_Operator_1    0.94478386  2.8418018
#> T-26-0055_Operator_2    1.00091438  2.8544145
#> T-26-0056-2_Operator_1  1.09998822  4.0491518
#> T-26-0056-2_Operator_2  1.19404463  4.0139593
#> T-26-0057_Operator_1    0.84792056  2.9038447
#> T-26-0057_Operator_2    0.91610418  2.8548034
#> T-26-0058_Operator_1    1.09506626  3.1454666
#> T-26-0058_Operator_2    0.87236043  2.6892875
#> T-26-0059_Operator_1    1.04775421  3.3956498
#> T-26-0059_Operator_2    1.03874805  3.3736203
#> T-26-0060_Operator_1    0.93461988  2.6292141
#> T-26-0060_Operator_2    0.97315038  2.7660483
#> T-26-0061_Operator_1    1.49947044  4.6079693
#> T-26-0061_Operator_2    1.59240855  4.7368871
#> T-26-0062_Operator_1    1.94615746  6.6733016
#> T-26-0062_Operator_2    2.00176444  7.0168582
#> T-26-0063_Operator_1    0.70409733  2.2468482
#> T-26-0063_Operator_2    0.72040147  2.2398611
#> T-26-0064_Operator_1    0.90570550  2.0421302
#> T-26-0064_Operator_2    0.94080931  2.1884567
#> T-26-0065_Operator_1    0.87995967  2.8812857
#> T-26-0065_Operator_2    0.92874863  2.9102122
#> T-26-0067_Operator_1    0.93043596  1.6071451
#> T-26-0067_Operator_2    1.02255663  1.7659190
#> T-26-0068_Operator_1    1.19853609  4.1259160
#> T-26-0068_Operator_2    1.26869179  4.2187464
#> T-26-0069_Operator_1    0.86558967  2.6553140
#> T-26-0069_Operator_2    0.88447243  2.7477265
#> T-26-0070_Operator_1    0.98532578  3.0144802
#> T-26-0070_Operator_2    1.05490236  3.0431116
#> T-26-0071_Operator_1    0.88086347  2.8643887
#> T-26-0071_Operator_2    0.90780782  2.8390204
#> T-26-0072_Operator_1    0.99095792  2.2465413
#> T-26-0072_Operator_2    1.03541889  2.3446777
#> T-26-0073_Operator_1    0.98305829  2.9215924
#> T-26-0073_Operator_2    0.97977434  2.9286063
#> T-26-0074_Operator_1    1.03864732  2.8445721
#> T-26-0074_Operator_2    1.07534459  2.9306498
#> T-26-0075_Operator_1    1.14507518  3.8286863
#> T-26-0075_Operator_2    1.32485512  3.9159532
#> T-26-0076_Operator_1    1.19933035  3.6514106
#> T-26-0076_Operator_2    1.28934391  3.6683041
#> T-26-0077_Operator_1    0.64109402  1.4798535
#> T-26-0077_Operator_2    0.72460423  1.5373085
#> T-26-0078_Operator_1    1.07916131  1.7517570
#> T-26-0078_Operator_2    1.10578879  1.8856283
#> T-26-0079_Operator_1    0.80448479  2.1296275
#> T-26-0079_Operator_2    0.78224941  2.1786610
#> T-26-0080_Operator_1    0.67221829  1.6498208
#> T-26-0080_Operator_2    0.68144450  1.7343666
#> T-26-0081_Operator_1    0.57663588  2.0594499
#> T-26-0081_Operator_2    0.61618884  2.1454370
#> T-26-0082_Operator_1    0.91004758  2.8854969
#> T-26-0082_Operator_2    0.92261717  2.8847856
#> T-26-0083_Operator_1    0.55932413  1.4254284
#> T-26-0083_Operator_2    0.57650674  1.4731171
#> T-26-0084_Operator_1    0.69300384  2.0254025
#> T-26-0084_Operator_2    0.69142606  2.0378669
#> T-26-0085_Operator_1    0.80344399  1.9696287
#> T-26-0085_Operator_2    0.82545103  2.6892875
#> T-26-0086_Operator_1    0.98054094  2.1420406
#> T-26-0086_Operator_2    0.97921177  2.3509634
#> T-26-0087_Operator_1    0.84671534  2.0895244
#> T-26-0087_Operator_2    0.82056096  2.0739657
#> T-26-0088_Operator_1    0.78696873  1.8058329
#> T-26-0088_Operator_2    0.82057768  2.6892875
#> T-26-0089_Operator_1    0.31151945  0.9462838
#> T-26-0089_Operator_2    0.31217805  1.0180950
#> T-26-0090_Operator_1    0.46499826  0.7266579
#> T-26-0090_Operator_2    0.42554710  0.7285386
#> T-26-0091_Operator_1    0.91491771  2.7065916
#> T-26-0091_Operator_2    1.00108794  2.9396444
#> T-26-0092_Operator_1    0.86242964  2.7905426
#> T-26-0092_Operator_2    0.93490388  2.8462478
#> T-26-0093_Operator_1    0.85141207  2.6579084
#> T-26-0093_Operator_2    0.85438558  2.7546495
#> T-26-0094_Operator_1    0.67282653  1.7084773
#> T-26-0094_Operator_2    0.69307110  1.8304740
#> T-26-0095_Operator_1    0.83458512  3.0876213
#> T-26-0095_Operator_2    0.80006403  3.0676959
#> T-26-0096_Operator_1    0.61503499  1.9894827
#> T-26-0096_Operator_2    0.65256182  2.0084186
#> T-26-0097_Operator_1    0.96180342  2.5495034
#> T-26-0097_Operator_2    0.96703238  2.5193426
#> T-26-0098_Operator_1    0.85450415  2.4580658
#> T-26-0098_Operator_2    0.79276981  2.5048147
#> T-26-0099_Operator_1    0.40729495  1.2417925
#> T-26-0099_Operator_2    0.42328260  1.2924933
#> T-26-0100_Operator_1    0.71411210  1.9585391
#> T-26-0100_Operator_2    0.61956915  2.6892875
#> T-26-0101_Operator_1    0.77207914  2.8471380
#> T-26-0101_Operator_2    0.82233011  2.9197267
#> T-26-0102_Operator_1    7.17720036  2.4448764
#> T-26-0102_Operator_2    0.73237071  2.4643298
#> T-26-0103_Operator_1    1.19085054  3.4684741
#> T-26-0103_Operator_2    1.07513234  3.5252356
#> T-26-0104_Operator_1    1.02580155  2.9546155
#> T-26-0104_Operator_2    0.96332047  3.0936431
#> T-26-0107_Operator_1    1.03806850  1.8771877
#> T-26-0107_Operator_2    0.87236043  2.6892875
#> T-26-0108_Operator_1    1.04895200  2.8055072
#> T-26-0108_Operator_2    0.97966313  2.9711929
#> T-26-0109_Operator_1    1.00875877  1.2746669
#> T-26-0109_Operator_2    0.85573835  1.3006195
#> T-26-0111_Operator_1    0.30359381  0.6624044
#> T-26-0111_Operator_2    0.26611091  0.6108420
#> T-26-0112-2_Operator_1  0.72739304  2.5341086
#> T-26-0112-2_Operator_2  0.71154338  2.5326900
#> T-26-0112_Operator_1    0.40937992  0.7516845
#> T-26-0112_Operator_2    0.41702433  0.8048003
#> T-26-0113_Operator_1    0.71480648  1.8336902
#> T-26-0113_Operator_2    0.74379703  1.8435405
#> T-26-0114_Operator_1    0.75893119  2.0858802
#> T-26-0114_Operator_2    1.04459895  2.2982704
#> T-26-0115_Operator_1    0.98794364  2.3051897
#> T-26-0115_Operator_2    0.73180688  1.8105997
#> T-26-0116_Operator_1    0.76697778  1.8505683
#> T-26-0116_Operator_2    0.81845000  2.2662616
#> T-26-0117_Operator_1    0.82980787  2.2834658
#> T-26-0117_Operator_2    1.00872651  2.8269347
#> T-26-0118_Operator_1    0.92580436  2.8196495
#> T-26-0118_Operator_2    0.80855984  2.2180214
#> T-26-0120_Operator_1    0.66419537  2.0108479
#> T-26-0120_Operator_2    0.69181351  1.9971281
#> T-26-0121_Operator_1    0.87236043  2.4889053
#> T-26-0121_Operator_2    0.87236043 46.2500000
#> T-26-0122_Operator_1    0.99523256  3.0324028
#> T-26-0122_Operator_2    0.94805104  3.0003691
#> T-26-0123_Operator_1    0.84531911  1.8359718
#> T-26-0123_Operator_2    0.91205363  1.9105812
#> T-26-0125_Operator_1    0.64714158  2.2002373
#> T-26-0125_Operator_2    0.62256089  2.2787559
#> T-26-0126_Operator_1    0.70140867  1.9737072
#> T-26-0126_Operator_2    0.72913926  2.0402390
#> T-26-0127_Operator_1    0.92211763  2.3774479
#> T-26-0127_Operator_2    0.92361074  2.5952002
#> T-26-0128_Operator_1    0.73475215  1.5237441
#> T-26-0128_Operator_2    0.70867070  1.5457207
#> T-26-0130_Operator_1    0.55843568  0.7953048
#> T-26-0130_Operator_2    0.59059332  0.7842463
#> T-26-0131_Operator_1    0.89738751  2.6258582
#> T-26-0131_Operator_2    0.96346128  2.6815355
#> T-26-0132_Operator_1    0.94520812  3.5100029
#> T-26-0132_Operator_2    0.96658013  3.5897979
#> T-26-0133_Operator_1    0.78771644  2.4214586
#> T-26-0133_Operator_2    0.91299852  2.4706085
#> T-26-0134_Operator_1    0.83682594  2.9771613
#> T-26-0134_Operator_2    0.87116571  2.9564417
#> T-26-0135_Operator_1    0.76549904  2.4105810
#> T-26-0135_Operator_2    0.79814605  2.4750311
#> T-26-0136_Operator_1    0.84913583  2.6508421
#> T-26-0136_Operator_2    0.89998973  2.6127350
#> T-26-0137_Operator_1    1.55955569  3.8441334
#> T-26-0137_Operator_2    1.60053499  4.1462961
#> T-26-0138_Operator_1    0.83676235  2.4000015
#> T-26-0138_Operator_2    0.88708697  2.4592981
#> T-26-0139_Operator_1    0.79587378  1.6135731
#> T-26-0139_Operator_2    0.91277777  1.7291064
#> T-26-0140_Operator_1    0.65752271  2.5026000
#> T-26-0140_Operator_2    0.73315404  2.4776456
#> T-26-0141_Operator_1    0.86299346  3.2191099
#> T-26-0141_Operator_2    0.92591179  3.2079963
#> T-26-0142_Operator_1    0.72589556  2.2281950
#> T-26-0142_Operator_2    0.74093314  2.2425744
#> T-26-0143_Operator_1    0.85360522  2.6120792
#> T-26-0143_Operator_2    0.85502843  2.6302135
#> T-26-0144_Operator_1    1.06822218  2.8988373
#> T-26-0144_Operator_2    1.16244876  3.0024063
#> T-26-0145_Operator_1    0.33999379  0.6120432
#> T-26-0145_Operator_2    0.32801951  0.6517895
#> T-26-0146_Operator_1    1.02735731  3.6745242
#> T-26-0146_Operator_2    1.08787758  3.6807453
#> T-26-0147_Operator_1    1.06700885  3.2792833
#> T-26-0147_Operator_2    1.05449177  3.2957084
#> T-26-0148_Operator_1    1.47766697  5.2675328
#> T-26-0148_Operator_2    1.53211259  5.4033873
#> T-26-0149_Operator_1    2.56939163  8.9125365
#> T-26-0149_Operator_2    2.62101820  8.7900698
#> T-26-0150_Operator_1    1.71473188  6.3131456
#> T-26-0150_Operator_2    1.68219658  6.2134242
#> T-26-0151_Operator_1    0.99324603  3.5499705
#> T-26-0151_Operator_2    1.04407626  3.5890075
#> T-26-0152_Operator_1    0.32412453  1.0854926
#> T-26-0152_Operator_2    0.32078987  1.1213906
#> T-26-0153_Operator_1    0.83055181  2.7890400
#> T-26-0153_Operator_2    0.89249282  2.8189162
#> T-26-0154_Operator_1    0.71613763  1.9667001
#> T-26-0154_Operator_2    0.73999209  1.9944878
#> T-26-0155_Operator_1    0.48613070  1.6487981
#> T-26-0155_Operator_2    0.49305395  1.6444771
#> T-26-0156_Operator_1    2.01351105  6.5074921
#> T-26-0156_Operator_2    2.12346276  6.4784613
#> T-26-0157_Operator_1    1.02697733  3.1586578
#> T-26-0157_Operator_2    1.08570917  3.0392820
#> T-26-0158_Operator_1    0.87921789  3.2281692
#> T-26-0158_Operator_2    0.92869913  3.2029995
#> T-26-0159_Operator_1    0.99386610  3.2132416
#> T-26-0159_Operator_2    0.99290579  3.1348309
#> T-26-0160_Operator_1    0.91511901  3.1518291
#> T-26-0160_Operator_2    0.96480562  3.1183684
#> T-26-0161_Operator_1    0.81319803  2.5316513
#> T-26-0161_Operator_2    0.89239574  2.5077029
#> T-26-0162_Operator_1    0.79852408  2.6361187
#> T-26-0162_Operator_2    0.83617159  2.5944157
#> T-26-0163_Operator_1    1.04668790  2.7435095
#> T-26-0163_Operator_2    1.09604410  2.7052521
#> T-26-0164_Operator_1    0.48674340  1.6430883
#> T-26-0164_Operator_2    0.50675901  1.6330442
#> T-26-0165_Operator_1    0.78956511  2.0182109
#> T-26-0165_Operator_2    0.80776941  2.0194991
#> T-26-0166_Operator_1    0.42130251  1.6089361
#> T-26-0166_Operator_2    0.44153185  1.6533006
#> T-26-0167_Operator_1    2.81640047 10.9241640
#> T-26-0167_Operator_2    2.70414424 10.4805669
#> T-26-0168_Operator_1    0.89818435  3.1844346
#> T-26-0168_Operator_2    0.86591454  3.0997330
#> T-26-0169_Operator_1    1.07451554  3.6356437
#> T-26-0169_Operator_2    2.14600361  7.1654512
#> T-26-0170_Operator_1    1.04460351  3.1696411
#> T-26-0170_Operator_2    1.21316105  3.0969766
#> T-26-0171_Operator_1    1.07362888  3.1554360
#> T-26-0171_Operator_2    1.08184235  3.2030868
#> T-26-0172_Operator_1    1.03372048  3.5798343
#> T-26-0172_Operator_2    1.06724121  3.5172135
#> T-26-0173_Operator_1    0.71169482  2.1216551
#> T-26-0173_Operator_2    0.72085019  2.1410302
#> T-26-0174_Operator_1    0.89256228  3.2518680
#> T-26-0174_Operator_2    0.95331328  3.1863202
#> T-26-0175_Operator_1    0.93288904  3.2010521
#> T-26-0175_Operator_2    0.90974780  3.0700439
#> T-26-0176_Operator_1    0.89859201  2.9762694
#> T-26-0176_Operator_2    0.87540742  2.9327261
#> T-26-0177_Operator_1    0.97971964  3.3085401
#> T-26-0177_Operator_2    0.99791806  3.3157905
#> T-26-0178_Operator_1    1.00054807  3.5868983
#> T-26-0178_Operator_2    0.99631423  3.5790157
#> T-26-0179-3_Operator_1  0.99503383  2.9464178
#> T-26-0179-3_Operator_2  0.99884489  2.9335416
#> T-26-0179_Operator_1    0.52449466  1.6627169
#> T-26-0179_Operator_2    0.52475488  1.6351626
#> T-26-0180_Operator_1    1.02320390  2.9707247
#> T-26-0180_Operator_2    1.03478927  2.9149734
#> T-26-0181_Operator_1    0.91185421  3.0396183
#> T-26-0181_Operator_2    0.88816399  2.9376842
#> T-26-0182_Operator_1    0.82648038  2.6596087
#> T-26-0182_Operator_2    0.84685720  2.6004194
#> T-26-0183_Operator_1    1.05274864  2.8606558
#> T-26-0183_Operator_2    1.08731532  2.8561641
#> T-26-0184_Operator_1    0.96129625  2.2332909
#> T-26-0184_Operator_2    1.17590252  2.1989375
#> T-26-0185_Operator_1    0.72091024  2.2312527
#> T-26-0185_Operator_2    0.77583481  2.1629098
#> T-26-0186_Operator_1    1.10623297  3.5062715
#> T-26-0186_Operator_2    1.10280140  3.5266749
#> T-26-0187_Operator_1    1.07934953  2.9902705
#> T-26-0187_Operator_2    1.06973386  2.8675641
#> T-26-0188_Operator_1    0.85374148  1.4430073
#> T-26-0188_Operator_2    0.77846076  1.4678234
#> T-26-0189_Operator_1    0.82062091  2.7096297
#> T-26-0189_Operator_2    0.80951323  2.6608072
#> T-26-0190_Operator_1    0.91803235  3.1422466
#> T-26-0190_Operator_2    0.89936654  3.0265674
#> T-26-0191_Operator_1    0.89795257  2.8681991
#> T-26-0191_Operator_2    0.90612754  2.8372637
#> T-26-0192_Operator_1    1.00645486  3.0791598
#> T-26-0192_Operator_2    1.05781244  3.0051291
#> T-26-0193_Operator_1    0.94086971  2.9338289
#> T-26-0193_Operator_2    0.90710090  2.8656576
#> T-26-0194_Operator_1    1.09882435  3.7203691
#> T-26-0194_Operator_2    1.09592021  3.6195673
#> T-26-0195_Operator_1    0.98327086  3.4557332
#> T-26-0195_Operator_2    0.95339652  3.3574004
#> T-26-0196_Operator_1    0.67871992  2.1642101
#> T-26-0196_Operator_2    0.69314556  2.1547211
#> T-26-0197_Operator_1    0.95377157  3.1698940
#> T-26-0197_Operator_2    0.90926404  3.0777669
#> T-26-0198_Operator_1    0.86595499  2.9369247
#> T-26-0198_Operator_2    0.85756604  2.7925573
#> T-26-0199_Operator_1    0.71064132  1.5896634
#> T-26-0199_Operator_2    0.68991287  1.6290135
#> T-26-0200_Operator_1    0.97413326  3.7784049
#> T-26-0200_Operator_2    1.03204377  3.7381998
#> T-26-0201_Operator_1    0.77161382  2.8315407
#> T-26-0201_Operator_2    0.77685102  2.8224485
#> T-26-0202_Operator_1    0.98025701  4.2461142
#> T-26-0202_Operator_2    1.03136434  4.0630081
#> T-26-0203_Operator_1    0.85579184  2.7530320
#> T-26-0203_Operator_2    0.84183380  2.6897598
#> T-26-0204_Operator_1    0.93416468  3.1448217
#> T-26-0204_Operator_2    1.03225450  3.1187043
#> T-26-0205_Operator_1    0.80250225  2.6000509
#> T-26-0205_Operator_2    0.82079045  2.5416547
#> T-26-0206_Operator_1    0.73031548  2.8255736
#> T-26-0206_Operator_2    0.73721903  2.8114563
#> T-26-0207_Operator_1    0.66649799  2.2322844
#> T-26-0207_Operator_2    0.66549984  2.2341607
#> T-26-0208_Operator_1    0.82795773  1.3885782
#> T-26-0208_Operator_2    0.80060172  1.4386457
#> T-26-0209_Operator_1    0.93020856  2.2393635
#> T-26-0209_Operator_2    1.01730626  2.2987996
#> T-26-0210_Operator_1    0.53442050  1.7290386
#> T-26-0210_Operator_2    0.52419719  1.7342168
#> T-26-0211_Operator_1    0.79368318  2.1989571
#> T-26-0211_Operator_2    0.80580800  2.2155026
#> T-26-0212_Operator_1    0.66074746  1.9789651
#> T-26-0212_Operator_2    0.65217452  1.9387125
#> T-26-0213_Operator_1    0.72789078  2.1905256
#> T-26-0213_Operator_2    0.71981779  2.2159798
#> T-26-0214_Operator_1    1.35413009  4.1483965
#> T-26-0214_Operator_2    1.35263088  4.1218400
#> T-26-0215_Operator_1    0.81081824  2.6951345
#> T-26-0215_Operator_2    0.84988027  2.6903156
#> T-26-0216_Operator_1    0.74986136  2.5774111
#> T-26-0216_Operator_2    0.73254584  2.5915043
#> T-26-0217_Operator_1    1.01500355  3.8429466
#> T-26-0217_Operator_2    0.97932510  3.8976176
#> T-26-0218_Operator_1    0.80892068  2.2346672
#> T-26-0218_Operator_2    0.82731315  2.1690987
#> T-26-0219_Operator_1    0.46441415  1.0109583
#> T-26-0219_Operator_2    0.46012507  1.0398407
#> T-26-0220_Operator_1    0.68539441  1.9827539
#> T-26-0220_Operator_2    0.67923439  1.9825952
#> T-26-0221_Operator_1    0.75752976  2.5002975
#> T-26-0221_Operator_2    0.78996695  2.5179755
#> T-26-0222_Operator_1    1.59030288  6.7887016
#> T-26-0222_Operator_2    1.76569455  6.9655747
#> T-26-0223_Operator_1    0.94144242  2.6305537
#> T-26-0223_Operator_2    1.03234768  2.6201501
#> T-26-0224_Operator_1    1.00638635  3.2187543
#> T-26-0224_Operator_2    0.99179287  3.1800766
#> T-26-0225_Operator_1    1.09108301  3.8509176
#> T-26-0225_Operator_2    1.05156136  3.8184733
#> T-26-0226_Operator_1    0.55160142  1.6322400
#> T-26-0226_Operator_2    0.53941361  1.6381295
#> T-26-0227_Operator_1    0.75374979  2.6367184
#> T-26-0227_Operator_2    0.76447266  2.6530645
#> T-26-0228_Operator_1    0.88323650  3.0647303
#> T-26-0228_Operator_2    0.84580115  3.0669149
#> T-26-0229_Operator_1    1.04557108  4.1205778
#> T-26-0229_Operator_2    1.03266925  4.0394089
#> T-26-0230-1_Operator_1  0.76119760  1.4825842
#> T-26-0230-1_Operator_2 17.23814286 32.9524286
#> T-26-0230-2_Operator_1  0.73992303  1.6782507
#> T-26-0230-2_Operator_2  0.71700636  1.6990649
#> T-26-0230-3_Operator_1  0.74060975  1.5735781
#> T-26-0230-3_Operator_2  0.70913449  1.5686017
#> T-26-0230-4_Operator_1  0.77268126  1.8070497
#> T-26-0230-4_Operator_2  0.80272844  1.7965344
#> T-26-0231_Operator_1    0.84996206  1.9126364
#> T-26-0231_Operator_2    0.80385593  1.8950976
#> T-26-0232_Operator_1    0.69394380  0.9091051
#> T-26-0232_Operator_2    0.66924583  0.9772442
#> T-26-0233_Operator_1    1.21970041  2.2635260
#> T-26-0233_Operator_2    0.63728291  1.2317546
#> T-26-0234_Operator_1    2.04482733  5.1096278
#> T-26-0234_Operator_2    1.98580731  5.2451098
#> T-26-0235_Operator_1    0.67917006  1.9081159
#> T-26-0235_Operator_2    0.68771589  2.0235563
#> T-26-0236_Operator_1    1.60178859  5.0011264
#> T-26-0236_Operator_2    1.61193588  5.0099427
#> T-26-0237_Operator_1    1.75216231  5.4790483
#> T-26-0237_Operator_2    1.75042833  5.4343017
#> T-26-0238_Operator_1    1.29805143  3.8671481
#> T-26-0238_Operator_2    1.28342192  3.8102989
#> T-26-0239_Operator_1    1.02196774  1.9529501
#> T-26-0239_Operator_2    0.95382131  1.9611826
#> T-26-0240_Operator_1    0.77623429  2.2115968
#> T-26-0240_Operator_2    0.75675676  2.2205722
#> T-26-0241_Operator_1    0.48496481  1.3278484
#> T-26-0241_Operator_2    0.51628988  1.3115326
#> T-26-0242_Operator_1    1.78126071  4.4602793
#> T-26-0242_Operator_2    1.69209366  4.3648338
#> T-26-0243_Operator_1    0.52592322  1.7867144
#> T-26-0243_Operator_2    0.53203871  1.6391988
#> T-26-0244_Operator_1    0.37857636  1.0212588
#> T-26-0244_Operator_2    0.39535142  1.0105534
#> T-26-0245_Operator_1    0.77335777  1.8103214
#> T-26-0245_Operator_2    0.78603004  1.8615893
#> T-26-0246_Operator_1    0.70760524  1.7531888
#> T-26-0246_Operator_2    0.65028447  1.7156355
#> T-26-0247_Operator_1    0.48913471  1.4800813
#> T-26-0247_Operator_2    0.48542480  1.2332955
#> T-26-0248_Operator_1    0.35694987  0.8958600
#> T-26-0248_Operator_2    0.31998735  0.9510795
#> T-26-0249_Operator_1    0.36892175  0.7915911
#> T-26-0249_Operator_2    0.35776455  0.7629833
#> T-26-0250_Operator_1    0.36103027  1.7867144
#> T-26-0250_Operator_2    0.36135765  1.1619087
#> T-26-0251_Operator_1    0.54840819  1.7701324
#> T-26-0251_Operator_2    0.51736990  1.7625174
#> T-26-0252_Operator_1    0.37654764  1.3572539
#> T-26-0252_Operator_2    0.38627280  1.3581170
#> T-26-0261-1_Operator_1  1.05206634  2.1585273
#> T-26-0261-1_Operator_2  1.07713044  2.2159578
#> T-26-0261-2_Operator_1  0.93903966  2.2522764
#> T-26-0261-2_Operator_2  0.91455845  2.3571911
#> T-26-0261-3_Operator_1  0.86275344  1.4535208
#> T-26-0261-3_Operator_2  0.65358051  1.5304062
#> T-26-0261-4_Operator_1  0.65763999  1.6767746
#> T-26-0261-4_Operator_2  0.60177874  1.7171569
#> T-26-0261-5_Operator_1  0.89196997  1.3477131
#> T-26-0261-5_Operator_2  0.82465753  1.4869528
#> T-26-0262-1_Operator_1  0.77017839  0.8893569
#> T-26-0262-1_Operator_2  0.76276219  0.8686862
#> T-26-0262-2_Operator_1  0.66670239  0.8426073
#> T-26-0262-2_Operator_2  0.73571823  0.9969905
#> T-26-0263_Operator_1    0.45241713  0.6934284
#> T-26-0263_Operator_2    0.45451078  0.7434583
#> T-26-0264-1_Operator_1  0.45125314  0.7930407
#> T-26-0264-1_Operator_2  0.42533335  0.8505807
#> T-26-0264-2_Operator_1  0.46454098  0.5646399
#> T-26-0264-2_Operator_2  0.44133036  0.7328010
#> T-26-0264-3_Operator_1  0.39580338  1.0584567
#> T-26-0264-3_Operator_2  0.39114438  1.0835165
#> T-26-0264-4_Operator_1  0.38940848  0.7662178
#> T-26-0264-4_Operator_2  0.39387127  0.8113735
#> T-26-0265_Operator_1    1.00000000  2.3205004
#> T-26-0265_Operator_2    1.04489391  2.4451873
#> T-26-0266_Operator_1    2.54883132  6.9647184
#> T-26-0266_Operator_2    2.54363508  7.1326607
#> T-26-0267_Operator_1    2.67815682  8.6800605
#> T-26-0267_Operator_2    2.52558216  8.7359023
#> T-26-0268_Operator_1    0.81410037  1.2806203
#> T-26-0268_Operator_2    0.74753759  1.3659381
#> T-26-0269_Operator_1    0.83385665  2.4437436
#> T-26-0269_Operator_2    0.81699593  2.4546331
#> T-26-0270-1_Operator_1  1.36288887  3.2769592
#> T-26-0270-1_Operator_2  1.31969034  3.3987308
#> T-26-0270-2_Operator_1  1.39255783  2.5969944
#> T-26-0270-2_Operator_2  1.39255035  2.8347499
#> T-26-0271_Operator_1    0.86402215  3.0574002
#> T-26-0271_Operator_2    0.85763267  3.0611648
#> T-26-0272_Operator_1    0.75447552  1.2102572
#> T-26-0272_Operator_2    0.75634144  1.2828177
#> T-26-0273_Operator_1    0.82702315  2.7111506
#> T-26-0273_Operator_2    0.85847915  2.7862445
#> T-26-0274_Operator_1    0.80159265  1.2234723
#> T-26-0274_Operator_2    0.78299754  1.3660243
#> T-26-0275_Operator_1    0.75770551  1.4072418
#> T-26-0275_Operator_2    0.79790647  1.4686380
#> T-26-0276_Operator_1    0.69495450  0.5426357
#> T-26-0276_Operator_2    0.64664237  0.6806938
#> T-26-0277_Operator_1    0.85605626  0.9903243
#> T-26-0277_Operator_2    0.79442475  1.0390353
#> T-26-0278-1_Operator_1  0.60699079  0.3225506
#> T-26-0278-1_Operator_2  0.57988149  0.2719205
#> T-26-0278-2_Operator_1  0.64430266  0.4397017
#> T-26-0278-2_Operator_2  0.63632438  0.4284270
#> T-26-0279_Operator_1    0.75473329  1.4642815
#> T-26-0279_Operator_2    0.73251748  1.4642914
```
