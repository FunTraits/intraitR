# =============================================================================
# measure_hub.R -- the measuring hub: what lies between a folder of photographs
# and a table of measured specimens.
#
#   choose  a folder / sub-folder, a gallery with species and measured state,
#           any subset of photographs
#   measure optional automatic pre-pass (batch_landmarks), then
#           digitize_landmarks() on exactly that subset, in a background R
#           process (the digitizer is itself a Shiny app and cannot run inside
#           another one)
#   check   progress, landmarks and their statuses (journal), FISHMORPH traits,
#           photograph with its landmarks; remeasure one photograph
#
# Generic on purpose: a folder of photographs is all it needs. A data-management
# layer (FishInTrait) passes its own paths, species table, ruler and trait
# function, and gets the same hub.
# =============================================================================

.HUB_DEPS   <- c("shiny", "bslib", "DT", "callr", "httpuv", "jpeg", "png",
                 "writexl", "readxl")
.HUB_IMG_RE <- "\\.(jpe?g|png|gif|bmp|tiff?)$"

# Species table: a data.frame, or the path of a CSV / Excel file, with a column
# naming the photograph (`photo`, `code`, `specimen`, `specimen_code` or `file`;
# with or without extension) and a column `species`. Returns a named character
# vector code -> species.
.hub_species_table <- function(species) {
  d <- species
  # already resolved (launch_measure_hub() checks the table once, then hands
  # the code -> species vector on)
  if (is.character(d) && !is.null(names(d)) && all(nzchar(names(d))))
    return(d)
  if (is.character(d) && length(d) == 1L && file.exists(d)) {
    d <- if (grepl("\\.xlsx?$", d, ignore.case = TRUE)) {
      if (!requireNamespace("readxl", quietly = TRUE))
        stop("Reading an Excel species table needs 'readxl'.", call. = FALSE)
      as.data.frame(readxl::read_excel(d), stringsAsFactors = FALSE)
    } else utils::read.csv(d, stringsAsFactors = FALSE, check.names = FALSE)
  }
  if (!is.data.frame(d))
    stop("`species` must be NULL, \"folder\", a data.frame or the path of a ",
         "CSV / Excel file.", call. = FALSE)
  nm <- tolower(names(d))
  key <- intersect(c("photo", "code", "specimen_code", "specimen", "file",
                     "photo_file"), nm)[1]
  if (is.na(key) || !("species" %in% nm))
    stop("The species table needs a column `species` and a column naming the ",
         "photograph (photo, code, specimen, specimen_code or file).", call. = FALSE)
  k <- tools::file_path_sans_ext(basename(as.character(d[[which(nm == key)[1]]])))
  v <- as.character(d[[which(nm == "species")[1]]])
  ok <- !is.na(k) & nzchar(k)
  stats::setNames(v[ok], k[ok])
}

# One row per photograph code measured in the landmark journal.
.hub_journal_state <- function(journal_dir) {
  cols <- c("code", "n_records", "operator", "timestamp", "n_missing",
            "n_seeded", "has_scale")
  empty <- as.data.frame(stats::setNames(replicate(length(cols), character(0),
                                                   simplify = FALSE), cols))
  # a journal already read (landmark_journal_read()) is used as it is: the hub
  # reads it once per change and derives everything from that one read
  if (is.data.frame(journal_dir)) {
    if (!nrow(journal_dir)) return(empty)
  } else if (is.null(journal_dir) || !dir.exists(journal_dir) ||
             !length(list.files(journal_dir, pattern = "\\.tsv$")))
    return(empty)
  cons <- tryCatch(suppressMessages(suppressWarnings(
    consolidate_landmarks(journal_dir))), error = function(e) NULL)
  if (is.null(cons) || !nrow(cons)) return(empty)
  code <- .hub_code_of(cons)
  ts <- as.character(if (is.null(cons$timestamp)) NA else cons$timestamp)
  op <- as.character(if (is.null(cons$operator)) NA else cons$operator)
  ts <- rep_len(ts, nrow(cons)); op <- rep_len(op, nrow(cons))
  o <- order(code, ts)
  code <- code[o]; ts <- ts[o]; op <- op[o]
  last <- !duplicated(code, fromLast = TRUE)
  out <- data.frame(code = code[last],
                    n_records = as.integer(table(code)[code[last]]),
                    operator = op[last], timestamp = ts[last],
                    n_missing = NA_integer_, n_seeded = NA_integer_,
                    has_scale = NA, stringsAsFactors = FALSE)
  qc <- tryCatch(suppressMessages(suppressWarnings(landmark_journal_qc(journal_dir))),
                 error = function(e) NULL)
  if (!is.null(qc) && nrow(qc)) {
    qcode <- .hub_code_of(qc)
    # several individuals on one photograph: the worst of them
    mx <- function(v) tapply(v, qcode, max)
    m <- match(out$code, names(mx(qc$n_missing)))
    out$n_missing <- as.integer(mx(qc$n_missing)[m])
    out$n_seeded  <- as.integer(mx(qc$n_seeded)[m])
    out$has_scale <- as.logical(tapply(as.logical(qc$has_scale), qcode, all)[m])
  }
  rownames(out) <- NULL
  out
}

# Photograph code of journal / consolidated rows: the file name it recorded,
# else the specimen.
.hub_code_of <- function(d) {
  n <- nrow(d)
  pf <- if (is.null(d$photo_file)) rep(NA_character_, n) else as.character(d$photo_file)
  sp <- if (is.null(d$specimen)) rep(NA_character_, n) else as.character(d$specimen)
  ifelse(!is.na(pf) & nzchar(pf), tools::file_path_sans_ext(basename(pf)), sp)
}

#' Photographs of a folder, with their species and their measured state
#'
#' Lists the photographs under `photo_dir` (sub-folders included), attaches a
#' species to each, and says whether the landmark journal already holds a
#' measurement of it. This is the table [launch_measure_hub()] is built on,
#' exported so that a selection can be prepared or checked at the console.
#'
#' The photograph's file name without its extension is the specimen code, as
#' in [digitize_landmarks()]. Sub-folders are reported as two levels: `folder`
#' (the first one under `photo_dir`) and `subfolder` (the rest of the path), so
#' that a tree such as `site/date/` or `species/` can be browsed level by level.
#'
#' @param photo_dir Root folder of the photographs.
#' @param species Where the species come from. `NULL`: unknown (`NA`).
#'   `"folder"`: the name of the folder holding the photograph (one folder per
#'   species). A data.frame, or the path of a CSV / Excel file, with a column
#'   `species` and a column naming the photograph (`photo`, `code`,
#'   `specimen`, `specimen_code` or `file`, with or without extension). Or a
#'   named character vector, code -> species.
#' @param journal_dir Landmark journal of [digitize_landmarks()], or a journal
#'   already read with [landmark_journal_read()]. `NULL`: no measured state
#'   (everything is "to measure").
#' @param exclude Folders under `photo_dir` to leave out (for example the
#'   output of [batch_landmarks()], whose control thumbnails are images too).
#' @return A data.frame, one row per photograph: `code`, `folder`, `subfolder`,
#'   `species`, `file`, `path` (absolute), `measured`, `n_records` (records in
#'   the journal: individuals, repeats), `operator`, `timestamp`, `n_missing`
#'   (expected points absent, worst individual), `n_seeded` (points never moved
#'   from their seed) and `has_scale`.
#' @seealso [launch_measure_hub()], [consolidate_landmarks()],
#'   [landmark_journal_qc()]
#' @examples
#' d <- file.path(tempdir(), "mq_demo", "Gobio occitaniae")
#' dir.create(d, recursive = TRUE, showWarnings = FALSE)
#' for (f in file.path(d, c("GOBOCC_001.jpg", "GOBOCC_002.jpg"))) writeLines("x", f)
#' measure_queue(dirname(d), species = "folder")[c("code", "species", "measured")]
#' @export
measure_queue <- function(photo_dir, species = NULL, journal_dir = NULL,
                          exclude = NULL) {
  cols <- c("code", "folder", "subfolder", "species", "file", "path", "measured",
            "n_records", "operator", "timestamp", "n_missing", "n_seeded",
            "has_scale")
  if (!is.character(photo_dir) || length(photo_dir) != 1L || !dir.exists(photo_dir))
    stop("`photo_dir` must be an existing folder.", call. = FALSE)
  root <- normalizePath(photo_dir, winslash = "/")
  f <- list.files(root, pattern = .HUB_IMG_RE, ignore.case = TRUE,
                  recursive = TRUE, full.names = TRUE)
  f <- normalizePath(f, winslash = "/")
  # copies of originals kept by the digitizer's "Write the flip into the file"
  f <- f[!grepl("/_(originaux|original_photos)/", f)]
  if (length(exclude)) {
    ex <- normalizePath(exclude[dir.exists(exclude)], winslash = "/")
    for (e in ex) f <- f[!startsWith(f, paste0(e, "/"))]
  }
  f <- sort(f)
  if (!length(f)) {
    out <- as.data.frame(stats::setNames(replicate(length(cols), character(0),
                                                   simplify = FALSE), cols))
    out$measured <- logical(0)
    return(out)
  }
  rel <- substring(f, nchar(root) + 2L)
  rdir <- dirname(rel); rdir[rdir == "."] <- ""
  parts <- strsplit(rdir, "/", fixed = TRUE)
  out <- data.frame(
    code = tools::file_path_sans_ext(basename(f)),
    folder = vapply(parts, function(p) if (length(p)) p[1] else "", ""),
    subfolder = vapply(parts, function(p) if (length(p) > 1L)
      paste(p[-1], collapse = "/") else "", ""),
    species = NA_character_, file = basename(f), path = f,
    stringsAsFactors = FALSE)

  if (identical(species, "folder")) {
    out$species <- ifelse(nzchar(rdir), basename(rdir), NA_character_)
  } else if (!is.null(species)) {
    tab <- .hub_species_table(species)
    out$species <- unname(tab[out$code])
  }

  st <- .hub_journal_state(journal_dir)
  m <- match(out$code, st$code)
  out$measured  <- !is.na(m)
  out$n_records <- ifelse(is.na(m), 0L, as.integer(st$n_records[m]))
  out$operator  <- as.character(st$operator[m])
  out$timestamp <- as.character(st$timestamp[m])
  out$n_missing <- as.integer(st$n_missing[m])
  out$n_seeded  <- as.integer(st$n_seeded[m])
  out$has_scale <- as.logical(st$has_scale[m])
  rownames(out) <- NULL
  out[, cols, drop = FALSE]
}

# Default trait function of the hub: the workbook's measurements sheet ->
# segments -> the nine FISHMORPH ratios, restricted to `codes` (photograph
# codes; individuals of a plate are matched through `photo_file`).
.hub_traits_default <- function(codes, xlsx_path, ruler_mm, scale_action = "pixels") {
  lm <- read_landmarks_xlsx(xlsx_path, sheet = "measurements", n_landmarks = 22L,
                            x_pattern = "{i}_X", y_pattern = "{i}_Y",
                            id_cols = "specimen")
  seg <- fishmorph_segments(lm, scale_cm = ruler_mm / 10, scale_action = scale_action)
  rat <- fishmorph_ratios(seg)
  out <- as.data.frame(rat, stringsAsFactors = FALSE)
  out$specimen_code <- if (!is.null(out$specimen)) as.character(out$specimen) else
    rownames(out)
  segdf <- as.data.frame(seg, stringsAsFactors = FALSE)
  for (cc in setdiff(intersect(c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed",
                                 "Jl", "CPd", "CFd"), names(segdf)), names(out)))
    out[[cc]] <- segdf[[cc]][match(out$specimen_code, rownames(segdf))]
  wb <- as.data.frame(readxl::read_excel(xlsx_path, sheet = "measurements"))
  pc <- .hub_code_of(wb)
  out$photo_code <- pc[match(out$specimen_code, as.character(wb$specimen))]
  out$photo_code[is.na(out$photo_code)] <- out$specimen_code[is.na(out$photo_code)]
  out <- out[out$photo_code %in% codes, , drop = FALSE]
  front <- intersect(c("specimen_code", "photo_code", "scale_units"), names(out))
  out <- out[, c(front, setdiff(names(out), c(front, "specimen"))), drop = FALSE]
  rownames(out) <- NULL
  out
}

# ---- background processes ----------------------------------------------------
.hub_free_port <- function() httpuv::randomPort(min = 3900L, max = 6900L)

.hub_bg_digitizer <- function(args, port, log) {
  callr::r_bg(function(args, port) {
    options(intraitR.background = TRUE)
    do.call(intraitR::digitize_landmarks,
            c(args, list(launch.browser = FALSE, port = port, host = "127.0.0.1")))
  }, args = list(args = args, port = port), stdout = log, stderr = "2>&1",
  supervise = TRUE)
}

.hub_bg_batch <- function(args, log) {
  callr::r_bg(function(args) {
    do.call(intraitR::batch_landmarks, c(args, list(open_qc = FALSE)))
    invisible(NULL)
  }, args = list(args = args), stdout = log, stderr = "2>&1", supervise = TRUE)
}

# SIGINT first: runApp() closes its sessions, which writes the digitizer's
# workbook; then firmly.
.hub_bg_stop <- function(proc, wait = 3000) {
  if (is.null(proc) || !proc$is_alive()) return(invisible(FALSE))
  try(proc$interrupt(), silent = TRUE)
  try(proc$wait(wait), silent = TRUE)
  if (proc$is_alive()) try(proc$kill(), silent = TRUE)
  invisible(TRUE)
}

# Any other Shiny application, started the same way: `fun` is "pkg::name" of a
# launcher that passes `...` to shiny::runApp() (all launchers of intraitR,
# Rfishmorph and FishInTrait do).
.hub_bg_app <- function(fun, args, port, log) {
  callr::r_bg(function(fun, args, port) {
    sp <- strsplit(fun, "::", fixed = TRUE)[[1]]
    f <- getExportedValue(sp[1], sp[2])
    do.call(f, c(args, list(launch.browser = FALSE, port = port, host = "127.0.0.1")))
    invisible(NULL)
  }, args = list(fun = fun, args = args, port = port), stdout = log,
  stderr = "2>&1", supervise = TRUE)
}

# The applications the hub can open, checked once at launch. Each entry is a
# list: `label`, `fun` ("pkg::name"), `args` (list), `place` ("select": a
# button of the Select tab, about the whole data set; "photo": a button on one
# photograph -- the magnifier of the gallery and the Annotated photograph tab --
# which receives its code in the argument named `photo_arg`; "menu": the Apps
# menu only), and optionally `id`, `description`, `warn_measured` (a message
# shown before opening it on a photograph that is already measured).
.hub_apps <- function(apps) {
  if (is.null(apps) || !length(apps)) return(list())
  if (!is.list(apps)) stop("`apps` must be a list of applications.", call. = FALSE)
  out <- lapply(seq_along(apps), function(k) {
    a <- apps[[k]]
    if (!is.list(a) || is.null(a$label) || is.null(a$fun))
      stop("`apps[[", k, "]]` needs at least `label` and `fun`.", call. = FALSE)
    if (!is.character(a$fun) || !grepl("^[A-Za-z][A-Za-z0-9.]*::[A-Za-z.][A-Za-z0-9._]*$", a$fun))
      stop("`apps[[", k, "]]$fun` must be \"package::function\", e.g. ",
           "\"Rfishmorph::launch_fishmorph_space\".", call. = FALSE)
    a$place <- a$place %||% "menu"
    if (!a$place %in% c("select", "photo", "menu"))
      stop("`apps[[", k, "]]$place` must be \"select\", \"photo\" or \"menu\".",
           call. = FALSE)
    if (identical(a$place, "photo") && is.null(a$photo_arg))
      stop("`apps[[", k, "]]`: an application placed on a photograph needs ",
           "`photo_arg`, the argument that receives the photograph's code.", call. = FALSE)
    a$args <- a$args %||% list()
    a$id <- gsub("[^A-Za-z0-9_]", "_", a$id %||% paste0("app", k))
    a
  })
  ids <- vapply(out, `[[`, "", "id")
  if (anyDuplicated(ids)) stop("`apps`: duplicated id(s).", call. = FALSE)
  stats::setNames(out, ids)
}

# A photograph whose prepared image changed (re-cropped, turned) has stale
# predictions in the batch outputs: its rows are removed, so the digitizer does
# not pre-fill it with points placed on the old image.
.hub_purge_batch <- function(batch_root, file) {
  if (is.null(batch_root) || !dir.exists(batch_root)) return(invisible(0L))
  fs <- list.files(batch_root, pattern = "^(landmarks_long|landmarks_wide|summary)\\.csv$",
                   recursive = TRUE, full.names = TRUE)
  n <- 0L
  for (f in fs) {
    d <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE),
                  error = function(e) NULL)
    if (is.null(d) || is.null(d$photo)) next
    bad <- tolower(basename(d$photo)) %in% tolower(file)
    if (any(bad)) {
      utils::write.csv(d[!bad, , drop = FALSE], f, row.names = FALSE)
      n <- n + sum(bad)
    }
  }
  invisible(n)
}

.hub_tail <- function(path, n = 15L) {
  if (is.null(path) || !file.exists(path)) return(character(0))
  x <- tryCatch(readLines(path, warn = FALSE), error = function(e) character(0))
  utils::tail(x, n)
}

#' Choose, digitize and check photographs: the measuring hub
#'
#' Launches the screen that comes before [digitize_landmarks()] and the one that
#' comes after it, for any folder of photographs.
#'
#' 1. *Setup*: paths, operator, ruler, ml-morph folder; the sub-folders with
#'    their numbers of photographs and of measured ones.
#' 2. *Select*: a folder and a sub-folder (for example a site and a date, or a
#'    species), a gallery of their photographs with species and measured state,
#'    a species table; any subset can be picked (a species, the photographs not
#'    yet measured, a few by hand).
#' 3. *Digitize*: optionally the automatic pre-pass [batch_landmarks()] (with
#'    or without a ruler on the photographs), then [digitize_landmarks()] on
#'    exactly the selection. The digitizer runs in a separate R process and
#'    opens in its own browser tab; the hub stays usable.
#' 4. *Results*: progress by folder and species; landmarks and their statuses
#'    (clicked, predicted, seeded...) read from the journal, with its quality
#'    control; the FISHMORPH traits (a specimen without a ruler keeps its nine
#'    ratios, its segments then being in pixels); any photograph with its
#'    landmarks drawn on it, and a *Remeasure* button that reopens the
#'    digitizer on that photograph alone, in `correct` mode. The tables follow
#'    the journal while the digitizer is running.
#'
#' *Finish* (top right) stops the digitizer and the pre-pass if they are
#' running -- the digitizer is interrupted cleanly, which writes its workbook --
#' closes the hub and returns to the console.
#'
#' @param photo_dir Root folder of the photographs (sub-folders included).
#'   `NULL` (default): the hub opens on a start page where the folder is chosen
#'   (or photographs are uploaded into a new one), with the species, where the
#'   measurements are saved, the operator and the ruler -- and the recent
#'   sessions, reopened in one click. *Open another folder*, on the home page
#'   of the hub, comes back to it.
#' @param xlsx_path Workbook written by the digitizer. `NULL`:
#'   `intraitR_landmarks.xlsx` next to `photo_dir`, as [digitize_landmarks()].
#' @param journal_dir Landmark journal. `NULL`: `landmark_journal` next to the
#'   workbook.
#' @param species Where the species come from: `NULL`, `"folder"` (one folder
#'   per species) or a table; see [measure_queue()]. Also a function without
#'   argument returning such a table, called again at every refresh (so that
#'   photographs imported while the hub is open get their species).
#' @param operator Operator identifier (editable in the hub). `NULL`: the
#'   system user.
#' @param ruler_mm Real distance between landmarks 20 and 21, in mm (editable).
#' @param mlmorph_dir,python ml-morph folder and Python interpreter, as in
#'   [digitize_landmarks()] (editable).
#' @param levels Labels of the two folder levels in the hub, e.g.
#'   `c("Site", "Date")` or `c("Species", "Sub-folder")`.
#' @param traits_fun Optional function computing the trait table, called as
#'   `traits_fun(codes, xlsx_path, ruler_mm, scale_action)` with the
#'   photograph codes to keep; it must return a data.frame with a column
#'   `specimen_code` (and may return `photo_code` and `species`). `NULL` uses
#'   [read_landmarks_xlsx()], [fishmorph_segments()] and [fishmorph_ratios()].
#'   This is how a data-management layer attaches its own metadata.
#' @param apps Other applications the hub opens, each in its own background R
#'   process and browser tab, so that the hub is the one place a session
#'   starts from. A list of entries `list(label = , fun = "pkg::launcher",
#'   args = list(...), place = )`, `place` being `"select"` (a button of the
#'   Select tab: importing data, for example), `"photo"` (a button on one
#'   photograph, in the gallery magnifier and in the Annotated photograph tab;
#'   its code is passed in the argument named `photo_arg`; `warn_measured` is
#'   shown first when the photograph is already measured; `close_digitizer =
#'   TRUE` closes an open digitizer first, for an application that rewrites
#'   the workbook; `photo_query`: the URL parameter the application reads the
#'   photograph from, so that an open application is pointed at the next
#'   photograph in its own tab instead of being restarted) or `"menu"` (the
#'   Apps menu only; every non-photograph application is in that menu). The
#'   launcher must pass `...` to [shiny::runApp()]. The hub refreshes its
#'   photographs when one of these applications closes.
#' @param sync_fun Optional function without argument, run by the hub's
#'   *Save to the database* button, when the digitizer closes and at *Finish*:
#'   what a data-management layer needs to register the measurements (for
#'   FishInTrait, linking the workbook's specimens in the project manifest).
#'   It returns a short message, shown in the hub. The landmarks themselves
#'   need no such step: each *Save & next* of the digitizer writes them to the
#'   journal at once.
#' @param default_apps Add the FISHMORPH functional space
#'   ([Rfishmorph::launch_fishmorph_space()]) to the Apps menu.
#' @param title Title shown in the hub.
#' @param launch.browser Where the hub opens; see [digitize_landmarks()].
#' @param ... Passed to [shiny::runApp()].
#' @return Invisibly, when closed with *Finish*, a list: `photo_dir`,
#'   `xlsx_path`, `journal_dir`, `selected` (the selected photographs, as in
#'   [measure_queue()]) and `traits` (the last table computed, or `NULL`).
#'   `NULL` when the hub is stopped otherwise.
#' @seealso [measure_queue()], [digitize_landmarks()], [batch_landmarks()]
#' @examples
#' \dontrun{
#' # one folder per species, a 10 mm ruler on the photographs
#' # no argument: choose everything on the start page
#' res <- launch_measure_hub()
#'
#' res <- launch_measure_hub("~/my_photos", species = "folder",
#'                           levels = c("Species", "Sub-folder"),
#'                           operator = "XX", mlmorph_dir = "~/ml_morph")
#' res$traits
#' }
#' @export
launch_measure_hub <- function(photo_dir = NULL, xlsx_path = NULL, journal_dir = NULL,
                               species = NULL, operator = NULL, ruler_mm = 10,
                               mlmorph_dir = NULL, python = NULL,
                               levels = c("Folder", "Sub-folder"),
                               traits_fun = NULL, apps = NULL, default_apps = TRUE,
                               sync_fun = NULL,
                               title = "intraitR - measure",
                               launch.browser = TRUE, ...) {
  miss <- .HUB_DEPS[!vapply(.HUB_DEPS, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss))
    stop("The measuring hub needs: ", paste(miss, collapse = ", "),
         "\n  install.packages(c(", paste0('"', miss, '"', collapse = ", "), "))",
         call. = FALSE)
  args <- list(photo_dir = photo_dir, xlsx_path = xlsx_path, journal_dir = journal_dir,
               species = species, operator = operator, ruler_mm = ruler_mm,
               mlmorph_dir = mlmorph_dir, python = python, levels = levels,
               traits_fun = traits_fun, apps = apps, default_apps = default_apps,
               sync_fun = sync_fun, title = title, from_start = FALSE)
  # Checked at once when given: an error belongs in the console, not in a page.
  if (!is.null(photo_dir)) .hub_cfg(args)
  dots <- list(...)
  # One port for the whole session: the start page and the hub follow each
  # other on it, and the page in the browser reloads itself onto the next one.
  port <- dots$port %||% .hub_free_port()
  dots$port <- NULL
  browser <- .intrait_browser(launch.browser)
  repeat {
    if (is.null(args$photo_dir)) {
      st <- .hub_run_start(args, port, browser, dots)
      browser <- FALSE
      if (!is.list(st) || is.null(st$photo_dir)) return(invisible(NULL))
      args[names(st)] <- st
      args$from_start <- TRUE
    }
    cfg <- .hub_cfg(args)
    .hub_recent_add(args)
    old <- options(intraitR.hub = cfg)
    res <- tryCatch(do.call(shiny::runApp, c(list(
      system.file("shiny", "measure_hub", package = "intraitR"),
      launch.browser = browser, port = port), dots)),
      finally = options(old))
    browser <- FALSE
    if (is.list(res) && identical(res$restart, "start")) {
      # "Open another folder": back to the start page, the last choices kept
      args$prev_photo_dir <- args$photo_dir
      args$photo_dir <- NULL
      next
    }
    return(invisible(res))
  }
}

# The configuration of a hub session, checked; `args` as in launch_measure_hub().
.hub_cfg <- function(args) {
  photo_dir <- args$photo_dir; xlsx_path <- args$xlsx_path
  journal_dir <- args$journal_dir; species <- args$species
  if (!is.character(photo_dir) || length(photo_dir) != 1L || !dir.exists(photo_dir))
    stop("`photo_dir` must be an existing folder.", call. = FALSE)
  photo_dir <- normalizePath(photo_dir, winslash = "/")
  if (is.null(xlsx_path) || !nzchar(xlsx_path))
    xlsx_path <- file.path(dirname(photo_dir), "intraitR_landmarks.xlsx")
  if (!grepl("\\.xlsx$", xlsx_path, ignore.case = TRUE))
    stop("`xlsx_path` must end in \".xlsx\".", call. = FALSE)
  xlsx_path <- normalizePath(xlsx_path, winslash = "/", mustWork = FALSE)
  if (is.null(journal_dir) || !nzchar(journal_dir))
    journal_dir <- file.path(dirname(xlsx_path), "landmark_journal")
  journal_dir <- normalizePath(journal_dir, winslash = "/", mustWork = FALSE)
  if (is.function(species)) {
    tryCatch(.hub_species_table(species()), error = function(e)
      stop("`species()` must return a species table: ", conditionMessage(e),
           call. = FALSE))
  } else if (!is.null(species) && !identical(species, "folder")) {
    species <- .hub_species_table(species)     # checked now, not in the app
    if (!length(species)) species <- NULL      # an empty table: species unknown
  }
  mlmorph_dir <- args$mlmorph_dir
  if (!is.null(mlmorph_dir) && nzchar(mlmorph_dir) && !dir.exists(mlmorph_dir))
    stop("`mlmorph_dir` not found: ", mlmorph_dir, call. = FALSE)
  if (!is.null(args$traits_fun) && !is.function(args$traits_fun))
    stop("`traits_fun` must be a function.", call. = FALSE)
  if (!is.null(args$sync_fun) && !is.function(args$sync_fun))
    stop("`sync_fun` must be a function.", call. = FALSE)
  ruler_mm <- suppressWarnings(as.numeric(args$ruler_mm))
  if (length(ruler_mm) != 1L || !is.finite(ruler_mm) || ruler_mm <= 0)
    stop("`ruler_mm` must be a single positive number.", call. = FALSE)
  levels <- rep_len(as.character(args$levels %||% c("Folder", "Sub-folder")), 2L)
  apps <- c(args$apps, if (!isFALSE(args$default_apps)) list(list(
    id = "fishmorph_space", label = "FISHMORPH functional space",
    fun = "Rfishmorph::launch_fishmorph_space", place = "menu",
    description = "The 9,556 species of FISHMORPH in their functional space.")))
  apps <- .hub_apps(apps)
  operator <- args$operator
  if (is.null(operator) || !nzchar(operator))
    operator <- tryCatch(unname(Sys.info()[["user"]]), error = function(e) "unknown")
  list(photo_dir = photo_dir, xlsx_path = xlsx_path, journal_dir = journal_dir,
       batch_root = file.path(dirname(xlsx_path), "batch"),
       species = species, levels = levels, operator = operator,
       ruler_mm = ruler_mm,
       mlmorph_dir = if (is.null(mlmorph_dir) || !nzchar(mlmorph_dir)) "" else
         normalizePath(mlmorph_dir, winslash = "/"),
       python = args$python %||% "",
       traits_fun = args$traits_fun %||% .hub_traits_default, apps = apps,
       sync_fun = args$sync_fun, title = args$title %||% "intraitR - measure",
       from_start = isTRUE(args$from_start))
}

# The start page (inst/shiny/hub_start): returns the choices made, a list of
# launch_measure_hub() arguments, or NULL when it was closed without choosing.
.hub_run_start <- function(args, port, browser, dots) {
  last <- args[c("photo_dir", "xlsx_path", "journal_dir", "species", "operator",
                 "ruler_mm", "mlmorph_dir", "python", "levels")]
  last$photo_dir <- args$photo_dir %||% args$prev_photo_dir
  # a species table held in memory cannot be shown as a path
  if (!is.null(last$species) && !(is.character(last$species) && length(last$species) == 1L))
    last$species <- NULL
  old <- options(intraitR.hub_start = list(
    last = last,
    recent = .hub_recent_read(), title = args$title %||% "intraitR - measure"))
  on.exit(options(old), add = TRUE)
  do.call(shiny::runApp, c(list(system.file("shiny", "hub_start", package = "intraitR"),
                                launch.browser = browser, port = port), dots))
}

# Recent sessions, for the start page: the plain arguments of the last few
# sessions (no functions), most recent first, in the user's data folder.
.hub_recent_file <- function() file.path(tools::R_user_dir("intraitR", "data"), "hub_recent.rds")
.hub_recent_read <- function() {
  f <- .hub_recent_file()
  r <- if (file.exists(f)) tryCatch(readRDS(f), error = function(e) list()) else list()
  Filter(function(x) is.list(x) && !is.null(x$photo_dir) && dir.exists(x$photo_dir), r)
}
.hub_recent_add <- function(args) {
  keep <- c("photo_dir", "xlsx_path", "journal_dir", "species", "operator",
            "ruler_mm", "mlmorph_dir", "python", "levels")
  x <- args[keep]
  # a species TABLE given in memory is not remembered; its file path is
  if (!is.null(x$species) && !(is.character(x$species) && length(x$species) == 1L &&
                                 (identical(x$species, "folder") || file.exists(x$species))))
    x$species <- NULL
  if (is.null(x$photo_dir)) return(invisible(NULL))
  x$photo_dir <- normalizePath(x$photo_dir, winslash = "/", mustWork = FALSE)
  x$used <- format(Sys.time(), "%Y-%m-%d %H:%M")
  r <- .hub_recent_read()
  r <- Filter(function(y) !identical(y$photo_dir, x$photo_dir), r)
  r <- c(list(x), r)[seq_len(min(8L, length(r) + 1L))]
  tryCatch({
    dir.create(dirname(.hub_recent_file()), recursive = TRUE, showWarnings = FALSE)
    saveRDS(r, .hub_recent_file())
  }, error = function(e) NULL)
  invisible(NULL)
}

# The profile of a fish with its landmarks and a scale bar (an outline of no
# particular species), shown on the start page and the home page of the hub.
# The dots appear one after the other (CSS), none when less motion is asked.
.hub_fish_svg <- function() {
  tags <- htmltools::tags; HTML <- htmltools::HTML
  # landmarks on the outline: snout, caudal-fin base, body depth above and below,
  # eye, mouth corner, dorsal-fin origin and end, pectoral insertion and tip,
  # caudal peduncle, tips of the caudal lobes
  pts <- rbind(c(40, 96), c(330, 96), c(196, 45), c(196, 146), c(80, 82),
               c(80, 97), c(52, 103), c(166, 50), c(238, 50), c(112, 120),
               c(150, 146), c(326, 84), c(326, 108), c(382, 36), c(384, 158))
  dots <- lapply(seq_len(nrow(pts)), function(i)
    tags$circle(class = "lm", cx = pts[i, 1], cy = pts[i, 2], r = 4.4,
                style = sprintf("animation-delay:%.2fs;", 0.3 + 0.09 * i)))
  HTML(as.character(tags$svg(
    class = "home-fish", viewBox = "20 6 380 186", role = "img",
    `aria-label` = "Outline of a fish with its landmarks and a scale bar",
    # fins first, the body over their bases
    tags$path(class = "fin", d = "M164,52 C170,30 182,16 198,12 C210,22 226,36 240,52 Z"),
    tags$path(class = "fin", d = paste("M322,84 C340,70 360,50 382,36 C374,62 364,84 362,96",
                                       "C364,110 374,132 384,158 C362,142 340,122 322,108 Z")),
    tags$path(class = "fin", d = "M196,141 C204,156 214,164 226,166 C222,154 220,146 220,139 Z"),
    tags$path(class = "fin", d = "M262,131 C268,148 278,156 292,158 C290,146 292,134 296,124 Z"),
    tags$path(class = "body", d = paste(
      "M40,96 C52,74 100,52 170,47 C232,43 292,60 326,84 L326,108",
      "C292,130 232,148 170,146 C104,143 54,124 40,96 Z")),
    tags$path(class = "fin", d = "M108,118 C118,136 132,146 152,148 C142,134 132,122 124,114 Z"),
    tags$path(class = "detail", d = "M102,66 C114,84 114,108 102,128"),
    tags$path(class = "detail lateral", d = "M104,90 C170,84 250,88 324,96"),
    tags$circle(class = "eye", cx = 80, cy = 89, r = 7),
    tags$circle(class = "pupil", cx = 81, cy = 89, r = 2.6),
    tags$path(class = "detail", d = "M40,96 C46,100 50,103 56,103"),
    tags$path(class = "ruler", d = paste("M48,182 L148,182 M48,177 L48,187 M73,179 L73,185",
                                         "M98,177 L98,187 M123,179 L123,185 M148,177 L148,187")),
    tags$circle(class = "lm ruler-pt", cx = 48, cy = 182, r = 3.6, style = "animation-delay:1.85s;"),
    tags$circle(class = "lm ruler-pt", cx = 148, cy = 182, r = 3.6, style = "animation-delay:1.95s;"),
    dots)))
}

.HUB_FISH_CSS <- "
  .home-fish { width:100%; max-width:440px; height:auto; display:block; margin-left:auto; }
  .home-fish .body { fill:#e3eeec; stroke:var(--fm-river); stroke-width:2; }
  .home-fish .fin  { fill:#d4e4e1; stroke:var(--fm-river); stroke-width:1.5; }
  .home-fish .eye  { fill:#fff; stroke:var(--fm-river); stroke-width:1.5; }
  .home-fish .pupil { fill:var(--fm-ink); }
  .home-fish .detail { fill:none; stroke:var(--fm-river); stroke-width:1.2; opacity:.7; }
  .home-fish .lateral { stroke-dasharray:2 5; }
  .home-fish .ruler { fill:none; stroke:var(--fm-ink); stroke-width:1.5; }
  .home-fish .lm { fill:var(--fm-gravel); stroke:#fff; stroke-width:1.2;
                   opacity:0; animation:lm-in .35s ease-out forwards; }
  .home-fish .ruler-pt { fill:var(--fm-ink); }
  @keyframes lm-in { from { opacity:0; r:9; } to { opacity:1; } }
  @media (prefers-reduced-motion: reduce) { .home-fish .lm { animation:none; opacity:1; } }
"
