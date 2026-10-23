# =============================================================================
# intraitR -- the start page of the measuring hub (launch_measure_hub() with no
# photo folder). Choose the photographs (or upload them into a new folder),
# where the species come from, where the measurements are saved, the operator
# and the ruler; or reopen a recent session. "Open" hands the choices back to
# launch_measure_hub(), which starts the hub on the same port; this page
# reloads itself onto it.
#
# Configuration: options(intraitR.hub_start = list(last, recent, title)).
# =============================================================================

library(shiny)
library(bslib)
library(intraitR)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
ns <- asNamespace("intraitR")
IMG_RE <- get(".HUB_IMG_RE", ns)
SC <- getOption("intraitR.hub_start") %||% list()
LAST <- SC$last %||% list()
RECENT <- SC$recent %||% list()
options(shiny.maxRequestSize = 4 * 1024^3)       # photographs, several GB at once

LEVELS <- list("Folder / Sub-folder" = c("Folder", "Sub-folder"),
               "Site / Date" = c("Site", "Date"),
               "Species / Sub-folder" = c("Species", "Sub-folder"))
lev_key <- function(l) {
  hit <- names(LEVELS)[vapply(LEVELS, function(x) identical(x, as.character(l)), TRUE)]
  if (length(hit)) hit else names(LEVELS)[1]
}
sp_mode0 <- if (is.null(LAST$species)) "none" else
  if (identical(LAST$species, "folder")) "folder" else "table"
sp_path0 <- if (identical(sp_mode0, "table") && is.character(LAST$species)) LAST$species else ""

hint <- function(...) tags$p(class = "start-hint", ...)
card_x <- function(title, ...) bslib::card(fill = FALSE, bslib::card_header(title),
                                           bslib::card_body(..., gap = "10px", fillable = FALSE))
path_row <- function(id, label, value, button, placeholder = "")
  div(class = "path-row",
      textInput(id, label, value = value, width = "100%", placeholder = placeholder),
      actionButton(button, "Browse", class = "btn-sm"))

CSS <- tags$style(HTML(paste0(get(".HUB_FISH_CSS", ns), "
  .start-hero { display:grid; grid-template-columns:minmax(0,7fr) minmax(0,5fr); gap:32px;
                align-items:center; background:#fff; border:1px solid var(--fm-line);
                border-radius:0.5rem; padding:28px 32px; margin-bottom:18px; }
  .start-hero h1 { font-size:2.1rem; line-height:1.15; margin:0 0 8px 0; }
  .start-lead { color:var(--fm-muted); max-width:60ch; margin:0; }
  .start-hint { color:var(--fm-muted); font-size:0.86rem; margin:0; }
  .path-row { display:grid; grid-template-columns:minmax(0,1fr) auto; gap:8px; align-items:end; }
  .path-row .form-group { margin-bottom:0; }
  .path-row .btn { margin-bottom:1px; }
  .found { font-size:0.92rem; }
  .found.ok { color:#2f7a4f; } .found.bad { color:#a83a2c; }
  .start-col { display:flex; flex-direction:column; gap:16px; }
  .start-col > .card { margin-bottom:0; }
  .start-open { display:flex; gap:12px; align-items:center; flex-wrap:wrap; }
  .recent { list-style:none; padding:0; margin:0; }
  .recent li { padding:9px 4px; border-bottom:1px solid var(--fm-line); cursor:pointer; }
  .recent li:last-child { border-bottom:none; }
  .recent li:hover, .recent li:focus { background:var(--fm-wash); outline:none; }
  .recent .name { font-weight:500; }
  .recent .where { color:var(--fm-muted); font-size:0.82rem; word-break:break-all; }
  .br-path { display:grid; grid-template-columns:minmax(0,1fr) auto; gap:8px; align-items:center; }
  .br-path .form-group { margin-bottom:0; }
  .br-short { display:flex; gap:6px; flex-wrap:wrap; margin:8px 0; }
  .br-list { list-style:none; padding:0; margin:0; max-height:46vh; overflow:auto;
             border:1px solid var(--fm-line); border-radius:0.375rem; background:#fff; }
  .br-list li { padding:6px 10px; cursor:pointer; border-bottom:1px solid var(--fm-wash);
                display:flex; justify-content:space-between; gap:8px; }
  .br-list li:hover { background:var(--fm-wash); }
  .br-list .n { color:var(--fm-muted); font-size:0.82rem; white-space:nowrap; }
  .br-list .file { color:var(--fm-river); }
  .code-out pre { font-size:0.82rem; white-space:pre-wrap; word-break:break-all; margin:0; }
  @media (max-width: 900px) {
    .start-hero { grid-template-columns:1fr; padding:20px; }
    .home-fish { margin:0 auto; max-width:300px; }
  }
")))
JS <- tags$script(HTML("
  $(document).on('click', '.br-list li', function() {
    Shiny.setInputValue('br_click', {name: String($(this).data('name')),
                                     kind: String($(this).data('kind'))}, {priority: 'event'});
  });
  $(document).on('click keydown', '.recent li', function(e) {
    if (e.type === 'keydown' && e.key !== 'Enter') return;
    Shiny.setInputValue('recent_pick', $(this).data('i'), {priority: 'event'});
  });
  // the start page closes and the hub starts on the same port: wait for the
  // server to go down and come back, then reload onto the hub
  Shiny.addCustomMessageHandler('hub_switch', function(msg) {
    document.body.innerHTML = '<div style=\"font-family:IBM Plex Sans,system-ui,sans-serif;' +
      'padding:56px;color:#1a2a2f\"><h2 style=\"font-weight:600\">' + msg +
      '</h2><p style=\"color:#566a70\">The page reloads by itself in a moment.</p></div>';
    var t0 = Date.now(), down = false;
    var poll = setInterval(function() {
      fetch(location.pathname, {cache: 'no-store'}).then(function(r) {
        if (r.ok && (down || Date.now() - t0 > 6000)) { clearInterval(poll); location.reload(); }
      }).catch(function() { down = true; });
    }, 600);
  });
"))

ui <- bslib::page_navbar(
  title = SC$title %||% "intraitR - measure", theme = Rfishmorph::app_theme(),
  fillable = FALSE, header = tagList(CSS, JS),
  bslib::nav_panel(
    "Start",
    div(class = "start-hero",
        div(tags$h1("Start a measuring session"),
            tags$p(class = "start-lead",
                   "Choose a folder of photographs -- its sub-folders are read too,",
                   "for example one per site and date, or one per species -- and where",
                   "the measurements are saved. Everything can be changed later in Setup.")),
        div(get(".hub_fish_svg", ns)())),
    layout_columns(
      col_widths = c(7, 5), fill = FALSE, style = "align-items:start;",
      div(class = "start-col",
        card_x("Photographs",
               path_row("photo_dir", "Folder of the photographs", LAST$photo_dir %||% "",
                        "br_photo", "/path/to/photographs"),
               uiOutput("found"),
               tags$details(
                 tags$summary("No folder yet? Upload photographs into a new one"),
                 div(style = "margin-top:10px;display:flex;flex-direction:column;gap:8px;",
                     path_row("up_parent", "Create the new folder in", "", "br_up_parent"),
                     textInput("up_name", "Name of the new folder", placeholder = "e.g. T26_20260615"),
                     fileInput("up_files", "Photographs", multiple = TRUE,
                               accept = c("image/jpeg", "image/png", "image/tiff",
                                          ".jpg", ".jpeg", ".png", ".tif", ".tiff")),
                     hint("The photographs are COPIED into the new folder; the originals",
                          "are not touched. A file of the same name already there is left as it is.")))),
        card_x("Species",
               radioButtons("sp_mode", NULL,
                            c("Not known yet" = "none",
                              "One folder per species (the folder names are the species)" = "folder",
                              "From a table: one row per photograph (CSV or Excel)" = "table"),
                            selected = sp_mode0, width = "100%"),
               conditionalPanel(
                 "input.sp_mode == 'table'",
                 path_row("sp_path", "Species table", sp_path0, "br_sp", "/path/to/species.csv"),
                 hint("Columns: `species`, and the photograph as `photo`, `code`, `file` or",
                      "`specimen` (file name, with or without extension)."),
                 uiOutput("sp_found"))),
        card_x("Where the measurements are saved",
               path_row("xlsx_path", "Workbook", LAST$xlsx_path %||% "", "br_xlsx",
                        "chosen from the photograph folder"),
               path_row("journal_dir", "Journal (one line per landmark, written at every save)",
                        LAST$journal_dir %||% "", "br_journal", "next to the workbook"),
               uiOutput("save_state")),
        card_x("Session",
               layout_columns(
                 col_widths = c(4, 4, 4), fill = FALSE,
                 textInput("operator", "Operator", value = LAST$operator %||%
                             tryCatch(unname(Sys.info()[["user"]]), error = function(e) "")),
                 numericInput("ruler_mm", "Ruler 20-21 (mm)", value = LAST$ruler_mm %||% 10,
                              min = 0.01, step = 0.5),
                 selectInput("levels", "The two folder levels are",
                             names(LEVELS), selected = lev_key(LAST$levels %||% LEVELS[[1]]))),
               path_row("mlmorph_dir", "Predictor folder, ml-morph (optional: found automatically)",
                        LAST$mlmorph_dir %||% "", "br_ml")),
        div(class = "start-open",
            actionButton("open", "Open the photographs", class = "btn-primary btn-lg"),
            uiOutput("open_why", inline = TRUE))),
      div(class = "start-col",
        card_x("Recent sessions", uiOutput("recent")),
        card_x("The same session from the console",
               div(class = "code-out", verbatimTextOutput("code")),
               hint("To start straight on these photographs next time, or to keep in a script.")))
    )
  ),
  bslib::nav_spacer(),
  bslib::nav_item(actionButton("quit", "Close", class = "btn-sm btn-outline-danger"))
)

server <- function(input, output, session) {
  rv <- reactiveValues(br_dir = NULL, br_target = NULL, br_mode = "dir", br_ext = NULL,
                       xlsx_auto = !nzchar(LAST$xlsx_path %||% ""),
                       jdir_auto = !nzchar(LAST$journal_dir %||% ""))
  norm <- function(p) if (is.null(p) || !nzchar(trimws(p))) "" else
    normalizePath(path.expand(trimws(p)), winslash = "/", mustWork = FALSE)

  ## ---- the photographs found --------------------------------------------------
  queue <- reactive({
    d <- norm(input$photo_dir)
    if (!nzchar(d) || !dir.exists(d)) return(NULL)
    tryCatch(measure_queue(d), error = function(e) NULL)
  })
  output$found <- renderUI({
    d <- norm(input$photo_dir)
    if (!nzchar(d)) return(hint("Type a path, or Browse."))
    if (!dir.exists(d)) return(tags$p(class = "found bad", "This folder does not exist."))
    q <- queue()
    if (is.null(q) || !nrow(q))
      return(tags$p(class = "found bad",
                    "No photograph here (JPEG, PNG, TIFF), nor in its sub-folders."))
    nf <- length(unique(q$folder[nzchar(q$folder)]))
    tags$p(class = "found ok", sprintf("%d photograph%s%s.", nrow(q), if (nrow(q) > 1) "s" else "",
      if (nf) sprintf(", in %d folder%s (%s%s)", nf, if (nf > 1) "s" else "",
                      paste(utils::head(sort(unique(q$folder[nzchar(q$folder)])), 4), collapse = ", "),
                      if (nf > 4) ", ..." else "") else " directly in this folder"))
  })
  # the default places follow the photograph folder until typed by hand
  observeEvent(input$photo_dir, {
    d <- norm(input$photo_dir); if (!nzchar(d)) return()
    if (isTRUE(rv$xlsx_auto))
      updateTextInput(session, "xlsx_path",
                      value = file.path(dirname(d), "intraitR_landmarks.xlsx"))
    if (isTRUE(rv$jdir_auto))
      updateTextInput(session, "journal_dir", value = file.path(dirname(d), "landmark_journal"))
  }, ignoreInit = FALSE)
  observeEvent(input$xlsx_path, {
    d <- norm(input$photo_dir)
    rv$xlsx_auto <- !nzchar(input$xlsx_path) ||
      identical(norm(input$xlsx_path), norm(file.path(dirname(d), "intraitR_landmarks.xlsx")))
  }, ignoreInit = TRUE)
  observeEvent(input$journal_dir, {
    d <- norm(input$photo_dir)
    rv$jdir_auto <- !nzchar(input$journal_dir) ||
      identical(norm(input$journal_dir), norm(file.path(dirname(d), "landmark_journal")))
  }, ignoreInit = TRUE)
  observeEvent(input$sp_mode, {
    if (identical(input$sp_mode, "folder") && identical(input$levels, names(LEVELS)[1]))
      updateSelectInput(session, "levels", selected = "Species / Sub-folder")
  }, ignoreInit = TRUE)

  output$sp_found <- renderUI({
    p <- norm(input$sp_path)
    if (!nzchar(p)) return(NULL)
    if (!file.exists(p)) return(tags$p(class = "found bad", "File not found."))
    tb <- tryCatch(get(".hub_species_table", ns)(p), error = function(e) e)
    if (inherits(tb, "error")) return(tags$p(class = "found bad", conditionMessage(tb)))
    q <- queue()
    hit <- if (is.null(q)) NA else sum(q$code %in% names(tb))
    tags$p(class = paste("found", if (is.na(hit) || hit > 0) "ok" else "bad"),
           sprintf("%d row(s), %d species%s.", length(tb), length(unique(tb)),
                   if (is.na(hit)) "" else sprintf("; %d of the %d photographs found in it",
                                                   hit, nrow(q))))
  })
  output$save_state <- renderUI({
    j <- norm(input$journal_dir); x <- norm(input$xlsx_path)
    st <- if (nzchar(j) && dir.exists(j) &&
              length(list.files(j, pattern = "\\.tsv$"))) {
      n <- tryCatch(nrow(get(".hub_journal_state", ns)(j)), error = function(e) NA)
      sprintf("An existing journal: %s photograph(s) already measured there; the session continues it.",
              if (is.na(n)) "some" else n)
    } else "New: the journal and the workbook are created at the first save."
    hint(st, if (nzchar(x) && !grepl("\\.xlsx$", x, ignore.case = TRUE))
      tags$b(" The workbook must end in .xlsx."))
  })

  ## ---- what launch_measure_hub() will receive ---------------------------------
  choices <- reactive({
    sp <- switch(input$sp_mode, folder = "folder",
                 table = if (nzchar(norm(input$sp_path))) norm(input$sp_path) else NULL, NULL)
    list(photo_dir = norm(input$photo_dir),
         xlsx_path = if (nzchar(norm(input$xlsx_path))) norm(input$xlsx_path) else NULL,
         journal_dir = if (nzchar(norm(input$journal_dir))) norm(input$journal_dir) else NULL,
         species = sp, operator = trimws(input$operator %||% ""),
         ruler_mm = input$ruler_mm,
         mlmorph_dir = if (nzchar(norm(input$mlmorph_dir))) norm(input$mlmorph_dir) else NULL,
         levels = LEVELS[[input$levels %||% names(LEVELS)[1]]])
  })
  output$code <- renderText({
    c0 <- choices()
    q <- function(x) sprintf('"%s"', x)
    a <- c(q(if (nzchar(c0$photo_dir)) c0$photo_dir else "<folder>"),
           if (!is.null(c0$species)) paste0("species = ", q(c0$species)),
           if (!is.null(c0$xlsx_path) && !isTRUE(rv$xlsx_auto)) paste0("xlsx_path = ", q(c0$xlsx_path)),
           if (!is.null(c0$journal_dir) && !isTRUE(rv$jdir_auto)) paste0("journal_dir = ", q(c0$journal_dir)),
           if (nzchar(c0$operator)) paste0("operator = ", q(c0$operator)),
           if (is.finite(c0$ruler_mm) && c0$ruler_mm != 10) paste0("ruler_mm = ", c0$ruler_mm),
           if (!identical(c0$levels, LEVELS[[1]]))
             sprintf("levels = c(%s)", paste(q(c0$levels), collapse = ", ")),
           if (!is.null(c0$mlmorph_dir)) paste0("mlmorph_dir = ", q(c0$mlmorph_dir)))
    paste0("res <- intraitR::launch_measure_hub(\n  ", paste(a, collapse = ",\n  "), ")")
  })
  problem <- reactive({
    c0 <- choices(); q <- queue()
    if (!nzchar(c0$photo_dir)) return("choose the folder of the photographs")
    if (!dir.exists(c0$photo_dir)) return("the photograph folder does not exist")
    if (is.null(q) || !nrow(q)) return("there is no photograph in this folder")
    if (identical(input$sp_mode, "table") && is.null(c0$species))
      return("choose the species table, or say the species are not known yet")
    if (!is.null(c0$xlsx_path) && !grepl("\\.xlsx$", c0$xlsx_path, ignore.case = TRUE))
      return("the workbook must end in .xlsx")
    if (!is.finite(c0$ruler_mm) || c0$ruler_mm <= 0) return("the ruler length must be positive")
    NULL
  })
  output$open_why <- renderUI({
    p <- problem()
    if (is.null(p)) hint(sprintf("%d photographs, ready.", nrow(queue())))
    else hint(paste0("To open: ", p, "."))
  })
  observeEvent(input$open, {
    p <- problem()
    if (!is.null(p)) { showNotification(paste0("To open: ", p, "."), type = "warning"); return() }
    c0 <- choices()
    # checked here as launch_measure_hub() will check it: an error stays on this page
    chk <- tryCatch({ get(".hub_cfg", ns)(c0); NULL }, error = function(e) conditionMessage(e))
    if (!is.null(chk)) { showNotification(chk, type = "error", duration = 10); return() }
    session$sendCustomMessage("hub_switch", "Opening the photographs...")
    stopApp(c0)
  })
  observeEvent(input$quit, {
    session$sendCustomMessage("hub_switch", "Closed. The R console is free again.")
    stopApp(NULL)
  })

  ## ---- recent sessions -------------------------------------------------------
  output$recent <- renderUI({
    if (!length(RECENT)) return(hint("None yet: the sessions you open appear here."))
    tags$ul(class = "recent", lapply(seq_along(RECENT), function(i) {
      r <- RECENT[[i]]
      tags$li(`data-i` = i, tabindex = 0, title = "Fill the form with this session",
              div(class = "name", basename(r$photo_dir),
                  span(class = "start-hint", style = "display:inline;margin-left:6px;",
                       r$used %||% "")),
              div(class = "where", r$photo_dir))
    }))
  })
  observeEvent(input$recent_pick, {
    r <- RECENT[[as.integer(input$recent_pick)]]; req(r)
    rv$xlsx_auto <- FALSE; rv$jdir_auto <- FALSE
    updateTextInput(session, "photo_dir", value = r$photo_dir)
    updateTextInput(session, "xlsx_path", value = r$xlsx_path %||% "")
    updateTextInput(session, "journal_dir", value = r$journal_dir %||% "")
    m <- if (is.null(r$species)) "none" else if (identical(r$species, "folder")) "folder" else "table"
    updateRadioButtons(session, "sp_mode", selected = m)
    if (m == "table") updateTextInput(session, "sp_path", value = r$species)
    if (!is.null(r$operator)) updateTextInput(session, "operator", value = r$operator)
    if (!is.null(r$ruler_mm)) updateNumericInput(session, "ruler_mm", value = r$ruler_mm)
    if (!is.null(r$levels)) updateSelectInput(session, "levels", selected = lev_key(r$levels))
    updateTextInput(session, "mlmorph_dir", value = r$mlmorph_dir %||% "")
    showNotification(paste("Filled with the session of", basename(r$photo_dir),
                           "-- check, then Open."), duration = 5)
  })

  ## ---- the folder browser (on the R side: a web page cannot read paths) -------
  shortcuts <- function() {
    h <- normalizePath("~", winslash = "/")
    c(Home = h,
      Desktop = file.path(h, "Desktop"), Documents = file.path(h, "Documents"),
      Downloads = file.path(h, "Downloads"),
      stats::setNames(list.dirs(file.path(h, "Library", "CloudStorage"), recursive = FALSE),
                      basename(list.dirs(file.path(h, "Library", "CloudStorage"), recursive = FALSE))),
      `iCloud Drive` = file.path(h, "Library", "Mobile Documents", "com~apple~CloudDocs"),
      if (dir.exists("/Volumes")) stats::setNames(list.dirs("/Volumes", recursive = FALSE),
                                                   basename(list.dirs("/Volumes", recursive = FALSE))),
      if (.Platform$OS.type == "windows")
        stats::setNames(paste0(LETTERS, ":/"), paste0(LETTERS, ":"))[dir.exists(paste0(LETTERS, ":/"))])
  }
  open_browser <- function(target, mode = "dir", ext = NULL, start = NULL) {
    st <- norm(start %||% "")
    if (nzchar(st) && !dir.exists(st)) st <- dirname(st)
    if (!nzchar(st) || !dir.exists(st)) st <- normalizePath("~", winslash = "/")
    rv$br_dir <- st; rv$br_target <- target; rv$br_mode <- mode; rv$br_ext <- ext
    showModal(modalDialog(
      title = if (mode == "dir") "Choose a folder" else "Choose a file",
      div(class = "br-path",
          textInput("br_path", NULL, value = st, width = "100%"),
          actionButton("br_go", "Go", class = "btn-sm")),
      uiOutput("br_short"),
      uiOutput("br_list"),
      size = "l", easyClose = TRUE,
      footer = tagList(modalButton("Cancel"),
                       if (mode == "dir") actionButton("br_choose", "Choose this folder",
                                                      class = "btn-primary"))))
  }
  SHORT <- local({ s <- unlist(shortcuts()); s[!is.na(s) & dir.exists(s)] })
  output$br_short <- renderUI(
    div(class = "br-short", lapply(seq_along(SHORT), function(i)
      actionLink(paste0("brs_", i), names(SHORT)[i], class = "btn btn-sm btn-outline-secondary"))))
  lapply(seq_along(SHORT), function(i) observeEvent(input[[paste0("brs_", i)]], {
    rv$br_dir <- normalizePath(SHORT[[i]], winslash = "/")
    updateTextInput(session, "br_path", value = rv$br_dir)
  }, ignoreInit = TRUE))
  output$br_list <- renderUI({
    d <- rv$br_dir; req(d)
    ds <- tryCatch(list.dirs(d, recursive = FALSE, full.names = TRUE), error = function(e) character(0))
    ds <- sort(ds[!grepl("^[.]", basename(ds))])
    nimg <- function(x) length(tryCatch(list.files(x, pattern = IMG_RE, ignore.case = TRUE),
                                        error = function(e) character(0)))
    # photographs in a folder, or else one level down (site/ -> date/ -> photos):
    # never deeper, a home folder would take minutes
    nlab <- function(x) {
      k <- nimg(x)
      if (k) return(sprintf("%d photo%s", k, if (k > 1) "s" else ""))
      sub <- utils::head(tryCatch(list.dirs(x, recursive = FALSE), error = function(e) character(0)), 60)
      k <- sum(vapply(sub, nimg, 1L))
      if (k) sprintf("%d photo%s in sub-folders", k, if (k > 1) "s" else "") else NULL
    }
    here <- nimg(d)
    fs <- if (identical(rv$br_mode, "file")) {
      f <- tryCatch(list.files(d, full.names = TRUE), error = function(e) character(0))
      f <- f[!dir.exists(f)]
      if (length(rv$br_ext)) f[grepl(paste0("\\.(", paste(rv$br_ext, collapse = "|"), ")$"),
                                    f, ignore.case = TRUE)] else f
    } else character(0)
    tagList(
      hint(if (identical(rv$br_mode, "dir"))
             sprintf("%d photograph(s) directly in this folder, %d sub-folder(s).", here, length(ds))
           else "Click a file to choose it."),
      tags$ul(class = "br-list",
        if (dirname(d) != d) tags$li(`data-name` = "..", `data-kind` = "up", span("↑ Up one level")),
        lapply(ds, function(x) tags$li(`data-name` = basename(x), `data-kind` = "dir",
                                       span(paste0(basename(x), "/")),
                                       span(class = "n", if (identical(rv$br_mode, "dir")) nlab(x)))),
        lapply(fs, function(x) tags$li(`data-name` = basename(x), `data-kind` = "file",
                                       span(class = "file", basename(x)))),
        if (!length(ds) && !length(fs)) tags$li(span(class = "n", "(nothing to show here)"))))
  })
  observeEvent(input$br_go, {
    p <- norm(input$br_path)
    if (dir.exists(p)) rv$br_dir <- p else showNotification("No such folder.", type = "warning")
  })
  observeEvent(input$br_click, {
    k <- input$br_click
    if (identical(k$kind, "up")) rv$br_dir <- dirname(rv$br_dir)
    else if (identical(k$kind, "dir")) rv$br_dir <- file.path(rv$br_dir, k$name)
    else if (identical(k$kind, "file")) {
      updateTextInput(session, rv$br_target, value = file.path(rv$br_dir, k$name))
      removeModal(); return()
    }
    updateTextInput(session, "br_path", value = rv$br_dir)
  })
  observeEvent(input$br_choose, {
    updateTextInput(session, rv$br_target, value = rv$br_dir); removeModal()
  })
  observeEvent(input$br_photo, open_browser("photo_dir", start = input$photo_dir))
  observeEvent(input$br_up_parent, open_browser("up_parent", start = input$up_parent))
  observeEvent(input$br_sp, open_browser("sp_path", "file", c("csv", "xlsx", "xls"),
                                         start = if (nzchar(input$sp_path)) input$sp_path else input$photo_dir))
  observeEvent(input$br_xlsx, open_browser("xlsx_path", "file", "xlsx", start = input$xlsx_path))
  observeEvent(input$br_journal, open_browser("journal_dir", start = input$journal_dir))
  observeEvent(input$br_ml, open_browser("mlmorph_dir", start = input$mlmorph_dir))

  ## ---- upload into a new folder ----------------------------------------------
  observeEvent(input$up_files, {
    f <- input$up_files; req(nrow(f))
    parent <- norm(input$up_parent); nm <- trimws(input$up_name %||% "")
    if (!nzchar(parent) || !dir.exists(parent)) {
      showNotification("Choose first where to create the new folder.", type = "warning", duration = 8)
      return() }
    if (!nzchar(nm) || grepl("[/\\\\:]", nm)) {
      showNotification("Give the new folder a name (no slash).", type = "warning", duration = 8)
      return() }
    dest <- file.path(parent, nm)
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    notimg <- !grepl(IMG_RE, f$name, ignore.case = TRUE)
    to <- file.path(dest, basename(f$name))
    exist <- file.exists(to)
    cp <- !notimg & !exist
    done <- if (any(cp)) file.copy(f$datapath[cp], to[cp]) else logical(0)
    updateTextInput(session, "photo_dir", value = dest)
    showNotification(sprintf("%d photograph(s) copied into %s%s%s.", sum(done), dest,
                             if (any(exist & !notimg)) sprintf("; %d already there, left as they were", sum(exist & !notimg)) else "",
                             if (any(notimg)) sprintf("; %d file(s) that are not photographs ignored", sum(notimg)) else ""),
                     duration = 10)
  })
}

shinyApp(ui, server)
