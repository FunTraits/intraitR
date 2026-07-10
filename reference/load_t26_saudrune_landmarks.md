# Real T-26 Saudrune landmark data, ready to use as an `"intrait_landmarks"` object

Loads the real T-26 Saudrune electrofishing landmark data (see
[`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md))
directly as an object of class `"intrait_landmarks"`, in exactly the
format returned by
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md):
a `p x k x n` coordinate array (21 FISHMORPH landmarks; Brosse et al.,
2021) together with a `metadata` data.frame carrying `specimen`,
`individual`, `species`, `population` and `replicate` columns. This
makes the real data set a drop-in replacement for
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
wherever a FISHMORPH-scheme `"intrait_landmarks"` object is expected,
e.g.
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md),
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md),
and
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md).

## Usage

``` r
load_t26_saudrune_landmarks(
  source = c("operators", "repeatability"),
  species = NULL,
  operator = NULL
)
```

## Arguments

- source:

  Character, one of `"operators"` (default: 279 fish, one digitization
  per operator, from the two independent operators of the T-26 survey)
  or `"repeatability"` (25 individuals, 9-10 replicate digitizations by
  a single operator; see
  [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md)
  and
  [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)).

- species:

  Optional character vector of species names: if supplied, only
  specimens identified (curated or preliminary) as one of these species
  are kept. Defaults to `NULL` (every fish is kept, including the single
  specimen with an unresolved identification, for which
  `metadata$species` is `NA`; see
  [`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md)).

- operator:

  `NULL` (default, every operator's digitizations are returned), or a
  character vector of one or more anonymous operator labels (e.g.
  `"Operator_1"`; see `unique(load_t26_saudrune(source)$operator)` for
  the labels available for a given `source`) to restrict to. This is the
  natural way to build **two separate functional trait spaces**, one per
  operator, from `source = "operators"` (each fish was digitized once by
  each of two operators) — e.g. to check whether
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  or
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  results are sensitive to who did the digitizing, complementing the
  landmark-level view of
  [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md).
  Modular by design: if the requested `source` has no `operator` column,
  `operator` is ignored with a warning and every row is returned (in
  practice every `source` currently offered here does have one, but this
  keeps the function robust to future `source` options that might not).

## Value

An object of class `"intrait_landmarks"`, a list with elements `coords`
(a `21 x 2 x n` array), `scale` (`NULL`; the scale bar is embedded as
landmarks 20-21, as in
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)),
and `metadata` (a `data.frame` with, in addition to the five standard
columns shared with
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)'s
output, an `operator` column and, for `source = "repeatability"`, a
`site` column carried over from the raw data).

## Details

Unlike
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md),
real specimens are not all fully digitized: some coordinates (chiefly
landmark 5, in roughly a quarter of specimens) are missing. Functions
that require a complete configuration (e.g.
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
which is not intended for this mixed shape/scale-bar landmark scheme in
any case; see
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md))
should filter on complete cases first. `metadata$population` is set to
`NA` throughout, because the T-26 survey sampled a single electrofishing
point: unlike the simulated data set, there is no genuine sub-population
structure in this real sample to report, and none is fabricated here.

## References

Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
morphological traits of freshwater fishes. Global Ecology and
Biogeography, 30(12), 2330-2336.

## See also

[`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md),
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()
fish
#> <intrait_landmarks>
#>   558 specimens, 21 landmarks, 2 dimensions
#>   Metadata columns: specimen, individual, species, population, replicate, operator 
table(fish$metadata$species, useNA = "ifany")
#> 
#>                                 Barbatula barbatula             Barbus barbus 
#>                         2                        36                        10 
#>          Gobio occitaniae          Lepomis gibbosus   Leuciscus burdigalensis 
#>                       338                         4                        14 
#>         Perca fluviatilis         Phoxinus phoxinus Phoxinus phoxinus/bigerri 
#>                        16                        34                         8 
#>         Squalius cephalus 
#>                        96 

# restrict to the two most abundant species
gobio_squalius <- load_t26_saudrune_landmarks(
  species = c("Gobio occitaniae", "Squalius cephalus")
)
dim(gobio_squalius$coords)
#> [1]  21   2 434

# build two separate functional trait spaces, one per operator, to check
# whether the two digitizers' shape spaces agree:
fish_op1 <- load_t26_saudrune_landmarks(operator = "Operator_1")
fish_op2 <- load_t26_saudrune_landmarks(operator = "Operator_2")
ratios_op1 <- fishmorph_ratios(fishmorph_segments(fish_op1))
#> Warning: 1 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
ratios_op2 <- fishmorph_ratios(fishmorph_segments(fish_op2))
#> Warning: 2 specimen(s) have a zero-length or missing scale bar (points 20-21); their segments will be NA. See fishmorph_ratios()'s `landmarks` argument to still recover the 9 unitless ratios for these specimens directly from pixel-space distances.
ts_op1 <- trait_space(ratios_op1, groups = fish_op1$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 139 row(s) out of 279 with missing values.
#> Warning: Dropping constant (zero-variance) column(s) from the ordination: replicate
#> flag_outliers: 3 specimen(s) flagged as within-group outlier(s) across 3 group(s) (Gobio occitaniae, Phoxinus phoxinus, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 2 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
ts_op2 <- trait_space(ratios_op2, groups = fish_op2$metadata$species, na_action = "omit")
#> Warning: Dropping non-numeric column(s) from the ordination: specimen, individual, species, population, operator
#> na_action = "omit": removing 91 row(s) out of 279 with missing values.
#> Warning: Dropping constant (zero-variance) column(s) from the ordination: replicate
#> flag_outliers: 12 specimen(s) flagged as within-group outlier(s) across 4 group(s) (Barbatula barbatula, Gobio occitaniae, Leuciscus burdigalensis, Squalius cephalus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 4 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
```
