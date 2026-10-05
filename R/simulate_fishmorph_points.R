#' Simulate landmark data following the FISHMORPH point digitization scheme
#'
#' Generates a simulated data set of 21 (or 22) landmarks per specimen,
#' positioned following the Brosse et al. (2021) FISHMORPH digitization
#' scheme (see [fishmorph_segments()]), for several simulated "species"
#' with distinct body proportions. This removes any dependency on real
#' digitized pictures for examples, teaching, and testing of
#' [fishmorph_segments()], [fishmorph_ratios()], [trait_space()], and
#' [plot_fishmorph_points()].
#'
#' @param n_per_species Integer, number of individuals simulated per
#'   species. Defaults to `15`.
#' @param species Character vector of species labels. Defaults to
#'   `c("Species_A", "Species_B", "Species_C")`, simulated with
#'   increasingly elongate-to-deep body proportions.
#' @param n_replicates Integer, number of digitization replicates
#'   simulated per individual (`1` for no replication). Defaults to `1`.
#' @param curvature Logical, also simulate a 22nd landmark for body
#'   curvature correction of standard length (see [fishmorph_segments()]).
#'   Defaults to `FALSE` (21 landmarks only, straight-line body length).
#' @param scale_cm Numeric, real-world distance in centimetres represented
#'   by the simulated scale bar (landmarks 20-21). Defaults to `1`.
#' @param px_per_cm Numeric, digitization units per centimetre used to
#'   build the simulated scale bar and body proportions (arbitrary; only
#'   the ratio to body landmark coordinates matters). Defaults to `12`.
#' @param seed Integer or `NULL`. Random seed for reproducibility. Defaults
#'   to `123`.
#'
#' @return An object of class `"intrait_landmarks"` (see [read_tps()]),
#'   with 21 (or 22) landmarks per specimen in the fixed order described in
#'   [fishmorph_segments()], and `metadata` columns `specimen`,
#'   `individual`, `species`, `population`, and `replicate`. `scale` is set
#'   to `NULL` (the scale bar is embedded as landmarks 20-21, per the
#'   FISHMORPH scheme, rather than carried as external metadata).
#'
#' @details
#' This landmark scheme mixes true body-shape landmarks (1-19) with an
#' external scale-bar reference (20-21) and, optionally, a non-homologous
#' curvature-correction point (22); it is intended for use with
#' [fishmorph_segments()], not for Generalised Procrustes Analysis
#' ([gpa_fish()]), which assumes all landmarks are homologous shape
#' coordinates.
#'
#' @seealso [fishmorph_segments()], [fishmorph_ratios()],
#'   [plot_fishmorph_points()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 2)
#' fish
#' head(fish$metadata)
#'
#' @export
simulate_fishmorph_points <- function(n_per_species = 15,
                                       species = c("Species_A", "Species_B", "Species_C"),
                                       n_replicates = 1,
                                       curvature = FALSE,
                                       scale_cm = 1,
                                       px_per_cm = 12,
                                       seed = 123) {
  if (!is.null(seed)) set.seed(seed)
  n_landmarks <- if (curvature) 22L else 21L

  # base template (arbitrary digitization units), landmarks 1-19 (body),
  # 20-21 (scale bar), optionally 22 (body-curvature correction point)
  template <- matrix(
    c(
       2,  8,  # 1  snout tip / top of mouth
      88, 10,  # 2  caudal fin basis
      35, 30,  # 3  body depth: top
      35,  0,  # 4  body depth: bottom
      12, 22,  # 5  head depth: top of head
      12,  6,  # 6  head depth: bottom (jaw)
      10, 16,  # 7  eye position: centre of eye
      10,  0,  # 8  eye position: bottom of body
       3,  0,  # 9  mouth height: bottom of body
      16,  8,  # 10 pectoral fin: upper insertion
      16,  0,  # 11 pectoral fin position: bottom of body
      24,  2,  # 12 pectoral fin length: tip of longest ray
      10, 18,  # 13 eye diameter: top of eye
      10, 14,  # 14 eye diameter: bottom of eye
       8,  9,  # 15 corner of the mouth
      82, 18,  # 16 caudal peduncle depth: top
      82,  4,  # 17 caudal peduncle depth: bottom
      92, 26,  # 18 caudal fin depth: top ray tip
      95,  0,  # 19 caudal fin depth: bottom ray tip
      70, -8,  # 20 scale bar point A
      70 + px_per_cm * scale_cm, -8 # 21 scale bar point B
    ),
    ncol = 2, byrow = TRUE
  )
  if (curvature) template <- rbind(template, c(45, 9)) # 22 body-curvature point

  body_idx <- 1:19
  scale_idx <- 20:21
  curve_idx <- if (curvature) 22L else integer(0)

  n_sp <- length(species)
  elong_factor <- seq(1.18, 0.85, length.out = n_sp)
  depth_factor <- seq(0.82, 1.22, length.out = n_sp)

  specimen_id <- character(); individual_v <- character(); species_v <- character()
  population_v <- character(); replicate_v <- integer()
  coords_list <- list()
  idx <- 1L

  for (sp in seq_len(n_sp)) {
    sp_template <- template
    sp_template[body_idx, 1] <- (sp_template[body_idx, 1] - template[1, 1]) * elong_factor[sp] + template[1, 1]
    sp_template[body_idx, 2] <- sp_template[body_idx, 2] * depth_factor[sp]

    for (ind in seq_len(n_per_species)) {
      indiv_template <- sp_template
      indiv_template[body_idx, ] <- indiv_template[body_idx, ] +
        matrix(stats::rnorm(length(body_idx) * 2, sd = 0.6), ncol = 2)

      for (rep_i in seq_len(n_replicates)) {
        rep_template <- indiv_template
        rep_template[body_idx, ] <- rep_template[body_idx, ] +
          matrix(stats::rnorm(length(body_idx) * 2, sd = 0.25), ncol = 2)
        rep_template[scale_idx, ] <- rep_template[scale_idx, ] +
          matrix(stats::rnorm(2 * 2, sd = 0.05), ncol = 2)
        if (curvature) {
          rep_template[curve_idx, ] <- rep_template[curve_idx, ] + stats::rnorm(2, sd = 0.3)
        }

        coords_list[[idx]] <- rep_template
        specimen_id[idx] <- sprintf("%s_ind%02d_rep%d", species[sp], ind, rep_i)
        individual_v[idx] <- sprintf("%s_ind%02d", species[sp], ind)
        species_v[idx] <- species[sp]
        population_v[idx] <- paste0("Pop_", ((ind - 1) %% 2) + 1)
        replicate_v[idx] <- rep_i
        idx <- idx + 1L
      }
    }
  }

  n_tot <- idx - 1L
  A <- array(
    NA_real_,
    dim = c(n_landmarks, 2, n_tot),
    dimnames = list(NULL, c("X", "Y"), specimen_id)
  )
  for (i in seq_len(n_tot)) A[, , i] <- coords_list[[i]]

  metadata <- data.frame(
    specimen = specimen_id,
    individual = individual_v,
    species = species_v,
    population = population_v,
    replicate = replicate_v,
    stringsAsFactors = FALSE,
    row.names = specimen_id
  )

  structure(
    list(coords = A, scale = NULL, metadata = metadata),
    class = "intrait_landmarks"
  )
}
