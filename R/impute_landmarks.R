#' Impute missing (NA) landmark coordinates using geometric morphometric methods
#'
#' Estimates missing 2D coordinates directly in `landmarks$coords` (or a raw
#' `p x k x n` array), rather than leaving gaps in individual specimens'
#' digitized configurations or discarding them. Unlike the `na_action`
#' options of [fishmorph_segments()]/[fishmorph_ratios()] -- which impute
#' the *derived* linear measurements/ratios after the fact, as a simple
#' fallback -- this operates on the landmark geometry itself, using
#' [geomorph::estimate.missing()], so the estimate reflects the covariation
#' among landmark positions across the sample (thin-plate spline warping or
#' multivariate regression), the standard approach for missing landmark data
#' in geometric morphometrics.
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
#'   sample to estimate that relationship reliably.
#'
#' @return An object of the same class as `landmarks` (`"intrait_landmarks"`
#'   or a raw array), with `NA` coordinates in landmarks 1-19 replaced by
#'   their geometric morphometric estimate. Everything else (`scale`,
#'   `metadata`, landmarks 20 and up) is left unchanged. The returned
#'   `coords` array also carries an `"imputed"` attribute (a `p x n`
#'   logical matrix, one row per landmark and one column per specimen,
#'   `TRUE` where that point was estimated rather than digitized), which
#'   [plot_fishmorph_points()] uses to highlight imputed points in red.
#'
#' @details
#' Only landmarks 1-19 (the anatomical/shape landmarks used for Generalised
#' Procrustes Analysis elsewhere in this package, e.g. [gpa_fish()]) are
#' eligible for imputation here. Landmarks 20-21 (the scale bar) are *not*
#' homologous shape landmarks -- their position simply reflects wherever a
#' ruler was placed in the picture -- so their covariation with the rest of
#' the configuration is meaningless, and a missing scale bar point cannot be
#' geometrically estimated; if either is missing for a specimen, a warning
#' is issued and that specimen's scale bar is left as `NA` (matching
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
#' grows, or when very few specimens have a complete configuration to learn
#' the covariation structure from. Always compare an imputed specimen
#' against its non-imputed neighbours (e.g. with [plot_fishmorph_points()],
#' which highlights imputed landmarks directly, or the more generic
#' [plot_landmarks()]) before relying on it in an analysis.
#'
#' @seealso [fishmorph_segments()], [fishmorph_ratios()], [gpa_fish()],
#'   [plot_fishmorph_points()], [plot_landmarks()]
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
#' }
#'
#' @export
#' @importFrom geomorph estimate.missing
impute_landmarks <- function(landmarks, method = c("tps", "regression")) {
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

  geomorph_method <- if (method == "tps") "TPS" else "Reg"
  imputed_shape <- tryCatch(
    geomorph::estimate.missing(shape_A, method = geomorph_method),
    error = function(e) {
      stop(
        "geomorph::estimate.missing() failed (method = \"", geomorph_method, "\"): ", conditionMessage(e),
        ". This usually means too few complete specimens are available to estimate ",
        "the missing landmark(s) reliably; consider na_action = \"omit\" in ",
        "fishmorph_segments()/fishmorph_ratios() instead for this data set.",
        call. = FALSE
      )
    }
  )

  A[shape_idx, , ] <- imputed_shape
  imputed_full[shape_idx, ] <- imputed_full[shape_idx, ] | imputed_shape_mask
  attr(A, "imputed") <- imputed_full
  message(sprintf(
    "impute_landmarks(): estimated %d missing anatomical landmark coordinate(s) using method = \"%s\".",
    n_missing_pts, method
  ))

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}
