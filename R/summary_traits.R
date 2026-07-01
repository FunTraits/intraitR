#' Summarise morphological traits by group
#'
#' Produces a tidy summary (n, mean, standard deviation, min, max) of one
#' or more morphological traits (e.g. linear distances or ratios), broken
#' down by a grouping variable such as species or population.
#'
#' @param traits A numeric `data.frame` (or matrix) of traits, one row per
#'   specimen, as returned by e.g. [linear_distances()] or
#'   [morpho_ratios()]. Non-numeric columns are dropped with a warning.
#' @param groups A factor or character vector of the same length as
#'   `nrow(traits)`, giving the grouping variable.
#'
#' @return A tidy `data.frame` with one row per group/trait combination and
#'   columns `group`, `trait`, `n`, `mean`, `sd`, `min`, `max`.
#'
#' @seealso [intraspecific_variability()], [morpho_ratios()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
#' distances <- list(SL = c(1, 7), BD = c(3, 10))
#' ratios <- morpho_ratios(fish, distances, norm_by = "SL")
#' summary_traits(ratios[, "BD_ratio", drop = FALSE], fish$metadata$species)
#'
#' @export
summary_traits <- function(traits, groups) {
  traits <- as.data.frame(traits)
  numeric_cols <- names(traits)[vapply(traits, is.numeric, logical(1))]
  dropped <- setdiff(names(traits), numeric_cols)
  if (length(numeric_cols) == 0) stop("`traits` contains no numeric columns.", call. = FALSE)
  if (length(dropped) > 0) {
    warning("Dropping non-numeric column(s): ", paste(dropped, collapse = ", "), call. = FALSE)
  }
  if (length(groups) != nrow(traits)) {
    stop("`groups` must have one entry per row of `traits`.", call. = FALSE)
  }

  group_f <- factor(groups)
  rows <- list()
  for (tr in numeric_cols) {
    x_all <- traits[[tr]]
    for (g in levels(group_f)) {
      x <- x_all[group_f == g]
      rows[[length(rows) + 1]] <- data.frame(
        group = g, trait = tr, n = sum(!is.na(x)),
        mean = mean(x, na.rm = TRUE), sd = stats::sd(x, na.rm = TRUE),
        min = suppressWarnings(min(x, na.rm = TRUE)),
        max = suppressWarnings(max(x, na.rm = TRUE)),
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
