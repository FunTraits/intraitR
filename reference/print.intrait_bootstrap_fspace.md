# Print and plot an `"intrait_bootstrap_fspace"` object

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws a
histogram of the bootstrap distribution (`fd_boot`), with `fd_ref`
(centroid-based reference) marked by a dashed red line and
`fd_boot_mean` (the bootstrap mean) by a dashed blue line; both values
are printed directly on the x-axis, in matching colour, rather than in a
separate text annotation.

## Usage

``` r
# S3 method for class 'intrait_bootstrap_fspace'
print(x, ...)

# S3 method for class 'intrait_bootstrap_fspace'
plot(x, ...)
```

## Arguments

- x:

  An object of class `"intrait_bootstrap_fspace"`, as returned by
  [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md).

- ...:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), further
  arguments passed to
  [`graphics::hist()`](https://rdrr.io/r/graphics/hist.html); currently
  unused by [`print()`](https://rdrr.io/r/base/print.html).

## Value

Invisibly returns `x`.

Invisibly returns `x`.
