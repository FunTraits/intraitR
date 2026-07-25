#' Proportion of the global functional diversity captured by projected ITV
#'
#' Quantifies how much of the entire (global) functional diversity of the
#' reference database a group's projected intraspecific trait variation (ITV)
#' actually occupies, from an [project_fishmorph()] projection, along two
#' complementary decompositions:
#'
#' * **per trait** -- univariate functional diversity is taken as the trait
#'   *range* (the one-dimensional convex hull; Villeger, Mason & Mouillot,
#'   2008). For each trait the proportion is the range spanned by the focal
#'   specimens divided by the range spanned by the whole reference, on the
#'   analysis scale (the `log10(x + 1)` scale when `log_transform` was used to
#'   build the projection). A value of `0.10` means the focal ITV spreads
#'   across a tenth of the global variation in that trait.
#' * **per functional volume** -- multivariate functional richness in the
#'   `volume_dims` leading principal components of the frozen global space,
#'   computed by one of two `metric`s and expressed as the ITV volume divided
#'   by the reference volume:
#'   * `metric = "hull"` (default): the **convex-hull** volume (Villeger,
#'     Mason & Mouillot, 2008), via [geometry::convhulln()]. An *extent*-based
#'     richness -- driven by the outermost specimens only, so a handful of
#'     dispersed individuals can enclose a large fraction of the reference
#'     hull even when the bulk of the reference is concentrated elsewhere.
#'   * `metric = "tpd"`: the **Trait Probability Density FRichness** (Carmona
#'     et al. 2016, 2019), via [TPD::TPDs()]/[TPD::TPDc()]/[TPD::REND()]. A
#'     *density*-based richness that estimates a kernel density from the
#'     individuals and measures the volume of trait space it occupies above an
#'     `tpd_alpha`-quantile density threshold, so sparse outliers are
#'     down-weighted rather than allowed to stretch the volume. Every unit (the
#'     reference, the pooled focal set, each species) is evaluated on the
#'     *same* fixed grid, keeping the volumes comparable. Typically yields a
#'     much smaller, more conservative proportion than the convex hull for a
#'     centrally-clustered focal set. Requires the Suggested 'TPD' package.
#'
#' Both decompositions are reported pooled over all focal specimens (the total
#' footprint of the focal set) and separately for each species. The per-trait
#' (range) decomposition is unaffected by `metric`.
#'
#' @param x An object of class `"intrait_fishmorph_projection"`, as returned
#'   by [project_fishmorph()]. It must carry the material stored by that
#'   function from version 1.7.0 onwards (`specimen_traits`,
#'   `trait_ranges_reference`, `scores_all`, `global_scores_all`); recompute
#'   the projection if an older object lacks them.
#' @param volume_dims Integer, the number of leading principal components used
#'   for the functional-volume (convex-hull) proportion. Defaults to the value
#'   stored on `x` (from [project_fishmorph()]'s own `volume_dims`, itself
#'   `2L` by default). A convex hull in `volume_dims` dimensions needs at
#'   least `volume_dims + 1` affinely independent points, so a species with
#'   fewer specimens yields `NA`.
#' @param metric Character, the multivariate functional-volume measure:
#'   `"hull"` (default) for the convex-hull volume, or `"tpd"` for the
#'   density-based Trait Probability Density FRichness (see Details).
#'   `"tpd"` requires the Suggested 'TPD' package. The per-trait range
#'   proportions are identical under either choice.
#' @param tpd_alpha Numeric in `(0, 1]`, used only when `metric = "tpd"`: the
#'   density quantile threshold passed to [TPD::TPDs()] (the fraction of the
#'   probability mass retained; the sparsest `1 - tpd_alpha` tail is trimmed
#'   before the occupied volume is measured). Defaults to `0.99`.
#' @param tpd_n_divisions Integer or `NULL`, used only when `metric = "tpd"`:
#'   the number of evaluation-grid divisions per axis (shared across all
#'   units). `NULL` (default) picks a value that keeps the grid tractable as
#'   `volume_dims` grows (`50` per axis in 2-D).
#' @param ... Currently unused.
#'
#' @return An object of class `"intrait_itv_proportion"`, a list with:
#'   \describe{
#'     \item{`trait`}{a `data.frame`, one row per trait, with `trait`,
#'       `global_range`, `itv_range_pooled` (range over all focal specimens),
#'       and `proportion_pooled` (`itv_range_pooled / global_range`).}
#'     \item{`trait_species`}{a long `data.frame` with `species`, `trait`,
#'       `n` (specimens of that species), `itv_range`, and `proportion`
#'       (per-species trait-range proportion).}
#'     \item{`volume`}{a `data.frame`, one row for the pooled focal set
#'       (`group = "(all focal species)"`) then one per species, with `group`,
#'       `n`, `volume` (the functional volume in `volume_dims` dimensions --
#'       convex-hull volume when `metric = "hull"`, TPD FRichness when
#'       `metric = "tpd"`), and `proportion` (`volume / global_volume`).}
#'     \item{`global_volume`}{the reference functional volume in `volume_dims`
#'       dimensions (same metric as `volume`).}
#'     \item{`volume_dims`}{the number of dimensions used.}
#'     \item{`metric`}{the functional-volume metric used (`"hull"` or
#'       `"tpd"`).}
#'     \item{`scale`, `volume_scale`}{character notes on the scale of the
#'       per-trait ranges and on the functional-volume metric.}
#'   }
#'   Has a dedicated [print()] method.
#'
#' @references
#' Villeger, S., Mason, N. W. H., & Mouillot, D. (2008). New multidimensional
#' functional diversity indices for a multifaceted framework in functional
#' ecology. Ecology, 89(8), 2290-2301.
#'
#' Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2016). Traits
#' without borders: integrating functional diversity across scales. Trends in
#' Ecology & Evolution, 31(5), 382-394.
#'
#' Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2019). Trait
#' probability density (TPD): measuring functional diversity across scales
#' based on TPD with R. Ecology, 100(12), e02876.
#'
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villeger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(11), 2330-2336.
#'
#' @seealso [project_fishmorph()], [bootstrap_functional_space()]
#'
#' @examples
#' \donttest{
#' # Needs the full FISHMORPH database (a ~9,000-species CSV) as `reference`;
#' # this file is not shipped with the package, so the example runs only when it
#' # is available locally (adjust the path to your own copy).
#' ref_path <- "FishMORPH/fishmorph_data.csv"
#' if (file.exists(ref_path)) {
#'   fish   <- load_t26_saudrune_landmarks()
#'   ratios <- fishmorph_ratios(fishmorph_segments(fish), na_action = "omit")
#'   proj   <- project_fishmorph(ratios, reference = ref_path)
#'
#'   # project_fishmorph() already bundles the default (volume_dims = 2) result:
#'   proj$itv_proportion
#'
#'   # recompute on a different number of axes:
#'   itv_proportion(proj, volume_dims = 3)
#'
#'   # density-based (TPD) functional richness instead of the convex hull:
#'   if (requireNamespace("TPD", quietly = TRUE)) itv_proportion(proj, metric = "tpd")
#' }
#' }
#'
#' @export
itv_proportion <- function(x, volume_dims = NULL, metric = c("hull", "tpd"),
                           tpd_alpha = 0.99, tpd_n_divisions = NULL, ...) {
  UseMethod("itv_proportion")
}

#' Density-based functional richness (TPD FRichness) of one point cloud, on a
#' fixed shared grid
#'
#' Density-weighted counterpart to `.convex_hull_volume()` for
#' [itv_proportion()]'s `metric = "tpd"`. Estimates a Trait Probability
#' Density (Carmona et al. 2016, 2019) for a single set of individuals with
#' [TPD::TPDs()] (a kernel density built from the individuals themselves, so
#' within-group spread and density -- not just the outer envelope -- drive the
#' result), then returns its functional richness (`TPD::REND()`'s `FRichness`
#' for the one-community TPDc: the volume of the evaluation grid whose density
#' exceeds the `alpha`-quantile threshold, i.e. after the sparsest tails
#' holding `1 - alpha` of the probability mass are trimmed).
#'
#' The grid (`trait_ranges`, `n_divisions`) is passed in from the caller and is
#' *identical* for every unit (the reference, the pooled focal set, each
#' species), so the cell volume is the same everywhere and the resulting
#' FRichness values -- and therefore their ratios in [itv_proportion()] -- are
#' directly comparable. Unlike the convex hull, this down-weights sparse
#' outliers instead of letting them stretch the measured volume.
#'
#' @param pts A numeric matrix, one row per individual, `k` columns (the
#'   leading PCs).
#' @param trait_ranges A length-`k` list of `c(min, max)` grid limits, shared
#'   across all units.
#' @param n_divisions Integer, the number of grid divisions per axis, shared
#'   across all units.
#' @param alpha Numeric in `(0, 1]`, the TPD density quantile threshold
#'   (`TPD::TPDs()`'s `alpha`).
#' @return A single numeric FRichness, or `NA_real_` if the cloud has too few
#'   points to support a density in `k` dimensions (fewer than `k + 1`) or the
#'   TPD computation fails.
#' @references
#' Carmona, C. P., de Bello, F., Mason, N. W. H., & Leps, J. (2019). Trait
#' probability density (TPD): measuring functional diversity across scales
#' based on TPD with R. Ecology, 100(12), e02876.
#' @noRd
.itv_tpd_richness <- function(pts, trait_ranges, n_divisions, alpha) {
  pts <- as.matrix(pts)
  k <- ncol(pts)
  # A density (like a hull) is degenerate with k or fewer points in k
  # dimensions; return NA so per-species results match the hull's NA rule.
  if (nrow(pts) <= k) return(NA_real_)
  # A constant axis (no spread) makes the per-unit kernel bandwidth singular.
  if (any(apply(pts, 2, stats::sd) <= 0)) return(NA_real_)

  tpds <- tryCatch(
    suppressWarnings(suppressMessages(
      TPD::TPDs(species = rep("unit", nrow(pts)), traits = pts,
                alpha = alpha, trait_ranges = trait_ranges,
                n_divisions = n_divisions)
    )),
    error = function(e) NULL
  )
  if (is.null(tpds)) return(NA_real_)

  samp <- matrix(1, nrow = 1, ncol = 1,
                 dimnames = list("community", "unit"))
  tpdc <- tryCatch(
    suppressWarnings(suppressMessages(TPD::TPDc(TPDs = tpds, sampUnit = samp))),
    error = function(e) NULL
  )
  if (is.null(tpdc)) return(NA_real_)

  rend <- tryCatch(
    suppressWarnings(suppressMessages(TPD::REND(TPDc = tpdc))),
    error = function(e) NULL
  )
  if (is.null(rend) || is.null(rend$communities$FRichness)) return(NA_real_)
  unname(rend$communities$FRichness[1])
}

#' @export
#' @rdname itv_proportion
itv_proportion.intrait_fishmorph_projection <- function(x, volume_dims = NULL,
                                                        metric = c("hull", "tpd"),
                                                        tpd_alpha = 0.99,
                                                        tpd_n_divisions = NULL, ...) {
  metric <- match.arg(metric)
  needed <- c("specimen_traits", "trait_ranges_reference",
              "scores_all", "global_scores_all")
  miss <- needed[!vapply(needed, function(nm) !is.null(x[[nm]]), logical(1))]
  if (length(miss) > 0) {
    stop("This projection predates itv_proportion(); recompute it with ",
         "project_fishmorph() (>= 1.7.0). Missing: ",
         paste(miss, collapse = ", "), call. = FALSE)
  }
  if (identical(metric, "tpd") && !requireNamespace("TPD", quietly = TRUE)) {
    stop("`metric = \"tpd\"` requires the (Suggested) 'TPD' package; ",
         "install it with install.packages(\"TPD\"), or use ",
         "`metric = \"hull\"`.", call. = FALSE)
  }
  if (identical(metric, "tpd")) {
    if (length(tpd_alpha) != 1 || !is.numeric(tpd_alpha) ||
        tpd_alpha <= 0 || tpd_alpha > 1) {
      stop("`tpd_alpha` must be a single number in (0, 1].", call. = FALSE)
    }
    if (!is.null(tpd_n_divisions) &&
        (length(tpd_n_divisions) != 1 || !is.numeric(tpd_n_divisions) ||
         tpd_n_divisions < 2)) {
      stop("`tpd_n_divisions` must be NULL or a single integer >= 2.",
           call. = FALSE)
    }
  }

  if (is.null(volume_dims)) {
    volume_dims <- if (is.null(x$volume_dims)) 2L else x$volume_dims
  }
  if (length(volume_dims) != 1 || !is.numeric(volume_dims) || volume_dims < 1) {
    stop("`volume_dims` must be a single integer >= 1.", call. = FALSE)
  }
  volume_dims <- as.integer(volume_dims)
  n_pc <- ncol(x$scores_all)
  if (volume_dims > n_pc) {
    stop("`volume_dims` (", volume_dims, ") exceeds the ", n_pc,
         " available principal component(s).", call. = FALSE)
  }

  traits <- x$traits
  Xsp    <- as.matrix(x$specimen_traits)[, traits, drop = FALSE]
  groups <- as.character(x$groups)
  ranges <- x$trait_ranges_reference
  glob_range <- stats::setNames(ranges$range, ranges$trait)[traits]

  ## -- per trait: pooled over all focal specimens --------------------------
  itv_range_pooled <- apply(Xsp, 2, function(v) diff(range(v)))
  trait_df <- data.frame(
    trait             = traits,
    global_range      = as.numeric(glob_range),
    itv_range_pooled  = as.numeric(itv_range_pooled[traits]),
    stringsAsFactors  = FALSE
  )
  trait_df$proportion_pooled <- trait_df$itv_range_pooled / trait_df$global_range
  rownames(trait_df) <- NULL

  ## -- per trait: species by species ---------------------------------------
  sp_levels <- levels(x$groups)
  trait_sp_rows <- list()
  for (g in sp_levels) {
    idx <- groups == g
    ng  <- sum(idx)
    rng <- apply(Xsp[idx, , drop = FALSE], 2, function(v) diff(range(v)))
    trait_sp_rows[[g]] <- data.frame(
      species    = g,
      trait      = traits,
      n          = ng,
      itv_range  = as.numeric(rng[traits]),
      proportion = as.numeric(rng[traits]) / as.numeric(glob_range),
      stringsAsFactors = FALSE
    )
  }
  trait_species_df <- do.call(rbind, trait_sp_rows)
  rownames(trait_species_df) <- NULL

  ## -- per functional volume (convex-hull OR TPD-FRichness ratio) ----------
  dims <- seq_len(volume_dims)
  Gref <- x$global_scores_all[, dims, drop = FALSE]
  Ssp  <- x$scores_all[, dims, drop = FALSE]

  if (identical(metric, "hull")) {
    # Extent-based functional richness: the convex-hull volume (Villeger,
    # Mason & Mouillot 2008). Sensitive to the outermost points only.
    vol_fun <- function(pts) .convex_hull_volume(pts)
  } else {
    # Density-based functional richness: TPD FRichness on a grid shared by
    # every unit, so the volumes (and their ratios) are comparable. The grid
    # spans the union of the reference and the projected specimens (so no
    # point falls outside it), padded by 15% of each axis' range for the KDE
    # tails; divisions per axis default to a value that keeps the grid cheap
    # as dimensionality grows.
    both <- rbind(Gref, Ssp)
    rng  <- apply(both, 2, range)
    pad  <- (rng[2, ] - rng[1, ]) * 0.15
    pad[!is.finite(pad) | pad <= 0] <- 1
    trait_ranges <- lapply(dims, function(j) {
      c(rng[1, j] - pad[j], rng[2, j] + pad[j])
    })
    # Fewer divisions per axis as dimensionality grows, so the total grid
    # (n_div ^ volume_dims cells) stays tractable: 1000 (1-D), 50 (2-D),
    # 25 (3-D), 12 (>= 4-D).
    n_div <- if (!is.null(tpd_n_divisions)) {
      as.integer(tpd_n_divisions)
    } else {
      c(1000L, 50L, 25L, 12L)[min(volume_dims, 4L)]
    }
    vol_fun <- function(pts) {
      .itv_tpd_richness(pts, trait_ranges = trait_ranges,
                        n_divisions = n_div, alpha = tpd_alpha)
    }
  }

  global_volume <- vol_fun(Gref)

  vol_rows <- list()
  vol_rows[["(all focal species)"]] <- data.frame(
    group      = "(all focal species)",
    n          = nrow(Ssp),
    volume     = vol_fun(Ssp),
    stringsAsFactors = FALSE
  )
  for (g in sp_levels) {
    idx <- groups == g
    vol_rows[[g]] <- data.frame(
      group  = g,
      n      = sum(idx),
      volume = vol_fun(Ssp[idx, , drop = FALSE]),
      stringsAsFactors = FALSE
    )
  }
  volume_df <- do.call(rbind, vol_rows)
  volume_df$proportion <- volume_df$volume / global_volume
  rownames(volume_df) <- NULL

  volume_scale <- if (identical(metric, "hull")) {
    "Functional volume is the convex-hull volume (extent-based; Villeger, Mason & Mouillot 2008)."
  } else {
    sprintf(paste0("Functional volume is the TPD FRichness (density-based; Carmona ",
                   "et al. 2019), alpha = %.3g, %d grid divisions/axis, shared grid."),
            tpd_alpha, n_div)
  }

  structure(
    list(
      trait         = trait_df,
      trait_species = trait_species_df,
      volume        = volume_df,
      global_volume = global_volume,
      volume_dims   = volume_dims,
      metric        = metric,
      scale = "Per-trait ranges are on the analysis scale used to build the projection (log10(x + 1) when log_transform = TRUE).",
      volume_scale = volume_scale
    ),
    class = "intrait_itv_proportion"
  )
}

#' Print an `"intrait_itv_proportion"` object
#'
#' @param x An object of class `"intrait_itv_proportion"`, from
#'   [itv_proportion()].
#' @param digits Integer, significant digits for the printed proportions.
#'   Defaults to `3`.
#' @param ... Currently unused.
#' @return Invisibly returns `x`.
#' @export
#' @rdname itv_proportion
print.intrait_itv_proportion <- function(x, digits = 3, ...) {
  pct <- function(p) ifelse(is.na(p), "  NA", sprintf("%5.1f%%", 100 * p))
  cat("<intrait_itv_proportion>\n")

  pooled <- x$volume[x$volume$group == "(all focal species)", , drop = FALSE]
  metric_label <- if (identical(x$metric, "tpd")) "TPD FRichness" else "convex hull"
  cat(sprintf("  Functional volume (%d-D %s): global reference = %.4g\n",
              x$volume_dims, metric_label, x$global_volume))
  if (nrow(pooled) == 1) {
    cat(sprintf("    ITV pooled over all focal species: %s of the global volume (n = %d)\n",
                trimws(pct(pooled$proportion)), pooled$n))
  }
  cat("\n  Per functional volume, by species:\n")
  vs <- x$volume[x$volume$group != "(all focal species)", , drop = FALSE]
  for (i in seq_len(nrow(vs))) {
    cat(sprintf("    %-28s %s  (n = %d)\n",
                vs$group[i], pct(vs$proportion[i]), vs$n[i]))
  }

  cat("\n  Per trait (ITV range / global range), pooled over all focal species:\n")
  tr <- x$trait
  for (i in seq_len(nrow(tr))) {
    cat(sprintf("    %-6s %s\n", tr$trait[i], pct(tr$proportion_pooled[i])))
  }
  cat(sprintf("    %-6s mean %s over %d traits\n", "",
              trimws(pct(mean(tr$proportion_pooled, na.rm = TRUE))), nrow(tr)))
  if (!is.null(x$volume_scale)) cat("\n  ", x$volume_scale, "\n", sep = "")
  cat("\n  ", x$scale, "\n", sep = "")
  invisible(x)
}
