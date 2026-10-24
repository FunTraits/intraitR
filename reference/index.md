# Package index

## Measurement hub and digitization

The measurement session: a hub over a folder of photographs, an optional
automatic pre-pass, the interactive digitizer (campaign photographs or
the FISHMORPH reference workbook), and the append-only landmark journal
that records every save.

- [`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md)
  : Choose, digitize and check photographs: the measuring hub

- [`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md)
  : Photographs of a folder, with their species and their measured state

- [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  : Automatic landmarking of a batch of photographs (no clicks)

- [`accept_batch_landmarks()`](https://funtraits.github.io/intraitR/reference/accept_batch_landmarks.md)
  : Record the predictions of an automatic pre-pass without reviewing
  them

- [`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md)
  : Install the prediction models

- [`install_mlmorph_python()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_python.md)
  : A Python environment able to run the prediction models

- [`mlmorph_models_dir()`](https://funtraits.github.io/intraitR/reference/mlmorph_models_dir.md)
  : Where the installed prediction models are

- [`mlmorph_models_info()`](https://funtraits.github.io/intraitR/reference/mlmorph_models_info.md)
  : The prediction models installed on this machine

- [`pack_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/pack_mlmorph_models.md)
  : Package the prediction models for distribution

- [`read_batch_landmarks()`](https://funtraits.github.io/intraitR/reference/read_batch_landmarks.md)
  :

  Read the output of
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)

- [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  : Launch the interactive ml-morph landmarking application

- [`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
  : Digitize the FISHMORPH reference workbook

- [`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md)
  : Open a session landmark journal (append-only)

- [`landmark_journal_append()`](https://funtraits.github.io/intraitR/reference/landmark_journal_append.md)
  : Append one record (one digitization) to a landmark journal

- [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md)
  : Read and concatenate every journal in a directory

- [`landmark_journal_status()`](https://funtraits.github.io/intraitR/reference/landmark_journal_status.md)
  : State of the journals in a directory

- [`landmark_journal_history()`](https://funtraits.github.io/intraitR/reference/landmark_journal_history.md)
  : History of the records of one key

- [`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md)
  : Quick quality control of the journals

- [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  : Rebuild the landmark table from the journals

- [`retract_landmarks()`](https://funtraits.github.io/intraitR/reference/retract_landmarks.md)
  : Retract the landmarks of a photograph (it goes back to "not
  measured")

- [`fishmorph_build_db()`](https://funtraits.github.io/intraitR/reference/fishmorph_build_db.md)
  : Rebuild the DuckDB database from the journals

- [`fishmorph_validate()`](https://funtraits.github.io/intraitR/reference/fishmorph_validate.md)
  : Structural AND morphometric control

- [`fishmorph_db_connect()`](https://funtraits.github.io/intraitR/reference/fishmorph_db_connect.md)
  : Open the database (read-only by default)

## Analyses exported as a reproducible project

The analysis part of the workflow on measured fishes, in an application
opened from the hub, and its export as a project with the architecture
of a published paper (numbered scripts, data, results, Methods and
Results report), produced by running the project’s own scripts.

- [`launch_intrait_analyses()`](https://funtraits.github.io/intraitR/reference/launch_intrait_analyses.md)
  : Analyses of measured fishes, exported as a reproducible project
- [`read_digitizer_workbook()`](https://funtraits.github.io/intraitR/reference/read_digitizer_workbook.md)
  : Read a workbook of the digitizer, every landmark included
- [`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md)
  : Write an analysis as a reproducible project (paper architecture)
- [`analysis_params()`](https://funtraits.github.io/intraitR/reference/analysis_params.md)
  : Parameters of an analysis project

## Landmark import

Read landmark data from tpsDig files, generic spreadsheets or earlier
tools; photograph identity; atomic workbook writes; visualise a single
configuration.

- [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
  :

  Import landmark coordinates from a tpsDig (`.tps`) file

- [`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md)
  : Import landmark coordinates from a generic long-format CSV file

- [`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)
  : Import landmark coordinates from a generic "wide"-format Excel sheet

- [`read_mlmorph_landmarks()`](https://funtraits.github.io/intraitR/reference/read_mlmorph_landmarks.md)
  : Import predicted landmarks from an ml-morph / landmarking-app
  measure table

- [`import_legacy_landmarks()`](https://funtraits.github.io/intraitR/reference/import_legacy_landmarks.md)
  : Fold an earlier digitization into the workbook of the landmarking
  app

- [`photo_hash()`](https://funtraits.github.io/intraitR/reference/photo_hash.md)
  : Fingerprint of an image file

- [`photo_hash_cached()`](https://funtraits.github.io/intraitR/reference/photo_hash_cached.md)
  : Fingerprint a batch of images, remembering the answer

- [`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)
  : Match digitized specimens back to renamed photographs

- [`photo_provenance_keys()`](https://funtraits.github.io/intraitR/reference/photo_provenance_keys.md)
  : Provenance keys: which photographs came from the same original

- [`write_xlsx_atomic()`](https://funtraits.github.io/intraitR/reference/write_xlsx_atomic.md)
  : Write a workbook atomically

- [`write_workbook_atomic()`](https://funtraits.github.io/intraitR/reference/write_workbook_atomic.md)
  : Write an openxlsx workbook atomically

- [`plot_landmarks()`](https://funtraits.github.io/intraitR/reference/plot_landmarks.md)
  : Plot a single landmark configuration

- [`print(`*`<intrait_landmarks>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_landmarks.md)
  :

  Print an `"intrait_landmarks"` object

## Superimposition and shape

Landmark quality control (missing-landmark imputation, orientation and
geometry correction), Generalised Procrustes Analysis, allometric
correction, and digitization/outlier quality control.

- [`exclude_specimens()`](https://funtraits.github.io/intraitR/reference/exclude_specimens.md)
  : Exclude known-bad specimens (e.g. mismeasured fish) from a landmark
  data set
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
  [`print(`*`<intrait_segments>`*`)`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
  : Compute linear morphological measurements following the FISHMORPH
  protocol
- [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
  : Compute the nine FISHMORPH unitless ecomorphological ratios
- [`impute_traits()`](https://funtraits.github.io/intraitR/reference/impute_traits.md)
  : Impute missing trait values, and say which cells were invented
- [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
  : Plot a specimen following the FISHMORPH point digitization scheme
- [`plot_fishmorph_shapes()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_shapes.md)
  : Overlay the body shape of every specimen in a species or a set of
  individuals
- [`reexports`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`load_fishmorph_phylogeny`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`load_fishmorph_phylo_axes`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`phylo_pcoa`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`group_colors`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`reset_group_colors`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`max_pair_distance`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`plotly_fishmorph`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`plot_fishmorph_density`](https://funtraits.github.io/intraitR/reference/reexports.md)
  : Objects exported from other packages

## Functional and shape space

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

- [`project_fishmorph()`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md)
  [`print(`*`<intrait_fishmorph_projection>`*`)`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md)
  : Project specimens into the global FISHMORPH functional space

- [`reexports`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`load_fishmorph_phylogeny`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`load_fishmorph_phylo_axes`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`phylo_pcoa`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`group_colors`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`reset_group_colors`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`max_pair_distance`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`plotly_fishmorph`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`plot_fishmorph_density`](https://funtraits.github.io/intraitR/reference/reexports.md)
  : Objects exported from other packages

- [`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md)
  [`print(`*`<intrait_itv_proportion>`*`)`](https://funtraits.github.io/intraitR/reference/itv_proportion.md)
  : Proportion of the global functional diversity captured by projected
  ITV

- [`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md)
  [`print(`*`<intrait_shapespace>`*`)`](https://funtraits.github.io/intraitR/reference/shape_space.md)
  : Build a shape space from Procrustes shape coordinates

- [`plot(`*`<intrait_shapespace>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_shapespace.md)
  : Plot a shape space

- [`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)
  : Test differences in functional trait dispersion between groups

- [`print(`*`<intrait_disparity>`*`)`](https://funtraits.github.io/intraitR/reference/print.intrait_disparity.md)
  :

  Print an `"intrait_disparity"` object

- [`tpd_dissimilarity()`](https://funtraits.github.io/intraitR/reference/tpd_dissimilarity.md)
  [`as.dist(`*`<intrait_tpd_dissim>`*`)`](https://funtraits.github.io/intraitR/reference/tpd_dissimilarity.md)
  [`print(`*`<intrait_tpd_dissim>`*`)`](https://funtraits.github.io/intraitR/reference/tpd_dissimilarity.md)
  : Intraspecific-variability-aware functional dissimilarity between
  species

- [`plot(`*`<intrait_tpd_dissim>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_tpd_dissim.md)
  : Plot the TPD dissimilarity matrix as a heat map

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

## Phylogenetic data and ordination

A bundled reference phylogeny and a phylogenetic PCoA ordination
producing axes directly usable as `traits` in
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
for comparing functional and phylogenetic diversity loss.

- [`reexports`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`load_fishmorph_phylogeny`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`load_fishmorph_phylo_axes`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`phylo_pcoa`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`group_colors`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`reset_group_colors`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`max_pair_distance`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`plotly_fishmorph`](https://funtraits.github.io/intraitR/reference/reexports.md)
  [`plot_fishmorph_density`](https://funtraits.github.io/intraitR/reference/reexports.md)
  : Objects exported from other packages

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

- [`itv_accumulation()`](https://funtraits.github.io/intraitR/reference/itv_accumulation.md)
  [`print(`*`<intrait_itv_accumulation>`*`)`](https://funtraits.github.io/intraitR/reference/itv_accumulation.md)
  : Rarefaction of intraspecific trait variability against sample size

- [`plot(`*`<intrait_itv_accumulation>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_itv_accumulation.md)
  : Plot intraspecific-variability rarefaction curves

- [`fd_accumulation()`](https://funtraits.github.io/intraitR/reference/fd_accumulation.md)
  [`print(`*`<intrait_fd_accumulation>`*`)`](https://funtraits.github.io/intraitR/reference/fd_accumulation.md)
  : Rarefaction of community functional diversity indices against
  sampling effort

- [`plot(`*`<intrait_fd_accumulation>`*`)`](https://funtraits.github.io/intraitR/reference/plot.intrait_fd_accumulation.md)
  : Plot functional-diversity rarefaction curves

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

- [`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md)
  [`print(`*`<intrait_operator_disagreement>`*`)`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md)
  [`plot(`*`<intrait_operator_disagreement>`*`)`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md)
  : Flag individuals whose landmark configuration disagrees across
  operators, and attribute the disagreement to a specific operator

- [`summary_traits()`](https://funtraits.github.io/intraitR/reference/summary_traits.md)
  : Summarise morphological traits by group

## Simulated example data

- [`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md)
  : Simulate a fish landmark data set
- [`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
  : Simulate landmark data following the FISHMORPH point digitization
  scheme

## Real data: T-26 La Saudrune

A real electrofishing landmark data set (Adour-Garonne basin, France)
digitized with
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
plus its blind repeat trial; used throughout the package’s examples and
`demo(pipeline_T26_saudrune)`.

- [`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md)
  : Real freshwater fish landmark data set from an electrofishing
  campaign (T-26, La Saudrune)

- [`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)
  :

  Real T-26 Saudrune landmark data, ready to use as an
  `"intrait_landmarks"` object
