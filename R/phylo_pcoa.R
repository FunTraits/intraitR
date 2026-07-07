#' Phylogenetic Principal Coordinates Analysis
#'
#' Derives quantitative "phylogenetic trait" axes from a phylogenetic tree,
#' by Principal Coordinates Analysis (PCoA) of the tree's patristic
#' (cophenetic) distances among species. The resulting axes summarise a
#' species' overall phylogenetic position as a small set of numeric
#' variables, in a `species`-plus-axes `data.frame` deliberately shaped so
#' it can be passed directly as the `traits` argument of [trait_space()] --
#' letting you build a "phylogenetic space" with exactly the same ordination
#' machinery used for morphological trait spaces elsewhere in this package,
#' and then compare functional and phylogenetic diversity loss (e.g. with
#' [bootstrap_functional_space()] or [species_sensitivity()]) using the same
#' statistics on both.
#'
#' @param tree An object of class `"phylo"` (e.g. from `ape::read.tree()`,
#'   `ape::read.nexus()`, or the bundled [load_fishmorph_phylogeny()]), with
#'   tip labels matching the species names used elsewhere in your analysis
#'   (e.g. `fish$metadata$species`, with spaces, underscores, and dots
#'   treated as interchangeable -- see Details).
#' @param species Optional character vector of species to retain (typically
#'   your actual species pool, e.g. `levels(factor(fish$metadata$species))`).
#'   Species not found among `tree$tip.label` are dropped with a warning;
#'   defaults to all of `tree$tip.label`.
#' @param k Integer, the number of phylogenetic axes to keep. Defaults to
#'   all axes with a (corrected, if `correction != "none"`) positive
#'   eigenvalue.
#' @param correction Character, `"none"` (default), `"cailliez"`, or
#'   `"lingoes"` -- passed to `ape::pcoa()`'s `correction` argument.
#'   Patristic/cophenetic distances are not guaranteed to be perfectly
#'   Euclidean, which can produce a handful of small negative eigenvalues in
#'   the decomposition; `"cailliez"` or `"lingoes"` add a constant to the
#'   distances to remove them (see `?ape::pcoa`). Legendre & Anderson (1999)
#'   found the Cailliez correction can inflate Type I error in downstream
#'   permutation tests, so treat `"lingoes"` as the more conservative choice
#'   if a correction is needed for such a test; `"none"` simply drops the
#'   negative-eigenvalue axes (the `ape::pcoa()` default).
#' @param ultrametric Logical, coerce `tree` to be ultrametric (constant
#'   root-to-tip distance) before computing distances, using
#'   `phytools::force.ultrametric()`, if it is not already (to tolerance;
#'   see `ape::is.ultrametric()`). Defaults to `TRUE`, matching a
#'   time-calibrated phylogeny's own assumption; set to `FALSE` if `tree`'s
#'   branch lengths are not meant to represent a strict molecular clock
#'   (e.g. a phylogram in substitutions/site) and cophenetic distance is
#'   still an appropriate summary for your purposes.
#' @param ultrametric_method Character, `"nnls"` (default) or `"extend"`,
#'   passed to `phytools::force.ultrametric()`'s `method` argument when
#'   `ultrametric = TRUE` and `tree` is not already (numerically)
#'   ultrametric; see `?phytools::force.ultrametric` -- this is a numerical
#'   adjustment for representing the tree, not a re-estimation of
#'   divergence times, and is reported with a `message()` when triggered.
#'
#' @return An object of class `"intrait_phylopcoa"`, a list with elements
#'   `traits` (a `data.frame`, one row per species, with a `species` column
#'   and `k` numeric columns `PCoA1`, `PCoA2`, ... -- ready to pass as
#'   `traits` to [trait_space()], which auto-detects `groups` from a
#'   `species` column), `var_explained` (percent variance explained by each
#'   retained axis), `k`, `correction`, `tree` (the pruned, and possibly
#'   ultrametric-coerced, tree actually used), and `dropped_species` (any
#'   `species` entries not found in `tree$tip.label`).
#'
#' @details
#' Species names are matched against `tree$tip.label` after collapsing any
#' run of spaces, underscores, and/or dots to a single underscore in both
#' (the various separator conventions used by different tip-label/species
#' sources -- e.g. `"Barbus_barbus"`, `"Barbus.barbus"`, as in the bundled
#' [load_fishmorph_phylogeny()] tree), so `species = "Barbus barbus"`
#' matches a tip labelled `"Barbus.barbus"` without requiring the caller to
#' reformat names first. At least 3 matched species are required for a
#' meaningful ordination.
#'
#' This function deliberately only covers the generic, reusable step of
#' turning a tree plus a species list into ordination axes -- it does not
#' attempt taxonomic name resolution, tree sourcing, or trait/occurrence
#' data assembly, all of which are specific to wherever your tree and
#' species list come from and are out of scope for this package.
#'
#' @references
#' Cailliez, F. (1983). The analytical solution of the additive constant
#'   problem. Psychometrika, 48, 305-308. \doi{10.1007/BF02294026}
#'
#' Lingoes, J. C. (1971). Some boundary conditions for a monotone analysis
#'   of symmetric matrices. Psychometrika, 36, 195-203.
#'   \doi{10.1007/BF02291398}
#'
#' Legendre, P., & Anderson, M. J. (1999). Distance-based redundancy
#'   analysis: testing multispecies responses in multifactorial ecological
#'   experiments. Ecological Monographs, 69(1), 1-24.
#'   \doi{10.1890/0012-9615(1999)069[0001:DBRATM]2.0.CO;2}
#'
#' @seealso [trait_space()], [bootstrap_functional_space()],
#'   [species_sensitivity()]
#'
#' @examples
#' \donttest{
#' if (requireNamespace("ape", quietly = TRUE)) {
#'   set.seed(1)
#'   tree <- ape::rcoal(8, tip.label = paste0("sp_", 1:8))
#'   pp <- phylo_pcoa(tree, k = 3)
#'   pp
#'
#'   # use directly as `traits` in trait_space(): groups auto-detected from
#'   # the `species` column, exactly like a morphological trait matrix
#'   ts_phylo <- trait_space(pp$traits, na_action = "fail", log_transform = FALSE)
#'   plot(ts_phylo)
#' }
#' }
#'
#' @export
phylo_pcoa <- function(tree, species = NULL, k = NULL,
                        correction = c("none", "cailliez", "lingoes"),
                        ultrametric = TRUE,
                        ultrametric_method = c("nnls", "extend")) {
  correction <- match.arg(correction)
  ultrametric_method <- match.arg(ultrametric_method)

  if (!inherits(tree, "phylo")) {
    stop(
      "`tree` must be an object of class \"phylo\" (e.g. as returned by ",
      "ape::read.tree()/ape::read.nexus()).",
      call. = FALSE
    )
  }
  if (!requireNamespace("ape", quietly = TRUE)) {
    stop("phylo_pcoa() requires the \"ape\" package. Install it with install.packages(\"ape\").", call. = FALSE)
  }

  tip_labels <- .canon_species_name(tree$tip.label)
  if (is.null(species)) {
    species <- tree$tip.label
  }
  species <- .canon_species_name(species)
  species_u <- unique(species)

  missing_sp <- setdiff(species_u, tip_labels)
  if (length(missing_sp) > 0) {
    warning(sprintf(
      "%d species not found in `tree$tip.label` and dropped: %s%s",
      length(missing_sp),
      paste(utils::head(missing_sp, 10), collapse = ", "),
      if (length(missing_sp) > 10) ", ..." else ""
    ), call. = FALSE)
  }
  keep <- intersect(species_u, tip_labels)
  if (length(keep) < 3) {
    stop(
      "At least 3 species with a tip label matching `tree` are required for ",
      "a phylogenetic PCoA; found ", length(keep), ".",
      call. = FALSE
    )
  }

  pruned <- tree
  pruned$tip.label <- tip_labels
  pruned <- ape::drop.tip(pruned, setdiff(tip_labels, keep))

  if (isTRUE(ultrametric) && !ape::is.ultrametric(pruned)) {
    if (!requireNamespace("phytools", quietly = TRUE)) {
      stop(
        "phylo_pcoa() requires the \"phytools\" package to coerce `tree` to be ",
        "ultrametric (it is not exactly ultrametric as supplied); install it ",
        "with install.packages(\"phytools\"), set ultrametric = FALSE if your ",
        "branch lengths are not meant to represent a molecular clock, or supply ",
        "an already-ultrametric tree.",
        call. = FALSE
      )
    }
    pruned <- phytools::force.ultrametric(pruned, method = ultrametric_method)
    message(sprintf(
      paste(
        "phylo_pcoa(): `tree` was not exactly ultrametric; coerced using",
        "phytools::force.ultrametric(method = \"%s\"). This is a numerical",
        "adjustment for representing the tree, not a re-estimation of",
        "divergence times -- see ?phytools::force.ultrametric."
      ),
      ultrametric_method
    ))
  }

  phylo_dist <- stats::as.dist(ape::cophenetic.phylo(pruned))
  pco <- ape::pcoa(phylo_dist, correction = correction)

  vectors <- pco$vectors
  eig_col <- "Relative_eig"
  if (correction != "none" && !is.null(pco$vectors.cor) && ncol(pco$vectors.cor) > 0) {
    vectors <- pco$vectors.cor
    eig_col <- "Rel_corr_eig"
  }
  n_axes_avail <- ncol(vectors)
  if (n_axes_avail == 0) {
    stop(
      "No positive-eigenvalue axis remains after PCoA; try correction = ",
      "\"cailliez\" or \"lingoes\" (see ?ape::pcoa).",
      call. = FALSE
    )
  }
  if (is.null(k)) k <- n_axes_avail
  if (k > n_axes_avail) {
    stop(sprintf(
      "`k` = %d requests more axes than the %d positive-eigenvalue axis/axes available%s.",
      k, n_axes_avail,
      if (correction == "none") {
        " (some eigenvalues may be negative; try correction = \"cailliez\" or \"lingoes\")"
      } else ""
    ), call. = FALSE)
  }

  vectors <- vectors[, seq_len(k), drop = FALSE]
  colnames(vectors) <- paste0("PCoA", seq_len(k))
  var_explained <- unname(pco$values[[eig_col]][seq_len(k)]) * 100

  traits <- data.frame(
    species = rownames(vectors), vectors,
    row.names = NULL, stringsAsFactors = FALSE, check.names = FALSE
  )

  structure(
    list(
      traits = traits,
      var_explained = var_explained,
      k = k,
      correction = correction,
      tree = pruned,
      dropped_species = missing_sp
    ),
    class = "intrait_phylopcoa"
  )
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname phylo_pcoa
#' @param x An object of class `"intrait_phylopcoa"`, as returned by
#'   [phylo_pcoa()].
#' @param ... Currently unused.
print.intrait_phylopcoa <- function(x, ...) {
  cat("<intrait_phylopcoa>\n")
  cat(sprintf(
    "  %d species, %d PCoA axis/axes (correction = \"%s\")\n",
    nrow(x$traits), x$k, x$correction
  ))
  cat(sprintf(
    "  Variance explained: %s\n",
    paste(sprintf("%s = %.1f%%", colnames(x$traits)[-1], x$var_explained), collapse = ", ")
  ))
  if (length(x$dropped_species) > 0) {
    cat(sprintf(
      "  %d requested species not found in the tree (see $dropped_species)\n",
      length(x$dropped_species)
    ))
  }
  invisible(x)
}
