#' Plot a specimen following the FISHMORPH point digitization scheme
#'
#' Visualises the 21 (or 22) landmarks of one specimen, digitized following
#' the Brosse et al. (2021) FISHMORPH scheme, together with the 11 linear
#' measurements they define, for quality control of digitization.
#'
#' @param landmarks An object of class `"intrait_landmarks"` with at least
#'   21 two-dimensional landmarks digitized following the scheme described
#'   in [fishmorph_segments()] (e.g. from [simulate_fishmorph_points()]).
#' @param specimen Integer index or character specimen identifier of the
#'   configuration to plot. Defaults to `1`.
#' @param labels Logical, label landmarks with their index. Defaults to
#'   `TRUE`.
#' @param legend Logical, draw a legend of measurement names/colours.
#'   Defaults to `TRUE`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns the `p x 2` matrix of coordinates plotted.
#'
#' @seealso [fishmorph_segments()], [fishmorph_ratios()],
#'   [simulate_fishmorph_points()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
#' plot_fishmorph_points(fish, specimen = 1)
#'
#' @export
plot_fishmorph_points <- function(landmarks, specimen = 1, labels = TRUE, legend = TRUE, ...) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  if (dim(A)[2] != 2) {
    stop("plot_fishmorph_points() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "`landmarks` must contain at least 21 landmarks digitized following the ",
      "Brosse et al. (2021) FISHMORPH scheme (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }

  if (is.character(specimen)) {
    idx <- match(specimen, dimnames(A)[[3]])
    if (is.na(idx)) stop("Specimen '", specimen, "' not found.", call. = FALSE)
  } else {
    idx <- specimen
  }

  xy <- A[, , idx]
  main_label <- dimnames(A)[[3]][idx]

  segments_display <- list(
    Bl  = list(pts = c(1, 2),   col = "firebrick"),
    Bd  = list(pts = c(3, 4),   col = "goldenrod"),
    Hd  = list(pts = c(5, 6),   col = "forestgreen"),
    Eh  = list(pts = c(7, 8),   col = "darkorchid"),
    Mo  = list(pts = c(1, 9),   col = "darkorange"),
    PFi = list(pts = c(10, 11), col = "turquoise4"),
    PFl = list(pts = c(10, 12), col = "navy"),
    Ed  = list(pts = c(13, 14), col = "deeppink"),
    Jl  = list(pts = c(1, 15),  col = "chartreuse4"),
    CPd = list(pts = c(16, 17), col = "grey40"),
    CFd = list(pts = c(18, 19), col = "grey70")
  )

  graphics::plot(
    xy, asp = 1, pch = 19, col = "grey20", xlab = "X", ylab = "Y",
    main = if (!is.null(main_label)) main_label else paste("Specimen", idx), ...
  )

  for (nm in names(segments_display)) {
    pr <- segments_display[[nm]]$pts
    graphics::segments(xy[pr[1], 1], xy[pr[1], 2], xy[pr[2], 1], xy[pr[2], 2],
                        col = segments_display[[nm]]$col, lwd = 2)
  }

  if (p >= 22) {
    graphics::points(xy[20, 1], xy[20, 2], pch = 17, col = "black")
    graphics::points(xy[21, 1], xy[21, 2], pch = 17, col = "black")
    graphics::segments(xy[20, 1], xy[20, 2], xy[21, 1], xy[21, 2], col = "black", lty = 2)
  }

  if (isTRUE(labels)) {
    graphics::text(xy, labels = seq_len(nrow(xy)), pos = 3, cex = 0.7)
  }
  if (isTRUE(legend)) {
    graphics::legend(
      "topright", legend = names(segments_display),
      col = vapply(segments_display, function(s) s$col, character(1)),
      lwd = 2, bty = "n", cex = 0.7, ncol = 2
    )
  }
  invisible(xy)
}
