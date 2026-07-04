#' Generalised Procrustes Analysis for fish landmark configurations
#'
#' Superimposes a sample of landmark configurations using Generalised
#' Procrustes Analysis (GPA), removing differences in position, orientation
#' and scale so that residual variation reflects shape alone. This is a
#' fish-oriented wrapper around [geomorph::gpagen()].
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()] or [read_landmarks_csv()]), or a raw `p x k x n`
#'   landmark array.
#' @param flag_outliers Logical, screen the Procrustes-aligned sample for
#'   specimens whose distance to the consensus shape is unusually large --
#'   the same rule as [detect_outliers()] (median + `outlier_threshold` x
#'   MAD of Procrustes distances) -- and report them (see Details and
#'   `outlier_threshold`). Defaults to `TRUE`. This never removes any
#'   observation on its own: it only flags candidates for visual/manual
#'   review (e.g. with [plot_landmarks()] or [plot_fishmorph_points()])
#'   before deciding whether an exclusion is warranted.
#' @param outlier_threshold Numeric, the number of median absolute
#'   deviations (MAD) above the median Procrustes distance beyond which a
#'   specimen is flagged; same convention as [detect_outliers()]'s
#'   `threshold`. Defaults to `3`.
#' @param remove_outliers Logical, actually exclude every specimen flagged
#'   by `flag_outliers` and re-run GPA on the cleaned sample (rather than
#'   only flagging them for review, the default). Requires
#'   `flag_outliers = TRUE` (an error is raised otherwise, since there
#'   would be nothing to remove). Defaults to `FALSE`: removing specimens
#'   changes the consensus shape and every downstream statistic (e.g.
#'   [morpho_space()], [intraspecific_variability()]), so this is opt-in
#'   rather than automatic, and every removal is still recorded in
#'   `$removed_outliers` (see Return) for transparency and reproducibility
#'   -- always confirm flagged specimens genuinely reflect a digitization
#'   error (e.g. via [plot_landmarks()]/[plot_fishmorph_points()]) before
#'   turning this on for a given data set, rather than treating it as a
#'   default cleaning step.
#' @param ... Additional arguments passed on to [geomorph::gpagen()] (e.g.
#'   `curves`, `surfaces`, `ProcD`).
#'
#' @return An object of class `"intrait_gpa"`, a list with elements:
#'   \describe{
#'     \item{coords}{`p x k x n` array of Procrustes-aligned shape
#'       coordinates -- of the *cleaned* sample if `remove_outliers = TRUE`
#'       removed any specimen.}
#'     \item{Csize}{named numeric vector of centroid sizes, one per
#'       specimen; the standard measure of overall specimen size in
#'       geometric morphometrics.}
#'     \item{consensus}{`p x k` matrix, the sample mean (consensus) shape.}
#'     \item{iter}{number of iterations used by [geomorph::gpagen()] to
#'       converge.}
#'     \item{metadata}{specimen metadata carried over from `landmarks`, if
#'       present (subset to match, if `remove_outliers = TRUE` removed any
#'       specimen).}
#'     \item{outlier_screen}{`NULL` unless `flag_outliers = TRUE` (the
#'       default); otherwise a `data.frame`, one row per specimen
#'       *actually used* (i.e. excluding any row removed by
#'       `remove_outliers = TRUE`), with columns `specimen`,
#'       `procrustes_distance` (to the consensus shape), `threshold_value`,
#'       `flagged`; see Details.}
#'     \item{removed_outliers}{`NULL` unless `remove_outliers = TRUE`
#'       removed at least one specimen, in which case a `data.frame` with
#'       the same columns as `outlier_screen`, one row per *excluded*
#'       specimen, for the record.}
#'   }
#'
#' @details
#' Centroid size (`Csize`) is retained explicitly because, unlike Procrustes
#' shape coordinates, it captures the size component of morphology and is
#' required for allometry correction ([correct_allometry()]) and to relate
#' shape to body size.
#'
#' When `flag_outliers = TRUE` (the default), every specimen's Euclidean
#' (Procrustes) distance to the sample consensus shape is computed, and
#' flagged if it exceeds `median + outlier_threshold * MAD` (median
#' absolute deviation) of those distances -- the same rule used by
#' [detect_outliers()] (which can be run on the result afterwards for the
#' ordered dot-plot view; both share the same screening code, so results
#' agree). This never removes anything automatically: it only flags
#' candidates -- always inspect a flagged specimen (e.g. with
#' [plot_landmarks()]/[plot_fishmorph_points()], and its original
#' photograph if available) before deciding whether to exclude it.
#'
#' Setting `remove_outliers = TRUE` goes one step further and actually
#' excludes every flagged specimen, then re-runs [geomorph::gpagen()] on
#' the cleaned sample -- a genuinely mis-digitized specimen can distort the
#' consensus shape (and hence every other specimen's alignment to it), so
#' simply dropping it from a plot after the fact is not equivalent to
#' re-aligning without it. `coords`, `Csize`, `consensus`, and `metadata`
#' in the returned object then describe the *cleaned* sample, and
#' `$removed_outliers` records exactly which specimens were dropped and
#' why, so the exclusion remains fully reproducible and auditable rather
#' than an undocumented, ad hoc edit made before calling `gpa_fish()`.
#' This is deliberately opt-in (`FALSE` by default): removing data always
#' changes the alignment and should be a conscious, visually-confirmed
#' decision (see above), not something that happens silently just because
#' a threshold was crossed.
#'
#' @references
#' Rohlf FJ, Slice D (1990). Extensions of the Procrustes method for the
#' optimal superimposition of landmarks. Systematic Zoology, 39(1), 40-59.
#'
#' @seealso [morpho_space()], [correct_allometry()], [detect_outliers()],
#'   [intraspecific_variability()], [fishmorph_shape_landmarks()]
#'
#' @examples
#' # real T-26 Saudrune data; GPA aligns *shape* only, so the FISHMORPH
#' # scale bar (points 20-21, a calibration segment, not a body landmark)
#' # must first be dropped, along with any specimen missing a landmark --
#' # fishmorph_shape_landmarks() does both:
#' fish <- load_t26_saudrune_landmarks()
#' fish_shape <- fishmorph_shape_landmarks(fish)
#' gpa <- gpa_fish(fish_shape)
#' gpa   # flags any Procrustes-distance outliers found, see gpa$outlier_screen
#'
#' # Once a flagged specimen has been visually confirmed as a digitization
#' # error (not just a genuinely extreme morphology), exclude it and
#' # re-align without it:
#' gpa_clean <- gpa_fish(fish_shape, remove_outliers = TRUE)
#' gpa_clean$removed_outliers   # exactly which specimen(s) were excluded, and why
#'
#' @export
#' @importFrom geomorph gpagen
gpa_fish <- function(landmarks, flag_outliers = TRUE, outlier_threshold = 3,
                      remove_outliers = FALSE, ...) {
  if (isTRUE(remove_outliers) && !isTRUE(flag_outliers)) {
    stop("`remove_outliers = TRUE` requires `flag_outliers = TRUE` (the default).", call. = FALSE)
  }
  if (!is.numeric(outlier_threshold) || length(outlier_threshold) != 1 || outlier_threshold <= 0) {
    stop("`outlier_threshold` must be a single positive number.", call. = FALSE)
  }

  A <- .get_coords(landmarks)
  gpa <- geomorph::gpagen(A, print.progress = FALSE, ...)
  meta <- .get_metadata(landmarks)

  outlier_screen <- NULL
  removed_outliers <- NULL

  if (isTRUE(flag_outliers)) {
    outlier_screen <- .procrustes_outlier_screen(gpa$coords, gpa$consensus, threshold = outlier_threshold)
    n_flagged <- sum(outlier_screen$flagged)

    if (isTRUE(remove_outliers) && n_flagged > 0) {
      removed_outliers <- outlier_screen[outlier_screen$flagged, , drop = FALSE]
      keep <- !outlier_screen$flagged
      message(sprintf(
        paste(
          "remove_outliers: removing %d specimen(s) flagged as Procrustes-distance",
          "outlier(s) (threshold = median + %.1f x MAD): %s. Re-running GPA without",
          "them; see $removed_outliers for the record, and always confirm each",
          "removal corresponds to a real digitization error (e.g. via",
          "plot_landmarks()/plot_fishmorph_points()), not just genuine morphological",
          "variation, before relying on this in a publication."
        ),
        n_flagged, outlier_threshold, paste(removed_outliers$specimen, collapse = ", ")
      ))

      A <- A[, , keep, drop = FALSE]
      gpa <- geomorph::gpagen(A, print.progress = FALSE, ...)
      if (!is.null(meta)) meta <- meta[keep, , drop = FALSE]

      # Re-screen the cleaned sample so $outlier_screen always reflects the
      # specimens actually retained in $coords (mirrors trait_space()).
      outlier_screen <- .procrustes_outlier_screen(gpa$coords, gpa$consensus, threshold = outlier_threshold)
    } else if (n_flagged > 0) {
      message(sprintf(
        paste(
          "flag_outliers: %d specimen(s) flagged as potential Procrustes-distance",
          "outlier(s) (threshold = median + %.1f x MAD): %s; this only flags",
          "candidates for review (e.g. with plot_landmarks()/plot_fishmorph_points()),",
          "nothing was removed automatically. Set remove_outliers = TRUE to exclude",
          "them and re-align, or see $outlier_screen for details."
        ),
        n_flagged, outlier_threshold, paste(outlier_screen$specimen[outlier_screen$flagged], collapse = ", ")
      ))
    }
  }

  structure(
    list(
      coords = gpa$coords,
      Csize = gpa$Csize,
      consensus = gpa$consensus,
      iter = gpa$iter,
      metadata = meta,
      outlier_screen = outlier_screen,
      removed_outliers = removed_outliers
    ),
    class = "intrait_gpa"
  )
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname gpa_fish
#' @param x An object to print: an `"intrait_gpa"` (from `gpa_fish()`) or
#'   `"summary.intrait_gpa"` (from `summary()` on one) object.
print.intrait_gpa <- function(x, ...) {
  d <- dim(x$coords)
  cat("<intrait_gpa> Procrustes-aligned landmark configurations\n")
  cat(sprintf("  %d specimens, %d landmarks, %d dimensions\n", d[3], d[1], d[2]))
  cat(sprintf("  Converged in %s iteration(s)\n", ifelse(is.null(x$iter), "NA", x$iter)))
  cat(sprintf(
    "  Centroid size: mean = %.3f, range = [%.3f, %.3f]\n",
    mean(x$Csize), min(x$Csize), max(x$Csize)
  ))
  if (!is.null(x$removed_outliers)) {
    cat(sprintf(
      "  %d specimen(s) removed as Procrustes-distance outliers before this alignment\n",
      nrow(x$removed_outliers)
    ))
    cat("  (see $removed_outliers): ", paste(x$removed_outliers$specimen, collapse = ", "), "\n", sep = "")
  }
  if (!is.null(x$outlier_screen)) {
    n_flagged <- sum(x$outlier_screen$flagged, na.rm = TRUE)
    if (n_flagged > 0) {
      top <- x$outlier_screen[order(-x$outlier_screen$procrustes_distance), , drop = FALSE][seq_len(min(n_flagged, 5)), ]
      cat(sprintf(
        "  %d potential Procrustes-distance outlier(s) flagged (see $outlier_screen); most atypical:\n",
        n_flagged
      ))
      for (i in seq_len(nrow(top))) {
        cat(sprintf(
          "    %s: distance = %.4f (threshold %.4f)\n",
          top$specimen[i], top$procrustes_distance[i], top$threshold_value[i]
        ))
      }
    } else {
      cat("  No Procrustes-distance outliers flagged (see $outlier_screen)\n")
    }
  }
  invisible(x)
}

#' @return A list of class `"summary.intrait_gpa"` (see `print.summary.intrait_gpa()`), returned visibly.
#' @export
#' @rdname gpa_fish
#' @param object An object of class `"intrait_gpa"`, as returned by
#'   `gpa_fish()`.
summary.intrait_gpa <- function(object, ...) {
  d <- dim(object$coords)
  out <- list(
    n_specimens = d[3],
    n_landmarks = d[1],
    n_dim = d[2],
    Csize_summary = summary(object$Csize)
  )
  class(out) <- "summary.intrait_gpa"
  out
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname gpa_fish
print.summary.intrait_gpa <- function(x, ...) {
  cat("Procrustes-aligned landmark configurations (intrait_gpa)\n")
  cat(sprintf("  Specimens : %d\n", x$n_specimens))
  cat(sprintf("  Landmarks : %d\n", x$n_landmarks))
  cat(sprintf("  Dimensions: %d\n", x$n_dim))
  cat("  Centroid size distribution:\n")
  print(x$Csize_summary)
  invisible(x)
}
