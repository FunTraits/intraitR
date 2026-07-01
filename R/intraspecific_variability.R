#' Quantify intraspecific morphological variability
#'
#' Combines two complementary approaches to intraspecific variability
#' commonly used in fish ecomorphology: (i) shape-based morphological
#' disparity per group, via a permutation test on Procrustes variance
#' ([geomorph::morphol.disparity()]), and (ii) classical coefficients of
#' variation (CV%) of linear traits or ratios per group.
#'
#' @param gpa Optional object of class `"intrait_gpa"` (from
#'   [gpa_fish()]). Required for the shape-based disparity analysis.
#' @param groups A factor or character vector giving the grouping variable
#'   (e.g. species or population), of the same length and order as the
#'   specimens in `gpa` and/or `traits`.
#' @param traits Optional `data.frame` of linear traits or ratios (e.g.
#'   from [linear_distances()] or [morpho_ratios()]), one row per specimen
#'   in the same order as `groups`. Non-numeric columns are ignored.
#' @param iter Integer, number of permutations for the disparity test.
#'   Defaults to `999`.
#'
#' @return An object of class `"intrait_variability"`, a list optionally
#'   containing:
#'   \describe{
#'     \item{shape_disparity}{the `geomorph` `"morphol.disparity"` object
#'       (Procrustes variance per group, with pairwise permutation
#'       p-values), when `gpa` is supplied.}
#'     \item{trait_cv}{a tidy `data.frame` with columns `group`, `trait`,
#'       `n`, `mean`, `sd`, `cv_percent`, when `traits` is supplied.}
#'   }
#'
#' @details
#' Procrustes variance (mean squared Procrustes distance to the group mean
#' shape) is a standard, unit-free measure of shape disparity and is
#' preferred over CV for shape data because Procrustes coordinates do not
#' have an interpretable scale on their own axes. Coefficients of variation
#' remain informative and widely reported for univariate, biologically
#' interpretable traits (e.g. body depth ratio) and are provided alongside
#' shape disparity for that reason.
#'
#' @references
#' Zelditch ML, Swiderski DL, Sheets HD (2012). Geometric Morphometrics for
#' Biologists: A Primer (2nd ed). Academic Press.
#'
#' @seealso [gpa_fish()], [morpho_ratios()], [measurement_error()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 10, n_replicates = 1)
#' gpa <- gpa_fish(fish)
#' distances <- list(SL = c(1, 7), BD = c(3, 10))
#' ratios <- morpho_ratios(fish, distances, norm_by = "SL")
#' \donttest{
#' iv <- intraspecific_variability(
#'   gpa = gpa, groups = fish$metadata$species,
#'   traits = ratios[, "BD_ratio", drop = FALSE], iter = 99
#' )
#' iv
#' }
#'
#' @export
#' @importFrom geomorph geomorph.data.frame morphol.disparity
intraspecific_variability <- function(gpa = NULL, groups, traits = NULL, iter = 999) {
  if (missing(groups)) stop("`groups` is required.", call. = FALSE)
  if (is.null(gpa) && is.null(traits)) {
    stop("Supply at least one of `gpa` or `traits`.", call. = FALSE)
  }

  results <- list()

  if (!is.null(gpa)) {
    if (!inherits(gpa, "intrait_gpa")) {
      stop("`gpa` must be an object returned by gpa_fish().", call. = FALSE)
    }
    groups_f <- factor(groups)
    gdf <- geomorph::geomorph.data.frame(coords = gpa$coords, groups = groups_f)
    results$shape_disparity <- geomorph::morphol.disparity(
      coords ~ 1, groups = ~groups, data = gdf, iter = iter, print.progress = FALSE
    )
  }

  if (!is.null(traits)) {
    traits <- as.data.frame(traits)
    numeric_cols <- names(traits)[vapply(traits, is.numeric, logical(1))]
    if (length(numeric_cols) == 0) stop("`traits` contains no numeric columns.", call. = FALSE)
    group_f <- factor(groups)

    rows <- list()
    for (tr in numeric_cols) {
      x_all <- traits[[tr]]
      for (g in levels(group_f)) {
        xi <- x_all[group_f == g]
        rows[[length(rows) + 1]] <- data.frame(
          group = g, trait = tr, n = sum(!is.na(xi)),
          mean = mean(xi, na.rm = TRUE), sd = stats::sd(xi, na.rm = TRUE),
          cv_percent = .cv_percent(xi), stringsAsFactors = FALSE
        )
      }
    }
    trait_cv <- do.call(rbind, rows)
    rownames(trait_cv) <- NULL
    results$trait_cv <- trait_cv
  }

  structure(results, class = "intrait_variability")
}

#' @export
print.intrait_variability <- function(x, ...) {
  cat("<intrait_variability>\n")
  if (!is.null(x$shape_disparity)) {
    cat("-- Shape (Procrustes variance) disparity --\n")
    print(x$shape_disparity)
  }
  if (!is.null(x$trait_cv)) {
    cat("-- Coefficient of variation (%) of linear traits --\n")
    print(x$trait_cv, row.names = FALSE)
  }
  invisible(x)
}
