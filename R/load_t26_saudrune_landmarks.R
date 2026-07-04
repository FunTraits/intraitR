#' Real T-26 Saudrune landmark data, ready to use as an
#' \code{"intrait_landmarks"} object
#'
#' Loads the real T-26 Saudrune electrofishing landmark data (see
#' [load_t26_saudrune()]) directly as an object of class
#' `"intrait_landmarks"`, in exactly the format returned by
#' [simulate_fishmorph_points()]: a `p x k x n` coordinate array (21
#' FISHMORPH landmarks; Brosse et al., 2021) together with a `metadata`
#' data.frame carrying `specimen`, `individual`, `species`, `population`
#' and `replicate` columns. This makes the real data set a drop-in
#' replacement for `simulate_fishmorph_points()` wherever a FISHMORPH-scheme
#' `"intrait_landmarks"` object is expected, e.g. [fishmorph_segments()],
#' [fishmorph_ratios()], [trait_space()], [itv_index()],
#' [trait_disparity()], and [plot_fishmorph_points()].
#'
#' @param source Character, one of `"operators"` (default: 279 fish, one
#'   digitization per operator, from the two independent operators of the
#'   T-26 survey) or `"repeatability"` (25 individuals, 9-10 replicate
#'   digitizations by a single operator; see [digitization_error()] and
#'   [measurement_error()]).
#' @param species Optional character vector of species names: if supplied,
#'   only specimens identified (curated or preliminary) as one of these
#'   species are kept. Defaults to `NULL` (every fish is kept, including
#'   the single specimen with an unresolved identification, for which
#'   `metadata$species` is `NA`; see [load_t26_saudrune()]).
#' @param operator `NULL` (default, every operator's digitizations are
#'   returned), or a character vector of one or more anonymous operator
#'   labels (e.g. `"Operator_1"`; see `unique(load_t26_saudrune(source)$operator)`
#'   for the labels available for a given `source`) to restrict to. This
#'   is the natural way to build **two separate functional trait spaces**,
#'   one per operator, from `source = "operators"` (each fish was
#'   digitized once by each of two operators) — e.g. to check whether
#'   [trait_space()] or [fishmorph_ratios()] results are sensitive to who
#'   did the digitizing, complementing the landmark-level view of
#'   [digitization_error()]. Modular by design: if the requested `source`
#'   has no `operator` column, `operator` is ignored with a warning and
#'   every row is returned (in practice every `source` currently offered
#'   here does have one, but this keeps the function robust to future
#'   `source` options that might not).
#'
#' @return An object of class `"intrait_landmarks"`, a list with elements
#'   `coords` (a `21 x 2 x n` array), `scale` (`NULL`; the scale bar is
#'   embedded as landmarks 20-21, as in [simulate_fishmorph_points()]), and
#'   `metadata` (a `data.frame` with, in addition to the five standard
#'   columns shared with `simulate_fishmorph_points()`'s output, an
#'   `operator` column and, for `source = "repeatability"`, a `site`
#'   column carried over from the raw data).
#'
#' @details
#' Unlike [simulate_fishmorph_points()], real specimens are not all fully
#' digitized: some coordinates (chiefly landmark 5, in roughly a quarter
#' of specimens) are missing. Functions that require a complete
#' configuration (e.g. [gpa_fish()], which is not intended for this mixed
#' shape/scale-bar landmark scheme in any case; see
#' [simulate_fishmorph_points()]) should filter on complete cases first.
#' `metadata$population` is set to `NA` throughout, because the T-26
#' survey sampled a single electrofishing point: unlike the simulated data
#' set, there is no genuine sub-population structure in this real sample
#' to report, and none is fabricated here.
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
#' table(fish$metadata$species, useNA = "ifany")
#'
#' # restrict to the two most abundant species
#' gobio_squalius <- load_t26_saudrune_landmarks(
#'   species = c("Gobio occitaniae", "Squalius cephalus")
#' )
#' dim(gobio_squalius$coords)
#'
#' # build two separate functional trait spaces, one per operator, to check
#' # whether the two digitizers' morphospaces agree:
#' fish_op1 <- load_t26_saudrune_landmarks(operator = "Operator_1")
#' fish_op2 <- load_t26_saudrune_landmarks(operator = "Operator_2")
#' ratios_op1 <- fishmorph_ratios(fishmorph_segments(fish_op1))
#' ratios_op2 <- fishmorph_ratios(fishmorph_segments(fish_op2))
#' ts_op1 <- trait_space(ratios_op1, groups = fish_op1$metadata$species, na_action = "omit")
#' ts_op2 <- trait_space(ratios_op2, groups = fish_op2$metadata$species, na_action = "omit")
#'
#' @export
load_t26_saudrune_landmarks <- function(source = c("operators", "repeatability"),
                                         species = NULL, operator = NULL) {
  source <- match.arg(source)
  long <- load_t26_saudrune(source, operator = operator)
  ident <- load_t26_saudrune("identifications")

  if (source == "operators") {
    key <- unique(long[c("specimen", "code", "operator")])
    key$replicate <- as.integer(factor(key$operator))
  } else {
    key <- unique(long[c("specimen", "code", "replicate", "operator", "site")])
  }
  key$individual <- key$code

  meta <- merge(key, ident[c("code", "species")], by = "code", all.x = TRUE, sort = FALSE)
  meta$population <- NA_character_
  other_cols <- setdiff(names(meta), c("specimen", "individual", "species", "population", "replicate", "code"))
  meta <- meta[c("specimen", "individual", "species", "population", "replicate", other_cols)]
  rownames(meta) <- meta$specimen

  if (!is.null(species)) {
    keep_specimens <- meta$specimen[meta$species %in% species]
    long <- long[long$specimen %in% keep_specimens, ]
    meta <- meta[meta$specimen %in% keep_specimens, , drop = FALSE]
  }

  read_landmarks_csv(long, specimen = "specimen", landmark = "landmark", coords = c("X", "Y"), metadata = meta)
}
