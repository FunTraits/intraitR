#' Exclude known-bad specimens (e.g. mismeasured fish) from a landmark data set
#'
#' Removes one or more specimens from an `"intrait_landmarks"` object (as
#' returned by [read_tps()], [read_landmarks_csv()],
#' [read_landmarks_xlsx()], or [load_t26_saudrune_landmarks()]) or a raw
#' `p x k x n` landmark array, dropping them consistently from the
#' coordinate array *and* from `$scale`/`$metadata` (if present), and
#' recording exactly which specimens were removed and why, so the
#' exclusion is reproducible and does not depend on remembering to repeat
#' a manual `dplyr::filter()` (or similar) every time the raw data is
#' reloaded.
#'
#' @param landmarks An object of class `"intrait_landmarks"`, or a raw
#'   `p x k x n` landmark array. Not `"intrait_gpa"` (the output of
#'   [gpa_fish()]) -- see Details.
#' @param specimen Character vector of specimen identifiers (matching
#'   `dimnames(landmarks$coords)[[3]]`, i.e. the row names used throughout
#'   the package, such as `rownames(landmarks$metadata)`), or an integer
#'   vector of positions, to remove. Every name must actually exist; unlike
#'   a manual `dplyr::filter(Code != "...")`, a typo or formatting mismatch
#'   (e.g. a leading zero, or `Site` vs `site`) errors immediately instead
#'   of silently matching (and removing) nothing.
#' @param reason Optional character vector explaining why each specimen in
#'   `specimen` is excluded (e.g. `"visibly mis-measured; landmarks 3-4 and
#'   5-6 collapsed to the same point"`), recorded alongside the specimen
#'   identifier for a full, reproducible audit trail (see Return). Either
#'   length 1 (recycled for every specimen) or the same length as
#'   `specimen`. Defaults to `NA`, i.e. unrecorded.
#'
#' @return An object of the same class as `landmarks`, with the specified
#'   specimen(s) removed from `coords` (and from `scale`/`metadata`, if
#'   present). Any `standardization_log`/`correction_log`/`corrected`/
#'   `orientation_log` attribute already present on `coords` (from an
#'   earlier [standardize_orientation()]/[standardize_geometry()]/
#'   [correct_geometry()]/[correct_geometry_conventions()]/
#'   [correct_landmarks()] call) is filtered the same way, so the audit
#'   trail never refers to a specimen no longer in the data. A
#'   `removed_specimens` element (`intrait_landmarks` input) or attribute
#'   (raw array input) records every exclusion made so far as a
#'   `data.frame` with columns `specimen`, `reason`; calling
#'   `exclude_specimens()` again on an already-cleaned object accumulates
#'   into the same record rather than replacing it, so the complete
#'   history of exclusions stays attached to the data, matching the same
#'   spirit as [gpa_fish()]'s `remove_outliers`/`$removed_outliers`.
#'
#' @details
#' Intended to be called right after loading raw landmark data (e.g.
#' immediately after [load_t26_saudrune_landmarks()] or
#' [read_landmarks_xlsx()]), once a specimen has been confirmed -- e.g. via
#' [plot_fishmorph_points()], [correct_landmarks()] (`rule =
#' "check_geometry"`), or the non-finite-ratio error from [trait_space()]/
#' [fishmorph_ratios()] -- to be a genuine measurement/digitization error
#' rather than a real, if unusual, morphology; every downstream function
#' in the package ([fishmorph_segments()], [gpa_fish()],
#' [correct_geometry()], ...) then simply never sees it, rather than
#' relying on filtering `segments`/`ratios`/`trait_space()` output after
#' the fact at every stage of the pipeline (easy to forget to repeat
#' consistently, and too late for any function -- like [standardize_geometry()]
#' or [gpa_fish()] -- whose result for the *other*, retained specimens can
#' itself depend on which specimens were included).
#'
#' Not supported for `"intrait_gpa"` objects (the output of [gpa_fish()]):
#' Procrustes alignment is computed jointly across every specimen supplied
#' to [gpa_fish()], so a mis-digitized specimen can distort the consensus
#' shape (and hence every other specimen's alignment to it); simply
#' deleting its row from an already-aligned `coords` array afterwards does
#' not undo that distortion. Call `exclude_specimens()` *before*
#' [gpa_fish()] instead (on the raw digitized landmarks), or use
#' [gpa_fish()]'s own `remove_outliers = TRUE`, which re-runs
#' [geomorph::gpagen()] on the cleaned sample and records the exclusion in
#' `$removed_outliers`.
#'
#' @seealso [gpa_fish()] (`remove_outliers`, for exclusions decided *after*
#'   Procrustes alignment), [detect_outliers()], [correct_landmarks()]
#'   (`rule = "check_geometry"`), [plot_fishmorph_points()],
#'   [load_t26_saudrune_landmarks()], [read_landmarks_xlsx()]
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#'
#' # after visually confirming these two specimens are mismeasured (not
#' # just morphologically unusual), remove them right after loading, so
#' # every downstream step (fishmorph_segments(), gpa_fish(), ...) is
#' # computed without them:
#' fish_clean <- exclude_specimens(
#'   fish,
#'   specimen = c("T-26-0050_Operator_2", "T-26-0230-1_Operator_2"),
#'   reason = "landmarks 3-4 and/or 5-6 collapsed to the same point (zero-length Bd/Hd)"
#' )
#' fish_clean$removed_specimens # full record: which, and why
#'
#' @export
exclude_specimens <- function(landmarks, specimen, reason = NA_character_) {
  if (inherits(landmarks, "intrait_gpa")) {
    stop(
      "exclude_specimens() does not support \"intrait_gpa\" objects: Procrustes ",
      "alignment is computed jointly across all specimens, so deleting a row ",
      "after the fact does not undo its effect on the consensus shape/other ",
      "specimens' alignment. Call exclude_specimens() before gpa_fish() on the ",
      "raw digitized landmarks instead, or use gpa_fish(remove_outliers = TRUE), ",
      "which re-runs GPA on the cleaned sample.",
      call. = FALSE
    )
  }
  if (missing(specimen) || length(specimen) == 0 || (is.character(specimen) && all(is.na(specimen)))) {
    stop("`specimen` must name (or index) at least one specimen to exclude.", call. = FALSE)
  }

  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  k <- dim(A)[2]
  n <- dim(A)[3]
  specimen_names_all <- dimnames(A)[[3]]

  idx <- .resolve_specimen_idx(specimen, specimen_names_all)
  if (anyNA(idx) || any(idx < 1) || any(idx > n)) {
    stop(
      "`specimen` contains position(s) outside 1:", n, " (the number of ",
      "specimens in `landmarks`).",
      call. = FALSE
    )
  }

  if (length(reason) == 1) {
    reason <- rep(reason, length(specimen))
  } else if (length(reason) != length(specimen)) {
    stop("`reason` must have length 1 or the same length as `specimen`.", call. = FALSE)
  }

  dup <- duplicated(idx)
  if (any(dup)) {
    warning(
      "exclude_specimens(): `specimen` listed the same specimen more than once; ",
      "duplicates ignored (the first matching `reason`, if any, is kept).",
      call. = FALSE
    )
  }
  idx_unique <- idx[!dup]
  reason_unique <- reason[!dup]

  if (length(idx_unique) >= n) {
    stop(
      "`specimen` names every specimen in `landmarks`; exclude_specimens() would ",
      "leave zero specimens, which is never intended.",
      call. = FALSE
    )
  }

  removed_now <- data.frame(
    specimen = specimen_names_all[idx_unique],
    reason = as.character(reason_unique),
    stringsAsFactors = FALSE
  )
  keep <- setdiff(seq_len(n), idx_unique)
  keep_names <- specimen_names_all[keep]

  A_kept <- A[, , keep, drop = FALSE]
  dimnames(A_kept) <- list(dimnames(A)[[1]], dimnames(A)[[2]], keep_names)

  # Any per-specimen audit-trail attribute already attached to `coords` must
  # be filtered the same way, so it never refers to a specimen no longer in
  # the data (extraction via `[` does not carry these over automatically,
  # unlike the in-place `[<-` assignments used elsewhere in the package, so
  # they are explicitly recomputed and reattached here).
  for (log_name in c("standardization_log", "correction_log", "orientation_log")) {
    prior_log <- attr(A, log_name)
    if (!is.null(prior_log) && "specimen" %in% names(prior_log)) {
      attr(A_kept, log_name) <- prior_log[prior_log$specimen %in% keep_names, , drop = FALSE]
    }
  }
  prior_corrected <- attr(A, "corrected")
  if (!is.null(prior_corrected) && !is.null(colnames(prior_corrected))) {
    attr(A_kept, "corrected") <- prior_corrected[, colnames(prior_corrected) %in% keep_names, drop = FALSE]
  }

  prior_removed <- if (inherits(landmarks, "intrait_landmarks")) {
    landmarks$removed_specimens
  } else {
    attr(A, "removed_specimens")
  }
  removed_all <- if (!is.null(prior_removed)) rbind(prior_removed, removed_now) else removed_now

  message(sprintf(
    "exclude_specimens(): removed %d specimen(s) (%d remaining, out of %d): %s.",
    nrow(removed_now), length(keep), n, paste(removed_now$specimen, collapse = ", ")
  ))

  if (inherits(landmarks, "intrait_landmarks")) {
    landmarks$coords <- A_kept
    if (!is.null(landmarks$scale)) {
      landmarks$scale <- landmarks$scale[keep_names]
    }
    if (!is.null(landmarks$metadata)) {
      landmarks$metadata <- landmarks$metadata[keep_names, , drop = FALSE]
    }
    landmarks$removed_specimens <- removed_all
    return(landmarks)
  }

  attr(A_kept, "removed_specimens") <- removed_all
  A_kept
}
