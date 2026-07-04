# Quantify hierarchical digitization (operator) error from repeated landmark placement, linear measurements, or ratios

Estimates the digitization error introduced by manual landmark placement
from repeated digitizations of the same specimens, and decomposes it
hierarchically across landmarks (or derived traits), individuals,
species and (optionally) sampling sites. For each landmark and each
individual, error is quantified as the dispersion of the repeated
landmark positions around their mean (consensus) position, normalised by
a reference distance so that it is comparable across specimens and
species of different sizes. This implements the protocol developed by
Boutic (2026, unpublished internship report, CRBE / INTRAIT project) to
quantify operator bias in the digitization of freshwater fish
morphological landmarks from French Guiana, prior to estimating
intraspecific trait variability with
[`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md).
The same repeated-digitization design can also be propagated through
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
and
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
via `level`, to ask how much of that raw-landmark noise actually
survives into the derived linear measurements and ecomorphological
ratios used downstream (see Details).

## Usage

``` r
digitization_error(
  landmarks,
  individual,
  species = NULL,
  site = NULL,
  level = c("landmarks", "segments", "ratios"),
  ref_landmarks = c(1, 2),
  exclude_landmarks = NULL,
  exclude_traits = NULL,
  normalization = c("landmarks", "standard_length", "centroid_size"),
  scale_cm = 1,
  no_caudal_fin = FALSE,
  ventral_mouth = FALSE,
  no_pectoral_fin = FALSE,
  digits = 4
)

# S3 method for class 'intrait_digitization_error'
print(x, ...)

# S3 method for class 'intrait_digitization_error'
plot(x, ...)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"` (from
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
  [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
  or
  [`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md))
  in which each individual has been digitized more than once (repeated
  digitization replicates of the same photograph or specimen).

- individual:

  A factor or character vector, with one entry per specimen/replicate in
  `landmarks` (i.e. length `dim(landmarks$coords)[3]`), giving the
  identity of the physical individual each replicate belongs to.
  Required, since replicates of the same individual are typically stored
  as distinct entries in `landmarks$coords`.

- species:

  A factor or character vector of the same length as `individual`,
  giving species identity. Defaults to `landmarks$metadata$species` if
  present.

- site:

  Optional factor or character vector of the same length as
  `individual`, giving a sampling site / population identity, used only
  to annotate the per-individual output (it does not otherwise affect
  the calculation). Defaults to `landmarks$metadata$population` if
  present, otherwise `NULL`.

- level:

  Character, one of `"landmarks"` (default), `"segments"`, or
  `"ratios"`, the level at which digitization error is quantified:
  `"landmarks"` reproduces the original Boutic (2026) protocol exactly,
  on raw digitized (X, Y) coordinates; `"segments"` instead quantifies
  the dispersion of the 11 linear FISHMORPH measurements computed by
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
  from each replicate (`Bl`, `Bd`, `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`,
  `Jl`, `CPd`, `CFd`); `"ratios"` quantifies the dispersion of the 9
  dimensionless FISHMORPH ratios computed by
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  from each replicate's segments (`BEl`, `VEp`, `REs`, `OGp`, `RMl`,
  `BLs`, `PFv`, `PFs`, `CPt`). At `"segments"`/ `"ratios"`, bias for a
  given trait and individual is expressed as a percentage of that
  trait's own consensus (across-replicate mean) value for the individual
  – a coefficient-of-variation-like quantity – since a single shared
  reference distance (as used at `"landmarks"`) would not be meaningful
  across traits of very different scale and units (compare `Bl`, in
  centimetres, to `CPt`, dimensionless); see Details for why this also
  lets `"ratios"` isolate scale-bar-independent shape error.
  `ref_landmarks`, `exclude_landmarks`, and `normalization` only apply
  at `level = "landmarks"`; `exclude_traits` only applies at
  `level = "segments"`/`"ratios"`.

- ref_landmarks:

  For `normalization = "landmarks"`, an integer vector of length 2
  giving the indices of two landmarks whose inter-landmark distance is
  used as a size reference (as in the original protocol, where landmarks
  spanning most of the body were used). Defaults to `c(1, 2)`. Only used
  at `level = "landmarks"`.

- exclude_landmarks:

  Optional integer vector of landmark indices to exclude from the
  analysis entirely (not included in `landmark_individual`,
  `by_landmark`, or any of the aggregated outputs). Use this to drop
  landmarks that are not homologous biological points and so are not
  meaningfully comparable to the others in a hierarchical bias
  decomposition — most notably the embedded scale-bar calibration points
  (landmarks 20-21) of the FISHMORPH digitization scheme
  ([`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)),
  which encode a fixed 1 cm real-world distance rather than a body
  landmark, and whose apparent "bias" mixes true digitization
  imprecision with pixel-to-cm rounding of the scale bar itself.
  Defaults to `NULL` (all landmarks included). Excluded landmarks may
  still be used in `ref_landmarks` for the reference distance, since
  that calculation is independent of the per-landmark decomposition.
  Only used at `level = "landmarks"`; ignored (with a warning) otherwise
  – use `exclude_traits` instead.

- exclude_traits:

  Optional character vector of segment or ratio names (e.g.
  `c("Bd", "CFd")` or `c("BEl", "CPt")`) to exclude from the analysis at
  `level = "segments"`/`"ratios"` – the analogue of `exclude_landmarks`
  at those levels. Defaults to `NULL` (all traits for the chosen `level`
  included). Ignored at `level = "landmarks"`.

- normalization:

  Character, one of `"landmarks"` (default, reproducing the original
  protocol exactly: a single reference distance per **species**,
  computed as the mean distance between `ref_landmarks` over all
  digitized replicates of that species), `"standard_length"` (each
  individual's own mean `standard_length_mm` from `landmarks$metadata`,
  averaged over its replicates), or `"centroid_size"` (each individual's
  own mean landmark configuration centroid size, averaged over its
  replicates, as recommended by Bookstein, 1991, and discussed as a
  methodological improvement in Boutic, 2026). Only used at
  `level = "landmarks"`; at `level = "segments"`/`"ratios"` bias is
  always expressed relative to each trait's own consensus value instead
  (see `level`).

- scale_cm:

  Numeric, passed to
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
  when `level = "segments"`/`"ratios"` (the real-world distance, in
  centimetres, represented by the scale bar at landmarks 20-21; see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).
  Defaults to `1`. Ignored at `level = "landmarks"`.

- no_caudal_fin, ventral_mouth, no_pectoral_fin:

  Passed to
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  when `level = "ratios"` (ignored otherwise); see there for details.
  Default to `FALSE`.

- digits:

  Integer, number of decimal places to round percentages to. Defaults to
  `4`.

- x:

  An object of class `"intrait_digitization_error"`.

- ...:

  Further arguments passed to
  [`graphics::boxplot()`](https://rdrr.io/r/graphics/boxplot.html).

## Value

An object of class `"intrait_digitization_error"`, a list with:

- `landmark_individual`:

  (`level = "landmarks"` only) `data.frame`, one row per individual x
  landmark combination, with `n_rep`, `mean_dist_pct` (mean distance of
  replicates to their consensus position), `sd_dist_pct` (standard
  deviation of that distance across replicates) and `rms_dist_pct`
  (root-mean-square distance), all expressed as a percentage of the
  relevant reference distance.

- `segment_individual`:

  (`level = "segments"` only) `data.frame`, the analogue of
  `landmark_individual` with a `segment` column (one of the 11
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
  measurement names) in place of `landmark`, and
  `mean_dist_pct`/`sd_dist_pct`/`rms_dist_pct` expressed as a percentage
  of that segment's own consensus value for the individual (see
  `level`), rather than of a shared reference distance.

- `ratio_individual`:

  (`level = "ratios"` only) `data.frame`, the analogue of
  `landmark_individual` with a `ratio` column (one of the 9
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  names) in place of `landmark`, likewise expressed as a percentage of
  that ratio's own consensus value.

- `by_landmark`:

  (`level = "landmarks"` only) `data.frame`, one row per landmark,
  aggregating `landmark_individual` across all individuals (mean,
  median, sd of `sd_dist_pct`), ordered by increasing median bias, in
  the spirit of the by-landmark boxplot of Boutic (2026, Figure 3).

- `by_segment`:

  (`level = "segments"` only) the analogue of `by_landmark`, one row per
  segment.

- `by_ratio`:

  (`level = "ratios"` only) the analogue of `by_landmark`, one row per
  ratio.

- `by_individual`:

  `data.frame`, one row per individual, aggregating
  `landmark_individual`/`segment_individual`/ `ratio_individual` across
  landmarks/segments/ratios; the trait-count column is named
  `n_landmarks`, `n_segments`, or `n_ratios` depending on `level`.

- `by_species`:

  `data.frame`, one row per species, aggregating `by_individual` across
  individuals (mean and sd of individual bias).

- `global`:

  One-row `data.frame`, the overall (community-level) digitization bias,
  aggregating `by_individual` across all individuals and species.

- `level`:

  The `level` used.

- `normalization`:

  (`level = "landmarks"` only) the normalization method used; `NA`
  otherwise.

- `reference_distance`:

  (`level = "landmarks"` only) named numeric vector (species-level
  reference distances) if `normalization = "landmarks"`, or a
  per-individual named numeric vector otherwise; `NULL` otherwise.

- `excluded_landmarks`:

  (`level = "landmarks"` only) integer vector of landmark indices
  excluded via `exclude_landmarks`, or `NULL`.

- `excluded_traits`:

  (`level = "segments"`/`"ratios"` only) character vector of
  segment/ratio names excluded via `exclude_traits`, or `NULL`.

Has a dedicated print method; `plot.intrait_digitization_error()`
reproduces the ordered by-landmark (or by-segment/by-ratio) boxplot of
the original report.

Invisibly returns `x`.

Invisibly returns `x`.

## Details

For a given landmark and individual, with replicate coordinates \\(x_i,
y_i)\\, \\i = 1, \dots, n\\, and consensus (mean) position \\(\bar{x},
\bar{y})\\, the Euclidean distance of replicate `i` to the consensus is:
\$\$d_i = \sqrt{(x_i - \bar{x})^2 + (y_i - \bar{y})^2}\$\$
`landmark_individual` reports the mean, standard deviation, and
root-mean-square of \\d_i\\ over the `n` replicates, each expressed as a
percentage of a reference distance (see `normalization`). These three
complementary summaries are all reported because Boutic (2026)'s
original analysis computed all three: `mean_dist_pct` and its own
dispersion across observations were used to report the headline
community-wide bias (0.47%, SD 0.57% in the original French Guiana data
set), while `sd_dist_pct` was used for the hierarchical
species/individual decomposition (Figure 3) and `rms_dist_pct` is the
quantity matching the bias formula given in the report's Methods
section. The bias is then aggregated hierarchically as the (unweighted)
arithmetic mean of the finer-scale bias, from landmark to individual to
species to overall community, mirroring the original protocol exactly
(rather than, e.g., pooling all replicates directly, which would
implicitly weight species/individuals with more replicates or more
landmarks more heavily).

**`level = "segments"`/`"ratios"`.** Each replicate's landmarks are
first collapsed to a single scalar per trait – 11 linear measurements
via
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
(`na_action = "keep"`, so a specimen missing a landmark a given segment
needs simply propagates `NA` for that segment/replicate, exactly as a
missing landmark already propagates `NA` at `level = "landmarks"`), or,
for `level = "ratios"`, 9 further ratios of those segments via
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md).
For a given trait and individual, with replicate values \\v_i\\ and
consensus (mean) \\\bar{v}\\, the (one-dimensional) deviation \\d_i =
\|v_i - \bar{v}\|\\ is expressed as a percentage of \\\bar{v}\\ itself,
i.e. a coefficient-of-variation-like quantity local to that individual
and trait – unlike `level = "landmarks"`, no external reference distance
is involved, since one would not be meaningful across traits of very
different units and scale (`ref_landmarks`, `exclude_landmarks`, and
`normalization` are consequently ignored at these levels; use
`exclude_traits` to drop a segment/ratio from the analysis instead).
\\d_i / \bar{v}\\ is undefined (`NA`) if \\\bar{v} = 0\\, which can
occur for a ratio forced to exactly `0` by `ventral_mouth` or
`no_pectoral_fin` for every replicate of a given individual.

This decomposition exposes a methodologically useful asymmetry between
the two derived levels. Every segment is converted from digitized pixels
to centimetres using that specimen's *own* scale bar (landmarks 20-21,
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)),
digitized independently on every replicate; so `level = "segments"` bias
mixes true body-landmark placement error with this additional,
per-replicate scale-bar digitization noise. A ratio, however, divides
two segments computed from the *same* replicate, so the (possibly noisy)
per-replicate scale factor is a common multiplicative term in numerator
and denominator and cancels out exactly, regardless of how much that
replicate's scale bar itself varied from the specimen's true 1 cm
reference. `level = "ratios"` therefore isolates digitization error
attributable specifically to body-shape (landmark placement), filtering
out scale-bar calibration noise entirely – comparing `by_segment`
against `by_ratio` for the same data set separates these two error
sources (a segment with high bias but whose associated ratios show
little to no bias points to scale-bar digitization, rather than
body-landmark placement, as the dominant source of that segment's
error).

As discussed at length in Boutic (2026), this normalized-Euclidean-
distance approach is a simplification relative to the geometric
morphometric reference standard, which would apply a Generalised
Procrustes superimposition (GPA;
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md))
before quantifying error, and compute a formal repeatability index
(Yezerinac et al., 1992; Fruciano, 2016) or Procrustes ANOVA
([`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md),
`method = "procrustes"`). The approach implemented here operates
directly on raw digitized coordinates (no GPA), which is appropriate
when the goal is specifically to characterise **operator/digitization**
bias landmark by landmark (e.g. to flag landmarks needing a stricter
operational definition, as in Boutic, 2026's Table/Figure 3), rather
than to test for shape differences among groups. Because the
decomposition is landmark by landmark, it should only be applied to a
set of homologous, independently-placed biological landmarks: fixed
calibration points such as a digitized scale bar (e.g. landmarks 20-21
of the FISHMORPH scheme) are not body landmarks in this sense and should
be dropped via `exclude_landmarks` before interpreting `by_landmark`,
`by_species`, or `global` (see Examples). For testing shape differences
among groups, or for a size- and rotation-invariant estimate directly
comparable to the wider geometric morphometrics literature, use
`measurement_error(..., method = "procrustes")` instead. The
terminological caveat raised in Boutic (2026) also applies here: what is
quantified is strictly **intra-operator repeatability** (the same single
operator digitizing the same specimens repeatedly), not inter-operator
systematic bias in the strict sense, which would require several
independent operators (Klingenberg & McIntyre, 1998).

## References

Boutic L (2026). Quantification du biais opérateur dans la mesure des
traits morphologiques de poissons d'eau douce. Rapport de projet
tuteuré, L2 BCP BIOMIP, Centre de Recherche sur la Biodiversité et
l'Environnement (CRBE), unpublished, supervised by A. Toussaint.

Bookstein FL (1991). Morphometric tools for landmark data: Geometry and
biology. Cambridge University Press.

Fruciano C (2016). Measurement error in geometric morphometrics.
Development Genes and Evolution, 226(3), 139-158.

Klingenberg CP, McIntyre GS (1998). Geometric morphometrics of
developmental instability: analyzing patterns of fluctuating asymmetry
with Procrustes methods. Evolution, 52(5), 1363-1375.

Yezerinac SM, Lougheed SC, Handford P (1992). Measurement error and
morphometric studies: statistical power and observer experience.
Systematic Biology, 41(4), 471-482.

## See also

[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
[`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md),
[`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)

## Examples

``` r
fish <- simulate_fish_landmarks(n_per_species = 4, n_replicates = 10)
# `individual` identifies which replicates belong to the same specimen
# (simulate_fish_landmarks() encodes it in the specimen/row name):
indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))
derr <- digitization_error(fish, individual = indiv_id)
derr
#> <intrait_digitization_error>
#>  Level: landmarks 
#>  Normalization: landmarks 
#> 
#>  Global digitization bias: 2.201% of reference distance (SD across individuals: 0.331%)
#>  Based on 12 individual(s) from 3 species, 12 landmark(s)
#> 
#>  Least precise landmark(s):
#>  landmark n_individuals mean_bias_pct median_bias_pct sd_bias_pct
#>        12            12        2.2557          2.3140      0.7249
#>         5            12        2.5026          2.3578      0.6972
#>         7            12        2.2648          2.4416      0.5078
#> 
#>  Most precise landmark(s):
#>  landmark n_individuals mean_bias_pct median_bias_pct sd_bias_pct
#>         4            12        2.1101          1.9569      0.7094
#>         9            12        2.1055          1.9842      0.5861
#>        10            12        2.0633          2.0796      0.6407
#> 
#>  Bias by species:
#>    species n_individuals mean_indiv_bias_pct sd_indiv_bias_pct
#>  Species_A             4              2.1201            0.2161
#>  Species_B             4              1.9672            0.3357
#>  Species_C             4              2.5155            0.1718
#>  mean_indiv_dist_pct mean_indiv_rms_pct
#>               4.1639             4.6413
#>               4.0100             4.4409
#>               4.8685             5.4403
derr$by_landmark
#>    landmark n_individuals mean_bias_pct median_bias_pct sd_bias_pct
#> 1         4            12        2.1101          1.9569      0.7094
#> 2         9            12        2.1055          1.9842      0.5861
#> 3        10            12        2.0633          2.0796      0.6407
#> 4        11            12        2.2848          2.0967      0.8333
#> 5         1            12        2.1753          2.1292      0.3825
#> 6         3            12        2.0575          2.1557      0.5397
#> 7         6            12        2.3006          2.1651      0.7680
#> 8         2            12        2.1575          2.2122      0.5061
#> 9         8            12        2.1337          2.2864      0.4045
#> 10       12            12        2.2557          2.3140      0.7249
#> 11        5            12        2.5026          2.3578      0.6972
#> 12        7            12        2.2648          2.4416      0.5078
derr$global
#>   n_individuals n_species global_mean_bias_pct global_sd_bias_pct
#> 1            12         3                2.201             0.3313
#>   global_mean_dist_pct global_mean_rms_pct
#> 1               4.3475              4.8408

# FISHMORPH scheme: landmarks 20-21 are a digitized scale bar, not a
# biological landmark, and should be excluded from the bias
# decomposition (they can still be examined separately if desired, but
# should not be pooled with anatomical landmarks in by_landmark/global):
fish_fm <- load_t26_saudrune_landmarks(source = "repeatability")
derr_fm <- digitization_error(
  fish_fm,
  individual = fish_fm$metadata$individual,
  exclude_landmarks = c(20, 21)
)
#> Warning: Unequal numbers of digitization replicates across individuals; bias estimates for individuals with fewer replicates will be noisier.
derr_fm$by_landmark
#>    landmark n_individuals mean_bias_pct median_bias_pct sd_bias_pct
#> 1         5            25        0.0826          0.0740      0.0340
#> 2        13            25        0.0865          0.0763      0.0387
#> 3        14            25        0.0835          0.0776      0.0327
#> 4         7            25        0.1045          0.0978      0.0370
#> 5        18            25        0.1293          0.1141      0.0710
#> 6         6            25        0.1262          0.1207      0.0480
#> 7        10            25        0.1618          0.1218      0.1077
#> 8        11            25        0.1697          0.1313      0.1051
#> 9        19            25        0.1555          0.1388      0.0794
#> 10        9            25        0.1556          0.1514      0.0397
#> 11       15            25        0.1987          0.1690      0.1212
#> 12        1            25        0.1884          0.1710      0.0902
#> 13        8            25        0.1786          0.1751      0.0489
#> 14       12            25        0.3624          0.2065      0.3330
#> 15       17            25        0.2384          0.2167      0.0983
#> 16        2            25        0.2639          0.2339      0.1404
#> 17       16            25        0.2746          0.2391      0.1322
#> 18        3            25        0.8600          0.8178      0.4349
#> 19        4            25        0.8778          0.8346      0.4815

# level = "segments": does raw-landmark digitization noise survive into
# the 11 linear FISHMORPH measurements? (mixes body-landmark placement
# error with per-replicate scale-bar digitization noise, see Details)
derr_seg <- digitization_error(
  fish_fm, individual = fish_fm$metadata$individual, level = "segments"
)
#> Warning: Unequal numbers of digitization replicates across individuals; bias estimates for individuals with fewer replicates will be noisier.
derr_seg$by_segment
#>    segment n_individuals mean_bias_pct median_bias_pct sd_bias_pct
#> 1       Bl            25        0.6268          0.4653      0.4342
#> 2      CFd            25        0.6325          0.5263      0.3877
#> 3       Bd            25        0.6577          0.5851      0.4597
#> 4       Hd            25        0.8750          0.7894      0.3618
#> 5       Eh            25        1.1976          1.0951      0.5670
#> 6       Mo            25        1.4501          1.1470      0.7697
#> 7      CPd            25        1.4488          1.2289      0.9036
#> 8      PFl            25        2.3623          1.6631      1.8279
#> 9       Ed            25        1.8135          1.7682      0.6782
#> 10     PFi            25        2.2991          2.0702      1.0466
#> 11      Jl            25        4.1454          3.8779      1.7967

# level = "ratios": the 9 dimensionless ratios cancel out any per-
# replicate scale-bar noise, isolating body-shape digitization error --
# comparing this against derr_seg$by_segment separates the two sources:
derr_rat <- digitization_error(
  fish_fm, individual = fish_fm$metadata$individual, level = "ratios"
)
#> Warning: Unequal numbers of digitization replicates across individuals; bias estimates for individuals with fewer replicates will be noisier.
derr_rat$by_ratio
#>   ratio n_individuals mean_bias_pct median_bias_pct sd_bias_pct
#> 1   BEl            25        0.4101          0.3667      0.2175
#> 2   BLs            25        0.6384          0.6242      0.2483
#> 3   VEp            25        1.0805          1.0004      0.4479
#> 4   CPt            25        1.2324          1.0079      0.6369
#> 5   OGp            25        1.2235          1.0202      0.4735
#> 6   PFs            25        2.1608          1.5431      1.7467
#> 7   REs            25        1.7599          1.6705      0.6908
#> 8   PFv            25        2.1531          1.9937      1.0481
#> 9   RMl            25        4.0739          3.9581      1.8080
```
