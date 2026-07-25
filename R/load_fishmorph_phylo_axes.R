# =============================================================================
# load_fishmorph_phylo_axes.R -- precomputed phylogenetic PCoA axes.
#
# Session cache: the table is read once per R session. `emptyenv()` as parent so
# the environment captures nothing else.
# =============================================================================

.intrait_phylo_cache <- new.env(parent = emptyenv())

#' Precomputed phylogenetic PCoA axes for the FISHMORPH species pool
#'
#' Loads `pcoaPhylogenyFish.rds`, the **precomputed** principal-coordinate axes
#' of the bundled fish phylogeny for the 8,970 FISHMORPH species (10 axes,
#' ordered by decreasing eigenvalue). These are the axes used by every
#' `"missforest_phylo"` option in the package: [trait_space()],
#' [fishmorph_segments()], [fishmorph_ratios()] and [impute_landmarks()].
#'
#' @section Why precomputed:
#' The alternative, [phylo_pcoa()], eigendecomposes the patristic distance matrix
#' of the tree. That matrix is *n by n*: for 8,970 species it holds roughly 80
#' million entries, and the decomposition is cubic in *n*. Recomputing it on
#' every imputation is both slow and, more importantly, **not comparable across
#' calls** -- the axes depend on which subset of species happens to be present in
#' the data at hand, so two analyses run on different subsets end up in different
#' phylogenetic coordinate systems and their results cannot be compared.
#'
#' Reading a fixed table instead makes the axes a *property of the phylogeny*
#' rather than of the current dataset. Every imputation, whatever the species
#' subset, then lives in one and the same phylogenetic space.
#'
#' @section File format:
#' The bundled table is a compressed `.rds` (about 540 kB, against 1.8 MB for the
#' whitespace-separated text it was produced from). Both formats are accepted and
#' dispatched on the file extension, so `file` may point at either. To regenerate
#' the `.rds` from a text source:
#' ```r
#' txt <- read.table("pcoaPhylogenyFish.txt", header = TRUE)
#' ax  <- data.frame(species = gsub("[ ._]+", "_", rownames(txt)), txt,
#'                   row.names = NULL)
#' names(ax)[-1] <- paste0("phylo_", seq_len(ncol(txt)))
#' saveRDS(ax, "pcoaPhylogenyFish.rds", compress = "xz")
#' ```
#'
#' @param file Optional path to an alternative axis table: either an `.rds`
#'   holding a data frame, or a whitespace-separated text file with species as
#'   row names and one column per axis. `NULL` (default) uses the bundled file.
#' @param k Number of axes to return (the first `k` columns). `NULL` returns all.
#' @param refresh Force a re-read instead of using the session cache.
#'
#' @return A data frame with a `species` column (canonical `Genus_species`
#'   spelling) followed by the axis columns, named `phylo_1`, `phylo_2`, ...
#'
#' @seealso [phylo_pcoa()] to recompute axes from an arbitrary tree,
#'   [load_fishmorph_phylogeny()] for the tree itself, [trait_space()] and
#'   [impute_landmarks()] for the imputation methods that consume these axes.
#'
#' @examples
#' ax <- load_fishmorph_phylo_axes(k = 3)
#' dim(ax)
#' head(ax, 3)
#'
#' @export
load_fishmorph_phylo_axes <- function(file = NULL, k = NULL, refresh = FALSE) {
  key <- if (is.null(file)) "__bundled__" else normalizePath(file, mustWork = FALSE)
  if (!isTRUE(refresh) && !is.null(.intrait_phylo_cache[[key]])) {
    ax <- .intrait_phylo_cache[[key]]
  } else {
    if (is.null(file)) {
      # .rds first (compressed), .txt second: the text source lets one fall back
      # to the raw table if the binary is unreadable on a given platform.
      for (nm in c("pcoaPhylogenyFish.rds", "pcoaPhylogenyFish.txt")) {
        cand <- system.file("extdata", "Phylogeny", nm, package = "intraitR")
        if (nzchar(cand) && file.exists(cand)) {
          file <- cand
          break
        }
      }
      if (is.null(file)) {
        stop(
          "Could not find 'pcoaPhylogenyFish.rds' (or .txt) under ",
          "inst/extdata/Phylogeny/; is intraitR installed correctly? You can ",
          "also recompute the axes with phylo_pcoa(load_fishmorph_phylogeny()).",
          call. = FALSE
        )
      }
    }
    if (!file.exists(file)) {
      stop("Phylogenetic axis table not found: ", file, call. = FALSE)
    }

    if (identical(tolower(tools::file_ext(file)), "rds")) {
      raw <- readRDS(file)
      if (!is.data.frame(raw)) {
        stop("The .rds file did not contain a data frame: ", file, call. = FALSE)
      }
    } else {
      # A header with one column FEWER than the data rows makes read.table promote
      # the first column to row names (the format written by write.table()). We
      # therefore do not force `row.names`, which would break a file written with
      # an explicit species column.
      raw <- utils::read.table(file, header = TRUE, check.names = FALSE,
                               stringsAsFactors = FALSE)
    }
    num <- vapply(raw, is.numeric, logical(1))
    if (!any(num)) {
      stop("No numeric axis column found in ", file, call. = FALSE)
    }
    sp <- if (all(num)) rownames(raw) else as.character(raw[[which(!num)[1]]])
    ax <- data.frame(species = .canon_species_name(sp),
                     raw[, num, drop = FALSE], stringsAsFactors = FALSE)
    names(ax)[-1] <- paste0("phylo_", seq_len(sum(num)))
    ax <- ax[!duplicated(ax$species), , drop = FALSE]
    rownames(ax) <- NULL
    .intrait_phylo_cache[[key]] <- ax
  }
  if (!is.null(k)) {
    k <- min(as.integer(k), ncol(ax) - 1L)
    ax <- ax[, c(1L, seq_len(k) + 1L), drop = FALSE]
  }
  ax
}
