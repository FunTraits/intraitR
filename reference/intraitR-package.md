# intraitR: Morphological Trait Analysis Toolkit for Freshwater Fish

`intraitR` provides a coherent workflow for the analysis of
morphological traits in freshwater fish, from raw two-dimensional
landmark digitization to derived linear ratios and morphological space,
together with tools to quantify intraspecific morphological variability
and measurement error.

## Workflow

The package is organised around five steps, each covered by one or more
functions:

1.  **Import** raw landmark coordinates with
    [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
    or
    [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)
    (or simulate a data set with
    [`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md)).

2.  **Align** configurations with Generalised Procrustes Analysis using
    [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
    a thin wrapper around
    [`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html).

3.  **Derive traits**: inter-landmark linear distances
    ([`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md))
    and normalised morphological ratios
    ([`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md));
    correct for allometry with
    [`correct_allometry()`](https://funtraits.github.io/intraitR/reference/correct_allometry.md)
    if required.

4.  **Explore shape**: build and plot a morphological space with
    [`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md).

5.  **Assess variability and error**: quantify intraspecific
    morphological variability with
    [`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)
    and
    [`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md),
    measurement error / repeatability from replicated digitization with
    [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md),
    and landmark-level digitization (operator) bias with
    [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md).

## The FISHMORPH protocol

The package additionally implements the specific 21/22-landmark
digitization scheme and trait protocol of the FISHMORPH database (Brosse
et al., 2021):
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
computes the 11 linear measurements of the protocol (with automatic
pixel-to-centimetre conversion via an embedded scale bar),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
derives the 9 unitless FISHMORPH ratios (applying the special-case rules
of Villéger et al., 2010),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
builds a generic functional trait space (PCA or PCoA) from any numeric
trait table, and
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
/
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
visualise and simulate data following this scheme.

## Dependencies

The statistical core of the package (Procrustes superimposition, shape
PCA, Procrustes ANOVA and morphological disparity) is delegated to the
geomorph package, which is the reference implementation of these methods
for the R ecosystem (Adams, Collyer and Kaliontzopoulou, 2024).
`intraitR` focuses on fish-specific conveniences: reading digitization
files, computing ecomorphological ratios, and reporting intraspecific
variability and measurement error in a form directly usable in
ecological analyses.

## References

Adams DC, Collyer ML, Kaliontzopoulou A (2024). geomorph: Software for
geometric morphometric analyses. R package.

Bailey RC, Byrnes J (1990). A new, old method for assessing measurement
error in both univariate and multivariate morphometric studies.
Systematic Zoology, 39(2), 124-130.

Boutic L (2026). Quantification du biais operateur dans la mesure des
traits morphologiques de poissons d'eau douce. Rapport de projet tutore,
L2 BCP BIOMIP, CRBE, unpublished.

Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
Villéger S (2021). FISHMORPH: A global database on morphological traits
of freshwater fishes. Global Ecology and Biogeography, 30(11),
2330-2336.

Fruciano C (2016). Measurement error in geometric morphometrics.
Development Genes and Evolution, 226, 139-158.

Villéger S, Ramos Miranda J, Flores Hernandez D, Mouillot D (2010).
Contrasting changes in taxonomic vs. functional diversity of tropical
fish communities after habitat degradation. Ecological Applications,
20(6), 1512-1522.

## See also

Useful links:

- <https://github.com/FunTraits/intraitR>

- Report bugs at <https://github.com/FunTraits/intraitR/issues>

## Author

**Maintainer**: Aurele Toussaint <aurele.toussaint@cnrs.fr>

Authors:

- Aurele Toussaint <aurele.toussaint@cnrs.fr>
