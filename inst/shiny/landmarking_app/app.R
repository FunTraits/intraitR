## =============================================================================
## app.R -- Interactive predictor-assisted landmarking (intraitR)
##
## Workflow: load a photograph (or a folder of photographs) -> a handful of
## calibration clicks (snout, caudal-fin basis, a dorsal orientation point and
## the two scale-bar points) -> the ml-morph shape predictor proposes the 19
## anatomical FISHMORPH landmarks -> manual review and correction -> export to
## CSV / tpsDig.
##
## Launched from the package with intraitR::digitize_landmarks(), which locates
## the ml-morph resources and sets the INTRAITR_MLMORPH_* environment variables
## read below, then calls shiny::runApp() on this folder. The app also runs
## standalone with shiny::runApp("ml_morph/landmarking_app"), in which case it
## falls back to paths relative to the parent "ml_morph" folder.
##
## Requires: a Python environment (.venv_mlmorph) with dlib/opencv, a trained
## predictor (mlmorph_run_*/predictor.dat) and the aligned training set
## (mlmorph_dataset_aligned) inside the ml-morph directory. See ml_morph/README.md.
##
## R dependencies: shiny, jpeg, png (magick optional, for images whose real
## format does not match their file extension).
## =============================================================================

library(shiny)

## shiny's %||% is not exported by every version this app may run under.
`%||%` <- function(x, y) if (is.null(x)) y else x

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
## Autosave: a WRITABLE path (the app folder is read-only once the package is
## installed in the library). Set by the launcher (INTRAITR_MLMORPH_AUTOSAVE);
## otherwise in the current working directory.
AUTOSAVE <- {
  a <- Sys.getenv("INTRAITR_MLMORPH_AUTOSAVE", "")
  if (!nzchar(a)) a <- file.path(getwd(), "intraitR_landmarking_autosave.csv")
  a
}

## ---- Landmark scheme --------------------------------------------------------
## 1-19  anatomical FISHMORPH landmarks (Brosse et al. 2021)
## 20-21 scale bar (a known real-world distance, `scale_mm`) -> mm_per_px
## 22    OPTIONAL body-curvature point on the midline. It is a genuine landmark:
##       fishmorph_segments() splits the standard length into (1-22) + (22-2)
##       when it is present, so a fish photographed with a bent body is not
##       under-measured. Exported like any other point.
## 23-24 EXTRA HINGES. Entry aids only: they extend the broken axis to up to
##       four segments for strongly curved specimens, so that the FISHMORPH
##       perpendicularity conventions are applied segment by segment instead of
##       against a single straight axis. They are NEVER exported.
N_ANAT    <- 19L
SCALE_PTS <- c(20L, 21L)
CURVE_PT  <- 22L                       # exported (Bl curvature correction)
EXTRA_HINGES <- c(23L, 24L)            # entry aids, never exported
HINGES    <- c(CURVE_PT, EXTRA_HINGES) # every point that can break the axis
SAVE_PTS  <- 1:22                      # rows written to CSV / TPS
N_TOT     <- 24L                       # rows carried in the coordinate matrix

## Automatically placed landmarks (not corrected by hand).
##  - standard mode: 1, 2 (clicks) + 8, 9, 11 (geometrically derived)
##  - "pin" mode: 3, 4, 7, 10, 12, 15, 16, 18 are pinned on the calibration
##    clicks as well, so they also become automatic (the auto-advance skips them).
AUTO_LM     <- c(1L, 2L, 8L, 9L, 11L)
AUTO_LM_PIN <- c(1L, 2L, 3L, 4L, 7L, 8L, 9L, 10L, 11L, 12L, 15L, 16L, 18L)
## Points whose position is computed, never measured.
DERIVED_LM  <- c(8L, 9L, 11L)

## Anatomical points in numeric order, minus the three derived ones.
ANAT_ORDER <- setdiff(3:19, DERIVED_LM)

## ONE auto-advance sequence, from the axis to the scale bar. There is no
## separate calibration list: every point is an ordinary landmark, and the ones
## the predictor needs (LM1, LM2, the dorsal point LM3, the scale bar) are
## simply the ones that come first.
##
##   1 -> 22 -> 23 -> 2 -> 3 ... 19 -> 20 -> 21
##
## The axis comes FIRST and complete: snout, the two hinges, caudal basis. Every
## convention downstream is expressed in the frame of a body segment, so
## defining the axis last would mean laying out every other point against the
## wrong reference. On a straight fish the hinges go anywhere along the midline:
## a hinge on the line leaves the chain straight, and LM22 then also gives
## fishmorph_segments() its curvature correction for free.
##
## Then the anatomical landmarks in plain numeric order, and finally the scale
## bar. The three derived points (8, 9, 11) are the only numbers skipped: they
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
## =============================================================================
ui <- fluidPage(
  # holding the right button down on the photo pans the view (sends deltas to Shiny)
  tags$head(tags$script(HTML(paste(
    "(function(){var dg=false,lx=0,ly=0,adx=0,ady=0,c=0,raf=null;",
    "function el(){return document.getElementById('img');}",
    "function flush(){raf=null;if(adx===0&&ady===0)return;Shiny.setInputValue('pan',{dx:adx,dy:ady,n:++c},{priority:'event'});adx=0;ady=0;}",
    "document.addEventListener('contextmenu',function(e){var m=el();if(m&&m.contains(e.target))e.preventDefault();});",
    "document.addEventListener('mousedown',function(e){var m=el();if(m&&m.contains(e.target)&&e.button===2){dg=true;lx=e.clientX;ly=e.clientY;e.preventDefault();}});",
    "document.addEventListener('mousemove',function(e){if(!dg)return;var m=el();if(!m)return;var r=m.getBoundingClientRect();adx+=(e.clientX-lx)/r.width;ady+=(e.clientY-ly)/r.height;lx=e.clientX;ly=e.clientY;if(!raf)raf=requestAnimationFrame(flush);});",
    "document.addEventListener('mouseup',function(e){if(e.button===2){dg=false;if(!raf)raf=requestAnimationFrame(flush);}});",
    "})();", sep = "\n"))),
    # the action bar is one row: kill the form-group margin the selectize would
    # otherwise add, and keep the checkbox labels on the baseline of the buttons
    tags$style(HTML(paste0(
      ".actionbar .form-group{margin-bottom:0;}",
      ".actionbar .btn{margin-right:3px;}",
      ".actionbar .selectize-control{margin-bottom:0;}",
      ".phasebar .form-group{margin-bottom:0;}",
      ".phasebar .checkbox{margin:0;}")))),
  titlePanel("Predictor-assisted landmarking -- ml-morph"),
  sidebarLayout(
    sidebarPanel(width = 3,
      uiOutput("progress"),
      tags$hr(),
      tags$strong("Photograph folder"),
      textInput("photo_dir", NULL, placeholder = "folder path..."),
      actionButton("load_dir", "Load folder", class = "btn-primary"),
      helpText("Navigation and the save actions live in the action bar above",
               "the photograph, where the eye already is."),
      tags$hr(),
      fileInput("photo", "...or a single photograph (jpg/png)",
                accept = c(".jpg", ".jpeg", ".png")),
      textInput("specimen_id", "Specimen code", ""),
      radioButtons("quality", "Quality score (1 = very good -> 5 = poor)",
                   choices = c("1" = 1, "2" = 2, "3" = 3, "4" = 4, "5" = 5),
                   selected = 3, inline = TRUE),
      if (length(PRED_CHOICES))
        selectInput("pred", "Model", choices = PRED_CHOICES)
      else div(style = "color:red", "No predictor.dat found in ml_morph/"),
      numericInput("scale_mm", "Scale-bar distance 20-21 (mm)", 10, min = 0),
      checkboxInput("pin", "Pin the reliable landmarks (LM1,2,3,4,7) on the clicks",
                    value = FALSE),
      tags$hr(),
      tags$strong("Display"),
      checkboxInput("showlines", "Reference lines (outline / belly / eye)", value = TRUE),
      checkboxInput("guides", "Alignment guides", value = FALSE),
      checkboxInput("fishguides", "FISHMORPH geometry check", value = FALSE),
      radioButtons("flip_mode", "Flip photograph (+ landmarks)",
                   c("None" = "none", "Horizontal" = "h", "Vertical" = "v", "180" = "hv"),
                   inline = TRUE),
      radioButtons("flip_disp", "Flip the photograph ONLY (landmarks fixed)",
                   c("None" = "none", "Horizontal" = "h", "Vertical" = "v", "180" = "hv"),
                   inline = TRUE),
      helpText("The first option moves the landmarks with the image, so points",
               "already placed stay on the specimen. The second changes the",
               "display only -- useful when loaded points are mirrored relative",
               "to the photograph. It persists from one photograph to the next."),
      tags$hr(),
      # --- review measurements already made (CSV specimen,landmark,X,Y[,mm_per_px]) ---
      tags$strong("Review existing measurements"),
      fileInput("measures_file", "Measurement table (CSV)",
                accept = c(".csv", ".tsv", ".txt")),
      uiOutput("load_specimen_ui"),
      helpText("Load a photograph, then pick the matching specimen to check or",
               "correct its landmarks. Coordinates are expected in image pixels",
               "(the same as the export). Keep 'Flip photograph' on None."),
      tags$hr(),
      tags$strong("This specimen:"),
      downloadButton("dl_csv", "CSV"), downloadButton("dl_tps", "TPS"),
      tags$hr(),
      tags$strong("Multi-specimen table"),
      textOutput("saved_info"),
      downloadButton("dl_all", "Export all measurements"),
      actionButton("clear_all", "Clear the table"),
      # --- seeding, last: set once for a batch, then rarely touched ------------
      tags$hr(),
      tags$strong("Seed (initial placement)"),
      helpText("Once the axis 1 - 22 - 23 - 2 is placed, every other landmark is",
               "put at the MEDIAN FISHMORPH proportion of the body, so there is",
               "only repositioning left to do. These sliders set what the segment",
               "ratios do not fix: where a segment sits along the body, how it",
               "splits dorsal/ventral, and two fin angles. A point you have moved",
               "is never re-seeded."),
      checkboxInput("flipdorsal", "Flip dorsal / ventral", FALSE),
      actionButton("reseed", "Re-seed the unplaced landmarks"),
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
      sliderInput("ang_Jl",  "Jaw angle",              -30, 90, 20,   1)
    ),
    mainPanel(width = 9,
      # ---- action bar, directly above the photograph -------------------------
      # Every action taken once per specimen sits on one row, where the eye
      # already is: navigating the queue, declaring a point unmeasurable, saving.
      # Nothing here requires a trip back to the side panel mid-specimen.
      div(class = "actionbar", style = "margin-bottom:6px;",
        actionButton("prev_photo", "< Previous"),
        actionButton("next_photo", "Next >"),
        span(style = "display:inline-block;width:14px;"),
        actionButton("set_na", "Mark NA"),
        actionButton("clear_pt", "Clear point"),
        span(style = "display:inline-block;width:14px;"),
        actionButton("save_specimen", "Save & next", class = "btn-primary"),
        actionButton("skip", "Skip"),
        span(style = "display:inline-block;width:14px;"),
        actionButton("flush", "Write the table"),
        span(style = "display:inline-block;width:14px;"),
        div(style = "display:inline-block;vertical-align:middle;min-width:280px;",
            selectizeInput("goto_file", NULL, choices = NULL, selected = NULL,
                           width = "280px",
                           options = list(placeholder = "Jump to a photograph...")))),
      uiOutput("click_help"),
      uiOutput("auto_help"),
      uiOutput("phase_ui"),     # phase-dependent controls (Predict / corrections)
      uiOutput("lm_buttons"),   # active-landmark bar, above the photograph
      # ---- view bar, immediately above the photograph ------------------------
      # Zoom belongs next to what it zooms: at high magnification the operator
      # alternates between placing a point and re-framing, and a trip to the
      # side panel between the two breaks that loop.
      div(class = "actionbar", style = "margin-bottom:4px;",
        actionButton("zoom_in", "Zoom +"),
        actionButton("zoom_out", "Zoom -"),
        actionButton("zoom_reset", "Whole view"),
        span(style = "display:inline-block;width:14px;"),
        div(style = "display:inline-block;vertical-align:middle;",
            selectInput("dispmax", NULL,
                        choices = c("Display 800 px (fastest)"  = 800,
                                    "Display 1200 px"           = 1200,
                                    "Display 1600 px"           = 1600,
                                    "Display 2400 px"           = 2400,
                                    "Display full resolution"   = 0),
                        selected = 1200, width = "215px")),
        span(style = "font-size:12px;color:#666;margin-left:10px;",
             "Right-click and drag to pan; double-click for the whole view;",
             "zoom centres on the active landmark. No wheel zoom.")),
      plotOutput("img", click = "click",
                 dblclick = "img_dblclick", height = "700px"),
      fluidRow(
        column(7,
               h5("Control: FISHMORPH segments as digitized"),
               tableOutput("qc")),
        column(5, verbatimTextOutput("status"))
      )
    )
  )
)

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
    saved = NULL,                       # cumulative table of every specimen done
    na = integer(0),                    # landmarks declared non-measurable
    edited = integer(0),                # landmarks moved by hand this session
    zoom = 1, cx = NULL, cy = NULL,     # zoom state / view centre
    dir_files = NULL, dir_i = 0L,       # photograph folder + current index
    loaded = NULL, loaded_sel = NULL)   # measurement table being reviewed

  ## Bring a saved table up to the current schema. Tables written before LM22
  ## (the curvature point) was exported hold 21 rows per specimen; mixing them
  ## with 22-row specimens would make read_landmarks_csv() refuse the file,
  ## since it requires one common landmark configuration. Missing rows are added
  ## as NA rather than dropped: an absent curvature point means "straight fish",
  ## which fishmorph_segments() already handles.
  normalise_saved <- function(df) {
    if (is.null(df) || !nrow(df) || !all(c("specimen", "landmark") %in% names(df)))
      return(df)
    for (cc in c("mm_per_px", "note", "status"))
      if (!cc %in% names(df)) df[[cc]] <- if (cc == "status") NA_character_ else NA
    full <- do.call(rbind, lapply(split(df, df$specimen), function(d) {
      miss <- setdiff(SAVE_PTS, d$landmark)
      if (!length(miss)) return(d[d$landmark %in% SAVE_PTS, , drop = FALSE])
      add <- d[rep(1L, length(miss)), , drop = FALSE]
      add$landmark <- miss; add$X <- NA_real_; add$Y <- NA_real_
      add$status <- "missing"
      rbind(d[d$landmark %in% SAVE_PTS, , drop = FALSE], add)
    }))
    full <- full[order(full$specimen, full$landmark), , drop = FALSE]
    rownames(full) <- NULL
    full
  }

  # Resume: reload the autosave file if one exists
  if (file.exists(AUTOSAVE))
    try(rv$saved <- normalise_saved(
      utils::read.csv(AUTOSAVE, stringsAsFactors = FALSE)), silent = TRUE)

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
    rv$seeded <- integer(0)
    rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL
  }

  observeEvent(input$photo, {
    rv$orig <- input$photo$datapath
    rv$dir_files <- NULL; rv$dir_i <- 0L        # single photo -> leave folder mode
    updateSelectizeInput(session, "goto_file", choices = character(0), server = TRUE)
    updateTextInput(session, "specimen_id",
                    value = tools::file_path_sans_ext(input$photo$name))
    load_working()
    rv$msg <- "Image loaded. Click the snout (point 1)."
  })

  ## ---- folder navigation ----------------------------------------------------
  load_dir_photo <- function(i) {
    n <- length(rv$dir_files)
    if (!n) return()
    i <- max(1L, min(as.integer(i), n)); rv$dir_i <- i
    p <- rv$dir_files[i]
    rv$orig <- p
    updateTextInput(session, "specimen_id",
                    value = tools::file_path_sans_ext(basename(p)))
    updateSelectizeInput(session, "goto_file", selected = i)
    load_working()
    rv$msg <- sprintf("Photograph %d/%d loaded. Click the snout (point 1).", i, n)
  }
  observeEvent(input$load_dir, {
    d <- trimws(input$photo_dir)
    if (!nzchar(d) || !dir.exists(d)) { notify("Folder not found.", "error"); return() }
    files <- sort(list.files(d, pattern = "\\.(jpe?g|png|gif|bmp|tiff?)$",
                             full.names = TRUE, ignore.case = TRUE))
    if (!length(files)) { notify("No image in this folder.", "error"); return() }
    rv$dir_files <- files
    # server-side choices: the list is never rendered whole in the browser
    updateSelectizeInput(session, "goto_file",
                         choices = stats::setNames(seq_along(files), basename(files)),
                         selected = 1L, server = TRUE)
    load_dir_photo(1L)
    notify(sprintf("%d photograph(s) loaded.", length(files)))
  })
  observeEvent(input$next_photo, if (length(rv$dir_files)) load_dir_photo(rv$dir_i + 1L))
  observeEvent(input$prev_photo, if (length(rv$dir_files)) load_dir_photo(rv$dir_i - 1L))
  observeEvent(input$goto_file, {
    i <- suppressWarnings(as.integer(input$goto_file))
    if (!is.na(i) && length(rv$dir_files) && i != rv$dir_i) load_dir_photo(i)
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

  ## ---- reviewing an existing measurement table ------------------------------
  ## Reads a CSV (specimen, landmark, X, Y[, mm_per_px, note]; X and Y in image
  ## pixels) and places one specimen's landmarks on the photograph.
  observeEvent(input$measures_file, {
    df <- tryCatch(utils::read.csv(input$measures_file$datapath,
                                   stringsAsFactors = FALSE, check.names = FALSE),
                   error = function(e) NULL)
    if (is.null(df) || !ncol(df)) { notify("Could not read the CSV.", "error"); return() }
    names(df) <- tolower(names(df))
    pick <- function(cands) { h <- intersect(cands, names(df)); if (length(h)) h[1] else NA }
    spc <- pick(c("specimen", "code", "id")); lmc <- pick(c("landmark", "lm"))
    xc  <- pick("x"); yc <- pick("y")
    ntc <- pick(c("note", "quality"))
    if (any(is.na(c(spc, lmc, xc, yc)))) {
      notify("Invalid CSV: expected columns specimen, landmark, X, Y.", "error"); return()
    }
    d <- data.frame(specimen = as.character(df[[spc]]),
                    landmark = suppressWarnings(as.integer(df[[lmc]])),
                    X = suppressWarnings(as.numeric(df[[xc]])),
                    Y = suppressWarnings(as.numeric(df[[yc]])),
                    note = if (!is.na(ntc)) suppressWarnings(as.integer(df[[ntc]]))
                           else NA_integer_,
                    stringsAsFactors = FALSE)
    d <- d[!is.na(d$landmark), , drop = FALSE]
    if (!nrow(d)) { notify("Empty CSV, or non-numeric columns.", "error"); return() }
    rv$loaded <- d
    sp <- sort(unique(d$specimen))
    rv$loaded_sel <- if (nzchar(input$specimen_id) && input$specimen_id %in% sp)
                       input$specimen_id else sp[1]
    notify(sprintf("Table loaded: %d specimen(s). Pick one, then 'Load onto the photograph'.",
                   length(sp)))
  })

  output$load_specimen_ui <- renderUI({
    if (is.null(rv$loaded)) return(NULL)
    sp <- sort(unique(rv$loaded$specimen))
    tagList(
      selectInput("load_specimen", "Specimen from the table", choices = sp,
                  selected = rv$loaded_sel),
      actionButton("load_measures_btn", "Load onto the photograph", class = "btn-primary"))
  })

  observeEvent(input$load_measures_btn, {
    req(rv$loaded, input$load_specimen)
    d <- rv$loaded[rv$loaded$specimen == input$load_specimen, , drop = FALSE]
    if (!nrow(d)) { notify("No row for this specimen.", "error"); return() }
    M <- matrix(NA_real_, N_TOT, 2, dimnames = list(seq_len(N_TOT), c("X", "Y")))
    ok <- d$landmark >= 1 & d$landmark <= N_TOT
    M[as.character(d$landmark[ok]), ] <- as.matrix(d[ok, c("X", "Y")])
    # Reloaded points count as already digitized, so the review phase applies.
    rv$pred <- M
    rv$na <- integer(0); rv$edited <- integer(0); rv$placed_order <- integer(0)
    rv$seeded <- integer(0)
    rv$sel <- ANAT_ORDER[1]   # first anatomical point to review
    updateTextInput(session, "specimen_id", value = input$load_specimen)
    nt <- if ("note" %in% names(d)) d$note[!is.na(d$note)] else integer(0)
    if (length(nt)) updateRadioButtons(session, "quality", selected = as.character(nt[1]))
    notify(sprintf("Landmarks of '%s' loaded (%d points), with no re-derivation.",
                   input$load_specimen, sum(ok)))
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

  ## One fixed bar. Placing by hand is the DEFAULT way to work -- the seed puts
  ## every landmark down as soon as the axis is drawn -- so it is not a mode to
  ## switch into. `Predict` stays available throughout: the model is an optional
  ## accelerator over the seeded configuration, not a step to get past first.
  ## Mark NA / Clear point / Save live in the action bar above; only the editing
  ## MODES belong here, since they change how the next click is interpreted.
  output$phase_ui <- renderUI({
    div(class = "phasebar", style = "margin-bottom:4px;",
      div(style = "display:inline-block;margin-right:16px;",
          checkboxInput("move_all", "Move the whole block (on click)", FALSE)),
      div(style = "display:inline-block;margin-right:16px;",
          checkboxInput("auto_constraints",
                        "Auto constraints (adapt the other points)", TRUE)),
      actionButton("predict", "Predict the 19 landmarks"),
      actionButton("undo", "Undo last point"),
      actionButton("restart", "Start over"))
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
             else if (i %in% rv$edited) "background:#cfe8ff;"
             else if (i %in% auto || i %in% DERIVED_LM) "background:#eee;color:#999;"
             else if (i %in% rv$seeded) "background:#faeeda;color:#854f0b;"
             else "background:#f7f7f7;"
      if (!fin_row(rv$pred, i) && !(i %in% rv$na))
        col <- paste0(col, "border-style:dashed;")
      tags$button(type = "button", i,
        onclick = sprintf("Shiny.setInputValue('sel_btn', %d, {priority:'event'});", i),
        style = paste0("margin:2px;padding:6px 12px;min-width:42px;font-size:15px;",
                       "border:1px solid #ccc;border-radius:4px;cursor:pointer;", col))
    }
    div(style = "margin-bottom:8px;line-height:2.4;",
        tags$strong("Active landmark (click the photograph to place it -> auto-advance): "),
        lapply(order_show, btn),
        tags$div(style = "font-size:11px;color:#666;line-height:1.5;",
          "Green = active; blue = placed by hand; amber = still at its seed",
          "(median FISHMORPH proportion -- never checked on this specimen);",
          "pink struck through = NA; grey = automatic or derived; gold = HINGES;",
          "pale green = SCALE BAR (20/21); dashed border = not placed yet.",
          tags$br(),
          "Broken axis 1 -> 22 -> 23 -> 2: place 22 then 23 on the bends of a curved",
          "specimen. Head conventions apply on 1-22, body depth and pectoral fin",
          "(10, 11, 12) on 22-23, caudal (16-17, 18-19) on 23-2. LM24 (end of the",
          "list) adds a fourth axis segment, without conventions. LM22 is a genuine",
          "landmark -- fishmorph_segments() uses it to correct the standard length --",
          "whereas 23 and 24 are entry aids and are NOT exported."))
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
  observeEvent(input$restart, {
    rv$pred <- empty_coords()
    rv$na <- integer(0); rv$edited <- integer(0); rv$placed_order <- integer(0)
    rv$seeded <- integer(0)
    rv$sel <- 1L
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
      else if (p %in% rv$edited) "clicked"
      else if (p %in% rv$seeded && !(p %in% DERIVED_LM)) "seeded"
      else if (p %in% DERIVED_LM) "derived"
      else if (p %in% c(1L, 2L)) "clicked"
      else "predicted"
    }, character(1))
    stats::setNames(st, as.character(points))
  }

  ## ---- multi-specimen table -------------------------------------------------
  current_table <- function() {
    id <- trimws(input$specimen_id); if (id == "") id <- "specimen"
    P <- rv$pred
    mmpp <- mm_per_px(P)                            # scale from the final 20-21
    note <- suppressWarnings(as.integer(input$quality))
    data.frame(specimen = id, landmark = SAVE_PTS,
               X = P[SAVE_PTS, 1], Y = P[SAVE_PTS, 2],
               mm_per_px = mmpp,
               note = note,                         # repeated on every row
               status = unname(point_status(SAVE_PTS)),
               row.names = NULL)
  }

  ## Skip: jump to the next photograph NOT yet in the saved table, rather than
  ## simply the next one. In a batch that is what "skip" is actually for --
  ## coming back to the gaps after a first pass, without stepping through the
  ## specimens already done.
  observeEvent(input$skip, {
    n <- length(rv$dir_files)
    if (!n) { notify("No folder loaded.", "warning"); return() }
    done <- if (!is.null(rv$saved)) unique(rv$saved$specimen) else character(0)
    codes <- tools::file_path_sans_ext(basename(rv$dir_files))
    cand <- setdiff(seq_len(n), which(codes %in% done))
    nxt <- cand[cand > rv$dir_i]
    if (!length(nxt)) nxt <- cand              # wrap around to the earlier gaps
    if (!length(nxt)) { notify("Every photograph in the folder is saved.");  return() }
    load_dir_photo(nxt[1])
  })

  ## Rewrite the cumulative table now. It is already written on every save, so
  ## this is a belt-and-braces action for a long session.
  observeEvent(input$flush, {
    if (is.null(rv$saved) || !nrow(rv$saved)) {
      notify("Nothing to write yet.", "warning"); return() }
    ok <- tryCatch({ utils::write.csv(rv$saved, AUTOSAVE, row.names = FALSE); TRUE },
                   error = function(e) FALSE)
    notify(if (ok) sprintf("Table written to %s (%d specimen(s)).",
                           basename(AUTOSAVE), length(unique(rv$saved$specimen)))
           else sprintf("Could not write %s.", AUTOSAVE),
           type = if (ok) "message" else "error")
  })

  observeEvent(input$save_specimen, {
    if (is.null(rv$pred)) {
      notify("Nothing to save yet: predict, or start manual placement first.",
             "warning"); return() }
    df <- current_table()
    id <- df$specimen[1]
    if (!is.null(rv$saved)) {
      rv$saved <- rv$saved[rv$saved$specimen != id, , drop = FALSE]
      for (cc in setdiff(names(df), names(rv$saved)))   # tables saved by older versions
        rv$saved[[cc]] <- NA
      rv$saved <- rv$saved[, names(df), drop = FALSE]
    }
    rv$saved <- rbind(rv$saved, df)
    ok <- tryCatch({ utils::write.csv(rv$saved, AUTOSAVE, row.names = FALSE); TRUE },
                   error = function(e) FALSE)
    msg <- sprintf("Specimen '%s' saved (score %s/5; %d in total; %s).",
                   id, df$note[1], length(unique(rv$saved$specimen)),
                   if (ok) "autosaved" else "AUTOSAVE FAILED")
    # Points never looked at are the quality risk worth surfacing, and a seeded
    # point is the worse of the two: it was measured on no specimen at all.
    unchecked <- c(seeded = sum(df$status == "seeded"),
                   predicted = sum(df$status == "predicted"))
    if (any(unchecked > 0))
      msg <- paste(msg, sprintf("%d still seeded, %d still predicted -- unchecked.",
                                unchecked[["seeded"]], unchecked[["predicted"]]))
    notify(msg, type = if (any(unchecked > 0)) "warning" else "message")
    if (!ok) showNotification(sprintf("Could not write %s.", AUTOSAVE),
                              type = "error", duration = 8)
    # move on to the next photograph when working through a folder
    if (length(rv$dir_files) && rv$dir_i < length(rv$dir_files))
      load_dir_photo(rv$dir_i + 1L)
  })
  observeEvent(input$clear_all, { rv$saved <- NULL
    if (file.exists(AUTOSAVE)) try(file.remove(AUTOSAVE), silent = TRUE)
    notify("Table cleared.") })
  output$saved_info <- renderText({
    if (is.null(rv$saved) || !nrow(rv$saved)) "No specimen saved yet."
    else paste0(length(unique(rv$saved$specimen)), " specimen(s): ",
                paste(unique(rv$saved$specimen), collapse = ", "))
  })
  output$dl_all <- downloadHandler(
    filename = function() paste0("measurements_", Sys.Date(), ".csv"),
    content = function(f) { req(rv$saved); utils::write.csv(rv$saved, f, row.names = FALSE) })

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
    if (is.null(rv$img)) { plot.new(); text(.5, .5, "Load a photograph"); return() }
    par(mar = c(0, 0, 0, 0))
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
  output$progress <- renderUI({
    n <- length(rv$dir_files)
    photo <- if (n) tools::file_path_sans_ext(basename(rv$dir_files[rv$dir_i]))
             else if (!is.null(rv$orig)) tools::file_path_sans_ext(basename(rv$orig))
             else "-"
    done <- if (!is.null(rv$saved) && "specimen" %in% names(rv$saved))
              length(unique(rv$saved$specimen)) else 0L
    left <- if (n) {
      todo <- setdiff(tools::file_path_sans_ext(basename(rv$dir_files)),
                      if (!is.null(rv$saved)) rv$saved$specimen else character(0))
      sprintf("Photograph %d / %d &nbsp;.&nbsp; %d not yet saved", rv$dir_i, n, length(todo))
    } else "No folder loaded."
    mpp  <- mm_per_px(rv$pred)
    scal <- if (is.finite(mpp)) sprintf("%.4f mm/px", mpp)
            else "scale bar 20-21 not placed"
    HTML(sprintf("<b>%s</b><br>%s<br>Saved: %d<br>Scale: %s",
                 photo, left, done, scal))
  })

  output$status <- renderText({
    if (is.null(rv$pred)) return("Load a photograph or a folder to begin.")
    st <- point_status(seq_len(N_ANAT))
    step <- if (!fin_row(rv$pred, 1L) || !fin_row(rv$pred, 2L))
      paste("Draw the axis first: 1, 22, 23, 2. The hinges go on the bends of a",
            "curved specimen, anywhere along the midline if it is straight.",
            "Every other landmark is placed for you as soon as LM2 is down.")
      else "Reposition each landmark in turn, then 'Save & next'."
    paste0(rv$msg, "\n\n", step,
           "\nActive landmark: ", point_label(rv$sel),
           sprintf("\n%d placed by hand | %d still seeded | %d still predicted | %d NA | %d not placed.",
                   sum(st == "clicked"), sum(st == "seeded"), sum(st == "predicted"),
                   sum(st == "na"), sum(st == "missing")))
  })

  ## ---- single-specimen export -----------------------------------------------
  fname <- reactive({
    id <- trimws(input$specimen_id %||% "")
    if (nzchar(id)) id else "specimen"
  })
  output$dl_csv <- downloadHandler(
    filename = function() paste0(fname(), "_landmarks.csv"),
    content = function(f) {
      req(rv$pred)
      # All SAVE_PTS rows are kept: an unmeasurable point is written NA, so the
      # scheme stays complete for downstream imputation.
      utils::write.csv(current_table(), f, row.names = FALSE) })
  output$dl_tps <- downloadHandler(
    filename = function() paste0(fname(), ".tps"),
    content = function(f) {
      req(rv$pred)
      con <- file(f, "w"); on.exit(close(con))
      keep <- SAVE_PTS[vapply(SAVE_PTS, function(i) fin_row(rv$pred, i), logical(1))]
      writeLines(sprintf("LM=%d", length(keep)), con)
      for (i in keep)                                       # TPS: bottom-left origin
        writeLines(sprintf("%.3f %.3f", rv$pred[i, 1], rv$h - rv$pred[i, 2]), con)
      writeLines(sprintf("IMAGE=%s",
                         if (!is.null(rv$orig)) basename(rv$orig) else ""), con)
      writeLines(sprintf("ID=%s", fname()), con) })
}

shinyApp(ui, server)
