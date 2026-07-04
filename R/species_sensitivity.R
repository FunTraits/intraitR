#' Species-level sensitivity index for functional space estimates
#'
#' For each species, quantifies how much replacing that species' centroid
#' with one of its real individuals changes the estimated functional
#' richness (an n-dimensional convex-hull volume in PCA space), while every
#' other species stays fixed at its own centroid, following the
#' species-level sensitivity index of Bertrand (2026, Section
#' "Species-level sensitivity index"). This complements
#' [bootstrap_functional_space()]'s community-wide comparison by asking a
#' finer-grained question: *which* species drive the difference between
#' individual-based and centroid-based functional richness, and are their
#' individual effects consistent or highly variable?
#'
#' @param x Either an object of class `"intrait_traitspace"` (from
#'   [trait_space()], built with `groups` supplied), or a
#'   `data.frame`/matrix of numeric traits (one row per individual), in
#'   which case `groups` must also be supplied and the same
#'   `log_transform`/`scale` preprocessing as [trait_space()] is applied
#'   before the PCA described below.
#' @param groups Required when `x` is a raw trait table (one value per
#'   individual, typically species identity); ignored (taken from
#'   `x$groups`) when `x` is an `"intrait_traitspace"` object.
#' @param n_axes,var_threshold,log_transform,scale As in
#'   [bootstrap_functional_space()]: `n_axes` PCA axes are used for the
#'   convex hull (auto-selected via `var_threshold` if `NULL`), computed
#'   from a fresh PCA on `x$X` (or on freshly standardised `x`).
#'
#' @return An object of class `"intrait_species_sensitivity"`, a list with
#'   elements: `summary` (a `data.frame`, one row per species, with
#'   columns `species`, `n_individuals`, `mean_dFD`, `min_dFD`, `max_dFD`
#'   -- the species-level index, i.e. Bertrand (2026)'s `mu_k` and range,
#'   in the original `levels(groups)` order), `individual` (a long-format
#'   `data.frame` with one row per individual, columns `species` and
#'   `dFD`, for full transparency beyond the per-species summary), `fd_ref`
#'   (the community-wide centroid-based reference volume), `n_axes`, and
#'   `var_explained`. Has dedicated [print()] and [plot()] methods.
#'
#' @details
#' For a focal species k with individuals `i = 1, ..., n_k`, its centroid
#' in the `n_axes`-dimensional PCA space is replaced, one individual at a
#' time, by that individual's own PCA scores, while every other species
#' remains at its centroid; the convex-hull volume of this modified
#' `n_species`-point configuration is `FD_{k,i}`. Each replacement is
#' expressed as a percentage change relative to the (unmodified)
#' centroid-based reference volume `fd_ref`:
#' \deqn{\Delta FD_{k,i} (\%) = 100 \times (FD_{k,i} - FD_{ref}) / FD_{ref}}
#' A positive `dFD` means that individual, if it alone stood in for its
#' species' centroid, would expand the estimated functional space; a
#' negative `dFD` means it would contract it. `mean_dFD` (`mu_k`)
#' summarises the average tendency of a species' individuals, and
#' `min_dFD`/`max_dFD` describe the heterogeneity of individual effects
#' within that species -- a wide range indicates a few unusual individuals
#' rather than a consistent species-level tendency (see Bertrand, 2026,
#' for worked examples of both patterns in real data).
#'
#' Unlike [bootstrap_functional_space()], this index requires no
#' resampling or significance test: every replacement is deterministic
#' (one individual, one recomputed volume), so `species_sensitivity()` is
#' exact given `x`/`groups`/`n_axes`, not simulation-based. Species with
#' only one individual still receive a (single-valued) `mean_dFD`, with
#' `min_dFD == max_dFD` and no useful "range" to speak of, which is
#' expected, not an error.
#'
#' Every individual, across every species, requires its own convex-hull
#' recomputation (one call per individual in `x`/`groups`, not per
#' species), so this is the most computationally demanding of the two
#' functional-space functions on a large data set -- Bertrand (2026)'s
#' regional panel, for instance, had 1,302 individuals. Each individual's
#' replacement is independent of every other's, so, exactly as in
#' [bootstrap_functional_space()], this is distributed automatically
#' across `future.apply`'s workers when that package is installed and a
#' parallel `future::plan()` has been set beforehand; with no plan set, or
#' without `future.apply`, it runs sequentially with identical results.
#'
#' @references
#' Bertrand P (2026). Intraspecific trait variability shapes the
#' functional space of freshwater fish in French Guiana assemblages. M2
#' Biodiversity Ecology Evolution (BEE) internship report, Lille
#' University / Centre de Recherche sur la Biodiversite et l'Environnement
#' (CRBE, AQUAECO team), unpublished, supervised by A. Toussaint and S.
#' Brosse.
#'
#' Villeger S, Mason NWH, Mouillot D (2008). New multidimensional
#' functional diversity indices for a multifaceted framework in functional
#' ecology. Ecology, 89(8), 2290-2301.
#'
#' @seealso [bootstrap_functional_space()], [trait_space()]
#'
#' @examples
#' \donttest{
#' if (requireNamespace("geometry", quietly = TRUE)) {
#'   fish <- load_t26_saudrune_landmarks()
#'   segments <- fishmorph_segments(fish)
#'   ratios <- fishmorph_ratios(segments)
#'   ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#'   ss <- species_sensitivity(ts, n_axes = 2)
#'   ss
#'   plot(ss)
#' }
#' }
#' @export
species_sensitivity <- function(x, groups = NULL, n_axes = NULL, var_threshold = 0.98,
                                 log_transform = TRUE, scale = TRUE) {
  if (!requireNamespace("geometry", quietly = TRUE)) {
    stop(
      "species_sensitivity() requires the \"geometry\" package (for ",
      "n-dimensional convex-hull volumes). Install it with ",
      "install.packages(\"geometry\").",
      call. = FALSE
    )
  }

  fs <- .fspace_pca_scores(x, groups, n_axes, var_threshold, log_transform, scale)
  scores <- fs$scores
  groups <- fs$groups
  n_axes <- fs$n_axes

  centroids <- .group_centroids(scores, groups)
  fd_ref <- .convex_hull_volume(centroids)
  if (is.na(fd_ref)) {
    stop(
      "The centroid-based convex hull is degenerate (species centroids are ",
      "not affinely independent in ", n_axes, " dimensions); try a smaller ",
      "`n_axes`.",
      call. = FALSE
    )
  }

  lv <- levels(groups)
  species_idx <- as.integer(groups)  # row of `centroids` each individual belongs to

  # Every individual's replacement is independent of every other's (each
  # starts fresh from `centroids` and only ever changes one row), so this
  # is flattened across *all* individuals (rather than nested per-species
  # loops) and distributed across future.apply's workers when available
  # and a future::plan() has been set (see Details); .papply() falls back
  # to a plain vapply() otherwise.
  dFD_all <- .papply(seq_len(nrow(scores)), function(i) {
    config <- centroids
    config[species_idx[i], ] <- scores[i, ]
    fd_ki <- .convex_hull_volume(config)
    100 * (fd_ki - fd_ref) / fd_ref
  }, numeric(1))

  individual <- data.frame(
    species = as.character(groups), dFD = dFD_all,
    row.names = NULL, stringsAsFactors = FALSE
  )

  summary_df <- data.frame(
    species = lv,
    n_individuals = as.integer(table(groups)[lv]),
    mean_dFD = vapply(lv, function(s) mean(individual$dFD[individual$species == s], na.rm = TRUE), numeric(1)),
    min_dFD = vapply(lv, function(s) min(individual$dFD[individual$species == s], na.rm = TRUE), numeric(1)),
    max_dFD = vapply(lv, function(s) max(individual$dFD[individual$species == s], na.rm = TRUE), numeric(1)),
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  structure(
    list(
      summary = summary_df,
      individual = individual,
      fd_ref = fd_ref,
      n_axes = n_axes,
      var_explained = fs$var_explained
    ),
    class = "intrait_species_sensitivity"
  )
}

#' Print and plot an `"intrait_species_sensitivity"` object
#'
#' @param x An object of class `"intrait_species_sensitivity"`, as returned
#'   by [species_sensitivity()].
#' @param n Integer, the number of most-influential species to show.
#'   Defaults to `12`.
#' @param abbreviate_species Logical (`plot()` only), abbreviate
#'   `"Genus species"` axis labels to `"G. species"`. Defaults to `TRUE`.
#' @param ... For `plot()`, further arguments passed to [graphics::barplot()];
#'   currently unused by `print()`.
#' @return Invisibly returns `x`.
#' @export
print.intrait_species_sensitivity <- function(x, n = 12, ...) {
  cat("<intrait_species_sensitivity>\n")
  cat(sprintf(
    "  %d PCA axes retained (%.1f%% of variance), %d species, FD_ref = %.4g\n",
    x$n_axes, x$var_explained * 100, nrow(x$summary), x$fd_ref
  ))
  ord <- order(abs(x$summary$mean_dFD), decreasing = TRUE)
  top <- x$summary[ord, , drop = FALSE][seq_len(min(n, nrow(x$summary))), , drop = FALSE]
  cat(sprintf(
    "  Top %d species by |mean %%change in functional richness|:\n",
    nrow(top)
  ))
  top_fmt <- data.frame(
    species = top$species,
    n = top$n_individuals,
    mean_dFD = sprintf("%+.2f%%", top$mean_dFD),
    range_dFD = sprintf("[%+.2f%%, %+.2f%%]", top$min_dFD, top$max_dFD),
    row.names = NULL
  )
  print(top_fmt, row.names = FALSE)
  invisible(x)
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname print.intrait_species_sensitivity
plot.intrait_species_sensitivity <- function(x, n = 12, abbreviate_species = TRUE, ...) {
  s <- x$summary
  ord <- order(abs(s$mean_dFD), decreasing = TRUE)
  top <- s[ord, , drop = FALSE][seq_len(min(n, nrow(s))), , drop = FALSE]
  # plot top-to-bottom in decreasing effect order, i.e. largest at the top
  top <- top[rev(seq_len(nrow(top))), , drop = FALSE]

  labels <- top$species
  if (isTRUE(abbreviate_species)) labels <- .abbreviate_species_name(labels)

  old_par <- graphics::par(mar = c(4, max(6, max(nchar(labels)) * 0.5), 3, 1))
  on.exit(graphics::par(old_par), add = TRUE)

  y <- seq_len(nrow(top))
  xr <- range(c(top$min_dFD, top$max_dFD, 0))
  xpad <- diff(xr) * 0.08
  if (!is.finite(xpad) || xpad == 0) xpad <- 1

  graphics::plot(
    top$mean_dFD, y, pch = 19, yaxt = "n", ylab = "",
    xlim = xr + c(-xpad, xpad), ylim = c(0.5, nrow(top) + 0.5),
    xlab = expression(paste(Delta, "FD (%)")),
    main = "Species-level sensitivity index", ...
  )
  graphics::axis(2, at = y, labels = labels, las = 1, font = 3, cex.axis = 0.8)
  graphics::segments(top$min_dFD, y, top$max_dFD, y)
  graphics::abline(v = 0, col = "firebrick", lty = 2)
  invisible(x)
}
