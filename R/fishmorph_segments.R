#' Compute linear morphological measurements following the FISHMORPH protocol
#'
#' Computes the 11 linear morphological measurements used by Brosse et al.
#' (2021) to build the FISHMORPH database, from a fixed 21- (or 22-)
#' landmark digitization scheme (see Details), including automatic
#' conversion from digitization (pixel) units to centimetres using a
#' scale bar digitized directly on the picture.
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()], [read_landmarks_csv()], or [simulate_fishmorph_points()]),
#'   or a raw `p x k x n` landmark array, digitized following the point
#'   scheme described in Details. Must contain at least 21 landmarks, in
#'   2 dimensions.
#' @param scale_cm Numeric, the real-world distance, in centimetres,
#'   represented by the scale bar digitized at points 20-21 (typically the
#'   width of a 1 cm section of a ruler placed in the picture). Defaults to
#'   `1`.
#'
#' @return A `data.frame` (class `"intrait_segments"`) with one row per
#'   specimen and columns `Bl`, `Bd`, `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`,
#'   `Jl`, `CPd`, `CFd` (all in centimetres), preceded by any metadata
#'   columns carried over from `landmarks`.
#'
#' @details
#' `fishmorph_segments()` implements the digitization scheme of Brosse
#' et al. (2021) (their figure 1a), in which 21 (optionally 22) landmarks
#' are placed on a lateral-view picture of a fish, in the following fixed
#' order:
#' \describe{
#'   \item{1}{snout tip (top of the mouth)}
#'   \item{2}{posterior insertion of the caudal fin (caudal fin basis)}
#'   \item{3-4}{top and bottom of the body at its deepest point (body depth)}
#'   \item{5-6}{top of the head and bottom of the head/jaw at the vertical
#'     of the eye (head depth)}
#'   \item{7-8}{centre of the eye and bottom of the body at the same
#'     vertical (eye position)}
#'   \item{9}{bottom of the body at the vertical of the snout/mouth}
#'   \item{10}{upper insertion of the pectoral fin}
#'   \item{11}{bottom of the body at the vertical of the pectoral fin
#'     insertion}
#'   \item{12}{tip of the longest pectoral fin ray}
#'   \item{13-14}{top and bottom of the eye (eye diameter)}
#'   \item{15}{corner of the mouth}
#'   \item{16-17}{top and bottom of the caudal peduncle, at its minimum
#'     depth}
#'   \item{18-19}{tip of the upper and lower rays of the caudal fin (caudal
#'     fin depth)}
#'   \item{20-21}{two points a known distance apart (`scale_cm`
#'     centimetres) on a scale bar/ruler included in the picture}
#'   \item{22}{optional: a point along the body midline used to correct
#'     standard length for body curvature in the picture (see below)}
#' }
#' From these landmarks, 11 linear measurements are derived (segment names
#' follow Brosse et al., 2021, table in their figure 1a): body length
#' (`Bl`, standard length from snout to caudal fin basis), body depth
#' (`Bd`), head depth (`Hd`), eye position (`Eh`), mouth height (`Mo`,
#' points 1-9), pectoral fin position (`PFi`, points 10-11), pectoral fin
#' length (`PFl`, points 10-12), eye diameter (`Ed`), maxillary jaw length
#' (`Jl`, points 1-15), caudal peduncle depth (`CPd`), and caudal fin depth
#' (`CFd`).
#'
#' All measurements are converted from digitization units to centimetres
#' using the scale bar (points 20-21), separately for every specimen, so
#' that pictures with different resolutions or magnifications remain
#' comparable.
#'
#' If body length cannot be measured as a straight line because the fish
#' is curved in the picture, a 22nd landmark can be placed along the body
#' midline between the snout and the caudal fin basis; `Bl` is then
#' computed as the sum of the two segments (1-22 and 22-2) instead of the
#' direct distance (1-2). This correction is applied automatically,
#' specimen by specimen, whenever landmark 22 is present in `landmarks`
#' and has non-zero, non-missing coordinates for that specimen; otherwise
#' the direct distance (1-2) is used, matching the original protocol
#' ("+22 if needed, otherwise 22 = 0").
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(11), 2330-2336.
#'
#' @seealso [fishmorph_ratios()], [simulate_fishmorph_points()],
#'   [plot_fishmorph_points()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
#' fishmorph_segments(fish)
#'
#' @export
fishmorph_segments <- function(landmarks, scale_cm = 1) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  if (dim(A)[2] != 2) {
    stop("fishmorph_segments() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "`landmarks` must contain at least 21 landmarks digitized following the ",
      "Brosse et al. (2021) FISHMORPH scheme (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }
  has_curvature_point <- p >= 22
  n <- dim(A)[3]
  specimen_names <- dimnames(A)[[3]]

  dist_lm <- function(a, b) {
    diff_mat <- A[a, , ] - A[b, , ]
    if (is.null(dim(diff_mat))) diff_mat <- matrix(diff_mat, ncol = n)
    sqrt(colSums(diff_mat^2))
  }

  segments_def <- list(
    Bd  = c(3, 4),
    Hd  = c(5, 6),
    Eh  = c(7, 8),
    Mo  = c(1, 9),
    PFi = c(10, 11),
    PFl = c(10, 12),
    Ed  = c(13, 14),
    Jl  = c(1, 15),
    CPd = c(16, 17),
    CFd = c(18, 19)
  )

  scale_px <- dist_lm(20, 21)
  bad_scale <- is.na(scale_px) | scale_px <= 0
  if (any(bad_scale)) {
    warning(
      sum(bad_scale), " specimen(s) have a zero-length or missing scale bar ",
      "(points 20-21); their segments will be NA.", call. = FALSE
    )
  }
  px_to_cm <- ifelse(bad_scale, NA_real_, scale_cm / scale_px)

  if (has_curvature_point) {
    pt22 <- A[22, , ]
    if (is.null(dim(pt22))) pt22 <- matrix(pt22, ncol = n)
    used_curvature <- colSums(abs(pt22), na.rm = TRUE) > 0 & !apply(pt22, 2, function(x) any(is.na(x)))
    bl_straight <- dist_lm(1, 2)
    bl_curved <- dist_lm(1, 22) + dist_lm(22, 2)
    Bl <- ifelse(used_curvature, bl_curved, bl_straight)
  } else {
    Bl <- dist_lm(1, 2)
  }

  out <- list(Bl = Bl)
  for (nm in names(segments_def)) {
    pr <- segments_def[[nm]]
    out[[nm]] <- dist_lm(pr[1], pr[2])
  }
  out <- lapply(out, function(x) x * px_to_cm)
  out <- as.data.frame(out)
  rownames(out) <- specimen_names

  meta <- .get_metadata(landmarks)
  if (!is.null(meta)) {
    meta <- meta[rownames(out), , drop = FALSE]
    out <- cbind(meta, out)
  }

  structure(out, class = c("intrait_segments", "data.frame"))
}
