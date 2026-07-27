# Import predicted landmarks from an ml-morph / landmarking-app measure table

Converts a "long" (tidy) table of landmark coordinates – as produced by
the **ml-morph** shape predictor or by the interactive landmarking Shiny
app, both of which export the same schema (one row per
specimen/landmark, columns `specimen`, `landmark`, `X`, `Y` and an
optional per-image scale `mm_per_px`) – straight into an
`"intrait_landmarks"` object, ready for
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
and the rest of the intraitR pipeline.

## Usage

``` r
read_mlmorph_landmarks(
  file,
  specimen = "specimen",
  landmark = "landmark",
  coords = c("X", "Y"),
  scale_col = "mm_per_px",
  metadata = NULL,
  by = NULL,
  operator = "ml_morph",
  replicate = 1L,
  save_to = NULL,
  ...
)
```

## Arguments

- file:

  Character path to the measure table (a CSV as written by the predictor
  or the landmarking app), or a `data.frame` already loaded in R.

- specimen, landmark:

  Character, the columns identifying specimens and landmarks. Default
  `"specimen"` and `"landmark"`.

- coords:

  Character vector of the coordinate columns, in order. Defaults to
  `c("X", "Y")`.

- scale_col:

  Character or `NULL`, the column holding the per-image calibration
  scale (millimetres per pixel). When present, one value per specimen is
  carried into `metadata$mm_per_px` and a logical
  `metadata$has_scalebar` flags specimens that had a usable scale. Set
  to `NULL` to ignore any such column. Defaults to `"mm_per_px"`.

- metadata:

  Optional specimen-level metadata: a `data.frame` (or a CSV path) with
  one row per individual, joined onto the imported specimens by `by`.
  Typically an identifications table carrying `species` and other
  descriptors.

- by:

  Character, the column of `metadata` whose values match the `specimen`
  ids (e.g. a `"code"` column). `NULL` (default) auto-detects the first
  of `specimen`, `"code"`, `"individual"` or `"id"` present in
  `metadata`.

- operator:

  Character scalar recorded in `metadata$operator` to identify the
  source of the digitization (the predictor, an app session, an operator
  name). Treating a set of predicted landmarks as one "operator" mirrors
  [`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)
  and makes it easy to compare predicted against hand-digitized trait
  spaces. Defaults to `"ml_morph"`. The special value `"parse"` instead
  reads the operator off each specimen identifier (see Details).

- replicate:

  Integer scalar recorded in `metadata$replicate` (one digitization per
  individual by default). Defaults to `1L`. The special value `"parse"`
  instead reads the replicate number off each specimen identifier (see
  Details), which is what a table produced by the repeat mode of
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  carries.

- save_to:

  Optional character path; when supplied, the resulting object is also
  written there with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)
  (a convenience for the common "predict, convert, cache" workflow).
  Defaults to `NULL` (return only, the standard behaviour of the
  package's `read_*()` importers).

- ...:

  Additional arguments passed to
  [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html) when
  `file` (or `metadata`) is a path.

## Value

An object of class `"intrait_landmarks"` (a `p x k x n` coordinate array
plus a `metadata` data.frame), in the same format as
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
and
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md).
The `metadata` always carries `specimen`, `individual`, `species`,
`population`, `replicate` and `operator` columns (the intraitR
convention; `species`/`population` are `NA` when not supplied via
`metadata`), any extra columns joined from `metadata`, and – when
`scale_col` is present – `mm_per_px` and `has_scalebar`.

## Details

This is a thin, reusable wrapper around
[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)
that adds the two things those exports carry which a bare coordinate
reshape does not: the per-specimen calibration scale (`mm_per_px`,
together with a `has_scalebar` flag flagging individuals whose
calibration mire – the FISHMORPH scale-bar landmarks 20-21 – was absent,
so that `mm_per_px = NA`), and an optional join to a specimen-level
metadata table (species, stage, site, ...). Individuals without a scale
keep `NA` coordinates where landmarks were not placed and an `NA` scale;
convert pixel distances to length units downstream with the `scale_cm`
argument of
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
and impute what is missing with
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)
if a complete configuration is required.

## Replicated digitizations

A measure table in which the same physical individual was digitized more
than once – the repeat mode of
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
used to quantify measurement error and operator bias – distinguishes the
passes by their identifier rather than by a column, since the exported
schema is one row per specimen and landmark. The convention, shared with
the T-26 repeatability set of
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md),
is `"<individual>_rep<N>"`, optionally with an operator token before the
suffix: `"<individual>_<operator>_rep<N>"`. The replicate number is
always the last underscore-separated token, so an identifier is
decomposed unambiguously from the right, and the operator label carries
no underscore.

Because a bare identifier cannot be told apart from an individual whose
name merely happens to end in `_rep2`, the decomposition is never
attempted silently: it is requested with `replicate = "parse"` (and,
when several operators share one table, `operator = "parse"`).
`metadata$individual` then holds the physical individual,
`metadata$replicate` the pass number, and `metadata$operator` the
operator, which is the grouping
[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
(`method = "procrustes"`, argument `individual`) and
[`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md)
expect. Identifiers carrying no suffix are left alone (`replicate = 1`),
so a table mixing single and repeated digitizations imports correctly.

One ambiguity is irreducible and worth stating: `operator = "parse"`
takes the token before the suffix as the operator, so an individual
whose own code contains an underscore and which was digitized *without*
an operator label (`"fish_01_rep2"`) would be split into individual
`"fish"` and operator `"01"`. Use `operator = "parse"` only on tables
where the operator was actually recorded in the identifier – the case it
exists for – and `replicate = "parse"` alone otherwise, which never
touches the individual's name beyond the suffix. Identifiers with a
suffix but no operator token are reported, and keep `operator = NA`.

## See also

[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)

## Examples

``` r
# A minimal ml-morph / app-style export (long format, with a scale):
mes <- data.frame(
  specimen  = rep(c("fish_01", "fish_02"), each = 3),
  landmark  = rep(1:3, times = 2),
  X = c(10, 15, 20, 11, 16, 21),
  Y = c(20, 25, 20, 21, 26, 21),
  mm_per_px = c(0.22, 0.22, 0.22, NA, NA, NA)  # fish_02 lacks a scale bar
)
lm <- read_mlmorph_landmarks(mes)
#> Measure table: 2 individual(s) x 3 landmark(s) (6 rows).
#> Warning: 1 individual(s) without a calibration scale (mm_per_px all NA); their measurements cannot be converted to length units and will stay NA. Affected: fish_02
dim(lm$coords)
#> [1] 3 2 2
lm$metadata[c("specimen", "operator", "mm_per_px", "has_scalebar")]
#>         specimen operator mm_per_px has_scalebar
#> fish_01  fish_01 ml_morph      0.22         TRUE
#> fish_02  fish_02 ml_morph        NA        FALSE

# Joining a species table by an identifications `code`:
ident <- data.frame(code = c("fish_01", "fish_02"),
                     species = c("Gobio occitaniae", "Squalius cephalus"))
lm2 <- read_mlmorph_landmarks(mes, metadata = ident, by = "code")
#> Measure table: 2 individual(s) x 3 landmark(s) (6 rows).
#> Warning: 1 individual(s) without a calibration scale (mm_per_px all NA); their measurements cannot be converted to length units and will stay NA. Affected: fish_02
table(lm2$metadata$species, useNA = "ifany")
#> 
#>  Gobio occitaniae Squalius cephalus 
#>                 1                 1 

# A table from the repeat mode of digitize_landmarks(): the same two fish,
# each digitized twice by operator "AT". Ask for the identifiers to be
# decomposed into individual / operator / replicate.
rep_tab <- data.frame(
  specimen = rep(c("fish_01_AT_rep1", "fish_01_AT_rep2",
                   "fish_02_AT_rep1", "fish_02_AT_rep2"), each = 3),
  landmark = rep(1:3, times = 4),
  X = c(10, 15, 20, 10.4, 15.2, 19.6, 11, 16, 21, 11.3, 15.7, 21.2),
  Y = c(20, 25, 20, 20.3, 24.6, 20.2, 21, 26, 21, 20.8, 26.4, 20.9)
)
lm3 <- read_mlmorph_landmarks(rep_tab, scale_col = NULL,
                              replicate = "parse", operator = "parse")
#> Measure table: 4 individual(s) x 3 landmark(s) (12 rows).
#> Parsed 4 replicated identifier(s): 2 individual(s), 2 replicate(s) per individual (median).
lm3$metadata[c("specimen", "individual", "operator", "replicate")]
#>                        specimen individual operator replicate
#> fish_01_AT_rep1 fish_01_AT_rep1    fish_01       AT         1
#> fish_01_AT_rep2 fish_01_AT_rep2    fish_01       AT         2
#> fish_02_AT_rep1 fish_02_AT_rep1    fish_02       AT         1
#> fish_02_AT_rep2 fish_02_AT_rep2    fish_02       AT         2
```
