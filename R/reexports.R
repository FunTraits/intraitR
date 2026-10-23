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
# functions interchangeable.
#
# Division of labour (intraitR 1.38.0 / Rfishmorph 0.17.0): intraitR MEASURES,
# Rfishmorph holds the FISHMORPH reference and VISUALISES its space. The
# figures of that space (plotly_fishmorph(), plot_fishmorph_density(), the
# plot method of projections), the ordination engine and the session colour
# cache moved to Rfishmorph. group_colors()/reset_group_colors() used to be
# the cautionary case of this file -- two caches, so a re-export would have
# returned colours no intraitR plot had drawn. intraitR now draws through
# Rfishmorph's engine (see .plot_ordination() in utils-internal.R), so there
# is a single cache and the re-export is exact.
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

#' @importFrom Rfishmorph group_colors
#' @export
Rfishmorph::group_colors

#' @importFrom Rfishmorph reset_group_colors
#' @export
Rfishmorph::reset_group_colors

#' @importFrom Rfishmorph max_pair_distance
#' @export
Rfishmorph::max_pair_distance

#' @importFrom Rfishmorph plotly_fishmorph
#' @export
Rfishmorph::plotly_fishmorph

#' @importFrom Rfishmorph plot_fishmorph_density
#' @export
Rfishmorph::plot_fishmorph_density
