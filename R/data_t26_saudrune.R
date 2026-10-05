#' Real freshwater fish landmark data set from an electrofishing campaign
#' (T-26, La Saudrune)
#'
#' Loads one of the four analysis-ready tables of the T-26 electric fishing
#' survey of the Saudrune (Adour-Garonne basin, south of Toulouse, France),
#' the real (non-simulated) data set shipped with intraitR. Fish were
#' photographed in the field on two dates (27 April and 18 May 2026) and
#' digitized with [digitize_landmarks()] on the 25-point scheme: the 19
#' FISHMORPH anatomical landmarks (Brosse et al., 2021; see
#' [fishmorph_segments()]), the scale bar (20-21), the curvature point (22),
#' the derived head base (23) and the entry hinges (24-25).
#'
#' @param dataset Character, one of `"landmarks"` (default), `"specimens"`,
#'   `"repeatability"` or `"qc_log"`. See Value.
#' @param operator `NULL` (default, all rows returned), or a character vector
#'   of one or more operator labels (e.g. `"AT"`) to restrict the returned rows
#'   to. Modular by design: if `dataset` has no `operator` column, `operator` is
#'   ignored with a warning and every row is returned.
#' @param species Logical, defaults to `FALSE`. If `TRUE`, left-joins the
#'   `species` and `species_code` columns of the `"specimens"` table onto
#'   `dataset`, matched by `code` with a plain [match()] lookup (not [merge()]),
#'   so the many rows sharing one `code` in the long-format tables keep their
#'   order exactly. `FALSE` by default because a landmark never needs to know a
#'   species and a determination can be revised without touching a coordinate:
#'   the two tables are kept apart on purpose. Ignored with a warning if
#'   `dataset` has no `code` column; a no-op on `"specimens"` itself.
#'
#' @return A `data.frame`:
#'   \describe{
#'     \item{`"landmarks"`}{Long-format coordinates (`specimen`, `code`,
#'       `operator`, `landmark`, `X`, `Y`), 25 rows per specimen, one
#'       digitization per specimen. Coordinates are pixels of the prepared
#'       photograph. Points a specimen does not carry are `NA` rather than
#'       absent rows, so the table is rectangular; point 25 is reserved by the
#'       digitizer and currently always `NA`. `specimen` and `code` are the
#'       campaign's immutable identifier `SITE_YYYYMMDD_NNNN`, with the suffix
#'       `_iK` for the K-th fish of a multi-individual plate.}
#'     \item{`"specimens"`}{One row per digitized specimen (`code`): `uid` (the
#'       photograph), `individual` (position on the plate, 1 for a single
#'       fish), `photo`, the current determination (`species`, `species_code`,
#'       `confidence`, `determined_by`), `site`, `date`, `operator`, the
#'       operator's `quality` score (1-5), `reviewed`, `n_landmarks` placed,
#'       `ruler_mm`, `mm_per_px`, image size, `photo_hash` (see [photo_hash()]),
#'       `app_version` and the `digitized` date.}
#'     \item{`"repeatability"`}{Long-format coordinates (`specimen`, `code`,
#'       `operator`, `replicate`, `landmark`, `X`, `Y`) of the blind repeat
#'       trial run in `digitize_landmarks()`'s repeat mode: the same individuals
#'       (`code`) re-digitized several times. `specimen` is
#'       `<code>_<operator>_rep<N>` and is unique. Input of
#'       [digitization_error()], [measurement_error()] and, once a second
#'       operator has digitized the same fish, [operator_disagreement()].}
#'     \item{`"qc_log"`}{One row per digitization excluded from the shipped
#'       tables, with the `reason` (see `data-raw/t26_campaign_prepare.R`).}
#'   }
#'
#' @details
#' Identity follows the campaign's own rule: the code is the photograph,
#' never the species. Species names are the last non-superseded determination
#' recorded in the campaign (`export/determinations.csv`) at the time the
#' tables were built, and may be revised in a later release without any
#' coordinate changing. Landmarks 20-21 are the two ends of a 10 mm segment on
#' a ruler placed alongside each fish, so [fishmorph_segments()] can be called
#' on these data with its default `scale_cm = 1`.
#'
#' @source T-26 electrofishing campaign, Saudrune (Adour-Garonne basin,
#'   France), 27 April and 18 May 2026; digitized by A. Toussaint (CNRS) with
#'   [digitize_landmarks()]. The raw workbook and photographs are not
#'   distributed; `data-raw/t26_campaign_prepare.R` rebuilds the tables.
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(12), 2330-2336.
#'
#' @seealso [load_t26_saudrune_landmarks()], [read_landmarks_csv()],
#'   [fishmorph_segments()], [digitization_error()], [measurement_error()];
#'   `demo(pipeline_T26_saudrune)` for a complete worked analysis.
#'
#' @examples
#' lm <- load_t26_saudrune()
#' str(lm)
#' spec <- load_t26_saudrune("specimens")
#' table(spec$species, spec$date)
#'
#' # the landmark table carries `code`, not `species` (species lives in
#' # "specimens" by design); species = TRUE joins it back, in row order:
#' lm_sp <- load_t26_saudrune(species = TRUE)
#' identical(lm_sp$code, lm$code)
#'
#' # the blind repeat trial: one `code` digitized several times
#' rep_df <- load_t26_saudrune("repeatability")
#' table(unique(rep_df[c("code", "replicate")])$code)
#'
#' @export
load_t26_saudrune <- function(dataset = c("landmarks", "specimens", "repeatability", "qc_log"),
                              operator = NULL, species = FALSE) {
  dataset <- match.arg(dataset)
  file <- switch(dataset,
    landmarks     = "t26_campaign_landmarks.csv.gz",
    specimens     = "t26_campaign_specimens.csv",
    repeatability = "t26_campaign_repeatability.csv.gz",
    qc_log        = "t26_campaign_qc_log.csv"
  )
  path <- system.file("extdata", "T26_Saudrune", file, package = "intraitR")
  if (!nzchar(path)) {
    stop("Could not find '", file, "' under inst/extdata/T26_Saudrune/; ",
         "is intraitR installed correctly?", call. = FALSE)
  }
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (dataset == "specimens") {
    df$photo_hash <- as.character(df$photo_hash)
    df$reviewed <- as.character(df$reviewed)
  }
  df <- .filter_by_operator(df, operator, dataset_label = sprintf("the \"%s\" table", dataset))
  if (isTRUE(species)) {
    df <- .join_species(df, dataset_label = sprintf("the \"%s\" table", dataset))
  }
  df
}
