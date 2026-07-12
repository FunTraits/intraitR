#' Rarefaction of intraspecific trait variability against sample size
#'
#' Builds, for each group (typically a species), a rarefaction/accumulation
#' curve of an intraspecific variability metric as a function of the number
#' of individuals sampled, and estimates the sample size `n*` at which that
#' variability *stabilises* -- the trait-based analogue of a species
#' accumulation (rarefaction) curve. For each sub-sample size
#' `n` = 2, 3, ..., N_g, `n_perm` sub-samples of `n` individuals are
#' drawn at random **without replacement** from the group's N_g
#' individuals, the metric is computed on each, and the draws are summarised
#' by their mean and a resampling quantile band.
#'
#' @details
#' The behaviour of the curve, and therefore the meaning of "stabilises",
#' depends fundamentally on the *kind* of metric (see also Violle et al.,
#' 2012; Gotelli & Colwell, 2001):
#'
#' \describe{
#'   \item{**Dispersion metrics** (`"variance"`, `"sd"`, `"cv"`)}{The sample
#'     variance is an *unbiased* estimator of the population variance:
#'     `E[s^2(n)] = sigma^2` for every `n >= 2`. The expected
#'     curve is therefore essentially **flat**; what changes with `n` is not
#'     its level but its *precision* -- the resampling band narrows as `n`
#'     grows. "Stabilisation" here is therefore convergence of the estimate
#'     in *precision*, not in level: `n*` is defined as the smallest `n`
#'     beyond which the resampling band's half-width, relative to the
#'     full-sample value `V(N_g)`, stays at or below `conv_tol` for all
#'     larger sub-sample sizes (framing `"convergence"`). Basing this on the
#'     band rather than the mean is deliberate: because `E[s^2(n)]` is
#'     flat, a criterion on the mean would return `n* = 2` trivially,
#'     whereas the band width is what actually decreases with sampling
#'     effort. This answers: *how many individuals are needed for a reliable
#'     (well-pinned-down) estimate of intraspecific variability?*}
#'   \item{**Accumulation metrics** (`"range"`)}{The observed range (and,
#'     more generally, the amount of trait space occupied) genuinely
#'     *increases* with `n` and saturates, exactly like species richness in
#'     a rarefaction curve. Here a saturating model is fitted to the curve
#'     (Michaelis-Menten `V(n) = Vmax * n / (K + n)` or negative
#'     exponential `V(n) = Vmax * (1 - exp(-b*n))`) and `n*` is the
#'     sample size reaching a fraction `asymptote_prop` of the estimated
#'     asymptote `Vmax` (framing `"accumulation"`). For
#'     Michaelis-Menten this is available in closed form,
#'     `n* = K * p / (1 - p)`; for the exponential model,
#'     `n* = -log(1 - p) / b`. When the metric has not saturated within
#'     the observed range (e.g. the range of an unbounded, approximately
#'     Gaussian trait, which grows without a true asymptote), `n*` may
#'     exceed `n_max` -- this is a legitimate *extrapolation* signalling
#'     that more individuals than were sampled would be needed to reach
#'     `asymptote_prop` of the fitted asymptote, and should be read
#'     alongside `prop_reached` (the fraction of the asymptote actually
#'     attained at N_g).}
#' }
#'
#' `"variance"` is multivariate: it uses the trace of the group trait
#' covariance matrix (the sum of the per-trait variances), the same
#' dispersion measure returned by [trait_disparity()], so a single curve is
#' produced per group. `"sd"`, `"cv"` and `"range"` are univariate and
#' produce one curve per group *and* trait.
#'
#' The `n_perm` random draws at each sub-sample size are independent of one
#' another and are distributed automatically across `future.apply`'s workers
#' when that (Suggested) package is installed and a parallel
#' [future::plan()] has been set beforehand; otherwise this runs
#' sequentially, with identical results (see [bootstrap_functional_space()],
#' [trait_disparity()]). Exact reproducibility across runs therefore
#' requires either a sequential plan together with `seed`, or reliance on
#' `future.apply`'s own parallel-safe streams.
#'
#' @param x Either an object of class `"intrait_traitspace"` (from
#'   [trait_space()], whose retained ordination `scores` and `groups` are
#'   used) or a `data.frame`/matrix of numeric traits, one row per
#'   **individual** (not averaged to group means -- intraspecific
#'   variability cannot be estimated from group means). Non-numeric columns
#'   are dropped with a warning. `metric = "cv"` is incompatible with an
#'   `"intrait_traitspace"` object, whose scores are centred (a coefficient
#'   of variation on centred data is meaningless).
#' @param groups Factor or character vector, one value per row of `x`: the
#'   grouping variable (typically species). Required when `x` is a raw
#'   trait table; taken from `x$groups` when `x` is an
#'   `"intrait_traitspace"`. Rows with a missing group are dropped with a
#'   message.
#' @param metric Character, the variability metric to rarefy. One of
#'   `"variance"` (default; multivariate trait variance / trace of the
#'   covariance -- dispersion), `"sd"` (per-trait standard deviation --
#'   dispersion), `"cv"` (per-trait coefficient of variation in percent --
#'   dispersion) or `"range"` (per-trait observed range -- accumulation).
#' @param n_perm Integer, number of random sub-samples drawn at each
#'   sub-sample size. Defaults to `99`.
#' @param sizes Optional integer vector of sub-sample sizes to evaluate. If
#'   `NULL` (default), every size from `2` to each group's own N_g is
#'   used; if supplied, it is intersected per group with `2:N_g`.
#' @param conv_tol Numeric in (0, 1), the precision tolerance defining
#'   convergence for dispersion metrics: `n*` is the smallest `n` beyond
#'   which the resampling band's half-width `(upper - lower) / 2`,
#'   relative to `|V(N_g)|`, stays at or below `conv_tol` for all larger
#'   sizes. With the default `probs = c(0.025, 0.975)` band this is a 95%
#'   resampling interval, so `conv_tol = 0.05` means "estimate pinned down
#'   to within +/-5% of the full-sample value". Defaults to `0.05`.
#' @param asymptote_prop Numeric in (0, 1), the fraction of the fitted
#'   asymptote Vmax defining `n*` for accumulation metrics.
#'   Defaults to `0.95`.
#' @param model Character, the saturating model fitted for accumulation
#'   metrics: `"michaelis"` (default, Michaelis-Menten) or `"exponential"`
#'   (negative exponential). Ignored for dispersion metrics.
#' @param probs Numeric length-2 vector of lower/upper probabilities for the
#'   resampling quantile band. Defaults to `c(0.025, 0.975)`.
#' @param min_n Integer, the minimum group size N_g required for a
#'   group to be rarefied; smaller groups are skipped with a message.
#'   Defaults to `5`.
#' @param log_transform Logical, apply a `log10(x + 1)`
#'   transformation to a raw trait table before computing the metric (as in
#'   [trait_space()]). Ignored when `x` is an `"intrait_traitspace"`.
#'   Defaults to `FALSE`.
#' @param scale Logical or `NULL`. Standardise each trait (z-score) before
#'   computing the metric, so traits with different units contribute
#'   comparably to the multivariate `"variance"`. `NULL` (default) resolves
#'   to `TRUE` for `metric = "variance"` and `FALSE` otherwise; it is
#'   always forced to `FALSE` for `metric = "cv"` (centring would make a CV
#'   meaningless). Ignored when `x` is an `"intrait_traitspace"` (already
#'   pre-processed).
#' @param seed Optional integer passed to [set.seed()] for reproducibility
#'   under a sequential plan (see Details). Defaults to `NULL`.
#'
#' @return An object of class `"intrait_itv_accumulation"`, a list with
#'   elements:
#'   \describe{
#'     \item{curve}{a tidy `data.frame` with columns `group`, `trait` (the
#'       trait name, or `"multivariate"` for `metric = "variance"`), `n`,
#'       `mean`, `lower`, `upper` (the resampling mean and quantile band at
#'       each sub-sample size).}
#'     \item{summary}{a `data.frame`, one row per (`group`, `trait`) series,
#'       with columns `group`, `trait`, `metric`, `framing`
#'       (`"convergence"` or `"accumulation"`), `n_max` (N_g),
#'       `v_full` (the full-sample metric value), `asymptote` and
#'       `prop_reached` and `k` (accumulation only; `NA` for convergence --
#'       `k` is the fitted half-saturation `K` for `model = "michaelis"` or
#'       the rate `b` for `model = "exponential"`, used to redraw and
#'       extrapolate the fitted curve), and `n_star` (the estimated
#'       stabilisation sample size).}
#'     \item{metric, framing, model, conv_tol, asymptote_prop, n_perm,
#'       probs}{the settings used.}
#'   }
#'   Has dedicated `print()` and `plot()` methods.
#'
#' @references
#' Gotelli, N. J., & Colwell, R. K. (2001). Quantifying biodiversity:
#' procedures and pitfalls in the measurement and comparison of species
#' richness. Ecology Letters, 4(4), 379-391.
#'
#' Violle, C., Enquist, B. J., McGill, B. J., Jiang, L., Albert, C. H.,
#' Hulshof, C., Jung, V., & Messier, J. (2012). The return of the variance:
#' intraspecific variability in community ecology. Trends in Ecology &
#' Evolution, 27(4), 244-252.
#'
#' @seealso [intraspecific_variability()], [itv_index()],
#'   [trait_disparity()], [bootstrap_functional_space()]
#'
#' @examples
#' fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
#' ratios <- fishmorph_ratios(fishmorph_segments(fish))
#'
#' # multivariate trait variance: how many individuals until the
#' # intraspecific-variability estimate converges (resampling band within
#' # +/-5% of the full-sample value)?
#' acc <- itv_accumulation(
#'   ratios[, c("BEl", "VEp", "REs")],
#'   groups = fish$metadata$species, n_perm = 30, seed = 1
#' )
#' acc
#' plot(acc)
#'
#' # per-trait range: a genuinely saturating accumulation curve, with n*
#' # taken at 95% of a fitted Michaelis-Menten asymptote
#' acc_range <- itv_accumulation(
#'   ratios[, c("BEl", "VEp")], groups = fish$metadata$species,
#'   metric = "range", n_perm = 30, seed = 1
#' )
#' acc_range
#'
#' @export
itv_accumulation <- function(x, groups = NULL,
                             metric = c("variance", "sd", "cv", "range"),
                             n_perm = 99, sizes = NULL, conv_tol = 0.05,
                             asymptote_prop = 0.95,
                             model = c("michaelis", "exponential"),
                             probs = c(0.025, 0.975), min_n = 5,
                             log_transform = FALSE, scale = NULL,
                             seed = NULL) {
  metric <- match.arg(metric)
  model <- match.arg(model)
  framing <- if (metric == "range") "accumulation" else "convergence"

  if (!is.numeric(n_perm) || length(n_perm) != 1 || n_perm < 1) {
    stop("`n_perm` must be a single positive integer.", call. = FALSE)
  }
  n_perm <- as.integer(n_perm)
  if (!is.numeric(conv_tol) || length(conv_tol) != 1 || conv_tol <= 0 || conv_tol >= 1) {
    stop("`conv_tol` must be a single number in (0, 1).", call. = FALSE)
  }
  if (!is.numeric(asymptote_prop) || length(asymptote_prop) != 1 ||
      asymptote_prop <= 0 || asymptote_prop >= 1) {
    stop("`asymptote_prop` must be a single number in (0, 1).", call. = FALSE)
  }
  if (!is.numeric(probs) || length(probs) != 2 || any(probs < 0) || any(probs > 1) ||
      probs[1] >= probs[2]) {
    stop("`probs` must be two increasing probabilities in [0, 1].", call. = FALSE)
  }
  if (!is.null(seed)) set.seed(seed)

  # -- Assemble the individual-by-trait matrix X and the grouping factor ---
  if (inherits(x, "intrait_traitspace")) {
    if (metric == "cv") {
      stop(
        "`metric = \"cv\"` is not meaningful on an \"intrait_traitspace\" ",
        "object, whose scores are centred; supply a raw trait table instead.",
        call. = FALSE
      )
    }
    X <- as.matrix(x$scores)
    if (is.null(groups)) groups <- x$groups
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
    dropped <- setdiff(names(traits_df), numeric_cols)
    if (length(numeric_cols) == 0) stop("`x` contains no numeric columns.", call. = FALSE)
    if (length(dropped) > 0) {
      warning("Dropping non-numeric column(s): ", paste(dropped, collapse = ", "), call. = FALSE)
    }
    X <- as.matrix(traits_df[numeric_cols])
    if (anyNA(X)) {
      stop(
        "`x` contains missing values; remove or impute NAs first (see the ",
        "`na_action` argument of trait_space()).",
        call. = FALSE
      )
    }
    if (isTRUE(log_transform)) {
      if (any(X < 0)) {
        stop(
          "`log_transform = TRUE` requires non-negative trait values; ",
          "set `log_transform = FALSE` or check your data.",
          call. = FALSE
        )
      }
      X <- log10(X + 1)
    }

    # Resolve `scale`: standardise for multivariate variance so traits with
    # different units contribute comparably; never for cv (centring makes a
    # coefficient of variation meaningless).
    if (is.null(scale)) scale <- identical(metric, "variance")
    if (metric == "cv" && isTRUE(scale)) {
      message("`scale` is ignored for metric = \"cv\" (a CV requires uncentred data).")
      scale <- FALSE
    }
    if (isTRUE(scale)) {
      col_sd <- apply(X, 2, stats::sd)
      X <- X[, col_sd > 0, drop = FALSE]
      if (ncol(X) == 0) stop("`x` has no non-constant numeric columns to scale.", call. = FALSE)
      X <- scale(X, center = TRUE, scale = TRUE)
    }
  }

  if (metric == "variance" && ncol(X) < 1) {
    stop("`x` must contain at least one numeric trait.", call. = FALSE)
  }
  trait_names <- colnames(X)
  if (is.null(trait_names)) trait_names <- paste0("trait_", seq_len(ncol(X)))

  groups <- factor(groups)
  if (length(groups) != nrow(X)) {
    stop("`groups` must have one entry per row of the trait data.", call. = FALSE)
  }
  if (anyNA(groups)) {
    keep_g <- !is.na(groups)
    message(sprintf(
      "Removing %d row(s) with a missing/unresolved `groups` value before rarefying.",
      sum(!keep_g)
    ))
    X <- X[keep_g, , drop = FALSE]
    groups <- droplevels(groups[keep_g])
  }
  if (nlevels(groups) < 1) stop("`groups` has no usable levels.", call. = FALSE)

  # -- Per-sub-sample metric: named numeric vector (length 1 for the
  #    multivariate variance, length ncol(X) for the univariate metrics) ---
  metric_fun <- switch(
    metric,
    variance = function(Xs) c(multivariate = sum(apply(Xs, 2, stats::var))),
    sd       = function(Xs) apply(Xs, 2, stats::sd),
    cv       = function(Xs) apply(Xs, 2, .cv_percent),
    range    = function(Xs) apply(Xs, 2, function(col) diff(range(col)))
  )
  series_names <- if (metric == "variance") "multivariate" else trait_names
  n_series <- length(series_names)

  curve_rows <- list()
  summary_rows <- list()
  skipped <- character(0)

  for (g in levels(groups)) {
    Xg <- X[groups == g, , drop = FALSE]
    Ng <- nrow(Xg)
    if (Ng < max(2L, min_n)) {
      skipped <- c(skipped, g)
      next
    }
    sizes_g <- if (is.null(sizes)) 2:Ng else sort(unique(sizes[sizes >= 2 & sizes <= Ng]))
    if (length(sizes_g) < 2) {
      skipped <- c(skipped, g)
      next
    }

    # mean / lower / upper of the metric at each sub-sample size, per series
    means <- matrix(NA_real_, length(sizes_g), n_series, dimnames = list(NULL, series_names))
    lower <- means
    upper <- means
    for (i in seq_along(sizes_g)) {
      n <- sizes_g[i]
      if (n == Ng) {
        # only one distinct sub-sample of size N_g; the metric is
        # order-invariant, so the band collapses to the point estimate
        v <- metric_fun(Xg)
        means[i, ] <- v
        lower[i, ] <- v
        upper[i, ] <- v
      } else {
        draws <- .papply(
          seq_len(n_perm),
          function(b) metric_fun(Xg[sample.int(Ng, n), , drop = FALSE]),
          numeric(n_series)
        )
        draws <- matrix(draws, nrow = n_series, ncol = n_perm)  # series x perm
        means[i, ] <- rowMeans(draws, na.rm = TRUE)
        lower[i, ] <- apply(draws, 1, stats::quantile, probs = probs[1], na.rm = TRUE)
        upper[i, ] <- apply(draws, 1, stats::quantile, probs = probs[2], na.rm = TRUE)
      }
    }

    for (s in seq_len(n_series)) {
      series <- series_names[s]
      m_s <- means[, s]
      curve_rows[[length(curve_rows) + 1]] <- data.frame(
        group = g, trait = series, n = sizes_g,
        mean = m_s, lower = lower[, s], upper = upper[, s],
        stringsAsFactors = FALSE
      )
      v_full <- m_s[length(m_s)]  # value at n = N_g

      if (framing == "convergence") {
        n_star <- .itv_convergence_n(sizes_g, lower[, s], upper[, s], v_full, conv_tol)
        asymptote <- NA_real_
        prop_reached <- NA_real_
        k <- NA_real_
      } else {
        fit <- .itv_saturating_fit(sizes_g, m_s, model, asymptote_prop)
        n_star <- fit$n_star
        asymptote <- fit$asymptote
        prop_reached <- if (is.na(fit$asymptote)) NA_real_ else v_full / fit$asymptote
        k <- fit$k  # half-saturation K (michaelis) or rate b (exponential)
      }

      summary_rows[[length(summary_rows) + 1]] <- data.frame(
        group = g, trait = series, metric = metric, framing = framing,
        n_max = Ng, v_full = v_full, asymptote = asymptote,
        prop_reached = prop_reached, n_star = n_star, k = k,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(skipped) > 0) {
    message(sprintf(
      "Skipped %d group(s) with fewer than %d individuals (or too few distinct sub-sample sizes): %s.",
      length(skipped), max(2L, min_n), paste(skipped, collapse = ", ")
    ))
  }
  if (length(curve_rows) == 0) {
    stop("No group had enough individuals to rarefy; lower `min_n` or check `groups`.", call. = FALSE)
  }

  curve <- do.call(rbind, curve_rows)
  summary_df <- do.call(rbind, summary_rows)
  rownames(curve) <- NULL
  rownames(summary_df) <- NULL

  structure(
    list(
      curve = curve, summary = summary_df,
      metric = metric, framing = framing, model = model,
      conv_tol = conv_tol, asymptote_prop = asymptote_prop,
      n_perm = n_perm, probs = probs
    ),
    class = "intrait_itv_accumulation"
  )
}

#' Smallest sub-sample size from which the resampling band's relative
#' half-width stays at or below `tol`, for every larger size
#'
#' Convergence is defined on the *precision* of the estimate (the width of
#' the resampling interval), not on the level of the mean, because for an
#' unbiased dispersion metric the mean is flat in `n` (see Details of
#' [itv_accumulation()]).
#'
#' @param sizes Integer vector of sub-sample sizes (increasing).
#' @param lower,upper Numeric vectors of the lower/upper band bounds,
#'   aligned with `sizes`.
#' @param v_full Numeric scalar, the full-sample reference value.
#' @param tol Numeric relative tolerance in (0, 1).
#' @return Integer `n*`. At `n = N_g` the band collapses to a point
#'   (half-width 0), so convergence is always attained by the largest size.
#' @noRd
.itv_convergence_n <- function(sizes, lower, upper, v_full, tol) {
  if (is.na(v_full) || v_full == 0) return(NA_integer_)
  rel_hw <- ((upper - lower) / 2) / abs(v_full)
  within <- rel_hw <= tol
  within[is.na(within)] <- FALSE
  # `n*` is the size from which `within` is TRUE all the way to the end:
  # the position just after the last FALSE. If every size already meets the
  # tolerance, that is the first (smallest) size.
  if (all(within)) return(as.integer(sizes[1]))
  last_false <- max(which(!within))
  if (last_false == length(sizes)) return(NA_integer_)
  as.integer(sizes[last_false + 1L])
}

#' Fit a saturating model to an accumulation curve and derive `n*`
#'
#' @param sizes Integer vector of sub-sample sizes.
#' @param means Numeric vector of rarefied means, aligned with `sizes`.
#' @param model `"michaelis"` or `"exponential"`.
#' @param prop Fraction of the asymptote defining `n*`.
#' @return A list with `asymptote` (Vmax), `n_star`, and `k` (the fitted
#'   rate/half-saturation parameter), each `NA` if the fit fails.
#' @noRd
.itv_saturating_fit <- function(sizes, means, model, prop) {
  fail <- list(asymptote = NA_real_, n_star = NA_integer_, k = NA_real_)
  df <- data.frame(n = as.numeric(sizes), y = as.numeric(means))
  df <- df[is.finite(df$y), , drop = FALSE]
  if (nrow(df) < 3 || diff(range(df$y)) == 0) return(fail)

  # `warnOnly = TRUE` already turns non-convergence into a returned (partial)
  # fit rather than an error; wrapping in suppressWarnings() additionally
  # silences the harmless "iterations exceeded maximum" note that nls()
  # raises on (near-)zero-residual data, e.g. a curve lying almost exactly
  # on the model. Fit quality is still guarded below via the finiteness and
  # positivity checks on the recovered coefficients.
  fit <- tryCatch(suppressWarnings({
    if (model == "michaelis") {
      stats::nls(y ~ Vmax * n / (K + n), data = df,
                 start = list(Vmax = max(df$y) * 1.05, K = stats::median(df$n)),
                 control = stats::nls.control(warnOnly = TRUE, maxiter = 500))
    } else {
      stats::nls(y ~ Vmax * (1 - exp(-b * n)), data = df,
                 start = list(Vmax = max(df$y) * 1.05, b = 1 / stats::median(df$n)),
                 control = stats::nls.control(warnOnly = TRUE, maxiter = 500))
    }
  }), error = function(e) NULL)
  if (is.null(fit)) return(fail)

  co <- stats::coef(fit)
  Vmax <- unname(co["Vmax"])
  if (!is.finite(Vmax) || Vmax <= 0) return(fail)

  if (model == "michaelis") {
    K <- unname(co["K"])
    if (!is.finite(K) || K <= 0) return(list(asymptote = Vmax, n_star = NA_integer_, k = K))
    n_star <- as.integer(ceiling(K * prop / (1 - prop)))
    list(asymptote = Vmax, n_star = n_star, k = K)
  } else {
    b <- unname(co["b"])
    if (!is.finite(b) || b <= 0) return(list(asymptote = Vmax, n_star = NA_integer_, k = b))
    n_star <- as.integer(ceiling(-log(1 - prop) / b))
    list(asymptote = Vmax, n_star = n_star, k = b)
  }
}

#' Evaluate a fitted saturating model at arbitrary sample sizes
#'
#' Used by [plot.intrait_itv_accumulation()] to redraw and extrapolate the
#' accumulation curve beyond the observed range, up towards its asymptote.
#'
#' @param nseq Numeric vector of sample sizes.
#' @param model `"michaelis"` or `"exponential"`.
#' @param Vmax,k The fitted asymptote and half-saturation/rate parameter.
#' @return Numeric vector of fitted values (all `NA` if the fit is unusable).
#' @noRd
.itv_fitted_curve <- function(nseq, model, Vmax, k) {
  if (!is.finite(Vmax) || !is.finite(k)) return(rep(NA_real_, length(nseq)))
  if (model == "michaelis") Vmax * nseq / (k + nseq) else Vmax * (1 - exp(-k * nseq))
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname itv_accumulation
#' @param x An object of class `"intrait_itv_accumulation"`.
#' @param ... Currently unused.
print.intrait_itv_accumulation <- function(x, ...) {
  cat("<intrait_itv_accumulation>\n")
  cat(sprintf(
    "  metric = %s (%s), %d permutation(s) per sub-sample size\n",
    x$metric, x$framing, x$n_perm
  ))
  if (x$framing == "convergence") {
    cat(sprintf("  n* = smallest n staying within %.0f%% of the full-sample value\n",
                x$conv_tol * 100))
  } else {
    cat(sprintf("  n* = n reaching %.0f%% of the fitted %s asymptote\n",
                x$asymptote_prop * 100, x$model))
  }
  cat("\n-- Stabilisation sample size per group/trait --\n")
  disp <- x$summary
  num_cols <- c("v_full", "asymptote", "prop_reached", "k")
  disp[num_cols] <- lapply(disp[num_cols], function(v) round(v, 4))
  if (x$framing == "convergence") disp[c("asymptote", "prop_reached", "k")] <- NULL
  print(disp, row.names = FALSE)
  invisible(x)
}

#' Plot intraspecific-variability rarefaction curves
#'
#' One panel per trait series (arranged with [graphics::par()] `mfrow`),
#' each showing the rarefied mean against sub-sample size for every group,
#' with the resampling quantile band as a shaded envelope and the estimated
#' stabilisation sample size `n*` as a vertical dashed line. For
#' *convergence* framing a horizontal reference line marks the full-sample
#' value. For *accumulation* framing the observed portion is drawn solid and,
#' when `extrapolate = TRUE`, the fitted saturating model is extended in a
#' dashed line beyond the observed range up towards its estimated asymptote
#' (drawn as a horizontal dotted line), so the plateau the curve is heading
#' for is visible even when it lies well beyond the individuals actually
#' sampled -- the interpolation/extrapolation style of a rarefaction curve.
#'
#' @param x An object of class `"intrait_itv_accumulation"`.
#' @param series Optional character vector selecting which trait series
#'   (panels) to draw; defaults to all.
#' @param band Logical, draw the resampling quantile band. Defaults to
#'   `TRUE`.
#' @param extrapolate Logical, for accumulation metrics extend the fitted
#'   curve beyond the observed range up to `n*` (or `xmax`) and draw the
#'   fitted asymptote. Ignored for convergence framing. Defaults to `TRUE`.
#' @param xmax Optional numeric, the largest sample size to extrapolate to.
#'   `NULL` (default) uses the largest finite `n*` in the panel, capped at
#'   ten times the observed maximum so a single very slowly saturating
#'   series cannot squash the observed range; the fitted asymptote is always
#'   drawn regardless, so the target remains visible even if the curve is
#'   cut off before reaching it.
#' @param ... Further arguments passed to [graphics::plot()].
#' @return Invisibly returns `x`.
#' @export
plot.intrait_itv_accumulation <- function(x, series = NULL, band = TRUE,
                                          extrapolate = TRUE, xmax = NULL, ...) {
  curve <- x$curve
  all_series <- unique(curve$trait)
  if (!is.null(series)) {
    keep <- intersect(series, all_series)
    if (length(keep) == 0) stop("None of `series` match the fitted trait series.", call. = FALSE)
    all_series <- keep
  }
  grps <- sort(unique(curve$group))
  cols <- .stable_group_colors(grps)
  do_extrap <- isTRUE(extrapolate) && x$framing == "accumulation"

  n_panel <- length(all_series)
  nc <- ceiling(sqrt(n_panel))
  nr <- ceiling(n_panel / nc)
  old_par <- graphics::par(mfrow = c(nr, nc), mar = c(4, 4, 2.5, 1))
  on.exit(graphics::par(old_par), add = TRUE)

  ylab <- switch(
    x$metric,
    variance = "Multivariate trait variance",
    sd = "Standard deviation", cv = "Coefficient of variation (%)",
    range = "Trait range"
  )

  for (sr in all_series) {
    cs <- curve[curve$trait == sr, , drop = FALSE]
    rows_panel <- x$summary[x$summary$trait == sr, , drop = FALSE]
    n_max_panel <- max(cs$n)

    # x-range: extend to the largest finite n* in the panel for accumulation
    # extrapolation, capped at 10x the observed maximum so one slowly
    # saturating series cannot compress the informative observed region.
    if (do_extrap) {
      ns <- rows_panel$n_star[is.finite(rows_panel$n_star)]
      auto_xmax <- if (length(ns) > 0) max(ns) else n_max_panel
      xmax_panel <- if (is.null(xmax)) min(auto_xmax, 10 * n_max_panel) else xmax
      xmax_panel <- max(xmax_panel, n_max_panel)
    } else {
      xmax_panel <- n_max_panel
    }

    yvals <- if (isTRUE(band)) c(cs$lower, cs$upper) else cs$mean
    if (do_extrap) yvals <- c(yvals, rows_panel$asymptote)
    yr <- range(yvals, na.rm = TRUE)

    graphics::plot(
      NA, xlim = c(min(cs$n), xmax_panel), ylim = yr,
      xlab = "Number of individuals (n)", ylab = ylab,
      main = if (x$metric == "variance") "Multivariate" else sr, ...
    )
    for (g in grps) {
      cg <- cs[cs$group == g, , drop = FALSE]
      if (nrow(cg) == 0) next
      col <- cols[[g]]
      if (isTRUE(band)) {
        graphics::polygon(
          c(cg$n, rev(cg$n)), c(cg$lower, rev(cg$upper)),
          col = grDevices::adjustcolor(col, alpha.f = 0.18), border = NA
        )
      }
      graphics::lines(cg$n, cg$mean, col = col, lwd = 2)  # observed (solid)

      row <- rows_panel[rows_panel$group == g, , drop = FALSE]
      if (nrow(row) != 1) next

      if (x$framing == "convergence") {
        if (is.finite(row$v_full)) graphics::abline(h = row$v_full, col = col, lty = 3, lwd = 1)
        if (is.finite(row$n_star)) graphics::abline(v = row$n_star, col = col, lty = 2, lwd = 1.5)
      } else {
        # accumulation: fitted asymptote (dotted horizontal) + dashed
        # extrapolation of the fitted saturating curve beyond the observed
        # range, up to xmax_panel.
        if (is.finite(row$asymptote)) {
          graphics::abline(h = row$asymptote, col = col, lty = 3, lwd = 1)
        }
        if (do_extrap && is.finite(row$asymptote) && is.finite(row$k) && xmax_panel > row$n_max) {
          # extrapolate from this group's own last observed size so the
          # dashed curve connects to the end of its solid observed line
          nseq <- seq(row$n_max, xmax_panel, length.out = 100)
          graphics::lines(
            nseq, .itv_fitted_curve(nseq, x$model, row$asymptote, row$k),
            col = col, lty = 2, lwd = 2
          )
        }
        if (is.finite(row$n_star) && row$n_star <= xmax_panel) {
          graphics::abline(v = row$n_star, col = col, lty = 2, lwd = 1)
        }
      }
    }
    graphics::legend("bottomright", legend = grps, col = unlist(cols[grps]),
                     lwd = 2, bty = "n", cex = 0.75)
    if (do_extrap) {
      graphics::legend(
        "topleft",
        legend = c("observed", "extrapolated", "asymptote"),
        lty = c(1, 2, 3), lwd = c(2, 2, 1), col = "grey30", bty = "n", cex = 0.7
      )
    }
  }
  invisible(x)
}
