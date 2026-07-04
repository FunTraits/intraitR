# Plot a functional trait space

Plot a functional trait space

## Usage

``` r
# S3 method for class 'intrait_traitspace'
plot(
  x,
  style = c("spider", "hull", "density", "none"),
  ellipse_level = 0.95,
  density_level = 0.95,
  legend = !is.null(x$groups),
  legend_position = "outside",
  legend_title = "Group",
  legend_italic = FALSE,
  abbreviate_species = FALSE,
  ...
)
```

## Arguments

- x:

  An object of class `"intrait_traitspace"`, from
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md).

- style:

  Character, one of `"spider"` (default), `"hull"`, `"density"`, or
  `"none"`, controlling how groups are displayed; see the Details
  section of
  [`plot.intrait_morphospace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_morphospace.md).
  Ignored if `x$groups` is `NULL`.

- ellipse_level:

  Coverage probability of the per-group dispersion ellipse drawn when
  `style = "spider"`, under a bivariate-normal approximation. Defaults
  to `0.95`.

- density_level:

  Coverage probability of the per-group kernel-density contour drawn
  when `style = "density"` (see Details of
  [`plot.intrait_morphospace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_morphospace.md));
  groups with fewer than 5 points are silently skipped. Defaults to
  `0.95`.

- legend:

  Logical, draw a legend of group colors. Defaults to `TRUE` when
  `x$groups` is available.

- legend_position:

  One of `"outside"` (default: drawn in the margin, just outside the
  plot box, so it never overlaps the data) or a standard
  [`graphics::legend()`](https://rdrr.io/r/graphics/legend.html)
  position keyword (e.g. `"topright"`) to draw it inside the plot box
  instead.

- legend_title:

  Character, the legend's title. Defaults to `"Group"`; set to
  `"Species"` when `x$groups` represents species identity (as it does,
  e.g., throughout `demo(pipeline_T26_saudrune)`).

- legend_italic:

  Logical, italicise the legend labels (standard typographic convention
  for taxonomic names). Defaults to `FALSE`.

- abbreviate_species:

  Logical, abbreviate `"Genus species"` legend labels to `"G. species"`
  (e.g. `"Barbatula barbatula"` becomes `"B. barbatula"`); labels that
  are not a clean two-part binomial are left unchanged. Only affects the
  legend text. Defaults to `FALSE`.

- ...:

  Further arguments passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Value

Invisibly returns `x`.

## Examples

``` r
# \donttest{
fish <- load_t26_saudrune_landmarks()
segments <- fishmorph_segments(fish)
#> Warning: 3 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA.
ratios <- fishmorph_ratios(segments)
ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 230 row(s) out of 558 with missing values.
#> flag_outliers: 21 specimen(s) flagged as within-group outlier(s) across 5 group(s) (Barbatula barbatula, Gobio occitaniae, Leuciscus burdigalensis, Phoxinus phoxinus/bigerri, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 2 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
# species-flavoured legend: titled "Species", italic, abbreviated binomials
plot(ts, legend_title = "Species", legend_italic = TRUE, abbreviate_species = TRUE)

# }
```
