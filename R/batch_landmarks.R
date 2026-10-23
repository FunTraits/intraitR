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
  if (is.null(ml)) stop("No prediction model found: install them once with ",
                        "install_mlmorph_models(), or pass `mlmorph_dir`.", call. = FALSE)
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
            file.path(ml, ".venv_mlmorph", "bin", "python"),
            .mlmorph_venv_python())            # install_mlmorph_python()
  cand <- cand[nzchar(cand) & file.exists(cand)]
  if (length(cand)) cand[1] else "python3"
}

#' Record the predictions of an automatic pre-pass without reviewing them
#'
#' Writes the landmarks found by [batch_landmarks()] to the measurement journal
#' as they are, without anyone looking at them -- what the digitizer would
#' record if every pre-filled photograph were saved untouched. It is meant for
#' a large batch on which the model is known to do well; the price is that
#' every error the model made is now a measurement.
#'
#' What is accepted, and what is not:
#' * photographs the pre-pass FLAGGED (`flags` non-empty: upside down, at the
#'   border, low confidence, no readable ruler, several fish...) are left out
#'   unless `include_flagged = TRUE` -- they are the ones a person should open;
#' * a photograph that already has a measurement in the journal is never
#'   overwritten;
#' * plates (several fish on one photograph) are left out, as in the digitizer;
#' * the conventions of the digitizer are applied (perpendicular depths, derived
#'   ventral points and LM23), exactly as when a pre-filled photograph opens.
#'
#' Nothing is hidden: every point keeps the status `"predicted"` (the derived
#' ones `"derived"`), the entry is `reviewed = "no"`, and the record says it
#' came from here (`app_version`). [landmark_journal_qc()] and the Results of
#' the hub list such specimens as not reviewed, and opening one in the
#' digitizer (mode `"correct"`) and saving it turns it into an ordinary,
#' checked measurement.
#'
#' @param batch Output folder of [batch_landmarks()], or its returned list.
#' @param journal_dir Folder of the landmark journal.
#' @param operator Operator recorded with the records (who ACCEPTED them).
#' @param photos Optional: restrict to these photographs (paths, file names or
#'   codes, i.e. file names without extension).
#' @param include_flagged Also accept the photographs the pre-pass flagged.
#' @param ruler_mm Real distance between landmarks 20 and 21, in mm, used for
#'   `mm_per_px` when the ruler was detected.
#' @param xlsx_path Optional workbook rebuilt from the journal afterwards
#'   ([consolidate_landmarks()]).
#' @param dry_run Report what would be recorded, write nothing.
#' @return Invisibly, a data.frame: `photo`, `code`, `flags`, `status`
#'   (`"accepted"`, `"dry-run"`, `"flagged"`, `"already measured"`,
#'   `"plate"`, `"no landmarks"`, `"incomplete"`), `n_points`.
#' @seealso [batch_landmarks()], [digitize_landmarks()], [retract_landmarks()]
#' @examples
#' \dontrun{
#' res <- batch_landmarks("prepared/T26/20260615", out_dir = "batch_T26")
#' accept_batch_landmarks(res, "measurements/landmark_journal", operator = "AT",
#'                        dry_run = TRUE)
#' }
#' @export
accept_batch_landmarks <- function(batch, journal_dir, operator, photos = NULL,
                                   include_flagged = FALSE, ruler_mm = 10,
                                   xlsx_path = NULL, dry_run = FALSE) {
  if (is.list(batch) && !is.null(batch$out_dir)) batch <- batch$out_dir
  b <- read_batch_landmarks(batch)
  S <- b$summary; L <- b$landmarks
  if (!nrow(S)) {
    message("The pre-pass holds no photograph.")
    return(invisible(data.frame(photo = character(), code = character(),
                                flags = character(), status = character(),
                                n_points = integer())))
  }
  key <- function(p) tolower(basename(p))
  code_of <- function(p) tools::file_path_sans_ext(basename(p))
  # one line per PHOTOGRAPH: a plate has several rows (individuals)
  n_ind <- tapply(if (is.null(S$individual)) rep(1L, nrow(S)) else S$individual,
                  key(S$photo), function(x) length(unique(x)))
  S <- S[!duplicated(key(S$photo)), , drop = FALSE]
  if (!is.null(photos)) {
    want <- unique(c(key(photos), tolower(code_of(photos))))
    S <- S[key(S$photo) %in% want | tolower(code_of(S$photo)) %in% want, , drop = FALSE]
  }
  done <- tryCatch(.hub_journal_state(journal_dir)$code, error = function(e) character(0))
  out <- data.frame(photo = S$photo, code = code_of(S$photo), flags = S$flags,
                    status = NA_character_, n_points = 0L, stringsAsFactors = FALSE)
  out$status[out$code %in% done] <- "already measured"
  out$status[is.na(out$status) & n_ind[key(S$photo)] > 1L] <- "plate"
  out$status[is.na(out$status) & nzchar(out$flags) & !isTRUE(include_flagged)] <- "flagged"
  if ("individual" %in% names(L)) L <- L[L$individual == 1L, , drop = FALSE]
  byp <- split(L, key(L$photo))
  keep <- c(seq_len(N_ANAT), CURVE_PT, EXTRA_HINGES[1], SCALE_PTS)
  todo <- which(is.na(out$status))
  recs <- list()
  for (i in todo) {
    d <- byp[[key(out$photo[i])]]
    if (is.null(d)) { out$status[i] <- "no landmarks"; next }
    d <- d[d$landmark %in% keep & is.finite(d$X) & is.finite(d$Y), , drop = FALSE]
    P <- empty_coords()
    P[as.character(d$landmark), ] <- as.matrix(d[, c("X", "Y")])
    if (!all(is.finite(P[1, ])) || !all(is.finite(P[2, ]))) {
      out$status[i] <- "incomplete"; next
    }
    P <- apply_conventions(P)
    P <- derive_head_pt(P)
    fin <- is.finite(P[WB_PTS, 1]) & is.finite(P[WB_PTS, 2])
    st <- ifelse(!fin, "missing", ifelse(WB_PTS %in% DERIVED_LM, "derived", "predicted"))
    names(st) <- as.character(WB_PTS)
    mmpx <- if (all(is.finite(P[c("20", "21"), ])) && is.finite(ruler_mm) && ruler_mm > 0) {
      dd <- sqrt(sum((P["21", ] - P["20", ])^2)); if (dd > 0) ruler_mm / dd else NA_real_
    } else NA_real_
    out$n_points[i] <- sum(fin & st != "derived")
    recs[[length(recs) + 1L]] <- list(i = i, P = P, st = st, mmpx = mmpx,
                                      w = S$width[i] %||% NA, h = S$height[i] %||% NA)
  }
  if (isTRUE(dry_run)) {
    out$status[vapply(recs, function(r) r$i, integer(1))] <- "dry-run"
  } else if (length(recs)) {
    jr <- landmark_journal_open(journal_dir, operator = operator,
      app_version = paste0("intraitR ", tryCatch(as.character(utils::packageVersion("intraitR")),
                                                 error = function(e) "dev"),
                           " accept_batch_landmarks (not reviewed)"))
    for (r in recs) {
      i <- r$i; f <- out$photo[i]
      landmark_journal_append(
        jr, row_key = out$code[i], coords = r$P, points = WB_PTS, status = r$st,
        specimen = out$code[i], individual = out$code[i], replicate = 1L,
        photo_file = basename(f), mode = "new", target_sheet = "measurements",
        img_w = r$w, img_h = r$h,
        ruler_mm = if (is.finite(r$mmpx)) ruler_mm else NA,
        mm_per_px = r$mmpx,
        photo_hash = if (file.exists(f)) tryCatch(photo_hash(f), error = function(e) NA) else NA,
        reviewed = "no")
      out$status[i] <- "accepted"
    }
    if (!is.null(xlsx_path))
      tryCatch(.refresh_workbook_from_journal(journal_dir, xlsx_path),
               error = function(e) warning("The journal is written, but the workbook ",
                                           "could not be updated: ", conditionMessage(e),
                                           call. = FALSE))
  }
  tab <- table(factor(out$status, c("accepted", "dry-run", "flagged", "already measured",
                                    "plate", "no landmarks", "incomplete")))
  tab <- tab[tab > 0]
  message(paste(sprintf("%d %s", tab, names(tab)), collapse = ", "),
          if (any(out$status %in% "accepted"))
            ". Recorded WITHOUT REVIEW: every point keeps the status 'predicted'." else ".")
  invisible(out)
}

# Bring a digitizer workbook up to date with the journal WITHOUT losing what
# only the workbook holds: the sheets the journal rebuilds (measurements, bias)
# get the journal's rows, in the workbook's own columns (its schema kept exactly,
# workbook's schema kept as it is); every other sheet (bias_summary, notes...) is written back as read.
# No workbook yet: consolidate_landmarks() writes one.
.refresh_workbook_from_journal <- function(journal_dir, xlsx_path) {
  if (!file.exists(xlsx_path))
    return(invisible(suppressMessages(consolidate_landmarks(journal_dir,
                                                            xlsx_path = xlsx_path))))
  for (pkg in c("readxl", "writexl"))
    if (!requireNamespace(pkg, quietly = TRUE))
      stop("Package \"", pkg, "\" is required to update the workbook.", call. = FALSE)
  cons <- suppressMessages(consolidate_landmarks(journal_dir))
  tgt <- ifelse(is.na(cons$target_sheet) | !nzchar(cons$target_sheet),
                "measurements", cons$target_sheet)
  sheets <- readxl::excel_sheets(xlsx_path)
  out <- lapply(stats::setNames(sheets, sheets), function(sh)
    as.data.frame(readxl::read_excel(xlsx_path, sheet = sh, guess_max = 10000)))
  drop <- c("target_sheet")
  for (sh in unique(tgt)) {
    rows <- cons[tgt == sh, setdiff(names(cons), drop), drop = FALSE]
    old <- out[[sh]]
    if (!is.null(old)) {                 # the workbook's own schema, exactly
      for (cc in setdiff(names(old), names(rows))) rows[[cc]] <- rep(NA, nrow(rows))
      rows <- rows[, names(old), drop = FALSE]
    }
    out[[sh]] <- rows
  }
  write_xlsx_atomic(out, xlsx_path)
  invisible(xlsx_path)
}
