# Plot the TPD dissimilarity matrix as a heat map

Plot the TPD dissimilarity matrix as a heat map

## Usage

``` r
# S3 method for class 'intrait_tpd_dissim'
plot(x, col = grDevices::hcl.colors(50, "TealGrn", rev = TRUE), ...)
```

## Arguments

- x:

  An object of class `"intrait_tpd_dissim"`.

- col:

  A vector of colours for increasing dissimilarity. Defaults to a
  white-to-teal ramp.

- ...:

  Passed to
  [`graphics::image()`](https://rdrr.io/r/graphics/image.html).

## Value

Invisibly returns `x`.
