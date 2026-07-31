#' Impute missing trait values, and say which cells were invented
#'
#' The imputation that [trait_space()], [fishmorph_ratios()] and
#' [fishmorph_segments()] perform internally, exposed on its own so that a
#' filled trait table can be **kept** rather than recomputed inside every
#' ordination -- and, above all, so that the cells that were filled can travel
#' with it.
#'
#' @section Why the mask matters more than the values:
#' An imputed value is indistinguishable from a measured one once it is in a
#' table: it has the same type, the same magnitude, and it makes every
#' completeness check pass. The `imputed` matrix returned here is the only
#' thing that keeps the two apart afterwards, and it is what lets a downstream
#' analysis weight, exclude or simply report them. A function that returned the
#' filled matrix alone would be handing back a table that has quietly stopped
#' being a record of measurements.
#'
#' @section Choosing a method:
#' `"impute_group_mean"` replaces a missing value with the mean of its species.
#' It is transparent and reproducible, and it CONTRACTS INTRASPECIFIC
#' VARIABILITY -- every imputed individual is placed exactly at its species'
#' centre -- which is a problem when intraspecific variability is the quantity
#' being measured. `"missforest"` predicts each trait from the others by random
#' forest and preserves more of the spread; `"missforest_phylo"` adds
#' phylogenetic PCoA axes as predictors (see [phylo_pcoa()]) and falls back to
#' plain `"missforest"`, with a message, when no usable tree is available.
#' Both report an out-of-bag NRMSE, which is the honest measure of how much the
#' filled values can be trusted.
#'
#' @param traits A data.frame or matrix of numeric traits, one row per
#'   specimen. Non-numeric columns are dropped, with a warning.
#' @param method Imputation method: `"impute_mean"`, `"impute_group_mean"`,
#'   `"missforest"` or `"missforest_phylo"`. `"omit"` drops the incomplete rows
#'   instead of filling them, and `"keep"` returns the table untouched -- both
#'   accepted so that a caller can pass the user's choice through unchanged.
#' @param groups Grouping factor, one value per row: the key of
#'   `"impute_group_mean"` and a categorical predictor for the forests. `NULL`
#'   uses `species` when it is given.
#' @param species Species name per row, used only to look up the phylogenetic
#'   axes of `"missforest_phylo"`.
#' @param tree,phylo_axes,missforest_phylo_k Phylogeny for
#'   `"missforest_phylo"`; see [trait_space()].
#' @param missforest_ntree,missforest_maxiter Passed to
#'   [missForest::missForest()].
#' @return A list of class `"intrait_imputation"`:
#'   \describe{
#'     \item{`traits`}{the filled data.frame, in the order given}
#'     \item{`imputed`}{a logical matrix of the same shape, `TRUE` where a
#'       value was invented}
#'     \item{`keep`}{logical vector, `FALSE` for rows dropped by `"omit"`}
#'     \item{`method`}{the method applied}
#'     \item{`n_missing`,`n_imputed`}{counts before and after}
#'   }
#' @seealso [trait_space()], [fishmorph_ratios()], [impute_landmarks()]
#' @examples
#' set.seed(1)
#' d <- data.frame(a = rnorm(20), b = rnorm(20), c = rnorm(20))
#' d$a[c(2, 7)] <- NA
#' im <- impute_traits(d, method = "impute_mean")
#' sum(im$imputed)
#' @export
impute_traits <- function(traits,
                          method = c("missforest_phylo", "missforest",
                                     "impute_group_mean", "impute_mean",
                                     "omit", "keep"),
                          groups = NULL, species = NULL,
                          tree = NULL, phylo_axes = NULL,
                          missforest_phylo_k = 10,
                          missforest_ntree = 100, missforest_maxiter = 10) {
  method <- match.arg(method)
  if (!is.data.frame(traits) && !is.matrix(traits)) {
    stop("`traits` must be a data.frame or a matrix.", call. = FALSE)
  }
  df <- as.data.frame(traits, stringsAsFactors = FALSE)
  num <- names(df)[vapply(df, is.numeric, logical(1))]
  dropped <- setdiff(names(df), num)
  if (length(dropped)) {
    warning("Dropping non-numeric column(s): ", paste(dropped, collapse = ", "),
            call. = FALSE)
  }
  if (!length(num)) {
    stop("`traits` holds no numeric column to impute.", call. = FALSE)
  }
  X <- as.matrix(df[, num, drop = FALSE])
  storage.mode(X) <- "double"
  rn <- rownames(df)

  # The mask is taken BEFORE the imputation, because after it there is nothing
  # left in the data to tell a filled cell from a measured one.
  miss <- is.na(X)
  n_missing <- sum(miss)

  if (is.null(groups) && !is.null(species)) groups <- species

  res <- .apply_na_action(
    X, groups = groups, na_action = method,
    missforest_ntree = missforest_ntree, missforest_maxiter = missforest_maxiter,
    context = "traits", tree = tree, missforest_phylo_k = missforest_phylo_k,
    phylo_axes = phylo_axes, species = species)

  Xi <- res$X
  keep <- res$keep
  mask <- miss[keep, , drop = FALSE]
  # A cell that was missing and is still missing was not imputed: "impute_mean"
  # can leave a wholly empty column untouched, and reporting it as filled would
  # be the exact opposite of what this mask is for.
  mask <- mask & !is.na(Xi)

  out <- as.data.frame(Xi, stringsAsFactors = FALSE)
  names(out) <- num
  if (!is.null(rn)) rownames(out) <- rn[keep]
  dimnames(mask) <- list(rownames(out), num)

  structure(list(traits = out, imputed = mask, keep = keep, method = method,
                 n_missing = n_missing, n_imputed = sum(mask),
                 columns = num),
            class = "intrait_imputation")
}

#' @export
print.intrait_imputation <- function(x, ...) {
  cat("Trait imputation:", x$method, "\n")
  cat(sprintf("  %d row(s) x %d trait(s)\n", nrow(x$traits), ncol(x$traits)))
  cat(sprintf("  %d missing value(s) before, %d filled, %d still missing\n",
              x$n_missing, x$n_imputed, sum(is.na(x$traits))))
  if (any(!x$keep))
    cat(sprintf("  %d row(s) dropped\n", sum(!x$keep)))
  per <- colSums(x$imputed)
  per <- per[per > 0]
  if (length(per))
    cat("  by trait: ",
        paste(sprintf("%s %d", names(per), per), collapse = ", "), "\n", sep = "")
  invisible(x)
}
