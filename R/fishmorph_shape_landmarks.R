#' Extract complete-case body-shape landmarks from a FISHMORPH configuration
#'
#' Prepares a FISHMORPH-scheme `"intrait_landmarks"` object (21+ points; see
#' [fishmorph_segments()]) for Generalised Procrustes Analysis
#' ([gpa_fish()]) or any other function that expects a single, complete set
#' of homologous shape landmarks. Two adjustments are needed before such a
#' configuration can be treated as pure shape data, and this function
#' applies both at once: the embedded scale bar (landmarks 20-21) is
#' dropped, since it is a fixed calibration segment rather than a body
#' landmark and mixing it into a Procrustes superimposition (which treats
#' every point as part of the shape) would distort the alignment; and, by
#' default, any specimen missing one or more of the remaining landmarks (or
#' with a missing/unresolved species identification, if `species` is
#' supplied) is dropped, since GPA requires complete configurations.
#'
#' @param landmarks An object of class `"intrait_landmarks"` with at least
#'   the 21 FISHMORPH landmarks (see [fishmorph_segments()]).
#' @param species Optional character vector (or factor), one value per
#'   specimen, used only to additionally drop specimens with a missing
#'   (`NA`) value -- e.g. an unresolved identification -- so that a
#'   downstream grouped analysis ([morpho_space()],
#'   [intraspecific_variability()], [detect_outliers()]) never encounters
#'   an `NA` group. Defaults to `landmarks$metadata$species` if present,
#'   otherwise `NULL` (no filtering on species).
#' @param drop_incomplete Logical, drop specimens missing one or more of
#'   landmarks 1-19 (plus 22, if present). Defaults to `TRUE`; set to
#'   `FALSE` to keep every specimen and inspect missingness yourself (e.g.
#'   via [impute_landmarks()] instead of dropping).
#'
#' @return An object of the same class as `landmarks`, with landmarks 20-21
#'   removed and, if `drop_incomplete`, incomplete/unidentified specimens
#'   removed from `coords`, `metadata`, and `scale` alike.
#'
#' @seealso [gpa_fish()], [fishmorph_segments()], [impute_landmarks()],
#'   [load_t26_saudrune_landmarks()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' fish_shape <- fishmorph_shape_landmarks(fish)
#' dim(fish$coords)
#' dim(fish_shape$coords)
#' gpa <- gpa_fish(fish_shape)
#' gpa
#'
#' @export
fishmorph_shape_landmarks <- function(landmarks, species = NULL, drop_incomplete = TRUE) {
  if (!inherits(landmarks, "intrait_landmarks")) {
    stop("`landmarks` must be an object of class \"intrait_landmarks\".", call. = FALSE)
  }
  A <- landmarks$coords
  p <- dim(A)[1]
  if (p < 21) {
    stop(
      "`landmarks` must contain at least the 21 FISHMORPH landmarks (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }
  body_idx <- if (p >= 22) c(1:19, 22L) else 1:19
  shape <- A[body_idx, , , drop = FALSE]

  if (is.null(species) && !is.null(landmarks$metadata) && "species" %in% names(landmarks$metadata)) {
    species <- landmarks$metadata$species
  }

  if (isTRUE(drop_incomplete)) {
    keep <- apply(shape, 3, function(cfg) !anyNA(cfg))
    if (!is.null(species)) keep <- keep & !is.na(species)
    n_drop <- sum(!keep)
    if (n_drop > 0) {
      message(sprintf(
        "fishmorph_shape_landmarks(): dropping %d specimen(s) with a missing landmark%s.",
        n_drop, if (!is.null(species)) " or unresolved species identification" else ""
      ))
    }
    shape <- shape[, , keep, drop = FALSE]
    if (!is.null(landmarks$metadata)) landmarks$metadata <- landmarks$metadata[keep, , drop = FALSE]
    if (!is.null(landmarks$scale)) landmarks$scale <- landmarks$scale[keep]
  }

  landmarks$coords <- shape
  landmarks
}
