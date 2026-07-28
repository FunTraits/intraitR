#' Compute linear morphological measurements following the FISHMORPH protocol
#'
#' Computes the 11 linear morphological measurements used by Brosse et al.
#' (2021) to build the FISHMORPH database, from a fixed 21-landmark
#' digitization scheme, optionally extended with the axis hinges 22, 24 and
#' 25 for curved specimens (see Details), including automatic conversion
#' from digitization (pixel) units to centimetres using a scale bar
#' digitized directly on the picture.
#'
#' @param landmarks An object of class `"intrait_landmarks"` (from
#'   [read_tps()], [read_landmarks_csv()], or [simulate_fishmorph_points()]),
#'   or a raw `p x k x n` landmark array, digitized following the point
#'   scheme described in Details. Must contain at least 21 landmarks, in
#'   2 dimensions. Rows 22, 24 and 25, when present, are read as the
#'   midline hinges of the broken axis (see the section on curved
#'   specimens); any further row is ignored.
#' @param scale_cm Numeric, the real-world distance, in centimetres,
#'   represented by the scale bar digitized at points 20-21 (typically the
#'   width of a 1 cm section of a ruler placed in the picture). Defaults to
#'   `1`.
#' @param scale_action Character, what to do with a specimen whose scale bar
#'   (points 20-21) is missing or of zero length: `"na"` (default) returns
#'   `NA` for all 11 of its measurements, as previous versions did;
#'   `"pixels"` returns them in **pixels** instead, and adds a
#'   `scale_units` column (`"cm"` / `"px"`) plus a `"pixel_specimens"`
#'   attribute so the two units are never confused. See the section on
#'   uncalibrated specimens for what this is and is not valid for.
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
#' @param species Species identifier for **each row / specimen**, used only to
#'   look up the phylogenetic axes of `"missforest_phylo"`. `NULL` (default)
#'   auto-detects it (a `species` / `Species` / `Genus.species` column, the
#'   metadata, or the specimen names). Deliberately **separate from `groups`**:
#'   the phylogeny needs to know which species a row belongs to, not a
#'   categorical predictor for the forest.
#' @param phylo_axes Used only by `"missforest_phylo"`. `NULL` (default) uses the
#'   **precomputed** axes of [load_fishmorph_phylo_axes()], so that every call
#'   shares one and the same phylogenetic coordinate system. Supply a data frame
#'   (a `species` column plus one column per axis) to use your own.
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
#'   from `landmarks`. With `scale_action = "pixels"` a trailing
#'   `scale_units` column (`"cm"` or `"px"`, one value per specimen) is
#'   added and the identifiers of the pixel-measured specimens are stored in
#'   the `"pixel_specimens"` attribute; the column is present whenever that
#'   argument was used, even if every specimen turned out to be calibrated,
#'   so its presence depends on the call and not on the data.
#'
#' @details
#' `fishmorph_segments()` implements the digitization scheme of Brosse
#' et al. (2021) (their figure 1a), in which 21 landmarks -- plus, optionally,
#' the midline hinges 22, 24 and 25 -- are placed on a lateral-view picture of
#' a fish, in the following fixed order:
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
#'   \item{23}{optional, and *not used here*: the derived head base (the
#'     intersection of line (1, 9) with the parallel to the head axis
#'     through 6), produced by [digitize_landmarks()]}
#'   \item{24-25}{optional: two further midline hinges, for a specimen too
#'     curved to be described by a single bend (see below)}
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
#' @section Specimens without a scale bar (`scale_action`):
#' A specimen whose scale bar (points 20-21) is missing or degenerate has no
#' measurement in centimetres: there is no factor to convert its pixel
#' distances with, and returning the pixel numbers under a column documented
#' as centimetres would be a silent unit error. That is why the default
#' (`scale_action = "na"`) sets all 11 measurements to `NA` -- the honest
#' value for "not measured on this scale".
#'
#' It does, however, have a perfectly good *shape*. Each of the nine
#' FISHMORPH ratios divides two measurements of the **same** specimen, so the
#' unknown per-specimen factor cancels algebraically and the ratios computed
#' from pixel distances are numerically identical to the ones the calibrated
#' picture would have given. `scale_action = "pixels"` records that: the
#' uncalibrated specimens keep their raw pixel distances (a conversion factor
#' of 1), the calibrated ones stay in centimetres, and a `scale_units` column
#' says which is which. [fishmorph_ratios()] then needs no special argument
#' -- it treats those rows like any other, and carries `scale_units` through
#' to its own output as a metadata column.
#'
#' What this does **not** make comparable is anything absolute. A pixel is a
#' property of one photograph's resolution and magnification, so `Bl` in
#' pixels cannot be compared with `Bl` in centimetres, nor with the pixels of
#' another picture, and neither can a mean, a variance or an allometric
#' regression computed over a mixed set of rows. Any analysis of absolute size
#' should therefore be restricted explicitly, e.g.
#' `subset(segments, scale_units == "cm")`. The [print()] method states the
#' mix whenever it exists, for exactly that reason.
#'
#' The alternative route remains available and is equivalent in result:
#' compute the segments with the default `"na"` and pass the same landmarks to
#' [fishmorph_ratios()]'s `landmarks` argument, which rescues the ratios of
#' the all-`NA` rows from pixel distances at the ratio stage. Use that when
#' the cm table itself must not contain pixel values (e.g. it is being
#' archived as a calibrated measurement table); use `scale_action = "pixels"`
#' when the ratios are the point of the table.
#'
#' @section Standard length on a curved specimen (the broken axis):
#' If body length cannot be measured as a straight line because the fish is
#' curved in the picture, hinge points can be placed along the body midline
#' between the snout (1) and the caudal fin basis (2), and `Bl` is measured
#' as the *curvilinear* length of the resulting polyline instead of the
#' direct distance (1-2). Three hinges are recognised, the numbering of
#' [digitize_landmarks()] and of the FISHMORPH protocol: **22** (the
#' curvature point proper), **24** and **25** (the further hinges a strongly
#' bent specimen needs; entry aids in the digitizer, but genuine midline
#' points geometrically, and exported as such). Landmark 23 is skipped --
#' it is the derived head base, not a point on the axis.
#'
#' The correction is applied hinge by hinge and specimen by specimen: each
#' hinge counts for a given specimen when it is present in `landmarks` and
#' has complete, non-missing, non-all-zero coordinates for that specimen
#' (the original protocol's "+22 if needed, otherwise 22 = 0" convention,
#' which a table that reserves the columns for every specimen encodes as
#' `0, 0`). With hinges 22 and 24 placed, for instance, `Bl` is
#' `d(1, 22) + d(22, 24) + d(24, 2)`; with none placed it reduces exactly to
#' `d(1, 2)`, so a 21-landmark data set is unaffected.
#'
#' The hinges are chained **in ascending landmark order** (1, 22, 24, 25, 2):
#' the numbering *is* the antero-posterior order of the protocol. A hinge
#' placed out of anatomical sequence therefore yields a zig-zagging polyline
#' and an inflated `Bl`, rather than being silently re-sorted -- which is the
#' intended behaviour, since such a specimen is a digitization error to fix
#' and not a measurement to keep. (Note that the on-screen `Bl` of
#' [digitize_landmarks()] instead orders the hinges by their projection on
#' the 1-2 chord, so the two agree on every correctly digitized specimen and
#' can disagree on a mis-ordered one.)
#'
#' A curvilinear `Bl` is longer than the chord it replaces, and exactly two
#' of the nine FISHMORPH ratios involve it: body elongation
#' (`BEl = Bl / Bd`) rises and pectoral fin size (`PFs = PFl / Bl`) falls.
#' Both are biased in that same direction by an uncorrected bend -- a curved
#' fish measured chord-wise is recorded as shorter, hence stubbier, than it
#' is -- so the correction is what makes curved and straight specimens
#' comparable, and is therefore applied automatically rather than offered as
#' an option.
#'
#' @references
#' Brosse, S., Charpin, N., Su, G., Toussaint, A., Herrera-R, G. A.,
#' Tedesco, P. A., & Villéger, S. (2021). FISHMORPH: A global database on
#' morphological traits of freshwater fishes. Global Ecology and
#' Biogeography, 30(11), 2330-2336.
#'
#' @seealso [fishmorph_ratios()], [simulate_fishmorph_points()],
#'   [load_t26_saudrune_landmarks()], [plot_fishmorph_points()],
#'   [trait_space()], [impute_landmarks()], [correct_landmarks()],
#'   [digitize_landmarks()] (where the hinges 22/24/25 are placed)
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
#' # specimens with no usable scale bar: measure them in pixels instead of
#' # returning NA. The 9 ratios are unaffected (the unknown factor cancels);
#' # only absolute values are not comparable, hence the scale_units column.
#' seg_px <- fishmorph_segments(fish, scale_action = "pixels")
#' table(seg_px$scale_units)
#' fishmorph_ratios(seg_px)                    # no `landmarks` argument needed
#' subset(seg_px, scale_units == "cm")         # for anything absolute
#'
#' # the broken axis: a midline hinge makes Bl the curvilinear length. Here
#' # landmark 22 is put halfway along the midline and displaced dorsally, so
#' # Bl becomes d(1, 22) + d(22, 2) instead of d(1, 2) -- and is longer.
#' A  <- fish$coords
#' A2 <- array(0, dim = c(25, dim(A)[2], dim(A)[3]),
#'             dimnames = list(NULL, NULL, dimnames(A)[[3]]))
#' A2[seq_len(dim(A)[1]), , ] <- A
#' A2[22, , ] <- (A[1, , ] + A[2, , ]) / 2 + c(0, 20)
#' straight <- fishmorph_segments(fish)$Bl
#' broken   <- fishmorph_segments(A2)$Bl     # rows 23-25 left at 0 = not placed
#' head(data.frame(straight, broken))
#'
#' @export
fishmorph_segments <- function(landmarks, scale_cm = 1,
                                scale_action = c("na", "pixels"),
                                groups = NULL,
                                na_action = c("keep", "omit", "impute_mean",
                                              "impute_group_mean", "missforest",
                                              "missforest_phylo"),
                                missforest_ntree = 100, missforest_maxiter = 10,
                                geometry_check = NULL, tree = NULL,
                                missforest_phylo_k = 10,
                                species = NULL, phylo_axes = NULL) {
  na_action <- match.arg(na_action)
  scale_action <- match.arg(scale_action)
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
  # An uncalibrated specimen has no length in centimetres -- but it does have
  # one in pixels, and every FISHMORPH ratio divides two measurements of the
  # same specimen, so the unknown factor cancels. `scale_action` decides which
  # of the two facts the returned table records (see the section on
  # uncalibrated specimens).
  if (any(bad_scale)) {
    if (scale_action == "pixels") {
      message(sprintf(
        paste(
          "scale_action = \"pixels\": %d specimen(s) have a zero-length or",
          "missing scale bar (points 20-21); their measurements are returned",
          "in PIXELS (scale_units == \"px\"), the other %d in centimetres. The",
          "nine ratios are unaffected; absolute values are not comparable",
          "across the two units."
        ),
        sum(bad_scale), sum(!bad_scale)
      ))
    } else {
      warning(
        sum(bad_scale), " specimen(s) have a zero-length or missing scale bar ",
        "(points 20-21); their segments will be NA. Use ",
        "scale_action = \"pixels\" to measure them in pixels instead (the 9 ",
        "unitless ratios are unaffected), or see fishmorph_ratios()'s ",
        "`landmarks` argument to recover those ratios from an existing ",
        "cm table.", call. = FALSE
      )
    }
  }
  px_to_cm <- ifelse(bad_scale,
                     if (scale_action == "pixels") 1 else NA_real_,
                     scale_cm / scale_px)
  # One unit label per specimen, carried through the na_action filtering below
  # and returned as a `scale_units` column whenever scale_action = "pixels".
  scale_units <- ifelse(bad_scale,
                        if (scale_action == "pixels") "px" else NA_character_,
                        "cm")

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
  # `species` (the key of the phylogenetic axes) is auto-detected: from the
  # metadata, otherwise from the specimen names themselves. `groups` is not.
  if (is.null(species)) {
    if (!is.null(meta) && "species" %in% names(meta)) {
      species <- meta[specimen_names, "species"]
    } else {
      species <- specimen_names
    }
  }
  if (!is.null(species) && length(species) != nrow(out)) {
    stop("`species` must have one entry per specimen.", call. = FALSE)
  }
  # within-group means may auto-detect the grouping only from a *real* species
  # column (metadata$species), never from the specimen names -- so a raw array
  # without species metadata still errors below (a per-specimen group mean is
  # meaningless).
  if (is.null(groups) && na_action == "impute_group_mean" &&
      !is.null(meta) && "species" %in% names(meta)) {
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
    context = "segments", tree = tree, missforest_phylo_k = missforest_phylo_k,
    phylo_axes = phylo_axes, species = species
  )
  out <- as.data.frame(res$X)
  if (!all(res$keep)) {
    specimen_names <- specimen_names[res$keep]
    scale_units <- scale_units[res$keep]
  }
  rownames(out) <- specimen_names

  if (!is.null(meta)) {
    meta <- meta[rownames(out), , drop = FALSE]
    out <- cbind(meta, out)
  }

  # The unit column exists exactly when `scale_action = "pixels"` was asked
  # for -- a property of the call, not of the data -- so its presence is
  # predictable, and a default call returns the same columns as before. It is
  # appended last, leaving the 11 measurement columns contiguous, and
  # `fishmorph_ratios()` carries it over as a metadata column for free.
  if (scale_action == "pixels") {
    out$scale_units <- scale_units
    attr(out, "pixel_specimens") <-
      rownames(out)[!is.na(scale_units) & scale_units == "px"]
  }

  structure(out, class = c("intrait_segments", "data.frame"))
}

#' @rdname fishmorph_segments
#' @param x An object of class `"intrait_segments"`, from
#'   [fishmorph_segments()].
#' @param ... Further arguments passed to [print.data.frame()].
#' @return `print()` invisibly returns `x`.
#' @details
#' The `print()` method is the ordinary data-frame print, plus -- and only
#' when the table actually mixes units, i.e. when `scale_action = "pixels"`
#' left some specimens uncalibrated -- a one-line note naming how many rows
#' are in pixels. A mixed-unit table is safe for the ratios and wrong for
#' anything absolute, and that is precisely the kind of property that must be
#' visible at the console rather than only in an attribute.
#' @export
print.intrait_segments <- function(x, ...) {
  print(as.data.frame(x), ...)
  px <- attr(x, "pixel_specimens")
  if (length(px) > 0) {
    cat(sprintf(
      paste0("# %d of %d specimen(s) measured in PIXELS (no valid scale bar): ",
             "%s\n# The 9 FISHMORPH ratios are valid; absolute values are not ",
             "comparable across units.\n#   Use subset(x, scale_units == ",
             "\"cm\") for any analysis of absolute size.\n"),
      length(px), nrow(x),
      paste(c(utils::head(px, 3), if (length(px) > 3) "..." else NULL),
            collapse = ", ")
    ))
  }
  invisible(x)
}
