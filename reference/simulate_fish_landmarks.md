# Simulate a fish landmark data set

Generates a simulated two-dimensional landmark data set representing
several fish "species" with distinct mean body shapes and sizes, several
individuals per species drawn from a population, and (optionally)
several digitization replicates per individual. This is used throughout
the package documentation and vignette to demonstrate the full
`intraitR` workflow without requiring real digitized data, and can be
used as a starting point (with
[`set.seed()`](https://rdrr.io/r/base/Random.html)) for teaching or for
testing analysis code before applying it to real specimens.

## Usage

``` r
simulate_fish_landmarks(
  n_per_species = 20,
  species = c("Species_A", "Species_B", "Species_C"),
  n_landmarks = 12,
  n_replicates = 3,
  seed = 123
)
```

## Arguments

- n_per_species:

  Integer, number of individuals simulated per species. Defaults to
  `20`.

- species:

  Character vector of species labels. Defaults to
  `c("Species_A", "Species_B", "Species_C")`.

- n_landmarks:

  Integer, number of landmarks per configuration (placed at evenly
  spaced angles around a fish-body-shaped ellipse). Defaults to `12`.

- n_replicates:

  Integer, number of digitization replicates simulated per individual
  (`1` for no replication). Defaults to `3`.

- seed:

  Integer or `NULL`. Random seed for reproducibility. Defaults to `123`.

## Value

An object of class `"intrait_landmarks"` (see
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)),
with `metadata` columns `specimen`, `species`, `population`,
`standard_length_mm` and `replicate`. `scale` is set to `1` for every
specimen (coordinates are already expressed in simulated millimetres).

## Details

Shape is simulated as isotropic Gaussian noise added to a per-species
mean ellipse, plus independent per-individual and
per-digitization-replicate noise components; centroid size ( proxy for
standard length) is drawn from a normal distribution. Because the
per-replicate noise is deliberately much smaller than the per-individual
and per-species variance components, the simulated data set is well
suited to illustrate
[`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)
(genuine among-individual and among-species variation) and
[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
(small, quantifiable digitization noise).

## See also

[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)

## Examples

``` r
fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 2)
fish
#> <intrait_landmarks>
#>   30 specimens, 12 landmarks, 2 dimensions
#>   Scale available for 30/30 specimens
#>   Metadata columns: specimen, species, population, standard_length_mm, replicate 
head(fish$metadata)
#>                                  specimen   species population
#> Species_A_ind01_rep1 Species_A_ind01_rep1 Species_A      Pop_1
#> Species_A_ind01_rep2 Species_A_ind01_rep2 Species_A      Pop_1
#> Species_A_ind02_rep1 Species_A_ind02_rep1 Species_A      Pop_2
#> Species_A_ind02_rep2 Species_A_ind02_rep2 Species_A      Pop_2
#> Species_A_ind03_rep1 Species_A_ind03_rep1 Species_A      Pop_1
#> Species_A_ind03_rep2 Species_A_ind03_rep2 Species_A      Pop_1
#>                      standard_length_mm replicate
#> Species_A_ind01_rep1               74.4         1
#> Species_A_ind01_rep2               74.4         2
#> Species_A_ind02_rep1               72.9         1
#> Species_A_ind02_rep2               72.9         2
#> Species_A_ind03_rep1               65.4         1
#> Species_A_ind03_rep2               65.4         2
```
