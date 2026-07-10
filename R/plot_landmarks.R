#' Plot a single landmark configuration
#'
#' Produces a simple two-dimensional scatterplot of one specimen's
#' landmark configuration (raw or Procrustes-aligned), with landmarks
#' optionally numbered, for quality control of digitization and
#' configuration checking.
#'
#' This is a deliberately generic viewer: it makes no assumption about
#' landmark count or anatomical scheme, and works equally well on raw,
#' Procrustes-aligned (`"intrait_gpa"`), or simulated configurations (e.g.
#' the `n_landmarks`-only shapes from [simulate_fish_landmarks()]) -- the
#' natural companion to the package's scheme-agnostic functions
#' ([gpa_fish()], [detect_outliers()], [correct_allometry()],
#' [intraspecific_variability()], [shape_space()]). For data digitized
#' following the FISHMORPH scheme specifically (Brosse et al. 2021, at
#' least 21 points), [plot_fishmorph_points()] is usually more
#' informative -- it colours the 11 measurement segments, draws the body
#' outline/eye/scale bar, and highlights imputed/corrected/geometry-
#' flagged landmarks -- but it requires that scheme and errors on anything
#' with fewer than 21 landmarks; use this function instead for any other
#' landmark configuration, or for a lighter-weight look at FISHMORPH data
#' without that added detail.
#'
#' @param landmarks An object of class `"intrait_landmarks"` or
#'   `"intrait_gpa"`, or a raw `p x k x n` array. Must be two-dimensional.
#' @param specimen Integer index or character specimen identifier of the
#'   configuration to plot. Defaults to `1`.
#' @param labels Logical, label landmarks with their index. Defaults to
#'   `TRUE`.
#' @param background_image Optional path to a `.jpg`/`.jpeg` or `.png`
#'   photograph of the specimen, drawn as a background layer beneath the
#'   landmarks (e.g. to visually check whether a landmark was placed off
#'   the body outline). Only meaningful for raw, un-aligned digitized
#'   coordinates (a warning is issued if `landmarks` is an
#'   `"intrait_gpa"` object, since Procrustes-aligned coordinates will not
#'   line up with the original photograph). Requires the (Suggested)
#'   `jpeg` package for `.jpg`/`.jpeg` files, or `png` for `.png` files.
#'   Defaults to `NULL` (no background).
#' @param flip_y Logical, flip `background_image` vertically before
#'   plotting. Image files are conventionally stored with row 1 at the
#'   top, while digitized landmark coordinates (as read by
#'   [read_tps()]/[geomorph::digitize2d()]) place the origin at the
#'   bottom-left; the default `TRUE` flips the image so it lines up with
#'   the landmarks without needing to pre-flip the file itself. Ignored
#'   when `background_image` is `NULL`.
#' @param ... Further arguments passed to [graphics::plot()].
#'
#' @return Invisibly returns the `p x 2` matrix of coordinates plotted.
#'
#' @seealso [gpa_fish()], [shape_space()], [plot_fishmorph_points()] (richer
#'   viewer for FISHMORPH-scheme data specifically)
#'
#' @examples
#' fish <- load_t26_saudrune_landmarks()
#' plot_landmarks(fish, specimen = 1)
#'
#' \dontrun{
#' # Overlay the original photograph (requires the "jpeg" package and a
#' # photograph in the same pixel coordinate system as `fish`'s landmarks):
#' plot_landmarks(fish, specimen = 1, background_image = "specimen1.jpg")
#' }
#'
#' @export
plot_landmarks <- function(landmarks, specimen = 1, labels = TRUE,
                            background_image = NULL, flip_y = TRUE, ...) {
  A <- .get_coords(landmarks)
  if (dim(A)[2] != 2) {
    stop("plot_landmarks() currently supports two-dimensional landmark configurations only.", call. = FALSE)
  }

  if (is.character(specimen)) {
    idx <- match(specimen, dimnames(A)[[3]])
    if (is.na(idx)) stop("Specimen '", specimen, "' not found.", call. = FALSE)
  } else {
    idx <- specimen
    if (idx < 1 || idx > dim(A)[3]) stop("`specimen` index out of range.", call. = FALSE)
  }

  xy <- A[, , idx]
  main_label <- dimnames(A)[[3]][idx]
  main_title <- if (!is.null(main_label)) main_label else paste("Specimen", idx)

  if (!is.null(background_image)) {
    if (inherits(landmarks, "intrait_gpa")) {
      warning(
        "`background_image` is being overlaid on Procrustes-aligned ",
        "coordinates (`landmarks` is an \"intrait_gpa\" object); the ",
        "photograph will generally not line up with the landmarks unless ",
        "`landmarks` holds the original, un-aligned digitized coordinates ",
        "(e.g. from read_tps() or load_t26_saudrune_landmarks()).",
        call. = FALSE
      )
    }
    img <- .read_background_image(background_image)
    wh <- .background_image_dims(img)
    # Plot region covers the full photograph, padded to also include any
    # landmark that happens to fall outside it (e.g. a coordinate-system
    # mismatch worth spotting rather than silently clipping).
    xlim <- range(c(0, wh[1], xy[, 1]))
    ylim <- range(c(0, wh[2], xy[, 2]))
    dots <- list(...)
    defaults <- list(
      x = xy, asp = 1, type = "n", xlab = "X", ylab = "Y", main = main_title,
      xlim = xlim, ylim = ylim
    )
    do.call(graphics::plot, utils::modifyList(defaults, dots))
    .draw_background_image(img, flip_y = flip_y)
    graphics::points(xy, pch = 19)
  } else {
    graphics::plot(
      xy, asp = 1, pch = 19, xlab = "X", ylab = "Y",
      main = main_title, ...
    )
  }
  if (isTRUE(labels)) {
    graphics::text(xy, labels = seq_len(nrow(xy)), pos = 3, cex = 0.8, col = "steelblue4")
  }
  invisible(xy)
}
