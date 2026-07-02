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
#'
#' @return A `data.frame` (class `"intrait_fishmorph"`) with one row per
#'   specimen, an `MBl` column if supplied, and columns `BEl`, `VEp`,
#'   `REs`, `OGp`, `RMl`, `BLs`, `PFv`, `PFs`, `CPt`, preceded by any
#'   metadata columns carried over from `segments`.
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
#' @seealso [fishmorph_segments()], [trait_space()], [load_t26_saudrune_landmarks()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' fishmorph_ratios(segments)
#'
#' @export
fishmorph_ratios <- function(segments, MBl = NULL, no_caudal_fin = FALSE,
                              ventral_mouth = FALSE, no_pectoral_fin = FALSE,
                              digits = 4) {
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

  ratio_df <- data.frame(
    BEl = round(BEl, digits), VEp = round(VEp, digits), REs = round(REs, digits),
    OGp = round(OGp, digits), RMl = round(RMl, digits), BLs = round(BLs, digits),
    PFv = round(PFv, digits), PFs = round(PFs, digits), CPt = round(CPt, digits)
  )
  rownames(ratio_df) <- rownames(segments)

  if (!is.null(MBl)) {
    if (length(MBl) != n) stop("`MBl` must have length nrow(segments) (", n, ").", call. = FALSE)
    ratio_df <- cbind(MBl = MBl, ratio_df)
  }

  meta_cols <- setdiff(names(segments), required)
  if (length(meta_cols) > 0) {
    ratio_df <- cbind(segments[meta_cols], ratio_df)
  }

  structure(ratio_df, class = c("intrait_fishmorph", "data.frame"))
}
