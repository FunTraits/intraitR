#' Compute linear morphological measurements following the FISHMORPH protocol
#'
#' Computes the 11 linear morphological measurements used by Brosse et al.
#' (2021) to build the FISHMORPH database, from a fixed 21- (or 22-)
#' landmark digitization scheme (see Details), including automatic
#' conversion from digitization (pixel) units to centimetres using a
#' scale bar digitized directly on the picture.
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()], [read_landmarks_csv()], or [simulate_fishmorph_points()]),
#'   or a raw `p x k x n` landmark array, digitized following the point
#'   scheme described in Details. Must contain at least 21 landmarks, in
#'   2 dimensions.
#' @param scale_cm Numeric, the real-world distance, in centimetres,
#'   represented by the scale bar digitized at points 20-21 (typically the
#'   width of a 1 cm section of a ruler placed in the picture). Defaults to
#'   `1`.
#' @param groups Optional factor (or character vector), one value per
#'   specimen, used only by `na_action = "impute_group_mean"` (and
#'   optionally by `"missforest"`, as an auxiliary predictor). If `NULL`
#'   and `landmarks$metadata` has a `species` column, it is used
#'   automatically (as in [trait_space()]).
#' @param na_action Character, how to handle missing values in the 11
#'   computed segment columns (e.g. because a landmark used by that
#'   measurement -- commonly landmark 5 -- was not digitized for a given
#'   specimen): `"keep"` (default) leaves `NA` in place, exactly as in
#'   previous package versions; `"omit"` removes affected specimens and
#'   reports how many; `"impute_mean"` replaces missing segment values with
#'   the column mean; `"impute_group_mean"` uses the within-group (e.g.
#'   within-species) mean instead, falling back to the column mean, with a
#'   warning, for a group entirely missing a segment; `"missforest"` uses
#'   random-forest-based iterative imputation (`missForest::missForest()`);
#'   `"missforest_phylo"` does the same but additionally augments the
#'   predictor matrix with phylogenetic PCoA axes (see [phylo_pcoa()],
#'   `tree`) for the species in `groups`, falling back to plain
#'   `"missforest"` (with a warning) if phylogenetic axes cannot be used.
#'   Same convention, options, and messages as [trait_space()]'s
#'   `na_action` -- see there for details -- except that here imputation
#'   operates on the derived linear *measurements*, not on landmark
#'   coordinates: this is not a substitute for a proper
#'   geometric-morphometric estimate of a missing landmark's position (see
#'   [impute_landmarks()], run on `landmarks` *before* calling this
#'   function), and is best reserved for a small number of missing values.
#' @param missforest_ntree,missforest_maxiter Number of trees per forest
#'   and maximum number of iterations passed to `missForest::missForest()`
#'   when `na_action` is `"missforest"`/`"missforest_phylo"`; ignored
#'   otherwise. Default to `missForest`'s own defaults (`100` and `10`).
#' @param tree Used only by `na_action = "missforest_phylo"`: an object of
#'   class `"phylo"`, or `NULL` (default) to use the bundled
#'   [load_fishmorph_phylogeny()] tree.
#' @param missforest_phylo_k Used only by `na_action = "missforest_phylo"`:
#'   maximum number of phylogenetic PCoA axes to add as predictors.
#'   Defaults to `10`.
#' @param geometry_check Optional object of class `"intrait_geometry_check"`,
#'   as returned by `correct_landmarks(landmarks, rule = "check_geometry")`
#'   -- typically computed once beforehand and passed in here, rather than
#'   recomputed. Any measurement whose underlying landmark line failed a
#'   check for a given specimen (e.g. `Bd`, if segment (3, 4) was flagged
#'   as non-perpendicular to the main body axis) is set to `NA` for that
#'   specimen *before* `na_action` runs, so the usual `na_action` machinery
#'   (`"omit"`, `"impute_mean"`, ...) then handles it exactly like any
#'   other missing value; only checks that are invariant to the picture's
#'   own rotation are used for this (see
#'   `correct_landmarks(rule = "check_geometry")`'s Details), and only
#'   `Bl`, `Bd`, `Mo`, `PFi`, `Hd`, `Eh`, `Ed` can be affected (`PFl`,
#'   `Jl`, `CPd`, `CFd` involve landmarks outside the checked battery).
#'   `NULL` (default) leaves every measurement as computed, regardless of
#'   `geometry_check`.
#'
#' @return A `data.frame` (class `"intrait_segments"`) with one row per
#'   specimen (fewer, if `na_action = "omit"` dropped any) and columns
#'   `Bl`, `Bd`, `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`, `CFd`
#'   (all in centimetres), preceded by any metadata columns carried over
#'   from `landmarks`.
#'
#' @details
#' `fishmorph_segments()` implements the digitization scheme of Brosse
#' et al. (2021) (their figure 1a), in which 21 (optionally 22) landmarks
#' are placed on a lateral-view picture of a fish, in the following fixed
#' order:
#' \describe{
#'   \item{1}{snout tip (top of the mouth)}
#'   \item{2}{posterior insertion of the caudal fin (caudal fin basis)}
#'   \item{3-4}{top and bottom of the body at its deepest point (body depth)}
#'   \item{5-6}{top of the head and bottom of the head/jaw at the vertical
#'     of the eye (head depth)}
#'   \item{7-8}{centre of the eye and bottom of the body at the same
#'     vertical (eye position)}
#'   \item{9}{bottom of the body at the vertical of the snout/mouth}
#'   \item{10}{upper insertion of the pectoral fin}
#'   \item{11}{bottom of the body at the vertical of the pectoral fin
#'     insertion}
#'   \item{12}{tip of the longest pectoral fin ray}
#'   \item{13-14}{top and bottom of the eye (eye diameter)}
#'   \item{15}{corner of the mouth}
#'   \item{16-17}{top and bottom of the caudal peduncle, at its minimum
#'     depth}
#'   \item{18-19}{tip of the upper and lower rays of the caudal fin (caudal
#'     fin depth)}
#'   \item{20-21}{two points a known distance apart (`scale_cm`
#'     centimetres) on a scale bar/ruler included in the picture}
#'   \item{22}{optional: a point along the body midline used to correct
#'     standard length for body curvature in the picture (see below)}
#' }
#' From these landmarks, 11 linear measurements are derived (segment names
#' follow Brosse et al., 2021, table in their figure 1a): body length
#' (`Bl`, standard length from snout to caudal fin basis), body depth
#' (`Bd`), head depth (`Hd`), eye position (`Eh`), mouth height (`Mo`,
#' points 1-9), pectoral fin position (`PFi`, points 10-11), pectoral fin
#' length (`PFl`, points 10-12), eye diameter (`Ed`), maxillary jaw length
#' (`Jl`, points 1-15), caudal peduncle depth (`CPd`), and caudal fin depth
#' (`CFd`).
#'
#' All measurements are converted from digitization units to centimetres
#' using the scale bar (points 20-21), separately for every specimen, so
#' that pictures with different resolutions or magnifications remain
#' comparable.
#'
#' If body length cannot be measured as a straight line because the fish
#' is curved in the picture, a 22nd landmark can be placed along the body
#' midline between the snout and the caudal fin basis; `Bl` is then
#' computed as the sum of the two segments (1-22 and 22-2) instead of the
#' direct distance (1-2). This correction is applied automatically,
#' specimen by specimen, whenever landmark 22 is present in `landmarks`
#' and has non-zero, non-missing coordinates for that specimen; otherwise
#' the direct distance (1-2) is used, matching the original protocol
#' ("+22 if needed, otherwise 22 = 0").
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(11), 2330-2336.
#'
#' @seealso [fishmorph_ratios()], [simulate_fishmorph_points()],
#'   [load_t26_saudrune_landmarks()], [plot_fishmorph_points()],
#'   [trait_space()], [impute_landmarks()], [correct_landmarks()]
#'
#' @examples
#' # real T-26 Saudrune data, in the same "intrait_landmarks" format as
#' # simulate_fishmorph_points()
#' fish <- load_t26_saudrune_landmarks()
#' fishmorph_segments(fish)
#'
#' # some real specimens are missing landmark 5, leaving Hd/RMl-related
#' # segments as NA; impute them using the within-species mean instead of
#' # carrying the NA forward (na_action defaults to "keep"):
#' fishmorph_segments(fish, groups = fish$metadata$species, na_action = "impute_group_mean")
#'
#' # measurements resting on a geometrically non-conforming landmark line
#' # (e.g. Bd if segment (3,4) isn't perpendicular to the body axis) are
#' # set to NA before na_action runs:
#' geom_check <- correct_landmarks(fish, rule = "check_geometry")
#' fishmorph_segments(fish, geometry_check = geom_check, na_action = "impute_group_mean")
#'
#' @export
fishmorph_segments <- function(landmarks, scale_cm = 1, groups = NULL,
                                na_action = c("keep", "omit", "impute_mean",
                                              "impute_group_mean", "missforest",
                                              "missforest_phylo"),
                                missforest_ntree = 100, missforest_maxiter = 10,
                                geometry_check = NULL, tree = NULL,
                                missforest_phylo_k = 10) {
  na_action <- match.arg(na_action)
  if (!is.null(geometry_check) && !inherits(geometry_check, "intrait_geometry_check")) {
    stop(
      "`geometry_check` must be an object returned by ",
      "correct_landmarks(landmarks, rule = \"check_geometry\").",
      call. = FALSE
    )
  }
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  if (dim(A)[2] != 2) {
    stop("fishmorph_segments() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "`landmarks` must contain at least 21 landmarks digitized following the ",
      "Brosse et al. (2021) FISHMORPH scheme (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }
  n <- dim(A)[3]
  specimen_names <- dimnames(A)[[3]]

  dist_lm <- function(a, b) {
    diff_mat <- A[a, , ] - A[b, , ]
    if (is.null(dim(diff_mat))) diff_mat <- matrix(diff_mat, ncol = n)
    sqrt(colSums(diff_mat^2))
  }

  scale_px <- dist_lm(20, 21)
  bad_scale <- is.na(scale_px) | scale_px <= 0
  if (any(bad_scale)) {
    warning(
      sum(bad_scale), " specimen(s) have a zero-length or missing scale bar ",
      "(points 20-21); their segments will be NA. See fishmorph_ratios()'s ",
      "`landmarks` argument to still recover the 9 unitless ratios for these ",
      "specimens directly from pixel-space distances.", call. = FALSE
    )
  }
  px_to_cm <- ifelse(bad_scale, NA_real_, scale_cm / scale_px)

  # Bl/Bd/Hd/Eh/Mo/PFi/PFl/Ed/Jl/CPd/CFd, in raw pixel (digitization) units,
  # including the landmark-22 body-curvature correction to Bl when present;
  # shared with fishmorph_ratios()'s `landmarks`-based rescue (see
  # .fishmorph_pixel_segments()).
  out <- .fishmorph_pixel_segments(A)
  out <- as.data.frame(lapply(out, function(x) x * px_to_cm))
  rownames(out) <- specimen_names

  if (!is.null(geometry_check)) {
    matched_specimens <- intersect(unique(geometry_check$specimen), specimen_names)
    if (length(matched_specimens) == 0) {
      warning(
        "`geometry_check` contains no specimen matching `landmarks`; ignoring it.",
        call. = FALSE
      )
    } else {
      trait_map <- .geometry_check_traits()
      failing <- geometry_check[!is.na(geometry_check$ok) & !geometry_check$ok, c("specimen", "check")]
      n_flagged <- 0L
      for (k in seq_len(nrow(failing))) {
        row_i <- match(failing$specimen[k], specimen_names)
        if (is.na(row_i)) next
        cols <- intersect(trait_map[[failing$check[k]]], names(out))
        for (col in cols) {
          if (!is.na(out[row_i, col])) {
            out[row_i, col] <- NA_real_
            n_flagged <- n_flagged + 1L
          }
        }
      }
      if (n_flagged > 0) {
        message(sprintf(
          paste(
            "geometry_check: set %d measurement value(s) to NA because their",
            "underlying landmark line was flagged as non-conforming by",
            "correct_landmarks(rule = \"check_geometry\")."
          ),
          n_flagged
        ))
      }
    }
  }

  meta <- .get_metadata(landmarks)
  if (is.null(groups) && !is.null(meta) && "species" %in% names(meta)) {
    groups <- meta[specimen_names, "species"]
  }
  if (!is.null(groups)) {
    if (length(groups) != nrow(out)) {
      stop("`groups` must have one entry per specimen.", call. = FALSE)
    }
    groups <- factor(groups)
  }

  res <- .apply_na_action(
    as.matrix(out), groups, na_action, missforest_ntree, missforest_maxiter,
    context = "segments", tree = tree, missforest_phylo_k = missforest_phylo_k
  )
  out <- as.data.frame(res$X)
  if (!all(res$keep)) {
    specimen_names <- specimen_names[res$keep]
  }
  rownames(out) <- specimen_names

  if (!is.null(meta)) {
    meta <- meta[rownames(out), , drop = FALSE]
    out <- cbind(meta, out)
  }

  structure(out, class = c("intrait_segments", "data.frame"))
}
