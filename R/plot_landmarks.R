#' Plot a single landmark configuration
#'
#' Produces a simple two-dimensional scatterplot of one specimen's
#' landmark configuration (raw or Procrustes-aligned), with landmarks
#' optionally numbered, for quality control of digitization and
#' configuration checking.
#'
#' @param landmarks An object of class `"intrait_landmarks"` or
#'   `"intrait_gpa"`, or a raw `p x k x n` array. Must be two-dimensional.
#' @param specimen Integer index or character specimen identifier of the
#'   configuration to plot. Defaults to `1`.
#' @param labels Logical, label landmarks with their index. Defaults to
#'   `TRUE`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns the `p x 2` matrix of coordinates plotted.
#'
#' @seealso [gpa_fish()], [morpho_space()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 1)
#' plot_landmarks(fish, specimen = 1)
#'
#' @export
plot_landmarks <- function(landmarks, specimen = 1, labels = TRUE, ...) {
  A <- .get_coords(landmarks)
  if (dim(A)[2] != 2) {
    stop("plot_landmarks() currently supports two-dimensional landmark configurations only.", call. = FALSE)
  }

  if (is.character(specimen)) {
    idx <- match(specimen, dimnames(A)[[3]])
    if (is.na(idx)) stop("Specimen '", specimen, "' not found.", call. = FALSE)
  } else {
    idx <- specimen
    if (idx < 1 || idx > dim(A)[3]) stop("`specimen` index out of range.", call. = FALSE)
  }

  xy <- A[, , idx]
  main_label <- dimnames(A)[[3]][idx]

  graphics::plot(
    xy, asp = 1, pch = 19, xlab = "X", ylab = "Y",
    main = if (!is.null(main_label)) main_label else paste("Specimen", idx), ...
  )
  if (isTRUE(labels)) {
    graphics::text(xy, labels = seq_len(nrow(xy)), pos = 3, cex = 0.8, col = "steelblue4")
  }
  invisible(xy)
}
