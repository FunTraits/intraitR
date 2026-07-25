#' Project specimens into the global FISHMORPH functional space
#'
#' Builds a fixed functional trait space by Principal Component Analysis of
#' a reference database of FISHMORPH ecomorphological ratios (typically the
#' full FISHMORPH database of Brosse et al. 2021, ~9,000 species), then
#' places new specimens -- e.g. the individuals of a few focal species,
#' from [fishmorph_ratios()] -- into that *same, frozen* space using
#' [stats::predict()], without re-estimating the ordination. This is the
#' standard way to show how much of the global morphospace a group's
#' intraspecific trait variation (ITV) occupies relative to the entire
#' diversity of fishes, on axes defined once by the reference alone (so the
#' space does not move when specimens are added or removed, and separate
#' studies remain comparable).
#'
#' @section Scale of the reference vs the specimens:
#' The published FISHMORPH database distributes its trait columns already
#' `log10(x + 1)`-transformed (verifiable against the raw measurements: a
#' stored body elongation of `0.888` is `log10(6.72 + 1)`, not the raw
#' `Bl / Bd = 6.72`), whereas [fishmorph_ratios()] returns *raw* ratios. If
#' the reference were log-transformed a second time while the specimens
#' were logged only once (or vice versa), the two sets of scores would land
#' on incompatible scales and the projected specimens would be displaced by
#' a large, spurious offset. The defaults here encode the correct
#' combination for that common case (`reference_prelogged = TRUE`,
#' `specimens_prelogged = FALSE`, `log_transform = TRUE`): the reference is
#' taken as-is and the specimens are `log10(x + 1)`-transformed onto its
#' scale before projection. Set these flags explicitly if your inputs are
#' on different scales (e.g. a raw reference: `reference_prelogged = FALSE`).
#'
#' @param specimens A `data.frame` (e.g. from [fishmorph_ratios()], class
#'   `"intrait_fishmorph"`) with one row per specimen, containing at least
#'   the columns named in `traits`, and -- for grouping/colouring -- either
#'   a `species` column or a `groups` argument. Row names are used as
#'   specimen identifiers (for the `select_specimens` filter and for the
#'   returned scores).
#' @param reference The reference trait table defining the global space:
#'   either a `data.frame`/`matrix` with (at least) the `traits` columns,
#'   or a single string giving the path to a delimited file to read (a
#'   `;`-separated, `.`-decimal file such as the shipped `fishmorph_data.csv`
#'   is read with [utils::read.csv2()]; a `,`-separated file with
#'   [utils::read.csv()]). One row per reference species.
#' @param traits Character vector of the trait columns to use, present in
#'   both `specimens` and `reference`. Defaults to the nine dimensionless
#'   FISHMORPH ratios common to [fishmorph_ratios()] output and the
#'   FISHMORPH database (`"REs"`, `"VEp"`, `"RMl"`, `"OGp"`, `"BEl"`,
#'   `"BLs"`, `"PFv"`, `"PFs"`, `"CPt"`); the two mouth ratios (`MBl`,
#'   `MBw`) are excluded by default because [fishmorph_ratios()] does not
#'   produce them.
#' @param groups Optional factor (or character vector), one value per row of
#'   `specimens`, used to colour/group the projected points. If `NULL` and
#'   `specimens` has a `species` column, that column is used.
#' @param select_species Optional character vector: keep only these
#'   species/groups among the projected specimens (matched against
#'   `groups`). `NULL` (default) keeps them all. Unmatched names are
#'   reported with a warning.
#' @param select_specimens Optional character vector: keep only these
#'   specimen identifiers (matched against `rownames(specimens)`). `NULL`
#'   (default) keeps them all. Combined with `select_species` by
#'   intersection (a specimen must satisfy both filters to be kept).
#' @param reference_prelogged Logical; is `reference` already
#'   `log10(x + 1)`-transformed? Defaults to `TRUE` (the state in which the
#'   FISHMORPH database is distributed). When `TRUE`, no log transform is
#'   applied to the reference even if `log_transform = TRUE`.
#' @param specimens_prelogged Logical; are the `specimens`' trait values
#'   already `log10(x + 1)`-transformed? Defaults to `FALSE`
#'   ([fishmorph_ratios()] returns raw ratios).
#' @param log_transform Logical, apply a `log10(x + 1)` transform to bring
#'   raw inputs onto the (log) reference scale, following
#'   [trait_space()]'s default preprocessing. Defaults to `TRUE`. Applied to
#'   the reference only if not `reference_prelogged`, and to the specimens
#'   only if not `specimens_prelogged`, so that both end up on the same
#'   scale exactly once.
#' @param scale Logical, standardise traits to unit variance inside the PCA
#'   (centring is always applied). Defaults to `TRUE`, matching
#'   [trait_space()].
#' @param axes Integer vector of length 2, the ordination axes retained for
#'   the returned scores and plotting. Defaults to `c(1, 2)`.
#' @param volume_dims Integer, the number of leading principal components on
#'   which the *functional-volume* proportion (convex-hull ratio) is computed
#'   by the bundled [itv_proportion()] call. Independent of `axes` (which only
#'   controls the two plotted axes). Defaults to `2L`; a convex hull in
#'   `volume_dims` dimensions needs at least `volume_dims + 1` non-degenerate
#'   points, so per-species volumes are `NA` for species with too few
#'   specimens.
#' @param na_action Character, how to handle specimens with missing values
#'   in the `traits` columns (a projection cannot place a row with a missing
#'   coordinate): `"omit"` (default) drops them, reporting how many;
#'   `"fail"` stops with an error. Reference rows with missing trait values
#'   are always dropped (with a message) before the space is built.
#'
#' @return An object of class `"intrait_fishmorph_projection"`, a list with
#'   elements `scores` (data.frame of projected specimen scores on the two
#'   axes), `global_scores` (data.frame of the reference species' own scores
#'   on the same axes, for the background cloud), `global_species` (character
#'   vector of the reference species labels, aligned row-for-row to
#'   `global_scores`; from a `"Species"` column of `reference` when present,
#'   else its row names -- used by the plot method to locate the focal
#'   species' own reference points), `groups` (factor aligned
#'   to `scores`), `var_explained` (percent variance of the two axes),
#'   `loadings` (PCA variable loadings), `axes`, `traits`, `n_reference`
#'   (number of reference species used), and `pca` (the fitted
#'   [stats::prcomp()] object, so further specimens can be projected with
#'   `predict(x$pca, ...)`). It also carries the material used to quantify how
#'   much of the global functional diversity the projected ITV occupies:
#'   `scores_all`/`global_scores_all` (specimen and reference scores on *all*
#'   components), `specimen_traits` (the transformed specimen traits, analysis
#'   scale), `trait_ranges_reference` (per-trait reference envelope),
#'   `reference_traits` (the full reference trait matrix on the analysis scale,
#'   one row per reference species -- used e.g. by
#'   [plot_fishmorph_density()] to draw the reference trait distributions),
#'   `volume_dims`, and `itv_proportion` -- an `"intrait_itv_proportion"`
#'   object (see [itv_proportion()]) giving the ITV-to-global proportion per
#'   trait and per functional volume, pooled and per species. Has dedicated
#'   [print()] and [plot()] methods.
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villeger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(11), 2330-2336.
#'
#' @seealso [fishmorph_ratios()], [trait_space()],
#'   [plot.intrait_fishmorph_projection()]
#'
#' @examples
#' \donttest{
#' # Reference: the FISHMORPH database (a ~9,000-species CSV, not shipped with
#' # the package). The example runs only where that file is available locally.
#' ref_path <- "FishMORPH/fishmorph_data.csv"
#' if (file.exists(ref_path)) {
#'   # Focal specimens: the T-26 Saudrune individuals
#'   fish   <- load_t26_saudrune_landmarks()
#'   ratios <- fishmorph_ratios(fishmorph_segments(fish), na_action = "omit")
#'
#'   proj <- project_fishmorph(ratios, reference = ref_path)
#'   proj
#'
#'   plot(proj, style = "hull")       # ITV footprints over the density heatmap
#'   plot(proj, style = "spider")     # dispersion around centroids
#'   plot(proj, style = "points", select_species = "Squalius cephalus")
#'
#'   # raw reference cloud instead of (or as well as) the heatmap:
#'   plot(proj, style = "hull", reference_density = FALSE, reference_points = TRUE)
#'
#'   # mark each focal species' own FISHMORPH-database point:
#'   plot(proj, style = "hull", itv_reference = TRUE)
#'
#'   # overlay the trait loadings as biplot arrows:
#'   plot(proj, style = "hull", arrows = TRUE)
#' }
#' }
#'
#' @export
project_fishmorph <- function(specimens, reference,
                              traits = c("REs", "VEp", "RMl", "OGp", "BEl",
                                         "BLs", "PFv", "PFs", "CPt"),
                              groups = NULL,
                              select_species = NULL, select_specimens = NULL,
                              reference_prelogged = TRUE,
                              specimens_prelogged = FALSE,
                              log_transform = TRUE, scale = TRUE,
                              axes = c(1, 2), volume_dims = 2L,
                              na_action = c("omit", "fail")) {
  na_action <- match.arg(na_action)
  if (length(axes) != 2 || !is.numeric(axes)) {
    stop("`axes` must be a length-2 integer vector.", call. = FALSE)
  }
  if (length(volume_dims) != 1 || !is.numeric(volume_dims) || volume_dims < 1) {
    stop("`volume_dims` must be a single integer >= 1.", call. = FALSE)
  }
  volume_dims <- as.integer(volume_dims)

  ## -- resolve the reference table (data.frame/matrix or a file path) -----
  if (is.character(reference) && length(reference) == 1) {
    if (!file.exists(reference)) {
      stop("`reference` file does not exist: ", reference, call. = FALSE)
    }
    sep_semicolon <- grepl(";", readLines(reference, n = 1))
    reference <- if (sep_semicolon) {
      utils::read.csv2(reference, dec = ".", stringsAsFactors = FALSE, check.names = TRUE)
    } else {
      utils::read.csv(reference, stringsAsFactors = FALSE, check.names = TRUE)
    }
  }
  if (!is.data.frame(reference) && !is.matrix(reference)) {
    stop("`reference` must be a data.frame, a matrix, or a path to a delimited file.",
         call. = FALSE)
  }
  reference <- as.data.frame(reference)

  ## -- check trait columns are present on both sides ----------------------
  miss_ref <- setdiff(traits, names(reference))
  if (length(miss_ref) > 0) {
    stop("`reference` is missing trait column(s): ", paste(miss_ref, collapse = ", "),
         call. = FALSE)
  }
  specimens_df <- as.data.frame(specimens)
  miss_sp <- setdiff(traits, names(specimens_df))
  if (length(miss_sp) > 0) {
    stop("`specimens` is missing trait column(s): ", paste(miss_sp, collapse = ", "),
         ". Compute them with fishmorph_ratios().", call. = FALSE)
  }

  ## -- build the frozen global PCA from the reference ---------------------
  Xref <- data.matrix(reference[traits])
  # Species labels for the reference rows, kept aligned to Xref/global_scores
  # so the plot method can locate the focal species' own reference points
  # (see `itv_reference` in plot.intrait_fishmorph_projection()). Uses a
  # "Species" column when present (as in the shipped fishmorph_data.csv,
  # whose read-in rownames are just row numbers), otherwise the row names.
  ref_species <- if ("Species" %in% names(reference)) {
    as.character(reference[["Species"]])
  } else {
    rownames(reference)
  }
  ok_ref <- stats::complete.cases(Xref)
  if (any(!ok_ref)) {
    message(sprintf("Dropping %d reference row(s) with missing trait values.",
                    sum(!ok_ref)))
    Xref <- Xref[ok_ref, , drop = FALSE]
    if (!is.null(ref_species)) ref_species <- ref_species[ok_ref]
  }
  if (nrow(Xref) < 3) stop("Fewer than 3 complete reference rows; cannot build a space.",
                           call. = FALSE)
  if (any(!is.finite(Xref))) stop("Non-finite value(s) in the reference trait matrix.",
                                  call. = FALSE)
  if (log_transform && !reference_prelogged) {
    if (any(Xref < 0)) stop("`log_transform = TRUE` needs non-negative reference values.",
                            call. = FALSE)
    Xref <- log10(Xref + 1)
  }
  pca <- stats::prcomp(Xref, center = TRUE, scale. = scale)
  if (max(axes) > ncol(pca$rotation)) {
    stop("`axes` requests a component beyond the ", ncol(pca$rotation), " available.",
         call. = FALSE)
  }
  var_explained <- (pca$sdev^2 / sum(pca$sdev^2))[axes] * 100
  global_scores <- as.data.frame(pca$x[, axes, drop = FALSE])
  names(global_scores) <- paste0("PC", axes)
  if (volume_dims > ncol(pca$x)) {
    stop("`volume_dims` (", volume_dims, ") exceeds the ", ncol(pca$x),
         " available principal component(s).", call. = FALSE)
  }
  # Per-trait envelope of the whole reference on the analysis scale (i.e. the
  # log10(x + 1) scale when log_transform is applied): the univariate
  # functional diversity against which each focal species' intraspecific
  # trait variation is expressed as a proportion (see itv_proportion()).
  trait_ranges_reference <- data.frame(
    trait = traits,
    min   = apply(Xref, 2, min),
    max   = apply(Xref, 2, max),
    row.names = NULL, stringsAsFactors = FALSE
  )
  trait_ranges_reference$range <- trait_ranges_reference$max - trait_ranges_reference$min

  ## -- resolve grouping for the specimens ---------------------------------
  if (is.null(groups) && "species" %in% names(specimens_df)) {
    groups <- specimens_df$species
  }
  if (is.null(groups)) {
    stop("No `groups` supplied and `specimens` has no `species` column to group by.",
         call. = FALSE)
  }
  if (length(groups) != nrow(specimens_df)) {
    stop("`groups` must have one entry per row of `specimens`.", call. = FALSE)
  }
  groups <- as.character(groups)

  ## -- apply the species / specimen selection filters ---------------------
  keep <- rep(TRUE, nrow(specimens_df))
  if (!is.null(select_species)) {
    unmatched <- setdiff(select_species, unique(groups))
    if (length(unmatched) > 0) {
      warning("`select_species` not found among specimens: ",
              paste(unmatched, collapse = ", "), call. = FALSE)
    }
    keep <- keep & groups %in% select_species
  }
  if (!is.null(select_specimens)) {
    ids <- rownames(specimens_df)
    unmatched <- setdiff(select_specimens, ids)
    if (length(unmatched) > 0) {
      warning("`select_specimens` not found: ",
              paste(utils::head(unmatched, 5), collapse = ", "),
              if (length(unmatched) > 5) ", ..." else "", call. = FALSE)
    }
    keep <- keep & ids %in% select_specimens
  }
  if (!any(keep)) stop("No specimens left after applying the selection filter(s).",
                       call. = FALSE)
  specimens_df <- specimens_df[keep, , drop = FALSE]
  groups <- groups[keep]

  ## -- handle missing specimen traits -------------------------------------
  Xsp <- data.matrix(specimens_df[traits])
  incomplete <- !stats::complete.cases(Xsp)
  if (any(incomplete)) {
    if (na_action == "fail") {
      stop(sum(incomplete), " specimen(s) have missing trait value(s); set ",
           "na_action = \"omit\" to drop them.", call. = FALSE)
    }
    message(sprintf("na_action = \"omit\": dropping %d specimen(s) with missing trait values.",
                    sum(incomplete)))
    Xsp <- Xsp[!incomplete, , drop = FALSE]
    specimens_df <- specimens_df[!incomplete, , drop = FALSE]
    groups <- groups[!incomplete]
  }
  if (nrow(Xsp) == 0) stop("No specimens with complete trait values to project.",
                           call. = FALSE)
  if (any(!is.finite(Xsp))) stop("Non-finite value(s) in the specimen trait matrix.",
                                 call. = FALSE)

  ## -- put specimens on the reference scale, then project (frozen PCA) -----
  if (log_transform && !specimens_prelogged) {
    if (any(Xsp < 0)) stop("`log_transform = TRUE` needs non-negative specimen values.",
                           call. = FALSE)
    Xsp <- log10(Xsp + 1)
  }
  # predict.prcomp reorders newdata columns to match rownames(rotation) and
  # reapplies the reference PCA's stored centre/scale/rotation -- the global
  # axes are never re-estimated. Keep the scores on *all* components (not just
  # the two plotted `axes`) so functional-volume proportions can be computed
  # in `volume_dims` dimensions (see itv_proportion()).
  proj_all <- stats::predict(pca, newdata = Xsp)
  rownames(proj_all) <- rownames(specimens_df)
  scores <- as.data.frame(proj_all[, axes, drop = FALSE])
  names(scores) <- paste0("PC", axes)
  rownames(scores) <- rownames(specimens_df)

  # Transformed specimen traits (analysis scale), aligned to `groups`/`scores`,
  # for the per-trait proportions.
  colnames(Xsp) <- traits
  rownames(Xsp) <- rownames(specimens_df)

  out <- structure(
    list(
      scores = scores,
      scores_all = proj_all,
      global_scores = global_scores,
      global_scores_all = pca$x,
      global_species = ref_species,
      groups = factor(groups),
      var_explained = stats::setNames(var_explained, names(scores)),
      loadings = pca$rotation,
      axes = axes,
      volume_dims = volume_dims,
      traits = traits,
      trait_ranges_reference = trait_ranges_reference,
      reference_traits = Xref,
      specimen_traits = Xsp,
      n_reference = nrow(Xref),
      pca = pca
    ),
    class = "intrait_fishmorph_projection"
  )

  # Proportion of global functional diversity captured by the projected ITV,
  # per trait (range ratio) and per functional volume (convex-hull ratio).
  out$itv_proportion <- itv_proportion(out, volume_dims = volume_dims)
  out
}

#' @return `print()` invisibly returns `x`.
#' @export
#' @rdname project_fishmorph
#' @param x An object of class `"intrait_fishmorph_projection"`.
#' @param ... Further arguments passed to [graphics::plot()] (for the
#'   `plot()` method) or currently unused (for `print()`).
print.intrait_fishmorph_projection <- function(x, ...) {
  cat("<intrait_fishmorph_projection>\n")
  cat(sprintf("  Reference space: %d species, %d traits (%s)\n",
              x$n_reference, length(x$traits), paste(x$traits, collapse = ", ")))
  cat(sprintf("  Axes %s/%s, variance explained: %.1f%% / %.1f%%\n",
              names(x$scores)[1], names(x$scores)[2],
              x$var_explained[1], x$var_explained[2]))
  cat(sprintf("  %d specimen(s) projected across %d species\n",
              nrow(x$scores), nlevels(x$groups)))
  tb <- table(x$groups)
  for (g in names(tb)) cat(sprintf("    %-28s n = %d\n", g, tb[[g]]))
  if (!is.null(x$itv_proportion)) {
    v <- x$itv_proportion$volume
    pooled <- v[v$group == "(all focal species)", , drop = FALSE]
    if (nrow(pooled) == 1 && is.finite(pooled$proportion)) {
      cat(sprintf(
        "  ITV / global functional volume (%d-D hull): %.2f%% of the reference\n",
        x$itv_proportion$volume_dims, 100 * pooled$proportion))
    }
    tr <- x$itv_proportion$trait
    if (nrow(tr) > 0) {
      cat(sprintf("  ITV / global trait range: mean %.1f%%, per-trait %.1f-%.1f%%\n",
                  100 * mean(tr$proportion_pooled, na.rm = TRUE),
                  100 * min(tr$proportion_pooled, na.rm = TRUE),
                  100 * max(tr$proportion_pooled, na.rm = TRUE)))
    }
    cat("  (see $itv_proportion for the per-trait / per-species breakdown)\n")
  }
  invisible(x)
}

#' Plot specimens projected into the global FISHMORPH space
#'
#' Draws the reference database as a background layer -- by default a
#' kernel-density heatmap of the whole FISHMORPH morphospace -- with the
#' projected specimens on top of it, grouped/coloured by species, in any of
#' the display styles shared with [plot.intrait_traitspace()]. The
#' background can equivalently (or additionally) be shown as the raw
#' reference point cloud, and the focal species' own positions *in the
#' reference database* can be marked, to see how a group's projected
#' intraspecific trait variation (ITV) sits relative to its single
#' database point.
#'
#' @param style Character, one of `"hull"` (default; per-species convex hull
#'   = the ITV footprint), `"spider"` (dispersion ellipse + spokes to the
#'   centroid), `"density"` (per-species kernel-density contour of the
#'   projected specimens), or `"points"` (the projected points only, no
#'   per-group geometry). Note this is the *foreground* per-species geometry
#'   and is independent of `reference_density`, which controls the
#'   *background* reference heatmap.
#' @param reference_density Logical, draw the reference database's
#'   distribution as a filled kernel-density heatmap (a white-to-red
#'   gradient with a few nested highest-density-region contour lines) behind
#'   the projected specimens -- the recommended way to show a ~9,000-species
#'   morphospace, which is unreadable as raw points. Defaults to `TRUE`.
#' @param reference_points Logical, draw the reference database species as a
#'   light background point cloud (the previous default display). Can be
#'   combined with `reference_density`. Defaults to `FALSE`.
#' @param itv_reference Logical, mark the focal species' *own* entries in
#'   the reference database -- i.e. the FISHMORPH points of exactly the
#'   species for which projected ITV is shown -- as filled circles coloured
#'   to match their species, so the single database morphotype can be
#'   compared with the spread of the projected individuals. Requires the
#'   projection to carry reference species labels (`x$global_species`, added
#'   by [project_fishmorph()]); species with no matching reference row are
#'   skipped with a warning. Defaults to `FALSE`.
#' @param arrows Logical, overlay the trait *loadings* (the PCA variable
#'   contributions stored in `x$loadings`) as a biplot: one arrow per trait,
#'   drawn from the origin in the direction of that trait's loading on the
#'   two plotted axes, with the trait name at the arrow tip. This turns the
#'   score plot into a standard PCA biplot, showing which morphological
#'   ratios drive each axis and hence how a group's position in the
#'   morphospace should be read ecomorphologically (e.g. an ITV footprint
#'   stretched along the body-elongation arrow varies mostly in body shape).
#'   The arrows are a purely visual overlay and do not change the ordination.
#'   Defaults to `FALSE`.
#' @param arrow_scale Numeric in `(0, 1]`, how far the longest loading arrow
#'   reaches, as a fraction of the distance from the origin to the nearest
#'   plot edge; all arrows are scaled by this same factor so their relative
#'   lengths and directions are preserved. Loadings are unit-scaled vectors
#'   with no natural size in score units, so this is a display choice only.
#'   Smaller values keep the arrows clear of the outer points; larger values
#'   make short loadings more legible. Only used when `arrows = TRUE`.
#'   Defaults to `0.8`.
#' @param arrow_col Colour of the loading arrows and their trait labels (when
#'   `arrows = TRUE`). Defaults to `"grey20"`.
#' @param background Logical master switch: when `FALSE`, no reference
#'   background layer of any kind is drawn (overrides `reference_density`,
#'   `reference_points` and `itv_reference`). Defaults to `TRUE`.
#' @param background_col Colour of the reference point cloud (when
#'   `reference_points = TRUE`). Defaults to `"grey75"`.
#' @param density_probs Numeric vector of coverage probabilities for the
#'   reference heatmap's highest-density-region contour lines. Defaults to
#'   `c(0.25, 0.5, 0.99)`.
#' @param density_palette Optional character vector of colours for the
#'   reference heatmap gradient (low to high density). `NULL` (default) uses
#'   a white-to-dark-red ColorBrewer YlOrRd ramp.
#' @param ellipse_level,density_level Coverage probabilities for the
#'   `"spider"` ellipse and `"density"` contour respectively. Default
#'   `0.95`.
#' @param legend Logical, draw a species legend. Defaults to `TRUE`.
#' @param legend_position,legend_title,legend_italic,abbreviate_species
#'   Legend controls, as in [plot.intrait_traitspace()]; defaults here are
#'   tuned for species names (`legend_title = "Species"`, italic,
#'   abbreviated binomials).
#'
#' @details
#' In the `plot()` method, `select_species`/`select_specimens` restrict
#' *this plot* to a subset of the already-projected species or specimen
#' identifiers, without recomputing the space (the reference background is
#' unchanged); `NULL` (default) plots everything projected. When
#' `itv_reference = TRUE`, the reference points marked follow the same
#' selection: only the focal species still shown after
#' `select_species`/`select_specimens` are matched against the reference
#' database (matching is case-insensitive and treats spaces and underscores
#' as equivalent, so `"Squalius cephalus"` and `"Squalius_cephalus"` match).
#'
#' @return `plot()` invisibly returns `x`.
#' @export
#' @rdname project_fishmorph
plot.intrait_fishmorph_projection <- function(x,
                                              style = c("hull", "spider", "density", "points"),
                                              reference_density = TRUE,
                                              reference_points = FALSE,
                                              itv_reference = FALSE,
                                              arrows = FALSE,
                                              arrow_scale = 0.8,
                                              arrow_col = "grey20",
                                              background = TRUE,
                                              background_col = "grey75",
                                              density_probs = c(0.25, 0.5, 0.99),
                                              density_palette = NULL,
                                              select_species = NULL,
                                              select_specimens = NULL,
                                              ellipse_level = 0.95, density_level = 0.95,
                                              legend = TRUE, legend_position = "outside",
                                              legend_title = "Species", legend_italic = TRUE,
                                              abbreviate_species = TRUE, ...) {
  style <- match.arg(style)
  internal_style <- if (identical(style, "points")) "none" else style
  if (isTRUE(arrows) &&
      (!is.numeric(arrow_scale) || length(arrow_scale) != 1 ||
       arrow_scale <= 0 || arrow_scale > 1)) {
    stop("`arrow_scale` must be a single number in (0, 1].", call. = FALSE)
  }

  sc <- x$scores
  gr <- x$groups
  keep <- rep(TRUE, nrow(sc))
  if (!is.null(select_species))   keep <- keep & as.character(gr) %in% select_species
  if (!is.null(select_specimens)) keep <- keep & rownames(sc) %in% select_specimens
  if (!any(keep)) stop("No projected specimens match the plot selection.", call. = FALSE)
  sc <- sc[keep, , drop = FALSE]
  gr <- droplevels(gr[keep])

  xlab <- sprintf("%s (%.1f%%)", names(x$scores)[1], x$var_explained[1])
  ylab <- sprintf("%s (%.1f%%)", names(x$scores)[2], x$var_explained[2])

  # `background = FALSE` is a master off-switch for every reference layer.
  show_ref <- isTRUE(background)
  draw_density <- show_ref && isTRUE(reference_density)
  draw_points  <- show_ref && isTRUE(reference_points)
  # `bg` (the reference cloud) is passed whenever a density heatmap or a
  # point cloud is drawn from it; the two flags then select which.
  bg <- if (draw_density || draw_points) x$global_scores else NULL

  # Focal species' own reference-database points (itv_reference): match the
  # still-shown focal species against the reference species labels, treating
  # spaces/underscores as equivalent and ignoring case.
  hl <- NULL
  hl_col <- "black"
  if (show_ref && isTRUE(itv_reference)) {
    gs <- x$global_species
    if (is.null(gs)) {
      warning("`itv_reference = TRUE` needs reference species labels; recompute ",
              "the projection with project_fishmorph() (>= 1.6.0).", call. = FALSE)
    } else {
      norm <- function(s) tolower(gsub("[ _]+", " ", trimws(as.character(s))))
      focal <- levels(gr)
      gs_norm <- norm(gs)
      match_idx <- which(gs_norm %in% norm(focal))
      unmatched <- setdiff(norm(focal), gs_norm)
      if (length(unmatched) > 0) {
        warning("`itv_reference`: no reference row for species: ",
                paste(focal[norm(focal) %in% unmatched], collapse = ", "),
                call. = FALSE)
      }
      if (length(match_idx) > 0) {
        hl <- x$global_scores[match_idx, , drop = FALSE]
        # Colour each reference point to match its species' foreground colour.
        label_colors <- .stable_group_colors(levels(gr))
        focal_norm <- norm(names(label_colors))
        hl_col <- unname(label_colors[match(gs_norm[match_idx], focal_norm)])
        hl_col[is.na(hl_col)] <- "black"
      }
    }
  }

  .plot_ordination(sc, gr, xlab, ylab, style = internal_style,
                   ellipse_level = ellipse_level, density_level = density_level,
                   legend = legend, legend_position = legend_position,
                   legend_title = legend_title, legend_italic = legend_italic,
                   abbreviate_species = abbreviate_species,
                   space_name = "FISHMORPH space",
                   background = bg, background_col = background_col,
                   background_density = draw_density, background_points = draw_points,
                   density_probs = density_probs, density_palette = density_palette,
                   highlight = hl, highlight_col = hl_col, ...)

  # Optional PCA-biplot overlay: the trait loadings (x$loadings) on the two
  # plotted axes, drawn as arrows from the origin, so the reader can see
  # which morphological ratios drive each axis. Added *after*
  # .plot_ordination() has drawn the scores, reusing the coordinate system it
  # established (the scores are mean-centred, so the ordination origin is
  # (0, 0), where abline(h = 0, v = 0) is drawn). Loadings are unit-scaled
  # direction vectors with no natural length in score units, so they are
  # rescaled to fit the current plot: the longest arrow reaches `arrow_scale`
  # of the distance from the origin to the nearest plot edge, all arrows
  # sharing that one factor so their relative lengths/directions are kept.
  if (isTRUE(arrows)) {
    load <- x$loadings[, x$axes, drop = FALSE]
    trait_names <- rownames(load)
    lens <- sqrt(rowSums(load^2))
    max_len <- max(lens, na.rm = TRUE)
    usr <- graphics::par("usr")
    # Distance from the origin to the nearest of the four plot edges, so no
    # arrow is drawn outside the plotting region regardless of how the score
    # cloud is offset from (0, 0).
    edge <- min(abs(usr[1]), abs(usr[2]), abs(usr[3]), abs(usr[4]))
    if (is.finite(max_len) && max_len > 0 && is.finite(edge) && edge > 0) {
      fac <- arrow_scale * edge / max_len
      ax <- load[, 1] * fac
      ay <- load[, 2] * fac
      graphics::arrows(0, 0, ax, ay, length = 0.07, angle = 20,
                       col = arrow_col, lwd = 1.5)
      # Trait labels just beyond each arrow tip; xpd = NA lets a label that
      # lands right on the plot border spill into the margin rather than
      # being clipped.
      graphics::text(ax * 1.08, ay * 1.08, labels = trait_names,
                     col = arrow_col, cex = 0.75, font = 3, xpd = NA)
    }
  }
  invisible(x)
}
