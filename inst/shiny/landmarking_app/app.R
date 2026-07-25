## =============================================================================
## app.R — Landmarking automatique interactif (volet A)
##
## Charge une photo -> 4 clics (museau, base caudale, 2 points de règle) ->
## l'automate ml-morph prédit les 19 landmarks anatomiques -> revue/correction
## manuelle -> export TPS / CSV.
##
## Intégré au package intraitR : lancer via  intraitR::digitize_landmarks()
## (qui résout les ressources ml-morph et pose les variables d'environnement
## INTRAITR_MLMORPH_* ci-dessous, puis appelle shiny::runApp() sur ce dossier).
## L'app reste utilisable seule via shiny::runApp("ml_morph/landmarking_app"),
## auquel cas elle retombe sur le comportement relatif d'origine (dossier ml_morph
## = dossier parent "..").
##
## Nécessite : le venv Python (.venv_mlmorph) avec dlib/opencv, un prédicteur
## entraîné (mlmorph_run_*/predictor.dat) et le jeu aligné
## (mlmorph_dataset_aligned) dans le dossier ml-morph. Voir ml_morph/README.md.
##
## Dépendances R : shiny, jpeg, png.
## =============================================================================

library(shiny)

## ---- Chemins (absolus, robustes au cwd du sous-processus) --------------------
## Résolus par intraitR::digitize_landmarks() via des variables d'environnement
## INTRAITR_MLMORPH_* ; à défaut (app lancée seule) on retombe sur les chemins
## relatifs au dossier ml_morph (dossier parent).
ML <- {
  d <- Sys.getenv("INTRAITR_MLMORPH_DIR", "")               # posé par le lanceur
  if (!nzchar(d)) d <- normalizePath("..", mustWork = FALSE) # sinon dossier ml_morph
  d
}
# Python du venv : INTRAITR_MLMORPH_PY (lanceur) puis PY, puis ~/.venv_mlmorph
# (hors OneDrive), puis le venv local, puis python3.
.py_cand  <- c(Sys.getenv("INTRAITR_MLMORPH_PY", ""), Sys.getenv("PY", ""),
               path.expand("~/.venv_mlmorph/bin/python"),
               file.path(ML, ".venv_mlmorph", "bin", "python"))
PY        <- c(.py_cand[nzchar(.py_cand) & file.exists(.py_cand)], "python3")[1]
# Worker Python : la copie embarquée dans le package (posée par le lanceur via
# INTRAITR_MLMORPH_WORKER) est prioritaire ; sinon celle du dossier ml_morph.
WORKER <- {
  w <- Sys.getenv("INTRAITR_MLMORPH_WORKER", "")
  if (!nzchar(w) || !file.exists(w)) w <- file.path(ML, "predict_new_image.py")
  w
}
DATASET   <- file.path(ML, "mlmorph_dataset_aligned")
# Prédicteurs disponibles (choisis dans l'UI) : un chemin explicite fourni au
# lanceur (argument `predictor=`, via INTRAITR_MLMORPH_PREDICTOR) puis ceux
# trouvés dans le dossier ml-morph.
PRED_CHOICES <- {
  ex <- Sys.getenv("INTRAITR_MLMORPH_PREDICTOR", "")
  Filter(file.exists, c(
    if (nzchar(ex)) c(fourni = ex),
    app     = file.path(ML, "mlmorph_run_app",     "predictor.dat"),
    aligned = file.path(ML, "mlmorph_run_aligned", "predictor.dat")))
}
N_ANAT    <- 19
# Sauvegarde automatique : chemin INSCRIPTIBLE (le dossier de l'app est en lecture
# seule une fois le package installé dans la bibliothèque). Posé par le lanceur
# (INTRAITR_MLMORPH_AUTOSAVE) ; à défaut, dans le répertoire de travail courant.
AUTOSAVE <- {
  a <- Sys.getenv("INTRAITR_MLMORPH_AUTOSAVE", "")
  if (!nzchar(a)) a <- file.path(getwd(), "intraitR_landmarking_autosave.csv")
  a
}
# Landmarks placés automatiquement (non corrigés à la main).
#  - mode standard : 1,2 (clics) + 8,9,11 (dérivés)
#  - mode "forcer" (pin) : on épingle en plus 3,4,7 sur les clics de calibration ;
#    ils deviennent donc auto (l'avance auto de correction les saute aussi).
AUTO_LM     <- c(1L, 2L, 8L, 9L, 11L)
# Mode "forcer" : landmarks épinglés sur les clics (1,2,3,4,7,10,12,15,16,18) +
# dérivés géométriquement (8,9,11). Tous sont sautés par l'avance auto de correction.
AUTO_LM_PIN <- c(1L, 2L, 3L, 4L, 7L, 8L, 9L, 10L, 11L, 12L, 15L, 16L, 18L)
next_manual <- function(cur, n, auto = AUTO_LM) {  # prochain landmark À CORRIGER (saute auto)
  q <- cur
  for (i in seq_len(n)) { q <- if (q < n) q + 1L else 1L
    if (!(q %in% auto)) return(q) }
  cur
}
# Séquences de clics de calibration (dépendent de l'option "forcer" / pin).
#  - pin OFF : museau, caudale, dorsal(orientation), 2 repères de règle       (5 clics)
#  - pin ON  : museau, caudale, LM3(=dorsal), LM4, LM7, LM10, LM12, LM16,
#              LM18, LM15(bouche), puis 2 repères de règle                    (12 clics)
CLICK_LABELS <- c("1 — museau (LM1)", "2 — base caudale (LM2)",
                  "3 — point dorsal (haut du corps, oriente dos-en-haut)",
                  "4 — échelle A (LM20)", "5 — échelle B (LM21)")
CLICK_LABELS_PIN <- c("1 — museau (LM1)", "2 — base caudale (LM2)",
                  "3 — point DORSAL = LM3 (haut du corps, oriente dos-en-haut)",
                  "4 — LM4 (ventral, à l'aplomb de LM3)",
                  "5 — LM7 (référence tête : définit la verticale de l'œil)",
                  "6 — LM10", "7 — LM12", "8 — LM16", "9 — LM18",
                  "10 — LM15 (bouche)",
                  "11 — échelle A (LM20)", "12 — échelle B (LM21)")
# Nombre de clics et positions des repères de règle selon le mode.
n_calib_clicks <- function(pin) if (isTRUE(pin)) 12L else 5L
scale_click_idx <- function(pin) if (isTRUE(pin)) c(11L, 12L) else c(4L, 5L)

# Axe du corps robuste aux points manquants : LM1->LM2 si présents, sinon
# 1re composante principale des landmarks anatomiques (1..17) disponibles.
body_axis <- function(P) {
  a <- P["1", ]; b <- P["2", ]
  idx <- intersect(as.character(1:17), rownames(P))
  M <- P[idx, , drop = FALSE]; M <- M[stats::complete.cases(M), , drop = FALSE]
  if (all(is.finite(a)) && all(is.finite(b)) && sum((b - a)^2) > 0) {
    o <- a; u <- (b - a) / sqrt(sum((b - a)^2))
  } else {
    if (nrow(M) < 2) return(NULL)
    o <- colMeans(M); u <- eigen(stats::cov(M))$vectors[, 1]
    ref <- if (all(is.finite(b))) b - o else if (all(is.finite(a))) o - a else c(1, 0)
    if (sum(u * ref) < 0) u <- -u        # oriente tête -> queue
  }
  len <- if (nrow(M) >= 2)
    diff(range(as.vector((M - matrix(o, nrow(M), 2, byrow = TRUE)) %*% u)))
    else sqrt(sum((b - a)^2))
  list(o = o, u = u, len = len)
}

# Force l'ORDRE VERTICAL dorsal->ventral 5 > 13 > 7 > 14 > 6 > 8 le long de la
# verticale de 7 (perpendiculaire à l'axe 1-2), AVEC l'œil symétrique autour de 7
# (centre de l'œil) : dist(7,13) = dist(7,14) = h. Ancres FIXES : 7 (forcé) et 8
# (dérivé ventral). On projette 5,13,14,6 sur cette verticale et on borne les
# hauteurs (coord dorsale `t`, positive vers le dos) :
#   5 dorsal (t>=+m) ; 6 ventral dans ]8,7[ ; 13 = +h ; 14 = -h,
#   h = demi-hauteur d'œil observée, bornée pour rester sous 5 et au-dessus de 6.
# m = petite marge (0.5 % de la longueur de corps) qui évite les points confondus.
enforce_head_order <- function(P, o, u, vp, len) {
  if (!all(is.finite(P["7", ]))) return(P)
  pe <- function(x) sum((x - o) * vp)
  a7 <- sum((P["7", ] - o) * u); p7 <- pe(P["7", ])
  up <- if (all(is.finite(c(P["5", ], P["6", ])))) sign(pe(P["5", ]) - pe(P["6", ]))
        else if (all(is.finite(c(P["3", ], P["4", ])))) sign(pe(P["3", ]) - pe(P["4", ]))
        else 1
  if (up == 0) up <- 1
  m   <- max(1e-6, 0.005 * len)
  tof <- function(q) up * (pe(P[q, ]) - p7)             # coord dorsale de q
  put <- function(t) o + a7 * u + (p7 + up * t) * vp    # pose sur la verticale de 7
  t8 <- if (all(is.finite(P["8", ]))) tof("8") else NA_real_
  # 6 : ventral (t<=-m) et au-dessus de 8 (t>=t8+m)
  if (all(is.finite(P["6", ]))) {
    t6 <- min(tof("6"), -m); if (is.finite(t8)) t6 <- max(t6, t8 + m)
    P["6", ] <- put(t6)
  }
  # 5 : dorsal (t>=+m)
  if (all(is.finite(P["5", ]))) P["5", ] <- put(max(tof("5"), m))
  t5 <- if (all(is.finite(P["5", ]))) tof("5") else NA_real_
  t6 <- if (all(is.finite(P["6", ]))) tof("6") else NA_real_
  # 13 (haut) et 14 (bas) SYMÉTRIQUES autour de 7 (centre de l'œil) :
  # même distance h à 7. h = demi-hauteur moyenne observée, bornée pour que
  # 13 reste sous 5 (h <= t5 - m) et 14 au-dessus de 6 (h <= -t6 - m).
  d13 <- if (all(is.finite(P["13", ]))) abs(tof("13")) else NA_real_
  d14 <- if (all(is.finite(P["14", ]))) abs(tof("14")) else NA_real_
  hobs <- mean(c(d13, d14), na.rm = TRUE)
  if (is.finite(hobs)) {
    hmax <- Inf
    if (is.finite(t5)) hmax <- min(hmax, t5 - m)        # 13 sous 5
    if (is.finite(t6)) hmax <- min(hmax, -t6 - m)       # 14 au-dessus de 6 (t6<0)
    h <- min(max(hobs, m), max(hmax, m))                # borné dans [m, hmax]
    if (all(is.finite(P["13", ]))) P["13", ] <- put( h)
    if (all(is.finite(P["14", ]))) P["14", ] <- put(-h)
  }
  P
}

# Propage les conventions FISHMORPH à partir des ancres FORCÉES vers les points
# dépendants, en coordonnées ABSOLUES (pas de delta). Utilisé juste après une
# prédiction en mode "forcer" (pin), quand 1,2,3,4,7,10,12,15,16,18 sont épinglés.
# Conventions (mêmes relations que enforce_from) :
#   (2) LM3-LM4 PERPENDICULAIRE à l'axe 1-2 : LM4 verrouillé à l'aplomb de LM3
#       (même axiale), libre le long de la perpendiculaire (hauteur ventrale).
#   (3) DÉRIVÉS ventraux 8,9,11 : perpendiculaire commune = celle de 4,
#       aux verticales de 7 / 1 / 10. (8 = ancre ventrale de l'ordre tête.)
#   (1) ORDRE VERTICAL tête 5 > 13 > 7 > 14 > 6 > 8 (via enforce_head_order).
apply_fishmorph <- function(P) {
  axis <- body_axis(P); if (is.null(axis)) return(P)
  o <- axis$o; u <- axis$u; vp <- c(-u[2], u[1])
  ax <- function(x) sum((x - o) * u); pe <- function(x) sum((x - o) * vp)
  recon <- function(a, pp) o + a * u + pp * vp
  # (2) LM4 sur la verticale (perpendiculaire à 1-2) de LM3, garde sa hauteur
  if (all(is.finite(c(P["3", ], P["4", ]))))
    P["4", ] <- recon(ax(P["3", ]), pe(P["4", ]))
  # (3) dérivés ventraux 8,9,11 (avant l'ordre : 8 sert d'ancre ventrale)
  if (all(is.finite(P["4", ]))) {
    p4 <- pe(P["4", ])
    if (all(is.finite(P["1", ])))  P["9", ]  <- recon(ax(P["1", ]),  p4)
    if (all(is.finite(P["7", ])))  P["8", ]  <- recon(ax(P["7", ]),  p4)
    if (all(is.finite(P["10", ]))) P["11", ] <- recon(ax(P["10", ]), p4)
  }
  # (1) ordre vertical tête 5 > 13 > 7 > 14 > 6 > 8
  P <- enforce_head_order(P, o, u, vp, axis$len)
  P
}

read_image <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("jpg", "jpeg")) jpeg::readJPEG(path)
  else if (ext == "png") png::readPNG(path)
  else stop("Format non supporté (jpg/jpeg/png) : ", ext)
}
# Sous-échantillonnage pour l'AFFICHAGE seulement (les coordonnées restent en
# pixels d'origine ; rasterImage réétire l'image sur la même boîte rv$w x rv$h).
downscale <- function(a, maxdim = 1600L) {
  d <- dim(a); if (max(d[1], d[2]) <= maxdim) return(a)
  st <- ceiling(max(d[1], d[2]) / maxdim)
  ri <- seq(1L, d[1], by = st); ci <- seq(1L, d[2], by = st)
  if (length(d) == 3) a[ri, ci, , drop = FALSE] else a[ri, ci, drop = FALSE]
}

## ---- UI ---------------------------------------------------------------------
ui <- fluidPage(
  # clic droit maintenu sur la photo = déplacer la vue (envoie des deltas à Shiny)
  tags$head(tags$script(HTML(paste(
    "(function(){var dg=false,lx=0,ly=0,adx=0,ady=0,c=0,raf=null;",
    "function el(){return document.getElementById('img');}",
    "function flush(){raf=null;if(adx===0&&ady===0)return;Shiny.setInputValue('pan',{dx:adx,dy:ady,n:++c},{priority:'event'});adx=0;ady=0;}",
    "document.addEventListener('contextmenu',function(e){var m=el();if(m&&m.contains(e.target))e.preventDefault();});",
    "document.addEventListener('mousedown',function(e){var m=el();if(m&&m.contains(e.target)&&e.button===2){dg=true;lx=e.clientX;ly=e.clientY;e.preventDefault();}});",
    "document.addEventListener('mousemove',function(e){if(!dg)return;var m=el();if(!m)return;var r=m.getBoundingClientRect();adx+=(e.clientX-lx)/r.width;ady+=(e.clientY-ly)/r.height;lx=e.clientX;ly=e.clientY;if(!raf)raf=requestAnimationFrame(flush);});",
    "document.addEventListener('mouseup',function(e){if(e.button===2){dg=false;if(!raf)raf=requestAnimationFrame(flush);}});",
    "})();", sep = "\n")))),
  titlePanel("Landmarking automatique — ml-morph"),
  sidebarLayout(
    sidebarPanel(width = 3,
      tags$strong("Dossier de photos"),
      textInput("photo_dir", NULL, placeholder = "chemin du dossier…"),
      actionButton("load_dir", "Charger le dossier", class = "btn-primary"),
      uiOutput("dir_progress"),
      div(style = "margin:4px 0;",
          actionButton("prev_photo", "◀ Précédent"),
          actionButton("next_photo", "Suivant ▶")),
      div(style = "margin:4px 0; display:flex; gap:4px; align-items:flex-end;",
          numericInput("goto_photo", "Aller à la photo n°", value = 1, min = 1,
                       width = "130px"),
          actionButton("goto_btn", "Aller")),
      tags$hr(),
      fileInput("photo", "…ou une photo seule (jpg/png)", accept = c(".jpg", ".jpeg", ".png")),
      textInput("specimen_id", "Code spécimen", ""),
      radioButtons("quality", "Note qualité (1 = très bien → 5 = mauvais)",
                   choices = c("1" = 1, "2" = 2, "3" = 3, "4" = 4, "5" = 5),
                   selected = 3, inline = TRUE),
      if (length(PRED_CHOICES))
        selectInput("pred", "Modèle", choices = PRED_CHOICES)
      else div(style = "color:red", "Aucun predictor.dat trouvé dans ml_morph/"),
      numericInput("scale_mm", "Distance règle 20-21 (mm)", 10, min = 0),
      checkboxInput("pin", "Forcer les landmarks fiables (LM1,2,3,4,7) sur les clics",
                    value = FALSE),
      checkboxInput("fastdisp", "Affichage rapide (photo allégée)", value = TRUE),
      checkboxInput("guides", "Guides d'alignement", value = FALSE),
      checkboxInput("fishguides", "Guides géométriques FISHMORPH", value = FALSE),
      radioButtons("flip_mode", "Retourner la photo",
                   c("Aucun" = "none", "Horizontal" = "h", "Vertical" = "v", "180°" = "hv"),
                   inline = TRUE),
      div(actionButton("zoom_in", "Zoom +"), actionButton("zoom_out", "Zoom −"),
          actionButton("zoom_reset", "Vue entière")),
      helpText("Le zoom se centre sur le landmark sélectionné."),
      tags$hr(),
      # --- Réviser des mesures déjà faites (CSV specimen,landmark,X,Y[,mm_per_px]) ---
      tags$strong("Réviser des mesures existantes"),
      fileInput("measures_file", "Tableau de mesures (CSV)", accept = c(".csv", ".tsv", ".txt")),
      uiOutput("load_specimen_ui"),
      helpText("Charge une photo puis sélectionnez le spécimen correspondant pour",
               "contrôler / corriger ses landmarks. Coordonnées attendues : pixels image",
               "(mêmes que l'export). Gardez « Retourner la photo » sur Aucun."),
      tags$hr(),
      tags$strong("Ce spécimen :"),
      downloadButton("dl_csv", "CSV"), downloadButton("dl_tps", "TPS"),
      tags$hr(),
      tags$strong("Table multi-poissons"),
      textOutput("saved_info"),
      downloadButton("dl_all", "Exporter toutes les mesures"),
      actionButton("clear_all", "Vider la table")
    ),
    mainPanel(width = 9,
      uiOutput("click_help"),
      uiOutput("auto_help"),
      helpText("Zoom : boutons +/- ; clic droit maintenu = se déplacer sur la photo ;",
               "double-clic = vue entière."),
      uiOutput("phase_ui"),     # boutons d'action (Prédire / NA / Enregistrer…) remontés ici
      uiOutput("lm_buttons"),   # barre de sélection du landmark à corriger (au-dessus de la photo)
      plotOutput("img", click = "click",
                 dblclick = "img_dblclick", height = "700px"),
      verbatimTextOutput("status")
    )
  )
)

## ---- Server -----------------------------------------------------------------
server <- function(input, output, session) {
  rv <- reactiveValues(img = NULL, img_full = NULL, w = NULL, h = NULL, path = NULL,
                       clicks = list(), pred = NULL, sel = 1L, msg = "",
                       saved = NULL,   # table cumulée de tous les poissons mesurés
                       zoom = 1, cx = NULL, cy = NULL,   # état du zoom / centre de vue
                       orig = NULL, flip = "none",       # photo d'origine + retournement
                       dir_files = NULL, dir_i = 0L)     # dossier de photos + index courant
  # Reprise : recharge la sauvegarde automatique si elle existe
  if (file.exists(AUTOSAVE))
    try(rv$saved <- utils::read.csv(AUTOSAVE, stringsAsFactors = FALSE), silent = TRUE)

  # Adapte les autres landmarks aux conventions FISHMORPH quand on déplace `sel`.
  # Les contraintes agissent sur des coordonnées orthogonales (axiale via u,
  # perpendiculaire via vp) donc les points partagés (4,8,9) restent cohérents.
  enforce_from <- function(sel, delta = c(0, 0)) {
    P <- rv$pred; if (is.null(P)) return()
    axis <- body_axis(P); if (is.null(axis)) return()
    o <- axis$o; u <- axis$u; vp <- c(-u[2], u[1])
    ax <- function(x) sum((x - o) * u); pe <- function(x) sum((x - o) * vp)
    recon <- function(a, pp) o + a * u + pp * vp
    s <- as.character(sel); aP <- ax(P[s, ]); pP <- pe(P[s, ])
    for (pr in list(c("1","9"), c("3","4"), c("10","11")))
      if (s %in% pr) { oth <- setdiff(pr, s)
        if (all(is.finite(P[oth, ]))) P[oth, ] <- recon(aP, pe(P[oth, ])) }
    hg <- c("9","8","11","4")                                          # groupe ventral
    if (s %in% hg) for (q in setdiff(hg, s))
      if (all(is.finite(P[q, ]))) P[q, ] <- recon(ax(P[q, ]), pP)       # même perpendiculaire
    # Ordre vertical tête 5>13>7>14>6>8 : appliqué en fin de fonction (après les
    # dérivés) via enforce_head_order dès qu'un point de la tête bouge.
    # caudale : garde 16-17 // 18-19 (aligne l'autre segment sur celui déplacé)
    if (s %in% c("16","17") && all(is.finite(c(P["18", ], P["19", ])))) {
      d <- P["17", ] - P["16", ]; d <- d / sqrt(sum(d^2))
      m <- (P["18", ] + P["19", ]) / 2; L <- sqrt(sum((P["19", ] - P["18", ])^2))
      P["18", ] <- m - d * L / 2; P["19", ] <- m + d * L / 2
    }
    if (s %in% c("18","19") && all(is.finite(c(P["16", ], P["17", ])))) {
      d <- P["19", ] - P["18", ]; d <- d / sqrt(sum(d^2))
      m <- (P["16", ] + P["17", ]) / 2; L <- sqrt(sum((P["17", ] - P["16", ])^2))
      P["16", ] <- m - d * L / 2; P["17", ] <- m + d * L / 2
    }
    # Points DÉRIVÉS (placés automatiquement) : 9, 8, 11 = ligne ventrale
    # (perpendiculaire commune = celle de 4) x verticale de 1 / 7 / 10.
    if (all(is.finite(P["4", ]))) {
      p4 <- pe(P["4", ])
      if (all(is.finite(P["1", ])))  P["9", ]  <- recon(ax(P["1", ]),  p4)
      if (all(is.finite(P["7", ])))  P["8", ]  <- recon(ax(P["7", ]),  p4)
      if (all(is.finite(P["10", ]))) P["11", ] <- recon(ax(P["10", ]), p4)
    }
    # Dès qu'un point de la tête bouge (ou 7), on ré-impose l'ordre vertical
    # 5>13>7>14>6>8 sur la verticale de 7.
    if (s %in% c("7","5","6","13","14"))
      P <- enforce_head_order(P, o, u, vp, axis$len)
    rv$pred <- P
  }

  zoom_to_sel <- function() {
    if (!is.null(rv$pred) && all(is.finite(rv$pred[rv$sel, ]))) {
      rv$cx <- rv$pred[rv$sel, 1]; rv$cy <- rv$pred[rv$sel, 2] }
  }
  observeEvent(input$zoom_in,  { rv$zoom <- min(rv$zoom * 1.5, 12); zoom_to_sel() })
  observeEvent(input$zoom_out, { rv$zoom <- max(rv$zoom / 1.5, 1)
    if (rv$zoom == 1) { rv$cx <- NULL; rv$cy <- NULL } })
  observeEvent(input$zoom_reset, { rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL })
  # Zoom via les boutons +/- ; le deplacement de la vue se fait en cliquant sur la
  # photo (voir observeEvent(input$click)). Double-clic = vue entiere.
  observeEvent(input$img_dblclick, { rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL })  # vue entière
  # clic droit maintenu : déplacement (pan) de la vue
  observeEvent(input$pan, {
    if (is.null(rv$img) || rv$zoom <= 1) return()
    if (is.null(rv$cx)) rv$cx <- rv$w / 2
    if (is.null(rv$cy)) rv$cy <- rv$h / 2
    rv$cx <- rv$cx - input$pan$dx * (rv$w / rv$zoom)
    rv$cy <- rv$cy - input$pan$dy * (rv$h / rv$zoom)
  })
  # bascule affichage rapide (ne réinitialise pas les points)
  observeEvent(input$fastdisp, {
    if (!is.null(rv$img_full))
      rv$img <- if (isTRUE(input$fastdisp)) downscale(rv$img_full) else rv$img_full
  }, ignoreInit = TRUE)

  # Applique le retournement (h/v/180) à l'image d'origine et prépare l'image de
  # travail : rv$img (affichage) + rv$path (fichier envoyé au worker). Ainsi clics,
  # prédiction et export sont tous cohérents avec l'image retournée.
  apply_flip <- function(im, mode) {
    H <- dim(im)[1]; W <- dim(im)[2]
    if (grepl("h", mode)) im <- im[, W:1, , drop = FALSE]
    if (grepl("v", mode)) im <- im[H:1, , , drop = FALSE]
    im
  }
  load_working <- function() {
    if (is.null(rv$orig)) return()
    im <- tryCatch(read_image(rv$orig),
                   error = function(e) { rv$msg <- conditionMessage(e); NULL })
    if (is.null(im)) return()
    if (length(dim(im)) == 3 && dim(im)[3] > 3) im <- im[, , 1:3, drop = FALSE]
    im <- apply_flip(im, rv$flip)
    rv$h <- dim(im)[1]; rv$w <- dim(im)[2]        # dims ORIGINALES (coordonnées)
    rv$img_full <- im                              # pleine résolution (worker + bascule)
    rv$img <- if (isTRUE(input$fastdisp)) downscale(im) else im
    if (rv$flip == "none") {
      rv$path <- rv$orig
    } else {                                   # écrit l'image retournée pour le worker
      tf <- tempfile(fileext = ".jpg"); jpeg::writeJPEG(im, tf, quality = 0.95)
      rv$path <- tf
    }
    rv$clicks <- list(); rv$pred <- NULL; rv$sel <- 1L
    rv$zoom <- 1; rv$cx <- NULL; rv$cy <- NULL
  }

  observeEvent(input$photo, {
    rv$orig <- input$photo$datapath; rv$flip <- "none"
    rv$dir_files <- NULL; rv$dir_i <- 0L            # photo seule -> quitte le mode dossier
    updateRadioButtons(session, "flip_mode", selected = "none")
    updateTextInput(session, "specimen_id",
                    value = tools::file_path_sans_ext(input$photo$name))
    load_working()
    rv$msg <- "Image chargée. Cliquez le museau (point 1)."
  })

  # --- Navigation par dossier (Précédent / Suivant) --------------------------
  load_dir_photo <- function(i) {
    n <- length(rv$dir_files)
    if (!n) return()
    i <- max(1L, min(as.integer(i), n)); rv$dir_i <- i
    updateNumericInput(session, "goto_photo", value = i, max = n)
    p <- rv$dir_files[i]
    rv$orig <- p; rv$flip <- "none"
    updateRadioButtons(session, "flip_mode", selected = "none")
    updateTextInput(session, "specimen_id",
                    value = tools::file_path_sans_ext(basename(p)))
    load_working()
    rv$msg <- sprintf("Photo %d/%d chargée. Cliquez le museau (point 1).", i, n)
  }
  observeEvent(input$load_dir, {
    d <- trimws(input$photo_dir)
    if (!nzchar(d) || !dir.exists(d)) { rv$msg <- "Dossier introuvable."; return() }
    files <- sort(list.files(d, pattern = "\\.(jpg|jpeg|png|JPG|JPEG|PNG)$",
                             full.names = TRUE))
    if (!length(files)) { rv$msg <- "Aucune photo (jpg/png) dans ce dossier."; return() }
    rv$dir_files <- files; load_dir_photo(1L)
  })
  observeEvent(input$next_photo, if (length(rv$dir_files)) load_dir_photo(rv$dir_i + 1L))
  observeEvent(input$prev_photo, if (length(rv$dir_files)) load_dir_photo(rv$dir_i - 1L))
  observeEvent(input$goto_btn,
    if (length(rv$dir_files) && !is.na(input$goto_photo)) load_dir_photo(input$goto_photo))

  output$dir_progress <- renderUI({
    n <- length(rv$dir_files)
    if (!n) return(helpText("Aucun dossier chargé."))
    code <- tools::file_path_sans_ext(basename(rv$dir_files[rv$dir_i]))
    done <- if (!is.null(rv$saved) && "specimen" %in% names(rv$saved))
              sum(tools::file_path_sans_ext(basename(rv$dir_files)) %in% rv$saved$specimen)
            else 0L
    HTML(sprintf(
      "<b>%s</b><br>Photo %d / %d &nbsp;·&nbsp; reste %d<br>Déjà enregistrées : %d",
      code, rv$dir_i, n, n - rv$dir_i, done))
  })
  observeEvent(input$flip_mode, {
    if (!is.null(rv$orig)) {
      rv$flip <- input$flip_mode; load_working()
      rv$msg <- "Photo retournée — recliquez les points (museau, caudale, règle)."
    }
  }, ignoreInit = TRUE)

  # --- Réviser des mesures existantes ------------------------------------------
  # Charge un CSV (specimen, landmark, X, Y[, mm_per_px] ; X,Y en pixels image) et
  # place les landmarks d'un spécimen sur la photo pour contrôle/correction.
  observeEvent(input$measures_file, {
    df <- tryCatch(utils::read.csv(input$measures_file$datapath, stringsAsFactors = FALSE,
                                   check.names = FALSE),
                   error = function(e) NULL)
    if (is.null(df) || !ncol(df)) { rv$msg <- "Lecture du CSV impossible."; return() }
    names(df) <- tolower(names(df))
    pick <- function(cands) { h <- intersect(cands, names(df)); if (length(h)) h[1] else NA }
    spc <- pick(c("specimen", "code", "id")); lmc <- pick(c("landmark", "lm"))
    xc  <- pick("x"); yc <- pick("y")
    ntc <- pick(c("note", "quality", "qualite", "qualité"))   # note qualité si présente
    if (any(is.na(c(spc, lmc, xc, yc)))) {
      rv$msg <- "CSV invalide : colonnes attendues specimen, landmark, X, Y."; return()
    }
    d <- data.frame(specimen = as.character(df[[spc]]),
                    landmark = suppressWarnings(as.integer(df[[lmc]])),
                    X = suppressWarnings(as.numeric(df[[xc]])),
                    Y = suppressWarnings(as.numeric(df[[yc]])),
                    note = if (!is.na(ntc)) suppressWarnings(as.integer(df[[ntc]])) else NA_integer_,
                    stringsAsFactors = FALSE)
    d <- d[!is.na(d$landmark), , drop = FALSE]
    if (!nrow(d)) { rv$msg <- "CSV vide ou colonnes non numériques."; return() }
    rv$loaded <- d
    sp <- sort(unique(d$specimen))
    rv$loaded_sel <- if (nzchar(input$specimen_id) && input$specimen_id %in% sp)
                       input$specimen_id else sp[1]
    rv$msg <- paste0("Tableau chargé : ", length(sp), " spécimen(s). ",
                     "Sélectionnez-en un puis « Charger sur la photo ».")
  })

  output$load_specimen_ui <- renderUI({
    if (is.null(rv$loaded)) return(NULL)
    sp <- sort(unique(rv$loaded$specimen))
    tagList(
      selectInput("load_specimen", "Spécimen du tableau", choices = sp,
                  selected = rv$loaded_sel),
      actionButton("load_measures_btn", "Charger sur la photo", class = "btn-primary"))
  })

  observeEvent(input$load_measures_btn, {
    req(rv$loaded, input$load_specimen)
    d <- rv$loaded[rv$loaded$specimen == input$load_specimen, , drop = FALSE]
    if (!nrow(d)) { rv$msg <- "Aucune ligne pour ce spécimen."; return() }
    NTOT <- max(21L, max(d$landmark, na.rm = TRUE))
    M <- matrix(NA_real_, NTOT, 2, dimnames = list(seq_len(NTOT), c("X", "Y")))
    ok <- d$landmark >= 1 & d$landmark <= NTOT
    M[as.character(d$landmark[ok]), ] <- as.matrix(d[ok, c("X", "Y")])
    rv$pred <- M; rv$clicks <- list()
    auto <- if (isTRUE(input$pin)) AUTO_LM_PIN else AUTO_LM
    rv$sel <- next_manual(1L, NTOT, auto)
    updateTextInput(session, "specimen_id", value = input$load_specimen)
    nt <- if ("note" %in% names(d)) d$note[!is.na(d$note)] else integer(0)   # note existante
    if (length(nt)) updateRadioButtons(session, "quality", selected = as.character(nt[1]))
    rv$msg <- paste0("Landmarks de « ", input$load_specimen, " » chargés (", sum(ok),
                     " points) — sans re-dérivation. Corrigez via les boutons puis exportez.",
                     if (is.null(rv$img)) " (Chargez la photo correspondante pour les voir.)")
  })

  # Clic : phase calibration (<=4 pts) puis phase correction (déplace le LM choisi)
  observeEvent(input$click, {
    if (is.null(rv$img)) return()
    p <- c(input$click$x, input$click$y)
    if (is.null(rv$pred)) {
      nmax <- n_calib_clicks(input$pin)
      labs <- if (isTRUE(input$pin)) CLICK_LABELS_PIN else CLICK_LABELS
      if (length(rv$clicks) < nmax) {
        rv$clicks[[length(rv$clicks) + 1]] <- p
        nxt <- length(rv$clicks) + 1
        rv$msg <- if (nxt <= nmax) paste("Cliquez :", labs[nxt])
                  else "Points posés — cliquez « Prédire »."
      }
    } else if (isTRUE(input$move_all)) {
      cur <- rv$pred[rv$sel, ]                       # translation rigide de tout le bloc
      if (all(is.finite(cur))) {
        rv$pred <- sweep(rv$pred, 2, p - cur, "+")
        rv$msg <- paste0("Bloc déplacé (via LM", rv$sel, ").")
      }
    } else {
      old <- rv$pred[rv$sel, ]
      rv$pred[rv$sel, ] <- p
      del <- if (all(is.finite(old))) p - old else c(0, 0)
      if (isTRUE(input$auto_constraints)) enforce_from(rv$sel, del)
      auto <- if (isTRUE(input$pin)) AUTO_LM_PIN else AUTO_LM
      nxt <- next_manual(rv$sel, nrow(rv$pred), auto)          # saute les points auto
      rv$msg <- paste0("Landmark ", rv$sel, " posé → suivant : ", nxt, ".")
      rv$sel <- nxt   # la barre de boutons se met à jour automatiquement (renderUI)
    }
  })

  # Aides contextuelles (dépendent de l'option "forcer" / pin)
  output$click_help <- renderUI({
    if (isTRUE(input$pin))
      helpText("Mode FORCER (12 clics) : museau, base de caudale, DORSAL (= LM3,",
               "oriente dos-en-haut), LM4, LM7, LM10, LM12, LM16, LM18, LM15 (bouche),",
               "puis les 2 repères de règle. Puis « Prédire » : 1,2,3,4,7,10,12,15,16,18",
               "sont figés sur vos clics, 8/9/11 dérivés, et le modèle ne prédit que le reste.")
    else
      helpText("Cliquez dans l'ordre : museau, base de caudale, un point DORSAL (haut",
               "du corps — oriente dos-en-haut), puis les 2 repères de la règle — 5 clics.",
               "Puis « Prédire ». Ensuite, sélectionnez un landmark et cliquez pour le",
               "repositionner (20-21 = règle, se placent de la même façon).")
  })
  output$auto_help <- renderUI({
    if (isTRUE(input$pin))
      helpText(tags$b("À corriger :"), "5,6,13,14,17,19 (l'avance auto s'y arrête).",
               tags$br(), tags$b("Forcés/dérivés :"),
               "1,2,3,4,7,10,12,15,16,18 (clics) et 8,9,11 (dérivés de 1,7,10 et 4).")
    else
      helpText(tags$b("À corriger :"), "3,4,5,6,7,10,12,13→21 (l'avance auto s'y arrête).",
               tags$br(), tags$b("Auto :"), "1,2 (clics) et 8,9,11 (dérivés de 1,7,10 et 4).")
  })

  output$phase_ui <- renderUI({
    if (is.null(rv$pred)) {
      tagList(
        actionButton("undo", "Annuler dernier clic"),
        actionButton("predict", "Prédire les 19 landmarks", class = "btn-primary"))
    } else {
      tagList(
        helpText("Sélectionnez le landmark à corriger via les boutons numérotés",
                 "au-dessus de la photo, puis cliquez sa position."),
        checkboxInput("move_all", "Déplacer tout le bloc (au clic)", FALSE),
        checkboxInput("auto_constraints", "Contraintes auto (adapter les autres)", TRUE),
        actionButton("snap1", "Recaler LM1 sur le clic museau"),
        actionButton("set_na", "Marquer NA (non mesurable)"),
        tags$hr(),
        actionButton("save_specimen", "✓ Enregistrer ce spécimen", class = "btn-success"),
        actionButton("restart", "Recommencer (nouveaux clics)"))
    }
  })
  # Barre de boutons numérotés (au-dessus de la photo) pour choisir le landmark à
  # corriger : plus rapide que le menu déroulant. Le sélectionné est vert, les
  # points forcés/dérivés (auto) sont grisés mais restent cliquables. Boutons HTML
  # simples qui posent input$sel_btn (robuste au ré-affichage, contrairement à des
  # actionButton dont le compteur se réinitialiserait à chaque renderUI).
  output$lm_buttons <- renderUI({
    if (is.null(rv$pred)) return(NULL)
    auto <- if (isTRUE(input$pin)) AUTO_LM_PIN else AUTO_LM
    btns <- lapply(seq_len(nrow(rv$pred)), function(i) {
      col <- if (i == rv$sel) "background:#28a745;color:#fff;font-weight:bold;"
             else if (i %in% auto) "background:#eee;color:#999;" else "background:#f7f7f7;"
      tags$button(type = "button", i,
        onclick = sprintf("Shiny.setInputValue('sel_btn', %d, {priority:'event'});", i),
        style = paste0("margin:1px;padding:3px 7px;min-width:32px;border:1px solid #ccc;",
                       "border-radius:3px;cursor:pointer;", col))
    })
    div(style = "margin-bottom:6px;line-height:2;",
        tags$strong("Corriger le landmark : "), btns)
  })
  observeEvent(input$sel_btn, { rv$sel <- as.integer(input$sel_btn) })
  observeEvent(input$set_na, { rv$pred[rv$sel, ] <- NA_real_
    rv$msg <- paste("Landmark", rv$sel, "marqué NA (non mesurable).") })
  observeEvent(input$snap1, {                        # recale tout le bloc : LM1 -> clic museau
    if (is.null(rv$pred) || length(rv$clicks) < 1) return()
    cur <- rv$pred[1, ]
    if (all(is.finite(cur))) {
      rv$pred <- sweep(rv$pred, 2, rv$clicks[[1]] - cur, "+")
      rv$msg <- "Bloc recalé : LM1 sur le clic museau."
    }
  })
  # --- Table multi-poissons ---
  observeEvent(input$save_specimen, {
    req(rv$pred)
    id <- trimws(input$specimen_id); if (id == "") id <- "specimen"
    p20 <- rv$pred["20", ]; p21 <- rv$pred["21", ]     # échelle depuis 20-21 finaux
    mmpp <- if (all(is.finite(c(p20, p21))) && input$scale_mm > 0)
              input$scale_mm / sqrt(sum((p21 - p20)^2)) else NA_real_
    note <- suppressWarnings(as.integer(input$quality))   # note qualité 1 (très bien) .. 5 (mauvais)
    df <- data.frame(specimen = id, landmark = as.integer(rownames(rv$pred)),
                     X = rv$pred[, 1], Y = rv$pred[, 2], mm_per_px = mmpp,
                     note = note,                          # même valeur répétée sur les 21 lignes
                     row.names = NULL)
    if (!is.null(rv$saved)) {
      rv$saved <- rv$saved[rv$saved$specimen != id, , drop = FALSE]
      if (!"note" %in% names(rv$saved))               # compat tables enregistrées avant la note
        rv$saved$note <- NA_integer_
    }
    rv$saved <- rbind(rv$saved, df)
    try(utils::write.csv(rv$saved, AUTOSAVE, row.names = FALSE), silent = TRUE)  # autosave
    rv$msg <- paste0("Spécimen « ", id, " » enregistré (note ", note, "/5 ; ",
                     length(unique(rv$saved$specimen)), " au total, sauvegardé).")
  })
  observeEvent(input$clear_all, { rv$saved <- NULL
    if (file.exists(AUTOSAVE)) try(file.remove(AUTOSAVE), silent = TRUE)
    rv$msg <- "Table vidée." })
  output$saved_info <- renderText({
    if (is.null(rv$saved) || !nrow(rv$saved)) "Aucun spécimen enregistré."
    else paste0(length(unique(rv$saved$specimen)), " spécimen(s) : ",
                paste(unique(rv$saved$specimen), collapse = ", "))
  })
  output$dl_all <- downloadHandler(
    filename = function() paste0("mesures_", Sys.Date(), ".csv"),
    content = function(f) { req(rv$saved); utils::write.csv(rv$saved, f, row.names = FALSE) })

  observeEvent(input$undo, if (length(rv$clicks)) rv$clicks[[length(rv$clicks)]] <- NULL)
  observeEvent(input$restart, { rv$pred <- NULL; rv$clicks <- list()
    rv$msg <- "Cliquez le museau (point 1)." })

  observeEvent(input$predict, {
    if (length(rv$clicks) < 2) { rv$msg <- "Il faut au moins museau + caudale."; return() }
    if (!length(PRED_CHOICES)) { rv$msg <- "Aucun modèle disponible."; return() }
    out <- tempfile(fileext = ".csv")
    xy <- function(i) paste0(rv$clicks[[i]][1], ",", rv$clicks[[i]][2])
    # jeu correspondant au modèle choisi (box identique à l'entraînement) :
    # mlmorph_run_app -> mlmorph_dataset_app, etc.
    ds_dir <- file.path(ML, sub("mlmorph_run", "mlmorph_dataset",
                                basename(dirname(input$pred))))
    if (!dir.exists(ds_dir)) ds_dir <- DATASET
    si <- scale_click_idx(input$pin)          # indices des 2 clics de règle selon le mode
    args <- c(shQuote(WORKER), "--image", shQuote(rv$path),
              "--snout", xy(1), "--caudal", xy(2),
              if (length(rv$clicks) >= 3) c("--dorsal", xy(3)),   # = LM3 si pin
              if (isTRUE(input$pin) && length(rv$clicks) >= 4) c("--lm4",  xy(4)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 5) c("--lm7",  xy(5)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 6) c("--lm10", xy(6)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 7) c("--lm12", xy(7)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 8) c("--lm16", xy(8)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 9) c("--lm18", xy(9)),
              if (isTRUE(input$pin) && length(rv$clicks) >= 10) c("--lm15", xy(10)),
              if (length(rv$clicks) >= si[2]) c("--scale1", xy(si[1]), "--scale2", xy(si[2])),
              if (!isTRUE(input$pin)) "--no-pin-clicks",
              "--scale-mm", input$scale_mm,
              "--dataset-dir", shQuote(ds_dir),
              "--predictor", shQuote(input$pred),
              "--out", shQuote(out))
    rv$msg <- "Prédiction en cours…"
    res <- tryCatch(system2(PY, args, stdout = TRUE, stderr = TRUE),
                    error = function(e) conditionMessage(e))
    if (file.exists(out)) {
      d <- utils::read.csv(out)
      # Toujours 21 lignes : les points d'échelle 20-21 (ou tout point non prédit)
      # restent NA et peuvent être placés à la main dans la phase de correction.
      NTOT <- max(21L, max(d$landmark))
      M <- matrix(NA_real_, NTOT, 2, dimnames = list(seq_len(NTOT), c("X", "Y")))
      M[as.character(d$landmark), ] <- as.matrix(d[, c("X", "Y")])
      # Mode "forcer" : 1,2,3,4,7 sont déjà figés sur les clics par le worker ;
      # on propage les conventions FISHMORPH aux dépendants (8,9,11,5,6,13,14).
      if (isTRUE(input$pin)) M <- apply_fishmorph(M)
      rv$pred <- M
      # démarre la correction au 1er point NON auto (saute 3,4,7 en mode forcer)
      rv$sel <- if (isTRUE(input$pin)) next_manual(2L, nrow(M), AUTO_LM_PIN) else 3L
      rv$msg <- paste0("Prédiction OK. Corrigez si besoin. Points 20-21 (règle) : ",
                       if (any(is.na(M[c("20","21"), ]))) "à placer (sélectionnez 20/21)."
                       else "posés.")
    } else {
      rv$msg <- paste("Échec prédiction :\n", paste(tail(res, 8), collapse = "\n"))
    }
  })

  output$img <- renderPlot({
    if (is.null(rv$img)) { plot.new(); text(.5, .5, "Chargez une photo"); return() }
    par(mar = c(0, 0, 0, 0))
    cx <- if (is.null(rv$cx)) rv$w / 2 else rv$cx
    cy <- if (is.null(rv$cy)) rv$h / 2 else rv$cy
    hw <- (rv$w / 2) / rv$zoom; hh <- (rv$h / 2) / rv$zoom
    cx <- min(max(cx, hw), rv$w - hw); cy <- min(max(cy, hh), rv$h - hh)
    plot(NA, xlim = c(cx - hw, cx + hw), ylim = c(cy + hh, cy - hh), asp = 1,
         xaxs = "i", yaxs = "i", xlab = "", ylab = "", axes = FALSE)
    graphics::rasterImage(rv$img, 0, rv$h, rv$w, 0)
    # guides d'alignement : grille fine sur tous les landmarks + croix sur le sélectionné
    if (isTRUE(input$guides) && !is.null(rv$pred)) {
      ok <- stats::complete.cases(rv$pred)
      abline(v = rv$pred[ok, 1], col = adjustcolor("yellow", 0.25), lty = 3)
      abline(h = rv$pred[ok, 2], col = adjustcolor("yellow", 0.25), lty = 3)
      if (all(is.finite(rv$pred[rv$sel, ]))) {
        abline(v = rv$pred[rv$sel, 1], col = "yellow", lwd = 1.5)
        abline(h = rv$pred[rv$sel, 2], col = "yellow", lwd = 1.5)
      }
    }
    # Guides géométriques FISHMORPH (axe du corps = LM1->LM2). Vert = conforme.
    #  - segments (1,9)(3,4)(10,11) perpendiculaires à l'axe
    #  - groupe (5,13,7,14,6,8) aligné sur une VERTICALE (perpendiculaire à l'axe)
    #  - groupe (9,8,11,4) aligné sur une HORIZONTALE (parallèle à l'axe 1-2)
    if (isTRUE(input$fishguides) && !is.null(rv$pred)) {
      P <- rv$pred; axis <- body_axis(P)
      if (!is.null(axis)) {
        u <- axis$u; vp <- c(-u[2], u[1]); tol <- 0.03 * axis$len; L <- rv$w + rv$h
        for (pr in list(c("1","9"), c("3","4"), c("10","11"))) {
          a <- P[pr[1], ]; b <- P[pr[2], ]
          if (all(is.finite(c(a, b)))) {
            s <- b - a; s <- s / sqrt(sum(s^2))
            dev <- abs(90 - acos(pmin(1, abs(sum(s * u)))) * 180 / pi)
            segments(a[1], a[2], b[1], b[2], col = if (dev < 8) "green" else "orange", lwd = 2)
          }
        }
        # groupe à aligner (parallel=FALSE : verticale ; TRUE : parallèle à l'axe)
        drawgrp <- function(ids, parallel) {
          pts <- P[ids, , drop = FALSE]; pts <- pts[stats::complete.cases(pts), , drop = FALSE]
          if (nrow(pts) < 2) return(invisible())
          c0 <- colMeans(pts)
          coord <- (pts - matrix(c0, nrow(pts), 2, byrow = TRUE)) %*% (if (parallel) vp else u)
          col <- if (diff(range(coord)) < tol) "green" else "orange"
          d <- if (parallel) u else vp
          segments(c0[1] - d[1]*L, c0[2] - d[2]*L, c0[1] + d[1]*L, c0[2] + d[2]*L,
                   col = col, lwd = 1.5, lty = 2)
        }
        drawgrp(c("5","13","7","14","6","8"), parallel = FALSE)  # verticale tête
        drawgrp(c("9","8","11","4"),          parallel = TRUE)   # horizontale ventrale // axe
        # caudale : 16-17 doit être PARALLÈLE à 18-19 (référence propre à la
        # caudale, indépendante de l'axe du corps si le poisson est courbé)
        if (all(is.finite(c(P["16", ], P["17", ], P["18", ], P["19", ])))) {
          s16 <- P["17", ] - P["16", ]; s18 <- P["19", ] - P["18", ]
          ac <- acos(pmin(1, abs(sum((s16 / sqrt(sum(s16^2))) *
                                     (s18 / sqrt(sum(s18^2))))))) * 180 / pi
          colc <- if (ac < 8) "green" else "orange"
          segments(P["16",1], P["16",2], P["17",1], P["17",2], col = colc, lwd = 2)
          segments(P["18",1], P["18",2], P["19",1], P["19",2], col = colc, lwd = 2)
        }
      }
    }
    # clics de calibration
    if (length(rv$clicks)) {
      cl <- do.call(rbind, rv$clicks)
      points(cl, col = "yellow", pch = 3, cex = 2, lwd = 2)
      text(cl[, 1], cl[, 2], seq_len(nrow(cl)), col = "yellow", pos = 3, cex = 1.2)
    }
    # landmarks prédits
    if (!is.null(rv$pred)) {
      outline <- c(1, 5, 3, 16, 18, 19, 17, 4, 6, 1)
      op <- outline[outline <= nrow(rv$pred)]
      lines(rv$pred[op, 1], rv$pred[op, 2], col = "cyan", lwd = 2)
      points(rv$pred[, 1], rv$pred[, 2], col = "red", pch = 19, cex = 1)
      text(rv$pred[, 1], rv$pred[, 2], rownames(rv$pred), col = "white", pos = 3, cex = 0.9)
      points(rv$pred[rv$sel, 1, drop = FALSE], rv$pred[rv$sel, 2, drop = FALSE],
             col = "green", pch = 1, cex = 3, lwd = 3)   # landmark sélectionné
    }
  })

  output$status <- renderText(rv$msg)

  fname <- reactive(if (!is.null(input$photo)) tools::file_path_sans_ext(input$photo$name) else "specimen")
  output$dl_csv <- downloadHandler(
    filename = function() paste0(fname(), "_landmarks.csv"),
    content = function(f) {
      req(rv$pred)
      # On conserve les 21 lignes : un point non mesurable est écrit en NA (le
      # schéma reste complet pour l'imputation en aval).
      df <- data.frame(landmark = rownames(rv$pred), X = rv$pred[, 1], Y = rv$pred[, 2],
                       note = suppressWarnings(as.integer(input$quality)))
      utils::write.csv(df, f, row.names = FALSE) })
  output$dl_tps <- downloadHandler(
    filename = function() paste0(fname(), ".tps"),
    content = function(f) {
      req(rv$pred)
      con <- file(f, "w"); on.exit(close(con))
      keep <- which(stats::complete.cases(rv$pred))         # ignore les points non posés
      writeLines(sprintf("LM=%d", length(keep)), con)
      for (i in keep)                                       # TPS : origine bas-gauche
        writeLines(sprintf("%.3f %.3f", rv$pred[i, 1], rv$h - rv$pred[i, 2]), con)
      writeLines(sprintf("IMAGE=%s", input$photo$name), con)
      writeLines(sprintf("ID=%s", fname()), con) })
}

shinyApp(ui, server)
