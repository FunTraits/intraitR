#' Intraspecific-variability-aware functional dissimilarity between species
#'
#' Computes the overlap-based functional dissimilarity between every pair of
#' species (or populations) from **individual-level** trait data, using the
#' Trait Probability Density (TPD) framework of Carmona et al. (2016, 2019).
#' Each species is represented not by a single mean trait value but by a
#' probability density estimated from its individuals, and the dissimilarity
#' between two species is `1 - overlap` of their densities. Because the
#' densities are built from individuals, intraspecific variability shapes the
#' distances directly: two species whose individuals spread into a shared
#' region of trait space are treated as functionally closer than their means
#' alone would suggest -- unlike a Euclidean distance between species means,
#' which ignores within-species spread entirely.
#'
#' @details
#' Individuals are projected into a fixed, reduced trait space (a PCA on the
#' standardised traits, keeping `n_axes` axes) before the densities are
#' estimated, because TPD kernels are only tractable in a few dimensions;
#' `n_axes = 2` is the recommended default. The densities and their pairwise
#' overlaps are obtained with [TPD::TPDs()] and [TPD::dissim()]; the returned
#' matrix is `TPD::dissim()`'s population-level dissimilarity, and its
#' decomposition into the shared and non-shared (turnover-like) components is
#' returned alongside when available.
#'
#' The resulting dissimilarity is a drop-in, ITV-aware replacement for a
#' species-mean distance matrix: it can be ordinated (`cmdscale(as.dist(d))`),
#' clustered, or fed to a distance-based diversity index (e.g. Rao's quadratic
#' entropy via [TPD::Rao()], or a functional Hill number).
#'
#' @param x Either an `"intrait_traitspace"` object (from [trait_space()],
#'   whose `scores` and `groups` are used) or a `data.frame`/matrix of numeric
#'   traits, one row per **individual**. Non-numeric columns are dropped with a
#'   warning.
#' @param groups Factor or character vector, one value per row of `x`
#'   (species or population). Required for a raw trait table; taken from
#'   `x$groups` for an `"intrait_traitspace"`. Rows with a missing group are
#'   dropped. At least two groups with at least two individuals each are
#'   required.
#' @param n_axes Integer, number of PCA axes defining the trait space in which
#'   the densities are estimated. Defaults to `2`; values above `3` make the
#'   TPD grid very costly and trigger a warning.
#' @param log_transform,scale Preprocessing of a raw trait table, as in
#'   [trait_space()]: `log_transform` applies `log10(x + 1)`; `scale`
#'   standardises each trait before the PCA. Ignored for an
#'   `"intrait_traitspace"`. Default `FALSE` and `TRUE`.
#' @param seed Optional integer for [set.seed()] (TPD kernel estimation is
#'   deterministic, but this fixes any incidental randomness). Defaults to
#'   `NULL`.
#'
#' @return An object of class `"intrait_tpd_dissim"`, a list with:
#'   \describe{
#'     \item{dissimilarity}{a symmetric species-by-species matrix of
#'       overlap-based functional dissimilarity (`1 - overlap`, in `[0, 1]`).}
#'     \item{shared, non_shared}{the shared and non-shared components of the
#'       dissimilarity (each a species-by-species matrix), when
#'       [TPD::dissim()] returns them; otherwise `NULL`.}
#'     \item{species, n_axes, var_explained}{the group levels, the number of
#'       PCA axes used, and the proportion of trait variance they capture.}
#'   }
#'   Has `print()`, `plot()` (a dissimilarity heat map) and [as.dist()]
#'   methods.
#'
#' @references
#' Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2016). Traits
#' without borders: integrating functional diversity across scales. Trends in
#' Ecology & Evolution, 31(5), 382-394.
#'
#' Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2019). Trait
#' probability density (TPD): measuring functional diversity across scales
#' based on TPD with R. Ecology, 100(12), e02876.
#'
#' @seealso [trait_disparity()], [bootstrap_functional_space()],
#'   [fd_accumulation()], [trait_space()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
#' ratios <- fishmorph_ratios(fishmorph_segments(fish))
#' \donttest{
#' if (requireNamespace("TPD", quietly = TRUE)) {
#'   d <- tpd_dissimilarity(
#'     ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species
#'   )
#'   d
#'   plot(d)
#'   # use as an ITV-aware distance, e.g. an ordination of species:
#'   pcoa <- stats::cmdscale(as.dist(d))
#' }
#' }
#'
#' @export
tpd_dissimilarity <- function(x, groups = NULL, n_axes = 2,
                              log_transform = FALSE, scale = TRUE, seed = NULL) {
  if (!requireNamespace("TPD", quietly = TRUE)) {
    stop("`tpd_dissimilarity()` requires the (Suggested) 'TPD' package; ",
         "install it with install.packages(\"TPD\").", call. = FALSE)
  }
  if (!is.numeric(n_axes) || length(n_axes) != 1 || n_axes < 1) {
    stop("`n_axes` must be a single positive integer.", call. = FALSE)
  }
  if (!is.null(seed)) set.seed(seed)

  # -- trait matrix + groups ---------------------------------------------------
  if (inherits(x, "intrait_traitspace")) {
    X <- as.matrix(x$scores)
    if (is.null(groups)) groups <- x$groups
  } else {
    if (!is.data.frame(x) && !is.matrix(x)) {
      stop("`x` must be an \"intrait_traitspace\" object or a data.frame/matrix.", call. = FALSE)
    }
    if (is.null(groups)) stop("`groups` is required when `x` is a raw trait table.", call. = FALSE)
    df <- as.data.frame(x)
    num <- names(df)[vapply(df, is.numeric, logical(1))]
    dropped <- setdiff(names(df), num)
    if (length(num) == 0) stop("`x` contains no numeric columns.", call. = FALSE)
    if (length(dropped) > 0) {
      warning("Dropping non-numeric column(s): ", paste(dropped, collapse = ", "), call. = FALSE)
    }
    X <- as.matrix(df[num])
    if (anyNA(X)) stop("`x` contains missing values; remove or impute NAs first.", call. = FALSE)
    if (isTRUE(log_transform)) {
      if (any(X < 0)) stop("`log_transform = TRUE` requires non-negative values.", call. = FALSE)
      X <- log10(X + 1)
    }
    col_sd <- apply(X, 2, stats::sd)
    X <- X[, col_sd > 0, drop = FALSE]
    if (ncol(X) < 1) stop("`x` has no non-constant numeric columns.", call. = FALSE)
    if (isTRUE(scale)) X <- scale(X, center = TRUE, scale = TRUE)
  }

  groups <- factor(groups)
  if (length(groups) != nrow(X)) stop("`groups` must have one entry per row of `x`.", call. = FALSE)
  if (anyNA(groups)) {
    keep <- !is.na(groups)
    message(sprintf("Removing %d row(s) with a missing `groups` value.", sum(!keep)))
    X <- X[keep, , drop = FALSE]
    groups <- droplevels(groups[keep])
  }
  if (nlevels(groups) < 2) stop("`groups` must have at least two levels.", call. = FALSE)
  if (any(table(groups) < 2)) {
    stop("Every group needs at least two individuals to estimate a trait density.", call. = FALSE)
  }

  # -- fixed reduced trait space ----------------------------------------------
  n_axes <- as.integer(n_axes)
  if (n_axes > 3) {
    warning("`n_axes` > 3 makes the TPD grid very costly; consider n_axes = 2.", call. = FALSE)
  }
  pca <- stats::prcomp(X, center = TRUE, scale. = FALSE)
  n_axes <- min(n_axes, ncol(pca$x))
  scores <- pca$x[, seq_len(n_axes), drop = FALSE]
  var_explained <- sum(pca$sdev[seq_len(n_axes)]^2) / sum(pca$sdev^2)

  # -- TPD densities + overlap-based dissimilarity ----------------------------
  tpds <- tryCatch(
    suppressWarnings(suppressMessages(
      TPD::TPDs(species = as.character(groups), traits = scores)
    )),
    error = function(e) stop("TPD::TPDs() failed: ", conditionMessage(e), call. = FALSE)
  )
  diss <- tryCatch(
    suppressWarnings(suppressMessages(TPD::dissim(tpds))),
    error = function(e) stop("TPD::dissim() failed: ", conditionMessage(e), call. = FALSE)
  )

  pop <- diss$populations
  if (is.null(pop) || is.null(pop$dissimilarity)) {
    stop("TPD::dissim() did not return a population dissimilarity matrix; ",
         "check the installed 'TPD' version.", call. = FALSE)
  }
  D <- as.matrix(pop$dissimilarity)

  structure(
    list(
      dissimilarity = D,
      shared = if (!is.null(pop$shared)) as.matrix(pop$shared) else NULL,
      non_shared = if (!is.null(pop$non_shared)) as.matrix(pop$non_shared) else NULL,
      species = levels(groups),
      n_axes = n_axes,
      var_explained = var_explained
    ),
    class = "intrait_tpd_dissim"
  )
}

#' @return `as.dist()` returns a `"dist"` object of the dissimilarity matrix.
#' @export
#' @rdname tpd_dissimilarity
#' @param m An object of class `"intrait_tpd_dissim"`.
#' @param ... Currently unused.
as.dist.intrait_tpd_dissim <- function(m, ...) {
  stats::as.dist(m$dissimilarity)
}

#' @return `print()` invisibly returns `x`.
#' @export
#' @rdname tpd_dissimilarity
#' @param x An object of class `"intrait_tpd_dissim"`.
print.intrait_tpd_dissim <- function(x, ...) {
  cat("<intrait_tpd_dissim> overlap-based functional dissimilarity\n")
  cat(sprintf("  %d species, %d PCA axis/axes (%.1f%% of trait variance)\n",
              length(x$species), x$n_axes, 100 * x$var_explained))
  off <- x$dissimilarity[upper.tri(x$dissimilarity)]
  cat(sprintf("  mean pairwise dissimilarity = %.3f (range %.3f-%.3f)\n",
              mean(off, na.rm = TRUE), min(off, na.rm = TRUE), max(off, na.rm = TRUE)))
  cat("\n")
  print(round(x$dissimilarity, 3))
  invisible(x)
}

#' Plot the TPD dissimilarity matrix as a heat map
#'
#' @param x An object of class `"intrait_tpd_dissim"`.
#' @param col A vector of colours for increasing dissimilarity. Defaults to a
#'   white-to-teal ramp.
#' @param ... Passed to [graphics::image()].
#' @return Invisibly returns `x`.
#' @export
plot.intrait_tpd_dissim <- function(x, col = grDevices::hcl.colors(50, "TealGrn", rev = TRUE), ...) {
  D <- x$dissimilarity
  s <- length(x$species)
  # image() plots the matrix with the first row at the bottom; reverse the
  # rows so the heat map reads top-to-bottom in species order.
  old_par <- graphics::par(mar = c(7, 7, 2, 2))
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::image(seq_len(s), seq_len(s), t(D[s:1, , drop = FALSE]),
                  col = col, xlab = "", ylab = "", axes = FALSE,
                  main = "TPD overlap-based dissimilarity", zlim = c(0, 1), ...)
  graphics::axis(1, at = seq_len(s), labels = x$species, las = 2, cex.axis = 0.8)
  graphics::axis(2, at = seq_len(s), labels = rev(x$species), las = 2, cex.axis = 0.8)
  graphics::box()
  invisible(x)
}
