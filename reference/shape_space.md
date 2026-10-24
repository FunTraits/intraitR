# Build a shape space from Procrustes shape coordinates

Performs a Principal Component Analysis of Procrustes-aligned shape
coordinates to construct a shape space, the standard ordination used to
visualise and compare shape variation among specimens, populations or
species in geometric morphometrics.

## Usage

``` r
shape_space(gpa, groups = NULL, axes = c(1, 2))

# S3 method for class 'intrait_shapespace'
print(x, ...)
```

## Arguments

- gpa:

  An object of class `"intrait_gpa"`, as returned by
  [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md).

- groups:

  Optional factor (or character vector), one value per specimen in the
  same order as `dimnames(gpa$coords)[[3]]`, used to colour/group
  specimens when plotting. If `NULL` and `gpa$metadata` contains a
  `species` column, it is used automatically.

- axes:

  Integer vector of length 2, the principal components to retain for
  plotting (defaults to `c(1, 2)`).

- x:

  An object of class `"intrait_shapespace"`, as returned by
  `shape_space()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_shapespace"`, a list with elements `scores`
(data.frame of PC scores), `sdev` (standard deviations of all PCs),
`var_explained` (percent variance explained by the two selected axes),
`rotation` (PCA loadings), `groups`, and `axes`. Has a dedicated
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method.

Invisibly returns `x`.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)

## Examples

``` r
# real T-26 Saudrune data (see ?fishmorph_shape_landmarks for why the
# scale bar and incomplete/unidentified specimens are dropped first):
fish <- load_t26_saudrune_landmarks()
fish_shape <- fishmorph_shape_landmarks(fish)
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 11 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
ms <- shape_space(gpa, groups = fish_shape$metadata$species)
ms
#> <intrait_shapespace>
#>   Axes PC1/PC2, variance explained: 24.8% / 17.3%
#>   494 specimens, 7 groups
# \donttest{
plot(ms)

# }
```
