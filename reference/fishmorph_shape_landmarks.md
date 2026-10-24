# Extract complete-case body-shape landmarks from a FISHMORPH configuration

Prepares a FISHMORPH-scheme `"intrait_landmarks"` object (21+ points;
see
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md))
for Generalised Procrustes Analysis
([`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md))
or any other function that expects a single, complete set of homologous
shape landmarks. Two adjustments are needed before such a configuration
can be treated as pure shape data, and this function applies both at
once: the embedded scale bar (landmarks 20-21) is dropped, since it is a
fixed calibration segment rather than a body landmark and mixing it into
a Procrustes superimposition (which treats every point as part of the
shape) would distort the alignment; and, by default, any specimen
missing one or more of the remaining landmarks (or with a
missing/unresolved species identification, if `species` is supplied) is
dropped, since GPA requires complete configurations.

## Usage

``` r
fishmorph_shape_landmarks(landmarks, species = NULL, drop_incomplete = TRUE)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` with at least the 21
  FISHMORPH landmarks (see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).

- species:

  Optional character vector (or factor), one value per specimen, used
  only to additionally drop specimens with a missing (`NA`) value – e.g.
  an unresolved identification – so that a downstream grouped analysis
  ([`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md),
  [`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md),
  [`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md))
  never encounters an `NA` group. Defaults to
  `landmarks$metadata$species` if present, otherwise `NULL` (no
  filtering on species).

- drop_incomplete:

  Logical, drop specimens missing one or more of landmarks 1-19 (plus
  22, if present). Defaults to `TRUE`; set to `FALSE` to keep every
  specimen and inspect missingness yourself (e.g. via
  [`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)
  instead of dropping).

## Value

An object of the same class as `landmarks`, with landmarks 20-21 removed
and, if `drop_incomplete`, incomplete/unidentified specimens removed
from `coords`, `metadata`, and `scale` alike.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
fish_shape <- fishmorph_shape_landmarks(fish)
dim(fish$coords)
#> [1]  25   2 494
dim(fish_shape$coords)
#> [1]  20   2 494
gpa <- gpa_fish(fish_shape)
#> flag_outliers: 11 specimen(s) flagged as potential Procrustes-distance outlier(s) (threshold = median + 3.0 x MAD): SAUDRUNESUDTOULOUSE_20260427_0009, SAUDRUNESUDTOULOUSE_20260518_0012, SAUDRUNESUDTOULOUSE_20260518_0015, SAUDRUNESUDTOULOUSE_20260518_0017, SAUDRUNESUDTOULOUSE_20260518_0024, SAUDRUNESUDTOULOUSE_20260518_0030, SAUDRUNESUDTOULOUSE_20260518_0036, SAUDRUNESUDTOULOUSE_20260518_0039_i2, SAUDRUNESUDTOULOUSE_20260518_0044, SAUDRUNESUDTOULOUSE_20260518_0050_i1, SAUDRUNESUDTOULOUSE_20260518_0055; this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them and re-align, or see $outlier_screen for details.
gpa
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   494 specimens, 20 landmarks, 2 dimensions
#>   Converged in 3 iteration(s)
#>   Centroid size: mean = 2159.321, range = [316.008, 7576.064]
#>   11 potential Procrustes-distance outlier(s) flagged (see $outlier_screen); most atypical:
#>     SAUDRUNESUDTOULOUSE_20260518_0050_i1: distance = 0.1568 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260518_0012: distance = 0.1499 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260427_0009: distance = 0.1431 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260518_0055: distance = 0.1309 (threshold 0.1159)
#>     SAUDRUNESUDTOULOUSE_20260518_0039_i2: distance = 0.1275 (threshold 0.1159)
```
