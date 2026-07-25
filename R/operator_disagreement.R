#' Flag individuals whose landmark configuration disagrees across operators,
#' and attribute the disagreement to a specific operator
#'
#' Screens a landmark data set in which the *same* physical individuals were
#' each digitized once (or a few times) by *several* independent operators
#' -- as produced by [load_t26_saudrune_landmarks()] with
#' `source = "operators"` -- and returns, for every individual, a single
#' inter-operator disagreement index together with an automatic "at-risk"
#' flag and, where identifiable, the operator responsible for the
#' disagreement. It is the population-level, one-number-per-individual
#' companion to the by-eye, one-individual-at-a-time overlay of
#' [plot_fishmorph_shapes()] (`operator = TRUE`): rather than paging through
#' every fish to spot the ones whose operators drew visibly different shapes,
#' `operator_disagreement()` ranks all individuals by how much their
#' operators disagree, flags the unusually discordant ones, and names the
#' operator whose placement is the outlier.
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()], [read_landmarks_csv()], [read_mlmorph_landmarks()], or
#'   [load_t26_saudrune_landmarks()]) in which each physical individual has
#'   been digitized by two or more operators (one or more configurations per
#'   operator; see `individual`/`operator`).
#' @param individual A factor or character vector with one entry per
#'   specimen/row in `landmarks` (length `dim(landmarks$coords)[3]`), giving
#'   the identity of the physical individual each digitization belongs to.
#'   Defaults to `landmarks$metadata$individual` if present.
#' @param operator A factor or character vector of the same length, giving
#'   the operator who produced each digitization. Defaults to
#'   `landmarks$metadata$operator` if present (as produced by
#'   [load_t26_saudrune_landmarks()] with `source = "operators"`). When an
#'   operator digitized the same individual more than once, that operator's
#'   replicate configurations are first averaged (landmark-wise mean,
#'   ignoring `NA`) into a single per-operator configuration, so every
#'   operator contributes exactly one configuration per individual and no
#'   operator is implicitly up-weighted by having digitized an individual
#'   more often.
#' @param species A factor or character vector of the same length, giving
#'   species identity, used only to annotate the output. Defaults to
#'   `landmarks$metadata$species` if present.
#' @param normalization Character, one of `"centroid_size"` (default),
#'   `"landmarks"`, or `"standard_length"`, giving the per-individual
#'   reference distance by which raw landmark displacements are divided so
#'   that the disagreement index is a size-free percentage, comparable
#'   across individuals of very different body size (as in
#'   [digitization_error()]). `"centroid_size"` uses each individual's own
#'   mean landmark-configuration centroid size (averaged over its operators;
#'   Bookstein, 1991), the self-contained default that requires no landmark
#'   choice and matches the centre-and-scale view drawn by
#'   [plot_fishmorph_shapes()] (`align = TRUE`); `"landmarks"` uses the
#'   inter-landmark distance between `ref_landmarks` (averaged over the
#'   individual's operators); `"standard_length"` uses the individual's mean
#'   `standard_length_mm` from `landmarks$metadata`. Unlike
#'   [digitization_error()], the reference is always computed **per
#'   individual** (not per species), since the quantity of interest here is
#'   how much the operators of *one* fish disagree relative to *that* fish's
#'   size.
#' @param ref_landmarks Integer vector of length 2, the two landmarks whose
#'   distance is the size reference when `normalization = "landmarks"`.
#'   Defaults to `c(1, 2)`. Ignored otherwise.
#' @param exclude_landmarks Optional integer vector of landmark indices to
#'   exclude from the disagreement calculation entirely -- most importantly
#'   the embedded scale-bar calibration points (landmarks 20-21) of the
#'   FISHMORPH scheme ([fishmorph_segments()]), which encode a fixed
#'   real-world distance rather than a body landmark and so are not a
#'   homologous point whose across-operator scatter is meaningful. Defaults
#'   to `NULL` (all landmarks used); pass `c(20, 21)` for FISHMORPH-scheme
#'   data (see Examples). Excluded landmarks may still be used in
#'   `ref_landmarks`.
#' @param reference_operator Optional character scalar naming one operator
#'   (a value of `operator`) to treat as a gold-standard reference against
#'   which the others are measured, e.g. an expert digitizer. When supplied,
#'   each other operator's deviation for an individual is its distance to the
#'   reference operator's configuration of that individual, and the
#'   responsible operator is the non-reference operator that deviates most
#'   from it. This makes operator attribution identifiable even for
#'   individuals digitized by only two operators (see Details). Defaults to
#'   `NULL`: attribution is then made against a leave-one-out consensus of
#'   the other operators, which is only identifiable when an individual has
#'   at least three operators (again, see Details). The disagreement
#'   *magnitude* (`disagreement_pct`) is a symmetric, reference-free quantity
#'   and is unaffected by `reference_operator`.
#' @param threshold Numeric, the number of median absolute deviations (MAD)
#'   above the median disagreement index beyond which an individual is
#'   flagged as at-risk. Defaults to `3`, the same robust rule (and default)
#'   as [detect_outliers()] and the within-group screen underlying
#'   [species_sensitivity()]. The median and MAD are used, rather than the
#'   mean and SD, because they are themselves resistant to the discordant
#'   individuals being screened for.
#' @param min_operators Integer, the minimum number of distinct operators an
#'   individual must have to be included. Defaults to `2` (the smallest
#'   number for which any disagreement can be defined). Individuals digitized
#'   by fewer operators are dropped, with a message.
#' @param digits Integer, number of decimal places to round percentages to.
#'   Defaults to `4`.
#'
#' @return An object of class `"intrait_operator_disagreement"`, a list with:
#'   \describe{
#'     \item{`by_individual`}{`data.frame`, one row per retained individual,
#'       ordered by decreasing disagreement, with columns `individual`,
#'       `species`, `n_operators`, `operators` (comma-separated labels),
#'       `disagreement_pct` (the index: the mean across landmarks of the
#'       root-mean-square across-operator displacement from the per-landmark
#'       consensus, as a percentage of the reference distance),
#'       `max_landmark_pct` (the single most discordant landmark's value),
#'       `at_risk` (logical, `disagreement_pct` exceeds the robust
#'       threshold), `responsible_operator` (the attributed operator, or `NA`
#'       when not identifiable -- see Details), `responsible_deviation_pct`,
#'       and `attribution_margin_pct` (how far ahead of the next operator the
#'       attributed one is; small values mean a low-confidence attribution).}
#'     \item{`by_operator`}{`data.frame`, one row per operator, with the
#'       number of individuals it digitized, its mean and SD deviation across
#'       them, and how often (count and percentage, among identifiable
#'       individuals) it was the responsible operator -- the systematic view
#'       that also resolves, at the population level, the two-operator
#'       individuals whose culprit is not identifiable one at a time.}
#'     \item{`by_landmark`}{`data.frame`, one row per landmark, giving the
#'       mean/median/SD across-operator spread at that landmark over all
#'       individuals, ordered by decreasing mean spread -- which anatomical
#'       points the operators disagree on most.}
#'     \item{`landmark_operator`}{long `data.frame`, one row per
#'       individual x operator x landmark, of normalised displacements from
#'       the per-landmark consensus, for drill-down.}
#'     \item{`threshold_value`}{the numeric `disagreement_pct` cut-off implied
#'       by `threshold`.}
#'     \item{`threshold`, `normalization`, `reference_operator`,
#'       `excluded_landmarks`}{the settings used.}
#'   }
#'   Has dedicated `print()` and `plot()` methods.
#'
#' @details
#' For a given individual and landmark, let the (single, per-operator)
#' positions be \eqn{(x_o, y_o)} for operators \eqn{o = 1, \dots, K}, with
#' consensus (mean across operators) \eqn{(\bar{x}, \bar{y})}. Operator
#' \eqn{o}'s displacement is \eqn{d_o = \sqrt{(x_o - \bar{x})^2 + (y_o -
#' \bar{y})^2}}, and the landmark's across-operator *spread* is the
#' root-mean-square \eqn{\sqrt{\frac{1}{K}\sum_o d_o^2}}. The individual's
#' disagreement index is the mean of that spread over all (included)
#' landmarks, divided by the individual's reference distance and expressed as
#' a percentage (see `normalization`). This is the inter-operator analogue of
#' the intra-operator, repeated-digitization bias of [digitization_error()]:
#' there the replicated configurations come from *one* operator digitizing
#' the same specimen repeatedly (quantifying repeatability); here they come
#' from *different* operators digitizing it once each (quantifying
#' inter-operator disagreement, the "several independent operators" case that
#' [digitization_error()] explicitly does not cover; Klingenberg & McIntyre,
#' 1998). Because the calculation is landmark by landmark, it should be
#' applied only to homologous, independently placed body landmarks: fixed
#' calibration points such as the FISHMORPH scale bar (landmarks 20-21)
#' should be dropped via `exclude_landmarks` (see Examples).
#'
#' \strong{Operator attribution.} Detecting *that* the operators of a fish
#' disagree is symmetric; attributing the disagreement to *one* of them is
#' not always possible. With `reference_operator = NULL` (the default), the
#' responsible operator is the one lying furthest from the leave-one-out
#' consensus of the *other* operators (a majority-vote logic robust to the
#' full consensus being dragged toward the outlier). This is well defined
#' only when an individual has at least three operators: for exactly two
#' operators the two leave-one-out deviations are equal by construction
#' (each operator's "consensus of the others" is simply the other operator),
#' so neither can be singled out and `responsible_operator` is `NA` -- the
#' disagreement magnitude is still reported, and the `by_operator` table
#' still reveals which operator is *systematically* discordant across the
#' whole data set even when no single two-operator fish can be adjudicated.
#' Supplying `reference_operator` (e.g. a trusted expert) breaks this
#' symmetry: every other operator is then measured against that reference, so
#' attribution becomes identifiable for two-operator individuals as well.
#' `responsible_operator` is reported for every identifiable individual, but
#' is only *meaningful* for those flagged `at_risk`; for the rest,
#' `attribution_margin_pct` is typically small (the nominally most-deviant
#' operator is barely ahead), a signal not to over-interpret it.
#'
#' Like [detect_outliers()], this is a fast screening tool, not a formal
#' test: a genuinely and correctly digitized but naturally unusual fish, or
#' an individual for which one landmark is legitimately ambiguous, may be
#' flagged. Always inspect flagged individuals visually (e.g. with
#' [plot_fishmorph_shapes()], `operator = TRUE`, exactly the per-individual
#' overlay this function summarises) before acting on the flag. For a
#' rotation-invariant, formal Procrustes-ANOVA treatment of the same
#' replicated-digitization design, see [measurement_error()]
#' (`method = "procrustes"`).
#'
#' @references
#' Bookstein FL (1991). Morphometric Tools for Landmark Data: Geometry and
#' Biology. Cambridge University Press.
#'
#' Klingenberg CP, McIntyre GS (1998). Geometric morphometrics of
#' developmental instability: analyzing patterns of fluctuating asymmetry
#' with Procrustes methods. Evolution, 52(5), 1363-1375.
#'
#' @seealso [digitization_error()] (intra-operator repeatability from
#'   repeated digitization), [measurement_error()] (Procrustes-ANOVA
#'   measurement error), [detect_outliers()] (Procrustes-distance outlier
#'   screen), [plot_fishmorph_shapes()] (the per-individual, operator-coloured
#'   overlay this function summarises), [load_t26_saudrune_landmarks()]
#'
#' @examples
#' # T-26 Saudrune: every fish digitized once by each of several operators.
#' fish <- load_t26_saudrune_landmarks(source = "operators")
#'
#' # FISHMORPH scheme: drop the scale bar (landmarks 20-21) before screening.
#' od <- operator_disagreement(fish, exclude_landmarks = c(20, 21))
#' od
#'
#' # the ranked, flagged table of individuals and their culprit operator:
#' head(od$by_individual)
#'
#' # which operator is systematically the most discordant?
#' od$by_operator
#'
#' # visually confirm a flagged individual (the overlay this summarises):
#' risky <- od$by_individual$individual[od$by_individual$at_risk]
#' if (length(risky) > 0) {
#'   plot_fishmorph_shapes(fish, individuals = risky[1],
#'                         operator = TRUE, alpha = 0.6)
#' }
#'
#' # treat Operator_1 as an expert reference so two-operator fish can also
#' # have their culprit named:
#' od_ref <- operator_disagreement(
#'   fish, exclude_landmarks = c(20, 21), reference_operator = "Operator_1"
#' )
#'
#' @export
operator_disagreement <- function(landmarks,
                                   individual = NULL,
                                   operator = NULL,
                                   species = NULL,
                                   normalization = c("centroid_size", "landmarks", "standard_length"),
                                   ref_landmarks = c(1, 2),
                                   exclude_landmarks = NULL,
                                   reference_operator = NULL,
                                   threshold = 3,
                                   min_operators = 2,
                                   digits = 4) {
  normalization <- match.arg(normalization)

  if (!inherits(landmarks, "intrait_landmarks")) {
    stop(
      "`landmarks` must be an object of class \"intrait_landmarks\" (see ",
      "read_tps(), read_landmarks_csv(), or load_t26_saudrune_landmarks()), ",
      "with the same individuals digitized by two or more operators.",
      call. = FALSE
    )
  }
  if (!is.numeric(threshold) || length(threshold) != 1 || threshold <= 0) {
    stop("`threshold` must be a single positive number.", call. = FALSE)
  }

  coords <- landmarks$coords
  n_lmk <- dim(coords)[1]
  n_obs <- dim(coords)[3]
  meta <- landmarks$metadata

  ## ---- resolve grouping vectors ---------------------------------------
  if (is.null(individual)) {
    if (is.null(meta) || !"individual" %in% names(meta)) {
      stop("`individual` must be supplied (no `individual` column in `landmarks$metadata`).", call. = FALSE)
    }
    individual <- meta$individual
  }
  if (is.null(operator)) {
    if (is.null(meta) || !"operator" %in% names(meta)) {
      stop(
        "`operator` must be supplied (no `operator` column in `landmarks$metadata`; ",
        "load_t26_saudrune_landmarks(source = \"operators\") provides one).",
        call. = FALSE
      )
    }
    operator <- meta$operator
  }
  if (is.null(species) && !is.null(meta) && "species" %in% names(meta)) {
    species <- meta$species
  }
  if (length(individual) != n_obs || length(operator) != n_obs) {
    stop("`individual` and `operator` must each have one entry per specimen (length ", n_obs, ").", call. = FALSE)
  }
  if (!is.null(species) && length(species) != n_obs) {
    stop("`species` must have one entry per specimen (length ", n_obs, ").", call. = FALSE)
  }
  individual <- as.character(individual)
  operator <- as.character(operator)
  species <- if (is.null(species)) rep(NA_character_, n_obs) else as.character(species)

  ## ---- landmark set ---------------------------------------------------
  if (!is.null(exclude_landmarks)) {
    if (!is.numeric(exclude_landmarks) || any(exclude_landmarks < 1) || any(exclude_landmarks > n_lmk)) {
      stop("`exclude_landmarks` must index valid landmarks (between 1 and ", n_lmk, ").", call. = FALSE)
    }
    exclude_landmarks <- as.integer(exclude_landmarks)
  }
  landmark_set <- setdiff(seq_len(n_lmk), exclude_landmarks)
  if (length(landmark_set) < 1) {
    stop("`exclude_landmarks` excludes all available landmarks; nothing left to analyse.", call. = FALSE)
  }
  if (normalization == "landmarks") {
    if (!is.numeric(ref_landmarks) || length(ref_landmarks) != 2) {
      stop("`ref_landmarks` must be an integer vector of length 2.", call. = FALSE)
    }
    if (any(ref_landmarks < 1) || any(ref_landmarks > n_lmk)) {
      stop("`ref_landmarks` must index valid landmarks (between 1 and ", n_lmk, ").", call. = FALSE)
    }
  }
  if (normalization == "standard_length" &&
      (is.null(meta) || !"standard_length_mm" %in% names(meta))) {
    stop("normalization = \"standard_length\" requires a `standard_length_mm` column in `landmarks$metadata`.", call. = FALSE)
  }
  if (!is.null(reference_operator)) {
    if (!is.character(reference_operator) || length(reference_operator) != 1) {
      stop("`reference_operator` must be a single operator label.", call. = FALSE)
    }
    if (!reference_operator %in% operator) {
      stop(
        "`reference_operator` = \"", reference_operator, "\" is not among the operators present (",
        paste(sort(unique(operator)), collapse = ", "), ").",
        call. = FALSE
      )
    }
  }

  ## ---- retain individuals with >= min_operators distinct operators ----
  ind_ops <- tapply(operator, individual, function(o) length(unique(o)))
  eligible <- names(ind_ops)[ind_ops >= min_operators]
  if (length(eligible) < 1) {
    stop(
      "No individual is digitized by at least `min_operators` = ", min_operators,
      " distinct operators; nothing to compare.", call. = FALSE
    )
  }
  dropped <- length(ind_ops) - length(eligible)
  if (dropped > 0) {
    message(sprintf(
      "operator_disagreement(): %d of %d individual(s) digitized by fewer than %d operators were dropped.",
      dropped, length(ind_ops), min_operators
    ))
  }

  ## ---- helper: mean configuration per operator, NA-aware --------------
  op_config <- function(obs_idx) {
    ops <- unique(operator[obs_idx])
    cfg <- array(NA_real_, dim = c(n_lmk, 2, length(ops)), dimnames = list(NULL, NULL, ops))
    for (k in seq_along(ops)) {
      idx <- obs_idx[operator[obs_idx] == ops[k]]
      if (length(idx) == 1) {
        cfg[, , k] <- coords[, , idx]
      } else {
        cfg[, , k] <- apply(coords[, , idx, drop = FALSE], c(1, 2), mean, na.rm = TRUE)
      }
    }
    cfg[is.nan(cfg)] <- NA_real_
    cfg
  }

  ## ---- per-individual computation -------------------------------------
  lm_op_rows <- list()
  indiv_rows <- list()

  for (ind in eligible) {
    obs_idx <- which(individual == ind)
    cfg <- op_config(obs_idx)          # n_lmk x 2 x n_op (one config per operator)
    ops <- dimnames(cfg)[[3]]
    n_op <- length(ops)
    sp <- species[obs_idx[1]]

    ## reference distance (per individual, averaged over operators)
    if (normalization == "landmarks") {
      per_op_ref <- vapply(seq_len(n_op), function(k) {
        p1 <- cfg[ref_landmarks[1], , k]
        p2 <- cfg[ref_landmarks[2], , k]
        sqrt(sum((p1 - p2)^2))
      }, numeric(1))
      ref <- mean(per_op_ref, na.rm = TRUE)
    } else if (normalization == "standard_length") {
      ref <- mean(meta$standard_length_mm[obs_idx], na.rm = TRUE)
    } else {
      per_op_ref <- vapply(seq_len(n_op), function(k) {
        sub <- cfg[landmark_set, , k, drop = FALSE][, , 1]
        sub <- sub[stats::complete.cases(sub), , drop = FALSE]
        if (nrow(sub) < 2) return(NA_real_)
        ctr <- colMeans(sub)
        sqrt(sum(sweep(sub, 2, ctr)^2))
      }, numeric(1))
      ref <- mean(per_op_ref, na.rm = TRUE)
    }
    if (!is.finite(ref) || ref <= 0) {
      warning(
        "Individual \"", ind, "\": reference distance is not usable (", signif(ref, 3),
        "); skipping this individual.", call. = FALSE
      )
      next
    }

    ## per-landmark across-operator displacement + spread
    spread_l <- rep(NA_real_, length(landmark_set))
    ref_op_cfg <- if (!is.null(reference_operator) && reference_operator %in% ops) {
      cfg[, , match(reference_operator, ops)]
    } else {
      NULL
    }
    # per-operator deviation accumulator (sum of squared distances over landmarks)
    dev_ss <- stats::setNames(numeric(n_op), ops)
    dev_n <- stats::setNames(numeric(n_op), ops)

    for (li in seq_along(landmark_set)) {
      l <- landmark_set[li]
      pts <- t(cfg[l, , ])                       # n_op x 2
      ok <- stats::complete.cases(pts)
      if (sum(ok) >= 2) {
        cons <- colMeans(pts[ok, , drop = FALSE])
        d <- sqrt(rowSums(sweep(pts, 2, cons)^2)) # length n_op, NA where !ok
        dpct <- d / ref * 100
        spread_l[li] <- sqrt(mean(dpct[ok]^2))
        for (k in seq_len(n_op)) {
          lm_op_rows[[length(lm_op_rows) + 1L]] <- data.frame(
            individual = ind, species = sp, operator = ops[k], landmark = l,
            dist_pct = round(dpct[k], digits), stringsAsFactors = FALSE
          )
        }
      }

      ## attribution deviation, per operator
      if (!is.null(ref_op_cfg)) {
        # distance to the reference operator's own position at this landmark
        rp <- ref_op_cfg[l, ]
        if (all(is.finite(rp))) {
          for (k in seq_len(n_op)) {
            if (ops[k] == reference_operator) next
            pk <- cfg[l, , k]
            if (all(is.finite(pk))) {
              dev_ss[k] <- dev_ss[k] + sum((pk - rp)^2)
              dev_n[k] <- dev_n[k] + 1
            }
          }
        }
      } else {
        # leave-one-out consensus of the other operators
        for (k in seq_len(n_op)) {
          pk <- cfg[l, , k]
          if (!all(is.finite(pk))) next
          others_raw <- cfg[l, , -k]            # 2 x (n_op-1), or length-2 if one other
          others <- if (is.matrix(others_raw)) t(others_raw) else matrix(others_raw, nrow = 1)
          ok_o <- stats::complete.cases(others)
          if (sum(ok_o) < 1) next
          cons_o <- colMeans(others[ok_o, , drop = FALSE])
          dev_ss[k] <- dev_ss[k] + sum((pk - cons_o)^2)
          dev_n[k] <- dev_n[k] + 1
        }
      }
    }

    if (all(is.na(spread_l))) {
      warning(
        "Individual \"", ind, "\": no landmark has at least two operators with ",
        "complete coordinates; skipping this individual.", call. = FALSE
      )
      next
    }
    disagreement_pct <- round(mean(spread_l, na.rm = TRUE), digits)
    max_landmark_pct <- round(max(spread_l, na.rm = TRUE), digits)

    ## per-operator deviation (RMS over landmarks), normalised
    dev_pct <- ifelse(dev_n > 0, sqrt(dev_ss / dev_n) / ref * 100, NA_real_)
    names(dev_pct) <- ops

    ## responsible operator
    identifiable <- (!is.null(reference_operator) && reference_operator %in% ops) || n_op >= 3
    responsible <- NA_character_
    resp_dev <- NA_real_
    margin <- NA_real_
    if (identifiable) {
      cand <- dev_pct
      if (!is.null(reference_operator)) cand <- cand[names(cand) != reference_operator]
      cand <- cand[is.finite(cand)]
      if (length(cand) >= 1) {
        ord <- order(cand, decreasing = TRUE)
        responsible <- names(cand)[ord[1]]
        resp_dev <- round(unname(cand[ord[1]]), digits)
        margin <- round(unname(cand[ord[1]] - if (length(cand) >= 2) cand[ord[2]] else 0), digits)
      }
    }

    indiv_rows[[ind]] <- data.frame(
      individual = ind,
      species = sp,
      n_operators = n_op,
      operators = paste(sort(ops), collapse = ","),
      disagreement_pct = disagreement_pct,
      max_landmark_pct = max_landmark_pct,
      responsible_operator = responsible,
      responsible_deviation_pct = resp_dev,
      attribution_margin_pct = margin,
      stringsAsFactors = FALSE
    )
  }

  by_individual <- do.call(rbind, indiv_rows)
  rownames(by_individual) <- NULL
  landmark_operator <- do.call(rbind, lm_op_rows)
  rownames(landmark_operator) <- NULL

  ## ---- robust at-risk threshold (median + threshold * MAD) ------------
  d <- by_individual$disagreement_pct
  med <- stats::median(d, na.rm = TRUE)
  mad_val <- stats::mad(d, na.rm = TRUE)
  if (isTRUE(mad_val == 0)) {
    threshold_value <- med
    warning(
      "Disagreement indices have zero median absolute deviation; no individual ",
      "can be reliably flagged as at-risk.", call. = FALSE
    )
  } else {
    threshold_value <- med + threshold * mad_val
  }
  threshold_value <- round(threshold_value, digits)
  by_individual$at_risk <- by_individual$disagreement_pct > threshold_value

  by_individual <- by_individual[order(-by_individual$disagreement_pct), ]
  by_individual <- by_individual[, c(
    "individual", "species", "n_operators", "operators",
    "disagreement_pct", "max_landmark_pct", "at_risk",
    "responsible_operator", "responsible_deviation_pct", "attribution_margin_pct"
  )]
  rownames(by_individual) <- NULL

  ## ---- by operator ----------------------------------------------------
  # per-operator deviation across individuals: rebuild from landmark_operator
  # (mean over landmarks of dist_pct for each individual x operator), plus
  # responsibility counts from by_individual.
  io_dev <- stats::aggregate(dist_pct ~ individual + operator, data = landmark_operator, FUN = mean)
  all_ops <- sort(unique(operator))
  by_operator <- do.call(rbind, lapply(all_ops, function(o) {
    sub <- io_dev[io_dev$operator == o, ]
    n_ind <- nrow(sub)
    resp_sub <- by_individual[!is.na(by_individual$responsible_operator), ]
    n_resp <- sum(resp_sub$responsible_operator == o)
    n_ident <- nrow(resp_sub)
    data.frame(
      operator = o,
      n_individuals = n_ind,
      mean_deviation_pct = round(mean(sub$dist_pct), digits),
      sd_deviation_pct = round(if (n_ind > 1) stats::sd(sub$dist_pct) else NA_real_, digits),
      n_responsible = n_resp,
      pct_responsible = round(if (n_ident > 0) n_resp / n_ident * 100 else NA_real_, digits),
      stringsAsFactors = FALSE
    )
  }))
  by_operator <- by_operator[order(-by_operator$mean_deviation_pct), ]
  rownames(by_operator) <- NULL

  ## ---- by landmark ----------------------------------------------------
  # across-operator spread per (individual, landmark), aggregated over individuals
  il_spread <- stats::aggregate(
    dist_pct ~ individual + landmark, data = landmark_operator,
    FUN = function(v) sqrt(mean(v^2))
  )
  by_landmark <- do.call(rbind, lapply(sort(unique(il_spread$landmark)), function(l) {
    sub <- il_spread$dist_pct[il_spread$landmark == l]
    data.frame(
      landmark = l,
      n_individuals = length(sub),
      mean_spread_pct = round(mean(sub), digits),
      median_spread_pct = round(stats::median(sub), digits),
      sd_spread_pct = round(if (length(sub) > 1) stats::sd(sub) else NA_real_, digits),
      stringsAsFactors = FALSE
    )
  }))
  by_landmark <- by_landmark[order(-by_landmark$mean_spread_pct), ]
  rownames(by_landmark) <- NULL

  structure(
    list(
      by_individual = by_individual,
      by_operator = by_operator,
      by_landmark = by_landmark,
      landmark_operator = landmark_operator,
      threshold_value = threshold_value,
      threshold = threshold,
      normalization = normalization,
      reference_operator = reference_operator,
      excluded_landmarks = exclude_landmarks
    ),
    class = "intrait_operator_disagreement"
  )
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname operator_disagreement
#' @param x An object of class `"intrait_operator_disagreement"`.
#' @param ... Currently unused (`print`) or passed to [graphics::plot()] /
#'   [graphics::barplot()] (`plot`).
print.intrait_operator_disagreement <- function(x, ...) {
  n_risk <- sum(x$by_individual$at_risk, na.rm = TRUE)
  n_ind <- nrow(x$by_individual)
  cat("<intrait_operator_disagreement>\n")
  cat(sprintf(" Normalization: %s\n", x$normalization))
  if (!is.null(x$reference_operator)) {
    cat(sprintf(" Reference operator: %s\n", x$reference_operator))
  }
  if (!is.null(x$excluded_landmarks)) {
    cat(sprintf(" Excluded landmark(s): %s\n", paste(x$excluded_landmarks, collapse = ", ")))
  }
  cat(sprintf(
    "\n %d at-risk individual(s) out of %d (threshold disagreement = %.4f%% of reference)\n",
    n_risk, n_ind, x$threshold_value
  ))
  cat("\n Most discordant individual(s):\n")
  print(utils::head(x$by_individual, 5), row.names = FALSE)
  cat("\n Operator disagreement summary:\n")
  print(x$by_operator, row.names = FALSE)
  invisible(x)
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname operator_disagreement
#' @param type Character, one of `"individual"` (default), `"operator"`, or
#'   `"landmark"`, selecting which view [plot.intrait_operator_disagreement()]
#'   draws: a ranked dot plot of every individual's disagreement index with
#'   at-risk individuals highlighted and the threshold marked (as in
#'   [detect_outliers()]); a bar plot of mean deviation per operator; or a bar
#'   plot of mean across-operator spread per landmark.
plot.intrait_operator_disagreement <- function(x, type = c("individual", "operator", "landmark"), ...) {
  type <- match.arg(type)
  if (type == "individual") {
    d <- x$by_individual$disagreement_pct
    at_risk <- x$by_individual$at_risk
    ord <- order(d)
    graphics::plot(
      d[ord], seq_along(d),
      pch = ifelse(at_risk[ord], 19, 1),
      col = ifelse(at_risk[ord], "firebrick", "black"),
      xlab = "Inter-operator disagreement (% of reference)",
      ylab = "Individual rank",
      main = "Inter-operator disagreement screening",
      ...
    )
    graphics::abline(v = x$threshold_value, lty = 2, col = "firebrick")
  } else if (type == "operator") {
    bo <- x$by_operator[order(x$by_operator$mean_deviation_pct), ]
    graphics::barplot(
      bo$mean_deviation_pct, names.arg = bo$operator, horiz = TRUE, las = 1,
      xlab = "Mean deviation from consensus (% of reference)",
      main = "Disagreement by operator", col = "steelblue4", ...
    )
  } else {
    bl <- x$by_landmark[order(x$by_landmark$mean_spread_pct), ]
    graphics::barplot(
      bl$mean_spread_pct, names.arg = bl$landmark, horiz = TRUE, las = 1,
      xlab = "Mean across-operator spread (% of reference)",
      ylab = "Landmark",
      main = "Disagreement by landmark", col = "steelblue4", ...
    )
  }
  invisible(x)
}
