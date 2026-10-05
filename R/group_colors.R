#' Reset the session-level group/species colour cache
#'
#' `plot.intrait_shapespace()` and `plot.intrait_traitspace()` assign
#' group colours from a small cache that persists for the duration of the
#' R session (see Details), so that the same species is always drawn in
#' the same colour across separate plot calls -- e.g. a morphological
#' space and a trait space built from the same dataset, even though each
#' typically retains a slightly different subset of specimens (and
#' possibly species) after its own upstream missing-data or outlier
#' filtering. `reset_group_colors()` clears that cache, so that the next
#' plot call starts reassigning colours from scratch, in the order
#' species are then encountered.
#'
#' @details
#' Call this function when starting to work with an unrelated dataset in
#' the same R session (otherwise its species would be assigned colours
#' continuing on from wherever the previous dataset's species left off,
#' which is harmless but not particularly meaningful), or at the top of a
#' script whose figures must not depend on what happened to run earlier in
#' the session (for full reproducibility of colour assignment regardless
#' of call history).
#'
#' @return Invisibly returns `NULL`.
#' @seealso [group_colors()] (look up the current colours without
#'   resetting them)
#' @export
#' @examples
#' reset_group_colors()
reset_group_colors <- function() {
  rm(list = ls(envir = .intrait_color_cache), envir = .intrait_color_cache)
  invisible(NULL)
}

#' Look up the group/species colours used by the ordination plot methods
#'
#' Returns the exact colour [plot.intrait_shapespace()]/
#' [plot.intrait_traitspace()] draw (or would draw) for each group, in the
#' same order as their own legend -- so a shared legend built separately
#' (e.g. one common legend below several panels laid out with
#' `par(mfrow = ...)`/`layout()`, each plotted with `legend = FALSE`) is
#' guaranteed to match every panel's actual colours, without reimplementing
#' or guessing at the underlying colour assignment.
#'
#' @param x Either an object with a `$groups` element (e.g. one returned by
#'   [shape_space()]/[trait_space()]), or a factor/character vector of
#'   group labels directly (e.g. `fish$metadata$species`), one per
#'   observation -- duplicates are fine, only the distinct values matter.
#'
#' @return A `data.frame` with one row per distinct group (in the same
#'   order used by the plot methods' own legend), and columns `group`
#'   (character) and `color` (hex character).
#'
#' @details
#' Looking a group up here does not itself add it to the session-level
#' colour cache in a way that is any different from plotting it directly:
#' either way, a group not yet seen this session is assigned the next
#' unused colour and keeps it for the rest of the session (see
#' [reset_group_colors()]). Calling `group_colors()` *before* plotting is
#' therefore entirely safe and produces the same colours the subsequent
#' plot calls will use.
#'
#' @seealso [reset_group_colors()], [plot.intrait_shapespace()],
#'   [plot.intrait_traitspace()]
#'
#' @export
#' @examples
#' fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
#' gpa <- gpa_fish(fish)
#' ms <- shape_space(gpa, groups = fish$metadata$species)
#' group_colors(ms)
#'
#' # or directly from a label vector:
#' group_colors(fish$metadata$species)
group_colors <- function(x) {
  if (is.list(x)) {
    labels <- x$groups
    if (is.null(labels)) {
      stop(
        "`x` has no `groups` element (or none were supplied when it was created), ",
        "and is not itself a vector of group labels.",
        call. = FALSE
      )
    }
  } else {
    labels <- x
  }
  groups_f <- droplevels(as.factor(labels))
  lv <- levels(groups_f)
  cols <- unname(.stable_group_colors(lv)[lv])
  data.frame(group = lv, color = cols, stringsAsFactors = FALSE)
}
