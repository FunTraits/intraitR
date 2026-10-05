# =============================================================================
# photo_identity.R -- the identity of a photograph, and what survives a rename
#
# A digitized specimen is keyed on the name of its photograph: the file name
# without its extension IS the specimen code, in the workbook, in the journal
# and in the digitizing queues. That works exactly as long as the name never
# changes -- and the name is metadata. It carries the site, the date, the
# species and the specimen number, and a determination read again turns
# SAUDRUNESUDTOULOUSE_20260427_SQUCEP_004_AT into
# SAUDRUNESUDTOULOUSE_20260427_BARBAR_025_AT without a single pixel moving.
#
# Before this layer, that correction cost the measurements. The workbook still
# held the row under the old name, the queue matched on the new one, and a fish
# measured a week earlier came back in the "new" queue as if it had never been
# touched -- with no error, no warning, and a silent duplicate the day it was
# measured again. The bookkeeping was quietly deciding what the taxonomy was
# allowed to say.
#
# The fix is to record what a photograph IS alongside what it is called. An MD5
# of the file is stable under renaming, under moving, and under the whole of a
# re-import; it changes if and only if the bytes change. Reconciliation is then
# a join on that column, and a re-determination costs a rename and nothing else.
#
# NOT a perceptual hash. Two photographs of the same fish, or the same
# photograph re-encoded, are DIFFERENT digitizations: they have different pixel
# frames, so the coordinates of one are wrong on the other, and merging them
# would be a data error rather than a convenience. The exact-bytes criterion is
# the one that matches what the coordinates mean.
# =============================================================================


#' Fingerprint of an image file
#'
#' The MD5 sum of the file's bytes: the identity of a photograph that survives
#' renaming, moving and re-importing, and that changes if and only if the pixels
#' do. [digitize_landmarks()] records it next to the coordinates, in the
#' `photo_hash` column of the workbook and of the journal, so that a specimen
#' renamed -- because its determination was corrected, or its numbering redone --
#' is matched back to its own measurements instead of re-entering the "new"
#' queue as if it had never been digitized.
#'
#' @param path Character vector of file paths.
#'
#' @return A character vector of MD5 sums, `NA` for a path that does not exist
#'   or cannot be read. Names are dropped, so the result lines up positionally
#'   with `path`.
#'
#' @seealso [reconcile_photo_names()], [digitize_landmarks()]
#'
#' @examples
#' f <- tempfile(fileext = ".txt")
#' writeLines("not really an image", f)
#' photo_hash(f)
#' identical(photo_hash(f), photo_hash(f))   # stable
#' unlink(f)
#'
#' @export
photo_hash <- function(path) {
  path <- as.character(path)
  out <- rep(NA_character_, length(path))
  if (!length(path)) return(out)
  ok <- !is.na(path) & nzchar(path) & file.exists(path)
  if (any(ok))
    out[ok] <- unname(tryCatch(tools::md5sum(path[ok]),
                               error = function(e) rep(NA_character_, sum(ok))))
  out
}


#' Fingerprint a batch of images, remembering the answer
#'
#' [photo_hash()] reads every byte of every file. On a folder of several hundred
#' photographs of a few megabytes each that is a second or two from a local
#' disk, and considerably more from a synchronised folder, where reading a file
#' can mean fetching it from the cloud. Since a digitizing session starts by
#' fingerprinting the whole batch, and the batch barely changes between
#' sessions, the answers are kept in a small table beside the journals.
#'
#' A cached fingerprint is reused only when the file's SIZE and MODIFICATION
#' TIME both still match. That is the usual heuristic and it has the usual
#' limit -- a file rewritten within the timestamp's resolution, keeping its
#' size, would be missed -- but a photograph edited in place after digitization
#' is a protocol violation of its own, not a case to be silently absorbed. A
#' rename, which is what the cache exists to survive, changes neither size nor
#' mtime and is therefore free.
#'
#' @param path Character vector of image paths.
#' @param cache_file Path of the cache (a TSV). Its directory is created if
#'   needed. `NULL` disables the cache and falls back to [photo_hash()].
#'
#' @return A character vector of fingerprints, one per element of `path`.
#'
#' @seealso [photo_hash()], [reconcile_photo_names()]
#'
#' @examples
#' d <- file.path(tempdir(), "hash_cache_demo")
#' dir.create(d, showWarnings = FALSE)
#' f <- file.path(d, "a.txt"); writeLines("x", f)
#' cache <- file.path(d, "cache.tsv")
#' h1 <- photo_hash_cached(f, cache)
#' h2 <- photo_hash_cached(f, cache)      # second call reads the cache
#' identical(h1, h2)
#' unlink(d, recursive = TRUE)
#'
#' @export
photo_hash_cached <- function(path, cache_file) {
  path <- as.character(path)
  if (!length(path)) return(character(0))
  if (is.null(cache_file) || !nzchar(cache_file)) return(photo_hash(path))

  info <- file.info(path)
  size <- as.character(info$size)
  mt   <- format(info$mtime, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  key  <- paste(normalizePath(path, mustWork = FALSE), size, mt, sep = "\t")

  old <- NULL
  if (file.exists(cache_file))
    old <- tryCatch(utils::read.delim(cache_file, sep = "\t", header = TRUE,
                                      quote = "", comment.char = "",
                                      colClasses = "character",
                                      stringsAsFactors = FALSE),
                    error = function(e) NULL)
  out <- rep(NA_character_, length(path))
  if (!is.null(old) && nrow(old) && all(c("key", "hash") %in% names(old))) {
    hit <- match(key, old$key)
    out[!is.na(hit)] <- old$hash[hit[!is.na(hit)]]
  }
  todo <- which(is.na(out) | !nzchar(out))
  if (length(todo)) out[todo] <- photo_hash(path[todo])

  # The cache is rewritten in full, holding ONLY what this batch knows about:
  # it is a cache, and letting it accumulate the fingerprints of every folder
  # ever opened would make it slower to read than the files are to hash.
  ok <- !is.na(out) & nzchar(out)
  if (any(ok)) {
    d <- dirname(cache_file)
    if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
    try(utils::write.table(
      data.frame(key = key[ok], hash = out[ok], stringsAsFactors = FALSE),
      cache_file, sep = "\t", row.names = FALSE, quote = FALSE), silent = TRUE)
  }
  out
}


#' Provenance keys: which photographs came from the same original
#'
#' [reconcile_photo_names()] recognises a row by the file it still names, which
#' is exactly what a rename destroys. For a correction made BEFORE `photo_hash`
#' was recorded -- the whole of any workbook digitized with intraitR 1.30.0 or
#' earlier -- the old name is nowhere and nothing in the table connects the row
#' to any image. No amount of hashing the current folder can recover that link,
#' because the link was never written down there.
#'
#' It was, however, written down by whatever did the renaming. A pipeline that
#' imports photographs under a naming convention records which ORIGINAL image
#' became which specimen, and that record is the missing edge: two specimen
#' codes pointing at the same original are the same fish. This function reads
#' such a journal and returns the map [reconcile_photo_names()] needs.
#'
#' THE KEY IS AN IDENTIFIER, NOT A MEASUREMENT. What matters is only that two
#' codes from one original get the same string and codes from different
#' originals do not; the recorded path of the original does that, costs no file
#' read, and keeps working after the originals have been archived off the
#' machine. It is deliberately NOT a fingerprint of the original: the
#' photographs a digitizing session runs over are usually cropped working
#' copies, which share no fingerprint with the camera files at all, so a
#' fingerprint would have to be matched against something that is not there.
#' Grouping the CODES sidesteps that entirely -- and
#' [reconcile_photo_names()] still checks the pixel dimensions before it moves
#' any coordinates, so a grouping that is right about the fish but wrong about
#' the picture is caught rather than believed.
#'
#' @param dir Directory of import journals: tab-separated, one row per
#'   (record, specimen, field, value), with columns `record_id`, `timestamp`,
#'   `operator`, `app_version`, `action`, `specimen`, `field`, `value` and no
#'   header -- the format written by the FishInTrait campaign journal. Rows with
#'   `action == "import"` and `field == "source_path"` are the ones read. A
#'   directory with nothing of that shape yields an empty map rather than an
#'   error: absent provenance is a normal state, not a failure.
#' @param field Name of the field holding the identifier of the original.
#'   Defaults to `"source_path"`.
#'
#' @return A named character vector, names = specimen (photograph) codes,
#'   values = the key of the original they were imported from, ready to pass as
#'   the `provenance` argument of [reconcile_photo_names()]. A code imported
#'   more than once keeps the original it was LAST built from.
#'
#' @seealso [reconcile_photo_names()], [photo_hash()], [digitize_landmarks()]
#'
#' @examples
#' # Two codes, one original: the determination was corrected and the file
#' # renamed, so the second import is the same fish as the first.
#' d <- file.path(tempdir(), "provenance_demo")
#' dir.create(d, showWarnings = FALSE)
#' writeLines(c(
#'   paste("r1", "2026-07-28T10:07:55Z", "AT", "0.17.0", "import",
#'         "SITE_20260427_SQUCEP_004_AT", "source_path", "/raw/T-26-0011.jpeg",
#'         sep = "\t"),
#'   paste("r2", "2026-07-31T20:03:36Z", "AT", "0.17.0", "import",
#'         "SITE_20260427_BARBAR_025_AT", "source_path", "/raw/T-26-0011.jpeg",
#'         sep = "\t")),
#'   file.path(d, "campaign_AT_1.tsv"))
#' photo_provenance_keys(d)
#' unlink(d, recursive = TRUE)
#'
#' @export
photo_provenance_keys <- function(dir, field = "source_path") {
  out <- stats::setNames(character(0), character(0))
  if (is.null(dir) || !length(dir)) return(out)
  fs <- unlist(lapply(dir, function(d)
    if (is.character(d) && length(d) == 1L && !is.na(d) && dir.exists(d))
      list.files(d, pattern = "\\.tsv$", full.names = TRUE) else character(0)),
    use.names = FALSE)
  if (!length(fs)) return(out)

  parts <- lapply(sort(fs), function(f) {
    d <- tryCatch(utils::read.delim(f, sep = "\t", header = FALSE, quote = "",
                                    comment.char = "", colClasses = "character",
                                    fill = TRUE, stringsAsFactors = FALSE),
                  error = function(e) NULL)
    if (is.null(d) || !nrow(d) || ncol(d) < 8L) return(NULL)
    d <- d[, 1:8, drop = FALSE]
    names(d) <- c("record_id", "timestamp", "operator", "app_version",
                  "action", "specimen", "field", "value")
    d[d$action == "import" & d$field == field, , drop = FALSE]
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  parts <- parts[vapply(parts, nrow, integer(1)) > 0L]
  if (!length(parts)) return(out)

  j <- do.call(rbind, parts)
  # Chronological, then last-wins: a specimen re-imported keeps the original it
  # was LAST built from, which is the one the folder now reflects.
  j <- j[order(j$timestamp), , drop = FALSE]
  src <- stats::setNames(j$value, j$specimen)
  src <- src[!duplicated(names(src), fromLast = TRUE)]
  src[!is.na(src) & nzchar(src)]
}


## Pixel dimensions of an image, from its HEADER -- a few dozen bytes read, not
## the whole file, and no decoding. Enough to say whether two renderings of a
## photograph share a coordinate frame, which is the only question asked of it.
##
## JPEG and PNG only, deliberately: they are what the digitizer deals with, and
## a half-correct TIFF parser that returns a wrong size would be worse than one
## that returns NA. NA means "cannot tell", and the caller refuses to re-key on
## a frame it cannot verify rather than assuming one.
.intraitr_image_size <- function(path) {
  if (!file.exists(path)) return(c(NA_integer_, NA_integer_))
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  sig <- readBin(con, "raw", 8L)
  if (length(sig) < 8L) return(c(NA_integer_, NA_integer_))

  # PNG: the IHDR chunk is always first, width then height, big-endian.
  if (identical(as.integer(sig),
                c(137L, 80L, 78L, 71L, 13L, 10L, 26L, 10L))) {
    readBin(con, "raw", 8L)                       # length + "IHDR"
    d <- readBin(con, "integer", n = 2L, size = 4L, endian = "big")
    if (length(d) < 2L) return(c(NA_integer_, NA_integer_))
    return(as.integer(d))
  }
  # JPEG: walk the markers to the first SOF, which carries height then width.
  if (sig[1] == as.raw(0xFF) && sig[2] == as.raw(0xD8)) {
    seek(con, 2L)
    sof <- as.raw(c(0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                    0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF))
    repeat {
      b <- readBin(con, "raw", 1L)
      if (!length(b)) break
      if (b != as.raw(0xFF)) next                 # resynchronise on the fill
      m <- readBin(con, "raw", 1L)
      if (!length(m)) break
      while (length(m) && m == as.raw(0xFF)) m <- readBin(con, "raw", 1L)
      if (!length(m) || m == as.raw(0xD8) || m == as.raw(0x01) ||
          (m >= as.raw(0xD0) && m <= as.raw(0xD7))) next   # no length field
      if (m == as.raw(0xD9) || m == as.raw(0xDA)) break    # end / scan data
      ln <- readBin(con, "integer", n = 1L, size = 2L, endian = "big",
                    signed = FALSE)
      if (!length(ln) || ln < 2L) break
      if (m %in% sof) {
        readBin(con, "raw", 1L)                   # sample precision
        d <- readBin(con, "integer", n = 2L, size = 2L, endian = "big",
                     signed = FALSE)
        if (length(d) < 2L) break
        return(as.integer(c(d[2], d[1])))         # stored height, width
      }
      seek(con, ln - 2L, origin = "current")
    }
  }
  c(NA_integer_, NA_integer_)
}

#' Match digitized specimens back to renamed photographs
#'
#' Reconciles a landmark table with a folder of photographs on the FINGERPRINT
#' of the image files rather than on their names, and re-keys the rows whose
#' photograph has been renamed since it was digitized. This is what makes a
#' correction of determination -- which renames the file, and therefore the
#' specimen code -- cost a rename and nothing else, instead of stranding the
#' measurements under a name nothing points to any more.
#'
#' Three things happen, in this order. Rows that carry no `photo_hash` (written
#' by a version before the column existed) are back-filled from the file they
#' still name, when it is still there under that name. Rows whose `photo_hash`
#' matches a photograph now called something else are re-keyed: `photo_file`
#' takes the new name and `specimen`/`individual` have their leading photograph
#' code replaced, so the `_i<k>` of a plate and the `_<operator>_rep<N>` of a
#' repeat are carried across untouched. Everything else is left exactly as it
#' was.
#'
#' AMBIGUITY IS NEVER RESOLVED SILENTLY. A fingerprint matching more than one
#' file in the folder (the same photograph copied twice), or a target name that
#' another row already occupies, is reported and left alone: a wrong automatic
#' merge is far more expensive than a rename done by hand, because it is
#' invisible afterwards.
#'
#' @param x A `data.frame` of digitizations in the wide layout written by
#'   [digitize_landmarks()] -- one row per digitization, with at least
#'   `specimen` and `photo_file`. A `photo_hash` column is used when present and
#'   created when it is not.
#' @param photos Character vector of image paths -- the folder the digitizing
#'   session is run over.
#' @param hashes Optional pre-computed fingerprints of `photos`, in the same
#'   order (see [photo_hash()]). Supplying them avoids re-reading every file,
#'   which matters on a batch of several hundred.
#' @param provenance Optional named character vector, names = photograph codes,
#'   values = an arbitrary key identifying the PHYSICAL SPECIMEN behind the
#'   photograph (see [photo_provenance_keys()]). Two codes sharing a key are
#'   the same fish, whatever they are called now.
#'
#'   This is the only route to a rename that happened BEFORE `photo_hash` was
#'   recorded. The fingerprint route needs the old file to still be somewhere;
#'   after such a rename it is nowhere, and nothing in the table connects the
#'   row to any image. Matching is therefore done CODE TO CODE here -- the key
#'   groups the codes, and the one whose file is in `photos` is the target --
#'   which also makes it independent of *which* rendering of the photograph the
#'   session is run over. A digitizer pointed at cropped working copies and a
#'   provenance journal recording the original camera files have no fingerprint
#'   in common, and the grouping does not need one.
#'
#'   Because a key match says the two codes name one fish but nothing about the
#'   pixels, the COORDINATE FRAME is checked before anything is re-keyed: the
#'   row's `img_w`/`img_h` must equal the dimensions of the target image.
#'   Landmarks are recorded in the pixels of a particular rendering, so
#'   carrying them onto a differently cropped or rescaled copy would move every
#'   one of them without changing a single recorded number. A frame that does
#'   not match is reported, never applied.
#'
#' @return A list of two elements: `data`, the table with `photo_hash` filled in
#'   and the renamed rows re-keyed, and `changes`, a `data.frame` with one row
#'   per re-keying (`specimen_old`, `specimen_new`, `photo_file_old`,
#'   `photo_file_new`, `photo_hash`, `status`). `status` is `"renamed"` for a
#'   re-keying that was applied, `"ambiguous"` for a match found and
#'   deliberately not applied (the same image twice, a target code already
#'   taken), and `"frame_changed"` for a provenance match whose target image
#'   has different pixel dimensions from the ones the row was digitized in --
#'   the same fish, but not the same picture, so the coordinates do not
#'   transfer. `changes` has zero rows when the table and the folder already
#'   agree.
#'
#' @seealso [photo_hash()], [digitize_landmarks()], [consolidate_landmarks()]
#'
#' @examples
#' # Two photographs, one of them digitized and then renamed.
#' d <- file.path(tempdir(), "photos_demo")
#' dir.create(d, showWarnings = FALSE)
#' f1 <- file.path(d, "SITE_20260427_BARBAR_025_AT.jpeg")
#' writeLines("pixels of fish one", f1)
#'
#' meas <- data.frame(specimen = "SITE_20260427_SQUCEP_004_AT",
#'                    individual = "SITE_20260427_SQUCEP_004_AT",
#'                    photo_file = "SITE_20260427_SQUCEP_004_AT.jpeg",
#'                    photo_hash = photo_hash(f1),
#'                    stringsAsFactors = FALSE)
#'
#' r <- reconcile_photo_names(meas, f1)
#' r$changes[, c("specimen_old", "specimen_new", "status")]
#' r$data$specimen
#' unlink(d, recursive = TRUE)
#'
#' @export
reconcile_photo_names <- function(x, photos, hashes = NULL,
                                  provenance = NULL) {
  empty <- data.frame(specimen_old = character(0), specimen_new = character(0),
                      photo_file_old = character(0), photo_file_new = character(0),
                      photo_hash = character(0), status = character(0),
                      stringsAsFactors = FALSE)
  if (is.null(x) || !is.data.frame(x) || !nrow(x))
    return(list(data = x, changes = empty))
  if (!all(c("specimen", "photo_file") %in% names(x)))
    stop("`x` must have `specimen` and `photo_file` columns.", call. = FALSE)

  photos <- as.character(photos)
  photos <- photos[!is.na(photos) & nzchar(photos)]
  if (!length(photos)) return(list(data = x, changes = empty))
  if (is.null(hashes)) hashes <- photo_hash(photos)
  hashes <- as.character(hashes)
  if (length(hashes) != length(photos))
    stop("`hashes` must have one element per element of `photos`.", call. = FALSE)

  files <- basename(photos)
  codes <- tools::file_path_sans_ext(files)

  if (is.null(x[["photo_hash"]])) x[["photo_hash"]] <- NA_character_
  x[["photo_hash"]] <- as.character(x[["photo_hash"]])
  x[["specimen"]]   <- as.character(x[["specimen"]])
  x[["photo_file"]] <- as.character(x[["photo_file"]])

  ## 1. BACK-FILL. A row written before the column existed still names a file;
  ##    when that file is in the folder under that name, its fingerprint is the
  ##    row's. This is the only place a name is trusted -- and it is trusted for
  ##    exactly one purpose: to record what the row can be recognised by from
  ##    now on.
  need <- which(is.na(x[["photo_hash"]]) | !nzchar(x[["photo_hash"]]))
  if (length(need)) {
    hit <- match(x[["photo_file"]][need], files)
    # `i` is filtered down to the rows that matched: `v[integer(0)] <- ...` is
    # fine, but the nested form would not be, and an explicit index reads.
    fillable <- need[!is.na(hit)]
    if (length(fillable))
      x[["photo_hash"]][fillable] <- hashes[hit[!is.na(hit)]]
  }
  ## 1b. THE RETROACTIVE CASE, matched CODE TO CODE.
  ##
  ##     The back-fill above recognises a row by the file it still names, which
  ##     is exactly what a rename destroys: for a correction made BEFORE the
  ##     fingerprint was recorded, the old name is nowhere and nothing in the
  ##     table connects the row to any image. No fingerprint can be computed for
  ##     it -- not from the folder, not from anywhere.
  ##
  ##     What CAN be recovered is that two codes name one fish, from whatever
  ##     recorded the rename. So the provenance key groups the codes and the
  ##     member whose file is in `photos` is the target. Grouping by code rather
  ##     than by fingerprint also makes this independent of which RENDERING the
  ##     session is run over: a digitizer pointed at cropped working copies and
  ##     an import journal recording the original camera files share no
  ##     fingerprint at all, and the grouping does not need one.
  ##
  ##     Keyed on the PHOTOGRAPH -- `photo_file` without its extension -- not on
  ##     `specimen`, so a plate's `_i2` and a repeat's `_AT_rep3` look up the
  ##     photograph they belong to rather than failing to be found.
  prov_target <- rep(NA_integer_, nrow(x))
  if (length(provenance) && !is.null(names(provenance))) {
    pv <- as.character(provenance); names(pv) <- names(provenance)
    pv <- pv[!is.na(pv) & nzchar(pv)]
    key_of_file <- pv[codes]                 # provenance key of each photograph
    row_code <- tools::file_path_sans_ext(x[["photo_file"]])
    key_of_row <- pv[row_code]
    for (i in seq_len(nrow(x))) {
      if (x[["photo_file"]][i] %in% files) next        # nothing was renamed
      k <- unname(key_of_row[i])
      if (is.na(k)) next
      cand <- which(!is.na(key_of_file) & key_of_file == k)
      # Exactly one candidate, or the group says nothing about which file this
      # row belongs to. Silence is the right answer to an ambiguous group.
      if (length(cand) == 1L) prov_target[i] <- cand
    }
  }

  ## 2. WHICH FINGERPRINTS CAN BE TRUSTED TO NAME ONE FILE. A photograph
  ##    present twice under two names says nothing about which of the two a row
  ##    belongs to, so it is excluded from the automatic path and reported.
  dup_hash <- unique(hashes[duplicated(hashes) & !is.na(hashes)])

  # Dimensions are read at most once per target file, and only for the rows the
  # provenance route reaches: on a batch where nothing was renamed this costs
  # nothing at all.
  # `names %in%` and NOT `is.null(dim_cache[[key]])`: on a LIST, `[[` with an
  # absent name is an error ("subscript out of bounds"), not NULL -- the
  # asymmetry with data.frames, where it does return NULL, is exactly the trap.
  # Written the other way this threw on its first call, and the caller's
  # tryCatch turned the throw into "nothing to reconcile", silently.
  dim_cache <- list()
  size_of <- function(k) {
    key <- as.character(k)
    if (!key %in% names(dim_cache))
      dim_cache[[key]] <<- .intraitr_image_size(photos[k])
    dim_cache[[key]]
  }

  changes <- empty
  drop_rows <- integer(0)
  for (i in seq_len(nrow(x))) {
    h <- x[["photo_hash"]][i]
    old_file <- x[["photo_file"]][i]
    by_provenance <- FALSE

    ## THE PICTURE CHANGED UNDER THE MEASUREMENTS.
    ##
    ## The row still names a file that is still there -- so nothing above
    ## notices -- but the bytes are not the ones it was digitized on. A crop
    ## redone to include a ruler that had been cut off is the ordinary way this
    ## happens, and it is silent: every landmark keeps its recorded number
    ## while the pixel those numbers point at moves. The specimen then sits in
    ## the "correct" queue looking finished, with a configuration that belongs
    ## to an image no longer on disk.
    ##
    ## Reported, never repaired: a crop cannot be undone from the coordinates,
    ## so the only honest outcome is that the specimen is measured again.
    if (!is.na(h) && nzchar(h) && old_file %in% files) {
      j <- match(old_file, files)
      if (!is.na(hashes[j]) && !identical(hashes[j], h)) {
        changes <- rbind(changes, data.frame(
          specimen_old = x[["specimen"]][i], specimen_new = NA_character_,
          photo_file_old = old_file, photo_file_new = old_file,
          photo_hash = hashes[j], status = "image_changed",
          stringsAsFactors = FALSE))
        next
      }
    }

    if (!is.na(h) && nzchar(h)) {
      k <- which(hashes == h)
    } else k <- integer(0)

    if (!length(k) && !is.na(prov_target[i])) {
      # No fingerprint to go on: this is the retroactive case, resolved from
      # provenance. The two codes name one fish -- but that says nothing about
      # the pixels, so the coordinate frame is checked before anything moves.
      k <- prov_target[i]
      by_provenance <- TRUE
      sz <- size_of(k)
      w <- suppressWarnings(as.numeric(x[["img_w"]][i]))
      hgt <- suppressWarnings(as.numeric(x[["img_h"]][i]))
      frame_ok <- all(is.finite(sz)) && is.finite(w) && is.finite(hgt) &&
        sz[1] == w && sz[2] == hgt
      if (!frame_ok) {
        # Same fish, not the same picture. Landmarks live in the pixels of one
        # rendering; carrying them onto another would move every point without
        # changing a single recorded number.
        changes <- rbind(changes, data.frame(
          specimen_old = x[["specimen"]][i], specimen_new = NA_character_,
          photo_file_old = old_file, photo_file_new = files[k],
          photo_hash = NA_character_, status = "frame_changed",
          stringsAsFactors = FALSE))
        next
      }
    }
    if (!length(k)) next                        # photograph not in this folder

    if (!by_provenance && (length(k) > 1L || h %in% dup_hash)) {
      # Ambiguous ONLY when it would actually change something: a row already
      # sitting on one of the copies is left in peace and reported as nothing.
      if (!(old_file %in% files[k]))
        changes <- rbind(changes, data.frame(
          specimen_old = x[["specimen"]][i], specimen_new = NA_character_,
          photo_file_old = old_file,
          photo_file_new = paste(files[k], collapse = " | "),
          photo_hash = h, status = "ambiguous", stringsAsFactors = FALSE))
      next
    }
    new_file <- files[k]
    if (identical(old_file, new_file)) next     # nothing was renamed

    ## 3. RE-KEY. The specimen code is the photograph code plus whatever the
    ##    protocol appended to it -- `_i2` for the second fish of a plate,
    ##    `_AT_rep3` for a repeat. Replacing only the LEADING photograph code
    ##    carries those suffixes across untouched, which a rebuild of the code
    ##    from scratch would lose.
    old_code <- tools::file_path_sans_ext(old_file)
    new_code <- codes[k]
    rekey <- function(v) {
      if (is.na(v) || !nzchar(v) || !nzchar(old_code)) return(v)
      if (!startsWith(v, old_code)) return(v)
      paste0(new_code, substring(v, nchar(old_code) + 1L))
    }
    spec_new <- rekey(x[["specimen"]][i])
    # The fingerprint of the file this row is now known to belong to. On the
    # provenance route the row had none -- recording it here is what makes the
    # NEXT reconciliation a plain fingerprint match, with no provenance journal
    # needed and no dependence on which rendering the session runs over.
    new_hash <- hashes[k]

    # A target another row already occupies is a collision, not a rename: two
    # digitizations would silently become one row keyed the same way.
    clash <- !identical(spec_new, x[["specimen"]][i]) &&
      spec_new %in% x[["specimen"]][-i]
    if (clash || identical(spec_new, x[["specimen"]][i])) {
      # ... UNLESS the two rows hold the same coordinates to the last decimal.
      # Then this is not two digitizations of one fish, it is ONE digitization
      # present twice: the row was re-keyed on an earlier run and the old key
      # came back from the append-only journal. Reporting that as an ambiguity
      # for the operator to arbitrate, at every launch, for ever, is noise
      # dressed as caution -- there is nothing to arbitrate between two copies
      # of the same numbers. It is marked `"superseded"` and dropped, which
      # loses no measurement: the surviving row IS it.
      twin <- match(spec_new, x[["specimen"]])
      same <- FALSE
      if (clash && !is.na(twin)) {
        cc <- grep("^[0-9]+_[XY]$", names(x), value = TRUE)
        if (length(cc)) {
          a <- unlist(x[i, cc]); b <- unlist(x[twin, cc])
          same <- all((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b))
        }
      }
      changes <- rbind(changes, data.frame(
        specimen_old = x[["specimen"]][i], specimen_new = spec_new,
        photo_file_old = old_file, photo_file_new = new_file,
        photo_hash = new_hash,
        status = if (same) "superseded" else "ambiguous",
        stringsAsFactors = FALSE))
      if (same) drop_rows <- c(drop_rows, i)
      next
    }
    changes <- rbind(changes, data.frame(
      specimen_old = x[["specimen"]][i], specimen_new = spec_new,
      photo_file_old = old_file, photo_file_new = new_file,
      photo_hash = new_hash, status = "renamed", stringsAsFactors = FALSE))
    x[["specimen"]][i] <- spec_new
    if (!is.null(x[["individual"]]))
      x[["individual"]][i] <- rekey(as.character(x[["individual"]][i]))
    x[["photo_file"]][i] <- new_file
    x[["photo_hash"]][i] <- new_hash
  }
  # Dropped LAST, so the indices used throughout the loop stay valid.
  if (length(drop_rows)) x <- x[-drop_rows, , drop = FALSE]
  rownames(x) <- NULL
  rownames(changes) <- NULL
  list(data = x, changes = changes)
}
