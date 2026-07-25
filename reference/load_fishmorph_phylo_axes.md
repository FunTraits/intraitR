# Precomputed phylogenetic PCoA axes for the FISHMORPH species pool

Loads `pcoaPhylogenyFish.rds`, the **precomputed** principal-coordinate
axes of the bundled fish phylogeny for the 8,970 FISHMORPH species (10
axes, ordered by decreasing eigenvalue). These are the axes used by
every `"missforest_phylo"` option in the package:
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
and
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md).

## Usage

``` r
load_fishmorph_phylo_axes(file = NULL, k = NULL, refresh = FALSE)
```

## Arguments

- file:

  Optional path to an alternative axis table: either an `.rds` holding a
  data frame, or a whitespace-separated text file with species as row
  names and one column per axis. `NULL` (default) uses the bundled file.

- k:

  Number of axes to return (the first `k` columns). `NULL` returns all.

- refresh:

  Force a re-read instead of using the session cache.

## Value

A data frame with a `species` column (canonical `Genus_species`
spelling) followed by the axis columns, named `phylo_1`, `phylo_2`, ...

## Why precomputed

The alternative,
[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md),
eigendecomposes the patristic distance matrix of the tree. That matrix
is *n by n*: for 8,970 species it holds roughly 80 million entries, and
the decomposition is cubic in *n*. Recomputing it on every imputation is
both slow and, more importantly, **not comparable across calls** – the
axes depend on which subset of species happens to be present in the data
at hand, so two analyses run on different subsets end up in different
phylogenetic coordinate systems and their results cannot be compared.

Reading a fixed table instead makes the axes a *property of the
phylogeny* rather than of the current dataset. Every imputation,
whatever the species subset, then lives in one and the same phylogenetic
space.

## File format

The bundled table is a compressed `.rds` (about 540 kB, against 1.8 MB
for the whitespace-separated text it was produced from). Both formats
are accepted and dispatched on the file extension, so `file` may point
at either. To regenerate the `.rds` from a text source:

    txt <- read.table("pcoaPhylogenyFish.txt", header = TRUE)
    ax  <- data.frame(species = gsub("[ ._]+", "_", rownames(txt)), txt,
                      row.names = NULL)
    names(ax)[-1] <- paste0("phylo_", seq_len(ncol(txt)))
    saveRDS(ax, "pcoaPhylogenyFish.rds", compress = "xz")

## See also

[`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)
to recompute axes from an arbitrary tree,
[`load_fishmorph_phylogeny()`](https://funtraits.github.io/intraitR/reference/load_fishmorph_phylogeny.md)
for the tree itself,
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
and
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)
for the imputation methods that consume these axes.

## Examples

``` r
ax <- load_fishmorph_phylo_axes(k = 3)
dim(ax)
#> [1] 8970    4
head(ax, 3)
#>                   species  phylo_1    phylo_2   phylo_3
#> 1        Aaptosyax_grypus 1.163439 -0.4148371 0.3580825
#> 2  Abactochromis_labrosus 1.163439 -0.4148371 0.3580825
#> 3 Abbottina_liaoningensis 1.163944 -0.4152019 0.3587335
```
