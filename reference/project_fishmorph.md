# Project specimens into the global FISHMORPH functional space

Builds a fixed functional trait space by Principal Component Analysis of
a reference database of FISHMORPH ecomorphological ratios (typically the
full FISHMORPH database of Brosse et al. 2021, ~9,000 species), then
places new specimens – e.g. the individuals of a few focal species, from
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
– into that *same, frozen* space using
[`stats::predict()`](https://rdrr.io/r/stats/predict.html), without
re-estimating the ordination. This is the standard way to show how much
of the global morphospace a group's intraspecific trait variation (ITV)
occupies relative to the entire diversity of fishes, on axes defined
once by the reference alone (so the space does not move when specimens
are added or removed, and separate studies remain comparable).

## Usage

``` r
project_fishmorph(
  specimens,
  reference = NULL,
  source = NULL,
  traits = c("REs", "VEp", "RMl", "OGp", "BEl", "BLs", "PFv", "PFs", "CPt"),
  groups = NULL,
  select_species = NULL,
  select_specimens = NULL,
  reference_prelogged = TRUE,
  specimens_prelogged = FALSE,
  log_transform = TRUE,
  scale = TRUE,
  axes = c(1, 2),
  volume_dims = 2L,
  na_action = c("omit", "fail")
)

# S3 method for class 'intrait_fishmorph_projection'
print(x, ...)
```

## Arguments

- specimens:

  A `data.frame` (e.g. from
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
  class `"intrait_fishmorph"`) with one row per specimen, containing at
  least the columns named in `traits`, and – for grouping/colouring –
  either a `species` column or a `groups` argument. Row names are used
  as specimen identifiers (for the `select_specimens` filter and for the
  returned scores).

- reference:

  The reference trait table defining the global space: either a
  `data.frame`/`matrix` with (at least) the `traits` columns, or a
  single string giving the path to a delimited file to read (a
  `;`-separated, `.`-decimal file such as the shipped
  `fishmorph_data.csv` is read with
  [`utils::read.csv2()`](https://rdrr.io/r/utils/read.table.html); a
  `,`-separated file with
  [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html)). One
  row per reference species. `NULL` (default) asks Rfishmorph for its
  bundled table – see `source` – which is the only way to guarantee that
  intraitR and Rfishmorph are looking at the same species pool. intraitR
  ships no copy of the FISHMORPH table on purpose: two copies on disk is
  exactly how the two diverge unnoticed.

- source:

  Which FISHMORPH measurement campaign to load when `reference` is
  `NULL`: `"segment"` (the published table, ratios from the eleven
  segments) or `"landmark"` (ratios recomputed from the landmark
  re-digitization, covering only the digitized species). `NULL`
  (default) follows `getOption("fishmorph.source", "segment")`, which
  [`Rfishmorph::set_fishmorph_source()`](https://rdrr.io/pkg/Rfishmorph/man/set_fishmorph_source.html)
  sets for a whole session. Requires Rfishmorph; ignored when
  `reference` is supplied.

- traits:

  Character vector of the trait columns to use, present in both
  `specimens` and `reference`. Defaults to the nine dimensionless
  FISHMORPH ratios common to
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  output and the FISHMORPH database (`"REs"`, `"VEp"`, `"RMl"`, `"OGp"`,
  `"BEl"`, `"BLs"`, `"PFv"`, `"PFs"`, `"CPt"`); the two mouth ratios
  (`MBl`, `MBw`) are excluded by default because
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  does not produce them.

- groups:

  Optional factor (or character vector), one value per row of
  `specimens`, used to colour/group the projected points. If `NULL` and
  `specimens` has a `species` column, that column is used.

- select_species:

  Optional character vector: keep only these species/groups among the
  projected specimens (matched against `groups`). `NULL` (default) keeps
  them all. Unmatched names are reported with a warning.

- select_specimens:

  Optional character vector: keep only these specimen identifiers
  (matched against `rownames(specimens)`). `NULL` (default) keeps them
  all. Combined with `select_species` by intersection (a specimen must
  satisfy both filters to be kept).

- reference_prelogged:

  Logical; is `reference` already `log10(x + 1)`-transformed? Defaults
  to `TRUE` (the state in which the FISHMORPH database is distributed).
  When `TRUE`, no log transform is applied to the reference even if
  `log_transform = TRUE`.

- specimens_prelogged:

  Logical; are the `specimens`' trait values already
  `log10(x + 1)`-transformed? Defaults to `FALSE`
  ([`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  returns raw ratios).

- log_transform:

  Logical, apply a `log10(x + 1)` transform to bring raw inputs onto the
  (log) reference scale, following
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)'s
  default preprocessing. Defaults to `TRUE`. Applied to the reference
  only if not `reference_prelogged`, and to the specimens only if not
  `specimens_prelogged`, so that both end up on the same scale exactly
  once.

- scale:

  Logical, standardise traits to unit variance inside the PCA (centring
  is always applied). Defaults to `TRUE`, matching
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md).

- axes:

  Integer vector of length 2, the ordination axes retained for the
  returned scores and plotting. Defaults to `c(1, 2)`.

- volume_dims:

  Integer, the number of leading principal components on which the
  *functional-volume* proportion (convex-hull ratio) is computed by the
  bundled
  [`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md)
  call. Independent of `axes` (which only controls the two plotted
  axes). Defaults to `2L`; a convex hull in `volume_dims` dimensions
  needs at least `volume_dims + 1` non-degenerate points, so per-species
  volumes are `NA` for species with too few specimens.

- na_action:

  Character, how to handle specimens with missing values in the `traits`
  columns (a projection cannot place a row with a missing coordinate):
  `"omit"` (default) drops them, reporting how many; `"fail"` stops with
  an error. Reference rows with missing trait values are always dropped
  (with a message) before the space is built.

- x:

  An object of class `"intrait_fishmorph_projection"`.

- ...:

  Currently unused.

## Value

An object of class
`c("intrait_fishmorph_projection", "fishmorph_projection")`, a list with
elements `scores` (data.frame of projected specimen scores on the two
axes), `global_scores` (data.frame of the reference species' own scores
on the same axes, for the background cloud), `global_species` (character
vector of the reference species labels, aligned row-for-row to
`global_scores`; from a `"Species"` column of `reference` when present,
else its row names – used by the plot method to locate the focal
species' own reference points), `groups` (factor aligned to `scores`),
`var_explained` (percent variance of the two axes), `loadings` (PCA
variable loadings), `axes`, `traits`, `n_reference` (number of reference
species used), and `pca` (the fitted
[`stats::prcomp()`](https://rdrr.io/r/stats/prcomp.html) object, so
further specimens can be projected with `predict(x$pca, ...)`). It also
carries the material used to quantify how much of the global functional
diversity the projected ITV occupies: `scores_all`/`global_scores_all`
(specimen and reference scores on *all* components), `specimen_traits`
(the transformed specimen traits, analysis scale),
`trait_ranges_reference` (per-trait reference envelope),
`reference_traits` (the full reference trait matrix on the analysis
scale, one row per reference species – used e.g. by
[`Rfishmorph::plot_fishmorph_density()`](https://rdrr.io/pkg/Rfishmorph/man/plot_fishmorph_density.html)
to draw the reference trait distributions), `volume_dims`, and
`itv_proportion` – an `"intrait_itv_proportion"` object (see
[`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md))
giving the ITV-to-global proportion per trait and per functional volume,
pooled and per species. Has a
[`print()`](https://rdrr.io/r/base/print.html) method (which adds the
ITV summary); plotting is done by
[`Rfishmorph::plot.fishmorph_projection()`](https://rdrr.io/pkg/Rfishmorph/man/plot.fishmorph_projection.html).

[`print()`](https://rdrr.io/r/base/print.html) invisibly returns `x`.

## Details

The projection itself is computed by
[`Rfishmorph::project_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/project_fishmorph.html),
which owns the FISHMORPH space and its figures; this function calls it
and adds what is specific to intraitR, the intraspecific-variability
analysis
([`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md)).
The result is therefore both an `"intrait_fishmorph_projection"` and a
`"fishmorph_projection"`: it is drawn by Rfishmorph's
[plot()](https://rdrr.io/pkg/Rfishmorph/man/plot.fishmorph_projection.html)
method,
[`Rfishmorph::plotly_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/plotly_fishmorph.html)
and
[`Rfishmorph::plot_fishmorph_density()`](https://rdrr.io/pkg/Rfishmorph/man/plot_fishmorph_density.html)
(re-exported from Rfishmorph), which show the ITV results when present.

## Scale of the reference vs the specimens

The published FISHMORPH database distributes its trait columns already
`log10(x + 1)`-transformed (verifiable against the raw measurements: a
stored body elongation of `0.888` is `log10(6.72 + 1)`, not the raw
`Bl / Bd = 6.72`), whereas
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
returns *raw* ratios. If the reference were log-transformed a second
time while the specimens were logged only once (or vice versa), the two
sets of scores would land on incompatible scales and the projected
specimens would be displaced by a large, spurious offset. The defaults
here encode the correct combination for that common case
(`reference_prelogged = TRUE`, `specimens_prelogged = FALSE`,
`log_transform = TRUE`): the reference is taken as-is and the specimens
are `log10(x + 1)`-transformed onto its scale before projection. Set
these flags explicitly if your inputs are on different scales (e.g. a
raw reference: `reference_prelogged = FALSE`).

## References

Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
Tedesco, P. A., & Villeger, S. (2021). FISHMORPH: A global database on
morphological traits of freshwater fishes. Global Ecology and
Biogeography, 30(12), 2330-2336.

## See also

[`Rfishmorph::project_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/project_fishmorph.html)
(the projection itself),
[`Rfishmorph::plot.fishmorph_projection()`](https://rdrr.io/pkg/Rfishmorph/man/plot.fishmorph_projection.html)
(the static figure and its options),
[`Rfishmorph::plotly_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/plotly_fishmorph.html)
(the same figure as an interactive widget),
[`Rfishmorph::plot_fishmorph_density()`](https://rdrr.io/pkg/Rfishmorph/man/plot_fishmorph_density.html),
[`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)

## Examples

``` r
# \donttest{
# Reference: the FISHMORPH database (a ~9,000-species CSV, not shipped with
# the package). The example runs only where that file is available locally.
ref_path <- "FishMORPH/fishmorph_data.csv"
if (file.exists(ref_path)) {
  # Focal specimens: the T-26 Saudrune individuals
  fish   <- load_t26_saudrune_landmarks()
  ratios <- fishmorph_ratios(fishmorph_segments(fish), na_action = "omit")

  proj <- project_fishmorph(ratios, reference = ref_path)
  proj

  plot(proj, style = "hull")       # ITV footprints over the density heatmap
  plot(proj, style = "spider")     # dispersion around centroids
  plot(proj, style = "points", select_species = "Squalius cephalus")

  # raw reference cloud instead of (or as well as) the heatmap:
  plot(proj, style = "hull", reference_density = FALSE, reference_points = TRUE)

  # mark each focal species' own FISHMORPH-database point:
  plot(proj, style = "hull", itv_reference = TRUE)

  # overlay the trait loadings as biplot arrows:
  plot(proj, style = "hull", arrows = TRUE)

  # the same figure, interactive (hover a point for its identity/traits):
  if (requireNamespace("plotly", quietly = TRUE)) plotly_fishmorph(proj)
}
# }
```
