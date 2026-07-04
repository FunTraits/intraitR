# Build a morphological space from Procrustes shape coordinates

Performs a Principal Component Analysis of Procrustes-aligned shape
coordinates to construct a morphological space ("morphospace"), the
standard ordination used to visualise and compare shape variation among
specimens, populations or species in geometric morphometrics.

## Usage

``` r
morpho_space(gpa, groups = NULL, axes = c(1, 2))

# S3 method for class 'intrait_morphospace'
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

  An object of class `"intrait_morphospace"`, as returned by
  `morpho_space()`.

- ...:

  Currently unused.

## Value

An object of class `"intrait_morphospace"`, a list with elements
`scores` (data.frame of PC scores), `sdev` (standard deviations of all
PCs), `var_explained` (percent variance explained by the two selected
axes), `rotation` (PCA loadings), `groups`, and `axes`. Has a dedicated
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
#> fishmorph_shape_landmarks(): dropping 230 specimen(s) with a missing landmark or unresolved species identification.
gpa <- gpa_fish(fish_shape)
ms <- morpho_space(gpa, groups = fish_shape$metadata$species)
ms
#> <intrait_morphospace>
#>   Axes PC1/PC2, variance explained: 83.5% / 5.0%
#>   328 specimens, 10 groups
# \donttest{
plot(ms)

# }
```
