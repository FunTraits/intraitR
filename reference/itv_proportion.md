# Proportion of the global functional diversity captured by projected ITV

Quantifies how much of the entire (global) functional diversity of the
reference database a group's projected intraspecific trait variation
(ITV) actually occupies, from an
[`project_fishmorph()`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md)
projection, along two complementary decompositions:

## Usage

``` r
itv_proportion(
  x,
  volume_dims = NULL,
  metric = c("hull", "tpd"),
  tpd_alpha = 0.99,
  tpd_n_divisions = NULL,
  ...
)

# S3 method for class 'intrait_fishmorph_projection'
itv_proportion(
  x,
  volume_dims = NULL,
  metric = c("hull", "tpd"),
  tpd_alpha = 0.99,
  tpd_n_divisions = NULL,
  ...
)

# S3 method for class 'intrait_itv_proportion'
print(x, digits = 3, ...)
```

## Arguments

- x:

  An object of class `"intrait_itv_proportion"`, from
  `itv_proportion()`.

- volume_dims:

  Integer, the number of leading principal components used for the
  functional-volume (convex-hull) proportion. Defaults to the value
  stored on `x` (from
  [`project_fishmorph()`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md)'s
  own `volume_dims`, itself `2L` by default). A convex hull in
  `volume_dims` dimensions needs at least `volume_dims + 1` affinely
  independent points, so a species with fewer specimens yields `NA`.

- metric:

  Character, the multivariate functional-volume measure: `"hull"`
  (default) for the convex-hull volume, or `"tpd"` for the density-based
  Trait Probability Density FRichness (see Details). `"tpd"` requires
  the Suggested 'TPD' package. The per-trait range proportions are
  identical under either choice.

- tpd_alpha:

  Numeric in `(0, 1]`, used only when `metric = "tpd"`: the density
  quantile threshold passed to
  [`TPD::TPDs()`](https://rdrr.io/pkg/TPD/man/TPDs.html) (the fraction
  of the probability mass retained; the sparsest `1 - tpd_alpha` tail is
  trimmed before the occupied volume is measured). Defaults to `0.99`.

- tpd_n_divisions:

  Integer or `NULL`, used only when `metric = "tpd"`: the number of
  evaluation-grid divisions per axis (shared across all units). `NULL`
  (default) picks a value that keeps the grid tractable as `volume_dims`
  grows (`50` per axis in 2-D).

- ...:

  Currently unused.

- digits:

  Integer, significant digits for the printed proportions. Defaults to
  `3`.

## Value

An object of class `"intrait_itv_proportion"`, a list with:

- `trait`:

  a `data.frame`, one row per trait, with `trait`, `global_range`,
  `itv_range_pooled` (range over all focal specimens), and
  `proportion_pooled` (`itv_range_pooled / global_range`).

- `trait_species`:

  a long `data.frame` with `species`, `trait`, `n` (specimens of that
  species), `itv_range`, and `proportion` (per-species trait-range
  proportion).

- `volume`:

  a `data.frame`, one row for the pooled focal set
  (`group = "(all focal species)"`) then one per species, with `group`,
  `n`, `volume` (the functional volume in `volume_dims` dimensions –
  convex-hull volume when `metric = "hull"`, TPD FRichness when
  `metric = "tpd"`), and `proportion` (`volume / global_volume`).

- `global_volume`:

  the reference functional volume in `volume_dims` dimensions (same
  metric as `volume`).

- `volume_dims`:

  the number of dimensions used.

- `metric`:

  the functional-volume metric used (`"hull"` or `"tpd"`).

- `scale`, `volume_scale`:

  character notes on the scale of the per-trait ranges and on the
  functional-volume metric.

Has a dedicated [`print()`](https://rdrr.io/r/base/print.html) method.

Invisibly returns `x`.

## Details

- **per trait** – univariate functional diversity is taken as the trait
  *range* (the one-dimensional convex hull; Villeger, Mason & Mouillot,
  2008). For each trait the proportion is the range spanned by the focal
  specimens divided by the range spanned by the whole reference, on the
  analysis scale (the `log10(x + 1)` scale when `log_transform` was used
  to build the projection). A value of `0.10` means the focal ITV
  spreads across a tenth of the global variation in that trait.

- **per functional volume** – multivariate functional richness in the
  `volume_dims` leading principal components of the frozen global space,
  computed by one of two `metric`s and expressed as the ITV volume
  divided by the reference volume:

  - `metric = "hull"` (default): the **convex-hull** volume (Villeger,
    Mason & Mouillot, 2008), via
    [`geometry::convhulln()`](https://rdrr.io/pkg/geometry/man/convhulln.html).
    An *extent*-based richness – driven by the outermost specimens only,
    so a handful of dispersed individuals can enclose a large fraction
    of the reference hull even when the bulk of the reference is
    concentrated elsewhere.

  - `metric = "tpd"`: the **Trait Probability Density FRichness**
    (Carmona et al. 2016, 2019), via
    [`TPD::TPDs()`](https://rdrr.io/pkg/TPD/man/TPDs.html)/[`TPD::TPDc()`](https://rdrr.io/pkg/TPD/man/TPDc.html)/[`TPD::REND()`](https://rdrr.io/pkg/TPD/man/REND.html).
    A *density*-based richness that estimates a kernel density from the
    individuals and measures the volume of trait space it occupies above
    an `tpd_alpha`-quantile density threshold, so sparse outliers are
    down-weighted rather than allowed to stretch the volume. Every unit
    (the reference, the pooled focal set, each species) is evaluated on
    the *same* fixed grid, keeping the volumes comparable. Typically
    yields a much smaller, more conservative proportion than the convex
    hull for a centrally-clustered focal set. Requires the Suggested
    'TPD' package.

Both decompositions are reported pooled over all focal specimens (the
total footprint of the focal set) and separately for each species. The
per-trait (range) decomposition is unaffected by `metric`.

## References

Villeger, S., Mason, N. W. H., & Mouillot, D. (2008). New
multidimensional functional diversity indices for a multifaceted
framework in functional ecology. Ecology, 89(8), 2290-2301.

Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2016). Traits
without borders: integrating functional diversity across scales. Trends
in Ecology & Evolution, 31(5), 382-394.

Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2019). Trait
probability density (TPD): measuring functional diversity across scales
based on TPD with R. Ecology, 100(12), e02876.

Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
Tedesco, P. A., & Villeger, S. (2021). FISHMORPH: A global database on
morphological traits of freshwater fishes. Global Ecology and
Biogeography, 30(11), 2330-2336.

## See also

[`project_fishmorph()`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md),
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)

## Examples

``` r
# \donttest{
# Needs the full FISHMORPH database (a ~9,000-species CSV) as `reference`;
# this file is not shipped with the package, so the example runs only when it
# is available locally (adjust the path to your own copy).
ref_path <- "FishMORPH/fishmorph_data.csv"
if (file.exists(ref_path)) {
  fish   <- load_t26_saudrune_landmarks()
  ratios <- fishmorph_ratios(fishmorph_segments(fish), na_action = "omit")
  proj   <- project_fishmorph(ratios, reference = ref_path)

  # project_fishmorph() already bundles the default (volume_dims = 2) result:
  proj$itv_proportion

  # recompute on a different number of axes:
  itv_proportion(proj, volume_dims = 3)

  # density-based (TPD) functional richness instead of the convex hull:
  if (requireNamespace("TPD", quietly = TRUE)) itv_proportion(proj, metric = "tpd")
}
# }
```
