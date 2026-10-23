#' Digitize the FISHMORPH reference workbook
#'
#' Opens the landmark digitizer of [digitize_landmarks()] on the FISHMORPH
#' reference workbook (`FISHMORPH_PUBLI_*.xlsx`) instead of a campaign photo
#' folder. It replaces `Rfishmorph::launch_fishmorph_digitizer()`: the same
#' three queues, the same sheets, the same journal keys -- and the
#' application, the conventions checked on save, the ml-morph prediction and the
#' append-only journal of the campaign digitizer, so the two kinds of work no
#' longer run on two separately maintained tools.
#'
#' @section The three queues:
#' * `"reconstruct"`: species WITHOUT landmarks, WITH segments and a
#'   photograph. Once the axis (1, then 2, with the hinges 22/24 on a curved
#'   fish) is placed, every landmark is seeded at the species' MEASURED
#'   proportions -- its published segments -- rather than at the median
#'   FISHMORPH proportions, so most of the work is checking.
#' * `"correct"`: rows ALREADY landmarked, on the landmark sheet or on the
#'   new-specimen sheet; their points are reloaded, to be reviewed and moved.
#' * `"new"`: the photographs of `new_photo_dir`, one entry per photograph,
#'   written to `new_sheet` (species name typed in the *Species* field, scale
#'   bar 20-21 optional).
#'
#' @section What is written where:
#' Every save is appended to the journal FIRST (the source of truth, read by
#' [landmark_journal_read()] and [consolidate_landmarks()] together with the
#' journals written by the old Rfishmorph digitizer), then to the working
#' copy of the workbook (`out_path`), edited in place through openxlsx and
#' written atomically every `xlsx_flush_every` records. The journal `row_key`
#' is the species name (`"reconstruct"`, `"correct"`) or the photograph file
#' name (`"new"`), as before, so the history of a species continues across the
#' two tools. The quality score is on the common scale, 1 (unusable) to
#' 5 (excellent), empty when not scored.
#'
#' @param xlsx_path The FISHMORPH workbook (sheets `seg_sheet` and `lm_sheet`).
#' @param photo_dir Folder of the species photographs.
#' @param out_path Working copy that is written. `NULL` (default): `xlsx_path`
#'   itself when its name ends in `_reconstructed.xlsx`, otherwise
#'   `<name>_reconstructed.xlsx`, created from `xlsx_path` if absent.
#' @param seg_sheet,lm_sheet,new_sheet Sheet names: segments, landmarks, and the
#'   new specimens (created with the header of `lm_sheet` when absent).
#' @param new_photo_dir Folder of the new photographs (the `"new"` queue).
#' @param ruler_mm Real length (mm) of the scale bar 20-21, `"new"` queue.
#' @param journal_dir Journal folder. Default: `landmark_journal` beside the
#'   workbook -- the folder the old digitizer used, so both histories are read
#'   together.
#' @param operator Operator identifier (`NULL`: the system user).
#' @param xlsx_flush_every Records between two writes of the workbook.
#' @param mode Starting queue; switchable in the app.
#' @param mlmorph_dir,predictor,python ml-morph resources, as in
#'   [digitize_landmarks()].
#' @param launch.browser Where the app opens (see [digitize_landmarks()]).
#' @param ... Passed to [shiny::runApp()].
#' @return The path of the working copy, invisibly. Called for its side effect.
#' @seealso [digitize_landmarks()], [landmark_journal_status()],
#'   [landmark_journal_qc()], [consolidate_landmarks()]
#' @examples
#' \dontrun{
#' digitize_fishmorph_reference(
#'   xlsx_path     = "FishMORPH/FISHMORPH_PUBLI_9556sp_reconstructed.xlsx",
#'   photo_dir     = "FishMORPH/Photos utilisees",
#'   new_photo_dir = "FishMORPH/Photos nouvelles",
#'   operator      = "AT",
#'   mode          = "correct")
#' }
#' @export
digitize_fishmorph_reference <- function(
    xlsx_path,
    photo_dir = file.path(dirname(xlsx_path), "Photos utilisees"),
    out_path = NULL,
    seg_sheet = "Global_segments",
    lm_sheet = "Global_Landmark",
    new_sheet = "new_specimens",
    new_photo_dir = file.path(dirname(xlsx_path), "Photos nouvelles"),
    ruler_mm = 10,
    journal_dir = file.path(dirname(xlsx_path), "landmark_journal"),
    operator = NULL,
    xlsx_flush_every = 10L,
    mode = c("reconstruct", "correct", "new"),
    mlmorph_dir = NULL, predictor = NULL, python = NULL,
    launch.browser = TRUE, ...) {
  mode <- match.arg(mode)
  one <- function(x, what) {
    if (!is.character(x) || length(x) != 1L || is.na(x))
      stop("`", what, "` must be a single path.", call. = FALSE)
    x
  }
  xlsx_path <- one(xlsx_path, "xlsx_path")
  if (!file.exists(xlsx_path))
    stop("Workbook not found: ", xlsx_path, call. = FALSE)
  xlsx_path <- normalizePath(xlsx_path, mustWork = TRUE)
  photo_dir <- one(photo_dir, "photo_dir")
  if (!dir.exists(photo_dir))
    stop("Photograph folder not found: ", photo_dir, call. = FALSE)
  photo_dir <- normalizePath(photo_dir, mustWork = TRUE)
  new_photo_dir <- one(new_photo_dir, "new_photo_dir")
  journal_dir <- one(journal_dir, "journal_dir")
  ruler_mm <- suppressWarnings(as.numeric(ruler_mm))
  if (length(ruler_mm) != 1L || is.na(ruler_mm) || ruler_mm <= 0)
    stop("`ruler_mm` must be a single positive number.", call. = FALSE)
  xlsx_flush_every <- max(1L, suppressWarnings(as.integer(xlsx_flush_every)))
  if (is.na(xlsx_flush_every)) stop("`xlsx_flush_every` must be an integer.", call. = FALSE)
  for (pkg in c("shiny", "openxlsx", "jpeg", "png", "writexl"))
    if (!requireNamespace(pkg, quietly = TRUE))
      stop("Package \"", pkg, "\" is required by digitize_fishmorph_reference(); ",
           "install it with install.packages(\"", pkg, "\").", call. = FALSE)
  if (is.null(out_path))
    out_path <- if (grepl("_reconstructed\\.xlsx$", xlsx_path)) xlsx_path
                else sub("\\.xlsx$", "_reconstructed.xlsx", xlsx_path)

  app_dir <- system.file("shiny", "landmarking_app", package = "intraitR")
  if (!nzchar(app_dir) || !file.exists(file.path(app_dir, "app.R")))
    stop("Could not locate the bundled landmarking app; reinstall intraitR.",
         call. = FALSE)
  worker <- system.file("mlmorph", "predict_new_image.py", package = "intraitR")
  mlmorph_dir <- .resolve_mlmorph_dir(mlmorph_dir)
  if (!interactive())
    stop("digitize_fishmorph_reference() launches an interactive Shiny ",
         "application; run it from an interactive R session.", call. = FALSE)

  cfg <- list(
    target = "fishmorph",
    fm = list(xlsx_path = xlsx_path, out_path = out_path, photo_dir = photo_dir,
              new_photo_dir = new_photo_dir, seg_sheet = seg_sheet,
              lm_sheet = lm_sheet, new_sheet = new_sheet),
    photo_dir = photo_dir, photos = character(0), xlsx_path = out_path,
    journal_dir = journal_dir, operator = operator, mode = mode,
    ruler_mm = ruler_mm, xlsx_flush_every = xlsx_flush_every,
    individuals_per_photo = 1L, provenance_keys = character(0),
    app_version = tryCatch(as.character(utils::packageVersion("intraitR")),
                           error = function(e) "dev"))
  message(sprintf("Workbook: %s\nJournal : %s\nQueue   : %s",
                  out_path, journal_dir, mode))
  .run_digitizer_app(app_dir, cfg, mlmorph_dir = mlmorph_dir, worker = worker,
                     python = python, predictor = predictor,
                     launch.browser = launch.browser, ...)
  invisible(out_path)
}
