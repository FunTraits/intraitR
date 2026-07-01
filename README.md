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
   replicated digitization (`measurement_error()`), and the
   interspecific/intraspecific (ITV) partitioning of trait variance
   (`itv_index()`, optionally split into between- and within-population
   components).

Additional utilities: `plot_landmarks()` and `detect_outliers()` for
quality control of digitization (visual inspection and automatic
Procrustes-distance-based outlier screening, respectively),
`summary_traits()` for tidy group-level summaries, and `trait_disparity()`
for permutation tests of group differences in functional trait
dispersion.

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

## Citation

```r
citation("intraitR")
```

## License

GPL-3. See `LICENSE.md`.
