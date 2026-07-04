# Compute classical fish morphometric ratios

Derives size-corrected morphological ratios from raw landmark
coordinates by dividing a set of inter-landmark distances by a chosen
normalising distance (typically standard length). Ratios of this kind
are widely used in fish ecomorphology to relate body shape to ecological
function (e.g. body depth ratio as a proxy for swimming performance, eye
diameter ratio for visual ecology; Winemiller, 1991; Pease et al.,
2012).

## Usage

``` r
morpho_ratios(landmarks, distances, norm_by, scale = NULL, digits = 4)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` or a raw `p x k x n` landmark
  array (raw, un-aligned coordinates; see
  [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)).

- distances:

  A named list of length-2 landmark index vectors, passed to
  [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)
  (e.g. `list(SL = c(1, 2), BD = c(3, 4), ED = c(13, 14))` for
  FISHMORPH-scheme landmarks; see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).
  Must include the normalising distance named in `norm_by`.

- norm_by:

  Character. Name of the entry in `distances` used as the denominator
  for all other distances (typically standard length, `"SL"`).

- scale:

  Optional named numeric vector of scale factors, as in
  [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md).

- digits:

  Integer, number of decimal places to round ratios to. Defaults to `4`.

## Value

A `data.frame` with one row per specimen, columns `<name>_ratio` for
every entry in `distances` other than `norm_by`, and any metadata
columns carried over from `landmarks` (if present).

## Details

Ratios are dimensionless and therefore comparable across specimens
irrespective of the digitization scale, provided the same unit is used
for numerator and denominator; as a result, `scale` only needs to be
supplied if all distances are to also be reported at their original
(unscaled) magnitude via
[`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)
beforehand, or if specimens were digitized at different magnifications,
in which case the scale must be supplied to keep ratios strictly
comparable.

## References

Winemiller KO (1991). Ecomorphological diversification in lowland
freshwater fish assemblages from five biotic regions. Ecological
Monographs, 61(4), 343-365.

Pease AA, Gonzalez-Diaz AA, Rodiles-Hernandez R, Winemiller KO (2012).
Functional diversity and trait-environment relationships of stream fish
assemblages in a large tropical catchment. Freshwater Biology, 57(5),
1060-1075.

## See also

[`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md),
[`summary_traits()`](https://funtraits.github.io/intraitR/reference/summary_traits.md)

## Examples

``` r
# real T-26 Saudrune data; landmark indices follow the FISHMORPH scheme
# (see ?fishmorph_segments)
fish <- load_t26_saudrune_landmarks()
distances <- list(SL = c(1, 2), BD = c(3, 4), ED = c(13, 14))
head(morpho_ratios(fish, distances, norm_by = "SL"))
#>                                  specimen individual          species
#> T-26-0001_Operator_1 T-26-0001_Operator_1  T-26-0001 Gobio occitaniae
#> T-26-0001_Operator_2 T-26-0001_Operator_2  T-26-0001 Gobio occitaniae
#> T-26-0002_Operator_1 T-26-0002_Operator_1  T-26-0002 Gobio occitaniae
#> T-26-0002_Operator_2 T-26-0002_Operator_2  T-26-0002 Gobio occitaniae
#> T-26-0003_Operator_1 T-26-0003_Operator_1  T-26-0003 Gobio occitaniae
#> T-26-0003_Operator_2 T-26-0003_Operator_2  T-26-0003 Gobio occitaniae
#>                      population replicate   operator BD_ratio ED_ratio
#> T-26-0001_Operator_1       <NA>         1 Operator_1   0.2605   0.0507
#> T-26-0001_Operator_2       <NA>         2 Operator_2   0.2598   0.0486
#> T-26-0002_Operator_1       <NA>         1 Operator_1   0.2398   0.0461
#> T-26-0002_Operator_2       <NA>         2 Operator_2   0.2459   0.0419
#> T-26-0003_Operator_1       <NA>         1 Operator_1   0.2430   0.0524
#> T-26-0003_Operator_2       <NA>         2 Operator_2   0.2482   0.0485
```
