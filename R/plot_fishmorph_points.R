#' Plot a specimen following the FISHMORPH point digitization scheme
#'
#' Visualises the 21 (or 22) landmarks of one specimen, digitized following
#' the Brosse et al. (2021) FISHMORPH scheme, together with the 11 linear
#' measurements they define, a body outline, the eye, and the digitization
#' scale bar, for quality control of digitization.
#'
#' @param landmarks An object of class `"intrait_landmarks"` with at least
#'   21 two-dimensional landmarks digitized following the scheme described
#'   in [fishmorph_segments()] (e.g. from [simulate_fishmorph_points()]).
#' @param specimen Integer index or character specimen identifier of the
#'   configuration to plot. Defaults to `1`. Ignored if `individual` is
#'   supplied.
#' @param individual Optional character. Instead of `specimen`, select
#'   every digitization belonging to a given fish, matched against
#'   `landmarks$metadata$individual` -- the identifier used throughout the
#'   package to link digitizations of the same fish (see
#'   [digitization_error()], [measurement_error()]; for
#'   [load_t26_saudrune_landmarks()] this is identical to the `code`
#'   column). This is useful when `landmarks` holds one row per
#'   specimen/operator or specimen/replicate combination (e.g.
#'   `load_t26_saudrune_landmarks("operators")`, with two rows per fish, one
#'   per operator) and it is more natural to look a fish up by its code than
#'   by the exact specimen identifier. If `individual` matches more than one
#'   specimen (e.g. two operators, or several replicate digitizations), all
#'   matches are plotted side by side in a single figure (one panel per
#'   specimen, titled with its own specimen identifier) so they can be
#'   compared visually; `background_image` is then ignored (with a
#'   warning), since a single photograph cannot be assumed to apply to every
#'   match. Requires `landmarks$metadata` to have an `individual` column.
#'   Defaults to `NULL` (use `specimen` instead).
#' @param labels Logical, label landmarks with their index. Defaults to
#'   `TRUE`.
#' @param legend Logical, draw a legend of measurement names/colours.
#'   Defaults to `TRUE`.
#' @param legend_position One of `"outside"` (default: drawn in the
#'   margin, just to the right of the plot box, so it never overlaps the
#'   fish outline) or a standard [graphics::legend()] position keyword
#'   (e.g. `"topright"`) to draw it inside the plot box instead, as in
#'   previous versions.
#' @param background_image Optional path to a `.jpg`/`.jpeg` or `.png`
#'   photograph of the specimen, drawn as a background layer beneath the
#'   landmarks and measurement segments (e.g. to visually check whether a
#'   landmark was placed off the body outline). Only meaningful for the
#'   original, un-aligned digitized coordinates. Requires the (Suggested)
#'   `jpeg` package for `.jpg`/`.jpeg` files, or `png` for `.png` files.
#'   Defaults to `NULL` (no background).
#' @param flip_y Logical, flip `background_image` vertically before
#'   plotting, to match the bottom-left-origin convention of digitized
#'   landmark coordinates against the top-row-first convention of image
#'   files (see `flip_y` in [plot_landmarks()]). Ignored when
#'   `background_image` is `NULL`. Defaults to `TRUE`.
#' @param highlight_imputed Logical, colour landmark points red if they
#'   carry an `"imputed"` marker for this specimen -- i.e. were estimated
#'   by [impute_landmarks()] rather than digitized -- instead of the usual
#'   grey, with a matching "Imputed landmark" legend entry. Has no visible
#'   effect on `landmarks` without such a marker (e.g. never run through
#'   [impute_landmarks()]). Defaults to `TRUE`.
#' @param highlight_corrected Logical, colour landmark points blue if they
#'   carry a `"corrected"` marker for this specimen -- i.e. were manually
#'   adjusted by [correct_landmarks()] -- with a matching "Corrected
#'   landmark" legend entry. If a point is both imputed and corrected,
#'   blue (corrected) takes precedence. Has no visible effect on
#'   `landmarks` without such a marker. Defaults to `TRUE`.
#' @param geometry_check Optional object of class `"intrait_geometry_check"`,
#'   as returned by `correct_landmarks(landmarks, rule = "check_geometry")`
#'   -- typically computed once for the whole data set and reused across
#'   plot calls, rather than recomputed here. When supplied, any landmark
#'   implicated by a check that failed (`ok = FALSE`) for this specimen is
#'   coloured orange, with a matching "Geometry check flagged" legend
#'   entry, so specimens worth a closer look (or a [correct_landmarks()]
#'   fix) stand out visually. `NULL` (default) draws no such highlighting.
#'   Ignored (with no effect) if `geometry_check` has no row for this
#'   specimen.
#' @param highlight_geometry Logical, whether to apply the `geometry_check`
#'   highlighting described above. Only relevant when `geometry_check` is
#'   supplied. Defaults to `TRUE`.
#' @param outline Logical, add a set of purely visual reference lines,
#'   drawn in addition to (and visually subordinate to) the 11 coloured
#'   measurement segments, reproducing the digitization protocol sheet:
#'   a body outline (solid, points 1-5-3-16-18-19-17-4-6, closed back to
#'   1), a horizontal reference line along the belly (points 9-8-11-4),
#'   a vertical reference line at eye level (points 5-13-7-14-6-8), and
#'   the eye itself (a circle centred on point 7 with diameter equal to
#'   the Ed measurement, i.e. the distance between points 13 and 14). The
#'   body outline is drawn as a plain solid line; the two reference lines
#'   and the eye circle are drawn very light and dotted, so they read as
#'   background guides rather than measurements. Any landmark missing
#'   (`NA`) for this specimen is silently dropped from these reference
#'   paths rather than leaving a gap -- e.g. real T-26 specimens are
#'   commonly missing landmark 5, in which case the body outline falls
#'   back to a direct 1-3 segment. Defaults to `TRUE`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns the `p x 2` matrix of coordinates plotted, or
#'   (when `individual` matches more than one specimen) a named list of such
#'   matrices, one per matching specimen.
#'
#' @seealso [fishmorph_segments()], [fishmorph_ratios()],
#'   [simulate_fishmorph_points()], [load_t26_saudrune_landmarks()],
#'   [impute_landmarks()], [correct_landmarks()],
#'   [standardize_orientation()] (fix an upside-down/mirrored specimen at
#'   the data level, rather than a per-plot display toggle)
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' plot_fishmorph_points(fish, specimen = 1)
#'
#' # look a fish up by its code rather than by specimen/operator: the raw
#' # operator-level data has two rows (one per operator) per fish, so both
#' # digitizations are plotted side by side for comparison
#' fish_ops <- load_t26_saudrune_landmarks("operators")
#' one_code <- fish_ops$metadata$individual[1]
#' plot_fishmorph_points(fish_ops, individual = one_code)
#'
#' # if some specimens appear upside down or mirrored left-right, fix the
#' # underlying coordinates (not just the display) for every specimen at
#' # once, using landmarks that are always present and in the same role:
#' fish_oriented <- standardize_orientation(fish)
#' plot_fishmorph_points(fish_oriented, specimen = 1)
#'
#' # disable the body outline / eye / reference lines, keeping only the
#' # 11 coloured measurement segments (as in earlier package versions):
#' plot_fishmorph_points(fish, specimen = 1, outline = FALSE)
#'
#' # points estimated by impute_landmarks() are highlighted in red:
#' \donttest{
#' fish_imputed <- impute_landmarks(fish)
#' plot_fishmorph_points(fish_imputed, specimen = 1)
#' }
#'
#' # points fixed by correct_landmarks() are highlighted in blue:
#' fish_fixed <- correct_landmarks(
#'   fish, specimen = "T-26-0010_Operator_1",
#'   points = c(9, 8, 11, 4), correct = 11, axis = "y"
#' )
#' plot_fishmorph_points(fish_fixed, specimen = "T-26-0010_Operator_1")
#'
#' # landmarks implicated in a failed check_geometry() convention are
#' # highlighted in orange:
#' geom_check <- correct_landmarks(fish, rule = "check_geometry")
#' plot_fishmorph_points(fish, specimen = 1, geometry_check = geom_check)
#'
#' \dontrun{
#' # Overlay the original photograph (requires the "jpeg" package and a
#' # photograph in the same pixel coordinate system as the landmarks):
#' plot_fishmorph_points(fish, specimen = 1, background_image = "specimen1.jpg")
#' }
#'
#' @export
plot_fishmorph_points <- function(landmarks, specimen = 1, individual = NULL, labels = TRUE, legend = TRUE,
                                   legend_position = "outside",
                                   background_image = NULL, flip_y = TRUE,
                                   outline = TRUE,
                                   highlight_imputed = TRUE, highlight_corrected = TRUE,
                                   geometry_check = NULL, highlight_geometry = TRUE, ...) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  if (dim(A)[2] != 2) {
    stop("plot_fishmorph_points() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (!is.null(geometry_check) && !inherits(geometry_check, "intrait_geometry_check")) {
    stop(
      "`geometry_check` must be an object returned by ",
      "correct_landmarks(landmarks, rule = \"check_geometry\").",
      call. = FALSE
    )
  }
  if (p < 21) {
    stop(
      "`landmarks` must contain at least 21 landmarks digitized following the ",
      "Brosse et al. (2021) FISHMORPH scheme (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }

  if (!is.null(individual)) {
    if (!identical(specimen, 1)) {
      stop("Specify only one of `specimen` or `individual`, not both.", call. = FALSE)
    }
    meta <- if (is.list(landmarks)) landmarks$metadata else NULL
    if (is.null(meta) || is.null(meta$individual)) {
      stop(
        "`individual` requires `landmarks$metadata` to have an `individual` ",
        "column, as produced by simulate_fishmorph_points()/",
        "load_t26_saudrune_landmarks(); found none.",
        call. = FALSE
      )
    }
    matches <- which(meta$individual == individual)
    if (length(matches) == 0) {
      stop("No specimen found with individual = '", individual, "'.", call. = FALSE)
    }
    specimen_ids <- dimnames(A)[[3]][matches]

    if (length(specimen_ids) > 1) {
      if (!is.null(background_image)) {
        warning(
          "`background_image` is ignored: `individual` = '", individual,
          "' matches ", length(specimen_ids), " specimens, and a single ",
          "photograph cannot be assumed to apply to all of them. Plot each ",
          "specimen individually via `specimen` to overlay a photograph.",
          call. = FALSE
        )
      }
      n_match <- length(specimen_ids)
      n_col <- ceiling(sqrt(n_match))
      n_row <- ceiling(n_match / n_col)
      old_par <- graphics::par(mfrow = c(n_row, n_col))
      on.exit(graphics::par(old_par), add = TRUE)

      results <- lapply(specimen_ids, function(s) {
        plot_fishmorph_points(
          landmarks, specimen = s, labels = labels, legend = legend,
          legend_position = legend_position, background_image = NULL,
          flip_y = flip_y, outline = outline,
          highlight_imputed = highlight_imputed,
          highlight_corrected = highlight_corrected,
          geometry_check = geometry_check, highlight_geometry = highlight_geometry, ...
        )
      })
      names(results) <- specimen_ids
      return(invisible(results))
    }
    specimen <- specimen_ids
  }

  if (is.character(specimen)) {
    idx <- match(specimen, dimnames(A)[[3]])
    if (is.na(idx)) stop("Specimen '", specimen, "' not found.", call. = FALSE)
  } else {
    idx <- specimen
  }

  xy <- A[, , idx]
  main_label <- dimnames(A)[[3]][idx]
  main_title <- if (!is.null(main_label)) main_label else paste("Specimen", idx)

  # Points estimated by impute_landmarks() (attr(A, "imputed"), a p x n
  # logical matrix) are highlighted in red, and points manually adjusted by
  # correct_landmarks() (attr(A, "corrected")) in blue, rather than the
  # usual grey. If a point is both, blue (the more deliberate, later
  # manual decision) takes precedence.
  imputed_full <- attr(A, "imputed")
  imputed_idx <- rep(FALSE, nrow(xy))
  if (!is.null(imputed_full) && nrow(imputed_full) == p && ncol(imputed_full) == dim(A)[3]) {
    imputed_idx <- imputed_full[, idx]
  }
  corrected_full <- attr(A, "corrected")
  corrected_idx <- rep(FALSE, nrow(xy))
  if (!is.null(corrected_full) && nrow(corrected_full) == p && ncol(corrected_full) == dim(A)[3]) {
    corrected_idx <- corrected_full[, idx]
  }

  # Landmarks implicated by a failed correct_landmarks(rule =
  # "check_geometry") check for this specimen (orange) -- lowest
  # precedence of the three highlight colours, so a point that is *also*
  # imputed/corrected shows that (arguably more informative, since it is
  # already a known, handled issue) instead.
  geometry_idx <- rep(FALSE, nrow(xy))
  if (!is.null(geometry_check) && isTRUE(highlight_geometry)) {
    sname_check <- dimnames(A)[[3]][idx]
    failing <- geometry_check$check[
      !is.na(geometry_check$ok) & !geometry_check$ok & geometry_check$specimen == sname_check
    ]
    if (length(failing) > 0) {
      pts_map <- .geometry_check_points()
      flagged_pts <- unique(unlist(pts_map[failing], use.names = FALSE))
      flagged_pts <- flagged_pts[flagged_pts >= 1 & flagged_pts <= nrow(xy)]
      geometry_idx[flagged_pts] <- TRUE
    }
  }

  point_col <- rep("grey20", nrow(xy))
  if (isTRUE(highlight_geometry)) {
    point_col[geometry_idx] <- "orange"
  }
  if (isTRUE(highlight_imputed)) {
    point_col[imputed_idx] <- "red"
  }
  if (isTRUE(highlight_corrected)) {
    point_col[corrected_idx] <- "blue"
  }

  bg_img <- NULL
  if (!is.null(background_image)) {
    if (inherits(landmarks, "intrait_gpa")) {
      warning(
        "`background_image` is being overlaid on Procrustes-aligned ",
        "coordinates (`landmarks` is an \"intrait_gpa\" object); the ",
        "photograph will generally not line up with the landmarks unless ",
        "`landmarks` holds the original, un-aligned digitized coordinates.",
        call. = FALSE
      )
    }
    bg_img <- .read_background_image(background_image)
  }

  segments_display <- list(
    Bl  = list(pts = c(1, 2),   col = "firebrick"),
    Bd  = list(pts = c(3, 4),   col = "goldenrod"),
    Hd  = list(pts = c(5, 6),   col = "forestgreen"),
    Eh  = list(pts = c(7, 8),   col = "darkorchid"),
    Mo  = list(pts = c(1, 9),   col = "darkorange"),
    PFi = list(pts = c(10, 11), col = "turquoise4"),
    PFl = list(pts = c(10, 12), col = "navy"),
    Ed  = list(pts = c(13, 14), col = "deeppink"),
    Jl  = list(pts = c(1, 15),  col = "chartreuse4"),
    CPd = list(pts = c(16, 17), col = "grey40"),
    CFd = list(pts = c(18, 19), col = "grey70")
  )

  if (isTRUE(legend) && identical(legend_position, "outside")) {
    old_par <- graphics::par(mar = graphics::par("mar") + c(0, 0, 0, 8))
    on.exit(graphics::par(old_par), add = TRUE)
  }

  if (!is.null(bg_img)) {
    wh <- .background_image_dims(bg_img)
    xlim <- range(c(0, wh[1], xy[, 1]))
    ylim <- range(c(0, wh[2], xy[, 2]))
    dots <- list(...)
    defaults <- list(
      x = xy, asp = 1, type = "n", xlab = "X", ylab = "Y", main = main_title,
      xlim = xlim, ylim = ylim
    )
    do.call(graphics::plot, utils::modifyList(defaults, dots))
    .draw_background_image(bg_img, flip_y = flip_y)
    graphics::points(xy, pch = 19, col = point_col)
  } else {
    graphics::plot(
      xy, asp = 1, pch = 19, col = point_col, xlab = "X", ylab = "Y",
      main = main_title, ...
    )
  }

  for (nm in names(segments_display)) {
    pr <- segments_display[[nm]]$pts
    graphics::segments(xy[pr[1], 1], xy[pr[1], 2], xy[pr[2], 1], xy[pr[2], 2],
                        col = segments_display[[nm]]$col, lwd = 2)
  }

  if (isTRUE(outline)) {
    # Draws a path through `pts`, silently dropping any landmark that is
    # missing (NA) for this specimen rather than leaving a gap: e.g. real
    # T-26 specimens are commonly missing landmark 5, in which case the
    # body outline below falls back to a direct 1-3 segment instead of
    # breaking the line between 1 and 3.
    draw_ref_path <- function(pts, ...) {
      pts <- pts[stats::complete.cases(xy[pts, , drop = FALSE])]
      if (length(pts) > 1) {
        graphics::lines(xy[pts, 1], xy[pts, 2], ...)
      }
    }

    # Body outline (visual reference only, not a FISHMORPH measurement):
    # clockwise around the periphery, closed back to the snout tip (1).
    draw_ref_path(c(1, 5, 3, 16, 18, 19, 17, 4, 6, 1), col = "grey30", lwd = 1)

    ref_col <- "grey85"
    # Horizontal reference line along the belly.
    draw_ref_path(c(9, 8, 11, 4), col = ref_col, lty = 3, lwd = 1)
    # Vertical reference line at eye level.
    draw_ref_path(c(5, 13, 7, 14, 6, 8), col = ref_col, lty = 3, lwd = 1)
    # The eye itself: a circle centred on point 7, with diameter equal to
    # the Ed measurement (distance between points 13 and 14).
    if (all(stats::complete.cases(xy[c(7, 13, 14), , drop = FALSE]))) {
      eye_radius <- sqrt(sum((xy[13, ] - xy[14, ])^2)) / 2
      theta <- seq(0, 2 * pi, length.out = 100)
      graphics::lines(
        xy[7, 1] + eye_radius * cos(theta), xy[7, 2] + eye_radius * sin(theta),
        col = ref_col, lty = 3, lwd = 1
      )
    }
  }

  if (p >= 21) {
    graphics::points(xy[20, 1], xy[20, 2], pch = 17, col = "black")
    graphics::points(xy[21, 1], xy[21, 2], pch = 17, col = "black")
    graphics::segments(xy[20, 1], xy[20, 2], xy[21, 1], xy[21, 2], col = "black", lty = 2)
  }

  if (isTRUE(labels)) {
    graphics::text(xy, labels = seq_len(nrow(xy)), pos = 3, cex = 0.7)
  }
  if (isTRUE(legend)) {
    legend_labels <- names(segments_display)
    legend_cols <- vapply(segments_display, function(s) s$col, character(1))
    legend_lwd <- rep(2, length(legend_labels))
    legend_pch <- rep(NA, length(legend_labels))
    if (isTRUE(highlight_geometry) && any(geometry_idx)) {
      legend_labels <- c(legend_labels, "Geometry check flagged")
      legend_cols <- c(legend_cols, "orange")
      legend_lwd <- c(legend_lwd, NA)
      legend_pch <- c(legend_pch, 19)
    }
    if (isTRUE(highlight_imputed) && any(imputed_idx)) {
      legend_labels <- c(legend_labels, "Imputed landmark")
      legend_cols <- c(legend_cols, "red")
      legend_lwd <- c(legend_lwd, NA)
      legend_pch <- c(legend_pch, 19)
    }
    if (isTRUE(highlight_corrected) && any(corrected_idx)) {
      legend_labels <- c(legend_labels, "Corrected landmark")
      legend_cols <- c(legend_cols, "blue")
      legend_lwd <- c(legend_lwd, NA)
      legend_pch <- c(legend_pch, 19)
    }
    if (identical(legend_position, "outside")) {
      graphics::legend(
        x = graphics::par("usr")[2], y = graphics::par("usr")[4], xpd = TRUE,
        legend = legend_labels, col = legend_cols, lwd = legend_lwd, pch = legend_pch,
        bty = "n", cex = 0.7, xjust = 0, yjust = 1
      )
    } else {
      graphics::legend(
        legend_position, legend = legend_labels, col = legend_cols,
        lwd = legend_lwd, pch = legend_pch, bty = "n", cex = 0.7, ncol = 2
      )
    }
  }
  invisible(xy)
}
