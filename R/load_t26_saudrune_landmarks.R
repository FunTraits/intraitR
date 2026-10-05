#' Real T-26 Saudrune landmark data, ready to use as an
#' \code{"intrait_landmarks"} object
#'
#' Loads the real T-26 Saudrune electrofishing landmark data (see
#' [load_t26_saudrune()]) directly as an object of class
#' `"intrait_landmarks"`, in the format returned by
#' [simulate_fishmorph_points()]: a `p x k x n` coordinate array together with
#' a `metadata` data.frame carrying `specimen`, `individual`, `species`,
#' `population` and `replicate`. The real data set is therefore a drop-in
#' replacement for `simulate_fishmorph_points()` wherever a FISHMORPH-scheme
#' `"intrait_landmarks"` object is expected, e.g. [fishmorph_segments()],
#' [fishmorph_ratios()], [trait_space()], [itv_index()], [trait_disparity()]
#' and [plot_fishmorph_points()].
#'
#' @param source Character, one of:
#'   \describe{
#'     \item{`"landmarks"`}{**Default.** Every specimen of the campaign,
#'       digitized once with [digitize_landmarks()] on the 25-point scheme.
#'       `metadata$replicate` is 1 throughout and `metadata$individual` equals
#'       `specimen`.}
#'     \item{`"repeatability"`}{The blind repeat trial: the same individuals
#'       re-digitized several times in the digitizer's repeat mode.
#'       `metadata$individual` is the fish (`code`), `metadata$replicate` the
#'       pass; the input of [digitization_error()], [measurement_error()] and
#'       [operator_disagreement()].}
#'   }
#' @param species Optional character vector of species names: if supplied,
#'   only specimens currently determined as one of these species are kept.
#'   Defaults to `NULL` (every fish is kept).
#' @param operator `NULL` (default, every operator's digitizations), or a
#'   character vector of operator labels (e.g. `"AT"`; see
#'   `unique(load_t26_saudrune(source)$operator)`) to restrict to. With two
#'   operators in `"repeatability"` this is the natural way to build two
#'   separate trait spaces and check whether results depend on who digitized.
#'
#' @return An object of class `"intrait_landmarks"`: `coords` (a `25 x 2 x n`
#'   array), `scale` (`NULL`; the scale bar is embedded as landmarks 20-21, as
#'   in [simulate_fishmorph_points()]) and `metadata` (the five standard
#'   columns plus `operator`, and `species_code`, `quality`, `date` and `uid`
#'   carried over from the `"specimens"` table).
#'
#' @details
#' Point 25 is reserved by the digitizer and currently always `NA`; a few
#' specimens lack the scale bar (20-21). Functions that require a complete
#' configuration (e.g. [gpa_fish()]) should filter on complete cases of the
#' landmarks they use. `metadata$population` is `NA` throughout: the survey
#' sampled one electrofishing point and no sub-population structure is
#' fabricated.
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(12), 2330-2336.
#'
#' @seealso [load_t26_saudrune()], [simulate_fishmorph_points()],
#'   [fishmorph_segments()], [read_landmarks_csv()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' fish
#' table(fish$metadata$species)
#'
#' # restrict to the two most abundant species
#' gobio_squalius <- load_t26_saudrune_landmarks(
#'   species = c("Gobio gobio", "Squalius cephalus")
#' )
#' dim(gobio_squalius$coords)
#'
#' # the repeat trial: several configurations per individual
#' rep_fish <- load_t26_saudrune_landmarks("repeatability")
#' table(rep_fish$metadata$individual)
#'
#' @export
load_t26_saudrune_landmarks <- function(source = c("landmarks", "repeatability"),
                                        species = NULL, operator = NULL) {
  source <- match.arg(source)
  long <- load_t26_saudrune(source, operator = operator)
  spec <- load_t26_saudrune("specimens")

  if (source == "landmarks") {
    key <- unique(long[c("specimen", "code", "operator")])
    key$replicate <- 1L
  } else {
    key <- unique(long[c("specimen", "code", "operator", "replicate")])
  }
  key$individual <- key$code

  meta <- merge(key, spec[c("code", "species", "species_code", "quality", "date", "uid")],
                by = "code", all.x = TRUE, sort = FALSE)
  meta$population <- NA_character_
  other_cols <- setdiff(names(meta), c("specimen", "individual", "species", "population",
                                       "replicate", "code"))
  meta <- meta[c("specimen", "individual", "species", "population", "replicate", other_cols)]
  rownames(meta) <- meta$specimen

  if (!is.null(species)) {
    keep_specimens <- meta$specimen[meta$species %in% species]
    long <- long[long$specimen %in% keep_specimens, ]
    meta <- meta[meta$specimen %in% keep_specimens, , drop = FALSE]
  }

  read_landmarks_csv(long, specimen = "specimen", landmark = "landmark",
                     coords = c("X", "Y"), metadata = meta)
}
