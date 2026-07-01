#' Simulate a fish landmark data set
#'
#' Generates a simulated two-dimensional landmark data set representing
#' several fish "species" with distinct mean body shapes and sizes, several
#' individuals per species drawn from a population, and (optionally)
#' several digitization replicates per individual. This is used throughout
#' the package documentation and vignette to demonstrate the full
#' `intraitR` workflow without requiring real digitized data, and can be
#' used as a starting point (with `set.seed()`) for teaching or for
#' testing analysis code before applying it to real specimens.
#'
#' @param n_per_species Integer, number of individuals simulated per
#'   species. Defaults to `20`.
#' @param species Character vector of species labels. Defaults to
#'   `c("Species_A", "Species_B", "Species_C")`.
#' @param n_landmarks Integer, number of landmarks per configuration
#'   (placed at evenly spaced angles around a fish-body-shaped ellipse).
#'   Defaults to `12`.
#' @param n_replicates Integer, number of digitization replicates
#'   simulated per individual (`1` for no replication). Defaults to `3`.
#' @param seed Integer or `NULL`. Random seed for reproducibility. Defaults
#'   to `123`.
#'
#' @return An object of class `"intrait_landmarks"` (see [read_tps()]),
#'   with `metadata` columns `specimen`, `species`, `population`,
#'   `standard_length_mm` and `replicate`. `scale` is set to `1` for every
#'   specimen (coordinates are already expressed in simulated millimetres).
#'
#' @details
#' Shape is simulated as isotropic Gaussian noise added to a per-species
#' mean ellipse, plus independent per-individual and per-digitization-replicate
#' noise components; centroid size ( proxy for standard length) is drawn
#' from a normal distribution. Because the per-replicate noise is
#' deliberately much smaller than the per-individual and per-species
#' variance components, the simulated data set is well suited to
#' illustrate [intraspecific_variability()] (genuine among-individual and
#' among-species variation) and [measurement_error()] (small, quantifiable
#' digitization noise).
#'
#' @seealso [read_tps()], [gpa_fish()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 2)
#' fish
#' head(fish$metadata)
#'
#' @export
simulate_fish_landmarks <- function(n_per_species = 20,
                                     species = c("Species_A", "Species_B", "Species_C"),
                                     n_landmarks = 12,
                                     n_replicates = 3,
                                     seed = 123) {
  if (!is.null(seed)) set.seed(seed)
  k <- 2

  theta <- seq(0, 2 * pi, length.out = n_landmarks + 1)[-(n_landmarks + 1)]
  base_shape <- cbind(X = cos(theta), Y = sin(theta) * 0.35)

  n_sp <- length(species)
  species_shape <- lapply(seq_len(n_sp), function(i) {
    base_shape * matrix(c(1 + 0.08 * i, 1 - 0.05 * i), nrow = n_landmarks, ncol = 2, byrow = TRUE)
  })

  specimen_id <- character()
  species_v <- character()
  population_v <- character()
  sl_v <- numeric()
  replicate_v <- integer()
  coords_list <- list()
  idx <- 1L

  for (sp in seq_len(n_sp)) {
    for (ind in seq_len(n_per_species)) {
      csize <- stats::rnorm(1, mean = 80, sd = 10)
      indiv_shape <- species_shape[[sp]] +
        matrix(stats::rnorm(n_landmarks * k, sd = 0.025), n_landmarks, k)

      for (rep_i in seq_len(n_replicates)) {
        digitizing_noise <- matrix(stats::rnorm(n_landmarks * k, sd = 0.008), n_landmarks, k)
        shape_r <- (indiv_shape + digitizing_noise) * (csize / 2)

        coords_list[[idx]] <- shape_r
        specimen_id[idx] <- sprintf("%s_ind%02d_rep%d", species[sp], ind, rep_i)
        species_v[idx] <- species[sp]
        population_v[idx] <- paste0("Pop_", ((ind - 1) %% 2) + 1)
        sl_v[idx] <- csize
        replicate_v[idx] <- rep_i
        idx <- idx + 1L
      }
    }
  }

  n_tot <- idx - 1L
  A <- array(
    NA_real_,
    dim = c(n_landmarks, k, n_tot),
    dimnames = list(NULL, c("X", "Y"), specimen_id)
  )
  for (i in seq_len(n_tot)) A[, , i] <- coords_list[[i]]

  metadata <- data.frame(
    specimen = specimen_id,
    species = species_v,
    population = population_v,
    standard_length_mm = round(sl_v, 1),
    replicate = replicate_v,
    stringsAsFactors = FALSE,
    row.names = specimen_id
  )

  structure(
    list(
      coords = A,
      scale = stats::setNames(rep(1, n_tot), specimen_id),
      metadata = metadata
    ),
    class = "intrait_landmarks"
  )
}
