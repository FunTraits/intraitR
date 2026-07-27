## =============================================================================
## app.R -- Interactive predictor-assisted landmarking (intraitR)
##
## Workflow: a folder of photographs declared AT THE CONSOLE -> a handful of
## clicks per specimen (snout, hinges, caudal-fin basis, then the anatomical
## points) -> optionally the ml-morph shape predictor -> review and correction
## -> one append-only journal line per landmark, and one workbook.
##
## Launched from the package with intraitR::digitize_landmarks(), which
## validates the session, locates the ml-morph resources and hands everything
## over through the `intraitR.digitizer` option (see CFG below) plus the
## INTRAITR_MLMORPH_* environment variables, then calls shiny::runApp() on this
## folder. The app also runs standalone with
## shiny::runApp("inst/shiny/landmarking_app"), in which case it falls back to
## the working directory and to paths relative to a parent "ml_morph" folder.
##
## THREE QUEUES, switchable from the action bar (argument `mode`):
##   new     : photographs not yet in the workbook          -> measurements sheet
##   correct : specimens already digitized, points reloaded -> measurements sheet
##   repeat  : the same photograph digitized n times        -> bias sheet
##
## PERSISTENCE, in two layers with different jobs:
##   * the JOURNAL (one TSV per session, append-only, one line per landmark) is
##     the source of truth. It is written FIRST, at every save, and never
##     rewritten -- a crash costs at most the specimen in hand.
##   * the WORKBOOK is an export, rewritten in full every `xlsx_flush_every`
##     records and atomically (temporary file + rename). Losing it costs
##     nothing: intraitR::consolidate_landmarks() rebuilds it from the journals.
##
## Requires: a Python environment (.venv_mlmorph) with dlib/opencv, a trained
## predictor (mlmorph_run_*/predictor.dat) and the aligned training set
## (mlmorph_dataset_aligned) inside the ml-morph directory, for the OPTIONAL
## prediction step. See ml_morph/README.md.
##
## R dependencies: shiny, jpeg, png, writexl (readxl to resume from a workbook;
## magick for images whose real format does not match their extension; bslib
## for the themed interface -- all optional, the app degrades gracefully).
## =============================================================================

library(shiny)

## shiny's %||% is not exported by every version this app may run under.
`%||%` <- function(x, y) if (is.null(x)) y else x

## ---- Session configuration --------------------------------------------------
## Handed over by intraitR::digitize_landmarks() in ONE option rather than a
## dozen environment variables: runApp() evaluates this file in the SAME R
## process as the launcher, so the option is simply visible from here. The
## defaults keep the app runnable standalone, for development.
CFG <- local({
  d <- getOption("intraitR.digitizer", NULL)
  if (!is.list(d)) d <- list()
  def <- list(
    photo_dir = getwd(), photos = character(0),
    xlsx_path = file.path(getwd(), "intraitR_landmarks.xlsx"),
    journal_dir = file.path(getwd(), "landmark_journal"),
    operator = NULL, mode = "new", n_repeats = 3L, ruler_mm = 10,
    xlsx_flush_every = 10L, sheet_measurements = "measurements",
    sheet_bias = "bias", sheet_summary = "bias_summary", app_version = "dev")
  for (nm in names(def)) if (is.null(d[[nm]])) d[[nm]] <- def[[nm]]
  if (!length(d$photos) && dir.exists(d$photo_dir))
    d$photos <- sort(list.files(d$photo_dir, full.names = TRUE,
                                ignore.case = TRUE,
                                pattern = "\\.(jpe?g|png|gif|bmp|tiff?)$"))
  d
})
OPERATOR <- local({
  o <- CFG$operator
  if (is.null(o) || !nzchar(o))
    tryCatch(unname(Sys.info()[["user"]]), error = function(e) "unknown") else o
})
## Codes of the queue, in the order of the photographs: the file name without
## its extension IS the specimen code, here and in the workbook.
PHOTO_CODES <- tools::file_path_sans_ext(basename(CFG$photos))

## The package supplies the journal and the atomic workbook write. Required:
## without them a save would have nowhere durable to go, and running on
## degraded persistence is exactly what this app must not do.
if (!requireNamespace("intraitR", quietly = TRUE))
  stop("The intraitR package must be installed and loadable: the app writes ",
       "through intraitR::landmark_journal_append() and ",
       "intraitR::write_xlsx_atomic().", call. = FALSE)

## ---- Resource paths (absolute, robust to the sub-process working directory) --
## Resolved by intraitR::digitize_landmarks() through the INTRAITR_MLMORPH_*
## environment variables; otherwise (standalone launch) relative to the parent
## "ml_morph" folder.
ML <- {
  d <- Sys.getenv("INTRAITR_MLMORPH_DIR", "")                # set by the launcher
  if (!nzchar(d)) d <- normalizePath("..", mustWork = FALSE)  # else ml_morph folder
  d
}
## Python interpreter: INTRAITR_MLMORPH_PY (launcher), then PY, then
## ~/.venv_mlmorph (outside any cloud-synced folder), then the local venv, then
## python3 on the search path.
.py_cand  <- c(Sys.getenv("INTRAITR_MLMORPH_PY", ""), Sys.getenv("PY", ""),
               path.expand("~/.venv_mlmorph/bin/python"),
               file.path(ML, ".venv_mlmorph", "bin", "python"))
PY        <- c(.py_cand[nzchar(.py_cand) & file.exists(.py_cand)], "python3")[1]
## Python worker: the copy bundled in the package (passed by the launcher through
## INTRAITR_MLMORPH_WORKER) takes precedence over the one in the ml-morph folder.
WORKER <- {
  w <- Sys.getenv("INTRAITR_MLMORPH_WORKER", "")
  if (!nzchar(w) || !file.exists(w)) w <- file.path(ML, "predict_new_image.py")
  w
}
DATASET   <- file.path(ML, "mlmorph_dataset_aligned")
## Available predictors (selected in the UI): an explicit path handed to the
## launcher (argument `predictor=`, via INTRAITR_MLMORPH_PREDICTOR) first, then
## those discovered in the ml-morph folder.
PRED_CHOICES <- {
  ex <- Sys.getenv("INTRAITR_MLMORPH_PREDICTOR", "")
  Filter(file.exists, c(
    if (nzchar(ex)) c(supplied = ex),
    app     = file.path(ML, "mlmorph_run_app",     "predictor.dat"),
    aligned = file.path(ML, "mlmorph_run_aligned", "predictor.dat")))
}

## ---- Landmark scheme --------------------------------------------------------
## 1-19  anatomical FISHMORPH landmarks (Brosse et al. 2021)
## 20-21 scale bar (a known real-world distance, `scale_mm`) -> mm_per_px
## 22    OPTIONAL body-curvature point on the midline. It is a genuine landmark:
##       fishmorph_segments() splits the standard length into (1-22) + (22-2)
##       when it is present, so a fish photographed with a bent body is not
##       under-measured. Exported like any other point.
## 23-24 EXTRA HINGES. Entry aids: they extend the broken axis to up to four
##       segments for strongly curved specimens, so that the FISHMORPH
##       perpendicularity conventions are applied segment by segment instead of
##       against a single straight axis. They are NOT anatomical landmarks and
##       have no place in a shape analysis -- but they ARE recorded, because
##       they define the frames every convention was applied in: without them a
##       specimen reopened for correction comes back with a straight axis and
##       the geometry silently stops matching the one it was digitized under.
N_ANAT    <- 19L
SCALE_PTS <- c(20L, 21L)
CURVE_PT  <- 22L                       # a genuine landmark (Bl curvature correction)
EXTRA_HINGES <- c(23L, 24L)            # entry aids: recorded, never analysed
HINGES    <- c(CURVE_PT, EXTRA_HINGES) # every point that can break the axis
## Two lists, because "recorded" and "is a landmark" are not the same statement:
##   SAVE_PTS : the landmarks proper (1-22) -- what a TPS file and any shape
##              analysis may contain.
##   WB_PTS   : everything written to the workbook and the journal, hinges
##              included. Reading the sheet for an analysis therefore means
##              taking the first 22 points, not every column that ends in _X.
SAVE_PTS  <- 1:22
WB_PTS    <- c(SAVE_PTS, EXTRA_HINGES)
N_TOT     <- 24L                       # rows carried in the coordinate matrix

## Automatically placed landmarks (not corrected by hand).
##  - standard mode: 1, 2 (clicks) + 8, 9, 11 (geometrically derived)
##  - "pin" mode: 3, 4, 7, 10, 12, 15, 16, 18 are pinned on the calibration
##    clicks as well, so they also become automatic (the auto-advance skips them).
AUTO_LM     <- c(1L, 2L, 8L, 9L, 11L)
AUTO_LM_PIN <- c(1L, 2L, 3L, 4L, 7L, 8L, 9L, 10L, 11L, 12L, 15L, 16L, 18L)
## Points whose position is computed, never measured.
DERIVED_LM  <- c(8L, 9L, 11L)

## Anatomical points in ANATOMICAL order, minus the three derived ones -- not in
## numeric order, which the FISHMORPH numbering does not follow. The sequence
## walks the specimen the way the eye does, and groups the points that are read
## against one another:
##
##   3, 4       maximum body depth, dorsal then ventral (the Bd pair)
##   7, 5, 6    eye height, then the head-depth pair -- all three on the head
##   13, 14     eye diameter, once the head frame is set
##   15         jaw tip, read against the snout
##   10, 12     pectoral fin: insertion then tip
##   16, 17, 18, 19  caudal peduncle, then caudal fin
##
## Placing an isolated point far from the one before it costs a saccade and a
## re-zoom each time; a path that stays in one region until it is finished does
## not. This is also the order the button bar shows, so what is read and what is
## entered are the same sequence.
ANAT_ORDER <- c(3L, 4L, 7L, 5L, 6L, 13L, 14L, 15L, 10L, 12L,
                16L, 17L, 18L, 19L)
stopifnot(setequal(ANAT_ORDER, setdiff(3:19, DERIVED_LM)))

## ONE auto-advance sequence, from the axis to the scale bar. There is no
## separate calibration list: every point is an ordinary landmark, and the ones
## the predictor needs (LM1, LM2, the dorsal point LM3, the scale bar) are
## simply the ones that come first.
##
##   1 -> 22 -> 23 -> 2 -> 3, 4, 7, 5, 6, 13, 14, 15, 10, 12, 16..19 -> 20 -> 21
##
## The axis comes FIRST and complete: snout, the two hinges, caudal basis. Every
## convention downstream is expressed in the frame of a body segment, so
## defining the axis last would mean laying out every other point against the
## wrong reference. On a straight fish the hinges go anywhere along the midline:
## a hinge on the line leaves the chain straight, and LM22 then also gives
## fishmorph_segments() its curvature correction for free.
##
## Then the anatomical landmarks in the anatomical order above, and finally the
## scale bar. The three derived points (8, 9, 11) are the only ones skipped: they
## are computed from LM1, LM7, LM10 and LM4, so stopping on them would invite a
## click that the next derivation immediately undoes. They stay reachable from
## the button bar. LM24, the spare hinge, is likewise on demand only.
ADVANCE_ORDER <- c(1L, CURVE_PT, EXTRA_HINGES[1], 2L, ANAT_ORDER, SCALE_PTS)

## Next landmark after `cur` in that sequence (wraps around).
next_point <- function(cur) {
  i <- match(cur, ADVANCE_ORDER)
  if (is.na(i)) return(ADVANCE_ORDER[1])
  ADVANCE_ORDER[if (i >= length(ADVANCE_ORDER)) 1L else i + 1L]
}
## An empty coordinate matrix: the app always has one, from the moment a
## photograph is loaded, so the landmark bar is usable straight away.
empty_coords <- function() {
  matrix(NA_real_, N_TOT, 2, dimnames = list(seq_len(N_TOT), c("X", "Y")))
}

## Anatomical landmarks the worker FREEZES on the operator's clicks, and which
## therefore stay measurements after a prediction. In pin mode that is the whole
## pinned battery; otherwise only the snout and the caudal basis -- LM3 is an
## orientation hint there and IS re-predicted, so it must not keep the status of
## a hand-placed point. (20-21 are outside the model's range and never touched.)
PINNED_CLICKS <- c(1L, 2L, 3L, 4L, 7L, 10L, 12L, 15L, 16L, 18L)
pinned_clicks <- function(pin) if (isTRUE(pin)) PINNED_CLICKS else c(1L, 2L)

## Human-readable role of a point, for the status line and the click prompts.
point_label <- function(i) {
  switch(as.character(i),
    "1"  = "LM1 -- snout",
    "2"  = "LM2 -- caudal-fin basis",
    "3"  = "LM3 -- dorsal point (top of the body; orients dorsal side up)",
    "20" = "LM20 -- scale mark A",
    "21" = "LM21 -- scale mark B",
    "22" = "LM22 -- curvature point on the midline (exported)",
    "23" = "LM23 -- hinge (entry aid, not exported)",
    "24" = "LM24 -- hinge (entry aid, not exported)",
    paste0("LM", i))
}

## ---- Repeated digitization (measurement error / operator bias) --------------
## In "repeat" mode the SAME photograph is digitized several times and each pass
## is saved under an identifier of its own, so that measurement_error() and
## operator_disagreement() have replicate configurations to partition variance
## over. The identifier follows the convention already used by the T-26
## repeatability set (load_t26_saudrune_landmarks(source = "repeatability")):
##
##   <code>_rep<N>              one operator, N-th digitization
##   <code>_<operator>_rep<N>   several operators sharing one table
##
## The replicate number is always the LAST underscore-separated token, so an
## identifier is parsed unambiguously from the right; the operator label is
## sanitized to hold no underscore, which keeps the token before "rep" readable
## as the operator. read_mlmorph_landmarks(replicate = "parse", operator =
## "parse") reverses the construction.
REP_RE <- "_rep([0-9]+)$"

## Strip an underscore, whitespace or anything else that would make the operator
## token ambiguous when the identifier is parsed back.
clean_operator <- function(op) {
  op <- trimws(as.character(op %||% ""))
  if (!nzchar(op)) return("")
  gsub("[^A-Za-z0-9.-]+", "-", op)
}
## Build the saved identifier. `rep_n = NULL` gives the plain code (standard
## mode); otherwise the operator token and the _rep<N> suffix are appended.
make_id <- function(code, operator = "", rep_n = NULL) {
  code <- trimws(as.character(code %||% ""))
  if (!nzchar(code)) code <- "specimen"
  if (is.null(rep_n) || !is.finite(rep_n)) return(code)
  # A code reloaded from a measurement table may already carry a suffix; rebuild
  # it rather than nesting "_rep2_rep3".
  code <- sub(REP_RE, "", code)
  op <- clean_operator(operator)
  paste0(code, if (nzchar(op)) paste0("_", op) else "", "_rep", as.integer(rep_n))
}
## The physical individual behind a saved identifier: drop the _rep<N> suffix
## and, when one is present, the operator token before it. Identifiers with no
## suffix (standard mode) are returned unchanged, so the same helper serves the
## progress display and the "skip to the next unsaved photograph" logic.
base_code <- function(id, operator = "") {
  id <- as.character(id)
  has <- grepl(REP_RE, id)
  out <- sub(REP_RE, "", id)
  op <- clean_operator(operator)
  # `x[i] <- character(0)` is an error in R, so the empty case is guarded rather
  # than left to the vectorized assignment.
  if (nzchar(op) && any(has)) {
    tok <- paste0("_", op, "$")
    out[has] <- sub(tok, "", out[has])
  }
  out
}
## Replicate number carried by an identifier (NA when it carries none).
rep_of <- function(id) {
  id <- as.character(id)
  out <- rep(NA_integer_, length(id))
  hit <- grepl(REP_RE, id)
  if (!any(hit)) return(out)
  out[hit] <- as.integer(sub(paste0("^.*", REP_RE), "\\1", id[hit]))
  out
}

## ---- The workbook: one file, three sheets -----------------------------------
## `measurements` and `bias` share the WIDE FISHMORPH layout -- one row per
## digitization, "1_X, 1_Y, ... 22_X, 22_Y" -- which is what
## read_landmarks_xlsx(x_pattern = "{i}_X", y_pattern = "{i}_Y") reads back and
## what the published FISHMORPH tables use. What a wide table cannot carry, the
## per-point status, is kept twice over: as counts here (n_seeded, n_predicted,
## ...) and point by point in the journal.
WB_ID_COLS <- c("specimen", "individual", "replicate", "operator", "mode",
                "photo_file", "img_w", "img_h", "quality", "ruler_mm",
                "mm_per_px", "n_clicked", "n_seeded", "n_predicted",
                "n_adjusted", "n_na", "app_version", "timestamp")
WB_COORD_COLS <- as.vector(rbind(paste0(WB_PTS, "_X"), paste0(WB_PTS, "_Y")))
WB_COLS <- c(WB_ID_COLS, WB_COORD_COLS)

WB_CHR_COLS <- c("specimen", "individual", "operator", "mode", "photo_file",
                 "app_version", "timestamp")
wb_empty <- function() {
  d <- data.frame(matrix(nrow = 0, ncol = 0))
  for (cc in WB_COLS)
    d[[cc]] <- if (cc %in% WB_CHR_COLS) character(0) else numeric(0)
  d
}
## Bring a sheet read from disk up to the current schema: missing columns added
## as NA, unknown columns dropped, order fixed. A workbook written by an earlier
## version therefore reopens instead of erroring.
wb_normalise <- function(d) {
  if (is.null(d) || !nrow(d)) return(wb_empty())
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  for (cc in setdiff(WB_COLS, names(d))) d[[cc]] <- NA
  d <- d[, WB_COLS, drop = FALSE]
  for (cc in WB_CHR_COLS) d[[cc]] <- as.character(d[[cc]])
  for (cc in setdiff(WB_COLS, WB_CHR_COLS))
    d[[cc]] <- suppressWarnings(as.numeric(d[[cc]]))
  rownames(d) <- NULL
  d
}
wb_read_sheet <- function(path, sheet) {
  if (!file.exists(path) || !requireNamespace("readxl", quietly = TRUE))
    return(wb_empty())
  nms <- tryCatch(readxl::excel_sheets(path), error = function(e) character(0))
  if (!sheet %in% nms) return(wb_empty())
  d <- tryCatch(as.data.frame(readxl::read_excel(path, sheet = sheet,
                                                 .name_repair = "minimal"),
                              stringsAsFactors = FALSE),
                error = function(e) NULL)
  wb_normalise(d)
}

## ---- bias_summary: where the protocol is imprecise --------------------------
## For each individual and each landmark, the distance from every repeat to the
## MEAN position of that landmark over the individual's repeats, summarised by
## its median. Reported in pixels and, more usefully, as a percentage of the
## standard length (Bl = 1-2) of the same individual: pixels are not comparable
## between a 900 px and a 4000 px photograph, so the percentage is the only
## figure that can be read across a batch. The "(all)" block gives, per
## landmark, the median of the per-individual medians -- the one number that
## says which points the protocol places reproducibly and which it does not.
##
## Deliberately not an %ME: that requires a Procrustes fit and a model
## (measurement_error(), operator_disagreement()), which belong in R and not in
## a digitizing loop. This is the descriptive view that can be read while the
## session is still open, and which tells the operator whether to keep going.
bias_summary <- function(bias_df, points = 1:22) {
  if (is.null(bias_df) || !nrow(bias_df)) {
    out <- data.frame(individual = character(0), landmark = integer(0),
                      n_replicates = integer(0), median_dev_px = numeric(0),
                      median_dev_pct_bl = numeric(0), max_dev_px = numeric(0),
                      stringsAsFactors = FALSE)
    return(out)
  }
  ind <- bias_df$individual
  ind[is.na(ind) | !nzchar(ind)] <- bias_df$specimen[is.na(ind) | !nzchar(ind)]
  per <- lapply(split(seq_len(nrow(bias_df)), ind), function(idx) {
    d <- bias_df[idx, , drop = FALSE]
    if (nrow(d) < 2L) return(NULL)          # a single pass says nothing
    # Standard length of this individual, averaged over its repeats: the size
    # reference the deviations are expressed against.
    bl <- sqrt((d[["1_X"]] - d[["2_X"]])^2 + (d[["1_Y"]] - d[["2_Y"]])^2)
    bl <- suppressWarnings(mean(bl[is.finite(bl)]))
    rows <- lapply(points, function(p) {
      x <- suppressWarnings(as.numeric(d[[paste0(p, "_X")]]))
      y <- suppressWarnings(as.numeric(d[[paste0(p, "_Y")]]))
      ok <- is.finite(x) & is.finite(y)
      if (sum(ok) < 2L) return(NULL)
      dev <- sqrt((x[ok] - mean(x[ok]))^2 + (y[ok] - mean(y[ok]))^2)
      data.frame(landmark = p, n_replicates = sum(ok),
                 median_dev_px = stats::median(dev),
                 median_dev_pct_bl = if (is.finite(bl) && bl > 0)
                   100 * stats::median(dev) / bl else NA_real_,
                 max_dev_px = max(dev), stringsAsFactors = FALSE)
    })
    rows <- rows[!vapply(rows, is.null, logical(1))]
    if (!length(rows)) return(NULL)
    do.call(rbind, rows)
  })
  per <- per[!vapply(per, is.null, logical(1))]
  if (!length(per)) return(bias_summary(NULL))
  out <- do.call(rbind, lapply(names(per), function(k)
    cbind(individual = k, per[[k]], stringsAsFactors = FALSE)))
  # per-landmark overview across individuals, first in the sheet
  ov <- do.call(rbind, lapply(split(out, out$landmark), function(d)
    data.frame(individual = "(all)", landmark = d$landmark[1],
               n_replicates = sum(d$n_replicates),
               median_dev_px = stats::median(d$median_dev_px),
               median_dev_pct_bl = suppressWarnings(
                 stats::median(d$median_dev_pct_bl, na.rm = TRUE)),
               max_dev_px = max(d$max_dev_px), stringsAsFactors = FALSE)))
  out <- rbind(ov[order(ov$landmark), , drop = FALSE],
               out[order(out$individual, out$landmark), , drop = FALSE])
  rownames(out) <- NULL
  out
}

## FISHMORPH segments, for the on-screen control table. Same battery as
## fishmorph_segments(): standard length, body depth, head depth, eye position,
## mouth height, pectoral-fin position and length, eye diameter, jaw length,
## caudal-peduncle and caudal-fin depth.
SEG_PAIRS <- list(Bl  = c(1L, 2L),   Bd  = c(3L, 4L),   Hd  = c(5L, 6L),
                  Eh  = c(7L, 8L),   Mo  = c(1L, 9L),   PFi = c(10L, 11L),
                  PFl = c(10L, 12L), Ed  = c(13L, 14L), Jl  = c(1L, 15L),
                  CPd = c(16L, 17L), CFd = c(18L, 19L))

## =============================================================================
## Geometry
## =============================================================================

## Is row `i` of P a usable coordinate pair?
fin_row <- function(P, i) {
  i <- suppressWarnings(as.integer(i))
  !is.na(i) && i >= 1L && i <= nrow(P) && all(is.finite(P[i, ]))
}

## Body axis, robust to missing points: LM1 -> LM2 when both are present,
## otherwise the first principal component of the available anatomical
## landmarks (1..17). Returns the origin, the unit axis and the body length.
body_axis <- function(P) {
  a <- P["1", ]; b <- P["2", ]
  idx <- intersect(as.character(1:17), rownames(P))
  M <- P[idx, , drop = FALSE]; M <- M[stats::complete.cases(M), , drop = FALSE]
  if (all(is.finite(a)) && all(is.finite(b)) && sum((b - a)^2) > 0) {
    o <- a; u <- (b - a) / sqrt(sum((b - a)^2))
  } else {
    if (nrow(M) < 2) return(NULL)
    o <- colMeans(M); u <- eigen(stats::cov(M))$vectors[, 1]
    ref <- if (all(is.finite(b))) b - o else if (all(is.finite(a))) o - a else c(1, 0)
    if (sum(u * ref) < 0) u <- -u        # orient head -> tail
  }
  len <- if (nrow(M) >= 2)
    diff(range(as.vector((M - matrix(o, nrow(M), 2, byrow = TRUE)) %*% u)))
    else sqrt(sum((b - a)^2))
  list(o = o, u = u, len = len)
}

## Ordered chain of the BROKEN AXIS: 1, then the hinges actually placed (sorted
## by their position along the 1->2 chord), then 2. With no hinge placed this is
## simply c(1, 2) and every downstream computation reduces to the straight axis.
axis_chain <- function(P) {
  hs <- HINGES[vapply(HINGES, function(i) fin_row(P, i), logical(1))]
  if (length(hs) > 1L && fin_row(P, 1L) && fin_row(P, 2L)) {
    uc <- P[2L, ] - P[1L, ]
    hs <- hs[order(vapply(hs, function(i) sum((P[i, ] - P[1L, ]) * uc), numeric(1)))]
  }
  c(1L, hs, 2L)
}

## Curvilinear length (px) along the broken axis: the sum of its segments. This
## is the quantity fishmorph_segments() calls Bl once landmark 22 is present.
axis_len_px <- function(P) {
  ch <- axis_chain(P)
  if (!all(vapply(ch, function(i) fin_row(P, i), logical(1)))) return(NA_real_)
  sum(vapply(seq_len(length(ch) - 1L),
             function(k) sqrt(sum((P[ch[k + 1L], ] - P[ch[k], ])^2)), numeric(1)))
}

## Local orthonormal frame on a body segment: origin `o`, unit axial direction
## `o -> tip`, and the perpendicular (dorso-ventral) direction. `ax`/`pe` read
## the axial and perpendicular coordinates of a point, `at` rebuilds a point
## from them. `fallback` is the direction used if `o` and `tip` coincide.
make_frame <- function(o, tip, fallback) {
  d <- tip - o; L <- sqrt(sum(d^2))
  d <- if (is.finite(L) && L > 0) d / L else fallback
  n <- c(-d[2], d[1])
  list(o = o, u = d, n = n,
       ax = function(p) sum((p - o) * d),
       pe = function(p) sum((p - o) * n),
       at = function(a, b) o + a * d + b * n)
}

## Three frames along the broken axis, with graceful fallback to the straight
## 1->2 chord when the corresponding hinge has not been placed (so a straight
## fish behaves exactly as before hinges existed):
##   head = 1 -> hinge1   : mouth (1-9), eye vertical {5,13,7,14,6,8}
##   mid  = hinge1 -> hinge2 : body depth (3-4), pectoral fin (10-11, 10-12)
##   tail = hinge2 -> 2   : caudal peduncle (16-17), caudal fin (18-19)
seg_frames <- function(P) {
  ax <- body_axis(P); if (is.null(ax)) return(NULL)
  A <- if (fin_row(P, 1L)) P["1", ] else ax$o
  B <- if (fin_row(P, 2L)) P["2", ] else ax$o + ax$len * ax$u
  hs <- setdiff(axis_chain(P), c(1L, 2L))          # placed hinges, in order
  h1 <- if (length(hs) >= 1L) P[hs[1], ] else NULL
  h2 <- if (length(hs) >= 2L) P[hs[2], ] else NULL
  list(head = make_frame(A, if (!is.null(h1)) h1 else B, ax$u),
       mid  = make_frame(if (!is.null(h1)) h1 else A,
                         if (!is.null(h2)) h2 else B, ax$u),
       tail = make_frame(if (!is.null(h2)) h2 else if (!is.null(h1)) h1 else A,
                         B, ax$u),
       len  = ax$len)
}

## Enforce the DORSAL-TO-VENTRAL ORDER 5 > 13 > 7 > 14 > 6 > 8 along the vertical
## of LM7 (perpendicular to the head axis), with the eye SYMMETRIC about LM7 (its
## centre): dist(7,13) = dist(7,14) = h. Fixed anchors: 7 (measured) and 8
## (derived ventral point). 5, 13, 14 and 6 are projected on that vertical and
## their dorsal coordinate `t` (positive towards the back) is bounded:
##   5 dorsal (t >= +m); 6 ventral, between 8 and 7; 13 = +h; 14 = -h,
##   h = the observed eye half-height, capped so 13 stays below 5 and 14 above 6.
## m is a small margin (0.5 % of the body length) that keeps points distinct.
enforce_head_order <- function(P, fr, len) {
  if (!all(is.finite(P["7", ]))) return(P)
  a7 <- fr$ax(P["7", ]); p7 <- fr$pe(P["7", ])
  up <- if (all(is.finite(c(P["5", ], P["6", ])))) sign(fr$pe(P["5", ]) - fr$pe(P["6", ]))
        else if (all(is.finite(c(P["3", ], P["4", ])))) sign(fr$pe(P["3", ]) - fr$pe(P["4", ]))
        else 1
  if (up == 0) up <- 1
  m   <- max(1e-6, 0.005 * len)
  tof <- function(q) up * (fr$pe(P[q, ]) - p7)      # dorsal coordinate of q
  put <- function(t) fr$at(a7, p7 + up * t)         # place on the vertical of 7
  t8 <- if (all(is.finite(P["8", ]))) tof("8") else NA_real_
  # 6: ventral (t <= -m) and above 8 (t >= t8 + m)
  if (all(is.finite(P["6", ]))) {
    t6 <- min(tof("6"), -m); if (is.finite(t8)) t6 <- max(t6, t8 + m)
    P["6", ] <- put(t6)
  }
  # 5: dorsal (t >= +m)
  if (all(is.finite(P["5", ]))) P["5", ] <- put(max(tof("5"), m))
  t5 <- if (all(is.finite(P["5", ]))) tof("5") else NA_real_
  t6 <- if (all(is.finite(P["6", ]))) tof("6") else NA_real_
  # 13 (upper) and 14 (lower) SYMMETRIC about 7: same distance h. h is the mean
  # observed half-height, capped so that 13 stays below 5 (h <= t5 - m) and 14
  # above 6 (h <= -t6 - m).
  d13 <- if (all(is.finite(P["13", ]))) abs(tof("13")) else NA_real_
  d14 <- if (all(is.finite(P["14", ]))) abs(tof("14")) else NA_real_
  hobs <- mean(c(d13, d14), na.rm = TRUE)
  if (is.finite(hobs)) {
    hmax <- Inf
    if (is.finite(t5)) hmax <- min(hmax, t5 - m)        # 13 below 5
    if (is.finite(t6)) hmax <- min(hmax, -t6 - m)       # 14 above 6 (t6 < 0)
    h <- min(max(hobs, m), max(hmax, m))                # bounded in [m, hmax]
    if (all(is.finite(P["13", ]))) P["13", ] <- put( h)
    if (all(is.finite(P["14", ]))) P["14", ] <- put(-h)
  }
  P
}

## Belly line, BROKEN at LM11 (the pectoral-fin insertion is where the ventral
## profile changes segment):
##   mid segment  : 11 aligned on 4    -> line 11-4 parallel to the mid axis
##   head segment : 8 and 9 aligned on 11 -> line 9-8-11 parallel to the head axis
## Only the perpendicular coordinate (the height) is transferred; each point
## keeps its axial coordinate, so it stays on the perpendicular dropped from its
## dorsal partner.
belly_align <- function(P, fr, pivot, movers) {
  if (!fin_row(P, pivot)) return(P)
  b <- fr$pe(P[pivot, ])
  for (m in movers) if (m != pivot && fin_row(P, m))
    P[m, ] <- fr$at(fr$ax(P[m, ]), b)
  P
}

## Ventral DERIVED points 8, 9, 11: on the belly line, on the perpendicular
## dropped from LM7, LM1 and LM10 respectively. Chain of dependence: 4 -> 11
## (mid frame), then 11 -> 8, 9 (head frame). LM4 is the MASTER of the belly
## line: it is the only ventral point of the battery that is actually measured
## (the ventral end of the body-depth segment), so it defines the height the
## others inherit. Moving 8, 9 or 11 by hand is therefore only meaningful with
## "Auto constraints" switched off -- otherwise the next derivation overrides it.
## ORDER MATTERS: abscissas first, heights second. Setting an abscissa moves the
## point in space, which on a curved specimen changes its coordinate in the
## OTHER segment's frame -- so fixing 11 onto 10 after propagating heights from
## 11 pulls 8 and 9 off the belly line (measured at 9.8 px on a fish bent 35
## degrees). belly_align() only ever touches the perpendicular coordinate, so
## running it second leaves the abscissas intact.
derive_ventral <- function(P, fr) {
  if (fin_row(P, 1L)  && fin_row(P, 9L))
    P["9", ]  <- fr$head$at(fr$head$ax(P["1", ]),  fr$head$pe(P["9", ]))
  if (fin_row(P, 7L)  && fin_row(P, 8L))
    P["8", ]  <- fr$head$at(fr$head$ax(P["7", ]),  fr$head$pe(P["8", ]))
  if (fin_row(P, 10L) && fin_row(P, 11L))
    P["11", ] <- fr$mid$at(fr$mid$ax(P["10", ]),   fr$mid$pe(P["11", ]))
  P <- belly_align(P, fr$mid, 4L, 11L)                    # 11 <- 4  (mid frame)
  belly_align(P, fr$head, if (fin_row(P, 11L)) 11L else 9L, c(8L, 9L))
}

## Keep the caudal peduncle (16-17) parallel to the caudal fin (18-19): the
## segment that was NOT moved is rotated onto the direction of the one that was.
## Deliberately frame-free -- the caudal reference is the pair itself, which
## stays valid on a bent specimen.
enforce_caudal <- function(P, moved) {
  s <- as.character(moved)
  if (!all(is.finite(c(P["16", ], P["17", ], P["18", ], P["19", ])))) return(P)
  if (s %in% c("16", "17")) {
    d <- P["17", ] - P["16", ]; d <- d / sqrt(sum(d^2))
    m <- (P["18", ] + P["19", ]) / 2; L <- sqrt(sum((P["19", ] - P["18", ])^2))
    P["18", ] <- m - d * L / 2; P["19", ] <- m + d * L / 2
  }
  if (s %in% c("18", "19")) {
    d <- P["19", ] - P["18", ]; d <- d / sqrt(sum(d^2))
    m <- (P["16", ] + P["17", ]) / 2; L <- sqrt(sum((P["17", ] - P["16", ])^2))
    P["16", ] <- m - d * L / 2; P["17", ] <- m + d * L / 2
  }
  P
}

## =============================================================================
## Extreme-point convention: LM3 the most DORSAL, LM4 the most VENTRAL
## =============================================================================
## FISHMORPH defines Bd as the MAXIMUM body depth, so LM3 must be the most
## dorsal and LM4 the most ventral point of the body outline. A head top (LM5)
## above LM3, or a belly point (LM11) below LM4, silently under-measures Bd --
## an error no per-pair convention catches, since each pair is internally
## consistent. Checked when the specimen is saved.
##
## EXCLUDED from the comparison:
##   8, 9, 11 DERIVED ventral points. They are computed FROM LM4 (belly line),
##          so testing whether LM4 is the lowest point against them is circular.
##          Measured on the 1,036 digitized T-26 specimens, including them
##          flags 20.6 % of the batch -- 198 of those 213 flags are 8, 9 or 11,
##          at a median overshoot of 0.5 % of Bl, i.e. belly-line noise, not a
##          Bd error. Excluding them leaves 1.5 % flagged (16 specimens), 12 of
##          which are the LM5-above-LM3 case, at a median overshoot of 7.8 % of
##          Bl. The flag rate is then flat from 0.003 to 0.02 Bl, so what is
##          left is gross error cleanly separated from noise, not a threshold
##          artefact;
##   16-19  caudal peduncle and fin: outside the body outline by definition,
##          and routinely deeper than Bd;
##   12, 15 pectoral-fin and jaw tips: appendages, which legitimately overshoot
##          the outline (and, being the belly master's neighbours, would drag
##          the whole ventral line down if LM4 were snapped onto them);
##   20-21  scale bar; 22-24 midline curvature point and hinges.
## Compared with 3/4, therefore: 1, 2, 5, 6, 7, 10, 13, 14 -- every landmark
## that is an independent MEASUREMENT on the body outline.
EXTREME_EXCLUDE <- c(8L, 9L, 11L, 12L, 15L, 16L, 17L, 18L, 19L,
                     20L, 21L, 22L, 23L, 24L)
EXTREME_CAND    <- setdiff(seq_len(N_TOT), c(3L, 4L, EXTREME_EXCLUDE))

## Tolerance, as a FRACTION of body length: below 0.003 of Bl (3 px on a
## 1000 px fish) the discrepancy is click noise, not a digitizing error.
EXTREME_TOL <- 0.003
## Absolute FLOOR, in pixels. On a small photograph the relative tolerance falls
## below click noise (0.003 * 600 px = 1.8 px) and a 2 px overshoot would raise
## the alert -- noise, not an error. Set to 5 px on the T-26 data: compliant
## specimens top out at -0.4 px of overshoot (p98) while the smallest REAL
## breach is 11.8 px. Anywhere between a 1 px and an 8 px floor the count of
## flagged specimens is unchanged (16): the band is empty, so 5 px sits in the
## middle of it and costs no detection.
EXTREME_FLOOR <- 5

## Which body segment each point is measured in -- the same assignment
## propagate_conventions() uses, so a bent specimen is read segment by segment
## instead of against one straight axis. Heights are then local body
## half-depths, which is what makes them comparable across the fish.
EXTREME_FRAME <- list(head = c(1L, 5L, 6L, 7L, 8L, 9L, 13L, 14L),
                      mid  = c(3L, 4L, 10L, 11L, 12L),
                      tail = c(2L, 16L, 17L, 18L, 19L))
frame_of <- function(i, fr) {
  if (i %in% EXTREME_FRAME$mid)  return(fr$mid)
  if (i %in% EXTREME_FRAME$tail) return(fr$tail)
  fr$head
}

## Signed DORSAL height of each point: its perpendicular coordinate in its own
## segment frame, oriented so that "greater = more dorsal". The dorsal side is
## read off the relative position of LM3 and LM4 rather than assumed from the
## image, so the test holds whatever the orientation -- head left or right,
## flipped photograph, "Flip dorsal / ventral" ticked.
dorsal_heights <- function(P) {
  fr <- seg_frames(P); if (is.null(fr)) return(NULL)
  if (!fin_row(P, 3L) || !fin_row(P, 4L)) return(NULL)
  sgn <- sign(fr$mid$pe(P["3", ]) - fr$mid$pe(P["4", ]))
  if (sgn == 0) return(NULL)                       # 3 and 4 at the same height
  h <- rep(NA_real_, nrow(P))
  for (i in seq_len(nrow(P)))
    if (fin_row(P, i)) h[i] <- sgn * frame_of(i, fr)$pe(P[i, ])
  list(fr = fr, sgn = sgn, h = h, len = fr$len)
}

## Violations of the convention. NULL when the specimen is compliant, otherwise
## a data.frame: `point` (3 or 4), `culprit` (the point overshooting it),
## `delta` (the overshoot, in pixels).
extreme_violations <- function(P, tol_frac = EXTREME_TOL) {
  g <- dorsal_heights(P); if (is.null(g)) return(NULL)
  if (!is.finite(g$len) || g$len <= 0) return(NULL)
  tol  <- max(EXTREME_FLOOR, tol_frac * g$len)
  cand <- EXTREME_CAND[is.finite(g$h[EXTREME_CAND])]
  if (!length(cand)) return(NULL)
  out <- list()
  d <- g$h[cand] - g$h[3L]                          # dorsal overshoot
  k <- which.max(d)
  if (d[k] > tol) out[[length(out) + 1L]] <-
    data.frame(point = 3L, culprit = cand[k], delta = unname(d[k]))
  d <- g$h[4L] - g$h[cand]                          # ventral overshoot
  k <- which.max(d)
  if (d[k] > tol) out[[length(out) + 1L]] <-
    data.frame(point = 4L, culprit = cand[k], delta = unname(d[k]))
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}

## Correction: LM3 (resp. LM4) takes the HEIGHT of the point overshooting it,
## keeping its own position along the axis. Bd therefore grows, and the "3-4
## perpendicular to the axis" convention is preserved. No other point is moved
## here; the belly line is re-derived by the caller through
## propagate_conventions() when the auto constraints are on.
fix_extremes <- function(P, viol) {
  g <- dorsal_heights(P); if (is.null(g)) return(P)
  for (r in seq_len(nrow(viol))) {
    i <- viol$point[r]; j <- viol$culprit[r]
    if (!fin_row(P, i) || !is.finite(g$h[j])) next
    f <- frame_of(i, g$fr)
    P[i, ] <- f$at(f$ax(P[i, ]), g$sgn * g$h[j])
  }
  P
}

## Propagate the FISHMORPH conventions after landmark `sel` has been moved.
## Each convention is applied in the frame of the body segment it belongs to,
## so a curved specimen with hinges placed is handled correctly; with no hinge
## the three frames collapse onto the straight 1-2 axis.
propagate_conventions <- function(P, sel) {
  fr <- seg_frames(P); if (is.null(fr)) return(P)
  s <- as.character(sel)
  # (1) perpendicular pairs: the partner keeps its height, takes the mover's abscissa
  for (pr in list(list(p = c("1", "9"),   f = fr$head),
                  list(p = c("3", "4"),   f = fr$mid),
                  list(p = c("10", "11"), f = fr$mid)))
    if (s %in% pr$p) {
      oth <- setdiff(pr$p, s)
      if (all(is.finite(P[oth, ])))
        P[oth, ] <- pr$f$at(pr$f$ax(P[s, ]), pr$f$pe(P[oth, ]))
    }
  # (2) caudal parallelism
  P <- enforce_caudal(P, sel)
  # (3) belly line and derived ventral points, recomputed from their anchors.
  #     Unconditional: moving LM4 (the master), LM1, LM7 or LM10 -- or a hinge,
  #     which redefines the frames themselves -- all shift the derived points.
  P <- derive_ventral(P, fr)
  # (4) head vertical order, re-imposed as soon as a head point moves
  if (s %in% c("7", "5", "6", "13", "14"))
    P <- enforce_head_order(P, fr$head, fr$len)
  P
}

## =============================================================================
## Seeding a whole configuration from the axis
## =============================================================================

## MEDIAN FISHMORPH proportions, segment / standard length. Computed over the
## FISHMORPH database (n = 6,492 to 7,706 species depending on the segment;
## only strictly positive values retained). They are a SEED and nothing more:
## once the axis 1 -> 22 -> 23 -> 2 is placed, every remaining landmark is put
## at the median proportion of the body so the operator repositions points
## rather than placing them from nothing. A point left at its seed has been
## measured on no specimen -- which is why it carries the status "seeded" and
## is reported separately when the specimen is saved.
FM_MEDIAN_RATIOS <- c(Bd = 0.2480, Hd = 0.1382, Eh = 0.1372, Mo = 0.1152,
                      PFi = 0.0745, PFl = 0.1829, Ed = 0.0589, Jl = 0.0559,
                      CPd = 0.1055, CFd = 0.2593)

## Free parameters the segment ratios do not determine: where along the body a
## segment sits (f_*), how it splits dorsal/ventral (o_*), and the angle of the
## pectoral fin and the jaw. Defaults are the medians of the digitized FISHMORPH
## species. o_PF is negative because the pectoral insertion lies below the
## midline.
SEED_DEFAULTS <- list(f_Bd = 0.47, o_Bd = 0.50, f_Hd = 0.10, o_Hd = 0.43,
                      f_eye = 0.10, o_eye = 0.82, f_PF = 0.25, o_PF = -0.69,
                      ang_PFl = 35, ang_Jl = 20, f_CP = 0.93, o_CP = 0.52,
                      f_CF = 1.15, o_CF = 0.47)

## Point and local frame at arc-length fraction `f` of the broken axis. `f` may
## fall outside [0, 1] (the caudal fin sits past LM2, f_CF = 1.15), in which
## case the first or last segment is extrapolated. Working in arc length rather
## than along the straight chord is what makes the seed follow a curved body.
chain_at <- function(P, f) {
  ch <- axis_chain(P)
  if (!all(vapply(ch, function(i) fin_row(P, i), logical(1)))) return(NULL)
  pts <- P[ch, , drop = FALSE]
  d <- pts[-1, , drop = FALSE] - pts[-nrow(pts), , drop = FALSE]
  seglen <- sqrt(rowSums(d^2))
  L <- sum(seglen)
  if (!is.finite(L) || L <= 0) return(NULL)
  t <- f * L
  k <- 1L; acc <- 0
  while (k < length(seglen) && acc + seglen[k] < t) { acc <- acc + seglen[k]; k <- k + 1L }
  u <- d[k, ] / seglen[k]
  list(p = as.numeric(pts[k, ] + (t - acc) * u), u = as.numeric(u),
       n = c(-u[2], u[1]), L = L)
}

## Fill every anatomical landmark from the median proportions, then apply the
## FISHMORPH conventions so the seeded configuration is already coherent.
## `keep` lists the points that must NOT be overwritten -- everything the
## operator has placed by hand, marked NA, or that defines the axis.
seed_configuration <- function(P, params = list(), flip_dorsal = FALSE,
                               keep = integer(0)) {
  mid <- chain_at(P, 0.5); if (is.null(mid)) return(P)
  L <- mid$L
  p <- utils::modifyList(SEED_DEFAULTS, params)
  r <- function(nm) as.numeric(FM_MEDIAN_RATIOS[[nm]])
  # Which side is dorsal? The normal is always u rotated the same way, so one
  # sign settles it for the whole chain. Default to the top of the image (Y
  # grows downward); LM3 is the dorsal point and overrides that when present.
  sgn <- if (mid$n[2] > 0) -1 else 1
  if (fin_row(P, 3L)) {
    d <- sum((P[3, ] - mid$p) * (mid$n * sgn))
    if (is.finite(d) && d < 0) sgn <- -sgn
  }
  if (isTRUE(flip_dorsal)) sgn <- -sgn
  frame_at <- function(f) {
    A <- chain_at(P, f)
    list(p = A$p, u = A$u, up = A$n * sgn)
  }
  cm  <- function(x) x * L
  set <- function(i, xy) { if (!(i %in% keep)) P[i, ] <<- xy; invisible() }
  vseg <- function(f, ratio, o) {
    A <- frame_at(f)
    list(top = A$p + cm(ratio) * o * A$up,
         bot = A$p - cm(ratio) * (1 - o) * A$up)
  }
  rot <- function(ang, A) cos(-ang * pi / 180) * A$u + sin(-ang * pi / 180) * A$up

  v <- vseg(p$f_Bd, r("Bd"), p$o_Bd); set(3L, v$top);  set(4L, v$bot)
  v <- vseg(p$f_Hd, r("Hd"), p$o_Hd); set(5L, v$top);  set(6L, v$bot)
  A <- frame_at(p$f_eye)                       # eye vertical, ventral end first
  set(8L, A$p - cm(r("Hd")) * p$o_eye * A$up)
  if (fin_row(P, 8L)) set(7L, P[8L, ] + cm(r("Eh")) * A$up)
  if (fin_row(P, 7L)) {                        # eye symmetric about its centre
    set(13L, P[7L, ] + cm(r("Ed") / 2) * A$up)
    set(14L, P[7L, ] - cm(r("Ed") / 2) * A$up)
  }
  A1 <- frame_at(0)
  set(9L, P[1L, ] - cm(r("Mo")) * A1$up)
  v <- vseg(p$f_PF, r("PFi"), p$o_PF); set(10L, v$top); set(11L, v$bot)
  Apf <- frame_at(p$f_PF)
  if (fin_row(P, 10L)) set(12L, P[10L, ] + cm(r("PFl")) * rot(p$ang_PFl, Apf))
  set(15L, P[1L, ] + cm(r("Jl")) * rot(p$ang_Jl, A1))
  v <- vseg(p$f_CP, r("CPd"), p$o_CP); set(16L, v$top); set(17L, v$bot)
  v <- vseg(p$f_CF, r("CFd"), p$o_CF); set(18L, v$top); set(19L, v$bot)
  apply_conventions(P)
}

## Propagate the conventions from the PINNED anchors to the dependent points, in
## absolute coordinates. Used right after a prediction in "pin" mode, when 1, 2,
## 3, 4, 7, 10, 12, 15, 16 and 18 sit on the operator's clicks.
apply_conventions <- function(P) {
  fr <- seg_frames(P); if (is.null(fr)) return(P)
  # LM4 on the perpendicular of LM3, keeping its ventral height
  if (fin_row(P, 3L) && fin_row(P, 4L))
    P["4", ] <- fr$mid$at(fr$mid$ax(P["3", ]), fr$mid$pe(P["4", ]))
  P <- derive_ventral(P, fr)
  enforce_head_order(P, fr$head, fr$len)
}

## =============================================================================
## Image input / output
## =============================================================================

## ROBUST image reader. File extensions lie often enough to matter (a fair share
## of ".jpg" files in specimen archives are in fact PNG, GIF or BMP), so the real
## format is detected from the magic bytes and routed to the right reader.
## JPEG/PNG go through jpeg/png (fast); anything else goes through magick, which
## re-encodes to a temporary PNG rather than reshaping the array by hand (the
## classic source of "striped" images).
read_image <- function(path) {
  sig <- tryCatch(readBin(path, "raw", n = 8L), error = function(e) raw(0))
  is_jpeg <- length(sig) >= 2 && sig[1] == as.raw(0xFF) && sig[2] == as.raw(0xD8)
  is_png  <- length(sig) >= 8 &&
    all(sig[1:8] == as.raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)))
  if (is_jpeg && requireNamespace("jpeg", quietly = TRUE)) return(jpeg::readJPEG(path))
  if (is_png  && requireNamespace("png",  quietly = TRUE)) return(png::readPNG(path))
  if (requireNamespace("magick", quietly = TRUE) &&
      requireNamespace("png", quietly = TRUE)) {
    im  <- magick::image_read(path)
    tmp <- tempfile(fileext = ".png"); on.exit(unlink(tmp), add = TRUE)
    magick::image_write(im, tmp, format = "png")
    return(png::readPNG(tmp))
  }
  out <- tryCatch(jpeg::readJPEG(path), error = function(e)
           tryCatch(png::readPNG(path), error = function(e2) NULL))
  if (is.null(out))
    stop("Unreadable image format (the real format of ", basename(path),
         " differs from its extension). Install the 'magick' package.",
         call. = FALSE)
  out
}

## Sub-sampling for DISPLAY only: coordinates stay in original pixels, since
## rasterImage() stretches the image back onto the same rv$w x rv$h box.
downscale <- function(a, maxdim = 1600L) {
  d <- dim(a); if (max(d[1], d[2]) <= maxdim) return(a)
  st <- ceiling(max(d[1], d[2]) / maxdim)
  ri <- seq(1L, d[1], by = st); ci <- seq(1L, d[2], by = st)
  if (length(d) == 3) a[ri, ci, , drop = FALSE] else a[ri, ci, drop = FALSE]
}

## Flip an image array horizontally / vertically / both.
flip_array <- function(a, mode) {
  d <- dim(a); H <- d[1]; W <- d[2]
  if (length(d) == 3) {
    if (grepl("h", mode)) a <- a[, W:1, , drop = FALSE]
    if (grepl("v", mode)) a <- a[H:1, , , drop = FALSE]
  } else {
    if (grepl("h", mode)) a <- a[, W:1, drop = FALSE]
    if (grepl("v", mode)) a <- a[H:1, , drop = FALSE]
  }
  a
}

## =============================================================================
## UI
##
## The side panel is a TABSET, not a scroll. The controls fall into groups that
## are touched at different rhythms -- once per specimen (identity, quality),
## once per repeatability batch, once per photograph (flips, guides), once per
## session (the seeding sliders, the extreme-point check) -- and stacking them
## in one column made the ones used constantly sit below the ones used never.
## Tabs put each rhythm one click away and leave the photograph the full width.
##
## With bslib installed the page uses a Bootstrap 5 theme; without it, the same
## content is laid out with the standard Shiny sidebar. No feature depends on
## bslib: only the appearance does.
## =============================================================================
HAS_BSLIB <- requireNamespace("bslib", quietly = TRUE) &&
  utils::packageVersion("bslib") >= "0.5.0"

APP_CSS <- paste0(
  # the action bars are single rows: kill the form-group margins the selectize
  # and the checkboxes would otherwise add
  ".actionbar .form-group{margin-bottom:0;}",
  ".actionbar .btn{margin-right:4px;}",
  ".actionbar .selectize-control{margin-bottom:0;}",
  ".phasebar .form-group{margin-bottom:0;}",
  ".phasebar .checkbox{margin:0;}",
  # a denser side panel: the tabs already separate the groups, so the vertical
  # rhythm inside a tab can be tighter than Bootstrap's default
  ".sidetabs .tab-content{padding-top:10px;}",
  ".sidetabs .form-group{margin-bottom:10px;}",
  ".sidetabs .shiny-input-container{width:100% !important;}",
  ".sidetabs .irs{margin-bottom:0;}",
  ".sidetabs .help-block{font-size:11.5px;line-height:1.35;color:#6b7280;}",
  ".sidetabs .nav-link{padding:5px 9px;font-size:12.5px;}",
  # the header strip: what the session IS, always visible, never in the way
  ".sessionbar{font-size:12px;color:#6b7280;padding:2px 0 8px 0;",
  "border-bottom:1px solid #e5e7eb;margin-bottom:10px;}",
  ".sessionbar code{font-size:11.5px;color:#374151;background:#f3f4f6;",
  "padding:1px 5px;border-radius:4px;}",
  ".progressbox{background:#f8fafc;border:1px solid #e5e7eb;border-radius:8px;",
  "padding:8px 10px;font-size:13px;line-height:1.5;}",
  ".statusline{font-size:12px;}",
  # The landmark bar is the app's real navigation. One flex row, never wrapped:
  # the buttons share the available width (flex:1 1 0) and shrink together, so a
  # given landmark keeps its position on the screen whatever the window size.
  # overflow-x is a floor, not a plan: below ~700 px the row scrolls rather than
  # collapsing the digits.
  ".lmrow{display:flex;flex-wrap:nowrap;gap:3px;align-items:stretch;",
  "overflow-x:auto;margin-bottom:6px;padding-bottom:2px;}",
  ".lmrow .lmbtn{flex:1 1 0;min-width:30px;padding:7px 0;font-size:14px;",
  "line-height:1.1;text-align:center;border:1px solid #ccc;border-radius:6px;",
  "cursor:pointer;}",
  ".lmbar .btn{margin:2px 2px 0 0;padding:2px 7px;font-size:12px;",
  "border-radius:6px;}",
  # a floor under the photograph: a plot device narrower than this cannot draw
  # anything useful, and a collapsed one cannot draw at all
  "#img{min-width:360px;min-height:360px;}",
  # the queue selector heads the side panel: boxed, so it reads as the state of
  # the session rather than as one more control
  ".modebar{background:#f8fafc;border:1px solid #e5e7eb;border-radius:8px;",
  "padding:6px 10px 0 10px;margin-bottom:10px;}",
  ".modebar .form-group{margin-bottom:4px;}",
  ".modebar .control-label{font-size:12px;color:#6b7280;margin-bottom:2px;}",
  # the title. A system stack rather than a web font: it renders identically
  # offline, which a field session may well be, and matches the platform.
  ".app-title{font-family:'Inter','SF Pro Display','Segoe UI Variable',",
  "'Helvetica Neue',system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;",
  "letter-spacing:-0.015em;}",
  ".app-title-name{font-weight:800;}",
  ".app-title-sub{font-weight:600;opacity:0.62;}",
  # Mark NA is destructive-ish and pressed with the eye on the photograph: give
  # it a colour of its own so it is never hit for 'Clear point'
  "#set_na{font-weight:600;}")

## Right-button drag on the photograph pans the view (deltas sent to Shiny).
PAN_JS <- paste(
  "(function(){var dg=false,lx=0,ly=0,adx=0,ady=0,c=0,raf=null;",
  "function el(){return document.getElementById('img');}",
  "function flush(){raf=null;if(adx===0&&ady===0)return;Shiny.setInputValue('pan',{dx:adx,dy:ady,n:++c},{priority:'event'});adx=0;ady=0;}",
  "document.addEventListener('contextmenu',function(e){var m=el();if(m&&m.contains(e.target))e.preventDefault();});",
  "document.addEventListener('mousedown',function(e){var m=el();if(m&&m.contains(e.target)&&e.button===2){dg=true;lx=e.clientX;ly=e.clientY;e.preventDefault();}});",
  "document.addEventListener('mousemove',function(e){if(!dg)return;var m=el();if(!m)return;var r=m.getBoundingClientRect();adx+=(e.clientX-lx)/r.width;ady+=(e.clientY-ly)/r.height;lx=e.clientX;ly=e.clientY;if(!raf)raf=requestAnimationFrame(flush);});",
  "document.addEventListener('mouseup',function(e){if(e.button===2){dg=false;if(!raf)raf=requestAnimationFrame(flush);}});",
  "})();", sep = "\n")

## A card when bslib is available, a bordered div otherwise. Used for the two
## panels under the photograph, which read better boxed than free-floating.
## A card when bslib is available, a bordered div otherwise. `fill = FALSE` on
## purpose: a filling card inside a flex column negotiates its height with its
## siblings, and the plot above it loses the argument -- which is how a 700 px
## photograph ends up in a device too small for its own margins.
card_box <- function(title, ...) {
  if (HAS_BSLIB)
    bslib::card(bslib::card_header(title), bslib::card_body(..., gap = "6px"),
                fill = FALSE)
  else
    div(class = "well", style = "padding:10px;", tags$strong(title), ...)
}

## ---- side panel: one tab per rhythm of use ----------------------------------
side_tabs <- function() {
  tabsetPanel(
    id = "sidetab", type = if (HAS_BSLIB) "pills" else "tabs",

    tabPanel(
      "Specimen",
      textInput("specimen_id", "Specimen code", ""),
      radioButtons("quality", "Quality score (1 = very good -> 5 = poor)",
                   choices = c("1" = 1, "2" = 2, "3" = 3, "4" = 4, "5" = 5),
                   selected = 3, inline = TRUE),
      numericInput("scale_mm", "Scale bar 20-21: real length (mm)",
                   CFG$ruler_mm, min = 0),
      helpText("Optional. Place 20 and 21 at the two ends of the reference:",
               "mm_per_px = real length / their distance in pixels. Left",
               "unplaced, mm_per_px stays NA and the coordinates stay in pixels."),
      if (length(PRED_CHOICES))
        selectInput("pred", "Predictor model", choices = PRED_CHOICES)
      else div(class = "text-danger", style = "font-size:12px;",
               "No predictor.dat found: the prediction step is disabled."),
      checkboxInput("pin", "Pin the reliable landmarks (LM1,2,3,4,7) on the clicks",
                    value = FALSE),
      tags$hr(),
      # --- how the next click is interpreted -----------------------------------
      # Set once and left alone for a whole batch, so they belong here rather
      # than in a bar the eye crosses on every point.
      tags$strong("Click behaviour"),
      checkboxInput("move_all", "Move the whole block (on click)", FALSE),
      helpText("The click translates the entire configuration instead of the",
               "active landmark -- for re-framing a whole set at once."),
      checkboxInput("auto_constraints",
                    "Auto constraints (adapt the other points)", TRUE),
      helpText("Moving a landmark propagates the FISHMORPH conventions to the",
               "points that depend on it: the 3-4 segment stays perpendicular",
               "to the body axis, the eye group on one vertical, the ventral",
               "group on one line. Unticked, each point moves alone."),
      tags$hr(),
      tags$strong("This specimen"),
      div(class = "actionbar", style = "margin-top:6px;",
          downloadButton("dl_csv", "CSV"), downloadButton("dl_tps", "TPS")),
      helpText("A side export of the configuration on screen. The session's",
               "real output is the workbook and the journal.")),

    tabPanel(
      "Repeats",
      uiOutput("rep_info"),
      numericInput("rep_target", "Repeats per individual", CFG$n_repeats,
                   min = 2, step = 1),
      numericInput("rep_i", "Current repeat", 1, min = 1, step = 1),
      checkboxInput("rep_blind",
                    "Blind repeat (clear the landmarks after each save)",
                    value = TRUE),
      helpText("Active in mode 'repeat'. The same photograph is digitized",
               "several times and each pass is saved to the bias sheet as",
               "individual + operator + replicate. Keep the repeats BLIND: a",
               "pass started from the previous configuration measures how",
               "little the operator moved the points, not how reproducibly",
               "they place them, and collapses %ME towards zero."),
      tags$hr(),
      tags$strong("Bias so far"),
      tableOutput("bias_tab"),
      helpText("Median distance of the repeats to their own mean position, per",
               "landmark, as a percentage of standard length. Written in full",
               "to the bias_summary sheet.")),

    tabPanel(
      "Display",
      checkboxInput("showlines", "Reference lines (outline / belly / eye)", TRUE),
      checkboxInput("guides", "Alignment guides", FALSE),
      checkboxInput("fishguides", "FISHMORPH geometry check", FALSE),
      radioButtons("flip_mode", "Flip photograph (+ landmarks)",
                   c("None" = "none", "Horizontal" = "h", "Vertical" = "v",
                     "180" = "hv"), inline = TRUE),
      radioButtons("flip_disp", "Flip the photograph ONLY (landmarks fixed)",
                   c("None" = "none", "Horizontal" = "h", "Vertical" = "v",
                     "180" = "hv"), inline = TRUE),
      helpText("The first option moves the landmarks with the image, so points",
               "already placed stay on the specimen. The second changes the",
               "display only -- useful when reloaded points are mirrored",
               "relative to the photograph. It persists between photographs.")),

    tabPanel(
      "Checks",
      checkboxInput("check_extremes",
                    "Check LM3 / LM4 (extremes) on save", value = TRUE),
      helpText("Bd is the MAXIMUM body depth: on save, checks that LM3 is the",
               "most dorsal and LM4 the most ventral landmark of the body",
               "outline. Heights are taken perpendicular to the body axis,",
               "segment by segment, so posture is not flagged. Excluded: the",
               "caudal peduncle and fin (16-19), the appendage tips (12, 15)",
               "and the derived ventral points (8, 9, 11). On a breach, offers",
               "to measure again or to correct automatically."),
      tags$hr(),
      tags$strong("Workbook"),
      verbatimTextOutput("saved_info"),
      div(class = "actionbar",
          actionButton("flush", "Write the workbook now", class = "btn-primary"),
          actionButton("rebuild", "Rebuild from the journal")),
      helpText("The workbook is written every", CFG$xlsx_flush_every,
               "record(s), atomically. The journal is written at every save and",
               "is the source of truth: 'Rebuild' reconstructs the sheets from",
               "it, which is the recovery path after a crash.")),

    tabPanel(
      "Seed",
      helpText("Once the axis 1 - 22 - 23 - 2 is placed, every other landmark is",
               "put at the MEDIAN FISHMORPH proportion of the body, so there is",
               "only repositioning left to do. These sliders set what the",
               "segment ratios do not fix: where a segment sits along the body,",
               "how it splits dorsal/ventral, and two fin angles. A point you",
               "have moved is never re-seeded."),
      checkboxInput("flipdorsal", "Flip dorsal / ventral", FALSE),
      actionButton("reseed", "Re-seed the unplaced landmarks"),
      tags$hr(),
      sliderInput("f_Bd",    "Bd position",              0, 1,  0.47, 0.01),
      sliderInput("o_Bd",    "Bd dorsal share",          0, 1,  0.50, 0.01),
      sliderInput("f_Hd",    "Hd position",              0, 1,  0.10, 0.01),
      sliderInput("o_Hd",    "Hd dorsal share",          0, 1,  0.43, 0.01),
      sliderInput("f_eye",   "Eye position",             0, 1,  0.10, 0.01),
      sliderInput("o_eye",   "Eye height (from belly)",  0, 1.5, 0.82, 0.01),
      sliderInput("f_PF",    "Pectoral position",        0, 1,  0.25, 0.01),
      sliderInput("o_PF",    "Pectoral dorsal share",   -1, 1, -0.69, 0.01),
      sliderInput("f_CP",    "Peduncle position",      0.5, 1,  0.93, 0.01),
      sliderInput("ang_PFl", "Pectoral fin angle",       0, 90, 35,   1),
      sliderInput("ang_Jl",  "Jaw angle",              -30, 90, 20,   1))
  )
}

## The queue selector sits at the top of the side panel, above the tabs: it
## decides what the whole session is doing -- which photographs are offered and
## what "Save & next" means -- so it belongs with the state of the session, not
## in the row of per-specimen actions where it was one click away from "Save".
side_panel <- function()
  div(class = "sidetabs",
      div(class = "modebar",
          radioButtons("session_mode", "Queue",
                       c("New" = "new", "Correct" = "correct",
                         "Repeats" = "repeat"),
                       selected = CFG$mode, inline = TRUE)),
      uiOutput("progress"), tags$br(), side_tabs())

## ---- main panel -------------------------------------------------------------
main_panel <- function() tagList(
  # what this session IS, on one line: paths are declared at the console, so
  # they belong in a header strip and not in editable fields.
  div(class = "sessionbar", uiOutput("session_info")),
  # ---- action bar, directly above the photograph -----------------------------
  # Every action taken once per specimen sits on one row, where the eye already
  # is: the queue, declaring a point unmeasurable, saving. Nothing here requires
  # a trip back to the side panel mid-specimen.
  div(class = "actionbar", style = "margin-bottom:6px;",
      actionButton("prev_photo", "< Previous"),
      actionButton("next_photo", "Next >"),
      span(style = "display:inline-block;width:14px;"),
      actionButton("save_specimen", "Save & next", class = "btn-primary"),
      actionButton("skip", "Skip"),
      span(style = "display:inline-block;width:14px;"),
      div(style = "display:inline-block;vertical-align:middle;min-width:280px;",
          selectizeInput("goto_file", NULL, choices = NULL, selected = NULL,
                         width = "280px",
                         options = list(placeholder = "Jump to a photograph...")))),
  # ---- point bar: what acts on the ACTIVE landmark ---------------------------
  # Declaring a point unmeasurable, clearing it, undoing, starting over: these
  # act on the point under the cursor, so they belong beside the landmark bar
  # rather than beside "Save & next", where a slip of one button was a saved
  # specimen. Static, not a renderUI: re-rendering an actionButton resets its
  # counter, which fires its observer as if it had been pressed.
  div(class = "actionbar phasebar", style = "margin-bottom:4px;",
      actionButton("set_na", "Mark NA", class = "btn-warning"),
      actionButton("clear_pt", "Clear point"),
      span(style = "display:inline-block;width:14px;"),
      actionButton("predict", "Predict the 19 landmarks"),
      actionButton("undo", "Undo last point"),
      actionButton("restart", "Start over")),
  div(class = "lmbar", uiOutput("lm_buttons")),   # active-landmark bar, bare
  # ---- view bar, immediately above the photograph ----------------------------
  # Zoom belongs next to what it zooms: at high magnification the operator
  # alternates between placing a point and re-framing, and a trip to the side
  # panel between the two breaks that loop.
  div(class = "actionbar", style = "margin:6px 0 4px 0;",
      actionButton("zoom_in", "Zoom +"),
      actionButton("zoom_out", "Zoom -"),
      actionButton("zoom_reset", "Whole view"),
      span(style = "display:inline-block;width:14px;"),
      div(style = "display:inline-block;vertical-align:middle;",
          selectInput("dispmax", NULL,
                      choices = c("Display 800 px (fastest)" = 800,
                                  "Display 1200 px"          = 1200,
                                  "Display 1600 px"          = 1600,
                                  "Display 2400 px"          = 2400,
                                  "Display full resolution"  = 0),
                      selected = 1200, width = "215px")),
      span(style = "font-size:12px;color:#6b7280;margin-left:10px;",
           "Right-click and drag to pan; double-click for the whole view;",
           "zoom centres on the active landmark. No wheel zoom.")),
  plotOutput("img", click = "click", dblclick = "img_dblclick", height = "700px"),
  fluidRow(
    column(7, card_box("Control: FISHMORPH segments as digitized",
                       tableOutput("qc"))),
    column(5, card_box("Status",
                       div(class = "statusline",
                           verbatimTextOutput("status"))))),
  # ---- reference, at the foot of the page ------------------------------------
  # The entry order, the conventions and the colour code are read on the first
  # specimen and never again. Above the photograph they cost three lines of
  # scroll on every one of the following thousand; here they cost nothing and
  # are still one page-end away.
  card_box("Entry order, conventions and colour code",
           uiOutput("click_help"),
           uiOutput("auto_help"),
           uiOutput("lm_legend"))
)

head_tags <- tags$head(tags$script(HTML(PAN_JS)), tags$style(HTML(APP_CSS)))

## The title, once, as a tag rather than a string: the package name carries the
## capitals it is written with, and the rest of the line is a subtitle, not part
## of the name -- so it is set lighter instead of being run together with it.
APP_TITLE <- tags$span(
  class = "app-title",
  tags$span(class = "app-title-name", "InTraitR"),
  tags$span(class = "app-title-sub", " — predictor-assisted landmarking"))

## `fillable = FALSE`: this page is a scrolling document, not a dashboard. In a
## fillable page every child negotiates a share of the viewport height, so the
## photograph -- asked for 700 px -- is squeezed by the bars above and the two
## panels below, and on a short window the plot device ends up smaller than its
## own margins. Ordinary document flow gives the plot the height it asks for and
## lets the rest scroll.
ui <- if (HAS_BSLIB) {
  bslib::page_sidebar(
    title = APP_TITLE,
    theme = bslib::bs_theme(version = 5, primary = "#2563eb",
                            "border-radius" = "0.5rem"),
    fillable = FALSE,
    sidebar = bslib::sidebar(width = 360, open = "desktop", side_panel()),
    head_tags, main_panel())
} else {
  fluidPage(
    head_tags,
    titlePanel(APP_TITLE, windowTitle = "InTraitR landmarking"),
    sidebarLayout(sidebarPanel(width = 3, side_panel()),
                  mainPanel(width = 9, main_panel())))
}

## =============================================================================
## Server
## =============================================================================
server <- function(input, output, session) {
  rv <- reactiveValues(
    img = NULL, arr = NULL, w = NULL, h = NULL, orig = NULL,
    flip = "none", dispflip = "none",
    pred = NULL, sel = 1L, msg = "",
    placed_order = integer(0),          # points in the order they were placed (for Undo)
    seeded = integer(0),                # points still at their median-proportion seed
    na = integer(0),                    # landmarks declared non-measurable
    edited = integer(0),                # landmarks moved by hand this session
    adjusted = integer(0),              # landmarks snapped by the extreme-point
                                        # convention (3/4), exported as "adjusted"
    zoom = 1, cx = NULL, cy = NULL,     # zoom state / view centre
    meas = NULL, bias = NULL,           # the two workbook sheets, in memory
    q = integer(0), qi = 0L,            # current queue (photo indices) + position
    pending = 0L)                       # records not yet written to the workbook

  ## ---- persistence ----------------------------------------------------------
  ## Resume from the workbook if there is one. The two sheets are held in
  ## memory: they are small (one row per digitization) and having them here is
  ## what lets the queues, the progress display and the bias summary be computed
  ## without touching the disk on every interaction.
  rv$meas <- wb_read_sheet(CFG$xlsx_path, CFG$sheet_measurements)
  rv$bias <- wb_read_sheet(CFG$xlsx_path, CFG$sheet_bias)

  ## The journal is opened BEFORE any digitizing can happen, and every save goes
  ## there first. It is the source of truth; the workbook is an export.
  journal <- intraitR::landmark_journal_open(
    CFG$journal_dir, operator = OPERATOR, app_version = CFG$app_version)

  ## Write the workbook when enough records have accumulated (or when forced).
  ## On failure NOTHING is overwritten and the operator is told: the journal is
  ## already written, so no data is lost -- consolidate_landmarks() finds it.
  flush_xlsx <- function(force = FALSE, quiet = TRUE) {
    if (rv$pending == 0L && !force) return(invisible(FALSE))
    if (!force && rv$pending < CFG$xlsx_flush_every) return(invisible(FALSE))
    sheets <- list(rv$meas, rv$bias, bias_summary(rv$bias, WB_PTS))
    names(sheets) <- c(CFG$sheet_measurements, CFG$sheet_bias, CFG$sheet_summary)
    ok <- tryCatch({ intraitR::write_xlsx_atomic(sheets, CFG$xlsx_path); TRUE },
                   error = function(e) { rv$msg <- conditionMessage(e); FALSE })
    if (ok) {
      rv$pending <- 0L
      if (!quiet) showNotification(
        sprintf("Workbook written: %s (%d + %d row(s)).",
                basename(CFG$xlsx_path), nrow(rv$meas), nrow(rv$bias)),
        type = "message", duration = 4)
    } else {
      showNotification(
        paste0("Could not write the workbook (open in Excel? locked by the ",
               "sync client?). Nothing is lost: every record is in the journal ",
               journal$path, "."), type = "error", duration = 12)
    }
    invisible(ok)
  }
  ## Last-chance write: closing the browser tab ends the session, and the
  ## records accumulated since the last flush would otherwise wait in memory
  ## until they were rebuilt from the journal.
  session$onSessionEnded(function() {
    isolate(if (rv$pending > 0L) try(flush_xlsx(force = TRUE), silent = TRUE))
  })

  notify <- function(text, type = "message") {
    rv$msg <- text
    showNotification(text, type = type, duration = 4)
  }

  ## A single finite scalar, or NA. numericInput() yields NULL before the input
  ## exists and NA when the field is emptied; both would break `x > 0` inside &&.
  num1 <- function(x) {
    v <- suppressWarnings(as.numeric(x))
    if (length(v) != 1L || !is.finite(v)) NA_real_ else v
  }
  ## mm per pixel from the scale bar 20-21 and the declared real distance.
  mm_per_px <- function(P) {
    mm <- num1(input$scale_mm)
    if (!is.finite(mm) || mm <= 0) return(NA_real_)
    if (is.null(P) || !fin_row(P, 20L) || !fin_row(P, 21L)) return(NA_real_)
    d <- sqrt(sum((P["21", ] - P["20", ])^2))
    if (!is.finite(d) || d <= 0) NA_real_ else mm / d
  }

  ## ---- repeated digitization ------------------------------------------------
  ## The code typed in the side panel names the PHYSICAL INDIVIDUAL throughout;
  ## the saved identifier is derived from it. In standard mode the two coincide,
  ## in repeat mode the identifier carries the operator and the repeat number, so
  ## a second pass never overwrites the first (save_specimen() drops rows sharing
  ## the identifier, which is exactly what must NOT happen between repeats).
  rep_mode <- function() identical(input$session_mode, "repeat")
  cur_mode <- function() input$session_mode %||% CFG$mode

  cur_code <- function() {
    id <- trimws(input$specimen_id %||% "")
    if (nzchar(id)) id else "specimen"
  }
  rep_target <- function() {
    t <- suppressWarnings(as.integer(input$rep_target))
    if (!length(t) || is.na(t) || t < 1L) as.integer(CFG$n_repeats) else t
  }
  ## Repeat numbers already saved for this individual, by THIS operator. The
  ## bias sheet carries `individual` and `replicate` as columns, so nothing has
  ## to be parsed back out of the identifier here -- the identifier convention
  ## exists for the exports that only have one string to work with.
  saved_reps <- function(code = cur_code()) {
    b <- rv$bias
    if (is.null(b) || !nrow(b)) return(integer(0))
    hit <- !is.na(b$individual) & b$individual == code &
      (is.na(b$operator) | b$operator == OPERATOR)
    if (!any(hit)) return(integer(0))
    r <- suppressWarnings(as.integer(b$replicate[hit]))
    sort(unique(r[is.finite(r)]))
  }
  ## Specimens already in the measurements sheet: the "new" queue is what is NOT
  ## here, the "correct" queue is what IS.
  saved_specimens <- function() {
    m <- rv$meas
    if (is.null(m) || !nrow(m)) return(character(0))
    unique(m$specimen[!is.na(m$specimen)])
  }
  ## Individuals that need no further work in the CURRENT mode: anything already
  ## measured (new/correct), or carrying its full complement of repeats.
  done_codes <- function() {
    if (isTRUE(rep_mode())) {
      b <- rv$bias
      if (is.null(b) || !nrow(b)) return(character(0))
      ind <- unique(b$individual[!is.na(b$individual)])
      tgt <- rep_target()
      return(ind[vapply(ind, function(c0) length(saved_reps(c0)) >= tgt,
                        logical(1))])
    }
    saved_specimens()
  }
  next_rep <- function(code = cur_code()) {
    done <- saved_reps(code)
    if (!length(done)) 1L else max(done) + 1L
  }
  ## Re-point the repeat counter at the first free slot for the individual now
  ## on screen: reopening a photograph half-way through its repeats must
  ## continue the series rather than restart it.
  sync_rep <- function() {
    if (!isTRUE(rep_mode())) return(invisible(NULL))
    updateNumericInput(session, "rep_i", value = next_rep())
    invisible(NULL)
  }
  ## The identifier the current configuration will be saved under.
  save_id <- function() {
    if (!isTRUE(rep_mode())) return(make_id(cur_code()))
    n <- suppressWarnings(as.integer(input$rep_i))
    if (!length(n) || is.na(n) || n < 1L) n <- 1L
    make_id(cur_code(), OPERATOR, n)
  }
  observeEvent(input$specimen_id, sync_rep(), ignoreInit = TRUE)

  output$rep_info <- renderUI({
    done <- saved_reps(); tgt <- rep_target()
    cls <- if (!isTRUE(rep_mode())) "text-muted" else ""
    div(class = paste("progressbox", cls),
        HTML(sprintf(
          "<b>%s</b><br>%d / %d repeat(s) saved%s<br>Next save: <code>%s</code>%s",
          cur_code(), length(done), tgt,
          if (length(done)) paste0(" (rep ", paste(done, collapse = ", "), ")")
          else "", save_id(),
          if (!isTRUE(rep_mode()))
            "<br><i>Switch the mode to 'Repeats' to use this tab.</i>" else "")))
  })

  ## Per-landmark reproducibility of what has been repeated so far. Shown while
  ## the session is open, because it is the number that tells the operator
  ## whether the protocol is holding -- not something to discover a month later.
  output$bias_tab <- renderTable({
    s <- bias_summary(rv$bias, WB_PTS)
    if (!nrow(s)) return(data.frame(`No repeat saved yet` = character(0),
                                    check.names = FALSE))
    s <- s[s$individual == "(all)", c("landmark", "n_replicates",
                                      "median_dev_px", "median_dev_pct_bl")]
    names(s) <- c("LM", "n", "px", "% Bl")
    s
  }, digits = 2, na = "-", width = "100%")

  ## ---- image display --------------------------------------------------------
  ## PERFORMANCE. A 24 Mpx photograph makes the app unusable for clicking unless
  ## three things are avoided on every redraw, and the plot redraws on *every*
  ## click, slider and checkbox:
  ##   1. keeping the full-resolution array around. It is decoded once, then
  ##      immediately downsampled to `dispmax` and the original is dropped --
  ##      coordinates stay in original pixels (rv$w, rv$h are unchanged), so
  ##      nothing downstream notices. The predictor still gets the file itself.
  ##   2. handing rasterImage() a numeric array. It re-converts the whole thing
  ##      to colours each call; a raster object is converted once, here.
  ##   3. drawing the whole image when zoomed in. Only the visible crop is
  ##      drawn (see output$img), which is what makes work at 8x fluid.
  ## rv$arr holds the downsampled array in ORIGINAL orientation; rv$flip is
  ## baked into the coordinate frame (landmarks are remapped when it changes)
  ## while rv$dispflip is purely visual.
  disp_max <- function() {
    v <- num1(input$dispmax)
    if (!is.finite(v) || v <= 0) Inf else v
  }
  make_disp <- function() {
    if (is.null(rv$arr)) return(NULL)
    a <- flip_array(rv$arr, rv$flip)
    a <- flip_array(a, rv$dispflip)
    grDevices::as.raster(a)                 # converted once, redrawn cheaply
  }
  flip_pt <- function(p, mode) {
    if (is.null(p) || !all(is.finite(p))) return(p)
    if (grepl("h", mode)) p[1] <- rv$w - p[1]
    if (grepl("v", mode)) p[2] <- rv$h - p[2]
    p
  }
  remap_pt <- function(p, oldm, newm) flip_pt(flip_pt(p, oldm), newm)

  ## Path of the image handed to the Python worker. With no flip it is the file
  ## itself, at full resolution. With a flip the ORIGINAL is re-read from disk
  ## and flipped: the display copy is downsampled, and feeding that to the
  ## predictor would both degrade it and put its output in the wrong pixel
  ## frame. One extra decode at prediction time is a fair price.
  worker_path <- function() {
    if (identical(rv$flip, "none")) return(rv$orig)
    full <- tryCatch(read_image(rv$orig), error = function(e) NULL)
    if (is.null(full)) return(rv$orig)
    if (length(dim(full)) == 2) full <- array(full, c(dim(full), 3))
    if (dim(full)[3] > 3) full <- full[, , 1:3, drop = FALSE]
    tf <- tempfile(fileext = ".jpg")
    jpeg::writeJPEG(flip_array(full, rv$flip), tf, quality = 0.95)
    tf
  }

  ## Load the photograph pointed to by rv$orig, resetting every point.
  load_working <- function() {
    if (is.null(rv$orig)) return()
    im <- tryCatch(read_image(rv$orig),
                   error = function(e) { notify(conditionMessage(e), "error"); NULL })
    if (is.null(im)) { rv$arr <- NULL; rv$img <- NULL; return() }
    if (length(dim(im)) == 2) im <- array(im, c(dim(im), 3))     # greyscale -> RGB
    if (length(dim(im)) == 3 && dim(im)[3] > 3) im <- im[, , 1:3, drop = FALSE]
    rv$h <- dim(im)[1]; rv$w <- dim(im)[2]      # ORIGINAL dims (coordinate frame)
    # Downsample now and drop the full array: it is never needed again for
    # display, and holding a 24 Mpx double array is what makes every redraw slow.
    rv$arr <- downscale(im, disp_max())
    rm(im)
    rv$flip <- "none"
    updateRadioButtons(session, "flip_mode", selected = "none")
    rv$img <- make_disp()
    rv$pred <- empty_coords(); rv$sel <- 1L
    rv$na <- integer(0); rv$edited <- integer(0); rv$placed_order <- integer(0)
    rv$seeded <- integer(0); rv$adjusted <- integer(0)
    rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL
  }

  ## ---- the queues -----------------------------------------------------------
  ## A queue is a set of INDICES into CFG$photos, so switching mode never
  ## reloads the folder and the photograph on screen keeps its identity.
  ##   new     : photographs not yet in the measurements sheet
  ##   correct : those that are (their points are reloaded on arrival)
  ##   repeat  : every photograph, until each has its complement of repeats
  queue_of <- function(m = cur_mode()) {
    done <- saved_specimens()
    switch(m,
           new     = which(!(PHOTO_CODES %in% done)),
           correct = which(PHOTO_CODES %in% done),
           `repeat` = seq_along(CFG$photos),
           seq_along(CFG$photos))
  }
  ## Points already saved for a specimen, put back on the photograph. This is
  ## the whole of "correct" mode: the operator sees what was digitized, moves
  ## what is wrong, and saves over it.
  ##
  ## Provenance survives the round trip. A row this app wrote comes back as
  ## "clicked" -- a human placed those points at least once. A row whose `mode`
  ## says it was SEEDED from elsewhere (an import, another operator's table)
  ## comes back as "seeded": nobody has yet checked it against THIS photograph,
  ## which is exactly what that status means. Without the distinction, importing
  ## a starting configuration and pressing Save would silently relabel it as
  ## hand-placed measurement -- the one thing the status column exists to
  ## prevent. Each point the operator actually moves becomes "clicked" through
  ## the normal click path.
  seed_from_sheet <- function(code) {
    m <- rv$meas
    if (is.null(m) || !nrow(m)) return(FALSE)
    i <- match(code, m$specimen)
    if (is.na(i)) return(FALSE)
    imported <- !is.na(m$mode[i]) && grepl("^seed", m$mode[i])
    P <- empty_coords()
    got <- integer(0)
    for (p in WB_PTS) {
      x <- suppressWarnings(as.numeric(m[[paste0(p, "_X")]][i]))
      y <- suppressWarnings(as.numeric(m[[paste0(p, "_Y")]][i]))
      if (is.finite(x) && is.finite(y)) { P[p, ] <- c(x, y); got <- c(got, p) }
    }
    if (!length(got)) return(FALSE)
    rv$pred <- P
    if (imported) {
      rv$seeded <- setdiff(got, DERIVED_LM); rv$edited <- integer(0)
    } else {
      rv$edited <- setdiff(got, DERIVED_LM); rv$seeded <- integer(0)
    }
    rv$adjusted <- integer(0); rv$na <- integer(0)
    rv$placed_order <- got
    rv$sel <- if (22L %in% got) 22L else got[1]
    q <- suppressWarnings(as.numeric(m$quality[i]))
    if (is.finite(q)) updateRadioButtons(session, "quality",
                                         selected = as.character(round(q)))
    TRUE
  }
  load_queue_photo <- function(k) {
    n <- length(rv$q)
    if (!n) { rv$qi <- 0L; return(invisible(NULL)) }
    k <- max(1L, min(as.integer(k), n)); rv$qi <- k
    i <- rv$q[k]
    rv$orig <- CFG$photos[i]
    code <- PHOTO_CODES[i]
    updateTextInput(session, "specimen_id", value = code)
    updateSelectizeInput(session, "goto_file", selected = i)
    load_working()                                  # resets every point
    reloaded <- if (identical(cur_mode(), "correct")) seed_from_sheet(code) else FALSE
    if (isTRUE(rep_mode())) updateNumericInput(session, "rep_i",
                                               value = next_rep(code))
    rv$msg <- sprintf(
      "%s (%d/%d in the '%s' queue). %s",
      code, k, n, cur_mode(),
      if (!reloaded) "Click the snout (point 1)."
      else if (length(rv$seeded))
        paste("Configuration SEEDED from elsewhere, checked by nobody on this",
              "photograph: go through every point before saving.")
      else "Points reloaded from the workbook: check and correct.")
    invisible(NULL)
  }
  ## Rebuild the queue for a mode and land on the first photograph that still
  ## needs work -- not simply the first one, which in a resumed session is
  ## almost always already done.
  set_mode <- function(m, keep_photo = TRUE) {
    cur <- if (keep_photo && rv$qi > 0L && length(rv$q)) rv$q[rv$qi] else NA_integer_
    rv$q <- queue_of(m)
    if (!length(rv$q)) {
      # An empty queue at launch is the normal state of a finished batch, not an
      # error: fall back to the first queue that has work, and say so.
      alt <- setdiff(c("new", "correct", "repeat"), m)
      alt <- alt[vapply(alt, function(x) length(queue_of(x)) > 0, logical(1))]
      if (length(alt)) {
        notify(sprintf("The '%s' queue is empty -- switching to '%s'.", m, alt[1]),
               "warning")
        updateRadioButtons(session, "session_mode", selected = alt[1])
        return(invisible(NULL))       # the observer re-enters with the new mode
      }
      rv$qi <- 0L
      notify(sprintf("The '%s' queue is empty.", m), "warning")
      return(invisible(NULL))
    }
    k <- if (!is.na(cur) && cur %in% rv$q) match(cur, rv$q) else {
      todo <- which(!(PHOTO_CODES[rv$q] %in% done_codes()))
      if (length(todo)) todo[1] else 1L
    }
    load_queue_photo(k)
  }

  ## The photograph jump list is the whole folder, once, server-side: the list
  ## is never rendered in full in the browser.
  updateSelectizeInput(session, "goto_file",
                       choices = stats::setNames(seq_along(CFG$photos),
                                                 basename(CFG$photos)),
                       selected = character(0), server = TRUE)
  observeEvent(input$session_mode, set_mode(cur_mode()), ignoreInit = FALSE)
  observeEvent(input$next_photo, if (length(rv$q)) load_queue_photo(rv$qi + 1L))
  observeEvent(input$prev_photo, if (length(rv$q)) load_queue_photo(rv$qi - 1L))
  observeEvent(input$goto_file, {
    i <- suppressWarnings(as.integer(input$goto_file))
    if (is.na(i) || !length(rv$q)) return()
    if (rv$qi > 0L && identical(rv$q[rv$qi], i)) return()
    k <- match(i, rv$q)
    if (is.na(k)) {
      # the photograph is outside the current queue: follow the operator rather
      # than refuse, and say which queue they have landed in.
      notify(sprintf("%s is not in the '%s' queue -- opened anyway.",
                     PHOTO_CODES[i], cur_mode()), "warning")
      rv$q <- sort(unique(c(rv$q, i))); k <- match(i, rv$q)
    }
    load_queue_photo(k)
  }, ignoreInit = TRUE)

  ## ---- flips ----------------------------------------------------------------
  ## Flipping the photograph REMAPS the points already placed instead of
  ## discarding them, so the specimen can be re-oriented mid-session.
  observeEvent(input$flip_mode, {
    if (is.null(rv$arr)) return()
    oldm <- rv$flip; newm <- input$flip_mode
    if (identical(oldm, newm)) return()
    if (!is.null(rv$pred)) {
      P <- rv$pred
      for (i in seq_len(nrow(P))) if (all(is.finite(P[i, ])))
        P[i, ] <- remap_pt(P[i, ], oldm, newm)
      rv$pred <- P
    }
    rv$flip <- newm
    rv$img <- make_disp()
    rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL
  }, ignoreInit = TRUE)
  ## Display-only flip: the landmarks (and the export) do not move.
  observeEvent(input$flip_disp, {
    if (is.null(rv$arr)) return()
    rv$dispflip <- input$flip_disp
    rv$img <- make_disp()
  }, ignoreInit = TRUE)
  ## Changing the display resolution needs the pixels back, so the file is
  ## re-decoded and re-downsampled. The landmarks are untouched: they live in
  ## original-pixel coordinates, which no display setting affects.
  observeEvent(input$dispmax, {
    if (is.null(rv$orig)) return()
    im <- tryCatch(read_image(rv$orig), error = function(e) NULL)
    if (is.null(im)) return()
    if (length(dim(im)) == 2) im <- array(im, c(dim(im), 3))
    if (dim(im)[3] > 3) im <- im[, , 1:3, drop = FALSE]
    rv$arr <- downscale(im, disp_max())
    rv$img <- make_disp()
  }, ignoreInit = TRUE)

  ## ---- zoom and pan ---------------------------------------------------------
  zoom_to_sel <- function() {
    if (!is.null(rv$pred) && fin_row(rv$pred, rv$sel)) {
      rv$cx <- rv$pred[rv$sel, 1]; rv$cy <- rv$pred[rv$sel, 2] }
  }
  observeEvent(input$zoom_in,  { rv$zoom <- min(rv$zoom * 1.5, 12); zoom_to_sel() })
  observeEvent(input$zoom_out, { rv$zoom <- max(rv$zoom / 1.5, 1)
    if (rv$zoom == 1) { rv$cx <- NULL; rv$cy <- NULL } })
  observeEvent(input$zoom_reset, { rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL })
  observeEvent(input$img_dblclick, { rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL })
  observeEvent(input$pan, {
    if (is.null(rv$img) || rv$zoom <= 1) return()
    if (is.null(rv$cx)) rv$cx <- rv$w / 2
    if (is.null(rv$cy)) rv$cy <- rv$h / 2
    rv$cx <- rv$cx - input$pan$dx * (rv$w / rv$zoom)
    rv$cy <- rv$cy - input$pan$dy * (rv$h / rv$zoom)
  })

  ## ---- seeding --------------------------------------------------------------
  seed_params <- reactive({
    p <- SEED_DEFAULTS
    for (nm in c("f_Bd", "o_Bd", "f_Hd", "o_Hd", "f_eye", "o_eye",
                 "f_PF", "o_PF", "f_CP", "ang_PFl", "ang_Jl")) {
      v <- num1(input[[nm]])
      if (is.finite(v)) p[[nm]] <- v
    }
    p
  })

  ## Place every landmark the operator has not touched at its median FISHMORPH
  ## proportion. Protected from being overwritten: the axis itself (it is the
  ## input), anything placed by hand, and anything marked NA.
  reseed <- function(quiet = TRUE) {
    P <- rv$pred
    if (is.null(P) || !fin_row(P, 1L) || !fin_row(P, 2L)) return(invisible(FALSE))
    keep <- Reduce(union, list(rv$edited, rv$na, c(1L, 2L), HINGES))
    P2 <- seed_configuration(P, seed_params(), isTRUE(input$flipdorsal), keep = keep)
    if (is.null(P2)) return(invisible(FALSE))
    rv$pred <- P2
    rv$seeded <- setdiff(seq_len(N_ANAT), keep)
    if (!quiet)
      notify(sprintf("%d landmark(s) seeded at the median FISHMORPH proportions -- reposition them.",
                     length(setdiff(rv$seeded, DERIVED_LM))))
    invisible(TRUE)
  }
  observeEvent(input$reseed, reseed(quiet = FALSE))
  ## Live re-seed while the axis is still being defined: moving a slider or the
  ## dorsal switch should show its effect straight away. Not in the review
  ## phase, where the conventions are already driving the configuration.
  observeEvent(
    lapply(c("f_Bd", "o_Bd", "f_Hd", "o_Hd", "f_eye", "o_eye", "f_PF", "o_PF",
             "f_CP", "ang_PFl", "ang_Jl", "flipdorsal"), function(nm) input[[nm]]),
    reseed(), ignoreInit = TRUE)

  ## ---- clicking on the photograph -------------------------------------------
  ## One behaviour throughout: a click places the ACTIVE landmark and the
  ## selection advances. Before the model has been run the sequence walks the
  ## calibration points, afterwards the points left to review -- but there is no
  ## separate "calibration mode", so any landmark can be selected and placed at
  ## any moment, which is what makes the numbered bar useful from the start.
  observeEvent(input$click, {
    if (is.null(rv$img) || is.null(rv$pred)) return()
    p <- c(input$click$x, input$click$y)
    if (isTRUE(input$move_all)) {                  # rigid translation of the block
      cur <- rv$pred[rv$sel, ]
      if (all(is.finite(cur))) {
        rv$pred <- sweep(rv$pred, 2, p - cur, "+")
        rv$msg <- paste0("Block moved (via LM", rv$sel, ").")
      }
      return()
    }
    just <- rv$sel
    P <- rv$pred
    P[just, ] <- p
    rv$na     <- setdiff(rv$na, just)              # re-placed -> no longer NA
    rv$edited <- union(rv$edited, just)            # placed by hand
    rv$seeded <- setdiff(rv$seeded, just)          # no longer at its seed
    rv$adjusted <- setdiff(rv$adjusted, just)      # measured, not snapped
    rv$placed_order <- c(setdiff(rv$placed_order, just), just)
    # Points that define the reference frames rather than sit in them: the axis
    # (1, 2 and the hinges) and LM3, which settles which side is dorsal. Moving
    # one of these re-seeds instead of propagating, since it changes the frame
    # every other point is expressed in.
    frame_pt <- just %in% c(1L, 2L, 3L, HINGES)
    if (isTRUE(input$auto_constraints) && !frame_pt &&
        fin_row(P, 1L) && fin_row(P, 2L))
      P <- propagate_conventions(P, just)
    rv$pred <- P
    # ALWAYS advance -- hinges included. They are stops in the sequence like any
    # other point; treating them as a special case is what left the selection
    # stuck on 22.
    nxt <- next_point(just)
    rv$sel <- nxt
    rv$msg <- paste0(point_label(just), " placed -> next: ", point_label(nxt), ".")
    # As soon as the axis is complete, drop the whole configuration onto the
    # median FISHMORPH proportions, so from LM2 onwards the work is
    # repositioning rather than placing on a bare photograph.
    if (frame_pt && fin_row(rv$pred, 1L) && fin_row(rv$pred, 2L)) reseed()
  })

  ## ---- contextual help ------------------------------------------------------
  ## Printed from ADVANCE_ORDER itself, so the help cannot drift away from what
  ## the auto-advance actually does.
  output$click_help <- renderUI({
    helpText(tags$b("Auto-advance:"), paste(ADVANCE_ORDER, collapse = " > "),
             tags$br(),
             "Place the axis first (1, 22, 23, 2): the hinges 22 and 23 go on the",
             "bends of a curved specimen, anywhere along the midline if it is",
             "straight. The moment LM2 is down, every remaining landmark is put",
             "at the median FISHMORPH proportion, so from there on it is",
             "repositioning only. 'Predict' is optional and can be used at any",
             "point to let the model refine the anatomical landmarks. Any",
             "landmark can also be selected directly from the bar below.")
  })
  output$auto_help <- renderUI({
    if (isTRUE(input$pin))
      helpText(tags$b("Skipped by the auto-advance:"),
               "8, 9, 11 (derived from 1, 7, 10 and 4) and 24 (spare hinge).",
               tags$br(), tags$b("PIN mode:"), "once 1, 2, 3, 4, 7, 10, 12, 15,",
               "16 and 18 are placed, 'Predict' freezes them on your clicks and",
               "the model predicts only the rest.")
    else
      helpText(tags$b("Skipped by the auto-advance:"),
               "8, 9, 11 (derived from 1, 7, 10 and 4) and 24 (spare hinge).",
               tags$br(), "'Predict' keeps LM1 and LM2; LM3 only orients the fish",
               "dorsal side up and is re-predicted.")
  })

  ## ---- active-landmark bar --------------------------------------------------
  ## Faster than a drop-down, and it doubles as a status display: green = active,
  ## blue = placed by hand, pink struck through = NA, grey = derived, gold =
  ## hinge, pale green = scale bar. Plain HTML buttons setting input$sel_btn --
  ## robust to re-rendering, unlike actionButton counters which would reset.
  output$lm_buttons <- renderUI({
    if (is.null(rv$pred)) return(helpText("Load a photograph to start placing landmarks."))
    auto <- if (isTRUE(input$pin)) AUTO_LM_PIN else AUTO_LM
    # Layout, as in the FISHMORPH digitizer: the broken axis first (1 -> 22 ->
    # 23 -> 2, the points that define every frame), then the anatomical points in
    # numeric order, then the derived ones and the spare hinge, and finally the
    # scale bar. Anatomical order beats numeric order here because it follows the
    # path the eye takes over the specimen -- head, then body, then caudal.
    order_show <- c(1L, CURVE_PT, EXTRA_HINGES[1], 2L, ANAT_ORDER,
                    DERIVED_LM, EXTRA_HINGES[-1], SCALE_PTS)
    btn <- function(i) {
      col <- if (i == rv$sel) "background:#28a745;color:#fff;font-weight:bold;"
             else if (i %in% rv$na) "background:#f8d7da;color:#a00;text-decoration:line-through;"
             else if (i %in% HINGES) "background:#ffd24d;color:#000;font-weight:bold;"
             else if (i %in% SCALE_PTS) "background:#d9f2e6;color:#065;font-weight:bold;"
             else if (i %in% rv$adjusted) "background:#e6d9f2;color:#4a2d6b;font-weight:bold;"
             else if (i %in% rv$edited) "background:#cfe8ff;"
             else if (i %in% auto || i %in% DERIVED_LM) "background:#eee;color:#999;"
             else if (i %in% rv$seeded) "background:#faeeda;color:#854f0b;"
             else "background:#f7f7f7;"
      if (!fin_row(rv$pred, i) && !(i %in% rv$na))
        col <- paste0(col, "border-style:dashed;")
      tags$button(type = "button", i, class = "lmbtn",
        onclick = sprintf("Shiny.setInputValue('sel_btn', %d, {priority:'event'});", i),
        style = col)
    }
    # Nothing but the buttons, and all of them on ONE line: the bar is a map of
    # the specimen, read at a glance dozens of times per fish, and a wrap turns
    # that glance into a search -- the point that moves to the second row is at a
    # different place on every window size. The flex row shares the width out
    # instead (see .lmbar in APP_CSS). Its meaning is carried by the colours,
    # which the legend at the foot of the page states once.
    div(class = "lmrow", lapply(order_show, btn))
  })

  ## The colour legend, at the foot of the page: read once, then never again.
  output$lm_legend <- renderUI({
    tags$div(style = "font-size:11.5px;color:#6b7280;line-height:1.6;",
      tags$b("Landmark bar: "),
      "green = active; blue = placed by hand; amber = still at its seed",
      "(median FISHMORPH proportion -- never checked on this specimen);",
      "pink struck through = NA; grey = automatic or derived; gold = HINGES;",
      "pale green = SCALE BAR (20/21); mauve = snapped onto the body outline",
      "by the LM3/LM4 check; dashed border = not placed yet.",
      tags$br(),
      "Broken axis 1 -> 22 -> 23 -> 2: place 22 then 23 on the bends of a curved",
      "specimen. Head conventions apply on 1-22, body depth and pectoral fin",
      "(10, 11, 12) on 22-23, caudal (16-17, 18-19) on 23-2. LM24 (end of the",
      "list) adds a fourth axis segment, without conventions. LM22 is a genuine",
      "landmark -- fishmorph_segments() uses it to correct the standard length.",
      "LM23 and LM24 are entry aids, not landmarks: they are written to the",
      "workbook and the journal, so that reopening a specimen restores the axis",
      "it was digitized under, but they must be left out of any shape analysis",
      "(read the first 22 points, not every _X column).")
  })
  observeEvent(input$sel_btn, { rv$sel <- as.integer(input$sel_btn); zoom_to_sel() })

  # The action bar is always on screen, so these guard against being pressed
  # during the calibration phase, when there is no coordinate matrix yet.
  observeEvent(input$set_na, {
    if (is.null(rv$pred)) {
      notify("Nothing to mark yet: predict, or start manual placement first.",
             "warning"); return() }
    if (rv$sel %in% c(1L, 2L)) {
      notify("LM1 and LM2 define the body axis and cannot be marked NA.", "warning"); return()
    }
    rv$pred[rv$sel, ] <- NA_real_
    rv$na <- union(rv$na, rv$sel); rv$edited <- setdiff(rv$edited, rv$sel)
    rv$seeded <- setdiff(rv$seeded, rv$sel)
    rv$adjusted <- setdiff(rv$adjusted, rv$sel)
    s <- rv$sel
    rv$placed_order <- setdiff(rv$placed_order, s)
    rv$sel <- if (s %in% HINGES) s else next_point(s)
    rv$msg <- paste(point_label(s), "marked NA (not measurable).")
  })
  observeEvent(input$clear_pt, {                   # unlike NA: simply "not placed"
    if (is.null(rv$pred)) return()
    rv$pred[rv$sel, ] <- NA_real_
    rv$na <- setdiff(rv$na, rv$sel); rv$edited <- setdiff(rv$edited, rv$sel)
    rv$seeded <- setdiff(rv$seeded, rv$sel)
    rv$adjusted <- setdiff(rv$adjusted, rv$sel)
    rv$placed_order <- setdiff(rv$placed_order, rv$sel)
    rv$msg <- paste(point_label(rv$sel), "cleared.")
  })
  ## Undo: clear the point placed most recently, and make it active again.
  observeEvent(input$undo, {
    if (is.null(rv$pred) || !length(rv$placed_order)) {
      notify("Nothing to undo.", "warning"); return() }
    last <- rv$placed_order[length(rv$placed_order)]
    rv$placed_order <- rv$placed_order[-length(rv$placed_order)]
    rv$pred[last, ] <- NA_real_
    rv$edited <- setdiff(rv$edited, last); rv$na <- setdiff(rv$na, last)
    rv$seeded <- setdiff(rv$seeded, last)
    rv$sel <- last
    rv$msg <- paste0(point_label(last), " cleared -- place it again.")
  })
  ## Drop every point and its status, keeping the photograph, the zoom and the
  ## flips as they are. Shared by "Start over" and by the blind repeat, which
  ## must leave the operator facing the same image with nothing already placed.
  reset_points <- function() {
    rv$pred <- empty_coords()
    rv$na <- integer(0); rv$edited <- integer(0); rv$placed_order <- integer(0)
    rv$seeded <- integer(0); rv$adjusted <- integer(0)
    rv$sel <- 1L
    invisible(NULL)
  }
  observeEvent(input$restart, {
    reset_points()
    rv$msg <- "Cleared. Click the snout (LM1)."
  })

  ## ---- per-point status -----------------------------------------------------
  ## The information a wide coordinate table cannot carry: which points were
  ## actually looked at. "predicted" flags a point still sitting exactly where
  ## the model put it -- never verified by eye, and therefore to be audited.
  point_status <- function(points) {
    st <- vapply(points, function(p) {
      if (p %in% rv$na) "na"
      else if (!fin_row(rv$pred, p)) "missing"
      # BEFORE "clicked": a point snapped by the extreme-point convention was
      # not pointed at by the operator, and the distinction has to survive into
      # the exported table. Re-clicking it makes it a measurement again.
      else if (p %in% rv$adjusted) "adjusted"
      else if (p %in% rv$edited) "clicked"
      else if (p %in% rv$seeded && !(p %in% DERIVED_LM)) "seeded"
      else if (p %in% DERIVED_LM) "derived"
      else if (p %in% c(1L, 2L)) "clicked"
      else "predicted"
    }, character(1))
    stats::setNames(st, as.character(points))
  }

  ## ---- the record: one row for the workbook, one line per point for the journal
  ## The long form is what goes to the journal (it carries the per-point status);
  ## the wide form is the workbook row. They are built from the same state, so
  ## the two layers can never disagree about what was saved.
  current_table <- function() {
    id <- save_id()                       # code, or code[_operator]_rep<N>
    P <- rv$pred
    data.frame(specimen = id, landmark = WB_PTS,
               X = P[WB_PTS, 1], Y = P[WB_PTS, 2],
               mm_per_px = mm_per_px(P),            # scale from the final 20-21
               note = suppressWarnings(as.integer(input$quality)),
               status = unname(point_status(WB_PTS)),
               row.names = NULL)
  }
  current_row <- function(st) {
    P <- rv$pred
    row <- data.frame(
      specimen = save_id(), individual = cur_code(),
      replicate = if (isTRUE(rep_mode()))
        suppressWarnings(as.integer(input$rep_i)) else 1L,
      operator = OPERATOR, mode = cur_mode(),
      photo_file = if (!is.null(rv$orig)) basename(rv$orig) else NA_character_,
      img_w = rv$w %||% NA_real_, img_h = rv$h %||% NA_real_,
      quality = suppressWarnings(as.numeric(input$quality)),
      ruler_mm = num1(input$scale_mm), mm_per_px = mm_per_px(P),
      n_clicked = sum(st == "clicked"), n_seeded = sum(st == "seeded"),
      n_predicted = sum(st == "predicted"), n_adjusted = sum(st == "adjusted"),
      n_na = sum(st == "na"),
      app_version = CFG$app_version,
      timestamp = format(as.POSIXct(Sys.time(), tz = "UTC"),
                         "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      stringsAsFactors = FALSE)
    for (p in WB_PTS) {
      row[[paste0(p, "_X")]] <- if (fin_row(P, p)) P[p, 1] else NA_real_
      row[[paste0(p, "_Y")]] <- if (fin_row(P, p)) P[p, 2] else NA_real_
    }
    row[, WB_COLS, drop = FALSE]
  }

  ## Skip: jump to the next photograph of the queue that still NEEDS work,
  ## rather than simply the next one. In a batch that is what skip is for --
  ## coming back to the gaps after a first pass, without stepping through the
  ## specimens already done.
  observeEvent(input$skip, {
    if (!length(rv$q)) { notify("The queue is empty.", "warning"); return() }
    done <- done_codes()
    cand <- which(!(PHOTO_CODES[rv$q] %in% done))
    nxt <- cand[cand > rv$qi]
    if (!length(nxt)) nxt <- cand              # wrap around to the earlier gaps
    if (!length(nxt)) {
      notify(sprintf("Nothing left to do in the '%s' queue.", cur_mode()))
      return()
    }
    load_queue_photo(nxt[1])
  })

  ## Write the workbook now. It is written every `xlsx_flush_every` records
  ## anyway, so this is the belt-and-braces action for a long session -- and the
  ## one to press before opening the file in Excel.
  observeEvent(input$flush, {
    if (is.null(rv$meas) && is.null(rv$bias)) {
      notify("Nothing to write yet.", "warning"); return() }
    flush_xlsx(force = TRUE, quiet = FALSE)
  })

  ## Recovery: rebuild both sheets from the journals and take them as the state.
  ## The journal is the source of truth, so this is not an import -- it is the
  ## workbook catching up with what was actually recorded.
  observeEvent(input$rebuild, {
    j <- tryCatch(intraitR::consolidate_landmarks(CFG$journal_dir, points = WB_PTS),
                  error = function(e) NULL)
    if (is.null(j) || !nrow(j)) {
      notify("No record found in the journal directory.", "warning"); return() }
    is_bias <- !is.na(j$target_sheet) & j$target_sheet == CFG$sheet_bias
    rv$meas <- wb_normalise(j[!is_bias, , drop = FALSE])
    rv$bias <- wb_normalise(j[is_bias, , drop = FALSE])
    rv$pending <- rv$pending + 1L
    flush_xlsx(force = TRUE, quiet = FALSE)
    notify(sprintf("Rebuilt from the journals: %d measurement(s), %d repeat(s).",
                   nrow(rv$meas), nrow(rv$bias)))
    set_mode(cur_mode())
  })

  ## ---- extreme-point check, on save -----------------------------------------
  ## "Save & next" goes through this check before anything is written. When LM3
  ## is not the most dorsal point (or LM4 the most ventral), the operator is
  ## offered the two ways out that matter: measure it again, or let the app
  ## snap the point onto the true extreme.
  extreme_modal <- function(v) {
    showModal(modalDialog(
      title = "FISHMORPH conventions: Bd (3-4) is not the maximum body depth",
      tags$ul(lapply(seq_len(nrow(v)), function(r) {
        i <- v$point[r]; j <- v$culprit[r]
        tags$li(sprintf(
          "LM%d must be the most %s point: LM%d overshoots it by %.0f px.",
          i, if (i == 3L) "DORSAL" else "VENTRAL", j, v$delta[r]))
      })),
      tags$p(tags$em(
        "Heights are measured perpendicular to the body axis, segment by",
        "segment, so a bent or tilted specimen is not flagged for its posture.",
        "The caudal peduncle and fin (16-19), the appendage tips (12, 15) and",
        "the derived ventral points (8, 9, 11 -- computed from LM4 itself) are",
        "excluded from the test.")),
      tags$p("Auto-correct gives the landmark the height of the point",
             "overshooting it, keeping its position along the axis; corrected",
             "points are exported with status \"adjusted\"."),
      footer = tagList(
        actionButton("extreme_remeasure", "Measure again", class = "btn-primary"),
        actionButton("extreme_fix", "Auto-correct and save"),
        actionButton("extreme_asis", "Save without correcting")),
      easyClose = FALSE, size = "l"))
  }

  ## Apply the correction. propagate_conventions() may move the belly line once
  ## LM4 has changed height, so the check is iterated to a fixed point -- three
  ## passes is ample, and the bound rules out a loop on a pathological case.
  ## LM4 alone drives the propagation: LM3 keeps its abscissa, so the 3-4
  ## perpendicular is already satisfied, and LM3 is a FRAME point whose click
  ## handler would re-seed the whole configuration.
  apply_extreme_fix <- function() {
    for (it in 1:3) {
      P <- rv$pred
      v <- extreme_violations(P)
      if (is.null(v)) return(TRUE)
      P <- fix_extremes(P, v)
      if (isTRUE(input$auto_constraints) && 4L %in% v$point &&
          fin_row(P, 1L) && fin_row(P, 2L))
        P <- propagate_conventions(P, 4L)
      rv$pred     <- P
      rv$na       <- setdiff(rv$na, v$point)
      rv$seeded   <- setdiff(rv$seeded, v$point)
      rv$adjusted <- union(rv$adjusted, v$point)
    }
    is.null(extreme_violations(rv$pred))
  }

  observeEvent(input$save_specimen, {
    if (is.null(rv$pred)) {
      notify("Nothing to save yet: predict, or start manual placement first.",
             "warning"); return() }
    if (isTRUE(input$check_extremes)) {
      v <- extreme_violations(rv$pred)
      if (!is.null(v)) { extreme_modal(v); return() }
    }
    save_specimen()
  })

  ## Measure again: close, select the offending landmark and centre the view.
  observeEvent(input$extreme_remeasure, {
    removeModal()
    v <- extreme_violations(rv$pred)
    if (!is.null(v)) {
      rv$sel <- v$point[1]; zoom_to_sel()
      rv$msg <- sprintf("%s -- click its true position (the most %s point).",
                        point_label(v$point[1]),
                        if (v$point[1] == 3L) "dorsal" else "ventral")
    }
  })
  observeEvent(input$extreme_fix, {
    removeModal()
    if (!isTRUE(apply_extreme_fix()))
      showNotification(paste("LM3/LM4 still breach the convention after",
                             "correction: check the placement."),
                       type = "warning", duration = 8)
    save_specimen()
  })
  observeEvent(input$extreme_asis, { removeModal(); save_specimen() })

  save_specimen <- function() {
    df  <- current_table()
    id  <- df$specimen[1]
    st  <- stats::setNames(df$status, as.character(df$landmark))
    row <- current_row(df$status)
    is_bias <- isTRUE(rep_mode())
    sheet <- if (is_bias) CFG$sheet_bias else CFG$sheet_measurements

    ## 1. THE JOURNAL FIRST, always. It is append-only, so this cannot destroy
    ##    anything already recorded, and once it has returned the record exists
    ##    whatever happens to the workbook, to R or to the machine.
    jok <- tryCatch({
      intraitR::landmark_journal_append(
        journal, row_key = id, coords = rv$pred, points = WB_PTS, status = st,
        specimen = id, individual = row$individual, replicate = row$replicate,
        photo_file = row$photo_file, mode = row$mode, target_sheet = sheet,
        img_w = row$img_w, img_h = row$img_h, quality = row$quality,
        ruler_mm = row$ruler_mm, mm_per_px = row$mm_per_px)
      TRUE
    }, error = function(e) { rv$msg <- conditionMessage(e); FALSE })
    if (!jok) {
      showNotification(
        paste("JOURNAL WRITE FAILED -- nothing was saved. Check that",
              journal$path, "is writable before going on."),
        type = "error", duration = NULL)
      return(invisible(NULL))
    }

    ## 2. Then the in-memory sheet. Same identifier = same row: a corrected
    ##    specimen replaces itself, while a repeat -- whose identifier carries
    ##    its number -- never can.
    # `x != id` would yield NA on an NA identifier and slip a row of NAs into
    # the sheet; the negated equality keeps those rows instead.
    drop_id <- function(d) d[!(!is.na(d$specimen) & d$specimen == id), ,
                             drop = FALSE]
    if (is_bias) rv$bias <- rbind(drop_id(rv$bias), row)
    else         rv$meas <- rbind(drop_id(rv$meas), row)
    rv$pending <- rv$pending + 1L
    flush_xlsx()                                   # writes every N records

    msg <- sprintf("'%s' saved to %s (score %s/5; %d measurement(s), %d repeat(s)).",
                   id, sheet, df$note[1], nrow(rv$meas), nrow(rv$bias))
    # Points never looked at are the quality risk worth surfacing, and a seeded
    # point is the worse of the two: it was measured on no specimen at all.
    unchecked <- c(seeded = sum(df$status == "seeded"),
                   predicted = sum(df$status == "predicted"))
    if (any(unchecked > 0))
      msg <- paste(msg, sprintf("%d still seeded, %d still predicted -- unchecked.",
                                unchecked[["seeded"]], unchecked[["predicted"]]))
    n_adj <- sum(df$status == "adjusted")
    if (n_adj > 0)
      msg <- paste(msg, sprintf("%d snapped to the body outline (status adjusted).",
                                n_adj))
    notify(msg, type = if (any(unchecked > 0)) "warning" else "message")

    ## 3. What "next" means depends on the queue. In repeat mode it is the SAME
    ##    photograph again until the individual has its complement -- and, by
    ##    default, with the landmarks cleared, because a pass resumed from the
    ##    configuration just saved measures how little the operator moved the
    ##    points rather than how reproducibly they place them, which drives %ME
    ##    to zero.
    if (is_bias) {
      tgt <- rep_target()
      done <- length(saved_reps())
      if (done < tgt) {
        updateNumericInput(session, "rep_i", value = next_rep())
        if (isTRUE(input$rep_blind)) {
          reset_points()
          notify(sprintf(paste("Repeat %d/%d of '%s' saved. Landmarks cleared:",
                               "measure again from the snout."),
                         done, tgt, cur_code()))
        } else {
          notify(sprintf(paste("Repeat %d/%d of '%s' saved. The previous",
                               "configuration is still on screen -- these",
                               "repeats are NOT independent."),
                         done, tgt, cur_code()), "warning")
        }
        return(invisible(NULL))
      }
      notify(sprintf("'%s' complete: %d repeat(s).", cur_code(), done))
    }
    if (length(rv$q) && rv$qi < length(rv$q)) load_queue_photo(rv$qi + 1L)
    invisible(NULL)
  }

  output$saved_info <- renderText({
    nm <- if (is.null(rv$meas)) 0L else nrow(rv$meas)
    nb <- if (is.null(rv$bias)) 0L else nrow(rv$bias)
    ni <- if (nb) length(unique(rv$bias$individual)) else 0L
    paste0(
      sprintf("%s\n", basename(CFG$xlsx_path)),
      sprintf("%s: %d specimen(s)\n", CFG$sheet_measurements, nm),
      sprintf("%s: %d digitization(s) of %d individual(s)\n",
              CFG$sheet_bias, nb, ni),
      sprintf("%d record(s) not yet written (flush every %d)",
              rv$pending, CFG$xlsx_flush_every))
  })

  ## ---- prediction -----------------------------------------------------------
  observeEvent(input$predict, {
    P <- rv$pred
    if (is.null(P) || !fin_row(P, 1L) || !fin_row(P, 2L)) {
      notify("Place at least the snout (LM1) and the caudal-fin basis (LM2) first.",
             "error"); return() }
    if (!length(PRED_CHOICES)) { notify("No model available.", "error"); return() }
    out <- tempfile(fileext = ".csv")
    # Calibration coordinates now come straight from the landmark matrix, so the
    # points fed to the model are exactly the ones shown on screen.
    has <- function(i) fin_row(P, i)
    xy  <- function(i) paste0(P[i, 1], ",", P[i, 2])
    # training set matching the chosen model (identical bounding box):
    # mlmorph_run_app -> mlmorph_dataset_app, and so on.
    ds_dir <- file.path(ML, sub("mlmorph_run", "mlmorph_dataset",
                                basename(dirname(input$pred))))
    if (!dir.exists(ds_dir)) ds_dir <- DATASET
    img_path <- worker_path()
    args <- c(shQuote(WORKER), "--image", shQuote(img_path),
              "--snout", xy(1L), "--caudal", xy(2L),
              if (has(3L)) c("--dorsal", xy(3L)),   # orientation; = LM3 in pin mode
              if (isTRUE(input$pin) && has(4L))  c("--lm4",  xy(4L)),
              if (isTRUE(input$pin) && has(7L))  c("--lm7",  xy(7L)),
              if (isTRUE(input$pin) && has(10L)) c("--lm10", xy(10L)),
              if (isTRUE(input$pin) && has(12L)) c("--lm12", xy(12L)),
              if (isTRUE(input$pin) && has(16L)) c("--lm16", xy(16L)),
              if (isTRUE(input$pin) && has(18L)) c("--lm18", xy(18L)),
              if (isTRUE(input$pin) && has(15L)) c("--lm15", xy(15L)),
              if (has(20L) && has(21L)) c("--scale1", xy(20L), "--scale2", xy(21L)),
              if (!isTRUE(input$pin)) "--no-pin-clicks",
              "--scale-mm", { v <- num1(input$scale_mm); if (is.finite(v)) v else 0 },
              "--dataset-dir", shQuote(ds_dir),
              "--predictor", shQuote(input$pred),
              "--out", shQuote(out))
    rv$msg <- "Prediction running..."
    res <- tryCatch(system2(PY, args, stdout = TRUE, stderr = TRUE),
                    error = function(e) conditionMessage(e))
    if (!identical(img_path, rv$orig)) try(unlink(img_path), silent = TRUE)
    if (file.exists(out)) {
      d <- utils::read.csv(out)
      # Start from the points already on screen, so the scale bar, the curvature
      # point and the hinges placed during calibration SURVIVE the prediction --
      # the model only fills in the anatomical landmarks it was asked for.
      M <- rv$pred
      keep <- d$landmark >= 1 & d$landmark <= N_ANAT
      M[as.character(d$landmark[keep]), ] <- as.matrix(d[keep, c("X", "Y")])
      # Pin mode: 1, 2, 3, 4, 7 are already frozen on the clicks by the worker;
      # propagate the FISHMORPH conventions to the dependants (8, 9, 11, 5, 6, 13, 14).
      if (isTRUE(input$pin)) M <- apply_conventions(M)
      rv$pred <- M
      rv$seeded <- setdiff(rv$seeded, as.integer(d$landmark[keep]))
      # Provenance: every landmark the model wrote over becomes "predicted"
      # again, except those the worker froze on the operator's clicks.
      rv$edited <- union(setdiff(rv$edited, as.integer(d$landmark[keep])),
                         intersect(pinned_clicks(input$pin), rv$placed_order))
      # a landmark the model has just rewritten is no longer the one the
      # extreme-point convention had snapped
      rv$adjusted <- setdiff(rv$adjusted, as.integer(d$landmark[keep]))
      rv$sel <- ANAT_ORDER[1]   # first anatomical point to review
      notify(paste0("Prediction done. Review the points; scale bar 20-21: ",
                    if (any(is.na(M[c("20", "21"), ]))) "still to place."
                    else "in place."))
    } else {
      notify(paste("Prediction failed:", paste(utils::tail(res, 4), collapse = " | ")),
             "error")
    }
  })

  ## ---- plot -----------------------------------------------------------------
  output$img <- renderPlot({
    # The margins go to zero FIRST, before anything is drawn: with the default
    # 5.1/4.1/4.1/2.1 lines, plot.new() errors with "figure margins too large"
    # as soon as the device is narrow (a collapsed layout, a small window),
    # which would replace the photograph with a stack trace.
    par(mar = c(0, 0, 0, 0))
    if (is.null(rv$img)) { plot.new(); text(.5, .5, "Load a photograph"); return() }
    cx <- if (is.null(rv$cx)) rv$w / 2 else rv$cx
    cy <- if (is.null(rv$cy)) rv$h / 2 else rv$cy
    hw <- (rv$w / 2) / rv$zoom; hh <- (rv$h / 2) / rv$zoom
    cx <- min(max(cx, hw), rv$w - hw); cy <- min(max(cy, hh), rv$h - hh)
    plot(NA, xlim = c(cx - hw, cx + hw), ylim = c(cy + hh, cy - hh), asp = 1,
         xaxs = "i", yaxs = "i", xlab = "", ylab = "", axes = FALSE)
    # Draw ONLY the visible crop of the raster. Handing the whole image to
    # rasterImage() and letting the device clip means the full bitmap is
    # rasterized on every redraw -- and the plot redraws on every click. At 8x
    # the visible crop is about 1/64 of the pixels.
    rr <- rv$img
    dh <- nrow(rr); dw <- ncol(rr)
    c0 <- max(1L, floor((cx - hw) / rv$w * dw)); c1 <- min(dw, ceiling((cx + hw) / rv$w * dw))
    r0 <- max(1L, floor((cy - hh) / rv$h * dh)); r1 <- min(dh, ceiling((cy + hh) / rv$h * dh))
    if (c1 >= c0 && r1 >= r0)
      graphics::rasterImage(rr[r0:r1, c0:c1, drop = FALSE],
                            (c0 - 1) / dw * rv$w, r1 / dh * rv$h,
                            c1 / dw * rv$w, (r0 - 1) / dh * rv$h,
                            interpolate = FALSE)

    P <- rv$pred
    # alignment guides: a faint grid on every landmark, a cross on the active one
    if (isTRUE(input$guides) && !is.null(P)) {
      ok <- stats::complete.cases(P)
      abline(v = P[ok, 1], col = adjustcolor("yellow", 0.25), lty = 3)
      abline(h = P[ok, 2], col = adjustcolor("yellow", 0.25), lty = 3)
      if (fin_row(P, rv$sel)) {
        abline(v = P[rv$sel, 1], col = "yellow", lwd = 1.5)
        abline(h = P[rv$sel, 2], col = "yellow", lwd = 1.5)
      }
    }
    # reference lines: body outline, belly line, eye vertical, eye circle
    if (isTRUE(input$showlines) && !is.null(P)) {
      path <- function(ids, ...) {
        ids <- ids[vapply(ids, function(i) fin_row(P, i), logical(1))]
        if (length(ids) > 1) lines(P[ids, 1], P[ids, 2], ...)
      }
      path(c(1, 5, 3, 16, 18, 19, 17, 4, 6, 1), col = "cyan", lwd = 2)      # outline
      path(c(9, 8, 11, 4), col = "grey85", lty = 3, lwd = 1)                # belly
      path(c(1, 9), col = "grey60", lwd = 1)                                # mouth height
      path(c(5, 13, 7, 14, 6, 8), col = "grey85", lty = 3, lwd = 1)         # eye vertical
      if (fin_row(P, 7) && fin_row(P, 13) && fin_row(P, 14)) {              # eye
        er <- sqrt(sum((P[13, ] - P[14, ])^2)) / 2
        th <- seq(0, 2 * pi, length.out = 60)
        lines(P[7, 1] + er * cos(th), P[7, 2] + er * sin(th),
              col = "grey85", lty = 3, lwd = 1)
      }
      ch <- axis_chain(P)                                                   # broken axis
      if (length(ch) > 2 && all(vapply(ch, function(i) fin_row(P, i), logical(1))))
        lines(P[ch, 1], P[ch, 2], col = "gold", lwd = 2, lty = 2)
    }
    # FISHMORPH geometry check (green = compliant). Computed segment by segment,
    # so a curved specimen with hinges placed is judged against the right axis.
    if (isTRUE(input$fishguides) && !is.null(P)) {
      fr <- seg_frames(P)
      if (!is.null(fr)) {
        tol <- 0.03 * fr$len; L <- rv$w + rv$h
        for (pr in list(list(p = c("1", "9"),   f = fr$head),
                        list(p = c("3", "4"),   f = fr$mid),
                        list(p = c("10", "11"), f = fr$mid))) {
          a <- P[pr$p[1], ]; b <- P[pr$p[2], ]
          if (all(is.finite(c(a, b)))) {
            s <- b - a; s <- s / sqrt(sum(s^2))
            dev <- abs(90 - acos(pmin(1, abs(sum(s * pr$f$u)))) * 180 / pi)
            segments(a[1], a[2], b[1], b[2],
                     col = if (dev < 8) "green" else "orange", lwd = 2)
          }
        }
        drawgrp <- function(ids, f, parallel) {
          pts <- P[ids, , drop = FALSE]
          pts <- pts[stats::complete.cases(pts), , drop = FALSE]
          if (nrow(pts) < 2) return(invisible())
          c0 <- colMeans(pts)
          d  <- if (parallel) f$u else f$n
          proj <- (pts - matrix(c0, nrow(pts), 2, byrow = TRUE)) %*%
                  (if (parallel) f$n else f$u)
          col <- if (diff(range(proj)) < tol) "green" else "orange"
          segments(c0[1] - d[1] * L, c0[2] - d[2] * L,
                   c0[1] + d[1] * L, c0[2] + d[2] * L, col = col, lwd = 1.5, lty = 2)
        }
        drawgrp(c("5", "13", "7", "14", "6", "8"), fr$head, parallel = FALSE)
        drawgrp(c("9", "8", "11"),                 fr$head, parallel = TRUE)
        drawgrp(c("11", "4"),                      fr$mid,  parallel = TRUE)
        # caudal: 16-17 must stay PARALLEL to 18-19 (a reference internal to the
        # caudal region, hence valid whatever the curvature of the body)
        if (all(is.finite(c(P["16", ], P["17", ], P["18", ], P["19", ])))) {
          s16 <- P["17", ] - P["16", ]; s18 <- P["19", ] - P["18", ]
          ac <- acos(pmin(1, abs(sum((s16 / sqrt(sum(s16^2))) *
                                     (s18 / sqrt(sum(s18^2))))))) * 180 / pi
          colc <- if (ac < 8) "green" else "orange"
          segments(P["16", 1], P["16", 2], P["17", 1], P["17", 2], col = colc, lwd = 2)
          segments(P["18", 1], P["18", 2], P["19", 1], P["19", 2], col = colc, lwd = 2)
        }
      }
    }
    # landmarks
    if (!is.null(P)) {
      lm_show <- c(seq_len(N_ANAT), SCALE_PTS)
      ok <- lm_show[vapply(lm_show, function(i) fin_row(P, i), logical(1))]
      if (length(ok)) {
        bg <- ifelse(ok %in% DERIVED_LM, "grey70",
                     ifelse(ok %in% SCALE_PTS, "#00a06a", "red"))
        points(P[ok, 1], P[ok, 2], pch = 21, bg = bg, col = "white", cex = 1.2)
        text(P[ok, 1], P[ok, 2], ok, col = "white", pos = 3, cex = 0.9)
      }
      if (fin_row(P, SCALE_PTS[1]) && fin_row(P, SCALE_PTS[2]))
        segments(P["20", 1], P["20", 2], P["21", 1], P["21", 2],
                 col = "#00a06a", lwd = 3)
      hs <- HINGES[vapply(HINGES, function(i) fin_row(P, i), logical(1))]
      if (length(hs)) {
        points(P[hs, 1], P[hs, 2], pch = 21, bg = "gold", col = "black", cex = 1.4)
        text(P[hs, 1], P[hs, 2], hs, col = "gold", pos = 3, cex = 0.9)
      }
      if (fin_row(P, rv$sel))
        points(P[rv$sel, 1, drop = FALSE], P[rv$sel, 2, drop = FALSE],
               col = "green", pch = 1, cex = 3, lwd = 3)   # active landmark
    }
  })

  ## ---- control table --------------------------------------------------------
  ## The 11 FISHMORPH segments as they stand on screen: pixels, ratio to the
  ## standard length (comparable across specimens, which raw pixels are not) and,
  ## when the scale bar is placed, millimetres. Bl is measured along the BROKEN
  ## axis, exactly as fishmorph_segments() does once landmark 22 is present.
  output$qc <- renderTable({
    req(rv$pred)
    P <- rv$pred
    blpx <- axis_len_px(P)
    mmpp <- mm_per_px(P)
    px <- vapply(names(SEG_PAIRS), function(nm) {
      ab <- SEG_PAIRS[[nm]]
      if (nm == "Bl") return(blpx)
      if (!(fin_row(P, ab[1]) && fin_row(P, ab[2]))) return(NA_real_)
      sqrt(sum((P[ab[2], ] - P[ab[1], ])^2))
    }, numeric(1))
    out <- data.frame(segment = names(SEG_PAIRS),
                      landmarks = vapply(SEG_PAIRS,
                        function(ab) paste(ab, collapse = "-"), character(1)),
                      px = px, ratio_Bl = px / blpx, row.names = NULL)
    if (is.finite(mmpp)) out$mm <- px * mmpp
    out
  }, digits = 3, na = "-")

  ## ---- progress and status --------------------------------------------------
  ## Counted in the unit the operator is actually working in: photographs of the
  ## CURRENT queue, and -- in repeat mode -- individuals that still owe repeats,
  ## not rows. A batch is finished when nothing is left in the queue, which is
  ## not the same statement as "n rows have been written".
  output$progress <- renderUI({
    n <- length(rv$q)
    photo <- if (n && rv$qi > 0L) PHOTO_CODES[rv$q[rv$qi]]
             else if (!is.null(rv$orig)) tools::file_path_sans_ext(basename(rv$orig))
             else "-"
    left <- if (n) {
      todo <- sum(!(PHOTO_CODES[rv$q] %in% done_codes()))
      sprintf("Photograph %d / %d &nbsp;&middot;&nbsp; %d still to do",
              rv$qi, n, todo)
    } else sprintf("The '%s' queue is empty.", cur_mode())
    mpp  <- mm_per_px(rv$pred)
    scal <- if (is.finite(mpp)) sprintf("%.4f mm/px", mpp)
            else "scale bar 20-21 not placed"
    rep_line <- if (isTRUE(rep_mode()))
      sprintf("<br>Repeats: %d / %d for this individual",
              length(saved_reps()), rep_target()) else ""
    div(class = "progressbox",
        HTML(sprintf("<b>%s</b><br>%s<br>Queue: <code>%s</code>%s<br>Scale: %s",
                     photo, left, cur_mode(), rep_line, scal)))
  })

  ## The session in one line: the paths were declared at the console and cannot
  ## be changed from here, so they are shown, not offered.
  output$session_info <- renderUI({
    HTML(sprintf(paste("Photographs <code>%s</code> (%d) &nbsp;&middot;&nbsp;",
                       "workbook <code>%s</code> &nbsp;&middot;&nbsp;",
                       "journal <code>%s</code> &nbsp;&middot;&nbsp;",
                       "operator <code>%s</code>"),
                 CFG$photo_dir, length(CFG$photos), basename(CFG$xlsx_path),
                 basename(journal$path), OPERATOR))
  })

  output$status <- renderText({
    if (is.null(rv$pred)) return("Load a photograph to begin.")
    st <- point_status(seq_len(N_ANAT))
    step <- if (!fin_row(rv$pred, 1L) || !fin_row(rv$pred, 2L))
      paste("Draw the axis first: 1, 22, 23, 2. The hinges go on the bends of a",
            "curved specimen, anywhere along the midline if it is straight.",
            "Every other landmark is placed for you as soon as LM2 is down.")
      else "Reposition each landmark in turn, then 'Save & next'."
    paste0(rv$msg, "\n\n", step,
           "\nActive landmark: ", point_label(rv$sel),
           sprintf(paste("\n%d placed by hand | %d still seeded | %d still",
                         "predicted | %d snapped | %d NA | %d not placed."),
                   sum(st == "clicked"), sum(st == "seeded"), sum(st == "predicted"),
                   sum(st == "adjusted"), sum(st == "na"), sum(st == "missing")))
  })

  ## ---- single-specimen export -----------------------------------------------
  fname <- reactive({
    save_id()                              # carries _rep<N> in repeat mode
  })
  output$dl_csv <- downloadHandler(
    filename = function() paste0(fname(), "_landmarks.csv"),
    content = function(f) {
      req(rv$pred)
      # Every WB_PTS row is kept, hinges included: an unmeasurable point is
      # written NA, so the scheme stays complete for downstream imputation.
      utils::write.csv(current_table(), f, row.names = FALSE) })
  output$dl_tps <- downloadHandler(
    filename = function() paste0(fname(), ".tps"),
    content = function(f) {
      req(rv$pred)
      con <- file(f, "w"); on.exit(close(con))
      # SAVE_PTS and not WB_PTS: a TPS file is read as a shape, and the entry
      # hinges 23-24 are not landmarks -- letting them into a configuration
      # would put two arbitrary points into every Procrustes fit downstream.
      keep <- SAVE_PTS[vapply(SAVE_PTS, function(i) fin_row(rv$pred, i), logical(1))]
      writeLines(sprintf("LM=%d", length(keep)), con)
      for (i in keep)                                       # TPS: bottom-left origin
        writeLines(sprintf("%.3f %.3f", rv$pred[i, 1], rv$h - rv$pred[i, 2]), con)
      writeLines(sprintf("IMAGE=%s",
                         if (!is.null(rv$orig)) basename(rv$orig) else ""), con)
      writeLines(sprintf("ID=%s", fname()), con) })
}

shinyApp(ui, server)
