#' Launch the interactive ml-morph landmarking application
#'
#' Opens the bundled Shiny application for semi-automatic digitization of fish
#' landmarks. Everything the session needs is declared **at the console** --
#' the photograph folder, the output workbook, the operator, the working queue
#' -- and everything it produces goes to **one workbook** with a
#' `measurements` sheet, a `bias` sheet holding the repeated digitizations, and
#' a `bias_summary` sheet quantifying them, backed by an append-only journal
#' that survives a crash. The operator loads a photograph, places a handful of
#' clicks, and a trained ml-morph shape predictor (Porto & Voje, 2020) proposes
#' the 19 anatomical FISHMORPH landmarks (Brosse et al., 2021); the remaining
#' points are reviewed and corrected by hand, quality-scored, and saved.
#'
#' The workbook is read back into an `"intrait_landmarks"` object with
#' [read_landmarks_xlsx()], and the journal with [consolidate_landmarks()].
#'
#' @param photo_dir Directory of specimen photographs. Every image in it forms
#'   the working queue (`jpg`, `jpeg`, `png`, `gif`, `bmp`, `tif`, `tiff`); the
#'   file name without its extension is the specimen code. Photographs stay
#'   where they are -- only their name and pixel size are ever recorded.
#' @param xlsx_path Path of the single output workbook. `NULL` (default) uses
#'   `intraitR_landmarks.xlsx` next to `photo_dir`. Created if absent; an
#'   existing workbook is resumed from (its specimens are excluded from the
#'   `"new"` queue and are the `"correct"` queue).
#' @param journal_dir Directory of the append-only JOURNAL (see
#'   [landmark_journal_open()]). Every record goes there BEFORE any workbook
#'   write: it is the source of truth, and it survives a crash --
#'   [consolidate_landmarks()] rebuilds the workbook from it at any time.
#'   Defaults to `landmark_journal/` next to the workbook.
#' @param operator Operator identifier, traced in the journal, in the workbook
#'   and in the identifiers of repeated digitizations. `NULL` (default) uses
#'   the system user.
#' @param mode Starting queue, switchable at any moment from the app:
#'   `"new"` (photographs not yet in the workbook), `"correct"` (specimens
#'   already digitized, whose points are reloaded onto the photograph for
#'   review) or `"repeat"` (the same photograph digitized several times, to
#'   measure digitization error and operator bias). If the requested queue is
#'   empty the app starts on another one.
#' @param n_repeats Number of digitizations per individual in `mode =
#'   "repeat"`. Defaults to `3`.
#' @param ruler_mm Real length, in millimetres, of the scale bar digitized by
#'   landmarks 20-21. Changeable in the app, specimen by specimen. Defaults to
#'   `10`.
#' @param xlsx_flush_every Number of records between two workbook writes. The
#'   workbook is REWRITTEN IN FULL each time, so taking it out of the
#'   digitizing loop removes both the wait and the risk; unwritten records stay
#'   in memory, are written when the session ends or on demand, and are in the
#'   journal in any case. `1` writes after every specimen. Defaults to `10`.
#' @param mlmorph_dir Path to the ml-morph resource directory holding the
#'   trained predictor(s) (`mlmorph_run_app/predictor.dat`,
#'   `mlmorph_run_aligned/predictor.dat`), the aligned dataset
#'   (`mlmorph_dataset_aligned/`) and, optionally, a Python virtual environment
#'   (`.venv_mlmorph/`). `NULL` (default) auto-detects it from the
#'   `INTRAITR_MLMORPH_DIR` environment variable, then from `ml_morph/`,
#'   `../ml_morph/` and the working directory. The app runs without a
#'   predictor; only the prediction step is then disabled.
#' @param predictor Optional path to a specific trained predictor (`.dat`) to
#'   offer first in the app's model selector.
#' @param python Optional path to (or name of) the Python interpreter running
#'   the prediction worker; it needs `numpy`, `opencv-python` and `dlib`
#'   (typically `.venv_mlmorph`). `NULL` (default) resolves it from
#'   `INTRAITR_MLMORPH_PY`/`PY`, then `~/.venv_mlmorph/bin/python`, then
#'   `.venv_mlmorph/` inside `mlmorph_dir`, then `python3` on the search path.
#' @param sheets Named character vector giving the three sheet names. Defaults
#'   to `c(measurements = "measurements", bias = "bias", summary =
#'   "bias_summary")`.
#' @param launch.browser Passed to [shiny::runApp()]. Defaults to the
#'   `shiny.launch.browser` option, or to [interactive()].
#' @param ... Further arguments passed to [shiny::runApp()] (for example `port`
#'   or `host`). Do not pass `appDir`; the packaged app directory is used.
#'
#' @return Invisibly, the path of the workbook. Called for its side effect of
#'   running the Shiny application (a blocking call in an interactive session).
#'
#' @details
#' The Shiny application is shipped inside the package
#' (`system.file("shiny/landmarking_app", package = "intraitR")`) together with
#' its Python worker (`system.file("mlmorph", package = "intraitR")`). The
#' heavier ml-morph assets -- the trained predictor(s), the aligned training
#' set, the Python environment with `dlib` -- are *not* bundled (they are large
#' and platform-specific) and must live in an external directory located via
#' `mlmorph_dir`.
#'
#' The session configuration is handed to the app through the
#' `intraitR.digitizer` option (and the `INTRAITR_MLMORPH_*` environment
#' variables for the ml-morph paths); both are set for the duration of the call
#' and restored on exit.
#'
#' # One workbook, three sheets
#'
#' `measurements` holds one row per specimen, in the wide FISHMORPH layout
#' (`1_X, 1_Y, ... 24_X, 24_Y`) read back by [read_landmarks_xlsx()]
#' (`n_landmarks = 22`, `x_pattern = "{i}_X"`, `y_pattern = "{i}_Y"`), together
#' with the operator, the photograph, its pixel size, the quality score,
#' `mm_per_px`, and the per-record status counts (`n_seeded`, `n_predicted`,
#' ...) that say how much of the configuration was actually looked at. The last
#' two coordinate pairs are the entry hinges 23-24 (see *Curved specimens*
#' below): recorded so that a specimen can be reopened in the axis it was
#' digitized under, and deliberately outside the `n_landmarks = 22` an analysis
#' reads.
#'
#' `bias` has the same layout but one row per *repeated* digitization, with
#' `individual`, `operator` and `replicate` columns: it is the input of
#' [measurement_error()] and [operator_disagreement()]. `bias_summary` is
#' computed from it at each write -- per individual and per landmark, the
#' median distance of the repeats to their own mean position, in pixels and as
#' a percentage of the standard length (`Bl`, landmarks 1-2) -- which is the
#' one-number-per-landmark view that says where the protocol is imprecise
#' before any modelling.
#'
#' The workbook is an EXPORT. The journal is the source of truth: every record
#' is appended to it first, as one immutable line per landmark, so an
#' interrupted session costs at most the specimen being digitized. See
#' [landmark_journal_open()] and [consolidate_landmarks()].
#'
#' # Working in the app
#'
#' Everything follows one *active-landmark* model, from the first click to the
#' last: a single point is active, a click on the photograph places it, and the
#' selection advances along one sequence, `1, 22, 23, 2, 3 ... 19, 20, 21` --
#' the axis first and complete, then the anatomical landmarks, then the scale
#' bar. Only the derived points 8, 9 and 11 and the spare hinge 24 are skipped,
#' and they stay reachable from the button bar, as does any other landmark at
#' any moment.
#'
#' The moment LM2 goes down the whole configuration is seeded, so placing by
#' hand is the default way to work rather than a mode to switch into. Running
#' the predictor is optional and available throughout: it refines the
#' anatomical landmarks over the seeded configuration. The button bar above the
#' photograph is also a status display -- active, placed by hand, marked `NA`,
#' automatic or derived, hinge, scale bar, and not yet placed are all
#' distinguishable at a glance, which makes an unreviewed point visible before
#' it is exported rather than after.
#'
#' The side panel is organised in tabs -- `Specimen`, `Repeats`, `Display`,
#' `Checks`, `Seed` -- so that what is set once per batch (the seeding sliders,
#' the quality controls) does not stand between the operator and what is set
#' once per specimen. With `bslib` installed the app uses a Bootstrap 5 theme;
#' without it, it falls back to the standard Shiny layout, unchanged in
#' function.
#'
#' Field photographs of 12 to 24 Mpx would otherwise make clicking sluggish,
#' since the plot redraws on every interaction. The image is therefore
#' downsampled once when it is loaded and the full-resolution array is dropped,
#' the display bitmap is converted to a raster once rather than on every
#' redraw, and only the visible crop is drawn when zoomed. A `Display` selector
#' trades sharpness against speed (800 to 2400 px, or full resolution; 1200 px
#' by default). None of this touches the coordinates -- landmarks are always
#' recorded in original image pixels -- and the predictor is still handed the
#' file itself at full resolution.
#'
#' Flipping the photograph remaps the points already placed instead of
#' discarding them, and a separate display-only flip mirrors the image while
#' leaving the coordinates untouched (useful when a reloaded configuration is
#' mirrored relative to its photograph). Images are routed by their magic bytes
#' rather than their file extension, so the `.jpg` files that are in fact
#' `PNG`, `GIF` or `BMP` -- common in specimen archives -- open correctly,
#' through `magick` when it is installed.
#'
#' # Curved specimens: the broken axis
#'
#' The FISHMORPH conventions (segment 3-4 perpendicular to the body axis, the
#' eye group on one vertical, the ventral group on one line) are defined
#' against the antero-posterior axis. On a fish photographed with a bent body a
#' single straight axis 1-2 misstates all of them at once. The app therefore
#' accepts *hinge* points that break the axis into up to four segments, each
#' convention being applied in the frame of the segment it belongs to: head
#' conventions on 1-22, body depth and pectoral fin on 22-23, caudal peduncle
#' and fin on 23-2. Landmark 22 is a genuine landmark -- [fishmorph_segments()]
#' already uses it to split the standard length into (1-22) + (22-2) -- and is
#' exported. Landmarks 23 and 24 are entry aids rather than landmarks, but they
#' are written out all the same, in their own `23_X ... 24_Y` columns: they
#' define the frames every convention was applied in, so without them a
#' specimen reopened for correction comes back with a straight axis and its
#' geometry silently stops matching the one it was digitized under. They must
#' be left out of any shape analysis -- read the first 22 points
#' (`n_landmarks = 22`), not every column ending in `_X`. Placing no hinge
#' reproduces exactly the straight-axis behaviour.
#'
#' # Auditing a batch
#'
#' Each record carries, per point, a `status`: `"clicked"` for a point placed
#' or moved by hand, `"seeded"` for one still at the median FISHMORPH
#' proportion the app used to lay out the configuration, `"predicted"` for one
#' still sitting exactly where the model put it, `"derived"` for the
#' geometrically computed ventral points 8, 9 and 11, `"adjusted"` for one
#' snapped onto the body outline by the extreme-point check below, `"na"` for a
#' point declared non-measurable and `"missing"` for one never placed. This is
#' the piece of information a coordinate table cannot carry, and it is what
#' distinguishes a measurement from a plausible guess: a `"predicted"` point
#' was at least inferred from this image, whereas a `"seeded"` one was measured
#' on no specimen at all. The journal keeps them point by point; the workbook
#' keeps the counts per specimen. Both are worth auditing before the
#' coordinates are analysed.
#'
#' # Repeated digitization: measurement error and operator bias
#'
#' A landmark coordinate is a measurement, and like any measurement it has a
#' technical variance that has to be estimated before a biological one is
#' interpreted: the same operator does not click twice in exactly the same
#' place, and two operators disagree more than one operator with themselves. In
#' `mode = "repeat"` the app saves the pass and stays on the same photograph,
#' until the individual has `n_repeats` digitizations.
#'
#' Each pass is saved under an identifier of its own -- `"<code>_rep<N>"`, or
#' `"<code>_<operator>_rep<N>"` when an operator is named, the convention of
#' the T-26 repeatability set ([load_t26_saudrune_landmarks()], `source =
#' "repeatability"`). The replicate number is always the last
#' underscore-separated token and the operator label is stripped of
#' underscores, so an identifier decomposes unambiguously from the right;
#' [read_mlmorph_landmarks()] reverses it with `replicate = "parse"` and
#' `operator = "parse"`, and the `bias` sheet carries `individual`, `operator`
#' and `replicate` as columns anyway.
#'
#' Repeats are cleared by default (`Blind repeat`): the app wipes the
#' configuration after each save so the next pass starts from the snout. This
#' is not a convenience setting. A pass resumed from the configuration just
#' saved measures how far the operator chose to move points they had already
#' placed, not how reproducibly they place them; the replicate variance then
#' reflects the operator's reluctance to revise rather than the precision of
#' the protocol, and `%ME` collapses towards zero.
#'
#' # The extreme-point check
#'
#' FISHMORPH defines `Bd` as the MAXIMUM body depth, so LM3 must be the most
#' dorsal and LM4 the most ventral landmark of the body outline. No per-pair
#' convention catches a breach of that -- each pair stays internally consistent
#' while `Bd` is quietly under-measured -- so the app tests it when the
#' specimen is saved (box "Check LM3 / LM4 (extremes) on save", on by default)
#' and offers to measure the landmark again, to snap it onto the true extreme,
#' or to save as is. Auto-correction keeps the landmark's position along the
#' axis and only changes its height, so `Bd` grows without disturbing the
#' perpendicularity of the 3-4 segment; the points it moves are exported as
#' `"adjusted"`.
#'
#' Heights are perpendicular coordinates taken in each point's own body
#' segment, so posture is not mistaken for error, and the dorsal side is read
#' off the relative position of LM3 and LM4 rather than assumed from the image.
#' The caudal peduncle and fin (16-19), the appendage tips (12, 15) and the
#' derived ventral points (8, 9, 11 -- computed from LM4, so circular as a test
#' of LM4) are excluded. On the 1,036 digitized T-26 specimens the check flags
#' 1.5 % of the batch at a median overshoot of 6.8 % of `Bl`, and the flagged
#' specimens have a median `Bd/Bl` of 0.14 against a FISHMORPH median of 0.248
#' -- that is, they are genuinely under-measured, and correction brings them
#' back into the expected range.
#'
#' # Coincident landmarks: a measurement of zero
#'
#' A bar under the photograph declares the segments that are ZERO on the
#' specimen in view. A zero is a measurement like any other -- neither a missing
#' value nor a placement error -- and the FISHMORPH ratios are defined to take
#' it: `OGp = 0` for a mouth opening on the ventral profile, `PFv = 0` for a
#' pectoral fin inserted on the belly. Four rules are offered:
#'
#' \describe{
#'   \item{`Mo = 0`}{LM9 takes the coordinates of LM1 -- the mouth sits on the
#'     ventral profile.}
#'   \item{`LM6 = LM8`}{LM6 takes the coordinates of LM8 -- the bottom of the
#'     head is the body underside.}
#'   \item{`PFi = 0`}{LM10 takes the coordinates of LM11 -- the pectoral fin
#'     inserts on the belly.}
#'   \item{`LM5 = LM13`}{LM5 takes the coordinates of LM13 -- the eye reaches
#'     the top of the head.}
#' }
#'
#' **Nothing is deleted.** Both landmarks keep a position, both are drawn on the
#' photograph and both are written to the workbook; one simply takes the
#' coordinates of the other, so the segment between them measures zero. A
#' coincidence is a measurement, an absence is `NA`, and the two must not be
#' confused downstream.
#'
#' Clicking two landmarks onto the same pixel would express the same thing but
#' would not SURVIVE: the conventions re-derive the ventral points on the belly
#' line and the head order re-separates the eye group by its margin, so the zero
#' would be undone at the next click. A declared rule is re-applied after every
#' propagation, every re-seed and every prediction, which is what makes a zero a
#' stable statement about the fish rather than a position that drifts.
#'
#' Which landmark moves is a protocol decision, not an aesthetic one, and it is
#' not the same for every rule. For the mouth the fixed point is LM1, the snout,
#' an anatomical landmark that must not move. For the two ventral rules the
#' BELLY LINE holds: LM8 and LM11 are its intersections with the eye and the
#' pectoral verticals, so the head bottom and the fin insertion come onto them
#' rather than the reverse -- the ventral profile is a global fit, steadier than
#' a single click. For the eye at the top of the head, LM5 (the head outline)
#' comes onto LM13, since moving LM13 would change `Ed`, the eye diameter, which
#' is a measurement in its own right.
#'
#' Landmarks moved by a rule are exported with status `"adjusted"` -- placed by
#' a rule the operator invoked, neither pointed at by hand nor left at a seed.
#' The declarations are reset for every specimen, since they are statements
#' about one fish, and read back from the coordinates when a specimen is
#' reopened in the `"correct"` queue: two coincident landmarks re-tick their
#' box, so a zero saved yesterday is still visibly a zero today.
#'
#' # The eye vertical, in order
#'
#' The same box checks a second convention, on the six landmarks the FISHMORPH
#' conventions put on ONE vertical: 5, 13, 7, 14, 6, 8. Being on a vertical says
#' nothing about their ORDER along it, and the order is anatomy rather than a
#' choice -- top of the head, top of the eye, centre of the eye, bottom of the
#' eye, bottom of the head, body underside, read from the back downwards. Two
#' things are tested, and they are not the same statement: that **LM5 tops the
#' group** (the `Hd` analogue of the LM3/LM4 rule for `Bd`), and that **every
#' consecutive pair is in order**, which catches a local swap the first cannot
#' see.
#'
#' This is the failure no other check catches, because each pair stays
#' internally consistent: with 13 and 14 exchanged -- the eye clicked
#' bottom-first -- `Ed` (13-14) keeps its exact length while `Eh` (7-8) silently
#' measures to the wrong edge of the eye. Nothing in a coordinate table shows
#' it, and no Procrustes fit will either.
#'
#' Settled on the data, like the extreme-point rule. The expected order already
#' holds for 98.6 % of the 1,036 digitized T-26 configurations (13 above 5 in 9
#' specimens, 0.87 %, the same nine as "LM5 does not top the group"; 7 above 13
#' in 4; 14 above 7 in 1; 8 above 6 in 1) and for 100 % of the 250 repeatability
#' configurations. An order a hand-digitized corpus already satisfies to that
#' degree is a convention, not a preference, and what is left is worth looking
#' at one specimen at a time.
#'
#' An inversion is reported but **never auto-corrected**: moving a landmark to
#' satisfy the order would invent a measurement rather than repair one. The
#' dialog offers *Measure again* -- which selects the landmark found on the
#' wrong side, not the reference it was compared with -- and *Save without
#' correcting*; *Auto-correct* only appears when there is an extreme-point
#' violation, the only kind a snap can repair.
#'
#' Once the axis (LM1, the hinges, LM2) is in place the app seeds every
#' remaining landmark at the median proportion of the body -- medians of
#' segment over standard length across 6,492 to 7,706 FISHMORPH species -- so
#' the work is repositioning rather than placing from nothing. Sliders expose
#' the quantities those ratios leave free. A landmark moved by hand is never
#' re-seeded.
#'
#' Digitizing points out of order silently produces wrong measurements
#' downstream in [fishmorph_segments()]; always spot-check immediately with
#' [plot_fishmorph_points()] on the imported object, and consider
#' [detect_outliers()] across a full batch once Procrustes-aligned.
#'
#' @references
#' Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
#' Villeger S (2021). FISHMORPH: A global database on morphological
#' traits of freshwater fishes. Global Ecology and Biogeography, 30(12),
#' 2330-2336. \doi{10.1111/geb.13395}
#'
#' Porto A, Voje KL (2020). ML-morph: A fast, accurate and general approach
#' for automated detection and landmarking of biological structures in
#' images. Methods in Ecology and Evolution, 11(4), 500-512.
#' \doi{10.1111/2041-210X.13373}
#'
#' @seealso [read_landmarks_xlsx()], [consolidate_landmarks()],
#'   [landmark_journal_open()], [read_mlmorph_landmarks()],
#'   [plot_fishmorph_points()], [fishmorph_segments()], [detect_outliers()],
#'   [measurement_error()], [operator_disagreement()]
#'
#' @examples
#' \dontrun{
#' # A digitizing session: photographs in, one workbook out.
#' digitize_landmarks(
#'   photo_dir        = "T26/photos",
#'   xlsx_path        = "T26/T26_landmarks.xlsx",
#'   journal_dir      = "T26/landmark_journal",   # default
#'   operator         = "AT",
#'   xlsx_flush_every = 10,
#'   mode             = "new"
#' )
#'
#' # A repeatability session on the same photographs: 5 blind passes each.
#' digitize_landmarks(
#'   photo_dir = "T26/photos", xlsx_path = "T26/T26_landmarks.xlsx",
#'   operator  = "AT", mode = "repeat", n_repeats = 5
#' )
#'
#' # Read the workbook back, one object per sheet.
#' lm <- read_landmarks_xlsx("T26/T26_landmarks.xlsx", sheet = "measurements",
#'                           n_landmarks = 22, x_pattern = "{i}_X",
#'                           y_pattern = "{i}_Y", id_cols = "specimen")
#' rep_lm <- read_landmarks_xlsx("T26/T26_landmarks.xlsx", sheet = "bias",
#'                               n_landmarks = 22, x_pattern = "{i}_X",
#'                               y_pattern = "{i}_Y",
#'                               id_cols = c("individual", "operator", "replicate"))
#' measurement_error(gpa_fish(rep_lm), individual = rep_lm$metadata$individual,
#'                   method = "procrustes")
#'
#' # After a crash: rebuild the workbook from the journals.
#' consolidate_landmarks("T26/landmark_journal",
#'                       xlsx_path = "T26/T26_landmarks_rebuilt.xlsx")
#' }
#'
#' @export
digitize_landmarks <- function(photo_dir,
                               xlsx_path = NULL,
                               journal_dir = NULL,
                               operator = NULL,
                               mode = c("new", "correct", "repeat"),
                               n_repeats = 3L,
                               ruler_mm = 10,
                               xlsx_flush_every = 10L,
                               mlmorph_dir = NULL, predictor = NULL,
                               python = NULL,
                               sheets = c(measurements = "measurements",
                                          bias = "bias",
                                          summary = "bias_summary"),
                               launch.browser = getOption("shiny.launch.browser",
                                                          interactive()),
                               ...) {
  ## ---- argument validation (runs regardless of interactivity) ---------------
  mode <- match.arg(mode)
  .one_path <- function(x, what) {
    if (!is.character(x) || length(x) != 1L || is.na(x))
      stop("`", what, "` must be a single path.", call. = FALSE)
    x
  }
  photo_dir <- .one_path(photo_dir, "photo_dir")
  if (!dir.exists(photo_dir))
    stop("`photo_dir` directory not found: ", photo_dir, call. = FALSE)
  photo_dir <- normalizePath(photo_dir, mustWork = TRUE)

  if (is.null(xlsx_path))
    xlsx_path <- file.path(dirname(photo_dir), "intraitR_landmarks.xlsx")
  xlsx_path <- .one_path(xlsx_path, "xlsx_path")
  if (!grepl("\\.xlsx$", xlsx_path, ignore.case = TRUE))
    stop("`xlsx_path` must end in \".xlsx\": ", xlsx_path, call. = FALSE)
  if (!dir.exists(dirname(xlsx_path)))
    stop("The directory of `xlsx_path` does not exist: ", dirname(xlsx_path),
         call. = FALSE)
  xlsx_path <- file.path(normalizePath(dirname(xlsx_path), mustWork = TRUE),
                         basename(xlsx_path))

  if (is.null(journal_dir))
    journal_dir <- file.path(dirname(xlsx_path), "landmark_journal")
  journal_dir <- .one_path(journal_dir, "journal_dir")

  if (!is.null(operator) &&
      (!is.character(operator) || length(operator) != 1L || is.na(operator)))
    stop("`operator` must be a single character string (or NULL).", call. = FALSE)

  n_repeats <- suppressWarnings(as.integer(n_repeats))
  if (length(n_repeats) != 1L || is.na(n_repeats) || n_repeats < 2L)
    stop("`n_repeats` must be a single integer >= 2.", call. = FALSE)
  ruler_mm <- suppressWarnings(as.numeric(ruler_mm))
  if (length(ruler_mm) != 1L || is.na(ruler_mm) || ruler_mm <= 0)
    stop("`ruler_mm` must be a single positive number.", call. = FALSE)
  xlsx_flush_every <- suppressWarnings(as.integer(xlsx_flush_every))
  if (length(xlsx_flush_every) != 1L || is.na(xlsx_flush_every))
    stop("`xlsx_flush_every` must be a single integer.", call. = FALSE)
  xlsx_flush_every <- max(1L, xlsx_flush_every)

  if (!is.character(sheets) || !all(c("measurements", "bias", "summary") %in%
                                    names(sheets)))
    stop("`sheets` must be a character vector named measurements, bias, summary.",
         call. = FALSE)
  if (anyDuplicated(sheets))
    stop("`sheets` must give three distinct sheet names.", call. = FALSE)

  if (!is.null(mlmorph_dir)) {
    mlmorph_dir <- .one_path(mlmorph_dir, "mlmorph_dir")
    if (!dir.exists(mlmorph_dir))
      stop("`mlmorph_dir` directory not found: ", mlmorph_dir, call. = FALSE)
  }
  if (!is.null(predictor)) {
    predictor <- .one_path(predictor, "predictor")
    if (!file.exists(predictor))
      stop("`predictor` file not found: ", predictor, call. = FALSE)
  }
  if (!is.null(python)) {
    python <- .one_path(python, "python")
    if (!file.exists(python) && !nzchar(Sys.which(python)))
      stop("`python` interpreter not found: ", python, call. = FALSE)
  }

  ## ---- required packages ----------------------------------------------------
  for (pkg in c("shiny", "jpeg", "png", "writexl")) {
    if (!requireNamespace(pkg, quietly = TRUE))
      stop("Package \"", pkg, "\" is required by digitize_landmarks(); ",
           "install it with install.packages(\"", pkg, "\").", call. = FALSE)
  }
  # readxl only matters when an existing workbook has to be resumed from.
  if (file.exists(xlsx_path) && !requireNamespace("readxl", quietly = TRUE))
    stop("Package \"readxl\" is required to resume from an existing workbook (",
         xlsx_path, "); install it with install.packages(\"readxl\").",
         call. = FALSE)
  ## Optional: 'magick' lets the app open images whose real format does not
  ## match their extension (a sizeable minority of ".jpg" specimen photographs
  ## are in fact PNG, GIF or BMP). Without it those files simply fail to load.
  if (!requireNamespace("magick", quietly = TRUE))
    message("Package \"magick\" is not installed: photographs whose real format ",
            "differs from their file extension (e.g. a GIF named \".jpg\") will ",
            "not open. install.packages(\"magick\") to handle them.")
  if (!requireNamespace("bslib", quietly = TRUE))
    message("Package \"bslib\" is not installed: the app falls back to the ",
            "standard Shiny layout (same features, plainer look). ",
            "install.packages(\"bslib\") for the themed interface.")

  ## ---- the photograph queue -------------------------------------------------
  photos <- sort(list.files(photo_dir, full.names = TRUE, ignore.case = TRUE,
                            pattern = "\\.(jpe?g|png|gif|bmp|tiff?)$"))
  if (!length(photos))
    stop("No image found in `photo_dir`: ", photo_dir, call. = FALSE)
  message(sprintf("%d photograph(s) in %s.", length(photos), photo_dir))

  ## ---- locate the packaged app and worker -----------------------------------
  app_dir <- system.file("shiny", "landmarking_app", package = "intraitR")
  if (!nzchar(app_dir) || !file.exists(file.path(app_dir, "app.R")))
    stop("Could not locate the bundled landmarking app under ",
         "system.file(\"shiny/landmarking_app\", package = \"intraitR\"); ",
         "reinstall the package.", call. = FALSE)
  worker <- system.file("mlmorph", "predict_new_image.py", package = "intraitR")

  ## ---- resolve the ml-morph resource directory ------------------------------
  mlmorph_dir <- .resolve_mlmorph_dir(mlmorph_dir)
  if (is.null(mlmorph_dir))
    warning(
      "Could not auto-detect an ml-morph resource directory (no trained ",
      "predictor found). The app will open but the prediction step stays ",
      "disabled until you pass `mlmorph_dir` (or set INTRAITR_MLMORPH_DIR).",
      call. = FALSE)

  ## ---- guard: the app needs an interactive session --------------------------
  if (!interactive())
    stop("digitize_landmarks() launches an interactive Shiny application and ",
         "cannot be run non-interactively (e.g. via Rscript, in a knitted ",
         "vignette, or inside automated tests). Run it from an interactive R ",
         "session.", call. = FALSE)

  ## ---- hand the session to the app ------------------------------------------
  ## One option rather than a dozen environment variables: runApp() evaluates
  ## the app in THIS process, so the option is simply visible from it. The
  ## ml-morph paths stay in environment variables as well, so the app can also
  ## be launched standalone with shiny::runApp("inst/shiny/landmarking_app").
  cfg <- list(
    photo_dir = photo_dir, photos = photos, xlsx_path = xlsx_path,
    journal_dir = journal_dir, operator = operator, mode = mode,
    n_repeats = n_repeats, ruler_mm = ruler_mm,
    xlsx_flush_every = xlsx_flush_every,
    sheet_measurements = unname(sheets[["measurements"]]),
    sheet_bias = unname(sheets[["bias"]]),
    sheet_summary = unname(sheets[["summary"]]),
    app_version = tryCatch(as.character(utils::packageVersion("intraitR")),
                           error = function(e) "dev"))
  old_opt <- options(intraitR.digitizer = cfg)
  on.exit(options(old_opt), add = TRUE)

  env <- c(
    INTRAITR_MLMORPH_DIR       = if (!is.null(mlmorph_dir)) mlmorph_dir else "",
    INTRAITR_MLMORPH_WORKER    = if (nzchar(worker)) worker else "",
    INTRAITR_MLMORPH_PY        = if (!is.null(python)) python else "",
    INTRAITR_MLMORPH_PREDICTOR = if (!is.null(predictor)) normalizePath(predictor) else "")
  old <- Sys.getenv(names(env), unset = NA, names = TRUE)
  do.call(Sys.setenv, as.list(env))
  on.exit({
    set_again <- old[!is.na(old)]
    if (length(set_again)) do.call(Sys.setenv, as.list(set_again))
    unset <- names(old)[is.na(old)]
    if (length(unset)) Sys.unsetenv(unset)
  }, add = TRUE)

  message(sprintf("Workbook: %s\nJournal : %s\nMode    : %s",
                  xlsx_path, journal_dir, mode))
  shiny::runApp(app_dir, launch.browser = launch.browser, ...)
  invisible(xlsx_path)
}

# Auto-detect an ml-morph resource directory. Returns a normalized absolute
# path, or NULL if none of the candidates looks like an ml-morph directory.
# A directory "looks like" ml-morph when it holds a trained predictor, the
# prediction worker, or the aligned training dataset.
.resolve_mlmorph_dir <- function(mlmorph_dir = NULL) {
  looks_like <- function(d) {
    nzchar(d) && dir.exists(d) && any(file.exists(file.path(d, c(
      "predict_new_image.py",
      file.path("mlmorph_run_app", "predictor.dat"),
      file.path("mlmorph_run_aligned", "predictor.dat"),
      "mlmorph_dataset_aligned"
    ))))
  }
  if (!is.null(mlmorph_dir)) {
    return(normalizePath(mlmorph_dir, mustWork = FALSE))
  }
  env <- Sys.getenv("INTRAITR_MLMORPH_DIR", "")
  if (nzchar(env) && dir.exists(env)) {
    return(normalizePath(env, mustWork = FALSE))
  }
  wd <- getwd()
  candidates <- c(
    file.path(wd, "ml_morph"),
    normalizePath(file.path(wd, "..", "ml_morph"), mustWork = FALSE),
    wd
  )
  hit <- Filter(looks_like, candidates)
  if (length(hit)) normalizePath(hit[[1]], mustWork = FALSE) else NULL
}
