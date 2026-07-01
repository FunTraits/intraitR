#' Extract a geomorph-style coordinate array from supported input objects
#'
#' @param x An object of class `"intrait_landmarks"`, `"intrait_gpa"`, or a
#'   raw `p x k x n` numeric array.
#' @return A `p x k x n` numeric array.
#' @noRd
.get_coords <- function(x) {
  if (inherits(x, "intrait_landmarks") || inherits(x, "intrait_gpa")) {
    A <- x$coords
  } else if (is.array(x) && length(dim(x)) == 3) {
    A <- x
  } else {
    stop(
      "`x` must be an object returned by read_tps(), read_landmarks_csv(), ",
      "gpa_fish(), or a raw p x k x n landmark array.",
      call. = FALSE
    )
  }
  if (is.null(dimnames(A)) || is.null(dimnames(A)[[3]])) {
    dimnames(A)[[3]] <- paste0("specimen_", seq_len(dim(A)[3]))
  }
  A
}

#' Extract specimen metadata from supported input objects, if present
#' @param x An object possibly carrying a `metadata` element.
#' @return A `data.frame` or `NULL`.
#' @noRd
.get_metadata <- function(x) {
  if (is.list(x) && !is.null(x$metadata)) {
    return(x$metadata)
  }
  NULL
}

#' Merge a user-supplied metadata table with a vector of specimen names
#'
#' @param metadata A `data.frame` with either row names matching
#'   `specimen_names`, or a column named `specimen` matching them.
#' @param specimen_names Character vector of specimen identifiers, in the
#'   order used by the coordinate array.
#' @return A `data.frame` re-ordered and row-named to match
#'   `specimen_names`, with unmatched specimens set to `NA`.
#' @noRd
.merge_metadata <- function(metadata, specimen_names) {
  if (!is.data.frame(metadata)) {
    stop("`metadata` must be a data.frame.", call. = FALSE)
  }
  if ("specimen" %in% names(metadata)) {
    rownames(metadata) <- metadata[["specimen"]]
  }
  missing_specimens <- setdiff(specimen_names, rownames(metadata))
  if (length(missing_specimens) > 0) {
    warning(
      length(missing_specimens),
      " specimen(s) have no matching row in `metadata` and will contain NA values: ",
      paste(utils::head(missing_specimens, 5), collapse = ", "),
      if (length(missing_specimens) > 5) ", ..." else "",
      call. = FALSE
    )
  }
  metadata[specimen_names, , drop = FALSE]
}

#' Coefficient of variation (percent)
#' @param x Numeric vector.
#' @param na.rm Logical.
#' @return Numeric scalar, the CV expressed in percent.
#' @noRd
.cv_percent <- function(x, na.rm = TRUE) {
  stats::sd(x, na.rm = na.rm) / mean(x, na.rm = na.rm) * 100
}

#' Points on a bivariate covariance ("dispersion") ellipse
#'
#' Computes points on the ellipse of constant Mahalanobis distance around
#' the centroid of a 2D point cloud, assuming approximate bivariate
#' normality — the classical "confidence"/"dispersion" ellipse used to
#' depict the region occupied by a group of points in an ordination
#' (e.g. `vegan::ordiellipse()`, `car::dataEllipse()`).
#'
#' @param x,y Numeric vectors of coordinates (same length, at least 3
#'   points).
#' @param level Coverage probability of the ellipse under a bivariate
#'   normal approximation (e.g. `0.95`).
#' @param n_points Number of points used to draw the ellipse outline.
#' @return A two-column matrix of ellipse coordinates, or `NULL` if fewer
#'   than 3 points are supplied or the covariance matrix is degenerate.
#' @noRd
.covariance_ellipse <- function(x, y, level = 0.95, n_points = 100) {
  if (length(x) < 3) return(NULL)
  S <- stats::cov(cbind(x, y))
  if (any(!is.finite(S)) || any(diag(S) <= 0)) return(NULL)
  centre <- c(mean(x), mean(y))
  eig <- eigen(S)
  scale_factor <- sqrt(stats::qchisq(level, df = 2))
  theta <- seq(0, 2 * pi, length.out = n_points)
  circle <- rbind(cos(theta), sin(theta))
  axes <- eig$vectors %*% diag(sqrt(pmax(eig$values, 0)), nrow = 2)
  ellipse_pts <- t(axes %*% circle) * scale_factor
  sweep(ellipse_pts, 2, centre, "+")
}

#' Scatterplot of a 2D ordination, by group
#'
#' Shared plotting logic used by plot.intrait_morphospace() and
#' plot.intrait_traitspace() so that both ordination types are displayed
#' consistently: each group is shown as its individual points, a "spider"
#' of dashed segments linking each point to its group mean, the group
#' mean itself, and a dispersion ellipse (`style = "spider"`, the
#' default); a classical convex hull (`style = "hull"`); or plain points
#' with no group decoration (`style = "none"`).
#'
#' @param scores A data.frame/matrix with (at least) two columns of
#'   ordination scores.
#' @param groups A factor of the same length as `nrow(scores)`, or `NULL`.
#' @param xlab,ylab Axis labels.
#' @param style One of `"spider"`, `"hull"`, or `"none"`.
#' @param ellipse_level Coverage probability of the dispersion ellipse
#'   (`style = "spider"` only).
#' @param legend Logical, draw a legend of group colors.
#' @param ... Further arguments passed to [graphics::plot()].
#' @return Invisibly returns `NULL`.
#' @noRd
.plot_ordination <- function(scores, groups, xlab, ylab, style = "spider",
                              ellipse_level = 0.95, legend = TRUE, ...) {
  if (is.null(groups)) {
    graphics::plot(scores[, 1], scores[, 2], xlab = xlab, ylab = ylab, pch = 19, ...)
    graphics::abline(h = 0, v = 0, lty = 3, col = "grey60")
    return(invisible(NULL))
  }

  pal <- grDevices::hcl.colors(nlevels(groups), palette = "Dark 3")
  cols <- pal[as.integer(groups)]

  graphics::plot(scores[, 1], scores[, 2], xlab = xlab, ylab = ylab, pch = 19, col = cols, ...)
  graphics::abline(h = 0, v = 0, lty = 3, col = "grey60")

  if (style == "spider") {
    for (i in seq_len(nlevels(groups))) {
      idx <- which(as.integer(groups) == i)
      if (length(idx) == 0) next
      gx <- scores[idx, 1]
      gy <- scores[idx, 2]
      centre <- c(mean(gx), mean(gy))

      graphics::segments(centre[1], centre[2], gx, gy, col = pal[i], lty = 2, lwd = 0.8)

      ell <- .covariance_ellipse(gx, gy, level = ellipse_level)
      if (!is.null(ell)) graphics::lines(ell, col = pal[i], lwd = 1.5)

      graphics::points(centre[1], centre[2], pch = 8, cex = 1.5, col = pal[i], lwd = 2)
    }
  } else if (style == "hull") {
    for (i in seq_len(nlevels(groups))) {
      idx <- which(as.integer(groups) == i)
      if (length(idx) >= 3) {
        hpts <- grDevices::chull(scores[idx, 1], scores[idx, 2])
        graphics::polygon(scores[idx, 1][hpts], scores[idx, 2][hpts],
                           border = pal[i], col = grDevices::adjustcolor(pal[i], alpha.f = 0.15))
      }
    }
  }

  if (isTRUE(legend)) {
    graphics::legend("topright", legend = levels(groups), col = pal, pch = 19, bty = "n", cex = 0.8)
  }
  invisible(NULL)
}
