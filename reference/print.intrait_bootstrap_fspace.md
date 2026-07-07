# Print and plot an `"intrait_bootstrap_fspace"` object

`plot(type = "pool")` (the default) draws a histogram of the
whole-species-pool bootstrap distribution (`fd_boot`), with `fd_ref`
(centroid-based reference) marked by a dashed red line and
`fd_boot_mean` (the bootstrap mean) by a dashed blue line; both values
are printed directly on the x-axis, in matching colour, rather than in a
separate text annotation. `plot(type = "communities")` instead draws a
dot ("forest") plot of the per-community Standardized Effect Size
(`x$communities$ses`), one row per community, coloured by whether that
community's `p_value` falls below `alpha` – only available when `x` was
built with a `composition` matrix (see
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)).

## Usage

``` r
# S3 method for class 'intrait_bootstrap_fspace'
print(x, ...)

# S3 method for class 'intrait_bootstrap_fspace'
plot(x, type = c("pool", "communities"), alpha = 0.05, order = TRUE, ...)
```

## Arguments

- x:

  An object of class `"intrait_bootstrap_fspace"`, as returned by
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md).

- ...:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), further
  arguments passed to
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html)
  (`type = "pool"`) or
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html)
  (`type = "communities"`); currently unused by
  [`print()`](https://rdrr.io/r/base/print.html).

- type:

  Character, `"pool"` (default) for the whole-species-pool histogram, or
  `"communities"` for the per-community SES dot plot (requires
  `x$communities`, i.e. `composition` was supplied to
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)).

- alpha:

  Numeric, the significance threshold used only by
  `type = "communities"` to colour communities by `p_value < alpha`.
  Defaults to `0.05`.

- order:

  Logical, for `type = "communities"` only: sort communities by
  increasing `ses` (`TRUE`, default) rather than keeping `composition`'s
  original row order.

## Value

Invisibly returns `x` (`type = "pool"`), or the (possibly reordered,
NA-dropped) `x$communities` data.frame actually plotted
(`type = "communities"`).

Invisibly returns `x`.
