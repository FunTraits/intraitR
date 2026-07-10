#' intraitR: Morphological Trait Analysis Toolkit for Freshwater Fish
#'
#' `intraitR` provides a coherent workflow for the analysis of morphological
#' traits in freshwater fish, from raw two-dimensional landmark digitization
#' to derived linear ratios and shape space, together with tools to
#' quantify intraspecific morphological variability and measurement error.
#'
#' @section Workflow:
#' The package is organised around five steps, each covered by one or more
#' functions:
#' \enumerate{
#'   \item **Import** raw landmark coordinates with [read_tps()] or
#'     [read_landmarks_csv()] (or simulate a data set with
#'     [simulate_fish_landmarks()]).
#'   \item **Align** configurations with Generalised Procrustes Analysis
#'     using [gpa_fish()], a thin wrapper around [geomorph::gpagen()].
#'   \item **Derive traits**: inter-landmark linear distances
#'     ([linear_distances()]) and normalised morphological ratios
#'     ([morpho_ratios()]); correct for allometry with
#'     [correct_allometry()] if required.
#'   \item **Explore shape**: build and plot a shape space with
#'     [shape_space()].
#'   \item **Assess variability and error**: quantify intraspecific
#'     morphological variability with [intraspecific_variability()] and
#'     [itv_index()], measurement error / repeatability from replicated
#'     digitization with [measurement_error()], and landmark-level
#'     digitization (operator) bias with [digitization_error()].
#' }
#'
#' @section The FISHMORPH protocol:
#' The package additionally implements the specific 21/22-landmark
#' digitization scheme and trait protocol of the FISHMORPH database
#' (Brosse et al., 2021): [fishmorph_segments()] computes the 11 linear
#' measurements of the protocol (with automatic pixel-to-centimetre
#' conversion via an embedded scale bar), [fishmorph_ratios()] derives the
#' 9 unitless FISHMORPH ratios (applying the special-case rules of
#' Villéger et al., 2010), [trait_space()] builds a generic functional
#' trait space (PCA or PCoA) from any numeric trait table, and
#' [plot_fishmorph_points()] / [simulate_fishmorph_points()] visualise and
#' simulate data following this scheme.
#'
#' @section Dependencies:
#' The statistical core of the package (Procrustes superimposition, shape
#' PCA, Procrustes ANOVA and morphological disparity) is delegated to the
#' \pkg{geomorph} package, which is the reference implementation of these
#' methods for the R ecosystem (Adams, Collyer and Kaliontzopoulou, 2024).
#' `intraitR` focuses on fish-specific conveniences: reading digitization
#' files, computing ecomorphological ratios, and reporting intraspecific
#' variability and measurement error in a form directly usable in
#' ecological analyses.
#'
#' @references
#' Adams DC, Collyer ML, Kaliontzopoulou A (2024). geomorph: Software for
#' geometric morphometric analyses. R package.
#'
#' Bailey RC, Byrnes J (1990). A new, old method for assessing measurement
#' error in both univariate and multivariate morphometric studies.
#' Systematic Zoology, 39(2), 124-130.
#'
#' Boutic L (2026). Quantification du biais operateur dans la mesure des
#' traits morphologiques de poissons d'eau douce. Rapport de projet
#' tutore, L2 BCP BIOMIP, CRBE, unpublished.
#'
#' Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
#' Villéger S (2021). FISHMORPH: A global database on morphological
#' traits of freshwater fishes. Global Ecology and Biogeography, 30(11),
#' 2330-2336.
#'
#' Fruciano C (2016). Measurement error in geometric morphometrics.
#' Development Genes and Evolution, 226, 139-158.
#'
#' Villéger S, Ramos Miranda J, Flores Hernandez D, Mouillot D (2010).
#' Contrasting changes in taxonomic vs. functional diversity of tropical
#' fish communities after habitat degradation. Ecological Applications,
#' 20(6), 1512-1522.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
