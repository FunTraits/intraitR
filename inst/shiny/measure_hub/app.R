# =============================================================================
# intraitR -- the measuring hub (launch_measure_hub()).
#
#   1. Setup     paths, operator, ruler, ml-morph folder; the sub-folders
#   2. Select    folder -> sub-folder -> gallery of the photographs, with their
#                species and what is already measured; pick any subset
#   3. Digitize  optional automatic pre-pass (batch_landmarks), then
#                digitize_landmarks() on EXACTLY the selection
#   4. Results   progress, landmarks + statuses (journal), traits, annotated
#                photograph, remeasure one photograph
#
# The digitizer is itself a Shiny application and cannot run inside this one.
# It is started in a separate R process (callr) on its own port and opens in
# its own browser tab; this hub stays usable and re-reads the journal while the
# operator clicks. The processes belong to the APP, not to a browser session:
# reloading this page does not kill a digitizer in use. They are stopped when
# the hub stops (Finish, or the Stop buttons).
#
# Configuration: options(intraitR.hub = <list>), set by launch_measure_hub().
# =============================================================================

library(shiny)
library(bslib)
library(DT)
library(intraitR)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
ns <- asNamespace("intraitR")
bg_digitizer <- get(".hub_bg_digitizer", ns)
bg_batch     <- get(".hub_bg_batch", ns)
bg_stop      <- get(".hub_bg_stop", ns)
bg_tail      <- get(".hub_tail", ns)
free_port    <- get(".hub_free_port", ns)
bg_app       <- get(".hub_bg_app", ns)
purge_batch  <- get(".hub_purge_batch", ns)

CFG <- getOption("intraitR.hub")
if (is.null(CFG))
  stop("Start the hub with intraitR::launch_measure_hub().", call. = FALSE)
LV <- CFG$levels
addResourcePath("hubimg", CFG$photo_dir)

# the photographs, in the vocabulary of the app: folder -> `site`, sub-folder ->
# `date` (internal names only; the labels shown are CFG$levels)
TOP <- "(top level)"; NONE <- "(none)"
hub_queue <- function(J = CFG$journal_dir) {
  sp <- if (is.function(CFG$species)) tryCatch(CFG$species(), error = function(e) NULL) else
    CFG$species
  q <- measure_queue(CFG$photo_dir, species = sp,
                     journal_dir = J, exclude = CFG$batch_root)
  q$specimen_code <- q$code
  q$site <- ifelse(nzchar(q$folder), q$folder, TOP)
  q$date <- ifelse(nzchar(q$subfolder), q$subfolder, NONE)
  q
}

THEME <- Rfishmorph::app_theme()   # common look of the apps (Rfishmorph)
card_x <- function(title, ...) {
  bslib::card(bslib::card_header(title), bslib::card_body(..., gap = "8px"))
}
hint <- function(...) tags$p(style = "color:var(--fm-muted);font-size:12px;margin:2px 0;", ...)
dt_opts <- list(pageLength = 15, scrollX = TRUE, dom = "ftip")
url_path <- function(...) paste(vapply(c(...), utils::URLencode, "", reserved = TRUE),
                                collapse = "/")

## Background processes: app-level, so that a page reload does not orphan them.
BG <- new.env()
BG$dig <- NULL; BG$dig_log <- NULL; BG$dig_url <- NULL; BG$dig_opened <- FALSE
BG$dig_n <- 0L
BG$batch <- NULL; BG$batch_log <- NULL; BG$batch_dir <- NULL
BG$apps <- list()          # id -> list(proc, url, log, opened, photo, ended)
stop_all <- function() {
  bg_stop(BG$dig); bg_stop(BG$batch)
  for (a in BG$apps) bg_stop(a$proc)
}
shiny::onStop(stop_all)

## The connected applications (argument `apps` of launch_measure_hub()).
APPS <- CFG$apps %||% list()
apps_at <- function(place) Filter(function(a) identical(a$place, place), APPS)
app_buttons <- function(place, prefix, cls = "btn-outline-primary btn-sm") {
  a <- apps_at(place)
  if (!length(a)) return(NULL)
  tagList(lapply(unname(a), function(x)
    div(style = "margin:4px 0;",
        actionButton(paste0(prefix, x$id), x$label, class = paste(cls, "w-100"),
                     title = x$description %||% x$label))))
}

STATUS_COL <- c(clicked = "#16a34a", validated = "#16a34a", adjusted = "#0ea5e9",
                predicted = "#f59e0b", seeded = "#dc2626", derived = "#7c3aed",
                imported = "#6b7280", na = "#9ca3af")

GALLERY_CSS <- tags$style(HTML("
  .gal { display:flex; flex-wrap:wrap; gap:8px; }
  .gal-card { width:170px; border:2px solid var(--fm-line); border-radius:6px; padding:4px;
              cursor:pointer; background:#fff; position:relative; user-select:none; }
  .gal-card img { width:100%; height:110px; object-fit:contain; background:var(--fm-wash); }
  .gal-card.sel { border-color:var(--bs-primary); box-shadow:0 0 0 2px rgba(29,94,107,.25); }
  .gal-card .cap { font-size:11px; line-height:1.25; margin-top:3px; word-break:break-all; }
  .gal-card .sp  { font-style:italic; color:var(--fm-ink); }
  .gal-card .badge-m { position:absolute; top:6px; left:6px; background:#16a34a; color:#fff;
                       font-size:10px; padding:1px 5px; border-radius:8px; }
  .gal-card .zoom { position:absolute; top:4px; right:6px; font-size:14px; color:var(--fm-ink);
                    background:rgba(255,255,255,.8); border-radius:4px; padding:0 4px; }
"))
## ---- Home page -----------------------------------------------------------------
## The profile of a fish with its landmarks: drawn here (an outline of no
## particular species), the dots placed one after the other when the page opens
## -- the only animation of the hub, and none when the system asks for less
## motion.
HOME_FISH <- get(".hub_fish_svg", ns)()

HOME_CSS <- tags$style(HTML(paste0(get(".HUB_FISH_CSS", ns), "
  .home-hero { display:grid; grid-template-columns:minmax(0,7fr) minmax(0,5fr); gap:32px;
               align-items:center; background:#fff; border:1px solid var(--fm-line);
               border-radius:0.5rem; padding:28px 32px; margin-bottom:18px; }
  .home-hero h1 { font-size:2.1rem; line-height:1.15; margin:0 0 8px 0; color:var(--fm-ink); }
  .home-actions .btn-link { padding-left:4px; padding-right:4px; }
  .home-lead { color:var(--fm-muted); max-width:62ch; margin-bottom:18px; }
  .home-progress { height:10px; border-radius:5px; background:var(--fm-line);
                   overflow:hidden; display:flex; margin:6px 0 8px 0; max-width:560px; }
  .home-progress .done { background:var(--bs-primary); }
  .home-state { max-width:62ch; margin-bottom:4px; }
  .home-last { color:var(--fm-muted); font-size:0.9rem; margin-bottom:18px; }
  .home-actions { display:flex; gap:8px; flex-wrap:wrap; }
  .home-folders { display:flex; flex-direction:column; }
  .home-col { display:flex; flex-direction:column; gap:16px; }
  .tab-flow { display:flex; flex-direction:column; gap:14px; }
  .home-col > .card { margin-bottom:0; }
  .home-folder { display:grid; grid-template-columns:minmax(0,1fr) 140px 110px; gap:14px;
                 align-items:center; padding:9px 4px; border-bottom:1px solid var(--fm-line);
                 cursor:pointer; }
  .home-folder:last-child { border-bottom:none; }
  .home-folder:hover { background:var(--fm-wash); }
  .home-folder .name { font-weight:500; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .home-folder .bar { height:6px; border-radius:3px; background:var(--fm-line); overflow:hidden; }
  .home-folder .bar span { display:block; height:100%; background:var(--bs-primary); }
  .home-folder .left { font-size:0.85rem; color:var(--fm-muted); text-align:right;
                       font-variant-numeric:tabular-nums; }
  .home-folder.complete .left { color:#2f7a4f; }
  .home-recent { list-style:none; padding:0; margin:0; }
  .home-recent li { display:flex; justify-content:space-between; gap:10px; padding:7px 0;
                    border-bottom:1px solid var(--fm-line); font-size:0.9rem; }
  .home-recent li:last-child { border-bottom:none; }
  .home-recent .code { font-weight:500; }
  .home-recent .when { color:var(--fm-muted); white-space:nowrap; font-variant-numeric:tabular-nums; }
  .home-steps { list-style:none; counter-reset:step; padding:0; margin:0; }
  .home-steps li { counter-increment:step; display:grid; grid-template-columns:28px 1fr;
                   gap:8px; padding:6px 0; }
  .home-steps li::before { content:counter(step); font-family:'IBM Plex Sans Condensed',sans-serif;
                           font-weight:600; color:var(--fm-river); border:1.5px solid var(--fm-river);
                           border-radius:50%; width:24px; height:24px; display:flex;
                           align-items:center; justify-content:center; font-size:0.8rem; }
  .home-steps a { font-weight:500; }
  .home-steps p { margin:0; color:var(--fm-muted); font-size:0.88rem; }
  @media (max-width: 900px) {
    .home-hero { grid-template-columns:1fr; padding:20px; }
    .home-fish { margin:0 auto; max-width:320px; }
    .home-folder { grid-template-columns:minmax(0,1fr) 90px; }
    .home-folder .left { grid-column:1 / -1; text-align:left; }
  }
")))
HOME_JS <- tags$script(HTML("
  $(document).on('click', '.home-folder', function() {
    Shiny.setInputValue('home_folder', {site: String($(this).data('site')),
                                        date: String($(this).data('date'))},
                        {priority: 'event'});
  });
"))

GALLERY_JS <- tags$script(HTML("
  $(document).on('click', '.gal-card .zoom', function(e) {
    e.stopPropagation();
    Shiny.setInputValue('gal_zoom', $(this).closest('.gal-card').data('code'),
                        {priority: 'event'});
  });
  $(document).on('click', '.gal-card', function() {
    $(this).toggleClass('sel');
    Shiny.setInputValue('gal_toggle',
      {code: String($(this).data('code')), on: $(this).hasClass('sel')},
      {priority: 'event'});
  });
  Shiny.addCustomMessageHandler('gal_sync', function(codes) {
    var s = new Set([].concat(codes || []).map(String));
    $('.gal-card').each(function() {
      $(this).toggleClass('sel', s.has(String($(this).data('code'))));
    });
  });
  // a string: a new tab; {url, name}: the tab of that name, reused if open
  Shiny.addCustomMessageHandler('open_url', function(u) {
    if (typeof u === 'string') window.open(u, '_blank'); else window.open(u.url, u.name);
  });
  // back to the start page, served next on the same port: wait for the
  // server to go down and come back, then reload onto it
  Shiny.addCustomMessageHandler('hub_switch', function(msg) {
    document.body.innerHTML = '<div style=\\'font-family:IBM Plex Sans,system-ui,sans-serif;' +
      'padding:56px;color:#1a2a2f\\'><h2 style=\\'font-weight:600\\'>' + msg +
      '</h2><p style=\\'color:#566a70\\'>The page reloads by itself in a moment.</p></div>';
    var t0 = Date.now(), down = false;
    var poll = setInterval(function() {
      fetch(location.pathname, {cache: 'no-store'}).then(function(r) {
        if (r.ok && (down || Date.now() - t0 > 6000)) { clearInterval(poll); location.reload(); }
      }).catch(function() { down = true; });
    }, 600);
  });
  Shiny.addCustomMessageHandler('hub_closed', function(x) {
    document.body.innerHTML = '<div style=\\'font-family:Inter,sans-serif;padding:40px;\\'>' +
      '<h3>Measuring hub: closed.</h3>' +
      '<p>The R console is free again. This tab can be closed.</p></div>';
    try { window.close(); } catch (e) {}
  });
"))

# =============================================================================
# UI
# =============================================================================

ui <- bslib::page_navbar(
  title = CFG$title,
  theme = THEME, id = "nav", fillable = FALSE,
  header = tagList(GALLERY_CSS, GALLERY_JS, HOME_CSS, HOME_JS),

  bslib::nav_panel(
    "Home", value = "home",
    uiOutput("home_hero"),
    layout_columns(
      col_widths = c(7, 5), fill = FALSE, style = "align-items:start;",
      div(class = "home-col",
        card_x("Folders", uiOutput("home_folders")),
        card_x("A session, step by step",
               tags$ol(class = "home-steps",
                 tags$li(div(actionLink("home_go_project", "Setup"),
                             tags$p("Operator, ruler length, where the predictor lives."))),
                 tags$li(div(actionLink("home_go_select", "Select"),
                             tags$p("Pick a folder, then the photographs to measure."))),
                 tags$li(div(actionLink("home_go_digitize", "Digitize"),
                             tags$p("Optional automatic pre-pass, then the digitizer on the selection."))),
                 tags$li(div(actionLink("home_go_results", "Results"),
                             tags$p("Progress, landmarks and their statuses, traits, annotated photographs.")))))),
      div(class = "home-col",
        card_x("Last saves", uiOutput("home_recent")),
        if (length(Filter(function(a) !identical(a$place, "photo"), APPS)))
          card_x("Other applications",
                 app_buttons("select", "appsh_", "btn-outline-secondary btn-sm"),
                 app_buttons("menu", "appsh_", "btn-outline-secondary btn-sm"))))
  ),

  bslib::nav_panel(
    "1. Setup", value = "project",
    layout_columns(
      col_widths = c(5, 7),
      card_x("Session",
             verbatimTextOutput("paths"),
             textInput("operator", "Operator", value = CFG$operator),
             numericInput("ruler_mm", "Ruler: real distance 20-21 (mm)",
                          value = CFG$ruler_mm, min = 0.01, step = 0.5),
             textInput("mlmorph_dir", "ml-morph folder (empty: auto-detect)",
                       value = CFG$mlmorph_dir, width = "100%"),
             textInput("python", "Python interpreter (empty: default)",
                       value = CFG$python, width = "100%")),
      card_x(paste(LV[1], "and", tolower(LV[2]), "folders"),
             DTOutput("tree_tbl"),
             hint("Click a row to open it in 2. Select."),
             hr(),
             tags$b("Open applications"),
             uiOutput("apps_state"),
             actionButton("apps_stop_all", "Close them all",
                          class = "btn-sm btn-outline-danger"))
    )
  ),

  bslib::nav_panel(
    "2. Select", value = "select",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectInput("site", LV[1], choices = NULL),
        selectInput("date", LV[2], choices = NULL),
        selectizeInput("sp_filter", "Species shown", choices = NULL, multiple = TRUE,
                       options = list(placeholder = "all species")),
        radioButtons("state_filter", "State shown",
                     c("All" = "all", "To measure" = "todo", "Measured" = "done"),
                     inline = TRUE),
        hr(),
        actionButton("sel_visible", "Select all shown", class = "btn-sm"),
        actionButton("sel_todo", "Select shown not measured", class = "btn-sm"),
        actionButton("sel_clear", "Clear selection", class = "btn-sm"),
        hint("Click a photograph to (de)select it; the magnifier enlarges it."),
        hr(),
        uiOutput("sel_summary"),
        if (length(apps_at("select"))) tagList(
          tags$b("Bring in data"),
          app_buttons("select", "apps_"),
          actionButton("sel_refresh", "Refresh the photographs", class = "btn-sm w-100"),
          hint("Each opens in its own tab. Back here, the photographs and species",
               "are re-read when it closes (or with Refresh)."),
          hr()),
        actionButton("go_digitize", "Next: digitize the selection →",
                     class = "btn-primary")
      ),
      layout_columns(
        col_widths = c(12, 12),
        card_x("Species of this selection of folders", DTOutput("sp_tbl"),
               hint("Click a row to show only that species.")),
        card_x("Photographs", uiOutput("gallery"))
      )
    )
  ),

  bslib::nav_panel(
    "3. Digitize", value = "digitize",
    layout_columns(
      col_widths = c(4, 4, 4),
      card_x("Selection",
             uiOutput("dig_selection"),
             hint("The digitizer receives exactly these photographs. In 'new' mode,",
                  "the ones already in the workbook are left out of its queue.")),
      card_x("Automatic pre-pass (optional)",
             checkboxInput("use_batch", "Pre-fill with batch_landmarks()", FALSE),
             conditionalPanel(
               "input.use_batch",
               radioButtons("batch_ruler", "Is there a ruler on the photographs?",
                            c("Yes: detect it (20-21)" = "yes",
                              "No: pixels only" = "no"), inline = FALSE),
               numericInput("batch_max_fish", "Fish per photograph", 1, min = 1, step = 1),
               actionButton("batch_run", "Run the pre-pass", class = "btn-secondary"),
               actionButton("batch_stop", "Stop", class = "btn-sm btn-outline-danger"),
               uiOutput("batch_state"),
               verbatimTextOutput("batch_log"))),
      card_x("Digitizer",
             selectInput("dig_mode", "Mode", c("new", "correct", "repeat")),
             conditionalPanel("input.dig_mode == 'repeat'",
                              numericInput("n_repeats", "Repeats", 3, min = 2, step = 1)),
             numericInput("ind_per_photo", "Individuals per photograph", 1, min = 1, step = 1),
             numericInput("flush_every", "Write the workbook every N saves", 1, min = 1, step = 1),
             hint("1 keeps measurements/landmarks.xlsx current for the Traits tab;",
                  "the journal is written at every save regardless."),
             uiOutput("dig_paths"),
             actionButton("dig_start", "Open the digitizer", class = "btn-primary"),
             actionButton("dig_stop", "Stop the digitizer", class = "btn-outline-danger"),
             actionButton("accept_batch", "Accept the pre-pass without review",
                          class = "btn-outline-warning",
                          title = paste("Record the points of the automatic pre-pass as",
                                        "measurements, without opening the photographs")),
             uiOutput("dig_state"),
             verbatimTextOutput("dig_log"))
    )
  ),

  bslib::nav_panel(
    "4. Results", value = "results",
    div(style = "display:flex;gap:16px;align-items:end;flex-wrap:wrap;",
        radioButtons("res_scope", "Scope",
                     stats::setNames(c("sel", "date", "site", "all"),
                       c("Selection", paste("This", tolower(LV[2])),
                         paste("This", tolower(LV[1])), "Everything")),
                     selected = "date", inline = TRUE),
        actionButton("res_refresh", "Refresh", class = "btn-sm"),
        uiOutput("res_live")),
    navset_card_tab(
      id = "res_tabs",
      # each tab's content in a plain div: in the card's fill layout the table
      # and the plot shared a fixed height, and the table, taller than its
      # share, covered the plot as soon as there were data
      nav_panel("Progress", div(class = "tab-flow",
                DTOutput("prog_tbl"),
                plotOutput("prog_plot", height = "auto"))),
      nav_panel("Landmarks & statuses", div(class = "tab-flow",
                checkboxInput("lm_coords", "Show coordinates", FALSE),
                DTOutput("lm_tbl"),
                hint("Statuses: clicked/validated (checked by the operator), adjusted,",
                     "predicted (model, not yet reviewed), seeded (still at the seed",
                     "position: never checked), derived, na. n_missing counts the",
                     "expected points (1-19, 23) that are absent."),
                downloadButton("lm_dl", "CSV"))),
      nav_panel("Traits", div(class = "tab-flow",
                actionButton("tr_compute", "Compute the FISHMORPH traits", class = "btn-primary"),
                checkboxInput("tr_pixels",
                              "Specimens without a ruler: keep them (segments in pixels, ratios valid)",
                              TRUE),
                hint("The measured specimens of the scope, read from the workbook.",
                     "Segments are in cm from the ruler;",
                     "a specimen without a ruler has its segments in PIXELS",
                     "(column scale_units = px): its nine ratios are exact, its",
                     "absolute lengths are not comparable with the others."),
                uiOutput("tr_msg"),
                DTOutput("tr_tbl"),
                downloadButton("tr_dl", "CSV"))),
      nav_panel("Annotated photograph", div(class = "tab-flow",
                layout_columns(
                  col_widths = c(3, 9),
                  div(selectizeInput("ann_code", "Photograph", choices = NULL),
                      checkboxInput("ann_labels", "Number the landmarks", TRUE),
                      uiOutput("ann_info"),
                      actionButton("remeasure", "Correct the points in the digitizer",
                                   class = "btn-warning btn-sm w-100",
                                   title = "Open this photograph alone in the digitizer, correct mode"),
                      hint("Opens the digitizer on this photograph only, with its saved",
                           "points, in correct mode: move the misplaced ones, save. Back",
                           "here, the drawing and the tables follow."),
                      app_buttons("photo", "appa_", "btn-outline-secondary btn-sm"),
                      tags$div(lapply(names(STATUS_COL), function(s)
                        tags$span(style = sprintf(
                          "display:inline-block;margin:2px 6px 2px 0;font-size:12px;color:%s;",
                          STATUS_COL[[s]]), "● ", s)))),
                  plotOutput("ann_plot", height = "640px")))))
  ),
  bslib::nav_spacer(),
  if (length(Filter(function(a) !identical(a$place, "photo"), APPS)))
    do.call(bslib::nav_menu, c(list(title = "Apps", align = "right"),
      lapply(unname(Filter(function(a) !identical(a$place, "photo"), APPS)), function(a)
        bslib::nav_item(actionLink(paste0("appm_", a$id), a$label,
                                   title = a$description %||% a$label))))),
  bslib::nav_item(uiOutput("db_state", inline = TRUE)),
  bslib::nav_item(actionButton("sync_now", "\U0001F4BE Save to the database",
                               class = "btn-sm btn-outline-success",
                               title = paste("The landmarks are recorded at every 'Save & next'",
                                             "of the digitizer; this re-reads everything and",
                                             "registers the measurements in the project."))),
  bslib::nav_item(actionButton("finish", "Finish", class = "btn-sm btn-outline-danger",
                               title = "Stop the digitizer, close the hub, back to R"))
)

# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {
  rv <- reactiveValues(selected = character(0), tick = 0L, traits = NULL,
                       tr_msg = NULL)

  journal_dir <- function() CFG$journal_dir
  xlsx_path   <- function() CFG$xlsx_path

  # changes of the journal (size + mtime of its files): drives every refresh
  journal_sig <- reactivePoll(3000, session, function() {
    d <- journal_dir()
    if (is.null(d) || !dir.exists(d)) return("")
    f <- list.files(d, pattern = "\\.tsv$", full.names = TRUE)
    if (!length(f)) return("")
    i <- file.info(f)
    paste(sum(i$size), max(as.numeric(i$mtime)))
  }, function() TRUE)

  ## The journal, read ONCE per change (and per file: only the files that
  ## changed are parsed again); the queue, the QC and the tables all derive
  ## from this one read.
  J <- reactive({
    journal_sig(); rv$tick; input$res_refresh
    if (!dir.exists(CFG$journal_dir)) return(NULL)
    tryCatch(suppressWarnings(landmark_journal_read(CFG$journal_dir)),
             error = function(e) NULL)
  })
  all_q <- reactive(hub_queue(J()))

  ## Gallery thumbnails, made on demand (the browser asks only for the cards it
  ## shows) and kept in the user cache: a date of 50 photographs no longer
  ## transfers 50 full-resolution images from a synchronised folder.
  thumb_dir <- file.path(tools::R_user_dir("intraitR", "cache"), "thumbs",
                         substr(gsub("[^A-Za-z0-9]+", "_", CFG$photo_dir), 1, 120))
  thumb_url <- if (requireNamespace("magick", quietly = TRUE))
    session$registerDataObj("thumbs", NULL, function(data, req) {
      qs <- shiny::parseQueryString(req$QUERY_STRING)
      rel <- qs$f %||% ""
      path <- normalizePath(file.path(CFG$photo_dir, rel), winslash = "/", mustWork = FALSE)
      if (!nzchar(rel) || grepl("..", rel, fixed = TRUE) || !file.exists(path) ||
          !startsWith(path, paste0(CFG$photo_dir, "/")))
        return(shiny::httpResponse(404L, "text/plain", "not found"))
      inf <- file.info(path)
      tf <- file.path(thumb_dir, paste0(gsub("[/\\\\]", "__", rel), "_",
                                        as.integer(inf$mtime), "_", inf$size, ".jpg"))
      if (!file.exists(tf)) {
        dir.create(thumb_dir, recursive = TRUE, showWarnings = FALSE)
        ok <- tryCatch({
          # stripped: the browser would otherwise apply the camera's EXIF
          # orientation, and the gallery would not show the raw grid that the
          # digitizer and the measurements use
          im <- magick::image_strip(magick::image_scale(magick::image_read(path), "320"))
          magick::image_write(im, tf, format = "jpeg", quality = 80); TRUE
        }, error = function(e) FALSE)
        if (!ok) return(shiny::httpResponse(302L, "text/plain", "",
                                            headers = list(Location = paste0("hubimg/", rel))))
      }
      shiny::httpResponse(200L, "image/jpeg", readBin(tf, "raw", file.size(tf)),
                          headers = list("Cache-Control" = "max-age=86400"))
    }) else NULL

  tree <- reactive({
    q <- all_q()
    if (!nrow(q)) return(data.frame(site = character(0), date = character(0),
                                    photos = integer(0), measured = integer(0)))
    k <- paste(q$site, q$date, sep = "\r"); u <- !duplicated(k)
    t <- data.frame(site = q$site[u], date = q$date[u],
                    photos = as.integer(table(k)[k[u]]),
                    measured = as.integer(tapply(q$measured, k, sum)[k[u]]),
                    stringsAsFactors = FALSE)
    t[order(t$site, t$date), , drop = FALSE]
  })

  output$paths <- renderText(sprintf(
    "Photographs: %s\nWorkbook   : %s\nJournal    : %s\n%d photograph(s), %d measured",
    CFG$photo_dir, CFG$xlsx_path, CFG$journal_dir, nrow(all_q()), sum(all_q()$measured)))
  output$tree_tbl <- renderDT({
    t <- tree()
    datatable(t, rownames = FALSE, selection = "single", options = dt_opts,
              colnames = c(LV[1], LV[2], "photos", "measured"))
  })
  # open one folder x sub-folder in 2. Select
  go_folder <- function(site, date) {
    if (identical(input$site, site)) {
      updateSelectInput(session, "date", selected = date)
    } else {
      session$userData$pending_date <- date
      updateSelectInput(session, "site", selected = site)
    }
    nav_select("nav", "select")
  }
  observeEvent(input$tree_tbl_rows_selected, {
    r <- tree()[input$tree_tbl_rows_selected, ]
    go_folder(r$site, r$date)
  })

  ## ---- Home ----------------------------------------------------------------------
  # "4 min ago", "yesterday 17:20", "12/09 09:41": a journal timestamp is UTC ISO
  ago <- function(ts) {
    t <- suppressWarnings(as.POSIXct(ts, tz = "UTC",
                                     tryFormats = c("%Y-%m-%dT%H:%M:%OS", "%Y-%m-%d %H:%M:%OS")))
    if (!length(t) || is.na(t)) return("")
    d <- as.numeric(difftime(Sys.time(), t, units = "mins"))
    if (d < 1) "just now" else if (d < 60) sprintf("%d min ago", as.integer(d))
    else if (d < 24 * 60 && format(t, "%Y%m%d", tz = "") == format(Sys.time(), "%Y%m%d"))
      paste("today", format(t, "%H:%M", tz = ""))
    else if (d < 48 * 60) paste("yesterday", format(t, "%H:%M", tz = ""))
    else format(t, "%d/%m/%Y %H:%M", tz = "")
  }
  folder_label <- function(site, date)
    if (identical(date, NONE)) site else paste(site, "/", date)
  # where to resume: the folder of the last save if work is left there, or else
  # the first folder with photographs still to measure
  resume_target <- reactive({
    t <- tree(); q <- all_q()
    left <- t[t$measured < t$photos, , drop = FALSE]
    if (!nrow(left)) return(NULL)
    if (any(q$measured) && any(!is.na(q$timestamp))) {
      i <- order(q$timestamp, decreasing = TRUE, na.last = TRUE)[1]   # ISO: text order = time order
      hit <- left$site == q$site[i] & left$date == q$date[i]
      if (any(hit)) return(left[which(hit)[1], ])
    }
    left[1, ]
  })
  output$home_hero <- renderUI({
    q <- all_q(); n <- nrow(q); m <- sum(q$measured); t <- tree()
    esc <- htmltools::htmlEscape
    where <- tags$p(class = "home-lead", HTML(sprintf(paste(
      "Photographs in <code>%s</code>. Every save of the digitizer goes to the",
      "journal first, then to the workbook."), esc(CFG$photo_dir))))
    title <- if (!n) "No photograph yet"
             else if (m == n) sprintf("All %d photographs are measured", n)
             else sprintf("%d photograph%s left to measure", n - m, if (n - m > 1) "s" else "")
    state <- if (!n)
      tags$p(class = "home-state", paste0(
        "Check the folder in Setup",
        if (length(apps_at("select"))) ", or bring photographs in with the import application" else "",
        "."))
    else {
      left_f <- sum(t$measured < t$photos)
      last <- if (m) q[order(q$timestamp, decreasing = TRUE, na.last = TRUE)[1], ] else NULL
      by <- function(x) if (!is.na(x) && nzchar(x)) paste0(", by ", esc(x)) else ""
      tagList(
        div(class = "home-progress", role = "progressbar",
            `aria-valuemin` = 0, `aria-valuemax` = n, `aria-valuenow` = m,
            span(class = "done", style = sprintf("width:%.2f%%;", 100 * m / n))),
        tags$p(class = "home-state",
               if (m == n) sprintf("%d of %d measured, in %d folder%s.", m, n, nrow(t),
                                   if (nrow(t) > 1) "s" else "")
               else sprintf("%d of %d measured; the photographs left are in %d of %d folder%s.",
                            m, n, left_f, nrow(t), if (nrow(t) > 1) "s" else "")),
        tags$p(class = "home-last", HTML(
          if (is.null(last)) "Nothing measured yet."
          else sprintf("Last save: <b>%s</b>%s%s, %s.", esc(last$specimen_code),
                       if (!is.na(last$species) && nzchar(last$species))
                         sprintf(" (<i>%s</i>)", esc(last$species)) else "",
                       by(last$operator), ago(last$timestamp)))))
    }
    r <- resume_target()
    div(class = "home-hero",
        div(tags$h1(title), where, state,
            div(class = "home-actions",
                if (!is.null(r))
                  actionButton("home_resume",
                               sprintf("Resume in %s (%d to measure)",
                                       folder_label(r$site, r$date), r$photos - r$measured),
                               class = "btn-primary"),
                actionButton("home_choose", "Choose photographs"),
                if (m) actionButton("home_results", "See the results", class = "btn-link"),
                if (isTRUE(CFG$from_start))
                  actionButton("home_switch", "Open another folder", class = "btn-link"))),
        div(HOME_FISH))
  })
  output$home_folders <- renderUI({
    t <- tree()
    if (!nrow(t)) return(hint("No folder of photographs yet."))
    t$left <- t$photos - t$measured
    t <- t[order(t$left == 0, t$site, t$date), , drop = FALSE]
    rows <- lapply(seq_len(min(nrow(t), 14L)), function(i) {
      div(class = paste("home-folder", if (t$left[i] == 0) "complete"),
          `data-site` = t$site[i], `data-date` = t$date[i], tabindex = 0,
          title = "Open this folder in Select",
          span(class = "name", folder_label(t$site[i], t$date[i])),
          div(class = "bar", span(style = sprintf("width:%.1f%%;",
                                                  100 * t$measured[i] / max(1, t$photos[i])))),
          span(class = "left",
               if (t$left[i] == 0) sprintf("all %d measured", t$photos[i])
               else sprintf("%d of %d to measure", t$left[i], t$photos[i])))
    })
    tagList(div(class = "home-folders", rows),
            if (nrow(t) > 14L)
              hint(sprintf("%d more folders: the full list is in Setup.", nrow(t) - 14L)))
  })
  output$home_recent <- renderUI({
    q <- all_q(); q <- q[q$measured & !is.na(q$timestamp), , drop = FALSE]
    if (!nrow(q)) return(hint("Nothing measured yet: the saves of the digitizer appear here."))
    q <- q[order(q$timestamp, decreasing = TRUE), , drop = FALSE][seq_len(min(6L, nrow(q))), ]
    tags$ul(class = "home-recent", lapply(seq_len(nrow(q)), function(i)
      tags$li(span(span(class = "code", q$specimen_code[i]),
                   if (!is.na(q$species[i]) && nzchar(q$species[i]))
                     tagList(" ", tags$i(q$species[i]))),
              span(class = "when",
                   paste0(if (!is.na(q$operator[i]) && nzchar(q$operator[i]))
                            paste0(q$operator[i], ", ") else "", ago(q$timestamp[i]))))))
  })
  observeEvent(input$home_resume, {
    r <- resume_target(); req(r)
    updateRadioButtons(session, "state_filter", selected = "todo")
    go_folder(r$site, r$date)
  })
  observeEvent(input$home_folder, go_folder(input$home_folder$site, input$home_folder$date))
  observeEvent(input$home_choose, nav_select("nav", "select"))
  ## back to the start page (launched without a folder): what runs is stopped
  ## first, the saves registered, as at Finish
  observeEvent(input$home_switch, {
    busy <- c(vapply(Filter(function(a) a$proc$is_alive(), BG$apps), function(a) a$label, ""),
              if (!is.null(BG$dig) && BG$dig$is_alive()) "the digitizer",
              if (!is.null(BG$batch) && BG$batch$is_alive()) "the automatic pre-pass")
    if (!length(busy)) return(do_switch())
    showModal(modalDialog(
      title = "Open another folder?",
      tags$p(paste0(paste(busy, collapse = " and "), " will be stopped. Nothing is lost: ",
                    "every save is in the journal, and the digitizer writes its workbook ",
                    "as it closes.")),
      footer = tagList(modalButton("Cancel"),
                       actionButton("home_switch_ok", "Open another folder", class = "btn-primary"))))
  })
  observeEvent(input$home_switch_ok, { removeModal(); do_switch() })
  do_switch <- function() {
    stop_all()
    do_sync(auto = TRUE)
    session$sendCustomMessage("hub_switch", "Back to the start page...")
    stopApp(list(restart = "start"))
  }
  observeEvent(input$home_results, nav_select("nav", "results"))
  observeEvent(input$home_go_project, nav_select("nav", "project"))
  observeEvent(input$home_go_select, nav_select("nav", "select"))
  observeEvent(input$home_go_digitize, nav_select("nav", "digitize"))
  observeEvent(input$home_go_results, nav_select("nav", "results"))
  # first folder on opening
  observe({
    t <- tree(); req(nrow(t))
    sites <- unique(t$site)
    if (!(isolate(input$site) %||% "") %in% sites)
      updateSelectInput(session, "site", choices = sites, selected = sites[1])
  })
  observeEvent(input$site, {
    t <- tree(); req(nrow(t), nzchar(input$site))
    d <- t[t$site == input$site, , drop = FALSE]
    lab <- sprintf("%s (%d photos)", d$date, d$photos)
    ch <- stats::setNames(d$date, lab)
    if (nrow(d) > 1L) ch <- c(stats::setNames("*", sprintf("(all: %d photos)", sum(d$photos))), ch)
    want <- session$userData$pending_date
    session$userData$pending_date <- NULL
    updateSelectInput(session, "date", choices = ch,
                      selected = if (!is.null(want) && want %in% d$date) want else ch[[1]])
  })

  queue <- reactive({
    req(nzchar(input$site %||% ""), nzchar(input$date %||% ""))
    q <- all_q()
    q <- q[q$site == input$site, , drop = FALSE]
    if (!identical(input$date, "*")) q <- q[q$date == input$date, , drop = FALSE]
    q
  })

  sp_label <- function(x) ifelse(is.na(x) | !nzchar(x), "(unknown species)", x)

  sp_counts <- reactive({
    q <- queue(); req(nrow(q))
    sp <- sp_label(q$species)
    s <- data.frame(species = sort(unique(sp)), stringsAsFactors = FALSE)
    s$photos   <- as.integer(table(sp)[s$species])
    s$measured <- as.integer(tapply(q$measured, sp, sum)[s$species])
    s$to_measure <- s$photos - s$measured
    s$selected <- as.integer(tapply(q$specimen_code %in% rv$selected, sp, sum)[s$species])
    s
  })

  observeEvent(list(input$site, input$date), {
    q <- tryCatch(queue(), error = function(e) NULL)
    sp <- if (is.null(q)) character(0) else sort(unique(sp_label(q$species)))
    updateSelectizeInput(session, "sp_filter", choices = sp, selected = character(0))
  })

  shown <- reactive({
    q <- queue()
    if (length(input$sp_filter)) q <- q[sp_label(q$species) %in% input$sp_filter, , drop = FALSE]
    switch(input$state_filter,
           todo = q[!q$measured, , drop = FALSE],
           done = q[q$measured, , drop = FALSE],
           q)
  })

  output$sp_tbl <- renderDT({
    datatable(sp_counts(), rownames = FALSE, selection = "single",
              options = list(pageLength = 8, dom = "tip"))
  })
  observeEvent(input$sp_tbl_rows_selected, {
    s <- sp_counts()$species[input$sp_tbl_rows_selected]
    updateSelectizeInput(session, "sp_filter", selected = s)
  })

  output$gallery <- renderUI({
    q <- shown()
    if (!nrow(q)) return(hint("No photograph to show."))
    sel <- isolate(rv$selected)
    pre <- paste0(CFG$photo_dir, "/")
    cards <- lapply(seq_len(nrow(q)), function(i) {
      rel <- substring(q$path[i], nchar(pre) + 1L)
      # ?v=<mtime>: a photograph re-cropped elsewhere keeps its name, and the
      # browser would otherwise go on showing the old image
      v <- as.integer(file.mtime(q$path[i]))
      src <- if (!is.null(thumb_url))
        paste0(thumb_url, "&f=", utils::URLencode(rel, reserved = TRUE), "&v=", v) else
        paste0("hubimg/", url_path(strsplit(rel, "/", fixed = TRUE)[[1]]), "?v=", v)
      div(class = paste("gal-card", if (q$specimen_code[i] %in% sel) "sel"),
          `data-code` = q$specimen_code[i],
          if (isTRUE(q$measured[i]))
            span(class = "badge-m", sprintf("measured%s",
                 if (q$n_records[i] > 1) paste0(" ×", q$n_records[i]) else "")),
          span(class = "zoom", title = "Enlarge", "\U0001F50D"),
          tags$img(src = src, loading = "lazy"),
          div(class = "cap", q$specimen_code[i], tags$br(),
              span(class = "sp", sp_label(q$species[i]))))
    })
    div(class = "gal", cards)
  })

  observeEvent(input$gal_toggle, {
    t <- input$gal_toggle
    rv$selected <- if (isTRUE(t$on)) union(rv$selected, t$code) else
      setdiff(rv$selected, t$code)
  })
  sync_gallery <- function() session$sendCustomMessage("gal_sync", as.list(rv$selected))
  observeEvent(input$sel_visible, {
    rv$selected <- union(rv$selected, shown()$specimen_code); sync_gallery() })
  observeEvent(input$sel_todo, {
    s <- shown(); rv$selected <- union(rv$selected, s$specimen_code[!s$measured])
    sync_gallery() })
  observeEvent(input$sel_clear, { rv$selected <- character(0); sync_gallery() })
  # the selection belongs to one site x date: changing either starts afresh
  observeEvent(list(input$site, input$date), rv$selected <- character(0),
               ignoreInit = TRUE)

  observeEvent(input$gal_zoom, {
    q <- queue(); i <- match(input$gal_zoom, q$specimen_code); req(!is.na(i))
    rv$zoom_code <- q$specimen_code[i]
    showModal(modalDialog(
      title = sprintf("%s -- %s", q$specimen_code[i], sp_label(q$species[i])),
      plotOutput("zoom_plot", height = "600px"), size = "xl", easyClose = TRUE,
      footer = tagList(
        lapply(unname(apps_at("photo")), function(a)
          actionButton(paste0("appz_", a$id), a$label, class = "btn-outline-primary")),
        modalButton("Close"))))
    output$zoom_plot <- renderPlot(draw_photo(q$path[i], NULL, FALSE))
  })

  sel_rows <- reactive({
    q <- queue(); q[q$specimen_code %in% rv$selected, , drop = FALSE]
  })
  output$sel_summary <- renderUI({
    q <- queue(); s <- sel_rows()
    tagList(
      tags$p(tags$b(nrow(q)), " photographs, ", tags$b(length(unique(sp_label(q$species)))),
             " species, ", tags$b(sum(q$measured)), " already measured."),
      tags$p("Selected: ", tags$b(nrow(s)), " photograph(s), ",
             tags$b(length(unique(sp_label(s$species)))), " species",
             if (nrow(s)) sprintf(" (%d already measured)", sum(s$measured))))
  })
  observeEvent(input$go_digitize, nav_select("nav", "digitize"))

  ## ---- 3. digitize ------------------------------------------------------------
  output$dig_selection <- renderUI({
    s <- sel_rows()
    if (!nrow(s)) return(hint("Nothing selected: go back to 2. Select."))
    tb <- table(sp_label(s$species))
    tagList(
      tags$p(tags$b(nrow(s)), " photograph(s) of ", input$site,
             if (!identical(input$date, "*")) paste(" /", input$date)),
      tags$ul(lapply(names(tb), function(n) tags$li(tags$i(n), ": ", tb[[n]]))))
  })
  output$dig_paths <- renderUI({
    hint("Workbook: ", tags$code(xlsx_path()), tags$br(),
         "Journal: ", tags$code(journal_dir()), tags$br(),
         "Ruler: ", input$ruler_mm, " mm")
  })
  nz <- function(x) if (is.null(x) || !nzchar(trimws(x))) NULL else trimws(x)

  ## pre-pass
  batch_out <- reactive({
    nm <- gsub("[^A-Za-z0-9._-]+", "_", paste(input$site, input$date, sep = "_"))
    file.path(CFG$batch_root, nm)
  })
  observeEvent(input$batch_run, {
    s <- sel_rows()
    if (!nrow(s)) { showNotification("Select photographs first.", type = "warning"); return() }
    if (!is.null(BG$batch) && BG$batch$is_alive()) {
      showNotification("A pre-pass is already running.", type = "warning"); return() }
    od <- batch_out(); dir.create(od, recursive = TRUE, showWarnings = FALSE)
    BG$batch_log <- tempfile("hub_batch_", fileext = ".log")
    BG$batch_dir <- od
    args <- list(photos = s$path, out_dir = od,
                 ruler = identical(input$batch_ruler, "yes"), ruler_mm = input$ruler_mm,
                 max_fish = as.integer(input$batch_max_fish),
                 mlmorph_dir = nz(input$mlmorph_dir), python = nz(input$python))
    BG$batch <- tryCatch(bg_batch(args, BG$batch_log), error = function(e) {
      showNotification(conditionMessage(e), type = "error", duration = 8); NULL })
  })
  observeEvent(input$batch_stop, bg_stop(BG$batch))

  ## ---- accept the pre-pass without review ------------------------------------
  ## The points of batch_landmarks() recorded as they are (accept_batch_landmarks):
  ## flagged photographs left out unless asked, measured ones never overwritten,
  ## and every point kept 'predicted' with reviewed = no -- so they can always be
  ## found and checked later. A dry run first, so the dialog says what will happen.
  accept_dir <- function() {
    d <- BG$batch_dir %||% batch_out()
    if (!is.null(d) && file.exists(file.path(d, "summary.csv"))) d else NULL
  }
  accept_scope <- function() {
    s <- tryCatch(sel_rows(), error = function(e) NULL)
    if (!is.null(s) && nrow(s)) s$path else NULL
  }
  accept_plan <- function(include_flagged) {
    tryCatch(suppressMessages(accept_batch_landmarks(
      accept_dir(), CFG$journal_dir, operator = input$operator %||% "?",
      photos = accept_scope(), include_flagged = include_flagged,
      ruler_mm = input$ruler_mm, dry_run = TRUE)), error = function(e) e)
  }
  observeEvent(input$accept_batch, {
    if (is.null(accept_dir())) {
      showNotification("Run the automatic pre-pass first: there is nothing to accept yet.",
                       type = "warning", duration = 6); return() }
    if (identical(dig_status(), "running")) {
      showNotification("Close the digitizer first: it writes the same workbook.",
                       type = "warning", duration = 6); return() }
    if (!is.null(BG$batch) && BG$batch$is_alive()) {
      showNotification("The pre-pass is still running: wait for it to finish.",
                       type = "warning", duration = 6); return() }
    pl <- accept_plan(TRUE)
    if (inherits(pl, "error")) {
      showNotification(conditionMessage(pl), type = "error", duration = 10); return() }
    n_ok   <- sum(pl$status == "dry-run" & !nzchar(pl$flags))
    n_flag <- sum(pl$status == "dry-run" & nzchar(pl$flags))
    n_done <- sum(pl$status == "already measured")
    n_other <- sum(pl$status %in% c("plate", "no landmarks", "incomplete"))
    fl <- sort(table(unlist(strsplit(pl$flags[pl$status == "dry-run" & nzchar(pl$flags)], "[ ,;]+"))),
               decreasing = TRUE)
    showModal(modalDialog(
      title = "Accept the pre-pass without review?",
      div(class = "alert alert-warning", role = "alert",
          tags$b("Nobody will look at these photographs. "),
          "Every error of the model -- a fish upside down, a fin missed, a ruler",
          "misread -- becomes a measurement, and the traits computed from it will",
          "carry it. Use this only on a batch where the predictions have proved",
          "reliable."),
      tags$p(sprintf("Pre-pass of %s%s.", basename(accept_dir()),
                     if (!is.null(accept_scope())) ", restricted to the selection" else "")),
      tags$ul(
        tags$li(tags$b(n_ok), " photograph(s) without any flag: recorded."),
        if (n_flag) tags$li(tags$b(n_flag), paste0(
          " flagged by the pre-pass",
          if (length(fl)) sprintf(" (%s)", paste(sprintf("%s: %d", names(fl), fl), collapse = ", ")),
          ": left out unless ticked below.")),
        if (n_done) tags$li(tags$b(n_done), " already measured: never overwritten."),
        if (n_other) tags$li(tags$b(n_other), " not recordable (plate, or no snout/caudal base).")),
      if (n_flag) checkboxInput("accept_flagged",
                                sprintf("Also record the %d flagged photograph(s)", n_flag), FALSE),
      tags$p(style = "color:var(--fm-muted);font-size:0.9rem;",
             "Recorded as they are: every point keeps the status 'predicted' and the",
             "entry is marked not reviewed, so these specimens stay listed as unreviewed",
             "in Results. Opening one in the digitizer (correct mode) and saving it",
             "makes it an ordinary checked measurement; retract_landmarks() removes it."),
      footer = tagList(modalButton("Cancel"),
                       actionButton("accept_batch_ok", "Record without review",
                                    class = "btn-warning")),
      easyClose = TRUE))
  })
  observeEvent(input$accept_batch_ok, {
    removeModal()
    res <- tryCatch(withCallingHandlers(
      suppressMessages(accept_batch_landmarks(
        accept_dir(), CFG$journal_dir, operator = input$operator %||% "?",
        photos = accept_scope(), include_flagged = isTRUE(input$accept_flagged),
        ruler_mm = input$ruler_mm, xlsx_path = CFG$xlsx_path)),
      warning = function(w) {
        showNotification(conditionMessage(w), type = "warning", duration = 12)
        invokeRestart("muffleWarning")
      }), error = function(e) e)
    if (inherits(res, "error")) {
      showNotification(conditionMessage(res), type = "error", duration = 12); return() }
    n <- sum(res$status == "accepted")
    rv$tick <- rv$tick + 1L
    if (n) do_sync(auto = TRUE)
    showNotification(
      if (n) sprintf(paste("%d photograph(s) recorded WITHOUT REVIEW (points 'predicted').",
                           "They are listed as unreviewed in Results."), n)
      else "Nothing recorded: no photograph left to accept.",
      type = if (n) "warning" else "message", duration = 12)
  })
  batch_poll <- reactiveTimer(1500)
  batch_status <- reactive({
    batch_poll()
    pr <- BG$batch
    if (is.null(pr)) return("none")
    if (pr$is_alive()) return("running")
    ok <- file.exists(file.path(BG$batch_dir %||% "", "landmarks_long.csv")) &&
      !inherits(tryCatch(pr$get_result(), error = function(e) e), "error")
    if (ok) "done" else "failed"
  })
  output$batch_state <- renderUI({
    st <- batch_status()
    switch(st,
      none = hint("Not run. The pre-pass proposes every landmark; the digitizer then",
                  "shows the flagged photographs first."),
      running = tags$p(style = "color:#b45309;", "Running..."),
      done = tags$p(style = "color:#15803d;", "Done: the digitizer will be pre-filled from ",
                    tags$code(BG$batch_dir)),
      failed = tags$p(style = "color:#b91c1c;", "Failed: see the log."))
  })
  output$batch_log <- renderText({ batch_poll(); paste(bg_tail(BG$batch_log), collapse = "\n") })

  ## digitizer
  ## One launcher for both entries: the Digitize tab (the selection, the mode
  ## chosen there) and the Remeasure button (one photograph, mode "correct").
  start_digitizer <- function(paths, mode, batch = NULL) {
    dir.create(dirname(xlsx_path()), recursive = TRUE, showWarnings = FALSE)
    args <- list(photo_dir = paths, xlsx_path = xlsx_path(),
                 journal_dir = journal_dir(), operator = nz(input$operator),
                 mode = mode, n_repeats = as.integer(input$n_repeats %||% 3),
                 ruler_mm = input$ruler_mm,
                 individuals_per_photo = as.integer(input$ind_per_photo),
                 xlsx_flush_every = as.integer(input$flush_every),
                 mlmorph_dir = nz(input$mlmorph_dir), python = nz(input$python),
                 batch = batch)
    port <- free_port()
    BG$dig_log <- tempfile("hub_digitizer_", fileext = ".log")
    BG$dig_url <- sprintf("http://127.0.0.1:%d", port)
    BG$dig_opened <- FALSE
    BG$dig_stopped <- FALSE
    BG$dig_n <- length(paths)
    BG$dig <- tryCatch(bg_digitizer(args, port, BG$dig_log), error = function(e) {
      showNotification(conditionMessage(e), type = "error", duration = 8); NULL })
  }
  observeEvent(input$dig_start, {
    s <- sel_rows()
    if (!nrow(s)) { showNotification("Select photographs first.", type = "warning"); return() }
    if (!is.null(BG$dig) && BG$dig$is_alive()) {
      showNotification("A digitizer is already open: stop it first.", type = "warning")
      return()
    }
    if (isTRUE(input$use_batch) && !identical(batch_status(), "done")) {
      showNotification("The pre-pass is not finished: run it, or untick it.",
                       type = "warning"); return()
    }
    start_digitizer(s$path, input$dig_mode,
                    batch = if (isTRUE(input$use_batch)) BG$batch_dir else NULL)
  })

  ## Remeasure the photograph shown in "Annotated photograph": the digitizer on
  ## that photograph alone, in "correct" mode (its saved points are reloaded).
  ## A digitizer already open is closed first -- cleanly, so its workbook is
  ## written and the photograph's last measurement is in it.
  remeasure_path <- reactive({
    q <- scope_queue(); i <- match(input$ann_code, q$specimen_code)
    if (is.na(i)) NULL else q$path[i]
  })
  do_remeasure <- function() {
    path <- remeasure_path(); req(path)
    if (!is.null(BG$dig) && BG$dig$is_alive()) {
      BG$dig_stopped <- TRUE; bg_stop(BG$dig)
    }
    start_digitizer(path, "correct")
    showNotification(sprintf("Opening the digitizer on %s (correct mode)...",
                             basename(path)), duration = 5)
  }
  observeEvent(input$remeasure, {
    req(nzchar(input$ann_code %||% ""))
    if (!is.null(BG$dig) && BG$dig$is_alive()) {
      showModal(modalDialog(
        title = "A digitizer is already open",
        tags$p("It will be closed (its workbook is written, nothing saved is lost)",
               "and reopened on ", tags$b(input$ann_code), " only, in correct mode.",
               "Points on screen there that were not saved are lost."),
        footer = tagList(modalButton("Cancel"),
                         actionButton("remeasure_ok", "Close it and remeasure",
                                      class = "btn-primary"))))
    } else do_remeasure()
  })
  observeEvent(input$remeasure_ok, { removeModal(); do_remeasure() })
  observeEvent(input$dig_stop, {
    BG$dig_stopped <- TRUE
    bg_stop(BG$dig); rv$tick <- rv$tick + 1L
  })
  dig_poll <- reactiveTimer(1000)
  dig_status <- reactive({
    dig_poll()
    pr <- BG$dig
    if (is.null(pr)) return("none")
    if (!pr$is_alive())
      return(if (inherits(tryCatch(pr$get_result(), error = function(e) e), "error") &&
                 !isTRUE(BG$dig_stopped)) "failed" else "closed")
    if (any(grepl("Listening on", bg_tail(BG$dig_log, 50)))) "running" else "starting"
  })
  observe({
    if (identical(dig_status(), "running") && !isTRUE(BG$dig_opened)) {
      BG$dig_opened <- TRUE
      session$sendCustomMessage("open_url", BG$dig_url)
    }
  })
  output$dig_state <- renderUI({
    switch(dig_status(),
      none = NULL,
      starting = tags$p(style = "color:#b45309;", "Starting..."),
      running = tags$p(style = "color:#15803d;",
                       sprintf("Open on %d photograph(s): ", BG$dig_n),
                       tags$a(href = BG$dig_url, target = "_blank", BG$dig_url),
                       " (if the tab did not open, click the link)."),
      closed = tags$p("Closed. Its measurements are in the Results tab."),
      failed = tags$p(style = "color:#b91c1c;", "Stopped with an error: see the log."))
  })
  output$dig_log <- renderText({ dig_poll(); paste(bg_tail(BG$dig_log), collapse = "\n") })

  ## ---- connected applications ------------------------------------------------
  ## Each in its own background R process and browser tab, like the digitizer.
  ## One process per application: asking again for one that is open brings its
  ## tab back, unless it was opened on another photograph (then it restarts).
  open_app <- function(id, photo = NULL) {
    a <- APPS[[id]]; req(a)
    cur <- BG$apps[[id]]
    tab <- paste0("hub_", id)                       # one browser tab per application
    if (!is.null(cur) && cur$proc$is_alive()) {
      if (is.null(a$photo_arg) || identical(cur$photo, photo)) {
        session$sendCustomMessage("open_url", list(url = cur$url, name = tab))
        return(invisible())
      }
      # Already running on another photograph: an application that reads the
      # photograph from its URL (`photo_query`) is simply pointed at the new
      # one -- no new R process, no reloading of packages. Others restart.
      if (!is.null(a$photo_query)) {
        BG$apps[[id]]$photo <- photo
        session$sendCustomMessage("open_url", list(
          url = sprintf("%s/?%s=%s", cur$url, a$photo_query,
                        utils::URLencode(photo, reserved = TRUE)), name = tab))
        return(invisible())
      }
      bg_stop(cur$proc)
    }
    # an application that rewrites the workbook must not race a digitizer
    # holding its own copy of it
    if (isTRUE(a$close_digitizer) && !is.null(BG$dig) && BG$dig$is_alive()) {
      BG$dig_stopped <- TRUE; bg_stop(BG$dig)
      showNotification("The digitizer was closed first (its workbook is written).",
                       duration = 6)
    }
    args <- a$args
    if (!is.null(a$photo_arg) && !is.null(photo)) args[[a$photo_arg]] <- photo
    q <- isolate(all_q())
    ppath <- if (is.null(photo)) NA_character_ else q$path[match(photo, q$specimen_code)]
    port <- free_port()
    log <- tempfile(paste0("hub_", id, "_"), fileext = ".log")
    pr <- tryCatch(bg_app(a$fun, args, port, log), error = function(e) {
      showNotification(conditionMessage(e), type = "error", duration = 8); NULL })
    if (is.null(pr)) return(invisible())
    BG$apps[[id]] <- list(proc = pr, url = sprintf("http://127.0.0.1:%d", port),
                          log = log, opened = FALSE, photo = photo, ended = FALSE,
                          label = a$label, path = ppath,
                          mtime = if (is.na(ppath)) NA else file.mtime(ppath))
    showNotification(sprintf("Opening %s%s...", a$label,
                             if (is.null(photo)) "" else paste0(" on ", photo)),
                     duration = 5)
  }
  ## on a photograph: a warning first when its landmarks would no longer match
  open_on_photo <- function(id, code) {
    req(nzchar(code %||% ""))
    a <- APPS[[id]]
    q <- all_q(); measured <- isTRUE(q$measured[match(code, q$specimen_code)])
    if (measured && !is.null(a$warn_measured)) {
      rv$pending_app <- list(id = id, code = code)
      showModal(modalDialog(
        title = paste(a$label, "--", code),
        tags$p(a$warn_measured),
        footer = tagList(modalButton("Cancel"),
                         actionButton("pending_app_ok", "Open it anyway",
                                      class = "btn-warning"))))
    } else {
      removeModal(); open_app(id, code)
    }
  }
  observeEvent(input$pending_app_ok, {
    removeModal(); pa <- rv$pending_app; req(pa)
    rv$pending_app <- NULL; open_app(pa$id, pa$code)
  })
  lapply(names(APPS), function(id) {
    observeEvent(input[[paste0("apps_", id)]], open_app(id))
    observeEvent(input[[paste0("appm_", id)]], open_app(id))
    observeEvent(input[[paste0("appsh_", id)]], open_app(id))
    observeEvent(input[[paste0("appz_", id)]], open_on_photo(id, rv$zoom_code))
    observeEvent(input[[paste0("appa_", id)]], open_on_photo(id, input$ann_code))
  })
  observeEvent(input$sel_refresh, rv$tick <- rv$tick + 1L)
  observeEvent(input$apps_stop_all, {
    for (a in BG$apps) bg_stop(a$proc)
  })
  ## open each tab once its server listens; refresh when an application ends
  apps_poll <- reactiveTimer(1000)
  observe({
    apps_poll()
    for (id in names(BG$apps)) {
      a <- BG$apps[[id]]
      if (!a$opened && any(grepl("Listening on", bg_tail(a$log, 50)))) {
        BG$apps[[id]]$opened <- TRUE
        session$sendCustomMessage("open_url", list(url = a$url, name = paste0("hub_", id)))
      }
      # An application working on photographs may change their images while it
      # is open (and move from one photograph to the next by itself): the
      # photographs of the current folder are watched, and any whose image
      # changed has its stale batch predictions removed and the gallery redrawn.
      if (!is.null(a$photo) && a$proc$is_alive()) {
        q <- tryCatch(isolate(queue()), error = function(e) NULL)
        if (!is.null(q) && nrow(q)) {
          mt <- stats::setNames(as.numeric(file.mtime(q$path)), q$path)
          old <- a$watch
          if (!is.null(old)) {
            common <- intersect(names(mt), names(old))
            changed <- common[mt[common] != old[common]]
            if (length(changed)) {
              for (f in changed) purge_batch(CFG$batch_root, basename(f))
              isolate(rv$tick <- rv$tick + 1L)
            }
          }
          BG$apps[[id]]$watch <- mt
        }
      }
      if (!a$ended && !a$proc$is_alive()) {
        BG$apps[[id]]$ended <- TRUE
        # the photograph's image changed: its batch predictions are stale
        if (!is.na(a$path %||% NA) && file.exists(a$path) &&
            !identical(as.numeric(file.mtime(a$path)), as.numeric(a$mtime))) {
          n <- purge_batch(CFG$batch_root, basename(a$path))
          if (n) showNotification(sprintf(
            "%s: image changed, its automatic pre-pass predictions were removed.",
            a$photo), duration = 8)
        }
        isolate(rv$tick <- rv$tick + 1L)        # photographs may have changed
        if (!a$opened)
          showNotification(paste0(a$label, " did not start: ",
                                  paste(bg_tail(a$log, 4), collapse = " | ")),
                           type = "error", duration = 12)
      }
    }
  })
  output$apps_state <- renderUI({
    apps_poll()
    live <- Filter(function(a) a$proc$is_alive(), BG$apps)
    if (!length(live)) return(hint("None."))
    tags$ul(lapply(live, function(a)
      tags$li(a$label, if (!is.null(a$photo)) paste0(" (", a$photo, ")"), ": ",
              tags$a(href = a$url, target = "_blank", a$url))))
  })

  ## ---- the database: what is recorded, and the explicit save ---------------
  ## Landmarks are RECORDED by the digitizer at every 'Save & next' (the
  ## journal line is written at once; the workbook follows, every save when
  ## the hub opens it). Saving here re-reads everything and runs the project's
  ## own registration (sync_fun) -- also run when the digitizer closes and at
  ## Finish, so nothing waits on the operator remembering it.
  do_sync <- function(auto = FALSE) {
    msg <- if (is.function(CFG$sync_fun)) {
      w <- character(0)
      m <- withCallingHandlers(
        tryCatch(CFG$sync_fun(), error = function(e) paste("Error:", conditionMessage(e))),
        warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") },
        message = function(x) invokeRestart("muffleMessage"))
      paste(c(as.character(m)[1], w), collapse = " ")
    } else "Landmarks are in the journal and the workbook."
    rv$sync_msg <- msg; rv$sync_at <- Sys.time()
    isolate(rv$tick <- rv$tick + 1L)
    if (!auto) showNotification(msg, duration = 8,
                                type = if (grepl("^Error", msg)) "error" else "message")
    invisible(msg)
  }
  observeEvent(input$sync_now, do_sync())
  ## when the digitizer closes, its last saves are registered at once
  BG$dig_prev <- "none"
  observe({
    st <- dig_status()
    if (st %in% c("closed", "failed") && BG$dig_prev %in% c("running", "starting"))
      do_sync(auto = TRUE)
    BG$dig_prev <- st
  })
  output$db_state <- renderUI({
    j <- J(); q <- all_q()
    last <- if (!is.null(j) && nrow(j)) max(j$timestamp, na.rm = TRUE) else NA
    wb <- if (file.exists(CFG$xlsx_path)) file.mtime(CFG$xlsx_path) else NA
    t <- function(x) if (is.na(x)) "-" else format(as.POSIXct(x, tz = "UTC",
                                    tryFormats = c("%Y-%m-%dT%H:%M:%OS", "%Y-%m-%d %H:%M:%OS")),
                                    "%d/%m %H:%M", tz = "")
    tags$span(style = "font-size:12px;color:var(--fm-ink);margin-right:8px;",
              title = paste(c(paste("Journal:", CFG$journal_dir),
                              paste("Workbook:", CFG$xlsx_path),
                              if (!is.null(rv$sync_msg))
                                paste0("Last save (", format(rv$sync_at, "%H:%M:%S"), "): ",
                                       rv$sync_msg)), collapse = "\n"),
              sprintf("%d measured \u00b7 last landmark %s \u00b7 workbook %s%s",
                      sum(q$measured), t(last),
                      if (is.na(wb)) "-" else format(wb, "%d/%m %H:%M"),
                      if (!is.null(rv$sync_at)) paste0(" \u00b7 saved ",
                                                       format(rv$sync_at, "%H:%M")) else ""))
  })

  ## ---- finish: back to the R console -----------------------------------------
  observeEvent(input$finish, {
    busy <- c(vapply(Filter(function(a) a$proc$is_alive(), BG$apps),
                     function(a) a$label, ""),
              if (!is.null(BG$dig) && BG$dig$is_alive()) "the digitizer",
              if (!is.null(BG$batch) && BG$batch$is_alive()) "the automatic pre-pass")
    showModal(modalDialog(
      title = "Finish and return to R?",
      if (length(busy))
        tags$p(paste0(paste(busy, collapse = " and "), " will be stopped. ",
                      "Nothing is lost: every save is in the journal, and the ",
                      "digitizer writes its workbook as it closes."))
      else tags$p("The hub closes and the R console is free again."),
      footer = tagList(modalButton("Cancel"),
                       actionButton("finish_ok", "Finish", class = "btn-danger"))))
  })
  observeEvent(input$finish_ok, {
    removeModal()
    stop_all()
    do_sync(auto = TRUE)          # the digitizer's last saves, registered
    out <- list(photo_dir = CFG$photo_dir, xlsx_path = CFG$xlsx_path,
                journal_dir = CFG$journal_dir,
                selected = tryCatch(sel_rows(), error = function(e) NULL),
                traits = rv$traits)
    session$sendCustomMessage("hub_closed", TRUE)
    stopApp(invisible(out))
  })

  ## ---- 4. results -------------------------------------------------------------
  output$res_live <- renderUI({
    if (identical(dig_status(), "running"))
      tags$span(style = "color:#15803d;font-size:13px;",
                "● digitizer open -- tables follow the journal")
  })

  scope_queue <- reactive({
    q <- all_q()
    switch(input$res_scope,
      sel  = sel_rows(),
      date = queue(),
      site = q[q$site == input$site, , drop = FALSE],
      all  = q)
  })

  prog <- reactive({
    q <- scope_queue(); req(nrow(q))
    q$species <- sp_label(q$species)
    k <- paste(q$site, q$date, q$species, sep = "\r")
    u <- !duplicated(k)
    out <- data.frame(site = q$site[u], date = q$date[u], species = q$species[u],
                      stringsAsFactors = FALSE)
    out$photos <- as.integer(table(k)[k[u]])
    out$measured <- as.integer(tapply(q$measured, k, sum)[k[u]])
    out$remaining <- out$photos - out$measured
    out$pct <- round(100 * out$measured / out$photos, 1)
    out$incomplete <- as.integer(tapply(q$measured & !is.na(q$n_missing) & q$n_missing > 0,
                                        k, sum)[k[u]])
    out$no_scale <- as.integer(tapply(q$measured & !is.na(q$has_scale) & !q$has_scale,
                                      k, sum)[k[u]])
    out[order(out$site, out$date, out$species), , drop = FALSE]
  })
  output$prog_tbl <- renderDT({
    p <- prog()
    tot <- data.frame(site = "TOTAL", date = "", species = "", photos = sum(p$photos),
                      measured = sum(p$measured), remaining = sum(p$remaining),
                      pct = round(100 * sum(p$measured) / max(1, sum(p$photos)), 1),
                      incomplete = sum(p$incomplete), no_scale = sum(p$no_scale))
    datatable(rbind(p, tot), rownames = FALSE, options = dt_opts,
              colnames = c(LV[1], LV[2], "species", "photos", "measured",
                           "remaining", "%", "incomplete", "no scale"))
  })
  ## Progress by species: measured / remaining. The legend sits ABOVE the bars
  ## (inside them it hid the bars as soon as anything was measured), each bar
  ## carries its count, and the height follows the number of species.
  prog_species <- reactive({
    p <- prog(); req(nrow(p))
    p <- p[!is.na(p$species) & p$species != "TOTAL", , drop = FALSE]
    a <- tapply(p$measured, p$species, sum); b <- tapply(p$remaining, p$species, sum)
    d <- data.frame(species = names(a), measured = as.numeric(a), remaining = as.numeric(b[names(a)]))
    d[order(d$measured + d$remaining, d$species), , drop = FALSE]
  })
  output$prog_plot <- renderPlot({
    d <- prog_species(); req(nrow(d))
    tot <- d$measured + d$remaining; n <- nrow(d)
    river <- "#1d5e6b"; rest <- "#e3ecea"; line <- "#cfdad8"; ink <- "#1a2a2f"; muted <- "#566a70"
    op <- graphics::par(family = "sans", col.axis = muted, fg = line)
    on.exit(graphics::par(op))
    lab_w <- max(graphics::strwidth(d$species, units = "inches", cex = 0.85, font = 3))
    graphics::par(mai = c(0.6, min(3.2, lab_w + 0.25), 0.4, 0.75))
    xmax <- max(tot) * 1.02; y <- seq_len(n); h <- 0.32
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, xmax), ylim = c(0.5, n + 0.5), xaxs = "i", yaxs = "i")
    # grid first, bars over it
    graphics::abline(v = pretty(c(0, max(tot))), col = grDevices::adjustcolor(line, 0.6), lwd = 0.6)
    graphics::rect(0, y - h, tot, y + h, col = rest, border = line, lwd = 0.8)
    graphics::rect(0, y - h, d$measured, y + h, col = river, border = NA)
    graphics::axis(1, at = pretty(c(0, max(tot))), lwd = 0, lwd.ticks = 0.8, col.ticks = line,
                   cex.axis = 0.85)
    graphics::mtext("photographs", side = 1, line = 2.1, cex = 0.85, col = muted)
    binom <- grepl("^[A-Z][a-z]+ [a-z]", d$species)
    graphics::text(-xmax * 0.012, y, d$species, adj = 1, xpd = TRUE, cex = 0.85,
                   font = ifelse(binom, 3, 1), col = ink)
    graphics::text(tot, y, sprintf("  %d / %d", d$measured, tot), adj = 0, xpd = TRUE,
                   cex = 0.8, col = muted)
    graphics::legend("bottomleft", inset = c(0, 1), xpd = TRUE, horiz = TRUE, bty = "n",
                     legend = c("measured", "remaining"), fill = c(river, rest),
                     border = c(NA, line), cex = 0.85, text.col = ink)
  }, res = 96, height = function() 120 + 34 * max(1L, tryCatch(nrow(isolate(prog_species())),
                                                                error = function(e) 1L)))

  # the journal, consolidated (one row per digitization)
  journal_cons <- reactive({
    j <- J(); if (is.null(j) || !nrow(j)) return(NULL)
    tryCatch(suppressMessages(suppressWarnings(
      intraitR::consolidate_landmarks(j, status_columns = TRUE))),
      error = function(e) NULL)
  })
  journal_qc <- reactive({
    j <- J(); if (is.null(j) || !nrow(j)) return(NULL)
    tryCatch(suppressMessages(suppressWarnings(intraitR::landmark_journal_qc(j))),
             error = function(e) NULL)
  })
  code_of <- function(d) {
    pf <- as.character(d$photo_file %||% rep(NA_character_, nrow(d)))
    ifelse(!is.na(pf) & nzchar(pf), tools::file_path_sans_ext(basename(pf)),
           as.character(d$specimen))
  }

  lm_table <- reactive({
    cons <- journal_cons(); req(!is.null(cons), nrow(cons))
    q <- scope_queue()
    cons$code <- code_of(cons)
    cons <- cons[cons$code %in% q$specimen_code, , drop = FALSE]
    req(nrow(cons))
    cons$species <- sp_label(q$species[match(cons$code, q$specimen_code)])
    qc <- journal_qc()
    if (!is.null(qc) && nrow(qc)) {
      m <- match(cons$row_key %||% cons$specimen, qc$row_key)
      for (k in c("n_missing", "missing", "seeded", "has_scale"))
        if (!is.null(qc[[k]])) cons[[paste0("qc_", k)]] <- qc[[k]][m]
    }
    id <- intersect(c("code", "specimen", "individual", "replicate", "species",
                      "operator", "timestamp", "mode"), names(cons))
    cnt <- grep("^n_", names(cons), value = TRUE)
    qcc <- grep("^qc_", names(cons), value = TRUE)
    xy  <- grep("^[0-9]+_[XY]$", names(cons), value = TRUE)
    st  <- grep("^[0-9]+_status$", names(cons), value = TRUE)
    cons[, c(id, cnt, qcc, if (isTRUE(input$lm_coords)) c(xy, st)), drop = FALSE]
  })
  output$lm_tbl <- renderDT({
    d <- lm_table()
    num <- vapply(d, is.numeric, logical(1))
    d[num] <- lapply(d[num], function(v) round(v, 1))
    datatable(d, rownames = FALSE, selection = "single", filter = "top",
              options = dt_opts)
  })
  output$lm_dl <- downloadHandler(
    filename = function() sprintf("landmarks_%s_%s.csv", input$site, input$date),
    content = function(f) utils::write.csv(lm_table(), f, row.names = FALSE))
  observeEvent(input$lm_tbl_rows_selected, {
    code <- lm_table()$code[input$lm_tbl_rows_selected]
    updateSelectizeInput(session, "ann_code", selected = code)
    nav_select("res_tabs", "Annotated photograph")
  })

  ## traits
  observeEvent(input$tr_compute, {
    q <- scope_queue(); codes <- q$specimen_code[q$measured]
    rv$traits <- NULL
    if (!length(codes)) { rv$tr_msg <- "No measured specimen in this scope."; return() }
    if (!file.exists(xlsx_path())) {
      rv$tr_msg <- paste("No workbook yet:", xlsx_path()); return() }
    warn <- character(0)
    res <- withProgress(message = "Computing the traits", value = 0.3,
      withCallingHandlers(tryCatch({
        tr <- CFG$traits_fun(codes, xlsx_path(), input$ruler_mm,
                             if (isTRUE(input$tr_pixels)) "pixels" else "na")
        tr <- as.data.frame(tr, stringsAsFactors = FALSE)
        # the photograph each row comes from, and its species when the trait
        # function did not attach one
        if (is.null(tr$photo_code)) tr$photo_code <- tr$specimen_code
        if (is.null(tr$species))
          tr$species <- q$species[match(tr$photo_code, q$specimen_code)]
        front <- intersect(c("specimen_code", "photo_code", "site", "date", "species",
                             "scale_units"), names(tr))
        tr[, c(front, setdiff(names(tr), front)), drop = FALSE]
      }, error = function(e) e),
      warning = function(w) { warn <<- c(warn, conditionMessage(w))
                              invokeRestart("muffleWarning") },
      message = function(m) invokeRestart("muffleMessage")))
    if (inherits(res, "error")) {
      rv$tr_msg <- paste("Error:", conditionMessage(res)); return() }
    rv$traits <- res
    npx <- if (is.null(res$scale_units)) 0L else sum(res$scale_units %in% "px")
    rv$tr_msg <- sprintf("%d specimen(s)%s.%s", nrow(res),
                         if (npx) sprintf(", of which %d without a ruler (segments in pixels, ratios valid)", npx) else "",
                         if (length(warn)) paste0(" Warnings: ",
                           paste(unique(warn), collapse = " | ")) else "")
  })
  output$tr_msg <- renderUI(if (!is.null(rv$tr_msg)) hint(rv$tr_msg))
  output$tr_tbl <- renderDT({
    d <- rv$traits; req(d)
    num <- vapply(d, is.numeric, logical(1))
    d[num] <- lapply(d[num], function(v) signif(v, 4))
    datatable(d, rownames = FALSE, filter = "top", selection = "single",
              options = dt_opts)
  })
  ## a specimen picked in the traits table opens on its photograph
  observeEvent(input$tr_tbl_rows_selected, {
    code <- rv$traits$photo_code[input$tr_tbl_rows_selected]
    req(length(code) == 1L, !is.na(code))
    updateSelectizeInput(session, "ann_code", selected = code)
    nav_select("res_tabs", "Annotated photograph")
  })
  output$tr_dl <- downloadHandler(
    filename = function() sprintf("traits_%s.csv", format(Sys.Date(), "%Y%m%d")),
    content = function(f) utils::write.csv(rv$traits, f, row.names = FALSE))

  ## annotated photograph
  observe({
    q <- tryCatch(scope_queue(), error = function(e) NULL); req(q)
    m <- q[q$measured, , drop = FALSE]
    ch <- stats::setNames(m$specimen_code,
                          sprintf("%s  (%s)", m$specimen_code, sp_label(m$species)))
    cur <- isolate(input$ann_code)
    updateSelectizeInput(session, "ann_code", choices = ch,
                         selected = if (!is.null(cur) && cur %in% ch) cur else ch[1] %||% "")
  })

  read_small <- function(path, max_px = 1600L) {
    if (requireNamespace("magick", quietly = TRUE)) {
      im <- magick::image_read(path)
      inf <- magick::image_info(im)
      sm <- magick::image_resize(im, sprintf("%dx%d>", max_px, max_px))
      return(list(r = grDevices::as.raster(sm), W = inf$width, H = inf$height))
    }
    a <- if (grepl("\\.png$", path, ignore.case = TRUE)) png::readPNG(path) else
      jpeg::readJPEG(path)
    list(r = grDevices::as.raster(a), W = dim(a)[2], H = dim(a)[1])
  }
  draw_photo <- function(path, pts, labels) {
    im <- tryCatch(read_small(path), error = function(e) NULL)
    op <- graphics::par(mar = c(0, 0, 0, 0)); on.exit(graphics::par(op))
    if (is.null(im)) {
      graphics::plot.new(); graphics::text(0.5, 0.5, "Cannot read this image."); return()
    }
    graphics::plot(NA, xlim = c(0, im$W), ylim = c(im$H, 0), asp = 1, axes = FALSE,
                   xlab = "", ylab = "", xaxs = "i", yaxs = "i")
    graphics::rasterImage(im$r, 0, im$H, im$W, 0)
    if (is.null(pts) || !nrow(pts)) return()
    col <- STATUS_COL[pts$status]; col[is.na(col)] <- "#111827"
    graphics::points(pts$x, pts$y, pch = 21, bg = col, col = "white", cex = 1.6, lwd = 1.2)
    if (labels) graphics::text(pts$x, pts$y, pts$lm, pos = 3, cex = 0.8, col = "#111827",
                               font = 2)
  }
  ann_rows <- reactive({
    req(nzchar(input$ann_code %||% ""))
    cons <- journal_cons(); req(cons)
    cons[code_of(cons) == input$ann_code, , drop = FALSE]
  })
  output$ann_plot <- renderPlot({
    q <- scope_queue(); i <- match(input$ann_code, q$specimen_code); req(!is.na(i))
    d <- ann_rows()
    pts <- do.call(rbind, lapply(seq_len(nrow(d)), function(r) {
      lm <- as.integer(sub("_X$", "", grep("^[0-9]+_X$", names(d), value = TRUE)))
      x <- unlist(d[r, paste0(lm, "_X")]); y <- unlist(d[r, paste0(lm, "_Y")])
      s <- if (all(paste0(lm, "_status") %in% names(d)))
        as.character(unlist(d[r, paste0(lm, "_status")])) else rep(NA_character_, length(lm))
      data.frame(lm = lm, x = as.numeric(x), y = as.numeric(y), status = s)
    }))
    pts <- pts[is.finite(pts$x) & is.finite(pts$y), , drop = FALSE]
    draw_photo(q$path[i], pts, isTRUE(input$ann_labels))
  }, res = 96)
  output$ann_info <- renderUI({
    d <- tryCatch(ann_rows(), error = function(e) NULL); req(d, nrow(d))
    hint(sprintf("%d record(s); last by %s on %s.", nrow(d),
                 utils::tail(d$operator %||% NA, 1), utils::tail(d$timestamp %||% NA, 1)))
  })
}

shinyApp(ui, server)
