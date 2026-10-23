#' Automatic landmarking of a batch of photographs (no clicks)
#'
#' Runs the fully automatic ml-morph chain on every photograph of a folder,
#' without opening them: the GLOBAL network (`mlmorph_run_global/model.onnx`)
#' finds the snout (LM1), the caudal-fin basis (LM2) and the dorsal side on the
#' whole photograph (then on a zoomed crop of the fish), and the neural-network
#' model of the canonical frame (`mlmorph_run_cnn/model.onnx`) places the other
#' landmarks. Same chain as the "Auto (no clicks)" button of
#' [digitize_landmarks()], with the models loaded once (a fraction of a second
#' per photograph on a CPU).
#'
#' Nothing is written to the measurement journal: the result is a proposal to
#' check. Every photograph gets quality flags and a risk score, so that only the
#' doubtful ones need opening:
#' * `plusieurs`: one fish more than `max_fish` was found (an undeclared plate);
#' * `dorsal`: the dorsal side of the global network and the LM3 of the fine
#'   model contradict each other (fish possibly upside down);
#' * `petit`: the fish spans less than `min_bl_frac` of the largest image side;
#' * `bord`: a landmark within 1 percent of the image border;
#' * `confiance`: score (mean confidence of the fine model) among the lowest 10
#'   percent of the batch.
#'
#' Localisation is robust to distractors (labels, reflections, other fish):
#' several candidates are taken for the snout and the caudal base, and each
#' snout-caudal pair is checked by the fine model, which recognises a real fish
#' in the canonical frame; on plates, each fish found is masked before the next
#' is searched.
#'
#' Scale bar (20-21): when the photographs carry a ruler (`ruler = TRUE`, the
#' default) and the ruler network `mlmorph_run_ruler/model.onnx` is present, the
#' two graduations are located automatically and `summary` gains `mm_per_px`,
#' `scale_quality` and `bl_mm`; a photograph whose ruler cannot be read is
#' flagged `règle`, and one whose graduation period departs from the network's
#' order of magnitude is flagged `échelle`. With `ruler = FALSE` nothing is
#' searched and nothing is flagged: measurements stay in pixels. The choice is
#' recorded per photograph in the `ruler` column of `summary`. Coordinates are
#' in pixels of the raw pixel grid (EXIF orientation ignored, as in the
#' applications).
#'
#' @param photos Folder of photographs, or a character vector of image paths.
#' @param out_dir Output folder (created). A photograph already processed there
#'   is skipped unless `redo = TRUE`.
#' @param recursive Look into sub-folders of `photos`.
#' @param qc Write annotated thumbnails and a contact sheet
#'   `qc/index.html`, sorted by decreasing risk.
#' @param open_qc Open the contact sheet in the browser when done.
#' @param max_fish Fish per photograph. `1` (default): one fish, and a photograph
#'   carrying more is flagged `plusieurs`. More (plates): up to `max_fish` fish
#'   are found, numbered `individual` 1, 2, ... from top to bottom.
#' @param ruler Do the photographs carry a ruler (scale bar)? `TRUE`
#'   (default): it is detected automatically (landmarks 20-21) and a photograph
#'   without a readable ruler is flagged `règle`. `FALSE`: no detection, no
#'   `règle` flag, measurements in pixels only. Applies to the whole call: run a
#'   folder with and a folder without ruler separately (a photograph already in
#'   `out_dir` keeps its first run unless `redo = TRUE`).
#' @param ruler_mm Real distance between landmarks 20 and 21, in mm (used only
#'   when `ruler = TRUE`).
#' @param min_bl_frac Flag threshold (see Details).
#' @param hinges Also write the hinges 22/24 of the broken axis predicted by the
#'   model (curved fish). Off by default: away from the sites where hinges were
#'   clicked for training, predicted hinges bias the derived points.
#' @param redo Process every photograph again.
#' @param mlmorph_dir,python As in [digitize_landmarks()]: the ml-morph folder
#'   (`NULL` auto-detects it) and the Python interpreter (`NULL`:
#'   `INTRAITR_MLMORPH_PY`, `~/.venv_mlmorph/bin/python`, then `python3`).
#' @return Invisibly, a list: `summary` (one row per fish: `photo`,
#'   `individual`, `ruler`, dimensions, standard length in pixels `bl_px`,
#'   `score`, `flags`, `risk`, and with a ruler `mm_per_px`, `bl_mm`), `landmarks` (long: `photo`, `individual`, `landmark`,
#'   `X`, `Y`, `conf`) and `out_dir`.
#' @seealso [read_batch_landmarks()], [digitize_landmarks()]
#' @examples
#' \dontrun{
#' res <- batch_landmarks("00_project/prepared/SAUDRUNE/20260427",
#'                        out_dir = "batch_saudrune", open_qc = TRUE)
#' subset(res$summary, flags != "")   # photographs to review
#' }
#' @export
batch_landmarks <- function(photos, out_dir, recursive = FALSE, qc = TRUE,
                            open_qc = interactive(), max_fish = 1L,
                            ruler = TRUE, ruler_mm = 10,
                            min_bl_frac = 0.15, hinges = FALSE, redo = FALSE,
                            mlmorph_dir = NULL, python = NULL) {
  if (!is.logical(ruler) || length(ruler) != 1L || is.na(ruler))
    stop("`ruler` must be TRUE or FALSE.", call. = FALSE)
  if (ruler && !(is.numeric(ruler_mm) && length(ruler_mm) == 1L && is.finite(ruler_mm) && ruler_mm > 0))
    stop("`ruler_mm` must be a single positive number.", call. = FALSE)
  ml <- .resolve_mlmorph_dir(mlmorph_dir)
  if (is.null(ml)) stop("ml-morph folder not found: pass `mlmorph_dir`.", call. = FALSE)
  glob  <- file.path(ml, "mlmorph_run_global", "model.onnx")
  fine  <- file.path(ml, "mlmorph_run_cnn", "model.onnx")
  ds    <- file.path(ml, "mlmorph_dataset_cnn")
  miss <- c(glob, fine, ds)[!file.exists(c(glob, fine, ds))]
  if (length(miss)) stop("Missing: ", paste(miss, collapse = ", "), call. = FALSE)
  script <- system.file("mlmorph", "batch_auto.py", package = "intraitR")
  if (!nzchar(script)) script <- file.path(ml, "batch_auto.py")
  if (!file.exists(script)) stop("batch_auto.py not found.", call. = FALSE)
  py <- .batch_python(python, ml)
  if (ruler && !file.exists(file.path(ml, "mlmorph_run_ruler", "model.onnx")))
    warning("`ruler = TRUE` but no ruler network (mlmorph_run_ruler/model.onnx): ",
            "the ruler is not detected and measurements stay in pixels.", call. = FALSE)

  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  out_dir <- normalizePath(out_dir)
  input <- if (length(photos) == 1L && dir.exists(photos)) normalizePath(photos) else {
    f <- file.path(out_dir, "input_list.txt")
    writeLines(normalizePath(photos, mustWork = TRUE), f); f
  }
  args <- c(shQuote(script), "--input", shQuote(input), "--out-dir", shQuote(out_dir),
            "--global-model", shQuote(glob), "--predictor", shQuote(fine),
            "--dataset-dir", shQuote(ds), "--max-fish", as.integer(max_fish),
            "--min-bl-frac", min_bl_frac,
            if (ruler) c("--ruler-mm", ruler_mm) else "--no-ruler",
            if (recursive) "--recursive", if (qc) "--qc", if (redo) "--redo",
            if (hinges) "--hinges")
  status <- system2(py, args)
  if (!identical(status, 0L) && !file.exists(file.path(out_dir, "summary.csv")))
    stop("Batch failed (see the messages above).", call. = FALSE)
  res <- read_batch_landmarks(out_dir)
  idx <- file.path(out_dir, "qc", "index.html")
  if (qc && open_qc && file.exists(idx)) utils::browseURL(idx)
  n_bad <- sum(nzchar(res$summary$flags))
  message(sprintf("%d photograph(s), %d fish, %d flagged for review -> %s",
                  length(unique(res$summary$photo)), nrow(res$summary), n_bad, out_dir))
  invisible(res)
}

#' Read the output of [batch_landmarks()]
#'
#' @param out_dir Output folder of [batch_landmarks()].
#' @return A list: `summary`, `landmarks` (long) and `out_dir`; `flags` is
#'   `""` for a photograph without any flag.
#' @export
read_batch_landmarks <- function(out_dir) {
  s <- file.path(out_dir, "summary.csv"); l <- file.path(out_dir, "landmarks_long.csv")
  if (!file.exists(s)) stop("No summary.csv in ", out_dir, call. = FALSE)
  S <- utils::read.csv(s, stringsAsFactors = FALSE)
  S$flags[is.na(S$flags)] <- ""
  # runs older than the `ruler` option: a ruler was assumed
  if (!"ruler" %in% names(S)) S$ruler <- TRUE
  S$ruler <- as.logical(S$ruler); S$ruler[is.na(S$ruler)] <- TRUE
  L <- if (file.exists(l)) utils::read.csv(l, stringsAsFactors = FALSE) else
    data.frame(photo = character(), landmark = integer(), X = numeric(), Y = numeric(), conf = numeric())
  list(summary = S[order(-S$risk), , drop = FALSE], landmarks = L, out_dir = out_dir)
}

.batch_python <- function(python, ml) {
  cand <- c(if (is.null(python)) "" else python, Sys.getenv("INTRAITR_MLMORPH_PY", ""), Sys.getenv("PY", ""),
            path.expand("~/.venv_mlmorph/bin/python"),
            file.path(ml, ".venv_mlmorph", "bin", "python"))
  cand <- cand[nzchar(cand) & file.exists(cand)]
  if (length(cand)) cand[1] else "python3"
}
