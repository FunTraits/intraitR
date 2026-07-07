# Package index

## Landmark import and digitization

Read landmark data from tpsDig files, generic spreadsheets, or an
interactive digitizer; visualise a single configuration.

- [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
  :

  Import landmark coordinates from a tpsDig (`.tps`) file

- [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)
  : Import landmark coordinates from a generic long-format CSV file

- [`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)
  : Import landmark coordinates from a generic "wide"-format Excel sheet

- [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  : Interactively digitize landmarks from specimen photographs

- [`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
  : Plot a single landmark configuration

- [`print(`*`<intrait_landmarks>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_landmarks.md)
  :

  Print an `"intrait_landmarks"` object

## Superimposition and shape

Landmark quality control (missing-landmark imputation, orientation and
geometry correction), Generalised Procrustes Analysis, allometric
correction, and digitization/outlier quality control.

- [`impute_landmarks()`](https://funtraits.github.io/intraitR/reference/impute_landmarks.md)
  : Impute missing (NA) landmark coordinates
- [`standardize_orientation()`](https://funtraits.github.io/intraitR/reference/standardize_orientation.md)
  : Standardize every specimen to the same head-left, belly-down
  orientation
- [`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md)
  [`print(`*`<intrait_geometry_check>`*`)`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md)
  : Manually correct a misplaced landmark using an alignment rule
- [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)
  : Standardize landmark configurations to a common scale, orientation,
  and geometric convention
- [`standardize_geometry()`](https://funtraits.github.io/intraitR/reference/standardize_geometry.md)
  : Standardize landmark scale, scale-bar position, and rotation,
  without changing any measurement value
- [`correct_geometry_conventions()`](https://funtraits.github.io/intraitR/reference/correct_geometry_conventions.md)
  : Actively correct landmarks that violate the FISHMORPH geometric
  conventions, once the axis is horizontal
- [`fishmorph_shape_landmarks()`](https://funtraits.github.io/intraitR/reference/fishmorph_shape_landmarks.md)
  : Extract complete-case body-shape landmarks from a FISHMORPH
  configuration
- [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
  [`print(`*`<intrait_gpa>`*`)`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
  [`summary(`*`<intrait_gpa>`*`)`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
  [`print(`*`<summary.intrait_gpa>`*`)`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
  : Generalised Procrustes Analysis for fish landmark configurations
- [`correct_allometry()`](https://funtraits.github.io/intraitR/reference/correct_allometry.md)
  : Correct Procrustes shape coordinates for allometry
- [`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)
  [`print(`*`<intrait_outliers>`*`)`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)
  : Detect potential digitization outliers from a GPA-aligned sample

## Morphometric traits and ratios

Classical linear distances and ratios, including the FISHMORPH (Brosse
et al., 2021) 11-measurement/9-ratio protocol.

- [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)
  : Compute inter-landmark linear distances
- [`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md)
  : Compute classical fish morphometric ratios
- [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
  : Compute linear morphological measurements following the FISHMORPH
  protocol
- [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  : Compute the nine FISHMORPH unitless ecomorphological ratios
- [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
  : Plot a specimen following the FISHMORPH point digitization scheme
- [`plot_fishmorph_shapes()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_shapes.md)
  : Overlay the body shape of every specimen in a species or a set of
  individuals

## Functional and morphological space

Build, visualise, and test ordinations of shape or trait data, and
quantify how intraspecific variability (ITV) affects estimated
functional richness.

- [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  [`print(`*`<intrait_traitspace>`*`)`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  : Build a functional trait space from a numeric trait table

- [`plot(`*`<intrait_traitspace>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_traitspace.md)
  : Plot a functional trait space

- [`plot_correlation_circle()`](https://funtraits.github.io/intraitR/reference/plot_correlation_circle.md)
  : Plot the correlation circle of a functional trait space

- [`morpho_space()`](https://funtraits.github.io/intraitR/reference/morpho_space.md)
  [`print(`*`<intrait_morphospace>`*`)`](https://funtraits.github.io/intraitR/reference/morpho_space.md)
  : Build a morphological space from Procrustes shape coordinates

- [`plot(`*`<intrait_morphospace>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_morphospace.md)
  : Plot a morphological space

- [`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)
  : Test differences in functional trait dispersion between groups

- [`print(`*`<intrait_disparity>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_disparity.md)
  :

  Print an `"intrait_disparity"` object

- [`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
  : Bootstrap-based estimate of functional space volume from individual
  data

- [`print(`*`<intrait_bootstrap_fspace>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_bootstrap_fspace.md)
  [`plot(`*`<intrait_bootstrap_fspace>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_bootstrap_fspace.md)
  :

  Print and plot an `"intrait_bootstrap_fspace"` object

- [`species_sensitivity()`](https://funtraits.github.io/intraitR/reference/species_sensitivity.md)
  : Species-level sensitivity index for functional space estimates

- [`print(`*`<intrait_species_sensitivity>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_species_sensitivity.md)
  [`plot(`*`<intrait_species_sensitivity>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_species_sensitivity.md)
  :

  Print and plot an `"intrait_species_sensitivity"` object

- [`compare_functional_richness()`](https://funtraits.github.io/intraitR/reference/compare_functional_richness.md)
  : Compare bootstrap-based functional richness estimates across methods

- [`print(`*`<intrait_richness_comparison>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_richness_comparison.md)
  [`plot(`*`<intrait_richness_comparison>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_richness_comparison.md)
  :

  Print and plot an `"intrait_richness_comparison"` object

- [`group_colors()`](https://funtraits.github.io/intraitR/reference/group_colors.md)
  : Look up the group/species colours used by the ordination plot
  methods

- [`reset_group_colors()`](https://funtraits.github.io/intraitR/reference/reset_group_colors.md)
  : Reset the session-level group/species colour cache

## Phylogenetic data and ordination

A bundled reference phylogeny and a phylogenetic PCoA ordination
producing axes directly usable as `traits` in
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
for comparing functional and phylogenetic diversity loss.

- [`load_fishmorph_phylogeny()`](https://funtraits.github.io/intraitR/reference/load_fishmorph_phylogeny.md)
  :

  Bundled global fish phylogeny, ready to use with
  [`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)

- [`phylo_pcoa()`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)
  [`print(`*`<intrait_phylopcoa>`*`)`](https://funtraits.github.io/intraitR/reference/phylo_pcoa.md)
  : Phylogenetic Principal Coordinates Analysis

## Intraspecific variability and measurement error

Decompose trait variance into interspecific/intraspecific components,
and quantify measurement and digitization error from replicated data.

- [`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md)
  [`print(`*`<intrait_itv>`*`)`](https://funtraits.github.io/intraitR/reference/itv_index.md)
  : Partition trait variance into interspecific and intraspecific (ITV)
  components

- [`plot(`*`<intrait_itv>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_itv.md)
  : Plot the interspecific/intraspecific variance breakdown

- [`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)
  [`print(`*`<intrait_variability>`*`)`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md)
  : Quantify intraspecific morphological variability

- [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
  : Estimate measurement error from replicated digitization

- [`print(`*`<intrait_measurement_error>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_measurement_error.md)
  :

  Print an `"intrait_measurement_error"` object

- [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md)
  [`print(`*`<intrait_digitization_error>`*`)`](https://funtraits.github.io/intraitR/reference/digitization_error.md)
  [`plot(`*`<intrait_digitization_error>`*`)`](https://funtraits.github.io/intraitR/reference/digitization_error.md)
  : Quantify hierarchical digitization (operator) error from repeated
  landmark placement, linear measurements, or ratios

- [`summary_traits()`](https://funtraits.github.io/intraitR/reference/summary_traits.md)
  : Summarise morphological traits by group

## Simulated example data

- [`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md)
  : Simulate a fish landmark data set
- [`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
  : Simulate landmark data following the FISHMORPH point digitization
  scheme

## Real data: T-26 La Saudrune

A real electrofishing landmark data set (Adour-Garonne basin, France),
used throughout the package’s examples and
`demo(pipeline_T26_saudrune)`.

- [`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md)
  : Real freshwater fish landmark data set from an electrofishing
  campaign (T-26, La Saudrune)

- [`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)
  :

  Real T-26 Saudrune landmark data, ready to use as an
  `"intrait_landmarks"` object
