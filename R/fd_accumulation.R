#' Rarefaction of community functional diversity indices against sampling effort
#'
#' Extends the individual-sampling rarefaction of [itv_accumulation()] from a
#' single per-species trait metric to **community-level functional diversity
#' indices**: it asks how many individuals must be sampled *per species*
#' before each functional diversity index of the assemblage stabilises. For
#' each sampling effort `n` (individuals per species), `n_perm` balanced
#' sub-samples of `n` individuals per species are drawn without replacement,
#' pooled into one assemblage, projected into a fixed trait space (a single
#' PCA computed once on all individuals, so indices stay comparable across
#' efforts, as in [bootstrap_functional_space()]), and every requested index
#' is recomputed. The draws are summarised by their mean and a resampling
#' quantile band.
#'
#' @details
#' Entities are **individuals** (so the indices are sensitive to intraspecific
#' variability), pooled into a single unweighted assemblage. Rarefaction is
#' *balanced*: only species with at least `min_n` complete individuals are
#' kept, and effort is capped at the smallest retained species' size, so every
#' species contributes exactly `n` individuals at every effort level and no
#' species-richness effect is confounded with sampling effort.
#'
#' As in [itv_accumulation()], the meaning of "stabilises" depends on the kind
#' of index:
#'
#' \describe{
#'   \item{**Accumulation index** (`"fric"`)}{Functional richness (the convex
#'     hull volume of the pooled individuals) genuinely rises with `n` and
#'     saturates. A Michaelis-Menten or negative-exponential model is fitted
#'     and `n*` is the effort reaching `asymptote_prop` of the fitted
#'     asymptote. A near-flat or ill-conditioned curve can send the fitted
#'     asymptote to implausible values; a fit whose asymptote exceeds
#'     `max_extrap_factor` times the observed maximum is rejected and reported
#'     as `"accumulation (no asymptote identified)"`, with the observed curve
#'     still returned.}
#'   \item{**Convergence indices** (`"fdis"`, `"rao"`, `"feve"`, `"fdiv"`)}{
#'     Dispersion / regularity indices are (near-)unbiased in expectation, so
#'     their mean is essentially flat and what stabilises is *precision*: `n*`
#'     is the smallest `n` beyond which the resampling band's relative
#'     half-width stays at or below `conv_tol`.}
#' }
#'
#' Index engines. `"fdis"` (functional dispersion, the mean distance of
#' individuals to their centroid; Laliberte & Legendre, 2010) and `"rao"`
#' (Rao's quadratic entropy, the mean pairwise distance; Botta-Dukat, 2005)
#' are computed directly. `"feve"` (functional evenness) and `"fdiv"`
#' (functional divergence; Villeger et al., 2008) are delegated to
#' [FD::dbFD()] and are only available when the (Suggested) `FD` package is
#' installed. `"fric"` is functional **richness**, and -- like
#' [bootstrap_functional_space()] -- how it is measured is controlled by
#' `method`: the convex-hull volume (`"convexhull"`, the default FRic of
#' Villeger et al., 2008), the total branch length of a UPGMA functional
#' dendrogram (`"dendrogram"`, Petchey & Gaston, 2002), the Trait Probability
#' Density richness (`"tpd"`, Carmona et al., 2019) or a Gaussian-kernel
#' hypervolume (`"hypervolume"`, Blonder et al., 2014). The kernel/grid used by
#' `"tpd"` and `"hypervolume"` is fixed once from the full individual set so
#' the richness stays comparable across efforts (as in
#' [bootstrap_functional_space()]). Requested but unavailable indices/methods
#' (missing Suggested package) are dropped with a message.
#'
#' The `n_perm` draws at each effort are independent and are distributed across
#' `future.apply`'s workers when that (Suggested) package is installed and a
#' parallel [future::plan()] is set, exactly as in
#' [bootstrap_functional_space()]; otherwise they run sequentially with
#' identical results.
#'
#' @param x Either an `"intrait_traitspace"` object (from [trait_space()],
#'   whose `scores` and `groups` are used) or a `data.frame`/matrix of numeric
#'   traits, one row per **individual**. Non-numeric columns are dropped with a
#'   warning.
#' @param groups Factor or character vector, one value per row of `x`
#'   (species). Required for a raw trait table; taken from `x$groups` for an
#'   `"intrait_traitspace"`. Rows with a missing group are dropped.
#' @param indices Character vector, any of `"fric"`, `"fdis"`, `"rao"`,
#'   `"feve"`, `"fdiv"`. Defaults to `c("fric", "fdis", "rao")`. `"feve"`/
#'   `"fdiv"` require the Suggested `FD` package; `"fric"` uses `method`.
#' @param method Character, how functional richness (`"fric"`) is measured:
#'   `"convexhull"` (default, requires Suggested `geometry`), `"dendrogram"`
#'   (no extra package), `"tpd"` (requires Suggested `TPD`) or `"hypervolume"`
#'   (requires Suggested `hypervolume`). Ignored when `"fric"` is not among
#'   `indices`. See [bootstrap_functional_space()] for the measures.
#' @param dendrogram_linkage,tpd_alpha,tpd_bw_factor,tpd_n_divisions,hv_bw_method,hv_samples_per_point
#'   Method-specific tuning for `"fric"`, passed through to the shared
#'   richness machinery exactly as in [bootstrap_functional_space()]; each is
#'   ignored by the methods that do not use it.
#' @param n_perm Integer, sub-samples drawn per effort level. Defaults to `99`.
#' @param min_n Integer, minimum individuals for a species to be retained;
#'   effort is capped at the smallest retained species' size. Defaults to `10`.
#' @param n_axes,var_threshold Definition of the fixed trait space, built
#'   exactly as in [trait_space()] / [bootstrap_functional_space()] (the same
#'   internal machinery): the traits are optionally log-transformed and
#'   scaled, constant columns dropped, and a PCA is run once on all
#'   individuals. `n_axes` is the number of PCA axes retained; if `NULL`
#'   (default) the smallest number of axes reaching `var_threshold`
#'   (default `0.98`) cumulative variance is chosen automatically. Keep
#'   `n_axes` small (e.g. `2`) for `method = "tpd"`/`"hypervolume"`, whose
#'   kernels are only tractable in a few dimensions.
#' @param conv_tol Numeric in (0, 1), precision tolerance for convergence
#'   indices. Defaults to `0.05`.
#' @param asymptote_prop Numeric in (0, 1), asymptote fraction defining `n*`
#'   for `"fric"`. Defaults to `0.95`.
#' @param model `"michaelis"` (default) or `"exponential"`, the saturating
#'   model for `"fric"`.
#' @param max_extrap_factor Numeric > 1, reject a fitted `"fric"` asymptote
#'   greater than this multiple of the observed maximum. Defaults to `5`.
#' @param probs Length-2 lower/upper probabilities for the resampling band.
#'   Defaults to `c(0.025, 0.975)`.
#' @param log_transform,scale Preprocessing of a raw trait table, as in
#'   [trait_space()]: `log_transform` applies `log10(x + 1)`; `scale`
#'   standardises each trait before the PCA. Ignored for an
#'   `"intrait_traitspace"`. Default `FALSE` and `TRUE`.
#' @param seed Optional integer for [set.seed()]. Defaults to `NULL`.
#'
#' @return An object of class `"intrait_fd_accumulation"`, a list with:
#'   \describe{
#'     \item{curve}{a `data.frame` with columns `index`, `n`, `mean`, `lower`,
#'       `upper`.}
#'     \item{summary}{a `data.frame`, one row per index, with `index`,
#'       `framing`, `v_full`, `asymptote`, `prop_reached`, `k`, `n_star`.}
#'     \item{indices, method, n_perm, n_axes, n_species, n_cap, conv_tol,
#'       asymptote_prop, model, probs}{settings used.}
#'   }
#'   Has `print()` and `plot()` methods.
#'
#' @references
#' Villeger, S., Mason, N. W. H., & Mouillot, D. (2008). New multidimensional
#' functional diversity indices for a multifaceted framework in functional
#' ecology. Ecology, 89(8), 2290-2301.
#'
#' Laliberte, E., & Legendre, P. (2010). A distance-based framework for
#' measuring functional diversity from multiple traits. Ecology, 91(1),
#' 299-305.
#'
#' Botta-Dukat, Z. (2005). Rao's quadratic entropy as a measure of functional
#' diversity based on multiple traits. Journal of Vegetation Science, 16(5),
#' 533-540.
#'
#' @seealso [itv_accumulation()], [bootstrap_functional_space()],
#'   [trait_disparity()], [trait_space()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 25, n_replicates = 1)
#' ratios <- fishmorph_ratios(fishmorph_segments(fish))
#' \donttest{
#' acc <- fd_accumulation(
#'   ratios[, c("BEl", "VEp", "REs", "OGp")],
#'   groups = fish$metadata$species,
#'   indices = c("fric", "fdis", "rao"), n_perm = 30, min_n = 10, seed = 1
#' )
#' acc
#' plot(acc)
#' }
#'
#' @export
fd_accumulation <- function(x, groups = NULL,
                            indices = c("fric", "fdis", "rao"),
                            method = c("convexhull", "dendrogram", "tpd", "hypervolume"),
                            n_perm = 99, min_n = 10, n_axes = NULL, var_threshold = 0.98,
                            conv_tol = 0.05, asymptote_prop = 0.95,
                            model = c("michaelis", "exponential"),
                            max_extrap_factor = 5,
                            probs = c(0.025, 0.975),
                            dendrogram_linkage = "average",
                            tpd_alpha = 0.95, tpd_bw_factor = 0.5,
                            tpd_n_divisions = NULL,
                            hv_bw_method = "silverman", hv_samples_per_point = 500,
                            log_transform = FALSE, scale = TRUE, seed = NULL) {
  allowed <- c("fric", "fdis", "rao", "feve", "fdiv")
  indices <- match.arg(indices, allowed, several.ok = TRUE)
  method <- match.arg(method)
  model <- match.arg(model)
  if (!is.numeric(n_perm) || length(n_perm) != 1 || n_perm < 1) {
    stop("`n_perm` must be a single positive integer.", call. = FALSE)
  }
  n_perm <- as.integer(n_perm)
  if (!is.numeric(conv_tol) || conv_tol <= 0 || conv_tol >= 1) {
    stop("`conv_tol` must be a single number in (0, 1).", call. = FALSE)
  }
  if (!is.numeric(asymptote_prop) || asymptote_prop <= 0 || asymptote_prop >= 1) {
    stop("`asymptote_prop` must be a single number in (0, 1).", call. = FALSE)
  }
  if (!is.numeric(probs) || length(probs) != 2 || probs[1] >= probs[2]) {
    stop("`probs` must be two increasing probabilities.", call. = FALSE)
  }
  if (!is.null(seed)) set.seed(seed)

  # -- fixed trait space: built exactly as in trait_space() --------------------
  # Shared helper (also used by bootstrap_functional_space() /
  # species_sensitivity()): accepts an "intrait_traitspace" or a raw trait
  # table + groups, applies the same log_transform/scale/constant-column
  # handling, runs one PCA on all individuals, and selects n_axes (auto via
  # var_threshold when NULL). Guarantees the same ordination conventions as
  # the rest of the package. NB: we pass method = "dendrogram" to relax the
  # helper's convex-hull dimensionality check, which counts *species* (right
  # for bootstrap_functional_space(), where each species is one point) but is
  # inappropriate here, where the hull is over pooled *individuals*; per-effort
  # FRic feasibility is instead handled by the richness engine's own NA guard.
  fs <- .fspace_pca_scores(
    x, groups, n_axes = n_axes, var_threshold = var_threshold,
    log_transform = log_transform, scale = scale, method = "dendrogram"
  )
  scores <- fs$scores
  groups <- fs$groups
  n_axes <- fs$n_axes
  rownames(scores) <- paste0("ind_", seq_len(nrow(scores)))  # unique entity ids

  # -- balanced rarefaction set-up --------------------------------------------
  tab <- table(groups)
  keep_sp <- names(tab)[tab >= min_n]
  if (length(keep_sp) < 3) {
    stop("Fewer than 3 species have >= `min_n` individuals; lower `min_n`.", call. = FALSE)
  }
  sel <- groups %in% keep_sp
  scores <- scores[sel, , drop = FALSE]
  groups <- droplevels(groups[sel])
  n_cap <- min(table(groups))
  if (n_cap < 2) stop("Retained species have too few individuals to rarefy.", call. = FALSE)
  n_species <- nlevels(groups)
  message(sprintf(
    "Rarefying %d species, effort n = 2..%d individuals/species, in %d PCA axes.",
    n_species, n_cap, n_axes
  ))

  # -- which engines are usable ------------------------------------------------
  need_fd <- any(c("feve", "fdiv") %in% indices)
  if (need_fd && !requireNamespace("FD", quietly = TRUE)) {
    message("`FD` package not installed: dropping \"feve\"/\"fdiv\".")
    indices <- setdiff(indices, c("feve", "fdiv"))
    need_fd <- FALSE
  }
  # `"fric"` uses `method`; each method needs its own (Suggested) package.
  method_pkg <- c(convexhull = "geometry", dendrogram = NA,
                  tpd = "TPD", hypervolume = "hypervolume")[[method]]
  if ("fric" %in% indices && !is.na(method_pkg) &&
      !requireNamespace(method_pkg, quietly = TRUE)) {
    message(sprintf("`%s` package not installed: dropping \"fric\" (method = \"%s\").",
                    method_pkg, method))
    indices <- setdiff(indices, "fric")
  }
  if (length(indices) == 0) stop("No requested index can be computed (missing Suggested packages).", call. = FALSE)

  # shared richness setup (kernel bandwidth / grid), computed once from the
  # full retained scores so richness stays comparable across efforts
  aux <- if ("fric" %in% indices) {
    .fspace_richness_setup(scores, method,
                           dendrogram_linkage = dendrogram_linkage,
                           tpd_alpha = tpd_alpha, tpd_bw_factor = tpd_bw_factor,
                           tpd_n_divisions = tpd_n_divisions,
                           hv_bw_method = hv_bw_method,
                           hv_samples_per_point = hv_samples_per_point)
  } else NULL

  idx_fun <- .fd_index_fun(indices, need_fd, method, aux)
  n_ind <- length(indices)

  # -- rarefaction driver ------------------------------------------------------
  lv <- levels(groups)
  idx_by_sp <- lapply(lv, function(g) which(groups == g))
  efforts <- 2:n_cap

  means <- matrix(NA_real_, length(efforts), n_ind, dimnames = list(NULL, indices))
  lower <- means; upper <- means
  for (i in seq_along(efforts)) {
    n <- efforts[i]
    draws <- .papply(seq_len(n_perm), function(b) {
      sel_i <- unlist(lapply(idx_by_sp, function(ig) sample(ig, n)))
      idx_fun(scores[sel_i, , drop = FALSE], groups[sel_i])
    }, numeric(n_ind))
    draws <- matrix(draws, nrow = n_ind, ncol = n_perm)  # index x perm
    means[i, ] <- rowMeans(draws, na.rm = TRUE)
    lower[i, ] <- apply(draws, 1, stats::quantile, probs = probs[1], na.rm = TRUE)
    upper[i, ] <- apply(draws, 1, stats::quantile, probs = probs[2], na.rm = TRUE)
  }

  # -- curve + n* per index ----------------------------------------------------
  accumulation <- "fric"
  curve_rows <- list()
  summary_rows <- list()
  for (j in seq_len(n_ind)) {
    idx <- indices[j]
    m_j <- means[, j]
    curve_rows[[j]] <- data.frame(
      index = idx, n = efforts, mean = m_j, lower = lower[, j], upper = upper[, j],
      stringsAsFactors = FALSE
    )
    v_full <- m_j[length(m_j)]
    framing <- NA_character_; asymptote <- NA_real_; prop_reached <- NA_real_
    k <- NA_real_; n_star <- NA_real_

    if (idx %in% accumulation) {
      fit <- .itv_saturating_fit(efforts, m_j, model, asymptote_prop)
      obs_max <- max(m_j, na.rm = TRUE)
      if (is.finite(fit$asymptote) && fit$asymptote <= max_extrap_factor * obs_max) {
        framing <- "accumulation"
        asymptote <- fit$asymptote; k <- fit$k; n_star <- fit$n_star
        prop_reached <- v_full / fit$asymptote
      } else {
        framing <- "accumulation (no asymptote identified)"
      }
    } else {
      framing <- "convergence"
      n_star <- .itv_convergence_n(efforts, lower[, j], upper[, j], v_full, conv_tol)
    }
    summary_rows[[j]] <- data.frame(
      index = idx, framing = framing, v_full = v_full, asymptote = asymptote,
      prop_reached = prop_reached, k = k, n_star = n_star, stringsAsFactors = FALSE
    )
  }

  structure(
    list(
      curve = do.call(rbind, curve_rows),
      summary = do.call(rbind, summary_rows),
      indices = indices, method = method, n_perm = n_perm, n_axes = n_axes,
      n_species = n_species, n_cap = n_cap, conv_tol = conv_tol,
      asymptote_prop = asymptote_prop, model = model, probs = probs
    ),
    class = "intrait_fd_accumulation"
  )
}

#' Build a function returning the requested functional diversity indices for a
#' pooled individual cloud
#'
#' @param indices Character vector of requested index codes.
#' @param need_fd Logical, whether `"feve"`/`"fdiv"` (via `FD::dbFD()`) are
#'   needed.
#' @param method How `"fric"` (functional richness) is measured; passed to
#'   `.fspace_richness()`.
#' @param aux The shared richness setup from `.fspace_richness_setup()`.
#' @return A function `(P, labels)` returning a named numeric vector aligned
#'   with `indices`.
#' @noRd
.fd_index_fun <- function(indices, need_fd, method, aux) {
  function(P, labels) {
    out <- stats::setNames(rep(NA_real_, length(indices)), indices)
    m <- nrow(P)

    if ("fdis" %in% indices) {
      cen <- colMeans(P)
      out["fdis"] <- mean(sqrt(rowSums(sweep(P, 2, cen)^2)))
    }
    if ("rao" %in% indices) {
      Dm <- as.matrix(stats::dist(P))
      out["rao"] <- sum(Dm) / (m * m)         # equal weights: (1/m^2) sum_ij d_ij
    }
    if ("fric" %in% indices) {
      # functional richness by the chosen method (convex hull / dendrogram /
      # TPD / hypervolume), reusing the shared machinery of
      # bootstrap_functional_space()
      out["fric"] <- tryCatch(.fspace_richness(P, method, aux), error = function(e) NA_real_)
    }
    if (need_fd && any(c("feve", "fdiv") %in% indices)) {
      a <- matrix(1, nrow = 1, ncol = m, dimnames = list("comm", rownames(P)))
      fd <- tryCatch(suppressWarnings(suppressMessages(
        FD::dbFD(stats::dist(P), a = a, calc.FRic = FALSE, calc.FDiv = ("fdiv" %in% indices),
                 calc.CWM = FALSE, messages = FALSE)
      )), error = function(e) NULL)
      if (!is.null(fd)) {
        if ("feve" %in% indices) out["feve"] <- unname(fd$FEve)
        if ("fdiv" %in% indices && !is.null(fd$FDiv)) out["fdiv"] <- unname(fd$FDiv)
      }
    }
    out
  }
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname fd_accumulation
#' @param x An object of class `"intrait_fd_accumulation"`.
#' @param ... Currently unused.
print.intrait_fd_accumulation <- function(x, ...) {
  cat("<intrait_fd_accumulation>\n")
  cat(sprintf(
    "  %d index/indices on %d species, effort n = 2..%d, %d permutation(s)\n",
    length(x$indices), x$n_species, x$n_cap, x$n_perm
  ))
  if ("fric" %in% x$indices) cat(sprintf("  functional richness method = %s\n", x$method))
  disp <- x$summary
  disp[c("v_full", "asymptote", "prop_reached", "k")] <-
    lapply(disp[c("v_full", "asymptote", "prop_reached", "k")], function(v) round(v, 4))
  cat("\n-- Stabilisation effort n* per index --\n")
  print(disp, row.names = FALSE)
  invisible(x)
}

#' Plot functional-diversity rarefaction curves
#'
#' One panel per index: the resampling mean against sampling effort (with the
#' quantile band as a shaded envelope), the stabilisation effort `n*` as a
#' vertical dashed line, and -- for the accumulation index -- the fitted
#' asymptote (dotted) with its dashed extrapolation, or -- for convergence
#' indices -- a dotted reference line at the full-effort value.
#'
#' @param x An object of class `"intrait_fd_accumulation"`.
#' @param indices Optional character vector selecting which indices to draw.
#' @param band Logical, draw the resampling band. Defaults to `TRUE`.
#' @param extrapolate Logical, extend the fitted accumulation curve to `n*`.
#'   Defaults to `TRUE`.
#' @param ... Passed to [graphics::plot()].
#' @return Invisibly returns `x`.
#' @export
plot.intrait_fd_accumulation <- function(x, indices = NULL, band = TRUE,
                                         extrapolate = TRUE, ...) {
  cur <- x$curve
  all_idx <- unique(cur$index)
  if (!is.null(indices)) {
    all_idx <- intersect(indices, all_idx)
    if (length(all_idx) == 0) stop("None of `indices` match the computed indices.", call. = FALSE)
  }
  labels <- c(fric = sprintf("Functional richness (%s)", x$method),
              fdis = "Functional dispersion (FDis)",
              rao = "Rao's quadratic entropy", feve = "Functional evenness (FEve)",
              fdiv = "Functional divergence (FDiv)")

  n_panel <- length(all_idx)
  nc <- ceiling(sqrt(n_panel)); nr <- ceiling(n_panel / nc)
  op <- graphics::par(mfrow = c(nr, nc), mar = c(4, 4, 2.5, 1))
  on.exit(graphics::par(op), add = TRUE)

  for (id in all_idx) {
    ci <- cur[cur$index == id, , drop = FALSE]
    row <- x$summary[x$summary$index == id, , drop = FALSE]
    is_acc <- startsWith(row$framing, "accumulation")
    has_asy <- is_acc && is.finite(row$asymptote)
    n_max <- max(ci$n)
    xmax <- if (has_asy && is.finite(row$n_star)) min(row$n_star, 10 * n_max) else n_max

    yv <- if (isTRUE(band)) c(ci$lower, ci$upper) else ci$mean
    if (has_asy) yv <- c(yv, row$asymptote)
    graphics::plot(NA, xlim = c(min(ci$n), xmax), ylim = range(yv, na.rm = TRUE),
                   xlab = "Individuals per species (n)",
                   ylab = if (!is.na(labels[id])) labels[id] else id, main = id, ...)
    if (isTRUE(band)) {
      graphics::polygon(c(ci$n, rev(ci$n)), c(ci$lower, rev(ci$upper)),
                        col = grDevices::adjustcolor("#276a76", 0.2), border = NA)
    }
    graphics::lines(ci$n, ci$mean, col = "#276a76", lwd = 2)

    if (is_acc) {
      if (has_asy) graphics::abline(h = row$asymptote, lty = 3)
      if (isTRUE(extrapolate) && has_asy && is.finite(row$k) && xmax > n_max) {
        nseq <- seq(n_max, xmax, length.out = 100)
        graphics::lines(nseq, .itv_fitted_curve(nseq, x$model, row$asymptote, row$k),
                        col = "#276a76", lty = 2, lwd = 2)
      }
    } else if (is.finite(row$v_full)) {
      graphics::abline(h = row$v_full, lty = 3)
    }
    if (is.finite(row$n_star) && row$n_star <= xmax) graphics::abline(v = row$n_star, lty = 2)
  }
  invisible(x)
}
