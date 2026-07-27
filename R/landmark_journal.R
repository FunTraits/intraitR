# =============================================================================
# landmark_journal.R -- append-only capture layer for digitize_landmarks()
#
# THE PROBLEM. The landmarking app used to write every specimen by rewriting a
# single table in full, in a cloud-synchronised folder. A crash, a power cut or
# a synchronisation lock during that rewrite does not cost the last specimen: it
# can cost the whole file. The volume is not the issue (a few thousand specimens
# x 22 points is a few Mb) -- the WRITE PATTERN is.
#
# THE PRINCIPLE. Never rewrite what is already written. Capture becomes a stream
# of immutable files; the analysable table is REBUILT on demand.
#
#   photographs --[app]--> append-only journal --[consolidation]--> xlsx / data
#                          (never modified)                         (export)
#
#   * One journal per SESSION, "landmarks_<operator>_<timestamp>.tsv". A finished
#     session is a frozen file, so a sync service cannot produce a conflicted
#     copy of it and two workstations produce two files that merge by plain
#     concatenation.
#   * LONG format (one row = ONE point): adding a landmark tomorrow is extra
#     rows, not a schema migration, and every row carries the per-point `status`
#     that a wide sheet cannot hold.
#   * A crash damages at worst the last line of the current journal, which is
#     detected and dropped when read.
#   * Deduplication keeps the last record per key, which yields the HISTORY of
#     corrections for free.
#
# This layer is deliberately dependency-free (base R). `writexl` is used only by
# the optional workbook export.
#
# See R/digitize_landmarks.R for the writing side.
# =============================================================================

# Journal columns, in order. Any column added later MUST be appended at the END
# of this vector: landmark_journal_read() tolerates journals of different widths
# (written by earlier versions) by filling absent columns with NA.
.INTRAITR_JOURNAL_COLS <- c(
  "record_id",      # identifier of one RECORD (one press of "Save")
  "timestamp",      # ISO 8601 UTC; lexicographic order IS chronological order
  "operator",       # who digitized
  "app_version",    # version of the digitizing tool
  "mode",           # new | correct | repeat
  "target_sheet",   # workbook sheet the record is destined for
  "row_key",        # deduplication KEY (the saved identifier)
  "specimen",       # saved identifier (individual, or individual_operator_repN)
  "individual",     # physical individual
  "replicate",      # digitization number for that individual (1 outside repeats)
  "photo_file",     # photograph file name (basename)
  "img_w", "img_h", # image size in pixels: X/Y are in IMAGE pixels
  "quality",        # operator's quality score for the photograph (1-5)
  "ruler_mm",       # real length of the scale bar 20-21 (mm), or NA
  "mm_per_px",      # resulting scale, or NA
  "landmark",       # point number
  "x", "y",         # coordinates in image pixels (Y downwards)
  "status"          # clicked | seeded | predicted | adjusted | derived | na | missing
)

# Meaning of `status` -- the information a wide coordinate sheet cannot carry,
# and the one that separates a measurement from a plausible guess:
#   clicked  : placed or moved by hand (or reloaded from an earlier session)
#   seeded   : still at its median-FISHMORPH seed, never checked by the operator
#   predicted: still exactly where the ml-morph model put it, never checked
#   adjusted : snapped by the extreme-point convention (LM3/LM4 -> maximum Bd)
#   derived  : geometrically computed (8, 9, 11)
#   na       : explicitly declared non-measurable
#   missing  : never placed
.INTRAITR_JOURNAL_STATUS <- c("clicked", "seeded", "predicted", "adjusted",
                              "derived", "na", "missing")

# ISO 8601 timestamp in UTC, to the millisecond. In UTC and in this format the
# lexicographic order of the strings IS the chronological order, so
# deduplication can sort without ever re-parsing a date and without depending on
# the workstation's time zone.
.intraitr_iso_now <- function()
  format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")

# Neutralise anything that would break a TSV (tab, newline, quote). ALWAYS
# returns at least one element: an absent piece of metadata (NULL, or a Shiny
# input not yet initialised) would otherwise give a zero-length vector and make
# data.frame() fail -- losing the record instead of degrading it.
.intraitr_tsv_safe <- function(x) {
  x <- as.character(x)
  if (!length(x)) return("")
  x[is.na(x)] <- ""
  gsub("[\t\r\n\"]+", " ", x)
}

# Fixed number of DECIMALS, never significant digits: format() would apply
# getOption("digits") and round an abscissa of 12345.678 px to "12345.68".
.intraitr_num <- function(v) {
  v <- suppressWarnings(as.numeric(v))
  if (!length(v)) return("")
  out <- rep("", length(v))
  ok <- is.finite(v)
  if (any(ok)) out[ok] <- formatC(v[ok], format = "f", digits = 6,
                                  drop0trailing = TRUE)
  out
}


#' Open a session landmark journal (append-only)
#'
#' Creates `journal_dir` if needed and a TSV file specific to this session. The
#' file is only ever written to by appending: it is never re-read nor rewritten
#' while the session runs, and becomes immutable the moment the session ends.
#' This is the capture layer behind [digitize_landmarks()], and the reason a
#' crashed session costs at most the specimen being digitized rather than the
#' whole data set.
#'
#' @param journal_dir Directory holding the journals. Created if absent.
#' @param operator Operator identifier, traced in every row and in the session
#'   file name. `NULL` (default) uses the system user.
#' @param app_version Version of the digitizing tool, traced in every row: it is
#'   what makes it possible to know, in two years, with which geometry a given
#'   specimen was digitized.
#'
#' @return An object of class `"intrait_journal"`: a handle to pass to
#'   [landmark_journal_append()], carrying the journal `path`, the `operator`
#'   and the `session_id`.
#'
#' @seealso [landmark_journal_append()], [landmark_journal_read()],
#'   [consolidate_landmarks()], [digitize_landmarks()]
#'
#' @examples
#' d <- file.path(tempdir(), "journal_demo")
#' jr <- landmark_journal_open(d, operator = "AT")
#' basename(jr$path)
#' unlink(d, recursive = TRUE)
#'
#' @export
landmark_journal_open <- function(journal_dir, operator = NULL,
                                  app_version = NA_character_) {
  if (!is.character(journal_dir) || length(journal_dir) != 1L || is.na(journal_dir))
    stop("`journal_dir` must be a single directory path.", call. = FALSE)
  if (is.null(operator) || !nzchar(operator))
    operator <- tryCatch(unname(Sys.info()[["user"]]), error = function(e) "unknown")
  operator <- gsub("[^A-Za-z0-9._-]+", "_", operator)

  if (!dir.exists(journal_dir))
    dir.create(journal_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(journal_dir))
    stop("Could not create the journal directory: ", journal_dir, call. = FALSE)

  stamp <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC")
  sid   <- paste0(operator, "_", stamp)
  path  <- file.path(journal_dir, paste0("landmarks_", sid, ".tsv"))
  k <- 1L                                   # two launches within one second
  while (file.exists(path)) {
    k <- k + 1L
    path <- file.path(journal_dir, sprintf("landmarks_%s-%d.tsv", sid, k))
  }
  cat(paste(.INTRAITR_JOURNAL_COLS, collapse = "\t"), "\n", sep = "", file = path)
  message("Session journal: ", path)
  structure(
    list(path = path, dir = journal_dir, operator = operator, session_id = sid,
         app_version = as.character(app_version),
         n = local({ e <- new.env(parent = emptyenv()); e$i <- 0L; e })),
    class = "intrait_journal")
}


#' Append one record (one digitization) to a landmark journal
#'
#' A "record" is one press of the app's *Save* button: one row per landmark,
#' all sharing the same `record_id`. Writing is a plain `cat(append = TRUE)` of
#' a text block built beforehand -- the existing file is never re-read nor
#' rewritten, so an interruption can only truncate the last line, which
#' [landmark_journal_read()] then discards.
#'
#' @param journal A handle from [landmark_journal_open()].
#' @param row_key Deduplication key: the saved identifier (an individual, or
#'   `"<individual>_<operator>_rep<N>"` for a repeated digitization).
#' @param coords Two-column matrix (X, Y) indexed by landmark number.
#' @param points Landmark numbers to record.
#' @param status Optional named character vector (names = point numbers) of
#'   per-point statuses; see the `status` values in the package `NEWS`. Points
#'   without a finite coordinate are recorded as `"na"` whatever is passed.
#' @param specimen,individual,replicate,photo_file,mode,target_sheet Record-level
#'   metadata, recycled over the points.
#' @param img_w,img_h,quality,ruler_mm,mm_per_px Further record-level metadata.
#'
#' @return The `record_id` written (invisibly), or `NULL` if there was nothing
#'   to write.
#'
#' @seealso [landmark_journal_open()], [landmark_journal_read()]
#'
#' @examples
#' d <- file.path(tempdir(), "journal_demo2")
#' jr <- landmark_journal_open(d, operator = "AT")
#' P <- cbind(X = c(10, 60), Y = c(20, 22))
#' landmark_journal_append(jr, row_key = "fish_01", coords = P, points = 1:2,
#'                         specimen = "fish_01", individual = "fish_01")
#' nrow(landmark_journal_read(d))
#' unlink(d, recursive = TRUE)
#'
#' @export
landmark_journal_append <- function(journal, row_key, coords, points,
                                    status = NULL, specimen = NA,
                                    individual = NA, replicate = 1L,
                                    photo_file = NA, mode = NA,
                                    target_sheet = NA, img_w = NA, img_h = NA,
                                    quality = NA, ruler_mm = NA,
                                    mm_per_px = NA) {
  if (!inherits(journal, "intrait_journal"))
    stop("`journal` is not a journal handle from landmark_journal_open().",
         call. = FALSE)
  coords <- as.matrix(coords)
  points <- points[points >= 1 & points <= nrow(coords)]
  if (!length(points)) return(invisible(NULL))

  journal$n$i <- journal$n$i + 1L
  rid <- sprintf("%s-%05d", journal$session_id, journal$n$i)

  st <- rep("clicked", length(points))
  if (!is.null(status)) {
    hit <- match(as.character(points), names(status))
    st[!is.na(hit)] <- as.character(status)[hit[!is.na(hit)]]
  }
  # Without a usable coordinate no other status means anything: record "na"
  # rather than let a reader believe the point was placed or computed.
  fin <- is.finite(coords[points, 1]) & is.finite(coords[points, 2])
  st[!fin] <- "na"

  rows <- data.frame(
    record_id = rid, timestamp = .intraitr_iso_now(),
    operator = journal$operator,
    app_version = if (length(journal$app_version)) journal$app_version else "",
    mode = .intraitr_tsv_safe(mode), target_sheet = .intraitr_tsv_safe(target_sheet),
    row_key = .intraitr_tsv_safe(row_key), specimen = .intraitr_tsv_safe(specimen),
    individual = .intraitr_tsv_safe(individual),
    replicate = .intraitr_num(replicate),
    photo_file = .intraitr_tsv_safe(photo_file),
    img_w = .intraitr_num(img_w), img_h = .intraitr_num(img_h),
    quality = .intraitr_num(quality), ruler_mm = .intraitr_num(ruler_mm),
    mm_per_px = .intraitr_num(mm_per_px),
    landmark = as.character(points),
    x = .intraitr_num(round(coords[points, 1], 3)),
    y = .intraitr_num(round(coords[points, 2], 3)),
    status = st, stringsAsFactors = FALSE)
  rows <- rows[, .INTRAITR_JOURNAL_COLS, drop = FALSE]

  txt <- paste(do.call(paste, c(unname(as.list(rows)), sep = "\t")), collapse = "\n")
  cat(txt, "\n", sep = "", file = journal$path, append = TRUE)
  invisible(rid)
}


.intraitr_journal_empty <- function() {
  d <- as.data.frame(matrix(character(0), nrow = 0,
                            ncol = length(.INTRAITR_JOURNAL_COLS)),
                     stringsAsFactors = FALSE)
  names(d) <- .INTRAITR_JOURNAL_COLS
  d
}


#' Read and concatenate every journal in a directory
#'
#' Tolerant by construction: a last line truncated by a crash is dropped
#' (mandatory columns missing), and a journal written by an earlier version
#' (fewer columns) is filled with `NA`. Two workstations' journals merge by
#' plain concatenation.
#'
#' @param journal_dir Journal directory, or a vector of directories.
#'
#' @return A LONG `data.frame`, one row per point and per record, with the
#'   columns listed in `intraitR:::.INTRAITR_JOURNAL_COLS`. Coordinates,
#'   `replicate`, `quality`, `img_w`, `img_h`, `ruler_mm` and `mm_per_px` are
#'   returned numeric; everything else is character.
#'
#' @seealso [consolidate_landmarks()], [landmark_journal_open()]
#'
#' @examples
#' d <- file.path(tempdir(), "journal_demo3")
#' jr <- landmark_journal_open(d, operator = "AT")
#' landmark_journal_append(jr, "fish_01", cbind(c(10, 60), c(20, 22)), 1:2,
#'                         specimen = "fish_01", individual = "fish_01")
#' str(landmark_journal_read(d)[c("specimen", "landmark", "x", "y", "status")])
#' unlink(d, recursive = TRUE)
#'
#' @export
landmark_journal_read <- function(journal_dir) {
  fs <- unlist(lapply(journal_dir, function(d)
    list.files(d, pattern = "^landmarks_.*\\.tsv$", full.names = TRUE)),
    use.names = FALSE)
  if (!length(fs)) return(.intraitr_journal_empty())

  parts <- lapply(fs, function(f) {
    d <- try(utils::read.delim(f, sep = "\t", header = TRUE, quote = "",
                               comment.char = "", colClasses = "character",
                               fill = TRUE, stringsAsFactors = FALSE),
             silent = TRUE)
    if (inherits(d, "try-error") || is.null(d) || !nrow(d)) return(NULL)
    for (cc in setdiff(.INTRAITR_JOURNAL_COLS, names(d)))
      d[[cc]] <- rep(NA_character_, nrow(d))
    d <- d[, .INTRAITR_JOURNAL_COLS, drop = FALSE]
    # A line truncated mid-write is unusable without record_id/landmark/row_key:
    # drop it silently, which is the whole point of an append-only file.
    ok <- !is.na(d$record_id) & nzchar(d$record_id) &
          !is.na(d$landmark)  & nzchar(d$landmark) &
          !is.na(d$row_key)
    d[ok, , drop = FALSE]
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(.intraitr_journal_empty())

  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  for (cc in c("landmark", "x", "y", "replicate", "quality",
               "img_w", "img_h", "ruler_mm", "mm_per_px"))
    out[[cc]] <- suppressWarnings(as.numeric(out[[cc]]))
  out
}


#' Rebuild the landmark table from the journals
#'
#' Reconstructs, from every journal in `journal_dir`, one row per digitization
#' in the "wide" layout of the workbook written by [digitize_landmarks()]
#' (`1_X, 1_Y, ... 24_X, 24_Y`), keeping for each key the LAST record -- so a
#' specimen digitized, then corrected, appears once, corrected. This is the
#' recovery path: the workbook can be deleted, corrupted, or left behind by a
#' crashed session, and the data are still there.
#'
#' @param journal_dir Journal directory, or a vector of directories.
#' @param points Landmark numbers to lay out as columns. Defaults to `1:24`,
#'   what [digitize_landmarks()] records: the 19 FISHMORPH landmarks, the scale
#'   bar (20-21), the curvature point (22) and the two entry hinges (23-24).
#'   The hinges are not landmarks and belong in no shape analysis; they are
#'   rebuilt here because they define the axis a specimen was digitized under.
#'   Pass `1:22` to leave them out.
#' @param history Logical. `FALSE` (default) keeps only the last record per
#'   key; `TRUE` keeps every record, adding `record_id` so the successive
#'   corrections of one specimen can be told apart and compared. `timestamp` is
#'   returned either way.
#' @param xlsx_path Optional path; when supplied, the result is also written
#'   there with [writexl::write_xlsx()], one sheet per group of `target_sheet`
#'   (typically `measurements` and `bias`).
#'
#' @return A `data.frame`, one row per digitization, with the identification
#'   columns (`specimen`, `individual`, `replicate`, `operator`, `photo_file`,
#'   ...), the coordinate columns, and the per-record status counts
#'   (`n_clicked`, `n_seeded`, `n_predicted`, `n_adjusted`, `n_na`).
#'
#' @seealso [landmark_journal_read()], [digitize_landmarks()],
#'   [read_landmarks_xlsx()]
#'
#' @examples
#' d <- file.path(tempdir(), "journal_demo4")
#' jr <- landmark_journal_open(d, operator = "AT")
#' P <- cbind(c(10, 60), c(20, 22))
#' landmark_journal_append(jr, "fish_01", P, 1:2, specimen = "fish_01",
#'                         individual = "fish_01", target_sheet = "measurements")
#' consolidate_landmarks(d, points = 1:2)[c("specimen", "1_X", "2_X")]
#' unlink(d, recursive = TRUE)
#'
#' @export
consolidate_landmarks <- function(journal_dir, points = 1:24,
                                  history = FALSE, xlsx_path = NULL) {
  j <- landmark_journal_read(journal_dir)
  points <- as.integer(points)
  id_cols <- c("specimen", "individual", "replicate", "operator", "mode",
               "target_sheet", "photo_file", "img_w", "img_h", "quality",
               "ruler_mm", "mm_per_px", "app_version")
  coord_cols <- as.vector(rbind(paste0(points, "_X"), paste0(points, "_Y")))
  cnt_cols <- c("n_clicked", "n_seeded", "n_predicted", "n_adjusted", "n_na")

  if (!nrow(j)) {
    out <- as.data.frame(
      matrix(numeric(0), nrow = 0,
             ncol = length(c("record_id", "timestamp", id_cols, coord_cols, cnt_cols))))
    names(out) <- c("record_id", "timestamp", id_cols, coord_cols, cnt_cols)
    if (!history) out <- out[, setdiff(names(out), "record_id"), drop = FALSE]
    return(out)
  }

  # One record = one press of Save. Sorting on the ISO timestamp is enough (see
  # .intraitr_iso_now); record_id breaks ties within a session.
  ord <- order(j$timestamp, j$record_id)
  j <- j[ord, , drop = FALSE]
  if (!history) {
    # Last record per key wins. The journal keeps the earlier ones, which is
    # what makes the correction history recoverable with history = TRUE.
    last_rec <- tapply(j$record_id, j$row_key, function(r) r[length(r)])
    j <- j[j$record_id %in% as.character(last_rec), , drop = FALSE]
  }

  recs <- split(j, factor(j$record_id, levels = unique(j$record_id)))
  rows <- lapply(recs, function(d) {
    one <- d[1L, , drop = FALSE]
    out <- data.frame(record_id = one$record_id, timestamp = one$timestamp,
                      stringsAsFactors = FALSE)
    for (cc in id_cols) out[[cc]] <- one[[cc]]
    # Coordinates: match() and not a merge, so a point absent from the record
    # stays NA rather than shifting the row.
    hit <- match(points, d$landmark)
    for (k in seq_along(points)) {
      out[[paste0(points[k], "_X")]] <- if (is.na(hit[k])) NA_real_ else d$x[hit[k]]
      out[[paste0(points[k], "_Y")]] <- if (is.na(hit[k])) NA_real_ else d$y[hit[k]]
    }
    # Counted over the whole record, including points outside `points`: the
    # summary answers "was this digitization checked", not "was this column".
    st <- d$status
    out$n_clicked   <- sum(st == "clicked")
    out$n_seeded    <- sum(st == "seeded")
    out$n_predicted <- sum(st == "predicted")
    out$n_adjusted  <- sum(st == "adjusted")
    out$n_na        <- sum(st == "na")
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  # `timestamp` is kept either way: it says WHEN a specimen was digitized, which
  # a wide table has no other way of carrying. Only `record_id`, meaningless
  # once the history is collapsed, is dropped.
  if (!history) out <- out[, setdiff(names(out), "record_id"), drop = FALSE]

  if (!is.null(xlsx_path)) {
    if (!requireNamespace("writexl", quietly = TRUE))
      stop("Package \"writexl\" is required to write `xlsx_path`.", call. = FALSE)
    sheets <- split(out, ifelse(is.na(out$target_sheet) | !nzchar(out$target_sheet),
                                "measurements", out$target_sheet))
    write_xlsx_atomic(sheets, xlsx_path)
    message(sprintf("Workbook rebuilt from the journals: %s (%s).",
                    xlsx_path, paste(names(sheets), collapse = ", ")))
  }
  out
}


#' Write a workbook atomically
#'
#' [writexl::write_xlsx()] overwrites its target in place: while it is being
#' rewritten (seconds, for a workbook of several Mb) the file is in an
#' intermediate state, and an interruption destroys it. This writes to a
#' temporary file in the SAME directory -- a necessary condition for the rename
#' to be atomic, a cross-volume rename being in fact a copy -- then switches by
#' renaming.
#'
#' The old file is not deleted but moved to `"<name>.prev.xlsx"`, which gives a
#' one-generation backup for free. If the final rename fails, the old file is
#' restored.
#'
#' @param x A named list of `data.frame`s (one per sheet), as
#'   [writexl::write_xlsx()] takes.
#' @param path Target path.
#' @param keep_prev Keep the previous generation (default `TRUE`).
#'
#' @return `TRUE`, invisibly, if the write succeeded.
#'
#' @seealso [consolidate_landmarks()], [digitize_landmarks()]
#'
#' @examples
#' f <- file.path(tempdir(), "demo_atomic.xlsx")
#' if (requireNamespace("writexl", quietly = TRUE)) {
#'   write_xlsx_atomic(list(measurements = data.frame(specimen = "fish_01")), f)
#'   file.exists(f)
#' }
#' unlink(c(f, sub("\\.xlsx$", ".prev.xlsx", f)))
#'
#' @export
write_xlsx_atomic <- function(x, path, keep_prev = TRUE) {
  if (!requireNamespace("writexl", quietly = TRUE))
    stop("Package \"writexl\" is required; install it with ",
         "install.packages(\"writexl\").", call. = FALSE)
  if (!is.list(x) || is.data.frame(x)) x <- list(Sheet1 = x)

  tmp <- file.path(dirname(path),
                   sprintf(".%s.tmp%d", basename(path), Sys.getpid()))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  writexl::write_xlsx(x, tmp)
  if (!file.exists(tmp))
    stop("Temporary write failed: ", tmp, call. = FALSE)

  prev <- sub("(\\.xlsx)?$", ".prev.xlsx", path)
  had  <- file.exists(path)
  # Move the old file aside BEFORE renaming: on Windows file.rename() fails when
  # the destination already exists.
  if (had) {
    if (file.exists(prev)) unlink(prev)
    if (!file.rename(path, prev))
      stop("Could not move the old workbook aside (open in Excel?): ", path,
           call. = FALSE)
  }
  if (!file.rename(tmp, path)) {
    if (had) file.rename(prev, path)                      # restore
    stop("Final rename failed: ", path, call. = FALSE)
  }
  if (had && !keep_prev) unlink(prev)
  invisible(TRUE)
}
