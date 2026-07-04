# Plot the interspecific/intraspecific variance breakdown

Plot the interspecific/intraspecific variance breakdown

## Usage

``` r
# S3 method for class 'intrait_itv'
plot(x, legend_position = "outside", ...)
```

## Arguments

- x:

  An object of class `"intrait_itv"`, from
  [`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md).

- legend_position:

  One of `"outside"` (default: drawn in the margin, just outside the
  top-right corner of the plot box, so it never overlaps the tallest
  bars) or a standard
  [`graphics::legend()`](https://rdrr.io/r/graphics/legend.html)
  position keyword (e.g. `"topright"`) to draw it inside the plot box
  instead, as in previous versions.

- ...:

  Further arguments passed to
  [`graphics::barplot()`](https://rdrr.io/r/graphics/barplot.html).

## Value

Invisibly returns `x`.
