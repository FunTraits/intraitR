#' Standardize landmark configurations to a common scale, orientation, and
#' geometric convention
#'
#' A full geometric standardization pipeline for FISHMORPH landmark
#' configurations, applied to every specimen in a fixed order: (1) rescale
#' the body landmarks isotropically so they fit within `[0, 1]` (preserving
#' body shape -- see Details); (2) reposition the embedded scale bar
#' (landmarks 20-21) to a fixed corner of that `[0, 1]` space, as a clean
#' horizontal reference segment rather than wherever it happened to sit in
#' the original photograph; (3) rotate the body so the main axis (landmarks
#' 1-2) is exactly horizontal, with landmark 1 always to the left of
#' landmark 2, then shift it vertically so that axis sits at `Y = 0.5` for
#' *every* specimen; (4) correct, exactly as
#' `correct_landmarks(rule = "check_geometry")` audits, whichever of the
#' five landmark-coordinate-scatter conventions still fails to hold once
#' the specimen is in this canonical frame. Each step operates on the
#' output of the step before it, in this order, for every specimen.
#'
#' @param landmarks An object of class `"intrait_landmarks"`, or a raw
#'   `p x k x n` landmark array, with at least the 21 landmarks of the
#'   FISHMORPH scheme (points 1-19 plus the scale bar, 20-21).
#' @param specimen `NULL` (default) to standardize every specimen, or an
#'   integer/character vector to restrict this to a subset.
#' @param scale_bar_pos Numeric length-2 vector, the `c(x, y)` position (in
#'   the post-rescaling `[0, 1]` space) landmark 20 is moved to; landmark
#'   21 is placed to its right, at `scale_bar_pos + c(length, 0)`, where
#'   `length` is the scale bar's own original length scaled by the same
#'   factor as the body (see Details) -- so the calibration ratio between
#'   the scale bar and the body is preserved, only its position and
#'   orientation are standardized. Defaults to `c(0.1, 0.1)` (bottom-left).
#' @param tolerance_coord Numeric, proportion of body length (Bl, the
#'   distance between landmarks 1 and 2, now measured in the rescaled and
#'   rotated frame) *any* point in a landmark group is allowed to sit from
#'   the shared coordinate the rest of the group agrees on, before it is
#'   corrected in step (4) -- same meaning as `correct_landmarks(rule =
#'   "check_geometry")`'s own `tolerance_coord`, but a much smaller default
#'   here (`1e-6`, i.e. essentially any visible misalignment is corrected):
#'   `correct_landmarks(rule = "check_geometry")`'s `0.02` default is tuned
#'   as a *diagnostic* threshold (distinguishing routine digitization noise
#'   from a problem worth a human's attention), whereas this function's job
#'   is to actually produce a clean, standardized configuration, for which
#'   there is no principled reason to leave a detectable misalignment
#'   uncorrected. Raise it (e.g. to match `check_geometry()`'s `0.02`) to
#'   preserve small deviations you consider acceptable digitization noise
#'   instead of correcting them.
#'
#' @return An object of the same class as `landmarks`, with every
#'   specimen's coordinates replaced by their standardized version. The
#'   returned `coords` array carries three attributes:
#'   \describe{
#'     \item{`standardization_log`}{a `data.frame`, one row per specimen
#'       processed, with columns `specimen`, `scale_factor` (the isotropic
#'       factor applied in step 1), `rotation_deg` (the rotation applied in
#'       step 3), `y_shift` (the vertical translation applied immediately
#'       after that rotation to bring the axis to `Y = 0.5`), and
#'       `scale_bar_placed` (logical, whether landmarks 20-21 were
#'       repositioned). Merged with any pre-existing `standardization_log`
#'       from an earlier call, so successive calls accumulate a full
#'       record; note that `old_value`/`new_value` in any pre-existing
#'       `correction_log` (see below) predating a given
#'       `standardization_log` row are expressed in that earlier,
#'       now-superseded coordinate frame.}
#'     \item{`corrected`}{a `p x n` logical matrix, `TRUE` where step (4)
#'       moved that point; used by [plot_fishmorph_points()] to highlight
#'       corrected points in blue. Shared with, and merged across,
#'       [correct_landmarks()] (`rule = "align"`) calls on the same object.}
#'     \item{`correction_log`}{a `data.frame`, one row per point corrected
#'       by step (4), with columns `specimen`, `check`, `landmark`, `axis`,
#'       `old_value`, `new_value`, `reference_points`, `reference_value` --
#'       the same shape as [correct_landmarks()] (`rule = "align"`)'s own
#'       log, so both accumulate into one unified audit trail.}
#'   }
#'
#' @details
#' **Step 1 -- rescale to `[0, 1]` (isotropic).** A single scale factor,
#' `1 / max(range(X), range(Y))` computed over the body landmarks (1-19,
#' plus 22 if present; the scale bar is excluded so its, often arbitrary,
#' position in the original photograph cannot distort the body's own
#' scale), is applied to *both* axes, so body shape (e.g. the ratio of
#' body depth to body length) is preserved exactly -- an independent
#' per-axis rescaling would instead stretch the body and silently corrupt
#' every FISHMORPH ratio and any shape-based analysis (GPA, shape PCA)
#' computed afterwards. Consequently, only the longer of the two axes ends
#' up spanning the full `[0, 1]` range exactly; if X is the shorter axis it
#' is centered within `[0, 1]` at this stage (Y does not need centering
#' here, since step 3 re-anchors it to `Y = 0.5` regardless).
#'
#' **Step 2 -- reposition the scale bar.** Landmarks 20 and 21 (missing for
#' a given specimen, this step is skipped for it, with a warning) are
#' moved to `scale_bar_pos` and `scale_bar_pos + c(length, 0)`
#' respectively, where `length` is their original Euclidean distance
#' multiplied by step 1's scale factor -- i.e. the scale bar keeps the
#' same size *relative to the body* (its calibration meaning is
#' preserved), it is simply drawn as a clean, purely horizontal reference
#' segment in a fixed corner rather than wherever, and at whatever angle,
#' it happened to be digitized.
#'
#' **Step 3 -- rotate the body horizontal, anchored at Y = 0.5.** The
#' whole body (landmarks 1-19, plus 22 if present; the now-repositioned
#' scale bar is a fixed legend element and is neither rotated nor shifted)
#' is rotated rigidly about landmark 1 by whatever angle brings the vector
#' from landmark 1 to landmark 2 exactly onto the positive X axis -- this
#' necessarily also places landmark 1 to the left of landmark 2, so this
#' step also standardizes left-right orientation as a side effect -- and
#' then translated vertically so that this now-horizontal axis sits at
#' `Y = 0.5` for *every* specimen, so standardized configurations line up
#' at a common height for visual comparison. This step does *not*
#' standardize dorsal-ventral orientation (whether landmark 4 sits below
#' landmark 3); pair this function with [standardize_orientation()] if a
#' specimen may also be digitized upside-down. Skipped, with a warning, if
#' landmark 1 or 2 is missing.
#'
#' **Step 4 -- correct remaining conventions.** The same landmark groups
#' `correct_landmarks(rule = "check_geometry")` audits (see its Details for
#' the full list and the two-point-segment anatomical-anchor rationale),
#' now applied in the canonical frame step 3 established, so "vertical"
#' and "horizontal" checks are evaluated directly on raw X/Y:
#' `perpendicular_seg_1_9_vs_axis`, `perpendicular_seg_3_4_vs_axis`, and
#' `perpendicular_seg_10_11_vs_axis` each snap the companion point's X onto
#' its anchor's X; `perpendicular_eye_vertical_vs_axis` snaps *every*
#' point among 5, 13, 7, 14, 6, 8 that sits beyond `tolerance_coord` from
#' their shared median X onto that median (not only the single worst one,
#' since more than one of the six can be misplaced); `axis_horizontal_parallel`
#' does the same for points 9, 8, 11, 4 against their shared median Y. The
#' reference (anchor, or median) is computed once per group, before any
#' correction, so this fully resolves a group with several misplaced
#' points in a single pass; re-running the function is only needed if a
#' later specimen is re-digitized or otherwise changed afterwards. Skipped,
#' with a warning, if step 3 itself was skipped (an axis-relative
#' correction is not meaningful without a horizontal axis).
#'
#' As with [correct_landmarks()], [standardize_orientation()], and
#' [impute_landmarks()], this is not a substitute for re-digitizing from
#' the original photograph when that is possible, and every step is fully
#' logged (`standardization_log`, `correction_log`) for transparency.
#' Because it only ever rescales, translates, and rigidly rotates
#' coordinates -- and only ever corrects a coordinate onto another point's
#' already-present value -- running it twice on already-standardized data
#' is harmless (idempotent up to floating-point precision).
#'
#' @seealso [correct_landmarks()], [standardize_orientation()],
#'   [plot_fishmorph_points()], [impute_landmarks()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' # fix left-right/dorsal-ventral mirroring first (a separate concern from
#' # the rescaling/rotation/alignment this function handles):
#' fish_oriented <- standardize_orientation(fish)
#' fish_std <- correct_geometry(fish_oriented)
#' attr(fish_std$coords, "standardization_log")
#' attr(fish_std$coords, "correction_log")
#' # the scale bar now reads as a clean horizontal segment bottom-left,
#' # and points 9, 8, 11, 4 line up exactly horizontal:
#' plot_fishmorph_points(fish_std, specimen = "T-26-0010_Operator_1")
#'
#' @export
correct_geometry <- function(landmarks, specimen = NULL, scale_bar_pos = c(0.1, 0.1),
                              tolerance_coord = 1e-6) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  if (k != 2) {
    stop("correct_geometry() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "correct_geometry() requires at least 21 landmarks (the FISHMORPH ",
      "scheme, including the scale bar, points 20-21); found ", p, ".",
      call. = FALSE
    )
  }
  if (!is.numeric(scale_bar_pos) || length(scale_bar_pos) != 2 || anyNA(scale_bar_pos)) {
    stop("`scale_bar_pos` must be a length-2 numeric vector c(x, y).", call. = FALSE)
  }
  if (!is.numeric(tolerance_coord) || length(tolerance_coord) != 1 || tolerance_coord < 0) {
    stop(
      "`tolerance_coord` must be a single non-negative number (a proportion of body length, Bl).",
      call. = FALSE
    )
  }

  specimen_names_all <- dimnames(A)[[3]]
  idx_all <- .resolve_specimen_idx(specimen, specimen_names_all)
  body_idx <- if (p >= 22) c(1:19, 22L) else 1:19
  plan <- .geometry_coord_plan()

  corrected_full <- matrix(FALSE, nrow = p, ncol = n, dimnames = list(NULL, specimen_names_all))
  prior_corrected <- attr(A, "corrected")
  if (!is.null(prior_corrected) && all(dim(prior_corrected) == dim(corrected_full))) {
    corrected_full <- prior_corrected
  }
  log_rows <- list()
  std_rows <- vector("list", length(idx_all))
  n_skipped_scale <- 0L
  n_skipped_rotate <- 0L

  for (i in seq_along(idx_all)) {
    idx <- idx_all[i]
    sname <- specimen_names_all[idx]
    xy_orig <- A[, , idx]
    xy <- xy_orig
    scale_factor <- NA_real_
    rotation_deg <- NA_real_
    y_shift <- NA_real_
    scale_bar_placed <- FALSE

    # --- Step 1: isotropic rescale of the body to [0, 1] -----------------
    bbox_x <- range(xy_orig[body_idx, 1], na.rm = TRUE)
    bbox_y <- range(xy_orig[body_idx, 2], na.rm = TRUE)
    span_x <- diff(bbox_x)
    span_y <- diff(bbox_y)
    span <- suppressWarnings(max(span_x, span_y))
    if (is.finite(span) && span > 0) {
      scale_factor <- 1 / span
      xy[, 1] <- (xy_orig[, 1] - bbox_x[1]) * scale_factor
      xy[, 2] <- (xy_orig[, 2] - bbox_y[1]) * scale_factor
      # Center X within [0, 1] if it is the shorter axis; Y is not centered
      # here since step 3 re-anchors the main axis to Y = 0.5 for every
      # specimen regardless of whatever offset this step leaves it at.
      if (span_x < span_y) {
        xy[, 1] <- xy[, 1] + (1 - span_x * scale_factor) / 2
      }
    } else {
      n_skipped_scale <- n_skipped_scale + 1L
    }

    # --- Step 2: reposition the scale bar (20, 21) ------------------------
    if (is.finite(scale_factor) && all(is.finite(xy_orig[c(20, 21), ]))) {
      orig_len <- sqrt(sum((xy_orig[21, ] - xy_orig[20, ])^2))
      new_len <- orig_len * scale_factor
      xy[20, ] <- scale_bar_pos
      xy[21, ] <- scale_bar_pos + c(new_len, 0)
      scale_bar_placed <- TRUE
    }

    # --- Step 3: rotate the body so axis (1, 2) is horizontal ------------
    do_rotate <- is.finite(scale_factor) && all(is.finite(xy[c(1, 2), ]))
    if (do_rotate) {
      v <- xy[2, ] - xy[1, ]
      if (!all(v == 0)) {
        angle <- atan2(v[2], v[1])
        Rmat <- matrix(c(cos(angle), -sin(angle), sin(angle), cos(angle)), nrow = 2)
        pivot <- xy[1, ]
        for (li in body_idx) {
          if (all(is.finite(xy[li, ]))) {
            xy[li, ] <- as.numeric(pivot + Rmat %*% (xy[li, ] - pivot))
          }
        }
        rotation_deg <- -angle * 180 / pi

        # Anchor the now-horizontal axis at Y = 0.5 for every specimen, so
        # standardized configurations line up/compare at a common height --
        # shifts only the body (landmarks in body_idx), never the
        # already-placed, fixed-position scale bar.
        y_shift <- 0.5 - xy[1, 2]
        for (li in body_idx) {
          if (is.finite(xy[li, 2])) xy[li, 2] <- xy[li, 2] + y_shift
        }
      } else {
        do_rotate <- FALSE
      }
    }
    if (!do_rotate) n_skipped_rotate <- n_skipped_rotate + 1L

    # --- Step 4: correct remaining coordinate-scatter conventions --------
    # Every point beyond `tolerance_coord` in a given group is corrected
    # (not only the single worst one), so a group with more than one
    # misplaced point is fully resolved in this one pass.
    if (do_rotate) {
      bl_new <- .body_length(xy)
      if (!is.na(bl_new) && bl_new > 0) {
        for (step in plan) {
          axis_col <- if (step$axis_dim == "x") 1 else 2
          deviants <- .geometry_group_deviants(xy, step, tolerance_coord, bl_new)
          for (dv in deviants) {
            if (isTRUE(all.equal(dv$old_value, dv$reference_value))) next
            xy[dv$correct_pt, axis_col] <- dv$reference_value
            corrected_full[dv$correct_pt, idx] <- TRUE
            log_rows[[length(log_rows) + 1]] <- data.frame(
              specimen = sname, check = step$check, landmark = dv$correct_pt,
              axis = step$axis_dim, old_value = dv$old_value, new_value = dv$reference_value,
              reference_points = paste(sort(dv$reference_pts), collapse = ","),
              reference_value = dv$reference_value,
              stringsAsFactors = FALSE
            )
          }
        }
      }
    }

    A[, , idx] <- xy
    std_rows[[i]] <- data.frame(
      specimen = sname, scale_factor = scale_factor, rotation_deg = rotation_deg,
      y_shift = y_shift, scale_bar_placed = scale_bar_placed, stringsAsFactors = FALSE
    )
  }

  if (n_skipped_scale > 0) {
    warning(sprintf(
      "correct_geometry(): could not rescale %d specimen(s) with degenerate/missing body landmarks.",
      n_skipped_scale
    ), call. = FALSE)
  }
  if (n_skipped_rotate > 0) {
    warning(sprintf(
      "correct_geometry(): could not rotate/correct %d specimen(s) missing landmark 1 or 2.",
      n_skipped_rotate
    ), call. = FALSE)
  }

  new_std <- do.call(rbind, std_rows)
  prior_std <- attr(A, "standardization_log")
  attr(A, "standardization_log") <- if (!is.null(prior_std)) rbind(prior_std, new_std) else new_std

  attr(A, "corrected") <- corrected_full
  if (length(log_rows) > 0) {
    new_log <- do.call(rbind, log_rows)
    prior_log <- attr(A, "correction_log")
    attr(A, "correction_log") <- if (!is.null(prior_log)) rbind(prior_log, new_log) else new_log
    message(sprintf(
      "correct_geometry(): standardized %d specimen(s) (scale + scale bar + rotation); corrected %d landmark coordinate(s) across %d specimen(s) in step 4.",
      length(idx_all), nrow(new_log), length(unique(new_log$specimen))
    ))
  } else {
    message(sprintf(
      "correct_geometry(): standardized %d specimen(s) (scale + scale bar + rotation); nothing left to correct in step 4.",
      length(idx_all)
    ))
  }

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}
