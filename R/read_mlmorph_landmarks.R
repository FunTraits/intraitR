#' Import predicted landmarks from an ml-morph / landmarking-app measure table
#'
#' Converts a "long" (tidy) table of landmark coordinates -- as produced by
#' the **ml-morph** shape predictor or by the interactive landmarking Shiny
#' app, both of which export the same schema (one row per
#' specimen/landmark, columns `specimen`, `landmark`, `X`, `Y` and an
#' optional per-image scale `mm_per_px`) -- straight into an
#' `"intrait_landmarks"` object, ready for [fishmorph_segments()],
#' [fishmorph_ratios()], [trait_space()], [itv_index()],
#' [plot_fishmorph_points()], and the rest of the intraitR pipeline.
#'
#' This is a thin, reusable wrapper around [read_landmarks_csv()] that adds
#' the two things those exports carry which a bare coordinate reshape does
#' not: the per-specimen calibration scale (`mm_per_px`, together with a
#' `has_scalebar` flag flagging individuals whose calibration mire -- the
#' FISHMORPH scale-bar landmarks 20-21 -- was absent, so that
#' `mm_per_px = NA`), and an optional join to a specimen-level metadata table
#' (species, stage, site, ...). Individuals without a scale keep `NA`
#' coordinates where landmarks were not placed and an `NA` scale; convert
#' pixel distances to length units downstream with the `scale_cm` argument of
#' [fishmorph_segments()], and impute what is missing with
#' [impute_landmarks()] if a complete configuration is required.
#'
#' @param file Character path to the measure table (a CSV as written by the
#'   predictor or the landmarking app), or a `data.frame` already loaded in
#'   R.
#' @param specimen,landmark Character, the columns identifying specimens and
#'   landmarks. Default `"specimen"` and `"landmark"`.
#' @param coords Character vector of the coordinate columns, in order.
#'   Defaults to `c("X", "Y")`.
#' @param scale_col Character or `NULL`, the column holding the per-image
#'   calibration scale (millimetres per pixel). When present, one value per
#'   specimen is carried into `metadata$mm_per_px` and a logical
#'   `metadata$has_scalebar` flags specimens that had a usable scale. Set to
#'   `NULL` to ignore any such column. Defaults to `"mm_per_px"`.
#' @param metadata Optional specimen-level metadata: a `data.frame` (or a CSV
#'   path) with one row per individual, joined onto the imported specimens by
#'   `by`. Typically an identifications table carrying `species` and other
#'   descriptors.
#' @param by Character, the column of `metadata` whose values match the
#'   `specimen` ids (e.g. a `"code"` column). `NULL` (default) auto-detects
#'   the first of `specimen`, `"code"`, `"individual"` or `"id"` present in
#'   `metadata`.
#' @param operator Character scalar recorded in `metadata$operator` to
#'   identify the source of the digitization (the predictor, an app session,
#'   an operator name). Treating a set of predicted landmarks as one
#'   "operator" mirrors [load_t26_saudrune_landmarks()] and makes it easy to
#'   compare predicted against hand-digitized trait spaces. Defaults to
#'   `"ml_morph"`.
#' @param replicate Integer scalar recorded in `metadata$replicate` (one
#'   digitization per individual by default). Defaults to `1L`.
#' @param save_to Optional character path; when supplied, the resulting
#'   object is also written there with [saveRDS()] (a convenience for the
#'   common "predict, convert, cache" workflow). Defaults to `NULL` (return
#'   only, the standard behaviour of the package's `read_*()` importers).
#' @param ... Additional arguments passed to [utils::read.csv()] when `file`
#'   (or `metadata`) is a path.
#'
#' @return An object of class `"intrait_landmarks"` (a `p x k x n`
#'   coordinate array plus a `metadata` data.frame), in the same format as
#'   [simulate_fishmorph_points()] and [load_t26_saudrune_landmarks()]. The
#'   `metadata` always carries `specimen`, `individual`, `species`,
#'   `population`, `replicate` and `operator` columns (the intraitR
#'   convention; `species`/`population` are `NA` when not supplied via
#'   `metadata`), any extra columns joined from `metadata`, and -- when
#'   `scale_col` is present -- `mm_per_px` and `has_scalebar`.
#'
#' @seealso [read_landmarks_csv()], [read_tps()],
#'   [load_t26_saudrune_landmarks()], [fishmorph_segments()],
#'   [impute_landmarks()]
#'
#' @examples
#' # A minimal ml-morph / app-style export (long format, with a scale):
#' mes <- data.frame(
#'   specimen  = rep(c("fish_01", "fish_02"), each = 3),
#'   landmark  = rep(1:3, times = 2),
#'   X = c(10, 15, 20, 11, 16, 21),
#'   Y = c(20, 25, 20, 21, 26, 21),
#'   mm_per_px = c(0.22, 0.22, 0.22, NA, NA, NA)  # fish_02 lacks a scale bar
#' )
#' lm <- read_mlmorph_landmarks(mes)
#' dim(lm$coords)
#' lm$metadata[c("specimen", "operator", "mm_per_px", "has_scalebar")]
#'
#' # Joining a species table by an identifications `code`:
#' ident <- data.frame(code = c("fish_01", "fish_02"),
#'                      species = c("Gobio occitaniae", "Squalius cephalus"))
#' lm2 <- read_mlmorph_landmarks(mes, metadata = ident, by = "code")
#' table(lm2$metadata$species, useNA = "ifany")
#'
#' @export
read_mlmorph_landmarks <- function(file, specimen = "specimen",
                                   landmark = "landmark", coords = c("X", "Y"),
                                   scale_col = "mm_per_px", metadata = NULL,
                                   by = NULL, operator = "ml_morph",
                                   replicate = 1L, save_to = NULL, ...) {
  df <- if (is.data.frame(file)) file else utils::read.csv(file, stringsAsFactors = FALSE, ...)

  required_cols <- c(specimen, landmark, coords)
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing column(s) in the measure table: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  df[[specimen]] <- as.character(df[[specimen]])
  specimen_names <- sort(unique(df[[specimen]]))

  message(sprintf(
    "Measure table: %d individual(s) x %d landmark(s) (%d rows).",
    length(specimen_names), length(unique(df[[landmark]])), nrow(df)
  ))

  # -- Per-specimen calibration scale (mm per pixel), one value per
  #    individual, and a flag for individuals whose scale bar was absent. ----
  mm_per_px <- NULL
  has_scalebar <- NULL
  if (!is.null(scale_col) && scale_col %in% names(df)) {
    per_spec <- tapply(
      df[[scale_col]], df[[specimen]],
      function(v) {
        v <- v[is.finite(v)]
        if (length(v) > 0) v[1] else NA_real_
      }
    )
    mm_per_px <- as.numeric(per_spec[specimen_names])
    has_scalebar <- is.finite(mm_per_px)
    n_noscale <- sum(!has_scalebar)
    if (n_noscale > 0) {
      warning(
        n_noscale, " individual(s) without a calibration scale (",
        scale_col, " all NA); their measurements cannot be converted to ",
        "length units and will stay NA. Affected: ",
        paste(utils::head(specimen_names[!has_scalebar], 5), collapse = ", "),
        if (n_noscale > 5) ", ..." else "", call. = FALSE
      )
    }
  }

  # -- Assemble specimen-level metadata in the intraitR convention. ---------
  meta <- data.frame(
    specimen   = specimen_names,
    individual = specimen_names,
    species    = NA_character_,
    population = NA_character_,
    replicate  = as.integer(replicate),
    operator   = as.character(operator),
    stringsAsFactors = FALSE
  )

  if (!is.null(metadata)) {
    md <- if (is.data.frame(metadata)) metadata
    else utils::read.csv(metadata, stringsAsFactors = FALSE, ...)
    if (!is.data.frame(md)) stop("`metadata` must be a data.frame or a CSV path.", call. = FALSE)

    key <- by
    if (is.null(key)) {
      key <- intersect(c(specimen, "code", "individual", "id"), names(md))
      key <- if (length(key) > 0) key[1] else NA_character_
    }
    if (is.na(key) || !key %in% names(md)) {
      stop("Could not find a key column in `metadata` to join by; ",
           "set `by` to the column matching the `specimen` ids.", call. = FALSE)
    }

    idx <- match(specimen_names, as.character(md[[key]]))
    n_absent <- sum(is.na(idx))
    if (n_absent > 0) {
      warning(
        n_absent, " individual(s) have no matching row in `metadata` (joined by \"",
        key, "\") and keep NA descriptors: ",
        paste(utils::head(specimen_names[is.na(idx)], 5), collapse = ", "),
        if (n_absent > 5) ", ..." else "", call. = FALSE
      )
    }
    # Carry every metadata column except the join key; overwrite the standard
    # placeholders (species, population, ...) when the table supplies them.
    for (col in setdiff(names(md), key)) {
      meta[[col]] <- md[[col]][idx]
    }
  }

  if (!is.null(mm_per_px)) {
    meta$mm_per_px <- mm_per_px
    meta$has_scalebar <- has_scalebar
  }
  # Keep the five standard columns first, in the canonical order.
  std <- c("specimen", "individual", "species", "population", "replicate")
  meta <- meta[c(std, setdiff(names(meta), std))]
  rownames(meta) <- meta$specimen

  lm <- read_landmarks_csv(
    df[c(specimen, landmark, coords)],
    specimen = specimen, landmark = landmark, coords = coords, metadata = meta
  )

  if (!is.null(save_to)) {
    saveRDS(lm, save_to)
    message(sprintf("Saved intrait_landmarks object to %s.",
                    normalizePath(save_to, mustWork = FALSE)))
  }
  lm
}
