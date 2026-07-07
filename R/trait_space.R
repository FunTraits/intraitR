#' Build a functional trait space from a numeric trait table
#'
#' Constructs a low-dimensional functional trait space from any table of
#' numeric traits (e.g. the FISHMORPH ecomorphological ratios produced by
#' [fishmorph_ratios()], or linear traits/ratios from [morpho_ratios()]),
#' by Principal Component Analysis or by metric multidimensional scaling
#' (Principal Coordinate Analysis) of a Euclidean distance matrix, the two
#' standard approaches used to build functional trait spaces in
#' comparative ecology (e.g. Villéger et al., 2017).
#'
#' @param traits A `data.frame` or matrix of numeric traits, one row per
#'   specimen or species. Non-numeric columns are dropped with a warning
#'   (they are not included in the ordination, but grouping is still
#'   auto-detected from a `species` column if present; see `groups`).
#'   Constant (zero-variance) numeric columns are also dropped with a
#'   warning, since they carry no information for an ordination and
#'   cannot be rescaled to unit variance; this commonly happens when
#'   incidental numeric metadata (e.g. a digitization replicate counter)
#'   is carried over from [fishmorph_segments()]/[fishmorph_ratios()] and
#'   passed to `trait_space()` unfiltered. A non-finite value (`Inf`/
#'   `-Inf`, as from a ratio with a zero-length denominator segment) is
#'   always an error regardless of `na_action` (it is not treated as an
#'   ordinary missing value -- see Details).
#' @param groups Optional factor (or character vector), one value per row
#'   of `traits`, used to colour/group observations when plotting. If
#'   `NULL` and `traits` contains a `species` column, it is used
#'   automatically.
#' @param method Character, one of `"pca"` (default, Principal Component
#'   Analysis via [stats::prcomp()]) or `"pcoa"` (Principal Coordinate
#'   Analysis / classical multidimensional scaling, via
#'   [stats::cmdscale()], of a Euclidean distance matrix on the same,
#'   optionally transformed and standardised, trait data — equivalent to
#'   PCA up to an arbitrary rotation and sign).
#' @param log_transform Logical, apply a `log10(x + 1)` transformation to
#'   every numeric trait before centring/scaling and ordination. Defaults
#'   to `TRUE`. Ratio traits (e.g. from [fishmorph_ratios()] or
#'   [morpho_ratios()]) are bounded at zero and often right-skewed, so a
#'   log(x + 1) transformation (the `+ 1` accommodating traits that can
#'   legitimately equal zero, e.g. under the Villéger et al., 2010,
#'   exception rules) is common practice before ordination. Requires all
#'   trait values to be non-negative; set to `FALSE` to skip (e.g. for
#'   traits that can be negative, such as PCA scores fed back into a
#'   second ordination).
#' @param scale Logical, standardise (centre and scale to unit variance)
#'   traits before building the trait space, after the optional log
#'   transformation (recommended when traits are on different scales or
#'   have different variances). Defaults to `TRUE`.
#' @param axes Integer vector of length 2, the ordination axes to retain
#'   for plotting. Defaults to `c(1, 2)`.
#' @param na_action Character, how to handle missing values in the numeric
#'   trait columns: `"fail"` (default) stops with an error, as in previous
#'   versions; `"omit"` removes affected rows (specimens/species) and
#'   reports how many were dropped; `"impute_mean"` replaces missing
#'   values with the corresponding column mean; `"impute_group_mean"`
#'   replaces missing values with the mean of the same trait within the
#'   same group (`groups`, or the auto-detected `species` column), falling
#'   back to the column mean, with a warning, for a group entirely missing
#'   a trait; `"missforest"` uses random-forest-based iterative imputation
#'   (`missForest::missForest()`, Stekhoven & Bühlmann, 2012) on the
#'   numeric trait matrix, using `groups` (when available) as an
#'   additional predictor; `"missforest_phylo"` does the same but also
#'   augments the predictor matrix with phylogenetic PCoA axes (see
#'   [phylo_pcoa()], `tree`/`missforest_phylo_k`) for the species in
#'   `groups`, so that phylogenetically related species can inform each
#'   other's imputed values in addition to shared species identity --
#'   falling back to plain `"missforest"`, with a warning explaining why,
#'   if phylogenetic axes cannot be used (no `groups`, fewer than 3 species
#'   matched to `tree`, "ape" not installed, etc.). `"omit"` and every
#'   imputation option print a `message()` reporting the number of rows
#'   removed or values imputed (plus, for `"missforest"`/
#'   `"missforest_phylo"`, the out-of-bag normalised RMSE of the
#'   imputation, and, for `"missforest_phylo"`, how many phylogenetic axes
#'   and matched species were actually used), so this is never a silent
#'   operation.
#' @param missforest_ntree,missforest_maxiter Number of trees per forest
#'   and maximum number of iterations passed to
#'   `missForest::missForest()` when `na_action` is `"missforest"`/
#'   `"missforest_phylo"`; ignored otherwise. Default to `missForest`'s
#'   own defaults (`100` and `10`).
#' @param tree Used only by `na_action = "missforest_phylo"`: an object of
#'   class `"phylo"` (e.g. from `ape::read.tree()`), or `NULL` (default) to
#'   use the bundled [load_fishmorph_phylogeny()] tree.
#' @param missforest_phylo_k Used only by `na_action = "missforest_phylo"`:
#'   maximum number of phylogenetic PCoA axes to add as predictors.
#'   Defaults to `10`.
#' @param flag_outliers Logical, screen for potential within-group (e.g.
#'   within-species) outliers -- specimens unusually far from other members
#'   of their own group in the standardised trait space -- and report them
#'   (see Details and `outlier_threshold`/`outlier_min_n`). Requires
#'   `groups` (or an auto-detected `species` column); has no effect (no
#'   `$outlier_screen` element, no message) if no grouping is available,
#'   since "distance from other individuals of the same species" is
#'   undefined without species labels. Defaults to `TRUE`. This never
#'   removes any observation: it only flags candidates for visual/manual
#'   review (e.g. with [plot_landmarks()] or [plot_fishmorph_points()])
#'   before deciding whether an exclusion is warranted.
#' @param outlier_threshold Numeric, the number of median absolute
#'   deviations (MAD) above a group's median within-group distance beyond
#'   which a specimen is flagged; same convention as
#'   [detect_outliers()]'s `threshold`. Defaults to `3`.
#' @param outlier_min_n Integer, the minimum number of specimens a group
#'   must have for outlier flagging to be attempted in it; groups smaller
#'   than this still get a computed distance (in `$outlier_screen`) but are
#'   never flagged (`NA`), since a median/MAD computed from very few points
#'   is not a reliable reference. Defaults to `5`.
#' @param remove_outliers Logical, actually exclude every specimen flagged
#'   by `flag_outliers` from the trait matrix *before* building the
#'   ordination (rather than only flagging them for review, the default).
#'   Requires `flag_outliers = TRUE` (an error is raised otherwise, since
#'   there would be nothing to remove). Defaults to `FALSE`: removing
#'   specimens changes the ordination and any statistic derived from it
#'   (e.g. [trait_disparity()], [bootstrap_functional_space()]), so this is
#'   opt-in rather than automatic, and every removal is still recorded in
#'   `$removed_outliers` (see Return) for transparency and reproducibility
#'   -- always confirm flagged specimens genuinely reflect an error (e.g.
#'   via [plot_landmarks()]/[plot_fishmorph_points()]) before turning this
#'   on for a given data set, rather than treating it as a default cleaning
#'   step.
#'
#' @return An object of class `"intrait_traitspace"`, a list with elements
#'   `scores` (data.frame of ordination scores), `var_explained` (percent
#'   variance explained by the two selected axes), `loadings` (PCA
#'   variable loadings, `NULL` for `method = "pcoa"`), `groups`, `axes`,
#'   `method`, `traits_used` (names of the numeric columns used), `X`
#'   (the full standardised trait matrix actually analysed, i.e. after
#'   log-transformation, removal of constant columns, and any outlier
#'   removal, centred/scaled as requested; used internally by
#'   [trait_disparity()] so that dispersion statistics are not truncated to
#'   the two plotting axes), and, when `flag_outliers = TRUE` and `groups`
#'   is available, `outlier_screen` (a `data.frame`, one row per specimen
#'   *actually used in the ordination* -- i.e. excluding any row removed by
#'   `remove_outliers = TRUE` -- with columns `group`, `n_group`, `distance`
#'   (to the specimen's own group centroid, in the full standardised trait
#'   space `X`), `median_distance`, `mad_distance`, `threshold_value`, and
#'   `flagged`; see Details), and `removed_outliers` (`NULL` unless
#'   `remove_outliers = TRUE` removed at least one specimen, in which case
#'   a `data.frame` with the same columns as `outlier_screen`, one row per
#'   *excluded* specimen, for the record). Has a dedicated [plot()] method.
#'
#' @details
#' A non-finite trait value (`Inf`/`-Inf`) is rejected with an error
#' regardless of `na_action`, before any missing-value handling: unlike
#' `NA`, `is.na()`/`anyNA()` do not detect `Inf`/`-Inf`, so such a value
#' would otherwise silently pass through every `na_action` unimputed and
#' corrupt the ordination (and, specifically for `na_action =
#' "missforest"`, can crash `missForest::missForest()` itself with a
#' cryptic "missing value where TRUE/FALSE needed" error, because its
#' internal convergence check computes `Inf - Inf = NaN`). This most
#' commonly arises from a ratio with a zero-length denominator segment,
#' e.g. from a degenerate or duplicated landmark (see
#' [fishmorph_segments()]/[fishmorph_ratios()]); investigate and correct
#' the underlying measurement, or replace it with `NA` yourself first if
#' you want it handled like any other missing value.
#'
#' By default (`na_action = "fail"`), rows with `NA` in any numeric trait
#' cause an error; set `na_action` to `"omit"` or one of the imputation
#' options to handle missing values automatically (see `na_action`). Mean
#' imputation (`"impute_mean"`, `"impute_group_mean"`) is a simple,
#' commonly used approach for small amounts of missing data in functional
#' trait matrices, but it shrinks the imputed trait's variance, ignores
#' correlations among traits, and can understate group dispersion (see
#' [trait_disparity()]). `na_action = "missforest"` addresses these
#' limitations with nonparametric random-forest imputation (Stekhoven &
#' Bühlmann, 2012), which uses the correlation structure among all
#' numeric traits (and `groups`, when available, as an auxiliary
#' predictor) to predict each missing value, and is generally preferred
#' over mean imputation once more than a few values are missing;
#' it requires the `missForest` package (not installed by default; see
#' `Suggests`) and is stochastic, so results vary run to run unless
#' `set.seed()` is called beforehand. `na_action = "missforest_phylo"`
#' extends this further with phylogenetic PCoA axes (see [phylo_pcoa()])
#' as additional predictors, so species can also borrow information from
#' their close relatives, not only from shared species identity; this can
#' help when a species has very few (or zero) complete specimens of its
#' own for `missForest` to learn from, but adds a phylogenetic assumption
#' (trait similarity correlates with relatedness) that should be
#' reasonable for the trait in question. If a very large fraction of values
#' is missing, no automated imputation method is a substitute for
#' reviewing the missing-data mechanism directly. This function does not
#' implement Gower distance for mixed (numeric and categorical) trait
#' tables; for mixed-trait functional spaces, standard tools such as the
#' `mFD` or `FD` packages should be used instead.
#'
#' Note that this log-transform-then-standardise treatment applies to
#' *trait* data (ratios, linear measurements, etc.) only. It is not applied
#' by, and should not be applied to, [morpho_space()], which ordinates
#' Procrustes shape coordinates: those are already a homogeneous,
#' size-free coordinate system in which log-transforming or rescaling
#' individual columns would distort shape geometry.
#'
#' When `flag_outliers = TRUE` (the default), every specimen's Euclidean
#' distance to its own group's centroid is computed on the full
#' standardised trait matrix `X` (all traits, not just the two plotting
#' axes), and, within each group with at least `outlier_min_n` specimens,
#' flagged if that distance exceeds `median + outlier_threshold * MAD`
#' (median absolute deviation) of that group's own within-group distances
#' -- the same robust rule used by [detect_outliers()], but computed
#' *within* each group rather than pooled across the whole sample.
#' Pooling across species, as a naive global outlier screen would, mostly
#' flags genuine interspecific morphological diversity rather than
#' digitization or identification errors (see the worked pooled-vs-within-
#' species comparison in `demo(pipeline_T26_saudrune)`); computing this
#' automatically, per group, inside `trait_space()` removes the need to
#' subset by hand. A single extreme specimen in an otherwise tight species
#' can also visibly distort the ordination for every *other* group, by
#' inflating the axis ranges/variance explained: a species-level outlier
#' is therefore often the right first thing to check when a functional
#' space "does not look right" (widely spread groups collapsed into one
#' corner of the plot), before considering, e.g., a different `na_action`
#' or transformation. As with [detect_outliers()], this only *flags*
#' candidates -- it never removes anything automatically, since ad hoc,
#' undocumented removal of "bad-looking" specimens is itself a threat to
#' reproducibility; always inspect a flagged specimen (e.g. with
#' [plot_landmarks()]/[plot_fishmorph_points()], and its original
#' photograph if available) before deciding whether to exclude it, and
#' record that decision (e.g. in a QC log, as
#' `data-raw/t26_saudrune_prepare.R` does for the bundled real data set)
#' rather than silently dropping rows. This is a Euclidean, not
#' Mahalanobis, distance (like [detect_outliers()]), so it does not
#' account for correlations among traits; it is intended as a fast,
#' transparent first pass, not a definitive statistical test.
#'
#' Setting `remove_outliers = TRUE` goes one step further and actually
#' excludes every flagged specimen before the ordination is built (rather
#' than only flagging it): `X`, `groups`, and `scores` in the returned
#' object then describe the *cleaned* data set, and `$removed_outliers`
#' records exactly which specimens were dropped and why, so the exclusion
#' remains fully reproducible and auditable (e.g. reportable in a
#' manuscript's methods) rather than an undocumented, ad hoc edit made
#' before calling `trait_space()`. This is deliberately opt-in
#' (`FALSE` by default): removing data always changes downstream results
#' and should be a conscious, visually-confirmed decision (see above), not
#' something that happens silently just because a threshold was crossed.
#'
#' @references
#' Villéger, S., Brosse, S., Mouchet, M., Mouillot, D., & Vanni, M. J.
#' (2017). Functional ecology of fish: current approaches and future
#' challenges. Aquatic Sciences, 79(4), 783-801.
#'
#' @seealso [fishmorph_ratios()], [morpho_ratios()], [morpho_space()],
#'   [detect_outliers()], [load_t26_saudrune_landmarks()]
#'
#' @examples
#' # real T-26 Saudrune data; na_action = "omit" is required here because,
#' # unlike simulate_fishmorph_points(), real specimens have some missing
#' # landmarks (see ?load_t26_saudrune_landmarks)
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#' ts   # flags any within-species outliers found, see ts$outlier_screen
#' \donttest{
#' plot(ts)
#' }
#'
#' # Once a flagged specimen has been visually confirmed as an error (not
#' # just genuine morphological variation), exclude it from the ordination:
#' ts_clean <- trait_space(
#'   ratios, groups = fish$metadata$species, na_action = "omit",
#'   remove_outliers = TRUE
#' )
#' ts_clean$removed_outliers   # exactly which specimen(s) were excluded, and why
#'
#' @export
trait_space <- function(traits, groups = NULL, method = c("pca", "pcoa"),
                         log_transform = TRUE, scale = TRUE, axes = c(1, 2),
                         na_action = c("fail", "omit", "impute_mean", "impute_group_mean",
                                       "missforest", "missforest_phylo"),
                         missforest_ntree = 100, missforest_maxiter = 10,
                         tree = NULL, missforest_phylo_k = 10,
                         flag_outliers = TRUE, outlier_threshold = 3, outlier_min_n = 5,
                         remove_outliers = FALSE) {
  method <- match.arg(method)
  na_action <- match.arg(na_action)
  if (isTRUE(remove_outliers) && !isTRUE(flag_outliers)) {
    stop("`remove_outliers = TRUE` requires `flag_outliers = TRUE` (the default).", call. = FALSE)
  }
  if (!is.data.frame(traits) && !is.matrix(traits)) {
    stop("`traits` must be a data.frame or matrix of numeric trait values.", call. = FALSE)
  }
  traits_df <- as.data.frame(traits)

  if (is.null(groups) && "species" %in% names(traits_df)) {
    groups <- traits_df$species
  }
  if (!is.null(groups)) {
    if (length(groups) != nrow(traits_df)) stop("`groups` must have one entry per row of `traits`.", call. = FALSE)
    groups <- factor(groups)
    if (anyNA(groups)) {
      keep_g <- !is.na(groups)
      message(sprintf(
        paste(
          "Removing %d row(s) with a missing/unresolved `groups` value (e.g. an",
          "unidentified specimen): a group-wise trait space cannot place a specimen",
          "whose group is unknown."
        ),
        sum(!keep_g)
      ))
      traits_df <- traits_df[keep_g, , drop = FALSE]
      groups <- droplevels(groups[keep_g])
    }
  }

  numeric_cols <- names(traits_df)[vapply(traits_df, is.numeric, logical(1))]
  dropped <- setdiff(names(traits_df), numeric_cols)
  if (length(numeric_cols) == 0) stop("`traits` must contain at least two numeric columns.", call. = FALSE)
  if (length(dropped) > 0) {
    warning("Dropping non-numeric column(s) from the ordination: ", paste(dropped, collapse = ", "), call. = FALSE)
  }

  X <- as.matrix(traits_df[numeric_cols])

  # Inf/-Inf are not caught by anyNA()/is.na() (only NA and NaN are), so a
  # ratio with a zero-length denominator (e.g. a degenerate/duplicate
  # landmark collapsing a segment to zero -- see fishmorph_segments()/
  # fishmorph_ratios()) would otherwise sail straight through every
  # `na_action`, silently corrupting the ordination -- and, for
  # na_action = "missforest" specifically, can crash missForest itself
  # with a cryptic "missing value where TRUE/FALSE needed" error, because
  # its convergence check computes Inf - Inf = NaN internally. Caught here,
  # unconditionally (regardless of `na_action`), since a non-finite value
  # is not an ordinary missing measurement and should not be imputed as if
  # it were one.
  non_finite <- !is.na(X) & !is.finite(X)
  if (any(non_finite)) {
    bad <- which(non_finite, arr.ind = TRUE)
    bad_cols <- unique(colnames(X)[bad[, "col"]])
    bad_rows <- rownames(X)[bad[, "row"]]
    if (is.null(bad_rows) || anyNA(bad_rows)) bad_rows <- as.character(bad[, "row"])
    bad_rows <- unique(bad_rows)
    stop(sprintf(
      paste(
        "`traits` contains %d non-finite value(s) (Inf/-Inf, not NA) in",
        "column(s): %s. This is not an ordinary missing value and is not",
        "handled by `na_action` -- it usually indicates a zero-length",
        "denominator segment (e.g. from a degenerate/duplicate landmark;",
        "see fishmorph_segments()/fishmorph_ratios()) rather than a",
        "genuinely missing measurement. Affected row(s): %s%s. Investigate",
        "and correct the underlying measurement(s), or explicitly replace",
        "these entries with NA yourself first if you do want them treated",
        "as missing data by `na_action`."
      ),
      sum(non_finite), paste(bad_cols, collapse = ", "),
      paste(utils::head(bad_rows, 10), collapse = ", "),
      if (length(bad_rows) > 10) ", ..." else ""
    ), call. = FALSE)
  }

  if (anyNA(X)) {
    if (na_action == "fail") {
      stop(
        "`traits` contains missing values; remove or impute NAs before building ",
        "a trait space, or set `na_action` to \"omit\", \"impute_mean\", ",
        "\"impute_group_mean\", \"missforest\", or \"missforest_phylo\" (see ?trait_space).",
        call. = FALSE
      )
    }
    if (na_action == "impute_group_mean" && is.null(groups)) {
      stop(
        "`na_action = \"impute_group_mean\"` requires `groups` (or a `species` ",
        "column in `traits`) to be available.",
        call. = FALSE
      )
    }

    if (na_action == "omit") {
      keep <- stats::complete.cases(X)
      n_dropped <- sum(!keep)
      message(sprintf(
        "na_action = \"omit\": removing %d row(s) out of %d with missing values.",
        n_dropped, nrow(X)
      ))
      X <- X[keep, , drop = FALSE]
      traits_df <- traits_df[keep, , drop = FALSE]
      if (!is.null(groups)) groups <- droplevels(groups[keep])
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
      n_na <- sum(is.na(X))
      for (j in seq_len(ncol(X))) {
        col <- X[, j]
        col_na <- is.na(col)
        if (!any(col_na)) next
        for (g in levels(groups)) {
          idx <- groups == g & col_na
          if (!any(idx)) next
          g_mean <- mean(col[groups == g], na.rm = TRUE)
          if (is.nan(g_mean)) {
            warning(
              "Group \"", g, "\" has no non-missing values for at least one trait; ",
              "falling back to the overall column mean for imputation.",
              call. = FALSE
            )
            g_mean <- mean(col, na.rm = TRUE)
          }
          col[idx] <- g_mean
        }
        X[, j] <- col
      }
      message(sprintf(
        "na_action = \"impute_group_mean\": imputed %d missing value(s) using within-group means.",
        n_na
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
      X <- as.matrix(ximp[, numeric_cols, drop = FALSE])
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
  }

  if (isTRUE(log_transform)) {
    if (any(X < 0)) {
      stop(
        "`log_transform = TRUE` requires all trait values to be non-negative ",
        "(log10(x + 1) is not meaningful for negative traits); set `log_transform = FALSE` ",
        "or check your data.",
        call. = FALSE
      )
    }
    X <- log10(X + 1)
  }

  col_sd <- apply(X, 2, stats::sd)
  zero_var <- colnames(X)[col_sd == 0]
  if (length(zero_var) > 0) {
    warning(
      "Dropping constant (zero-variance) column(s) from the ordination: ",
      paste(zero_var, collapse = ", "), call. = FALSE
    )
    X <- X[, setdiff(colnames(X), zero_var), drop = FALSE]
  }
  numeric_cols <- colnames(X)
  if (ncol(X) < 2) {
    stop(
      "`traits` must contain at least two numeric columns after removing ",
      "constant (zero-variance) columns.",
      call. = FALSE
    )
  }
  if (length(axes) != 2) stop("`axes` must be a length-2 integer vector.", call. = FALSE)

  # Standardised matrix actually analysed (post log-transform, post
  # zero-variance-column removal, centred/scaled as requested), kept for
  # re-use by trait_disparity() so that dispersion statistics are computed
  # on exactly the same preprocessed data as the ordination, without
  # truncation to the 2 plotting axes.
  X_std <- scale(X, center = TRUE, scale = scale)

  # Outlier screening happens here, BEFORE the ordination itself, so that
  # (when remove_outliers = TRUE) flagged specimens are excluded from X,
  # traits_df and groups before the PCA/PCoA is computed, not just flagged
  # in an ordination that still includes them.
  outlier_screen <- NULL
  removed_outliers <- NULL
  if (isTRUE(flag_outliers) && !is.null(groups)) {
    outlier_screen <- .group_outlier_distance(
      X_std, groups, threshold = outlier_threshold, min_n = outlier_min_n
    )
    n_flagged <- sum(outlier_screen$flagged, na.rm = TRUE)
    n_flaggable_groups <- length(unique(outlier_screen$group[!is.na(outlier_screen$flagged)]))
    n_skipped_groups <- length(unique(outlier_screen$group)) - n_flaggable_groups

    if (isTRUE(remove_outliers) && n_flagged > 0) {
      is_flagged <- !is.na(outlier_screen$flagged) & outlier_screen$flagged
      removed_outliers <- outlier_screen[is_flagged, , drop = FALSE]
      flagged_groups <- sort(unique(removed_outliers$group))
      message(sprintf(
        paste(
          "remove_outliers: removing %d specimen(s) flagged as within-group",
          "outlier(s) across %d group(s) (%s) before building the ordination;",
          "see $removed_outliers for exactly which ones, and why, before",
          "relying on this in a publication -- always confirm each removal",
          "corresponds to a real error (e.g. via plot_landmarks()/",
          "plot_fishmorph_points()), not just genuine morphological variation."
        ),
        n_flagged, length(flagged_groups), paste(flagged_groups, collapse = ", ")
      ))

      keep <- !is_flagged
      X <- X[keep, , drop = FALSE]
      traits_df <- traits_df[keep, , drop = FALSE]
      groups <- droplevels(groups[keep])
      X_std <- scale(X, center = TRUE, scale = scale)
      outlier_screen <- outlier_screen[keep, , drop = FALSE]
    } else if (n_flagged > 0) {
      flagged_groups <- sort(unique(outlier_screen$group[which(outlier_screen$flagged)]))
      message(sprintf(
        paste(
          "flag_outliers: %d specimen(s) flagged as within-group outlier(s)",
          "across %d group(s) (%s); this only flags candidates for review",
          "(e.g. with plot_landmarks()/plot_fishmorph_points()), nothing was",
          "removed automatically. Set remove_outliers = TRUE to exclude them",
          "from the ordination, or see $outlier_screen for details."
        ),
        n_flagged, length(flagged_groups), paste(flagged_groups, collapse = ", ")
      ))
    }

    if (n_skipped_groups > 0) {
      message(sprintf(
        paste(
          "flag_outliers: %d group(s) have fewer than outlier_min_n = %d",
          "specimens and were not screened (distance still reported,",
          "flagged = NA)."
        ),
        n_skipped_groups, outlier_min_n
      ))
    }
  }

  if (method == "pca") {
    pca <- stats::prcomp(X, center = TRUE, scale. = scale)
    if (max(axes) > ncol(pca$x)) {
      stop("`axes` requests a component beyond the ", ncol(pca$x), " available.", call. = FALSE)
    }
    scores <- as.data.frame(pca$x[, axes, drop = FALSE])
    var_explained <- (pca$sdev^2 / sum(pca$sdev^2))[axes] * 100
    loadings <- pca$rotation
    axis_prefix <- "PC"
  } else {
    Xs <- scale(X, center = TRUE, scale = scale)
    d <- stats::dist(Xs, method = "euclidean")
    mds <- stats::cmdscale(d, k = max(axes), eig = TRUE)
    if (max(axes) > ncol(mds$points)) {
      stop("`axes` requests a component beyond the ", ncol(mds$points), " available.", call. = FALSE)
    }
    scores <- as.data.frame(mds$points[, axes, drop = FALSE])
    eig_pos <- mds$eig[mds$eig > 0]
    var_explained <- (mds$eig[axes] / sum(eig_pos)) * 100
    loadings <- NULL
    axis_prefix <- "MDS"
  }

  names(scores) <- paste0(axis_prefix, axes)
  rownames(scores) <- rownames(traits_df)

  structure(
    list(
      scores = scores,
      var_explained = stats::setNames(var_explained, names(scores)),
      loadings = loadings,
      groups = groups,
      axes = axes,
      method = method,
      traits_used = numeric_cols,
      X = X_std,
      scale = scale,
      outlier_screen = outlier_screen,
      removed_outliers = removed_outliers
    ),
    class = "intrait_traitspace"
  )
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname trait_space
#' @param x An object of class `"intrait_traitspace"`, as returned by
#'   [trait_space()].
#' @param ... Currently unused.
print.intrait_traitspace <- function(x, ...) {
  cat("<intrait_traitspace> (", x$method, ")\n", sep = "")
  cat(sprintf(
    "  Axes %s/%s, variance explained: %.1f%% / %.1f%%\n",
    names(x$scores)[1], names(x$scores)[2], x$var_explained[1], x$var_explained[2]
  ))
  cat(sprintf(
    "  %d observations, %d traits (%s)\n",
    nrow(x$scores), length(x$traits_used), paste(x$traits_used, collapse = ", ")
  ))
  if (!is.null(x$groups)) cat(sprintf("  %d groups\n", nlevels(x$groups)))
  if (!is.null(x$removed_outliers)) {
    cat(sprintf(
      "  %d specimen(s) removed as within-group outliers before this ordination\n",
      nrow(x$removed_outliers)
    ))
    cat("  (see $removed_outliers): ", paste(rownames(x$removed_outliers), collapse = ", "), "\n", sep = "")
  }
  if (!is.null(x$outlier_screen)) {
    n_flagged <- sum(x$outlier_screen$flagged, na.rm = TRUE)
    if (n_flagged > 0) {
      top <- x$outlier_screen[order(-x$outlier_screen$distance), , drop = FALSE][seq_len(min(n_flagged, 5)), ]
      cat(sprintf(
        "  %d potential within-group outlier(s) flagged (see $outlier_screen); most atypical:\n",
        n_flagged
      ))
      for (i in seq_len(nrow(top))) {
        cat(sprintf(
          "    %s (%s): distance = %.3f (group median %.3f)\n",
          rownames(top)[i], top$group[i], top$distance[i], top$median_distance[i]
        ))
      }
    } else {
      cat("  No within-group outliers flagged (see $outlier_screen)\n")
    }
  }
  invisible(x)
}

#' Plot a functional trait space
#'
#' @param x An object of class `"intrait_traitspace"`, from
#'   [trait_space()].
#' @param style Character, one of `"spider"` (default), `"hull"`,
#'   `"density"`, or `"none"`, controlling how groups are displayed; see
#'   the Details section of [plot.intrait_morphospace()]. Ignored if
#'   `x$groups` is `NULL`. Also named in the plot's title (e.g. `"Trait
#'   space (spider)"`), so the display style used is always legible from
#'   the figure itself, not just from the call that produced it; pass
#'   `main = ` via `...` to override with a custom title instead.
#' @param ellipse_level Coverage probability of the per-group dispersion
#'   ellipse drawn when `style = "spider"`, under a bivariate-normal
#'   approximation. Defaults to `0.95`.
#' @param density_level Coverage probability of the per-group
#'   kernel-density contour drawn when `style = "density"` (see Details of
#'   [plot.intrait_morphospace()]); groups with fewer than 5 points are
#'   silently skipped. Defaults to `0.95`.
#' @param legend Logical, draw a legend of group colors. Defaults to
#'   `TRUE` when `x$groups` is available.
#' @param legend_position One of `"outside"` (default: drawn in the
#'   margin, just outside the plot box, so it never overlaps the data) or
#'   a standard [graphics::legend()] position keyword (e.g. `"topright"`)
#'   to draw it inside the plot box instead.
#' @param legend_title Character, the legend's title. Defaults to
#'   `"Group"`; set to `"Species"` when `x$groups` represents species
#'   identity (as it does, e.g., throughout `demo(pipeline_T26_saudrune)`).
#' @param legend_italic Logical, italicise the legend labels (standard
#'   typographic convention for taxonomic names). Defaults to `FALSE`.
#' @param abbreviate_species Logical, abbreviate `"Genus species"` legend
#'   labels to `"G. species"` (e.g. `"Barbatula barbatula"` becomes
#'   `"B. barbatula"`); labels that are not a clean two-part binomial are
#'   left unchanged. Only affects the legend text. Defaults to `FALSE`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns `x`.
#'
#' @examples
#' \donttest{
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#' # species-flavoured legend: titled "Species", italic, abbreviated binomials
#' plot(ts, legend_title = "Species", legend_italic = TRUE, abbreviate_species = TRUE)
#' }
#' @export
plot.intrait_traitspace <- function(x, style = c("spider", "hull", "density", "none"),
                                     ellipse_level = 0.95, density_level = 0.95,
                                     legend = !is.null(x$groups),
                                     legend_position = "outside",
                                     legend_title = "Group", legend_italic = FALSE,
                                     abbreviate_species = FALSE, ...) {
  style <- match.arg(style)
  xlab <- sprintf("%s (%.1f%%)", names(x$scores)[1], x$var_explained[1])
  ylab <- sprintf("%s (%.1f%%)", names(x$scores)[2], x$var_explained[2])
  .plot_ordination(x$scores, x$groups, xlab, ylab, style = style,
                    ellipse_level = ellipse_level, density_level = density_level,
                    legend = legend, legend_position = legend_position,
                    legend_title = legend_title, legend_italic = legend_italic,
                    abbreviate_species = abbreviate_species, space_name = "Trait space", ...)
  invisible(x)
}
