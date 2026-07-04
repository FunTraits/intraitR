#' Manually correct a misplaced landmark using an alignment rule
#'
#' Applies a documented, reproducible correction to one or more landmark
#' coordinates for a single specimen, after visual quality-control (e.g.
#' with [plot_fishmorph_points()]) has identified a misplaced point --
#' rather than editing digitized coordinates by hand outside the package,
#' leaving no record of what changed or why. Currently implements one rule,
#' `"align"`: some landmark groups are expected, by the digitization
#' protocol, to share the same X or Y coordinate (e.g. points 9, 8, 11, 4,
#' the ventral reference line drawn by [plot_fishmorph_points()]'s
#' `outline`); when one of them is visibly off, `correct_landmarks()` snaps
#' *only* the specified point(s) to the median position of the other,
#' trusted points in the group -- it never silently decides on its own
#' which point is wrong.
#'
#' @param landmarks An object of class `"intrait_landmarks"`, or a raw
#'   `p x k x n` landmark array.
#' @param specimen For `rule = "align"`, an integer index or character
#'   specimen identifier of the single specimen to correct (as in
#'   [plot_fishmorph_points()]). For `rule = "check_geometry"`, `NULL`
#'   (default) to check every specimen, or an integer/character vector to
#'   restrict the check to a subset.
#' @param rule Character, the operation to perform: `"align"` (default,
#'   see Details) manually corrects one or more landmark coordinates;
#'   `"check_geometry"` instead *audits* (without modifying anything) a
#'   fixed battery of geometric conventions expected of the FISHMORPH
#'   landmark scheme (see Details) and returns a diagnostic report -- a
#'   natural first pass to run *before* deciding which points, if any, need
#'   `rule = "align"`.
#' @param points Integer vector of landmark indices that are expected, for
#'   this specimen, to share the same `axis` coordinate. Only used by
#'   `rule = "align"`.
#' @param correct Integer vector, a non-empty subset of `points`: the
#'   landmark(s) to actually move (i.e. the one(s) visually identified as
#'   misplaced). Every other point in `points` is treated as a trusted
#'   reference for computing the corrected value, but is never itself
#'   modified. Only used by `rule = "align"`.
#' @param axis Character, `"y"` (default) or `"x"`, the coordinate expected
#'   to be shared across `points`. Only used by `rule = "align"`.
#' @param tolerance Numeric, degrees of angular deviation tolerated before
#'   the two orientation-based `rule = "check_geometry"` checks
#'   (`eye_axis_vertical_alignment`, `parallel_vertical_segments`; see
#'   Details) are flagged as non-conforming. Defaults to `2`. Only used by
#'   `rule = "check_geometry"`.
#' @param tolerance_coord Numeric, proportion of body length (Bl, the
#'   distance between landmarks 1 and 2) tolerated before one of the five
#'   landmark-coordinate-scatter `rule = "check_geometry"` checks (see
#'   Details) is flagged as non-conforming -- the same checks
#'   [correct_geometry()] acts on, using the identical criterion, so a
#'   check flagged here is exactly the set [correct_geometry()] will
#'   correct. Defaults to `0.02` (2% of body length); tighten or loosen
#'   based on the digitization precision you expect, e.g. by inspecting
#'   the distribution of `deviation` for `unit == "rel_bl"` rows across
#'   your own data set before settling on a final value. Only used by
#'   `rule = "check_geometry"`.
#'
#' @return
#' For `rule = "align"`: an object of the same class as `landmarks`, with
#' `correct`'s `axis` coordinate, for `specimen` only, set to the median
#' `axis` value of `setdiff(points, correct)`. The returned `coords` array
#' carries two attributes, both merged with any pre-existing ones from an
#' earlier `correct_landmarks()` call on the same object, so a full audit
#' trail accumulates across successive corrections:
#'   \describe{
#'     \item{`corrected`}{a `p x n` logical matrix (as in
#'       [impute_landmarks()]'s `imputed` attribute), `TRUE` where that
#'       point has been manually corrected; used by
#'       [plot_fishmorph_points()] to highlight corrected points in blue.
#'       Shared with, and merged across, [correct_geometry()] calls on the
#'       same object, so a point corrected by either function is
#'       highlighted the same way.}
#'     \item{`correction_log`}{a `data.frame`, one row per corrected point
#'       across all calls (from this function *and* from
#'       [correct_geometry()], which logs to the same attribute), with
#'       columns `specimen`, `check` (`"align"` for rows from this
#'       function), `landmark`, `axis`, `old_value`, `new_value`,
#'       `reference_points`, `reference_value`,
#'       recording exactly what was changed and from what reference, for
#'       reproducibility (e.g. reporting in a manuscript's methods or a QC
#'       log, as `data-raw/t26_saudrune_prepare.R` does for the bundled
#'       real data set).}
#'   }
#'
#' For `rule = "check_geometry"`: an object of class
#' `"intrait_geometry_check"` (and `"data.frame"`), one row per
#' specimen/check combination, with columns `specimen`, `check`,
#' `deviation` (the measured deviation from the expected convention, in
#' whatever `unit` this row uses), `unit` (`"deg"` for the two
#' orientation-based checks, `"rel_bl"` -- a proportion of body length --
#' for the five landmark-coordinate-scatter checks; see Details),
#' `tolerance` (the `tolerance` or `tolerance_coord` value applicable to
#' this row's `unit`), and `ok` (logical; `NA` if the check could not be
#' computed because a required landmark was missing for that specimen).
#' Has a dedicated print method.
#'
#' @details
#' `rule = "align"` computes the reference value as the *median* (not
#' mean) of `setdiff(points, correct)`'s `axis` coordinate, for robustness
#' if one of the trusted reference points also happens to be slightly off;
#' with very few reference points (e.g. two), this offers little
#' protection and the correction should be visually re-checked afterwards.
#' Only `specimen` is modified; every other specimen's landmarks are left
#' untouched. As with [impute_landmarks()], this is not a substitute for
#' re-digitizing from the original photograph when that is possible.
#'
#' `rule = "check_geometry"` runs a fixed set of seven checks, of two
#' different kinds:
#'
#' Five checks ask whether a landmark group shares the raw coordinate the
#' FISHMORPH protocol expects of it (`unit = "rel_bl"`, gated by
#' `tolerance_coord`; identical to the criterion [correct_geometry()] uses
#' to decide what to correct): (1)-(3) each of the segments (1, 9), (3, 4),
#' (10, 11) should share a common X (i.e. be vertical, perpendicular to
#' the main body axis) -- reported as `perpendicular_seg_1_9_vs_axis`,
#' `perpendicular_seg_3_4_vs_axis`, `perpendicular_seg_10_11_vs_axis`; (4)
#' the eye-socket line (5, 13, 7, 14, 6, 8) should likewise share a common
#' X, reported as `perpendicular_eye_vertical_vs_axis`; (5) the ventral
#' line (9, 8, 11, 4) should share a common Y (i.e. be horizontal,
#' parallel to the main axis), reported as `axis_horizontal_parallel`. For
#' each, the deviation is the absolute difference between the most
#' deviant point's coordinate and the shared reference value the other
#' point(s) agree on (median, for the two multi-point groups; a fixed
#' anatomical anchor, for the three two-point segments -- see
#' [correct_geometry()]'s Details for why), expressed as a proportion of
#' body length (Bl, the distance between landmarks 1 and 2) so the same
#' default tolerance is meaningful across specimens/data sets digitized at
#' different scales.
#'
#' Two further checks remain angular (`unit = "deg"`, gated by
#' `tolerance`), because they compare the *orientation* of two lines
#' rather than asking whether a single group of points shares a
#' coordinate, and are deliberately sensitive to how the photograph itself
#' was oriented: (6) `eye_axis_vertical_alignment`, whether the eye-socket
#' line's own best-fit orientation is close to vertical *in the image's
#' own frame* (i.e. the photograph itself looks reasonably level -- this
#' can, and should, fail for a validly measured but visibly rotated
#' photograph, which is why it is excluded from
#' [fishmorph_segments()]'s `geometry_check` trait-NA-ing); and (7)
#' `parallel_vertical_segments`, whether segments (1,9), (3,4), (10,11),
#' and the eye-socket line are mutually parallel to each other (reported
#' as the single largest pairwise deviation among them). A line's
#' orientation, for these two checks, is estimated by its first principal
#' axis (via [stats::prcomp()]), which reduces to the exact two-point
#' direction for two-landmark segments and is a robust fit for the
#' longer, multi-landmark lines.
#'
#' Specimens missing a landmark needed by a given check yield `NA` for
#' that check rather than an error (mirroring the rest of the package's
#' tolerance of missing landmarks, e.g. `outline` in
#' [plot_fishmorph_points()]); the five coordinate checks additionally
#' yield `NA` if landmark 1 or 2 (needed to compute Bl) is missing.
#'
#' @seealso [plot_fishmorph_points()], [impute_landmarks()],
#'   [detect_outliers()], [correct_geometry()] (automatic correction of
#'   whatever `rule = "check_geometry"` flags, rather than a manually
#'   named point)
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' plot_fishmorph_points(fish, specimen = "T-26-0010_Operator_1") # point 11 looks off
#' fish_fixed <- correct_landmarks(
#'   fish, specimen = "T-26-0010_Operator_1",
#'   points = c(9, 8, 11, 4), correct = 11, axis = "y"
#' )
#' plot_fishmorph_points(fish_fixed, specimen = "T-26-0010_Operator_1") # point 11 now in blue
#'
#' # Audit the FISHMORPH geometric conventions across the whole data set
#' # before deciding which specimens/points need rule = "align" -- or use
#' # correct_geometry() to correct every flagged specimen automatically:
#' geom_check <- correct_landmarks(fish, rule = "check_geometry")
#' geom_check
#'
#' @export
correct_landmarks <- function(landmarks, specimen = NULL, rule = c("align", "check_geometry"),
                               points = NULL, correct = NULL, axis = c("y", "x"),
                               tolerance = 2, tolerance_coord = 0.02) {
  rule <- match.arg(rule)
  axis <- match.arg(axis)
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  if (k != 2) {
    stop("correct_landmarks() requires two-dimensional landmark configurations.", call. = FALSE)
  }

  if (rule == "check_geometry") {
    return(.check_landmark_geometry(A, specimen, tolerance, tolerance_coord, p))
  }

  if (is.null(specimen) || length(specimen) != 1) {
    stop("`specimen` must identify a single specimen for rule = \"align\".", call. = FALSE)
  }
  if (is.null(points) || is.null(correct)) {
    stop("`points` and `correct` are required for rule = \"align\".", call. = FALSE)
  }
  if (is.character(specimen)) {
    idx <- match(specimen, dimnames(A)[[3]])
    if (is.na(idx)) stop("Specimen '", specimen, "' not found.", call. = FALSE)
  } else {
    idx <- specimen
  }
  if (any(points < 1) || any(points > p) || any(correct < 1) || any(correct > p)) {
    stop("`points` and `correct` must be valid landmark indices (1-", p, ").", call. = FALSE)
  }
  if (length(correct) == 0 || !all(correct %in% points)) {
    stop("`correct` must be a non-empty subset of `points`.", call. = FALSE)
  }
  reference_points <- setdiff(points, correct)
  if (length(reference_points) == 0) {
    stop(
      "`points` must include at least one landmark not in `correct`, to ",
      "compute a reference value from.",
      call. = FALSE
    )
  }

  axis_col <- if (axis == "y") 2 else 1
  axis_vals <- A[, axis_col, idx]
  ref_value <- stats::median(axis_vals[reference_points], na.rm = TRUE)
  if (!is.finite(ref_value)) {
    stop(
      "Could not compute a reference value: all of `reference_points` (",
      paste(reference_points, collapse = ", "), ") are NA for this specimen.",
      call. = FALSE
    )
  }
  old_values <- axis_vals[correct]

  specimen_name <- dimnames(A)[[3]][idx]
  new_log <- data.frame(
    specimen = specimen_name,
    check = "align", # distinguishes rows from correct_geometry()'s automatic checks
    landmark = correct,
    axis = axis,
    old_value = old_values,
    new_value = ref_value,
    reference_points = paste(sort(reference_points), collapse = ","),
    reference_value = ref_value,
    stringsAsFactors = FALSE
  )

  A[correct, axis_col, idx] <- ref_value

  corrected_full <- matrix(
    FALSE, nrow = p, ncol = n, dimnames = list(NULL, dimnames(A)[[3]])
  )
  prior_corrected <- attr(A, "corrected")
  if (!is.null(prior_corrected) && all(dim(prior_corrected) == dim(corrected_full))) {
    corrected_full <- prior_corrected
  }
  corrected_full[correct, idx] <- TRUE
  attr(A, "corrected") <- corrected_full

  prior_log <- attr(A, "correction_log")
  attr(A, "correction_log") <- if (!is.null(prior_log)) rbind(prior_log, new_log) else new_log

  message(sprintf(
    "correct_landmarks(): specimen '%s', landmark(s) %s: %s set to %.3f (median of point(s) %s).",
    specimen_name, paste(correct, collapse = ", "), axis,
    ref_value, paste(sort(reference_points), collapse = ", ")
  ))

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}

#' Audit the FISHMORPH geometric conventions for `correct_landmarks()`
#'
#' @param A A `p x k x n` coordinate array.
#' @param specimen `NULL` (every specimen), or an integer/character vector
#'   of specimens to check.
#' @param tolerance Numeric, degrees (the two orientation-based checks).
#' @param tolerance_coord Numeric, proportion of body length (the five
#'   landmark-coordinate-scatter checks).
#' @param p Integer, `dim(A)[1]` (passed in rather than recomputed).
#' @return An object of class `c("intrait_geometry_check", "data.frame")`.
#' @noRd
.check_landmark_geometry <- function(A, specimen, tolerance, tolerance_coord, p) {
  if (p < 19) {
    stop(
      "rule = \"check_geometry\" requires at least 19 anatomical landmarks ",
      "(the FISHMORPH scheme); found ", p, ".",
      call. = FALSE
    )
  }
  if (!is.numeric(tolerance) || length(tolerance) != 1 || tolerance <= 0) {
    stop("`tolerance` must be a single positive number (degrees).", call. = FALSE)
  }
  if (!is.numeric(tolerance_coord) || length(tolerance_coord) != 1 || tolerance_coord <= 0) {
    stop(
      "`tolerance_coord` must be a single positive number (a proportion of body length, Bl).",
      call. = FALSE
    )
  }

  specimen_names_all <- dimnames(A)[[3]]
  idx_all <- .resolve_specimen_idx(specimen, specimen_names_all)

  groups <- .geometry_check_groups()
  vertical_defs <- groups[c("seg_1_9", "seg_3_4", "seg_10_11", "eye_vertical")]
  pair_idx <- utils::combn(names(vertical_defs), 2, simplify = FALSE)
  coord_plan <- .geometry_coord_plan()

  rows <- vector("list", length(idx_all))
  for (i in seq_along(idx_all)) {
    idx <- idx_all[i]
    xy <- A[, , idx]
    sname <- specimen_names_all[idx]
    bl <- .body_length(xy)

    vert_angles <- lapply(vertical_defs, function(pts) .line_angle_deg(xy[pts, , drop = FALSE]))

    checks <- list()
    units <- list()
    tols <- list()

    # (1) eye-socket line aligned on X *in the image's own frame* (i.e. a
    # vertical line, angle ~ 90deg) -- deliberately rotation-sensitive; see
    # Details in correct_landmarks()'s roxygen documentation.
    eye_angle <- vert_angles$eye_vertical
    checks[["eye_axis_vertical_alignment"]] <- if (is.na(eye_angle)) NA_real_ else abs(eye_angle - 90)
    units[["eye_axis_vertical_alignment"]] <- "deg"
    tols[["eye_axis_vertical_alignment"]] <- tolerance

    # (2)+(4) the five landmark-coordinate-scatter checks -- identical
    # criterion to correct_geometry(), via the shared .geometry_coord_plan()/
    # .geometry_step_deviation().
    for (step in coord_plan) {
      dev <- .geometry_step_deviation(xy, step)$deviation
      checks[[step$check]] <- if (is.na(dev) || is.na(bl) || bl <= 0) NA_real_ else dev / bl
      units[[step$check]] <- "rel_bl"
      tols[[step$check]] <- tolerance_coord
    }

    # (3) the four "vertical" segments are mutually parallel to each other
    pair_deltas <- vapply(pair_idx, function(pr) {
      .angle_between_deg(vert_angles[[pr[1]]], vert_angles[[pr[2]]])
    }, numeric(1))
    checks[["parallel_vertical_segments"]] <-
      if (all(is.na(pair_deltas))) NA_real_ else max(pair_deltas, na.rm = TRUE)
    units[["parallel_vertical_segments"]] <- "deg"
    tols[["parallel_vertical_segments"]] <- tolerance

    rows[[i]] <- data.frame(
      specimen = sname,
      check = names(checks),
      deviation = unlist(checks, use.names = FALSE),
      unit = unlist(units, use.names = FALSE),
      tolerance = unlist(tols, use.names = FALSE),
      stringsAsFactors = FALSE
    )
  }

  result <- do.call(rbind, rows)
  result$ok <- ifelse(is.na(result$deviation), NA, result$deviation <= result$tolerance)
  rownames(result) <- NULL
  structure(result, class = c("intrait_geometry_check", "data.frame"))
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname correct_landmarks
#' @param x An object of class `"intrait_geometry_check"`, as returned by
#'   `correct_landmarks(rule = "check_geometry")`.
#' @param ... Currently unused.
print.intrait_geometry_check <- function(x, ...) {
  cat("<intrait_geometry_check>\n")
  n_specimens <- length(unique(x$specimen))
  n_fail <- sum(!x$ok, na.rm = TRUE)
  n_na <- sum(is.na(x$ok))
  tol_deg <- x$tolerance[x$unit == "deg"][1]
  tol_coord <- x$tolerance[x$unit == "rel_bl"][1]
  cat(sprintf(
    "  %d check(s) across %d specimen(s): %d non-conforming, %d skipped (missing landmark(s))\n",
    nrow(x), n_specimens, n_fail, n_na
  ))
  cat(sprintf(
    "  tolerance = %s deg (orientation checks), %s of body length (coordinate checks)\n",
    if (is.na(tol_deg)) "NA" else formatC(tol_deg, format = "f", digits = 1),
    if (is.na(tol_coord)) "NA" else sprintf("%.1f%%", 100 * tol_coord)
  ))
  if (n_fail > 0) {
    cat("\n  Non-conforming:\n")
    # Base `[.data.frame` preserves the "intrait_geometry_check" class on a
    # row/column subset (it restores the original object's full class
    # vector), which would otherwise make this print() re-dispatch to
    # print.intrait_geometry_check() on a subset missing the `ok` column
    # (infinite-recursion-shaped, and erroring on `!x$ok` once `ok` is
    # gone) -- resetting the class first ensures a plain data.frame print.
    non_conforming <- x[!is.na(x$ok) & !x$ok, c("specimen", "check", "deviation", "unit", "tolerance")]
    class(non_conforming) <- "data.frame"
    print(non_conforming, row.names = FALSE)
  }
  invisible(x)
}
