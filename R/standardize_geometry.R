#' Standardize landmark scale, scale-bar position, and rotation, without
#' changing any measurement value
#'
#' The value-preserving half of [correct_geometry()]'s pipeline (its steps
#' 1-3), available on its own: (1) rescale the body landmarks isotropically
#' so they fit within `[0, 1]` (preserving body shape); (2) reposition the
#' embedded scale bar (landmarks 20-21) to a fixed corner of that `[0, 1]`
#' space; (3) rotate the body so the main axis (landmarks 1-2) is exactly
#' horizontal, landmark 1 to the left of landmark 2, anchored at `Y = 0.5`
#' for every specimen. Because it only ever rescales, translates, and
#' rigidly rotates coordinates, it never changes any FISHMORPH segment or
#' ratio value (Euclidean distances, and therefore every ratio computed
#' from them, are invariant under these operations) -- see Details. This is
#' in contrast to [correct_geometry_conventions()] (step 4), which actively
#' moves landmarks and does change values.
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
#'   factor as the body -- so the calibration ratio between the scale bar
#'   and the body is preserved, only its position and orientation are
#'   standardized. Defaults to `c(0.1, 0.1)` (bottom-left).
#' @param orient Logical, whether to call [standardize_orientation()]
#'   first, before steps 1-3, so a specimen digitized mirrored
#'   (left-right) or upside-down (dorsal-ventral) is corrected before
#'   rescaling/rotation rather than needing a separate call. Defaults to
#'   `TRUE`, coupling the two functions that earlier versions of this
#'   package's documentation already recommended chaining manually (`fish
#'   \%>\% standardize_orientation() \%>\% standardize_geometry(orient =
#'   FALSE)` is equivalent to the default `standardize_geometry(fish)`).
#'   Set to `FALSE` if orientation was already standardized separately (as
#'   [correct_geometry()] itself does internally, to stay behaviour
#'   identical across package versions), or if you deliberately want to
#'   preserve each specimen's original mirroring.
#'
#' @return An object of the same class as `landmarks`, with every
#'   specimen's coordinates replaced by their standardized version, and,
#'   if `landmarks` is an `"intrait_landmarks"` object with a `$scale`
#'   element, that element rescaled to match (see Details) so that no
#'   specimen's true real-world size is lost even though every specimen is
#'   now drawn at the same visual size. The returned `coords` array carries
#'   a `standardization_log` attribute, a `data.frame`, one row per
#'   specimen processed, with columns `specimen`, `scale_factor` (the
#'   isotropic factor applied in step 1), `rotation_deg` (the rotation
#'   applied in step 3), `y_shift` (the vertical translation applied
#'   immediately after that rotation to bring the axis to `Y = 0.5`), and
#'   `scale_bar_placed` (logical, whether landmarks 20-21 were
#'   repositioned). Merged with any pre-existing `standardization_log` from
#'   an earlier call, so successive calls accumulate a full record. If
#'   `orient = TRUE`, the returned object also carries `orientation_log`
#'   from the internal [standardize_orientation()] call (see its own
#'   Return).
#'
#' @details
#' See [correct_geometry()]'s Details for the full rationale behind each of
#' the three steps (isotropic rescale, scale-bar repositioning, rotation +
#' vertical anchoring), which this function implements identically -- the
#' only difference is that step 4 (active correction of landmarks that
#' still violate the FISHMORPH geometric conventions once the axis is
#' horizontal) is not performed here; call
#' [correct_geometry_conventions()] afterwards for that, or use
#' [correct_geometry()] directly for the combined pipeline in one call.
#'
#' As with [correct_geometry()], running this function twice on
#' already-standardized data is harmless (idempotent up to floating-point
#' precision): a specimen already isotropically scaled to `[0, 1]` and
#' horizontal is left materially unchanged by a second pass.
#'
#' @seealso [correct_geometry_conventions()] (step 4, which does change
#'   values), [correct_geometry()] (the combined pipeline, unchanged and
#'   still the recommended one-call route for existing workflows),
#'   [standardize_orientation()], [correct_landmarks()],
#'   [plot_fishmorph_points()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' # orientation (left-right/dorsal-ventral mirroring) is standardized
#' # automatically first, by default:
#' fish_std <- standardize_geometry(fish)
#' attr(fish_std$coords, "orientation_log")
#' attr(fish_std$coords, "standardization_log")
#'
#' # equivalent to the pre-existing two-call workflow:
#' fish_std2 <- standardize_geometry(standardize_orientation(fish), orient = FALSE)
#'
#' # then, only if/where desired, actively correct remaining conventions:
#' fish_corrected <- correct_geometry_conventions(fish_std)
#'
#' @export
standardize_geometry <- function(landmarks, specimen = NULL,
                                  scale_bar_pos = c(0.1, 0.1), orient = TRUE) {
  if (isTRUE(orient)) {
    landmarks <- standardize_orientation(landmarks, specimen = specimen)
  } else if (!isFALSE(orient)) {
    stop("`orient` must be TRUE or FALSE.", call. = FALSE)
  }

  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  if (k != 2) {
    stop("standardize_geometry() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "standardize_geometry() requires at least 21 landmarks (the FISHMORPH ",
      "scheme, including the scale bar, points 20-21); found ", p, ".",
      call. = FALSE
    )
  }
  if (!is.numeric(scale_bar_pos) || length(scale_bar_pos) != 2 || anyNA(scale_bar_pos)) {
    stop("`scale_bar_pos` must be a length-2 numeric vector c(x, y).", call. = FALSE)
  }

  specimen_names_all <- dimnames(A)[[3]]
  idx_all <- .resolve_specimen_idx(specimen, specimen_names_all)
  body_idx <- if (p >= 22) c(1:19, 22L) else 1:19

  std_rows <- vector("list", length(idx_all))
  n_skipped_scale <- 0L
  n_skipped_rotate <- 0L

  # See correct_geometry()'s own comment on this same pattern: keeps
  # `landmarks$scale` (real-world units per raw digitization pixel)
  # consistent with the rescaled coordinates, for linear_distances()/
  # morpho_ratios(); fishmorph_segments() is unaffected, since it always
  # re-derives its own scale from the scale bar's current length instead.
  has_scale_attr <- inherits(landmarks, "intrait_landmarks") && !is.null(landmarks$scale)
  n_scale_attr_updated <- 0L

  for (i in seq_along(idx_all)) {
    idx <- idx_all[i]
    sname <- specimen_names_all[idx]
    xy_orig <- A[, , idx]

    std <- .geometry_standardize_one(xy_orig, body_idx, scale_bar_pos)
    A[, , idx] <- std$xy

    if (is.na(std$scale_factor)) {
      n_skipped_scale <- n_skipped_scale + 1L
    } else if (has_scale_attr && !is.na(landmarks$scale[[sname]])) {
      landmarks$scale[[sname]] <- landmarks$scale[[sname]] / std$scale_factor
      n_scale_attr_updated <- n_scale_attr_updated + 1L
    }
    if (!std$rotated) n_skipped_rotate <- n_skipped_rotate + 1L

    std_rows[[i]] <- data.frame(
      specimen = sname, scale_factor = std$scale_factor, rotation_deg = std$rotation_deg,
      y_shift = std$y_shift, scale_bar_placed = std$scale_bar_placed, stringsAsFactors = FALSE
    )
  }

  if (n_skipped_scale > 0) {
    warning(sprintf(
      "standardize_geometry(): could not rescale %d specimen(s) with degenerate/missing body landmarks.",
      n_skipped_scale
    ), call. = FALSE)
  }
  if (n_skipped_rotate > 0) {
    warning(sprintf(
      "standardize_geometry(): could not rotate %d specimen(s) missing landmark 1 or 2.",
      n_skipped_rotate
    ), call. = FALSE)
  }
  if (n_scale_attr_updated > 0) {
    message(sprintf(
      paste(
        "standardize_geometry(): rescaled `landmarks$scale` for %d specimen(s) to stay",
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

  message(sprintf(
    paste(
      "standardize_geometry(): standardized %d specimen(s) (isotropic rescale +",
      "scale bar + rotation); no landmark coordinate value was corrected (see",
      "correct_geometry_conventions() for that)."
    ),
    length(idx_all)
  ))

  if (inherits(landmarks, "intrait_landmarks") || inherits(landmarks, "intrait_gpa")) {
    landmarks$coords <- A
    return(landmarks)
  }
  A
}
