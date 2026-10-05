#' Import landmark coordinates from a generic "wide"-format Excel sheet
#'
#' Reads landmark coordinates stored in a "wide" spreadsheet layout, one row
#' per specimen (or per replicate digitization) with one pair of X/Y columns
#' per landmark (e.g. `X_1, Y_1, X_2, Y_2, ...`, or `1_X, 1_Y, 2_X, 2_Y, ...`),
#' and reshapes them into a geomorph-style `p x k x n` array. This is the
#' layout produced directly by most manual digitization spreadsheets (one
#' column per landmark coordinate, filled in by hand or copy-pasted from
#' image analysis software), as opposed to the "long" (tidy) layout expected
#' by [read_landmarks_csv()]. An optional second spreadsheet of specimen-level
#' identifications/metadata (e.g. taxonomic identification, capture date) can
#' be joined in directly via `species_file`.
#'
#' @param file Character. Path to an `.xlsx`/`.xls` file.
#' @param sheet Sheet to read: a name or 1-based index, passed to
#'   [readxl::read_excel()]. Defaults to the first sheet.
#' @param n_landmarks Integer, the number of landmarks digitized per
#'   specimen (i.e. the number of X/Y column pairs to look for).
#' @param x_pattern,y_pattern Character, a template for the X/Y column names
#'   of landmark `i`, with `"{i}"` as a placeholder for the landmark number.
#'   Defaults to `"X_{i}"`/`"Y_{i}"` (e.g. `X_1, X_2, ..., Y_1, Y_2, ...`,
#'   the layout of a single-digitization sheet); use `"{i}_X"`/`"{i}_Y"` for
#'   a sheet organised the other way round (e.g. `1_X, 1_Y, 2_X, 2_Y, ...`,
#'   as is common in replicate-digitization/repeatability sheets).
#' @param id_cols Character vector of one or more column names that
#'   together identify each row (e.g. a specimen code, and, if the sheet
#'   records more than one digitization per specimen, an operator or
#'   replicate/measurement column). Kept as-is in `metadata`. Rows with a
#'   missing value in `id_cols[1]` (typically a blank spreadsheet row) are
#'   dropped with a message.
#' @param specimen `NULL` (default), or a single existing column name to use
#'   directly as the specimen identifier. When `NULL`, specimen identifiers
#'   are built by pasting together every column in `id_cols` with `"_"`
#'   (e.g. `code_operator`, or `code_replicate`), which is almost always
#'   the desired behaviour when a sheet records more than one digitization
#'   per specimen (each row must resolve to a unique identifier). Duplicated
#'   identifiers are made unique (with a warning) via [make.unique()].
#' @param species_file,species_sheet Optional path (and sheet, as `sheet`
#'   above) to a second spreadsheet of one-row-per-specimen metadata (e.g.
#'   species identification) to left-join onto the landmark data.
#' @param species_by Character, the column name shared by `file` and
#'   `species_file` to join on. Defaults to `id_cols[1]` (typically the
#'   specimen code column). Every column of `species_file` other than
#'   `species_by` is added to `metadata` as-is (no renaming, no attempt to
#'   resolve conflicting/uncertain identifications -- see Details).
#' @param metadata Optional further `data.frame` of specimen-level
#'   metadata, merged in on top of `id_cols`/`species_file`, as in
#'   [read_tps()].
#' @param ... Additional arguments passed to [readxl::read_excel()] (e.g.
#'   `skip`, `na`, `col_types`).
#'
#' @return An object of class `"intrait_landmarks"` (see [read_tps()] for
#'   details); `scale` is set to `NULL` since a wide landmark sheet does not,
#'   by itself, carry a digitization scale (see [fishmorph_segments()]'s
#'   `scale_cm` argument if landmarks 20-21 encode a calibration segment, as
#'   in the FISHMORPH scheme).
#'
#' @details
#' This function generalises the private, one-off cleaning script originally
#' written to import the real T-26 Saudrune field data (`Code`/`Utilisateur`
#' columns, `X_1..X_21`/`Y_1..Y_21`; see `data-raw/t26_saudrune_prepare.R`
#' and [load_t26_saudrune_landmarks()]) so that the same "wide spreadsheet"
#' import can be reused directly on new field seasons or other surveys,
#' without hand-written reshaping code, whatever the specific column-naming
#' convention (`x_pattern`/`y_pattern`) or number of landmarks
#' (`n_landmarks`) involved.
#'
#' Coordinate cells are coerced with [as.numeric()]; spreadsheet cells that
#' are blank or contain the literal text `"NA"` become `NA` silently (the
#' normal, expected case for genuinely missing digitizations), while any
#' other non-numeric cell content triggers a warning naming the offending
#' column(s), since that usually indicates a data-entry problem (a stray
#' comment, a mistyped value) rather than an intentionally missing landmark.
#'
#' `species_file` performs a plain left-join (via [match()], so `file`'s row
#' order and length are always preserved even if `species_file` has
#' duplicated or missing keys) and does **not** attempt to reproduce any
#' project-specific identification-resolution logic (e.g. falling back from
#' a preliminary/AI-assisted call to a curated one, or flagging uncertain
#' identifications) -- if your identification sheet needs that kind of
#' resolution before use, do it in R first (e.g. with [dplyr::coalesce()]
#' or a custom `data.frame` you then pass to `species_file`/`metadata`), or
#' inspect the FISHMORPH T-26 case study in `data-raw/t26_saudrune_prepare.R`
#' for a worked, non-generic example of exactly that kind of resolution.
#' Likewise, `species_by` values are matched exactly (after [trimws()]):
#' inconsistent codes across the two files (extra whitespace, a stray
#' `"_"` vs `"-"`, a parenthetical annotation) will not be matched, and
#' should be normalised in `file`/`species_file` beforehand if needed.
#'
#' @seealso [read_landmarks_csv()], [read_tps()], [gpa_fish()],
#'   [load_t26_saudrune_landmarks()]
#'
#' @examples
#' if (requireNamespace("readxl", quietly = TRUE) &&
#'     requireNamespace("writexl", quietly = TRUE)) {
#'   wide <- data.frame(
#'     Code = c("fish_01", "fish_02", "fish_03"),
#'     Utilisateur = c("Op1", "Op1", "Op2"),
#'     X_1 = c(10, 11, 9), Y_1 = c(20, 21, 19),
#'     X_2 = c(15, 16, 14), Y_2 = c(25, 26, 24),
#'     X_3 = c(20, 21, 19), Y_3 = c(20, 21, 19)
#'   )
#'   ident <- data.frame(
#'     Code = c("fish_01", "fish_02", "fish_03"),
#'     species = c("Gobio occitaniae", "Gobio occitaniae", "Squalius cephalus")
#'   )
#'   xlsx_path <- tempfile(fileext = ".xlsx")
#'   ident_path <- tempfile(fileext = ".xlsx")
#'   writexl::write_xlsx(wide, xlsx_path)
#'   writexl::write_xlsx(ident, ident_path)
#'
#'   lm <- read_landmarks_xlsx(
#'     xlsx_path, n_landmarks = 3, id_cols = c("Code", "Utilisateur"),
#'     species_file = ident_path, species_by = "Code"
#'   )
#'   dim(lm$coords)
#'   lm$metadata
#' }
#'
#' @export
read_landmarks_xlsx <- function(file, sheet = 1, n_landmarks,
                                 x_pattern = "X_{i}", y_pattern = "Y_{i}",
                                 id_cols = "Code", specimen = NULL,
                                 species_file = NULL, species_sheet = 1,
                                 species_by = NULL, metadata = NULL, ...) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop(
      "read_landmarks_xlsx() requires the \"readxl\" package. ",
      "Install it with install.packages(\"readxl\").",
      call. = FALSE
    )
  }
  if (!is.numeric(n_landmarks) || length(n_landmarks) != 1 || n_landmarks < 1) {
    stop("`n_landmarks` must be a single positive integer.", call. = FALSE)
  }
  n_landmarks <- as.integer(n_landmarks)
  if (!grepl("{i}", x_pattern, fixed = TRUE) || !grepl("{i}", y_pattern, fixed = TRUE)) {
    stop("`x_pattern`/`y_pattern` must contain the placeholder \"{i}\".", call. = FALSE)
  }

  df <- as.data.frame(readxl::read_excel(file, sheet = sheet, ...), stringsAsFactors = FALSE)

  xcols <- vapply(seq_len(n_landmarks), function(i) gsub("{i}", i, x_pattern, fixed = TRUE), character(1))
  ycols <- vapply(seq_len(n_landmarks), function(i) gsub("{i}", i, y_pattern, fixed = TRUE), character(1))

  missing_cols <- setdiff(c(id_cols, xcols, ycols), names(df))
  if (length(missing_cols) > 0) {
    stop(
      "Column(s) not found in sheet ", if (is.character(sheet)) sprintf("\"%s\"", sheet) else sheet,
      " of '", file, "': ", paste(missing_cols, collapse = ", "),
      ". Check `id_cols`, `n_landmarks`, and `x_pattern`/`y_pattern` against ",
      "the sheet's actual column names.",
      call. = FALSE
    )
  }

  n_before <- nrow(df)
  df <- df[!is.na(df[[id_cols[1]]]), , drop = FALSE]
  if (n_before - nrow(df) > 0) {
    message(sprintf(
      "Dropped %d blank row(s) (missing `%s`).", n_before - nrow(df), id_cols[1]
    ))
  }
  if (nrow(df) == 0) {
    stop("No usable rows left after dropping blank rows.", call. = FALSE)
  }

  specimen_names <- if (is.null(specimen)) {
    # unname(): apply() over a data.frame-derived matrix inherits that
    # matrix's rownames (the default "1", "2", ... row labels of `df`) as
    # the *names* of its result vector; since specimen identifiers are the
    # *values* here, not a names attribute, that stray names attribute is
    # dropped so dimnames(A)[[3]] is a plain, unnamed character vector.
    unname(apply(df[id_cols], 1, function(r) paste(trimws(as.character(r)), collapse = "_")))
  } else {
    if (!specimen %in% names(df)) {
      stop("`specimen` column '", specimen, "' not found in the sheet.", call. = FALSE)
    }
    trimws(as.character(df[[specimen]]))
  }
  if (anyDuplicated(specimen_names) > 0) {
    warning(
      "Duplicated specimen identifiers found; appending numeric suffixes. ",
      "Add more columns to `id_cols` (or supply `specimen` explicitly) if ",
      "each row should already be unique.",
      call. = FALSE
    )
    specimen_names <- make.unique(specimen_names)
  }

  .coerce_numeric_matrix <- function(sub_df, cols) {
    mat <- matrix(NA_real_, nrow = nrow(sub_df), ncol = length(cols))
    n_bad <- 0L
    bad_cols <- character(0)
    for (j in seq_along(cols)) {
      raw <- sub_df[[cols[j]]]
      chr <- trimws(as.character(raw))
      expected_na <- is.na(raw) | chr == "" | toupper(chr) == "NA"
      num <- suppressWarnings(as.numeric(chr))
      unexpected <- is.na(num) & !expected_na
      if (any(unexpected)) {
        n_bad <- n_bad + sum(unexpected)
        bad_cols <- union(bad_cols, cols[j])
      }
      mat[, j] <- num
    }
    list(mat = mat, n_bad = n_bad, bad_cols = bad_cols)
  }

  x_res <- .coerce_numeric_matrix(df, xcols)
  y_res <- .coerce_numeric_matrix(df, ycols)
  n_bad_total <- x_res$n_bad + y_res$n_bad
  if (n_bad_total > 0) {
    warning(
      n_bad_total, " coordinate cell(s) could not be parsed as numeric and ",
      "were set to NA, in column(s): ",
      paste(union(x_res$bad_cols, y_res$bad_cols), collapse = ", "),
      call. = FALSE
    )
  }

  n <- nrow(df)
  A <- array(
    NA_real_, dim = c(n_landmarks, 2, n),
    dimnames = list(NULL, c("X", "Y"), specimen_names)
  )
  A[, 1, ] <- t(x_res$mat)
  A[, 2, ] <- t(y_res$mat)

  meta <- df[id_cols]
  rownames(meta) <- specimen_names

  if (!is.null(species_file)) {
    by_col <- if (is.null(species_by)) id_cols[1] else species_by
    if (!by_col %in% names(meta)) {
      stop("`species_by` ('", by_col, "') is not one of `id_cols`.", call. = FALSE)
    }
    sp_df <- as.data.frame(readxl::read_excel(species_file, sheet = species_sheet), stringsAsFactors = FALSE)
    if (!by_col %in% names(sp_df)) {
      stop(
        "`species_by` column '", by_col, "' not found in `species_file` ",
        "('", species_file, "').",
        call. = FALSE
      )
    }
    if (anyDuplicated(sp_df[[by_col]]) > 0) {
      warning(
        "`species_file` has duplicated '", by_col, "' values; keeping the ",
        "first occurrence of each.",
        call. = FALSE
      )
      sp_df <- sp_df[!duplicated(sp_df[[by_col]]), , drop = FALSE]
    }
    key_meta <- trimws(as.character(meta[[by_col]]))
    key_sp <- trimws(as.character(sp_df[[by_col]]))
    idx <- match(key_meta, key_sp)
    n_unmatched <- sum(is.na(idx))
    if (n_unmatched > 0) {
      warning(
        n_unmatched, " specimen(s) have no match in `species_file` on '",
        by_col, "' and will have NA metadata from that file (check for ",
        "inconsistent formatting, e.g. spacing or separators, between the ",
        "two spreadsheets' key column).",
        call. = FALSE
      )
    }
    extra_cols <- setdiff(names(sp_df), by_col)
    extra <- sp_df[idx, extra_cols, drop = FALSE]
    rownames(extra) <- rownames(meta)
    meta <- cbind(meta, extra)
  }

  if (!is.null(metadata)) meta <- cbind(meta, .merge_metadata(metadata, specimen_names))

  structure(
    list(coords = A, scale = NULL, metadata = meta),
    class = "intrait_landmarks"
  )
}
