# =============================================================================
# analysis_project.R -- an analysis written as a reproducible project
#
# What launch_intrait_analyses() exports, and what write_analysis_project()
# builds from R: a folder with the architecture of a published paper
# (scripts/ numbered 00_START, 01_DATA, 02_ANALYSIS, 03_FIGURE, 04_SUPP,
# 05_STAT; utils/; data/raw|processed; results/figures|tables; manuscript/;
# run_all.R; README.md; .Rproj; .gitignore), zipped.
#
# THE RULE THAT MAKES IT REPRODUCIBLE: the tables, figures and report of the
# archive are not copies of what the app displayed; they are produced by
# RUNNING THE ARCHIVE'S OWN SCRIPTS (run_all.R, in a separate R process) on
# its own data/raw. What is in results/ is therefore, by construction, what
# anyone obtains by running the project -- the app only sets the parameters.
#
# The templates are in inst/templates/analysis_project/; {{KEY}} placeholders
# are filled here. utils/parameters.R is generated from analysis_params().
# =============================================================================

.ANA_PARAM_DOC <- c(
  seed = "random seed (permutations, resampling)",
  min_n = "minimum number of complete individuals for a species to be analysed",
  species = "species to analyse (NULL = all those with >= min_n individuals)",
  sources = "provenances to analyse, e.g. c(\"campaign\", \"literature\") (NULL = all)",
  ratios = "FISHMORPH ratios used (a specimen needs all of them); default the nine",
  sites = "sites to analyse (NULL = all)",
  impute = "estimate missing anatomical landmarks (impute_landmarks)",
  orientation = "orient every configuration head left, belly down (standardize_orientation)",
  geometry = "enforce the FISHMORPH geometric conventions (correct_geometry)",
  scale_cm = "real length of the scale bar, points 20-21 (cm)",
  scale_action = "specimens without a scale bar: \"pixels\" (kept, ratios valid) or \"na\"",
  no_caudal_fin = "special morphology: no visible caudal fin (CPt = 1)",
  ventral_mouth = "special morphology: ventral mouth (OGp = RMl = 0)",
  no_pectoral_fin = "special morphology: no pectoral fin (PFv = 0)",
  ts_axes = "axes of the trait-space figure",
  ts_remove_outliers = "remove within-species outliers before the trait-space PCA",
  ts_style = "trait-space figure: \"spider\", \"hull\", \"density\" or \"none\"",
  disparity_iter = "permutations of the trait-disparity test",
  pf_style = "FISHMORPH figure: \"hull\", \"spider\", \"density\" or \"points\"",
  pf_itv_reference = "show the FISHMORPH reference position of each species",
  pf_arrows = "show the trait loadings in the FISHMORPH figure",
  itv_nested = "split ITV into between- and within-site parts: \"site\" or \"none\"",
  acc_metric = "rarefaction metric: \"variance\", \"sd\", \"cv\" or \"range\"",
  acc_n_perm = "sub-samples drawn per sample size in the rarefaction",
  acc_conv_tol = "precision criterion of n* (relative half-width of the 95% band)",
  acc_asymptote = "fraction of the asymptote defining n* for metric = \"range\"",
  shape = "run the geometric-morphometric analyses (GPA, shape space, disparity)",
  shape_remove_outliers = "remove Procrustes-distance outliers before the shape PCA",
  shape_style = "shape-space figure: \"spider\", \"hull\", \"density\" or \"none\"",
  shape_disparity_iter = "permutations of the shape-disparity test",
  fig_width_mm = "figure width (mm)",
  fig_height_mm = "figure height (mm)",
  fig_dpi = "figure resolution (dpi) of the .png files"
)

#' Parameters of an analysis project
#'
#' The settings of every step of the analysis written by
#' [write_analysis_project()] (and chosen in [launch_intrait_analyses()]),
#' with their defaults. They end up, commented, in the project's
#' `utils/parameters.R`, the one place where they are read.
#'
#' @param ... Values replacing the defaults, by name: `seed`, `min_n`,
#'   `species`, `sites`, `sources`, `ratios`, `impute`, `orientation`, `geometry`, `scale_cm`,
#'   `scale_action`, `no_caudal_fin`, `ventral_mouth`, `no_pectoral_fin`,
#'   `ts_axes`, `ts_remove_outliers`, `ts_style`, `disparity_iter`,
#'   `pf_style`, `pf_itv_reference`, `pf_arrows`, `itv_nested`,
#'   `acc_metric`, `acc_n_perm`, `acc_conv_tol`, `acc_asymptote`, `shape`,
#'   `shape_remove_outliers`, `shape_style`, `shape_disparity_iter`,
#'   `fig_width_mm`, `fig_height_mm`, `fig_dpi`.
#' @return A named list.
#' @examples
#' str(analysis_params(min_n = 10, acc_n_perm = 49))
#' @export
analysis_params <- function(...) {
  p <- list(seed = 16L, min_n = 5L, species = NULL, sites = NULL, sources = NULL,
            ratios = c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt"),
            impute = FALSE, orientation = FALSE, geometry = FALSE,
            scale_cm = 1, scale_action = "pixels",
            no_caudal_fin = FALSE, ventral_mouth = FALSE, no_pectoral_fin = FALSE,
            ts_axes = c(1L, 2L), ts_remove_outliers = FALSE, ts_style = "spider",
            disparity_iter = 999L,
            pf_style = "hull", pf_itv_reference = TRUE, pf_arrows = FALSE,
            itv_nested = "site",
            acc_metric = "variance", acc_n_perm = 99L, acc_conv_tol = 0.05,
            acc_asymptote = 0.95,
            shape = TRUE, shape_remove_outliers = FALSE, shape_style = "spider",
            shape_disparity_iter = 999L,
            fig_width_mm = 180, fig_height_mm = 140, fig_dpi = 300L)
  new <- list(...)
  bad <- setdiff(names(new), names(p))
  if (length(bad))
    stop("Unknown analysis parameter(s): ", paste(bad, collapse = ", "), call. = FALSE)
  for (k in names(new)) p[k] <- list(new[[k]])
  p
}

# utils/parameters.R, commented
.ana_parameters_r <- function(params) {
  w <- max(nchar(names(params)))
  lines <- vapply(seq_along(params), function(i) {
    k <- names(params)[i]
    v <- paste(deparse(params[[i]], width.cutoff = 500L), collapse = " ")
    sprintf("  %s = %s%s  # %s", formatC(k, width = -w), v,
            if (i < length(params)) "," else "", .ANA_PARAM_DOC[[k]] %||% "")
  }, character(1))
  c("################################################################################",
    "#  Analysis parameters -- the only place where they are set",
    "#",
    "#  Chosen in launch_intrait_analyses() (intraitR); change a value and re-run",
    "#  run_all.R to update every table, figure and the report.",
    "################################################################################",
    "", "PARAMS <- list(", lines, ")")
}

# intrait_landmarks -> long table (specimen, landmark, X, Y) + specimen table
.ana_landmarks_tables <- function(lm) {
  co <- lm$coords
  if (is.null(co) || length(dim(co)) != 3)
    stop("`landmarks` must be an intrait_landmarks object with a p x 2 x n array.",
         call. = FALSE)
  p <- dim(co)[1]; n <- dim(co)[3]
  sp <- dimnames(co)[[3]] %||% as.character(seq_len(n))
  lmk <- dimnames(co)[[1]] %||% as.character(seq_len(p))
  long <- data.frame(specimen = rep(sp, each = p),
                     landmark = rep(suppressWarnings(as.integer(lmk)), times = n),
                     X = as.vector(co[, 1, ]), Y = as.vector(co[, 2, ]),
                     stringsAsFactors = FALSE)
  meta <- lm$metadata
  if (is.null(meta)) meta <- data.frame(specimen = sp, stringsAsFactors = FALSE)
  meta <- as.data.frame(meta, stringsAsFactors = FALSE)
  meta$specimen <- sp
  meta <- meta[, c("specimen", setdiff(names(meta), "specimen")), drop = FALSE]
  list(long = long, meta = meta)
}

.ana_fill <- function(txt, vals) {
  txt <- enc2utf8(txt)
  for (k in names(vals))
    txt <- gsub(paste0("{{", k, "}}"), enc2utf8(as.character(vals[[k]])), txt,
                fixed = TRUE, useBytes = TRUE)
  Encoding(txt) <- "UTF-8"
  txt
}

.ANA_SCRIPT_DESC <- c(
  "00_START_GeneralScript.R" = "Packages, parameters, helpers; sourced by every script",
  "01_DATA_load_and_clean.R" = "Landmarks -> 11 measurements, 9 ratios, analysed sample",
  "02_ANALYSIS_traits_by_species.R" = "Ratios per species: mean, sd, range, CV",
  "03_FIGURE_trait_space.R" = "Fig. 1: trait space (PCA of the 9 ratios)",
  "03_FIGURE_fishmorph_projection.R" = "Fig. 2: the sample in the global FISHMORPH space",
  "03_FIGURE_itv.R" = "Fig. 3: inter- vs intraspecific variance",
  "03_FIGURE_itv_accumulation.R" = "Fig. 4: within-species variability vs sampling effort",
  "03_FIGURE_shape_space.R" = "Fig. 5: shape space (GPA + PCA)",
  "04_SUPP_repeatability.R" = "Measurement error of repeated digitizations",
  "05_STAT_trait_disparity.R" = "Trait dispersion per species, permutation tests",
  "05_STAT_shape_disparity.R" = "Shape disparity per species, permutation tests"
)

.ana_metadata <- function() {
  v <- function(variable, table, definition, unit = "")
    data.frame(variable = variable, table = table, definition = definition, unit = unit,
               stringsAsFactors = FALSE)
  rat <- c(BEl = "body elongation, Bl / Bd", VEp = "vertical eye position, Eh / Bd",
           REs = "relative eye size, Ed / Hd", OGp = "oral gape position, Mo / Bd",
           RMl = "relative maxillary length, Jl / Hd", BLs = "body lateral shape, Hd / Bd",
           PFv = "pectoral fin vertical position, PFi / Bd", PFs = "pectoral fin size, PFl / Bl",
           CPt = "caudal peduncle throttling, CFd / CPd")
  seg <- c(Bl = "standard length (curvilinear when midline hinges are placed)",
           Bd = "body depth", Hd = "head depth", Eh = "eye position (height)",
           Mo = "mouth position (height)", PFi = "pectoral fin position (height)",
           PFl = "pectoral fin length", Ed = "eye diameter", Jl = "maxillary jaw length",
           CPd = "caudal peduncle depth", CFd = "caudal fin depth")
  rbind(
    v("specimen", "data/raw/*", "specimen code (one digitized configuration)"),
    v("landmark", "data/raw/landmarks.csv", "landmark number (FISHMORPH protocol: 1-19 anatomical, 20-21 scale bar, 22/24/25 midline hinges)"),
    v(c("X", "Y"), "data/raw/landmarks.csv", "landmark coordinates in the photograph (y pointing down)", "pixel"),
    v("species", "data/raw/landmarks_specimens.csv", "species name"),
    v("site", "data/raw/landmarks_specimens.csv", "sampling site"),
    v("date", "data/raw/landmarks_specimens.csv", "sampling date (YYYYMMDD)"),
    v("operator", "data/raw/landmarks_specimens.csv", "person who digitized the landmarks"),
    v(c("individual", "replicate"), "data/raw/repeats_specimens.csv", "repeated digitizations: fish digitized, and replicate number"),
    v(names(seg), "data/processed/fishmorph_segments.csv", unname(seg), "cm (pixel when scale_units = px)"),
    v("scale_units", "data/processed/fishmorph_segments.csv", "unit of the measurements of the specimen: cm, or px when the scale bar is missing"),
    v(names(rat), "data/processed/fishmorph_ratios.csv; traits_analysed.csv", unname(rat), "unitless"),
    v(c("n_measured", "n_complete", "n_analysed"), "Table1_sample", "specimens measured, with the 9 ratios, and analysed"),
    v(c("pct_interspecific", "pct_itv"), "Table6_itv_partition", "share of the variance between species / within species (ITV)", "%"),
    v(c("pct_itv_between_pop", "pct_itv_within_pop"), "Table6_itv_partition", "ITV split into between-site and within-site parts (when sites are nested)", "%"),
    v("cv_percent", "TableS1_cv_by_species_trait", "coefficient of variation of a ratio within a species", "%"),
    v("trait_variance", "Table4_trait_disparity", "trace of the covariance matrix of the log-transformed, standardised ratios of the species"),
    v(c("p_value", "p_holm"), "TableS4/TableS6", "permutation p-value of a pairwise difference, raw and Holm-adjusted"),
    v(c("volume", "proportion", "pct_global"), "Table5_fishmorph_space_occupancy", "convex-hull area on the first two FISHMORPH axes, and its share of the global hull", "%"),
    v("n_star", "Table7_itv_accumulation", "number of individuals needed for a precise estimate of within-species variability"),
    v("procrustes_variance", "Table9_shape_disparity", "Procrustes variance of the species"),
    v(c("pct_ME", "R"), "TableS7_repeatability_segments", "percent measurement error and repeatability of a measurement")
  )
}

#' Write an analysis as a reproducible project (paper architecture)
#'
#' Writes a folder organised like the repository of a published paper --
#' `scripts/` numbered (`00_START`, `01_DATA`, `02_ANALYSIS`, `03_FIGURE`,
#' `04_SUPP`, `05_STAT`), `utils/`, `data/raw` and `data/processed`,
#' `results/figures` and `results/tables`, `manuscript/`, `run_all.R`,
#' `README.md`, an RStudio project and `.gitignore` -- then RUNS it: the
#' tables, figures and the Methods & Results report (`manuscript/
#' Methods_Results.docx`) are produced by the project's own scripts, in a
#' separate R process, from the raw landmarks written in `data/raw`. What the
#' archive contains is therefore exactly what running it again gives.
#'
#' @param landmarks An `"intrait_landmarks"` object (coordinates in pixels,
#'   metadata with at least `species`; `site`, `date`, `operator`, `source`
#'   used when present), e.g. from [read_landmarks_xlsx()]. May be `NULL`
#'   when `literature` is given (the analyses based on landmarks -- shape,
#'   measurement error -- are then left out).
#' @param dir Folder to create (its name is the project name). Must not exist
#'   or be empty.
#' @param params Analysis parameters, see [analysis_params()].
#' @param literature Optional individual trait records without photographs
#'   (published data sets): a data.frame with `species`, the nine FISHMORPH
#'   ratios and optionally `specimen_code`, `site`, `date`, `study_id`. They
#'   enter every analysis based on the ratios, with the provenance
#'   `"literature"`; written in `data/raw/traits_literature.csv`.
#' @param repeats Optional `"intrait_landmarks"` object of repeated
#'   digitizations (metadata `individual`, `operator`, `replicate`), for the
#'   measurement-error script.
#' @param title,author Title of the project and author(s), written in the
#'   README, the script headers and the report.
#' @param run Run the project (`run_all.R`) after writing it.
#' @param zip Zip the folder (`<dir>.zip`, next to it).
#' @param quiet No progress messages.
#' @return A list: `dir`, `zip` (path or `NULL`), `log` (the run log),
#'   `ok` (`TRUE` when the run completed), `error` (message, when it did not).
#' @seealso [launch_intrait_analyses()], [analysis_params()]
#' @examples
#' \dontrun{
#' lm <- read_landmarks_xlsx("landmarks.xlsx", sheet = "measurements",
#'                           n_landmarks = 25, id_cols = "specimen")
#' res <- write_analysis_project(lm, "~/Desktop/T26_morphology",
#'                               params = analysis_params(min_n = 10),
#'                               title = "Morphology of the T26 fishes",
#'                               author = "A. Toussaint")
#' res$zip
#' }
#' @export
write_analysis_project <- function(landmarks, dir, params = analysis_params(),
                                   repeats = NULL, literature = NULL,
                                   title = "Morphological analyses",
                                   author = "", run = TRUE, zip = TRUE, quiet = FALSE) {
  if (!is.null(landmarks) && dim(landmarks$coords)[3] == 0) landmarks <- NULL
  if (!is.null(landmarks) && !inherits(landmarks, "intrait_landmarks"))
    stop("`landmarks` must be an \"intrait_landmarks\" object.", call. = FALSE)
  if (!is.null(literature) && !nrow(literature)) literature <- NULL
  if (is.null(landmarks) && is.null(literature))
    stop("Nothing to analyse: give `landmarks` and/or `literature`.", call. = FALSE)
  if (dir.exists(dir) && length(list.files(dir, all.files = TRUE, no.. = TRUE)))
    stop("`dir` exists and is not empty: ", dir, call. = FALSE)
  params <- do.call(analysis_params, params)
  say <- function(...) if (!quiet) message(...)
  tpl <- system.file("templates", "analysis_project", package = "intraitR")
  if (!nzchar(tpl)) stop("Templates not found in the intraitR installation.", call. = FALSE)

  project <- basename(normalizePath(dir, mustWork = FALSE))
  for (d in c("scripts", "utils", "data/raw", "data/processed", "results/figures",
              "results/tables", "manuscript"))
    dir.create(file.path(dir, d), recursive = TRUE, showWarnings = FALSE)

  # --- data/raw ---------------------------------------------------------------
  has_lm <- !is.null(landmarks)
  if (has_lm) {
    tb <- .ana_landmarks_tables(landmarks)
    utils::write.csv(tb$long, file.path(dir, "data/raw/landmarks.csv"), row.names = FALSE, na = "")
    utils::write.csv(tb$meta, file.path(dir, "data/raw/landmarks_specimens.csv"), row.names = FALSE, na = "")
  }
  has_lit <- !is.null(literature)
  if (has_lit) {
    lit <- .ana_bind_literature(NULL, literature)
    utils::write.csv(lit[, setdiff(names(lit), "source")],
                     file.path(dir, "data/raw/traits_literature.csv"), row.names = FALSE, na = "")
  }
  if (!has_lm) params$shape <- FALSE
  has_rep <- !is.null(repeats) && has_lm
  if (has_rep) {
    rt <- .ana_landmarks_tables(repeats)
    utils::write.csv(rt$long, file.path(dir, "data/raw/repeats.csv"), row.names = FALSE, na = "")
    utils::write.csv(rt$meta, file.path(dir, "data/raw/repeats_specimens.csv"), row.names = FALSE, na = "")
  }
  utils::write.csv(.ana_metadata(), file.path(dir, "data/metadata.csv"), row.names = FALSE)

  # --- scripts ----------------------------------------------------------------
  scripts <- c("00_START_GeneralScript.R", "01_DATA_load_and_clean.R",
               "02_ANALYSIS_traits_by_species.R", "03_FIGURE_trait_space.R",
               "03_FIGURE_fishmorph_projection.R", "03_FIGURE_itv.R",
               "03_FIGURE_itv_accumulation.R",
               if (isTRUE(params$shape)) "03_FIGURE_shape_space.R",
               if (has_rep) "04_SUPP_repeatability.R",
               "05_STAT_trait_disparity.R",
               if (isTRUE(params$shape)) "05_STAT_shape_disparity.R")
  cran <- c("rmarkdown", "knitr", if (isTRUE(params$shape)) "geomorph")
  vals <- list(
    TITLE = title, AUTHOR = if (nzchar(author)) author else "[author]",
    DATE = format(Sys.Date(), "%Y-%m-%d"), PROJECT = project,
    INTRAITR_VERSION = as.character(utils::packageVersion("intraitR")),
    RFISHMORPH_VERSION = tryCatch(as.character(utils::packageVersion("Rfishmorph")),
                                  error = function(e) "?"),
    CRAN_PACKAGES = paste0('"', cran, '"', collapse = ", "),
    N_SPECIMENS = format((if (has_lm) dim(landmarks$coords)[3] else 0) +
                           (if (has_lit) nrow(literature) else 0), big.mark = ","),
    N_SPECIES = length(unique(stats::na.omit(c(if (has_lm) tb$meta$species, if (has_lit) lit$species)))),
    SCRIPT_TREE = paste(sprintf("\u2502   \u251c\u2500\u2500 %-34s # %s", scripts, .ANA_SCRIPT_DESC[scripts]),
                        collapse = "\n"),
    REPEATS_SENTENCE = paste(
      if (has_rep) "`data/raw/repeats.csv` and `repeats_specimens.csv` hold the repeated digitizations used to estimate measurement error." else "",
      if (has_lit) "`data/raw/traits_literature.csv` holds individual trait records taken from the literature (no photograph): the nine ratios as published, with the study they come from (`study_id`)." else "",
      if (!has_lm) "There are no landmark data: only the analyses based on the ratios are run." else ""))
  cp <- function(from, to) {
    txt <- readLines(file.path(tpl, from), warn = FALSE, encoding = "UTF-8")
    writeLines(enc2utf8(.ana_fill(txt, vals)), file.path(dir, to), useBytes = TRUE)
  }
  for (s in c(scripts, "setup_environment.R")) cp(file.path("scripts", s), file.path("scripts", s))
  cp("utils/library.R", "utils/library.R")
  file.copy(file.path(tpl, "utils/functions.R"), file.path(dir, "utils/functions.R"))
  writeLines(.ana_parameters_r(params), file.path(dir, "utils/parameters.R"))
  cp("run_all.R", "run_all.R")
  cp("README.md", "README.md")
  cp("manuscript/Methods_Results.Rmd", "manuscript/Methods_Results.Rmd")
  file.copy(file.path(tpl, "manuscript", c("references.bib", "ecology-letters.csl")),
            file.path(dir, "manuscript"))
  # named rproj.txt in the package: .Rbuildignore drops every *.Rproj
  file.copy(file.path(tpl, "rproj.txt"), file.path(dir, paste0(project, ".Rproj")))
  file.copy(file.path(tpl, "gitignore.txt"), file.path(dir, ".gitignore"))

  # --- versions -------------------------------------------------------------------
  pk <- c("intraitR", "Rfishmorph", "geomorph", "rmarkdown", "knitr")
  writeLines(c(paste("Project:", title), paste("Written:", format(Sys.time(), "%Y-%m-%d %H:%M %Z")), "",
               paste("R", paste(R.version$major, R.version$minor, sep = "."), "--", R.version$platform),
               vapply(pk, function(x) sprintf("%-12s %s", x,
                 tryCatch(as.character(utils::packageVersion(x)), error = function(e) "not installed")),
                 character(1))),
             file.path(dir, "session_info.txt"))

  out <- list(dir = normalizePath(dir), zip = NULL, log = NULL, ok = NA, error = NULL)

  # --- run the project's own scripts ----------------------------------------------
  if (run) {
    if (!requireNamespace("callr", quietly = TRUE))
      stop("Running the project needs the 'callr' package: install.packages(\"callr\").",
           call. = FALSE)
    log <- file.path(out$dir, "results", "run_all.log")
    say("Running the project's scripts (run_all.R)...")
    res <- tryCatch({
      callr::r(function(d) { setwd(d); source("run_all.R", local = new.env()) },
               args = list(d = out$dir), stdout = log, stderr = "2>&1",
               libpath = .libPaths())
      TRUE
    }, error = function(e) e)
    out$log <- log
    out$ok <- isTRUE(res)
    if (!out$ok) {
      tail_log <- tryCatch(utils::tail(readLines(log, warn = FALSE), 15), error = function(e) "")
      out$error <- paste(c(conditionMessage(res), tail_log), collapse = "\n")
      if (!quiet) warning("The project did not run to the end:\n", out$error, call. = FALSE)
    }
  }

  # --- zip ------------------------------------------------------------------------
  if (zip) {
    zf <- paste0(out$dir, ".zip")
    if (file.exists(zf)) unlink(zf)
    old <- setwd(dirname(out$dir)); on.exit(setwd(old), add = TRUE)
    files <- list.files(project, recursive = TRUE, all.files = TRUE, full.names = TRUE)
    if (requireNamespace("zip", quietly = TRUE)) zip::zip(zf, files) else
      utils::zip(zf, files, flags = "-r9Xq")
    out$zip <- zf
    say("Project archive: ", zf)
  }
  out
}

# --- reading a digitizer workbook, every landmark up to 25 -------------------
# The hinges of a curved specimen (22, 24, 25) are found BY POSITION in the
# coordinate array (.fishmorph_pixel_segments), so the array must have one row
# per landmark number, 1 to the largest present, the absent ones (23, the
# derived head base, is often not exported) left NA. Reading only 1-22, as the
# hub's trait table did, silently drops hinges 24 and 25 and shortens Bl.
.ana_read_workbook <- function(path, sheet = "measurements", max_landmark = 25L) {
  if (!requireNamespace("readxl", quietly = TRUE))
    stop("Reading a workbook needs the 'readxl' package.", call. = FALSE)
  wb <- as.data.frame(readxl::read_excel(path, sheet = sheet, guess_max = 10000),
                      stringsAsFactors = FALSE)
  xc <- grep("^[0-9]+_X$", names(wb), value = TRUE)
  idx <- sort(as.integer(sub("_X$", "", xc)))
  idx <- idx[idx >= 1L & idx <= max_landmark & paste0(idx, "_Y") %in% names(wb)]
  if (!length(idx)) stop("No landmark column (1_X, 1_Y, ...) in sheet '", sheet, "'.",
                         call. = FALSE)
  spec <- if (!is.null(wb$specimen)) as.character(wb$specimen) else
    if (all(c("individual", "replicate") %in% names(wb)))
      paste(wb$individual, wb$operator %||% "", paste0("rep", wb$replicate), sep = "_") else
      as.character(seq_len(nrow(wb)))
  keep <- !is.na(spec) & nzchar(spec) & !duplicated(spec)
  wb <- wb[keep, , drop = FALSE]; spec <- spec[keep]
  p <- max(idx)
  A <- array(NA_real_, dim = c(p, 2L, length(spec)),
             dimnames = list(as.character(seq_len(p)), c("X", "Y"), spec))
  num <- function(v) suppressWarnings(as.numeric(v))
  for (i in idx) {
    A[i, 1, ] <- num(wb[[paste0(i, "_X")]])
    A[i, 2, ] <- num(wb[[paste0(i, "_Y")]])
  }
  coord_cols <- grepl("^[0-9]+_[XY]$", names(wb))
  meta <- wb[, !coord_cols, drop = FALSE]
  meta[] <- lapply(meta, function(v) if (is.list(v)) vapply(v, function(z) paste(z, collapse = ";"), "") else
    as.character(v))
  meta$specimen <- spec
  meta <- meta[, c("specimen", setdiff(names(meta), "specimen")), drop = FALSE]
  rownames(meta) <- spec
  structure(list(coords = A, scale = NULL, metadata = meta), class = "intrait_landmarks")
}

.ANA_RATIOS <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")

# What scripts/01_DATA_load_and_clean.R computes, for the app's live views.
# The SAME steps in the same order; tests/testthat/test-analysis_project.R
# checks that the analysed sample is identical to the script's.
.ana_prepare <- function(lm, params, literature = NULL) {
  fish <- if (!is.null(lm) && dim(lm$coords)[3] > 0) lm else NULL
  segments <- NULL; r <- NULL
  if (!is.null(fish)) {
    if (isTRUE(params$impute))      fish <- impute_landmarks(fish)
    if (isTRUE(params$orientation)) fish <- standardize_orientation(fish)
    if (isTRUE(params$geometry))    fish <- correct_geometry(fish)
    segments <- fishmorph_segments(fish, scale_cm = params$scale_cm,
                                   scale_action = params$scale_action)
    ratios <- fishmorph_ratios(segments, no_caudal_fin = params$no_caudal_fin,
                               ventral_mouth = params$ventral_mouth,
                               no_pectoral_fin = params$no_pectoral_fin)
    r <- as.data.frame(ratios)
    md <- fish$metadata
    src <- md$source %||% md$data_source
    src <- if (is.null(src)) rep(NA_character_, nrow(r)) else
      as.character(src)[match(r$specimen, md$specimen)]
    r$source <- ifelse(is.na(src) | !nzchar(src), "photographs", src)
    r$study_id <- NA_character_
  }
  r <- .ana_bind_literature(r, literature)
  if (is.null(r)) stop("Nothing to analyse: no landmarks and no literature record.", call. = FALSE)
  rat <- params$ratios %||% .ANA_RATIOS
  r$complete <- stats::complete.cases(r[, rat, drop = FALSE]) & !is.na(r$species) & nzchar(r$species)
  if (!is.null(params$species)) r$complete <- r$complete & r$species %in% params$species
  if (!is.null(params$sites) && !is.null(r$site)) r$complete <- r$complete & r$site %in% params$sites
  if (!is.null(params$sources)) r$complete <- r$complete & r$source %in% params$sources
  n_complete <- table(r$species[r$complete])
  kept <- sort(names(n_complete)[n_complete >= params$min_n])
  r$analysed <- r$complete & r$species %in% kept
  keep_cols <- intersect(c("specimen", "species", "site", "date", "source", "study_id", "scale_units"),
                         names(r))
  traits <- r[r$analysed, c(keep_cols, .ANA_RATIOS), drop = FALSE]
  rownames(traits) <- NULL
  list(fish = fish, segments = segments, ratios = r, traits = traits,
       x = traits[, rat, drop = FALSE], species = traits$species, kept_species = kept)
}

# Literature records (one row per individual, the nine ratios as published)
# appended to the photographs' ratios. The same code is in the project's
# 01_DATA script.
.ana_bind_literature <- function(r, literature) {
  if (is.null(literature) || !nrow(literature)) return(r)
  l <- as.data.frame(literature, stringsAsFactors = FALSE)
  n <- nrow(l)
  ch <- function(v) if (is.null(v)) rep(NA_character_, n) else as.character(v)
  out <- data.frame(specimen = ch(l$specimen_code %||% l$specimen), species = ch(l$species),
                    site = ch(l$site), date = ch(l$date), source = "literature",
                    study_id = ch(l$study_id), stringsAsFactors = FALSE)
  for (k in .ANA_RATIOS) out[[k]] <- suppressWarnings(as.numeric(l[[k]] %||% rep(NA_real_, n)))
  if (is.null(r)) return(out)
  cols <- unique(c(names(r), names(out)))
  fill <- function(d) { for (cc in setdiff(cols, names(d))) d[[cc]] <- NA; d[, cols, drop = FALSE] }
  rbind(fill(r), fill(out))
}

# Repeated digitizations: only the photographs digitized at least twice
# measure anything (a replicate variance needs two values), and
# digitization_error() refuses the whole set when one has a single pass.
# Returns the kept repeats (NULL when fewer than two photographs remain) and
# the identifiers dropped.
.ana_keep_replicated <- function(rep) {
  if (is.null(rep) || is.null(rep$metadata$individual)) return(list(rep = NULL, dropped = character(0)))
  ind <- as.character(rep$metadata$individual)
  n <- table(ind)
  ok <- names(n)[n >= 2]
  dropped <- names(n)[n < 2]
  keep <- ind %in% ok
  rep$coords <- rep$coords[, , keep, drop = FALSE]
  rep$metadata <- rep$metadata[keep, , drop = FALSE]
  list(rep = if (length(ok) >= 2) rep else NULL, dropped = dropped, n_ok = length(ok))
}

#' Read a workbook of the digitizer, every landmark included
#'
#' Reads a sheet of the workbook written by [digitize_landmarks()] (or rebuilt
#' by [consolidate_landmarks()]) into an `"intrait_landmarks"` object, with
#' one row of the coordinate array per landmark NUMBER, from 1 to the largest
#' present (up to 25): the hinges 22, 24 and 25 of curved specimens are found
#' by their position, so that [fishmorph_segments()] measures standard length
#' along them; a landmark absent from the sheet (23, the derived head base,
#' often) is `NA`. Every other column of the sheet becomes metadata.
#'
#' @param path The workbook (`.xlsx`).
#' @param sheet `"measurements"` (default) or `"bias"` (repeated
#'   digitizations: the specimen identifier is then built from `individual`,
#'   `operator` and `replicate` when there is no `specimen` column).
#' @param max_landmark Largest landmark number read.
#' @return An `"intrait_landmarks"` object.
#' @seealso [fishmorph_segments()], [write_analysis_project()]
#' @examples
#' \dontrun{
#' fish <- read_digitizer_workbook("landmarks.xlsx")
#' rat  <- fishmorph_ratios(fishmorph_segments(fish, scale_cm = 1))
#' }
#' @export
read_digitizer_workbook <- function(path, sheet = "measurements", max_landmark = 25L) {
  if (!file.exists(path)) stop("Workbook not found: ", path, call. = FALSE)
  .ana_read_workbook(path, sheet = sheet, max_landmark = max_landmark)
}
