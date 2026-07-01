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
#' @param ... Additional arguments passed on to [geomorph::gpagen()] (e.g.
#'   `curves`, `surfaces`, `ProcD`).
#'
#' @return An object of class `"intrait_gpa"`, a list with elements:
#'   \describe{
#'     \item{coords}{`p x k x n` array of Procrustes-aligned shape
#'       coordinates.}
#'     \item{Csize}{named numeric vector of centroid sizes, one per
#'       specimen; the standard measure of overall specimen size in
#'       geometric morphometrics.}
#'     \item{consensus}{`p x k` matrix, the sample mean (consensus) shape.}
#'     \item{iter}{number of iterations used by [geomorph::gpagen()] to
#'       converge.}
#'     \item{metadata}{specimen metadata carried over from `landmarks`, if
#'       present.}
#'   }
#'
#' @details
#' Centroid size (`Csize`) is retained explicitly because, unlike Procrustes
#' shape coordinates, it captures the size component of morphology and is
#' required for allometry correction ([correct_allometry()]) and to relate
#' shape to body size.
#'
#' @references
#' Rohlf FJ, Slice D (1990). Extensions of the Procrustes method for the
#' optimal superimposition of landmarks. Systematic Zoology, 39(1), 40-59.
#'
#' @seealso [morpho_space()], [correct_allometry()],
#'   [intraspecific_variability()]
#'
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
#' gpa <- gpa_fish(fish)
#' gpa
#'
#' @export
#' @importFrom geomorph gpagen
gpa_fish <- function(landmarks, ...) {
  A <- .get_coords(landmarks)
  gpa <- geomorph::gpagen(A, print.progress = FALSE, ...)
  meta <- .get_metadata(landmarks)

  structure(
    list(
      coords = gpa$coords,
      Csize = gpa$Csize,
      consensus = gpa$consensus,
      iter = gpa$iter,
      metadata = meta
    ),
    class = "intrait_gpa"
  )
}

#' @export
print.intrait_gpa <- function(x, ...) {
  d <- dim(x$coords)
  cat("<intrait_gpa> Procrustes-aligned landmark configurations\n")
  cat(sprintf("  %d specimens, %d landmarks, %d dimensions\n", d[3], d[1], d[2]))
  cat(sprintf("  Converged in %s iteration(s)\n", ifelse(is.null(x$iter), "NA", x$iter)))
  cat(sprintf(
    "  Centroid size: mean = %.3f, range = [%.3f, %.3f]\n",
    mean(x$Csize), min(x$Csize), max(x$Csize)
  ))
  invisible(x)
}

#' @export
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

#' @export
print.summary.intrait_gpa <- function(x, ...) {
  cat("Procrustes-aligned landmark configurations (intrait_gpa)\n")
  cat(sprintf("  Specimens : %d\n", x$n_specimens))
  cat(sprintf("  Landmarks : %d\n", x$n_landmarks))
  cat(sprintf("  Dimensions: %d\n", x$n_dim))
  cat("  Centroid size distribution:\n")
  print(x$Csize_summary)
  invisible(x)
}
