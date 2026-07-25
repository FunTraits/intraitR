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

Draws the reference database as a background layer – by default a
kernel-density heatmap of the whole FISHMORPH morphospace – with the
projected specimens on top of it, grouped/coloured by species, in any of
the display styles shared with
[`plot.intrait_traitspace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_traitspace.md).
The background can equivalently (or additionally) be shown as the raw
reference point cloud, and the focal species' own positions *in the
reference database* can be marked, to see how a group's projected
intraspecific trait variation (ITV) sits relative to its single database
point.

## Usage

``` r
project_fishmorph(
  specimens,
  reference,
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

# S3 method for class 'intrait_fishmorph_projection'
plot(
  x,
  style = c("hull", "spider", "density", "points"),
  reference_density = TRUE,
  reference_points = FALSE,
  itv_reference = FALSE,
  arrows = FALSE,
  arrow_scale = 0.8,
  arrow_col = "grey20",
  background = TRUE,
  background_col = "grey75",
  density_probs = c(0.25, 0.5, 0.99),
  density_palette = NULL,
  select_species = NULL,
  select_specimens = NULL,
  ellipse_level = 0.95,
  density_level = 0.95,
  legend = TRUE,
  legend_position = "outside",
  legend_title = "Species",
  legend_italic = TRUE,
  abbreviate_species = TRUE,
  ...
)
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
  row per reference species.

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

  Further arguments passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html)
  (for the [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  method) or currently unused (for
  [`print()`](https://rdrr.io/r/base/print.html)).

- style:

  Character, one of `"hull"` (default; per-species convex hull = the ITV
  footprint), `"spider"` (dispersion ellipse + spokes to the centroid),
  `"density"` (per-species kernel-density contour of the projected
  specimens), or `"points"` (the projected points only, no per-group
  geometry). Note this is the *foreground* per-species geometry and is
  independent of `reference_density`, which controls the *background*
  reference heatmap.

- reference_density:

  Logical, draw the reference database's distribution as a filled
  kernel-density heatmap (a white-to-red gradient with a few nested
  highest-density-region contour lines) behind the projected specimens –
  the recommended way to show a ~9,000-species morphospace, which is
  unreadable as raw points. Defaults to `TRUE`.

- reference_points:

  Logical, draw the reference database species as a light background
  point cloud (the previous default display). Can be combined with
  `reference_density`. Defaults to `FALSE`.

- itv_reference:

  Logical, mark the focal species' *own* entries in the reference
  database – i.e. the FISHMORPH points of exactly the species for which
  projected ITV is shown – as filled circles coloured to match their
  species, so the single database morphotype can be compared with the
  spread of the projected individuals. Requires the projection to carry
  reference species labels (`x$global_species`, added by
  `project_fishmorph()`); species with no matching reference row are
  skipped with a warning. Defaults to `FALSE`.

- arrows:

  Logical, overlay the trait *loadings* (the PCA variable contributions
  stored in `x$loadings`) as a biplot: one arrow per trait, drawn from
  the origin in the direction of that trait's loading on the two plotted
  axes, with the trait name at the arrow tip. This turns the score plot
  into a standard PCA biplot, showing which morphological ratios drive
  each axis and hence how a group's position in the morphospace should
  be read ecomorphologically (e.g. an ITV footprint stretched along the
  body-elongation arrow varies mostly in body shape). The arrows are a
  purely visual overlay and do not change the ordination. Defaults to
  `FALSE`.

- arrow_scale:

  Numeric in `(0, 1]`, how far the longest loading arrow reaches, as a
  fraction of the distance from the origin to the nearest plot edge; all
  arrows are scaled by this same factor so their relative lengths and
  directions are preserved. Loadings are unit-scaled vectors with no
  natural size in score units, so this is a display choice only. Smaller
  values keep the arrows clear of the outer points; larger values make
  short loadings more legible. Only used when `arrows = TRUE`. Defaults
  to `0.8`.

- arrow_col:

  Colour of the loading arrows and their trait labels (when
  `arrows = TRUE`). Defaults to `"grey20"`.

- background:

  Logical master switch: when `FALSE`, no reference background layer of
  any kind is drawn (overrides `reference_density`, `reference_points`
  and `itv_reference`). Defaults to `TRUE`.

- background_col:

  Colour of the reference point cloud (when `reference_points = TRUE`).
  Defaults to `"grey75"`.

- density_probs:

  Numeric vector of coverage probabilities for the reference heatmap's
  highest-density-region contour lines. Defaults to
  `c(0.25, 0.5, 0.99)`.

- density_palette:

  Optional character vector of colours for the reference heatmap
  gradient (low to high density). `NULL` (default) uses a
  white-to-dark-red ColorBrewer YlOrRd ramp.

- ellipse_level, density_level:

  Coverage probabilities for the `"spider"` ellipse and `"density"`
  contour respectively. Default `0.95`.

- legend:

  Logical, draw a species legend. Defaults to `TRUE`.

- legend_position, legend_title, legend_italic, abbreviate_species:

  Legend controls, as in
  [`plot.intrait_traitspace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_traitspace.md);
  defaults here are tuned for species names (`legend_title = "Species"`,
  italic, abbreviated binomials).

## Value

An object of class `"intrait_fishmorph_projection"`, a list with
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
[`plot_fishmorph_density()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_density.md)
to draw the reference trait distributions), `volume_dims`, and
`itv_proportion` – an `"intrait_itv_proportion"` object (see
[`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md))
giving the ITV-to-global proportion per trait and per functional volume,
pooled and per species. Has dedicated
[`print()`](https://rdrr.io/r/base/print.html) and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

[`print()`](https://rdrr.io/r/base/print.html) invisibly returns `x`.

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) invisibly
returns `x`.

## Details

In the [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method,
`select_species`/`select_specimens` restrict *this plot* to a subset of
the already-projected species or specimen identifiers, without
recomputing the space (the reference background is unchanged); `NULL`
(default) plots everything projected. When `itv_reference = TRUE`, the
reference points marked follow the same selection: only the focal
species still shown after `select_species`/`select_specimens` are
matched against the reference database (matching is case-insensitive and
treats spaces and underscores as equivalent, so `"Squalius cephalus"`
and `"Squalius_cephalus"` match).

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
Biogeography, 30(11), 2330-2336.

## See also

[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
`plot.intrait_fishmorph_projection()`

## Examples

``` r
# \donttest{
# Focal specimens: the T-26 Saudrune individuals
fish     <- load_t26_saudrune_landmarks()
ratios   <- fishmorph_ratios(fishmorph_segments(fish), na_action = "omit")
#> Warning: 23 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
#> na_action = "omit": removing 293 row(s) out of 1036 with missing values.

# Reference: the FISHMORPH database (here, a path to fishmorph_data.csv)
proj <- project_fishmorph(ratios, reference = "FishMORPH/fishmorph_data.csv")
#> Error: `reference` file does not exist: FishMORPH/fishmorph_data.csv
proj
#> function (object, ...) 
#> UseMethod("proj")
#> <bytecode: 0x5617534bb298>
#> <environment: namespace:stats>

plot(proj, style = "hull")                       # ITV footprints over the
#> Error in object$qr: $ operator is invalid for atomic vectors
                                                 # reference density heatmap
plot(proj, style = "spider")                     # dispersion around centroids
#> Error in object$qr: $ operator is invalid for atomic vectors
plot(proj, style = "points",                     # just the projected points
     select_species = "Squalius cephalus")
#> Error in object$qr: $ operator is invalid for atomic vectors

# show the raw reference cloud instead of (or as well as) the heatmap:
plot(proj, style = "hull", reference_density = FALSE, reference_points = TRUE)
#> Error in object$qr: $ operator is invalid for atomic vectors

# mark each focal species' own FISHMORPH-database point, to compare the
# single database morphotype with the spread of projected individuals:
plot(proj, style = "hull", itv_reference = TRUE)
#> Error in object$qr: $ operator is invalid for atomic vectors

# overlay the trait loadings as biplot arrows, to read which ratios drive
# each axis:
plot(proj, style = "hull", arrows = TRUE)
#> Error in object$qr: $ operator is invalid for atomic vectors
# }
```
