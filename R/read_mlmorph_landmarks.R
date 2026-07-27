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
#'   `"ml_morph"`. The special value `"parse"` instead reads the operator
#'   off each specimen identifier (see Details).
#' @param replicate Integer scalar recorded in `metadata$replicate` (one
#'   digitization per individual by default). Defaults to `1L`. The special
#'   value `"parse"` instead reads the replicate number off each specimen
#'   identifier (see Details), which is what a table produced by the repeat
#'   mode of [digitize_landmarks()] carries.
#' @param save_to Optional character path; when supplied, the resulting
#'   object is also written there with [saveRDS()] (a convenience for the
#'   common "predict, convert, cache" workflow). Defaults to `NULL` (return
#'   only, the standard behaviour of the package's `read_*()` importers).
#' @param ... Additional arguments passed to [utils::read.csv()] when `file`
#'   (or `metadata`) is a path.
#'
#' @details
#' # Replicated digitizations
#'
#' A measure table in which the same physical individual was digitized more
#' than once -- the repeat mode of [digitize_landmarks()], used to quantify
#' measurement error and operator bias -- distinguishes the passes by their
#' identifier rather than by a column, since the exported schema is one row
#' per specimen and landmark. The convention, shared with the T-26
#' repeatability set of [load_t26_saudrune_landmarks()], is
#' `"<individual>_rep<N>"`, optionally with an operator token before the
#' suffix: `"<individual>_<operator>_rep<N>"`. The replicate number is always
#' the last underscore-separated token, so an identifier is decomposed
#' unambiguously from the right, and the operator label carries no underscore.
#'
#' Because a bare identifier cannot be told apart from an individual whose
#' name merely happens to end in `_rep2`, the decomposition is never
#' attempted silently: it is requested with `replicate = "parse"` (and, when
#' several operators share one table, `operator = "parse"`). `metadata$individual`
#' then holds the physical individual, `metadata$replicate` the pass number,
#' and `metadata$operator` the operator, which is the grouping
#' [measurement_error()] (`method = "procrustes"`, argument `individual`) and
#' [operator_disagreement()] expect. Identifiers carrying no suffix are left
#' alone (`replicate = 1`), so a table mixing single and repeated
#' digitizations imports correctly.
#'
#' One ambiguity is irreducible and worth stating: `operator = "parse"` takes
#' the token before the suffix as the operator, so an individual whose own code
#' contains an underscore and which was digitized *without* an operator label
#' (`"fish_01_rep2"`) would be split into individual `"fish"` and operator
#' `"01"`. Use `operator = "parse"` only on tables where the operator was
#' actually recorded in the identifier -- the case it exists for -- and
#' `replicate = "parse"` alone otherwise, which never touches the individual's
#' name beyond the suffix. Identifiers with a suffix but no operator token are
#' reported, and keep `operator = NA`.
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
#' # A table from the repeat mode of digitize_landmarks(): the same two fish,
#' # each digitized twice by operator "AT". Ask for the identifiers to be
#' # decomposed into individual / operator / replicate.
#' rep_tab <- data.frame(
#'   specimen = rep(c("fish_01_AT_rep1", "fish_01_AT_rep2",
#'                    "fish_02_AT_rep1", "fish_02_AT_rep2"), each = 3),
#'   landmark = rep(1:3, times = 4),
#'   X = c(10, 15, 20, 10.4, 15.2, 19.6, 11, 16, 21, 11.3, 15.7, 21.2),
#'   Y = c(20, 25, 20, 20.3, 24.6, 20.2, 21, 26, 21, 20.8, 26.4, 20.9)
#' )
#' lm3 <- read_mlmorph_landmarks(rep_tab, scale_col = NULL,
#'                               replicate = "parse", operator = "parse")
#' lm3$metadata[c("specimen", "individual", "operator", "replicate")]
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

  # -- Individual / operator / replicate carried in the identifier ----------
  #    Requested explicitly (see Details): an identifier ending in "_rep2" is
  #    indistinguishable from an individual named that way, so parsing is never
  #    silent. Decomposition is done from the RIGHT, the replicate number being
  #    the last token and the operator (when asked for) the one before it.
  ids <- .parse_replicate_ids(specimen_names, replicate = replicate,
                              operator = operator)

  # -- Assemble specimen-level metadata in the intraitR convention. ---------
  meta <- data.frame(
    specimen   = specimen_names,
    individual = ids$individual,
    species    = NA_character_,
    population = NA_character_,
    replicate  = ids$replicate,
    operator   = ids$operator,
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

# Decompose specimen identifiers of the form "<individual>_rep<N>" or
# "<individual>_<operator>_rep<N>" -- the convention written by the repeat mode
# of digitize_landmarks() and by the T-26 repeatability set -- into the three
# metadata columns intraitR groups replicated digitizations by.
#
# Parsing happens only when asked for (replicate = "parse", operator = "parse"),
# since "fish_rep2" is a perfectly valid individual name and guessing would
# silently split a data set that was never replicated. Identifiers carrying no
# suffix keep replicate 1 and their own name as `individual`, so a table mixing
# single and repeated digitizations is handled in one pass.
#
# Returns a list of three vectors, each of length(ids).
.parse_replicate_ids <- function(ids, replicate = 1L, operator = "ml_morph") {
  n <- length(ids)
  parse_rep <- is.character(replicate) && length(replicate) == 1L &&
    identical(replicate, "parse")
  parse_op  <- is.character(operator) && length(operator) == 1L &&
    identical(operator, "parse")

  if (!parse_rep) {
    rep_num <- suppressWarnings(as.integer(replicate))
    if (length(rep_num) != 1L || is.na(rep_num)) {
      stop("`replicate` must be a single integer, or \"parse\" to read the ",
           "replicate number off the specimen identifiers.", call. = FALSE)
    }
  }
  if (!parse_op && (!is.character(operator) || length(operator) != 1L)) {
    stop("`operator` must be a single character string, or \"parse\" to read ",
         "the operator off the specimen identifiers.", call. = FALSE)
  }

  individual <- as.character(ids)
  rep_out <- if (parse_rep) rep(1L, n) else rep(as.integer(replicate), n)
  op_out  <- if (parse_op) rep(NA_character_, n) else rep(as.character(operator), n)

  if (!parse_rep && !parse_op) {
    return(list(individual = individual, replicate = rep_out, operator = op_out))
  }

  suffix <- "_rep([0-9]+)$"
  has <- grepl(suffix, individual)
  if (!any(has)) {
    warning("No specimen identifier ends in \"_rep<N>\"; nothing to parse. ",
            "Identifiers are left as they are (replicate 1).", call. = FALSE)
    return(list(individual = individual, replicate = rep_out, operator = op_out))
  }

  if (parse_rep) {
    rep_out[has] <- as.integer(sub(paste0("^.*", suffix), "\\1", individual[has]))
  }
  prefix <- sub(suffix, "", individual[has])

  if (parse_op) {
    # The operator is the last underscore-separated token of the prefix. A
    # prefix with no underscore carries no operator: keep NA rather than
    # amputating the individual's name.
    tok <- grepl("_", prefix, fixed = TRUE)
    if (any(tok)) {                       # `x[i] <- character(0)` is an error
      op_out[has][tok] <- sub("^.*_", "", prefix[tok])
      prefix[tok] <- sub("_[^_]+$", "", prefix[tok])
    }
    if (any(!tok)) {
      warning(sum(!tok), " identifier(s) with a \"_rep<N>\" suffix carry no ",
              "operator token and keep operator = NA: ",
              paste(utils::head(individual[has][!tok], 5), collapse = ", "),
              if (sum(!tok) > 5) ", ..." else "", call. = FALSE)
    }
  }
  individual[has] <- prefix

  if (parse_rep) {
    n_ind <- length(unique(individual))
    message(sprintf(
      "Parsed %d replicated identifier(s): %d individual(s), %d replicate(s) per individual (median).",
      sum(has), n_ind,
      as.integer(stats::median(as.integer(table(individual))))))
  }
  list(individual = individual, replicate = rep_out, operator = op_out)
}
