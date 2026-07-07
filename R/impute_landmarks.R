#' Impute missing (NA) landmark coordinates
#'
#' Estimates missing 2D coordinates directly in `landmarks$coords` (or a raw
#' `p x k x n` array), rather than leaving gaps in individual specimens'
#' digitized configurations or discarding them. Two families of method are
#' available: `"tps"`/`"regression"` use
#' [geomorph::estimate.missing()] to exploit the geometric covariation among
#' landmark positions across the sample (thin-plate spline warping or
#' multivariate regression) -- the standard approach for missing landmark
#' data in geometric morphometrics; `"impute_mean"`, `"impute_group_mean"`,
#' `"missforest"`, and `"missforest_phylo"` instead treat each landmark
#' coordinate as an ordinary numeric variable and impute it statistically,
#' mirroring the equivalent `na_action` options of [trait_space()] (applied
#' there to the *derived* trait matrix rather than to raw coordinates).
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()], [read_landmarks_csv()], or [simulate_fishmorph_points()]/
#'   [load_t26_saudrune_landmarks()]), or a raw `p x k x n` landmark array,
#'   with at least one `NA` coordinate. Landmarks are expected to follow the
#'   FISHMORPH digitization scheme (see [fishmorph_segments()]): landmarks
#'   1-19 are anatomical (shape) landmarks; 20-21 are a scale bar; the
#'   optional 22 is a body-curvature correction point.
#' @param method Character, `"tps"` (default) for thin-plate spline
#'   interpolation, or `"regression"` for multivariate regression on the
#'   other landmarks; passed to `method = "TPS"`/`"Reg"` in
#'   [geomorph::estimate.missing()]. `"tps"` uses local geometric
#'   relationships to the nearest complete landmarks and is the more
#'   commonly used default; `"regression"` can perform better when a
#'   missing landmark is strongly correlated with overall shape (e.g. a
#'   near-symmetric point) but needs a reasonably large, complete-enough
#'   sample to estimate that relationship reliably. `"impute_mean"` replaces
#'   a missing coordinate with the mean of that same coordinate (landmark x
#'   dimension) across all specimens; `"impute_group_mean"` uses the mean
#'   within the specimen's own `groups` instead (falling back to the overall
#'   mean, with a warning, for a group entirely missing that coordinate);
#'   `"missforest"` uses random-forest-based iterative imputation
#'   (`missForest::missForest()`, Stekhoven & Buhlmann, 2012) across all
#'   landmark coordinates jointly, using `groups` (when available) as an
#'   additional predictor; `"missforest_phylo"` does the same but also
#'   augments the predictor matrix with phylogenetic PCoA axes (see
#'   [phylo_pcoa()], `tree`/`missforest_phylo_k`) for the species in
#'   `groups`, falling back to plain `"missforest"` (with a warning) if
#'   phylogenetic axes cannot be used. Unlike `"tps"`/`"regression"`, these
#'   four options ignore the geometric/shape covariation among landmarks
#'   altogether and treat each coordinate independently (or, for
#'   `"missforest"`/`"missforest_phylo"`, via generic non-linear
#'   association) -- they are simpler and match [trait_space()]'s own
#'   `na_action` behaviour, but are not a geometric-morphometric estimate
#'   of the missing point's true position, so prefer `"tps"`/`"regression"`
#'   for actual shape landmarks when enough complete specimens are
#'   available, and reserve the statistical options for exploratory use or
#'   when too few complete configurations remain for
#'   `geomorph::estimate.missing()` to work reliably.
#' @param groups Optional factor (or character vector), one value per
#'   specimen in the same order as `dimnames(A)[[3]]`, used by
#'   `method = "impute_group_mean"` (required) and, optionally, by
#'   `method = "missforest"`/`"missforest_phylo"` (as an auxiliary
#'   predictor; required by `"missforest_phylo"` for phylogenetic matching
#'   specifically -- without it, `"missforest_phylo"` falls back to plain
#'   `"missforest"`). If `NULL` and `landmarks` is an
#'   `"intrait_landmarks"`/`"intrait_gpa"` object whose `metadata` contains
#'   a `species` column, it is used automatically. Ignored by `"tps"`,
#'   `"regression"`, and `"impute_mean"`.
#' @param missforest_ntree,missforest_maxiter Number of trees per forest and
#'   maximum number of iterations passed to `missForest::missForest()` when
#'   `method` is `"missforest"`/`"missforest_phylo"`; ignored otherwise.
#'   Default to `missForest`'s own defaults (`100` and `10`).
#' @param tree Used only by `method = "missforest_phylo"`: an object of
#'   class `"phylo"`, or `NULL` (default) to use the bundled
#'   [load_fishmorph_phylogeny()] tree.
#' @param missforest_phylo_k Used only by `method = "missforest_phylo"`:
#'   maximum number of phylogenetic PCoA axes to add as predictors.
#'   Defaults to `10`.
#'
#' @return An object of the same class as `landmarks` (`"intrait_landmarks"`
#'   or a raw array), with `NA` coordinates in landmarks 1-19 replaced by
#'   their estimated value. Everything else (`scale`, `metadata`, landmarks
#'   20 and up) is left unchanged. The returned `coords` array also carries
#'   an `"imputed"` attribute (a `p x n` logical matrix, one row per
#'   landmark and one column per specimen, `TRUE` where that point was
#'   estimated rather than digitized), which [plot_fishmorph_points()] uses
#'   to highlight imputed points in red.
#'
#' @details
#' Only landmarks 1-19 (the anatomical/shape landmarks used for Generalised
#' Procrustes Analysis elsewhere in this package, e.g. [gpa_fish()]) are
#' eligible for imputation here. Landmarks 20-21 (the scale bar) are *not*
#' homologous shape landmarks -- their position simply reflects wherever a
#' ruler was placed in the picture -- so their covariation with the rest of
#' the configuration is meaningless, and a missing scale bar point cannot be
#' estimated by any of these methods; if either is missing for a specimen, a
#' warning is issued and that specimen's scale bar is left as `NA` (matching
#' [fishmorph_segments()]'s own "zero-length or missing scale bar" warning
#' -- that specimen's segments/ratios will still be `NA` downstream unless
#' the scale bar is fixed some other way). Landmark 22 (optional body-
#' curvature correction) is deliberately "0 if not needed" under the
#' original protocol rather than a routinely digitized point, so it is also
#' left untouched.
#'
#' As with any imputation, this is not a substitute for re-digitizing a
#' specimen from its original photograph when that is possible, and results
#' should be treated with more caution as the fraction of missing landmarks
#' grows, or when very few specimens are available to learn the imputation
#' model from (be it the covariation structure used by `"tps"`/
#' `"regression"`, or the column/group means and random forests used by the
#' statistical options). Always compare an imputed specimen against its
#' non-imputed neighbours (e.g. with [plot_fishmorph_points()], which
#' highlights imputed landmarks directly, or the more generic
#' [plot_landmarks()]) before relying on it in an analysis.
#'
#' @references Stekhoven, D. J., & Buhlmann, P. (2012). MissForest --
#'   non-parametric missing value imputation for mixed-type data.
#'   Bioinformatics, 28(1), 112-118. \doi{10.1093/bioinformatics/btr597}
#'
#' @seealso [fishmorph_segments()], [fishmorph_ratios()], [gpa_fish()],
#'   [plot_fishmorph_points()], [plot_landmarks()], [trait_space()],
#'   [phylo_pcoa()], [load_fishmorph_phylogeny()]
#'
#' @examples
#' \donttest{
#' fish <- load_t26_saudrune_landmarks()
#' anyNA(fish$coords) # some real specimens are missing landmark 5
#' fish_imputed <- impute_landmarks(fish)
#' anyNA(fish_imputed$coords[1:19, , ]) # anatomical landmarks now complete
#'
#' # plot_fishmorph_points() highlights the imputed point(s) in red:
#' plot_fishmorph_points(fish_imputed, specimen = 1)
#'
#' # statistical alternatives, mirroring trait_space()'s na_action options;
#' # `groups` is auto-detected here from fish$metadata$species
#' fish_mean <- impute_landmarks(fish, method = "impute_mean")
#' fish_gmean <- impute_landmarks(fish, method = "impute_group_mean")
#' if (requireNamespace("missForest", quietly = TRUE)) {
#'   fish_rf <- impute_landmarks(fish, method = "missforest")
#'
#'   # phylogenetically-augmented missForest: adds phylogenetic PCoA axes
#'   # (from the bundled FISHMORPH tree, see load_fishmorph_phylogeny()) as
#'   # extra predictors, so close relatives can inform each other's
#'   # imputed coordinates in addition to shared species identity
#'   if (requireNamespace("ape", quietly = TRUE)) {
#'     fish_rf_phylo <- impute_landmarks(fish, method = "missforest_phylo")
#'   }
#' }
#' }
#'
#' @export
#' @importFrom geomorph estimate.missing
impute_landmarks <- function(landmarks,
                              method = c("tps", "regression", "impute_mean",
                                         "impute_group_mean", "missforest",
                                         "missforest_phylo"),
                              groups = NULL,
                              missforest_ntree = 100, missforest_maxiter = 10,
                              tree = NULL, missforest_phylo_k = 10) {
  method <- match.arg(method)
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  if (k != 2) {
    stop("impute_landmarks() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "`landmarks` must contain at least 21 landmarks digitized following the ",
      "Brosse et al. (2021) FISHMORPH scheme (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }

  if (is.null(groups) &&
      (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) &&
      !is.null(landmarks$metadata) && "species" %in% names(landmarks$metadata)) {
    groups <- landmarks$metadata$species
  }
  if (method == "impute_group_mean" && is.null(groups)) {
    stop(
      "method = \"impute_group_mean\" requires `groups` (e.g. species labels, ",
      "one per specimen), either passed directly or available as a `species` ",
      "column in `landmarks$metadata`.",
      call. = FALSE
    )
  }
  if (!is.null(groups)) {
    if (length(groups) != n) {
      stop(
        "`groups` must have one entry per specimen (", n, " found in `landmarks`); ",
        "got length ", length(groups), ".",
        call. = FALSE
      )
    }
    groups <- factor(groups)
  }

  scale_na <- apply(A[20:21, , , drop = FALSE], 3, anyNA)
  if (any(scale_na)) {
    warning(
      sum(scale_na), " specimen(s) have a missing scale bar landmark (20 or ",
      "21); these cannot be estimated from shape covariation (they are not ",
      "homologous shape landmarks) and are left as NA -- see ",
      "fishmorph_segments()'s \"zero-length or missing scale bar\" warning.",
      call. = FALSE
    )
  }

  shape_idx <- seq_len(min(19, p))
  n_shape <- length(shape_idx)
  shape_A <- A[shape_idx, , , drop = FALSE]
  # Per-landmark (not per-coordinate) missingness: TRUE if that point's X
  # and/or Y was NA for that specimen, i.e. it will be imputed below. Kept
  # as a full p x n matrix (FALSE beyond the 19 anatomical landmarks) and
  # attached to the output as attr(., "imputed"), so plot_fishmorph_points()
  # can highlight exactly which points were estimated rather than digitized.
  imputed_shape_mask <- apply(is.na(shape_A), c(1, 3), any)
  n_missing_pts <- sum(imputed_shape_mask)

  imputed_full <- matrix(
    FALSE, nrow = p, ncol = n, dimnames = list(NULL, dimnames(A)[[3]])
  )
  prior_imputed <- attr(A, "imputed")
  if (!is.null(prior_imputed) && all(dim(prior_imputed) == dim(imputed_full))) {
    imputed_full <- prior_imputed
  }

  if (n_missing_pts == 0) {
    message("impute_landmarks(): no missing anatomical landmark (1-19) found; nothing to impute.")
    return(landmarks)
  }

  if (method %in% c("tps", "regression")) {
    geomorph_method <- if (method == "tps") "TPS" else "Reg"
    imputed_shape <- tryCatch(
      geomorph::estimate.missing(shape_A, method = geomorph_method),
      error = function(e) {
        stop(
          "geomorph::estimate.missing() failed (method = \"", geomorph_method, "\"): ", conditionMessage(e),
          ". This usually means too few complete specimens are available to estimate ",
          "the missing landmark(s) reliably; consider na_action = \"omit\" in ",
          "fishmorph_segments()/fishmorph_ratios() instead for this data set, or one ",
          "of the statistical `method`s (\"impute_mean\", \"impute_group_mean\", ",
          "\"missforest\", \"missforest_phylo\").",
          call. = FALSE
        )
      }
    )
    A[shape_idx, , ] <- imputed_shape
    message(sprintf(
      "impute_landmarks(): estimated %d missing anatomical landmark coordinate(s) using method = \"%s\".",
      n_missing_pts, method
    ))
  } else {
    # Statistical imputation: flatten shape_A (n_shape x k x n) into an
    # n x (n_shape * k) matrix, one column per landmark coordinate (e.g.
    # "lm5_x"), mirroring trait_space()'s na_action logic on a derived
    # trait matrix -- here applied to raw coordinates instead.
    n_coord_cols <- n_shape * k
    M <- matrix(NA_real_, nrow = n, ncol = n_coord_cols)
    col_names <- character(n_coord_cols)
    dim_labels <- c("x", "y")
    col_i <- 0L
    for (pt in seq_len(n_shape)) {
      for (dd in seq_len(k)) {
        col_i <- col_i + 1L
        M[, col_i] <- shape_A[pt, dd, ]
        col_names[col_i] <- paste0("lm", shape_idx[pt], "_", dim_labels[dd])
      }
    }
    colnames(M) <- col_names
    n_na <- sum(is.na(M))

    if (method == "impute_mean") {
      for (j in seq_len(ncol(M))) {
        col_na <- is.na(M[, j])
        if (any(col_na)) M[col_na, j] <- mean(M[, j], na.rm = TRUE)
      }
      message(sprintf(
        "impute_landmarks(): imputed %d missing landmark coordinate value(s) using column means (method = \"impute_mean\").",
        n_na
      ))
    } else if (method == "impute_group_mean") {
      for (j in seq_len(ncol(M))) {
        col <- M[, j]
        col_na <- is.na(col)
        if (!any(col_na)) next
        for (g in levels(groups)) {
          idx <- groups == g & col_na
          if (!any(idx)) next
          g_mean <- mean(col[groups == g], na.rm = TRUE)
          if (is.nan(g_mean)) {
            warning(
              "Group \"", g, "\" has no non-missing values for at least one landmark ",
              "coordinate; falling back to the overall column mean for imputation.",
              call. = FALSE
            )
            g_mean <- mean(col, na.rm = TRUE)
          }
          col[idx] <- g_mean
        }
        M[, j] <- col
      }
      message(sprintf(
        "impute_landmarks(): imputed %d missing landmark coordinate value(s) using within-group means (method = \"impute_group_mean\").",
        n_na
      ))
    } else if (method %in% c("missforest", "missforest_phylo")) {
      if (!requireNamespace("missForest", quietly = TRUE)) {
        stop(
          "method = \"", method, "\" requires the \"missForest\" package. ",
          "Install it with install.packages(\"missForest\").",
          call. = FALSE
        )
      }
      df_for_rf <- as.data.frame(M)
      if (!is.null(groups)) df_for_rf$.group <- groups

      phylo_note <- ""
      if (method == "missforest_phylo") {
        pax <- .phylo_axes_for_groups(groups, tree = tree, k_phylo = missforest_phylo_k)
        if (is.null(pax$axes)) {
          warning(
            "method = \"missforest_phylo\": phylogenetic axes could not be used (",
            pax$reason, "); falling back to plain \"missforest\" (no phylogenetic predictors).",
            call. = FALSE
          )
        } else {
          df_for_rf <- cbind(df_for_rf, pax$axes)
          phylo_note <- sprintf(
            ", augmented with %d phylogenetic PCoA axis/axes (%d species matched to the tree)",
            pax$k_used, pax$n_matched
          )
        }
      }

      imp <- missForest::missForest(
        df_for_rf, ntree = missforest_ntree, maxiter = missforest_maxiter,
        verbose = FALSE
      )
      ximp <- imp$ximp
      M <- as.matrix(ximp[, col_names, drop = FALSE])
      storage.mode(M) <- "double"
      nrmse <- if ("NRMSE" %in% names(imp$OOBerror)) imp$OOBerror[["NRMSE"]] else NA_real_
      message(sprintf(
        "impute_landmarks(): imputed %d missing landmark coordinate value(s) using random-forest imputation (missForest)%s%s%s.",
        n_na,
        if (!is.null(groups)) ", using `groups` as an auxiliary predictor" else "",
        phylo_note,
        if (!is.na(nrmse)) sprintf(" (out-of-bag NRMSE = %.3f)", nrmse) else ""
      ))
    }

    col_i <- 0L
    for (pt in seq_len(n_shape)) {
      for (dd in seq_len(k)) {
        col_i <- col_i + 1L
        shape_A[pt, dd, ] <- M[, col_i]
      }
    }
    A[shape_idx, , ] <- shape_A
  }

  imputed_full[shape_idx, ] <- imputed_full[shape_idx, ] | imputed_shape_mask
  attr(A, "imputed") <- imputed_full

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}
