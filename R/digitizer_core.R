# =============================================================================
# digitizer_core.R -- the shared core of the landmark digitizer
#
# Point scheme (21 FISHMORPH landmarks + scale bar + hinges), click orders,
# workbook layout of the campaign target, the FISHMORPH digitizing conventions
# checked on save (broken axis, extreme points 3/4, eye order, coincident
# points), the seeding geometry and the image helpers.
#
# Moved VERBATIM out of inst/shiny/landmarking_app/app.R in intraitR 1.39.0,
# first step of merging the two digitizers (intraitR::digitize_landmarks() and
# Rfishmorph::launch_fishmorph_digitizer()) into ONE application with two
# targets: the field campaign and the FISHMORPH reference workbook. Living in
# the package, this code is shared by both targets, and the tests reach it
# directly instead of parsing the app file.
#
# Contract: nothing here may read the session (CFG, OPERATOR, photos, worker,
# Shiny inputs). The app imports every name listed in .digitizer_core_names()
# into its own environment at start-up.
# =============================================================================

`%||%` <- function(x, y) if (is.null(x)) y else x

## ---- Landmark scheme --------------------------------------------------------
## 1-19  anatomical FISHMORPH landmarks (Brosse et al. 2021)
## 20-21 scale bar (a known real-world distance, `scale_mm`) -> mm_per_px
## 22    OPTIONAL body-curvature point on the midline. It is a genuine landmark:
##       fishmorph_segments() splits the standard length into (1-22) + (22-2)
##       when it is present, so a fish photographed with a bent body is not
##       under-measured. Exported like any other point.
## 23    DERIVED head-base point: the intersection of the line (1, 9) with the
##       line through 6 parallel to the head axis (1 -> 22). Segment 23-6 is
##       therefore parallel to the head axis and measures the axial distance
##       from the snout to the base of the head. Computed, never clicked.
## 24-25 EXTRA HINGES. Entry aids: they extend the broken axis to up to four
##       segments for strongly curved specimens, so that the FISHMORPH
##       perpendicularity conventions are applied segment by segment instead of
##       against a single straight axis. They are NOT anatomical landmarks and
##       have no place in a shape analysis -- but they ARE recorded, because
##       they define the frames every convention was applied in: without them a
##       specimen reopened for correction comes back with a straight axis and
##       the geometry silently stops matching the one it was digitized under.
##
## THIS IS THE FISHMORPH NUMBERING, the one Rfishmorph and the published
## database use. It is worth the alignment: landmark tables travel between the
## two packages, and a "23" that means the head base in one and an entry hinge
## in the other is the kind of divergence that produces two incomparable
## corpora without anyone noticing.
N_ANAT    <- 19L
SCALE_PTS <- c(20L, 21L)
CURVE_PT  <- 22L                       # a genuine landmark (Bl curvature correction)
HEAD_PT   <- 23L                       # derived: snout -> head base (see point23())
EXTRA_HINGES <- c(24L, 25L)            # entry aids: recorded, never analysed
HINGES    <- c(CURVE_PT, EXTRA_HINGES) # every point that can break the axis
## Two lists, because "recorded" and "is a landmark" are not the same statement:
##   SAVE_PTS : the landmarks proper (1-23) -- what a TPS file and any shape
##              analysis may contain.
##   WB_PTS   : everything written to the workbook and the journal, hinges
##              included. Reading the sheet for an analysis therefore means
##              taking the first 23 points, not every column that ends in _X.
SAVE_PTS  <- 1:23
WB_PTS    <- c(SAVE_PTS, EXTRA_HINGES)
N_TOT     <- 25L                       # rows carried in the coordinate matrix

## Automatically placed landmarks (not corrected by hand).
##  - standard mode: 1, 2 (clicks) + 8, 9, 11, 23 (geometrically derived)
##  - "pin" mode: 3, 4, 7, 10, 12, 15, 16, 18 are pinned on the calibration
##    clicks as well, so they also become automatic (the auto-advance skips them).
AUTO_LM     <- c(1L, 2L, 8L, 9L, 11L, 23L)
AUTO_LM_PIN <- c(1L, 2L, 3L, 4L, 7L, 8L, 9L, 10L, 11L, 12L, 15L, 16L, 18L, 23L)
## Points whose position is computed, never measured.
DERIVED_LM  <- c(8L, 9L, 11L, 23L)

## THE 11 FISHMORPH SEGMENTS, as landmark pairs. Same table as Rfishmorph's
## digitizer (.FM_PAIR_SEG), deliberately: the two applications measure the same
## protocol and must draw it the same way, or an operator moving between them
## reads two different pictures of one specimen.
##
## Bl is the exception in the drawing as it is in the computation: it follows the
## BROKEN axis 1 -> hinges placed -> 2 (axis_chain()), not the straight 1-2
## segment. Drawing it straight while fishmorph_segments() measures the arc would
## show the operator a length the analysis never uses.
PAIR_SEG <- list(
  Bl  = c(1L, 2L),   Bd  = c(3L, 4L),   Hd  = c(5L, 6L),
  Eh  = c(7L, 8L),   Mo  = c(1L, 9L),   PFi = c(10L, 11L),
  PFl = c(10L, 12L), Ed  = c(13L, 14L), Jl  = c(1L, 15L),
  CPd = c(16L, 17L), CFd = c(18L, 19L)
)
SEG_COLS <- grDevices::hcl.colors(length(PAIR_SEG), "Dark3")

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
##   1 -> 22 -> 24 -> 2 -> 3, 4, 7, 5, 6, 13, 14, 15, 10, 12, 16..19 -> 20 -> 21
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
    "23" = "LM23 -- head base (derived from 1, 6 and 9; never clicked)",
    "24" = "LM24 -- hinge (entry aid)",
    "25" = "LM25 -- hinge (entry aid)",
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
##
## `photo_hash` is the identity of the PHOTOGRAPH, as opposed to `photo_file`
## which is only its current name. A determination corrected renames the file --
## and, with it, the specimen code -- without moving a pixel; matching on the
## name alone therefore sent an already-measured fish back into the "new" queue,
## silently, to be measured a second time. See R/photo_identity.R.
##
## `reviewed`, `reviewed_by`, `review_date` and `collapse_rules` come from the
## Rfishmorph digitizer. The first three separate two statements the single
## `quality` score was conflating: how good the entry is, and whether anyone has
## actually looked at it -- a specimen can be checked AND poor, and that is the
## state a re-photographing list is built from. The fourth records the
## coincidences DECLARED on the specimen rather than leaving them to be inferred
## back from the geometry they produced.
WB_ID_COLS <- c("specimen", "individual", "replicate", "operator", "mode",
                "photo_file", "photo_hash", "img_w", "img_h", "quality",
                "reviewed", "reviewed_by", "review_date", "collapse_rules",
                "ruler_mm", "mm_per_px", "n_clicked", "n_seeded", "n_predicted",
                "n_adjusted", "n_na", "app_version", "timestamp")
WB_COORD_COLS <- as.vector(rbind(paste0(WB_PTS, "_X"), paste0(WB_PTS, "_Y")))
WB_COLS <- c(WB_ID_COLS, WB_COORD_COLS)

WB_CHR_COLS <- c("specimen", "individual", "operator", "mode", "photo_file",
                 "photo_hash", "reviewed", "reviewed_by", "review_date",
                 "collapse_rules", "app_version", "timestamp")
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

## PERPENDICULAR PAIRS, and the body segment each one is measured in. Every
## FISHMORPH depth is a distance taken PERPENDICULAR to the axis of the segment
## it belongs to: mouth height (1-9) on the head, body depth (3-4) and pectoral
## insertion (10-11) on the mid segment, caudal-peduncle depth (16-17) and
## caudal-fin depth (18-19) on the caudal segment 24 -> 2. The first point of
## each pair is the ANCHOR: the one the operator actually aims at.
##
## The caudal pairs used to be held PARALLEL TO EACH OTHER instead, with no tie
## to the axis. That constraint is satisfied by a pair that is oblique to
## 24 -> 2 -- both segments simply rotate together -- so CPd and CFd drifted off
## the perpendicular as soon as the axis was adjusted, and the depths they
## returned were hypotenuses rather than depths. The reference is the axis, not
## the other pair.
PERP_PAIRS <- list(c("1", "9"), c("3", "4"), c("10", "11"),
                   c("16", "17"), c("18", "19"))
PERP_FRAME <- c("head", "mid", "mid", "tail", "tail")

## Square one pair up: `keep` does not move; the other point takes its abscissa
## and keeps its own height, so the measured depth survives the correction (the
## partner slides ALONG the axis, it is not rotated about a midpoint).
square_pair <- function(P, f, keep, move) {
  if (!fin_row(P, keep) || !fin_row(P, move)) return(P)
  P[move, ] <- f$at(f$ax(P[keep, ]), f$pe(P[move, ]))
  P
}

## Re-impose the perpendicular convention on EVERY pair. `sel` is the landmark
## that has just moved: when it belongs to a pair it anchors that pair, so the
## click is never undone; every other pair is squared up on its own anchor.
## Applying all of them each time is what makes the convention hold when the
## FRAME changes rather than the points -- moving LM24 or LM2 rotates the caudal
## axis, and a depth that stays where it was is no longer a depth. The operation
## is idempotent, so a configuration already square is left untouched.
enforce_perp <- function(P, fr, sel = NULL) {
  s <- as.character(sel)
  for (k in seq_along(PERP_PAIRS)) {
    pr <- PERP_PAIRS[[k]]
    keep <- if (length(s) && (pr[2] %in% s)) pr[2] else pr[1]
    P <- square_pair(P, fr[[PERP_FRAME[k]]], keep, setdiff(pr, keep))
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
##   20-21  scale bar; 22 midline curvature point; 23 derived head base;
##          24-25 entry hinges.
## Compared with 3/4, therefore: 1, 2, 5, 6, 7, 10, 13, 14 -- every landmark
## that is an independent MEASUREMENT on the body outline.
EXTREME_EXCLUDE <- c(8L, 9L, 11L, 12L, 15L, 16L, 17L, 18L, 19L,
                     20L, 21L, 22L, 23L, 24L, 25L)
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
EXTREME_FRAME <- list(head = c(1L, 5L, 6L, 7L, 8L, 9L, 13L, 14L, 23L),
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
## `delta` (the overshoot, in pixels) and `kind` ("extreme").
## `skip` suspends the test on one side: a coincidence rule that puts LM4 on the
## mid axis makes the ventral half of the convention meaningless, and reporting
## it would turn a statement the operator made into an alert on every save.
extreme_violations <- function(P, tol_frac = EXTREME_TOL, skip = integer(0)) {
  g <- dorsal_heights(P); if (is.null(g)) return(NULL)
  if (!is.finite(g$len) || g$len <= 0) return(NULL)
  tol  <- max(EXTREME_FLOOR, tol_frac * g$len)
  cand <- EXTREME_CAND[is.finite(g$h[EXTREME_CAND])]
  if (!length(cand)) return(NULL)
  out <- list()
  if (!(3L %in% skip)) {
    d <- g$h[cand] - g$h[3L]                        # dorsal overshoot
    k <- which.max(d)
    if (d[k] > tol) out[[length(out) + 1L]] <-
      data.frame(point = 3L, culprit = cand[k], delta = unname(d[k]),
                 kind = "extreme", stringsAsFactors = FALSE)
  }
  if (!(4L %in% skip)) {
    d <- g$h[4L] - g$h[cand]                        # ventral overshoot
    k <- which.max(d)
    if (d[k] > tol) out[[length(out) + 1L]] <-
      data.frame(point = 4L, culprit = cand[k], delta = unname(d[k]),
                 kind = "extreme", stringsAsFactors = FALSE)
  }
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}

## ---- The eye vertical, in order ---------------------------------------------
## The six points 5, 13, 7, 14, 6, 8 are put on ONE vertical by the conventions
## (propagate_conventions aligns their abscissa in the head frame). That says
## nothing about their ORDER along it -- and the order is anatomy, not a choice:
## top of the head, top of the eye, centre of the eye, bottom of the eye, bottom
## of the head, body underside. Read from the back downwards, 5 > 13 > 7 > 14 >
## 6 > 8.
##
## This catches the failure no other check can, because every pair stays
## internally consistent: with 13 and 14 exchanged -- the eye clicked
## bottom-first -- `Ed` (13-14) keeps its exact length while `Eh` (7-8) silently
## measures to the wrong edge of the eye. And 5 no longer topping the group
## under-measures `Hd` exactly as a misplaced LM3 under-measures `Bd`.
##
## Settled on the data, like the extreme-point rule. Over the T-26 corpus the
## expected order already holds for 98.6 % of the 1,036 digitized configurations
## (13 above 5 in 9 specimens, 0.87 %, the same nine as "5 does not top the
## group"; 7 above 13 in 4; 14 above 7 in 1; 8 above 6 in 1) and for 100 % of
## the 250 repeatability configurations. What is left is gross error, not noise.
EYE_ORDER <- c(5L, 13L, 7L, 14L, 6L, 8L)            # dorsal -> ventral

## Same schema as extreme_violations(), with `kind = "order"`: `point` is the
## one that should sit ABOVE, `culprit` the one found above it, `delta` the
## inversion in pixels.
eye_order_violations <- function(P, tol_frac = EXTREME_TOL) {
  g <- dorsal_heights(P); if (is.null(g)) return(NULL)
  if (!is.finite(g$len) || g$len <= 0) return(NULL)
  tol <- max(EXTREME_FLOOR, tol_frac * g$len)
  pts <- EYE_ORDER[EYE_ORDER <= length(g$h)]
  h   <- g$h[pts]
  ok  <- is.finite(h)
  if (sum(ok) < 2L) return(NULL)
  out <- list()
  # 1. the top of the head must top the whole group
  if (ok[1]) {
    d <- h[-1] - h[1]
    d[!is.finite(d)] <- -Inf
    k <- which.max(d)
    if (is.finite(d[k]) && d[k] > tol) out[[length(out) + 1L]] <-
      data.frame(point = pts[1], culprit = pts[-1][k], delta = unname(d[k]),
                 kind = "order", stringsAsFactors = FALSE)
  }
  # 2. consecutive pairs, over the points actually placed: a landmark left out
  #    must be stepped over, not treated as breaking the chain.
  sq <- pts[ok]; hh <- h[ok]
  for (i in seq_len(length(sq) - 1L)) {
    d <- hh[i + 1L] - hh[i]                         # > 0 = the lower one is above
    if (d > tol) out[[length(out) + 1L]] <-
      data.frame(point = sq[i], culprit = sq[i + 1L], delta = unname(d),
                 kind = "order", stringsAsFactors = FALSE)
  }
  if (!length(out)) return(NULL)
  out <- do.call(rbind, out)
  # "5 tops the group" and the first consecutive pair can name one inversion
  # twice; one line per (point, culprit) is enough.
  out[!duplicated(out[, c("point", "culprit")]), , drop = FALSE]
}

## Everything checked on save, in one table. Extremes first, deliberately: they
## are the only ones the automatic correction can repair -- an inversion is
## repaired by measuring again, never by moving a point.
convention_violations <- function(P, tol_frac = EXTREME_TOL, skip = integer(0)) {
  v <- rbind(extreme_violations(P, tol_frac, skip = skip),
             eye_order_violations(P, tol_frac))
  if (is.null(v) || !nrow(v)) NULL else v
}

## ---- LM23: the head base, derived ------------------------------------------
## The intersection of the line (1, 9) -- the mouth-height line -- with the line
## through 6 parallel to the HEAD axis (1 -> 22, falling back to the first
## placed hinge, then to the chord 1 -> 2). Segment 23-6 is therefore parallel
## to the head axis, and 1 -> 23 measures the axial distance from the snout to
## the base of the head.
##
## Frame-agnostic: it is built from the landmarks themselves, so it holds in
## image pixels, on a tilted photograph and on a mirrored one. It returns NA
## when the construction is degenerate -- 1 and 9 coincident (a mouth on the
## ventral profile), or the two directions parallel -- because a derived point
## with a degenerate input has no value, and inventing one would be worse than
## leaving it empty. The `Mo = 0` rule below is what then puts 23 on 1.
point23 <- function(P) {
  need <- c(1L, 6L, 9L)
  if (!all(vapply(need, function(i) fin_row(P, i), logical(1))))
    return(c(NA_real_, NA_real_))
  d1 <- P[9L, ] - P[1L, ]                       # direction of the line (1, 9)
  tip <- if (fin_row(P, CURVE_PT)) P[CURVE_PT, ]
         else if (fin_row(P, EXTRA_HINGES[1])) P[EXTRA_HINGES[1], ]
         else if (fin_row(P, 2L)) P[2L, ] else NULL
  if (is.null(tip)) return(c(NA_real_, NA_real_))
  d2 <- tip - P[1L, ]                           # direction of the head axis
  cr <- d1[1] * d2[2] - d1[2] * d2[1]
  if (!is.finite(cr) || abs(cr) < 1e-9) return(c(NA_real_, NA_real_))
  w <- P[6L, ] - P[1L, ]
  a <- (w[1] * d2[2] - w[2] * d2[1]) / cr
  as.numeric(P[1L, ] + a * d1)
}
## Recomputed after every change of the configuration, exactly like the ventral
## points: 23 is a function of 1, 6, 9 and the head axis, so it has no business
## surviving a move of any of them.
derive_head_pt <- function(P) {
  if (is.null(P) || nrow(P) < HEAD_PT) return(P)
  P[HEAD_PT, ] <- point23(P)
  P
}

## ---- Coincident landmarks: a measurement of zero ----------------------------
## Some segments are legitimately ZERO on some species, and a zero is a
## measurement like any other -- not a missing value and not a placement error.
## The FISHMORPH heights read from the ventral profile vanish when the structure
## sits ON that profile (`OGp = 0` for a mouth at the bottom, `PFv = 0` for a
## pectoral fin inserted on the belly); the bottom of the head can be exactly the
## body underside; an eye reaching the top of the head puts LM5 on LM13.
##
## NOTHING IS DELETED. Both landmarks keep a position, both are drawn on the
## photograph and both are written to the workbook -- one simply takes the
## coordinates of the other, so the segment between them measures zero. A
## coincidence is a measurement; an absence is `NA`, and the two must not be
## confused downstream.
##
## Clicking two landmarks onto the same pixel would express the same thing but
## does not SURVIVE: the conventions re-derive the ventral points on the belly
## line and enforce_head_order() re-separates the eye group by its margin, so the
## zero is undone at the next click. These rules are therefore declared once per
## specimen and RE-APPLIED after every propagation, which is what makes a zero a
## stable statement about the fish rather than a position that drifts.
##
## Which landmark moves is a protocol decision, not an aesthetic one, and it is
## not the same for every rule. For the mouth the fixed point is LM1, the snout,
## an anatomical landmark that must not move. For the two ventral rules it is
## the BELLY LINE that holds: LM8 and LM11 are its intersections with the eye and
## the pectoral verticals, so the head bottom (LM6) and the fin insertion (LM10)
## come onto them rather than the reverse -- the ventral profile is a global fit,
## steadier than a single click. And for the eye at the top of the head, LM5 (the
## head outline) comes onto LM13, because moving LM13 would change `Ed`, the eye
## diameter, which is a measurement in its own right.
## A rule is a list of MOVES, each `c(from, to)`: one rule may have to move more
## than one landmark, and not necessarily onto the same partner. `LM6 = LM8` is
## the case that forces it. LM23 is the intersection of the line (1, 9) with the
## parallel to the head axis through LM6, and the belly line {9, 8, 11} is
## itself parallel to that axis -- so the moment LM6 sits ON the belly line,
## that parallel IS the belly line and its intersection with (1, 9) is LM9.
## LM23 = LM9 follows; it is a consequence, not an extra convention. Stating it
## in the rule makes it hold even where the derivation is degenerate, which is
## exactly the case when `Mo = 0` is on as well.
COLLAPSE_RULES <- list(
  Mo  = list(moves = list(c(9L, 1L), c(23L, 1L)),
             label = "Mo = 0 (mouth on the belly)",
             tip = "LM9 and LM23 take the coordinates of LM1: mouth height nil, OGp = 0"),
  Hd6 = list(moves = list(c(6L, 8L), c(23L, 9L)),
             label = "LM6 = LM8 (head bottom on the belly)",
             tip = paste("LM6 takes the coordinates of LM8: the head ends on the",
                         "ventral profile -- and LM23 follows LM9, since the",
                         "parallel through LM6 is then the belly line itself")),
  PFi = list(moves = list(c(10L, 11L)),
             label = "PFi = 0 (pectoral on the belly)",
             tip = "LM10 takes the coordinates of LM11: insertion on the ventral profile, PFv = 0"),
  EyeTop = list(moves = list(c(5L, 13L)),
                label = "LM5 = LM13 (eye at the head top)",
                tip = "LM5 takes the coordinates of LM13: the eye reaches the dorsal profile"),
  ## A second KIND of rule. The partner is not a landmark but a LINE -- the mid
  ## axis 22 -> 24 -- so the statement cannot be expressed as a copy of
  ## coordinates: LM4 is PROJECTED perpendicularly onto it. It keeps the abscissa
  ## the operator clicked along the axis and surrenders only its height. LM4
  ## being the master of the belly line, LM11 and then LM8 and LM9 follow it.
  Bd4 = list(moves = list(), project = 4L,
             label = "LM4 on 22-24 (belly on the mid axis)",
             tip = paste("LM4 is projected perpendicularly onto the line",
                         "(LM22, LM24): it keeps its abscissa along the axis,",
                         "its height becomes zero, and LM11 then LM8/LM9 follow"))
)

## ---- projecting onto the mid axis -------------------------------------------
## The mid frame is taken from seg_frames() rather than rebuilt from LM22 and
## LM24 directly, so a projected landmark sits at height zero in the VERY frame
## the conventions then work in -- hinge fallbacks included. Rebuilding it
## independently would let derive_ventral() re-derive the belly line in a frame
## where LM4 is no longer on the axis.
project_mid <- function(P, pt) {
  if (!fin_row(P, pt)) return(P)
  fr <- seg_frames(P); if (is.null(fr)) return(P)
  P[pt, ] <- fr$mid$at(fr$mid$ax(P[pt, ]), 0)
  P
}
## Distance from a landmark to that axis, in pixels (NA when undefined): what a
## projection rule is read back by on a specimen reopened later.
dist_mid <- function(P, pt) {
  if (!fin_row(P, pt)) return(NA_real_)
  fr <- seg_frames(P); if (is.null(fr)) return(NA_real_)
  abs(fr$mid$pe(P[pt, ]))
}
## Below this distance a landmark IS on the axis: the coordinates written to the
## workbook are the projection itself, so only rounding separates them from it.
## A real belly sits at half the body depth from the midline -- some 12 % of the
## standard length -- so the band is empty by orders of magnitude.
PROJ_TOL <- 0.5

## Apply the active rules, move by move and in order. A move whose reference is
## not placed is skipped: a zero is only meaningful once the landmark it is
## measured from exists. Order matters when several rules are on -- with `Mo`
## and `LM6 = LM8` both active, LM9 goes onto LM1 first, so LM23 then follows
## LM9 to the same place.
## `kinds` selects which half of a rule is applied. The PROJECTIONS have to act
## BEFORE the conventions -- LM4 drives the belly line, so LM11, LM8 and LM9 must
## be re-derived from the projected LM4 -- while the copies act after them, since
## the conventions are precisely what would undo a copy.
apply_collapse <- function(P, active, kinds = c("move", "project")) {
  if (is.null(P) || !length(active)) return(P)
  for (nm in intersect(active, names(COLLAPSE_RULES))) {
    r <- COLLAPSE_RULES[[nm]]
    if ("project" %in% kinds && !is.null(r$project))
      for (pt in r$project) P <- project_mid(P, pt)
    if ("move" %in% kinds)
      for (mv in r$moves)
        if (mv[1] <= nrow(P) && fin_row(P, mv[2])) P[mv[1], ] <- P[mv[2], ]
  }
  P
}
## The landmarks a set of rules places -- their status has to say they were
## placed by a rule and not pointed at. The two families are separable, and the
## distinction is not cosmetic: a landmark COPIED onto another owes it
## everything, so the rule takes over its position; a PROJECTED landmark keeps
## the abscissa that was clicked and only gives up its height, so it must stay
## in `edited` -- dropping it would send LM4 back to its seed along the body at
## the next reseed.
collapse_points <- function(active, kinds = c("move", "project")) {
  if (!length(active)) return(integer(0))
  pts <- unlist(lapply(COLLAPSE_RULES[intersect(active, names(COLLAPSE_RULES))],
                       function(r) c(
                         if ("move" %in% kinds)
                           vapply(r$moves, function(m) m[1], integer(1))
                         else integer(0),
                         if ("project" %in% kinds && !is.null(r$project))
                           as.integer(r$project) else integer(0))),
                use.names = FALSE)
  if (is.null(pts)) integer(0) else pts
}
## Read the rules back off the coordinates of a specimen saved earlier. A copy
## rule leaves two coincident landmarks; a PROJECTION leaves no such pair, only
## a landmark lying on a line, so it has to be recognized geometrically.
collapse_detect <- function(P, tol = PROJ_TOL) {
  if (is.null(P)) return(character(0))
  names(COLLAPSE_RULES)[vapply(COLLAPSE_RULES, function(r) {
    ok_mv <- length(r$moves) == 0L || all(vapply(r$moves, function(mv)
      fin_row(P, mv[1]) && fin_row(P, mv[2]) &&
        isTRUE(all.equal(unname(P[mv[1], ]), unname(P[mv[2], ]),
                         tolerance = 1e-6)), logical(1)))
    ok_pj <- is.null(r$project) || {
      d <- vapply(r$project, function(pt) dist_mid(P, pt), numeric(1))
      all(is.finite(d)) && all(d <= tol)
    }
    ## a rule with neither a move nor a projection is not "detected" by default
    (length(r$moves) > 0L || !is.null(r$project)) && ok_mv && ok_pj
  }, logical(1))]
}
## The extreme-point convention a rule deliberately SUSPENDS. Declaring LM4 on
## the mid axis states that the ventral profile is not what LM4 reads on this
## specimen; the ventral half of the 3/4 test would then flag every landmark
## below the axis (LM6, LM10, LM14 ...) on every save -- the rule working, not an
## error. The dorsal half, on LM3, is untouched and still holds.
collapse_skip_extreme <- function(active) {
  if ("Bd4" %in% active) 4L else integer(0)
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
  # (1) perpendicular pairs, caudal ones included: the partner keeps its height
  #     and takes the anchor's abscissa, in the frame of its own body segment
  P <- enforce_perp(P, fr, sel)
  # (2) belly line and derived ventral points, recomputed from their anchors.
  #     Unconditional: moving LM4 (the master), LM1, LM7 or LM10 -- or a hinge,
  #     which redefines the frames themselves -- all shift the derived points.
  P <- derive_ventral(P, fr)
  # (3) head vertical order, re-imposed as soon as a head point moves
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
## once the axis 1 -> 22 -> 24 -> 2 is placed, every remaining landmark is put
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
  # Every depth back onto the perpendicular of its own segment: LM4 under LM3,
  # LM17 under LM16, LM19 under LM18. This is the path a RE-SEED takes, and a
  # re-seed is exactly what a click on LM2 or on a hinge triggers -- the caudal
  # pairs are hand-placed, hence kept, so without this they would keep the
  # orientation they had under the PREVIOUS axis.
  P <- enforce_perp(P, fr)
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


# Names the app imports at start-up (see the top of
# inst/shiny/landmarking_app/app.R). Kept explicit so a test can check that
# every one exists and that the app does not redefine any of them.
.digitizer_core_names <- function() c(
  "N_ANAT",
  "SCALE_PTS",
  "CURVE_PT",
  "HEAD_PT",
  "EXTRA_HINGES",
  "HINGES",
  "SAVE_PTS",
  "WB_PTS",
  "N_TOT",
  "AUTO_LM",
  "AUTO_LM_PIN",
  "DERIVED_LM",
  "PAIR_SEG",
  "SEG_COLS",
  "ANAT_ORDER",
  "ADVANCE_ORDER",
  "next_point",
  "empty_coords",
  "PINNED_CLICKS",
  "pinned_clicks",
  "point_label",
  "REP_RE",
  "clean_operator",
  "make_id",
  "base_code",
  "rep_of",
  "WB_ID_COLS",
  "WB_COORD_COLS",
  "WB_COLS",
  "WB_CHR_COLS",
  "wb_empty",
  "wb_normalise",
  "wb_read_sheet",
  "bias_summary",
  "SEG_PAIRS",
  "fin_row",
  "body_axis",
  "axis_chain",
  "axis_len_px",
  "make_frame",
  "seg_frames",
  "enforce_head_order",
  "belly_align",
  "derive_ventral",
  "PERP_PAIRS",
  "PERP_FRAME",
  "square_pair",
  "enforce_perp",
  "EXTREME_EXCLUDE",
  "EXTREME_CAND",
  "EXTREME_TOL",
  "EXTREME_FLOOR",
  "EXTREME_FRAME",
  "frame_of",
  "dorsal_heights",
  "extreme_violations",
  "EYE_ORDER",
  "eye_order_violations",
  "convention_violations",
  "point23",
  "derive_head_pt",
  "COLLAPSE_RULES",
  "project_mid",
  "dist_mid",
  "PROJ_TOL",
  "apply_collapse",
  "collapse_points",
  "collapse_detect",
  "collapse_skip_extreme",
  "fix_extremes",
  "propagate_conventions",
  "FM_MEDIAN_RATIOS",
  "SEED_DEFAULTS",
  "chain_at",
  "seed_configuration",
  "apply_conventions",
  "read_image",
  "downscale",
  "flip_array")
