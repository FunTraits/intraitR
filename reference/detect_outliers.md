# Detect potential digitization outliers from a GPA-aligned sample

Flags specimens whose Procrustes distance to the sample consensus shape
is unusually large, a fast, general-purpose quality-control screen for
landmark digitization errors (mislabelled points, landmarks digitized
out of order, or gross measurement mistakes), in the spirit of the
exploratory outlier screening implemented by
[`geomorph::plotOutliers()`](https://rdrr.io/pkg/geomorph/man/plotOutliers.html).

## Usage

``` r
detect_outliers(gpa, threshold = 3, plot = TRUE)

# S3 method for class 'intrait_outliers'
print(x, ...)
```

## Arguments

- gpa:

  An object of class `"intrait_gpa"` (from
  [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)).

- threshold:

  Numeric, the number of median absolute deviations (MAD) above the
  median Procrustes distance beyond which a specimen is flagged.
  Defaults to `3`. The median and MAD are used, rather than the mean and
  standard deviation, because they are themselves robust to the outliers
  being screened for.

- plot:

  Logical, draw an ordered dot plot of Procrustes distances with flagged
  specimens highlighted and the threshold marked as a dashed line.
  Defaults to `TRUE`.

- x:

  An object of class `"intrait_outliers"`, as returned by
  `detect_outliers()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_outliers"`, a list with elements
`procrustes_distance` (named numeric vector, one value per specimen),
`threshold_value` (the numeric Procrustes-distance cut-off implied by
`threshold`), `outliers` (character vector of flagged specimen names),
and `rank` (a `data.frame` with columns `specimen`,
`procrustes_distance`, `outlier`, ordered from most to least atypical).
Has a dedicated print method; if `plot = TRUE`, a base R plot is also
drawn as a side effect.

Invisibly returns `x`.

## Details

This is a coarse, univariate screen based on overall Procrustes distance
to the consensus shape, intended as a fast first pass rather than a
definitive statistical test: a genuinely unusual but correctly digitized
specimen (e.g. a naturally extreme morphology) will also be flagged,
while a digitization error affecting only a subset of landmarks in a way
that partly cancels out in the overall Procrustes distance could be
missed. Always visually inspect flagged specimens (e.g. with
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
or
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
before excluding them from downstream analyses.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)

## Examples

``` r
# real T-26 Saudrune data (see ?fishmorph_shape_landmarks for why the
# scale bar and incomplete specimens are dropped before GPA):
fish <- load_t26_saudrune_landmarks()
gpa <- gpa_fish(fishmorph_shape_landmarks(fish))
#> flag_outliers: 11 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
out <- detect_outliers(gpa, plot = FALSE)
out
#> <intrait_outliers>
#>   11 specimen(s) flagged out of 494 (threshold Procrustes distance = 0.1159)
#>   Flagged: SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055
#> 
#>   Most atypical specimen(s):
#>                              specimen procrustes_distance outlier
#>  SAUDRUNESUDTOULOUSE_20260518_0050_i1           0.1567729    TRUE
#>     SAUDRUNESUDTOULOUSE_20260518_0012           0.1499422    TRUE
#>     SAUDRUNESUDTOULOUSE_20260427_0009           0.1430509    TRUE
#>     SAUDRUNESUDTOULOUSE_20260518_0055           0.1309012    TRUE
#>  SAUDRUNESUDTOULOUSE_20260518_0039_i2           0.1275017    TRUE
```
