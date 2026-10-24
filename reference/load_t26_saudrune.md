# Real freshwater fish landmark data set from an electrofishing campaign (T-26, La Saudrune)

Loads one of the four analysis-ready tables of the T-26 electric fishing
survey of the Saudrune (Adour-Garonne basin, south of Toulouse, France),
the real (non-simulated) data set shipped with intraitR. Fish were
photographed in the field on two dates (27 April and 18 May 2026) and
digitized with
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
on the 25-point scheme: the 19 FISHMORPH anatomical landmarks (Brosse et
al., 2021; see
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)),
the scale bar (20-21), the curvature point (22), the derived head base
(23) and the entry hinges (24-25).

## Usage

``` r
load_t26_saudrune(
  dataset = c("landmarks", "specimens", "repeatability", "qc_log"),
  operator = NULL,
  species = FALSE
)
```

## Source

T-26 electrofishing campaign, Saudrune (Adour-Garonne basin, France), 27
April and 18 May 2026; digitized by A. Toussaint (CNRS) with
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).
The raw workbook and photographs are not distributed;
`data-raw/t26_campaign_prepare.R` rebuilds the tables.

## Arguments

- dataset:

  Character, one of `"landmarks"` (default), `"specimens"`,
  `"repeatability"` or `"qc_log"`. See Value.

- operator:

  `NULL` (default, all rows returned), or a character vector of one or
  more operator labels (e.g. `"AT"`) to restrict the returned rows to.
  Modular by design: if `dataset` has no `operator` column, `operator`
  is ignored with a warning and every row is returned.

- species:

  Logical, defaults to `FALSE`. If `TRUE`, left-joins the `species` and
  `species_code` columns of the `"specimens"` table onto `dataset`,
  matched by `code` with a plain
  [`match()`](https://rdrr.io/r/base/match.html) lookup (not
  [`merge()`](https://rdrr.io/r/base/merge.html)), so the many rows
  sharing one `code` in the long-format tables keep their order exactly.
  `FALSE` by default because a landmark never needs to know a species
  and a determination can be revised without touching a coordinate: the
  two tables are kept apart on purpose. Ignored with a warning if
  `dataset` has no `code` column; a no-op on `"specimens"` itself.

## Value

A `data.frame`:

- `"landmarks"`:

  Long-format coordinates (`specimen`, `code`, `operator`, `landmark`,
  `X`, `Y`), 25 rows per specimen, one digitization per specimen.
  Coordinates are pixels of the prepared photograph. Points a specimen
  does not carry are `NA` rather than absent rows, so the table is
  rectangular; point 25 is reserved by the digitizer and currently
  always `NA`. `specimen` and `code` are the campaign's immutable
  identifier `SITE_YYYYMMDD_NNNN`, with the suffix `_iK` for the K-th
  fish of a multi-individual plate.

- `"specimens"`:

  One row per digitized specimen (`code`): `uid` (the photograph),
  `individual` (position on the plate, 1 for a single fish), `photo`,
  the current determination (`species`, `species_code`, `confidence`,
  `determined_by`), `site`, `date`, `operator`, the operator's `quality`
  score on the scale of intraitR \<= 1.40 (1 = very good .. 5 = poor;
  the digitizer now records `quality_score`, 5 = excellent). 491 of the
  494 specimens carry 3, the old DEFAULT of the app: read it as "not
  scored", not as a judgement. Then `reviewed`, `n_landmarks` placed,
  `ruler_mm`, `mm_per_px`, image size, `photo_hash` (see
  [`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md)),
  `app_version` and the `digitized` date.

- `"repeatability"`:

  Long-format coordinates (`specimen`, `code`, `operator`, `replicate`,
  `landmark`, `X`, `Y`) of the blind repeat trial run in
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)'s
  repeat mode: the same individuals (`code`) re-digitized several times.
  `specimen` is `<code>_<operator>_rep<N>` and is unique. Input of
  [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md),
  [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
  and, once a second operator has digitized the same fish,
  [`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md).

- `"qc_log"`:

  One row per digitization excluded from the shipped tables, with the
  `reason` (see `data-raw/t26_campaign_prepare.R`).

## Details

Identity follows the campaign's own rule: the code is the photograph,
never the species. Species names are the last non-superseded
determination recorded in the campaign (`export/determinations.csv`) at
the time the tables were built, and may be revised in a later release
without any coordinate changing. Landmarks 20-21 are the two ends of a
10 mm segment on a ruler placed alongside each fish, so
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
can be called on these data with its default `scale_cm = 1`.

## References

Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
morphological traits of freshwater fishes. Global Ecology and
Biogeography, 30(12), 2330-2336.

## See also

[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md),
[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md),
[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md);
`demo(pipeline_T26_saudrune)` for a complete worked analysis.

## Examples

``` r
lm <- load_t26_saudrune()
str(lm)
#> 'data.frame':    12350 obs. of  6 variables:
#>  $ specimen: chr  "SAUDRUNESUDTOULOUSE_20260427_0001" "SAUDRUNESUDTOULOUSE_20260427_0001" "SAUDRUNESUDTOULOUSE_20260427_0001" "SAUDRUNESUDTOULOUSE_20260427_0001" ...
#>  $ code    : chr  "SAUDRUNESUDTOULOUSE_20260427_0001" "SAUDRUNESUDTOULOUSE_20260427_0001" "SAUDRUNESUDTOULOUSE_20260427_0001" "SAUDRUNESUDTOULOUSE_20260427_0001" ...
#>  $ operator: chr  "AT" "AT" "AT" "AT" ...
#>  $ landmark: int  1 2 3 4 5 6 7 8 9 10 ...
#>  $ X       : num  220 1247 647 641 312 ...
#>  $ Y       : num  300 271 159 425 213 ...
spec <- load_t26_saudrune("specimens")
table(spec$species, spec$date)
#>                          
#>                           20260427 20260518
#>   Barbatula barbatula           17        0
#>   Barbus barbus                  5       25
#>   Gobio gobio                  176      112
#>   Lepomis gibbosus               2        7
#>   Leuciscus burdigalensis        4        0
#>   Perca fluviatilis              8       12
#>   Squalius cephalus             66       60

# the landmark table carries `code`, not `species` (species lives in
# "specimens" by design); species = TRUE joins it back, in row order:
lm_sp <- load_t26_saudrune(species = TRUE)
identical(lm_sp$code, lm$code)
#> [1] TRUE

# the blind repeat trial: one `code` digitized several times
rep_df <- load_t26_saudrune("repeatability")
table(unique(rep_df[c("code", "replicate")])$code)
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
