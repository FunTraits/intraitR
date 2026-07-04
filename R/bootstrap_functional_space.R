#' Bootstrap-based estimate of functional space volume from individual data
#'
#' Compares the functional richness (an n-dimensional convex-hull volume in
#' a PCA-based trait space) obtained when species are represented by real
#' individuals to the functional richness obtained when species are
#' collapsed to their centroid (mean trait position), following the
#' bootstrap procedure of Bertrand (2026, Section "Bootstrap-based
#' functional space estimates"). For each of `n_boot` bootstrap
#' "communities", one individual is drawn at random per species and the
#' convex-hull volume of these individual-level points is computed
#' (`fd_boot`); this distribution is compared to a single centroid-based
#' reference volume (`fd_ref`), obtained by replacing each species with the
#' mean position of its individuals before computing the hull. Because a
#' single randomly chosen individual necessarily sits somewhere within (or
#' at the edge of) its species' own dispersion, `fd_boot` is expected to
#' equal or exceed `fd_ref` whenever species show non-trivial intraspecific
#' trait variability (ITV); this function also tests whether `fd_ref` sits
#' unusually low relative to the bootstrap distribution (see Details).
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
#' @param n_axes Integer, the number of PCA axes to retain for the
#'   convex-hull volume. If `NULL` (default), the smallest number of axes
#'   whose cumulative proportion of variance reaches `var_threshold` is
#'   used automatically -- Bertrand (2026) used 8 axes, capturing 98% of
#'   total variance, for a similar ten-trait morphological data set. Must
#'   leave strictly more species than axes (`nlevels(groups) > n_axes`),
#'   since a non-degenerate n-dimensional convex hull requires at least
#'   `n_axes + 1` affinely independent points; lower `n_axes` (or
#'   `var_threshold`) if this is not satisfied.
#' @param var_threshold Cumulative proportion of variance used to
#'   automatically choose `n_axes` when `n_axes = NULL`. Defaults to
#'   `0.98`, as in Bertrand (2026).
#' @param n_boot Integer, number of bootstrap "communities". For each, one
#'   individual is drawn at random (independently across species) for
#'   every species, and the convex-hull volume of the resulting
#'   one-individual-per-species point set is computed. This is also the
#'   number of draws the significance test is based on (see Details), so
#'   larger values give a finer-grained p-value floor of `1 / (n_boot +
#'   1)`. Defaults to `100`, as in Bertrand (2026).
#' @param log_transform,scale As in [trait_space()]; only used when `x` is
#'   a raw trait table (ignored, and taken from `x`, when `x` is an
#'   `"intrait_traitspace"` object).
#'
#' @return An object of class `"intrait_bootstrap_fspace"`, a list with
#'   elements `fd_ref` (centroid-based reference volume), `fd_boot`
#'   (numeric vector of length `n_boot`, the bootstrap volumes),
#'   `fd_boot_mean`, `fd_boot_sd`, `fd_boot_q05`, `fd_boot_q95` (summary of
#'   `fd_boot`), `diff` (`fd_boot_mean - fd_ref`), `p_value` (one-sided
#'   bootstrap p-value, see Details), `n_axes` (actual number of PCA axes
#'   used), `var_explained` (cumulative proportion of variance captured by
#'   those `n_axes` axes), `n_boot`, and `groups`. Has dedicated
#'   [print()] and [plot()] methods.
#'
#' @details
#' A fresh Principal Component Analysis is always performed inside this
#' function (on `x$X`, the standardised trait matrix, when `x` is an
#' `"intrait_traitspace"` object, or on freshly standardised `x`
#' otherwise), so that `n_axes` PCA dimensions -- rather than only the two
#' axes [trait_space()] retains for plotting -- are available for the
#' convex hull, exactly as in Bertrand (2026). Convex-hull volumes are
#' computed with [geometry::convhulln()] (Qhull; Barber, Dobkin &
#' Huhdanpaa, 1996), which requires the `geometry` package: it is Suggested
#' but not automatically installed with intraitR, since it is only needed
#' for this function.
#'
#' Bertrand (2026) compares the bootstrap distribution to `fd_ref` with a
#' one-sided permutation test (H0: mean(FD_boot) <= FD_ref, using 9,999
#' permutations of an unspecified scheme). Reproducing that test exactly
#' is not possible from the report's description alone, so two candidate
#' designs were evaluated by simulation before choosing an implementation,
#' and it is worth recording why the first one was rejected. The initial
#' candidate reassigned species labels to individuals at random
#' (preserving sample sizes, as in [trait_disparity()]'s permutation test)
#' and compared a permuted centroid volume to a permuted single-draw
#' volume. Simulation showed this null is not informative here: shuffling
#' labels collapses every permuted centroid toward the *global* mean of
#' all individuals (a permuted "species" is just a random subsample of the
#' whole data set), while a permuted single-individual draw still spans
#' the data's full range, so the permuted difference is typically far
#' larger than the real, structure-preserving difference regardless of
#' whether genuine ITV is present -- the test was essentially always
#' non-significant by construction, which does not match Bertrand (2026)'s
#' reported result and would silently mislead users.
#'
#' The implementation used here instead treats `fd_boot` itself as the
#' reference (empirical, resampling-based) distribution and asks how
#' extreme `fd_ref` is relative to it, which requires no separate
#' permutation scheme: `p_value` is the proportion of `fd_boot` draws less
#' than or equal to `fd_ref`, plus one, divided by `n_boot + 1` (the same
#' `+ 1` correction convention as [trait_disparity()]; Davison & Hinkley,
#' 1997). A small `p_value` means `fd_ref` sits in the low tail of the
#' bootstrap distribution, i.e. that individual-based functional richness
#' exceeds the centroid-based reference by more than would be expected
#' from the bootstrap resampling variability alone. This design was
#' verified by simulation (clustered points with known, tunable
#' intraspecific dispersion) to correctly stay non-significant when
#' intraspecific variability is negligible and to correctly detect a
#' strong, real excess when it is not.
#'
#' Species represented by a single individual necessarily contribute the
#' same point to every bootstrap draw (there is nothing to resample for
#' that species); this is expected behaviour, not an error.
#'
#' The `n_boot` bootstrap draws are independent of one another (each is
#' just one random individual per species plus a convex-hull recomputation),
#' so they parallelise trivially. If the `future.apply` package is
#' installed and a parallel `future::plan()` (e.g. `future::plan(
#' "multisession")`) has been set before calling this function, the draws
#' are distributed across that plan's workers automatically; otherwise
#' (no plan set, or `future.apply` not installed) they simply run
#' sequentially, with identical results either way. This matters mainly
#' for large `n_axes`/many-species data sets, where each convex-hull
#' computation itself becomes more expensive (see [species_sensitivity()]
#' for a discussion of that per-call cost).
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
#' Barber CB, Dobkin DP, Huhdanpaa H (1996). The Quickhull algorithm for
#' convex hulls. ACM Transactions on Mathematical Software, 22(4), 469-483.
#'
#' Davison AC, Hinkley DV (1997). Bootstrap Methods and their Application.
#' Cambridge University Press.
#'
#' @seealso [trait_space()], [trait_disparity()]
#'
#' @examples
#' \donttest{
#' if (requireNamespace("geometry", quietly = TRUE)) {
#'   fish <- load_t26_saudrune_landmarks()
#'   segments <- fishmorph_segments(fish)
#'   ratios <- fishmorph_ratios(segments)
#'   ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#'   # n_axes = 2 here only to keep the example fast; Bertrand (2026) used 8
#'   bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 200)
#'   bf
#'   plot(bf)
#' }
#' }
#' @export
bootstrap_functional_space <- function(x, groups = NULL, n_axes = NULL, var_threshold = 0.98,
                                        n_boot = 100,
                                        log_transform = TRUE, scale = TRUE) {
  if (!requireNamespace("geometry", quietly = TRUE)) {
    stop(
      "bootstrap_functional_space() requires the \"geometry\" package (for ",
      "n-dimensional convex-hull volumes). Install it with ",
      "install.packages(\"geometry\").",
      call. = FALSE
    )
  }
  if (!is.numeric(n_boot) || length(n_boot) != 1 || n_boot < 1) {
    stop("`n_boot` must be a single positive integer.", call. = FALSE)
  }

  fs <- .fspace_pca_scores(x, groups, n_axes, var_threshold, log_transform, scale)
  scores <- fs$scores
  groups <- fs$groups
  n_axes <- fs$n_axes

  .draw_one_per_species <- function(sc, g) {
    t(vapply(levels(g), function(lv) {
      idx <- which(g == lv)
      sc[if (length(idx) == 1) idx else sample(idx, 1), ]
    }, numeric(ncol(sc))))
  }

  fd_ref <- .convex_hull_volume(.group_centroids(scores, groups))
  if (is.na(fd_ref)) {
    stop(
      "The centroid-based convex hull is degenerate (species centroids are ",
      "not affinely independent in ", n_axes, " dimensions); try a smaller ",
      "`n_axes`.",
      call. = FALSE
    )
  }

  fd_boot <- .papply(seq_len(n_boot), function(b) {
    .convex_hull_volume(.draw_one_per_species(scores, groups))
  }, numeric(1))

  # One-sided bootstrap p-value: how far into the lower tail of the
  # bootstrap distribution itself does the fixed reference fd_ref fall?
  # See Details for why this replaces a label-permutation null.
  p_value <- (sum(fd_boot <= fd_ref, na.rm = TRUE) + 1) / (n_boot + 1)

  structure(
    list(
      fd_ref = fd_ref,
      fd_boot = fd_boot,
      fd_boot_mean = mean(fd_boot, na.rm = TRUE),
      fd_boot_sd = stats::sd(fd_boot, na.rm = TRUE),
      fd_boot_q05 = stats::quantile(fd_boot, 0.05, na.rm = TRUE, names = FALSE),
      fd_boot_q95 = stats::quantile(fd_boot, 0.95, na.rm = TRUE, names = FALSE),
      diff = mean(fd_boot, na.rm = TRUE) - fd_ref,
      p_value = p_value,
      n_axes = n_axes,
      var_explained = fs$var_explained,
      n_boot = as.integer(n_boot),
      groups = groups
    ),
    class = "intrait_bootstrap_fspace"
  )
}

#' Print and plot an `"intrait_bootstrap_fspace"` object
#'
#' @param x An object of class `"intrait_bootstrap_fspace"`, as returned by
#'   [bootstrap_functional_space()].
#' @param ... For `plot()`, further arguments passed to [graphics::hist()];
#'   currently unused by `print()`.
#' @return Invisibly returns `x`.
#' @export
print.intrait_bootstrap_fspace <- function(x, ...) {
  cat("<intrait_bootstrap_fspace>\n")
  cat(sprintf(
    "  %d PCA axes retained (%.1f%% of variance), %d species\n",
    x$n_axes, x$var_explained * 100, nlevels(x$groups)
  ))
  cat(sprintf("  Centroid-based reference volume (FD_ref): %.4g\n", x$fd_ref))
  cat(sprintf(
    "  Bootstrap volume (FD_boot, %d draws): mean = %.4g, SD = %.4g, 5-95%% = [%.4g, %.4g]\n",
    x$n_boot, x$fd_boot_mean, x$fd_boot_sd, x$fd_boot_q05, x$fd_boot_q95
  ))
  cat(sprintf(
    "  Difference (mean FD_boot - FD_ref): %.4g (one-sided bootstrap p = %.4g)\n",
    x$diff, x$p_value
  ))
  invisible(x)
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname print.intrait_bootstrap_fspace
plot.intrait_bootstrap_fspace <- function(x, ...) {
  graphics::hist(
    x$fd_boot, col = "grey85", border = "white",
    main = "Bootstrap-based functional space estimate",
    xlab = "Functional richness (convex-hull volume)",
    xlim = range(c(x$fd_boot, x$fd_ref)),
    ...
  )
  graphics::abline(v = x$fd_ref, col = "firebrick", lwd = 2, lty = 2)
  graphics::mtext(
    sprintf("Centroid-based reference: FD_ref = %.4g (dashed line)", x$fd_ref),
    side = 3, line = 0.3, col = "firebrick", cex = 0.8
  )
  invisible(x)
}
