# Plot a morphological space

Plot a morphological space

## Usage

``` r
# S3 method for class 'intrait_morphospace'
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

  An object of class `"intrait_morphospace"`, from
  [`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md).

- style:

  Character, one of `"spider"` (default), `"hull"`, `"density"`, or
  `"none"`, controlling how groups are displayed (see Details). Ignored
  if `x$groups` is `NULL`.

- ellipse_level:

  Coverage probability of the per-group dispersion ellipse drawn when
  `style = "spider"`, under a bivariate-normal approximation. Defaults
  to `0.95`.

- density_level:

  Coverage probability of the per-group kernel-density contour drawn
  when `style = "density"` (see Details); groups with fewer than 5
  points are silently skipped (too few observations for a meaningful 2D
  density estimate). Defaults to `0.95`.

- legend:

  Logical, draw a legend of group colors. Defaults to `TRUE` when
  `x$groups` is available.

- legend_position:

  One of `"outside"` (default: drawn in the margin, just outside the
  top-right corner of the plot box, so the legend never overlaps the
  data points, at the cost of a wider right margin) or a standard
  [`graphics::legend()`](https://rdrr.io/r/graphics/legend.html)
  position keyword (e.g. `"topright"`, `"bottomleft"`) to draw it inside
  the plot box instead, as in previous versions.

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

## Details

With `style = "spider"` (the default), each group is shown as: its
individual points; dashed segments ("spider" legs) linking every point
to its group mean; the group mean itself (an asterisk); and a dispersion
ellipse of coverage `ellipse_level` around the group mean, assuming
approximate bivariate normality of the group's scores (as in
`vegan::ordiellipse()`/`car::dataEllipse()`). This mirrors the
star/spider plots commonly used to display group structure in
geometric-morphometric and functional-trait ordinations. Use
`style = "hull"` for the classical convex-hull display,
`style = "density"` for a non-parametric kernel-density contour of
coverage `density_level` around each group's mean (using the same
lightweight bivariate Gaussian-kernel estimator as
[`MASS::kde2d()`](https://rdrr.io/pkg/MASS/man/kde2d.html), without
requiring MASS itself; see Hyndman, 1996, for the highest-density-region
construction used to pick the contour threshold) — a useful alternative
to the ellipse when a group's point cloud is visibly skewed or
multimodal, since it does not assume bivariate normality — or
`style = "none"` to plot points without any group decoration.

## References

Hyndman RJ (1996). Computing and graphing highest density regions. The
American Statistician, 50(2), 120-126.
