#' Analyses of measured fishes, exported as a reproducible project
#'
#' Opens a Shiny application for the ANALYSIS part of the intraitR workflow,
#' on specimens already measured: FISHMORPH traits, functional trait space and
#' dispersion tests, position in the global FISHMORPH space, intraspecific
#' variability (variance partition, coefficients of variation, sampling
#' effort), shape space, measurement error. Each tab shows the result live;
#' the *Export* tab writes the whole analysis as a project with the
#' architecture of a published paper -- numbered scripts, data, results,
#' `run_all.R`, README, and a Methods & Results report -- by running the
#' project's own scripts, then zips it (see [write_analysis_project()]).
#'
#' The measurement hub ([launch_measure_hub()]) opens it from its *Results*
#' tab on the measured specimens of the chosen scope.
#'
#' @param xlsx_path A digitizer workbook (sheet `measurements`; a `bias` sheet,
#'   when present, gives the repeated digitizations for measurement error).
#'   Landmarks are read up to point 25, so that the hinges of curved
#'   specimens count in standard length.
#' @param specimens Optional table of the specimens (a data.frame or the path
#'   of a CSV file): column `specimen` (the workbook's identifier) and any of
#'   `species`, `site`, `date`, `operator`. It overrides the workbook's own
#'   columns and restricts the analysis to the specimens it lists.
#' @param landmarks Alternatively, an `"intrait_landmarks"` object (or the
#'   path of an `.rds` file holding one), metadata with `species`.
#' @param literature Optional individual trait records without photographs
#'   (a data.frame or the path of a CSV file): `species`, the nine FISHMORPH
#'   ratios, and optionally `specimen_code`, `site`, `date`, `study_id`. They
#'   enter the analyses based on the ratios, with the provenance
#'   `"literature"`; the hub passes those of its Results filters.
#' @param title,author Pre-filled title and author of the exported project.
#' @param launch.browser,port,host Passed to [shiny::runApp()].
#' @param ... Other arguments for [shiny::runApp()].
#' @return Called for its side effect; the app's value when it closes.
#' @seealso [write_analysis_project()], [analysis_params()]
#' @examples
#' \dontrun{
#' launch_intrait_analyses(xlsx_path = "T26_landmarks.xlsx")
#' }
#' @export
launch_intrait_analyses <- function(xlsx_path = NULL, specimens = NULL, landmarks = NULL,
                                    literature = NULL, title = NULL, author = NULL,
                                    launch.browser = TRUE, port = NULL,
                                    host = "127.0.0.1", ...) {
  for (p in c("shiny", "bslib")) if (!requireNamespace(p, quietly = TRUE))
    stop("launch_intrait_analyses() needs the '", p, "' package.", call. = FALSE)
  if (is.character(landmarks) && length(landmarks) == 1L) landmarks <- readRDS(landmarks)
  if (!is.null(landmarks) && !inherits(landmarks, "intrait_landmarks"))
    stop("`landmarks` must be an \"intrait_landmarks\" object.", call. = FALSE)
  if (is.character(specimens) && length(specimens) == 1L)
    specimens <- utils::read.csv(specimens, stringsAsFactors = FALSE, colClasses = "character")
  if (is.character(literature) && length(literature) == 1L)
    literature <- utils::read.csv(literature, stringsAsFactors = FALSE,
                                  colClasses = c(specimen_code = "character", site = "character",
                                                 date = "character", study_id = "character"))
  if (!is.null(xlsx_path) && !file.exists(xlsx_path))
    stop("Workbook not found: ", xlsx_path, call. = FALSE)
  old <- options(intraitR.analyses = list(
    xlsx_path = xlsx_path, specimens = specimens, landmarks = landmarks,
    literature = literature,
    title = title, author = author))
  on.exit(options(old), add = TRUE)
  app <- system.file("shiny", "analyses_app", package = "intraitR")
  args <- list(appDir = app, launch.browser = launch.browser, host = host, ...)
  if (!is.null(port)) args$port <- port
  do.call(shiny::runApp, args)
}

# The workbook's measured specimens, restricted to and described by `specimens`.
.ana_load_input <- function(xlsx_path = NULL, specimens = NULL, landmarks = NULL,
                            literature = NULL) {
  lit <- if (!is.null(literature) && nrow(literature)) literature else NULL
  if (is.null(landmarks) && is.null(xlsx_path)) {
    if (is.null(lit)) stop("No data: give a workbook, landmarks or literature records.", call. = FALSE)
    return(list(lm = NULL, repeats = NULL, literature = lit))
  }
  lm <- landmarks %||% .ana_read_workbook(xlsx_path, "measurements")
  rep <- NULL
  if (!is.null(xlsx_path) && requireNamespace("readxl", quietly = TRUE) &&
      "bias" %in% readxl::excel_sheets(xlsx_path)) {
    rep <- tryCatch(.ana_read_workbook(xlsx_path, "bias"), error = function(e) NULL)
    kr <- .ana_keep_replicated(rep)
    rep <- kr$rep
    if (!is.null(rep)) attr(rep, "dropped") <- kr$dropped
  }
  if (!is.null(specimens) && nrow(specimens)) {
    specimens <- as.data.frame(specimens, stringsAsFactors = FALSE)
    sp <- dimnames(lm$coords)[[3]]
    keep <- sp %in% specimens$specimen
    lm$coords <- lm$coords[, , keep, drop = FALSE]
    md <- lm$metadata[keep, , drop = FALSE]
    j <- match(md$specimen, specimens$specimen)
    for (cc in setdiff(names(specimens), "specimen")) md[[cc]] <- as.character(specimens[[cc]][j])
    lm$metadata <- md
    if (!is.null(rep) && !is.null(rep$metadata$individual) && !is.null(specimens$photo_code)) {
      # the repeats are described by the photograph they were made on
      k <- match(rep$metadata$individual, specimens$photo_code)
      for (cc in intersect(c("species", "site", "date"), names(specimens)))
        rep$metadata[[cc]] <- ifelse(is.na(k), rep$metadata[[cc]] %||% NA, specimens[[cc]][k])
    }
  }
  if (is.null(lm$metadata$species))
    lm$metadata$species <- NA_character_
  if (!is.null(rep)) {
    # a repeat is made on a photograph that is also measured: same species,
    # site and date (the identifier of the measured specimen, or its photograph)
    md <- lm$metadata
    key <- if (!is.null(md$photo_code)) md$photo_code else md$specimen
    k <- match(rep$metadata$individual, key)
    k[is.na(k)] <- match(rep$metadata$individual[is.na(k)], md$specimen)
    for (cc in intersect(c("species", "site", "date"), names(md))) {
      cur <- rep$metadata[[cc]] %||% rep(NA_character_, length(k))
      rep$metadata[[cc]] <- ifelse(is.na(cur) | !nzchar(cur), md[[cc]][k], cur)
    }
  }
  list(lm = lm, repeats = rep, literature = lit)
}
