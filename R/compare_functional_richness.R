#' Compare bootstrap-based functional richness estimates across methods
#'
#' Runs [bootstrap_functional_space()] once per requested `method`
#' (`"convexhull"`, `"dendrogram"`, `"tpd"`, `"hypervolume"`) on the same
#' data, and tabulates the results side by side. Convex-hull volume,
#' dendrogram branch length, TPD richness, and hypervolume are not on the
#' same scale, so raw `fd_ref`/`fd_boot_mean` values are not directly
#' comparable across rows; what *is* comparable is whether each method
#' agrees, qualitatively, that individual-based richness exceeds the
#' centroid-based reference, and by roughly how much in relative
#' (percentage) terms -- exactly the triangulation this function is for.
#'
#' @param x,groups,n_axes,var_threshold,n_boot,log_transform,scale As in
#'   [bootstrap_functional_space()].
#' @param methods Character vector, one or more of `"convexhull"`,
#'   `"dendrogram"`, `"tpd"`, `"hypervolume"` (see
#'   [bootstrap_functional_space()] for what each measures). Defaults to
#'   all four. A method whose Suggested package is not installed, or that
#'   errors for any other reason (e.g. `n_axes` too large for
#'   `"convexhull"`'s affine-independence requirement), is not fatal: it
#'   is recorded as `status != "ok"` in `$summary` with `NA` numeric
#'   columns, and the comparison proceeds with the remaining methods.
#' @param alpha Numeric, the significance threshold used to flag
#'   `$summary$significant` and summarised in `print()`. Defaults to
#'   `0.05`. Purely a display/summary convenience: the underlying
#'   `p_value` for each method is always reported in full.
#' @param seed Optional single integer. If supplied, `set.seed(seed)` is
#'   called immediately before *each* method's [bootstrap_functional_space()]
#'   call, so every method draws the same sequence of one-individual-per-
#'   species bootstrap "communities" (community 1 is the same draw under
#'   every method, community 2 the same under every method, and so on) --
#'   useful if you want the per-draw richness values to be directly
#'   paired across methods (e.g. to correlate them), rather than merely
#'   comparing summary statistics. Defaults to `NULL` (no explicit
#'   seeding; each method's draws continue the ambient RNG stream, as a
#'   single ordinary call to [bootstrap_functional_space()] would).
#' @param ... Further method-specific tuning arguments forwarded as-is to
#'   every [bootstrap_functional_space()] call: `dendrogram_linkage`,
#'   `tpd_alpha`, `tpd_bw_factor`, `tpd_n_divisions`, `hv_bw_method`,
#'   `hv_samples_per_point`. Irrelevant arguments are simply ignored by
#'   whichever method does not use them.
#'
#' @return An object of class `"intrait_richness_comparison"`, a list
#'   with elements: `summary` (a `data.frame`, one row per requested
#'   method, in the order of `methods`, with columns `method`, `status`
#'   (`"ok"` or a `"skipped: <error message>"` note), `n_axes`,
#'   `var_explained`, `fd_ref`, `fd_boot_mean`, `fd_boot_sd`, `diff`,
#'   `pct_diff` (`100 * diff / fd_ref`, the cross-method-comparable
#'   quantity), `p_value`, and `significant` (`p_value < alpha`); `NA` in
#'   every numeric column for a skipped method), `results` (a named list
#'   of the full `"intrait_bootstrap_fspace"` object for every method that
#'   succeeded, e.g. for `plot()`-ing an individual method's bootstrap
#'   histogram), `n_boot`, and `alpha`. Has dedicated [print()] and
#'   [plot()] methods.
#'
#' @details
#' Each method gets its own, independent call to
#' [bootstrap_functional_space()] -- including its own fresh PCA and its
#' own `n_boot` bootstrap draws -- rather than sharing internal
#' computation across methods; this keeps the comparison exactly as
#' trustworthy as calling [bootstrap_functional_space()] directly four
#' times, at the cost of repeating the (comparatively cheap) PCA step. Use
#' `seed` if you specifically want the same draws reused across methods
#' rather than four independent bootstrap samples.
#'
#' `pct_diff` is the one quantity meaningfully compared across rows:
#' consistent, similarly sized, statistically significant `pct_diff`
#' across most or all methods is stronger evidence that intraspecific
#' trait variability genuinely inflates the estimated functional space
#' than a single method's result taken alone, since the four measures
#' make different assumptions (hard-edged hull vs. kernel-smoothed
#' density vs. distance-based dendrogram) and so are unlikely to agree
#' spuriously for the same reason.
#'
#' @references
#' Bertrand P (2026). Intraspecific trait variability shapes the
#' functional space of freshwater fish in French Guiana assemblages. M2
#' Biodiversity Ecology Evolution (BEE) internship report, Lille
#' University / Centre de Recherche sur la Biodiversite et l'Environnement
#' (CRBE, AQUAECO team), unpublished, supervised by A. Toussaint and S.
#' Brosse.
#'
#' @seealso [bootstrap_functional_space()], [species_sensitivity()]
#'
#' @examples
#' \donttest{
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#'
#' # "dendrogram" always runs; "convexhull"/"tpd"/"hypervolume" are
#' # skipped gracefully (not fatal) if their package is not installed
#' cmp <- compare_functional_richness(ts, n_axes = 2, n_boot = 100)
#' cmp
#' plot(cmp)
#' }
#' @export
compare_functional_richness <- function(x, groups = NULL,
                                         methods = c("convexhull", "dendrogram", "tpd", "hypervolume"),
                                         n_axes = NULL, var_threshold = 0.98,
                                         n_boot = 100,
                                         log_transform = TRUE, scale = TRUE,
                                         alpha = 0.05, seed = NULL, ...) {
  methods <- match.arg(methods, several.ok = TRUE)
  if (!is.numeric(alpha) || length(alpha) != 1 || alpha <= 0 || alpha >= 1) {
    stop("`alpha` must be a single number strictly between 0 and 1.", call. = FALSE)
  }
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1)) {
    stop("`seed` must be `NULL` or a single integer.", call. = FALSE)
  }

  results <- list()
  rows <- vector("list", length(methods))

  for (i in seq_along(methods)) {
    m <- methods[i]
    if (!is.null(seed)) set.seed(seed)
    bf <- tryCatch(
      bootstrap_functional_space(
        x, groups = groups, method = m, n_axes = n_axes, var_threshold = var_threshold,
        n_boot = n_boot, log_transform = log_transform, scale = scale, ...
      ),
      error = function(e) conditionMessage(e)
    )
    if (is.character(bf)) {
      rows[[i]] <- data.frame(
        method = m, status = paste0("skipped: ", bf),
        n_axes = NA_integer_, var_explained = NA_real_,
        fd_ref = NA_real_, fd_boot_mean = NA_real_, fd_boot_sd = NA_real_,
        diff = NA_real_, pct_diff = NA_real_, p_value = NA_real_, significant = NA,
        stringsAsFactors = FALSE
      )
    } else {
      results[[m]] <- bf
      pct_diff <- 100 * bf$diff / bf$fd_ref
      rows[[i]] <- data.frame(
        method = m, status = "ok",
        n_axes = bf$n_axes, var_explained = bf$var_explained,
        fd_ref = bf$fd_ref, fd_boot_mean = bf$fd_boot_mean, fd_boot_sd = bf$fd_boot_sd,
        diff = bf$diff, pct_diff = pct_diff, p_value = bf$p_value,
        significant = bf$p_value < alpha,
        stringsAsFactors = FALSE
      )
    }
  }

  summary_df <- do.call(rbind, rows)
  rownames(summary_df) <- NULL

  structure(
    list(
      summary = summary_df,
      results = results,
      n_boot = as.integer(n_boot),
      alpha = alpha
    ),
    class = "intrait_richness_comparison"
  )
}

#' Print and plot an `"intrait_richness_comparison"` object
#'
#' `plot()` draws a dot-and-whisker comparison, one row per method that
#' succeeded: the dot is `pct_diff` (bootstrap mean vs. centroid reference,
#' as a % change), the whiskers span the bootstrap 5-95% interval on the
#' same relative scale, and colour marks whether `p_value < alpha`.
#'
#' @param x An object of class `"intrait_richness_comparison"`, as
#'   returned by [compare_functional_richness()].
#' @param ... For `plot()`, further arguments passed to [graphics::plot()];
#'   currently unused by `print()`.
#' @return Invisibly returns `x`.
#' @export
print.intrait_richness_comparison <- function(x, ...) {
  s <- x$summary
  ok <- s$status == "ok"
  cat("<intrait_richness_comparison>\n")
  cat(sprintf("  %d method(s) requested, %d succeeded\n", nrow(s), sum(ok)))

  print_df <- data.frame(
    method = s$method,
    status = ifelse(ok, "ok", s$status),
    fd_ref = ifelse(ok, sprintf("%.4g", s$fd_ref), NA_character_),
    fd_boot_mean = ifelse(ok, sprintf("%.4g", s$fd_boot_mean), NA_character_),
    pct_diff = ifelse(ok, sprintf("%+.1f%%", s$pct_diff), NA_character_),
    p_value = ifelse(ok, sprintf("%.4g", s$p_value), NA_character_),
    significant = ifelse(ok, as.character(s$significant), NA_character_),
    stringsAsFactors = FALSE
  )
  print(print_df, row.names = FALSE)

  n_ok <- sum(ok)
  n_sig <- sum(s$significant, na.rm = TRUE)
  if (n_ok > 0) {
    cat(sprintf(
      "\n  %d/%d method(s) agree that individual-based richness significantly\n  exceeds the centroid-based reference (p < %.3g).\n",
      n_sig, n_ok, x$alpha
    ))
  }
  invisible(x)
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname print.intrait_richness_comparison
plot.intrait_richness_comparison <- function(x, ...) {
  s <- x$summary[x$summary$status == "ok", , drop = FALSE]
  if (nrow(s) == 0) {
    stop("No method succeeded in `x`; nothing to plot.", call. = FALSE)
  }

  q_lo <- vapply(s$method, function(m) {
    r <- x$results[[m]]
    100 * (r$fd_boot_q05 - r$fd_ref) / r$fd_ref
  }, numeric(1))
  q_hi <- vapply(s$method, function(m) {
    r <- x$results[[m]]
    100 * (r$fd_boot_q95 - r$fd_ref) / r$fd_ref
  }, numeric(1))

  y <- seq_len(nrow(s))
  cols <- ifelse(s$significant, "firebrick", "grey40")

  old_par <- graphics::par(mar = c(4, 8, 3, 1))
  on.exit(graphics::par(old_par), add = TRUE)

  xr <- range(c(q_lo, q_hi, 0))
  xpad <- diff(xr) * 0.08
  if (!is.finite(xpad) || xpad == 0) xpad <- 1

  graphics::plot(
    s$pct_diff, y, pch = 19, col = cols, yaxt = "n", ylab = "",
    xlim = xr + c(-xpad, xpad), ylim = c(0.5, nrow(s) + 0.5),
    xlab = "Bootstrap mean vs. centroid reference (% change)",
    main = "Functional richness: method comparison", ...
  )
  graphics::axis(2, at = y, labels = s$method, las = 1, cex.axis = 0.9)
  graphics::segments(q_lo, y, q_hi, y, col = cols)
  graphics::abline(v = 0, col = "grey60", lty = 2)
  graphics::legend(
    "bottomright",
    legend = c(sprintf("p < %.3g", x$alpha), sprintf("p >= %.3g", x$alpha)),
    col = c("firebrick", "grey40"), pch = 19, bty = "n", cex = 0.8
  )
  invisible(x)
}
