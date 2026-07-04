# Print and plot an `"intrait_species_sensitivity"` object

Print and plot an `"intrait_species_sensitivity"` object

## Usage

``` r
# S3 method for class 'intrait_species_sensitivity'
print(x, n = 12, ...)

# S3 method for class 'intrait_species_sensitivity'
plot(x, n = 12, abbreviate_species = TRUE, ...)
```

## Arguments

- x:

  An object of class `"intrait_species_sensitivity"`, as returned by
  [`species_sensitivity()`](https://funtraits.github.io/intraitR/reference/species_sensitivity.md).

- n:

  Integer, the number of most-influential species to show. Defaults to
  `12`.

- ...:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), further
  arguments passed to
  [`graphics::barplot()`](https://rdrr.io/r/graphics/barplot.html);
  currently unused by [`print()`](https://rdrr.io/r/base/print.html).

- abbreviate_species:

  Logical ([`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  only), abbreviate `"Genus species"` axis labels to `"G. species"`.
  Defaults to `TRUE`.

## Value

Invisibly returns `x`.

Invisibly returns `x`.
