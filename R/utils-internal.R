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

#' Filter a data.frame to one or more operators, if an `operator` column
#' is present
#'
#' Shared, modular implementation of the `operator` argument of
#' [load_t26_saudrune()] and [load_t26_saudrune_landmarks()]: matches
#' case-insensitively (so `"operator_1"`/`"Operator_1"`/`"OPERATOR_1"` are
#' all accepted), and is a no-op (returns `df` unchanged, with a warning)
#' when `df` has no `operator` column at all, so the same call works
#' whether or not the requested table happens to record operator identity.
#'
#' @param df A `data.frame`, possibly with an `operator` column.
#' @param operator `NULL` (no filtering), or a character vector of one or
#'   more operator labels to keep.
#' @param dataset_label Character, used only in the warning/error messages
#'   to name the table being filtered (e.g. `"the \"operators\" table"`).
#' @return `df`, filtered to the requested operator(s) if applicable.
#' @noRd
.filter_by_operator <- function(df, operator, dataset_label = "this table") {
  if (is.null(operator)) {
    return(df)
  }
  if (!"operator" %in% names(df)) {
    warning(
      "`operator` was supplied but ", dataset_label, " has no `operator` ",
      "column; ignoring `operator` and returning all available data.",
      call. = FALSE
    )
    return(df)
  }
  available <- sort(unique(df$operator))
  matched <- tolower(trimws(df$operator)) %in% tolower(trimws(operator))
  if (!any(matched)) {
    stop(
      "`operator` (", paste(sprintf("\"%s\"", operator), collapse = ", "),
      ") does not match any operator recorded in ", dataset_label,
      " (available: ", paste(available, collapse = ", "), ").",
      call. = FALSE
    )
  }
  df[matched, , drop = FALSE]
}

#' Left-join species identity onto a T-26 Saudrune table, if possible
#'
#' Shared, modular implementation of the `species` argument of
#' [load_t26_saudrune()]: adds `species` and `id_status` columns looked up
#' from the `"identifications"` table via `code`. Deliberately implemented
#' with a vectorised [match()] lookup rather than [merge()]: the
#' `"operators"`/`"repeatability"` long-format tables have many rows per
#' `code` (one per landmark, and per operator/replicate), so a
#' duplicate-key join must be verified to preserve the original row order
#' exactly (`match()` guarantees this trivially, by construction, so there
#' is nothing to verify).
#'
#' @param df A `data.frame`, possibly with a `code` column.
#' @param dataset_label Character, used only in the warning message to
#'   name the table being joined (e.g. `"the \"operators\" table"`).
#' @return `df`, with `species`/`id_status` columns added if possible; a
#'   no-op if `df` already has both (e.g. the `"identifications"` table
#'   itself), or (with a warning) if `df` has no `code` column to join on.
#' @noRd
.join_species <- function(df, dataset_label = "this table") {
  if (all(c("species", "id_status") %in% names(df))) {
    return(df)
  }
  if (!"code" %in% names(df)) {
    warning(
      "`species` was supplied but ", dataset_label, " has no `code` column ",
      "to join on; ignoring `species` and returning the table unchanged.",
      call. = FALSE
    )
    return(df)
  }
  ident <- load_t26_saudrune("identifications")
  idx <- match(df$code, ident$code)
  df$species <- ident$species[idx]
  df$id_status <- ident$id_status[idx]
  df
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

#' Bivariate Gaussian kernel density estimate on a regular grid
#'
#' A small, dependency-free reimplementation of the standard bivariate
#' kernel density estimator (the same product-Gaussian-kernel formula
#' underlying `MASS::kde2d()`), used to draw non-parametric group-density
#' contours in `.plot_ordination()` (`style = "density"`). Implemented
#' directly with base R (`stats::dnorm()`, `stats::bw.nrd0()`) rather than
#' importing MASS, since MASS is bundled with R but not automatically
#' attached, and this estimator is only a few lines long.
#'
#' @param x,y Numeric vectors of coordinates (same length).
#' @param n Grid resolution (an `n x n` grid).
#' @param expand Fraction of each axis' data range used to pad the grid on
#'   either side, so contours are not clipped at the data extremes.
#' @return A list with `x`, `y` (length-`n` grid coordinate vectors) and
#'   `z` (an `n x n` density matrix; `z[i, j]` is the density estimate at
#'   `(x[i], y[j])`, the orientation expected by
#'   [grDevices::contourLines()]).
#' @noRd
.kde2d <- function(x, y, n = 60, expand = 0.2) {
  rx <- range(x)
  ry <- range(y)
  padx <- diff(rx) * expand
  pady <- diff(ry) * expand
  if (padx <= 0) padx <- 1
  if (pady <= 0) pady <- 1
  gx <- seq(rx[1] - padx, rx[2] + padx, length.out = n)
  gy <- seq(ry[1] - pady, ry[2] + pady, length.out = n)

  hx <- stats::bw.nrd0(x)
  hy <- stats::bw.nrd0(y)
  if (!is.finite(hx) || hx <= 0) hx <- max(diff(rx), 1e-6) / 4
  if (!is.finite(hy) || hy <= 0) hy <- max(diff(ry), 1e-6) / 4

  ax <- outer(gx, x, function(g, xi) stats::dnorm((g - xi) / hx)) / hx
  ay <- outer(gy, y, function(g, yi) stats::dnorm((g - yi) / hy)) / hy
  z <- (ax %*% t(ay)) / length(x)
  list(x = gx, y = gy, z = z)
}

#' Highest-density-region contour line(s) for a 2D point cloud
#'
#' Non-parametric alternative to `.covariance_ellipse()`: estimates a 2D
#' kernel density (`.kde2d()`) and finds the density threshold whose
#' enclosed region contains approximately `level` of the estimated
#' probability mass (the highest-density-region, HDR, approach of Hyndman,
#' 1996), so that groups with skewed or multimodal point clouds (as can
#' occur, e.g., with real digitization data; see the T-26 Saudrune
#' morphospace, where a couple of strongly deviating specimens skew one
#' species' distribution) are not forced into a symmetric ellipse.
#'
#' @param x,y Numeric vectors of coordinates.
#' @param level Coverage probability of the contour (e.g. `0.95`),
#'   analogous in spirit to `ellipse_level` for `.covariance_ellipse()`.
#' @param n Grid resolution passed to `.kde2d()`.
#' @return A list of data.frames (one per contour polyline, as returned by
#'   [grDevices::contourLines()]), or `NULL` if there are too few points
#'   (fewer than 5) or the density estimate is degenerate.
#'
#' @references
#' Hyndman RJ (1996). Computing and graphing highest density regions. The
#' American Statistician, 50(2), 120-126.
#' @noRd
.density_contour <- function(x, y, level = 0.95, n = 60) {
  if (length(x) < 5) return(NULL)
  kd <- tryCatch(.kde2d(x, y, n = n), error = function(e) NULL)
  if (is.null(kd) || any(!is.finite(kd$z))) return(NULL)
  z_sorted <- sort(as.vector(kd$z), decreasing = TRUE)
  total_mass <- sum(z_sorted)
  if (!is.finite(total_mass) || total_mass <= 0) return(NULL)
  cum_mass <- cumsum(z_sorted) / total_mass
  idx <- which(cum_mass >= level)[1]
  if (is.na(idx)) return(NULL)
  hdr_level <- z_sorted[idx]
  lines <- grDevices::contourLines(kd$x, kd$y, kd$z, levels = hdr_level)
  if (length(lines) == 0) return(NULL)
  lines
}

#' Abbreviate a "Genus species" binomial for compact legend display
#'
#' Converts `"Genus species"` to `"G. species"` (the standard taxonomic
#' abbreviation convention, e.g. journal figure legends), leaving anything
#' that is not a clean two-part (or more) binomial unchanged: single-word
#' labels (e.g. a non-species grouping variable accidentally passed through)
#' are returned as-is, and only the first word is abbreviated so that
#' informal multi-part labels (e.g. `"Phoxinus phoxinus/bigerri"`, used in
#' the T-26 Saudrune identifications for two morphologically inseparable
#' taxa) degrade gracefully to `"P. phoxinus/bigerri"` rather than being
#' mangled.
#'
#' @param x Character vector of labels.
#' @return Character vector, same length as `x`.
#' @noRd
.abbreviate_species_name <- function(x) {
  vapply(x, function(lbl) {
    parts <- strsplit(lbl, " ", fixed = TRUE)[[1]]
    if (length(parts) < 2 || nchar(parts[1]) < 2) return(lbl)
    paste0(substr(parts[1], 1, 1), ". ", paste(parts[-1], collapse = " "))
  }, character(1), USE.NAMES = FALSE)
}

#' Qualitative colour palette for ordination group plots
#'
#' A curated, high-contrast categorical palette (the "Tableau 10" set,
#' widely used for qualitative data because its colours are chosen to be
#' distinguishable both from each other and, reasonably, under common forms
#' of colour vision deficiency) for up to 10 groups; for more groups than
#' that, falls back to [grDevices::hcl.colors()], which can generate an
#' arbitrarily large qualitative palette (at some cost to distinguishability
#' once very many groups are requested, an unavoidable limit of categorical
#' colour, not specific to this palette).
#'
#' @param n Number of colours needed (i.e. `nlevels(groups)`).
#' @return A character vector of `n` hex colour codes.
#' @noRd
.ordination_palette <- function(n) {
  base_pal <- c(
    "#4E79A7", "#F28E2B", "#59A14F", "#E15759", "#B07AA1",
    "#76B7B2", "#EDC948", "#FF9DA7", "#9C755F", "#BAB0AC"
  )
  if (n <= length(base_pal)) return(base_pal[seq_len(n)])
  grDevices::hcl.colors(n, palette = "Dark 3")
}

#' n-dimensional convex-hull volume, via Qhull
#'
#' Thin wrapper around [geometry::convhulln()] used by
#' [bootstrap_functional_space()] to compute functional richness (the
#' convex-hull "volume" of a point cloud in a k-dimensional PCA space,
#' Villeger, Mason & Mouillot, 2008) for an arbitrary number of dimensions,
#' degrading gracefully (returning `NA`, never erroring) whenever the
#' points do not support a non-degenerate hull in that many dimensions
#' (fewer than `k + 1` points, or points that are not affinely
#' independent, e.g. exactly co-planar).
#'
#' @param pts A numeric matrix, one row per point, `k` columns
#'   (dimensions).
#' @return A single numeric volume, or `NA_real_` if the hull is
#'   degenerate.
#' @noRd
.convex_hull_volume <- function(pts) {
  pts <- as.matrix(pts)
  if (nrow(pts) <= ncol(pts)) return(NA_real_)
  vol <- tryCatch(
    geometry::convhulln(pts, options = "FA")$vol,
    error = function(e) NA_real_
  )
  if (is.null(vol)) return(NA_real_)
  vol
}

#' Parallel-aware `vapply()`
#'
#' Uses [future.apply::future_vapply()] (with `future.seed = TRUE` for
#' statistically correct random-number handling across parallel workers,
#' via `L'Ecuyer-CMRG` streams) when the `future.apply` package is
#' available, falling back to a plain [vapply()] otherwise. Used to
#' distribute the independent, repeated convex-hull computations in
#' [bootstrap_functional_space()], [trait_disparity()], and
#' [species_sensitivity()] -- each individual bootstrap draw, permutation,
#' or species/individual replacement is embarrassingly parallel (no
#' dependency on any other iteration's result).
#'
#' Deliberately never chooses a worker count or backend itself: that
#' decision belongs entirely to the calling user's own `future::plan()`
#' (e.g. `future::plan("multisession")` before calling
#' `bootstrap_functional_space()`, or `future::plan("multisession",
#' workers = 4)`) -- a package should never silently spawn background
#' processes a user didn't ask for. With no plan set (future's own
#' default, `"sequential"`), or without `future.apply` installed at all,
#' this behaves exactly like a plain `vapply()`, so nothing changes for
#' users who have not opted in.
#'
#' @param X A vector or list to iterate over.
#' @param FUN A function to apply to each element of `X`.
#' @param FUN.VALUE As in [vapply()]: a template for the return value of
#'   `FUN`, defining its expected length/type.
#' @return As in [vapply()]: a vector (or matrix, if `FUN.VALUE` has
#'   length > 1) of the results.
#' @noRd
.papply <- function(X, FUN, FUN.VALUE) {
  if (requireNamespace("future.apply", quietly = TRUE)) {
    future.apply::future_vapply(X, FUN, FUN.VALUE, future.seed = TRUE)
  } else {
    vapply(X, FUN, FUN.VALUE)
  }
}

#' Per-group centroid matrix
#'
#' @param sc A numeric matrix of scores, one row per individual.
#' @param g A factor of the same length as `nrow(sc)`.
#' @return A numeric matrix, one row per level of `g` (in `levels(g)`
#'   order), giving the column means of `sc` within that level.
#' @noRd
.group_centroids <- function(sc, g) {
  t(vapply(levels(g), function(lv) {
    colMeans(sc[g == lv, , drop = FALSE])
  }, numeric(ncol(sc))))
}

#' Within-group outlier distance screen
#'
#' For each observation, computes its Euclidean distance to its own group's
#' centroid (in whatever space `X` represents, e.g. a standardised trait
#' matrix), then flags observations whose distance is unusually large
#' *relative to other members of the same group*, using the same
#' median + `threshold` * MAD robust rule as `detect_outliers()`. Deliberately
#' a simple, transparent per-group generalisation of `detect_outliers()`'s
#' pooled screen (Euclidean distance, not Mahalanobis, so it does not
#' require estimating a per-group covariance matrix -- unreliable for the
#' small per-species sample sizes typical of real field data).
#'
#' @param X A numeric matrix, one row per observation (e.g. a standardised
#'   trait matrix).
#' @param groups A factor of length `nrow(X)`, e.g. species identity.
#' @param threshold Numeric, number of MADs above the group's median
#'   distance beyond which an observation is flagged.
#' @param min_n Integer, minimum group size for flagging to be attempted;
#'   groups smaller than this get a distance (still informative) but
#'   `flagged` is `NA` rather than `TRUE`/`FALSE`, since median/MAD are not
#'   reliably estimable from very few points.
#' @return A `data.frame`, one row per observation (same row order as `X`),
#'   with columns `group`, `n_group`, `distance`, `median_distance`,
#'   `mad_distance`, `threshold_value`, `flagged` (logical, `NA` for groups
#'   smaller than `min_n`).
#' @noRd
.group_outlier_distance <- function(X, groups, threshold = 3, min_n = 5) {
  groups <- droplevels(as.factor(groups))
  n <- nrow(X)
  distance <- numeric(n)
  median_distance <- numeric(n)
  mad_distance <- numeric(n)
  threshold_value <- numeric(n)
  flagged <- logical(n)
  n_group <- integer(n)

  for (lv in levels(groups)) {
    idx <- which(groups == lv)
    n_group[idx] <- length(idx)
    sub <- X[idx, , drop = FALSE]
    centroid <- colMeans(sub)
    d <- sqrt(rowSums(sweep(sub, 2, centroid)^2))
    distance[idx] <- d

    if (length(idx) < min_n) {
      median_distance[idx] <- NA_real_
      mad_distance[idx] <- NA_real_
      threshold_value[idx] <- NA_real_
      flagged[idx] <- NA
      next
    }

    med <- stats::median(d)
    mad_val <- stats::mad(d)
    thr <- if (isTRUE(mad_val == 0)) med else med + threshold * mad_val
    median_distance[idx] <- med
    mad_distance[idx] <- mad_val
    threshold_value[idx] <- thr
    flagged[idx] <- d > thr
  }

  data.frame(
    group = as.character(groups),
    n_group = n_group,
    distance = distance,
    median_distance = median_distance,
    mad_distance = mad_distance,
    threshold_value = threshold_value,
    flagged = flagged,
    row.names = rownames(X)
  )
}

#' Handle missing values in a numeric matrix of traits/measurements
#'
#' Shared implementation of the `na_action` convention introduced by
#' [trait_space()] (`"fail"`/`"keep"`, `"omit"`, `"impute_mean"`,
#' `"impute_group_mean"`, `"missforest"`), reused by [trait_space()],
#' [fishmorph_segments()], and [fishmorph_ratios()] so the same options
#' behave identically (same messages, same imputation logic) wherever
#' missing values need handling in this package.
#'
#' @param X A numeric matrix, one row per specimen/observation.
#' @param groups Optional factor, one value per row of `X`; required for
#'   `na_action = "impute_group_mean"`, optionally used as an auxiliary
#'   predictor for `na_action = "missforest"`.
#' @param na_action Character: `"keep"`/`"fail"` do nothing except, for
#'   `"fail"`, stop with an error if `X` has any `NA`; `"omit"` reports and
#'   drops incomplete rows; `"impute_mean"`/`"impute_group_mean"` replace
#'   `NA` with the column/within-group mean; `"missforest"` uses
#'   `missForest::missForest()`.
#' @param missforest_ntree,missforest_maxiter Passed to
#'   `missForest::missForest()`.
#' @param context Character, used only to word messages/errors (e.g.
#'   `"traits"`, `"segments"`, `"ratios"`).
#' @return A list with `X` (the possibly modified/row-reduced matrix) and
#'   `keep` (logical vector, length `nrow(X)` as passed in, `TRUE` for rows
#'   retained -- all `TRUE` unless `na_action = "omit"` dropped some).
#' @noRd
.apply_na_action <- function(X, groups, na_action, missforest_ntree = 100,
                              missforest_maxiter = 10, context = "traits") {
  n <- nrow(X)
  if (!anyNA(X)) {
    return(list(X = X, keep = rep(TRUE, n)))
  }
  if (na_action == "keep") {
    return(list(X = X, keep = rep(TRUE, n)))
  }
  if (na_action == "fail") {
    stop(
      "`", context, "` contains missing values; set `na_action` to \"omit\", ",
      "\"impute_mean\", \"impute_group_mean\", or \"missforest\" to handle them ",
      "(see the function's documentation).",
      call. = FALSE
    )
  }
  if (na_action == "impute_group_mean" && is.null(groups)) {
    stop(
      "`na_action = \"impute_group_mean\"` requires `groups` (or an ",
      "auto-detected `species` column) to be available.",
      call. = FALSE
    )
  }

  keep <- rep(TRUE, n)
  if (na_action == "omit") {
    keep <- stats::complete.cases(X)
    message(sprintf(
      "na_action = \"omit\": removing %d row(s) out of %d with missing values.",
      sum(!keep), n
    ))
    X <- X[keep, , drop = FALSE]
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
    # `groups` itself can legitimately contain NA (e.g. an unresolved
    # species identification, as in the real T-26 data); using which() with
    # explicit !is.na() guards below (rather than plain logical indexing)
    # keeps this branch from erroring in that case -- rows with an unknown
    # group simply cannot be imputed by within-group mean and are left NA.
    X_before <- is.na(X)
    group_na <- is.na(groups)
    if (any(group_na)) {
      warning(
        sum(group_na), " row(s) have a missing/unresolved `groups` value and ",
        "cannot be imputed by within-group mean; any missing ", context,
        " value(s) for them are left as NA.",
        call. = FALSE
      )
    }
    for (j in seq_len(ncol(X))) {
      col <- X[, j]
      col_na <- is.na(col)
      if (!any(col_na)) next
      for (g in levels(groups)) {
        in_group <- !group_na & groups == g
        idx <- which(in_group & col_na)
        if (length(idx) == 0) next
        g_mean <- mean(col[in_group], na.rm = TRUE)
        if (is.nan(g_mean)) {
          warning(
            "Group \"", g, "\" has no non-missing values for at least one ",
            context, " column; falling back to the overall column mean for imputation.",
            call. = FALSE
          )
          g_mean <- mean(col, na.rm = TRUE)
        }
        col[idx] <- g_mean
      }
      X[, j] <- col
    }
    n_imputed <- sum(X_before & !is.na(X))
    message(sprintf(
      "na_action = \"impute_group_mean\": imputed %d missing value(s) using within-group means.",
      n_imputed
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
    X <- as.matrix(ximp[, colnames(X), drop = FALSE])
    storage.mode(X) <- "double"
    nrmse <- if ("NRMSE" %in% names(imp$OOBerror)) imp$OOBerror[["NRMSE"]] else NA_real_
    message(sprintf(
      "na_action = \"missforest\": imputed %d missing value(s) using random-forest imputation (missForest)%s%s.",
      n_na,
      if (!is.null(groups)) ", using `groups` as an auxiliary predictor" else "",
      if (!is.na(nrmse)) sprintf(" (out-of-bag NRMSE = %.3f)", nrmse) else ""
    ))
  }

  list(X = X, keep = keep)
}

#' Orientation of the best-fit line through a set of 2D points
#'
#' Used by `correct_landmarks(rule = "check_geometry")` to estimate the
#' direction of a landmark line (a two-point segment, or a longer
#' multi-landmark reference line such as the eye-socket vertical) as an
#' undirected angle. Rows with a missing (`NA`) coordinate are dropped
#' first (as in `plot_fishmorph_points()`'s `outline` drawing), so a line
#' still gets an estimated orientation from its remaining landmarks rather
#' than failing outright. For exactly two points, the angle is the exact
#' direction between them; for more than two, it is the first principal
#' axis (a total-least-squares line fit, robust to a near-vertical line,
#' unlike an ordinary `y ~ x` regression).
#'
#' @param xy A numeric matrix, one row per landmark, two columns (X, Y).
#' @return A single angle in degrees, in `[0, 180)` (a line has no
#'   direction, only an orientation, so 0 and 180 are equivalent and folded
#'   together), or `NA_real_` if fewer than two landmarks have complete
#'   coordinates, or all remaining points coincide.
#' @noRd
.line_angle_deg <- function(xy) {
  xy <- xy[stats::complete.cases(xy), , drop = FALSE]
  if (nrow(xy) < 2) return(NA_real_)
  if (nrow(xy) == 2) {
    d <- xy[2, ] - xy[1, ]
  } else {
    ctr <- scale(xy, scale = FALSE)
    if (all(ctr == 0)) return(NA_real_)
    d <- stats::prcomp(ctr)$rotation[, 1]
  }
  if (all(d == 0)) return(NA_real_)
  (atan2(d[2], d[1]) * 180 / pi) %% 180
}

#' Undirected angle between two lines, given their `.line_angle_deg()`
#'
#' `0` means the two lines are parallel, `90` means they are perpendicular;
#' intermediate values interpolate between the two. Used by
#' `correct_landmarks(rule = "check_geometry")` both directly (for
#' parallelism checks) and via `abs(delta - 90)` (for perpendicularity
#' checks), so a single degree-based `tolerance` covers every check.
#'
#' @param a,b Angles in degrees, in `[0, 180)`, as returned by
#'   `.line_angle_deg()`.
#' @return A single angle in degrees, in `[0, 90]`, or `NA_real_` if either
#'   input is `NA`.
#' @noRd
.angle_between_deg <- function(a, b) {
  if (is.na(a) || is.na(b)) return(NA_real_)
  d <- abs(a - b) %% 180
  min(d, 180 - d)
}

#' FISHMORPH landmark groups checked by `correct_landmarks(rule =
#' "check_geometry")`
#'
#' Single source of truth for the landmark indices making up the main body
#' axis, the ventral horizontal reference line, and the three "vertical"
#' segments/lines whose orientation `check_geometry` audits, so
#' `.check_landmark_geometry()`, `.geometry_check_points()` (used by
#' `plot_fishmorph_points()`'s `highlight_geometry`), and
#' `.geometry_check_traits()` (used by `fishmorph_segments()`'s
#' `geometry_check`) never drift out of sync with each other.
#'
#' @return A named list of integer vectors of landmark indices.
#' @noRd
.geometry_check_groups <- function() {
  list(
    axis         = c(1, 2),
    horiz        = c(9, 8, 11, 4),
    seg_1_9      = c(1, 9),
    seg_3_4      = c(3, 4),
    seg_10_11    = c(10, 11),
    eye_vertical = c(5, 13, 7, 14, 6, 8)
  )
}

#' Landmark points implicated by each `check_geometry()` check
#'
#' Used by `plot_fishmorph_points()`'s `highlight_geometry` to know which
#' points to highlight when a `correct_landmarks(rule = "check_geometry")`
#' check fails for the specimen being plotted.
#'
#' @return A named list (names matching the `check` column of an
#'   `"intrait_geometry_check"` object) of integer vectors of landmark
#'   indices.
#' @noRd
.geometry_check_points <- function() {
  g <- .geometry_check_groups()
  list(
    eye_axis_vertical_alignment        = g$eye_vertical,
    perpendicular_seg_1_9_vs_axis       = union(g$seg_1_9, g$axis),
    perpendicular_seg_3_4_vs_axis       = union(g$seg_3_4, g$axis),
    perpendicular_seg_10_11_vs_axis     = union(g$seg_10_11, g$axis),
    perpendicular_eye_vertical_vs_axis  = union(g$eye_vertical, g$axis),
    parallel_vertical_segments         = Reduce(union, list(g$seg_1_9, g$seg_3_4, g$seg_10_11, g$eye_vertical)),
    axis_horizontal_parallel           = union(g$axis, g$horiz)
  )
}

#' FISHMORPH trait columns implicated by each `check_geometry()` check
#'
#' Used by `fishmorph_segments()`'s `geometry_check` to know which of the
#' 11 linear measurements rely on a landmark line whose orientation
#' `correct_landmarks(rule = "check_geometry")` flagged as non-conforming
#' for a given specimen -- only the checks that are invariant to the
#' picture's own rotation (perpendicularity/parallelism *relative to the
#' fish's own body axis*, rather than to the absolute image frame) are
#' used here; `eye_axis_vertical_alignment` is deliberately excluded, since
#' it can fail for a validly measured, merely slightly rotated photograph
#' (see `perpendicular_eye_vertical_vs_axis` instead, which does not).
#'
#' @return A named list (names matching the `check` column of an
#'   `"intrait_geometry_check"` object) of character vectors of
#'   [fishmorph_segments()] column names.
#' @noRd
.geometry_check_traits <- function() {
  list(
    perpendicular_seg_1_9_vs_axis       = "Mo",
    perpendicular_seg_3_4_vs_axis       = "Bd",
    perpendicular_seg_10_11_vs_axis     = "PFi",
    perpendicular_eye_vertical_vs_axis  = c("Hd", "Eh", "Ed"),
    parallel_vertical_segments         = c("Mo", "Bd", "PFi", "Hd", "Eh", "Ed"),
    axis_horizontal_parallel           = "Bl"
  )
}

#' Resolve a `specimen` argument (`NULL`, integer, or character) into
#' integer indices
#'
#' Shared by `correct_landmarks(rule = "check_geometry")` and
#' `correct_geometry()`, so both accept the same `specimen = NULL` (every
#' specimen), integer, or character-vector convention identically.
#'
#' @param specimen `NULL`, or an integer/character vector of specimens.
#' @param specimen_names_all Character vector, `dimnames(A)[[3]]`.
#' @return Integer vector of specimen indices.
#' @noRd
.resolve_specimen_idx <- function(specimen, specimen_names_all) {
  if (is.null(specimen)) {
    return(seq_along(specimen_names_all))
  }
  if (is.character(specimen)) {
    idx <- match(specimen, specimen_names_all)
    if (anyNA(idx)) {
      stop(
        "Specimen(s) not found: ",
        paste(specimen[is.na(idx)], collapse = ", "),
        call. = FALSE
      )
    }
    return(idx)
  }
  as.integer(specimen)
}

#' Body length (Bl): Euclidean distance between landmarks 1 and 2
#'
#' Used to express `correct_landmarks(rule = "check_geometry")`'s and
#' `correct_geometry()`'s landmark-coordinate-scatter checks as a
#' proportion of body size (`tolerance_coord`) rather than an absolute
#' distance, so the same default tolerance is meaningful across specimens
#' and datasets digitized at different scales (pixels, mm, etc.).
#'
#' @param xy A `p x 2` matrix, one specimen's landmark coordinates.
#' @return A single positive number, or `NA_real_` if landmark 1 or 2 is
#'   missing for this specimen.
#' @noRd
.body_length <- function(xy) {
  if (anyNA(xy[c(1, 2), ])) return(NA_real_)
  sqrt(sum((xy[2, ] - xy[1, ])^2))
}

#' Fixed plan of the five FISHMORPH landmark-coordinate-scatter checks
#' shared by `correct_landmarks(rule = "check_geometry")` and
#' `correct_geometry()`
#'
#' Single source of truth for the five checks that ask, in effect, "do
#' these landmarks share the coordinate the FISHMORPH protocol expects of
#' them?" -- `perpendicular_seg_1_9_vs_axis`, `perpendicular_seg_3_4_vs_axis`,
#' `perpendicular_seg_10_11_vs_axis`, and `perpendicular_eye_vertical_vs_axis`
#' expect a shared X (the segment/line is vertical, i.e. perpendicular to
#' the horizontal main body axis); `axis_horizontal_parallel` expects a
#' shared Y (the ventral line is horizontal, i.e. parallel to the main
#' axis). Used identically by both functions (via
#' `.geometry_step_deviation()`) so that a check reported as non-conforming
#' by `correct_landmarks(rule = "check_geometry")` is, by construction,
#' exactly the set of checks `correct_geometry()` will act on -- earlier
#' versions measured the trigger condition as an angular deviation (the
#' group's own best-fit orientation vs the main axis'), which is a
#' *different* property from "do these points share a coordinate": a
#' landmark group can have a best-fit orientation close to the axis while
#' individual points still visibly fail to align on a shared coordinate
#' (e.g. a gently zig-zagging ventral line whose overall trend still
#' roughly parallels a main axis that is not perfectly horizontal in the
#' source photograph), which let the two functions disagree in exactly
#' that situation. Both are now driven by the same shared-coordinate
#' criterion below, so they always agree.
#'
#' Each step names: `check` (the label used throughout the package, e.g.
#' in `intrait_geometry_check`'s `check` column, `.geometry_check_points()`,
#' `.geometry_check_traits()`), `group` (landmark indices, from
#' `.geometry_check_groups()`), `axis_dim` (`"x"` or `"y"`, the coordinate
#' expected to be shared across `group`), and either a fixed `correct`/
#' `anchor` pair (two-point groups, where which of the two points deviates
#' cannot be inferred statistically -- see `correct_geometry()`'s Details)
#' or `correct = NULL`/`anchor = NULL` (multi-point groups, where the point
#' farthest from the group's own median is treated as the deviant one).
#'
#' This deliberately assumes the source photograph is reasonably close to
#' axis-aligned (as `correct_landmarks(rule = "align")` already assumes):
#' it tests raw X/Y scatter, not scatter relative to the main axis'
#' orientation, so a specimen digitized from a strongly rotated photograph
#' should be corrected at the digitization stage, not relied upon to be
#' handled by these checks.
#'
#' @return A `list` of steps, each itself a `list` with elements `check`,
#'   `group`, `axis_dim`, `correct`, `anchor`.
#' @noRd
.geometry_coord_plan <- function() {
  groups <- .geometry_check_groups()
  list(
    list(check = "perpendicular_seg_1_9_vs_axis", group = groups$seg_1_9,
         axis_dim = "x", correct = 9, anchor = 1),
    list(check = "perpendicular_seg_3_4_vs_axis", group = groups$seg_3_4,
         axis_dim = "x", correct = 4, anchor = 3),
    list(check = "perpendicular_seg_10_11_vs_axis", group = groups$seg_10_11,
         axis_dim = "x", correct = 11, anchor = 10),
    list(check = "perpendicular_eye_vertical_vs_axis", group = groups$eye_vertical,
         axis_dim = "x", correct = NULL, anchor = NULL),
    list(check = "axis_horizontal_parallel", group = groups$horiz,
         axis_dim = "y", correct = NULL, anchor = NULL)
  )
}

#' Deviation (and the correction that would resolve it) for one
#' `.geometry_coord_plan()` step
#'
#' Shared by `correct_landmarks(rule = "check_geometry")` (read-only
#' reporting, via `.check_landmark_geometry()`) and `correct_geometry()`
#' (which additionally applies the correction once
#' `deviation / .body_length(xy) > tolerance_coord`), so both always agree
#' on which point is deviant, by how much, and against which reference.
#'
#' @param xy A `p x 2` matrix, one specimen's landmark coordinates.
#' @param step One element of `.geometry_coord_plan()`.
#' @return A `list` with `deviation` (absolute coordinate difference, in
#'   the same units as `xy`; `NA_real_` if fewer than two of `step$group`'s
#'   landmarks are present, or -- for a two-point group -- if the specific
#'   `correct`/`anchor` landmark is missing), `correct_pt`, `reference_pts`,
#'   `reference_value`, and `old_value`.
#' @noRd
.geometry_step_deviation <- function(xy, step) {
  axis_col <- if (step$axis_dim == "x") 1 else 2
  vals <- xy[step$group, axis_col]
  present <- step$group[!is.na(vals)]
  na_result <- list(
    deviation = NA_real_, correct_pt = NA_integer_,
    reference_pts = integer(0), reference_value = NA_real_, old_value = NA_real_
  )
  if (length(present) < 2) return(na_result)

  if (!is.null(step$correct)) {
    # Two-point group: fixed anatomical anchor (see correct_geometry()'s
    # Details for the rationale).
    if (!(step$correct %in% present) || !(step$anchor %in% present)) return(na_result)
    correct_pt <- step$correct
    reference_pts <- step$anchor
  } else {
    # Multi-point group: the point farthest from the group's own median is
    # treated as the deviant one.
    present_vals <- xy[present, axis_col]
    med <- stats::median(present_vals)
    correct_pt <- present[which.max(abs(present_vals - med))]
    reference_pts <- setdiff(present, correct_pt)
  }

  old_value <- xy[correct_pt, axis_col]
  reference_value <- stats::median(xy[reference_pts, axis_col])
  deviation <- if (is.finite(reference_value)) abs(old_value - reference_value) else NA_real_
  list(
    deviation = deviation, correct_pt = correct_pt, reference_pts = reference_pts,
    reference_value = reference_value, old_value = old_value
  )
}

#' Every point in a `.geometry_coord_plan()` step's group that deviates
#' beyond `tolerance_coord`, and the correction that would resolve each
#'
#' Unlike `.geometry_step_deviation()` (which reports only the single
#' worst offender, for `correct_landmarks(rule = "check_geometry")`'s
#' one-number-per-check diagnostic), this is used by `correct_geometry()`
#' to *fully* resolve a group in one pass: for a multi-point group, the
#' reference (median of every present point, computed once up front) does
#' not change as points are corrected, so *every* point that individually
#' sits more than `tolerance_coord` times body length from it is corrected
#' -- not just the farthest one -- since a group can have more than one
#' misplaced point (e.g. two out of six eye-socket landmarks both off),
#' and fixing only the worst would silently leave the second visibly
#' misaligned. A two-point (fixed-anchor) group can only ever return zero
#' or one correction, since fixing the companion against its anchor always
#' fully resolves that segment.
#'
#' @param xy A `p x 2` matrix, one specimen's landmark coordinates.
#' @param step One element of `.geometry_coord_plan()`.
#' @param tolerance_coord Numeric, proportion of body length below which a
#'   point's deviation from its group's reference is left uncorrected.
#' @param bl Numeric, body length (Bl) for this specimen, as returned by
#'   `.body_length()`.
#' @return A `list` of corrections (possibly empty), each a `list` with
#'   `correct_pt`, `reference_pts`, `reference_value`, `old_value` (same
#'   shape as one `.geometry_step_deviation()` result, minus `deviation`).
#' @noRd
.geometry_group_deviants <- function(xy, step, tolerance_coord, bl) {
  if (!is.finite(bl) || bl <= 0) return(list())
  axis_col <- if (step$axis_dim == "x") 1 else 2
  vals <- xy[step$group, axis_col]
  present <- step$group[!is.na(vals)]
  if (length(present) < 2) return(list())

  if (!is.null(step$correct)) {
    # Two-point group: fixed anatomical anchor -- at most one correction.
    if (!(step$correct %in% present) || !(step$anchor %in% present)) return(list())
    old_value <- xy[step$correct, axis_col]
    reference_value <- xy[step$anchor, axis_col]
    dev <- abs(old_value - reference_value)
    if (is.na(dev) || dev / bl <= tolerance_coord) return(list())
    return(list(list(
      correct_pt = step$correct, reference_pts = step$anchor,
      reference_value = reference_value, old_value = old_value
    )))
  }

  # Multi-point group: reference is the median of every present point,
  # fixed before any correction in this pass, so every point beyond
  # tolerance -- not only the single farthest one -- is corrected onto it.
  present_vals <- xy[present, axis_col]
  med <- stats::median(present_vals)
  out <- list()
  for (j in seq_along(present)) {
    dev <- abs(present_vals[j] - med)
    if (is.na(dev) || dev / bl <= tolerance_coord) next
    out[[length(out) + 1]] <- list(
      correct_pt = present[j], reference_pts = setdiff(present, present[j]),
      reference_value = med, old_value = present_vals[j]
    )
  }
  out
}

#' Read a JPEG/PNG specimen photograph for use as a plot background
#'
#' Dispatches to `jpeg::readJPEG()` or `png::readPNG()` based on the file
#' extension, so `plot_landmarks()`/`plot_fishmorph_points()` can overlay
#' digitized landmarks on the original photograph without requiring both
#' optional packages to be installed.
#'
#' @param path Path to a `.jpg`/`.jpeg` or `.png` image file.
#' @return A numeric height x width (x channels) array, as returned by
#'   `jpeg::readJPEG()`/`png::readPNG()`, with row 1 corresponding to the
#'   top of the image (standard raster/image convention).
#' @noRd
.read_background_image <- function(path) {
  if (!is.character(path) || length(path) != 1) {
    stop("`background_image` must be a single file path.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("`background_image` file not found: '", path, "'.", call. = FALSE)
  }
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("jpg", "jpeg")) {
    if (!requireNamespace("jpeg", quietly = TRUE)) {
      stop(
        "Reading a JPEG `background_image` requires the \"jpeg\" package. ",
        "Install it with install.packages(\"jpeg\").",
        call. = FALSE
      )
    }
    jpeg::readJPEG(path)
  } else if (ext == "png") {
    if (!requireNamespace("png", quietly = TRUE)) {
      stop(
        "Reading a PNG `background_image` requires the \"png\" package. ",
        "Install it with install.packages(\"png\").",
        call. = FALSE
      )
    }
    png::readPNG(path)
  } else {
    stop(
      "`background_image` must be a \".jpg\", \".jpeg\", or \".png\" file ",
      "(found: '", path, "').",
      call. = FALSE
    )
  }
}

#' Draw an already-read background photograph into the current plot region
#'
#' Optionally flips `img` vertically to match the bottom-left-origin
#' convention of digitized landmark coordinates (raster images are
#' conventionally stored top-row first), and draws it with
#' [graphics::rasterImage()] spanning `[0, width] x [0, height]` in pixel
#' units. Must be called after a `plot(..., type = "n")` (or equivalent)
#' has already established a plot region; use `.background_image_dims()`
#' beforehand to size that region correctly.
#'
#' @param img A height x width (x channels) array, as returned by
#'   `.read_background_image()`.
#' @param flip_y Logical, flip the image vertically before drawing (see
#'   `flip_y` in [plot_landmarks()]/[plot_fishmorph_points()]).
#' @return Invisibly, `NULL`.
#' @noRd
.draw_background_image <- function(img, flip_y = TRUE) {
  h <- dim(img)[1]
  w <- dim(img)[2]
  if (isTRUE(flip_y)) {
    img <- img[h:1, , , drop = FALSE]
  }
  graphics::rasterImage(img, xleft = 0, ybottom = 0, xright = w, ytop = h)
  invisible(NULL)
}

#' Pixel dimensions of an already-read background image
#'
#' @param img A height x width (x channels) array, as returned by
#'   `.read_background_image()`.
#' @return A length-2 integer vector `c(width, height)` in pixels.
#' @noRd
.background_image_dims <- function(img) {
  c(dim(img)[2], dim(img)[1])
}

#' Resolve `x`/`groups` into PCA scores for a convex-hull functional space
#'
#' Shared preprocessing for [bootstrap_functional_space()] and
#' [species_sensitivity()]: accepts either an `"intrait_traitspace"`
#' object or a raw trait table plus `groups`, applies the same
#' `log_transform`/`scale` preprocessing as [trait_space()] for the raw
#' case, drops rows with a missing/unresolved `groups` value, then runs a
#' fresh Principal Component Analysis and selects `n_axes` dimensions
#' (either the value supplied, or automatically via `var_threshold`). Both
#' functions need exactly the same resolved PCA space to compute
#' consistent convex-hull volumes (a shared centroid-based `fd_ref`, in
#' particular), so this logic is centralised here rather than duplicated.
#'
#' @param x,groups,n_axes,var_threshold,log_transform,scale As in
#'   [bootstrap_functional_space()].
#' @return A list with `scores` (the `n_axes`-column PCA score matrix),
#'   `groups` (factor, `NA`-free, unused levels dropped, aligned to
#'   `scores`), `n_axes` (the actual integer used), and `var_explained`
#'   (cumulative proportion of variance captured by those axes).
#' @noRd
.fspace_pca_scores <- function(x, groups, n_axes, var_threshold, log_transform, scale) {
  if (inherits(x, "intrait_traitspace")) {
    if (is.null(x$X)) {
      stop(
        "`x` was built by an older version of trait_space() that did not ",
        "store the standardised trait matrix; rebuild `x` with the current ",
        "trait_space() first.",
        call. = FALSE
      )
    }
    X <- x$X
    if (is.null(groups)) groups <- x$groups
    if (is.null(groups)) {
      stop(
        "`x` has no `groups`; rebuild it with trait_space(traits, groups = ...) ",
        "or pass `groups` explicitly.",
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
  if (anyNA(groups)) {
    keep_g <- !is.na(groups)
    message(sprintf(
      paste(
        "Removing %d row(s) with a missing/unresolved `groups` value (e.g. an",
        "unidentified specimen) before building the functional space."
      ),
      sum(!keep_g)
    ))
    X <- X[keep_g, , drop = FALSE]
    groups <- droplevels(groups[keep_g])
  }
  if (nlevels(groups) < 3) {
    stop("`groups` must have at least 3 levels (species) to define a convex hull.", call. = FALSE)
  }

  pca <- stats::prcomp(X, center = TRUE, scale. = FALSE)
  var_prop <- pca$sdev^2 / sum(pca$sdev^2)
  cum_var <- cumsum(var_prop)

  if (is.null(n_axes)) {
    n_axes <- which(cum_var >= var_threshold)[1]
    if (is.na(n_axes)) n_axes <- ncol(pca$x)
    n_axes <- max(2L, n_axes)
  } else {
    if (!is.numeric(n_axes) || length(n_axes) != 1 || n_axes < 2) {
      stop("`n_axes` must be a single integer >= 2.", call. = FALSE)
    }
    n_axes <- as.integer(n_axes)
  }
  n_axes <- min(n_axes, ncol(pca$x))

  if (nlevels(groups) <= n_axes) {
    stop(
      sprintf(
        paste(
          "`n_axes` = %d requires more than %d species (points) to define a",
          "non-degenerate convex hull, but `groups` only has %d level(s);",
          "lower `n_axes` (or `var_threshold`)."
        ),
        n_axes, n_axes, nlevels(groups)
      ),
      call. = FALSE
    )
  }

  list(
    scores = pca$x[, seq_len(n_axes), drop = FALSE],
    groups = groups,
    n_axes = n_axes,
    var_explained = unname(cum_var[n_axes])
  )
}

#' Scatterplot of a 2D ordination, by group
#'
#' Shared plotting logic used by plot.intrait_morphospace() and
#' plot.intrait_traitspace() so that both ordination types are displayed
#' consistently: each group is shown as its individual points, plus one
#' of: a "spider" of dashed segments linking each point to its group mean
#' together with a parametric dispersion ellipse (`style = "spider"`, the
#' default); a classical convex hull (`style = "hull"`); a non-parametric
#' kernel-density contour (`style = "density"`), which does not assume
#' bivariate normality and so can better represent skewed or multimodal
#' groups; or plain points with no group decoration (`style = "none"`).
#'
#' @param scores A data.frame/matrix with (at least) two columns of
#'   ordination scores.
#' @param groups A factor of the same length as `nrow(scores)`, or `NULL`.
#' @param xlab,ylab Axis labels.
#' @param style One of `"spider"`, `"hull"`, `"density"`, or `"none"`.
#' @param ellipse_level Coverage probability of the dispersion ellipse
#'   (`style = "spider"` only).
#' @param density_level Coverage probability of the kernel-density contour
#'   (`style = "density"` only); groups with fewer than 5 points are
#'   silently skipped (too few observations for a meaningful 2D density
#'   estimate).
#' @param legend Logical, draw a legend of group colors.
#' @param legend_position One of `"outside"` (default: drawn just outside
#'   the top-right corner of the plot box, in the margin, so it never
#'   overlaps the data, at the cost of a wider right margin) or a standard
#'   [graphics::legend()] keyword (e.g. `"topright"`, `"bottomleft"`) to
#'   draw it inside the plot box instead.
#' @param legend_title Character, the legend's title. Defaults to
#'   `"Group"`; pass `"Species"` (or any other label) when `groups`
#'   represents species identity.
#' @param legend_italic Logical, italicise the legend labels. Intended for
#'   taxonomic names (species/genus), following standard nomenclatural
#'   typographic convention.
#' @param abbreviate_species Logical, abbreviate `"Genus species"` legend
#'   labels to `"G. species"` (see `.abbreviate_species_name()`). Only
#'   affects the legend text, never the underlying `groups` factor used
#'   for colouring/statistics.
#' @param ... Further arguments passed to [graphics::plot()]. If `xlim`/
#'   `ylim` are supplied here, they override the axis limits this function
#'   would otherwise compute (see Details).
#' @return Invisibly returns `NULL`.
#'
#' @details
#' Axis limits are computed from the data points *and* from every
#' additional geometric object the requested `style` will draw (dispersion
#' ellipses, convex hulls, or density contours) before the plot region is
#' established, so that a group's ellipse/hull/contour — which routinely
#' extends beyond that group's own points, by construction — is never
#' silently clipped at the plot box edge. Axis ticks are drawn short and
#' pointing inward (`par(tcl = 0.3)`), a common convention in published
#' ordination figures that keeps the plot box uncluttered.
#' @noRd
.plot_ordination <- function(scores, groups, xlab, ylab, style = "spider",
                              ellipse_level = 0.95, density_level = 0.95,
                              legend = TRUE, legend_position = "outside",
                              legend_title = "Group", legend_italic = FALSE,
                              abbreviate_species = FALSE, ...) {
  x <- scores[, 1]
  y <- scores[, 2]
  dots <- list(...)

  # Short, inward-pointing tick marks for the duration of this plot only.
  old_par <- graphics::par(tcl = 0.3, mgp = c(2.2, 0.5, 0))
  on.exit(graphics::par(old_par), add = TRUE)

  if (is.null(groups)) {
    plot_args <- utils::modifyList(
      list(x = x, y = y, xlab = xlab, ylab = ylab, pch = 19), dots
    )
    do.call(graphics::plot, plot_args)
    graphics::abline(h = 0, v = 0, lty = 3, col = "grey60")
    return(invisible(NULL))
  }

  # Defensive: drop unused factor levels (e.g. left over from an upstream
  # subset) so the palette/legend never reserves a colour and a legend
  # entry for a group with zero points.
  groups <- droplevels(as.factor(groups))
  pal <- .ordination_palette(nlevels(groups))
  cols <- pal[as.integer(groups)]

  # Pre-compute every group's extra geometry (ellipse / hull / density
  # contour) *before* plotting, purely to size the axes correctly; the
  # actual drawing happens in a second pass below, after graphics::plot()
  # has established the (correctly sized) plot region.
  ellipses <- vector("list", nlevels(groups))
  hulls <- vector("list", nlevels(groups))
  contours <- vector("list", nlevels(groups))
  extra_x <- numeric(0)
  extra_y <- numeric(0)

  for (i in seq_len(nlevels(groups))) {
    idx <- which(as.integer(groups) == i)
    if (length(idx) == 0) next
    gx <- x[idx]
    gy <- y[idx]

    if (style == "spider") {
      ell <- .covariance_ellipse(gx, gy, level = ellipse_level)
      if (!is.null(ell)) {
        ellipses[[i]] <- ell
        extra_x <- c(extra_x, ell[, 1])
        extra_y <- c(extra_y, ell[, 2])
      }
    } else if (style == "hull") {
      if (length(idx) >= 3) {
        hpts <- grDevices::chull(gx, gy)
        hulls[[i]] <- list(x = gx[hpts], y = gy[hpts])
        extra_x <- c(extra_x, gx[hpts])
        extra_y <- c(extra_y, gy[hpts])
      }
    } else if (style == "density") {
      ct <- .density_contour(gx, gy, level = density_level)
      if (!is.null(ct)) {
        contours[[i]] <- ct
        for (poly in ct) {
          extra_x <- c(extra_x, poly$x)
          extra_y <- c(extra_y, poly$y)
        }
      }
    }
  }

  xr <- range(c(x, extra_x))
  yr <- range(c(y, extra_y))
  xpad <- diff(xr) * 0.06
  ypad <- diff(yr) * 0.06
  if (!is.finite(xpad) || xpad == 0) xpad <- 1
  if (!is.finite(ypad) || ypad == 0) ypad <- 1
  auto_xlim <- xr + c(-xpad, xpad)
  auto_ylim <- yr + c(-ypad, ypad)

  draw_legend <- isTRUE(legend) && nlevels(groups) > 0
  if (draw_legend && identical(legend_position, "outside")) {
    # Reserve extra room in the right margin *before* plotting, so the
    # legend can sit just outside the plot box instead of overlapping the
    # data (a common source of unreadable ordination plots when groups
    # happen to cluster near a corner, e.g. "topright"). Captured and
    # restored separately from `old_par` above (a distinct par() call),
    # so the caller's margin setting is never left permanently altered.
    old_mar <- graphics::par(mar = graphics::par("mar") + c(0, 0, 0, 9))
    on.exit(graphics::par(old_mar), add = TRUE)
  }

  plot_args <- utils::modifyList(
    list(x = x, y = y, xlab = xlab, ylab = ylab, pch = 19, col = cols,
         xlim = auto_xlim, ylim = auto_ylim),
    dots
  )
  do.call(graphics::plot, plot_args)
  graphics::abline(h = 0, v = 0, lty = 3, col = "grey60")

  if (style == "spider") {
    for (i in seq_len(nlevels(groups))) {
      idx <- which(as.integer(groups) == i)
      if (length(idx) == 0) next
      gx <- x[idx]
      gy <- y[idx]
      centre <- c(mean(gx), mean(gy))

      graphics::segments(centre[1], centre[2], gx, gy, col = pal[i], lty = 2, lwd = 0.8)
      if (!is.null(ellipses[[i]])) graphics::lines(ellipses[[i]], col = pal[i], lwd = 1.5)
      graphics::points(centre[1], centre[2], pch = 8, cex = 1.5, col = pal[i], lwd = 2)
    }
  } else if (style == "hull") {
    for (i in seq_len(nlevels(groups))) {
      if (!is.null(hulls[[i]])) {
        graphics::polygon(hulls[[i]]$x, hulls[[i]]$y, border = pal[i],
                           col = grDevices::adjustcolor(pal[i], alpha.f = 0.15))
      }
    }
  } else if (style == "density") {
    for (i in seq_len(nlevels(groups))) {
      idx <- which(as.integer(groups) == i)
      if (length(idx) == 0) next
      gx <- x[idx]
      gy <- y[idx]
      graphics::points(mean(gx), mean(gy), pch = 8, cex = 1.5, col = pal[i], lwd = 2)
      if (!is.null(contours[[i]])) {
        for (poly in contours[[i]]) graphics::lines(poly$x, poly$y, col = pal[i], lwd = 1.5)
      }
    }
  }

  if (draw_legend) {
    labels <- levels(groups)
    if (isTRUE(abbreviate_species)) labels <- .abbreviate_species_name(labels)
    legend_text <- if (isTRUE(legend_italic)) {
      as.expression(lapply(labels, function(l) bquote(italic(.(l)))))
    } else {
      labels
    }

    if (identical(legend_position, "outside")) {
      graphics::legend(
        x = graphics::par("usr")[2], y = graphics::par("usr")[4], xpd = TRUE,
        legend = legend_text, col = pal, pch = 19, bty = "n", cex = 0.8,
        xjust = 0, yjust = 1, title = legend_title
      )
    } else {
      graphics::legend(legend_position, legend = legend_text, col = pal, pch = 19,
                        bty = "n", cex = 0.8, title = legend_title)
    }
  }
  invisible(NULL)
}
