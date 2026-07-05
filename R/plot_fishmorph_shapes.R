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
#' @param color Colour used for every specimen's points and outline.
#'   Defaults to `"steelblue4"`.
#' @param alpha Transparency (`0`-`1`) applied to `color`, so that
#'   overlapping specimens read as a denser cloud rather than a solid
#'   mass. Defaults to `0.15`.
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
#'   [morpho_space()]/[trait_space()] (ordination-based, rather than
#'   shape-outline-based, view of group-level variability)
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' plot_fishmorph_shapes(fish, species = "Gobio occitaniae")
#'
#' # or by an explicit list of individuals:
#' some_fish <- fish$metadata$individual[1:5]
#' plot_fishmorph_shapes(fish, individuals = some_fish)
#'
#' @export
plot_fishmorph_shapes <- function(landmarks, species = NULL, individuals = NULL,
                                   align = TRUE, color = "steelblue4", alpha = 0.15, ...) {
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

  draw_col <- grDevices::adjustcolor(color, alpha.f = alpha)

  draw_ref_path <- function(xy, pts) {
    pts <- pts[stats::complete.cases(xy[pts, , drop = FALSE])]
    if (length(pts) > 1) graphics::lines(xy[pts, 1], xy[pts, 2], col = draw_col, lwd = 1)
  }

  for (xy in shapes) {
    show_pt <- rep(TRUE, nrow(xy))
    show_pt[intersect(c(20, 21), seq_len(nrow(xy)))] <- FALSE
    complete_pt <- stats::complete.cases(xy) & show_pt
    graphics::points(xy[complete_pt, , drop = FALSE], pch = 19, cex = 0.6, col = draw_col)
    draw_ref_path(xy, outline_pts)
  }

  invisible(shapes)
}
