# intraitR

`intraitR` is an R package for the analysis of morphological traits in
freshwater fish: from raw landmark digitization to morphological ratios,
morphological space, intraspecific variability, and measurement error. It
builds on the geometric morphometric framework implemented in
[`geomorph`](https://cran.r-project.org/package=geomorph) and adds
fish-specific conveniences for ecomorphological analyses.

## Workflow

1. **Import** landmark coordinates: `read_tps()` (tpsDig files) or
   `read_landmarks_csv()` (generic long-format CSV/data.frame); or
   generate a simulated example data set with `simulate_fish_landmarks()`.
   Alternatively, `digitize_landmarks()` digitizes landmarks interactively
   from specimen photographs (point-and-click) and returns the result
   directly, following either the FISHMORPH scheme or a generic one.
2. **Align** configurations with Generalised Procrustes Analysis:
   `gpa_fish()`.
3. **Derive traits**: inter-landmark linear distances
   (`linear_distances()`) and normalised ecomorphological ratios
   (`morpho_ratios()`); correct for allometry with `correct_allometry()`.
4. **Explore shape**: build and plot a morphological space with
   `morpho_space()`. By default, `plot()` shows each group as its
   individual points, dashed segments linking them to the group mean, the
   group mean itself, and a 95% dispersion ellipse (`style = "spider"`);
   `style = "hull"` recovers the classical convex-hull display.
5. **Assess variability and error**: intraspecific morphological
   variability (`intraspecific_variability()`, combining shape disparity
   and coefficients of variation), measurement error / repeatability from
   replicated digitization (`measurement_error()`), landmark-level
   digitization (operator) bias (`digitization_error()`, following the
   protocol of Boutic, 2026), and the interspecific/intraspecific (ITV)
   partitioning of trait variance (`itv_index()`, optionally split into
   between- and within-population components).

Additional utilities: `plot_landmarks()` and `detect_outliers()` for
quality control of digitization (visual inspection and automatic
Procrustes-distance-based outlier screening, respectively),
`summary_traits()` for tidy group-level summaries, and `trait_disparity()`
for permutation tests of group differences in functional trait
dispersion.

### Digitization error (`digitization_error()`)

For a set of specimens digitized several times each (replicated
landmarking of the same photographs), `digitization_error()` quantifies
how dispersed repeated landmark placements are around their consensus
position, normalised so that bias is comparable across specimens of
different sizes, and aggregated hierarchically from landmark to
individual, species, and overall community bias:

```r
fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 10)
individual_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))
derr <- digitization_error(fish, individual = individual_id)
derr
plot(derr)  # bias by landmark, ordered by increasing median bias
```

This reproduces the protocol used by L. Boutic (internship report, 2026,
CRBE/INTRAIT) to quantify operator bias in French Guiana freshwater fish
landmark digitization: it deliberately operates on raw digitized
coordinates (no Procrustes superimposition) so that bias can be
attributed to individual landmarks (e.g. to flag which ones need a
stricter operational definition), complementing the overall,
rotation/scale-invariant repeatability estimate from
`measurement_error(..., method = "procrustes")`.

## The FISHMORPH protocol (Brosse et al., 2021)

`intraitR` also implements the specific digitization and trait protocol of
the FISHMORPH database (Brosse et al., 2021, *Global Ecology and
Biogeography*), based on a fixed scheme of 21 (optionally 22) landmarks per
specimen:

* `fishmorph_segments()` computes the 11 linear measurements of the
  protocol (`Bl`, `Bd`, `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`,
  `CFd`) directly from digitized points, converting pixels to centimetres
  using an embedded scale bar.
* `fishmorph_ratios()` computes the 9 unitless FISHMORPH ratios (`BEl`,
  `VEp`, `REs`, `OGp`, `RMl`, `BLs`, `PFv`, `PFs`, `CPt`), including the
  special-case rules of Villéger et al. (2010).
* `trait_space()` builds a PCA/PCoA functional trait space from any
  numeric trait table (FISHMORPH ratios or otherwise), by default
  applying a `log10(x + 1)` transformation followed by centring/scaling
  to unit variance before the ordination (`log_transform = TRUE`,
  `scale = TRUE`); `plot()` uses the same spider/ellipse display as
  `morpho_space()`.
* `trait_disparity()` tests whether groups differ in the multivariate
  dispersion of their functional traits (trait variance, i.e. the trace
  of each group's trait covariance matrix), by permutation of group
  labels, computed on the full standardised trait matrix rather than on
  the two axes retained for plotting.
* `trait_space(na_action = ...)` handles missing trait values: `"omit"`,
  `"impute_mean"`, `"impute_group_mean"`, or `"missforest"` (nonparametric
  random-forest imputation via the `missForest` package, using `groups`
  as an auxiliary predictor).
* `plot_fishmorph_points()` and `simulate_fishmorph_points()` visualise
  and simulate data following the 21/22-point scheme.

## Installation

```r
# install.packages("remotes")
remotes::install_github("FunTraits/intraitR")
```

`intraitR` requires the `geomorph` package (available on CRAN):

```r
install.packages("geomorph")
```

## Quick example

```r
library(intraitR)

fish <- simulate_fish_landmarks(n_per_species = 15, n_replicates = 3)
gpa  <- gpa_fish(fish)

distances <- list(SL = c(1, 7), BD = c(3, 10))
ratios    <- morpho_ratios(fish, distances, norm_by = "SL")

ms <- morpho_space(gpa, groups = fish$metadata$species)
plot(ms)

intraspecific_variability(
  gpa = gpa, groups = fish$metadata$species,
  traits = ratios[, "BD_ratio", drop = FALSE]
)
```

See `vignette("intraitR-intro")` for a full walkthrough.

## Real data: the T-26 La Saudrune data set

Beyond simulated examples, `intraitR` ships a real landmark data set from an
electric-fishing survey of the Saudrune (Adour-Garonne basin, France): 279
fish from 8 species, digitized by two independent operators on the
FISHMORPH scheme, plus a 25-fish x 9-10-replicate intra-operator
repeatability trial. See `?load_t26_saudrune` for the data and
`demo("pipeline_T26_saudrune")` for a complete worked pipeline (import,
GPA, quality control, FISHMORPH traits, trait space, `itv_index()`,
`measurement_error()`, `digitization_error()`, `trait_disparity()`) applied
to it end to end.

```r
ops <- load_t26_saudrune("operators")
lm  <- read_landmarks_csv(ops)
```

For the FISHMORPH-specific workflow, `load_t26_saudrune_landmarks()` returns
this same data directly as an `"intrait_landmarks"` object, in exactly the
format produced by `simulate_fishmorph_points()` — a drop-in real-data
replacement used throughout the package's own examples:

```r
fish <- load_t26_saudrune_landmarks()
fishmorph_ratios(fishmorph_segments(fish))
```

## Citation

```r
citation("intraitR")
```

## License

GPL-3. See `LICENSE.md`.
