#' Import landmark coordinates from a tpsDig (`.tps`) file
#'
#' Reads a `tpsDig`/`tpsUtil`-formatted `.tps` file containing two-dimensional
#' landmark coordinates for a set of specimens, and returns them as a
#' geomorph-style array, optionally merged with specimen-level metadata
#' (species, population, standard length, etc.) and together with the
#' digitization scale (units per pixel) when present in the file.
#'
#' @param file Character. Path to a `.tps` file.
#' @param specID Character, one of `"imageID"` (default), `"ID"`, or
#'   `"None"`. Controls how specimen identifiers are built: from the
#'   `IMAGE=` field, from the `ID=` field, or as sequential
#'   `specimen_1, specimen_2, ...` labels.
#' @param metadata Optional `data.frame` of specimen-level metadata. Row
#'   names, or a column named `specimen`, must match the specimen
#'   identifiers described by `specID`.
#' @param negNA Logical, defaults to `FALSE`. If `TRUE`, negative
#'   coordinates (commonly used to flag missing landmarks in `tpsDig`) are
#'   converted to `NA`.
#'
#' @return An object of class `"intrait_landmarks"`, a list with elements:
#'   \describe{
#'     \item{coords}{a `p x k x n` numeric array of raw (un-aligned)
#'       landmark coordinates, `p` landmarks by `k` (2) dimensions by `n`
#'       specimens, following the \pkg{geomorph} array convention.}
#'     \item{scale}{a named numeric vector of scale factors (real-world
#'       units per pixel), one per specimen, taken from the `SCALE=` field
#'       of the TPS file (`NA` where absent).}
#'     \item{metadata}{the merged specimen metadata `data.frame`, or `NULL`
#'       if `metadata` was not supplied.}
#'   }
#'
#' @details
#' TPS files are the de facto exchange format for digitized landmark data in
#' geometric morphometrics (Rohlf, 2015). All specimens in the file must
#' share the same number of landmarks (`LM=`); `read_tps()` throws an
#' informative error otherwise, since a common landmark configuration is
#' required for any downstream Procrustes analysis. Three-dimensional
#' (`LM3=`) TPS files are not currently supported; use
#' [read_landmarks_csv()] for 3D data.
#'
#' @references
#' Rohlf FJ (2015). The tps series of software. Hystrix, 26(1), 9-12.
#'
#' @seealso [read_landmarks_csv()], [gpa_fish()], [simulate_fish_landmarks()]
#'
#' @examples
#' tps_path <- tempfile(fileext = ".tps")
#' writeLines(c(
#'   "LM=3", "10.0 20.0", "15.0 25.0", "20.0 20.0",
#'   "IMAGE=fish_01.jpg", "ID=1", "SCALE=0.05",
#'   "LM=3", "11.0 21.0", "16.0 26.0", "21.0 21.0",
#'   "IMAGE=fish_02.jpg", "ID=2", "SCALE=0.05"
#' ), tps_path)
#' lm <- read_tps(tps_path)
#' dim(lm$coords)
#' lm$scale
#'
#' @export
read_tps <- function(file, specID = c("imageID", "ID", "None"),
                      metadata = NULL, negNA = FALSE) {
  specID <- match.arg(specID)
  if (!file.exists(file)) stop("File not found: ", file, call. = FALSE)

  raw_lines <- readLines(file, warn = FALSE)
  raw_lines <- trimws(raw_lines)
  raw_lines <- raw_lines[nzchar(raw_lines)]

  lm_idx <- grep("^LM=", raw_lines, ignore.case = TRUE)
  if (length(lm_idx) == 0) {
    stop(
      "No 'LM=' block found in '", file, "'. Is this a 2D tpsDig file? ",
      "3D files (LM3=) are not supported by read_tps(); ",
      "use read_landmarks_csv() instead.",
      call. = FALSE
    )
  }
  n_spec <- length(lm_idx)

  coords_list <- vector("list", n_spec)
  ids <- character(n_spec)
  images <- character(n_spec)
  scale_vec <- rep(NA_real_, n_spec)
  n_landmarks <- integer(n_spec)

  for (i in seq_len(n_spec)) {
    start <- lm_idx[i]
    p_i <- suppressWarnings(as.integer(sub("^LM=", "", raw_lines[start], ignore.case = TRUE)))
    if (is.na(p_i) || p_i <= 0) {
      stop("Could not parse a valid landmark count on line ", start, " of '", file, "'.", call. = FALSE)
    }
    n_landmarks[i] <- p_i

    coord_lines <- raw_lines[(start + 1):(start + p_i)]
    mat <- do.call(rbind, lapply(strsplit(coord_lines, "[ \t,]+"), as.numeric))
    if (nrow(mat) != p_i || ncol(mat) != 2) {
      stop("Malformed coordinate block for specimen ", i, " in '", file, "'.", call. = FALSE)
    }
    if (negNA) mat[mat < 0] <- NA
    coords_list[[i]] <- mat

    block_end <- if (i < n_spec) lm_idx[i + 1] - 1 else length(raw_lines)
    block <- raw_lines[(start + p_i + 1):block_end]

    id_line <- grep("^ID=", block, ignore.case = TRUE, value = TRUE)
    image_line <- grep("^IMAGE=", block, ignore.case = TRUE, value = TRUE)
    scale_line <- grep("^SCALE=", block, ignore.case = TRUE, value = TRUE)

    ids[i] <- if (length(id_line) > 0) sub("^ID=", "", id_line[1], ignore.case = TRUE) else NA_character_
    images[i] <- if (length(image_line) > 0) sub("^IMAGE=", "", image_line[1], ignore.case = TRUE) else NA_character_
    scale_vec[i] <- if (length(scale_line) > 0) {
      suppressWarnings(as.numeric(sub("^SCALE=", "", scale_line[1], ignore.case = TRUE)))
    } else {
      NA_real_
    }
  }

  if (length(unique(n_landmarks)) > 1) {
    stop(
      "Specimens in '", file, "' do not share the same number of landmarks (",
      paste(unique(n_landmarks), collapse = ", "),
      "); a common landmark configuration is required for Procrustes analysis.",
      call. = FALSE
    )
  }
  p <- n_landmarks[1]

  specimen_names <- switch(specID,
    imageID = ifelse(!is.na(images) & nzchar(images), images, paste0("specimen_", seq_len(n_spec))),
    ID      = ifelse(!is.na(ids) & nzchar(ids), ids, paste0("specimen_", seq_len(n_spec))),
    None    = paste0("specimen_", seq_len(n_spec))
  )
  if (anyDuplicated(specimen_names) > 0) {
    warning("Duplicated specimen identifiers found; appending numeric suffixes.", call. = FALSE)
    specimen_names <- make.unique(specimen_names)
  }

  A <- array(
    NA_real_,
    dim = c(p, 2, n_spec),
    dimnames = list(NULL, c("X", "Y"), specimen_names)
  )
  for (i in seq_len(n_spec)) A[, , i] <- coords_list[[i]]

  names(scale_vec) <- specimen_names

  meta <- if (!is.null(metadata)) .merge_metadata(metadata, specimen_names) else NULL

  structure(
    list(coords = A, scale = scale_vec, metadata = meta),
    class = "intrait_landmarks"
  )
}

#' Print an `"intrait_landmarks"` object
#'
#' @param x An object of class `"intrait_landmarks"`, as returned by
#'   [read_tps()], [read_landmarks_csv()], [simulate_fish_landmarks()],
#'   [simulate_fishmorph_points()], or [load_t26_saudrune_landmarks()].
#' @param ... Currently unused.
#' @return Invisibly returns `x`.
#' @export
print.intrait_landmarks <- function(x, ...) {
  d <- dim(x$coords)
  cat("<intrait_landmarks>\n")
  cat(sprintf("  %d specimens, %d landmarks, %d dimensions\n", d[3], d[1], d[2]))
  if (!is.null(x$scale) && any(!is.na(x$scale))) {
    cat(sprintf("  Scale available for %d/%d specimens\n", sum(!is.na(x$scale)), d[3]))
  }
  if (!is.null(x$metadata)) {
    cat("  Metadata columns:", paste(names(x$metadata), collapse = ", "), "\n")
  }
  if (!is.null(x$removed_specimens)) {
    cat(sprintf(
      "  %d specimen(s) excluded via exclude_specimens() (see $removed_specimens): %s\n",
      nrow(x$removed_specimens), paste(x$removed_specimens$specimen, collapse = ", ")
    ))
  }
  invisible(x)
}
