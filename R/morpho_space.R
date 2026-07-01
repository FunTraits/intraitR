#' Build a morphological space from Procrustes shape coordinates
#'
#' Performs a Principal Component Analysis of Procrustes-aligned shape
#' coordinates to construct a morphological space ("morphospace"), the
#' standard ordination used to visualise and compare shape variation among
#' specimens, populations or species in geometric morphometrics.
#'
#' @param gpa An object of class `"intrait_gpa"`, as returned by
#'   [gpa_fish()].
#' @param groups Optional factor (or character vector), one value per
#'   specimen in the same order as `dimnames(gpa$coords)[[3]]`, used to
#'   colour/group specimens when plotting. If `NULL` and `gpa$metadata`
#'   contains a `species` column, it is used automatically.
#' @param axes Integer vector of length 2, the principal components to
#'   retain for plotting (defaults to `c(1, 2)`).
#'
#' @return An object of class `"intrait_morphospace"`, a list with
#'   elements `scores` (data.frame of PC scores), `sdev` (standard
#'   deviations of all PCs), `var_explained` (percent variance explained by
#'   the two selected axes), `rotation` (PCA loadings), `groups`, and
#'   `axes`. Has a dedicated [plot()] method.
#'
#' @seealso [gpa_fish()], [intraspecific_variability()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
#' gpa <- gpa_fish(fish)
#' ms <- morpho_space(gpa, groups = fish$metadata$species)
#' ms
#' \donttest{
#' plot(ms)
#' }
#'
#' @export
#' @importFrom geomorph gm.prcomp
morpho_space <- function(gpa, groups = NULL, axes = c(1, 2)) {
  if (!inherits(gpa, "intrait_gpa")) {
    stop("`gpa` must be an object returned by gpa_fish().", call. = FALSE)
  }
  if (length(axes) != 2) stop("`axes` must be a length-2 integer vector.", call. = FALSE)

  if (is.null(groups) && !is.null(gpa$metadata) && "species" %in% names(gpa$metadata)) {
    groups <- gpa$metadata$species
  }
  if (!is.null(groups)) groups <- factor(groups)

  pca <- geomorph::gm.prcomp(gpa$coords)
  scores_all <- as.data.frame(pca$x)
  if (max(axes) > ncol(scores_all)) {
    stop("`axes` requests a PC axis beyond the ", ncol(scores_all), " available components.", call. = FALSE)
  }
  scores <- scores_all[, axes, drop = FALSE]
  names(scores) <- paste0("PC", axes)
  rownames(scores) <- dimnames(gpa$coords)[[3]]

  var_explained <- (pca$sdev^2 / sum(pca$sdev^2))[axes] * 100

  structure(
    list(
      scores = scores,
      sdev = pca$sdev,
      var_explained = stats::setNames(var_explained, paste0("PC", axes)),
      rotation = pca$rotation,
      groups = groups,
      axes = axes
    ),
    class = "intrait_morphospace"
  )
}

#' @export
print.intrait_morphospace <- function(x, ...) {
  cat("<intrait_morphospace>\n")
  cat(sprintf(
    "  Axes PC%d/PC%d, variance explained: %.1f%% / %.1f%%\n",
    x$axes[1], x$axes[2], x$var_explained[1], x$var_explained[2]
  ))
  cat(sprintf("  %d specimens", nrow(x$scores)))
  if (!is.null(x$groups)) cat(sprintf(", %d groups", nlevels(x$groups)))
  cat("\n")
  invisible(x)
}

#' Plot a morphological space
#'
#' @param x An object of class `"intrait_morphospace"`, from
#'   [morpho_space()].
#' @param style Character, one of `"spider"` (default), `"hull"`, or
#'   `"none"`, controlling how groups are displayed (see Details).
#'   Ignored if `x$groups` is `NULL`.
#' @param ellipse_level Coverage probability of the per-group dispersion
#'   ellipse drawn when `style = "spider"`, under a bivariate-normal
#'   approximation. Defaults to `0.95`.
#' @param legend Logical, draw a legend of group colors. Defaults to
#'   `TRUE` when `x$groups` is available.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns `x`.
#'
#' @details
#' With `style = "spider"` (the default), each group is shown as: its
#' individual points; dashed segments ("spider" legs) linking every point
#' to its group mean; the group mean itself (an asterisk); and a
#' dispersion ellipse of coverage `ellipse_level` around the group mean,
#' assuming approximate bivariate normality of the group's scores (as in
#' `vegan::ordiellipse()`/`car::dataEllipse()`). This mirrors the
#' star/spider plots commonly used to display group structure in
#' geometric-morphometric and functional-trait ordinations. Use
#' `style = "hull"` for the classical convex-hull display, or
#' `style = "none"` to plot points without any group decoration.
#'
#' @export
plot.intrait_morphospace <- function(x, style = c("spider", "hull", "none"),
                                      ellipse_level = 0.95,
                                      legend = !is.null(x$groups), ...) {
  style <- match.arg(style)
  xlab <- sprintf("PC%d (%.1f%%)", x$axes[1], x$var_explained[1])
  ylab <- sprintf("PC%d (%.1f%%)", x$axes[2], x$var_explained[2])
  .plot_ordination(x$scores, x$groups, xlab, ylab, style = style,
                    ellipse_level = ellipse_level, legend = legend, ...)
  invisible(x)
}
