#' Detect potential digitization outliers from a GPA-aligned sample
#'
#' Flags specimens whose Procrustes distance to the sample consensus shape
#' is unusually large, a fast, general-purpose quality-control screen for
#' landmark digitization errors (mislabelled points, landmarks digitized
#' out of order, or gross measurement mistakes), in the spirit of the
#' exploratory outlier screening implemented by
#' [geomorph::plotOutliers()].
#'
#' @param gpa An object of class `"intrait_gpa"` (from [gpa_fish()]).
#' @param threshold Numeric, the number of median absolute deviations
#'   (MAD) above the median Procrustes distance beyond which a specimen is
#'   flagged. Defaults to `3`. The median and MAD are used, rather than
#'   the mean and standard deviation, because they are themselves robust
#'   to the outliers being screened for.
#' @param plot Logical, draw an ordered dot plot of Procrustes distances
#'   with flagged specimens highlighted and the threshold marked as a
#'   dashed line. Defaults to `TRUE`.
#'
#' @return An object of class `"intrait_outliers"`, a list with elements
#'   `procrustes_distance` (named numeric vector, one value per specimen),
#'   `threshold_value` (the numeric Procrustes-distance cut-off implied by
#'   `threshold`), `outliers` (character vector of flagged specimen
#'   names), and `rank` (a `data.frame` with columns `specimen`,
#'   `procrustes_distance`, `outlier`, ordered from most to least
#'   atypical). Has a dedicated print method; if `plot = TRUE`, a base R
#'   plot is also drawn as a side effect.
#'
#' @details
#' This is a coarse, univariate screen based on overall Procrustes
#' distance to the consensus shape, intended as a fast first pass rather
#' than a definitive statistical test: a genuinely unusual but correctly
#' digitized specimen (e.g. a naturally extreme morphology) will also be
#' flagged, while a digitization error affecting only a subset of
#' landmarks in a way that partly cancels out in the overall Procrustes
#' distance could be missed. Always visually inspect flagged specimens
#' (e.g. with [plot_landmarks()] or [plot_fishmorph_points()]) before
#' excluding them from downstream analyses.
#'
#' @seealso [gpa_fish()], [plot_landmarks()], [plot_fishmorph_points()]
#'
#' @examples
#' # real T-26 Saudrune data (see ?fishmorph_shape_landmarks for why the
#' # scale bar and incomplete specimens are dropped before GPA):
#' fish <- load_t26_saudrune_landmarks()
#' gpa <- gpa_fish(fishmorph_shape_landmarks(fish))
#' out <- detect_outliers(gpa, plot = FALSE)
#' out
#'
#' @export
detect_outliers <- function(gpa, threshold = 3, plot = TRUE) {
  if (!inherits(gpa, "intrait_gpa")) {
    stop("`gpa` must be an object returned by gpa_fish().", call. = FALSE)
  }
  if (!is.numeric(threshold) || length(threshold) != 1 || threshold <= 0) {
    stop("`threshold` must be a single positive number.", call. = FALSE)
  }

  coords <- gpa$coords
  consensus <- gpa$consensus
  n <- dim(coords)[3]
  specimen_names <- dimnames(coords)[[3]]
  if (is.null(specimen_names)) specimen_names <- paste0("specimen_", seq_len(n))

  pd <- vapply(seq_len(n), function(i) {
    sqrt(sum((coords[, , i] - consensus)^2))
  }, numeric(1))
  names(pd) <- specimen_names

  med <- stats::median(pd)
  mad_val <- stats::mad(pd)
  if (isTRUE(mad_val == 0)) {
    threshold_value <- med
    warning(
      "Procrustes distances have zero median absolute deviation (little or ",
      "no variation among specimens); no specimen can be reliably flagged.",
      call. = FALSE
    )
  } else {
    threshold_value <- med + threshold * mad_val
  }

  is_outlier <- pd > threshold_value
  rank_df <- data.frame(
    specimen = specimen_names,
    procrustes_distance = as.numeric(pd),
    outlier = is_outlier,
    stringsAsFactors = FALSE
  )
  rank_df <- rank_df[order(-rank_df$procrustes_distance), ]
  rownames(rank_df) <- NULL

  result <- structure(
    list(
      procrustes_distance = pd,
      threshold_value = threshold_value,
      outliers = specimen_names[is_outlier],
      rank = rank_df
    ),
    class = "intrait_outliers"
  )

  if (isTRUE(plot)) {
    ord <- order(pd)
    graphics::plot(
      pd[ord], seq_len(n),
      pch = ifelse(is_outlier[ord], 19, 1),
      col = ifelse(is_outlier[ord], "firebrick", "black"),
      xlab = "Procrustes distance to consensus", ylab = "Specimen rank",
      main = "Digitization outlier screening"
    )
    graphics::abline(v = threshold_value, lty = 2, col = "firebrick")
  }

  result
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname detect_outliers
#' @param x An object of class `"intrait_outliers"`, as returned by
#'   [detect_outliers()].
print.intrait_outliers <- function(x, ...) {
  cat("<intrait_outliers>\n")
  cat(sprintf(
    "  %d specimen(s) flagged out of %d (threshold Procrustes distance = %.4f)\n",
    length(x$outliers), length(x$procrustes_distance), x$threshold_value
  ))
  if (length(x$outliers) > 0) {
    cat("  Flagged: ", paste(x$outliers, collapse = ", "), "\n", sep = "")
  }
  cat("\n  Most atypical specimen(s):\n")
  print(utils::head(x$rank, 5), row.names = FALSE)
  invisible(x)
}
