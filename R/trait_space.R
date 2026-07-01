#' Build a functional trait space from a numeric trait table
#'
#' Constructs a low-dimensional functional trait space from any table of
#' numeric traits (e.g. the FISHMORPH ecomorphological ratios produced by
#' [fishmorph_ratios()], or linear traits/ratios from [morpho_ratios()]),
#' by Principal Component Analysis or by metric multidimensional scaling
#' (Principal Coordinate Analysis) of a Euclidean distance matrix, the two
#' standard approaches used to build functional trait spaces in
#' comparative ecology (e.g. Villéger et al., 2017).
#'
#' @param traits A `data.frame` or matrix of numeric traits, one row per
#'   specimen or species. Non-numeric columns are dropped with a warning
#'   (they are not included in the ordination, but grouping is still
#'   auto-detected from a `species` column if present; see `groups`).
#'   Constant (zero-variance) numeric columns are also dropped with a
#'   warning, since they carry no information for an ordination and
#'   cannot be rescaled to unit variance; this commonly happens when
#'   incidental numeric metadata (e.g. a digitization replicate counter)
#'   is carried over from [fishmorph_segments()]/[fishmorph_ratios()] and
#'   passed to `trait_space()` unfiltered.
#' @param groups Optional factor (or character vector), one value per row
#'   of `traits`, used to colour/group observations when plotting. If
#'   `NULL` and `traits` contains a `species` column, it is used
#'   automatically.
#' @param method Character, one of `"pca"` (default, Principal Component
#'   Analysis via [stats::prcomp()]) or `"pcoa"` (Principal Coordinate
#'   Analysis / classical multidimensional scaling, via
#'   [stats::cmdscale()], of a Euclidean distance matrix on the same,
#'   optionally transformed and standardised, trait data — equivalent to
#'   PCA up to an arbitrary rotation and sign).
#' @param log_transform Logical, apply a `log10(x + 1)` transformation to
#'   every numeric trait before centring/scaling and ordination. Defaults
#'   to `TRUE`. Ratio traits (e.g. from [fishmorph_ratios()] or
#'   [morpho_ratios()]) are bounded at zero and often right-skewed, so a
#'   log(x + 1) transformation (the `+ 1` accommodating traits that can
#'   legitimately equal zero, e.g. under the Villéger et al., 2010,
#'   exception rules) is common practice before ordination. Requires all
#'   trait values to be non-negative; set to `FALSE` to skip (e.g. for
#'   traits that can be negative, such as PCA scores fed back into a
#'   second ordination).
#' @param scale Logical, standardise (centre and scale to unit variance)
#'   traits before building the trait space, after the optional log
#'   transformation (recommended when traits are on different scales or
#'   have different variances). Defaults to `TRUE`.
#' @param axes Integer vector of length 2, the ordination axes to retain
#'   for plotting. Defaults to `c(1, 2)`.
#' @param na_action Character, how to handle missing values in the numeric
#'   trait columns: `"fail"` (default) stops with an error, as in previous
#'   versions; `"omit"` removes affected rows (specimens/species) and
#'   reports how many were dropped; `"impute_mean"` replaces missing
#'   values with the corresponding column mean; `"impute_group_mean"`
#'   replaces missing values with the mean of the same trait within the
#'   same group (`groups`, or the auto-detected `species` column), falling
#'   back to the column mean, with a warning, for a group entirely missing
#'   a trait; `"missforest"` uses random-forest-based iterative imputation
#'   (`missForest::missForest()`, Stekhoven & Bühlmann, 2012) on the
#'   numeric trait matrix, using `groups` (when available) as an
#'   additional predictor. `"omit"` and every imputation option print a
#'   `message()` reporting the number of rows removed or values imputed
#'   (plus, for `"missforest"`, the out-of-bag normalised RMSE of the
#'   imputation), so this is never a silent operation.
#' @param missforest_ntree,missforest_maxiter Number of trees per forest
#'   and maximum number of iterations passed to
#'   `missForest::missForest()` when `na_action = "missforest"`; ignored
#'   otherwise. Default to `missForest`'s own defaults (`100` and `10`).
#'
#' @return An object of class `"intrait_traitspace"`, a list with elements
#'   `scores` (data.frame of ordination scores), `var_explained` (percent
#'   variance explained by the two selected axes), `loadings` (PCA
#'   variable loadings, `NULL` for `method = "pcoa"`), `groups`, `axes`,
#'   `method`, `traits_used` (names of the numeric columns used), and `X`
#'   (the full standardised trait matrix actually analysed, i.e. after
#'   log-transformation and removal of constant columns, centred/scaled as
#'   requested; used internally by [trait_disparity()] so that dispersion
#'   statistics are not truncated to the two plotting axes). Has a
#'   dedicated [plot()] method.
#'
#' @details
#' By default (`na_action = "fail"`), rows with `NA` in any numeric trait
#' cause an error; set `na_action` to `"omit"` or one of the imputation
#' options to handle missing values automatically (see `na_action`). Mean
#' imputation (`"impute_mean"`, `"impute_group_mean"`) is a simple,
#' commonly used approach for small amounts of missing data in functional
#' trait matrices, but it shrinks the imputed trait's variance, ignores
#' correlations among traits, and can understate group dispersion (see
#' [trait_disparity()]). `na_action = "missforest"` addresses these
#' limitations with nonparametric random-forest imputation (Stekhoven &
#' Bühlmann, 2012), which uses the correlation structure among all
#' numeric traits (and `groups`, when available, as an auxiliary
#' predictor) to predict each missing value, and is generally preferred
#' over mean imputation once more than a few values are missing;
#' it requires the `missForest` package (not installed by default; see
#' `Suggests`) and is stochastic, so results vary run to run unless
#' `set.seed()` is called beforehand. If a very large fraction of values
#' is missing, no automated imputation method is a substitute for
#' reviewing the missing-data mechanism directly. This function does not
#' implement Gower distance for mixed (numeric and categorical) trait
#' tables; for mixed-trait functional spaces, standard tools such as the
#' `mFD` or `FD` packages should be used instead.
#'
#' Note that this log-transform-then-standardise treatment applies to
#' *trait* data (ratios, linear measurements, etc.) only. It is not applied
#' by, and should not be applied to, [morpho_space()], which ordinates
#' Procrustes shape coordinates: those are already a homogeneous,
#' size-free coordinate system in which log-transforming or rescaling
#' individual columns would distort shape geometry.
#'
#' @references
#' Villéger, S., Brosse, S., Mouchet, M., Mouillot, D., & Vanni, M. J.
#' (2017). Functional ecology of fish: current approaches and future
#' challenges. Aquatic Sciences, 79(4), 783-801.
#'
#' @seealso [fishmorph_ratios()], [morpho_ratios()], [morpho_space()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species)
#' ts
#' \donttest{
#' plot(ts)
#' }
#'
#' @export
trait_space <- function(traits, groups = NULL, method = c("pca", "pcoa"),
                         log_transform = TRUE, scale = TRUE, axes = c(1, 2),
                         na_action = c("fail", "omit", "impute_mean", "impute_group_mean", "missforest"),
                         missforest_ntree = 100, missforest_maxiter = 10) {
  method <- match.arg(method)
  na_action <- match.arg(na_action)
  if (!is.data.frame(traits) && !is.matrix(traits)) {
    stop("`traits` must be a data.frame or matrix of numeric trait values.", call. = FALSE)
  }
  traits_df <- as.data.frame(traits)

  if (is.null(groups) && "species" %in% names(traits_df)) {
    groups <- traits_df$species
  }
  if (!is.null(groups)) {
    if (length(groups) != nrow(traits_df)) stop("`groups` must have one entry per row of `traits`.", call. = FALSE)
    groups <- factor(groups)
  }

  numeric_cols <- names(traits_df)[vapply(traits_df, is.numeric, logical(1))]
  dropped <- setdiff(names(traits_df), numeric_cols)
  if (length(numeric_cols) == 0) stop("`traits` must contain at least two numeric columns.", call. = FALSE)
  if (length(dropped) > 0) {
    warning("Dropping non-numeric column(s) from the ordination: ", paste(dropped, collapse = ", "), call. = FALSE)
  }

  X <- as.matrix(traits_df[numeric_cols])

  if (anyNA(X)) {
    if (na_action == "fail") {
      stop(
        "`traits` contains missing values; remove or impute NAs before building ",
        "a trait space, or set `na_action` to \"omit\", \"impute_mean\", ",
        "\"impute_group_mean\", or \"missforest\" (see ?trait_space).",
        call. = FALSE
      )
    }
    if (na_action == "impute_group_mean" && is.null(groups)) {
      stop(
        "`na_action = \"impute_group_mean\"` requires `groups` (or a `species` ",
        "column in `traits`) to be available.",
        call. = FALSE
      )
    }

    if (na_action == "omit") {
      keep <- stats::complete.cases(X)
      n_dropped <- sum(!keep)
      message(sprintf(
        "na_action = \"omit\": removing %d row(s) out of %d with missing values.",
        n_dropped, nrow(X)
      ))
      X <- X[keep, , drop = FALSE]
      traits_df <- traits_df[keep, , drop = FALSE]
      if (!is.null(groups)) groups <- droplevels(groups[keep])
    } else if (na_action == "impute_mean") {
      n_na <- sum(is.na(X))
      for (j in seq_len(ncol(X))) {
        col_na <- is.na(X[, j])
        if (any(col_na)) X[col_na, j] <- mean(X[, j], na.rm = TRUE)
      }
      message(sprintf(
        "na_action = \"impute_mean\": imputed %d missing value(s) using column means.",
        n_na
      ))
    } else if (na_action == "impute_group_mean") {
      n_na <- sum(is.na(X))
      for (j in seq_len(ncol(X))) {
        col <- X[, j]
        col_na <- is.na(col)
        if (!any(col_na)) next
        for (g in levels(groups)) {
          idx <- groups == g & col_na
          if (!any(idx)) next
          g_mean <- mean(col[groups == g], na.rm = TRUE)
          if (is.nan(g_mean)) {
            warning(
              "Group \"", g, "\" has no non-missing values for at least one trait; ",
              "falling back to the overall column mean for imputation.",
              call. = FALSE
            )
            g_mean <- mean(col, na.rm = TRUE)
          }
          col[idx] <- g_mean
        }
        X[, j] <- col
      }
      message(sprintf(
        "na_action = \"impute_group_mean\": imputed %d missing value(s) using within-group means.",
        n_na
      ))
    } else if (na_action == "missforest") {
      if (!requireNamespace("missForest", quietly = TRUE)) {
        stop(
          "na_action = \"missforest\" requires the \"missForest\" package. ",
          "Install it with install.packages(\"missForest\").",
          call. = FALSE
        )
      }
      n_na <- sum(is.na(X))
      df_for_rf <- as.data.frame(X)
      if (!is.null(groups)) df_for_rf$.group <- groups
      imp <- missForest::missForest(
        df_for_rf, ntree = missforest_ntree, maxiter = missforest_maxiter,
        verbose = FALSE
      )
      ximp <- imp$ximp
      X <- as.matrix(ximp[, numeric_cols, drop = FALSE])
      storage.mode(X) <- "double"
      nrmse <- if ("NRMSE" %in% names(imp$OOBerror)) imp$OOBerror[["NRMSE"]] else NA_real_
      message(sprintf(
        "na_action = \"missforest\": imputed %d missing value(s) using random-forest imputation (missForest)%s%s.",
        n_na,
        if (!is.null(groups)) ", using `groups` as an auxiliary predictor" else "",
        if (!is.na(nrmse)) sprintf(" (out-of-bag NRMSE = %.3f)", nrmse) else ""
      ))
    }
  }

  if (isTRUE(log_transform)) {
    if (any(X < 0)) {
      stop(
        "`log_transform = TRUE` requires all trait values to be non-negative ",
        "(log10(x + 1) is not meaningful for negative traits); set `log_transform = FALSE` ",
        "or check your data.",
        call. = FALSE
      )
    }
    X <- log10(X + 1)
  }

  col_sd <- apply(X, 2, stats::sd)
  zero_var <- colnames(X)[col_sd == 0]
  if (length(zero_var) > 0) {
    warning(
      "Dropping constant (zero-variance) column(s) from the ordination: ",
      paste(zero_var, collapse = ", "), call. = FALSE
    )
    X <- X[, setdiff(colnames(X), zero_var), drop = FALSE]
  }
  numeric_cols <- colnames(X)
  if (ncol(X) < 2) {
    stop(
      "`traits` must contain at least two numeric columns after removing ",
      "constant (zero-variance) columns.",
      call. = FALSE
    )
  }
  if (length(axes) != 2) stop("`axes` must be a length-2 integer vector.", call. = FALSE)

  # Standardised matrix actually analysed (post log-transform, post
  # zero-variance-column removal, centred/scaled as requested), kept for
  # re-use by trait_disparity() so that dispersion statistics are computed
  # on exactly the same preprocessed data as the ordination, without
  # truncation to the 2 plotting axes.
  X_std <- scale(X, center = TRUE, scale = scale)

  if (method == "pca") {
    pca <- stats::prcomp(X, center = TRUE, scale. = scale)
    if (max(axes) > ncol(pca$x)) {
      stop("`axes` requests a component beyond the ", ncol(pca$x), " available.", call. = FALSE)
    }
    scores <- as.data.frame(pca$x[, axes, drop = FALSE])
    var_explained <- (pca$sdev^2 / sum(pca$sdev^2))[axes] * 100
    loadings <- pca$rotation
    axis_prefix <- "PC"
  } else {
    Xs <- scale(X, center = TRUE, scale = scale)
    d <- stats::dist(Xs, method = "euclidean")
    mds <- stats::cmdscale(d, k = max(axes), eig = TRUE)
    if (max(axes) > ncol(mds$points)) {
      stop("`axes` requests a component beyond the ", ncol(mds$points), " available.", call. = FALSE)
    }
    scores <- as.data.frame(mds$points[, axes, drop = FALSE])
    eig_pos <- mds$eig[mds$eig > 0]
    var_explained <- (mds$eig[axes] / sum(eig_pos)) * 100
    loadings <- NULL
    axis_prefix <- "MDS"
  }

  names(scores) <- paste0(axis_prefix, axes)
  rownames(scores) <- rownames(traits_df)

  structure(
    list(
      scores = scores,
      var_explained = stats::setNames(var_explained, names(scores)),
      loadings = loadings,
      groups = groups,
      axes = axes,
      method = method,
      traits_used = numeric_cols,
      X = X_std,
      scale = scale
    ),
    class = "intrait_traitspace"
  )
}

#' @export
print.intrait_traitspace <- function(x, ...) {
  cat("<intrait_traitspace> (", x$method, ")\n", sep = "")
  cat(sprintf(
    "  Axes %s/%s, variance explained: %.1f%% / %.1f%%\n",
    names(x$scores)[1], names(x$scores)[2], x$var_explained[1], x$var_explained[2]
  ))
  cat(sprintf(
    "  %d observations, %d traits (%s)\n",
    nrow(x$scores), length(x$traits_used), paste(x$traits_used, collapse = ", ")
  ))
  if (!is.null(x$groups)) cat(sprintf("  %d groups\n", nlevels(x$groups)))
  invisible(x)
}

#' Plot a functional trait space
#'
#' @param x An object of class `"intrait_traitspace"`, from
#'   [trait_space()].
#' @param style Character, one of `"spider"` (default), `"hull"`, or
#'   `"none"`, controlling how groups are displayed; see the Details
#'   section of [plot.intrait_morphospace()]. Ignored if `x$groups` is
#'   `NULL`.
#' @param ellipse_level Coverage probability of the per-group dispersion
#'   ellipse drawn when `style = "spider"`, under a bivariate-normal
#'   approximation. Defaults to `0.95`.
#' @param legend Logical, draw a legend of group colors. Defaults to
#'   `TRUE` when `x$groups` is available.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns `x`.
#' @export
plot.intrait_traitspace <- function(x, style = c("spider", "hull", "none"),
                                     ellipse_level = 0.95,
                                     legend = !is.null(x$groups), ...) {
  style <- match.arg(style)
  xlab <- sprintf("%s (%.1f%%)", names(x$scores)[1], x$var_explained[1])
  ylab <- sprintf("%s (%.1f%%)", names(x$scores)[2], x$var_explained[2])
  .plot_ordination(x$scores, x$groups, xlab, ylab, style = style,
                    ellipse_level = ellipse_level, legend = legend, ...)
  invisible(x)
}
