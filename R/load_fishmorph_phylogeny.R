#' Bundled global fish phylogeny, ready to use with [phylo_pcoa()]
#'
#' Loads a large (10,705-tip) phylogenetic tree of ray-finned fishes bundled
#' with the package, for use with [phylo_pcoa()] and, in turn, with
#' `na_action`/`method = "missforest_phylo"` in [trait_space()],
#' [fishmorph_segments()], [fishmorph_ratios()], and [impute_landmarks()].
#'
#' @return An object of class `"phylo"` (see `ape::read.tree()`), with
#'   elements `edge`, `edge.length`, `Nnode`, and `tip.label` (10,705 tip
#'   labels, formatted `"Genus.species"`, e.g. `"Barbus.barbus"` -- note the
#'   dot separator, unlike this package's own `"Genus species"` convention;
#'   [phylo_pcoa()] and every `"missforest_phylo"` option in this package
#'   normalise spaces, underscores, and dots interchangeably before
#'   matching, so this difference does not need to be handled by hand).
#'
#' @details
#' **Provenance**: this tree was supplied by the package maintainer as
#' `FishMORPH_Phylogeny.rds` for use in the FISHMORPH-related analyses this
#' package supports; its exact upstream source/citation has not been
#' independently verified here. If you know the original publication this
#' tree should be attributed to (e.g. a large-scale fish time-tree such as
#' Rabosky et al., 2018, or a FISHMORPH-specific pruning of one), please add
#' the correct citation to your own methods/manuscript -- do not cite this
#' function's documentation as the source. Requires the `ape` package to
#' use with `ape`-based functions (e.g. [phylo_pcoa()]); loading the raw
#' object here only requires base R.
#'
#' @seealso [phylo_pcoa()], [trait_space()], [load_t26_saudrune_landmarks()]
#'
#' @examples
#' tree <- load_fishmorph_phylogeny()
#' length(tree$tip.label)
#' head(tree$tip.label)
#'
#' \donttest{
#' if (requireNamespace("ape", quietly = TRUE)) {
#'   pp <- phylo_pcoa(tree, species = c("Barbus.barbus", "Gobio.gobio", "Perca.fluviatilis"), k = 2)
#'   pp
#' }
#' }
#'
#' @export
load_fishmorph_phylogeny <- function() {
  path <- system.file("extdata", "Phylogeny", "FishMORPH_Phylogeny.rds", package = "intraitR")
  if (!nzchar(path)) {
    stop(
      "Could not find 'FishMORPH_Phylogeny.rds' under inst/extdata/Phylogeny/; ",
      "is intraitR installed correctly?",
      call. = FALSE
    )
  }
  tree <- readRDS(path)
  if (!inherits(tree, "phylo")) {
    stop(
      "The bundled 'FishMORPH_Phylogeny.rds' file did not contain an object ",
      "of class \"phylo\" as expected; the package installation may be corrupted.",
      call. = FALSE
    )
  }
  tree
}
