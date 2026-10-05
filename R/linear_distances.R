#' Compute inter-landmark linear distances
#'
#' Computes Euclidean distances between user-defined pairs of landmarks
#' (e.g. a truss network, Strauss & Bookstein, 1982) on raw, un-aligned
#' landmark coordinates, optionally converted to real-world units using a
#' digitization scale.
#'
#' @param landmarks An object of class `"intrait_landmarks"` or
#'   `"intrait_gpa"`, or a raw `p x k x n` landmark array. Note: distances
#'   are normally computed on **raw** (pre-Procrustes) coordinates, since
#'   Generalised Procrustes Analysis removes size information; passing an
#'   `"intrait_gpa"` object will return distances in the arbitrary
#'   unit-centroid-size scale of the Procrustes fit.
#' @param pairs A (optionally named) list of length-2 integer vectors, each
#'   giving the indices of two landmarks whose distance should be computed.
#'   List names become the trait names in the output (e.g.
#'   `list(SL = c(1, 2), BD = c(3, 4))`).
#' @param scale Optional numeric vector of scale factors (real-world units
#'   per coordinate unit), one per specimen and named to match specimen
#'   identifiers. If `NULL` and `landmarks` is an `"intrait_landmarks"`
#'   object with a non-missing `scale` element, that scale is used
#'   automatically.
#'
#' @return A `data.frame` with one row per specimen (row names = specimen
#'   identifiers) and one column per entry in `pairs`.
#'
#' @seealso [morpho_ratios()], [read_tps()]
#'
#' @examples
#' # real T-26 Saudrune data; landmark indices follow the FISHMORPH scheme
#' # (see ?fishmorph_segments), so these pairs are anatomically meaningful.
#' # `fish$scale` is not set, so distances stay in raw digitization units
#' # here; use fishmorph_segments() instead for measurements already
#' # converted to centimetres via the embedded scale bar (points 20-21):
#' fish <- load_t26_saudrune_landmarks()
#' pairs <- list(SL = c(1, 2), BD = c(3, 4), HD = c(5, 6))
#' head(linear_distances(fish, pairs))
#'
#' @export
linear_distances <- function(landmarks, pairs, scale = NULL) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  n <- dim(A)[3]
  specimen_names <- dimnames(A)[[3]]

  if (!is.list(pairs) || length(pairs) == 0) {
    stop("`pairs` must be a non-empty list of length-2 landmark index vectors.", call. = FALSE)
  }
  if (is.null(names(pairs)) || any(!nzchar(names(pairs)))) {
    names(pairs) <- vapply(
      pairs, function(pr) paste0("lm", pr[1], "_lm", pr[2]), character(1)
    )
  }
  for (nm in names(pairs)) {
    pr <- pairs[[nm]]
    if (length(pr) != 2 || any(pr < 1) || any(pr > p)) {
      stop("Entry '", nm, "' in `pairs` must be a length-2 vector of landmark indices between 1 and ", p, ".", call. = FALSE)
    }
  }

  if (is.null(scale) && inherits(landmarks, "intrait_landmarks")) {
    scale <- landmarks$scale
  }

  out <- matrix(
    NA_real_,
    nrow = n, ncol = length(pairs),
    dimnames = list(specimen_names, names(pairs))
  )
  for (nm in names(pairs)) {
    lm1 <- pairs[[nm]][1]
    lm2 <- pairs[[nm]][2]
    diff_mat <- A[lm1, , ] - A[lm2, , ]
    if (is.null(dim(diff_mat))) diff_mat <- matrix(diff_mat, ncol = n)
    out[, nm] <- sqrt(colSums(diff_mat^2))
  }

  if (!is.null(scale)) {
    if (is.null(names(scale))) {
      if (length(scale) != n) {
        stop("`scale` must be named to match specimens, or have exactly one value per specimen.", call. = FALSE)
      }
      names(scale) <- specimen_names
    }
    missing_scale <- setdiff(specimen_names, names(scale))
    if (length(missing_scale) > 0) {
      warning("No scale factor available for ", length(missing_scale), " specimen(s); distances left in digitization units for those rows.", call. = FALSE)
    }
    scale_vec <- scale[specimen_names]
    has_scale <- !is.na(scale_vec)
    out[has_scale, ] <- out[has_scale, , drop = FALSE] * scale_vec[has_scale]
  }

  as.data.frame(out)
}
