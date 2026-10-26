# Introduction to intraitR

``` r

library(intraitR)
```

## Overview

`intraitR` supports a complete workflow for the analysis of
morphological traits in freshwater fish, from digitized landmark
coordinates to morphological ratios, shape space, intraspecific
variability, and measurement error. This vignette walks through the
workflow end to end using a simulated data set, so that it runs without
any real specimen data.

The statistical core of the package (Generalised Procrustes Analysis,
shape principal component analysis, Procrustes ANOVA and morphological
disparity) is delegated to the `geomorph` package. `intraitR` adds
fish-specific conveniences on top: file import, linear ratios, and
reporting functions geared towards ecomorphological questions.

## 1. Obtaining landmark data

Landmark data can be imported from a `tpsDig`-formatted `.tps` file with
\[read_tps()\], or from a generic long-format CSV/data.frame with
\[read_landmarks_csv()\]. For this vignette we instead simulate a data
set of three artificial species, each digitized three times per
individual, using \[simulate_fish_landmarks()\]:

``` r

set.seed(1)
fish <- simulate_fish_landmarks(
  n_per_species = 15,
  species = c("Species_A", "Species_B", "Species_C"),
  n_landmarks = 12,
  n_replicates = 3
)
fish
#> <intrait_landmarks>
#>   135 specimens, 12 landmarks, 2 dimensions
#>   Scale available for 135/135 specimens
#>   Metadata columns: specimen, species, population, standard_length_mm, replicate
head(fish$metadata)
#>                                  specimen   species population
#> Species_A_ind01_rep1 Species_A_ind01_rep1 Species_A      Pop_1
#> Species_A_ind01_rep2 Species_A_ind01_rep2 Species_A      Pop_1
#> Species_A_ind01_rep3 Species_A_ind01_rep3 Species_A      Pop_1
#> Species_A_ind02_rep1 Species_A_ind02_rep1 Species_A      Pop_2
#> Species_A_ind02_rep2 Species_A_ind02_rep2 Species_A      Pop_2
#> Species_A_ind02_rep3 Species_A_ind02_rep3 Species_A      Pop_2
#>                      standard_length_mm replicate
#> Species_A_ind01_rep1               74.4         1
#> Species_A_ind01_rep2               74.4         2
#> Species_A_ind01_rep3               74.4         3
#> Species_A_ind02_rep1               95.3         1
#> Species_A_ind02_rep2               95.3         2
#> Species_A_ind02_rep3               95.3         3
```

Every specimen in `fish$metadata` is tagged with its species,
population, simulated standard length, and digitization replicate
number.

A single configuration can be inspected visually with
\[plot_landmarks()\]:

``` r

plot_landmarks(fish, specimen = 1)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-3-1.png)

When the original specimen photographs are available,
[`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
(and \[plot_fishmorph_points()\], below) can overlay the landmarks
directly on the photograph via `background_image`, a useful visual check
that no landmark was placed off the body outline:

``` r

plot_landmarks(fish, specimen = 1, background_image = "specimen1.jpg")
```

If landmarks have not yet been digitized, \[digitize_landmarks()\]
launches a bundled Shiny application for predictor-assisted
digitization. The session is declared at the console – the photograph
folder, the output workbook, the operator, the working queue – and
everything it produces goes to one workbook (a `measurements` sheet, a
`bias` sheet holding the repeated digitizations, and a `bias_summary`
sheet quantifying them), backed by an append-only journal that survives
a crash. A trained ml-morph model can propose the 19 FISHMORPH landmarks
from a few clicks per specimen, which are then reviewed and corrected.
It requires a live interactive session (and, for the prediction step
only, the models and the Python environment installed once per machine
with
[`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md)
and
[`install_mlmorph_python()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_python.md)),
so it cannot be run inside this vignette, but the intended usage is:

``` r

# Digitize a folder of photographs into one workbook:
digitize_landmarks(
  photo_dir        = "T26/photos",
  xlsx_path        = "T26/T26_landmarks.xlsx",
  journal_dir      = "T26/landmark_journal",   # default
  operator         = "AT",
  xlsx_flush_every = 10,
  mode             = "new"
)

# Read the measurements back into an "intrait_landmarks" object:
lm <- read_landmarks_xlsx("T26/T26_landmarks.xlsx", sheet = "measurements",
                          n_landmarks = 22, x_pattern = "{i}_X",
                          y_pattern = "{i}_Y", id_cols = "specimen")

# After a crash, the workbook is rebuilt from the journals:
consolidate_landmarks("T26/landmark_journal")
```

Digitization error and operator bias are measured with the same call and
`mode = "repeat"`, which keeps the app on the same photograph and saves
each blind pass to the `bias` sheet; the result feeds
\[measurement_error()\] and \[operator_disagreement()\] directly.

## 2. Generalised Procrustes Analysis

\[gpa_fish()\] superimposes all configurations, removing differences in
position, orientation and scale:

``` r

gpa <- gpa_fish(fish)
gpa
#> <intrait_gpa> Procrustes-aligned landmark configurations
#>   135 specimens, 12 landmarks, 2 dimensions
#>   Converged in 2 iteration(s)
#>   Centroid size: mean = 118.551, range = [81.630, 145.831]
#>   No Procrustes-distance outliers flagged (see $outlier_screen)
```

`gpa$Csize` holds centroid size, the standard size measure retained
alongside Procrustes shape coordinates.

## 3. Linear distances and morphological ratios

Classical fish morphometric traits are expressed as ratios of linear
inter-landmark distances to a reference distance (typically standard
length). Distance pairs are defined by landmark index and computed on
the **raw** (pre-Procrustes) coordinates, since Procrustes
superimposition removes size:

``` r

distances <- list(SL = c(1, 7), BD = c(3, 10), HL = c(1, 4))
morpho_ratios(fish, distances, norm_by = "SL")[1:5, ]
#>                                  specimen   species population
#> Species_A_ind01_rep1 Species_A_ind01_rep1 Species_A      Pop_1
#> Species_A_ind01_rep2 Species_A_ind01_rep2 Species_A      Pop_1
#> Species_A_ind01_rep3 Species_A_ind01_rep3 Species_A      Pop_1
#> Species_A_ind02_rep1 Species_A_ind02_rep1 Species_A      Pop_2
#> Species_A_ind02_rep2 Species_A_ind02_rep2 Species_A      Pop_2
#>                      standard_length_mm replicate BD_ratio HL_ratio
#> Species_A_ind01_rep1               74.4         1   0.3938   0.5144
#> Species_A_ind01_rep2               74.4         2   0.3935   0.5166
#> Species_A_ind01_rep3               74.4         3   0.3943   0.5132
#> Species_A_ind02_rep1               95.3         1   0.3829   0.5181
#> Species_A_ind02_rep2               95.3         2   0.3926   0.5158
```

## 4. Shape space

A shape space is built from a Principal Component Analysis of the
Procrustes shape coordinates. By default,
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) displays each
group as its individual points, a “spider” of dashed segments linking
every point to its group mean, the group mean itself, and a 95%
dispersion ellipse (`style = "spider"`); pass `style = "hull"` for a
classical convex-hull display, `style = "density"` for a non-parametric
kernel-density contour (useful when a group’s points are visibly skewed
or multimodal, so a bivariate-normal ellipse would be a poor fit), or
`style = "none"` for plain points. The group legend is drawn just
outside the plot box by default (`legend_position = "outside"`), so it
never overlaps the data; pass a standard
[`legend()`](https://rdrr.io/r/graphics/legend.html) keyword
(e.g. `"topright"`) to draw it inside the plot box instead, as in
previous versions. Axis limits are computed to fully contain the
ellipse/hull/contour, not just the raw points, so none of these are ever
clipped at the plot box edge. When `groups` represents species identity,
`legend_title`, `legend_italic`, and `abbreviate_species` produce a
properly typeset “Species” legend (e.g. `"Barbatula barbatula"`
displayed as italic *B. barbatula*):

``` r

ms <- shape_space(gpa, groups = fish$metadata$species)
ms
#> <intrait_shapespace>
#>   Axes PC1/PC2, variance explained: 37.1% / 7.7%
#>   135 specimens, 3 groups
plot(ms, legend_title = "Species", legend_italic = TRUE, abbreviate_species = TRUE)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-8-1.png)

``` r

plot(ms, style = "hull", legend_title = "Species", legend_italic = TRUE,
     abbreviate_species = TRUE)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-8-2.png)

``` r

plot(ms, style = "density", legend_title = "Species", legend_italic = TRUE,
     abbreviate_species = TRUE)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-8-3.png)

## 5. Intraspecific morphological variability

\[intraspecific_variability()\] reports both a shape-based disparity
measure (Procrustes variance per group, with a permutation test) and
classical coefficients of variation for chosen linear traits:

``` r

ratios <- morpho_ratios(fish, distances, norm_by = "SL")
iv <- intraspecific_variability(
  gpa = gpa,
  groups = fish$metadata$species,
  traits = ratios[, c("BD_ratio", "HL_ratio")],
  iter = 199
)
iv
#> <intrait_variability>
#> -- Shape (Procrustes variance) disparity --
#> 
#> Call:
#> geomorph::morphol.disparity(f1 = coords ~ 1, groups = ~groups,  
#>     iter = iter, data = gdf, print.progress = FALSE) 
#> 
#> 
#> 
#> Randomized Residual Permutation Procedure Used
#> 200 Permutations
#> 
#> Procrustes variances for defined groups
#>   Species_A   Species_B   Species_C 
#> 0.002775240 0.001398002 0.002362385 
#> 
#> 
#> Pairwise absolute differences between variances
#>              Species_A    Species_B    Species_C
#> Species_A 0.0000000000 0.0013772378 0.0004128544
#> Species_B 0.0013772378 0.0000000000 0.0009643834
#> Species_C 0.0004128544 0.0009643834 0.0000000000
#> 
#> 
#> P-Values
#>           Species_A Species_B Species_C
#> Species_A     1.000     0.005     0.035
#> Species_B     0.005     1.000     0.005
#> Species_C     0.035     0.005     1.000
#> 
#> 
#> -- Coefficient of variation (%) of linear traits --
#>      group    trait  n      mean         sd cv_percent
#>  Species_A BD_ratio 45 0.3828511 0.02152809   5.623096
#>  Species_B BD_ratio 45 0.3580489 0.01574101   4.396330
#>  Species_C BD_ratio 45 0.3381333 0.01598622   4.727785
#>  Species_A HL_ratio 45 0.5239222 0.01210852   2.311130
#>  Species_B HL_ratio 45 0.5190244 0.01362550   2.625213
#>  Species_C HL_ratio 45 0.5137244 0.01029254   2.003514
```

\[itv_index()\] complements this with a formal variance-partitioning
approach (Violle et al., 2012; de Bello et al., 2011): the percentage of
each trait’s total variance that lies *within* species (intraspecific
trait variability, ITV) versus *between* species (interspecific):

``` r

itv <- itv_index(ratios[, c("BD_ratio", "HL_ratio")], groups = fish$metadata$species)
itv
#> <intrait_itv> (species-level) 
#>   2 trait(s), 3 groups
#> 
#> -- Per trait --
#>     trait ss_total ss_between ss_within pct_interspecific pct_itv
#>  BD_ratio   0.0877     0.0452    0.0425           51.5009 48.4991
#>  HL_ratio   0.0216     0.0023    0.0193           10.8273 89.1727
#> 
#> -- Multivariate summary (standardised traits) --
#>  ss_total ss_between ss_within pct_interspecific pct_itv
#>       268    83.5197  184.4803           31.1641 68.8359
plot(itv)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-10-1.png)

Because `fish$metadata` also records a `population` nested within each
species, the ITV component can be split further into a
between-population and a within-population (residual) part, following
the within-/among-population distinction commonly used in ITV
meta-analyses (e.g. Siefert et al., 2015):

``` r

itv_nested <- itv_index(
  ratios[, c("BD_ratio", "HL_ratio")],
  groups = fish$metadata$species,
  nested = fish$metadata$population
)
itv_nested
#> <intrait_itv> (nested: species / population) 
#>   2 trait(s), 3 groups, 6 nested levels
#> 
#> -- Per trait --
#>     trait ss_total ss_between ss_population ss_residual ss_within
#>  BD_ratio   0.0877     0.0452        0.0065      0.0360    0.0425
#>  HL_ratio   0.0216     0.0023        0.0005      0.0188    0.0193
#>  pct_interspecific pct_itv pct_itv_between_pop pct_itv_within_pop
#>            51.5009 48.4991              7.4186            41.0806
#>            10.8273 89.1727              2.1858            86.9870
#> 
#> -- Multivariate summary (standardised traits) --
#>  ss_total ss_between ss_population ss_residual ss_within pct_interspecific
#>       268    83.5197       12.8698    171.6105  184.4803           31.1641
#>  pct_itv pct_itv_between_pop pct_itv_within_pop
#>  68.8359              4.8022            64.0338
plot(itv_nested)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-11-1.png)

## 6. Measurement error

Since our simulated data set includes three digitization replicates per
individual, \[measurement_error()\] can quantify how much of the
observed variance is attributable to digitization noise rather than
genuine biological variation, following a Procrustes ANOVA (Fruciano,
2016):

``` r

individual_id <- sub("_rep[0-9]+$", "", fish$metadata$specimen)

me <- measurement_error(gpa, individual = individual_id, method = "procrustes", iter = 199)
me
#> <intrait_measurement_error>
#>  Method: Procrustes ANOVA measurement error (Fruciano, 2016) 
#> 
#>             Df       SS        MS     Rsq     F      Z Pr(>F)   
#> individual  44 0.281112 0.0063889 0.95583 44.26 10.003  0.005 **
#> Residuals   90 0.012991 0.0001443 0.04417                       
#> Total      134 0.294103                                         
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
```

For a single univariate trait (e.g. body depth ratio measured on the
same individuals multiple times), the classical ANOVA-based percent
measurement error and repeatability (Bailey & Byrnes, 1990) are also
available:

``` r

me_ratio <- measurement_error(
  data.frame(value = ratios$BD_ratio, individual = individual_id),
  individual = "individual",
  method = "anova"
)
me_ratio
#> <intrait_measurement_error>
#>  Method: ANOVA-based measurement error (Bailey & Byrnes, 1990) 
#> 
#>             Df   Sum Sq   Mean Sq F value    Pr(>F)    
#> individual  44 0.085200 0.0019364  69.403 < 2.2e-16 ***
#> Residuals   90 0.002511 0.0000279                      
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> 
#>  Percent measurement error (%ME): 1.42%
#>  Repeatability (R): 0.958
```

## 7. Allometry correction (optional)

If species differ substantially in size, \[correct_allometry()\] removes
the shape variation linearly associated with log centroid size before
further analysis:

``` r

corrected <- correct_allometry(gpa, method = "group", groups = fish$metadata$species)
dim(corrected)
#> [1]  12   2 135
```

## 8. The FISHMORPH protocol (Brosse et al., 2021)

`intraitR` also implements the specific digitization and trait protocol
used to build the FISHMORPH database (Brosse et al., 2021), based on a
fixed scheme of 21 landmarks per specimen (snout, caudal fin basis, body
depth, head depth, eye position and diameter, mouth, pectoral fin,
caudal peduncle depth, caudal fin depth) plus an embedded scale bar, and
optionally a 22nd point to correct standard length for body curvature in
the picture.

From here on the vignette works on **real data**: the T-26
electrofishing survey of the Saudrune, 494 fish of seven species
photographed in the field on two dates and digitized specimen by
specimen with \[digitize_landmarks()\]. This is the data set the package
ships as its reference example, and the one the rest of this document
uses; the simulated generators above remain useful for teaching a
function’s shape, but the behaviour that matters — missing points,
unequal sample sizes, specimens whose scale bar was never placed — only
appears on a real survey.

The campaign was digitized on the 25-point scheme: the 19 anatomical
landmarks and the scale bar as above, plus the curvature point 22, the
derived head base 23, and the two entry hinges 24–25 that record the
broken axis a bent specimen was digitized under.

``` r

fishmorph_fish <- load_t26_saudrune_landmarks()
dim(fishmorph_fish$coords)
#> [1]  25   2 494
table(fishmorph_fish$metadata$species)
#> 
#>     Barbatula barbatula           Barbus barbus             Gobio gobio 
#>                      17                      30                     288 
#>        Lepomis gibbosus Leuciscus burdigalensis       Perca fluviatilis 
#>                       9                       4                      20 
#>       Squalius cephalus 
#>                     126
plot_fishmorph_points(fishmorph_fish, specimen = 1)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-15-1.png)

\[fishmorph_segments()\] computes the 11 linear measurements of the
protocol directly from the digitized points, automatically converting
pixel units to centimetres using the embedded scale bar (landmarks
20-21). Six photographs of this survey have no usable scale bar: by
default (`scale_action = "na"`) their measurements, and therefore their
ratios, would be `NA`. Because the 9 ratios are quotients of segments of
the same photograph, they do not need the scale:
`scale_action = "pixels"` keeps these specimens, their segments in
pixels (column `scale_units`), their ratios exact.

``` r

segments <- fishmorph_segments(fishmorph_fish, scale_action = "pixels")
#> scale_action = "pixels": 6 specimen(s) have a zero-length or missing scale bar (points 20-21); their measurements are returned in PIXELS (scale_units == "px"), the other 488 in centimetres. The nine ratios are unaffected; absolute values are not comparable across the two units.
table(segments$scale_units)
#> 
#>  cm  px 
#> 488   6
head(segments)
#>                                                            specimen
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0001
#> SAUDRUNESUDTOULOUSE_20260427_0002 SAUDRUNESUDTOULOUSE_20260427_0002
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0003
#> SAUDRUNESUDTOULOUSE_20260427_0004 SAUDRUNESUDTOULOUSE_20260427_0004
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0005
#> SAUDRUNESUDTOULOUSE_20260427_0006 SAUDRUNESUDTOULOUSE_20260427_0006
#>                                                          individual
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0001
#> SAUDRUNESUDTOULOUSE_20260427_0002 SAUDRUNESUDTOULOUSE_20260427_0002
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0003
#> SAUDRUNESUDTOULOUSE_20260427_0004 SAUDRUNESUDTOULOUSE_20260427_0004
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0005
#> SAUDRUNESUDTOULOUSE_20260427_0006 SAUDRUNESUDTOULOUSE_20260427_0006
#>                                             species population replicate
#> SAUDRUNESUDTOULOUSE_20260427_0001       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0002       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0003       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0004 Squalius cephalus       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0005       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0006       Gobio gobio       <NA>         1
#>                                   operator species_code quality     date
#> SAUDRUNESUDTOULOUSE_20260427_0001       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0002       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0003       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0004       AT       SQUCEP       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0005       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0006       AT       GOBGOB       3 20260427
#>                                                                 uid        Bl
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0001  6.967764
#> SAUDRUNESUDTOULOUSE_20260427_0002 SAUDRUNESUDTOULOUSE_20260427_0002  8.432734
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0003  7.253563
#> SAUDRUNESUDTOULOUSE_20260427_0004 SAUDRUNESUDTOULOUSE_20260427_0004 18.141961
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0005  5.647264
#> SAUDRUNESUDTOULOUSE_20260427_0006 SAUDRUNESUDTOULOUSE_20260427_0006  7.870956
#>                                         Bd        Hd       Eh        Mo
#> SAUDRUNESUDTOULOUSE_20260427_0001 1.797753 0.9478351 1.444919 1.1367640
#> SAUDRUNESUDTOULOUSE_20260427_0002 2.019094 1.1130886 1.639988 1.3758999
#> SAUDRUNESUDTOULOUSE_20260427_0003 1.737973 1.0128922 1.310671 1.1169357
#> SAUDRUNESUDTOULOUSE_20260427_0004 4.565275 1.9679574 2.797703 2.6759801
#> SAUDRUNESUDTOULOUSE_20260427_0005 1.218095 0.8027899 1.021271 0.8658812
#> SAUDRUNESUDTOULOUSE_20260427_0006 1.938835 1.1548407 1.473838 1.2392734
#>                                         PFi      PFl        Ed        Jl
#> SAUDRUNESUDTOULOUSE_20260427_0001 0.7850315 1.233118 0.2058680 0.3064680
#> SAUDRUNESUDTOULOUSE_20260427_0002 0.9330140 1.424398 0.2466172 0.4087650
#> SAUDRUNESUDTOULOUSE_20260427_0003 0.6674649 1.381436 0.3119971 0.3677807
#> SAUDRUNESUDTOULOUSE_20260427_0004 1.2356384 3.087450 0.8790524 0.8318649
#> SAUDRUNESUDTOULOUSE_20260427_0005 0.5061989 1.171174 0.2621636 0.2881316
#> SAUDRUNESUDTOULOUSE_20260427_0006 0.8213690 1.433144 0.3206749 0.4364443
#>                                         CPd      CFd scale_units
#> SAUDRUNESUDTOULOUSE_20260427_0001 0.6882458 2.450131          cm
#> SAUDRUNESUDTOULOUSE_20260427_0002 0.7987811 2.933587          cm
#> SAUDRUNESUDTOULOUSE_20260427_0003 0.6404500 1.717469          cm
#> SAUDRUNESUDTOULOUSE_20260427_0004 1.9823793 6.980833          cm
#> SAUDRUNESUDTOULOUSE_20260427_0005 0.5609858 1.334465          cm
#> SAUDRUNESUDTOULOUSE_20260427_0006 0.6964284 2.776055          cm
#> # 6 of 6 specimen(s) measured in PIXELS (no valid scale bar): SAUDRUNESUDTOULOUSE_20260427_0019, SAUDRUNESUDTOULOUSE_20260427_0126, SAUDRUNESUDTOULOUSE_20260427_0250_i4, ...
#> # The 9 FISHMORPH ratios are valid; absolute values are not comparable across units.
#> #   Use subset(x, scale_units == "cm") for any analysis of absolute size.
```

\[fishmorph_ratios()\] then derives the 9 unitless FISHMORPH ratios from
these measurements. The `no_caudal_fin`, `ventral_mouth`, and
`no_pectoral_fin` arguments implement the special-case rules of Villéger
et al. (2010) for species with unusual morphologies (e.g. no visible
caudal fin, a ventrally positioned mouth, or no pectoral fins):

``` r

fishmorph_traits <- fishmorph_ratios(segments)
head(fishmorph_traits)
#>                                                            specimen
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0001
#> SAUDRUNESUDTOULOUSE_20260427_0002 SAUDRUNESUDTOULOUSE_20260427_0002
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0003
#> SAUDRUNESUDTOULOUSE_20260427_0004 SAUDRUNESUDTOULOUSE_20260427_0004
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0005
#> SAUDRUNESUDTOULOUSE_20260427_0006 SAUDRUNESUDTOULOUSE_20260427_0006
#>                                                          individual
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0001
#> SAUDRUNESUDTOULOUSE_20260427_0002 SAUDRUNESUDTOULOUSE_20260427_0002
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0003
#> SAUDRUNESUDTOULOUSE_20260427_0004 SAUDRUNESUDTOULOUSE_20260427_0004
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0005
#> SAUDRUNESUDTOULOUSE_20260427_0006 SAUDRUNESUDTOULOUSE_20260427_0006
#>                                             species population replicate
#> SAUDRUNESUDTOULOUSE_20260427_0001       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0002       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0003       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0004 Squalius cephalus       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0005       Gobio gobio       <NA>         1
#> SAUDRUNESUDTOULOUSE_20260427_0006       Gobio gobio       <NA>         1
#>                                   operator species_code quality     date
#> SAUDRUNESUDTOULOUSE_20260427_0001       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0002       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0003       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0004       AT       SQUCEP       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0005       AT       GOBGOB       3 20260427
#> SAUDRUNESUDTOULOUSE_20260427_0006       AT       GOBGOB       3 20260427
#>                                                                 uid scale_units
#> SAUDRUNESUDTOULOUSE_20260427_0001 SAUDRUNESUDTOULOUSE_20260427_0001          cm
#> SAUDRUNESUDTOULOUSE_20260427_0002 SAUDRUNESUDTOULOUSE_20260427_0002          cm
#> SAUDRUNESUDTOULOUSE_20260427_0003 SAUDRUNESUDTOULOUSE_20260427_0003          cm
#> SAUDRUNESUDTOULOUSE_20260427_0004 SAUDRUNESUDTOULOUSE_20260427_0004          cm
#> SAUDRUNESUDTOULOUSE_20260427_0005 SAUDRUNESUDTOULOUSE_20260427_0005          cm
#> SAUDRUNESUDTOULOUSE_20260427_0006 SAUDRUNESUDTOULOUSE_20260427_0006          cm
#>                                      BEl    VEp    REs    OGp    RMl    BLs
#> SAUDRUNESUDTOULOUSE_20260427_0001 3.8758 0.8037 0.2172 0.6323 0.3233 0.5272
#> SAUDRUNESUDTOULOUSE_20260427_0002 4.1765 0.8122 0.2216 0.6814 0.3672 0.5513
#> SAUDRUNESUDTOULOUSE_20260427_0003 4.1736 0.7541 0.3080 0.6427 0.3631 0.5828
#> SAUDRUNESUDTOULOUSE_20260427_0004 3.9739 0.6128 0.4467 0.5862 0.4227 0.4311
#> SAUDRUNESUDTOULOUSE_20260427_0005 4.6361 0.8384 0.3266 0.7108 0.3589 0.6591
#> SAUDRUNESUDTOULOUSE_20260427_0006 4.0596 0.7602 0.2777 0.6392 0.3779 0.5956
#>                                      PFv    PFs    CPt
#> SAUDRUNESUDTOULOUSE_20260427_0001 0.4367 0.1770 3.5600
#> SAUDRUNESUDTOULOUSE_20260427_0002 0.4621 0.1689 3.6726
#> SAUDRUNESUDTOULOUSE_20260427_0003 0.3840 0.1904 2.6817
#> SAUDRUNESUDTOULOUSE_20260427_0004 0.2707 0.1702 3.5214
#> SAUDRUNESUDTOULOUSE_20260427_0005 0.4156 0.2074 2.3788
#> SAUDRUNESUDTOULOUSE_20260427_0006 0.4236 0.1821 3.9861
```

Finally, \[trait_space()\] builds a functional trait space from any
numeric trait table — here the 9 FISHMORPH ratios — by Principal
Component Analysis (or Principal Coordinate Analysis,
`method = "pcoa"`). By default, traits are `log10(x + 1)`-transformed
(the `+ 1` accommodating ratios that can legitimately equal 0 under the
Villéger et al., 2010, exception rules) and then centred and scaled to
unit variance before the ordination (`log_transform = TRUE`,
`scale = TRUE`); set either to `FALSE` to skip that step. As with
[`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md),
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) defaults to a
spider/ellipse display per group:

``` r

ratio_cols <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
fts <- trait_space(fishmorph_traits[, ratio_cols], groups = fishmorph_traits$species)
#> flag_outliers: 10 specimen(s) flagged as within-group outlier(s) across 2 group(s) (Gobio gobio, Lepomis gibbosus); this only flags candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was removed automatically. Set remove_outliers = TRUE to exclude them from the ordination, or see $outlier_screen for details.
#> flag_outliers: 1 group(s) have fewer than outlier_min_n = 5 specimens and were not screened (distance still reported, flagged = NA).
fts
#> <intrait_traitspace> (pca)
#>   Axes PC1/PC2, variance explained: 32.2% / 17.6%
#>   494 observations, 9 traits (BEl, VEp, REs, OGp, RMl, BLs, PFv, PFs, CPt)
#>   7 groups
#>   10 potential within-group outlier(s) flagged (see $outlier_screen); most atypical:
#>     SAUDRUNESUDTOULOUSE_20260518_0143_i1 (Gobio gobio): distance = 5.748 (group median 2.192)
#>     SAUDRUNESUDTOULOUSE_20260518_0159_i2 (Gobio gobio): distance = 5.450 (group median 2.192)
#>     SAUDRUNESUDTOULOUSE_20260427_0249 (Gobio gobio): distance = 5.438 (group median 2.192)
#>     SAUDRUNESUDTOULOUSE_20260427_0263 (Barbatula barbatula): distance = 5.028 (group median 2.807)
#>     SAUDRUNESUDTOULOUSE_20260427_0250_i2 (Gobio gobio): distance = 4.932 (group median 2.192)
plot(fts)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-18-1.png)

Missing trait values, common in real ecomorphological data sets, are
handled via the `na_action` argument: `"fail"` (default) errors,
`"omit"` drops incomplete rows, `"impute_mean"`/`"impute_group_mean"`
fill missing values with column or within-group means, and
`"missforest"` uses nonparametric random-forest imputation
([`missForest::missForest()`](https://rdrr.io/pkg/missForest/man/missForest.html),
Stekhoven & Bühlmann, 2012), exploiting correlations among traits (and
`groups`, as an auxiliary predictor) rather than filling every missing
value in a trait with the same mean:

``` r

fts_imputed <- trait_space(
  fishmorph_traits_with_gaps, groups = fishmorph_fish$metadata$species,
  na_action = "missforest"
)
```

Each option reports via
[`message()`](https://rdrr.io/r/base/message.html) how many rows or
values were affected (and, for `"missforest"`, the out-of-bag imputation
error).

\[trait_disparity()\] complements
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
with a permutation test of whether groups differ in multivariate trait
dispersion (the trace of each group’s trait covariance matrix), computed
on the full standardised trait matrix rather than on the two axes shown
in the plot above:

``` r

td <- trait_disparity(fts, iter = 199)
td
#> <intrait_disparity> (199 permutations)
#> -- Trait variance (dispersion) by group --
#>     Barbatula barbatula           Barbus barbus             Gobio gobio 
#>                 10.2014                  4.5090                  5.9711 
#>        Lepomis gibbosus Leuciscus burdigalensis       Perca fluviatilis 
#>                  2.1619                  3.9901                  9.8204 
#>       Squalius cephalus 
#>                  7.3011 
#> 
#> -- Pairwise absolute differences (lower triangle) / p-values (upper triangle) --
#>                         Barbatula barbatula Barbus barbus Gobio gobio
#> Barbatula barbatula                      NA        0.0050      0.0050
#> Barbus barbus                        5.6924            NA      0.2100
#> Gobio gobio                          4.2303        1.4621          NA
#> Lepomis gibbosus                     8.0395        2.3471      3.8092
#> Leuciscus burdigalensis              6.2112        0.5189      1.9810
#> Perca fluviatilis                    0.3809        5.3115      3.8493
#> Squalius cephalus                    2.9003        2.7921      1.3300
#>                         Lepomis gibbosus Leuciscus burdigalensis
#> Barbatula barbatula               0.0050                  0.1000
#> Barbus barbus                     0.3200                  0.9150
#> Gobio gobio                       0.0800                  0.5700
#> Lepomis gibbosus                      NA                  0.5800
#> Leuciscus burdigalensis           1.8283                      NA
#> Perca fluviatilis                 7.6586                  5.8303
#> Squalius cephalus                 5.1392                  3.3109
#>                         Perca fluviatilis Squalius cephalus
#> Barbatula barbatula                0.8900             0.085
#> Barbus barbus                      0.0050             0.035
#> Gobio gobio                        0.0150             0.080
#> Lepomis gibbosus                   0.0100             0.025
#> Leuciscus burdigalensis            0.1150             0.370
#> Perca fluviatilis                      NA             0.140
#> Squalius cephalus                  2.5194                NA
```

\[bootstrap_functional_space()\] asks a related but different question:
does representing species by real individuals, rather than by their
centroid, inflate the estimated functional space (an n-dimensional
convex-hull volume in PCA space)? For each of `n_boot` bootstrap
“communities” it draws one individual at random per species and computes
the resulting convex-hull volume, and compares this distribution to a
single centroid-based reference volume, following Bertrand (2026);
requires the `geometry` package (Suggested, not installed by default):

``` r

bf <- bootstrap_functional_space(fts, n_axes = 2, n_boot = 100)
bf
#> <intrait_bootstrap_fspace> (method = "convexhull")
#>   2 PCA axes retained (49.8% of variance), 7 species
#>   Centroid-based reference richness (FD_ref): 11.08
#>   Bootstrap richness (FD_boot, 100 draws): mean = 15.06, SD = 4.396, 5-95% = [9.495, 24.8]
#>   Difference (mean FD_boot - FD_ref): 3.987 (one-sided bootstrap p = 0.1584)
plot(bf)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-21-1.png)

\[species_sensitivity()\] then asks *which* species drive that
difference: each species’ centroid is replaced, one individual at a
time, by that individual’s own position (every other species fixed at
its centroid), and the resulting percent change in functional richness
is summarised per species as a mean effect and a min-max range
(Bertrand, 2026):

``` r

ss <- species_sensitivity(fts, n_axes = 2)
ss
#> <intrait_species_sensitivity> (method = "convexhull")
#>   2 PCA axes retained (49.8% of variance), 7 species, FD_ref = 11.08
#>   Top 7 species by |mean %change in functional richness|:
#>                  species   n mean_dFD          range_dFD
#>        Squalius cephalus 126   +7.95%  [+0.00%, +69.60%]
#>              Gobio gobio 288   +4.16% [-26.19%, +99.56%]
#>        Perca fluviatilis  20   +4.03%  [+0.00%, +17.41%]
#>      Barbatula barbatula  17   +3.68% [-17.46%, +44.84%]
#>            Barbus barbus  30   +2.96%  [+0.00%, +24.61%]
#>  Leuciscus burdigalensis   4   +2.07% [-17.57%, +40.92%]
#>         Lepomis gibbosus   9   +0.00% [-11.49%, +18.18%]
plot(ss)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-22-1.png)

Both functions accept a `method` argument beyond the default
`"convexhull"`: `"dendrogram"` (UPGMA functional dendrogram branch
length, Petchey & Gaston 2002, no extra package required), `"tpd"`
(Trait Probability Density, Carmona et al. 2019), or `"hypervolume"`
(Gaussian-kernel hypervolume, Blonder et al. 2014, 2018). Since these
four measures are not on the same scale,
\[compare_functional_richness()\] runs several of them on the same data
and tabulates the percent change and bootstrap p-value side by side, so
agreement (or disagreement) across methods can itself be assessed:

``` r

cmp <- compare_functional_richness(fts, methods = c("dendrogram", "convexhull"), n_axes = 2, n_boot = 100)
cmp
#> <intrait_richness_comparison>
#>   2 method(s) requested, 2 succeeded
#>      method status fd_ref fd_boot_mean pct_diff p_value significant
#>  dendrogram     ok   16.9         19.3   +14.2%  0.2277       FALSE
#>  convexhull     ok  11.08        14.46   +30.6%  0.2178       FALSE
#> 
#>   0/2 method(s) agree that individual-based richness significantly
#>   exceeds the centroid-based reference (p < 0.05).
plot(cmp)
```

![](intraitR-intro_files/figure-html/unnamed-chunk-23-1.png)

Because
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
and
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
return plain data frames, they compose directly with
\[summary_traits()\] and \[intraspecific_variability()\] (traits-only
mode) exactly as the ratios from \[morpho_ratios()\] do earlier in this
vignette.

## References

Adams DC, Collyer ML, Kaliontzopoulou A (2024). geomorph: Software for
geometric morphometric analyses. R package.

Bailey RC, Byrnes J (1990). A new, old method for assessing measurement
error in both univariate and multivariate morphometric studies.
Systematic Zoology, 39(2), 124-130.

Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
Villéger S (2021). FISHMORPH: A global database on morphological traits
of freshwater fishes. Global Ecology and Biogeography, 30(11),
2330-2336.

de Bello F, Lavorel S, Albert CH, Thuiller W, Grigulis K, Dolezal J,
Janecek S, Leps J (2011). Quantifying the relative importance of
intraspecific trait variability and interspecific trait turnover for
functional diversity. Methods in Ecology and Evolution, 2(2), 163-174.

Fruciano C (2016). Measurement error in geometric morphometrics.
Development Genes and Evolution, 226, 139-158.

Siefert A, Violle C, Chalmandrier L, et al. (2015). A global
meta-analysis of the relative extent of intraspecific trait variation in
plant communities. Ecology Letters, 18(12), 1406-1419.

Stekhoven DJ, Bühlmann P (2012). MissForest – non-parametric missing
value imputation for mixed-type data. Bioinformatics, 28(1), 112-118.

Villéger S, Ramos Miranda J, Flores Hernandez D, Mouillot D (2010).
Contrasting changes in taxonomic vs. functional diversity of tropical
fish communities after habitat degradation. Ecological Applications,
20(6), 1512-1522.

Violle C, Enquist BJ, McGill BJ, Jiang L, Albert CH, Hulshof C, Jung V,
Messier J (2012). The return of the variance: intraspecific variability
in community ecology. Trends in Ecology & Evolution, 27(4), 244-252.

Winemiller KO (1991). Ecomorphological diversification in lowland
freshwater fish assemblages from five biotic regions. Ecological
Monographs, 61(4), 343-365.

Zelditch ML, Swiderski DL, Sheets HD (2012). Geometric Morphometrics for
Biologists: A Primer (2nd ed). Academic Press.
