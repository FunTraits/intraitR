# Bundled global fish phylogeny, ready to use with [`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)

Loads a large (10,705-tip) phylogenetic tree of ray-finned fishes
bundled with the package, for use with
[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)
and, in turn, with `na_action`/`method = "missforest_phylo"` in
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
and
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md).

## Usage

``` r
load_fishmorph_phylogeny()
```

## Value

An object of class `"phylo"` (see
[`ape::read.tree()`](https://rdrr.io/pkg/ape/man/read.tree.html)), with
elements `edge`, `edge.length`, `Nnode`, and `tip.label` (10,705 tip
labels, formatted `"Genus.species"`, e.g. `"Barbus.barbus"` – note the
dot separator, unlike this package's own `"Genus species"` convention;
[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)
and every `"missforest_phylo"` option in this package normalise spaces,
underscores, and dots interchangeably before matching, so this
difference does not need to be handled by hand).

## Details

**Provenance**: this tree was supplied by the package maintainer as
`FishMORPH_Phylogeny.rds` for use in the FISHMORPH-related analyses this
package supports; its exact upstream source/citation has not been
independently verified here. If you know the original publication this
tree should be attributed to (e.g. a large-scale fish time-tree such as
Rabosky et al., 2018, or a FISHMORPH-specific pruning of one), please
add the correct citation to your own methods/manuscript – do not cite
this function's documentation as the source. Requires the `ape` package
to use with `ape`-based functions (e.g.
[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md));
loading the raw object here only requires base R.

## See also

[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)

## Examples

``` r
tree <- load_fishmorph_phylogeny()
length(tree$tip.label)
#> [1] 10705
head(tree$tip.label)
#> [1] "Polypterus.ornatipinnis" "Polypterus.weeksii"     
#> [3] "Polypterus.retropinnis"  "Polypterus.ansorgii"    
#> [5] "Polypterus.bichir"       "Polypterus.endlicherii" 

# \donttest{
if (requireNamespace("ape", quietly = TRUE)) {
  pp <- phylo_pcoa(tree, species = c("Barbus.barbus", "Gobio.gobio", "Perca.fluviatilis"), k = 2)
  pp
}
#> <intrait_phylopcoa>
#>   3 species, 2 PCoA axis/axes (correction = "none")
#>   Variance explained: PCoA1 = 87.2%, PCoA2 = 12.8%
# }
```
