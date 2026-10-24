# =============================================================================
# analyses_app -- the ANALYSIS part of the intraitR workflow, on measured fish
#
# Launched by intraitR::launch_intrait_analyses() (and by the measurement hub,
# Results tab). Configuration in getOption("intraitR.analyses"): xlsx_path,
# specimens, landmarks, title, author.
#
# The tabs compute live, with the same calls as the scripts of the exported
# project; the Export tab does NOT save what is on screen: it writes the
# project and RUNS its scripts (write_analysis_project(), in a background R
# process), so the archive is what anyone re-running it obtains.
# =============================================================================

library(shiny)
library(bslib)

ns <- asNamespace("intraitR")
`%||%` <- function(x, y) if (is.null(x)) y else x
req <- shiny::req

CFG <- getOption("intraitR.analyses", list())
RC <- get(".ANA_RATIOS", ns)
SHAPE_OK <- requireNamespace("geomorph", quietly = TRUE) &&
  !identical(utils::packageDescription("geomorph")$Title, "Stub")
DEF <- intraitR::analysis_params()

THEME <- tryCatch(Rfishmorph::app_theme(), error = function(e) bslib::bs_theme(version = 5))

hint <- function(...) tags$p(class = "text-muted", style = "font-size:12.5px;margin:4px 0 10px 0;", ...)
card_x <- function(title, ...) bslib::card(bslib::card_header(title), bslib::card_body(...))
fmt <- function(df, d = 3) {
  df[] <- lapply(df, function(v) if (is.numeric(v) && !all(is.na(v) | v == round(v))) round(v, d) else v)
  df
}
dt <- function(df, n = 10) DT::datatable(fmt(df), rownames = FALSE,
                                         options = list(pageLength = n, scrollX = TRUE, dom = "ftip"))
quietly <- function(expr) {
  msgs <- character(0)
  val <- withCallingHandlers(expr,
    message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") },
    warning = function(w) { msgs <<- c(msgs, conditionMessage(w)); invokeRestart("muffleWarning") })
  attr(val, "notes") <- msgs
  val
}
safely <- function(expr, what) {
  tryCatch(withProgress(message = what, value = 0.4, quietly(expr)),
           error = function(e) {
             showNotification(paste0(what, ": ", conditionMessage(e)), type = "error", duration = 12)
             NULL })
}
style_choices <- c("Spider + 95% ellipse" = "spider", "Convex hull" = "hull",
                   "Density contour" = "density", "Points only" = "none")

# =============================================================================
# UI
# =============================================================================
ui <- bslib::page_navbar(
  title = "intraitR — analyses", id = "nav", theme = THEME, fillable = FALSE,
  header = tags$style(HTML("
    .stat { font-size: 1.7rem; font-weight: 600; line-height: 1.1; }
    .stat-l { color: var(--bs-secondary-color); font-size: .8rem; text-transform: uppercase; letter-spacing: .04em; }
    .tree { font-family: var(--bs-font-monospace); font-size: 12px; white-space: pre; background: var(--bs-tertiary-bg);
            padding: 10px; border-radius: .4rem; max-height: 340px; overflow: auto; }
    .report { max-height: 560px; overflow: auto; border: 1px solid var(--bs-border-color); border-radius: .4rem; padding: 14px 18px; }
    .report img { max-width: 100%; }
    .runlog { font-size: 11.5px; max-height: 220px; overflow: auto; }")),

  # --- 1. Data -----------------------------------------------------------------
  bslib::nav_panel("1. Data", value = "data",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(width = 320,
        uiOutput("source_ui"),
        tags$hr(),
        numericInput("min_n", "Minimum individuals per species", DEF$min_n, min = 2, step = 1),
        uiOutput("species_ui"),
        uiOutput("sites_ui"),
        uiOutput("sources_ui"),
        checkboxGroupInput("ratios", "Ratios used (a specimen needs all of them)", RC, RC, inline = TRUE),
        uiOutput("ratio_cover"),
        tags$hr(),
        numericInput("scale_cm", "Length of the scale bar, points 20–21 (cm)", DEF$scale_cm,
                     min = 0.01, step = 0.1),
        radioButtons("scale_action", "Specimens without a scale bar",
                     c("Kept, measurements in pixels (ratios valid)" = "pixels",
                       "Measurements set to NA" = "na"), DEF$scale_action),
        tags$details(tags$summary("Landmark corrections and special morphologies"),
          checkboxInput("impute", "Estimate missing anatomical landmarks", FALSE),
          checkboxInput("orientation", "Orient head left, belly down", FALSE),
          checkboxInput("geometry", "Enforce FISHMORPH geometric conventions", FALSE),
          checkboxInput("no_caudal_fin", "No visible caudal fin (CPt = 1)", FALSE),
          checkboxInput("ventral_mouth", "Ventral mouth (OGp = RMl = 0)", FALSE),
          checkboxInput("no_pectoral_fin", "No pectoral fin (PFv = 0)", FALSE))),
      uiOutput("data_stats"),
      card_x("Table 1 — sample per species",
             hint("Analysed: all the ratios used, species with at least the minimum number of",
                  "individuals. Points 22/24/25 (midline hinges) are read: standard length is",
                  "curvilinear on curved specimens."),
             DT::DTOutput("tab1")))),

  # --- 2. Traits ---------------------------------------------------------------
  bslib::nav_panel("2. Traits", value = "traits",
    card_x("Table 2 — the nine ratios per species (mean, sd, min, max)", DT::DTOutput("tab2")),
    card_x("Table S1 — coefficient of variation per species and ratio (%)", DT::DTOutput("tab_cv"))),

  # --- 3. Trait space ------------------------------------------------------------
  bslib::nav_panel("3. Trait space", value = "ts",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(width = 300,
        selectInput("ts_style", "Display", style_choices, DEF$ts_style),
        selectInput("ts_axes", "Axes", c("PC1 × PC2" = "1,2", "PC1 × PC3" = "1,3",
                                         "PC2 × PC3" = "2,3")),
        checkboxInput("ts_remove_outliers", "Remove within-species outliers", FALSE),
        hint("PCA of the nine log10(x + 1)-transformed, standardised ratios (trait_space)."),
        tags$hr(),
        numericInput("disparity_iter", "Permutations (dispersion test)", DEF$disparity_iter,
                     min = 99, step = 100),
        actionButton("td_run", "Test differences in dispersion", class = "btn-outline-primary w-100")),
      card_x("Figure 1 — trait space", plotOutput("ts_plot", height = "560px"),
             uiOutput("ts_info")),
      card_x("Table 4 — trait dispersion per species (permutation test, Holm-adjusted pairs)",
             DT::DTOutput("td_tab"), DT::DTOutput("td_pairs")))),

  # --- 4. FISHMORPH ----------------------------------------------------------------
  bslib::nav_panel("4. FISHMORPH", value = "pf",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(width = 300,
        selectInput("pf_style", "Display", c("Convex hull" = "hull", "Spider" = "spider",
                                             "Density" = "density", "Points" = "points"), DEF$pf_style),
        checkboxInput("pf_itv_reference", "Reference position of each species", DEF$pf_itv_reference),
        checkboxInput("pf_arrows", "Trait loadings (arrows)", DEF$pf_arrows),
        actionButton("pf_run", "Project into FISHMORPH", class = "btn-primary w-100"),
        hint("Projection, without refitting, into the PCA of the FISHMORPH database",
             "(~9,000 species; project_fishmorph). The first run loads the reference.")),
      card_x("Figure 2 — the sample in the global space", plotOutput("pf_plot", height = "580px")),
      card_x("Table 5 — share of the global space (convex hull, first two axes)",
             DT::DTOutput("pf_tab")))),

  # --- 5. ITV ------------------------------------------------------------------------
  bslib::nav_panel("5. ITV", value = "itv",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(width = 300,
        checkboxInput("itv_nested", "Split ITV into between- and within-site parts", TRUE),
        hint("Used only when a species was sampled at several sites."),
        tags$hr(),
        selectInput("acc_metric", "Rarefaction metric",
                    c("Multivariate variance" = "variance", "Standard deviation" = "sd",
                      "Coefficient of variation" = "cv", "Range" = "range"), DEF$acc_metric),
        numericInput("acc_n_perm", "Sub-samples per sample size", DEF$acc_n_perm, min = 19, step = 10),
        numericInput("acc_conv_tol", "Precision criterion of n* (relative half-width)",
                     DEF$acc_conv_tol, min = 0.01, max = 0.5, step = 0.01),
        actionButton("acc_run", "Rarefaction curves", class = "btn-outline-primary w-100"),
        hint("Can take a minute with many individuals.")),
      card_x("Figure 3 — inter- vs intraspecific variance", plotOutput("itv_plot", height = "460px"),
             DT::DTOutput("itv_tab")),
      card_x("Figure 4 — within-species variability vs number of individuals",
             plotOutput("acc_plot", height = "520px"), DT::DTOutput("acc_tab")))),

  # --- 6. Shape ------------------------------------------------------------------------
  bslib::nav_panel("6. Shape", value = "shape",
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(width = 300,
        checkboxInput("shape", "Include shape in the exported project", SHAPE_OK),
        selectInput("shape_style", "Display", style_choices, DEF$shape_style),
        checkboxInput("shape_remove_outliers", "Remove Procrustes-distance outliers", FALSE),
        numericInput("shape_disparity_iter", "Permutations (shape disparity)", DEF$shape_disparity_iter,
                     min = 99, step = 100),
        actionButton("ss_run", "Build the shape space", class = "btn-primary w-100"),
        if (!SHAPE_OK) hint("geomorph is not available: shape analyses are disabled.")),
      card_x("Figure 5 — shape space (GPA + PCA)", plotOutput("ss_plot", height = "560px"),
             uiOutput("ss_info")))),

  # --- 7. Measurement error ------------------------------------------------------------
  bslib::nav_panel("7. Measurement error", value = "me",
    card_x("Repeated digitizations (the 'bias' sheet of the workbook)",
           uiOutput("me_status"),
           actionButton("me_run", "Compute measurement error", class = "btn-outline-primary"),
           DT::DTOutput("me_tab"), plotOutput("me_plot", height = "420px"))),

  # --- 8. Export -----------------------------------------------------------------------
  bslib::nav_panel("8. Export", value = "export",
    bslib::layout_columns(col_widths = c(4, 8),
      card_x("Reproducible project (.zip)",
        textInput("title", "Title", CFG$title %||% "Morphological analyses"),
        textInput("author", "Author(s)", CFG$author %||% ""),
        textInput("project", "Project (folder) name",
                  paste0("intraitR_analyses_", format(Sys.Date(), "%Y%m%d"))),
        textInput("save_dir", "Also save the .zip in this folder (optional)", "",
                  placeholder = "/path/to/folder"),
        hint("The project is written with the parameters of the tabs, then its own scripts",
             "are RUN (run_all.R): tables, figures and the Methods & Results report come",
             "from them, so the archive reproduces itself."),
        actionButton("build", "Build the project", class = "btn-primary w-100"),
        uiOutput("build_status"),
        uiOutput("dl_ui")),
      card_x("Contents and report",
        bslib::navset_tab(
          bslib::nav_panel("Architecture", uiOutput("tree")),
          bslib::nav_panel("Methods & Results", uiOutput("report")),
          bslib::nav_panel("Run log", verbatimTextOutput("runlog")))))),
  bslib::nav_spacer(),
  bslib::nav_menu(title = "? Help", align = "right",
    bslib::nav_item(tags$a("Step-by-step guide (English)", target = "_blank",
      href = "https://funtraits.github.io/intraitR/articles/apps-workflow.html")),
    bslib::nav_item(tags$a("Guide pas \u00e0 pas (fran\u00e7ais)", target = "_blank",
      href = "https://funtraits.github.io/intraitR/articles/apps-workflow-fr.html")))
)

# =============================================================================
# Server
# =============================================================================
server <- function(input, output, session) {
  rv <- reactiveValues(lm = NULL, rep = NULL, lit = NULL, source = NULL,
                       ts = NULL, td = NULL, pf = NULL, itv = NULL, acc = NULL,
                       gpa = NULL, ss = NULL, sdisp = NULL, me = NULL,
                       job = NULL, job_dir = NULL, result = NULL)

  load_input <- function(xlsx = NULL, specimens = NULL, landmarks = NULL, literature = NULL, label) {
    x <- safely(get(".ana_load_input", ns)(xlsx, specimens, landmarks, literature),
                "Reading the measurements")
    if (is.null(x)) return()
    rv$lm <- x$lm; rv$rep <- x$repeats; rv$lit <- x$literature; rv$source <- label
  }
  isolate(if (!is.null(CFG$landmarks) || !is.null(CFG$xlsx_path) || !is.null(CFG$literature))
    load_input(CFG$xlsx_path, CFG$specimens, CFG$landmarks, CFG$literature,
               if (!is.null(CFG$xlsx_path)) basename(CFG$xlsx_path) else
                 if (!is.null(CFG$landmarks)) "landmarks given in R" else "literature records"))
  has_data <- reactive(!is.null(rv$lm) || !is.null(rv$lit))
  # species / site / provenance of every record (photographs and literature)
  records <- reactive({
    req(has_data())
    md <- if (!is.null(rv$lm)) rv$lm$metadata else NULL
    ph <- if (!is.null(md)) {
      src <- md$source %||% md$data_source %||% rep(NA_character_, nrow(md))
      data.frame(species = as.character(md$species), site = as.character(md$site %||% NA),
                 source = ifelse(is.na(src) | !nzchar(src), "photographs", as.character(src)),
                 stringsAsFactors = FALSE)
    }
    li <- if (!is.null(rv$lit)) data.frame(species = as.character(rv$lit$species),
                                           site = as.character(rv$lit$site %||% NA),
                                           source = "literature", stringsAsFactors = FALSE)
    rbind(ph, li)
  })

  output$source_ui <- renderUI({
    if (has_data())
      return(tags$div(tags$b("Data: "), rv$source, tags$br(),
                      tags$small(class = "text-muted", paste0(
                        if (!is.null(rv$lm)) sprintf("%d photographed specimens", dim(rv$lm$coords)[3]) else "",
                        if (!is.null(rv$lit)) { ns_ <- length(unique(stats::na.omit(rv$lit$study_id)))
                          sprintf("%s%d literature records (%d stud%s)", if (!is.null(rv$lm)) "; " else "",
                                  nrow(rv$lit), ns_, if (ns_ > 1) "ies" else "y") } else "",
                        if (!is.null(rv$rep)) sprintf("; %d repeated digitizations", dim(rv$rep$coords)[3]) else ""))))
    tagList(textInput("xlsx_in", "Digitizer workbook (.xlsx)", "", placeholder = "/path/to/landmarks.xlsx"),
            actionButton("xlsx_go", "Load", class = "btn-primary btn-sm"))
  })
  observeEvent(input$xlsx_go, {
    p <- path.expand(trimws(input$xlsx_in))
    if (!file.exists(p)) { showNotification("File not found.", type = "warning"); return() }
    load_input(p, label = basename(p))
  })

  sp_counts <- reactive({
    s <- records()$species
    t <- sort(table(s[!is.na(s) & nzchar(s)]), decreasing = TRUE); t
  })
  output$species_ui <- renderUI({
    t <- sp_counts()
    selectizeInput("species", "Species (empty = all)", multiple = TRUE,
                   choices = stats::setNames(names(t), sprintf("%s (%d)", names(t), as.integer(t))),
                   options = list(placeholder = "all species with enough individuals"))
  })
  output$sites_ui <- renderUI({
    s <- records()$site
    if (is.null(s) || all(is.na(s))) return(NULL)
    t <- table(s[!is.na(s)])
    selectizeInput("sites", "Sites (empty = all)", multiple = TRUE,
                   choices = stats::setNames(names(t), sprintf("%s (%d)", names(t), as.integer(t))))
  })
  # which ratios each provenance / study provides: a ratio missing from a data
  # set excludes all its records unless it is unchecked
  output$ratio_cover <- renderUI({
    req(has_data())
    pr0 <- prep(); req(pr0); r <- pr0$ratios
    grp <- ifelse(r$source == "literature" & !is.na(r$study_id), r$study_id, r$source)
    cov <- t(sapply(split(r[, RC], grp), function(d) round(100 * colMeans(!is.na(d)))))
    if (is.null(dim(cov))) return(NULL)
    low <- which(cov < 50, arr.ind = TRUE)
    msg <- if (nrow(low)) paste0(unique(sprintf("%s lacks %s", rownames(cov)[low[, 1]], colnames(cov)[low[, 2]])),
                                 collapse = "; ") else NULL
    tagList(
      tags$div(style = "overflow-x:auto;", tags$table(class = "table table-sm",
                 style = "font-size:10px;margin:0;white-space:nowrap;",
        tags$thead(tags$tr(tags$th(""), lapply(colnames(cov), tags$th))),
        tags$tbody(lapply(rownames(cov), function(g) tags$tr(tags$td(g),
          lapply(cov[g, ], function(v) tags$td(style = if (v < 50) "color:#b91c1c;font-weight:600;" else "", v))))))),
      hint("% of records with each ratio.", if (!is.null(msg))
        paste0(msg, ": uncheck it to keep those records (and justify it in the Methods).")))
  })
  output$sources_ui <- renderUI({
    t <- table(records()$source)
    if (length(t) < 2) return(NULL)
    selectizeInput("sources", "Provenance (empty = all)", multiple = TRUE,
                   choices = stats::setNames(names(t), sprintf("%s (%d)", names(t), as.integer(t))))
  })

  data_params <- reactive(intraitR::analysis_params(
    min_n = as.integer(input$min_n %||% DEF$min_n),
    species = if (length(input$species)) input$species else NULL,
    sites = if (length(input$sites)) input$sites else NULL,
    sources = if (length(input$sources)) input$sources else NULL,
    ratios = if (length(input$ratios) >= 2) input$ratios else DEF$ratios,
    impute = isTRUE(input$impute), orientation = isTRUE(input$orientation),
    geometry = isTRUE(input$geometry), scale_cm = input$scale_cm %||% DEF$scale_cm,
    scale_action = input$scale_action %||% DEF$scale_action,
    no_caudal_fin = isTRUE(input$no_caudal_fin), ventral_mouth = isTRUE(input$ventral_mouth),
    no_pectoral_fin = isTRUE(input$no_pectoral_fin)))
  params <- reactive({
    p <- data_params()
    p$ts_axes <- as.integer(strsplit(input$ts_axes %||% "1,2", ",")[[1]])
    p$ts_remove_outliers <- isTRUE(input$ts_remove_outliers)
    p$ts_style <- input$ts_style %||% DEF$ts_style
    p$disparity_iter <- as.integer(input$disparity_iter %||% DEF$disparity_iter)
    p$pf_style <- input$pf_style %||% DEF$pf_style
    p$pf_itv_reference <- isTRUE(input$pf_itv_reference)
    p$pf_arrows <- isTRUE(input$pf_arrows)
    p$itv_nested <- if (isFALSE(input$itv_nested)) "none" else "site"
    p$acc_metric <- input$acc_metric %||% DEF$acc_metric
    p$acc_n_perm <- as.integer(input$acc_n_perm %||% DEF$acc_n_perm)
    p$acc_conv_tol <- input$acc_conv_tol %||% DEF$acc_conv_tol
    p$shape <- SHAPE_OK && isTRUE(input$shape %||% SHAPE_OK)
    p$shape_remove_outliers <- isTRUE(input$shape_remove_outliers)
    p$shape_style <- input$shape_style %||% DEF$shape_style
    p$shape_disparity_iter <- as.integer(input$shape_disparity_iter %||% DEF$shape_disparity_iter)
    p
  })

  prep <- reactive({
    req(has_data())
    safely(get(".ana_prepare", ns)(rv$lm, data_params(), rv$lit), "Computing the traits")
  }) |> debounce(600)
  observeEvent(prep(), {   # new sample: every result computed on the old one goes
    rv$ts <- NULL; rv$td <- NULL; rv$pf <- NULL; rv$itv <- NULL; rv$acc <- NULL
    rv$gpa <- NULL; rv$ss <- NULL; rv$sdisp <- NULL
  })
  enough <- function(k = 2) {
    pr <- prep(); req(pr)
    if (length(unique(pr$species)) < k) {
      validate(need(FALSE, sprintf("At least %d species with %d complete individuals are needed (tab 1).",
                                   k, data_params()$min_n)))
    }
    pr
  }

  # --- 1. Data ------------------------------------------------------------------
  table1 <- reactive({
    pr <- prep(); req(pr); r <- pr$ratios
    sp <- sort(unique(r$species[!is.na(r$species) & nzchar(r$species)]))
    do.call(rbind, lapply(sp, function(s) {
      d <- r[r$species %in% s, , drop = FALSE]
      a <- d[d$analysed, , drop = FALSE]; st <- table(a$source)
      data.frame(species = s, records = nrow(d), complete = sum(d$complete),
                 analysed = nrow(a),
                 sites = if (is.null(d$site)) NA_integer_ else length(unique(stats::na.omit(a$site))),
                 provenance = paste(sprintf("%s %d", names(st), as.integer(st)), collapse = "; "),
                 stringsAsFactors = FALSE)
    }))
  })
  output$data_stats <- renderUI({
    pr <- prep(); req(pr)
    box <- function(v, l) bslib::value_box(title = l, value = format(v, big.mark = ","), theme = "light")
    bslib::layout_columns(col_widths = c(3, 3, 3, 3),
      box(nrow(pr$ratios), "records (photographs + literature)"),
      box(sum(pr$ratios$complete), sprintf("with the %d ratios used", length(data_params()$ratios))),
      box(nrow(pr$traits), "analysed"),
      box(length(pr$kept_species), "species analysed"))
  })
  output$tab1 <- DT::renderDT(dt(table1(), 15))

  # --- 2. Traits ------------------------------------------------------------------
  output$tab2 <- DT::renderDT({
    pr <- enough(1); s <- quietly(intraitR::summary_traits(pr$x, groups = pr$species)); dt(s, 10)
  })
  output$tab_cv <- DT::renderDT({
    pr <- enough(1)
    iv <- quietly(intraitR::intraspecific_variability(traits = pr$x, groups = pr$species))
    cv <- stats::reshape(iv$trait_cv[, c("group", "trait", "cv_percent")], idvar = "group",
                         timevar = "trait", direction = "wide")
    names(cv) <- sub("^cv_percent\\.", "", names(cv)); names(cv)[1] <- "species"
    dt(cv, 10)
  })

  # --- 3. Trait space --------------------------------------------------------------
  observe({
    pr <- prep(); req(pr, length(unique(pr$species)) >= 1)
    # an ordination needs a few specimens and at least two varying ratios
    req(nrow(pr$x) >= 3, sum(vapply(pr$x, function(v) stats::var(v, na.rm = TRUE) > 0, logical(1)),
                             na.rm = TRUE) >= 2)
    p <- params()
    rv$ts <- safely(intraitR::trait_space(pr$x, groups = pr$species, axes = p$ts_axes,
                                          remove_outliers = p$ts_remove_outliers), "Trait space")
  })
  output$ts_plot <- renderPlot({
    req(rv$ts); plot(rv$ts, style = params()$ts_style, legend_italic = TRUE)
  })
  output$ts_info <- renderUI({
    req(rv$ts); ve <- rv$ts$var_explained
    os <- rv$ts$outlier_screen; nf <- if (is.null(os)) 0 else sum(os$flagged %in% TRUE)
    hint(sprintf("%s: %.1f%% and %.1f%% of the variance. %d within-species outlier(s) flagged%s.",
                 paste(names(ve), collapse = " and "), ve[1], ve[2], nf,
                 if (params()$ts_remove_outliers) " and removed" else ""))
  })
  observeEvent(input$td_run, {
    pr <- enough(2)
    rv$td <- safely(intraitR::trait_disparity(pr$x, groups = pr$species,
                                              iter = params()$disparity_iter), "Dispersion test")
  })
  output$td_tab <- DT::renderDT({
    req(rv$td); dt(data.frame(species = names(rv$td$disparity), trait_variance = unname(rv$td$disparity)))
  })
  output$td_pairs <- DT::renderDT({
    req(rv$td)
    m <- rv$td$pairwise_p; idx <- which(upper.tri(m), arr.ind = TRUE)
    d <- data.frame(species_1 = rownames(m)[idx[, 1]], species_2 = colnames(m)[idx[, 2]],
                    abs_difference = rv$td$pairwise_diff[idx], p_value = m[idx])
    d$p_holm <- stats::p.adjust(d$p_value, "holm")
    dt(d[order(d$p_value), ], 8)
  })

  # --- 4. FISHMORPH ------------------------------------------------------------------
  observeEvent(input$pf_run, {
    pr <- enough(1)
    rv$pf <- safely(intraitR::project_fishmorph(pr$x, groups = pr$species, traits = names(pr$x)),
                    "Projecting into FISHMORPH")
  })
  output$pf_plot <- renderPlot({
    validate(need(rv$pf, "Click 'Project into FISHMORPH'."))
    p <- params()
    plot(rv$pf, style = p$pf_style, itv_reference = p$pf_itv_reference, arrows = p$pf_arrows)
  })
  output$pf_tab <- DT::renderDT({
    req(rv$pf); v <- rv$pf$itv_proportion$volume; v$pct_global <- 100 * v$proportion; dt(v)
  })

  # --- 5. ITV ---------------------------------------------------------------------
  observe({
    pr <- prep(); req(pr, length(unique(pr$species)) >= 2)
    nested <- NULL
    if (!isFALSE(input$itv_nested) && !is.null(pr$traits$site)) {
      sps <- tapply(pr$traits$site, pr$species, function(s) length(unique(s)))
      if (any(sps > 1)) nested <- pr$traits$site
    }
    rv$itv <- safely(intraitR::itv_index(pr$x, groups = pr$species, nested = nested), "Variance partition")
  })
  output$itv_plot <- renderPlot({
    validate(need(rv$itv, "At least two species are needed.")); plot(rv$itv)
  })
  output$itv_tab <- DT::renderDT({ req(rv$itv); dt(rbind(rv$itv$per_trait,
    cbind(trait = "all (standardised)", rv$itv$multivariate))) })
  observeEvent(input$acc_run, {
    pr <- enough(1); p <- params()
    rv$acc <- safely(intraitR::itv_accumulation(pr$x, groups = pr$species, metric = p$acc_metric,
                                                n_perm = p$acc_n_perm, conv_tol = p$acc_conv_tol,
                                                asymptote_prop = p$acc_asymptote, min_n = p$min_n,
                                                log_transform = TRUE, seed = p$seed),
                     "Rarefaction")
  })
  output$acc_plot <- renderPlot({ validate(need(rv$acc, "Click 'Rarefaction curves'.")); plot(rv$acc) })
  output$acc_tab <- DT::renderDT({ req(rv$acc); dt(rv$acc$summary) })

  # --- 6. Shape ---------------------------------------------------------------------
  observeEvent(input$ss_run, {
    if (!SHAPE_OK) { showNotification("geomorph is not available.", type = "warning"); return() }
    pr <- enough(1); p <- params()
    res <- safely({
      if (is.null(pr$fish)) stop("no photographed specimen (literature records have no landmarks)")
      keep <- dimnames(pr$fish$coords)[[3]] %in% pr$traits$specimen
      fish <- pr$fish; fish$coords <- fish$coords[, , keep, drop = FALSE]
      fish$metadata <- fish$metadata[keep, , drop = FALSE]
      sh <- intraitR::fishmorph_shape_landmarks(fish, drop_incomplete = TRUE)
      g <- intraitR::gpa_fish(sh, remove_outliers = p$shape_remove_outliers)
      list(g = g, ss = intraitR::shape_space(g, groups = g$metadata$species))
    }, "Procrustes superimposition")
    req(res); rv$gpa <- res$g; rv$ss <- res$ss
  })
  output$ss_plot <- renderPlot({
    validate(need(rv$ss, if (SHAPE_OK) "Click 'Build the shape space'." else "geomorph is not available."))
    plot(rv$ss, style = params()$shape_style, legend_italic = TRUE)
  })
  output$ss_info <- renderUI({ req(rv$gpa); hint(sprintf("%d specimens superimposed.", dim(rv$gpa$coords)[3])) })

  # --- 7. Measurement error ----------------------------------------------------------
  output$me_status <- renderUI({
    if (is.null(rv$rep)) return(hint("No usable repeated digitizations (no 'bias' sheet in the workbook,",
                                     "or fewer than two photographs digitized at least twice): measure",
                                     "some photographs several times with the repeat mode of the",
                                     "digitizer to estimate measurement error."))
    dr <- attr(rv$rep, "dropped")
    hint(sprintf("%d digitizations of %d photographs digitized at least twice.", dim(rv$rep$coords)[3],
                 length(unique(rv$rep$metadata$individual))),
         if (length(dr)) sprintf("Left out, digitized only once: %s.", paste(dr, collapse = ", ")))
  })
  observeEvent(input$me_run, {
    req(rv$rep); p <- data_params(); rl <- rv$rep
    rv$me <- safely({
      seg <- as.data.frame(intraitR::fishmorph_segments(rl, scale_cm = p$scale_cm))
      ind <- rl$metadata$individual[match(seg$specimen, rl$metadata$specimen)]
      tab <- do.call(rbind, lapply(intersect(c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd"),
                                             names(seg)), function(s) {
        ok <- is.finite(seg[[s]])
        me <- tryCatch(intraitR::measurement_error(data.frame(individual = ind[ok], value = seg[[s]][ok]),
                                                   individual = "individual", method = "anova"),
                       error = function(e) NULL)
        data.frame(segment = s, pct_ME = if (is.null(me)) NA else me$percent_measurement_error,
                   R = if (is.null(me)) NA else me$repeatability)
      }))
      sp <- rl$metadata$species %||% rep(NA_character_, dim(rl$coords)[3])
      sp[is.na(sp) | !nzchar(sp)] <- "not identified"
      de <- tryCatch(intraitR::digitization_error(rl, individual = rl$metadata$individual,
                                         species = sp, exclude_landmarks = intersect(c(20, 21, 25), seq_len(dim(rl$coords)[1]))),
                     error = function(e) { showNotification(paste("Placement error per landmark not computed:",
                                                                  conditionMessage(e)), type = "warning", duration = 10)
                                           NULL })
      list(tab = tab, de = de)
    }, "Measurement error")
  })
  output$me_tab <- DT::renderDT({ req(rv$me); dt(rv$me$tab, 11) })
  output$me_plot <- renderPlot({ req(rv$me, rv$me$de); plot(rv$me$de) })

  # --- 8. Export ---------------------------------------------------------------------
  observeEvent(input$build, {
    req(has_data())
    if (!is.null(rv$job) && rv$job$is_alive()) return()
    if (!requireNamespace("callr", quietly = TRUE)) {
      showNotification("Building the project needs the 'callr' package.", type = "error"); return() }
    name <- gsub("[^A-Za-z0-9_.-]+", "_", trimws(input$project))
    if (!nzchar(name)) name <- "intraitR_analyses"
    base <- tempfile("ana_"); dir.create(base)
    dir <- file.path(base, name)
    lm_f <- file.path(base, "lm.rds"); saveRDS(rv$lm, lm_f)
    lit_f <- file.path(base, "lit.rds"); saveRDS(rv$lit, lit_f)
    rep_f <- NULL
    if (!is.null(rv$rep)) { rep_f <- file.path(base, "rep.rds"); saveRDS(rv$rep, rep_f) }
    rv$result <- NULL; rv$job_dir <- dir
    rv$job <- callr::r_bg(function(lm_f, lit_f, rep_f, dir, params, title, author, libs) {
      .libPaths(libs)
      intraitR::write_analysis_project(readRDS(lm_f), dir, params = params,
                                       repeats = if (!is.null(rep_f)) readRDS(rep_f),
                                       literature = readRDS(lit_f),
                                       title = title, author = author, quiet = TRUE)
    }, args = list(lm_f = lm_f, lit_f = lit_f, rep_f = rep_f, dir = dir, params = params(),
                   title = input$title, author = input$author, libs = .libPaths()),
    supervise = TRUE)
  })
  observe({
    j <- rv$job; req(j)
    if (j$is_alive()) { invalidateLater(1000); return() }
    res <- tryCatch(j$get_result(), error = function(e) list(ok = FALSE, error = conditionMessage(e)))
    isolate({
      rv$job <- NULL; rv$result <- res
      sd <- path.expand(trimws(input$save_dir))
      if (isTRUE(nzchar(sd)) && !is.null(res$zip) && dir.exists(sd)) {
        ok <- file.copy(res$zip, file.path(sd, basename(res$zip)), overwrite = TRUE)
        if (ok) showNotification(paste("Saved:", file.path(sd, basename(res$zip))), duration = 10)
      }
    })
  })
  output$build_status <- renderUI({
    if (!is.null(rv$job)) {
      invalidateLater(1500)
      log <- file.path(rv$job_dir %||% "", "results", "run_all.log")
      last <- if (file.exists(log)) utils::tail(grep("Loading|Done|Report", readLines(log, warn = FALSE),
                                                     value = TRUE), 1) else "Writing the project..."
      return(tags$div(class = "alert alert-info mt-3", tags$b("Building… "), last))
    }
    r <- rv$result; if (is.null(r)) return(NULL)
    if (isTRUE(r$ok)) tags$div(class = "alert alert-success mt-3",
                               "Project built and run: tables, figures and report are in the archive.")
    else tags$div(class = "alert alert-danger mt-3", tags$b("The project did not run to the end."),
                  tags$pre(style = "white-space:pre-wrap;font-size:11px;", r$error %||% ""),
                  "The archive still holds the scripts and data: run run_all.R to see the error.")
  })
  output$dl_ui <- renderUI({
    r <- rv$result; req(r, r$zip)
    downloadButton("dl_zip", paste("Download", basename(r$zip)), class = "btn-success w-100 mt-2")
  })
  output$dl_zip <- downloadHandler(filename = function() basename(rv$result$zip),
                                   content = function(f) file.copy(rv$result$zip, f))
  output$tree <- renderUI({
    r <- rv$result
    if (is.null(r)) return(hint("Build the project to see its contents."))
    fs <- sort(list.files(r$dir, recursive = TRUE, all.files = TRUE))
    tags$div(class = "tree", paste(fs, collapse = "\n"))
  })
  output$report <- renderUI({
    r <- rv$result
    if (is.null(r)) return(hint("Build the project to read the Methods & Results."))
    docx <- file.path(r$dir, "manuscript", "Methods_Results.docx")
    if (!file.exists(docx))
      return(hint(if (!isTRUE(r$ok)) "The run stopped before the report (see the Run log tab)." else
        "No rendered report (pandoc not found): knit manuscript/Methods_Results.Rmd in RStudio."))
    html <- tempfile(fileext = ".html")
    ok <- tryCatch({ rmarkdown::pandoc_convert(docx, to = "html", output = html,
                                               options = c("--embed-resources", "--standalone")); TRUE },
                   error = function(e) tryCatch({ rmarkdown::pandoc_convert(docx, to = "html", output = html,
                                                  options = "--self-contained"); TRUE }, error = function(e) FALSE))
    if (!ok) return(hint("The report is in manuscript/Methods_Results.docx."))
    body <- paste(readLines(html, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    body <- sub("(?s).*<body[^>]*>", "", body, perl = TRUE); body <- sub("(?s)</body>.*", "", body, perl = TRUE)
    tags$div(class = "report", HTML(body))
  })
  output$runlog <- renderText({
    r <- rv$result; req(r, r$log, file.exists(r$log))
    paste(readLines(r$log, warn = FALSE), collapse = "\n")
  })
}

shinyApp(ui, server)
