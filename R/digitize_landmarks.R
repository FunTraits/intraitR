#' Interactively digitize landmarks from specimen photographs
#'
#' A convenience wrapper around [geomorph::digitize2d()] for point-and-click
#' digitization of two-dimensional landmarks directly from specimen
#' photographs, following either the fixed 21/22-point FISHMORPH
#' digitization scheme (Brosse et al., 2021; see [plot_fishmorph_points()])
#' or a user-specified number of generic landmarks. Digitized coordinates
#' are written to a `tpsDig`-format file and immediately re-read with
#' [read_tps()], so the result is a ready-to-use `"intrait_landmarks"`
#' object.
#'
#' @param images Character vector of paths to `.jpg`/`.jpeg` specimen
#'   photographs (one file per specimen), passed on to
#'   [geomorph::digitize2d()] as its `filelist` argument. `geomorph`'s
#'   underlying reader ([jpeg::readJPEG()]) only supports JPEG images;
#'   convert other formats (PNG, TIFF, etc.) to `.jpg` first.
#' @param scheme Character, one of `"fishmorph"` (the fixed FISHMORPH
#'   scheme of Brosse et al., 2021: 21 landmarks, or 22 with `curvature =
#'   TRUE`) or `"generic"` (any fixed number of landmarks, set via
#'   `n_landmarks`).
#' @param n_landmarks Integer, number of landmarks to digitize per
#'   specimen when `scheme = "generic"`. Ignored (and set automatically to
#'   21 or 22) when `scheme = "fishmorph"`.
#' @param curvature Logical, digitize the optional 22nd FISHMORPH
#'   body-curvature correction point in addition to the 21 fixed points
#'   (see [fishmorph_segments()]). Ignored when `scheme = "generic"`.
#' @param tpsfile Path to the `tpsDig`-format file that will store the
#'   digitized coordinates (see [read_tps()]); required, since it is also
#'   how this function retrieves the digitized data back from
#'   [geomorph::digitize2d()].
#' @param metadata Optional `data.frame` of specimen-level metadata,
#'   passed on to [read_tps()] after digitizing (see its `metadata`
#'   argument).
#' @param ... Further arguments passed on to [geomorph::digitize2d()], for
#'   example `verbose = FALSE` for uninterrupted (non-prompted) digitizing
#'   of each landmark, or `scale`/`MultScale` to additionally digitize a
#'   scale bar per image via `digitize2d()`'s own mechanism (not needed
#'   for `scheme = "fishmorph"`, whose embedded scale-bar landmarks are
#'   handled separately by [fishmorph_segments()]). Do not pass
#'   `filelist`, `nlandmarks`, or `tpsfile` here; use the dedicated
#'   arguments above instead.
#'
#' @return An object of class `"intrait_landmarks"` (see [read_tps()]),
#'   built from the coordinates written to `tpsfile` by
#'   [geomorph::digitize2d()].
#'
#' @details
#' This function requires an interactive graphics device (it calls
#' [geomorph::digitize2d()], which in turn uses [graphics::locator()]) and
#' cannot be used non-interactively — e.g. via `Rscript`, inside a knitted
#' vignette, or inside automated tests — where it stops with an
#' informative error instead of hanging.
#'
#' For the FISHMORPH scheme, digitize landmarks 1 to 21 (or 1 to 22 with
#' `curvature = TRUE`) in the exact anatomical order shown by
#' [plot_fishmorph_points()] (points 20-21 are the embedded scale bar, used
#' by [fishmorph_segments()] to convert pixel distances to centimetres via
#' its own `scale_cm` argument — no separate scale-bar step is requested
#' here). Digitizing points out of order silently produces wrong
#' measurements downstream in [fishmorph_segments()]; always spot-check
#' immediately after digitizing with [plot_fishmorph_points()] on the
#' resulting object, and consider [detect_outliers()] across a full batch
#' once Procrustes-aligned.
#'
#' This wrapper relies on [geomorph::digitize2d()]'s `filelist`,
#' `nlandmarks`, and `tpsfile` arguments; if a future `geomorph` release
#' renames these, digitize directly with [geomorph::digitize2d()] and
#' import the resulting file with [read_tps()] instead.
#'
#' [geomorph::digitize2d()] checks for an existing file of the same name
#' as `tpsfile` in the current working directory to decide whether to
#' start a fresh digitizing session or resume an interrupted one; use a
#' `tpsfile` name not already present in the working directory for a new
#' batch of specimens (an unrelated pre-existing file of that name, from
#' an earlier, differently sized `images` batch, causes
#' `geomorph::digitize2d()` to error with "Filelist not the same length
#' as input TPS file").
#'
#' @references
#' Adams DC, Collyer ML, Kaliontzopoulou A, Baken EK (2024). geomorph:
#' Software for geometric morphometric analyses. R package.
#'
#' Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
#' Villeger S (2021). FISHMORPH: A global database on morphological
#' traits of freshwater fishes. Global Ecology and Biogeography, 30(12),
#' 2330-2336. \doi{10.1111/geb.13395}
#'
#' @seealso [plot_fishmorph_points()], [read_tps()], [fishmorph_segments()],
#'   [detect_outliers()]
#'
#' @examples
#' \dontrun{
#' # FISHMORPH scheme, three photographs, writing a tpsDig file:
#' lm <- digitize_landmarks(
#'   images = c("specimen1.jpg", "specimen2.jpg", "specimen3.jpg"),
#'   scheme = "fishmorph", tpsfile = "specimens.tps"
#' )
#'
#' # Generic 12-landmark scheme:
#' lm <- digitize_landmarks(
#'   images = "specimen1.jpg", scheme = "generic", n_landmarks = 12,
#'   tpsfile = "specimen1.tps"
#' )
#' }
#'
#' @export
#' @importFrom geomorph digitize2d
digitize_landmarks <- function(images, scheme = c("fishmorph", "generic"),
                                n_landmarks = NULL, curvature = FALSE,
                                tpsfile, metadata = NULL, ...) {
  scheme <- match.arg(scheme)
  if (!is.character(images) || length(images) == 0) {
    stop("`images` must be a non-empty character vector of image file paths.", call. = FALSE)
  }
  missing_files <- images[!file.exists(images)]
  if (length(missing_files) > 0) {
    stop("Image file(s) not found: ", paste(missing_files, collapse = ", "), call. = FALSE)
  }
  if (missing(tpsfile) || is.null(tpsfile) || !is.character(tpsfile) || length(tpsfile) != 1) {
    stop(
      "`tpsfile` is required: a single file path where the digitized ",
      "coordinates will be written (and then re-read into an ",
      "\"intrait_landmarks\" object).",
      call. = FALSE
    )
  }

  if (scheme == "fishmorph") {
    nlandmarks <- if (isTRUE(curvature)) 22L else 21L
    if (!is.null(n_landmarks) && n_landmarks != nlandmarks) {
      warning(
        "`n_landmarks` is ignored when `scheme = \"fishmorph\"`; using ",
        nlandmarks, " (set `curvature = TRUE` for 22).",
        call. = FALSE
      )
    }
  } else {
    if (is.null(n_landmarks) || length(n_landmarks) != 1 || n_landmarks < 3) {
      stop("`n_landmarks` must be a single whole number of at least 3 when `scheme = \"generic\"`.", call. = FALSE)
    }
    nlandmarks <- as.integer(n_landmarks)
  }

  if (!interactive()) {
    stop(
      "digitize_landmarks() requires an interactive graphics device (it ",
      "calls geomorph::digitize2d(), which uses graphics::locator()) and ",
      "cannot be run non-interactively (e.g. via Rscript, in a knitted ",
      "vignette, or inside automated tests). Run it directly in an ",
      "interactive R session.",
      call. = FALSE
    )
  }
  if (!requireNamespace("geomorph", quietly = TRUE)) {
    stop("Package \"geomorph\" is required for digitize_landmarks().", call. = FALSE)
  }

  geomorph::digitize2d(
    filelist = images,
    nlandmarks = nlandmarks,
    tpsfile = tpsfile,
    ...
  )

  if (!file.exists(tpsfile)) {
    stop(
      "geomorph::digitize2d() did not produce the expected `tpsfile` ('",
      tpsfile, "'); digitization may have been cancelled.",
      call. = FALSE
    )
  }

  read_tps(tpsfile, specID = "imageID", metadata = metadata)
}
