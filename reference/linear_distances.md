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
#>                            SL       BD HD
#> T-26-0001_Operator_1 1025.012 267.0342 NA
#> T-26-0001_Operator_2 1019.144 264.7499 NA
#> T-26-0002_Operator_1 1228.842 294.6678 NA
#> T-26-0002_Operator_2 1228.495 302.1350 NA
#> T-26-0003_Operator_1 1020.944 248.0573 NA
#> T-26-0003_Operator_2 1016.261 252.2548 NA
```
