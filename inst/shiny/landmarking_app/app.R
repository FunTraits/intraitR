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

## Landmarks the auto-advance stops on, in review order: the anatomical points
## left to the operator, then the two scale-bar points. Hinges are deliberately
## excluded -- they are placed on demand from the button bar.
review_order <- function(pin) {
  auto <- if (isTRUE(pin)) AUTO_LM_PIN else AUTO_LM
  c(setdiff(seq_len(N_ANAT), auto), SCALE_PTS)
}
## Next landmark TO REVIEW after `cur` (wraps around).
next_review <- function(cur, pin) {
  ord <- review_order(pin)
  if (!length(ord)) return(cur)
  i <- match(cur, ord)
  if (is.na(i)) return(ord[1])
  ord[if (i >= length(ord)) 1L else i + 1L]
}

## Calibration click sequences (depend on the "pin" option).
##  - pin OFF: snout, caudal basis, dorsal (orientation), 2 scale marks  (5 clicks)
##  - pin ON : snout, caudal basis, LM3 (= dorsal), LM4, LM7, LM10, LM12,
##             LM16, LM18, LM15 (mouth), then the 2 scale marks         (12 clicks)
CLICK_LABELS <- c("1 -- snout (LM1)", "2 -- caudal-fin basis (LM2)",
                  "3 -- dorsal point (top of the body; orients dorsal side up)",
                  "4 -- scale mark A (LM20)", "5 -- scale mark B (LM21)")
CLICK_LABELS_PIN <- c("1 -- snout (LM1)", "2 -- caudal-fin basis (LM2)",
                  "3 -- DORSAL point = LM3 (top of the body; orients dorsal side up)",
                  "4 -- LM4 (ventral, directly below LM3)",
                  "5 -- LM7 (head reference: defines the eye vertical)",
                  "6 -- LM10", "7 -- LM12", "8 -- LM16", "9 -- LM18",
                  "10 -- LM15 (mouth)",
                  "11 -- scale mark A (LM20)", "12 -- scale mark B (LM21)")
n_calib_clicks  <- function(pin) if (isTRUE(pin)) 12L else 5L
scale_click_idx <- function(pin) if (isTRUE(pin)) c(11L, 12L) else c(4L, 5L)

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
derive_ventral <- function(P, fr) {
  P <- belly_align(P, fr$mid, 4L, 11L)                    # 11 <- 4
  P <- belly_align(P, fr$head, if (fin_row(P, 11L)) 11L else 9L, c(8L, 9L))
  if (fin_row(P, 1L)  && fin_row(P, 9L))
    P["9", ]  <- fr$head$at(fr$head$ax(P["1", ]),  fr$head$pe(P["9", ]))
  if (fin_row(P, 7L)  && fin_row(P, 8L))
    P["8", ]  <- fr$head$at(fr$head$ax(P["7", ]),  fr$head$pe(P["8", ]))
  if (fin_row(P, 10L) && fin_row(P, 11L))
    P["11", ] <- fr$mid$at(fr$mid$ax(P["10", ]),   fr$mid$pe(P["11", ]))
  P
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
    "})();", sep = "\n")))),
  titlePanel("Predictor-assisted landmarking -- ml-morph"),
  sidebarLayout(
    sidebarPanel(width = 3,
      uiOutput("progress"),
      tags$hr(),
      tags$strong("Photograph folder"),
      textInput("photo_dir", NULL, placeholder = "folder path..."),
      actionButton("load_dir", "Load folder", class = "btn-primary"),
      div(style = "margin:4px 0;",
          actionButton("prev_photo", "< Previous"),
          actionButton("next_photo", "Next >")),
      selectizeInput("goto_file", NULL, choices = NULL, selected = NULL,
                     width = "100%",
                     options = list(placeholder = "Jump to a photograph...")),
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
      checkboxInput("fastdisp", "Fast display (down-sampled photograph)", value = TRUE),
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
      div(actionButton("zoom_in", "Zoom +"), actionButton("zoom_out", "Zoom -"),
          actionButton("zoom_reset", "Whole view")),
      helpText("Zoom centres on the selected landmark."),
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
      actionButton("clear_all", "Clear the table")
    ),
    mainPanel(width = 9,
      uiOutput("click_help"),
      uiOutput("auto_help"),
      helpText("Zoom: +/- buttons; hold the right button to pan across the",
               "photograph; double-click restores the whole view."),
      uiOutput("phase_ui"),     # action buttons (Predict / NA / Save...)
      uiOutput("lm_buttons"),   # active-landmark bar, above the photograph
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
    clicks = list(), pred = NULL, sel = 1L, msg = "",
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
  ## rv$arr holds the ORIGINAL array; rv$flip is baked into the coordinate frame
  ## (landmarks are remapped when it changes) while rv$dispflip is purely visual.
  make_disp <- function() {
    if (is.null(rv$arr)) return(NULL)
    a <- flip_array(rv$arr, rv$flip)
    a <- flip_array(a, rv$dispflip)
    if (isTRUE(input$fastdisp)) a <- downscale(a)
    a
  }
  flip_pt <- function(p, mode) {
    if (is.null(p) || !all(is.finite(p))) return(p)
    if (grepl("h", mode)) p[1] <- rv$w - p[1]
    if (grepl("v", mode)) p[2] <- rv$h - p[2]
    p
  }
  remap_pt <- function(p, oldm, newm) flip_pt(flip_pt(p, oldm), newm)

  ## Path of the image handed to the Python worker: the file itself when no flip
  ## is applied, a temporary flipped copy otherwise. Written on demand (at
  ## prediction time) rather than on every flip.
  worker_path <- function() {
    if (identical(rv$flip, "none")) return(rv$orig)
    tf <- tempfile(fileext = ".jpg")
    jpeg::writeJPEG(flip_array(rv$arr, rv$flip), tf, quality = 0.95)
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
    rv$arr <- im
    rv$h <- dim(im)[1]; rv$w <- dim(im)[2]      # ORIGINAL dims (coordinate frame)
    rv$flip <- "none"
    updateRadioButtons(session, "flip_mode", selected = "none")
    rv$img <- make_disp()
    rv$clicks <- list(); rv$pred <- NULL; rv$sel <- 1L
    rv$na <- integer(0); rv$edited <- integer(0)
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
    if (length(rv$clicks))
      rv$clicks <- lapply(rv$clicks, remap_pt, oldm = oldm, newm = newm)
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
  observeEvent(input$fastdisp, { if (!is.null(rv$arr)) rv$img <- make_disp() },
               ignoreInit = TRUE)

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
    rv$pred <- M; rv$clicks <- list(); rv$na <- integer(0); rv$edited <- integer(0)
    rv$sel <- next_review(0L, input$pin)
    updateTextInput(session, "specimen_id", value = input$load_specimen)
    nt <- if ("note" %in% names(d)) d$note[!is.na(d$note)] else integer(0)
    if (length(nt)) updateRadioButtons(session, "quality", selected = as.character(nt[1]))
    notify(sprintf("Landmarks of '%s' loaded (%d points), with no re-derivation.",
                   input$load_specimen, sum(ok)))
  })

  ## ---- clicking on the photograph -------------------------------------------
  ## Calibration phase (no prediction yet) accumulates the calibration clicks;
  ## afterwards a click moves the ACTIVE landmark and the selection auto-advances.
  observeEvent(input$click, {
    if (is.null(rv$img)) return()
    p <- c(input$click$x, input$click$y)
    if (is.null(rv$pred)) {
      nmax <- n_calib_clicks(input$pin)
      labs <- if (isTRUE(input$pin)) CLICK_LABELS_PIN else CLICK_LABELS
      if (length(rv$clicks) < nmax) {
        rv$clicks[[length(rv$clicks) + 1]] <- p
        nxt <- length(rv$clicks) + 1
        rv$msg <- if (nxt <= nmax) paste("Click:", labs[nxt])
                  else "All calibration points placed -- click 'Predict'."
      }
      return()
    }
    if (isTRUE(input$move_all)) {                  # rigid translation of the block
      cur <- rv$pred[rv$sel, ]
      if (all(is.finite(cur))) {
        rv$pred <- sweep(rv$pred, 2, p - cur, "+")
        rv$msg <- paste0("Block moved (via LM", rv$sel, ").")
      }
      return()
    }
    P <- rv$pred
    P[rv$sel, ] <- p
    rv$na     <- setdiff(rv$na, rv$sel)            # re-placed -> no longer NA
    rv$edited <- union(rv$edited, rv$sel)          # moved by hand
    # A hinge is not a landmark, but placing one redefines the segment frames, so
    # the derived points are recomputed in that case too.
    if (isTRUE(input$auto_constraints)) P <- propagate_conventions(P, rv$sel)
    rv$pred <- P
    if (rv$sel %in% HINGES) {                      # hinges are outside the review loop
      rv$msg <- paste0("Hinge ", rv$sel, " placed -- the axis is now broken there.")
    } else {
      nxt <- next_review(rv$sel, input$pin)
      rv$msg <- paste0("Landmark ", rv$sel, " placed -> next: ", nxt, ".")
      rv$sel <- nxt
    }
  })

  ## ---- contextual help ------------------------------------------------------
  output$click_help <- renderUI({
    if (isTRUE(input$pin))
      helpText("PIN mode (12 clicks): snout, caudal-fin basis, DORSAL point (= LM3,",
               "orients dorsal side up), LM4, LM7, LM10, LM12, LM16, LM18, LM15",
               "(mouth), then the 2 scale marks. Then 'Predict': 1, 2, 3, 4, 7, 10,",
               "12, 15, 16 and 18 are frozen on your clicks, 8/9/11 are derived, and",
               "the model predicts only the remaining points.")
    else
      helpText("Click in order: snout, caudal-fin basis, a DORSAL point (top of the",
               "body -- orients dorsal side up), then the 2 scale marks -- 5 clicks.",
               "Then 'Predict'. Afterwards, select a landmark and click to reposition",
               "it (20-21 = scale bar, placed the same way).")
  })
  output$auto_help <- renderUI({
    if (isTRUE(input$pin))
      helpText(tags$b("To review:"), "5, 6, 13, 14, 17, 19, 20, 21 (the auto-advance",
               "stops there).", tags$br(), tags$b("Pinned / derived:"),
               "1, 2, 3, 4, 7, 10, 12, 15, 16, 18 (clicks) and 8, 9, 11 (derived from",
               "1, 7, 10 and 4).")
    else
      helpText(tags$b("To review:"), "3-7, 10, 12-21 (the auto-advance stops there).",
               tags$br(), tags$b("Automatic:"), "1, 2 (clicks) and 8, 9, 11 (derived",
               "from 1, 7, 10 and 4).")
  })

  output$phase_ui <- renderUI({
    if (is.null(rv$pred)) {
      tagList(
        actionButton("undo", "Undo last click"),
        actionButton("predict", "Predict the 19 landmarks", class = "btn-primary"),
        actionButton("manual", "Place by hand (no model)"),
        helpText("'Place by hand' opens the correction phase with only the",
                 "calibration clicks in place and every other landmark empty --",
                 "the way to digitize when no trained predictor is available."))
    } else {
      tagList(
        helpText("Select the landmark to correct with the numbered buttons below,",
                 "then click its position on the photograph."),
        checkboxInput("move_all", "Move the whole block (on click)", FALSE),
        checkboxInput("auto_constraints", "Auto constraints (adapt the other points)", TRUE),
        actionButton("snap1", "Snap LM1 back onto the snout click"),
        actionButton("set_na", "Mark NA (not measurable)"),
        actionButton("clear_pt", "Clear this point"),
        tags$hr(),
        actionButton("save_specimen", "Save this specimen", class = "btn-success"),
        actionButton("restart", "Start over (new clicks)"))
    }
  })

  ## ---- active-landmark bar --------------------------------------------------
  ## Faster than a drop-down, and it doubles as a status display: green = active,
  ## blue = placed by hand, pink struck through = NA, grey = derived, gold =
  ## hinge, pale green = scale bar. Plain HTML buttons setting input$sel_btn --
  ## robust to re-rendering, unlike actionButton counters which would reset.
  output$lm_buttons <- renderUI({
    if (is.null(rv$pred)) return(NULL)
    auto <- if (isTRUE(input$pin)) AUTO_LM_PIN else AUTO_LM
    order_show <- c(1L, CURVE_PT, EXTRA_HINGES, 2L,
                    setdiff(seq_len(N_ANAT), c(1L, 2L)), SCALE_PTS)
    btn <- function(i) {
      col <- if (i == rv$sel) "background:#28a745;color:#fff;font-weight:bold;"
             else if (i %in% rv$na) "background:#f8d7da;color:#a00;text-decoration:line-through;"
             else if (i %in% HINGES) "background:#ffd24d;color:#000;font-weight:bold;"
             else if (i %in% SCALE_PTS) "background:#d9f2e6;color:#065;font-weight:bold;"
             else if (i %in% rv$edited) "background:#cfe8ff;"
             else if (i %in% auto || i %in% DERIVED_LM) "background:#eee;color:#999;"
             else "background:#f7f7f7;"
      if (!fin_row(rv$pred, i) && !(i %in% rv$na))
        col <- paste0(col, "border-style:dashed;")
      tags$button(type = "button", i,
        onclick = sprintf("Shiny.setInputValue('sel_btn', %d, {priority:'event'});", i),
        style = paste0("margin:1px;padding:3px 8px;min-width:34px;border:1px solid #ccc;",
                       "border-radius:3px;cursor:pointer;", col))
    }
    div(style = "margin-bottom:6px;line-height:2.2;",
        tags$strong("Active landmark (click the photograph to place it -> auto-advance): "),
        lapply(order_show, btn),
        tags$div(style = "font-size:11px;color:#666;",
          "Green = active; blue = placed by hand; pink struck through = NA;",
          "grey = automatic or derived; gold = HINGES; pale green = scale bar;",
          "dashed border = not placed yet.", tags$br(),
          "Broken axis 1 -> 22 -> 23 -> 24 -> 2: place the hinges on the bends of a",
          "curved specimen. LM22 is a genuine landmark (fishmorph_segments() uses",
          "it to correct the standard length); 23 and 24 are entry aids and are",
          "NOT exported. Head conventions apply on 1-22, body depth and pectoral",
          "fin on 22-23, caudal peduncle and fin on 23-2."))
  })
  observeEvent(input$sel_btn, { rv$sel <- as.integer(input$sel_btn); zoom_to_sel() })

  observeEvent(input$set_na, {
    if (rv$sel %in% c(1L, 2L)) {
      notify("LM1 and LM2 define the body axis and cannot be marked NA.", "warning"); return()
    }
    rv$pred[rv$sel, ] <- NA_real_
    rv$na <- union(rv$na, rv$sel); rv$edited <- setdiff(rv$edited, rv$sel)
    s <- rv$sel
    rv$sel <- if (s %in% HINGES) s else next_review(s, input$pin)
    rv$msg <- paste("Landmark", s, "marked NA (not measurable).")
  })
  observeEvent(input$clear_pt, {                   # unlike NA: simply "not placed"
    rv$pred[rv$sel, ] <- NA_real_
    rv$na <- setdiff(rv$na, rv$sel); rv$edited <- setdiff(rv$edited, rv$sel)
    rv$msg <- paste("Landmark", rv$sel, "cleared.")
  })
  observeEvent(input$snap1, {                      # translate the block: LM1 -> snout click
    if (is.null(rv$pred) || length(rv$clicks) < 1) return()
    cur <- rv$pred[1, ]
    if (all(is.finite(cur))) {
      rv$pred <- sweep(rv$pred, 2, rv$clicks[[1]] - cur, "+")
      notify("Block snapped: LM1 back on the snout click.")
    }
  })
  ## Manual entry: open the correction phase with the calibration clicks in place
  ## and nothing else, so the app is usable with no trained predictor at all.
  observeEvent(input$manual, {
    if (length(rv$clicks) < 2) {
      notify("Click at least the snout and the caudal-fin basis first.", "error"); return() }
    M <- matrix(NA_real_, N_TOT, 2, dimnames = list(seq_len(N_TOT), c("X", "Y")))
    M["1", ] <- rv$clicks[[1]]; M["2", ] <- rv$clicks[[2]]
    placed <- c(1L, 2L)
    if (isTRUE(input$pin)) {   # the pinned clicks map onto their own landmarks
      map <- c(3L, 4L, 7L, 10L, 12L, 16L, 18L, 15L)   # clicks 3..10, in pin order
      for (k in seq_along(map)) if (length(rv$clicks) >= k + 2L) {
        M[as.character(map[k]), ] <- rv$clicks[[k + 2L]]
        placed <- c(placed, map[k])
      }
    }
    si <- scale_click_idx(input$pin)                  # scale bar, when clicked
    if (length(rv$clicks) >= si[2]) {
      M["20", ] <- rv$clicks[[si[1]]]; M["21", ] <- rv$clicks[[si[2]]]
      placed <- c(placed, SCALE_PTS)
    }
    # Seed the derived ventral points from LM4 when it is available (pin mode):
    # derive_ventral() only moves points that already exist, so they need a
    # starting position before the conventions can take over.
    fr <- seg_frames(M)
    if (!is.null(fr) && fin_row(M, 4L)) {
      pb <- fr$mid$pe(M["4", ])
      for (ab in list(c(1L, 9L), c(7L, 8L), c(10L, 11L)))
        if (fin_row(M, ab[1])) {
          f <- if (ab[2] == 11L) fr$mid else fr$head
          M[as.character(ab[2]), ] <- f$at(f$ax(M[ab[1], ]), pb)
        }
      M <- apply_conventions(M)
    }
    rv$pred <- M; rv$na <- integer(0); rv$edited <- unique(placed)
    rv$sel <- next_review(0L, input$pin)
    notify("Manual placement: every remaining landmark is empty. Select one and click its position.")
  })

  observeEvent(input$undo, if (length(rv$clicks)) rv$clicks[[length(rv$clicks)]] <- NULL)
  observeEvent(input$restart, { rv$pred <- NULL; rv$clicks <- list()
    rv$na <- integer(0); rv$edited <- integer(0)
    rv$msg <- "Click the snout (point 1)." })

  ## ---- per-point status -----------------------------------------------------
  ## The information a wide coordinate table cannot carry: which points were
  ## actually looked at. "predicted" flags a point still sitting exactly where
  ## the model put it -- never verified by eye, and therefore to be audited.
  point_status <- function(points) {
    st <- vapply(points, function(p) {
      if (p %in% rv$na) "na"
      else if (!fin_row(rv$pred, p)) "missing"
      else if (p %in% rv$edited) "clicked"
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

  observeEvent(input$save_specimen, {
    req(rv$pred)
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
    npred <- sum(df$status == "predicted")
    msg <- sprintf("Specimen '%s' saved (score %s/5; %d in total; %s).",
                   id, df$note[1], length(unique(rv$saved$specimen)),
                   if (ok) "autosaved" else "AUTOSAVE FAILED")
    if (npred)   # points never looked at are the quality risk worth surfacing
      msg <- paste(msg, sprintf("%d point(s) still at the predicted position.", npred))
    notify(msg, type = if (ok) "message" else "error")
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
    if (length(rv$clicks) < 2) {
      notify("At least the snout and the caudal-fin basis are required.", "error"); return() }
    if (!length(PRED_CHOICES)) { notify("No model available.", "error"); return() }
    out <- tempfile(fileext = ".csv")
    xy <- function(i) paste0(rv$clicks[[i]][1], ",", rv$clicks[[i]][2])
    # training set matching the chosen model (identical bounding box):
    # mlmorph_run_app -> mlmorph_dataset_app, and so on.
    ds_dir <- file.path(ML, sub("mlmorph_run", "mlmorph_dataset",
                                basename(dirname(input$pred))))
    if (!dir.exists(ds_dir)) ds_dir <- DATASET
    si <- scale_click_idx(input$pin)          # indices of the two scale clicks
    img_path <- worker_path()
    args <- c(shQuote(WORKER), "--image", shQuote(img_path),
              "--snout", xy(1), "--caudal", xy(2),
              if (length(rv$clicks) >= 3) c("--dorsal", xy(3)),   # = LM3 in pin mode
              if (isTRUE(input$pin) && length(rv$clicks) >= 4) c("--lm4",  xy(4)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 5) c("--lm7",  xy(5)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 6) c("--lm10", xy(6)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 7) c("--lm12", xy(7)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 8) c("--lm16", xy(8)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 9) c("--lm18", xy(9)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 10) c("--lm15", xy(10)),
              if (length(rv$clicks) >= si[2]) c("--scale1", xy(si[1]), "--scale2", xy(si[2])),
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
      # Always N_TOT rows: the scale points 20-21 (and any point not predicted,
      # including the hinges) stay NA and can be placed by hand afterwards.
      M <- matrix(NA_real_, N_TOT, 2, dimnames = list(seq_len(N_TOT), c("X", "Y")))
      keep <- d$landmark >= 1 & d$landmark <= N_TOT
      M[as.character(d$landmark[keep]), ] <- as.matrix(d[keep, c("X", "Y")])
      # Pin mode: 1, 2, 3, 4, 7 are already frozen on the clicks by the worker;
      # propagate the FISHMORPH conventions to the dependants (8, 9, 11, 5, 6, 13, 14).
      if (isTRUE(input$pin)) M <- apply_conventions(M)
      rv$pred <- M
      rv$na <- integer(0); rv$edited <- c(1L, 2L)   # the calibration clicks
      rv$sel <- next_review(0L, input$pin)
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
    graphics::rasterImage(rv$img, 0, rv$h, rv$w, 0)

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
    # calibration clicks
    if (length(rv$clicks)) {
      cl <- do.call(rbind, rv$clicks)
      points(cl, col = "yellow", pch = 3, cex = 2, lwd = 2)
      text(cl[, 1], cl[, 2], seq_len(nrow(cl)), col = "yellow", pos = 3, cex = 1.2)
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
    lab <- if (rv$sel == 1L) "SNOUT (LM1)"
           else if (rv$sel == 2L) "CAUDAL-FIN BASIS (LM2)"
           else if (rv$sel == 20L) "SCALE BAR, start (LM20)"
           else if (rv$sel == 21L) "SCALE BAR, end (LM21)"
           else if (rv$sel == CURVE_PT) "CURVATURE POINT (LM22, exported)"
           else if (rv$sel %in% EXTRA_HINGES) paste0("HINGE ", rv$sel, " (entry aid, not exported)")
           else paste0("LM", rv$sel)
    npred <- if (!is.null(rv$pred)) sum(point_status(seq_len(N_ANAT)) == "predicted") else 0L
    paste0(rv$msg, "\n\nActive landmark: ", lab,
           if (!is.null(rv$pred))
             sprintf("\n%d of the %d anatomical landmarks are still at their predicted position.",
                     npred, N_ANAT) else "")
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
