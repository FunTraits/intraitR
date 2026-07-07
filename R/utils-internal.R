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

#' Canonicalise a species label for cross-source matching
#'
#' Phylogenetic tip labels, this package's own `species` columns, and
#' user-supplied composition/tree data all use different, otherwise
#' equivalent, word-separator conventions for the same binomial name --
#' e.g. `"Barbus barbus"` (this package's own convention), `"Barbus_barbus"`
#' (a common tip-label convention), and `"Barbus.barbus"` (the convention
#' used by the bundled [load_fishmorph_phylogeny()] tree). This collapses
#' any run of spaces, underscores, and/or dots to a single underscore and
#' trims leading/trailing whitespace, so labels from any of these sources
#' can be compared for equality regardless of which separator each side
#' happens to use.
#'
#' @param x Character vector of species labels.
#' @return Character vector, same length as `x`.
#' @noRd
.canon_species_name <- function(x) {
  gsub("[ ._]+", "_", trimws(as.character(x)))
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
#' @details
#' The sequence returned is a *prefix* of a single, fixed underlying
#' palette: colour 1 is always the same hex code regardless of `n`, colour
#' 2 is always the same, and so on, up to 40 groups (beyond the curated
#' 10-colour set, a single fixed-size `grDevices::hcl.colors(40, ...)`
#' vector is sliced rather than one sized to `n`, which would otherwise
#' respace hues and change already-issued colours as `n` grows). This
#' prefix-stability is what lets `.stable_group_colors()` hand out colours
#' one group at a time, as new groups are first seen, without ever having
#' to reassign a colour already given to an earlier group.
#' @noRd
.ordination_palette <- function(n) {
  base_pal <- c(
    "#4E79A7", "#F28E2B", "#59A14F", "#E15759", "#B07AA1",
    "#76B7B2", "#EDC948", "#FF9DA7", "#9C755F", "#BAB0AC"
  )
  if (n <= length(base_pal)) return(base_pal[seq_len(n)])
  extra_n <- n - length(base_pal)
  extra_pal <- grDevices::hcl.colors(max(extra_n, 40L), palette = "Dark 3")
  c(base_pal, extra_pal[seq_len(extra_n)])
}

#' Session-level cache backing `.stable_group_colors()`
#' @noRd
.intrait_color_cache <- new.env(parent = emptyenv())

#' Stable, session-persistent colours for group/species labels
#'
#' Assigns each distinct label in `labels` a colour from
#' `.ordination_palette()`, in the order labels are first encountered, and
#' remembers that assignment in a package-level cache for the rest of the
#' R session: the same label (e.g. the same species name) always gets the
#' same colour, in every subsequent call, even when it is plotted from a
#' different object whose own row-filtering (missing traits, outlier
#' removal, etc.) happens to retain a different subset of species than the
#' object plotted before it. This is what keeps a species' colour
#' consistent between, say, [plot.intrait_morphospace()] and
#' [plot.intrait_traitspace()] built from the same underlying dataset.
#' Already-cached labels never change colour as new, previously-unseen
#' labels are added; only the newly seen ones are appended using
#' `.ordination_palette()`'s next unused slot(s) (relying on that
#' function's prefix-stability). Call `reset_group_colors()` to clear the
#' cache, e.g. before starting on an unrelated dataset, or at the top of a
#' script that must be reproducible regardless of what ran earlier in the
#' session.
#'
#' @param labels Character vector or factor of group labels, one per
#'   observation (duplicates expected). A label equal to `""` (e.g. an
#'   unresolved/blank identification stored as an empty string rather
#'   than `NA`) is treated like any other label, not as missing.
#' @return A named character vector of hex colours, one per element of
#'   `unique(labels)` (in that order), named by the label itself.
#' @noRd
.stable_group_colors <- function(labels) {
  labels <- as.character(labels)
  uniq <- unique(labels)
  # The cache is a single named character vector (colour, named by label),
  # stored as one object in .intrait_color_cache -- not one environment
  # variable per label via assign()/get() -- specifically because a named
  # vector has no trouble with a `""` name, whereas assign()/get() on an
  # environment error on a zero-length variable name (a real hazard here:
  # e.g. an unresolved species identification stored as "" rather than
  # `NA` in the source data would previously crash plotting entirely).
  cache <- if (exists("map", envir = .intrait_color_cache, inherits = FALSE)) {
    get("map", envir = .intrait_color_cache, inherits = FALSE)
  } else {
    character(0)
  }
  new_labels <- setdiff(uniq, names(cache))
  if (length(new_labels) > 0) {
    pal <- .ordination_palette(length(cache) + length(new_labels))
    new_cols <- pal[seq(length(cache) + 1, length(cache) + length(new_labels))]
    names(new_cols) <- new_labels
    cache <- c(cache, new_cols)
    assign("map", cache, envir = .intrait_color_cache)
  }
  # Deliberately not `cache[uniq]`: R's `[` never matches a `""` character
  # index to a `""` name (documented in `?Extract`: "Neither empty ("") nor
  # NA indices match any names, not even empty nor missing names"), so a
  # label stored as "" would always come back as NA here even though it is
  # genuinely present in `cache`. `match()` performs ordinary value
  # equality instead, so it has no such exception.
  stats::setNames(unname(cache[match(uniq, names(cache))]), uniq)
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

#' Total branch length of a UPGMA functional dendrogram (Petchey & Gaston 2002)
#'
#' Builds a dendrogram from the Euclidean distances among a set of points
#' (species centroids or one-individual-per-species draws, in a PCA-based
#' trait space) via [stats::hclust()], and returns the sum of all its
#' branch lengths -- the FD index of Petchey & Gaston (2002), a
#' distance-based, non-volumetric alternative to convex-hull functional
#' richness that needs no additional Suggested package (unlike
#' `method = "tpd"`/`"hypervolume"` in [bootstrap_functional_space()]) and
#' places no restriction on the number of points relative to dimensionality.
#'
#' @param pts A numeric matrix, one row per point, `k` columns (dimensions).
#' @param linkage Clustering method passed to `stats::hclust(method =)`.
#'   Defaults to `"average"` (UPGMA), the linkage used by Petchey & Gaston
#'   (2002) and by `FD::dbFD()`.
#' @return A single numeric total branch length, or `NA_real_` if `pts` has
#'   fewer than 2 rows (no dendrogram can be built).
#' @noRd
.dendrogram_richness <- function(pts, linkage = "average") {
  pts <- as.matrix(pts)
  n <- nrow(pts)
  if (n < 2) return(NA_real_)
  hc <- stats::hclust(stats::dist(pts), method = linkage)
  # hc$merge[i, ]: the two children merged at step i (negative = original
  # leaf, born at height 0; positive j = the internal node created at the
  # earlier step j, born at hc$height[j]). Total branch length is the sum,
  # over every merge, of (that merge's height - each child's own birth
  # height) -- equivalent to summing edge lengths of the corresponding
  # phylogenetic tree (as ape::as.phylo() + sum(edge.length) would give),
  # without requiring the `ape` package.
  total <- 0
  for (i in seq_len(nrow(hc$merge))) {
    parent_height <- hc$height[i]
    for (child in hc$merge[i, ]) {
      child_height <- if (child < 0) 0 else hc$height[child]
      total <- total + (parent_height - child_height)
    }
  }
  total
}

#' Community functional richness via Trait Probability Density (TPD)
#'
#' Thin wrapper around [TPD::TPDsMean()]/[TPD::TPDc()]/[TPD::REND()] (Carmona
#' et al. 2019) used by [bootstrap_functional_space()] (`method = "tpd"`).
#' Each species is represented by a fixed-bandwidth Gaussian kernel centred
#' on its point (there is no within-species variance to estimate from a
#' single bootstrap-drawn individual, see Details there); functional
#' richness is `REND()`'s `FRichness` for the resulting one-community TPDc.
#'
#' @param pts A numeric matrix, one row per species, `k` columns; row names
#'   are used as species identifiers.
#' @param aux A list with elements `bw` (length-`k` fixed kernel SD per
#'   axis), `trait_ranges` (fixed grid limits, a length-`k` list of `c(min,
#'   max)`), `alpha`, `n_divisions` -- see `.fspace_richness_setup()`, which
#'   builds these once (shared across every call) so that richness values
#'   from different point sets remain comparable.
#' @return A single numeric functional richness (proportion of the shared
#'   evaluation grid occupied), or `NA_real_` if the TPD computation fails.
#' @noRd
.tpd_richness <- function(pts, aux) {
  pts <- as.matrix(pts)
  sp_names <- rownames(pts)
  if (is.null(sp_names)) sp_names <- paste0("sp", seq_len(nrow(pts)))
  sds <- matrix(aux$bw, nrow = nrow(pts), ncol = ncol(pts), byrow = TRUE)

  tpds <- tryCatch(
    TPD::TPDsMean(
      species = sp_names, means = pts, sds = sds, alpha = aux$alpha,
      trait_ranges = aux$trait_ranges, n_divisions = aux$n_divisions
    ),
    error = function(e) NULL
  )
  if (is.null(tpds)) return(NA_real_)

  samp_unit <- matrix(
    1, nrow = 1, ncol = length(sp_names),
    dimnames = list("community", sp_names)
  )
  tpdc <- tryCatch(TPD::TPDc(TPDs = tpds, sampUnit = samp_unit), error = function(e) NULL)
  if (is.null(tpdc)) return(NA_real_)

  rend <- tryCatch(TPD::REND(TPDc = tpdc), error = function(e) NULL)
  if (is.null(rend)) return(NA_real_)
  unname(rend$communities$FRichness[1])
}

#' Community functional richness via Gaussian-kernel hypervolume
#'
#' Thin wrapper around [hypervolume::hypervolume_gaussian()]/
#' [hypervolume::get_volume()] (Blonder et al. 2014, 2018) used by
#' [bootstrap_functional_space()] (`method = "hypervolume"`).
#'
#' @param pts A numeric matrix, one row per species, `k` columns.
#' @param aux A list with elements `bw` (fixed kernel bandwidth vector,
#'   shared across every call, see `.fspace_richness_setup()`) and
#'   `samples_per_point`.
#' @return A single numeric hypervolume, or `NA_real_` if the computation
#'   fails.
#' @noRd
.hypervolume_richness <- function(pts, aux) {
  pts <- as.matrix(pts)
  hv <- tryCatch(
    hypervolume::hypervolume_gaussian(
      pts, kde.bandwidth = aux$bw, samples.per.point = aux$samples_per_point,
      verbose = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(hv)) return(NA_real_)
  hypervolume::get_volume(hv)
}

#' Precompute method-specific, shared auxiliary parameters for functional
#' richness estimation
#'
#' Some `method`s of [bootstrap_functional_space()] need an auxiliary
#' quantity (a kernel bandwidth, an evaluation grid) that must be computed
#' **once**, from the full individual-level PCA scores, and then reused
#' identically for the centroid-based reference and every bootstrap draw:
#' if it were instead re-estimated separately from each draw's own (small,
#' single-individual-per-species) point set, differences in the resulting
#' richness would partly reflect differences in the estimated bandwidth/
#' grid rather than genuine differences in point configuration, making
#' `fd_ref` and `fd_boot` incomparable. `method = "convexhull"` and
#' `"dendrogram"` need no such shared setup (a convex hull and a UPGMA
#' dendrogram are both computed directly and consistently from whatever
#' points are given).
#'
#' @param scores The full individual-level PCA score matrix (all
#'   individuals, before any per-draw subsampling).
#' @param method One of `"convexhull"`, `"dendrogram"`, `"tpd"`,
#'   `"hypervolume"`.
#' @param dendrogram_linkage,tpd_alpha,tpd_bw_factor,tpd_n_divisions,hv_bw_method,hv_samples_per_point
#'   Method-specific tuning parameters, passed through from
#'   [bootstrap_functional_space()] -- see its documentation.
#' @return A list of auxiliary values used by `.fspace_richness()`.
#' @noRd
.fspace_richness_setup <- function(scores, method,
                                    dendrogram_linkage = "average",
                                    tpd_alpha = 0.95, tpd_bw_factor = 0.5,
                                    tpd_n_divisions = NULL,
                                    hv_bw_method = "silverman",
                                    hv_samples_per_point = 500) {
  if (identical(method, "dendrogram")) {
    return(list(linkage = dendrogram_linkage))
  }
  if (identical(method, "tpd")) {
    # Fixed per-axis kernel SD, a fraction of each PCA axis's overall
    # (between-species) standard deviation -- a deliberate plug-in choice,
    # since a single bootstrap-drawn individual carries no within-species
    # variance of its own to estimate a kernel from. Grid limits
    # (`trait_ranges`) are likewise fixed once, from the full data range
    # expanded by 5 kernel SDs in each direction (TPDsMean()'s own default
    # margin), so every TPDsMean() call in this procedure -- fd_ref and
    # every fd_boot draw -- is evaluated on the identical grid.
    bw <- apply(scores, 2, stats::sd) * tpd_bw_factor
    rng <- apply(scores, 2, range)
    trait_ranges <- lapply(seq_len(ncol(scores)), function(j) {
      c(rng[1, j] - 5 * bw[j], rng[2, j] + 5 * bw[j])
    })
    return(list(
      bw = bw, alpha = tpd_alpha, trait_ranges = trait_ranges,
      n_divisions = tpd_n_divisions
    ))
  }
  if (identical(method, "hypervolume")) {
    bw <- hypervolume::estimate_bandwidth(scores, method = hv_bw_method)
    return(list(bw = bw, samples_per_point = hv_samples_per_point))
  }
  list()
}

#' Dispatch a single functional-richness computation to the chosen `method`
#'
#' @param pts A numeric matrix, one row per point (species).
#' @param method One of `"convexhull"`, `"dendrogram"`, `"tpd"`,
#'   `"hypervolume"`.
#' @param aux The auxiliary list from `.fspace_richness_setup()`.
#' @return A single numeric richness value, or `NA_real_` on a degenerate/
#'   failed computation.
#' @noRd
.fspace_richness <- function(pts, method, aux) {
  switch(method,
    convexhull = .convex_hull_volume(pts),
    dendrogram = .dendrogram_richness(pts, linkage = aux$linkage),
    tpd = .tpd_richness(pts, aux),
    hypervolume = .hypervolume_richness(pts, aux),
    stop("Unknown `method`.", call. = FALSE)
  )
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

#' Flag Procrustes-distance outliers in a GPA-aligned coordinate sample
#'
#' Shared implementation of the median + threshold*MAD screening rule used
#' by both [detect_outliers()] and [gpa_fish()]'s `flag_outliers`/
#' `remove_outliers` arguments, so the two stay in sync rather than
#' maintaining two copies of the same computation.
#'
#' @param coords A `p x k x n` array of Procrustes-aligned shape
#'   coordinates (e.g. `gpa$coords`).
#' @param consensus A `p x k` matrix, the consensus shape (e.g.
#'   `gpa$consensus`).
#' @param threshold Numeric, number of MADs above the median Procrustes
#'   distance beyond which a specimen is flagged.
#' @return A `data.frame`, one row per specimen (in `dimnames(coords)[[3]]`
#'   order), with columns `specimen`, `procrustes_distance`,
#'   `threshold_value`, `flagged`.
#' @noRd
.procrustes_outlier_screen <- function(coords, consensus, threshold = 3) {
  n <- dim(coords)[3]
  specimen_names <- dimnames(coords)[[3]]
  if (is.null(specimen_names)) specimen_names <- paste0("specimen_", seq_len(n))

  pd <- vapply(seq_len(n), function(i) {
    sqrt(sum((coords[, , i] - consensus)^2))
  }, numeric(1))

  med <- stats::median(pd)
  mad_val <- stats::mad(pd)
  if (isTRUE(mad_val == 0)) {
    threshold_value <- med
    warning(
      "Procrustes distances have zero median absolute deviation (little or ",
      "no variation among specimens); no specimen can be reliably flagged.",
      call. = FALSE
    )
  } else {
    threshold_value <- med + threshold * mad_val
  }

  data.frame(
    specimen = specimen_names,
    procrustes_distance = as.numeric(pd),
    threshold_value = threshold_value,
    flagged = pd > threshold_value,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Short code -> full descriptive name lookup for the nine FISHMORPH ratios
#'
#' Used by `plot.intrait_itv()` to expand trait codes (`"RMl"`, etc.) to a
#' readable label (`"Relative maxillary length (RMl)"`) when the traits
#' passed to [itv_index()] happen to be FISHMORPH ratios; wording matches
#' [fishmorph_ratios()]'s own `@details` (Brosse et al. 2021, fig. 1b).
#' Any trait code not in this table (i.e. any non-FISHMORPH trait table)
#' is simply left as-is by the caller.
#' @noRd
.fishmorph_ratio_labels <- c(
  BEl = "Body elongation",
  VEp = "Vertical eye position",
  REs = "Relative eye size",
  OGp = "Oral gape position",
  RMl = "Relative maxillary length",
  BLs = "Body lateral shape",
  PFv = "Pectoral fin vertical position",
  PFs = "Pectoral fin size",
  CPt = "Caudal peduncle throttling"
)

#' Handle missing values in a numeric matrix of traits/measurements
#'
#' Shared implementation of the `na_action` convention introduced by
#' [trait_space()] (`"fail"`/`"keep"`, `"omit"`, `"impute_mean"`,
#' `"impute_group_mean"`, `"missforest"`, `"missforest_phylo"`), reused by
#' [fishmorph_segments()] and [fishmorph_ratios()] so the same options
#' behave identically (same messages, same imputation logic) wherever
#' missing values need handling in this package. [trait_space()] and
#' [impute_landmarks()] implement the same options inline (they operate on
#' a different shape of input -- a full ordination input / raw landmark
#' coordinates, respectively -- rather than a plain specimen x trait
#' matrix), calling the shared [.phylo_axes_for_groups()] helper for the
#' phylogenetic-augmentation step specifically, so that step at least is
#' not duplicated three times over.
#'
#' @param X A numeric matrix, one row per specimen/observation.
#' @param groups Optional factor, one value per row of `X`; required for
#'   `na_action = "impute_group_mean"`, optionally used as an auxiliary
#'   predictor for `na_action = "missforest"`/`"missforest_phylo"`.
#' @param na_action Character: `"keep"`/`"fail"` do nothing except, for
#'   `"fail"`, stop with an error if `X` has any `NA`; `"omit"` reports and
#'   drops incomplete rows; `"impute_mean"`/`"impute_group_mean"` replace
#'   `NA` with the column/within-group mean; `"missforest"` uses
#'   `missForest::missForest()`; `"missforest_phylo"` does the same but
#'   additionally augments the predictor matrix with phylogenetic PCoA axes
#'   (see [phylo_pcoa()]) for the species in `groups`, falling back to
#'   plain `"missforest"` (with a warning) if phylogenetic axes cannot be
#'   used (no `groups`, too few species matched to `tree`, etc.).
#' @param missforest_ntree,missforest_maxiter Passed to
#'   `missForest::missForest()`.
#' @param context Character, used only to word messages/errors (e.g.
#'   `"traits"`, `"segments"`, `"ratios"`).
#' @param tree Used only by `na_action = "missforest_phylo"`: an object of
#'   class `"phylo"`, or `NULL` (default) to use the bundled
#'   [load_fishmorph_phylogeny()] tree; see [.phylo_axes_for_groups()].
#' @param missforest_phylo_k Used only by `na_action = "missforest_phylo"`:
#'   maximum number of phylogenetic PCoA axes to add as predictors.
#' @return A list with `X` (the possibly modified/row-reduced matrix) and
#'   `keep` (logical vector, length `nrow(X)` as passed in, `TRUE` for rows
#'   retained -- all `TRUE` unless `na_action = "omit"` dropped some).
#' @noRd
.apply_na_action <- function(X, groups, na_action, missforest_ntree = 100,
                              missforest_maxiter = 10, context = "traits",
                              tree = NULL, missforest_phylo_k = 10) {
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
      "\"impute_mean\", \"impute_group_mean\", \"missforest\", or ",
      "\"missforest_phylo\" to handle them (see the function's documentation).",
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
  } else if (na_action %in% c("missforest", "missforest_phylo")) {
    if (!requireNamespace("missForest", quietly = TRUE)) {
      stop(
        "na_action = \"", na_action, "\" requires the \"missForest\" package. ",
        "Install it with install.packages(\"missForest\").",
        call. = FALSE
      )
    }
    n_na <- sum(is.na(X))
    df_for_rf <- as.data.frame(X)
    if (!is.null(groups)) df_for_rf$.group <- groups

    phylo_note <- ""
    if (na_action == "missforest_phylo") {
      pax <- .phylo_axes_for_groups(groups, tree = tree, k_phylo = missforest_phylo_k)
      if (is.null(pax$axes)) {
        warning(
          "na_action = \"missforest_phylo\": phylogenetic axes could not be used (",
          pax$reason, "); falling back to plain \"missforest\" (no phylogenetic predictors).",
          call. = FALSE
        )
      } else {
        df_for_rf <- cbind(df_for_rf, pax$axes)
        phylo_note <- sprintf(
          ", augmented with %d phylogenetic PCoA axis/axes (%d species matched to the tree)",
          pax$k_used, pax$n_matched
        )
      }
    }

    imp <- missForest::missForest(
      df_for_rf, ntree = missforest_ntree, maxiter = missforest_maxiter,
      verbose = FALSE
    )
    ximp <- imp$ximp
    X <- as.matrix(ximp[, colnames(X), drop = FALSE])
    storage.mode(X) <- "double"
    nrmse <- if ("NRMSE" %in% names(imp$OOBerror)) imp$OOBerror[["NRMSE"]] else NA_real_
    message(sprintf(
      "na_action = \"%s\": imputed %d missing value(s) using random-forest imputation (missForest)%s%s%s.",
      na_action, n_na,
      if (!is.null(groups)) ", using `groups` as an auxiliary predictor" else "",
      phylo_note,
      if (!is.na(nrmse)) sprintf(" (out-of-bag NRMSE = %.3f)", nrmse) else ""
    ))
  }

  list(X = X, keep = keep)
}

#' Species-level phylogenetic PCoA axes, broadcast to match `groups`
#'
#' Used internally by every `na_action`/`method = "missforest_phylo"`
#' option ([trait_space()], [fishmorph_segments()]/[fishmorph_ratios()] via
#' [.apply_na_action()], [impute_landmarks()]) to compute phylogenetic
#' PCoA axes (see [phylo_pcoa()]) for the species actually present in
#' `groups`, and broadcast them out to one row per element of `groups` so
#' they can be column-bound onto a missForest predictor matrix. Never
#' errors: any failure (no `groups`, no usable `tree`, too few matched
#' species, "ape"/"missForest" missing, ...) is reported back as `$reason`
#' instead, so callers can fall back to plain `"missforest"` with an
#' informative message rather than aborting the whole imputation --
#' phylogenetic augmentation is an opportunistic improvement, not a
#' requirement.
#'
#' @param groups Factor or character vector, one value per row to augment
#'   (e.g. specimens); `NA` entries, and entries whose species has no match
#'   in `tree$tip.label`, get `NA` phylogenetic axes (missForest imputes
#'   these internally along with everything else, so this is not an
#'   error -- it just means those specimens get no phylogenetic benefit).
#' @param tree `NULL` (default: try [load_fishmorph_phylogeny()]) or an
#'   object of class `"phylo"`.
#' @param k_phylo Integer, maximum number of phylogenetic axes to use.
#' @return A list with `axes` (a `data.frame` with `length(groups)` rows
#'   and up to `k_phylo` columns `phylo_1, phylo_2, ...`, or `NULL` on
#'   failure), `reason` (`NULL` on success, else a one-line character
#'   explanation of why phylogenetic augmentation was skipped), `n_matched`
#'   (number of distinct species successfully matched to the tree), and
#'   `k_used` (number of phylogenetic axes actually included).
#' @noRd
.phylo_axes_for_groups <- function(groups, tree = NULL, k_phylo = 10) {
  if (is.null(groups)) {
    return(list(axes = NULL, reason = "no `groups` supplied", n_matched = 0L, k_used = 0L))
  }
  if (is.null(tree)) {
    tree <- tryCatch(load_fishmorph_phylogeny(), error = function(e) e)
    if (inherits(tree, "error")) {
      return(list(
        axes = NULL,
        reason = paste0(
          "no `tree` supplied and the bundled phylogeny could not be loaded: ",
          conditionMessage(tree)
        ),
        n_matched = 0L, k_used = 0L
      ))
    }
  }

  sp_pool <- unique(as.character(groups)[!is.na(groups)])
  pp <- tryCatch(
    phylo_pcoa(tree, species = sp_pool, k = NULL, ultrametric = FALSE),
    error = function(e) e
  )
  if (inherits(pp, "error")) {
    return(list(axes = NULL, reason = conditionMessage(pp), n_matched = 0L, k_used = 0L))
  }

  k_use <- min(k_phylo, pp$k)
  ax <- pp$traits[, c("species", paste0("PCoA", seq_len(k_use))), drop = FALSE]
  names(ax) <- c("species", paste0("phylo_", seq_len(k_use)))

  canon_groups <- .canon_species_name(as.character(groups))
  canon_ax_sp <- .canon_species_name(ax$species)
  m <- match(canon_groups, canon_ax_sp)
  out <- ax[m, paste0("phylo_", seq_len(k_use)), drop = FALSE]
  rownames(out) <- NULL

  list(axes = out, reason = NULL, n_matched = nrow(ax), k_used = k_use)
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

#' Compute the 11 FISHMORPH linear measurements directly in pixel
#' (digitization) units, with no scale-bar conversion
#'
#' Shared geometry engine behind [fishmorph_segments()] (which multiplies
#' this by a per-specimen `scale_cm / scale_px` factor to obtain real-world
#' centimetres) and [fishmorph_ratios()]'s `landmarks`-based rescue of
#' specimens whose scale bar (points 20-21) is missing or invalid: since
#' every one of the nine FISHMORPH ratios divides two measurements from the
#' very same specimen, an unknown/missing scale factor cancels out
#' algebraically, so the *ratios* can be recovered directly from these raw
#' pixel distances even when no calibrated (cm) segment values exist.
#'
#' @param A A `p x 2 x n` landmark coordinate array (`p >= 21`), with
#'   `dimnames(A)[[3]]` giving specimen identifiers.
#' @return A `data.frame`, row-named by specimen, with columns `Bl`, `Bd`,
#'   `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`, `CFd`, all in raw
#'   pixel (digitization) units -- *not* centimetres.
#' @noRd
.fishmorph_pixel_segments <- function(A) {
  n <- dim(A)[3]
  p <- dim(A)[1]
  has_curvature_point <- p >= 22

  dist_lm <- function(a, b) {
    diff_mat <- A[a, , ] - A[b, , ]
    if (is.null(dim(diff_mat))) diff_mat <- matrix(diff_mat, ncol = n)
    sqrt(colSums(diff_mat^2))
  }

  segments_def <- list(
    Bd  = c(3, 4),
    Hd  = c(5, 6),
    Eh  = c(7, 8),
    Mo  = c(1, 9),
    PFi = c(10, 11),
    PFl = c(10, 12),
    Ed  = c(13, 14),
    Jl  = c(1, 15),
    CPd = c(16, 17),
    CFd = c(18, 19)
  )

  if (has_curvature_point) {
    pt22 <- A[22, , ]
    if (is.null(dim(pt22))) pt22 <- matrix(pt22, ncol = n)
    used_curvature <- colSums(abs(pt22), na.rm = TRUE) > 0 & !apply(pt22, 2, function(x) any(is.na(x)))
    bl_straight <- dist_lm(1, 2)
    bl_curved <- dist_lm(1, 22) + dist_lm(22, 2)
    Bl <- ifelse(used_curvature, bl_curved, bl_straight)
  } else {
    Bl <- dist_lm(1, 2)
  }

  out <- list(Bl = Bl)
  for (nm in names(segments_def)) {
    pr <- segments_def[[nm]]
    out[[nm]] <- dist_lm(pr[1], pr[2])
  }
  out <- as.data.frame(out)
  rownames(out) <- dimnames(A)[[3]]
  out
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

#' Draw text with a white halo behind it, for readability over busy plots
#'
#' Draws `labels` several times, offset by a small amount in every
#' direction, in `halo_col` (default white), then once more in `text_col`
#' on top -- the standard "shadow/halo text" trick (cf.
#' `TeachingDemos::shadowtext()`, `plotrix::text()`) reimplemented here
#' directly to avoid an extra dependency for a handful of lines. Used by
#' `plot_fishmorph_points()` to keep landmark index numbers legible where
#' they would otherwise cross a coloured measurement segment or sit close
#' to another landmark.
#'
#' @param x,y Numeric coordinates, as in [graphics::text()].
#' @param labels As in [graphics::text()].
#' @param cex,font,pos,offset As in [graphics::text()].
#' @param text_col Colour of the main text (drawn last, on top).
#' @param halo_col Colour of the halo (drawn first, as a ring of offset
#'   copies of `labels` around each label position).
#' @param n_halo Number of offset copies making up the halo ring (more
#'   copies give a smoother, more opaque halo at a small performance
#'   cost; 8 is visually indistinguishable from more, for text this
#'   small).
#' @param r Halo radius, in inches (device-resolution-independent, via
#'   [graphics::xinch()]/[graphics::yinch()], so it looks the same on
#'   screen and in a saved PDF/PNG regardless of plot size).
#' @return Invisibly, `NULL`.
#' @noRd
.halo_text <- function(x, y, labels, cex = 1, font = 2, pos = NULL, offset = 0.5,
                        text_col = "black", halo_col = "white", n_halo = 8, r = 0.02) {
  theta <- seq(0, 2 * pi, length.out = n_halo + 1)[-(n_halo + 1)]
  dx <- graphics::xinch(r) * cos(theta)
  dy <- graphics::yinch(r) * sin(theta)
  for (i in seq_along(theta)) {
    graphics::text(x + dx[i], y + dy[i], labels = labels, cex = cex, font = font,
                   col = halo_col, pos = pos, offset = offset)
  }
  graphics::text(x, y, labels = labels, cex = cex, font = font, col = text_col,
                 pos = pos, offset = offset)
  invisible(NULL)
}

#' Draw short tick marks, at quarter increments, with horizontal labels on
#' both axes
#'
#' Replaces the axis ticks/labels of a plot created with `xaxt = "n", yaxt
#' = "n"`: short tick marks (`tick_length`) at `n` evenly spaced positions
#' spanning `xlim`/`ylim` (by default 0, 0.25, 0.5, 0.75, 1 for the
#' package's default `[0, 1]` axes), with standard, always-horizontal
#' numeric labels on both axes (`las = 1`; the y-axis labels are not
#' rotated, so they stay easy to read at a glance) -- more compact and
#' less visually busy than R's own default axis style, used for the
#' small, densely annotated landmark diagrams drawn by
#' `plot_fishmorph_points()`.
#'
#' @param xlim,ylim The axis limits actually used by the current plot
#'   (i.e. whatever was passed to `graphics::plot()`), so tick positions
#'   are spaced evenly across the true plotted range rather than a
#'   hard-coded `[0, 1]` -- correct both for the package's own `[0, 1]`
#'   default and for a `background_image`'s pixel-dimension `xlim`/`ylim`.
#' @param cex_axis Character expansion for the tick labels.
#' @param tick_length Tick mark length, in `par("tcl")`-style fractions of
#'   a line height (negative values point outward, the base R default
#'   convention; a small magnitude, e.g. the default here, gives short
#'   ticks).
#' @param n Number of tick positions (evenly spaced, including both
#'   endpoints); the default of 5 gives quarter increments across
#'   `xlim`/`ylim`. Ignored if `pretty_ticks = TRUE`.
#' @param pretty_ticks Logical. `FALSE` (default) places `n` ticks evenly
#'   across the exact `xlim`/`ylim` -- correct for the package's `[0, 1]`
#'   digitization convention, whose quarter increments (0, 0.25, 0.5,
#'   0.75, 1) are already round numbers by construction. Set to `TRUE`
#'   for a data-driven range that generally is *not* already round (e.g.
#'   `plot_fishmorph_shapes()`'s centred, size-standardised coordinates),
#'   which instead places ticks via [grDevices::axisTicks()] -- the same
#'   underlying "round numbers" computation R's own default axes use
#'   (`graphics::axis()` when its `at` argument is left unspecified) --
#'   so labels read like `0.25`/`0.5` rather than arbitrary many-digit
#'   fractions of whatever range the data happened
#'   to span.
#' @return Invisibly, `NULL`.
#' @noRd
.draw_coord_axes <- function(xlim, ylim, cex_axis = 0.75, tick_length = -0.25, n = 5,
                              pretty_ticks = FALSE) {
  if (isTRUE(pretty_ticks)) {
    at_x <- grDevices::axisTicks(xlim, log = FALSE, nint = n - 1)
    at_y <- grDevices::axisTicks(ylim, log = FALSE, nint = n - 1)
  } else {
    at_x <- seq(xlim[1], xlim[2], length.out = n)
    at_y <- seq(ylim[1], ylim[2], length.out = n)
  }
  graphics::axis(1, at = at_x, cex.axis = cex_axis, tcl = tick_length, mgp = c(3, 0.4, 0), las = 1)
  graphics::axis(2, at = at_y, cex.axis = cex_axis, tcl = tick_length, mgp = c(3, 0.5, 0), las = 1)
  invisible(NULL)
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
#' @param method One of `"convexhull"`, `"dendrogram"`, `"tpd"`,
#'   `"hypervolume"` (see [bootstrap_functional_space()]), or any other
#'   caller-specific label. Only `"convexhull"` (the default, for backward
#'   compatibility with callers that do not pass `method`, e.g.
#'   [species_sensitivity()]) strictly requires `nlevels(groups) > n_axes`
#'   (a non-degenerate n-dimensional convex hull needs at least `n_axes +
#'   1` affinely independent points); the other methods do not need this
#'   and only get a (non-fatal) warning instead.
#' @return A list with `scores` (the `n_axes`-column PCA score matrix),
#'   `groups` (factor, `NA`-free, unused levels dropped, aligned to
#'   `scores`), `n_axes` (the actual integer used), and `var_explained`
#'   (cumulative proportion of variance captured by those axes).
#' @noRd
.fspace_pca_scores <- function(x, groups, n_axes, var_threshold, log_transform, scale,
                                method = "convexhull") {
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
    if (identical(method, "convexhull")) {
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
    warning(
      sprintf(
        paste(
          "`n_axes` = %d is not smaller than the number of species/groups",
          "(%d). This is not required for method = \"%s\" (unlike",
          "\"convexhull\"), but functional-richness estimates from very few",
          "points relative to dimensionality should be interpreted with",
          "caution."
        ),
        n_axes, nlevels(groups), method
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
                              abbreviate_species = FALSE, space_name = "Ordination", ...) {
  x <- scores[, 1]
  y <- scores[, 2]
  dots <- list(...)

  # Short, inward-pointing tick marks for the duration of this plot only.
  # `las = 1` is set explicitly (rather than left to whatever the current
  # device/session default happens to be) so both axes' tick labels always
  # read horizontally, regardless of ambient `par()` state.
  old_par <- graphics::par(tcl = 0.3, mgp = c(2.2, 0.5, 0), las = 1)
  on.exit(graphics::par(old_par), add = TRUE)

  # Individual points are drawn smaller and slightly see-through (rather
  # than R's default solid, full-size `pch = 19`) so that overlapping
  # specimens in a dense ordination cloud remain distinguishable instead
  # of merging into a single solid blob.
  pt_cex <- 0.7
  pt_alpha <- 0.75

  # Title names the display style actually used (e.g. "Trait space
  # (spider)"), so a reader (or a figure caption written after the fact)
  # doesn't have to guess which of `style`'s four options produced a given
  # plot; `style = "none"` has nothing to name, so the title is left plain.
  style_label <- switch(style,
    spider = "spider", hull = "convex hull", density = "density", NULL
  )
  main_title <- if (!is.null(style_label)) paste0(space_name, " (", style_label, ")") else space_name

  if (is.null(groups)) {
    plot_args <- utils::modifyList(
      list(x = x, y = y, xlab = xlab, ylab = ylab, main = main_title, pch = 19, cex = pt_cex,
           col = grDevices::adjustcolor("black", alpha.f = pt_alpha)),
      dots
    )
    do.call(graphics::plot, plot_args)
    graphics::abline(h = 0, v = 0, lty = 3, col = "grey60")
    return(invisible(NULL))
  }

  # Defensive: drop unused factor levels (e.g. left over from an upstream
  # subset) so the palette/legend never reserves a colour and a legend
  # entry for a group with zero points.
  groups <- droplevels(as.factor(groups))
  # Colours are looked up by *label*, from a session-persistent cache
  # (.stable_group_colors()), rather than derived from this call's own
  # `nlevels(groups)`/`as.integer(groups)` position -- otherwise the same
  # species would get a different colour in, say, plot.intrait_morphospace()
  # vs plot.intrait_traitspace() whenever those two objects happen to
  # retain a different subset of species after their own upstream
  # NA/outlier filtering (which shifts positional indices even though the
  # species themselves are identical). See .stable_group_colors().
  label_colors <- .stable_group_colors(levels(groups))
  pal <- unname(label_colors[levels(groups)])
  # `pal` itself (fully opaque) is kept as-is for the legend swatches
  # further down, and for the spider/hull/density group-summary elements
  # (ellipses, hulls, centroids), which should stay crisp; only the raw
  # per-specimen points below are made translucent.
  cols <- grDevices::adjustcolor(pal[as.integer(groups)], alpha.f = pt_alpha)

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
    list(x = x, y = y, xlab = xlab, ylab = ylab, main = main_title, pch = 19, cex = pt_cex,
         col = cols, xlim = auto_xlim, ylim = auto_ylim),
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
