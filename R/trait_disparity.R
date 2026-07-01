#' Test differences in functional trait dispersion between groups
#'
#' Tests whether groups (e.g. species) differ in the multivariate dispersion
#' of their functional traits, using a permutation approach analogous to
#' [geomorph::morphol.disparity()] but applied to the standardised trait
#' space built by [trait_space()] instead of to Procrustes shape
#' coordinates. For each group, dispersion is measured as trait variance
#' (the sum of the per-trait variances, i.e. the trace of the group's
#' trait covariance matrix), computed on the same log-transformed and
#' standardised data used to build the ordination, so that the result does
#' not depend on how many axes were retained for plotting. Pairwise
#' differences in dispersion between groups are tested against a null
#' distribution obtained by randomly permuting group labels.
#'
#' @param x Either an object of class `"intrait_traitspace"` (from
#'   [trait_space()], built with `groups` supplied), or a
#'   `data.frame`/matrix of numeric traits (one row per specimen), in
#'   which case `groups` must also be supplied and the same
#'   `log_transform`/`scale` preprocessing as [trait_space()] is applied
#'   before computing dispersion.
#' @param groups Required when `x` is a raw trait table; ignored (taken
#'   from `x$groups`) when `x` is an `"intrait_traitspace"` object.
#' @param iter Integer, number of random permutations of group labels used
#'   to build the null distribution. Defaults to `999`.
#' @param log_transform,scale As in [trait_space()]; only used when `x` is
#'   a raw trait table (ignored, and taken from `x`, when `x` is an
#'   `"intrait_traitspace"` object).
#'
#' @return An object of class `"intrait_disparity"`, a list with elements
#'   `disparity` (named numeric vector of per-group trait variance),
#'   `pairwise_diff` (symmetric matrix of observed absolute pairwise
#'   differences in disparity), `pairwise_p` (symmetric matrix of
#'   permutation p-values for these differences), and `iter`.
#'
#' @details
#' The permutation procedure reassigns the `n` specimens to groups at
#' random (preserving observed group sizes), recomputes each group's trait
#' variance, and derives the null distribution of the pairwise differences
#' from `iter` such permutations plus the observed assignment (the
#' standard `(iter + 1)`-permutation correction; Anderson, 2001). A group
#' with significantly higher trait variance than another occupies, on
#' average, a larger region of standardised functional trait space,
#' consistent with greater morphological or ecological generalism within
#' that group. Groups with fewer than two specimens receive a disparity of
#' `NA` and are excluded from the permutation test.
#'
#' This function complements [intraspecific_variability()], which reports
#' shape disparity (from Procrustes coordinates) and univariate
#' coefficients of variation, but does not test for group differences in
#' the dispersion of a multivariate *trait* space.
#'
#' @references
#' Anderson MJ (2001). A new method for non-parametric multivariate
#' analysis of variance. Austral Ecology, 26(1), 32-46.
#' \doi{10.1111/j.1442-9993.2001.01070.pp.x}
#'
#' @seealso [trait_space()], [intraspecific_variability()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species)
#' \donttest{
#' td <- trait_disparity(ts, iter = 199)
#' td
#' }
#'
#' @export
trait_disparity <- function(x, groups = NULL, iter = 999,
                             log_transform = TRUE, scale = TRUE) {
  if (inherits(x, "intrait_traitspace")) {
    if (is.null(x$X)) {
      stop(
        "`x` was built by an older version of trait_space() that did not ",
        "store the standardised trait matrix; rebuild `x` with the current ",
        "trait_space() before calling trait_disparity().",
        call. = FALSE
      )
    }
    X <- x$X
    if (is.null(groups)) groups <- x$groups
    if (is.null(groups)) {
      stop(
        "`x` has no `groups`; rebuild it with trait_space(traits, groups = ...) ",
        "or pass `groups` explicitly to trait_disparity().",
        call. = FALSE
      )
    }
  } else {
    if (!is.data.frame(x) && !is.matrix(x)) {
      stop(
        "`x` must be an \"intrait_traitspace\" object (see trait_space()) or ",
        "a data.frame/matrix of numeric traits.",
        call. = FALSE
      )
    }
    if (is.null(groups)) stop("`groups` is required when `x` is a raw trait table.", call. = FALSE)

    traits_df <- as.data.frame(x)
    numeric_cols <- names(traits_df)[vapply(traits_df, is.numeric, logical(1))]
    if (length(numeric_cols) == 0) stop("`x` contains no numeric columns.", call. = FALSE)

    Xraw <- as.matrix(traits_df[numeric_cols])
    if (anyNA(Xraw)) {
      stop(
        "`x` contains missing values; remove or impute NAs first (see the ",
        "`na_action` argument of trait_space()).",
        call. = FALSE
      )
    }
    if (isTRUE(log_transform)) {
      if (any(Xraw < 0)) {
        stop(
          "`log_transform = TRUE` requires all trait values to be non-negative; ",
          "set `log_transform = FALSE` or check your data.",
          call. = FALSE
        )
      }
      Xraw <- log10(Xraw + 1)
    }
    col_sd <- apply(Xraw, 2, stats::sd)
    Xraw <- Xraw[, col_sd > 0, drop = FALSE]
    if (ncol(Xraw) < 2) {
      stop("`x` must contain at least two non-constant numeric columns.", call. = FALSE)
    }
    X <- scale(Xraw, center = TRUE, scale = scale)
  }

  groups <- factor(groups)
  if (length(groups) != nrow(X)) {
    stop("`groups` must have one entry per row of the trait data.", call. = FALSE)
  }
  if (nlevels(groups) < 2) stop("`groups` must have at least two levels.", call. = FALSE)
  if (!is.numeric(iter) || length(iter) != 1 || iter < 1) {
    stop("`iter` must be a single positive integer.", call. = FALSE)
  }

  group_disparity <- function(Xmat, g) {
    vapply(levels(g), function(lv) {
      Xg <- Xmat[g == lv, , drop = FALSE]
      if (nrow(Xg) < 2) return(NA_real_)
      sum(apply(Xg, 2, stats::var))
    }, numeric(1))
  }

  obs_disp <- group_disparity(X, groups)
  lv <- levels(groups)
  n_lv <- length(lv)
  pair_idx <- utils::combn(n_lv, 2)
  obs_diff <- apply(pair_idx, 2, function(ij) abs(obs_disp[ij[1]] - obs_disp[ij[2]]))

  n <- nrow(X)
  iter <- as.integer(iter)
  perm_diff <- matrix(NA_real_, nrow = iter, ncol = ncol(pair_idx))
  for (i in seq_len(iter)) {
    g_perm <- sample(groups, n)
    d_perm <- group_disparity(X, g_perm)
    perm_diff[i, ] <- apply(pair_idx, 2, function(ij) abs(d_perm[ij[1]] - d_perm[ij[2]]))
  }

  p_vals <- vapply(seq_len(ncol(pair_idx)), function(j) {
    (sum(perm_diff[, j] >= obs_diff[j], na.rm = TRUE) + 1) / (iter + 1)
  }, numeric(1))

  pairwise_diff <- matrix(NA_real_, n_lv, n_lv, dimnames = list(lv, lv))
  pairwise_p <- pairwise_diff
  for (k in seq_len(ncol(pair_idx))) {
    i <- pair_idx[1, k]; j <- pair_idx[2, k]
    pairwise_diff[i, j] <- pairwise_diff[j, i] <- obs_diff[k]
    pairwise_p[i, j] <- pairwise_p[j, i] <- p_vals[k]
  }

  structure(
    list(
      disparity = obs_disp,
      pairwise_diff = pairwise_diff,
      pairwise_p = pairwise_p,
      iter = iter
    ),
    class = "intrait_disparity"
  )
}

#' @export
print.intrait_disparity <- function(x, ...) {
  cat("<intrait_disparity> (", x$iter, " permutations)\n", sep = "")
  cat("-- Trait variance (dispersion) by group --\n")
  print(round(x$disparity, 4))
  cat("\n-- Pairwise absolute differences (lower triangle) / p-values (upper triangle) --\n")
  m <- x$pairwise_diff
  p <- x$pairwise_p
  out <- m
  out[upper.tri(out)] <- p[upper.tri(p)]
  print(round(out, 4))
  invisible(x)
}
