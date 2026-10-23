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
    individuals_per_photo = 1L, individual_order = "top",
    individuals_per_row = NA_integer_,
    xlsx_flush_every = 10L, provenance_keys = character(0),
    sheet_measurements = "measurements",
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
## Predictions of batch_landmarks() (argument `batch` of digitize_landmarks()):
## the automatic chain run beforehand on the whole folder. Keyed by file name.
## In the "new" queue a photograph found there arrives pre-filled, and the
## photographs the batch flagged come first.
BATCH <- local({
  d <- CFG$batch_dir
  if (is.null(d) || !nzchar(d) || !file.exists(file.path(d, "landmarks_long.csv"))) NULL else {
    key <- function(p) tolower(basename(p))
    L <- utils::read.csv(file.path(d, "landmarks_long.csv"), stringsAsFactors = FALSE)
    # plates found by the batch (max_fish > 1): only individual 1 pre-fills a
    # one-fish photograph; plates themselves are not pre-filled (see seed_from_batch)
    if ("individual" %in% names(L)) L <- L[L$individual == 1L, , drop = FALSE]
    S <- if (file.exists(file.path(d, "summary.csv")))
      utils::read.csv(file.path(d, "summary.csv"), stringsAsFactors = FALSE) else
      data.frame(photo = unique(L$photo), flags = "", risk = 0)
    S$flags[is.na(S$flags)] <- ""
    S <- S[order(-S$risk), , drop = FALSE]                # worst fish of the photo
    S <- S[!duplicated(key(S$photo)), , drop = FALSE]
    list(key = key, P = split(L, key(L$photo)),
         risk = stats::setNames(S$risk, key(S$photo)),
         flags = stats::setNames(S$flags, key(S$photo)))
  }
})

## ...and what each photograph IS, as opposed to what it is called. The code
## above is metadata -- site, date, species, number -- and every one of those
## can be corrected. A determination read again turns
## SAUDRUNESUDTOULOUSE_20260427_SQUCEP_004_AT into
## SAUDRUNESUDTOULOUSE_20260427_BARBAR_025_AT and, before this, took the
## specimen's measurements with it: the workbook still held the row under the
## old code, the queue matched on the new one, and a fish digitized a week
## earlier came back in the "new" queue with nothing to say it had ever been
## measured. The fingerprint of the file does not move when the label does.
##
## Cached beside the journals: fingerprinting several hundred photographs on a
## synchronised folder is not something to do at every launch, and a rename --
## the one event this exists for -- changes neither the size nor the mtime the
## cache is keyed on. See intraitR::photo_hash_cached().
PHOTO_HASHES <- local({
  if (!length(CFG$photos)) return(character(0))
  tryCatch(intraitR::photo_hash_cached(
    CFG$photos, file.path(CFG$journal_dir, "photo_hash_cache.tsv")),
    error = function(e) rep(NA_character_, length(CFG$photos)))
})
## THE RENAMES THAT PREDATE THE FINGERPRINT COLUMN.
##
## Reconciling on `photo_hash` works from the moment the fingerprint is
## recorded. It cannot work backwards: a photograph renamed BEFORE the column
## existed left a row naming a file the folder no longer has, so there is
## nothing in the workbook to recognise it by, and hashing the folder harder
## will not conjure the link -- it was never written there. It was written in
## whatever renamed the file.
##
## digitize_landmarks() looks for it and hands the result over; run standalone,
## the app looks in the same place (a FishInTrait project keeps its import
## journals in <project>/journal, next to <project>/measurements/*.xlsx).
## Without it these specimens simply stay in the "new" queue, which is the
## behaviour of every earlier version -- no worse, and no silent guessing.
PROVENANCE <- local({
  k <- CFG$provenance_keys
  if (length(k) && !is.null(names(k))) return(k)
  d <- file.path(dirname(dirname(CFG$xlsx_path)), "journal")
  tryCatch(intraitR::photo_provenance_keys(d),
           error = function(e) stats::setNames(character(0), character(0)))
})
## The reconciliation, without any reporting: used where a table has to be
## brought to the CURRENT naming before it can be compared with another, and
## where the changes are not news -- see the journal merge below.
reconcile_quiet <- function(d) {
  if (is.null(d) || !nrow(d) || !length(CFG$photos)) return(d)
  tryCatch(intraitR::reconcile_photo_names(d, CFG$photos, PHOTO_HASHES,
                                           provenance = PROVENANCE)$data,
           error = function(e) d)
}
## Fingerprint of the photograph at queue position `i`, or of a file by name.
hash_of_photo <- function(i) {
  if (!length(i) || is.na(i) || i < 1L || i > length(PHOTO_HASHES))
    return(NA_character_)
  PHOTO_HASHES[[i]]
}

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
    ## campaign: trained on the INTRAIT campaign workbook (Guyane + Saudrune,
    ## build_campaign_dataset.py); its dataset folder mlmorph_dataset_campaign
    ## carries canon_params.txt, read by the worker (frame centred on LM1-LM2).
    ## combined: ONE model for the campaign photographs AND the FISHMORPH
    ## species photographs (build_combined_dataset.py), the default.
    ## cnn: neural network (heatmaps, train_cnn.py), exported to ONNX -- the
    ## default, best on both sources; same canonical frame, same worker (needs
    ## onnxruntime in the Python environment).
    cnn      = file.path(ML, "mlmorph_run_cnn",      "model.onnx"),
    combined = file.path(ML, "mlmorph_run_combined", "predictor.dat"),
    campaign = file.path(ML, "mlmorph_run_campaign", "predictor.dat"),
    app     = file.path(ML, "mlmorph_run_app",     "predictor.dat"),
    aligned = file.path(ML, "mlmorph_run_aligned", "predictor.dat")))
}

## =============================================================================
## Digitizer core: point scheme, click orders, workbook layout, FISHMORPH
## conventions, seeding geometry, image helpers. Since intraitR 1.39.0 it lives
## in the package (R/digitizer_core.R), shared by the campaign target and the
## FISHMORPH reference target; it is imported here under the same names, so the
## rest of this file reads unchanged.
## =============================================================================
for (.nm in intraitR:::.digitizer_core_names())
  assign(.nm, get(.nm, envir = asNamespace("intraitR")))
rm(.nm)


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
  # ---- toolbars --------------------------------------------------------------
  # One button style for the whole app, defined here rather than borrowed from
  # whatever Bootstrap happens to be loaded: the app must look the same with and
  # without bslib. Buttons carry their ROLE in their weight -- one filled
  # primary (Save), one amber (Mark NA, which destroys a measurement), the rest
  # quiet outlines -- because a row where everything shouts reads as a row where
  # nothing is important.
  ".toolbar{display:flex;flex-wrap:wrap;align-items:center;gap:6px;",
  "margin-bottom:8px;}",
  ".toolbar .form-group{margin-bottom:0;}",
  ".toolbar .selectize-control{margin-bottom:0;}",
  ".toolbar .btn,.lmbar .btn{height:32px;padding:0 12px;font-size:13px;",
  "line-height:30px;border:1px solid #d1d5db;background:#fff;color:#374151;",
  "border-radius:7px;box-shadow:none;transition:background .12s,border-color .12s;}",
  ".toolbar .btn:hover{background:#f3f4f6;border-color:#9ca3af;}",
  ".toolbar .btn:active,.toolbar .btn:focus{outline:none;box-shadow:0 0 0 3px rgba(37,99,235,.15);}",
  ".toolbar .btn-primary{background:#2563eb;border-color:#2563eb;color:#fff;font-weight:600;}",
  ".toolbar .btn-primary:hover{background:#1d4ed8;border-color:#1d4ed8;}",
  ".toolbar .btn-warning{background:#f59e0b;border-color:#f59e0b;color:#fff;font-weight:600;}",
  ".toolbar .btn-warning:hover{background:#d97706;border-color:#d97706;}",
  # Related actions touch, so the eye reads them as one control rather than as
  # four unrelated ones.
  ".tbgroup{display:inline-flex;}",
  ".tbgroup .btn{border-radius:0;margin:0;border-right-width:0;}",
  ".tbgroup .btn:first-child{border-top-left-radius:7px;border-bottom-left-radius:7px;}",
  ".tbgroup .btn:last-child{border-top-right-radius:7px;",
  "border-bottom-right-radius:7px;border-right-width:1px;}",
  ".tbsep{width:1px;height:22px;background:#e5e7eb;margin:0 3px;flex:0 0 auto;}",
  ".tbhint{font-size:11.5px;color:#9ca3af;line-height:1.3;max-width:340px;}",
  ".toolbar .selectize-input{min-height:32px;height:32px;padding:4px 10px;",
  "border-radius:7px;border-color:#d1d5db;}",
  ".toolbar select.form-control{height:32px;padding:2px 8px;font-size:13px;",
  "border-radius:7px;border-color:#d1d5db;}",
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
  "line-height:1.1;text-align:center;border:1px solid #d1d5db;",
  "border-radius:7px;cursor:pointer;transition:filter .12s;}",
  ".lmrow .lmbtn:hover{filter:brightness(0.94);}",
  # A gap between the sections of the bar -- axis, anatomical run, derived and
  # hinges, scale bar. Twenty-four identical buttons in a row is a list; four
  # groups is a map, and the eye finds a point in the group it belongs to.
  ".lmgap{flex:0 0 14px;}",
  # a floor under the photograph: a plot device narrower than this cannot draw
  # anything useful, and a collapsed one cannot draw at all
  "#img{min-width:360px;min-height:360px;}",
  # the zero-segment bar, directly under the photograph
  ".collapsebar{margin:8px 0 10px 0;padding:6px 10px;background:#fffbeb;",
  "border:1px solid #fde68a;border-radius:8px;font-size:13px;}",
  ".collapsebar .form-group{margin-bottom:0;}",
  ".collapsebar .checkbox-inline{margin-right:14px;font-size:12.5px;}",
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

## The navigation guides: a grey track, a darker thumb, and an arrow button at
## each end. Defined here because the tracks and the buttons are built in the
## UI and only the thumbs are rendered by the server.
NAV_TRACK <- "background:#e5e7eb;border:1px solid #d1d5db;border-radius:6px;"
NAV_THUMB <- "position:absolute;background:#6b7280;border-radius:6px;"
NAV_BTN   <- "padding:0 8px;line-height:22px;font-size:13px;color:#374151;"

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
      # --- several individuals on one photograph -------------------------------
      tags$strong("Individuals on this photograph"),
      div(class = "toolbar", style = "margin-top:6px;align-items:center;",
          div(style = "width:90px;",
              numericInput("n_ind", NULL, CFG$individuals_per_photo,
                           min = 1, step = 1)),
          actionButton("ind_add", "+ individual"),
          actionButton("ind_drop", "- individual")),
      uiOutput("ind_bar"),
      radioButtons("ind_order", "Numbering runs",
                   choices = c("top to bottom" = "top",
                               "left to right" = "left",
                               "reading order (rows, left to right)" = "reading"),
                   selected = CFG$individual_order),
      conditionalPanel(
        "input.ind_order == 'reading'",
        div(style = "width:150px;",
            numericInput("ind_per_row", "Individuals per row",
                         CFG$individuals_per_row %||% NA, min = 1, step = 1)),
        helpText("A grid: rows from top to bottom, and within a row from left",
                 "to right, the way text is read. Give the number per row when",
                 "the plate is regular -- 2 for a 2 x 2 -- and the rows are then",
                 "EXACT: i3 is the first of the second row, whatever the",
                 "spacing. Leave it empty and the rows are inferred from the",
                 "snouts already placed, which works but has to guess where one",
                 "row ends.")),
      helpText("A plate of several fish over one ruler. Each fish is saved as",
               tags$code("<photo>_i1, _i2 ..."), "and the scale bar 20-21 is",
               "placed ONCE and inherited by all of them -- one ruler, one",
               "calibration, no scale error added per fish. The number is",
               "SPATIAL: the app refuses a snout placed out of order, so",
               tags$code("_i2"), "names the same fish for every operator, which",
               "is what makes the repeat and operator-bias comparisons valid."),
      tags$hr(),
      radioButtons("quality", "Quality score of the entry",
                   choices = c("Not scored" = "0", "1" = "1", "2" = "2",
                               "3" = "3", "4" = "4", "5" = "5"),
                   selected = "0", inline = TRUE),
      helpText("1 = unusable (specimen unreadable, landmarks largely guessed),",
               "2 = doubtful, 3 = acceptable, 4 = good, 5 = excellent (whole",
               "fish, strictly lateral, every landmark unambiguous). 'Not",
               "scored' leaves the cell empty: an absent score and a bad score",
               "are not the same statement. (Until intraitR 1.40 the scale ran",
               "the other way, 1 = very good; old scores are converted on",
               "reading.)"),
      ## TWO STATEMENTS, NOT ONE. The score says how good the entry is; the tick
      ## says whether anyone has actually looked at it. They are independent,
      ## and conflating them loses the case that matters: a specimen can be
      ## checked AND poor, which is precisely the row a re-photographing list is
      ## built from. Untouched, the score is its default and the tick is off --
      ## "nobody has looked at it", which is a different thing from "somebody
      ## looked and said nothing". The author and the date are stamped only when
      ## the tick is on, so an unaudited opinion cannot be manufactured.
      checkboxInput("reviewed", "Checked: I have looked at this entry", FALSE),
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
      div(class = "toolbar", style = "margin-top:6px;",
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
      checkboxInput("showsegs", "FISHMORPH segments (the 11 measured lines)", TRUE),
      checkboxInput("seglegend", "Segment legend", TRUE),
      checkboxInput("showlines", "Reference lines (outline/eye/belly)", TRUE),
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
                    "Check the conventions on save (3/4 extremes, eye vertical)",
                    value = TRUE),
      helpText("Bd is the MAXIMUM body depth: on save, checks that LM3 is the",
               "most dorsal and LM4 the most ventral landmark of the body",
               "outline. Heights are taken perpendicular to the body axis,",
               "segment by segment, so posture is not flagged. Excluded: the",
               "caudal peduncle and fin (16-19), the appendage tips (12, 15)",
               "and the derived ventral points (8, 9, 11). On a breach, offers",
               "to measure again or to correct automatically."),
      helpText("Also checks the ORDER of the eye vertical -- 5, 13, 7, 14, 6, 8",
               "from the back downwards -- and that LM5 tops the group. An",
               "inversion (the eye clicked bottom-first, LM7 outside 13-14, LM5",
               "below 13) leaves every pair internally consistent, so Ed keeps",
               "its length while Hd or Eh refers to the wrong landmark. It is",
               "never auto-corrected: moving a point to satisfy the order would",
               "invent a measurement. The T-26 corpus already satisfies the",
               "order for 98.6 % of its 1,036 configurations."),
      tags$hr(),
      tags$strong("Workbook"),
      verbatimTextOutput("saved_info"),
      div(class = "toolbar",
          actionButton("flush", "Write the workbook now", class = "btn-primary"),
          actionButton("rebuild", "Rebuild from the journal")),
      helpText("The workbook is written every", CFG$xlsx_flush_every,
               "record(s), atomically. The journal is written at every save and",
               "is the source of truth: 'Rebuild' reconstructs the sheets from",
               "it, which is the recovery path after a crash.")),

    tabPanel(
      "Seed",
      helpText("Once the axis 1 - 22 - 24 - 2 is placed, every other landmark is",
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
  div(class = "toolbar",
      div(class = "tbgroup",
          actionButton("prev_photo", "‹ Previous"),
          actionButton("next_photo", "Next ›")),
      div(class = "tbsep"),
      actionButton("save_specimen", "Save & next", class = "btn-primary"),
      actionButton("skip", "Skip"),
      div(class = "tbsep"),
      div(style = "min-width:260px;",
          selectizeInput("goto_file", NULL, choices = NULL, selected = NULL,
                         width = "260px",
                         options = list(placeholder = "Jump to a photograph...")))),
  # ---- point bar: what acts on the ACTIVE landmark ---------------------------
  # Declaring a point unmeasurable, clearing it, undoing, starting over: these
  # act on the point under the cursor, so they belong beside the landmark bar
  # rather than beside "Save & next", where a slip of one button was a saved
  # specimen. Static, not a renderUI: re-rendering an actionButton resets its
  # counter, which fires its observer as if it had been pressed.
  div(class = "toolbar",
      div(class = "tbgroup",
          actionButton("set_na", "Mark NA", class = "btn-warning"),
          actionButton("clear_pt", "Clear point")),
      div(class = "tbsep"),
      actionButton("predict", "Predict 19 landmarks"),
      tags$span(style = "display:inline-block;vertical-align:middle;margin:0 6px;",
                title = paste("Also place the hinges 22/24 of the broken axis (curved fish).",
                              "Off by default: away from the sites where hinges were",
                              "clicked, predicted hinges tilt the head segment and bias",
                              "the derived points 8/9. Check them before saving."),
                checkboxInput("pred_hinges", "Hinges 22/24 (curved fish)", FALSE, width = "auto")),
      actionButton("validate_pts", "Validate points",
                   title = paste("Mark every point still 'predicted' or 'seeded' as checked",
                                 "and accepted (status 'validated'). Use it only after looking",
                                 "at each point: a validated point is treated as verified.")),
      actionButton("predict_auto", "Auto (no clicks)",
                   title = paste("The global network finds the snout (LM1), the caudal-fin",
                                 "basis (LM2) and the dorsal side on the whole photograph,",
                                 "then the model places the other landmarks. Points already",
                                 "clicked are kept. Needs mlmorph_run_global/model.onnx.")),
      div(class = "tbgroup",
          actionButton("undo", "Undo"),
          actionButton("restart", "Start over"))),
  div(class = "lmbar", uiOutput("lm_buttons")),   # active-landmark bar, bare
  # ---- view bar, immediately above the photograph ----------------------------
  # Zoom belongs next to what it zooms: at high magnification the operator
  # alternates between placing a point and re-framing, and a trip to the side
  # panel between the two breaks that loop.
  div(class = "toolbar", style = "margin-top:6px;",
      div(class = "tbgroup",
          actionButton("zoom_in", "Zoom +"),
          actionButton("zoom_out", "Zoom −"),
          actionButton("zoom_reset", "Whole view")),
      div(class = "tbsep"),
      div(style = "min-width:200px;",
          selectInput("dispmax", NULL,
                      choices = c("Display 800 px (fastest)" = 800,
                                  "Display 1200 px"          = 1200,
                                  "Display 1600 px"          = 1600,
                                  "Display 2400 px"          = 2400,
                                  "Display full resolution"  = 0),
                      selected = 1200, width = "200px")),
      div(style = "min-width:170px;",
          selectInput("panel_h", NULL,
                      choices = c("Panel 500 px (widest)" = 500,
                                  "Panel 700 px"          = 700,
                                  "Panel 900 px"          = 900,
                                  "Panel 1200 px (tallest)" = 1200),
                      selected = 700, width = "170px")),
      div(class = "tbhint",
          "Right-click and drag to pan · double-click for the whole view ·",
          "the zoom centres on the active landmark · no wheel zoom ·",
          "a shorter panel is a wider view")),
  # The panel's height is a control rather than a constant, because it decides
  # the SHAPE of the zoomed view: the window shown follows the panel's aspect
  # ratio, so a short panel is a wide band and a tall one a narrow column.
  # The photograph, with the vertical guide beside it and the horizontal one
  # under it. Both are ordinary HTML: they cannot reach the plot's click
  # handler, which is the whole reason they are not drawn in the picture.
  #
  # THE ARROWS ARE STATIC. Only the grey thumbs are rendered, because an
  # actionButton rebuilt by renderUI comes back with its counter reset to zero,
  # which its observer reads as a fresh press -- and a press that moves the
  # view, which rebuilds the button, which presses it again, is an infinite
  # scroll. The track is a fixed div; what the server draws inside it is a
  # rectangle.
  div(style = "display:flex;align-items:stretch;gap:6px;",
      div(style = "flex:1 1 auto;min-width:0;", uiOutput("img_box")),
      div(style = paste("width:26px;display:flex;flex-direction:column;",
                        "align-items:center;"),
          actionButton("nav_up", "▲", class = "btn btn-light btn-sm",
                       style = NAV_BTN),
          div(style = paste0("position:relative;flex:1 1 auto;width:12px;",
                             "margin:4px 0;", NAV_TRACK),
              uiOutput("nav_v")),
          actionButton("nav_down", "▼", class = "btn btn-light btn-sm",
                       style = NAV_BTN))),
  div(style = "display:flex;align-items:center;gap:6px;margin:6px 32px 0 0;",
      actionButton("nav_left", "◀", class = "btn btn-light btn-sm",
                   style = NAV_BTN),
      div(style = paste0("position:relative;flex:1 1 auto;height:12px;",
                         NAV_TRACK),
          uiOutput("nav_h")),
      actionButton("nav_right", "▶", class = "btn btn-light btn-sm",
                   style = NAV_BTN),
      div(class = "tbhint", style = "margin-left:8px;white-space:nowrap;",
          "grey bar = the whole photograph · dark = what is on screen")),
  # ---- coincident landmarks, immediately under the photograph -----------------
  # A zero is a measurement, and it is decided while looking at the fish -- so
  # the switch belongs under the photograph, not in a settings tab. It is reset
  # for every specimen: a mouth on the belly is a statement about THIS fish.
  # Neither landmark is removed: one takes the coordinates of the other, both
  # stay on the photograph and both are written to the workbook.
  div(class = "collapsebar",
      div(style = "display:inline-block;vertical-align:middle;margin-right:10px;",
          tags$strong("Coincident landmarks:")),
      div(style = "display:inline-block;vertical-align:middle;",
          checkboxGroupInput(
            "collapse", NULL, inline = TRUE,
            choiceNames = unname(vapply(COLLAPSE_RULES, function(r)
              paste0(r$label), character(1))),
            choiceValues = names(COLLAPSE_RULES))),
      uiOutput("collapse_help")),
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
    auto12 = integer(0),                # LM1/LM2 placed by the global network, not clicked
    validated = integer(0),             # predicted/seeded points the operator LOOKED AT and accepted
    na = integer(0),                    # landmarks declared non-measurable
    edited = integer(0),                # landmarks moved by hand this session
    adjusted = integer(0),              # landmarks snapped by the extreme-point
                                        # convention (3/4), exported as "adjusted"
    zoom = 1, cx = NULL, cy = NULL,     # zoom state / view centre
    collapse = character(0),            # segments declared zero on THIS specimen
    meas = NULL, bias = NULL,           # the two workbook sheets, in memory
    q = integer(0), qi = 0L,            # current queue (photo indices) + position
    pending = 0L,                       # records not yet written to the workbook
    ## SEVERAL INDIVIDUALS ON ONE PHOTOGRAPH. A plate of four fish over a ruler
    ## is the normal field object; one photograph = one specimen was an
    ## assumption, not a constraint.
    ind = 1L,                           # individual being digitized (1-based)
    photo = "",                         # code of the photograph on screen, set
                                        # SYNCHRONOUSLY: update*Input() only take
                                        # effect at the end of the reactive
                                        # cycle, so an observer keyed on the text
                                        # field can still see the previous
                                        # photograph and file the count under it
    n_by_photo = integer(0),            # declared count, named by photo code
    n_default = max(1L, as.integer(CFG$individuals_per_photo)),
                                        # count a photograph not yet seen inherits
    ind_ax = NULL)                      # n x 4: LM1 and LM2 of each individual of
                                        # the current photograph, working frame

  ## ---- persistence ----------------------------------------------------------
  ## Resume from the workbook if there is one. The two sheets are held in
  ## memory: they are small (one row per digitization) and having them here is
  ## what lets the queues, the progress display and the bias summary be computed
  ## without touching the disk on every interaction.
  rv$meas <- wb_read_sheet(CFG$xlsx_path, CFG$sheet_measurements)
  rv$bias <- wb_read_sheet(CFG$xlsx_path, CFG$sheet_bias)

  ## THE JOURNAL IS CONSULTED AT START-UP, NOT ONLY BY THE REBUILD BUTTON.
  ##
  ## The workbook is written every `xlsx_flush_every` records, and the last few
  ## of a session wait in memory until the session ends. That is fine while
  ## nothing goes wrong -- and it is exactly what goes wrong on a synchronised
  ## folder: a write refused because the file is open in Excel or locked by the
  ## sync client leaves those records in the journal alone. The next launch
  ## then read the WORKBOOK, found them missing, and put their photographs back
  ## in the "new" queue -- for ever, since re-measuring them wrote to the same
  ## workbook that could not be written. An operator re-measuring the same
  ## fish every morning is the visible symptom of an invisible failed write.
  ##
  ## So the two are reconciled here, IN MEMORY: the journal's records are taken
  ## as they are the source of truth, the queue is immediately right, and
  ## NOTHING IS WRITTEN -- the workbook is repaired by "Write the workbook now"
  ## or by "Rebuild from the journals", both of which stay a deliberate act.
  ## `isolate()`: this runs in the body of the server function, where WRITING
  ## to a reactiveValues is allowed but READING it is not -- rv$meas here would
  ## abort with "Can't access reactive value outside of reactive consumer".
  ## The reconciliation is a one-off at start-up and depends on nothing, which
  ## is exactly what isolate() is for.
  isolate(local({
    j <- tryCatch(intraitR::consolidate_landmarks(CFG$journal_dir,
                                                  points = WB_PTS),
                  error = function(e) NULL)
    if (is.null(j) || !nrow(j)) return(invisible(NULL))
    is_bias <- !is.na(j$target_sheet) & j$target_sheet == CFG$sheet_bias
    ## BOTH SIDES BROUGHT TO THE CURRENT NAMING BEFORE THEY ARE COMPARED.
    ##
    ## The journal is append-only: it holds every record under the code it was
    ## SAVED with, so a specimen re-keyed on an earlier run is still in there
    ## under its dead code. Comparing the raw journal with the workbook then
    ## finds that dead code "missing from the workbook" and puts it back --
    ## every launch, for ever -- and the reconciliation that runs next sees the
    ## restored row collide with the live one and reports an ambiguity that is
    ## nothing of the sort. On the T-26 campaign that manufactured 41 phantom
    ## records and 41 phantom ambiguities out of 41 renames correctly applied.
    ##
    ## Reconciling the journal side FIRST makes the comparison a comparison of
    ## like with like. A record whose code has since changed is then recognised
    ## as present, because it is.
    jm <- reconcile_quiet(wb_normalise(j[!is_bias, , drop = FALSE]))
    jb <- reconcile_quiet(wb_normalise(j[is_bias, , drop = FALSE]))
    ## ... and the workbook side likewise. It is reconciled for real a few lines
    ## down; here only its CODES are needed, brought to the same naming as the
    ## journal's, or the comparison compares two different vocabularies.
    known <- if (is.null(rv$meas) || !nrow(rv$meas)) character(0) else
      as.character(reconcile_quiet(rv$meas)$specimen)
    extra <- jm[!(as.character(jm$specimen) %in% known), , drop = FALSE]

    ## ONLY WHAT THIS SESSION CAN ACT ON.
    ##
    ## The journal is append-only and project-wide: it holds every record ever
    ## saved, under the code it was saved with, for every folder. Reinjecting
    ## all of it into the workbook of ONE folder had two consequences, and the
    ## second is a loop.
    ##
    ## A record whose photograph is not in this folder cannot be reviewed, cannot
    ## be re-measured and cannot be reconciled here: its old name matches no
    ## file, no fingerprint and no provenance. It comes back as `frame_changed`
    ## or `ambiguous` at EVERY launch, is cleared or re-keyed, is written out --
    ## and the journal, which never forgets, puts it back on the next launch.
    ## On T-26 that was 49 records regenerating 37 + 12 warnings, run after run,
    ## with counters that crept down but could never reach zero.
    ##
    ## So the test is the photograph: `photo_file` in THIS folder. That keeps
    ## the safety net exactly where it is needed -- a write that failed for the
    ## specimens being digitized now -- and leaves the rest of the project's
    ## history in the journal, where it belongs, to be picked up by the session
    ## that opens ITS folder. Nothing is lost: no record is deleted, only not
    ## copied into a workbook that has no use for it.
    held <- 0L
    if (nrow(extra)) {
      here <- !is.na(extra$photo_file) &
        basename(as.character(extra$photo_file)) %in% basename(CFG$photos)
      held  <- sum(!here)
      extra <- extra[here, , drop = FALSE]
    }
    if (nrow(extra)) {
      # Both sides went through wb_normalise(), so they carry exactly WB_COLS
      # in the same order and a plain rbind() is safe.
      rv$meas <- if (is.null(rv$meas) || !nrow(rv$meas)) extra else
        rbind(rv$meas, extra)
      rv$pending <- rv$pending + nrow(extra)
      txt <- sprintf(paste("%d digitization(s) of THIS folder were in the",
                           "journal but NOT in the workbook. They are counted",
                           "as done -- the queue is right -- but the workbook",
                           "is behind: press \"Write the workbook now\". A",
                           "write that failed (file open in Excel, folder being",
                           "synced) is the usual cause."), nrow(extra))
      rv$msg <- txt
      try(showNotification(txt, type = "warning", duration = 15), silent = TRUE)
    }
    if (held)
      try(showNotification(sprintf(paste(
        "%d journal record(s) name a photograph that is not in this folder --",
        "another site or date, or a picture digitized under a name it no longer",
        "carries. They are left in the journal, which is where the project's",
        "history lives; nothing is lost and nothing is expected of you here."),
        held), type = "message", duration = 10), silent = TRUE)
    if (!is.null(jb) && nrow(jb) &&
        (is.null(rv$bias) || nrow(jb) > nrow(rv$bias))) rv$bias <- jb
  }))

  ## A PHOTOGRAPH RENAMED IS NOT A PHOTOGRAPH REDISCOVERED.
  ##
  ## Everything downstream keys on the specimen code, which is the file name
  ## without its extension. Correcting a determination renames the file -- and
  ## the code with it -- while the pixels, the landmarks and the scale stay
  ## exactly where they were. Matching the queue on the name alone therefore put
  ## an already-digitized fish back in the "new" queue, with no error and no
  ## warning, to be measured a second time under its new name: two rows, one
  ## fish, and no column saying so.
  ##
  ## So the sheets are reconciled against the folder on the FINGERPRINT of the
  ## files before any queue is built. Rows written before the column existed are
  ## back-filled from the file they still name; rows whose photograph now has
  ## another name are re-keyed, carrying the `_i<k>` of a plate and the
  ## `_<operator>_rep<N>` of a repeat across untouched. Ambiguities -- the same
  ## photograph present twice, a target code already taken -- are reported and
  ## left alone, because a wrong merge is invisible afterwards and a rename done
  ## by hand is not.
  ##
  ## In memory only, like the journal reconciliation above: the queue is right
  ## immediately, and the workbook is repaired by a deliberate press of "Write
  ## the workbook now". The journal, being append-only, keeps the old key --
  ## which is what makes the re-keying auditable rather than a quiet rewriting
  ## of history.
  ## A FUNCTION AND NOT A ONE-OFF BLOCK, because there are two moments at which
  ## the sheets can come to disagree with the folder. The obvious one is launch.
  ## The other is "Rebuild from the journals": the journal is append-only, so it
  ## still holds every record under the code it was SAVED with, and a rebuild
  ## therefore resurrects exactly the old codes the reconciliation had just
  ## replaced. Rebuilding without re-reconciling would undo the repair and put
  ## the renamed specimens straight back in the "new" queue.
  reconcile_sheets <- function() {
    if (!length(CFG$photos)) return(invisible(NULL))
    ## A FAILURE HERE IS REPORTED, NOT SWALLOWED. The reconciliation is allowed
    ## to fail -- the app must still open, and a workbook it could not
    ## reconcile is a workbook exactly as usable as before. What it is NOT
    ## allowed to do is fail SILENTLY: "no rename found" and "the code that
    ## looks for renames threw" are indistinguishable from the outside, and the
    ## second was mistaken for the first for two releases.
    fix <- function(d) {
      if (is.null(d) || !nrow(d)) return(list(data = d, changes = NULL))
      tryCatch(intraitR::reconcile_photo_names(d, CFG$photos, PHOTO_HASHES,
                                               provenance = PROVENANCE),
               error = function(e) {
                 msg <- paste0("Could not reconcile the workbook against the ",
                               "photographs: ", conditionMessage(e),
                               ". Renamed specimens may reappear in the 'new' ",
                               "queue; nothing has been altered.")
                 rv$msg <- msg
                 try(showNotification(msg, type = "error", duration = NULL),
                     silent = TRUE)
                 list(data = d, changes = NULL)
               })
    }
    rm_ <- fix(rv$meas); rb_ <- fix(rv$bias)
    rv$meas <- rm_$data; rv$bias <- rb_$data
    ch <- rbind(rm_$changes, rb_$changes)
    if (is.null(ch) || !nrow(ch)) return(invisible(NULL))
    ren <- ch[ch$status == "renamed", , drop = FALSE]
    amb <- ch[ch$status == "ambiguous", , drop = FALSE]
    if (nrow(ren)) {
      rv$pending <- rv$pending + nrow(ren)
      ex <- utils::head(sprintf("%s -> %s", ren$specimen_old, ren$specimen_new), 3L)
      txt <- sprintf(paste("%d specimen(s) were renamed since they were",
                           "digitized and have been matched back to their",
                           "measurements on the image fingerprint (%s%s).",
                           "They stay OUT of the 'new' queue. Press \"Write",
                           "the workbook now\" to record the new codes."),
                     nrow(ren), paste(ex, collapse = "; "),
                     if (nrow(ren) > 3L) ", ..." else "")
      rv$msg <- txt
      try(showNotification(txt, type = "message", duration = 15), silent = TRUE)
    }
    sup <- ch[ch$status == "superseded", , drop = FALSE]
    frm <- ch[ch$status == "frame_changed", , drop = FALSE]
    ## THE QUEUE IS THE ANSWER TO "IS THERE ANYTHING LEFT TO DO?", SO EVERY
    ## DOUBT GOES BACK INTO IT.
    ##
    ## Leaving such a row in place puts the fish in the "correct" queue, where
    ## the operator is shown a configuration that fits nothing and invited to
    ## adjust it.
    ##
    ## Three findings mean the same thing for the operator -- these coordinates
    ## can no longer be trusted against this image -- and they used to be
    ## handled three different ways: the re-crop cleared and requeued, while the
    ## frame change and the ambiguity only printed a warning and left the row
    ## sitting in the "correct" queue. A warning is read once and gone; the
    ## queue is what is still on screen tomorrow. Splitting the two meant the
    ## queue said "nothing left" while 54 specimens needed attention.
    ##
    ## A few extra fish to measure costs an afternoon. A queue that lies costs
    ## the campaign. Clearing the COORDINATES rather than deleting the row keeps
    ## the record, and the journal keeps the original configuration either way
    ## -- "Rebuild from the journal" restores it if it is ever wanted back.
    ## Retourne le nombre de SPECIMENS distincts, pas de lignes. Un specimen
    ## occupe plusieurs lignes -- un individu de planche `_iK`, une repetition
    ## `_repN`, ou simplement son ancien et son nouveau nom quand les deux sont
    ## passes ici. Annoncer les lignes donnait "37 specimen(s) ... 94 row(s)",
    ## un ecart qui ressemble a une avarie alors qu'il n'en est pas une, et qui
    ## surtout ne se compare pas au compteur de la file.
    requeue <- function(codes) {
      codes <- unique(codes[!is.na(codes) & nzchar(codes)])
      if (!length(codes) || is.null(rv$meas) || !nrow(rv$meas)) return(0L)
      hit <- which(rv$meas$specimen %in% codes)
      # `v[integer(0)] <- NA` is an error in R, not a no-op: guard on the hit.
      if (!length(hit)) return(0L)
      for (cc in WB_COORD_COLS) rv$meas[[cc]][hit] <- NA_real_
      rv$meas$photo_hash[hit] <- NA_character_
      rv$pending <- rv$pending + length(hit)
      length(unique(sub("_i[0-9]+$", "", sub("_rep[0-9]+$", "",
                                             rv$meas$specimen[hit]))))
    }

    img <- ch[ch$status == "image_changed", , drop = FALSE]
    if (nrow(img)) {
      n <- requeue(img$specimen_old)
      try(showNotification(sprintf(paste(
        "%d photograph(s) have been RE-CROPPED since they were digitized (%s).",
        "The landmarks belong to the old framing and point at the wrong pixels",
        "now, so they have been cleared and %d specimen(s) are back in the",
        "'new' queue. The journal keeps the original configuration."),
        nrow(img), paste(utils::head(img$specimen_old, 3L), collapse = "; "), n),
        type = "warning", duration = NULL), silent = TRUE)
    }
    if (nrow(sup)) {
      rv$pending <- rv$pending + 1L
      try(showNotification(sprintf(paste(
        "%d row(s) were the SAME digitization present twice -- an old code",
        "still carried alongside the one that replaced it, with identical",
        "coordinates. The duplicate has been dropped; no measurement is lost."),
        nrow(sup)), type = "message", duration = 12), silent = TRUE)
    }
    if (nrow(frm)) {
      ## RE-KEY BEFORE REQUEUING, OR THE ROW DISAPPEARS ALTOGETHER.
      ##
      ## reconcile_photo_names() REPORTS a frame change, it does not rename:
      ## the row keeps the code and the file name it was digitized under. Those
      ## no longer name anything on disk once the specimen has been re-keyed
      ## (`GOBOCC_010_AT.jpeg` is now `..._0016.jpeg`). Clearing the
      ## coordinates then removes the row from the "correct" queue without ever
      ## putting it in the "new" one -- because that queue is built from the
      ## PHOTOGRAPHS in the folder, and no photograph answers to the old name.
      ## On T-26 that hid 42 specimens: the queue said 34 when it was 76.
      ##
      ## `photo_file_new` is exactly the file that was matched, so the current
      ## identity is readable from it. Any `_iK` / `_repN` suffix is carried
      ## over: it names a fish within a photograph, not the photograph.
      k <- match(rv$meas$specimen, frm$specimen_old)
      j <- which(!is.na(k))
      if (length(j)) {
        newf <- frm$photo_file_new[k[j]]
        oldf <- frm$photo_file_old[k[j]]
        ok <- !is.na(newf) & nzchar(newf) & !grepl("|", newf, fixed = TRUE)
        if (any(ok)) {
          jj  <- j[ok]
          suf <- substring(rv$meas$specimen[jj],
                           nchar(tools::file_path_sans_ext(oldf[ok])) + 1L)
          rv$meas$specimen[jj]   <- paste0(tools::file_path_sans_ext(newf[ok]), suf)
          rv$meas$photo_file[jj] <- newf[ok]
        }
      }
      n <- requeue(c(frm$specimen_old,
                     if (length(j)) rv$meas$specimen[j] else character(0)))
      try(showNotification(sprintf(paste(
        "%d specimen(s) match a photograph of the same fish at a DIFFERENT",
        "pixel size (%s). The picture was re-cropped after digitizing, so the",
        "landmarks do not transfer. They have been cleared, re-keyed to the",
        "photograph now on disk, and %d specimen(s) are back in the queue --",
        "the journal keeps the original."),
        nrow(frm), paste(utils::head(frm$specimen_old, 2L), collapse = "; "), n),
        type = "warning", duration = NULL), silent = TRUE)
    }
    if (nrow(amb)) {
      ## BOTH SIDES OF THE AMBIGUITY GO BACK, not just the row being examined.
      ## The finding is "this image exists under several names with different
      ## coordinates": requeuing one of them would leave the other looking
      ## finished, and the doubt would survive in the half that stayed.
      cand <- trimws(unlist(strsplit(as.character(amb$photo_file_new), "|",
                                     fixed = TRUE)))
      also <- if (is.null(rv$meas) || !nrow(rv$meas)) character(0) else
        rv$meas$specimen[!is.na(rv$meas$photo_file) &
                           rv$meas$photo_file %in% cand]
      n <- requeue(c(amb$specimen_old, also))

      ## THE SPENT HALF IS DROPPED, HERE AND NOWHERE ELSE.
      ##
      ## Once both halves are cleared, the one whose photograph is NOT in the
      ## folder can never be reached again: it carries no coordinates, and no
      ## image answers to its name. Left in place it is a dead row -- and it
      ## cannot be cleaned later either, because clearing its hash is exactly
      ## what stops the next run from recognising it as ambiguous at all. This
      ## is the only moment the evidence exists.
      ##
      ## Dropped only when its live counterpart is present (`length(also)`):
      ## without that, the row would be the last trace of the fish.
      if (length(also)) {
        gone <- amb$specimen_old[!(amb$photo_file_old %in% basename(CFG$photos))]
        keep <- !(rv$meas$specimen %in% gone)
        if (any(!keep)) {
          rv$meas <- rv$meas[keep, , drop = FALSE]
          rv$pending <- rv$pending + sum(!keep)
        }
      }
      try(showNotification(sprintf(paste(
        "%d photograph(s) could not be matched unambiguously -- the same image",
        "digitized twice under two names, with DIFFERENT coordinates: %s.",
        "Rather than leave the doubt in the workbook, %d specimen(s) have been",
        "put back in the 'new' queue and are to be measured again. Nothing is",
        "lost: the journal keeps every configuration."),
        nrow(amb), paste(utils::head(amb$specimen_old, 3L), collapse = "; "), n),
        type = "warning", duration = 20), silent = TRUE)
    }
    invisible(NULL)
  }
  isolate(reconcile_sheets())

  ## HOW MANY INDIVIDUALS A PHOTOGRAPH HOLDS IS READ BACK FROM WHAT WAS SAVED.
  ## The count lives in memory, and its default is a launch argument: a plate
  ## of four digitized as `<photo>_i1 ... _i4` was looked up, on the next
  ## launch, under the bare `<photo>` of the default count of one -- found
  ## nothing, and went back into the "new" queue with its four fish already
  ## measured. The identifiers themselves say how many there are, so they are
  ## asked rather than assumed. `isolate()` for the same reason as above.
  isolate(local({
    ids <- if (is.null(rv$meas) || !nrow(rv$meas)) character(0) else
      unique(as.character(rv$meas$specimen))
    m <- regmatches(ids, regexec("^(.*)_i([0-9]+)$", ids))
    hit <- vapply(m, length, integer(1)) == 3L
    if (!any(hit)) return(invisible(NULL))
    base <- vapply(m[hit], function(v) v[2], character(1))
    k <- as.integer(vapply(m[hit], function(v) v[3], character(1)))
    n <- tapply(k, base, max)
    for (nm in names(n)) rv$n_by_photo[[nm]] <- as.integer(n[[nm]])
  }))

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

  ## ---- several individuals on one photograph --------------------------------
  ## The code typed in the side panel names the PHOTOGRAPH. When it carries more
  ## than one fish, the code of the individual is that code plus `_i<k>`, and the
  ## repeat convention composes on top of it without any change:
  ## PLATE12_i2_AT_rep3. Everything downstream keys on `individual` = cur_code(),
  ## so the repeats, the operator bias and the "already done" queues all work per
  ## FISH rather than per photograph, which is what they were always about.
  photo_code <- function() {
    id <- trimws(input$specimen_id %||% "")
    if (nzchar(id)) id else "specimen"
  }
  ## Declared number of individuals, per photograph. Stored per photo (a plate is
  ## not guaranteed to hold the same number as the previous one) but STICKY: a
  ## photograph never opened inherits the last count the operator declared, which
  ## is right far more often than 1 on a batch of plates.
  ## The count belongs to the PHOTOGRAPH, so it is keyed on the photograph's own
  ## code (rv$photo) rather than on the editable text field: renaming a specimen
  ## does not change how many fish are lying on the plate.
  ## `[` and not `[[`: a photograph never declared has no entry, and `[[` on a
  ## missing name is an error rather than a missing value.
  photo_key <- function() if (nzchar(rv$photo)) rv$photo else photo_code()
  n_ind_of <- function(code = photo_key()) {
    n <- unname(rv$n_by_photo[code])
    if (!length(n) || is.na(n)) n <- rv$n_default
    max(1L, as.integer(n))
  }
  ind_i <- function() max(1L, min(as.integer(rv$ind), n_ind_of()))
  ind_code <- function(code, k, n = n_ind_of(code))
    if (n > 1L) paste0(code, "_i", k) else code

  cur_code <- function() ind_code(photo_code(), ind_i())

  ## Individuals of a photograph already in the measurements sheet.
  saved_inds <- function(code = photo_code()) {
    done <- saved_specimens()
    if (!length(done)) return(integer(0))
    n <- n_ind_of(code)
    which(vapply(seq_len(n), function(k) ind_code(code, k, n) %in% done,
                 logical(1)))
  }
  ## First individual still to do, or the last one when the plate is finished.
  next_ind <- function(code = photo_code()) {
    n <- n_ind_of(code); done <- saved_inds(code)
    todo <- setdiff(seq_len(n), done)
    if (length(todo)) todo[1] else n
  }

  ## THE NUMBERING IS SPATIAL, NOT CHRONOLOGICAL. `_i2` has to name the same
  ## fish for every operator: in repeat mode two operators digitizing the same
  ## plate in opposite orders would otherwise be compared fish against fish, and
  ## the operator bias that comes out of it measures nothing at all. So the
  ## number is fixed by position on the plate -- top to bottom by default, left
  ## to right for a plate laid out horizontally -- and the app checks it on the
  ## click that places LM1, the FIRST click of a fish, so the operator is stopped
  ## before digitizing the wrong one rather than told about it afterwards.
  ord_mode <- function() {
    m <- input$ind_order %||% CFG$individual_order
    if (m %in% c("top", "left", "reading")) m else "top"
  }
  ## The 1-D modes compare ONE coordinate. "reading" compares two, and keeps
  ## `ord_j() == 1L` so that everything written for the horizontal case -- the
  ## wording, the first-fish hint -- stays true of the within-row half of it.
  ord_j <- function() if (ord_mode() == "top") 2L else 1L
  ord_word <- function() switch(ord_mode(),
    top = "top to bottom", left = "left to right",
    reading = "in reading order: rows from top to bottom, and within a row from left to right")

  ## --- reading order -------------------------------------------------------
  ## WHY A THIRD MODE. A plate of four fish in two rows of two cannot be ordered
  ## by one coordinate: the second fish of the first row is to the RIGHT of the
  ## first, and the third is BELOW them both. Either 1-D rule refuses a correct
  ## click on half the plate, and an operator who is refused when right soon
  ## stops reading the message.
  ##
  ## HOW A ROW IS DECIDED. Told, when the operator says how many fish there are
  ## per row: row(k) = ceiling(k / per_row), exact whatever the spacing, and no
  ## parameter to tune. Otherwise inferred from the snouts already placed, with
  ## a tolerance that is STATED rather than hidden -- two snouts belong to the
  ## same row when their vertical distance is under a fifth of the frame
  ## height. It is a guess, and it is why the exact route is offered first.
  ind_per_row <- function() {
    v <- suppressWarnings(as.integer(input$ind_per_row %||% NA))
    if (length(v) != 1L || is.na(v) || v < 1L) NA_integer_ else v
  }
  row_tol <- function() {
    h <- rv$h
    if (!is.finite(h) || h <= 0) Inf else h / 5
  }
  ## Row index of every individual, 1-based. NA where it cannot be told.
  ind_rows <- function() {
    n <- n_ind_of()
    per <- ind_per_row()
    if (!is.na(per)) return(((seq_len(n) - 1L) %/% per) + 1L)
    A <- rv$ind_ax
    if (is.null(A) || !nrow(A)) return(rep(NA_integer_, n))
    y <- A[seq_len(min(n, nrow(A))), 2]
    length(y) <- n
    tol <- row_tol()
    r <- rep(NA_integer_, n)
    cur <- 1L; last <- NA_real_
    for (k in seq_len(n)) {
      if (is.na(y[k])) next
      if (!is.na(last) && (y[k] - last) > tol) cur <- cur + 1L
      r[k] <- cur; last <- y[k]
    }
    r
  }
  ## Is the snout `v = c(x, y)` acceptable for individual `k`? Returns "" when
  ## it is, and the reason when it is not. The comparison is with the
  ## individuals immediately before and after that are actually placed: an
  ## unplaced neighbour constrains nothing, exactly as in the 1-D rule.
  reading_reject <- function(k, v) {
    n <- n_ind_of()
    A <- rv$ind_ax
    if (is.null(A) || !nrow(A)) return("")
    rows <- ind_rows()
    tol <- row_tol()
    same_row <- function(a, b) {
      if (!is.na(rows[a]) && !is.na(rows[b])) return(rows[a] == rows[b])
      ya <- A[a, 2]; yb <- if (b == k) v[2] else A[b, 2]
      if (!is.finite(ya) || !is.finite(yb)) return(NA)
      abs(ya - yb) <= tol
    }
    # The previous placed individual: k must come after it.
    prev <- NA_integer_
    for (j in rev(seq_len(k - 1L))) if (is.finite(A[j, 1])) { prev <- j; break }
    if (!is.na(prev)) {
      sr <- same_row(prev, k)
      if (isTRUE(sr) && v[1] <= A[prev, 1])
        return(sprintf(paste("individual %d is on the same row as %d, so its",
                             "snout must be to its RIGHT (x = %.0f is not",
                             "greater than %.0f)"), k, prev, v[1], A[prev, 1]))
      if (isFALSE(sr) && v[2] <= A[prev, 2])
        return(sprintf(paste("individual %d starts a new row, so its snout must",
                             "be BELOW individual %d (y = %.0f is not greater",
                             "than %.0f)"), k, prev, v[2], A[prev, 2]))
    }
    # The next placed individual: k must come before it. Same test, mirrored.
    nxt <- NA_integer_
    if (k < n) for (j in seq.int(k + 1L, n)) if (is.finite(A[j, 1])) { nxt <- j; break }
    if (!is.na(nxt)) {
      sr <- same_row(nxt, k)
      if (isTRUE(sr) && v[1] >= A[nxt, 1])
        return(sprintf(paste("individual %d is on the same row as %d, so its",
                             "snout must be to its LEFT (x = %.0f is not less",
                             "than %.0f)"), k, nxt, v[1], A[nxt, 1]))
      if (isFALSE(sr) && v[2] >= A[nxt, 2])
        return(sprintf(paste("individual %d comes before %d, which is on a",
                             "later row, so its snout must be ABOVE it",
                             "(y = %.0f is not less than %.0f)"),
                       k, nxt, v[2], A[nxt, 2]))
    }
    ""
  }

  ## Ordering coordinate of every individual of the photograph on screen, NA
  ## where LM1 is not known. Held in the ORIGINAL frame of the file, never in the
  ## working frame: a vertical flip would otherwise reverse "top to bottom" and
  ## an operator who flipped a plate would number it upside down with respect to
  ## one who did not. `flip_pt` is an involution, so the same call converts each
  ## way.
  to_orig <- function(p) flip_pt(p, rv$flip)
  ind_ord <- function() {
    A <- rv$ind_ax
    if (is.null(A) || !nrow(A)) return(numeric(0))
    A[, ord_j()]
  }
  ## The open interval individual `k` must fall in: below every individual that
  ## precedes it, above every individual that follows it. Both bounds may be
  ## infinite -- an unplaced neighbour constrains nothing.
  ind_bounds <- function(k) {
    o <- ind_ord()
    if (!length(o)) return(c(-Inf, Inf))
    k <- as.integer(k)
    before <- if (k > 1L) o[seq_len(k - 1L)] else numeric(0)
    after  <- if (k < length(o)) o[seq.int(k + 1L, length(o))] else numeric(0)
    c(if (any(is.finite(before))) max(before, na.rm = TRUE) else -Inf,
      if (any(is.finite(after)))  min(after,  na.rm = TRUE) else  Inf)
  }
  ## Reshape the axis table when the declared count changes: keep what is known,
  ## pad or trim the rest. Never `[<-` with a zero-length index (that errors even
  ## when the index selects nothing), hence the explicit rebuild.
  ind_ax_resize <- function(n) {
    A <- matrix(NA_real_, nrow = n, ncol = 4)
    old <- rv$ind_ax
    if (!is.null(old) && nrow(old)) {
      k <- min(n, nrow(old))
      A[seq_len(k), ] <- old[seq_len(k), , drop = FALSE]
    }
    rv$ind_ax <- A
    invisible(A)
  }
  ## Record the axis of the individual on screen, so the other individuals can be
  ## drawn on the plate and the ordering rule has something to compare against.
  ind_ax_set <- function(k = ind_i(), P = rv$pred) {
    n <- n_ind_of()
    if (is.null(rv$ind_ax) || nrow(rv$ind_ax) != n) ind_ax_resize(n)
    if (k < 1L || k > n) return(invisible(NULL))
    A <- rv$ind_ax
    A[k, ] <- c(if (fin_row(P, 1L)) to_orig(P["1", ]) else c(NA_real_, NA_real_),
                if (fin_row(P, 2L)) to_orig(P["2", ]) else c(NA_real_, NA_real_))
    rv$ind_ax <- A
    invisible(NULL)
  }
  ## Rebuild the whole table from the measurements sheet: reopening a plate half
  ## done must restore the positions the rule is checked against, not start from
  ## an empty table and let the operator renumber the fish by accident.
  ind_ax_reload <- function(code = photo_code()) {
    n <- n_ind_of(code)
    A <- matrix(NA_real_, nrow = n, ncol = 4)
    m <- rv$meas
    if (!is.null(m) && nrow(m))
      for (k in seq_len(n)) {
        i <- match(ind_code(code, k, n), m$specimen)
        if (is.na(i)) next
        v <- suppressWarnings(as.numeric(
          c(m[["1_X"]][i], m[["1_Y"]][i], m[["2_X"]][i], m[["2_Y"]][i])))
        if (length(v) == 4L) A[k, ] <- v
      }
    rv$ind_ax <- A
    invisible(A)
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
  ## ROWS WITH NO AXIS DO NOT COUNT AS DIGITIZED. A row carrying a specimen, a
  ## photograph and no coordinate at all -- written by a press of "Save" on a
  ## photograph nothing had been placed on, which the guard in save_specimen()
  ## now refuses -- would otherwise take its specimen out of the "new" queue for
  ## ever without it ever having been measured. Reading the axis back is the
  ## same test the guard applies, so the sheet and the app agree on what "done"
  ## means; existing empty rows simply return to the queue and are overwritten
  ## by their own identifier the moment they are measured.
  saved_specimens <- function() {
    m <- rv$meas
    if (is.null(m) || !nrow(m)) return(character(0))
    ok <- !is.na(m$specimen) &
      is.finite(suppressWarnings(as.numeric(m[["1_X"]]))) &
      is.finite(suppressWarnings(as.numeric(m[["1_Y"]]))) &
      is.finite(suppressWarnings(as.numeric(m[["2_X"]]))) &
      is.finite(suppressWarnings(as.numeric(m[["2_Y"]])))
    unique(m$specimen[ok])
  }
  ## PHOTOGRAPHS that need no further work in the CURRENT mode. The unit of work
  ## is the individual, the unit of navigation is the photograph, and on a plate
  ## the two stopped coinciding: a photograph is finished when every individual
  ## declared on it is -- measured (new/correct), or carrying its full complement
  ## of repeats. Anything short of that leaves the plate in the queue.
  photo_complete <- function(code) {
    n <- n_ind_of(code)
    if (isTRUE(rep_mode())) {
      tgt <- rep_target()
      return(all(vapply(seq_len(n), function(k)
        length(saved_reps(ind_code(code, k, n))) >= tgt, logical(1))))
    }
    photo_done(code)
  }
  photos_todo <- function(codes)
    which(!vapply(codes, photo_complete, logical(1), USE.NAMES = FALSE))
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
    rv$seeded <- integer(0); rv$adjusted <- integer(0); rv$auto12 <- integer(0)
    rv$validated <- integer(0)
    rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL
    # A declared zero is a statement about ONE fish: it never carries over to
    # the next photograph.
    rv$collapse <- character(0)
    updateCheckboxGroupInput(session, "collapse", selected = character(0))
    # The score and the tick qualify ONE entry: they never trail behind the
    # operator onto the next specimen. A reloaded entry puts its own back
    # (seed_from_sheet).
    updateRadioButtons(session, "quality", selected = "0")
    updateCheckboxInput(session, "reviewed", value = FALSE)
  }

  ## ---- the queues -----------------------------------------------------------
  ## A queue is a set of INDICES into CFG$photos, so switching mode never
  ## reloads the folder and the photograph on screen keeps its identity.
  ##   new     : photographs not yet in the measurements sheet
  ##   correct : those that are (their points are reloaded on arrival)
  ##   repeat  : every photograph, until each has its complement of repeats
  ## A photograph counts as done when EVERY individual declared on it is in the
  ## sheet. Testing the photo code itself was correct only as long as one
  ## photograph meant one specimen: on a plate the codes in the sheet are
  ## `<photo>_i1 ... _i<n>` and the photo code appears nowhere, so the plain
  ## membership test left every plate in the "new" queue for ever.
  photo_ndone <- function(code) length(saved_inds(code))
  photo_done  <- function(code) photo_ndone(code) >= n_ind_of(code)
  ## batch run: flagged photographs first (decreasing risk), the others after
  batch_sort <- function(idx) {
    if (is.null(BATCH) || !identical(CFG$batch_order, "risk") || !length(idx)) return(idx)
    r <- unname(BATCH$risk[BATCH$key(CFG$photos[idx])])
    r[!is.finite(r)] <- -Inf
    idx[order(-r, idx)]
  }
  queue_of <- function(m = cur_mode()) {
    done <- vapply(PHOTO_CODES, photo_done, logical(1), USE.NAMES = FALSE)
    started <- vapply(PHOTO_CODES, function(c0) photo_ndone(c0) > 0L,
                      logical(1), USE.NAMES = FALSE)
    switch(m,
           # "new" keeps a plate only partly measured: it still has work on it.
           new     = batch_sort(which(!done)),
           correct = which(started),
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
    q <- suppressWarnings(as.numeric(m$quality_score[i]))
    updateRadioButtons(session, "quality",
                       selected = if (is.finite(q) && q >= 1 && q <= 5)
                         as.character(round(q)) else "0")
    # The tick comes back as it was left. It is deliberately NOT reset to FALSE
    # on reopening: "checked" is a statement about the entry, and a correction
    # pass that changes nothing must not silently retract it. Saving re-stamps
    # the author and the date, so the last person to look at it is the one
    # recorded.
    rvw <- as.character(m$reviewed[i])
    updateCheckboxInput(session, "reviewed",
                        value = !is.na(rvw) && tolower(rvw) %in% c("yes", "true", "1"))
    # A zero recorded earlier is read from what was DECLARED when the workbook
    # says so, and only otherwise inferred back from the coordinates. The two
    # normally agree; when they do not, the declaration is the statement the
    # operator actually made -- a coincidence read off the geometry cannot tell
    # a rule that was applied from two points that happened to land together,
    # and cannot see a rule whose points were later moved apart at all.
    declared <- as.character(m$collapse_rules[i])
    act <- if (!is.na(declared) && nzchar(declared))
      intersect(strsplit(declared, ";", fixed = TRUE)[[1]], names(COLLAPSE_RULES))
    else collapse_detect(P)
    rv$collapse <- act
    updateCheckboxGroupInput(session, "collapse", selected = act)
    rv$adjusted <- union(rv$adjusted, collapse_points(act))
    # only a COPY is taken over by its rule; a projected LM4 keeps the abscissa
    # that was clicked, so it stays a measurement
    rv$edited   <- setdiff(rv$edited, collapse_points(act, kinds = "move"))
    TRUE
  }
  ## Pre-fill from the batch run. Every landmark comes in as "predicted",
  ## LM1 and LM2 included (rv$auto12): nobody has looked at this photograph yet.
  seed_from_batch <- function() {
    if (is.null(BATCH) || !identical(cur_mode(), "new") || n_ind_of(rv$photo) != 1L)
      return(FALSE)
    d <- BATCH$P[[BATCH$key(rv$orig)]]
    if (is.null(d) || !nrow(d)) return(FALSE)
    d <- d[(d$landmark >= 1 & d$landmark <= N_ANAT | d$landmark %in% c(CURVE_PT, EXTRA_HINGES[1], SCALE_PTS)) &
             is.finite(d$X) & is.finite(d$Y), , drop = FALSE]
    # coordinates of another version of the photograph (re-cropped since)
    if (!nrow(d) || any(d$X > rv$w + 1 | d$Y > rv$h + 1)) return(FALSE)
    M <- rv$pred
    M[as.character(d$landmark), ] <- as.matrix(d[, c("X", "Y")])
    if (isTRUE(input$pin) || isTRUE(input$auto_constraints)) M <- apply_conventions(M)
    rv$pred <- collapse_pred(M)
    rv$auto12 <- intersect(c(1L, 2L), d$landmark)
    rv$edited <- integer(0); rv$placed_order <- integer(0); rv$seeded <- integer(0)
    rv$sel <- if (all(SCALE_PTS %in% d$landmark)) ANAT_ORDER[1] else SCALE_PTS[1]
    TRUE
  }
  load_queue_photo <- function(k) {
    n <- length(rv$q)
    if (!n) { rv$qi <- 0L; return(invisible(NULL)) }
    k <- max(1L, min(as.integer(k), n)); rv$qi <- k
    i <- rv$q[k]
    rv$orig <- CFG$photos[i]
    code <- PHOTO_CODES[i]
    rv$photo <- code                                # synchronous; see rv$photo
    updateTextInput(session, "specimen_id", value = code)
    updateSelectizeInput(session, "goto_file", selected = i)
    load_working()                                  # resets every point
    # The plate: how many fish it carries, which of them are done, and where
    # they lie. Arriving on a half-finished plate must resume at the first gap,
    # not at individual 1 -- and must know the positions the ordering rule is
    # checked against before the operator clicks anything.
    nn <- n_ind_of(code)
    updateNumericInput(session, "n_ind", value = nn)
    ind_ax_reload(code)
    rv$ind <- next_ind(code)
    reloaded <- if (identical(cur_mode(), "correct"))
      seed_from_sheet(ind_code(code, ind_i(), nn)) else FALSE
    batched <- if (!reloaded) seed_from_batch() else FALSE
    if (isTRUE(rep_mode())) updateNumericInput(session, "rep_i",
                                               value = next_rep(cur_code()))
    if (batched) {
      fl <- unname(BATCH$flags[BATCH$key(rv$orig)])
      notify(if (!is.na(fl) && nzchar(fl))
               sprintf("Batch prediction FLAGGED (%s): check every point, LM1 and LM2 first.", fl)
             else "Batch prediction loaded: click LM20/21 on the ruler, then review the points.",
             if (!is.na(fl) && nzchar(fl)) "warning" else "message")
    }
    rv$msg <- sprintf(
      "%s (%d/%d in the '%s' queue). %s",
      code, k, n, cur_mode(),
      if (batched) "Points proposed by the batch run (all 'predicted'): click the ruler, then review."
      else if (!reloaded) "Click the snout (point 1)."
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
      todo <- photos_todo(PHOTO_CODES[rv$q])
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

  ## ---- the visible window ---------------------------------------------------
  ##
  ## THE PROBLEM THIS SOLVES. The window used to be the photograph's own
  ## rectangle divided by the zoom. With `asp = 1`, a PORTRAIT photograph in a
  ## panel two thousand pixels wide is drawn as a narrow column with the whole
  ## width of the screen left empty on either side -- and zooming in on the head
  ## of a fish then shows a tall sliver of it, with the body running off the
  ## right edge into space that was never used. The fish is horizontal; the
  ## window was vertical.
  ##
  ## THE RULE. The window follows the PANEL's aspect ratio, not the file's. At
  ## zoom 1 it is the smallest such window that still contains the whole
  ## photograph, so nothing is lost and the view is what it always was; above
  ## zoom 1 the extra room goes where the panel is wide, which is sideways. The
  ## panel's height is a control (see "Panel ... px"), so the shape of the view
  ## is the operator's to choose: short panel, wide band.
  view_ar <- function() {
    cd <- session$clientData
    w <- cd[["output_img_width"]]; h <- cd[["output_img_height"]]
    if (is.numeric(w) && is.numeric(h) && length(w) && length(h) &&
        is.finite(w) && is.finite(h) && h > 0 && w > 0) return(w / h)
    # Before the first flush the panel's size is unknown; falling back to the
    # file's own ratio reproduces exactly the previous behaviour rather than
    # guessing a shape.
    if (is.finite(rv$w) && is.finite(rv$h) && rv$h > 0) rv$w / rv$h else 1
  }
  ## Half-width and half-height of the window, in image pixels.
  view_half <- function() {
    w <- rv$w; h <- rv$h
    if (!is.finite(w) || !is.finite(h) || w <= 0 || h <= 0) return(c(1, 1))
    ar <- view_ar()
    hw <- w / 2; hh <- h / 2
    if (hw / hh < ar) hw <- hh * ar else hh <- hw / ar   # contain, never crop
    z <- max(1, rv$zoom %||% 1)
    c(hw / z, hh / z)
  }
  ## Centre the window, allowing it to be WIDER than the photograph: the usual
  ## `min(max(c, half), span - half)` inverts when `2 * half > span` and would
  ## push the view off the image instead of centring it on it.
  view_clamp <- function(c0, half, span) {
    if (!is.finite(c0)) c0 <- span / 2
    if (2 * half >= span) span / 2 else min(max(c0, half), span - half)
  }

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
    # The drag is expressed as a fraction of the PANEL, so it is converted with
    # the panel's own window rather than with the file's rectangle: otherwise a
    # pan of one panel-width moves the image by a photograph-width, and the
    # cursor and the picture stop travelling together the moment the two shapes
    # differ -- which, since the window now follows the panel, is always.
    v <- view_half()
    rv$cx <- rv$cx - input$pan$dx * (2 * v[1])
    rv$cy <- rv$cy - input$pan$dy * (2 * v[2])
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
    rv$pred <- collapse_pred(P2)
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
    # The window is now allowed to be wider than the photograph, so there is
    # clickable background beside it -- which there was not when the plot region
    # was the image itself. A landmark placed out there would be a coordinate
    # outside the file: refused with the reason, rather than written.
    if (!all(is.finite(p)) || p[1] < 0 || p[2] < 0 ||
        p[1] > rv$w || p[2] > rv$h) {
      notify("That click is outside the photograph.", "warning")
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
    just <- rv$sel
    # LM23 is COMPUTED, not measured: it is rebuilt from LM1, LM6, LM9 and the
    # head axis after every change. A click on it would be undone on the spot,
    # so it is refused with the reason rather than silently swallowed.
    if (just == HEAD_PT) {
      notify(paste("LM23 is derived from LM1, LM6, LM9 and the head axis:",
                   "move one of those instead."), "warning")
      return()
    }
    # THE ORDERING RULE, checked on the click that places LM1. Refused rather
    # than corrected afterwards: the whole point is that the operator digitizes
    # the fish the number designates, and a renumbering after the fact would
    # rewrite identifiers that are already in the journal.
    if (just == 1L && n_ind_of() > 1L && ord_mode() == "reading") {
      nn <- n_ind_of(); k <- ind_i()
      why <- reading_reject(k, to_orig(p))
      if (nzchar(why)) {
        notify(sprintf(paste("Individual %d of %d: the numbering runs %s -- %s.",
                             "Pick the right fish, or select in the bar the",
                             "individual this one really is."),
                       k, nn, ord_word(), why), "error")
        return()
      }
      # Same courtesy as the 1-D rule for the first fish of a plate, which has
      # no placed neighbour to be checked against: i1 is expected top-left, and
      # a snout in the wrong quarter of the frame is worth a word, not a
      # refusal -- plates are not always tidy, and the operator is the one
      # looking at the fish.
      if (k == 1L && is.finite(rv$w) && is.finite(rv$h)) {
        v <- to_orig(p)
        per <- ind_per_row()
        ncol_ <- if (!is.na(per)) per else max(1L, ceiling(sqrt(nn)))
        nrow_ <- max(1L, ceiling(nn / ncol_))
        if (v[1] > rv$w / ncol_ || v[2] > rv$h / nrow_)
          notify(sprintf(paste("Individual 1 of %d is expected to be the",
                               "top-left fish of the plate, and this snout is",
                               "outside the first cell of a %d x %d grid.",
                               "Check you are not numbering the plate",
                               "backwards."), nn, nrow_, ncol_), "warning")
      }
    } else if (just == 1L && n_ind_of() > 1L) {
      nn <- n_ind_of(); k <- ind_i()
      b <- ind_bounds(k); v <- to_orig(p)[ord_j()]
      if (v <= b[1] || v >= b[2]) {
        notify(sprintf(paste("Individual %d of %d: the numbering runs %s, so this",
                             "snout must fall %sbetween the individuals already",
                             "placed%s. Pick the right fish -- or, if the plate",
                             "was started from the wrong end, select the",
                             "individual it really is in the bar."),
                       k, nn, ord_word(),
                       if (ord_j() == 1L) "horizontally " else "vertically ",
                       if (is.finite(b[1]) && is.finite(b[2]))
                         sprintf(" (%.0f < %.0f < %.0f expected)", b[1], v, b[2])
                       else ""),
               "error")
        return()
      }
      # The FIRST fish of a plate has no neighbour to be checked against, so the
      # interval rule cannot catch an operator starting from the wrong end -- it
      # would only fire on the second fish, one specimen too late. A plate of n
      # divides the frame into n bands; a snout for i1 found outside the first
      # one is worth a word, though not a refusal: plates are not always evenly
      # spaced, and the operator is the one looking at the fish.
      if (k == 1L && !is.finite(b[2])) {
        span <- if (ord_j() == 1L) rv$w else rv$h
        if (is.finite(span) && span > 0 && v > span / nn)
          notify(sprintf(paste("Individual 1 of %d is expected to be the %s one",
                               "on the plate, and this snout is not in the first",
                               "%s of the frame. Check you are not numbering the",
                               "plate backwards."),
                         nn, if (ord_j() == 1L) "leftmost" else "topmost",
                         if (ord_j() == 1L) "column" else "band"),
                 "warning")
      }
    }
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
    # The scale bar (20, 21) is not anatomy: it sits in no body frame and no
    # convention depends on it, so placing it must leave the fish untouched.
    # Propagating from it used to re-derive 8/9/11 and square the depth pairs
    # WITHOUT re-imposing the eye vertical (5-13-7-14-6), which is only run for
    # a head point -- after a prediction, LM8 moved and LM6 did not.
    if (isTRUE(input$auto_constraints) && !frame_pt && !(just %in% SCALE_PTS) &&
        fin_row(P, 1L) && fin_row(P, 2L))
      P <- propagate_conventions(P, just)
    rv$pred <- collapse_pred(P)          # a declared zero survives the conventions
    if (just %in% c(1L, 2L)) ind_ax_set(P = rv$pred)   # the plate map, kept live
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
             "Place the axis first (1, 22, 24, 2): the hinges 22 and 24 go on the",
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
    # 24 -> 2, the points that define every frame), then the anatomical points in
    # numeric order, then the derived ones and the spare hinge, and finally the
    # scale bar. Anatomical order beats numeric order here because it follows the
    # path the eye takes over the specimen -- head, then body, then caudal.
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
    # instead (see .lmrow in APP_CSS). Its meaning is carried by the colours,
    # which the legend at the foot of the page states once.
    #
    # Four sections, separated by a gap: the axis (1, 22, 24, 2), the anatomical
    # run, the points that are never clicked (derived, spare hinge), and the
    # scale bar. A single run of twenty-four identical buttons is a list; four
    # groups is a map, and a landmark is found in the group it belongs to.
    sec <- list(c(1L, CURVE_PT, EXTRA_HINGES[1], 2L), ANAT_ORDER,
                c(DERIVED_LM, EXTRA_HINGES[-1]), SCALE_PTS)   # 23 sits with the derived
    sec <- Filter(length, sec)
    kids <- list()
    for (k in seq_along(sec)) {
      if (k > 1L) kids[[length(kids) + 1L]] <- div(class = "lmgap")
      kids <- c(kids, lapply(sec[[k]], btn))
    }
    div(class = "lmrow", kids)
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
      "Broken axis 1 -> 22 -> 24 -> 2: place 22 then 24 on the bends of a curved",
      "specimen. Head conventions apply on 1-22, body depth and pectoral fin",
      "(10, 11, 12) on 22-24, caudal (16-17, 18-19) on 24-2. LM25 (end of the",
      "list) adds a fourth axis segment, without conventions. LM22 is a genuine",
      "landmark -- fishmorph_segments() uses it to correct the standard length.",
      tags$br(),
      tags$b("LM23 is DERIVED: "), "the intersection of the line (1, 9) with",
      "the parallel to the head axis through LM6, so 1 -> 23 is the axial",
      "distance from the snout to the base of the head. It is never clicked --",
      "it is rebuilt after every move of LM1, LM6, LM9 or the axis -- and it is",
      "the FISHMORPH numbering, shared with Rfishmorph. LM24 and LM25 are entry",
      "aids, not landmarks: they are written to the workbook and the journal so",
      "that reopening a specimen restores the axis it was digitized under, but",
      "they must be left out of any shape analysis (read the first 23 points,",
      "not every _X column).")
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
  ## ---- collapsed segments ---------------------------------------------------
  ## Re-applied after everything that could undo them: the conventions put LM9
  ## and LM11 back on the belly line and enforce_head_order() re-separates the
  ## eye group, so without this the zero would last exactly until the next
  ## click. The points a rule moves are marked "adjusted" -- placed by a rule the
  ## operator invoked, neither pointed at by hand nor left at their seed.
  collapse_pred <- function(P = rv$pred) {
    if (is.null(P)) return(P)
    P <- derive_head_pt(P)              # LM23 is a function of 1, 6, 9 and the axis
    act <- rv$collapse
    if (!length(act)) return(P)
    ## PROJECTIONS FIRST, and the ventral chain re-derived behind them. LM4 is
    ## the master of the belly line: projected after derive_ventral() it would
    ## leave LM11 -- and through it LM8 and LM9 -- at the height LM4 had BEFORE
    ## the projection, that is a belly line no longer passing through its own
    ## pivot. Only the ventral chain is replayed, not the whole propagation:
    ## nothing else depends on LM4, and enforce_perp() would be free to move it.
    if (length(collapse_points(act, kinds = "project"))) {
      P  <- apply_collapse(P, act, kinds = "project")
      fr <- seg_frames(P)
      if (isTRUE(input$auto_constraints) && !is.null(fr)) P <- derive_ventral(P, fr)
      P  <- derive_head_pt(P)           # LM23 is built on LM9, which has just moved
    }
    P <- apply_collapse(P, act, kinds = "move")
    moved <- collapse_points(act)
    moved <- moved[vapply(moved, function(i) fin_row(P, i), logical(1))]
    rv$seeded   <- setdiff(rv$seeded, moved)
    rv$na       <- setdiff(rv$na, moved)
    ## a COPIED landmark is entirely the rule's; a PROJECTED one keeps the
    ## abscissa that was clicked, so it stays a measurement in `edited` and
    ## survives a reseed. Both are reported "adjusted": a rule placed them.
    rv$edited   <- setdiff(rv$edited, collapse_points(act, kinds = "move"))
    rv$adjusted <- union(rv$adjusted, moved)
    P
  }
  ## Ticking a box applies it at once, unticking releases the point: it goes back
  ## to being derived by the conventions, which is what it was before.
  observeEvent(input$collapse, {
    rv$collapse <- input$collapse %||% character(0)
    if (is.null(rv$pred)) return()
    released <- setdiff(collapse_points(names(COLLAPSE_RULES)),
                        collapse_points(rv$collapse))
    rv$adjusted <- setdiff(rv$adjusted, released)
    P <- collapse_pred(rv$pred)
    if (length(released) && isTRUE(input$auto_constraints) &&
        fin_row(P, 1L) && fin_row(P, 2L))
      P <- propagate_conventions(P, 4L)          # re-derive the belly line
    rv$pred <- collapse_pred(P)
    ## Unticking a PROJECTION does not put LM4 back where it was: the height it
    ## gave up is not stored anywhere, and inventing one would be worse than
    ## saying so. The landmark stays on the axis until it is clicked again.
    if (4L %in% released)
      rv$msg <- paste("LM4 released: it stays on the mid axis until you place",
                      "it again -- the height it had before the rule is not kept.")
  }, ignoreNULL = FALSE, ignoreInit = TRUE)

  output$collapse_help <- renderUI({
    act <- rv$collapse
    txt <- if (!length(act))
      paste("A segment that is genuinely zero on this fish -- a mouth on the",
            "ventral profile, a head ending on it. One landmark takes the",
            "coordinates of the other, or is projected onto the mid axis:",
            "both stay on the photograph and in the workbook. Re-applied after",
            "every click, reset for each specimen.")
    else paste("Active:", paste(vapply(COLLAPSE_RULES[act], function(r) r$tip,
                                       character(1)), collapse = " | "))
    div(style = "font-size:11.5px;color:#92400e;margin-top:2px;", txt)
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

  ## Move to individual `k` of the photograph on screen. Everything that belongs
  ## to the FISH is cleared; everything that belongs to the PHOTOGRAPH is kept --
  ## the image, the zoom, and above all THE SCALE BAR 20-21. One ruler in one
  ## focal plane calibrates every fish lying on it, and re-placing 20 and 21 for
  ## each of them would add an independent scale error to each: the pair is
  ## measured once per plate and inherited, which is both less work and one fewer
  ## source of between-individual variance. (The caveat is real but small:
  ## individuals far from the ruler carry whatever residual perspective and lens
  ## distortion the plate has, so keep the ruler in the plane of the fish.)
  go_individual <- function(k) {
    if (is.null(rv$pred)) return(invisible(NULL))
    code <- photo_code(); n <- n_ind_of(code)
    k <- max(1L, min(as.integer(k), n))
    sb <- rv$pred[as.character(SCALE_PTS), , drop = FALSE]
    reset_points()
    P <- rv$pred; P[as.character(SCALE_PTS), ] <- sb; rv$pred <- P
    rv$ind <- k
    rv$collapse <- character(0)
    updateCheckboxGroupInput(session, "collapse", selected = character(0))
    # Already digitized? Put its configuration back, so selecting a slot is how
    # an individual is CORRECTED as well as how the next one is started.
    reloaded <- seed_from_sheet(cur_code())
    if (isTRUE(rep_mode())) updateNumericInput(session, "rep_i", value = next_rep())
    ind_ax_set()
    rv$msg <- sprintf("Individual %d / %d of %s%s", k, n, code,
                      if (isTRUE(reloaded)) " -- reloaded, correct and save again."
                      else " -- click the snout (LM1).")
    invisible(NULL)
  }
  observeEvent(input$ind_btn, go_individual(as.integer(input$ind_btn)))
  observeEvent(input$ind_add,
               updateNumericInput(session, "n_ind", value = n_ind_of() + 1L))
  ## Removing a slot that already holds a saved fish would orphan its row in the
  ## sheet under a code the app can no longer reach, so the count only shrinks
  ## down to the last individual actually digitized.
  observeEvent(input$ind_drop, {
    n <- n_ind_of(); done <- saved_inds()
    floor_n <- max(1L, if (length(done)) max(done) else 1L)
    if (n <= floor_n) {
      notify(sprintf(paste("%d individual(s) of this photograph are already",
                           "saved: the count cannot go below %d without leaving",
                           "their rows unreachable."), length(done), floor_n),
             "warning")
      return()
    }
    updateNumericInput(session, "n_ind", value = n - 1L)
  })

  ## ---- individual bar -------------------------------------------------------
  ## The plate at a glance, and the way back to a fish already measured. Same
  ## plain-HTML-button device as the landmark bar.
  output$ind_bar <- renderUI({
    n <- n_ind_of()
    if (n <= 1L) return(NULL)
    done <- saved_inds()
    cur  <- ind_i()
    btn <- function(k) {
      col <- if (k == cur) "background:#28a745;color:#fff;font-weight:bold;"
             else if (k %in% done) "background:#cfe8ff;"
             else "background:#f7f7f7;border-style:dashed;"
      tags$button(type = "button", paste0("i", k), class = "lmbtn",
        title = if (k %in% done) "saved -- click to reload and correct"
                else "not yet measured",
        onclick = sprintf("Shiny.setInputValue('ind_btn', %d, {priority:'event'});", k),
        style = col)
    }
    tagList(div(class = "lmrow", lapply(seq_len(n), btn)),
            helpText(sprintf("%d / %d measured on this photograph.",
                             length(done), n)))
  })
  ## Declaring a different count: keep the individual in range and re-read what
  ## is already saved under the NEW numbering (the code of a fish depends on the
  ## count, since a plate of one names its fish without any `_i` suffix at all).
  observeEvent(input$n_ind, {
    n <- suppressWarnings(as.integer(input$n_ind))
    if (!length(n) || is.na(n) || n < 1L) return()
    # Keyed on rv$photo, not on the text field: this observer also fires from
    # load_queue_photo()'s own updateNumericInput(), and at that moment the text
    # field may still hold the PREVIOUS photograph's code.
    code <- if (nzchar(rv$photo)) rv$photo else photo_code()
    if (identical(unname(rv$n_by_photo[code]), n)) return()
    rv$n_by_photo[[code]] <- n
    rv$n_default <- n
    if (rv$ind > n) rv$ind <- n
    ind_ax_reload(code)
  }, ignoreInit = TRUE)

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
      # "validated": a model (or seed) position the operator explicitly accepted
      # with "Validate points" -- checked, but not placed by hand. Kept apart from
      # "clicked" so that the training pipeline can tell the two (it uses
      # validated points with a lower weight, and never to evaluate a model).
      else if (p %in% rv$validated) "validated"
      else if (p %in% rv$seeded && !(p %in% DERIVED_LM)) "seeded"
      else if (p %in% DERIVED_LM) "derived"
      # LM1/LM2 found by the global network (Auto, batch) are not clicks
      else if (p %in% c(1L, 2L) && !(p %in% rv$auto12)) "clicked"
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
               note = qual_now(),
               status = unname(point_status(WB_PTS)),
               row.names = NULL)
  }
  ## The review of the ENTRY, as three fields rather than one. Empty strings and
  ## not NA for the author and the date when nothing has been declared: the
  ## column is character, and a reader has to be able to tell "not reviewed"
  ## from "reviewed by nobody in particular".
  ## The score of the entry, 1 (unusable) .. 5 (excellent), or NA: "Not scored"
  ## (value 0) and an empty cell are the same statement, and a 0 would be a
  ## sixth grade nobody defined.
  qual_now <- function() {
    v <- num1(input$quality)
    if (!is.finite(v) || v < 1 || v > 5) NA_real_ else round(v)
  }
  review_now <- function() {
    on <- isTRUE(input$reviewed)
    list(reviewed = if (on) "yes" else "no",
         reviewed_by = if (on) OPERATOR else NA_character_,
         review_date = if (on) format(as.POSIXct(Sys.time(), tz = "UTC"),
                                      "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
                       else NA_character_)
  }
  ## The coincidences DECLARED on this specimen, as one string. Recorded because
  ## a declared zero is a measurement: leaving only the geometry it produced
  ## means a reader cannot tell it from two points that happened to land on each
  ## other, and means the boxes come back empty when the specimen is reopened.
  collapse_now <- function() {
    a <- rv$collapse
    if (!length(a)) NA_character_ else paste(sort(unique(a)), collapse = ";")
  }
  current_row <- function(st) {
    P <- rv$pred
    rvw <- review_now()
    row <- data.frame(
      specimen = save_id(), individual = cur_code(),
      replicate = if (isTRUE(rep_mode()))
        suppressWarnings(as.integer(input$rep_i)) else 1L,
      operator = OPERATOR, mode = cur_mode(),
      photo_file = if (!is.null(rv$orig)) basename(rv$orig) else NA_character_,
      # The fingerprint of the file on screen, not of the queue slot: the
      # operator may have jumped to a photograph outside the current queue.
      photo_hash = if (!is.null(rv$orig))
        hash_of_photo(match(rv$orig, CFG$photos)) else NA_character_,
      img_w = rv$w %||% NA_real_, img_h = rv$h %||% NA_real_,
      quality_score = qual_now(),
      reviewed = rvw$reviewed, reviewed_by = rvw$reviewed_by,
      review_date = rvw$review_date, collapse_rules = collapse_now(),
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
    cand <- photos_todo(PHOTO_CODES[rv$q])
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
    # THE JOURNAL IS APPEND-ONLY, so it still holds every record under the code
    # it was SAVED with -- including the codes a rename has since replaced.
    # Rebuilding from it therefore resurrects exactly what the reconciliation
    # repaired, and the renamed specimens would go straight back into the "new"
    # queue. Re-reconciling here is what makes "rebuild" a recovery rather than
    # a regression. It is idempotent: on a workbook already in step it finds
    # nothing and says nothing.
    reconcile_sheets()
    rv$pending <- rv$pending + 1L
    flush_xlsx(force = TRUE, quiet = FALSE)
    notify(sprintf("Rebuilt from the journals: %d measurement(s), %d repeat(s).",
                   nrow(rv$meas), nrow(rv$bias)))
    set_mode(cur_mode())
  })

  ## ---- convention check, on save --------------------------------------------
  ## "Save & next" goes through this check before anything is written. When LM3
  ## is not the most dorsal point (or LM4 the most ventral), or when the eye
  ## vertical is out of order, the operator is offered the ways out that matter:
  ## measure it again, or -- for the extremes only -- let the app snap the point
  ## onto the true extreme.
  extreme_modal <- function(v) {
    has_ext <- any(v$kind == "extreme")
    has_ord <- any(v$kind == "order")
    showModal(modalDialog(
      title = if (has_ext && has_ord)
        "FISHMORPH conventions: Bd (3-4) and the eye vertical (5, 13, 7, 14, 6, 8)"
      else if (has_ord)
        "FISHMORPH conventions: the eye vertical (5, 13, 7, 14, 6, 8) is out of order"
      else "FISHMORPH conventions: Bd (3-4) is not the maximum body depth",
      tags$ul(lapply(seq_len(nrow(v)), function(r) {
        i <- v$point[r]; j <- v$culprit[r]
        tags$li(if (identical(v$kind[r], "extreme")) sprintf(
          "LM%d must be the most %s point: LM%d overshoots it by %.0f px.",
          i, if (i == 3L) "DORSAL" else "VENTRAL", j, v$delta[r])
        else sprintf(
          "Eye vertical out of order: LM%d must sit ABOVE LM%d, and is %.0f px below it.",
          i, j, v$delta[r]))
      })),
      tags$p(tags$em(
        "Heights are measured perpendicular to the body axis, segment by",
        "segment, so a bent or tilted specimen is not flagged for its posture.",
        "The caudal peduncle and fin (16-19), the appendage tips (12, 15) and",
        "the derived ventral points (8, 9, 11 -- computed from LM4 itself) are",
        "excluded from the Bd test.")),
      if (has_ord) tags$p(tags$em(
        "The six points 5, 13, 7, 14, 6, 8 lie on one vertical, in that order",
        "from the back downwards: top of the head, top of the eye, centre,",
        "bottom of the eye, bottom of the head, body underside. An inversion",
        "leaves every pair internally consistent -- Ed keeps its length -- while",
        "Hd or Eh silently refers to the wrong point, which is why no other",
        "check sees it.")),
      tags$p(
        if (has_ext) tags$span(
          "Auto-correct gives LM3 or LM4 the height of the point overshooting",
          "it, keeping its position along the axis; corrected points are",
          "exported with status \"adjusted\".") else NULL,
        if (has_ord) tags$span(
          tags$b(" An inversion is never auto-corrected:"),
          "moving a point to satisfy the order would invent a measurement",
          "rather than repair one. Measure the points again, or save as is if",
          "the order is real.") else NULL),
      footer = tagList(
        actionButton("extreme_remeasure", "Measure again", class = "btn-primary"),
        if (has_ext) actionButton("extreme_fix", "Auto-correct and save"),
        actionButton("extreme_asis", "Save without correcting")),
      easyClose = FALSE, size = "l"))
  }

  ## Apply the correction. propagate_conventions() may move the belly line once
  ## LM4 has changed height, so the check is iterated to a fixed point -- three
  ## passes is ample, and the bound rules out a loop on a pathological case.
  ## LM4 alone drives the propagation: LM3 keeps its abscissa, so the 3-4
  ## perpendicular is already satisfied, and LM3 is a FRAME point whose click
  ## handler would re-seed the whole configuration.
  ## The checks a declared coincidence suspends -- recomputed at every call,
  ## a rule being ticked and unticked while the specimen is on screen.
  conv_skip <- function() collapse_skip_extreme(rv$collapse)

  apply_extreme_fix <- function() {
    for (it in 1:3) {
      P <- rv$pred
      v <- extreme_violations(P, skip = conv_skip())
      if (is.null(v)) return(TRUE)
      P <- fix_extremes(P, v)
      if (isTRUE(input$auto_constraints) && 4L %in% v$point &&
          fin_row(P, 1L) && fin_row(P, 2L))
        P <- propagate_conventions(P, 4L)
      rv$pred     <- collapse_pred(P)
      rv$na       <- setdiff(rv$na, v$point)
      rv$seeded   <- setdiff(rv$seeded, v$point)
      rv$adjusted <- union(rv$adjusted, v$point)
    }
    is.null(extreme_violations(rv$pred, skip = conv_skip()))
  }

  observeEvent(input$save_specimen, {
    if (is.null(rv$pred)) {
      notify("Nothing to save yet: predict, or start manual placement first.",
             "warning"); return() }
    if (isTRUE(input$check_extremes)) {
      v <- convention_violations(rv$pred, skip = conv_skip())
      if (!is.null(v)) { extreme_modal(v); return() }
    }
    save_specimen()
  })

  ## Measure again: close, select the offending landmark and centre the view.
  ## For an inversion the landmark to re-measure is the CULPRIT -- the one found
  ## on the wrong side -- not the reference it was compared with.
  observeEvent(input$extreme_remeasure, {
    removeModal()
    v <- convention_violations(rv$pred, skip = conv_skip())
    if (!is.null(v)) {
      ord <- identical(v$kind[1], "order")
      rv$sel <- if (ord) v$culprit[1] else v$point[1]
      zoom_to_sel()
      rv$msg <- if (ord)
        sprintf("%s -- click its true position: it must sit below %s.",
                point_label(v$culprit[1]), point_label(v$point[1]))
      else
        sprintf("%s -- click its true position (the most %s point).",
                point_label(v$point[1]),
                if (v$point[1] == 3L) "dorsal" else "ventral")
    }
  })
  ## Auto-correct applies to the extremes only. An inversion of the eye vertical
  ## is reported again on the way out rather than saved in silence: it is the one
  ## error the check exists for.
  observeEvent(input$extreme_fix, {
    removeModal()
    if (!isTRUE(apply_extreme_fix()))
      showNotification(paste("LM3/LM4 still breach the convention after",
                             "correction: check the placement."),
                       type = "warning", duration = 8)
    ord <- eye_order_violations(rv$pred)
    if (!is.null(ord))
      showNotification(
        sprintf(paste("Eye vertical still out of order (%s): not auto-corrected,",
                      "saved as is."),
                paste(sprintf("%d/%d", ord$point, ord$culprit), collapse = ", ")),
        type = "warning", duration = 10)
    save_specimen()
  })
  observeEvent(input$extreme_asis, { removeModal(); save_specimen() })

  save_specimen <- function() {
    ## AN EMPTY RECORD IS NOT A RECORD.
    ##
    ## Three rows of the T-26 campaign workbook carry a specimen, a photograph,
    ## a size, a quality score and a timestamp -- and not one coordinate. They
    ## were written by a press of "Save & next" on a photograph nothing had been
    ## placed on yet, and they are worse than nothing: the queue counts them as
    ## digitized, so the specimen leaves the "new" queue for ever without ever
    ## having been measured, and `n_clicked = 0`, `n_na = 0` says so in a way
    ## nothing reads.
    ##
    ## The axis is the minimum. LM1 and LM2 are what every frame, every
    ## convention and every derived point are expressed against; a configuration
    ## without them is not a partial measurement, it is no measurement at all.
    ## Declaring a point unmeasurable (`na`) is a different act and stays
    ## allowed -- that is a statement about the specimen, not an empty row.
    P0 <- rv$pred
    axis_ok <- fin_row(P0, 1L) && fin_row(P0, 2L)
    n_placed <- sum(vapply(SAVE_PTS, function(p) fin_row(P0, p), logical(1)))
    if (!axis_ok || n_placed == 0L) {
      notify(paste("Nothing to save: place at least the snout (LM1) and the",
                   "caudal-fin basis (LM2). An empty row would take this",
                   "specimen out of the 'new' queue without measuring it."),
             "error")
      return(invisible(NULL))
    }

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
        img_w = row$img_w, img_h = row$img_h, quality_score = row$quality_score,
        ruler_mm = row$ruler_mm, mm_per_px = row$mm_per_px,
        photo_hash = row$photo_hash, reviewed = row$reviewed,
        reviewed_by = row$reviewed_by, review_date = row$review_date,
        collapse_rules = row$collapse_rules)
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

    msg <- sprintf("'%s' saved to %s (%s; %d measurement(s), %d repeat(s)).",
                   id, sheet,
                   if (is.finite(df$note[1])) sprintf("score %d/5", as.integer(df$note[1]))
                   else "not scored",
                   nrow(rv$meas), nrow(rv$bias))
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
    ## 4. On a plate, "next" is the next INDIVIDUAL until the plate is finished.
    ##    Only then does the queue move on -- so a photograph is never left with
    ##    three of its four fish measured because the operator was following the
    ##    photograph counter rather than the plate.
    ind_ax_set()
    if (ind_i() < n_ind_of()) {
      go_individual(ind_i() + 1L)
      notify(sprintf("%s saved. Individual %d / %d: click the snout of the next fish (%s).",
                     id, ind_i(), n_ind_of(), ord_word()))
      return(invisible(NULL))
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
  ## Fully automatic mode ('Auto'): no click needed. The worker runs the global
  ## network (mlmorph_run_global/model.onnx, train_global.py) on the whole
  ## photograph to find LM1, LM2 and the dorsal side, then the chosen model in
  ## the canonical frame. LM1/LM2 clicked beforehand take precedence over the
  ## detection; the automatic ones stay "predicted" (unchecked) until reviewed.
  GLOBAL_MODEL <- file.path(ML, "mlmorph_run_global", "model.onnx")
  observeEvent(input$predict, run_prediction(auto = FALSE))
  observeEvent(input$validate_pts, {
    if (is.null(rv$pred)) return()
    st <- point_status(WB_PTS)
    tgt <- WB_PTS[st %in% c("predicted", "seeded")]
    if (!length(tgt)) { notify("No predicted or seeded point to validate."); return() }
    rv$validated <- union(rv$validated, tgt)
    notify(sprintf("%d point(s) validated: %s.", length(tgt), paste(sort(tgt), collapse = ", ")))
  })
  observeEvent(input$predict_auto, {
    if (!file.exists(GLOBAL_MODEL)) {
      notify(paste("Auto mode unavailable: no global model at", GLOBAL_MODEL), "error")
      return()
    }
    run_prediction(auto = TRUE)
  })
  run_prediction <- function(auto = FALSE) {
    P <- rv$pred
    if (is.null(P)) { notify("No photograph loaded.", "error"); return() }
    if (!auto && (!fin_row(P, 1L) || !fin_row(P, 2L))) {
      notify("Place at least the snout (LM1) and the caudal-fin basis (LM2) first (or use 'Auto').",
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
              if (auto) c("--auto", "--global-model", shQuote(GLOBAL_MODEL)),
              if (isTRUE(input$pred_hinges)) "--hinges",
              if (has(1L)) c("--snout", xy(1L)), if (has(2L)) c("--caudal", xy(2L)),
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
    rv$msg <- if (auto) "Automatic landmarking running..." else "Prediction running..."
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
      # Hinges 22/24 placed by a model trained with them (train_cnn.py --hinges):
      # the broken axis 1-22-24-2 follows a curved body, and the conventions are
      # then applied segment by segment. A hinge the operator placed is kept.
      hk <- d$landmark %in% c(CURVE_PT, EXTRA_HINGES[1]) &
        !(d$landmark %in% rv$edited) & is.finite(d$X) & is.finite(d$Y)
      if (any(hk)) M[as.character(d$landmark[hk]), ] <- as.matrix(d[hk, c("X", "Y")])
      # Scale bar found automatically on the ruler (mlmorph_run_ruler + spectral
      # analysis of the millimetre ticks, worker ruler_scale.py): used only when
      # 20/21 are not already on the photograph; status "predicted" until clicked.
      sk <- d$landmark %in% SCALE_PTS & is.finite(d$X) & is.finite(d$Y) &
        !(d$landmark %in% rv$edited) &
        !vapply(d$landmark, function(i) i %in% SCALE_PTS && fin_row(rv$pred, i), logical(1))
      scale_auto <- any(sk)
      if (scale_auto) M[as.character(d$landmark[sk]), ] <- as.matrix(d[sk, c("X", "Y")])
      scale_msg <- grep("^SCALE:", res, value = TRUE)
      # Pin mode: 1, 2, 3, 4, 7 are already frozen on the clicks by the worker;
      # propagate the FISHMORPH conventions to the dependants (8, 9, 11, 5, 6, 13, 14).
      # Without pin mode the model output is not convention-compliant either
      # (9 off the perpendicular of 1, 8 off that of 7, 6 off the eye vertical).
      # Left as is, the FIRST later click propagated only part of the
      # conventions and visibly broke the head vertical. Applying them all now,
      # once, means what is on screen after 'Predict' is what will be saved.
      if (isTRUE(input$pin) || isTRUE(input$auto_constraints))
        M <- apply_conventions(M)
      rv$pred <- M
      rv$seeded <- setdiff(rv$seeded, as.integer(d$landmark[keep]))
      # The model knows nothing of a zero the operator declared on this fish:
      # re-assert it over the prediction, exactly as after the conventions.
      rv$pred <- collapse_pred(rv$pred)
      # Provenance: every landmark the model wrote over becomes "predicted"
      # again, except those the worker froze on the operator's clicks.
      rv$edited <- union(setdiff(rv$edited, as.integer(d$landmark[keep])),
                         intersect(pinned_clicks(input$pin), rv$placed_order))
      # a point the model has just rewritten is no longer the one validated
      rv$validated <- setdiff(rv$validated, as.integer(d$landmark))
      # LM1/LM2 placed by the global network stay "predicted" until clicked
      rv$auto12 <- setdiff(union(rv$auto12, if (auto) c(1L, 2L)), rv$edited)
      # a landmark the model has just rewritten is no longer the one the
      # extreme-point convention had snapped
      rv$adjusted <- setdiff(rv$adjusted, as.integer(d$landmark[keep]))
      # Straight on to the scale bar: the model has placed the anatomy, the
      # ruler is what is left to click. The first of 20/21 still missing
      # becomes active, with the whole photograph in view so the ruler is on
      # screen; once both are down the review starts on the first anatomical
      # point, as before.
      todo <- SCALE_PTS[!vapply(SCALE_PTS, function(i) fin_row(rv$pred, i), logical(1))]
      if (length(todo)) {
        rv$sel <- todo[1]
        rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL
      } else {
        rv$sel <- ANAT_ORDER[1]   # first anatomical point to review
      }
      notify(paste0(if (length(todo))
               sprintf("Prediction done. Click LM%d on the ruler, then review the points.", todo[1])
             else if (scale_auto) "Prediction done. Scale bar placed AUTOMATICALLY on the ruler: check 20-21, then review the points."
             else "Prediction done. Scale bar in place: review the points.",
             if (length(scale_msg)) paste0(" [", sub("^SCALE: ", "", scale_msg[1]), "]") else ""))
    } else {
      notify(paste("Prediction failed:", paste(utils::tail(res, 4), collapse = " | ")),
             "error")
    }
  }

  ## ---- plot -----------------------------------------------------------------
  # The plot output is rebuilt when the panel height changes. Safe for the pan
  # handler: PAN_JS listens on `document` and looks the element up by id on
  # every event, so it survives the element being replaced.
  output$img_box <- renderUI({
    h <- suppressWarnings(as.integer(input$panel_h %||% 700))
    if (!is.finite(h) || h < 200) h <- 700
    plotOutput("img", click = "click", dblclick = "img_dblclick",
               height = paste0(h, "px"))
  })

  output$img <- renderPlot({
    # The margins go to zero FIRST, before anything is drawn: with the default
    # 5.1/4.1/4.1/2.1 lines, plot.new() errors with "figure margins too large"
    # as soon as the device is narrow (a collapsed layout, a small window),
    # which would replace the photograph with a stack trace.
    par(mar = c(0, 0, 0, 0))
    if (is.null(rv$img)) { plot.new(); text(.5, .5, "Load a photograph"); return() }
    cx <- if (is.null(rv$cx)) rv$w / 2 else rv$cx
    cy <- if (is.null(rv$cy)) rv$h / 2 else rv$cy
    v <- view_half(); hw <- v[1]; hh <- v[2]
    cx <- view_clamp(cx, hw, rv$w); cy <- view_clamp(cy, hh, rv$h)
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
    # THE OTHER FISH ON THE PLATE. Their axis 1 -> 2, drawn faintly with their
    # number: without it the operator has no way of telling, on a plate of four
    # similar specimens, which ones are already measured -- and re-measuring one
    # under the wrong number is exactly the error the numbering exists to stop.
    if (!is.null(rv$ind_ax) && n_ind_of() > 1L) {
      A <- rv$ind_ax
      for (k in seq_len(nrow(A))) {
        if (k == ind_i() || !all(is.finite(A[k, ]))) next
        a <- flip_pt(A[k, 1:2], rv$flip); b <- flip_pt(A[k, 3:4], rv$flip)
        segments(a[1], a[2], b[1], b[2],
                 col = adjustcolor("black", 0.35), lwd = 0.7, lty = 3)
        text(a[1], a[2], paste0("i", k), col = adjustcolor("black", 0.55),
             pos = 2, cex = 0.7)
      }
    }
    # alignment guides: a faint grid on every landmark, a cross on the active one
    if (isTRUE(input$guides) && !is.null(P)) {
      ok <- stats::complete.cases(P)
      abline(v = P[ok, 1], col = adjustcolor("black", 0.20), lty = 3, lwd = 0.5)
      abline(h = P[ok, 2], col = adjustcolor("black", 0.20), lty = 3, lwd = 0.5)
      if (fin_row(P, rv$sel)) {
        abline(v = P[rv$sel, 1], col = adjustcolor("black", 0.55), lty = 2, lwd = 0.7)
        abline(h = P[rv$sel, 2], col = adjustcolor("black", 0.55), lty = 2, lwd = 0.7)
      }
    }
    # reference lines: body outline, belly line, eye vertical, eye circle
    if (isTRUE(input$showlines) && !is.null(P)) {
      path <- function(ids, ...) {
        ids <- ids[vapply(ids, function(i) fin_row(P, i), logical(1))]
        if (length(ids) > 1) lines(P[ids, 1], P[ids, 2], ...)
      }
      path(c(1, 5, 3, 16, 18, 19, 17, 4, 6, 1),                             # outline
           col = adjustcolor("black", 0.75), lwd = 0.8, lty = 2)
      path(c(9, 8, 11, 4), col = adjustcolor("black", 0.45), lty = 3, lwd = 0.6)  # belly
      path(c(1, 9), col = adjustcolor("black", 0.45), lwd = 0.6)            # mouth height
      path(c(5, 13, 7, 14, 6, 8),                                           # eye vertical
           col = adjustcolor("black", 0.45), lty = 3, lwd = 0.6)
      if (fin_row(P, 7) && fin_row(P, 13) && fin_row(P, 14)) {              # eye
        er <- sqrt(sum((P[13, ] - P[14, ])^2)) / 2
        th <- seq(0, 2 * pi, length.out = 60)
        lines(P[7, 1] + er * cos(th), P[7, 2] + er * sin(th),
              col = adjustcolor("black", 0.45), lty = 3, lwd = 0.6)
      }
    }
    # THE 11 FISHMORPH SEGMENTS. Ported from Rfishmorph's digitizer so that the
    # two applications draw the protocol identically: one saturated colour per
    # segment, plus a legend, rather than the uniform faint dashes used for the
    # reference lines. The distinction is the point -- the reference lines are
    # context, the segments ARE the measurement, and they should read as such
    # without the operator having to work out which line is which.
    #
    # Drawn AFTER the reference lines and BEFORE the landmarks: the measurement
    # covers the context, and the points stay on top of everything, since they
    # are what is being aimed at.
    if (isTRUE(input$showsegs) && !is.null(P)) {
      for (k in seq_along(PAIR_SEG)) {
        if (names(PAIR_SEG)[k] == "Bl") {
          # Bl along the broken axis, exactly as fishmorph_segments() measures it.
          ch <- axis_chain(P)
          ch <- ch[vapply(ch, function(i) fin_row(P, i), logical(1))]
          if (length(ch) > 1) lines(P[ch, 1], P[ch, 2], col = SEG_COLS[k], lwd = 2)
        } else {
          ab <- PAIR_SEG[[k]]
          if (fin_row(P, ab[1]) && fin_row(P, ab[2]))
            segments(P[ab[1], 1], P[ab[1], 2], P[ab[2], 1], P[ab[2], 2],
                     col = SEG_COLS[k], lwd = 2)
        }
      }
      if (isTRUE(input$seglegend))
        legend("topright", names(PAIR_SEG), col = SEG_COLS, lwd = 2,
               bg = "white", cex = 0.8, ncol = 2)
    } else if (isTRUE(input$showlines) && !is.null(P)) {
      # Segments hidden: the broken axis is still drawn faintly, otherwise the
      # curvature correction becomes invisible and a hinge can be left in an
      # absurd place without anything on screen saying so.
      ch <- axis_chain(P)
      ch <- ch[vapply(ch, function(i) fin_row(P, i), logical(1))]
      if (length(ch) > 2)
        lines(P[ch, 1], P[ch, 2], col = adjustcolor("black", 0.7), lwd = 0.8, lty = 2)
    }
    # FISHMORPH geometry check. Compliance is the SILENT state: a thin black
    # dash that does not hide the specimen. Only a violation is drawn loudly
    # (orange), so the eye is spent on what needs fixing rather than on what is
    # already right.
    if (isTRUE(input$fishguides) && !is.null(P)) {
      OKCOL <- adjustcolor("black", 0.7); BADCOL <- "orange"
      fr <- seg_frames(P)
      if (!is.null(fr)) {
        tol <- 0.03 * fr$len; L <- rv$w + rv$h
        for (pr in list(list(p = c("1", "9"),   f = fr$head),
                        list(p = c("3", "4"),   f = fr$mid),
                        list(p = c("10", "11"), f = fr$mid),
                        list(p = c("16", "17"), f = fr$tail),
                        list(p = c("18", "19"), f = fr$tail))) {
          a <- P[pr$p[1], ]; b <- P[pr$p[2], ]
          if (all(is.finite(c(a, b)))) {
            s <- b - a; s <- s / sqrt(sum(s^2))
            dev <- abs(90 - acos(pmin(1, abs(sum(s * pr$f$u)))) * 180 / pi)
            good <- dev < 8
            segments(a[1], a[2], b[1], b[2],
                     col = if (good) OKCOL else BADCOL,
                     lwd = if (good) 0.8 else 1.5, lty = 2)
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
          good <- diff(range(proj)) < tol
          segments(c0[1] - d[1] * L, c0[2] - d[2] * L,
                   c0[1] + d[1] * L, c0[2] + d[2] * L,
                   col = if (good) adjustcolor("black", 0.45) else BADCOL,
                   lwd = if (good) 0.6 else 1.2, lty = 3)
        }
        drawgrp(c("5", "13", "7", "14", "6", "8"), fr$head, parallel = FALSE)
        drawgrp(c("9", "8", "11"),                 fr$head, parallel = TRUE)
        drawgrp(c("11", "4"),                      fr$mid,  parallel = TRUE)
      }
    }
    # landmarks
    if (!is.null(P)) {
      lm_show <- c(seq_len(N_ANAT), SCALE_PTS)
      ok <- lm_show[vapply(lm_show, function(i) fin_row(P, i), logical(1))]
      if (length(ok)) {
        bg <- ifelse(ok %in% DERIVED_LM, "grey70",
                     ifelse(ok %in% SCALE_PTS, "#00a06a", "red"))
        points(P[ok, 1], P[ok, 2], pch = 21, bg = bg, col = "white", cex = 0.7,
               lwd = 0.5)
        # COINCIDENT LANDMARKS. Two points at the same pixel draw one circle on
        # top of the other and one label over the other, so a legitimate zero
        # LOOKS like a lost landmark. Both are here; the drawing has to say so.
        # A group is marked by a wider ring and labelled once, with every number
        # it holds ("10+11"), instead of stacking illegible labels.
        key <- paste(round(P[ok, 1], 1), round(P[ok, 2], 1))
        grp <- split(ok, key)
        multi <- grp[lengths(grp) > 1L]
        single <- unlist(grp[lengths(grp) == 1L], use.names = FALSE)
        # Yellow labels, as in Rfishmorph's digitizer. White was legible against
        # a bare photograph, but the segment overlay is drawn underneath now and
        # several of its colours are pale; yellow is the one hue that holds
        # against both a light photograph and the palette.
        if (length(single))
          text(P[single, 1], P[single, 2], single, col = "yellow", pos = 3, cex = 0.6)
        for (g in multi) {
          xy <- P[g[1], ]
          points(xy[1], xy[2], pch = 1, col = "yellow", cex = 1.4, lwd = 0.8)
          points(xy[1], xy[2], pch = 1, col = "black", cex = 1.8, lwd = 0.6)
          text(xy[1], xy[2], paste(sort(g), collapse = "+"),
               col = "yellow", pos = 3, cex = 0.65, font = 2)
        }
      }
      if (fin_row(P, SCALE_PTS[1]) && fin_row(P, SCALE_PTS[2]))
        segments(P["20", 1], P["20", 2], P["21", 1], P["21", 2],
                 col = adjustcolor("black", 0.8), lwd = 0.9, lty = 2)
      hs <- HINGES[vapply(HINGES, function(i) fin_row(P, i), logical(1))]
      if (length(hs)) {
        points(P[hs, 1], P[hs, 2], pch = 21, bg = "gold", col = "black",
               cex = 0.85, lwd = 0.5)
        text(P[hs, 1], P[hs, 2], hs, col = "gold", pos = 3, cex = 0.6)
      }
      # ACTIVE LANDMARK. A thin black ring, not a thick coloured disc: the point
      # has to be findable without covering the pixels being aimed at.
      if (fin_row(P, rv$sel))
        points(P[rv$sel, 1, drop = FALSE], P[rv$sel, 2, drop = FALSE],
               col = "black", pch = 1, cex = 1.6, lwd = 1)
    }

  })

  ## ---- navigation guides, OUTSIDE the photograph ----------------------------
  ##
  ## They were drawn inside the picture first, and that was a mistake: the plot
  ## click places a landmark, so aiming at a rail placed one. A control the eye
  ## reads as clickable, in a surface where clicking means something else
  ## entirely, is a trap however clearly it is labelled.
  ##
  ## So the guides live outside the image: a grey track, in the browser rather
  ## than in the graphic, with an arrow button at each end. The track SHOWS
  ## where the view sits in the photograph, the arrows MOVE it, and neither can
  ## reach the plot's click handler.
  ##
  ## The fraction of the photograph currently on screen, as percentages.
  view_frac <- function() {
    v <- view_half()
    fx0 <- min(max((( (rv$cx %||% (rv$w / 2)) - v[1]) / rv$w), 0), 1)
    fx1 <- min(max((( (rv$cx %||% (rv$w / 2)) + v[1]) / rv$w), 0), 1)
    fy0 <- min(max((( (rv$cy %||% (rv$h / 2)) - v[2]) / rv$h), 0), 1)
    fy1 <- min(max((( (rv$cy %||% (rv$h / 2)) + v[2]) / rv$h), 0), 1)
    list(x = 100 * fx0, w = 100 * max(fx1 - fx0, 0.02),
         y = 100 * fy0, h = 100 * max(fy1 - fy0, 0.02))
  }
  ## One arrow press moves by a FIFTH of what is on screen. A third was the
  ## first choice and it overshoots: at the zoom where a landmark is actually
  ## placed, a third of the window is more than the head of the fish, so the
  ## point being aimed at leaves the screen between two presses. A fifth keeps
  ## four fifths of the previous view -- the eye never loses its place -- at
  ## the cost of one more click per screenful, which is the right side of that
  ## trade for work done a point at a time.
  NAV_FRACTION <- 1 / 5
  nav_step <- function(k) {
    v <- view_half()
    if (is.null(rv$cx)) rv$cx <- rv$w / 2
    if (is.null(rv$cy)) rv$cy <- rv$h / 2
    if (k %in% c("l", "r")) rv$cx <- view_clamp(
      rv$cx + (if (k == "r") 1 else -1) * (2 * v[1]) * NAV_FRACTION, v[1], rv$w)
    else rv$cy <- view_clamp(
      rv$cy + (if (k == "d") 1 else -1) * (2 * v[2]) * NAV_FRACTION, v[2], rv$h)
  }
  observeEvent(input$nav_left,  nav_step("l"))
  observeEvent(input$nav_right, nav_step("r"))
  observeEvent(input$nav_up,    nav_step("u"))
  observeEvent(input$nav_down,  nav_step("d"))

  ## Only the thumb is rendered -- see the note beside the tracks in the UI.
  output$nav_v <- renderUI({
    if (is.null(rv$img)) return(NULL)
    f <- view_frac()
    div(style = sprintf("%sleft:0;right:0;top:%.2f%%;height:%.2f%%;%s",
                        NAV_THUMB, f$y, f$h,
                        if (f$h >= 99) "opacity:.35;" else ""))
  })

  output$nav_h <- renderUI({
    if (is.null(rv$img)) return(NULL)
    f <- view_frac()
    div(style = sprintf("%stop:0;bottom:0;left:%.2f%%;width:%.2f%%;%s",
                        NAV_THUMB, f$x, f$w,
                        if (f$w >= 99) "opacity:.35;" else ""))
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
      todo <- length(photos_todo(PHOTO_CODES[rv$q]))
      nn <- n_ind_of()
      sprintf("Photograph %d / %d &nbsp;&middot;&nbsp; %d still to do%s",
              rv$qi, n, todo,
              if (nn > 1L) sprintf(" &nbsp;&middot;&nbsp; individual %d / %d",
                                   ind_i(), nn) else "")
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
      paste("Draw the axis first: 1, 22, 24, 2. The hinges go on the bends of a",
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
      # hinges 24-25 are not landmarks -- letting them into a configuration
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
