# Print and plot an `"intrait_richness_comparison"` object

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws a
dot-and-whisker comparison, one row per method that succeeded: the dot
is `pct_diff` (bootstrap mean vs. centroid reference, as a % change),
the whiskers span the bootstrap 5-95% interval on the same relative
scale, and colour marks whether `p_value < alpha`.

## Usage

``` r
# S3 method for class 'intrait_richness_comparison'
print(x, ...)

# S3 method for class 'intrait_richness_comparison'
plot(x, ...)
```

## Arguments

- x:

  An object of class `"intrait_richness_comparison"`, as returned by
  [`compare_functional_richness()`](https://funtraits.github.io/intraitR/reference/compare_functional_richness.md).

- ...:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), further
  arguments passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html);
  currently unused by [`print()`](https://rdrr.io/r/base/print.html).

## Value

Invisibly returns `x`.

Invisibly returns `x`.
