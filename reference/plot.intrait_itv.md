# Plot the interspecific/intraspecific variance breakdown

Horizontal stacked bar chart, one bar per trait, ranked by intraspecific
variability (ITV): the trait with the highest %ITV at the top, the most
strongly species-differentiated trait at the bottom. The left margin is
sized automatically to fit whatever trait labels end up being used
(short codes or full descriptive names), so long labels are not cut off.
A bold coloured dashed reference line marks the mean (multivariate) %ITV
across all traits, labelled with its value.

## Usage

``` r
# S3 method for class 'intrait_itv'
plot(x, trait_labels = "auto", sort = TRUE, legend_position = "bottom", ...)
```

## Arguments

- x:

  An object of class `"intrait_itv"`, from
  [`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md).

- trait_labels:

  How to label each trait's bar. `"auto"` (default) expands any trait
  code recognised as one of the nine FISHMORPH ratios (see
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md))
  to its full descriptive name, e.g. `"RMl"` becomes
  `"Relative maxillary length (RMl)"`; codes not recognised (i.e. any
  other kind of trait table) are left as-is. `NULL` always uses the raw
  trait/column names unchanged. Alternatively, a named character vector
  (`names` matching `x$per_trait$trait`, values the display label to
  use) for full control over arbitrary trait sets.

- sort:

  Logical, sort bars by overall %ITV (ascending internally, so the
  highest ends up at the top of the figure) rather than plotting traits
  in their original column order. Defaults to `TRUE`.

- legend_position:

  One of `"bottom"` (default: a horizontal legend drawn just below the
  x-axis title) or a standard
  [`graphics::legend()`](https://rdrr.io/r/graphics/legend.html)
  position keyword (e.g. `"topright"`) to draw it inside the plot box
  instead.

- ...:

  Further arguments passed to
  [`graphics::barplot()`](https://rdrr.io/r/graphics/barplot.html).

## Value

Invisibly returns `x`.
