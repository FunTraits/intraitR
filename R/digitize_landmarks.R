#' Launch the interactive ml-morph landmarking application
#'
#' Opens the bundled Shiny application for semi-automatic digitization of
#' fish landmarks. The user loads a specimen photograph (or a folder of
#' photographs), places a handful of calibration clicks (snout, caudal-fin
#' base, a dorsal orientation point and the two scale-bar points), and a
#' trained ml-morph shape predictor (Porto & Voje, 2020) proposes the 19
#' anatomical FISHMORPH landmarks (Brosse et al., 2021); the remaining
#' points can then be reviewed and corrected by hand, quality-scored, and
#' exported to `CSV`/`tpsDig`. The exported `CSV`
#' (`specimen, landmark, X, Y, mm_per_px, note, status`) is read back into an
#' `"intrait_landmarks"` object with [read_mlmorph_landmarks()].
#'
#' This function replaces the former point-and-click wrapper around
#' [geomorph::digitize2d()]: rather than digitizing every landmark manually,
#' it drives a predictor-assisted workflow with far fewer clicks per
#' specimen and an active-learning loop (corrected specimens can be fed
#' back into training; see the `ml_morph/README.md` pipeline).
#'
#' @param mlmorph_dir Path to the ml-morph resource directory holding the
#'   trained predictor(s) (`mlmorph_run_app/predictor.dat`,
#'   `mlmorph_run_aligned/predictor.dat`), the aligned dataset
#'   (`mlmorph_dataset_aligned/`) and, optionally, a Python virtual
#'   environment (`.venv_mlmorph/`). If `NULL` (default), the location is
#'   auto-detected from the `INTRAITR_MLMORPH_DIR` environment variable and
#'   then from a small set of conventional locations relative to the current
#'   working directory (`ml_morph/`, `../ml_morph/`, and the working
#'   directory itself). A directory "looks like" an ml-morph directory when
#'   it contains a trained predictor, the worker script, or the aligned
#'   dataset.
#' @param predictor Optional path to a specific trained predictor
#'   (`.dat`) file to offer first in the app's model selector, in addition
#'   to any predictors auto-discovered under `mlmorph_dir`.
#' @param python Optional path to (or name of) the Python interpreter used
#'   to run the prediction worker. It must have `numpy`, `opencv-python`
#'   and `dlib` available (typically the `.venv_mlmorph` environment). If
#'   `NULL` (default), the interpreter is resolved from the
#'   `INTRAITR_MLMORPH_PY`/`PY` environment variables, then from
#'   `~/.venv_mlmorph/bin/python`, then from a `.venv_mlmorph/` inside
#'   `mlmorph_dir`, falling back to `python3` on the search path.
#' @param autosave Path to the writable `CSV` file the app uses to
#'   auto-save the cumulative multi-specimen table (reloaded on start-up).
#'   If `NULL` (default), a file `intraitR_landmarking_autosave.csv` is
#'   used in the working directory *from which this function is called*
#'   (necessary because [shiny::runApp()] switches the working directory to
#'   the read-only installed app folder while the app runs).
#' @param launch.browser Passed to [shiny::runApp()]; whether to open the
#'   app in a browser. Defaults to the `shiny.launch.browser` option, or to
#'   [interactive()].
#' @param ... Further arguments passed on to [shiny::runApp()] (for example
#'   `port` or `host`). Do not pass `appDir`; the packaged app directory is
#'   used automatically.
#'
#' @return Invisibly `NULL`. Called for its side effect of running the
#'   Shiny application (a blocking call in an interactive session).
#'   Landmark tables produced by the app are written to disk (`CSV`/`TPS`)
#'   and imported separately with [read_mlmorph_landmarks()] or
#'   [read_tps()].
#'
#' @details
#' The Shiny application is shipped inside the package
#' (`system.file("shiny/landmarking_app", package = "intraitR")`) together
#' with its Python worker (`system.file("mlmorph", package = "intraitR")`).
#' The heavier ml-morph assets — the trained predictor(s), the aligned
#' training dataset, and the Python virtual environment with `dlib` — are
#' *not* bundled (they are large and platform-specific) and must live in an
#' external ml-morph directory located via `mlmorph_dir`. When no predictor
#' is found the app still launches, but the prediction step is disabled
#' until a valid predictor is supplied.
#'
#' Resource locations are handed to the app through environment variables
#' (`INTRAITR_MLMORPH_DIR`, `INTRAITR_MLMORPH_WORKER`, `INTRAITR_MLMORPH_PY`,
#' `INTRAITR_MLMORPH_PREDICTOR`, `INTRAITR_MLMORPH_AUTOSAVE`); these are set
#' for the duration of the call and restored on exit, so the app can also be
#' launched directly with `shiny::runApp("ml_morph/landmarking_app")`, in
#' which case it falls back to paths relative to the `ml_morph/` folder.
#'
#' # Working in the app
#'
#' Correction follows an *active-landmark* model: one point is active at a
#' time, a click on the photograph places it, and the selection advances
#' automatically to the next point that actually needs review, skipping the
#' ones placed by a calibration click or derived geometrically. The button
#' bar above the photograph is also a status display -- active, placed by
#' hand, marked `NA`, automatic or derived, hinge, scale bar, and not yet
#' placed are all distinguishable at a glance, which makes an unreviewed
#' point visible before it is exported rather than after.
#'
#' Flipping the photograph remaps the points already placed instead of
#' discarding them, and a separate display-only flip mirrors the image while
#' leaving the coordinates untouched (useful when a reloaded table is
#' mirrored relative to its photograph). Images are routed by their magic
#' bytes rather than their file extension, so the `.jpg` files that are in
#' fact `PNG`, `GIF` or `BMP` -- common in specimen archives -- open
#' correctly, through `magick` when it is installed.
#'
#' # Curved specimens: the broken axis
#'
#' The FISHMORPH conventions (segment 3-4 perpendicular to the body axis,
#' the eye group on one vertical, the ventral group on one line) are defined
#' against the antero-posterior axis. On a fish photographed with a bent
#' body a single straight axis 1-2 misstates all of them at once. The app
#' therefore accepts *hinge* points that break the axis into up to four
#' segments, each convention being applied in the frame of the segment it
#' belongs to: head conventions on 1-22, body depth and pectoral fin on
#' 22-23, caudal peduncle and fin on 23-2. Landmark 22 is a genuine landmark
#' -- [fishmorph_segments()] already uses it to split the standard length
#' into (1-22) + (22-2) -- and is exported; landmarks 23 and 24 are entry
#' aids and are never written out. Placing no hinge reproduces exactly the
#' straight-axis behaviour.
#'
#' # Auditing a batch
#'
#' Each exported row carries a `status`: `"clicked"` for a point placed or
#' moved by hand, `"predicted"` for one still sitting exactly where the model
#' put it (never verified by eye, and therefore the first thing to audit),
#' `"derived"` for the geometrically computed ventral points 8, 9 and 11,
#' `"na"` for a point declared non-measurable and `"missing"` for one never
#' placed. This is the piece of information a coordinate table cannot carry,
#' and it is what distinguishes a measurement from a plausible guess.
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
#' @seealso [read_mlmorph_landmarks()], [plot_fishmorph_points()],
#'   [read_tps()], [fishmorph_segments()], [detect_outliers()]
#'
#' @examples
#' \dontrun{
#' # Auto-detect the ml-morph resources (e.g. an "ml_morph/" folder in the
#' # working directory) and open the landmarking app:
#' digitize_landmarks()
#'
#' # Point explicitly at the ml-morph directory, a specific predictor and
#' # the dlib-enabled Python environment:
#' digitize_landmarks(
#'   mlmorph_dir = "~/projects/fish/ml_morph",
#'   predictor   = "~/projects/fish/ml_morph/mlmorph_run_app/predictor.dat",
#'   python      = "~/.venv_mlmorph/bin/python"
#' )
#'
#' # Import the CSV exported from the app into an "intrait_landmarks" object:
#' lm <- read_mlmorph_landmarks("mesures.csv")
#' }
#'
#' @export
digitize_landmarks <- function(mlmorph_dir = NULL, predictor = NULL,
                               python = NULL, autosave = NULL,
                               launch.browser = getOption("shiny.launch.browser",
                                                          interactive()),
                               ...) {
  ## ---- argument validation (runs regardless of interactivity) ---------------
  if (!is.null(mlmorph_dir)) {
    if (!is.character(mlmorph_dir) || length(mlmorph_dir) != 1L || is.na(mlmorph_dir)) {
      stop("`mlmorph_dir` must be a single directory path (or NULL to auto-detect).",
           call. = FALSE)
    }
    if (!dir.exists(mlmorph_dir)) {
      stop("`mlmorph_dir` directory not found: ", mlmorph_dir, call. = FALSE)
    }
  }
  if (!is.null(predictor)) {
    if (!is.character(predictor) || length(predictor) != 1L || is.na(predictor)) {
      stop("`predictor` must be a single file path (or NULL).", call. = FALSE)
    }
    if (!file.exists(predictor)) {
      stop("`predictor` file not found: ", predictor, call. = FALSE)
    }
  }
  if (!is.null(python)) {
    if (!is.character(python) || length(python) != 1L || is.na(python)) {
      stop("`python` must be a single interpreter path or command name (or NULL).",
           call. = FALSE)
    }
    if (!file.exists(python) && !nzchar(Sys.which(python))) {
      stop("`python` interpreter not found: ", python, call. = FALSE)
    }
  }
  if (!is.null(autosave) &&
      (!is.character(autosave) || length(autosave) != 1L || is.na(autosave))) {
    stop("`autosave` must be a single file path (or NULL).", call. = FALSE)
  }

  ## ---- required packages ----------------------------------------------------
  for (pkg in c("shiny", "jpeg", "png")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Package \"", pkg, "\" is required by digitize_landmarks(); ",
           "install it with install.packages(\"", pkg, "\").", call. = FALSE)
    }
  }
  ## Optional: 'magick' lets the app open images whose real format does not
  ## match their extension (a sizeable minority of ".jpg" specimen photographs
  ## are in fact PNG, GIF or BMP). Without it those files simply fail to load.
  if (!requireNamespace("magick", quietly = TRUE)) {
    message("Package \"magick\" is not installed: photographs whose real format ",
            "differs from their file extension (e.g. a GIF named \".jpg\") will ",
            "not open. install.packages(\"magick\") to handle them.")
  }

  ## ---- locate the packaged app and worker -----------------------------------
  app_dir <- system.file("shiny", "landmarking_app", package = "intraitR")
  if (!nzchar(app_dir) || !file.exists(file.path(app_dir, "app.R"))) {
    stop("Could not locate the bundled landmarking app under ",
         "system.file(\"shiny/landmarking_app\", package = \"intraitR\"); ",
         "reinstall the package.", call. = FALSE)
  }
  worker <- system.file("mlmorph", "predict_new_image.py", package = "intraitR")

  ## ---- resolve the ml-morph resource directory ------------------------------
  mlmorph_dir <- .resolve_mlmorph_dir(mlmorph_dir)
  if (is.null(mlmorph_dir)) {
    warning(
      "Could not auto-detect an ml-morph resource directory (no trained ",
      "predictor found). The app will open but the prediction step stays ",
      "disabled until you pass `mlmorph_dir` (or set INTRAITR_MLMORPH_DIR).",
      call. = FALSE
    )
  }

  ## ---- autosave path: capture the CALLER's writable working directory -------
  ## (shiny::runApp() switches the wd to the read-only installed app folder).
  if (is.null(autosave)) {
    autosave <- file.path(getwd(), "intraitR_landmarking_autosave.csv")
  }

  ## ---- guard: the app needs an interactive session --------------------------
  if (!interactive()) {
    stop(
      "digitize_landmarks() launches an interactive Shiny application and ",
      "cannot be run non-interactively (e.g. via Rscript, in a knitted ",
      "vignette, or inside automated tests). Run it from an interactive R ",
      "session.", call. = FALSE
    )
  }

  ## ---- wire resources to the app via environment variables ------------------
  env <- c(
    INTRAITR_MLMORPH_DIR       = if (!is.null(mlmorph_dir)) mlmorph_dir else "",
    INTRAITR_MLMORPH_WORKER    = if (nzchar(worker)) worker else "",
    INTRAITR_MLMORPH_PY        = if (!is.null(python)) python else "",
    INTRAITR_MLMORPH_PREDICTOR = if (!is.null(predictor)) normalizePath(predictor) else "",
    INTRAITR_MLMORPH_AUTOSAVE  = autosave
  )
  old <- Sys.getenv(names(env), unset = NA, names = TRUE)
  do.call(Sys.setenv, as.list(env))
  on.exit({
    set_again <- old[!is.na(old)]
    if (length(set_again)) do.call(Sys.setenv, as.list(set_again))
    unset <- names(old)[is.na(old)]
    if (length(unset)) Sys.unsetenv(unset)
  }, add = TRUE)

  shiny::runApp(app_dir, launch.browser = launch.browser, ...)
  invisible(NULL)
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
