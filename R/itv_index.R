#' Partition trait variance into interspecific and intraspecific (ITV) components
#'
#' Decomposes the total variance of one or more numeric traits into an
#' interspecific (between-group, e.g. between-species) component and an
#' intraspecific trait variability (ITV, within-group) component, following
#' the variance-partitioning approach reviewed by Violle et al. (2012) and
#' de Bello et al. (2011). Optionally splits the ITV component further into
#' a between-population (within-species) and a within-population (residual)
#' part when a finer, nested grouping factor is supplied, following the
#' within-/among-population distinction used in ITV meta-analyses (e.g.
#' Siefert et al., 2015).
#'
#' @param traits A `data.frame` or matrix of numeric traits, one row per
#'   **individual** observation. Unlike [trait_space()], `traits` must not
#'   already be averaged to group (e.g. species) means: ITV is, by
#'   definition, the variability *within* groups, and cannot be estimated
#'   once individuals have been collapsed to a single value per group.
#'   Non-numeric columns are dropped with a warning.
#' @param groups Factor or character vector, one value per row of
#'   `traits`: the coarser, interspecific grouping variable (typically
#'   species). Must have at least two levels.
#' @param nested Optional factor or character vector, one value per row of
#'   `traits`: a finer grouping variable nested *within* `groups`
#'   (typically population or site), used to split the ITV component into
#'   a between-population and a within-population (residual) part. Levels
#'   of `nested` do not need to be globally unique: labels such as
#'   `"Pop_1"`/`"Pop_2"` may be (and commonly are) reused identically
#'   across different levels of `groups` — each *combination* of `groups`
#'   and `nested` is treated as a distinct population, exactly as the
#'   nesting operator in `aov(y ~ Error(species/population))` would.
#' @param scale Logical, standardise (z-score) each numeric trait before
#'   combining sums of squares across traits in the multivariate summary
#'   (see Details). Does not affect the per-trait percentages, which are
#'   invariant to linear rescaling of each trait on its own. Defaults to
#'   `TRUE`.
#' @param digits Integer, number of decimal places to round percentages
#'   and sums of squares to in the returned tables. Defaults to `4`.
#'
#' @return An object of class `"intrait_itv"`, a list with elements:
#'   \describe{
#'     \item{per_trait}{a `data.frame`, one row per numeric trait, with
#'       columns `trait`, `ss_total`, `ss_between` (interspecific),
#'       `ss_within` (intraspecific/ITV) — plus `ss_population` and
#'       `ss_residual` if `nested` is supplied — and the corresponding
#'       percentages `pct_interspecific`, `pct_itv` (and
#'       `pct_itv_between_pop`, `pct_itv_within_pop` if `nested` is
#'       supplied).}
#'     \item{multivariate}{a one-row `data.frame` with the same columns,
#'       summed across all (optionally standardised) traits, summarising
#'       the overall balance of interspecific vs. intraspecific
#'       variability across the whole trait set.}
#'     \item{groups, nested, scale, traits_used}{the grouping factors,
#'       the `scale` setting, and the numeric trait columns used.}
#'   }
#'   Has a dedicated print method and a [plot()] method (stacked bar chart
#'   of percent interspecific vs. intraspecific variance per trait).
#'
#' @details
#' For a single grouping level, this is the classical one-way ANOVA
#' sum-of-squares identity \eqn{SS_{total} = SS_{between} + SS_{within}},
#' with \eqn{\%ITV = 100 \times SS_{within} / SS_{total}}: the percentage
#' of total trait variance that lies *within* groups rather than *between*
#' them (Violle et al., 2012). When `nested` is supplied, the within-group
#' sum of squares is itself decomposed exactly (for any, including
#' unbalanced, design) into a between-population-within-species term and a
#' within-population residual term, following the same orthogonal
#' sum-of-squares identity one level down; this holds exactly regardless
#' of group-size imbalance.
#'
#' Per-trait percentages are invariant to how each trait is individually
#' rescaled (multiplying a trait by a constant scales `ss_total` and
#' `ss_within` by the same factor, leaving their ratio unchanged), so
#' `scale` has no effect on `per_trait`. It matters only for
#' `multivariate`, where sums of squares from traits with different units
#' and raw variances are added together: without standardising first, a
#' trait with a larger raw variance would dominate the aggregate
#' regardless of its actual relative ITV, which is rarely the intended
#' comparison.
#'
#' A within-group sum of squares of (near) zero for every trait indicates
#' that `groups` has essentially no replication (e.g. exactly one
#' observation per species); in that case ITV cannot be estimated, and a
#' warning is issued.
#'
#' @references
#' Violle, C., Enquist, B. J., McGill, B. J., Jiang, L., Albert, C. H.,
#' Hulshof, C., Jung, V., & Messier, J. (2012). The return of the
#' variance: intraspecific variability in community ecology. Trends in
#' Ecology & Evolution, 27(4), 244-252.
#'
#' de Bello, F., Lavorel, S., Albert, C. H., Thuiller, W., Grigulis, K.,
#' Dolezal, J., Janecek, S., & Leps, J. (2011). Quantifying the relative
#' importance of intraspecific trait variability and interspecific trait
#' turnover for functional diversity. Methods in Ecology and Evolution,
#' 2(2), 163-174.
#'
#' Siefert, A., Violle, C., Chalmandrier, L., et al. (2015). A global
#' meta-analysis of the relative extent of intraspecific trait variation
#' in plant communities. Ecology Letters, 18(12), 1406-1419.
#'
#' @seealso [trait_disparity()], [intraspecific_variability()],
#'   [trait_space()]
#'
#' @examples
#' # real T-26 Saudrune data; itv_index() requires complete cases, unlike
#' # trait_space()'s na_action, so incomplete rows are filtered explicitly
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' complete <- stats::complete.cases(ratios[, c("BEl", "VEp", "REs")])
#' itv <- itv_index(
#'   ratios[complete, c("BEl", "VEp", "REs")],
#'   groups = fish$metadata$species[complete]
#' )
#' itv
#'
#' # split ITV into between-/within-population components: the real T-26
#' # survey sampled a single site (no population structure to report), so
#' # the nested = argument is illustrated here on simulated data instead
#' fish_sim <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
#' segments_sim <- fishmorph_segments(fish_sim)
#' ratios_sim <- fishmorph_ratios(segments_sim)
#' itv_nested <- itv_index(
#'   ratios_sim[, c("BEl", "VEp", "REs")],
#'   groups = fish_sim$metadata$species,
#'   nested = fish_sim$metadata$population
#' )
#' itv_nested
#'
#' @export
itv_index <- function(traits, groups, nested = NULL, scale = TRUE, digits = 4) {
  if (missing(groups)) {
    stop("`groups` is required: the interspecific grouping factor (e.g. species).", call. = FALSE)
  }
  if (!is.data.frame(traits) && !is.matrix(traits)) {
    stop("`traits` must be a data.frame or matrix of numeric trait values.", call. = FALSE)
  }
  traits_df <- as.data.frame(traits)

  numeric_cols <- names(traits_df)[vapply(traits_df, is.numeric, logical(1))]
  dropped <- setdiff(names(traits_df), numeric_cols)
  if (length(numeric_cols) == 0) stop("`traits` must contain at least one numeric column.", call. = FALSE)
  if (length(dropped) > 0) {
    warning("Dropping non-numeric column(s): ", paste(dropped, collapse = ", "), call. = FALSE)
  }

  X <- as.matrix(traits_df[numeric_cols])
  if (anyNA(X)) {
    stop(
      "`traits` contains missing values; see the `na_action` argument of ",
      "trait_space() for ways to handle them before calling itv_index().",
      call. = FALSE
    )
  }

  if (length(groups) != nrow(X)) stop("`groups` must have one entry per row of `traits`.", call. = FALSE)
  groups <- factor(groups)
  if (anyNA(groups)) {
    keep_g <- !is.na(groups)
    message(sprintf(
      paste(
        "Removing %d row(s) with a missing/unresolved `groups` value (e.g. an",
        "unidentified specimen) before computing the interspecific/intraspecific",
        "variance decomposition."
      ),
      sum(!keep_g)
    ))
    X <- X[keep_g, , drop = FALSE]
    groups <- droplevels(groups[keep_g])
    if (!is.null(nested)) nested <- nested[keep_g]
  }
  if (nlevels(groups) < 2) stop("`groups` must have at least two levels.", call. = FALSE)

  has_nested <- !is.null(nested)
  if (has_nested) {
    if (length(nested) != nrow(X)) stop("`nested` must have one entry per row of `traits`.", call. = FALSE)
    # `nested` levels need not be globally unique: it is common (and, e.g.,
    # the case for the `population` column produced by
    # simulate_fish_landmarks()/simulate_fishmorph_points()) for population
    # labels such as "Pop_1"/"Pop_2" to be reused identically across
    # species. Each *combination* of `groups` and `nested` is therefore
    # treated as a distinct population, exactly as the nesting operator in
    # `aov(y ~ Error(species/population))` would; this makes `nested`
    # nested within `groups` by construction, so no separate validity
    # check is required.
    nested <- factor(interaction(groups, nested, drop = TRUE, sep = " / "))
  }

  if (all(table(groups) == 1)) {
    warning(
      "Every level of `groups` has exactly one observation; intraspecific ",
      "(within-group) variability cannot be estimated without replication.",
      call. = FALSE
    )
  }

  decompose <- function(x) {
    grand_mean <- mean(x)
    gm <- stats::ave(x, groups)
    ss_total <- sum((x - grand_mean)^2)
    ss_between <- sum((gm - grand_mean)^2)
    if (has_nested) {
      pm <- stats::ave(x, nested)
      ss_population <- sum((pm - gm)^2)
      ss_residual <- sum((x - pm)^2)
      ss_within <- ss_population + ss_residual
      c(ss_total = ss_total, ss_between = ss_between,
        ss_population = ss_population, ss_residual = ss_residual,
        ss_within = ss_within)
    } else {
      ss_within <- sum((x - gm)^2)
      c(ss_total = ss_total, ss_between = ss_between, ss_within = ss_within)
    }
  }

  ss_list <- lapply(numeric_cols, function(nm) decompose(X[, nm]))
  names(ss_list) <- numeric_cols
  ss_mat <- do.call(rbind, ss_list)

  pct <- function(ss_mat) {
    out <- data.frame(
      pct_interspecific = ss_mat[, "ss_between"] / ss_mat[, "ss_total"] * 100,
      pct_itv = ss_mat[, "ss_within"] / ss_mat[, "ss_total"] * 100
    )
    if (has_nested) {
      out$pct_itv_between_pop <- ss_mat[, "ss_population"] / ss_mat[, "ss_total"] * 100
      out$pct_itv_within_pop <- ss_mat[, "ss_residual"] / ss_mat[, "ss_total"] * 100
    }
    out
  }

  per_trait <- cbind(
    data.frame(trait = numeric_cols, stringsAsFactors = FALSE),
    round(as.data.frame(ss_mat), digits),
    round(pct(ss_mat), digits)
  )
  rownames(per_trait) <- NULL

  # Multivariate summary: optionally standardise each trait to unit
  # variance first, so traits with different units/raw variances
  # contribute comparably to the aggregate sums of squares.
  X_mv <- if (isTRUE(scale)) scale(X, center = TRUE, scale = TRUE) else X
  ss_list_mv <- lapply(numeric_cols, function(nm) decompose(X_mv[, nm]))
  ss_mat_mv <- do.call(rbind, ss_list_mv)
  ss_mv_sum <- colSums(ss_mat_mv)

  multivariate <- cbind(
    round(as.data.frame(t(ss_mv_sum)), digits),
    round(pct(matrix(ss_mv_sum, nrow = 1, dimnames = list(NULL, names(ss_mv_sum)))), digits)
  )

  structure(
    list(
      per_trait = per_trait,
      multivariate = multivariate,
      groups = groups,
      nested = nested,
      scale = scale,
      traits_used = numeric_cols
    ),
    class = "intrait_itv"
  )
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname itv_index
#' @param x An object of class `"intrait_itv"`, as returned by [itv_index()].
print.intrait_itv <- function(x, ...) {
  cat("<intrait_itv>", if (!is.null(x$nested)) "(nested: species / population)" else "(species-level)", "\n")
  cat(sprintf(
    "  %d trait(s), %d groups%s\n",
    length(x$traits_used), nlevels(x$groups),
    if (!is.null(x$nested)) sprintf(", %d nested levels", nlevels(x$nested)) else ""
  ))
  cat("\n-- Per trait --\n")
  print(x$per_trait, row.names = FALSE)
  cat("\n-- Multivariate summary", if (isTRUE(x$scale)) "(standardised traits)" else "(raw traits)", "--\n")
  print(x$multivariate, row.names = FALSE)
  invisible(x)
}

#' Plot the interspecific/intraspecific variance breakdown
#'
#' @param x An object of class `"intrait_itv"`, from [itv_index()].
#' @param legend_position One of `"outside"` (default: drawn in the
#'   margin, just outside the top-right corner of the plot box, so it
#'   never overlaps the tallest bars) or a standard [graphics::legend()]
#'   position keyword (e.g. `"topright"`) to draw it inside the plot box
#'   instead, as in previous versions.
#' @param ... Further arguments passed to [graphics::barplot()].
#'
#' @return Invisibly returns `x`.
#' @export
plot.intrait_itv <- function(x, legend_position = "outside", ...) {
  pt <- x$per_trait
  if (!is.null(x$nested)) {
    mat <- rbind(
      interspecific = pt$pct_interspecific,
      itv_between_pop = pt$pct_itv_between_pop,
      itv_within_pop = pt$pct_itv_within_pop
    )
    cols <- c("#1b9e77", "#7570b3", "#d95f02")
    legend_labels <- c("Interspecific", "ITV (between population)", "ITV (within population)")
  } else {
    mat <- rbind(
      interspecific = pt$pct_interspecific,
      itv = pt$pct_itv
    )
    cols <- c("#1b9e77", "#d95f02")
    legend_labels <- c("Interspecific", "Intraspecific (ITV)")
  }
  colnames(mat) <- pt$trait

  if (identical(legend_position, "outside")) {
    # Reserve extra room in the right margin so the legend sits just
    # outside the bars instead of on top of whichever trait happens to
    # reach 100% near the top-right corner; barplot()'s args.legend draws
    # the legend internally (after the bars, so par("usr") is by then
    # already correct), so a keyword position + negative inset is the
    # standard way to push it fully outside the plot box.
    old_par <- graphics::par(mar = graphics::par("mar") + c(0, 0, 0, 9))
    on.exit(graphics::par(old_par), add = TRUE)
    args_legend <- list(x = "topright", inset = c(-0.32, 0), xpd = TRUE, bty = "n", cex = 0.8)
  } else {
    args_legend <- list(x = legend_position, bty = "n", cex = 0.8)
  }

  graphics::barplot(
    mat, col = cols, ylab = "% of trait variance", ylim = c(0, 100),
    legend.text = legend_labels,
    args.legend = args_legend,
    ...
  )
  invisible(x)
}
