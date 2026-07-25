# Plot functional-diversity rarefaction curves

One panel per index: the resampling mean against sampling effort (with
the quantile band as a shaded envelope), the stabilisation effort `n*`
as a vertical dashed line, and – for the accumulation index – the fitted
asymptote (dotted) with its dashed extrapolation, or – for convergence
indices – a dotted reference line at the full-effort value.

## Usage

``` r
# S3 method for class 'intrait_fd_accumulation'
plot(x, indices = NULL, band = TRUE, extrapolate = TRUE, ...)
```

## Arguments

- x:

  An object of class `"intrait_fd_accumulation"`.

- indices:

  Optional character vector selecting which indices to draw.

- band:

  Logical, draw the resampling band. Defaults to `TRUE`.

- extrapolate:

  Logical, extend the fitted accumulation curve to `n*`. Defaults to
  `TRUE`.

- ...:

  Passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html).

## Value

Invisibly returns `x`.
