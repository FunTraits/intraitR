#' Standardize every specimen to the same head-left, belly-down orientation
#'
#' Digitization sources vary in how a picture happens to be oriented (fish
#' facing left or right, right-side up or upside down), and in whether Y
#' increases upward (standard Cartesian convention) or downward
#' (image/pixel convention). Rather than a per-plot display toggle (as an
#' earlier version of [plot_fishmorph_points()]'s `flip_y_points` argument
#' offered), `standardize_orientation()` checks and, if needed, mirrors
#' *every specimen*'s actual coordinates using two pairs of landmarks that
#' are present, and anatomically the same two points, in every FISHMORPH
#' digitization: the snout tip and caudal fin base (1, 2) fix the
#' left-right orientation, and the top/bottom of the body at its deepest
#' point (3, 4) fix the dorsal-ventral orientation.
#'
#' @param landmarks An object of class `"intrait_landmarks"`, or a raw
#'   `p x k x n` landmark array, with at least landmarks 1-4 digitized
#'   following the scheme described in [fishmorph_segments()].
#' @param specimen `NULL` (default) to check/correct every specimen, or an
#'   integer/character vector to restrict this to a subset.
#'
#' @return An object of the same class as `landmarks`, with any specimen
#'   not already in the target orientation mirrored (horizontally,
#'   vertically, or both) so that, afterwards, every specimen has the
#'   snout (1) to the left of the caudal fin base (2), and the bottom of
#'   the body (4) below its top (3). The returned `coords` array carries
#'   an `orientation_log` attribute, a `data.frame` with one row per
#'   specimen checked and columns `specimen`, `flipped_x`, `flipped_y`
#'   (logical), for transparency.
#'
#' @details
#' A mirror is a reflection about the midpoint of that specimen's own
#' coordinate range on the relevant axis (the same operation the old
#' `flip_y_points` display toggle used), so the corrected specimen stays
#' in roughly the same coordinate region rather than jumping to a
#' different part of the plane. Because [fishmorph_segments()] and
#' [fishmorph_ratios()] are computed from Euclidean distances between
#' landmarks, mirroring never changes their values -- but it does matter
#' for any geometric-morphometric analysis of *shape* (e.g. [gpa_fish()],
#' [trait_space()] on GPA-derived coordinates, or any PCA of landmark
#' configurations), where an inconsistently mirrored subset of specimens
#' would otherwise be treated as genuinely different in shape from the
#' rest, purely as an artifact of how each picture happened to be taken.
#' Apply this function to the raw digitized landmarks *before* such
#' analyses (a warning is issued if `landmarks` is already an
#' `"intrait_gpa"` object, since Procrustes alignment does not preserve
#' absolute orientation the same way).
#'
#' If a specimen is missing landmark 1, 2, 3, or 4, the corresponding
#' check (left-right or dorsal-ventral) is skipped for it (with a
#' warning), rather than guessed at or treated as an error.
#'
#' @seealso [plot_fishmorph_points()], [gpa_fish()], [impute_landmarks()],
#'   [correct_landmarks()], [correct_geometry()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' fish_oriented <- standardize_orientation(fish)
#' attr(fish_oriented$coords, "orientation_log")
#' plot_fishmorph_points(fish_oriented, specimen = 1)
#'
#' @export
standardize_orientation <- function(landmarks, specimen = NULL) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  if (k != 2) {
    stop("standardize_orientation() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 4) {
    stop(
      "standardize_orientation() requires at least landmarks 1-4 ",
      "(the FISHMORPH scheme); found ", p, ".",
      call. = FALSE
    )
  }
  if (inherits(landmarks, "intrait_gpa")) {
    warning(
      "`landmarks` is an \"intrait_gpa\" object (Procrustes-aligned); ",
      "standardize_orientation() is intended for the original digitized ",
      "coordinates, applied before gpa_fish(), not after.",
      call. = FALSE
    )
  }

  specimen_names_all <- dimnames(A)[[3]]
  idx_all <- .resolve_specimen_idx(specimen, specimen_names_all)

  flip_log <- data.frame(
    specimen = specimen_names_all[idx_all],
    flipped_x = FALSE, flipped_y = FALSE,
    stringsAsFactors = FALSE
  )
  n_skipped_x <- 0L
  n_skipped_y <- 0L

  for (i in seq_along(idx_all)) {
    idx <- idx_all[i]
    xy <- A[, , idx]

    # Left-right: the snout (1) should be to the left of (i.e. have a
    # smaller X than) the caudal fin base (2).
    if (all(is.finite(xy[c(1, 2), 1]))) {
      if (xy[1, 1] > xy[2, 1]) {
        finite_x <- xy[, 1][is.finite(xy[, 1])]
        xy[, 1] <- max(finite_x) + min(finite_x) - xy[, 1]
        flip_log$flipped_x[i] <- TRUE
      }
    } else {
      n_skipped_x <- n_skipped_x + 1L
    }

    # Dorsal-ventral: the bottom of the body (4) should be below (i.e.
    # have a smaller Y than) its top (3).
    if (all(is.finite(xy[c(3, 4), 2]))) {
      if (xy[4, 2] > xy[3, 2]) {
        finite_y <- xy[, 2][is.finite(xy[, 2])]
        xy[, 2] <- max(finite_y) + min(finite_y) - xy[, 2]
        flip_log$flipped_y[i] <- TRUE
      }
    } else {
      n_skipped_y <- n_skipped_y + 1L
    }

    A[, , idx] <- xy
  }

  if (n_skipped_x > 0 || n_skipped_y > 0) {
    warning(
      sprintf(
        paste(
          "standardize_orientation(): could not verify orientation for some",
          "specimen(s) due to missing landmarks (%d left-right check(s),",
          "%d dorsal-ventral check(s) skipped)."
        ),
        n_skipped_x, n_skipped_y
      ),
      call. = FALSE
    )
  }

  attr(A, "orientation_log") <- flip_log
  n_flipped <- sum(flip_log$flipped_x | flip_log$flipped_y)
  message(sprintf(
    "standardize_orientation(): %d of %d specimen(s) mirrored (%d horizontally, %d vertically) to a consistent head-left, belly-down orientation.",
    n_flipped, nrow(flip_log), sum(flip_log$flipped_x), sum(flip_log$flipped_y)
  ))

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}
