#' Import landmark coordinates from a generic long-format CSV file
#'
#' Reads landmark coordinates stored in a "long" (tidy) CSV file, with one
#' row per specimen/landmark combination, and reshapes them into a
#' geomorph-style `p x k x n` array. Useful when landmarks were digitized
#' outside `tpsDig` (e.g. in ImageJ/Fiji, or exported from a database), or
#' for three-dimensional landmark configurations.
#'
#' @param file Character. Path to a CSV file, or a `data.frame` already
#'   loaded in R.
#' @param specimen Character. Name of the column identifying specimens.
#'   Defaults to `"specimen"`.
#' @param landmark Character. Name of the column identifying landmarks
#'   (used only to order coordinates consistently within a specimen).
#'   Defaults to `"landmark"`.
#' @param coords Character vector of column names holding the coordinate
#'   values, in order (e.g. `c("X", "Y")` for 2D or `c("X", "Y", "Z")` for
#'   3D). Defaults to `c("X", "Y")`.
#' @param metadata Optional `data.frame` of specimen-level metadata, as in
#'   [read_tps()].
#' @param ... Additional arguments passed to [utils::read.csv()] when
#'   `file` is a path (ignored when `file` is already a `data.frame`).
#'
#' @return An object of class `"intrait_landmarks"` (see [read_tps()] for
#'   details); `scale` is set to `NULL` since long-format CSV files do not
#'   carry a digitization scale.
#'
#' @seealso [read_tps()], [gpa_fish()]
#'
#' @examples
#' df <- data.frame(
#'   specimen = rep(c("fish_01", "fish_02"), each = 3),
#'   landmark = rep(1:3, times = 2),
#'   X = c(10, 15, 20, 11, 16, 21),
#'   Y = c(20, 25, 20, 21, 26, 21)
#' )
#' lm <- read_landmarks_csv(df)
#' dim(lm$coords)
#'
#' @export
read_landmarks_csv <- function(file, specimen = "specimen", landmark = "landmark",
                                coords = c("X", "Y"), metadata = NULL, ...) {
  df <- if (is.data.frame(file)) file else utils::read.csv(file, stringsAsFactors = FALSE, ...)

  required_cols <- c(specimen, landmark, coords)
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop("Missing column(s) in input data: ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  df <- df[order(df[[specimen]], df[[landmark]]), ]
  specimen_names <- unique(as.character(df[[specimen]]))
  landmark_ids <- unique(df[[landmark]])
  n <- length(specimen_names)
  p <- length(landmark_ids)
  k <- length(coords)

  counts <- table(df[[specimen]])
  if (length(unique(as.vector(counts))) > 1) {
    stop(
      "Not all specimens have the same number of landmarks (counts: ",
      paste(unique(as.vector(counts)), collapse = ", "), "). ",
      "A common landmark configuration is required.",
      call. = FALSE
    )
  }

  A <- array(
    NA_real_,
    dim = c(p, k, n),
    dimnames = list(as.character(landmark_ids), coords, specimen_names)
  )
  for (s in specimen_names) {
    sub_df <- df[as.character(df[[specimen]]) == s, ]
    sub_df <- sub_df[match(landmark_ids, sub_df[[landmark]]), ]
    A[, , s] <- as.matrix(sub_df[, coords])
  }

  meta <- if (!is.null(metadata)) .merge_metadata(metadata, specimen_names) else NULL

  structure(
    list(coords = A, scale = NULL, metadata = meta),
    class = "intrait_landmarks"
  )
}
