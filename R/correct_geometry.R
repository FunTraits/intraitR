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
#'   specimen's coordinates replaced by their standardized version, and,
#'   if `landmarks` is an `intrait_landmarks` object with a `$scale`
#'   element, that element rescaled to match (see Details, step 1) so
#'   that no specimen's true real-world size is lost even though every
#'   specimen is now drawn at the same visual size. The returned `coords`
#'   array carries three attributes:
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
#' here, since step 3 re-anchors it to `Y = 0.5` regardless). This step
#' changes the *visual* size every specimen is drawn at (every body now
#' spans the same `[0, 1]` box, regardless of how large the real fish
#' was), but never the *information* about each specimen's true
#' real-world size: if `landmarks` is an `intrait_landmarks` object with a
#' `$scale` element (real-world units per pixel; see [read_tps()]), that
#' element is itself divided by the same per-specimen `scale_factor`, so
#' [linear_distances()]/[morpho_ratios()] (which use `$scale` directly)
#' keep returning correct, specimen-specific real-world distances from the
#' now-normalized coordinates; [fishmorph_segments()] needs no such
#' adjustment, since it always re-derives its own pixel-to-real-world
#' factor from the scale bar's own current length (step 2 below) rather
#' than from a stored value. Two different specimens rescaled to the same
#' `[0, 1]` box therefore still yield different, individually correct
#' real-world sizes downstream -- only their on-screen size is equalized.
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
#' Steps 1-3 (never change any FISHMORPH segment/ratio value: rescaling,
#' translation, and rigid rotation all preserve Euclidean distances and
#' therefore every ratio computed from them) and step 4 (which does change
#' values) are also available as two separate functions,
#' [standardize_geometry()] and [correct_geometry_conventions()], for
#' workflows that want to inspect or use the value-preserving
#' standardization on its own -- e.g. before deciding, from
#' `correct_landmarks(rule = "check_geometry")`'s audit, whether step 4's
#' automatic correction is appropriate for a given data set or species.
#' `correct_geometry()` itself is unaffected and remains the same one-call
#' pipeline as before (equivalent to `standardize_geometry(landmarks, ...,
#' orient = FALSE)` followed by `correct_geometry_conventions()`).
#'
#' @seealso [standardize_geometry()], [correct_geometry_conventions()],
#'   [correct_landmarks()], [standardize_orientation()],
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

  # `landmarks$scale` (real-world units per raw digitization pixel; see
  # read_tps()) is calibrated for the ORIGINAL coordinates. Step 1 below
  # rescales those coordinates per specimen by `scale_factor`, so a raw
  # distance measured after this function equals `scale_factor` times the
  # same raw distance before it; left untouched, `landmarks$scale` would
  # then silently give wrong real-world distances to anything that uses it
  # directly (linear_distances(), and morpho_ratios() through it) -- unlike
  # fishmorph_segments(), which is unaffected because it always re-derives
  # its own pixel-to-real-world factor from the scale bar's (proportionally
  # transformed, see step 2) current length rather than trusting a stored
  # value. Dividing each rescaled specimen's `scale` by its own
  # `scale_factor` keeps both routes consistent and correct.
  has_scale_attr <- inherits(landmarks, "intrait_landmarks") && !is.null(landmarks$scale)
  n_scale_attr_updated <- 0L

  for (i in seq_along(idx_all)) {
    idx <- idx_all[i]
    sname <- specimen_names_all[idx]
    xy_orig <- A[, , idx]

    # Steps 1-3 (value-preserving: rescale + scale bar + rotation) and step
    # 4 (value-changing: geometric-convention correction) are factored into
    # shared internal helpers -- also used standalone by the newer
    # standardize_geometry()/correct_geometry_conventions() functions -- so
    # this loop only orchestrates warnings/messages/logging around them;
    # the geometry math itself is unchanged from earlier package versions.
    std <- .geometry_standardize_one(xy_orig, body_idx, scale_bar_pos)
    xy <- std$xy

    if (is.na(std$scale_factor)) {
      n_skipped_scale <- n_skipped_scale + 1L
    } else if (has_scale_attr && !is.na(landmarks$scale[[sname]])) {
      landmarks$scale[[sname]] <- landmarks$scale[[sname]] / std$scale_factor
      n_scale_attr_updated <- n_scale_attr_updated + 1L
    }
    if (!std$rotated) n_skipped_rotate <- n_skipped_rotate + 1L

    # Every point beyond `tolerance_coord` in a given group is corrected
    # (not only the single worst one), so a group with more than one
    # misplaced point is fully resolved in this one pass.
    if (std$rotated) {
      corr <- .geometry_correct_one(xy, tolerance_coord, plan)
      xy <- corr$xy
      if (length(corr$log_rows) > 0) {
        for (lr in corr$log_rows) {
          lr$specimen <- sname
          lr <- lr[c(
            "specimen", "check", "landmark", "axis", "old_value",
            "new_value", "reference_points", "reference_value"
          )]
          log_rows[[length(log_rows) + 1]] <- lr
        }
        corrected_full[corr$corrected_pts, idx] <- TRUE
      }
    }

    A[, , idx] <- xy
    std_rows[[i]] <- data.frame(
      specimen = sname, scale_factor = std$scale_factor, rotation_deg = std$rotation_deg,
      y_shift = std$y_shift, scale_bar_placed = std$scale_bar_placed, stringsAsFactors = FALSE
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
  if (n_scale_attr_updated > 0) {
    message(sprintf(
      paste(
        "correct_geometry(): rescaled `landmarks$scale` for %d specimen(s) to stay",
        "consistent with their rescaled coordinates (so linear_distances()/",
        "morpho_ratios() keep returning correct real-world distances; unaffected:",
        "fishmorph_segments(), which always re-derives its own scale from the scale",
        "bar's current length instead)."
      ),
      n_scale_attr_updated
    ))
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
