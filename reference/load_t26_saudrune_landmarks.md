# Real T-26 Saudrune landmark data, ready to use as an `"intrait_landmarks"` object

Loads the real T-26 Saudrune electrofishing landmark data (see
[`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md))
directly as an object of class `"intrait_landmarks"`, in the format
returned by
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md):
a `p x k x n` coordinate array together with a `metadata` data.frame
carrying `specimen`, `individual`, `species`, `population` and
`replicate`. The real data set is therefore a drop-in replacement for
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
wherever a FISHMORPH-scheme `"intrait_landmarks"` object is expected,
e.g.
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md),
[`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)
and
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md).

## Usage

``` r
load_t26_saudrune_landmarks(
  source = c("landmarks", "repeatability"),
  species = NULL,
  operator = NULL
)
```

## Arguments

- source:

  Character, one of:

  `"landmarks"`

  :   **Default.** Every specimen of the campaign, digitized once with
      [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
      on the 25-point scheme. `metadata$replicate` is 1 throughout and
      `metadata$individual` equals `specimen`.

  `"repeatability"`

  :   The blind repeat trial: the same individuals re-digitized several
      times in the digitizer's repeat mode. `metadata$individual` is the
      fish (`code`), `metadata$replicate` the pass; the input of
      [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md),
      [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
      and
      [`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md).

- species:

  Optional character vector of species names: if supplied, only
  specimens currently determined as one of these species are kept.
  Defaults to `NULL` (every fish is kept).

- operator:

  `NULL` (default, every operator's digitizations), or a character
  vector of operator labels (e.g. `"AT"`; see
  `unique(load_t26_saudrune(source)$operator)`) to restrict to. With two
  operators in `"repeatability"` this is the natural way to build two
  separate trait spaces and check whether results depend on who
  digitized.

## Value

An object of class `"intrait_landmarks"`: `coords` (a `25 x 2 x n`
array), `scale` (`NULL`; the scale bar is embedded as landmarks 20-21,
as in
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md))
and `metadata` (the five standard columns plus `operator`, and
`species_code`, `quality`, `date` and `uid` carried over from the
`"specimens"` table).

## Details

Point 25 is reserved by the digitizer and currently always `NA`; a few
specimens lack the scale bar (20-21). Functions that require a complete
configuration (e.g.
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md))
should filter on complete cases of the landmarks they use.
`metadata$population` is `NA` throughout: the survey sampled one
electrofishing point and no sub-population structure is fabricated.

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
#>   494 specimens, 25 landmarks, 2 dimensions
#>   Metadata columns: specimen, individual, species, population, replicate, operator, species_code, quality, date, uid 
table(fish$metadata$species)
#> 
#>     Barbatula barbatula           Barbus barbus             Gobio gobio 
#>                      17                      30                     288 
#>        Lepomis gibbosus Leuciscus burdigalensis       Perca fluviatilis 
#>                       9                       4                      20 
#>       Squalius cephalus 
#>                     126 

# restrict to the two most abundant species
gobio_squalius <- load_t26_saudrune_landmarks(
  species = c("Gobio gobio", "Squalius cephalus")
)
dim(gobio_squalius$coords)
#> [1]  25   2 414

# the repeat trial: several configurations per individual
rep_fish <- load_t26_saudrune_landmarks("repeatability")
table(rep_fish$metadata$individual)
#> 
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0002 
#>                                 4                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0004 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0006 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0007 SAUDRUNESUDTOULOUSE_20260427_0008 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0009 SAUDRUNESUDTOULOUSE_20260427_0010 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0011 SAUDRUNESUDTOULOUSE_20260427_0012 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0013 SAUDRUNESUDTOULOUSE_20260427_0014 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0015 SAUDRUNESUDTOULOUSE_20260427_0016 
#>                                 3                                 3 
#> SAUDRUNESUDTOULOUSE_20260427_0017 
#>                                 3 
```
