#' Actively correct landmarks that violate the FISHMORPH geometric
#' conventions, once the axis is horizontal
#'
#' The value-*changing* half of [correct_geometry()]'s pipeline (its step
#' 4), available on its own: corrects, for every specimen, whichever of the
#' five landmark-coordinate-scatter conventions
#' `correct_landmarks(rule = "check_geometry")` audits still fails to hold,
#' by moving the deviant landmark(s) onto their group's shared reference
#' (an anatomical anchor, for the three two-point segments; the median of
#' every present point, for the two multi-point groups -- see Details).
#' Unlike [standardize_geometry()] (steps 1-3), this does change measured
#' distances/ratios for whichever landmark(s) it moves.
#'
#' @param landmarks An object of class `"intrait_landmarks"`, or a raw
#'   `p x k x n` landmark array, **already standardized** so that the main
#'   axis (landmarks 1-2) is horizontal -- i.e. the output of
#'   [standardize_geometry()] or [correct_geometry()], not raw digitized
#'   coordinates (see Details).
#' @param specimen `NULL` (default) to check/correct every specimen, or an
#'   integer/character vector to restrict this to a subset.
#' @param tolerance_coord Numeric, proportion of body length (Bl, the
#'   distance between landmarks 1 and 2) any point in a landmark group is
#'   allowed to sit from the shared coordinate the rest of the group agrees
#'   on, before it is corrected -- same meaning as
#'   `correct_landmarks(rule = "check_geometry")`'s own `tolerance_coord`,
#'   but a much smaller default here (`1e-6`, i.e. essentially any visible
#'   misalignment is corrected): see [correct_geometry()]'s Details for the
#'   full rationale. Raise it (e.g. to match `check_geometry()`'s `0.02`)
#'   to preserve small deviations you consider acceptable digitization
#'   noise instead of correcting them.
#'
#' @return An object of the same class as `landmarks`, with every
#'   flagged coordinate replaced by its group's reference value. The
#'   returned `coords` array carries two attributes, both merged with any
#'   pre-existing ones from an earlier [correct_geometry()]/
#'   [correct_landmarks()] call on the same object, so a full audit trail
#'   accumulates across successive corrections:
#'   \describe{
#'     \item{`corrected`}{a `p x n` logical matrix, `TRUE` where this
#'       function moved that point; used by [plot_fishmorph_points()] to
#'       highlight corrected points in blue.}
#'     \item{`correction_log`}{a `data.frame`, one row per point corrected,
#'       with columns `specimen`, `check`, `landmark`, `axis`, `old_value`,
#'       `new_value`, `reference_points`, `reference_value` -- the same
#'       shape as [correct_landmarks()] (`rule = "align"`)'s own log.}
#'   }
#'
#' @details
#' See [correct_geometry()]'s Details for the full description of the five
#' checks corrected here (`perpendicular_seg_1_9_vs_axis`,
#' `perpendicular_seg_3_4_vs_axis`, `perpendicular_seg_10_11_vs_axis`,
#' `perpendicular_eye_vertical_vs_axis`, `axis_horizontal_parallel`), which
#' this function applies identically.
#'
#' Because "vertical" and "horizontal" are evaluated directly on raw X/Y,
#' this function is only meaningful once the main axis is already
#' horizontal -- i.e. on the output of [standardize_geometry()] (or
#' [correct_geometry()], which performs both steps). Calling it on raw,
#' un-standardized coordinates will evaluate these checks against whatever
#' arbitrary orientation the photograph happened to have, producing
#' corrections that do not reflect the intended FISHMORPH conventions. A
#' specimen missing landmark 1 or 2 (needed to compute body length, Bl, the
#' denominator `tolerance_coord` is expressed against) is skipped, with a
#' warning.
#'
#' As with [correct_geometry()], running this function twice on
#' already-corrected data is harmless (idempotent up to floating-point
#' precision): it only ever corrects a coordinate onto another point's
#' already-present value.
#'
#' Splitting [correct_geometry()] this way lets you inspect
#' `correct_landmarks(rule = "check_geometry")`'s audit, or a diagnostic
#' like a functional-space sensitivity comparison, before deciding whether
#' this active correction is appropriate for a given data set or clade --
#' e.g. a species with a genuinely atypical body plan (very elongate,
#' dorsoventrally flattened, oblique/ventral mouth) may legitimately
#' violate these generic conventions as a matter of true anatomy rather
#' than digitization noise, in which case applying only
#' [standardize_geometry()] (or raising `tolerance_coord` well above the
#' default here) may be preferable to this function's default, strict
#' correction for those specimens.
#'
#' @seealso [standardize_geometry()] (steps 1-3, which never change any
#'   value), [correct_geometry()] (the combined pipeline, unchanged and
#'   still the recommended one-call route for existing workflows),
#'   [correct_landmarks()], [plot_fishmorph_points()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' fish_std <- standardize_geometry(fish) # steps 1-3 first, required
#' fish_corrected <- correct_geometry_conventions(fish_std)
#' attr(fish_corrected$coords, "correction_log")
#' # equivalent, in one call:
#' fish_corrected2 <- correct_geometry(fish)
#'
#' @export
correct_geometry_conventions <- function(landmarks, specimen = NULL, tolerance_coord = 1e-6) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  if (k != 2) {
    stop("correct_geometry_conventions() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "correct_geometry_conventions() requires at least 21 landmarks (the ",
      "FISHMORPH scheme, including the scale bar, points 20-21); found ", p, ".",
      call. = FALSE
    )
  }
  if (!is.numeric(tolerance_coord) || length(tolerance_coord) != 1 || tolerance_coord < 0) {
    stop(
      "`tolerance_coord` must be a single non-negative number (a proportion of body length, Bl).",
      call. = FALSE
    )
  }

  specimen_names_all <- dimnames(A)[[3]]
  idx_all <- .resolve_specimen_idx(specimen, specimen_names_all)
  plan <- .geometry_coord_plan()

  corrected_full <- matrix(FALSE, nrow = p, ncol = n, dimnames = list(NULL, specimen_names_all))
  prior_corrected <- attr(A, "corrected")
  if (!is.null(prior_corrected) && all(dim(prior_corrected) == dim(corrected_full))) {
    corrected_full <- prior_corrected
  }
  log_rows <- list()
  n_skipped <- 0L

  for (idx in idx_all) {
    sname <- specimen_names_all[idx]
    xy <- A[, , idx]

    if (!all(is.finite(xy[c(1, 2), ]))) {
      n_skipped <- n_skipped + 1L
      next
    }

    corr <- .geometry_correct_one(xy, tolerance_coord, plan)
    if (length(corr$log_rows) == 0) next

    A[, , idx] <- corr$xy
    corrected_full[corr$corrected_pts, idx] <- TRUE
    for (lr in corr$log_rows) {
      lr$specimen <- sname
      lr <- lr[c(
        "specimen", "check", "landmark", "axis", "old_value",
        "new_value", "reference_points", "reference_value"
      )]
      log_rows[[length(log_rows) + 1]] <- lr
    }
  }

  if (n_skipped > 0) {
    warning(sprintf(
      paste(
        "correct_geometry_conventions(): could not evaluate %d specimen(s)",
        "missing landmark 1 or 2 (needed to compute body length, Bl)."
      ),
      n_skipped
    ), call. = FALSE)
  }

  attr(A, "corrected") <- corrected_full
  if (length(log_rows) > 0) {
    new_log <- do.call(rbind, log_rows)
    prior_log <- attr(A, "correction_log")
    attr(A, "correction_log") <- if (!is.null(prior_log)) rbind(prior_log, new_log) else new_log
    message(sprintf(
      "correct_geometry_conventions(): corrected %d landmark coordinate(s) across %d specimen(s).",
      nrow(new_log), length(unique(new_log$specimen))
    ))
  } else {
    message("correct_geometry_conventions(): nothing to correct (every evaluable specimen already conforms).")
  }

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}
