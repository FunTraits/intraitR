# =============================================================================
# digitizer_fishmorph.R -- the FISHMORPH reference workbook as a target of the
# landmark digitizer (digitize_fishmorph_reference()).
#
# Merge of the two digitizers, step 3 (intraitR 1.42.0). The application is the
# one of digitize_landmarks(); what changes for this target is where the
# specimens come from (the species rows of FISHMORPH_PUBLI_*.xlsx, and a folder
# of new photographs), how a species is seeded (its MEASURED segments rather
# than the median proportions) and where a record is written (the landmark and
# new-specimen sheets of the working copy, edited in place). The helpers of the
# first section are moved VERBATIM from Rfishmorph R/digitizer-app.R (0.17),
# where they will be removed.
# =============================================================================

# species name proposed from the photograph file name:
# "Abramis_brama_2.JPG" -> "Abramis brama" (genus capitalised, epithet lower)
.fm_name_from_file <- function(path) {
  x <- tools::file_path_sans_ext(basename(path))
  x <- sub("\\s*\\d+$", "", x)
  x <- gsub("_(profile|dessin|dessous|dessus|photo)$", "", x, ignore.case = TRUE)
  x <- trimws(gsub("[^A-Za-z]+", " ", x))
  w <- strsplit(x, "\\s+")[[1]]
  w <- w[nzchar(w)]
  if (!length(w)) return("")
  w <- tolower(w)
  w[1] <- paste0(toupper(substr(w[1], 1, 1)), substring(w[1], 2))
  paste(w, collapse = " ")
}

# --- robust indexing of the photographs --------------------------------------
# maps a normalised species name -> file path
.fm_photo_index <- function(photo_dir) {
  files <- list.files(photo_dir, pattern = "\\.(jpg|jpeg|png|JPG|JPEG|PNG)$",
                      full.names = TRUE)
  norm <- function(x) {
    x <- tools::file_path_sans_ext(basename(x))
    x <- sub("\\s*\\d+$", "", x)                       # a trailing " 1", " 2"
    x <- gsub("_(profile|dessin|dessous|dessus|photo)$", "", x, ignore.case = TRUE)
    x <- gsub("[^A-Za-z]+", "_", x)                    # tout separateur -> _
    tolower(gsub("^_|_$", "", x))
  }
  keys <- vapply(files, norm, character(1))
  idx <- files[!duplicated(keys)]
  names(idx) <- keys[!duplicated(keys)]
  idx
}

# --- writing a photograph back to disk ---------------------------------------
# Used by the "bake the flip into the file" button. Three precautions, none of
# them optional:
#
#   * The ORIGINAL is copied aside first, ONCE. A digitizing session is allowed
#     to change how a photograph is stored, not to destroy the only copy of it;
#     and the backup is written only if it does not already exist, so a second
#     flip cannot overwrite the pristine file with an already-flipped one.
#   * The write goes to a temporary file IN THE SAME DIRECTORY and is renamed
#     over the target. A rename within one filesystem is atomic: an interrupted
#     write leaves the old photograph intact rather than a truncated one.
#     tempdir() would not do -- it is often another device, where rename falls
#     back on a copy and the atomicity is lost.
#   * The output format follows the REAL bytes of the original, not its
#     extension. In this collection about 7 % of the ".jpg" files are in fact
#     PNG, GIF or BMP (see read_img()), and re-encoding one of them as JPEG
#     because of its name would add lossy compression to a lossless file.
.fm_write_img <- function(a, path, quality = 0.97) {
  sig <- tryCatch(readBin(path, "raw", n = 2L), error = function(e) raw(0))
  is_jpeg <- length(sig) >= 2 && sig[1] == as.raw(0xFF) && sig[2] == as.raw(0xD8)
  a[!is.finite(a)] <- 0
  a[] <- pmin(pmax(a, 0), 1)
  # JPEG has no alpha channel: an RGBA array would be refused outright.
  if (is_jpeg && length(dim(a)) == 3L && dim(a)[3] == 4L)
    a <- a[, , seq_len(3), drop = FALSE]

  bak_dir <- file.path(dirname(path), "_originaux")
  bak <- file.path(bak_dir, basename(path))
  if (!file.exists(bak)) {
    dir.create(bak_dir, showWarnings = FALSE, recursive = TRUE)
    file.copy(path, bak, overwrite = FALSE)
  }

  tmp <- paste0(path, ".tmp")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  if (is_jpeg) {
    if (!requireNamespace("jpeg", quietly = TRUE))
      stop("Writing a JPEG needs the 'jpeg' package.", call. = FALSE)
    jpeg::writeJPEG(a, tmp, quality = quality)
  } else {
    if (!requireNamespace("png", quietly = TRUE))
      stop("Writing a PNG needs the 'png' package.", call. = FALSE)
    png::writePNG(a, tmp)
  }
  if (!file.rename(tmp, path))
    stop("Could not replace ", path, call. = FALSE)
  list(path = path, backup = bak, jpeg = is_jpeg)
}

.fm_species_key <- function(genus_species) {
  x <- gsub("[^A-Za-z]+", "_", genus_species)          # "Genus.species" -> genus_species
  tolower(gsub("^_|_$", "", x))
}

# --- intake of a new photograph ----------------------------------------------
# Crop, rotate and flip are applied to the raw ARRAY and baked into the file
# BEFORE the photograph enters the queue. That order is not a convenience: the
# digitizer records coordinates in the pixels OF THE FILE, so re-framing a
# picture that already carries landmarks would silently invalidate every one of
# them. The intake page is the only place where the geometry of the image may
# still change, and it is upstream of the first click by construction.

# rotation by a multiple of 90 degrees, counter-clockwise on screen. Written on
# the array rather than delegated to magick: a quarter turn is a transposition
# and a row reversal, exact and lossless, where a re-encode through an external
# library would resample the picture for nothing.
.fm_rot90 <- function(a, k = 1L) {
  k <- as.integer(k) %% 4L
  if (is.na(k) || !k) return(a)
  rot1 <- function(x) {
    d <- dim(x)
    if (length(d) == 3L) {
      out <- array(x[1], dim = c(d[2], d[1], d[3]))
      for (ch in seq_len(d[3])) out[, , ch] <- t(x[, , ch])[d[2]:1, , drop = FALSE]
      out
    } else t(x)[d[2]:1, , drop = FALSE]
  }
  for (i in seq_len(k)) a <- rot1(a)
  a
}

# mirror: "h" left/right, "v" top/bottom, "hv" both.
.fm_mirror <- function(a, mode = "h") {
  d <- dim(a); H <- d[1]; W <- d[2]
  if (length(d) == 3L) {
    if (grepl("h", mode)) a <- a[, W:1, , drop = FALSE]
    if (grepl("v", mode)) a <- a[H:1, , , drop = FALSE]
  } else {
    if (grepl("h", mode)) a <- a[, W:1, drop = FALSE]
    if (grepl("v", mode)) a <- a[H:1, , drop = FALSE]
  }
  a
}

# crop to a rectangle given in DISPLAY pixels (x to the right, y downwards from
# the top-left corner), the frame the brush of the preview returns. The
# rectangle is clamped to the picture and refused below 8 px a side: a stray
# click must not turn a specimen into a two-pixel smear.
.fm_crop <- function(a, x0, x1, y0, y1, min_px = 8L) {
  d <- dim(a); H <- d[1]; W <- d[2]
  cx <- sort(c(x0, x1)); cy <- sort(c(y0, y1))
  c0 <- max(1L, floor(cx[1]) + 1L); c1 <- min(W, ceiling(cx[2]))
  r0 <- max(1L, floor(cy[1]) + 1L); r1 <- min(H, ceiling(cy[2]))
  if (!is.finite(c0) || !is.finite(c1) || !is.finite(r0) || !is.finite(r1) ||
      c1 - c0 + 1L < min_px || r1 - r0 + 1L < min_px) return(NULL)
  if (length(d) == 3L) a[r0:r1, c0:c1, , drop = FALSE] else a[r0:r1, c0:c1, drop = FALSE]
}

# TRUE when the file really is a PNG, whatever its extension says (about 7 % of
# the ".jpg" of this collection are not JPEG -- see read_img()).
.fm_is_png_file <- function(path) {
  sig <- tryCatch(readBin(path, "raw", n = 8L), error = function(e) raw(0))
  length(sig) >= 8L &&
    all(sig[1:8] == as.raw(c(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)))
}

# writes an array to a NEW file, the format taken from the target extension and
# the write made atomic by a rename inside the same directory (see
# .fm_write_img for why tempdir() would not do). No backup here: the target
# does not exist yet -- .fm_new_photo_path() guarantees it.
.fm_write_img_as <- function(a, path, quality = 0.97) {
  a[!is.finite(a)] <- 0
  a[] <- pmin(pmax(a, 0), 1)
  is_png <- grepl("\\.png$", path, ignore.case = TRUE)
  if (!is_png && length(dim(a)) == 3L && dim(a)[3] == 4L)
    a <- a[, , seq_len(3), drop = FALSE]           # JPEG carries no alpha channel
  tmp <- paste0(path, ".tmp")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  if (is_png) {
    if (!requireNamespace("png", quietly = TRUE))
      stop("Writing a PNG needs the 'png' package.", call. = FALSE)
    png::writePNG(a, tmp)
  } else {
    if (!requireNamespace("jpeg", quietly = TRUE))
      stop("Writing a JPEG needs the 'jpeg' package.", call. = FALSE)
    jpeg::writeJPEG(a, tmp, quality = quality)
  }
  if (!file.rename(tmp, path))
    stop("Could not write ", path, call. = FALSE)
  path
}

# file name of a new photograph: "Genus_species.<ext>", suffixed 2, 3... when
# the folder already holds that species. The suffix is a SPECIMEN counter, not
# a duplicate marker -- the "new" queue is one entry per PHOTOGRAPH, several
# specimens of one species are legitimate, and both .fm_name_from_file() and
# .fm_photo_index() strip a trailing number, so all of them read back to the
# same binomial. The name is the only identity a raw image has, which is why it
# is normalised here rather than left to whatever the camera produced.
.fm_new_photo_path <- function(dir, genus_species, ext = "jpg") {
  base <- gsub("[^A-Za-z]+", "_", trimws(genus_species))
  base <- gsub("^_+|_+$", "", base)
  if (!nzchar(base)) return(NA_character_)
  ext <- sub("^\\.", "", tolower(ext))
  cand <- file.path(dir, paste0(base, ".", ext))
  k <- 1L
  while (file.exists(cand) && k < 999L) {
    k <- k + 1L
    cand <- file.path(dir, paste0(base, "_", k, ".", ext))
  }
  cand
}

# a binomial, checked on its FORM alone: two words, genus capitalised, epithet
# in lower case. Returns the normalised name, or NA with the reason attached.
# FishBase is a separate, optional and non-blocking step: a name absent from
# FishBase may still be a specimen worth digitizing, whereas "abramis  Brama"
# is a typing accident in every case.
.fm_check_binomial <- function(x) {
  x <- trimws(gsub("[_.]+", " ", as.character(x %||% "")))
  x <- gsub("\\s+", " ", x)
  w <- strsplit(x, " ")[[1]]
  w <- w[nzchar(w)]
  if (length(w) < 2L)
    return(list(ok = FALSE, name = x,
                msg = "Two words are needed: Genus species."))
  if (length(w) > 3L)
    return(list(ok = FALSE, name = x,
                msg = "Too many words for a binomial (three at most, sp. included)."))
  if (grepl("[^A-Za-z]", paste(w, collapse = "")))
    return(list(ok = FALSE, name = x,
                msg = "Letters only (no digit, no accent, no hyphen)."))
  w[1] <- paste0(toupper(substr(w[1], 1, 1)), tolower(substring(w[1], 2)))
  w[-1] <- tolower(w[-1])
  list(ok = TRUE, name = paste(w, collapse = " "), msg = "")
}

# =============================================================================
# The FISHMORPH reference workbook as a digitizer target
# =============================================================================

# Segment -> seed ratio. The seeding geometry (seed_configuration(), in
# digitizer_core.R) places every landmark at a proportion of the body length;
# by default the MEDIAN FISHMORPH proportions. For a species of the reference
# workbook the proportions are MEASURED -- its eleven segments -- and the seed
# then sits on the published measurements, which is what the "reconstruct"
# queue of the old Rfishmorph digitizer did with its own placement function.
# The height segments are taken from their *2 columns (Eh2, Mo2, PFi2): the
# raw Eh/Mo/PFi of this workbook are not distances between landmark pairs.
# A ratio that is missing or not positive falls back on the median, and is
# reported in attr(, "fallback").
.FM_SEG_FOR_RATIO <- c(Bd = "Bd", Hd = "Hd", Eh = "Eh2", Mo = "Mo2",
                       PFi = "PFi2", PFl = "PFl", Ed = "Ed", Jl = "Jl",
                       CPd = "CPd", CFd = "CFd")
.fm_seed_ratios <- function(seg) {
  num <- function(nm) suppressWarnings(as.numeric(seg[[nm]] %||% NA))
  bl <- num("Bl")
  out <- FM_MEDIAN_RATIOS
  fb <- character(0)
  for (r in names(.FM_SEG_FOR_RATIO)) {
    v <- num(.FM_SEG_FOR_RATIO[[r]]) / bl
    if (length(v) == 1L && is.finite(v) && v > 0) out[[r]] <- v else fb <- c(fb, r)
  }
  if (!is.finite(bl) || bl <= 0) fb <- names(.FM_SEG_FOR_RATIO)
  attr(out, "fallback") <- fb
  out
}

# Atomic write of an openxlsx Workbook (same principle as write_xlsx_atomic():
# temporary file in the SAME directory, then rename; the previous generation is
# kept as "<name>.prev.xlsx"). The FISHMORPH workbook is written through
# openxlsx because it is EDITED in place -- its other sheets and columns must
# survive -- where the campaign workbook is regenerated in full.
.fm_save_workbook_atomic <- function(wb, path, keep_prev = TRUE) {
  if (!requireNamespace("openxlsx", quietly = TRUE))
    stop("Package \"openxlsx\" is required.", call. = FALSE)
  tmp <- file.path(dirname(path),
                   sprintf(".%s.tmp%d", basename(path), Sys.getpid()))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)
  if (!file.exists(tmp)) stop("Temporary write failed: ", tmp, call. = FALSE)
  prev <- sub("(\\.xlsx)?$", ".prev.xlsx", path)
  had  <- file.exists(path)
  if (had) {
    if (file.exists(prev)) unlink(prev)
    if (!file.rename(path, prev))
      stop("Could not move the old workbook aside (open in Excel?): ", path,
           call. = FALSE)
  }
  if (!file.rename(tmp, path)) {
    if (had) file.rename(prev, path)
    stop("Final rename failed: ", path, call. = FALSE)
  }
  if (had && !keep_prev) unlink(prev)
  invisible(TRUE)
}

# Points written to the landmark sheet: the 19 landmarks, the axis point 22,
# the derived head-base point 23 and the two extra hinges. The "new" sheet adds
# the scale bar 20-21 (a new photograph carries its ruler; the published
# photographs do not).
.FM_SAVE_PTS     <- c(1:19, 22L, 23L, 24L, 25L)
.FM_SAVE_PTS_NEW <- c(1:19, 20L, 21L, 22L, 23L, 24L, 25L)
.FM_ENTRY_COLS   <- c("quality_score", "reviewed", "reviewed_by", "review_date",
                      "collapse_rules")

# Open the FISHMORPH workbook as a store. Reads the segment sheet, the landmark
# sheet and the new-specimen sheet of the WORKING COPY (created from `xlsx_path`
# when absent), builds the three queues, and returns a list of closures sharing
# that state: the app never touches openxlsx itself. Ported from the launcher
# of Rfishmorph::launch_fishmorph_digitizer() (0.17), behaviour unchanged:
#   reconstruct : species WITHOUT landmarks, WITH segments and a photograph
#   correct     : rows ALREADY landmarked, with a photograph -- of the landmark
#                 sheet AND of the new-specimen sheet (a species added since
#                 the publication is corrected like any other)
#   new         : every image of `new_photo_dir`, one entry per PHOTOGRAPH
# Row keys (journal `row_key`) are those of the old digitizer, so the history
# of a species continues across the two tools: the species name for the first
# two queues, the photograph file name for "new".
.fm_store_open <- function(xlsx_path, out_path = NULL, photo_dir, new_photo_dir,
                           seg_sheet = "Global_segments",
                           lm_sheet = "Global_Landmark",
                           new_sheet = "new_specimens") {
  if (!requireNamespace("openxlsx", quietly = TRUE))
    stop("Package \"openxlsx\" is required by digitize_fishmorph_reference().",
         call. = FALSE)
  if (is.null(out_path))
    out_path <- if (grepl("_reconstructed\\.xlsx$", xlsx_path)) xlsx_path
                else sub("\\.xlsx$", "_reconstructed.xlsx", xlsx_path)
  if (!file.exists(out_path)) file.copy(xlsx_path, out_path)

  # read.xlsx may rename the columns that start with a digit ("1_X" ->
  # "X1_X"), so the raw header row is read on its own and the full column range
  # forced (otherwise empty trailing columns -- 22_X, rarely filled -- vanish
  # and every name after them shifts).
  read_sheet <- function(sheet) {
    hdr <- as.character(openxlsx::read.xlsx(out_path, sheet = sheet,
                                            colNames = FALSE, rows = 1))
    ok <- !is.na(hdr) & nzchar(hdr)
    hdr <- if (any(ok)) hdr[seq_len(max(which(ok)))] else character(0)
    df <- openxlsx::read.xlsx(out_path, sheet = sheet, colNames = FALSE,
                              startRow = 2, cols = seq_along(hdr))
    if (is.null(df) || !nrow(df))
      df <- as.data.frame(matrix(NA, nrow = 0, ncol = length(hdr)))
    else if (ncol(df) < length(hdr))
      df[, (ncol(df) + 1):length(hdr)] <- NA
    names(df) <- hdr
    list(df = df, hdr = hdr)
  }
  s1 <- read_sheet(seg_sheet); seg_df <- s1$df
  s2 <- read_sheet(lm_sheet);  lm_df  <- s2$df; lm_hdr <- s2$hdr
  wb <- openxlsx::loadWorkbook(out_path)

  ensure_cols <- function(sheet, hdr, need) {
    miss <- need[!need %in% hdr]
    if (!length(miss)) return(hdr)
    for (j in seq_along(miss))
      openxlsx::writeData(wb, sheet, miss[j], startCol = length(hdr) + j,
                          startRow = 1, colNames = FALSE)
    .fm_save_workbook_atomic(wb, out_path)
    message("Columns added to '", sheet, "': ", paste(miss, collapse = ", "))
    c(hdr, miss)
  }
  hinge_cols <- c("24_X", "24_Y", "25_X", "25_Y")
  new_lm_hdr <- ensure_cols(lm_sheet, lm_hdr, c(hinge_cols, .FM_ENTRY_COLS))
  for (cc in setdiff(new_lm_hdr, lm_hdr))
    lm_df[[cc]] <- if (cc %in% .FM_ENTRY_COLS) rep(NA_character_, nrow(lm_df))
                   else rep(NA_real_, nrow(lm_df))
  lm_hdr <- new_lm_hdr

  new_exists <- new_sheet %in% openxlsx::getSheetNames(out_path)
  if (!new_exists) openxlsx::addWorksheet(wb, new_sheet)
  hdr0 <- if (new_exists) {
    h <- suppressWarnings(as.character(openxlsx::read.xlsx(
      out_path, sheet = new_sheet, colNames = FALSE, rows = 1)))
    h[!is.na(h) & nzchar(h)]
  } else character(0)
  if (!length(hdr0))
    openxlsx::writeData(wb, new_sheet, t(as.matrix(lm_hdr)), colNames = FALSE)
  if (!new_exists || !length(hdr0)) .fm_save_workbook_atomic(wb, out_path)
  ns <- read_sheet(new_sheet)
  new_hdr <- ns$hdr; new_df <- ns$df
  need_new <- c("Genus.species",
                as.vector(rbind(paste0(.FM_SAVE_PTS_NEW, "_X"),
                                paste0(.FM_SAVE_PTS_NEW, "_Y"))),
                "photo_file", "ruler_mm", "mm_per_px", "IUCN", .FM_ENTRY_COLS)
  new_hdr2 <- ensure_cols(new_sheet, new_hdr, need_new)
  for (cc in setdiff(new_hdr2, new_hdr)) new_df[[cc]] <- rep(NA, nrow(new_df))
  new_hdr <- new_hdr2
  if (ncol(new_df)) new_df[] <- lapply(new_df, as.character)

  photos <- .fm_photo_index(photo_dir)
  seg_df$.key <- .fm_species_key(seg_df$Genus.species)
  lm_df$.key  <- .fm_species_key(lm_df$Genus.species)
  lm_df$.sheet <- rep(lm_sheet, nrow(lm_df))
  lm_df$.srow  <- seq_len(nrow(lm_df))
  lm_df$.photo_file <- rep(NA_character_, nrow(lm_df))

  # rows of the new-specimen sheet already carrying their points join the
  # "correct" queue (unless the species is already on the landmark sheet)
  if (nrow(new_df)) {
    anchor <- suppressWarnings(as.numeric(new_df[["1_X"]]))
    cand <- which(!is.na(anchor))
    if (length(cand)) {
      like <- function(target, v)
        if (is.numeric(target)) suppressWarnings(as.numeric(v))
        else if (is.logical(target)) as.logical(v) else as.character(v)
      add <- as.data.frame(lapply(lm_df, function(cc) rep(cc[NA_integer_], length(cand))),
                           stringsAsFactors = FALSE)
      names(add) <- names(lm_df)
      for (nm in intersect(names(lm_df), names(new_df)))
        add[[nm]] <- like(lm_df[[nm]], new_df[[nm]][cand])
      add$.sheet <- rep(new_sheet, length(cand))
      add$.srow  <- cand
      add$.key   <- .fm_species_key(add$Genus.species)
      add$.photo_file <- if ("photo_file" %in% names(new_df))
        trimws(as.character(new_df$photo_file[cand])) else NA_character_
      seen <- (add$.key %in% lm_df$.key) | is.na(add$.key)
      add <- add[!seen, , drop = FALSE]
      if (nrow(add)) lm_df <- rbind(lm_df, add)
    }
  }

  seg_cols <- c("Bl", "Bd", "Hd", "Eh2", "Mo2", "PFi2", "PFl", "Ed", "Jl", "CPd", "CFd")
  has_seg <- !is.na(suppressWarnings(as.numeric(seg_df$Bl)))
  xcols <- paste0(c(1:19, 22L, 23L), "_X")
  xcols <- intersect(xcols, names(lm_df))
  lm_missing <- apply(lm_df[, xcols, drop = FALSE], 1, function(r) all(is.na(r)))

  photo_of_file <- function(f) {
    if (is.na(f) || !nzchar(f)) return(NA_character_)
    for (d in c(photo_dir, new_photo_dir)) {
      p <- file.path(d, f)
      if (file.exists(p)) return(p)
    }
    NA_character_
  }
  lm_photo <- unname(photos[lm_df$.key])
  for (i in which(!is.na(lm_df$.photo_file))) {
    p <- photo_of_file(lm_df$.photo_file[i])
    if (!is.na(p)) lm_photo[i] <- p
  }
  lm_df$.photo <- lm_photo
  has_photo <- !is.na(lm_df$.photo)

  seg_by_key <- seg_df[has_seg, , drop = FALSE]
  seg_by_key <- seg_by_key[!duplicated(seg_by_key$.key), , drop = FALSE]
  rownames(seg_by_key) <- seg_by_key$.key

  # alphabetical order of the species, in the C locale (same on every machine):
  # the order of the queue is the order of the work, and congeners come together
  alpha <- function(rows) rows[order(lm_df$Genus.species[rows], method = "radix")]
  q_recon <- alpha(which(lm_missing & lm_df$.key %in% rownames(seg_by_key) & has_photo))
  q_corr  <- alpha(which(!lm_missing & has_photo & !is.na(lm_df$.key)))
  list_new <- function()
    if (dir.exists(new_photo_dir))
      sort(list.files(new_photo_dir, full.names = TRUE, ignore.case = TRUE,
                      pattern = "\\.(jpe?g|png|gif|bmp|tiff?)$"))
    else character(0)
  new_photos <- list_new()

  pending <- 0L
  col_of_sheet <- function(sh, nm)
    if (identical(sh, lm_sheet)) match(nm, lm_hdr) else match(nm, new_hdr)
  new_row_of <- function(f) {
    if (length(f) != 1L || is.na(f) || !nrow(new_df) ||
        !"photo_file" %in% names(new_df)) return(NA_integer_)
    h <- which(!is.na(new_df$photo_file) & new_df$photo_file == f)
    if (length(h)) h[1] else NA_integer_
  }
  queue <- function(mode) switch(mode, reconstruct = q_recon, correct = q_corr,
                                 new = seq_along(new_photos), integer(0))

  entry <- function(mode, k) {
    q <- queue(mode)
    if (!length(q) || k < 1L || k > length(q)) return(NULL)
    if (identical(mode, "new")) {
      f <- new_photos[q[k]]
      r <- new_row_of(basename(f))
      sp <- if (!is.na(r) && "Genus.species" %in% names(new_df))
              as.character(new_df[r, "Genus.species"]) else NA_character_
      if (is.na(sp) || !nzchar(sp)) sp <- .fm_name_from_file(f)
      return(list(key = basename(f), species = sp, label = basename(f),
                  photo = f, sheet = new_sheet, row = r, df = "new"))
    }
    r <- q[k]
    sp <- as.character(lm_df$Genus.species[r])
    list(key = sp, species = sp, label = sp, photo = lm_df$.photo[r],
         sheet = lm_df$.sheet[r], row = r, df = "lm")
  }
  labels <- function(mode) {
    q <- queue(mode)
    if (identical(mode, "new")) basename(new_photos[q])
    else as.character(lm_df$Genus.species[q])
  }

  # what is already recorded for an entry: coordinates (25 x 2), the points to
  # treat as non-measurable (anatomical points left empty on a landmarked row),
  # and the entry-level fields. NULL when nothing is recorded yet.
  seed <- function(mode, k) {
    e <- entry(mode, k); if (is.null(e)) return(NULL)
    df <- if (identical(e$df, "new")) new_df else lm_df
    r <- e$row
    if (length(r) != 1L || is.na(r) || r > nrow(df)) return(NULL)
    getxy <- function(pt) {
      xc <- paste0(pt, "_X"); yc <- paste0(pt, "_Y")
      if (!all(c(xc, yc) %in% names(df))) return(c(NA_real_, NA_real_))
      c(suppressWarnings(as.numeric(df[r, xc])), suppressWarnings(as.numeric(df[r, yc])))
    }
    if (!all(is.finite(getxy(1L)))) return(NULL)
    P <- matrix(NA_real_, 25L, 2L, dimnames = list(1:25, c("X", "Y")))
    for (pt in 1:25) { xy <- getxy(pt); if (all(is.finite(xy))) P[pt, ] <- xy }
    na <- (3:19)[!vapply(3:19, function(p) all(is.finite(P[p, ])), logical(1))]
    val <- function(col) if (col %in% names(df)) df[r, col] else NA
    list(P = P, na = na,
         quality_score = suppressWarnings(as.numeric(val("quality_score"))),
         reviewed = tolower(trimws(as.character(val("reviewed")))) %in%
           c("true", "vrai", "1", "yes", "oui", "y", "x", "ok"),
         collapse_rules = as.character(val("collapse_rules")),
         ruler_mm = suppressWarnings(as.numeric(val("ruler_mm"))))
  }

  # measured proportions of the species of an entry (NULL: none -> medians)
  ratios <- function(mode, k) {
    e <- entry(mode, k)
    if (is.null(e) || identical(e$df, "new")) return(NULL)
    key <- lm_df$.key[e$row]
    if (is.na(key) || !key %in% rownames(seg_by_key)) return(NULL)
    .fm_seed_ratios(as.list(seg_by_key[key, seg_cols]))
  }

  # write one entry. `meta`: quality_score, reviewed (logical), reviewed_by,
  # review_date, collapse_rules, ruler_mm, mm_per_px, species (new only).
  # Returns the points that could not be written (missing columns).
  save <- function(mode, k, P, meta) {
    e <- entry(mode, k); if (is.null(e)) stop("No entry ", k, " in queue '", mode, "'.")
    dropped <- integer(0)
    if (identical(e$df, "new")) {
      r <- new_row_of(e$key)
      if (is.na(r)) {
        r <- nrow(new_df) + 1L
        blank <- as.data.frame(matrix(NA_character_, nrow = 1, ncol = ncol(new_df)),
                               stringsAsFactors = FALSE)
        names(blank) <- names(new_df)
        new_df <<- rbind(new_df, blank)
      }
      wr <- function(col, v) {
        j <- match(col, new_hdr); if (is.na(j)) return(invisible())
        openxlsx::writeData(wb, new_sheet, v, startCol = j, startRow = r + 1L,
                            colNames = FALSE)
        new_df[r, col] <<- as.character(v)
      }
      wr("Genus.species", meta$species)
      wr("photo_file", e$key)
      pts <- .FM_SAVE_PTS_NEW
    } else {
      sh <- e$sheet; rr <- e$row; srow <- lm_df$.srow[rr]
      wr <- function(col, v) {
        j <- col_of_sheet(sh, col); if (is.na(j)) return(invisible())
        openxlsx::writeData(wb, sh, v, startCol = j, startRow = srow + 1L,
                            colNames = FALSE)
        if (col %in% names(lm_df)) lm_df[rr, col] <<- v
      }
      pts <- .FM_SAVE_PTS
    }
    for (p in pts) {
      if (is.na(match(paste0(p, "_X"), if (identical(e$df, "new")) new_hdr
                      else if (identical(e$sheet, lm_sheet)) lm_hdr else new_hdr))) {
        if (all(is.finite(P[p, ]))) dropped <- c(dropped, p)
        next
      }
      wr(paste0(p, "_X"), if (all(is.finite(P[p, ]))) round(P[p, 1], 3) else NA)
      wr(paste0(p, "_Y"), if (all(is.finite(P[p, ]))) round(P[p, 2], 3) else NA)
    }
    if (identical(e$df, "new")) {
      wr("ruler_mm", if (is.finite(meta$ruler_mm %||% NA)) meta$ruler_mm else NA)
      wr("mm_per_px", if (is.finite(meta$mm_per_px %||% NA)) round(meta$mm_per_px, 6) else NA)
    }
    wr("quality_score", if (is.finite(meta$quality_score %||% NA)) meta$quality_score else NA)
    wr("reviewed", isTRUE(meta$reviewed))
    wr("reviewed_by", meta$reviewed_by %||% NA)
    wr("review_date", meta$review_date %||% NA)
    wr("collapse_rules", meta$collapse_rules %||% "")
    pending <<- pending + 1L
    invisible(dropped)
  }

  flush <- function(force = FALSE, every = 10L) {
    if (pending == 0L) return(invisible(TRUE))
    if (!force && pending < every) return(invisible(TRUE))
    .fm_save_workbook_atomic(wb, out_path)
    pending <<- 0L
    invisible(TRUE)
  }
  refresh_new <- function() { new_photos <<- list_new(); invisible(new_photos) }

  list(out_path = out_path, lm_sheet = lm_sheet, new_sheet = new_sheet,
       new_photo_dir = new_photo_dir, photo_dir = photo_dir,
       n = function(mode) length(queue(mode)), entry = entry, labels = labels,
       seed = seed, ratios = ratios, save = save, flush = flush,
       pending = function() pending, refresh_new = refresh_new,
       counts = function() c(reconstruct = length(q_recon),
                             correct = length(q_corr), new = length(new_photos)))
}
