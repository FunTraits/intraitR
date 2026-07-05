# Look up the group/species colours used by the ordination plot methods

Returns the exact colour
[`plot.intrait_morphospace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_morphospace.md)/
[`plot.intrait_traitspace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_traitspace.md)
draw (or would draw) for each group, in the same order as their own
legend – so a shared legend built separately (e.g. one common legend
below several panels laid out with
`par(mfrow = ...)`/[`layout()`](https://rdrr.io/r/graphics/layout.html),
each plotted with `legend = FALSE`) is guaranteed to match every panel's
actual colours, without reimplementing or guessing at the underlying
colour assignment.

## Usage

``` r
group_colors(x)
```

## Arguments

- x:

  Either an object with a `$groups` element (e.g. one returned by
  [`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md)/[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)),
  or a factor/character vector of group labels directly (e.g.
  `fish$metadata$species`), one per observation – duplicates are fine,
  only the distinct values matter.

## Value

A `data.frame` with one row per distinct group (in the same order used
by the plot methods' own legend), and columns `group` (character) and
`color` (hex character).

## Details

Looking a group up here does not itself add it to the session-level
colour cache in a way that is any different from plotting it directly:
either way, a group not yet seen this session is assigned the next
unused colour and keeps it for the rest of the session (see
[`reset_group_colors()`](https://funtraits.github.io/intraitR/reference/reset_group_colors.md)).
Calling `group_colors()` *before* plotting is therefore entirely safe
and produces the same colours the subsequent plot calls will use.

## See also

[`reset_group_colors()`](https://funtraits.github.io/intraitR/reference/reset_group_colors.md),
[`plot.intrait_morphospace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_morphospace.md),
[`plot.intrait_traitspace()`](https://funtraits.github.io/intraitR/reference/plot.intrait_traitspace.md)

## Examples

``` r
fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
gpa <- gpa_fish(fish)
ms <- morpho_space(gpa, groups = fish$metadata$species)
group_colors(ms)
#>       group   color
#> 1 Species_A #4E79A7
#> 2 Species_B #F28E2B
#> 3 Species_C #59A14F

# or directly from a label vector:
group_colors(fish$metadata$species)
#>       group   color
#> 1 Species_A #4E79A7
#> 2 Species_B #F28E2B
#> 3 Species_C #59A14F
```
