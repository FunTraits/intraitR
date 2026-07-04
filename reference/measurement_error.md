# Estimate measurement error from replicated digitization

Quantifies measurement error and repeatability from repeated
measurements (replicate digitizations of the same specimen), for either
univariate linear traits/ratios (ANOVA-based percent measurement error
and repeatability, Bailey & Byrnes, 1990; Yezerinac et al., 1992) or
landmark shape data (Procrustes ANOVA, Fruciano, 2016). Assessing
measurement error is a necessary step before interpreting any biological
pattern of intraspecific variability, since it partitions observed
variance into a biological and a technical (digitization) component.

## Usage

``` r
measurement_error(
  x,
  individual = NULL,
  method = c("anova", "procrustes"),
  iter = 999
)
```

## Arguments

- x:

  For `method = "anova"`: either a numeric matrix/data.frame with one
  row per individual and one column per replicate measurement, or a
  long-format `data.frame` with an `individual` grouping column and a
  `value` column. For `method = "procrustes"`: an object of class
  `"intrait_gpa"` built from replicate-digitized specimens (i.e. each
  individual appears multiple times in the sample, once per digitization
  replicate).

- individual:

  For long-format univariate input, the name of the column identifying
  individuals. For `method = "procrustes"`, a factor (or character
  vector) of the same length as the number of specimens in `x`, giving
  the individual identity of each replicate. Required for
  `method = "procrustes"`.

- method:

  Character, one of `"anova"` (default) or `"procrustes"`.

- iter:

  Integer, number of permutations for `method = "procrustes"`. Defaults
  to `999`.

## Value

An object of class `"intrait_measurement_error"`. For
`method = "anova"`, a list with `anova_table` (a one-way ANOVA of trait
value on individual identity), `percent_measurement_error` (`%ME`, the
proportion of total variance attributable to measurement error), and
`repeatability` (the intraclass correlation coefficient, `R`). For
`method = "procrustes"`, a list with `procD_table`, the Procrustes ANOVA
table testing whether shape variance among individuals exceeds variance
among replicates within individuals.

## Details

For `method = "anova"`, with among-individual and residual (replicate)
mean squares \\MS_a\\ and \\MS_e\\ from a one-way ANOVA, and `n`
replicates per individual: \$\$\\ME = \frac{MS_e}{MS_e + MS_a} \times
100\$\$ \$\$R = \frac{MS_a - MS_e}{MS_a + (n - 1) MS_e}\$\$ Low `%ME`
(and high `R`, close to 1) indicate that measurement error is small
relative to genuine among-individual variation, and that subsequent
analyses of intraspecific variability
([`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md))
are unlikely to be confounded by digitization noise.

## References

Bailey RC, Byrnes J (1990). A new, old method for assessing measurement
error in both univariate and multivariate morphometric studies.
Systematic Zoology, 39(2), 124-130.

Yezerinac SM, Lougheed SC, Handford P (1992). Measurement error and
morphometric studies: statistical power and observational error.
Systematic Biology, 41(4), 471-482.

Fruciano C (2016). Measurement error in geometric morphometrics.
Development Genes and Evolution, 226(3), 139-158.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)

## Examples

``` r
set.seed(1)
replicate_data <- data.frame(
  r1 = rnorm(10, 50, 5), r2 = rnorm(10, 50, 5), r3 = rnorm(10, 50, 5)
)
rownames(replicate_data) <- paste0("ind", 1:10)
measurement_error(replicate_data, method = "anova")
#> <intrait_measurement_error>
#>  Method: ANOVA-based measurement error (Bailey & Byrnes, 1990) 
#> 
#>             Df Sum Sq Mean Sq F value Pr(>F)
#> individual   9 165.31  18.368  0.8094 0.6134
#> Residuals   20 453.84  22.692               
#> 
#>  Percent measurement error (%ME): 55.27%
#>  Repeatability (R): -0.068
```
