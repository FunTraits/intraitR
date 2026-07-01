#' Compute classical fish morphometric ratios
#'
#' Derives size-corrected morphological ratios from raw landmark
#' coordinates by dividing a set of inter-landmark distances by a chosen
#' normalising distance (typically standard length). Ratios of this kind
#' are widely used in fish ecomorphology to relate body shape to
#' ecological function (e.g. body depth ratio as a proxy for swimming
#' performance, eye diameter ratio for visual ecology; Winemiller, 1991;
#' Pease et al., 2012).
#'
#' @param landmarks An object of class `"intrait_landmarks"` or a raw
#'   `p x k x n` landmark array (raw, un-aligned coordinates; see
#'   [linear_distances()]).
#' @param distances A named list of length-2 landmark index vectors,
#'   passed to [linear_distances()] (e.g.
#'   `list(SL = c(1, 7), BD = c(3, 10), HL = c(1, 4))`). Must include the
#'   normalising distance named in `norm_by`.
#' @param norm_by Character. Name of the entry in `distances` used as the
#'   denominator for all other distances (typically standard length,
#'   `"SL"`).
#' @param scale Optional named numeric vector of scale factors, as in
#'   [linear_distances()].
#' @param digits Integer, number of decimal places to round ratios to.
#'   Defaults to `4`.
#'
#' @return A `data.frame` with one row per specimen, columns
#'   `<name>_ratio` for every entry in `distances` other than `norm_by`,
#'   and any metadata columns carried over from `landmarks` (if present).
#'
#' @details
#' Ratios are dimensionless and therefore comparable across specimens
#' irrespective of the digitization scale, provided the same unit is used
#' for numerator and denominator; as a result, `scale` only needs to be
#' supplied if all distances are to also be reported at their original
#' (unscaled) magnitude via [linear_distances()] beforehand, or if
#' specimens were digitized at different magnifications, in which case the
#' scale must be supplied to keep ratios strictly comparable.
#'
#' @references
#' Winemiller KO (1991). Ecomorphological diversification in lowland
#' freshwater fish assemblages from five biotic regions. Ecological
#' Monographs, 61(4), 343-365.
#'
#' Pease AA, Gonzalez-Diaz AA, Rodiles-Hernandez R, Winemiller KO (2012).
#' Functional diversity and trait-environment relationships of stream fish
#' assemblages in a large tropical catchment. Freshwater Biology, 57(5),
#' 1060-1075.
#'
#' @seealso [linear_distances()], [summary_traits()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
#' distances <- list(SL = c(1, 7), BD = c(3, 10), HL = c(1, 4))
#' morpho_ratios(fish, distances, norm_by = "SL")
#'
#' @export
morpho_ratios <- function(landmarks, distances, norm_by, scale = NULL, digits = 4) {
  if (missing(norm_by) || !is.character(norm_by) || length(norm_by) != 1) {
    stop("`norm_by` must be a single character string naming an entry in `distances`.", call. = FALSE)
  }
  ld <- linear_distances(landmarks, distances, scale = scale)
  if (!norm_by %in% names(ld)) {
    stop("`norm_by` = '", norm_by, "' is not one of the names in `distances`: ",
         paste(names(ld), collapse = ", "), call. = FALSE)
  }

  denom <- ld[[norm_by]]
  if (any(denom == 0, na.rm = TRUE)) {
    warning("Zero value(s) found for the normalising distance '", norm_by, "'; corresponding ratios will be NA/Inf.", call. = FALSE)
  }

  ratio_cols <- setdiff(names(ld), norm_by)
  ratios <- as.data.frame(lapply(ld[ratio_cols], function(x) round(x / denom, digits)))
  names(ratios) <- paste0(ratio_cols, "_ratio")
  rownames(ratios) <- rownames(ld)

  meta <- .get_metadata(landmarks)
  if (!is.null(meta)) {
    meta <- meta[rownames(ratios), , drop = FALSE]
    ratios <- cbind(meta, ratios)
  }
  ratios
}
