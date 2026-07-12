#' Overlay the body shape of every specimen in a species or a set of individuals
#'
#' Superimposes the FISHMORPH-scheme landmark configurations -- points and
#' body outline only, no landmark numbers, measurement segments, eye, or
#' internal reference lines -- of every specimen belonging to a given
#' species, or of an explicit set of individuals, on a single figure, so
#' shape variability within that group can be seen at a glance rather than
#' one specimen at a time (as in [plot_fishmorph_points()]).
#'
#' @param landmarks An object of class `"intrait_landmarks"` with at least
#'   21 two-dimensional landmarks digitized following the FISHMORPH scheme
#'   (see [fishmorph_segments()]).
#' @param species Character scalar, a single value of
#'   `landmarks$metadata$species` -- every specimen of that species is
#'   plotted. Exactly one of `species`/`individuals` must be supplied.
#' @param individuals Character vector of individual/specimen identifiers
#'   to plot. Matched against `landmarks$metadata$individual` if that
#'   column exists (so a fish's code selects every digitization of it,
#'   e.g. two rows from `load_t26_saudrune_landmarks("operators")`, one
#'   per operator), and otherwise directly against the specimen
#'   identifiers (`dimnames`). Exactly one of `species`/`individuals`
#'   must be supplied.
#' @param align Logical, centre each specimen's configuration on its own
#'   centroid and rescale it to unit centroid size before overlaying it
#'   (translation and isotropic scale only -- no rotation; see Details).
#'   Defaults to `TRUE`. Set to `FALSE` only when `landmarks` is already
#'   fully comparable across specimens (e.g. Procrustes-aligned output
#'   from [gpa_fish()]); overlaying raw digitized coordinates without
#'   aligning them first would mix genuine shape differences with
#'   differences in each specimen's position/scale within its own
#'   photograph, which are not informative about shape.
#' @param color Colour used for every specimen's points and outline when no
#'   per-group colouring is requested (`color_by`/`operator`), and the
#'   colour every shape reverts to when the number of colour groups exceeds
#'   `max_colors`. Defaults to `"steelblue4"`.
#' @param alpha Transparency (`0`-`1`) applied to the drawing colour(s), so
#'   that overlapping specimens read as a denser cloud rather than a solid
#'   mass. Defaults to `0.15`; raise it when using `color_by`/`operator` so
#'   the individual group colours remain distinguishable.
#' @param color_by Optional, controls per-specimen colouring. `NULL`
#'   (default) draws every shape in `color`. Otherwise one of: a metadata
#'   column name (e.g. `"operator"`, `"species"`), colouring each shape by
#'   that column's value; the special value `"specimen"`, giving every
#'   plotted shape its own colour; or a vector with one value per plotted
#'   specimen (in the plotted order). See `max_colors` for the automatic
#'   fallback to a single colour.
#' @param operator Logical shortcut for `color_by = "operator"`: colour each
#'   shape by the operator who digitized it (requires an `operator` column
#'   in `landmarks$metadata`, as produced by
#'   [load_t26_saudrune_landmarks()] with `source = "operators"`). Cannot be
#'   combined with an explicit `color_by`. Defaults to `FALSE`.
#' @param palette Optional vector of colours to use for the groups defined
#'   by `color_by`/`operator`, at least as many as there are groups. `NULL`
#'   (default) generates evenly spaced, equally saturated HCL hues.
#' @param max_colors Integer. When `color_by`/`operator` yields more than
#'   `max_colors` distinct colour groups, per-group colouring is dropped and
#'   every shape reverts to the single `color` (with a message), so an
#'   overcrowded overlay -- e.g. colouring each of dozens of individuals --
#'   never becomes an illegible rainbow. Defaults to `10`.
#' @param legend Logical, draw a legend mapping groups to colours when
#'   per-group colouring is in effect. Defaults to `TRUE`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns a named list of the (aligned, if
#'   `align = TRUE`) `p x 2` coordinate matrices actually plotted, one per
#'   matched specimen.
#'
#' @details
#' Only each specimen's landmark points and its FISHMORPH body outline
#' (points 1-5-3-16-18-19-17-4-6, closed back to 1 -- the same path drawn
#' by [plot_fishmorph_points()]) are drawn; the 11 coloured measurement
#' segments, eye, internal reference lines, landmark numbers, and scale
#' bar of [plot_fishmorph_points()] are all omitted, since the goal here
#' is a fast visual read of shape variability across many specimens at
#' once rather than a detailed inspection of any one of them. Any
#' landmark missing (`NA`) for a given specimen is silently dropped from
#' that specimen's outline path (as in [plot_fishmorph_points()]), and a
#' specimen's outline is simply not drawn if fewer than two of its
#' outline landmarks are present (its points, if any, are still shown).
#'
#' With `align = TRUE` (the default), each specimen is independently
#' centred on its own centroid and divided by its own centroid size (the
#' root sum of squared landmark distances from that centroid; Bookstein,
#' 1991; Dryden & Mardia, 2016) before being drawn -- the translation and
#' scale steps of a Procrustes superimposition, without the rotation
#' step. Rotation is deliberately not applied here: unlike [gpa_fish()],
#' which estimates the single rotation that jointly minimises squared
#' point-to-point distance across a whole sample -- a well-defined
#' operation only for the full data set being jointly analysed, not for a
#' handful of specimens picked out afterwards for display -- this
#' function has no such joint alignment to fall back on for an arbitrary
#' `species`/`individuals` subset. In practice this means genuine
#' differences in how a fish happened to be oriented on its digitization
#' photograph (tilt, mirroring) will still show up here as apparent shape
#' differences; run [standardize_orientation()] on `landmarks` beforehand
#' to remove that source of noise if it is a concern for the data set at
#' hand, or pass already Procrustes-aligned coordinates with
#' `align = FALSE`.
#'
#' @references
#' Bookstein FL (1991). Morphometric Tools for Landmark Data: Geometry
#' and Biology. Cambridge University Press.
#'
#' Dryden IL, Mardia KV (2016). Statistical Shape Analysis, with
#' Applications in R (2nd ed). Wiley.
#'
#' @seealso [plot_fishmorph_points()] (one specimen at a time, full
#'   anatomical detail), [standardize_orientation()] (fix orientation
#'   before overlaying many specimens), [gpa_fish()] (full Procrustes
#'   alignment, including rotation, across a whole data set),
#'   [shape_space()]/[trait_space()] (ordination-based, rather than
#'   shape-outline-based, view of group-level variability)
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' plot_fishmorph_shapes(fish, species = "Gobio occitaniae")
#'
#' # colour each outline by the operator who digitized it (raise alpha so
#' # the two operators' colours stay legible through the overlap):
#' plot_fishmorph_shapes(fish, species = "Gobio occitaniae",
#'                       operator = TRUE, alpha = 0.4)
#'
#' # or by an explicit list of individuals, one colour each:
#' some_fish <- fish$metadata$individual[1:5]
#' plot_fishmorph_shapes(fish, individuals = some_fish,
#'                       color_by = "specimen", alpha = 0.6)
#'
#' @export
plot_fishmorph_shapes <- function(landmarks, species = NULL, individuals = NULL,
                                   align = TRUE, color = "steelblue4", alpha = 0.15,
                                   color_by = NULL, operator = FALSE, palette = NULL,
                                   max_colors = 10, legend = TRUE, ...) {
  A <- .get_coords(landmarks)
  p <- dim(A)[1]
  if (dim(A)[2] != 2) {
    stop("plot_fishmorph_shapes() requires two-dimensional landmark configurations.", call. = FALSE)
  }
  if (p < 21) {
    stop(
      "`landmarks` must contain at least 21 landmarks digitized following the ",
      "Brosse et al. (2021) FISHMORPH scheme (points 1-21); found ", p, ".",
      call. = FALSE
    )
  }
  if (is.null(species) == is.null(individuals)) {
    stop("Specify exactly one of `species` or `individuals`.", call. = FALSE)
  }

  meta <- .get_metadata(landmarks)
  specimen_names <- dimnames(A)[[3]]

  if (!is.null(species)) {
    if (!is.character(species) || length(species) != 1) {
      stop("`species` must be a single character string.", call. = FALSE)
    }
    if (is.null(meta) || is.null(meta$species)) {
      stop(
        "`species` requires `landmarks$metadata` to have a `species` column, ",
        "as produced by load_t26_saudrune_landmarks()/simulate_fishmorph_points().",
        call. = FALSE
      )
    }
    matched <- which(as.character(meta$species) == species)
    if (length(matched) == 0) {
      available <- sort(unique(as.character(stats::na.omit(meta$species))))
      stop(
        "No specimen found with species = '", species, "'. Available species: ",
        paste(utils::head(available, 10), collapse = ", "),
        if (length(available) > 10) ", ..." else "", ".",
        call. = FALSE
      )
    }
    group_label <- species
  } else {
    if (!is.character(individuals) || length(individuals) == 0) {
      stop("`individuals` must be a non-empty character vector.", call. = FALSE)
    }
    if (!is.null(meta) && !is.null(meta$individual)) {
      found_codes <- unique(as.character(meta$individual))
      unmatched <- setdiff(individuals, found_codes)
      matched <- which(as.character(meta$individual) %in% individuals)
    } else {
      unmatched <- setdiff(individuals, specimen_names)
      matched <- which(specimen_names %in% individuals)
    }
    if (length(matched) == 0) {
      stop("No specimen found matching `individuals`.", call. = FALSE)
    }
    if (length(unmatched) > 0) {
      warning(
        length(unmatched), " of the requested `individuals` were not found and are ",
        "ignored: ", paste(utils::head(unmatched, 5), collapse = ", "),
        if (length(unmatched) > 5) ", ..." else "", ".",
        call. = FALSE
      )
    }
    group_label <- if (length(individuals) == 1) individuals else sprintf("%d individuals", length(individuals))
  }

  outline_pts <- c(1, 5, 3, 16, 18, 19, 17, 4, 6, 1)
  body_pts <- seq_len(min(p, 19))
  if (p >= 22) body_pts <- c(body_pts, 22)

  # Each specimen is optionally reduced to translation- and scale-free
  # (but not rotation-free) coordinates -- see Details -- before being
  # drawn. NA landmarks are preserved as NA throughout (never imputed);
  # they are only dropped, per specimen, when actually drawing points or
  # the outline path.
  shapes <- vector("list", length(matched))
  names(shapes) <- specimen_names[matched]
  for (j in seq_along(matched)) {
    xy <- A[, , matched[j]]
    if (isTRUE(align)) {
      complete <- stats::complete.cases(xy[body_pts, , drop = FALSE])
      pts_ok <- body_pts[complete]
      if (length(pts_ok) >= 2) {
        centroid <- colMeans(xy[pts_ok, , drop = FALSE])
        xy <- sweep(xy, 2, centroid, "-")
        csize <- sqrt(sum(xy[pts_ok, , drop = FALSE]^2))
        if (is.finite(csize) && csize > 0) xy <- xy / csize
      }
    }
    shapes[[j]] <- xy
  }

  all_xy <- do.call(rbind, lapply(shapes, function(s) s[body_pts, , drop = FALSE]))
  rng <- range(all_xy, na.rm = TRUE)
  pad <- 0.08 * diff(rng)
  if (!is.finite(pad) || pad == 0) pad <- 0.1
  lims <- rng + c(-pad, pad)

  axis_lab <- if (isTRUE(align)) {
    c("X (centred, size-standardised)", "Y (centred, size-standardised)")
  } else {
    c("X coordinates", "Y coordinates")
  }

  old_pty <- graphics::par(pty = "s")
  on.exit(graphics::par(old_pty), add = TRUE)

  dots <- list(...)
  main_title <- paste0("Body shape overlay: ", group_label, sprintf(" (n = %d)", length(matched)))
  defaults <- list(
    x = lims, y = lims, type = "n", asp = 1, xlab = axis_lab[1], ylab = axis_lab[2],
    main = main_title, xlim = lims, ylim = lims, xaxt = "n", yaxt = "n", xaxs = "i", yaxs = "i"
  )
  plot_args <- utils::modifyList(defaults, dots)
  do.call(graphics::plot, plot_args)
  tick_xlim <- if (!is.null(dots$xlim)) dots$xlim else lims
  tick_ylim <- if (!is.null(dots$ylim)) dots$ylim else lims
  # Unlike plot_fishmorph_points()/plot_landmarks() (whose [0, 1]
  # digitization convention is already round at quarter increments),
  # these centred/size-standardised coordinates have a data-driven range
  # with no reason to land on round numbers -- pretty_ticks = TRUE places
  # ticks at nice, easy-to-read positions (e.g. 0.25, 0.5) instead.
  .draw_coord_axes(xlim = tick_xlim, ylim = tick_ylim, pretty_ticks = TRUE)

  # ---- Per-specimen colouring -------------------------------------------
  # `color_by` (or the `operator = TRUE` shortcut) maps each plotted shape to
  # a colour: by a metadata column (e.g. operator, species), one colour per
  # specimen ("specimen"), or a user-supplied grouping vector. When the number
  # of distinct groups exceeds `max_colors`, colouring is dropped and every
  # shape reverts to the single `color`, so an overcrowded figure never
  # becomes an illegible rainbow.
  if (isTRUE(operator)) {
    if (!is.null(color_by)) {
      stop("Supply either `operator = TRUE` or `color_by`, not both.", call. = FALSE)
    }
    color_by <- "operator"
  }

  group_vec <- NULL
  legend_title <- NULL
  if (!is.null(color_by)) {
    if (is.character(color_by) && length(color_by) == 1L) {
      if (identical(color_by, "specimen")) {
        group_vec <- factor(names(shapes), levels = names(shapes))
        legend_title <- "Specimen"
      } else if (!is.null(meta) && color_by %in% names(meta)) {
        group_vec <- factor(as.character(meta[[color_by]][matched]))
        legend_title <- color_by
      } else {
        stop(
          "`color_by = \"", color_by, "\"` is neither \"specimen\" nor a column of ",
          "`landmarks$metadata`. Supply \"specimen\", a metadata column name ",
          "(e.g. \"operator\"), or a vector with one value per plotted specimen.",
          call. = FALSE
        )
      }
    } else {
      if (length(color_by) != length(matched)) {
        stop(
          "`color_by` vector must have one value per plotted specimen (",
          length(matched), ").", call. = FALSE
        )
      }
      group_vec <- factor(as.character(color_by))
      legend_title <- "Group"
    }
  }

  use_groups <- !is.null(group_vec)
  if (use_groups && nlevels(group_vec) > max_colors) {
    message(sprintf(
      "color_by produces %d colour groups (> max_colors = %d): reverting to a single colour. Raise `max_colors` to keep per-group colours.",
      nlevels(group_vec), max_colors
    ))
    use_groups <- FALSE
  }

  if (use_groups) {
    k <- nlevels(group_vec)
    if (!is.null(palette)) {
      if (length(palette) < k) {
        stop("`palette` supplies ", length(palette), " colour(s) but ", k,
             " are needed for the requested groups.", call. = FALSE)
      }
      level_solid <- palette[seq_len(k)]
    } else {
      # Evenly spaced, equally saturated HCL hues -- distinct for any k.
      level_solid <- grDevices::hcl(
        h = seq(15, 375, length.out = k + 1)[seq_len(k)], c = 100, l = 60
      )
    }
    names(level_solid) <- levels(group_vec)
    spec_col <- grDevices::adjustcolor(level_solid[as.character(group_vec)], alpha.f = alpha)
  } else {
    spec_col <- rep(grDevices::adjustcolor(color, alpha.f = alpha), length(shapes))
  }

  draw_ref_path <- function(xy, pts, col) {
    pts <- pts[stats::complete.cases(xy[pts, , drop = FALSE])]
    if (length(pts) > 1) graphics::lines(xy[pts, 1], xy[pts, 2], col = col, lwd = 1)
  }

  for (j in seq_along(shapes)) {
    xy <- shapes[[j]]
    show_pt <- rep(TRUE, nrow(xy))
    show_pt[intersect(c(20, 21), seq_len(nrow(xy)))] <- FALSE
    complete_pt <- stats::complete.cases(xy) & show_pt
    graphics::points(xy[complete_pt, , drop = FALSE], pch = 19, cex = 0.6, col = spec_col[j])
    draw_ref_path(xy, outline_pts, spec_col[j])
  }

  if (isTRUE(legend) && use_groups) {
    graphics::legend(
      "topright", legend = levels(group_vec), col = level_solid,
      pch = 19, pt.cex = 1, cex = 0.7, bty = "n", title = legend_title, xpd = NA
    )
  }

  invisible(shapes)
}
