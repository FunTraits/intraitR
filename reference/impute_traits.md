# Impute missing trait values, and say which cells were invented

The imputation that
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
and
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
perform internally, exposed on its own so that a filled trait table can
be **kept** rather than recomputed inside every ordination – and, above
all, so that the cells that were filled can travel with it.

## Usage

``` r
impute_traits(
  traits,
  method = c("missforest_phylo", "missforest", "impute_group_mean", "impute_mean",
    "omit", "keep"),
  groups = NULL,
  species = NULL,
  tree = NULL,
  phylo_axes = NULL,
  missforest_phylo_k = 10,
  missforest_ntree = 100,
  missforest_maxiter = 10
)
```

## Arguments

- traits:

  A data.frame or matrix of numeric traits, one row per specimen.
  Non-numeric columns are dropped, with a warning.

- method:

  Imputation method: `"impute_mean"`, `"impute_group_mean"`,
  `"missforest"` or `"missforest_phylo"`. `"omit"` drops the incomplete
  rows instead of filling them, and `"keep"` returns the table untouched
  – both accepted so that a caller can pass the user's choice through
  unchanged.

- groups:

  Grouping factor, one value per row: the key of `"impute_group_mean"`
  and a categorical predictor for the forests. `NULL` uses `species`
  when it is given.

- species:

  Species name per row, used only to look up the phylogenetic axes of
  `"missforest_phylo"`.

- tree, phylo_axes, missforest_phylo_k:

  Phylogeny for `"missforest_phylo"`; see
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md).

- missforest_ntree, missforest_maxiter:

  Passed to
  [`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html).

## Value

A list of class `"intrait_imputation"`:

- `traits`:

  the filled data.frame, in the order given

- `imputed`:

  a logical matrix of the same shape, `TRUE` where a value was invented

- `keep`:

  logical vector, `FALSE` for rows dropped by `"omit"`

- `method`:

  the method applied

- `n_missing`,`n_imputed`:

  counts before and after

## Why the mask matters more than the values

An imputed value is indistinguishable from a measured one once it is in
a table: it has the same type, the same magnitude, and it makes every
completeness check pass. The `imputed` matrix returned here is the only
thing that keeps the two apart afterwards, and it is what lets a
downstream analysis weight, exclude or simply report them. A function
that returned the filled matrix alone would be handing back a table that
has quietly stopped being a record of measurements.

## Choosing a method

`"impute_group_mean"` replaces a missing value with the mean of its
species. It is transparent and reproducible, and it CONTRACTS
INTRASPECIFIC VARIABILITY – every imputed individual is placed exactly
at its species' centre – which is a problem when intraspecific
variability is the quantity being measured. `"missforest"` predicts each
trait from the others by random forest and preserves more of the spread;
`"missforest_phylo"` adds phylogenetic PCoA axes as predictors (see
[`phylo_pcoa()`](https://rdrr.io/pkg/Rfishmorph/man/phylo_pcoa.html))
and falls back to plain `"missforest"`, with a message, when no usable
tree is available. Both report an out-of-bag NRMSE, which is the honest
measure of how much the filled values can be trusted.

## See also

[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)

## Examples

``` r
set.seed(1)
d <- data.frame(a = rnorm(20), b = rnorm(20), c = rnorm(20))
d$a[c(2, 7)] <- NA
im <- impute_traits(d, method = "impute_mean")
#> na_action = "impute_mean": imputed 2 missing value(s) using column means.
sum(im$imputed)
#> [1] 2
```
