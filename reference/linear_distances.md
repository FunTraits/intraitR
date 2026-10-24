# Compute inter-landmark linear distances

Computes Euclidean distances between user-defined pairs of landmarks
(e.g. a truss network, Strauss & Bookstein, 1982) on raw, un-aligned
landmark coordinates, optionally converted to real-world units using a
digitization scale.

## Usage

``` r
linear_distances(landmarks, pairs, scale = NULL)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` or `"intrait_gpa"`, or a raw
  `p x k x n` landmark array. Note: distances are normally computed on
  **raw** (pre-Procrustes) coordinates, since Generalised Procrustes
  Analysis removes size information; passing an `"intrait_gpa"` object
  will return distances in the arbitrary unit-centroid-size scale of the
  Procrustes fit.

- pairs:

  A (optionally named) list of length-2 integer vectors, each giving the
  indices of two landmarks whose distance should be computed. List names
  become the trait names in the output (e.g.
  `list(SL = c(1, 2), BD = c(3, 4))`).

- scale:

  Optional numeric vector of scale factors (real-world units per
  coordinate unit), one per specimen and named to match specimen
  identifiers. If `NULL` and `landmarks` is an `"intrait_landmarks"`
  object with a non-missing `scale` element, that scale is used
  automatically.

## Value

A `data.frame` with one row per specimen (row names = specimen
identifiers) and one column per entry in `pairs`.

## See also

[`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md),
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)

## Examples

``` r
# real T-26 Saudrune data; landmark indices follow the FISHMORPH scheme
# (see ?fishmorph_segments), so these pairs are anatomically meaningful.
# `fish$scale` is not set, so distances stay in raw digitization units
# here; use fishmorph_segments() instead for measurements already
# converted to centimetres via the embedded scale bar (points 20-21):
fish <- load_t26_saudrune_landmarks()
pairs <- list(SL = c(1, 2), BD = c(3, 4), HD = c(5, 6))
head(linear_distances(fish, pairs))
#>                                          SL       BD       HD
#> SAUDRUNESUDTOULOUSE_20260427_0001 1027.0085 266.1601 140.3284
#> SAUDRUNESUDTOULOUSE_20260427_0002 1249.6162 300.2998 165.5497
#> SAUDRUNESUDTOULOUSE_20260427_0003 1045.9472 252.3055 147.0438
#> SAUDRUNESUDTOULOUSE_20260427_0004 2676.8360 673.7648 290.4404
#> SAUDRUNESUDTOULOUSE_20260427_0005  824.3423 178.1926 117.4385
#> SAUDRUNESUDTOULOUSE_20260427_0006 1131.5148 281.1218 167.4464
```
