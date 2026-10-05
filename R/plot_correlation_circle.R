#' Plot the correlation circle of a functional trait space
#'
#' Draws the classical "correlation circle" (variable factor map) of a
#' [trait_space()] ordination: each trait is shown as an arrow from the
#' origin to its Pearson correlation with the two plotted ordination axes,
#' inside a unit circle, the standard way of reading which traits drive
#' each axis and how well a trait is represented by the two-axis subspace
#' actually plotted (e.g. Legendre & Legendre, 2012, sec. 9.1.5).
#'
#' @param x An object of class `"intrait_traitspace"`, as returned by
#'   [trait_space()].
#' @param inner_circle Logical, draw a dashed inner circle at radius
#'   `sqrt(0.5)`, the conventional threshold above which a trait is
#'   considered well represented by the two plotted axes (i.e. more than
#'   half of that trait's variance is captured by them jointly). Defaults
#'   to `TRUE`.
#' @param cex_labels Character expansion for trait labels. Defaults to
#'   `0.8`.
#' @param arrow_col,label_col,circle_col Colours for the arrows, trait
#'   labels, and circle(s), respectively.
#' @param label_offset Numeric, how far outside each arrow tip its label
#'   is placed, as a multiple of the arrow's own length from the origin
#'   (e.g. `1.15` places a label 15% beyond the tip). Defaults to `1.15`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns a matrix of trait-axis correlations (one row
#'   per trait actually used in `x`, one column per plotted axis) -- the
#'   values represented by the arrows.
#'
#' @details
#' Unlike a plot of raw PCA loadings (`x$loadings`), which are unit-norm
#' *within* each axis and so are not directly comparable in length across
#' traits or informative about how well a trait is captured by the two
#' plotted axes jointly, the coordinates plotted here are the actual
#' Pearson correlation between each trait (as included in the ordination,
#' i.e. after any `log_transform`/`scale`/imputation/outlier removal --
#' see `x$X`) and the ordination scores on the two plotted axes (`x$scores`).
#' Because a Pearson correlation is always in `[-1, 1]`, every arrow tip
#' necessarily falls on or inside the unit circle: a tip near the circle
#' means that trait is well summarised by the two-axis plane shown, while
#' a short arrow means most of that trait's variance lies on other,
#' unplotted axes (or, for `method = "pcoa"`, was not linearly captured by
#' this ordination at all). This computation does not depend on
#' `method` (`"pca"` or `"pcoa"`), or on whether `scale = TRUE` was used
#' when building `x`, since a Pearson correlation is itself scale-invariant.
#'
#' The plot itself is drawn without a surrounding box: tick marks and
#' values (`-1` to `1`) are instead placed directly on the horizontal
#' (`y = 0`) and vertical (`x = 0`) reference lines through the origin,
#' and each line is labelled with its axis name only (e.g. `"PC1"`), in a
#' small italic font, just outside the unit circle and centred on the
#' line itself -- the standard presentation of a correlation circle in
#' the literature (e.g. `ade4::s.corcircle()`). The vertical axis's label
#' is itself drawn rotated (reading bottom to top), as for a conventional
#' `ylab`.
#'
#' @references
#' Legendre, P., & Legendre, L. (2012). Numerical Ecology (3rd English
#' ed). Elsevier.
#'
#' @seealso [trait_space()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#' \donttest{
#' plot_correlation_circle(ts)
#' }
#'
#' @export
plot_correlation_circle <- function(x, inner_circle = TRUE, cex_labels = 0.8,
                                     arrow_col = "firebrick3", label_col = "black",
                                     circle_col = "grey40", label_offset = 1.15, ...) {
  if (!inherits(x, "intrait_traitspace")) {
    stop(
      "`x` must be an object of class \"intrait_traitspace\", as returned by trait_space().",
      call. = FALSE
    )
  }
  if (is.null(x$X) || ncol(x$X) < 1) {
    stop("`x` has no trait data to correlate (`x$X` is missing or empty).", call. = FALSE)
  }

  cors <- stats::cor(x$X, as.matrix(x$scores))

  axis1_lab <- names(x$scores)[1]
  axis2_lab <- names(x$scores)[2]

  old_par <- graphics::par(pty = "s")
  on.exit(graphics::par(old_par), add = TRUE)

  # No box, no default axes/labels: the tick marks and values are drawn
  # further down along the h = 0 / v = 0 reference lines themselves (via
  # axis(..., pos = 0)) instead of at the plot box edges, and the usual
  # xlab/ylab are replaced by a small "PC1 (xx)"/"PC2 (xx)" label at the
  # tip of each reference line -- the conventional look of a correlation
  # circle (e.g. ade4::s.corcircle(), FactoMineR::fviz_pca_var()). The
  # plot region is expanded slightly beyond [-1, 1] (the largest a
  # correlation, and so an arrow, can ever be) so that tick labels, trait
  # labels and the axis-end labels are not clipped at the circle's edge.
  lim <- c(-1.2, 1.2)
  plot_args <- utils::modifyList(
    list(
      x = lim, y = lim, type = "n", asp = 1, axes = FALSE, ann = FALSE,
      bty = "n", main = "Correlation circle"
    ),
    list(...)
  )
  do.call(graphics::plot, plot_args)

  # Tick values and the PC1/PC2 axis-end labels share the same size
  # (cex_tick), so the two kinds of axis annotation read as one coherent
  # set rather than two different sizes.
  cex_tick <- cex_labels * 0.8
  at <- seq(-1, 1, by = 0.5)
  graphics::axis(1, at = at, pos = 0, cex.axis = cex_tick, tcl = -0.2, mgp = c(3, 0.3, 0))
  graphics::axis(2, at = at[at != 0], pos = 0, cex.axis = cex_tick, tcl = -0.2, mgp = c(3, 0.3, 0), las = 1)

  theta <- seq(0, 2 * pi, length.out = 200)
  graphics::lines(cos(theta), sin(theta), col = circle_col)
  if (isTRUE(inner_circle)) {
    r <- sqrt(0.5)
    graphics::lines(r * cos(theta), r * sin(theta), col = circle_col, lty = 2)
  }

  graphics::arrows(0, 0, cors[, 1], cors[, 2], length = 0.08, col = arrow_col, lwd = 1.5)
  .halo_text(
    cors[, 1] * label_offset, cors[, 2] * label_offset,
    labels = rownames(cors), cex = cex_labels, font = 1, text_col = label_col
  )

  # Axis-end labels sit just outside the unit circle (radius 1), in the
  # same small italic font/size as the tick values (cex_tick, set above),
  # centred on their own reference line (vadj = 0.5 centres the label's
  # height on y = 0 for PC1; for PC2, rotated 90 degrees, that same vadj
  # centres its width on x = 0) rather than floating above/beside it.
  graphics::text(1.04, 0, labels = axis1_lab, cex = cex_tick, font = 3,
                 adj = c(0, 0.5), xpd = NA)
  graphics::text(0, 1.04, labels = axis2_lab, cex = cex_tick, font = 3,
                 srt = 90, adj = c(0, 0.5), xpd = NA)

  invisible(cors)
}
