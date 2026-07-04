# Simulate landmark data following the FISHMORPH point digitization scheme

Generates a simulated data set of 21 (or 22) landmarks per specimen,
positioned following the Brosse et al. (2021) FISHMORPH digitization
scheme (see
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)),
for several simulated "species" with distinct body proportions. This
removes any dependency on real digitized pictures for examples,
teaching, and testing of
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
and
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md).

## Usage

``` r
simulate_fishmorph_points(
  n_per_species = 15,
  species = c("Species_A", "Species_B", "Species_C"),
  n_replicates = 1,
  curvature = FALSE,
  scale_cm = 1,
  px_per_cm = 12,
  seed = 123
)
```

## Arguments

- n_per_species:

  Integer, number of individuals simulated per species. Defaults to
  `15`.

- species:

  Character vector of species labels. Defaults to
  `c("Species_A", "Species_B", "Species_C")`, simulated with
  increasingly elongate-to-deep body proportions.

- n_replicates:

  Integer, number of digitization replicates simulated per individual
  (`1` for no replication). Defaults to `1`.

- curvature:

  Logical, also simulate a 22nd landmark for body curvature correction
  of standard length (see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).
  Defaults to `FALSE` (21 landmarks only, straight-line body length).

- scale_cm:

  Numeric, real-world distance in centimetres represented by the
  simulated scale bar (landmarks 20-21). Defaults to `1`.

- px_per_cm:

  Numeric, digitization units per centimetre used to build the simulated
  scale bar and body proportions (arbitrary; only the ratio to body
  landmark coordinates matters). Defaults to `12`.

- seed:

  Integer or `NULL`. Random seed for reproducibility. Defaults to `123`.

## Value

An object of class `"intrait_landmarks"` (see
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)),
with 21 (or 22) landmarks per specimen in the fixed order described in
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
and `metadata` columns `specimen`, `individual`, `species`,
`population`, and `replicate`. `scale` is set to `NULL` (the scale bar
is embedded as landmarks 20-21, per the FISHMORPH scheme, rather than
carried as external metadata).

## Details

This landmark scheme mixes true body-shape landmarks (1-19) with an
external scale-bar reference (20-21) and, optionally, a non-homologous
curvature-correction point (22); it is intended for use with
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
not for Generalised Procrustes Analysis
([`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)),
which assumes all landmarks are homologous shape coordinates.

## See also

[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)

## Examples

``` r
fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 2)
fish
#> <intrait_landmarks>
#>   30 specimens, 21 landmarks, 2 dimensions
#>   Metadata columns: specimen, individual, species, population, replicate 
head(fish$metadata)
#>                                  specimen      individual   species population
#> Species_A_ind01_rep1 Species_A_ind01_rep1 Species_A_ind01 Species_A      Pop_1
#> Species_A_ind01_rep2 Species_A_ind01_rep2 Species_A_ind01 Species_A      Pop_1
#> Species_A_ind02_rep1 Species_A_ind02_rep1 Species_A_ind02 Species_A      Pop_2
#> Species_A_ind02_rep2 Species_A_ind02_rep2 Species_A_ind02 Species_A      Pop_2
#> Species_A_ind03_rep1 Species_A_ind03_rep1 Species_A_ind03 Species_A      Pop_1
#> Species_A_ind03_rep2 Species_A_ind03_rep2 Species_A_ind03 Species_A      Pop_1
#>                      replicate
#> Species_A_ind01_rep1         1
#> Species_A_ind01_rep2         2
#> Species_A_ind02_rep1         1
#> Species_A_ind02_rep2         2
#> Species_A_ind03_rep1         1
#> Species_A_ind03_rep2         2
```
