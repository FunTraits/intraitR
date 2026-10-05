#' Fold an earlier digitization into the workbook of the landmarking app
#'
#' Copies specimens digitized with an EARLIER tool -- another workbook, another
#' application, a hand-kept spreadsheet -- into the `measurements` sheet that
#' [digitize_landmarks()] reads, so that a specimen already measured somewhere
#' else stops reappearing in the app's "new" queue.
#'
#' The queue of [digitize_landmarks()] is the set difference between the
#' photographs on disk and the `specimen` column of the workbook: a specimen
#' measured into a DIFFERENT file is, from the app's point of view, a specimen
#' that has never been measured. It is offered again, digitized again, and the
#' corpus quietly acquires two independent measurements of one fish -- the most
#' expensive kind of error, because nothing in either file says it happened.
#' This function removes the cause rather than the symptom: after it has run,
#' one specimen is one row in one workbook.
#'
#' @param from The earlier digitization: a path to a spreadsheet (`.xlsx`,
#'   `.xls`, `.csv`) or a `data.frame` already loaded. WIDE layout, one row per
#'   digitization, with an identifier column and one column per coordinate (see
#'   `x_pattern`).
#' @param into Path to the workbook of the landmarking app -- the `xlsx_path`
#'   given to [digitize_landmarks()]. It is rewritten in place through
#'   [write_xlsx_atomic()], which keeps the previous state in a `.prev.xlsx`
#'   file; its other sheets are carried over untouched. The file may not exist
#'   yet, in which case it is created.
#' @param sheet_from,sheet_into Sheets to read from and write into. Default the
#'   first sheet of `from`, and `"measurements"` in `into`.
#' @param id_from Character, the column of `from` holding the specimen
#'   identifier. It must match the photograph file name without its extension,
#'   which is what the app uses as `specimen`. Defaults to `"Code"`.
#' @param operator_from Character or `NULL`, the column of `from` naming the
#'   operator. When several rows share an identifier they are taken to be
#'   repeated digitizations of ONE specimen and are reduced to a single row (see
#'   `consensus`). `NULL` treats every row as a distinct specimen and errors on
#'   duplicated identifiers. Defaults to `"operator"`.
#' @param x_pattern,y_pattern Character templates naming the coordinate columns
#'   of `from`, `{i}` standing for the landmark number. Defaults `"x_{i}"` and
#'   `"y_{i}"`; the app's own layout is `"{i}_X"` / `"{i}_Y"`, and the published
#'   FISHMORPH tables use the latter.
#' @param points Integer landmarks to import. Defaults to `1:25` (the 19
#'   anatomical points, the scale bar 20-21, the curvature point 22, the derived
#'   head base 23 and the two spare hinges 24-25). Points whose columns are
#'   absent from `from` are silently skipped and stay `NA` in the workbook.
#' @param consensus How several digitizations of one specimen are reduced to the
#'   single row the workbook holds: `"median"` (default) takes the coordinate-
#'   wise median over the operators, `"mean"` their centroid, `"first"` the
#'   first row in file order. See Details.
#' @param operator_keep Character or `NULL`. When given, only the rows of that
#'   operator are read, and `consensus` is not applied. Use it when one operator
#'   is the reference and the others are a repeatability set.
#' @param ruler_mm Numeric, the real-world length of the calibration bar
#'   (landmarks 20-21) in millimetres, used to fill `mm_per_px` exactly as the
#'   app does: `ruler_mm / dist(20, 21)`. `NA` (default) leaves both columns
#'   empty, and the imported specimens then carry no scale -- their pixel
#'   distances cannot be converted to length units downstream. The T-26 protocol
#'   uses a 10 mm bar.
#' @param label Character, the operator label written on the imported rows.
#'   Defaults to `"legacy"`; the number of digitizations the consensus was taken
#'   over is appended (`"legacy_n4"`), so the sheet says how each row was
#'   obtained.
#' @param journal_dir Optional path to the journal directory of the app
#'   (`journal_dir` of [digitize_landmarks()]). When supplied, every imported
#'   specimen is also appended to the journal with the per-point status
#'   `"imported"`, so that [consolidate_landmarks()] can rebuild a workbook that
#'   still contains them. `NULL` (default) writes the sheet only.
#' @param overwrite Logical. `FALSE` (default) imports only the identifiers
#'   ABSENT from `into`: a row measured with the app is always authoritative
#'   over an earlier one. `TRUE` replaces the existing rows as well, which
#'   discards work done in the app and is never what a routine import wants.
#' @param dry_run Logical. `TRUE` reports what would be written and returns it
#'   without touching any file. Run it first.
#' @param tol_bl Numeric, the relative spread of the standard length (landmarks
#'   1-2) tolerated between the digitizations of one specimen before a warning is
#'   raised. Defaults to `0.05` (5 %). See Details.
#'
#' @details
#' # What a consensus over operators does, and does not, assume
#'
#' Reducing several digitizations to one row by a coordinate-wise median assumes
#' that they are expressed in the SAME frame -- the same photograph, the same
#' pixels. That is the case for a repeatability set, where two operators clicked
#' one image, and it is the reason no Procrustes fit is involved: superimposing
#' would remove exactly the differences (position, size) that are here identical
#' by construction, and would return coordinates in a frame no photograph is in.
#'
#' The assumption is testable, and it is tested. The standard length (1-2) is
#' the same physical quantity for every operator of one specimen, so a spread
#' between them beyond `tol_bl` means the rows are NOT in one frame -- two shots
#' of the same fish, a resized image, an identifier reused. Those specimens are
#' listed in a warning and imported all the same: the function's job is to
#' report the anomaly, not to decide for the analyst what it means.
#'
#' `"median"` is the default because a coordinate-wise median tolerates one
#' operator misplacing one point, which a mean does not. It is not the geometric
#' median and the resulting configuration is not one operator's work: it is an
#' estimate, and `mode` says so. `"mean"` gives the centroid, the classical
#' choice when the digitizations are equally trustworthy; `"first"` keeps one
#' operator's actual clicks and estimates nothing.
#'
#' # Provenance
#'
#' Imported rows are recognisable in the sheet without any extra column:
#' `mode` is `"imported(<source file>)"`, `operator` is `<label>_n<k>`,
#' `app_version` names this function and the package version, and `timestamp`
#' is the moment of the import. `n_clicked` counts the landmarks that arrived
#' with finite coordinates and `n_na` those that did not; `n_seeded`,
#' `n_predicted` and `n_adjusted` are zero, since an imported configuration went
#' through none of the app's seeding, prediction or snapping.
#'
#' Landmark 23, the head base, is DERIVED by the app from landmarks 1, 6 and 9
#' and the head axis. It is not recomputed here -- that geometry lives in the
#' app -- so it stays `NA` unless `from` already carries it. Reopening an
#' imported specimen in `mode = "correct"` re-derives it on the spot.
#'
#' # Idempotence
#'
#' With `overwrite = FALSE` the function is idempotent: a second call imports
#' nothing, because every identifier is by then present in `into`. Running it
#' at the head of a digitizing session is therefore safe, and is the intended
#' use.
#'
#' @return Invisibly, the `data.frame` of the rows that were added (or, under
#'   `dry_run`, that would be), in the schema of the `measurements` sheet.
#'   Zero rows when there was nothing to import.
#'
#' @seealso [digitize_landmarks()] for the app whose queue this feeds,
#'   [consolidate_landmarks()] to rebuild a workbook from the journal,
#'   [read_landmarks_xlsx()] to read the result back as landmarks
#'
#' @examples
#' # An earlier digitization of two fish, each measured by two operators.
#' old <- data.frame(
#'   Code     = c("F-01", "F-01", "F-02", "F-02"),
#'   operator = c("op1", "op2", "op1", "op2"),
#'   x_1 = c(10, 11, 20, 21), y_1 = c(5, 5, 6, 6),
#'   x_2 = c(90, 91, 80, 81), y_2 = c(5, 6, 6, 5)
#' )
#'
#' wb <- file.path(tempdir(), "landmarks.xlsx")
#' # What would be imported, without writing anything:
#' add <- import_legacy_landmarks(old, wb, points = 1:2, dry_run = TRUE)
#' add[c("specimen", "operator", "mode", "1_X", "2_X")]
#'
#' @export
import_legacy_landmarks <- function(from, into,
                                    sheet_from = 1L,
                                    sheet_into = "measurements",
                                    id_from = "Code",
                                    operator_from = "operator",
                                    x_pattern = "x_{i}",
                                    y_pattern = "y_{i}",
                                    points = 1:25,
                                    consensus = c("median", "mean", "first"),
                                    operator_keep = NULL,
                                    ruler_mm = NA_real_,
                                    label = "legacy",
                                    journal_dir = NULL,
                                    overwrite = FALSE,
                                    dry_run = FALSE,
                                    tol_bl = 0.05) {
  consensus <- match.arg(consensus)
  points    <- sort(unique(as.integer(points)))
  if (!length(points)) stop("`points` is empty.", call. = FALSE)
  if (!is.character(into) || length(into) != 1L || is.na(into))
    stop("`into` must be a single path to the workbook of the app.", call. = FALSE)

  src  <- .ilm_read_table(from, sheet_from)
  what <- if (is.data.frame(from)) "<data.frame>" else basename(from)

  if (!id_from %in% names(src))
    stop("Column \"", id_from, "\" not found in `from`; set `id_from` to the ",
         "column holding the specimen identifier.", call. = FALSE)
  ids <- trimws(as.character(src[[id_from]]))
  keep <- !is.na(ids) & nzchar(ids)
  if (!any(keep)) stop("No usable identifier in column \"", id_from, "\".", call. = FALSE)
  src <- src[keep, , drop = FALSE]
  ids <- ids[keep]

  # -- operator column, and the optional restriction to one of them ------------
  ops <- if (!is.null(operator_from) && operator_from %in% names(src))
    as.character(src[[operator_from]]) else rep(NA_character_, nrow(src))
  if (!is.null(operator_keep)) {
    sel <- !is.na(ops) & (ops %in% operator_keep)
    if (!any(sel))
      stop("No row with operator ", paste(sQuote(operator_keep), collapse = ", "),
           " in `from`. Available: ",
           paste(utils::head(sort(unique(stats::na.omit(ops))), 10), collapse = ", "),
           call. = FALSE)
    src <- src[sel, , drop = FALSE]; ids <- ids[sel]; ops <- ops[sel]
  }
  if (is.null(operator_from) && anyDuplicated(ids))
    stop("Duplicated identifiers in `from` and no `operator_from` column to ",
         "reduce them by; set `operator_from`, or `consensus`.", call. = FALSE)

  # -- coordinate columns actually present ------------------------------------
  xcol <- .ilm_expand(x_pattern, points)
  ycol <- .ilm_expand(y_pattern, points)
  has  <- (xcol %in% names(src)) & (ycol %in% names(src))
  if (!any(has))
    stop("None of the coordinate columns exist in `from` (looked for ",
         xcol[1], " / ", ycol[1], "). Check `x_pattern` and `y_pattern`.",
         call. = FALSE)
  if (any(!has))
    message(sprintf("Landmarks absent from `from` and left NA: %s.",
                    paste(points[!has], collapse = ", ")))
  pts_in <- points[has]

  X <- vapply(xcol[has], function(cc) suppressWarnings(as.numeric(src[[cc]])),
              numeric(nrow(src)))
  Y <- vapply(ycol[has], function(cc) suppressWarnings(as.numeric(src[[cc]])),
              numeric(nrow(src)))
  X <- matrix(X, nrow = nrow(src)); Y <- matrix(Y, nrow = nrow(src))

  # -- one row per specimen ----------------------------------------------------
  codes <- sort(unique(ids))
  agg <- switch(consensus,
                median = function(v) stats::median(v[is.finite(v)]),
                mean   = function(v) mean(v[is.finite(v)]),
                first  = function(v) { v <- v[is.finite(v)]; if (length(v)) v[1] else NA_real_ })
  red <- function(v) { v <- v[is.finite(v)]; if (!length(v)) NA_real_ else agg(v) }

  idx  <- split(seq_along(ids), factor(ids, levels = codes))
  nrep <- vapply(idx, length, integer(1))
  Xc <- t(vapply(idx, function(i) apply(X[i, , drop = FALSE], 2, red), numeric(ncol(X))))
  Yc <- t(vapply(idx, function(i) apply(Y[i, , drop = FALSE], 2, red), numeric(ncol(Y))))
  dimnames(Xc) <- dimnames(Yc) <- list(codes, NULL)

  # -- are the digitizations of one specimen in ONE frame? ---------------------
  #    Bl (1-2) is the same physical quantity for every operator of one
  #    specimen; a spread between them means the rows are not comparable.
  if (all(c(1L, 2L) %in% pts_in) && any(nrep > 1L)) {
    j1 <- match(1L, pts_in); j2 <- match(2L, pts_in)
    bl <- sqrt((X[, j1] - X[, j2])^2 + (Y[, j1] - Y[, j2])^2)
    spread <- vapply(idx, function(i) {
      v <- bl[i]; v <- v[is.finite(v)]
      if (length(v) < 2L) return(0)
      (max(v) - min(v)) / stats::median(v)
    }, numeric(1))
    bad <- names(spread)[is.finite(spread) & spread > tol_bl]
    if (length(bad))
      warning(length(bad), " specimen(s) whose digitizations differ in standard ",
              "length by more than ", round(100 * tol_bl, 1), " %: they are ",
              "probably not the same photograph, and the consensus mixes two ",
              "frames. Imported all the same -- check them: ",
              paste(utils::head(bad, 8), collapse = ", "),
              if (length(bad) > 8) ", ..." else "", call. = FALSE)
  }

  # -- the target workbook -----------------------------------------------------
  sheets <- .ilm_read_workbook(into)
  meas   <- .ilm_normalise(sheets[[sheet_into]])
  present <- unique(meas$specimen[!is.na(meas$specimen)])
  new <- if (isTRUE(overwrite)) codes else setdiff(codes, present)
  n_skipped <- length(codes) - length(new)

  if (!length(new)) {
    message(sprintf(
      "Nothing to import: the %d identifier(s) of %s are all in %s already.",
      length(codes), what, basename(into)))
    return(invisible(.ilm_normalise(NULL)))
  }

  # -- build the rows in the schema of the sheet -------------------------------
  stamp <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ver <- tryCatch(as.character(utils::packageVersion("intraitR")),
                  error = function(e) "dev")
  out <- .ilm_blank(length(new))
  i_new <- match(new, codes)

  out$specimen   <- new
  out$individual <- new
  out$replicate  <- 1
  out$operator   <- sprintf("%s_n%d", label, nrep[i_new])
  out$mode       <- sprintf("imported(%s)", what)
  out$app_version <- sprintf("import_legacy_landmarks/%s", ver)
  out$timestamp  <- stamp
  out$ruler_mm   <- if (is.finite(ruler_mm)) ruler_mm else NA_real_

  for (k in seq_along(pts_in)) {
    out[[paste0(pts_in[k], "_X")]] <- Xc[i_new, k]
    out[[paste0(pts_in[k], "_Y")]] <- Yc[i_new, k]
  }

  # matrix() and not vapply() alone: with a single specimen vapply drops to a
  # vector and rowSums() would error on it.
  fin <- rowSums(matrix(vapply(points, function(p)
    is.finite(out[[paste0(p, "_X")]]) & is.finite(out[[paste0(p, "_Y")]]),
    logical(nrow(out))), nrow = nrow(out)))
  out$n_clicked <- fin
  out$n_na      <- length(points) - fin
  out$n_seeded  <- 0; out$n_predicted <- 0; out$n_adjusted <- 0

  # mm per pixel, exactly as the app computes it: the calibration bar 20-21.
  if (is.finite(ruler_mm) && all(c(20L, 21L) %in% pts_in)) {
    d <- sqrt((out[["20_X"]] - out[["21_X"]])^2 + (out[["20_Y"]] - out[["21_Y"]])^2)
    out$mm_per_px <- ifelse(is.finite(d) & d > 0, ruler_mm / d, NA_real_)
    n_ns <- sum(!is.finite(out$mm_per_px))
    if (n_ns) message(sprintf("%d imported specimen(s) without a usable scale bar.", n_ns))
  }

  message(sprintf(
    "%s: %d specimen(s) to import into %s (%s), %d already present and left alone.",
    what, nrow(out), basename(into), sheet_into, n_skipped))

  if (isTRUE(dry_run)) {
    message("Dry run: nothing written.")
    return(invisible(out))
  }

  # -- write ------------------------------------------------------------------
  if (isTRUE(overwrite) && length(present))
    meas <- meas[!(meas$specimen %in% new), , drop = FALSE]
  sheets[[sheet_into]] <- rbind(meas, out)
  write_xlsx_atomic(sheets, into)

  if (!is.null(journal_dir)) {
    jr <- landmark_journal_open(journal_dir, operator = label, app_version = ver)
    P <- matrix(NA_real_, max(points), 2)
    for (r in seq_len(nrow(out))) {
      P[] <- NA_real_
      for (p in pts_in) P[p, ] <- c(out[[paste0(p, "_X")]][r], out[[paste0(p, "_Y")]][r])
      landmark_journal_append(
        jr, row_key = out$specimen[r], coords = P, points = points,
        status = stats::setNames(rep("imported", length(points)), as.character(points)),
        specimen = out$specimen[r], individual = out$individual[r],
        replicate = 1L, mode = out$mode[r], target_sheet = sheet_into,
        ruler_mm = out$ruler_mm[r], mm_per_px = out$mm_per_px[r])
    }
  }

  message(sprintf("Written: %s now holds %d specimen(s).",
                  basename(into), length(unique(sheets[[sheet_into]]$specimen))))
  invisible(out)
}

# -- helpers ------------------------------------------------------------------

# "x_{i}" + 1:3 -> "x_1" "x_2" "x_3". A template rather than a fixed layout
# because the two conventions in use ("x_1" and "1_X") differ in more than the
# separator, and a regexp guessing between them would fail silently on the day a
# third appears.
.ilm_expand <- function(pattern, i) {
  if (!is.character(pattern) || length(pattern) != 1L || !grepl("{i}", pattern, fixed = TRUE))
    stop("Coordinate patterns must be a single string containing \"{i}\", ",
         "e.g. \"x_{i}\" or \"{i}_X\".", call. = FALSE)
  vapply(i, function(k) gsub("{i}", k, pattern, fixed = TRUE), character(1))
}

.ilm_read_table <- function(x, sheet = 1L) {
  if (is.data.frame(x)) return(as.data.frame(x, stringsAsFactors = FALSE))
  if (!is.character(x) || length(x) != 1L || !file.exists(x))
    stop("`from` must be a data.frame or the path of an existing file.", call. = FALSE)
  if (grepl("\\.csv$|\\.tsv$|\\.txt$", x, ignore.case = TRUE))
    return(utils::read.csv(x, stringsAsFactors = FALSE,
                           sep = if (grepl("\\.csv$", x, ignore.case = TRUE)) "," else "\t"))
  if (!requireNamespace("readxl", quietly = TRUE))
    stop("Package \"readxl\" is required to read ", basename(x), ".", call. = FALSE)
  as.data.frame(readxl::read_excel(x, sheet = sheet, .name_repair = "minimal"),
                stringsAsFactors = FALSE)
}

# Every sheet of the workbook, so that the ones this function does not touch are
# written back unchanged rather than dropped.
.ilm_read_workbook <- function(path) {
  if (!file.exists(path)) return(stats::setNames(list(), character(0)))
  if (!requireNamespace("readxl", quietly = TRUE))
    stop("Package \"readxl\" is required to read ", basename(path), ".", call. = FALSE)
  nms <- readxl::excel_sheets(path)
  out <- lapply(nms, function(s)
    as.data.frame(readxl::read_excel(path, sheet = s, .name_repair = "minimal"),
                  stringsAsFactors = FALSE))
  stats::setNames(out, nms)
}

# The schema of the `measurements` sheet, kept in step with the app: identical
# column set, identical order, identical types. Stated once here so that an
# imported row and a digitized one are indistinguishable in structure -- which is
# the whole point of the import.
.ILM_ID_COLS <- c("specimen", "individual", "replicate", "operator", "mode",
                  "photo_file", "photo_hash", "img_w", "img_h", "quality",
                  "reviewed", "reviewed_by", "review_date", "collapse_rules",
                  "ruler_mm", "mm_per_px", "n_clicked", "n_seeded",
                  "n_predicted", "n_adjusted", "n_na", "app_version",
                  "timestamp")
.ILM_CHR_COLS <- c("specimen", "individual", "operator", "mode", "photo_file",
                   "photo_hash", "reviewed", "reviewed_by", "review_date",
                   "collapse_rules", "app_version", "timestamp")

# `n` rows of NA in the schema of the sheet. Built column by column rather than
# by indexing an empty frame with NA: the latter works but relies on a subsetting
# corner case, and this file's whole purpose is that an imported row be
# structurally identical to a digitized one.
.ilm_blank <- function(n, points = 1:25) {
  cols <- c(.ILM_ID_COLS,
            as.vector(rbind(paste0(points, "_X"), paste0(points, "_Y"))))
  d <- data.frame(matrix(nrow = n, ncol = 0))
  for (cc in cols)
    d[[cc]] <- if (cc %in% .ILM_CHR_COLS) rep(NA_character_, n) else rep(NA_real_, n)
  rownames(d) <- NULL
  d
}

.ilm_normalise <- function(d, points = 1:25) {
  cols <- c(.ILM_ID_COLS,
            as.vector(rbind(paste0(points, "_X"), paste0(points, "_Y"))))
  if (is.null(d) || !nrow(d)) {
    e <- data.frame(matrix(nrow = 0, ncol = 0))
    for (cc in cols) e[[cc]] <- if (cc %in% .ILM_CHR_COLS) character(0) else numeric(0)
    return(e)
  }
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  for (cc in setdiff(cols, names(d))) d[[cc]] <- NA
  d <- d[, cols, drop = FALSE]
  for (cc in .ILM_CHR_COLS) d[[cc]] <- as.character(d[[cc]])
  for (cc in setdiff(cols, .ILM_CHR_COLS)) d[[cc]] <- suppressWarnings(as.numeric(d[[cc]]))
  rownames(d) <- NULL
  d
}
