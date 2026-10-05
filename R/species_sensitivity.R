#' Species-level sensitivity index for functional space estimates
#'
#' For each species, quantifies how much replacing that species' centroid
#' with one of its real individuals changes the estimated functional
#' richness in PCA space, while every other species stays fixed at its own
#' centroid, following the species-level sensitivity index of Bertrand
#' (2026, Section "Species-level sensitivity index"). This complements
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
#' @param method,n_axes,var_threshold,log_transform,scale,dendrogram_linkage,tpd_alpha,tpd_bw_factor,tpd_n_divisions,hv_bw_method,hv_samples_per_point
#'   As in [bootstrap_functional_space()]: `method` selects the
#'   functional-richness measure recomputed for the reference configuration
#'   and every single-individual replacement (`"convexhull"`, the default,
#'   an n-dimensional convex-hull volume; `"dendrogram"`, total branch
#'   length of a UPGMA functional dendrogram; `"tpd"`, Trait Probability
#'   Density functional richness; `"hypervolume"`, a Gaussian-kernel
#'   hypervolume), and `n_axes` PCA axes are used (auto-selected via
#'   `var_threshold` if `NULL`), computed from a fresh PCA on `x$X` (or on
#'   freshly standardised `x`). As there, only `method = "convexhull"`
#'   strictly requires `nlevels(groups) > n_axes`; the other methods only
#'   warn instead. For `"tpd"`/`"hypervolume"`, the kernel bandwidth (and,
#'   for `"tpd"`, the evaluation grid) is likewise computed once from the
#'   full individual-level PCA scores and reused, unchanged, for `fd_ref`
#'   and every one of the `nrow(x)` single-individual replacements, for the
#'   same comparability reason explained there.
#'
#' @return An object of class `"intrait_species_sensitivity"`, a list with
#'   elements: `summary` (a `data.frame`, one row per species, with
#'   columns `species`, `n_individuals`, `mean_dFD`, `min_dFD`, `max_dFD`
#'   -- the species-level index, i.e. Bertrand (2026)'s `mu_k` and range,
#'   in the original `levels(groups)` order), `individual` (a long-format
#'   `data.frame` with one row per individual, columns `species` and
#'   `dFD`, for full transparency beyond the per-species summary), `fd_ref`
#'   (the community-wide centroid-based reference richness), `method`,
#'   `n_axes`, and `var_explained`. Has dedicated [print()] and [plot()]
#'   methods.
#'
#' @details
#' For a focal species k with individuals `i = 1, ..., n_k`, its centroid
#' in the `n_axes`-dimensional PCA space is replaced, one individual at a
#' time, by that individual's own PCA scores, while every other species
#' remains at its centroid; the functional richness of this modified
#' `n_species`-point configuration is `FD_{k,i}`. Each replacement is
#' expressed as a percentage change relative to the (unmodified)
#' centroid-based reference richness `fd_ref`:
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
#' (one individual, one recomputed richness value), so
#' `species_sensitivity()` is exact given `x`/`groups`/`n_axes`/`method`,
#' not simulation-based. Species with only one individual still receive a
#' (single-valued) `mean_dFD`, with `min_dFD == max_dFD` and no useful
#' "range" to speak of, which is expected, not an error.
#'
#' Every individual, across every species, requires its own
#' functional-richness recomputation (one call per individual in
#' `x`/`groups`, not per species), so this is the most computationally
#' demanding of the two functional-space functions on a large data set --
#' Bertrand (2026)'s regional panel, for instance, had 1,302 individuals --
#' and especially so for `method = "hypervolume"` (by far the most
#' expensive of the four measures per call, see
#' [bootstrap_functional_space()]). Each individual's replacement is
#' independent of every other's, so, exactly as in
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
#' Petchey OL, Gaston KJ (2002). Functional diversity (FD), species
#' richness and community composition. Ecology Letters, 5(3), 402-411.
#'
#' Carmona CP, de Bello F, Mason NWH, Leps J (2019). Trait probability
#' density (TPD): measuring functional diversity across scales based on
#' TPD with R. Ecology, 100(12), e02876.
#'
#' Blonder B, Lamanna C, Violle C, Enquist BJ (2014). The n-dimensional
#' hypervolume. Global Ecology and Biogeography, 23(5), 595-609.
#'
#' Blonder B, Morrow CB, Maitner B, Harris DJ, Lamanna C, Violle C,
#' Enquist BJ, Kerkhoff AJ (2018). New approaches for delineating
#' n-dimensional hypervolumes. Methods in Ecology and Evolution, 9(2),
#' 305-319.
#'
#' @seealso [bootstrap_functional_space()], [trait_space()]
#'
#' @examples
#' \donttest{
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#'
#' # method = "dendrogram" needs no extra Suggested package
#' ss_dendro <- species_sensitivity(ts, method = "dendrogram", n_axes = 2)
#' ss_dendro
#' plot(ss_dendro)
#'
#' if (requireNamespace("geometry", quietly = TRUE)) {
#'   ss <- species_sensitivity(ts, n_axes = 2)
#'   ss
#' }
#' }
#' @export
species_sensitivity <- function(x, groups = NULL,
                                 method = c("convexhull", "dendrogram", "tpd", "hypervolume"),
                                 n_axes = NULL, var_threshold = 0.98,
                                 log_transform = TRUE, scale = TRUE,
                                 dendrogram_linkage = "average",
                                 tpd_alpha = 0.95, tpd_bw_factor = 0.5,
                                 tpd_n_divisions = NULL,
                                 hv_bw_method = "silverman",
                                 hv_samples_per_point = 500) {
  method <- match.arg(method)
  if (identical(method, "convexhull") && !requireNamespace("geometry", quietly = TRUE)) {
    stop(
      "species_sensitivity(method = \"convexhull\") requires the ",
      "\"geometry\" package (for n-dimensional convex-hull volumes). ",
      "Install it with install.packages(\"geometry\").",
      call. = FALSE
    )
  }
  if (identical(method, "tpd") && !requireNamespace("TPD", quietly = TRUE)) {
    stop(
      "species_sensitivity(method = \"tpd\") requires the \"TPD\" package. ",
      "Install it with install.packages(\"TPD\").",
      call. = FALSE
    )
  }
  if (identical(method, "hypervolume") && !requireNamespace("hypervolume", quietly = TRUE)) {
    stop(
      "species_sensitivity(method = \"hypervolume\") requires the ",
      "\"hypervolume\" package. Install it with install.packages(\"hypervolume\").",
      call. = FALSE
    )
  }

  fs <- .fspace_pca_scores(x, groups, n_axes, var_threshold, log_transform, scale, method = method)
  scores <- fs$scores
  groups <- fs$groups
  n_axes <- fs$n_axes

  # Shared, method-specific auxiliary quantities (kernel bandwidth,
  # evaluation grid), computed once and reused for fd_ref and every
  # single-individual replacement -- see Details and
  # bootstrap_functional_space()'s own Details for why.
  aux <- .fspace_richness_setup(
    scores, method,
    dendrogram_linkage = dendrogram_linkage,
    tpd_alpha = tpd_alpha, tpd_bw_factor = tpd_bw_factor, tpd_n_divisions = tpd_n_divisions,
    hv_bw_method = hv_bw_method, hv_samples_per_point = hv_samples_per_point
  )

  centroids <- .group_centroids(scores, groups)
  rownames(centroids) <- levels(groups)
  fd_ref <- .fspace_richness(centroids, method, aux)
  if (is.na(fd_ref)) {
    stop(
      sprintf(
        paste(
          "The centroid-based functional-richness estimate (method = \"%s\")",
          "could not be computed (e.g. a degenerate configuration in %d",
          "dimensions, or a required package call failed); try a smaller",
          "`n_axes`."
        ),
        method, n_axes
      ),
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
    fd_ki <- .fspace_richness(config, method, aux)
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
      method = method,
      n_axes = n_axes,
      var_explained = fs$var_explained
    ),
    class = "intrait_species_sensitivity"
  )
}

#' Print and plot an `"intrait_species_sensitivity"` object
#'
#' Both mention which `method` (`"convexhull"`, `"dendrogram"`, `"tpd"`, or
#' `"hypervolume"`) was used to compute the underlying functional richness.
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
  method_label <- if (!is.null(x$method)) x$method else "convexhull"
  cat(sprintf("<intrait_species_sensitivity> (method = \"%s\")\n", method_label))
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

  method_label <- if (!is.null(x$method)) x$method else "convexhull"

  graphics::plot(
    top$mean_dFD, y, pch = 19, yaxt = "n", ylab = "",
    xlim = xr + c(-xpad, xpad), ylim = c(0.5, nrow(top) + 0.5),
    xlab = expression(paste(Delta, "FD (%)")),
    main = sprintf("Species-level sensitivity index (method = \"%s\")", method_label), ...
  )
  graphics::axis(2, at = y, labels = labels, las = 1, font = 3, cex.axis = 0.8)
  graphics::segments(top$min_dFD, y, top$max_dFD, y)
  graphics::abline(v = 0, col = "firebrick", lty = 2)
  invisible(x)
}
