# =============================================================================
# reexports.R -- functions that intraitR no longer implements.
#
# Rfishmorph and intraitR grew a shared surface: 13 exported names existed in
# both, and a script attaching the two got whichever package was loaded second.
# The resolution is one implementation per operation, owned by the package whose
# domain it belongs to, and re-exported by the other. This file holds the
# FISHMORPH-specific operations that now live in Rfishmorph: intraitR users keep
# calling them unqualified, and there is a single body of code to maintain.
#
# Only functions whose behaviour is bit-for-bit equivalent are re-exported here.
# The rest still exist twice on purpose and are being merged one at a time, each
# with its own regression check: an identical signature does not make two
# functions interchangeable. `group_colors()` and `reset_group_colors()` are the
# cautionary case -- same arguments, same return shape, but each is bound to its
# own session colour cache, so a naive re-export would return colours no
# intraitR plot has ever drawn.
# =============================================================================

#' @importFrom Rfishmorph load_fishmorph_phylogeny
#' @export
Rfishmorph::load_fishmorph_phylogeny

#' @importFrom Rfishmorph load_fishmorph_phylo_axes
#' @export
Rfishmorph::load_fishmorph_phylo_axes

#' @importFrom Rfishmorph phylo_pcoa
#' @export
Rfishmorph::phylo_pcoa
