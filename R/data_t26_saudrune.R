#' Real freshwater fish landmark data set from an electrofishing campaign
#' (T-26, La Saudrune)
#'
#' Loads one of four cleaned, analysis-ready tables from the T-26 electric
#' fishing survey conducted on the Saudrune (Adour-Garonne basin, south of
#' Toulouse, France), the first **real** (non-simulated) data set shipped
#' with intraitR. Individuals were photographed in the field and later
#' digitized on the 21-landmark FISHMORPH scheme (Brosse et al., 2021; see
#' [fishmorph_segments()]) directly from the photographs.
#'
#' @param dataset Character, one of `"operators"` (default),
#'   `"repeatability"`, `"identifications"`, or `"qc_log"`. See Details.
#'
#' @return A `data.frame`:
#'   \describe{
#'     \item{`"operators"`}{Long-format landmark coordinates (columns
#'       `specimen`, `code`, `operator`, `landmark`, `X`, `Y`), one row per
#'       specimen x landmark combination. 279 fish, each digitized once by
#'       each of two independent operators (558 specimen-level
#'       digitizations, 21 landmarks each). Use [read_landmarks_csv()] to
#'       import this table as an `"intrait_landmarks"` object; see
#'       `demo(pipeline_T26_saudrune)`.}
#'     \item{`"repeatability"`}{Long-format landmark coordinates (columns
#'       `specimen`, `code`, `replicate`, `operator`, `site`, `landmark`,
#'       `X`, `Y`) for the intra-operator repeatability trial: 25
#'       individuals, each digitized 9-10 times independently by the same
#'       operator. Intended for [measurement_error()] and
#'       [digitization_error()].}
#'     \item{`"identifications"`}{One row per fish (`code`), with
#'       `species` (binomial), `id_status` (`"curated"`, `"preliminary"` --
#'       from AI-vision-assisted identification not yet manually confirmed,
#'       or `"unresolved"`), `french_name`, `stage`, `confidence`,
#'       `n_individus`, `date_capture`, `site`. As noted in
#'       `metadonnees`/`stats` of the original identification file,
#'       identifications are a curated-but-not-fully-audited pilot data
#'       set: a handful of entries may still contain errors, which is why
#'       `id_status` is exposed explicitly rather than silently treating
#'       every row as ground truth.}
#'     \item{`"qc_log"`}{One row per specimen excluded during data
#'       cleaning (e.g. a code present in the measurement sheet with no
#'       match in the identification sheet), with a `reason` column,
#'       kept for full transparency of the cleaning pipeline (see
#'       `data-raw/t26_saudrune_prepare.R`).}
#'   }
#'
#' @details
#' Coordinates are in pixel units of the original photographs; landmarks
#' 20-21 are the two ends of a 1 cm calibration segment digitized on a
#' ruler placed alongside each fish, following the same convention as
#' [fishmorph_segments()]'s `scale_cm` argument (so `fishmorph_segments()`
#' can be called directly on `"intrait_landmarks"` objects built from these
#' tables with its default `scale_cm = 1`).
#'
#' Per the explicit instruction of the data owner, taxonomic identifications
#' have not been re-audited as part of building this data set: some species
#' calls (in particular the 16 entries with `id_status == "preliminary"`,
#' and the single `"unresolved"` juvenile) should be treated with caution
#' for any analysis sensitive to species identity, and are flagged via
#' `id_status` for exactly that reason.
#'
#' @source T-26 electrofishing campaign, Saudrune (Adour-Garonne basin,
#'   France), 21 April 2026. Landmarks digitized by two independent
#'   operators; identifications curated with AI-vision assistance by A.
#'   Toussaint (CNRS). Raw spreadsheets are not distributed with the
#'   package (only the cleaned, analysis-ready tables are); see
#'   `data-raw/t26_saudrune_prepare.R` for the full cleaning/QC pipeline.
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(12), 2330-2336.
#'
#' @seealso [read_landmarks_csv()], [fishmorph_segments()], [gpa_fish()],
#'   [digitization_error()], [measurement_error()];
#'   `demo(pipeline_T26_saudrune)` for a complete worked analysis of this
#'   data set using intraitR.
#'
#' @examples
#' ops <- load_t26_saudrune("operators")
#' str(ops)
#' ident <- load_t26_saudrune("identifications")
#' table(ident$species, ident$id_status)
#'
#' @export
load_t26_saudrune <- function(dataset = c("operators", "repeatability", "identifications", "qc_log")) {
  dataset <- match.arg(dataset)
  file <- switch(dataset,
    operators       = "t26_landmarks_operators.csv",
    repeatability   = "t26_landmarks_repeatability.csv",
    identifications = "t26_identifications.csv",
    qc_log          = "t26_qc_log.csv"
  )
  path <- system.file("extdata", "T26_Saudrune", file, package = "intraitR")
  if (!nzchar(path)) {
    stop("Could not find '", file, "' under inst/extdata/T26_Saudrune/; ",
         "is intraitR installed correctly?", call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}
