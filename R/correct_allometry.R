#' Correct Procrustes shape coordinates for allometry
#'
#' Removes the component of shape variation linearly associated with size
#' (allometry) by regressing Procrustes shape coordinates on log centroid
#' size and retaining the residuals, re-expressed as shape coordinates at
#' the sample's mean size. This is useful when comparing shape among
#' specimens or species that differ substantially in body size, so that
#' subsequent morphospace or disparity analyses are not simply driven by
#' size-related shape change.
#'
#' @param gpa An object of class `"intrait_gpa"`, as returned by
#'   [gpa_fish()].
#' @param method Character, one of `"common"` (a single common allometric
#'   trajectory fitted across all specimens) or `"group"` (allometric
#'   trajectories allowed to differ by group, e.g. species; requires a
#'   `species` column in `gpa$metadata`, or the `groups` argument).
#' @param groups Optional factor (or character vector) of group
#'   membership, required when `method = "group"` if `gpa$metadata` has no
#'   `species` column.
#'
#' @return A `p x k x n` array of allometry-corrected shape coordinates,
#'   with the same `dimnames` as `gpa$coords`.
#'
#' @details
#' This implements the "common allometric component" correction described
#' by Mosimann (1970) and widely used in the geometric morphometrics
#' literature (e.g. Adams & Nistri, 2010): shape is regressed on log
#' centroid size, and the residuals are added back to the value predicted
#' at the mean log centroid size, yielding a size-standardised shape for
#' every specimen. It is a simplification intended for exploratory use;
#' for formal hypothesis testing of allometric trajectories, use
#' [geomorph::procD.lm()] directly.
#'
#' @references
#' Mosimann JE (1970). Size allometry: size and shape variables with
#' characterizations of the lognormal and generalized gamma distributions.
#' Journal of the American Statistical Association, 65(330), 930-945.
#'
#' Adams DC, Nistri A (2010). Ontogenetic convergence and evolution of
#' foot morphology in European cave salamanders. BMC Evolutionary
#' Biology, 10, 216.
#'
#' @seealso [gpa_fish()], [morpho_space()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 10, n_replicates = 1)
#' gpa <- gpa_fish(fish)
#' corrected <- correct_allometry(gpa)
#' dim(corrected)
#'
#' @export
#' @importFrom geomorph two.d.array arrayspecs
correct_allometry <- function(gpa, method = c("common", "group"), groups = NULL) {
  method <- match.arg(method)
  if (!inherits(gpa, "intrait_gpa")) {
    stop("`gpa` must be an object returned by gpa_fish().", call. = FALSE)
  }

  logCS <- log(gpa$Csize)
  shape2d <- geomorph::two.d.array(gpa$coords)

  if (method == "common") {
    fit <- stats::lm(shape2d ~ logCS)
    resid <- stats::residuals(fit)
    pred_mean <- stats::predict(fit, newdata = data.frame(logCS = mean(logCS)))
    corrected2d <- sweep(resid, 2, pred_mean, "+")
  } else {
    if (is.null(groups)) {
      if (is.null(gpa$metadata) || !"species" %in% names(gpa$metadata)) {
        stop("method = 'group' requires `groups`, or a 'species' column in gpa$metadata.", call. = FALSE)
      }
      groups <- gpa$metadata$species
    }
    groups <- factor(groups)
    if (length(groups) != length(logCS)) {
      stop("`groups` must have one entry per specimen in `gpa`.", call. = FALSE)
    }
    fit <- stats::lm(shape2d ~ logCS * groups)
    resid <- stats::residuals(fit)
    pred_at_mean <- stats::predict(
      fit, newdata = data.frame(logCS = mean(logCS), groups = groups)
    )
    corrected2d <- resid + pred_at_mean
  }

  p <- dim(gpa$coords)[1]
  k <- dim(gpa$coords)[2]
  corrected_array <- geomorph::arrayspecs(corrected2d, p, k)
  dimnames(corrected_array) <- dimnames(gpa$coords)
  corrected_array
}
