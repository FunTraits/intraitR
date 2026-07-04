#' Compute the nine FISHMORPH unitless ecomorphological ratios
#'
#' Derives the nine dimensionless morphological ratios (traits) defined by
#' Brosse et al. (2021) for their FISHMORPH database, from the 11 linear
#' measurements produced by [fishmorph_segments()], and optionally
#' assembles the complete 10-trait FISHMORPH table by adding maximum body
#' length (`MBl`), a species-level, literature-derived size trait not
#' measured from the picture itself (e.g. taken from FishBase).
#'
#' @param segments A `data.frame` as returned by [fishmorph_segments()], or
#'   any `data.frame` containing (at least) numeric columns `Bl`, `Bd`,
#'   `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`, `CFd`.
#' @param MBl Optional numeric vector of maximum body length (one value
#'   per row of `segments`, same order), used only to add an `MBl` column
#'   to the output; not used in any ratio computation.
#' @param no_caudal_fin Logical, length 1 or `nrow(segments)`. `TRUE` for
#'   specimens with no visible caudal fin (e.g. Sternopygidae, Anguillidae,
#'   Plotosidae), for which caudal peduncle throttling (`CPt`) is set to 1
#'   (caudal fin depth assumed equal to caudal peduncle depth), following
#'   Villéger et al. (2010). Defaults to `FALSE`.
#' @param ventral_mouth Logical, length 1 or `nrow(segments)`. `TRUE` for
#'   algae-browsing species with the mouth positioned under the body
#'   (e.g. Loricariidae, some Balitoridae such as *Gastromyzon*), for which
#'   oral gape position (`OGp`) and relative maxillary length (`RMl`) are
#'   set to 0, following Villéger et al. (2010). Defaults to `FALSE`.
#' @param no_pectoral_fin Logical, length 1 or `nrow(segments)`. `TRUE` for
#'   species without pectoral fins (e.g. Synbranchiformes, some
#'   Anguilliformes), for which pectoral fin vertical position (`PFv`) is
#'   set to 0, following Villéger et al. (2010). Defaults to `FALSE`.
#' @param digits Integer, number of decimal places to round ratios to.
#'   Defaults to `4`.
#' @param groups Optional factor (or character vector), one value per row
#'   of `segments`, used only by `na_action = "impute_group_mean"` (and
#'   optionally by `"missforest"`, as an auxiliary predictor). If `NULL`
#'   and `segments` has a `species` column, it is used automatically (as
#'   in [trait_space()]).
#' @param na_action Character, how to handle missing values in the 9
#'   computed ratio columns (e.g. because one of the two segments a ratio
#'   divides was itself `NA`, whether from a missing landmark or from
#'   [fishmorph_segments()] having already left it `NA`): `"keep"`
#'   (default) leaves `NA` in place, exactly as in previous package
#'   versions; `"omit"` removes affected specimens and reports how many;
#'   `"impute_mean"` replaces missing ratio values with the column mean;
#'   `"impute_group_mean"` uses the within-group (e.g. within-species)
#'   mean instead, falling back to the column mean, with a warning, for a
#'   group entirely missing a ratio; `"missforest"` uses random-forest-
#'   based iterative imputation (`missForest::missForest()`). Same
#'   convention, options, and messages as [trait_space()]'s `na_action`
#'   -- see there for details -- except that here imputation operates on
#'   the derived *ratios* directly; imputing at the landmark level with
#'   [impute_landmarks()], or at the [fishmorph_segments()] stage instead
#'   (before computing ratios), is usually preferable when both are
#'   missing for the same specimen.
#' @param missforest_ntree,missforest_maxiter Number of trees per forest
#'   and maximum number of iterations passed to `missForest::missForest()`
#'   when `na_action = "missforest"`; ignored otherwise. Default to
#'   `missForest`'s own defaults (`100` and `10`).
#'
#' @return A `data.frame` (class `"intrait_fishmorph"`) with one row per
#'   specimen (fewer, if `na_action = "omit"` dropped any), an `MBl`
#'   column if supplied, and columns `BEl`, `VEp`, `REs`, `OGp`, `RMl`,
#'   `BLs`, `PFv`, `PFs`, `CPt`, preceded by any metadata columns carried
#'   over from `segments`.
#'
#' @details
#' The nine ratios and their ecological interpretation, following Brosse
#' et al. (2021, their figure 1b), are: body elongation
#' (`BEl = Bl / Bd`, hydrodynamism), vertical eye position
#' (`VEp = Eh / Bd`, position of the fish and/or its prey in the water
#' column), relative eye size (`REs = Ed / Hd`, visual acuity), oral gape
#' position (`OGp = Mo / Bd`, feeding position in the water column),
#' relative maxillary length (`RMl = Jl / Hd`, mouth size and jaw
#' strength), body lateral shape (`BLs = Hd / Bd`, hydrodynamism and head
#' size), pectoral fin vertical position (`PFv = PFi / Bd`, pectoral fin
#' use for swimming), pectoral fin size (`PFs = PFl / Bl`, pectoral fin
#' use for swimming), and caudal peduncle throttling
#' (`CPt = CFd / CPd`, caudal propulsion efficiency through reduction of
#' drag).
#'
#' Note that a fourth exception described by Villéger et al. (2010) — for
#' flatfishes (Pleuronectiformes), body depth (`Bd`) should be measured as
#' body *width* rather than body depth, because the fish lies on one side
#' of its body in lateral-view pictures — cannot be corrected after the
#' fact and must instead be applied when digitizing landmarks 3-4
#' (see [fishmorph_segments()]).
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(11), 2330-2336.
#'
#' Villéger, S., Ramos Miranda, J., Flores Hernandez, D., & Mouillot, D.
#' (2010). Contrasting changes in taxonomic vs. functional diversity of
#' tropical fish communities after habitat degradation. Ecological
#' Applications, 20(6), 1512-1522.
#'
#' @seealso [fishmorph_segments()], [trait_space()],
#'   [load_t26_saudrune_landmarks()], [impute_landmarks()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' fishmorph_ratios(segments)
#'
#' # impute missing ratios (na_action defaults to "keep") using the
#' # within-species mean instead of carrying NA forward:
#' fishmorph_ratios(segments, groups = segments$species, na_action = "impute_group_mean")
#'
#' @export
fishmorph_ratios <- function(segments, MBl = NULL, no_caudal_fin = FALSE,
                              ventral_mouth = FALSE, no_pectoral_fin = FALSE,
                              digits = 4, groups = NULL,
                              na_action = c("keep", "omit", "impute_mean",
                                            "impute_group_mean", "missforest"),
                              missforest_ntree = 100, missforest_maxiter = 10) {
  na_action <- match.arg(na_action)
  required <- c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")
  missing_cols <- setdiff(required, names(segments))
  if (length(missing_cols) > 0) {
    stop(
      "`segments` is missing required column(s): ", paste(missing_cols, collapse = ", "),
      ". Use fishmorph_segments() to compute them, or supply a data.frame with these exact column names.",
      call. = FALSE
    )
  }

  n <- nrow(segments)
  recycle <- function(x, name) {
    if (length(x) == 1) {
      rep(x, n)
    } else if (length(x) == n) {
      x
    } else {
      stop("`", name, "` must have length 1 or nrow(segments) (", n, ").", call. = FALSE)
    }
  }
  no_caudal_fin <- recycle(no_caudal_fin, "no_caudal_fin")
  ventral_mouth <- recycle(ventral_mouth, "ventral_mouth")
  no_pectoral_fin <- recycle(no_pectoral_fin, "no_pectoral_fin")
  if (!is.null(MBl) && length(MBl) != n) {
    stop("`MBl` must have length nrow(segments) (", n, ").", call. = FALSE)
  }

  Bl <- segments$Bl; Bd <- segments$Bd; Hd <- segments$Hd; Eh <- segments$Eh
  Mo <- segments$Mo; PFi <- segments$PFi; PFl <- segments$PFl; Ed <- segments$Ed
  Jl <- segments$Jl; CPd <- segments$CPd; CFd <- segments$CFd

  BEl <- Bl / Bd
  VEp <- Eh / Bd
  REs <- Ed / Hd
  OGp <- Mo / Bd
  RMl <- Jl / Hd
  BLs <- Hd / Bd
  PFv <- PFi / Bd
  PFs <- PFl / Bl
  CPt <- CFd / CPd

  CPt[no_caudal_fin] <- 1
  OGp[ventral_mouth] <- 0
  RMl[ventral_mouth] <- 0
  PFv[no_pectoral_fin] <- 0

  ratio_mat <- cbind(
    BEl = BEl, VEp = VEp, REs = REs, OGp = OGp, RMl = RMl,
    BLs = BLs, PFv = PFv, PFs = PFs, CPt = CPt
  )
  rownames(ratio_mat) <- rownames(segments)

  if (is.null(groups) && "species" %in% names(segments)) {
    groups <- segments$species
  }
  if (!is.null(groups)) {
    if (length(groups) != n) stop("`groups` must have one entry per row of `segments`.", call. = FALSE)
    groups <- factor(groups)
  }

  res <- .apply_na_action(
    ratio_mat, groups, na_action, missforest_ntree, missforest_maxiter,
    context = "ratios"
  )
  ratio_mat <- res$X
  if (!all(res$keep)) {
    segments <- segments[res$keep, , drop = FALSE]
    if (!is.null(MBl)) MBl <- MBl[res$keep]
  }

  ratio_df <- as.data.frame(round(ratio_mat, digits))
  rownames(ratio_df) <- rownames(segments)

  if (!is.null(MBl)) {
    if (length(MBl) != nrow(ratio_df)) {
      stop("`MBl` must have length nrow(segments) (", nrow(ratio_df), ").", call. = FALSE)
    }
    ratio_df <- cbind(MBl = MBl, ratio_df)
  }

  meta_cols <- setdiff(names(segments), required)
  if (length(meta_cols) > 0) {
    ratio_df <- cbind(segments[meta_cols], ratio_df)
  }

  structure(ratio_df, class = c("intrait_fishmorph", "data.frame"))
}
