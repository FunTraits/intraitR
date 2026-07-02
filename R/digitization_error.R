#' Quantify hierarchical digitization (operator) error from repeated
#' landmark placement
#'
#' Estimates the digitization error introduced by manual landmark placement
#' from repeated digitizations of the same specimens, and decomposes it
#' hierarchically across landmarks, individuals, species and (optionally)
#' sampling sites. For each landmark and each individual, error is
#' quantified as the dispersion of the repeated landmark positions around
#' their mean (consensus) position, normalised by a reference distance so
#' that it is comparable across specimens and species of different sizes.
#' This implements the protocol developed by Boutic (2026, unpublished
#' internship report, CRBE / INTRAIT project) to quantify operator bias in
#' the digitization of freshwater fish morphological landmarks from French
#' Guiana, prior to estimating intraspecific trait variability with
#' [itv_index()].
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()], [read_landmarks_csv()], or [simulate_fish_landmarks()])
#'   in which each individual has been digitized more than once (repeated
#'   digitization replicates of the same photograph or specimen).
#' @param individual A factor or character vector, with one entry per
#'   specimen/replicate in `landmarks` (i.e. length `dim(landmarks$coords)[3]`),
#'   giving the identity of the physical individual each replicate belongs
#'   to. Required, since replicates of the same individual are typically
#'   stored as distinct entries in `landmarks$coords`.
#' @param species A factor or character vector of the same length as
#'   `individual`, giving species identity. Defaults to
#'   `landmarks$metadata$species` if present.
#' @param site Optional factor or character vector of the same length as
#'   `individual`, giving a sampling site / population identity, used only
#'   to annotate the per-individual output (it does not otherwise affect
#'   the calculation). Defaults to `landmarks$metadata$population` if
#'   present, otherwise `NULL`.
#' @param ref_landmarks For `normalization = "landmarks"`, an integer
#'   vector of length 2 giving the indices of two landmarks whose
#'   inter-landmark distance is used as a size reference (as in the
#'   original protocol, where landmarks spanning most of the body were
#'   used). Defaults to `c(1, 2)`.
#' @param exclude_landmarks Optional integer vector of landmark indices to
#'   exclude from the analysis entirely (not included in
#'   `landmark_individual`, `by_landmark`, or any of the aggregated
#'   outputs). Use this to drop landmarks that are not homologous
#'   biological points and so are not meaningfully comparable to the
#'   others in a hierarchical bias decomposition — most notably the
#'   embedded scale-bar calibration points (landmarks 20-21) of the
#'   FISHMORPH digitization scheme ([fishmorph_segments()]), which encode
#'   a fixed 1 cm real-world distance rather than a body landmark, and
#'   whose apparent "bias" mixes true digitization imprecision with
#'   pixel-to-cm rounding of the scale bar itself. Defaults to `NULL`
#'   (all landmarks included). Excluded landmarks may still be used in
#'   `ref_landmarks` for the reference distance, since that calculation is
#'   independent of the per-landmark decomposition.
#' @param normalization Character, one of `"landmarks"` (default,
#'   reproducing the original protocol exactly: a single reference distance
#'   per **species**, computed as the mean distance between `ref_landmarks`
#'   over all digitized replicates of that species), `"standard_length"`
#'   (each individual's own mean `standard_length_mm` from
#'   `landmarks$metadata`, averaged over its replicates), or
#'   `"centroid_size"` (each individual's own mean landmark configuration
#'   centroid size, averaged over its replicates, as recommended by
#'   Bookstein, 1991, and discussed as a methodological improvement in
#'   Boutic, 2026).
#' @param digits Integer, number of decimal places to round percentages to.
#'   Defaults to `4`.
#'
#' @return An object of class `"intrait_digitization_error"`, a list with:
#'   \describe{
#'     \item{`landmark_individual`}{`data.frame`, one row per
#'       individual x landmark combination, with `n_rep`, `mean_dist_pct`
#'       (mean distance of replicates to their consensus position),
#'       `sd_dist_pct` (standard deviation of that distance across
#'       replicates) and `rms_dist_pct` (root-mean-square distance), all
#'       expressed as a percentage of the relevant reference distance.}
#'     \item{`by_landmark`}{`data.frame`, one row per landmark, aggregating
#'       `landmark_individual` across all individuals (mean, median, sd of
#'       `sd_dist_pct`), ordered by increasing median bias, in the spirit
#'       of the by-landmark boxplot of Boutic (2026, Figure 3).}
#'     \item{`by_individual`}{`data.frame`, one row per individual,
#'       aggregating `landmark_individual` across landmarks.}
#'     \item{`by_species`}{`data.frame`, one row per species, aggregating
#'       `by_individual` across individuals (mean and sd of individual
#'       bias).}
#'     \item{`global`}{One-row `data.frame`, the overall (community-level)
#'       digitization bias, aggregating `by_individual` across all
#'       individuals and species.}
#'     \item{`normalization`}{The normalization method used.}
#'     \item{`reference_distance`}{Named numeric vector (species-level
#'       reference distances) if `normalization = "landmarks"`, or a
#'       per-individual named numeric vector otherwise.}
#'     \item{`excluded_landmarks`}{Integer vector of landmark indices
#'       excluded from the analysis via `exclude_landmarks`, or `NULL`.}
#'   }
#'   Has a dedicated print method; [plot.intrait_digitization_error()]
#'   reproduces the ordered by-landmark boxplot of the original report.
#'
#' @details
#' For a given landmark and individual, with replicate coordinates
#' \eqn{(x_i, y_i)}, \eqn{i = 1, \dots, n}, and consensus (mean) position
#' \eqn{(\bar{x}, \bar{y})}, the Euclidean distance of replicate `i` to the
#' consensus is:
#' \deqn{d_i = \sqrt{(x_i - \bar{x})^2 + (y_i - \bar{y})^2}}
#' `landmark_individual` reports the mean, standard deviation, and
#' root-mean-square of \eqn{d_i} over the `n` replicates, each expressed as
#' a percentage of a reference distance (see `normalization`). These three
#' complementary summaries are all reported because Boutic (2026)'s
#' original analysis computed all three: `mean_dist_pct` and its own
#' dispersion across observations were used to report the headline
#' community-wide bias (0.47%, SD 0.57% in the original French Guiana
#' data set), while `sd_dist_pct` was used for the hierarchical
#' species/individual decomposition (Figure 3) and `rms_dist_pct` is the
#' quantity matching the bias formula given in the report's Methods
#' section. The bias is then aggregated hierarchically as the (unweighted)
#' arithmetic mean of the finer-scale bias, from landmark to individual to
#' species to overall community, mirroring the original protocol exactly
#' (rather than, e.g., pooling all replicates directly, which would
#' implicitly weight species/individuals with more replicates or more
#' landmarks more heavily).
#'
#' As discussed at length in Boutic (2026), this normalized-Euclidean-
#' distance approach is a simplification relative to the geometric
#' morphometric reference standard, which would apply a Generalised
#' Procrustes superimposition (GPA; [gpa_fish()]) before quantifying error,
#' and compute a formal repeatability index (Yezerinac et al., 1992;
#' Fruciano, 2016) or Procrustes ANOVA ([measurement_error()],
#' `method = "procrustes"`). The approach implemented here operates
#' directly on raw digitized coordinates (no GPA), which is appropriate
#' when the goal is specifically to characterise **operator/digitization**
#' bias landmark by landmark (e.g. to flag landmarks needing a stricter
#' operational definition, as in Boutic, 2026's Table/Figure 3), rather
#' than to test for shape differences among groups. Because the
#' decomposition is landmark by landmark, it should only be applied to a
#' set of homologous, independently-placed biological landmarks: fixed
#' calibration points such as a digitized scale bar (e.g. landmarks 20-21
#' of the FISHMORPH scheme) are not body landmarks in this sense and
#' should be dropped via `exclude_landmarks` before interpreting
#' `by_landmark`, `by_species`, or `global` (see Examples). For testing
#' shape differences among groups, or for
#' a size- and rotation-invariant estimate directly comparable to the
#' wider geometric morphometrics literature, use
#' `measurement_error(..., method = "procrustes")` instead. The
#' terminological caveat raised in Boutic (2026) also applies here: what
#' is quantified is strictly **intra-operator repeatability** (the same
#' single operator digitizing the same specimens repeatedly), not
#' inter-operator systematic bias in the strict sense, which would require
#' several independent operators (Klingenberg & McIntyre, 1998).
#'
#' @references
#' Boutic L (2026). Quantification du biais opérateur dans la mesure des
#' traits morphologiques de poissons d'eau douce. Rapport de projet
#' tuteuré, L2 BCP BIOMIP, Centre de Recherche sur la Biodiversité et
#' l'Environnement (CRBE), unpublished, supervised by A. Toussaint.
#'
#' Bookstein FL (1991). Morphometric tools for landmark data: Geometry and
#' biology. Cambridge University Press.
#'
#' Fruciano C (2016). Measurement error in geometric morphometrics.
#' Development Genes and Evolution, 226(3), 139-158.
#'
#' Klingenberg CP, McIntyre GS (1998). Geometric morphometrics of
#' developmental instability: analyzing patterns of fluctuating asymmetry
#' with Procrustes methods. Evolution, 52(5), 1363-1375.
#'
#' Yezerinac SM, Lougheed SC, Handford P (1992). Measurement error and
#' morphometric studies: statistical power and observer experience.
#' Systematic Biology, 41(4), 471-482.
#'
#' @seealso [measurement_error()], [detect_outliers()], [itv_index()],
#'   [simulate_fish_landmarks()], [fishmorph_segments()],
#'   [load_t26_saudrune_landmarks()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 4, n_replicates = 10)
#' # `individual` identifies which replicates belong to the same specimen
#' # (simulate_fish_landmarks() encodes it in the specimen/row name):
#' indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))
#' derr <- digitization_error(fish, individual = indiv_id)
#' derr
#' derr$by_landmark
#' derr$global
#'
#' # FISHMORPH scheme: landmarks 20-21 are a digitized scale bar, not a
#' # biological landmark, and should be excluded from the bias
#' # decomposition (they can still be examined separately if desired, but
#' # should not be pooled with anatomical landmarks in by_landmark/global):
#' fish_fm <- load_t26_saudrune_landmarks(source = "repeatability")
#' derr_fm <- digitization_error(
#'   fish_fm,
#'   individual = fish_fm$metadata$individual,
#'   exclude_landmarks = c(20, 21)
#' )
#' derr_fm$by_landmark
#'
#' @export
digitization_error <- function(landmarks,
                                individual,
                                species = NULL,
                                site = NULL,
                                ref_landmarks = c(1, 2),
                                exclude_landmarks = NULL,
                                normalization = c("landmarks", "standard_length", "centroid_size"),
                                digits = 4) {
  normalization <- match.arg(normalization)

  if (!inherits(landmarks, "intrait_landmarks")) {
    stop(
      "`landmarks` must be an object of class \"intrait_landmarks\" ",
      "(see read_tps(), read_landmarks_csv(), or simulate_fish_landmarks()), ",
      "with repeated digitization replicates per individual.",
      call. = FALSE
    )
  }

  coords <- landmarks$coords
  n_lmk <- dim(coords)[1]
  n_obs <- dim(coords)[3]

  if (missing(individual) || length(individual) != n_obs) {
    stop(
      "`individual` is required and must have one entry per specimen/replicate ",
      "in `landmarks` (length ", n_obs, "), identifying which replicates ",
      "belong to the same physical individual.",
      call. = FALSE
    )
  }
  individual <- as.character(individual)

  if (is.null(species)) {
    if (is.null(landmarks$metadata) || !"species" %in% names(landmarks$metadata)) {
      stop("`species` must be supplied (no `species` column found in `landmarks$metadata`).", call. = FALSE)
    }
    species <- landmarks$metadata$species
  }
  if (length(species) != n_obs) {
    stop("`species` must have one entry per specimen/replicate (length ", n_obs, ").", call. = FALSE)
  }
  species <- as.character(species)

  if (is.null(site) && !is.null(landmarks$metadata) && "population" %in% names(landmarks$metadata)) {
    site <- landmarks$metadata$population
  }
  if (!is.null(site) && length(site) != n_obs) {
    stop("`site` must have one entry per specimen/replicate (length ", n_obs, ").", call. = FALSE)
  }
  if (!is.null(site)) site <- as.character(site)

  if (!is.numeric(ref_landmarks) || length(ref_landmarks) != 2) {
    stop("`ref_landmarks` must be an integer vector of length 2.", call. = FALSE)
  }
  if (any(ref_landmarks < 1) || any(ref_landmarks > n_lmk)) {
    stop("`ref_landmarks` must index valid landmarks (between 1 and ", n_lmk, ").", call. = FALSE)
  }
  if (!is.null(exclude_landmarks)) {
    if (!is.numeric(exclude_landmarks) || any(exclude_landmarks < 1) || any(exclude_landmarks > n_lmk)) {
      stop("`exclude_landmarks` must index valid landmarks (between 1 and ", n_lmk, ").", call. = FALSE)
    }
    exclude_landmarks <- as.integer(exclude_landmarks)
  }
  landmark_set <- setdiff(seq_len(n_lmk), exclude_landmarks)
  if (length(landmark_set) < 1) {
    stop("`exclude_landmarks` excludes all available landmarks; nothing left to analyse.", call. = FALSE)
  }
  if (normalization == "standard_length" &&
      (is.null(landmarks$metadata) || !"standard_length_mm" %in% names(landmarks$metadata))) {
    stop("normalization = \"standard_length\" requires a `standard_length_mm` column in `landmarks$metadata`.", call. = FALSE)
  }

  rep_counts <- table(individual)
  if (any(rep_counts < 2)) {
    stop(
      "Every individual must have at least 2 digitization replicates; ",
      "individual(s) with fewer than 2: ",
      paste(names(rep_counts)[rep_counts < 2], collapse = ", "),
      call. = FALSE
    )
  }
  if (length(unique(as.vector(rep_counts))) > 1) {
    warning(
      "Unequal numbers of digitization replicates across individuals; ",
      "bias estimates for individuals with fewer replicates will be noisier.",
      call. = FALSE
    )
  }

  ## ---- reference distance -------------------------------------------
  if (normalization == "landmarks") {
    p1 <- t(coords[ref_landmarks[1], , , drop = TRUE])
    p2 <- t(coords[ref_landmarks[2], , , drop = TRUE])
    ref_dist_obs <- sqrt(rowSums((p1 - p2)^2))
    reference_distance <- vapply(sort(unique(species)), function(sp) {
      mean(ref_dist_obs[species == sp])
    }, numeric(1))
    names(reference_distance) <- sort(unique(species))
  } else if (normalization == "standard_length") {
    sl <- landmarks$metadata$standard_length_mm
    reference_distance <- vapply(unique(individual), function(ind) {
      mean(sl[individual == ind], na.rm = TRUE)
    }, numeric(1))
    names(reference_distance) <- unique(individual)
  } else {
    csize_obs <- vapply(seq_len(n_obs), function(i) {
      cfg <- coords[, , i]
      ctr <- colMeans(cfg)
      sqrt(sum(sweep(cfg, 2, ctr)^2))
    }, numeric(1))
    reference_distance <- vapply(unique(individual), function(ind) {
      mean(csize_obs[individual == ind])
    }, numeric(1))
    names(reference_distance) <- unique(individual)
  }

  ## ---- landmark x individual dispersion ------------------------------
  individuals <- unique(individual)
  landmark_individual <- do.call(rbind, lapply(individuals, function(ind) {
    obs_idx <- which(individual == ind)
    n_rep <- length(obs_idx)
    sp <- species[obs_idx[1]]
    st <- if (!is.null(site)) site[obs_idx[1]] else NA_character_

    rows <- lapply(landmark_set, function(lmk) {
      pts <- t(matrix(coords[lmk, , obs_idx], nrow = 2))
      mean_xy <- colMeans(pts)
      dist <- sqrt(rowSums(sweep(pts, 2, mean_xy)^2))
      data.frame(
        individual = ind, species = sp, site = st, landmark = lmk,
        n_rep = n_rep,
        mean_dist = mean(dist),
        sd_dist = if (n_rep > 1) stats::sd(dist) else NA_real_,
        rms_dist = sqrt(mean(dist^2)),
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, rows)
  }))

  ref_key <- if (normalization == "landmarks") landmark_individual$species else landmark_individual$individual
  ref_val <- reference_distance[ref_key]
  landmark_individual$mean_dist_pct <- round(landmark_individual$mean_dist / ref_val * 100, digits)
  landmark_individual$sd_dist_pct <- round(landmark_individual$sd_dist / ref_val * 100, digits)
  landmark_individual$rms_dist_pct <- round(landmark_individual$rms_dist / ref_val * 100, digits)
  landmark_individual$mean_dist <- NULL
  landmark_individual$sd_dist <- NULL
  landmark_individual$rms_dist <- NULL
  rownames(landmark_individual) <- NULL

  ## ---- by landmark (across individuals) ------------------------------
  by_landmark <- do.call(rbind, lapply(sort(unique(landmark_individual$landmark)), function(lmk) {
    sub <- landmark_individual[landmark_individual$landmark == lmk, ]
    data.frame(
      landmark = lmk,
      n_individuals = nrow(sub),
      mean_bias_pct = round(mean(sub$sd_dist_pct, na.rm = TRUE), digits),
      median_bias_pct = round(stats::median(sub$sd_dist_pct, na.rm = TRUE), digits),
      sd_bias_pct = round(stats::sd(sub$sd_dist_pct, na.rm = TRUE), digits)
    )
  }))
  by_landmark <- by_landmark[order(by_landmark$median_bias_pct), ]
  rownames(by_landmark) <- NULL

  ## ---- by individual (across landmarks) -------------------------------
  by_individual <- do.call(rbind, lapply(individuals, function(ind) {
    sub <- landmark_individual[landmark_individual$individual == ind, ]
    data.frame(
      individual = ind,
      species = sub$species[1],
      site = sub$site[1],
      n_landmarks = nrow(sub),
      mean_dist_pct = round(mean(sub$mean_dist_pct), digits),
      sd_dist_pct = round(mean(sub$sd_dist_pct, na.rm = TRUE), digits),
      rms_dist_pct = round(mean(sub$rms_dist_pct), digits),
      stringsAsFactors = FALSE
    )
  }))
  rownames(by_individual) <- NULL

  ## ---- by species (across individuals) --------------------------------
  by_species <- do.call(rbind, lapply(sort(unique(by_individual$species)), function(sp) {
    sub <- by_individual[by_individual$species == sp, ]
    data.frame(
      species = sp,
      n_individuals = nrow(sub),
      mean_indiv_bias_pct = round(mean(sub$sd_dist_pct), digits),
      sd_indiv_bias_pct = round(if (nrow(sub) > 1) stats::sd(sub$sd_dist_pct) else NA_real_, digits),
      mean_indiv_dist_pct = round(mean(sub$mean_dist_pct), digits),
      mean_indiv_rms_pct = round(mean(sub$rms_dist_pct), digits),
      stringsAsFactors = FALSE
    )
  }))
  rownames(by_species) <- NULL

  ## ---- global (community) ---------------------------------------------
  global <- data.frame(
    n_individuals = nrow(by_individual),
    n_species = length(unique(by_individual$species)),
    global_mean_bias_pct = round(mean(by_individual$sd_dist_pct), digits),
    global_sd_bias_pct = round(stats::sd(by_individual$sd_dist_pct), digits),
    global_mean_dist_pct = round(mean(by_individual$mean_dist_pct), digits),
    global_mean_rms_pct = round(mean(by_individual$rms_dist_pct), digits)
  )

  structure(
    list(
      landmark_individual = landmark_individual,
      by_landmark = by_landmark,
      by_individual = by_individual,
      by_species = by_species,
      global = global,
      normalization = normalization,
      reference_distance = reference_distance,
      excluded_landmarks = exclude_landmarks
    ),
    class = "intrait_digitization_error"
  )
}

#' @export
print.intrait_digitization_error <- function(x, ...) {
  cat("<intrait_digitization_error>\n")
  cat(" Normalization:", x$normalization, "\n\n")
  cat(sprintf(
    " Global digitization bias: %.3f%% of reference distance (SD across individuals: %.3f%%)\n",
    x$global$global_mean_bias_pct, x$global$global_sd_bias_pct
  ))
  cat(sprintf(
    " Based on %d individual(s) from %d species, %d landmark(s)\n",
    x$global$n_individuals, x$global$n_species, nrow(x$by_landmark)
  ))
  if (!is.null(x$excluded_landmarks)) {
    cat(" Excluded landmark(s):", paste(x$excluded_landmarks, collapse = ", "), "\n")
  }
  cat("\n Least precise landmark(s):\n")
  print(utils::tail(x$by_landmark, 3), row.names = FALSE)
  cat("\n Most precise landmark(s):\n")
  print(utils::head(x$by_landmark, 3), row.names = FALSE)
  cat("\n Bias by species:\n")
  print(x$by_species, row.names = FALSE)
  invisible(x)
}

#' @export
#' @rdname digitization_error
#' @param x An object of class `"intrait_digitization_error"`.
#' @param ... Further arguments passed to [graphics::boxplot()].
plot.intrait_digitization_error <- function(x, ...) {
  ord <- x$by_landmark$landmark[order(x$by_landmark$median_bias_pct)]
  df <- x$landmark_individual
  df$landmark <- factor(df$landmark, levels = ord)
  graphics::boxplot(
    sd_dist_pct ~ landmark, data = df,
    xlab = "Landmark (ordered by increasing median bias)",
    ylab = "Digitization bias (% of reference distance)",
    main = "Digitization bias by landmark",
    ...
  )
}
