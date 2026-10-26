# Changelog

## intraitR 1.47.2

- AIDE : la documentation de
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  (arguments `python` et `mlmorph_dir`, section *Details*) et la
  vignette d’introduction disaient encore qu’il fallait un Python avec
  `dlib` et un dossier ml-morph externe. Les modèles distribués sont au
  format ONNX :
  [`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md)
  et
  [`install_mlmorph_python()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_python.md)
  (`numpy`, `pandas`, `opencv-python-headless`, `pillow`, `onnxruntime`)
  suffisent, une fois par ordinateur ; `dlib` ne sert plus qu’aux
  anciens prédicteurs `.dat`. Ni Python ni les modèles ne sont
  nécessaires pour placer les points à la main.

## intraitR 1.47.1

- CORRECTION de
  [`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md),
  qui s’interrompait au démarrage (« attempt to set an attribute on NULL
  », [`stats::setNames`](https://rdrr.io/r/stats/setNames.html)) lorsque
  les photographies n’avaient aucune espèce – hub lancé sans `species`,
  ou espèces non encore déterminées – ou que le dossier était vide :
  [`names()`](https://rdrr.io/r/base/names.html) d’une table d’effectifs
  vide vaut `NULL`, et les listes de filtres de la page *Results*
  (dossiers, sous-dossiers, espèces, provenances, études) en étaient
  construites. Elles sont désormais simplement vides. Même correction
  pour la liste des espèces de l’application d’analyses.

## intraitR 1.47.0

- CORRECTION de `trait_space(remove_outliers = TRUE)` : une colonne
  devenue constante une fois les individus aberrants retirés faisait
  échouer [`prcomp()`](https://rdrr.io/r/stats/prcomp.html) (« cannot
  rescale a constant/zero column ») ; elle est maintenant écartée avec
  un avertissement. Les exemples n’ordonnent plus que les neuf ratios
  (et non `quality`/`date`), et ceux
  d’[`itv_accumulation()`](https://funtraits.github.io/intraitR/reference/itv_accumulation.md),
  [`fd_accumulation()`](https://funtraits.github.io/intraitR/reference/fd_accumulation.md)
  et
  [`tpd_dissimilarity()`](https://funtraits.github.io/intraitR/reference/tpd_dissimilarity.md)
  utilisent `scale_action = "pixels"` (6 spécimens T-26 sans barre
  d’échelle). `R CMD check` :
  [`fishmorph_db_connect()`](https://funtraits.github.io/intraitR/reference/fishmorph_db_connect.md)
  documentée, `htmltools::` remplacé par `shiny::`.

- CORRECTION de la vignette d’introduction (`intraitR-intro`), qui ne se
  construisait pas (`build_vignettes = TRUE`) : six photographies T-26
  sans barre d’echelle avaient des ratios NA et
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  les refusait. La vignette utilise `scale_action = "pixels"` (ratios
  exacts, mesures en pixels) et l’explique. Et
  [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
  y recevait toute la table : la DATE et la QUALITE de la photographie
  entraient dans l’ordination comme des traits (11 “traits”) ; elle
  recoit maintenant les 9 ratios.

- AIDE : deux vignettes jumelles,
  [`vignette("apps-workflow")`](https://funtraits.github.io/intraitR/articles/apps-workflow.md)
  (anglais) et
  [`vignette("apps-workflow-fr")`](https://funtraits.github.io/intraitR/articles/apps-workflow-fr.md)
  (francais) – presentation du package et marche a suivre a travers les
  applications : page d’accueil, hub (Setup, Select, Digitize, Results
  et ses filtres), digitizer (points, prediction, raccourcis, files new
  / correct / repeat, controles), analyses et export du projet
  reproductible, applications de FishInTrait, equivalents en console,
  depannage. Dans *Articles* du site pkgdown. Menu *? Help* (EN / FR)
  dans le hub, la page d’accueil et l’application d’analyses.

- [`read_digitizer_workbook()`](https://funtraits.github.io/intraitR/reference/read_digitizer_workbook.md)
  (exportee) : lit une feuille du classeur du digitizer avec TOUS ses
  points jusqu’a 25, a leur position (charnieres 22/24/25 comprises, 23
  absent = NA) ; c’est le lecteur des analyses et du tableau des traits
  du hub.

- HUB, PAGE *4. Results* : la selection se fait par MENUS DEROULANTS
  (vide = tout) au lieu des quatre boutons de portee : dossiers (sites),
  sous-dossiers (dates, limites aux dossiers choisis), especes,
  PROVENANCE (campaign, museum, … ; `literature`) et, quand la
  litterature est choisie, ETUDES. Chaque choix affiche ses effectifs ;
  une ligne resume la selection (photographies, mesurees, especes,
  enregistrements de litterature, par provenance). *This sub-folder* et
  *Clear the filters* ; *Only the photographs selected in 2. Select*
  remplace la portee *Selection*.

- Provenance : la table des especes du hub accepte une colonne `source`
  (ou `data_source`, `provenance`) ;
  [`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md)
  la rend (colonne `source`). Nouvel argument
  `launch_measure_hub(literature = )` : des enregistrements de traits
  SANS photographie (jeux publies), offerts sous la provenance
  `literature` ; ils entrent dans le tableau Traits et dans les analyses
  fondees sur les ratios, jamais dans les tableaux de points, la forme
  ou l’erreur de mesure.

- Analyses (`launch_intrait_analyses(literature = )`,
  `write_analysis_project(literature = )`) : les enregistrements de
  litterature rejoignent les ratios (provenance dans le tableau 1,
  filtre *Provenance*, `analysis_params(sources = )`) ; projet sans
  landmarks possible (litterature seule). CHOIX DES RATIOS
  (`analysis_params(ratios = )`, cases a cocher) avec, par provenance et
  par etude, le % d’enregistrements portant chaque ratio : LUIZ2022 n’a
  pas PFv (0 %), donc AUCUN de ses 4 302 enregistrements n’entre avec
  les neuf ratios ; decocher PFv les fait entrer (16 especes sur la
  campagne de test). Le rapport dit quels ratios ont ete ecartes et
  demande de le justifier ; tous les “nine ratios” deviennent le nombre
  de ratios utilises. Citations du rapport corrigees (“with the
  itv_index function \[@…\]” : le prefixe sans reference n’etait pas
  reconnu par pandoc).

- NOUVELLE APPLICATION D’ANALYSES :
  [`launch_intrait_analyses()`](https://funtraits.github.io/intraitR/reference/launch_intrait_analyses.md),
  ouverte depuis l’onglet *4. Results* du hub (bouton *Analyses -\>
  reproducible project (.zip)*) sur les photographies mesurees de la
  portee choisie, ou seule sur un classeur du digitizer. Onglets Donnees
  (echantillon, espece avec au moins n individus, sites, corrections),
  Traits (9 ratios par espece, CV), Espace des traits (+ test de
  dispersion par permutation, Holm), FISHMORPH (projection, part de
  l’espace global), ITV (partition inter/intra, emboitee par site ;
  courbes de rarefaction et n\*), Forme (GPA, espace des formes,
  disparite), Erreur de mesure (feuille `bias`).

- EXPORT EN PROJET REPRODUCTIBLE :
  [`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md)
  (et l’onglet *Export*) ecrit l’analyse avec l’architecture des papiers
  publies –
  `scripts/00_START ... 01_DATA ... 02_ANALYSIS ... 03_FIGURE ... 04_SUPP ... 05_STAT`,
  `utils/` (dont `parameters.R`, seul endroit des parametres),
  `data/raw|processed`, `data/metadata.csv`, `results/figures|tables`,
  `run_all.R`, `README.md`, `.Rproj`, `.gitignore`, `session_info.txt` –
  puis EXECUTE ses propres scripts (processus R separe) : les tableaux,
  les figures et le rapport `manuscript/Methods_Results.docx` (Methodes
  et Resultats seulement, chiffres lus dans `results/tables`, references
  en `.bib`, style Ecology Letters) sont ceux qu’on obtient en relancant
  le projet. Zippe.
  [`analysis_params()`](https://funtraits.github.io/intraitR/reference/analysis_params.md)
  donne les parametres et leurs valeurs par defaut. Verifie de bout en
  bout sur la campagne (554 specimens, 8 especes) : le projet tourne en
  ~20 s et l’echantillon analyse des scripts est identique a celui de
  l’application.

- CORRECTION. Le tableau des traits du hub ne lisait que les points 1 a
  22 : les charnieres 24 et 25 d’un poisson courbe etaient ignorees et
  sa longueur standard (donc BEl et PFs) sous-estimee. Les points sont
  maintenant lus jusqu’a 25, a leur position (le point 23, souvent
  absent du classeur, reste NA).

- Documentation : FISHMORPH est dans *Global Ecology and Biogeography*
  30(12), pas 30(11) ; titre corrige de de Bello et al. (2011)
  ([`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md)).

- `zip` en Suggests.

- CORRECTION (signalee par Aurele). Erreur de mesure : une photographie
  de la feuille `bias` numerisee UNE seule fois faisait echouer
  [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md)
  (“Every individual must have at least 2 digitization replicates”),
  donc l’onglet, et dans le projet exporte le script `04_SUPP` arretait
  toute la chaine `run_all.R`. Ces photographies sont maintenant
  ecartees et nommees (onglet et journal du projet) ; une erreur de
  placement non calculable n’empeche plus le tableau %ME / R ; sans deux
  photographies repetees, l’etape est sautee avec un message.

- Page d’accueil du hub, *Upload photographs into a new folder* : une
  photographie IDENTIQUE (octet pour octet, quel que soit son nom) a une
  photo deja presente sous le dossier parent, ou envoyee deux fois dans
  le meme envoi, n’est plus copiee ; une fenetre liste lesquelles et a
  quoi elles correspondent. Comparaison des tailles d’abord, MD5
  seulement pour les tailles egales : un gros dossier ne coute qu’un
  listage.

## intraitR 1.46.0

- Hub, pre-passe automatique : case *Hinges 22/24* COCHEE par defaut
  (axe brise 1-22-24-2, poissons courbes) ; les charnieres predites
  arrivent en `predicted` dans le digitizer. Un dossier deja pre-passe
  sans charnieres est retraite.
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  garde `hinges = FALSE` par defaut.

- Les MODELES DE PREDICTION se distribuent hors du package (7 reseaux
  ONNX, ~290 Mo : trop lourds pour le package et pour l’historique git)
  :

  - [`pack_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/pack_mlmorph_models.md)
    (mainteneur) : extrait d’un dossier ml_morph ce que la prediction
    utilise – reseaux global, fin, regle, periode de la regle et les
    trois affinages regionaux, leurs parametres, le repere canonique –
    en un zip avec manifeste (md5 de chaque fichier) ; les checkpoints
    d’entrainement (`*.pt`) et les jeux de donnees restent.
    `package_dir =` inscrit la version et la somme de controle dans
    `R/mlmorph_models.R` : une version d’intraitR predit TOUJOURS avec
    la meme version des modeles (reproductibilite).
  - [`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md)
    : telecharge le zip de la release GitHub `models-v<version>` (ou un
    zip local / un miroir), verifie le zip et chaque fichier, installe
    dans le dossier utilisateur d’intraitR. Une fois par machine.
    [`mlmorph_models_dir()`](https://funtraits.github.io/intraitR/reference/mlmorph_models_dir.md),
    [`mlmorph_models_info()`](https://funtraits.github.io/intraitR/reference/mlmorph_models_info.md).
  - [`install_mlmorph_python()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_python.md)
    : environnement Python (numpy, pandas, opencv, pillow, onnxruntime)
    dans le dossier utilisateur d’intraitR.
  - Detection automatique : le dossier ml_morph local reste prioritaire,
    puis les modeles installes ; meme chose pour Python
    (`~/.venv_mlmorph`, puis l’environnement installe). Page de
    demarrage du hub : etat des modeles et de Python, boutons
    d’installation (en arriere-plan).
  - Verifie de bout en bout : les 7 modeles reels empaquetes (zip de 287
    Mo), installes, puis
    [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
    sur deux photos T-26 sans aucun dossier ml_morph (2e etage et regle
    compris, 1,6 s/photo).

- Hub, Results \> Progress : le tableau ne recouvre plus le graphique
  quand il y a des donnees (contenu des onglets hors de la mise en page
  « remplissante », et correction generale dans
  [`Rfishmorph::app_theme()`](https://rdrr.io/pkg/Rfishmorph/man/app_theme.html)).
  Graphique refait : legende au-dessus des barres (dedans, elle les
  cachait), compte « mesurees / total » au bout de chaque barre, hauteur
  proportionnelle au nombre d’especes, italique pour les seuls binomes,
  couleurs du theme.

- [`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md)
  SANS ARGUMENT : une page de demarrage choisit le dossier des photos
  (explorateur de dossiers cote R, avec raccourcis Home, Bureau,
  Documents, OneDrive / iCloud, disques ; nombre de photos affiche en
  naviguant) ou y CHARGE des photos dans un nouveau dossier (copiees,
  les originaux intacts) ; les especes (inconnues, un dossier par
  espece, ou une table CSV / Excel verifiee contre les photos) ; ou sont
  enregistrees les mesures (classeur et journal proposes a cote des
  photos, etat du journal existant) ; operateur, regle, noms des deux
  niveaux de dossiers, dossier ml-morph. Les SESSIONS RECENTES (8, dans
  le dossier utilisateur d’intraitR) se rouvrent en un clic, et l’appel
  equivalent en console est affiche. *Open* lance le hub dans le meme
  onglet (meme port, la page se recharge seule) ; sur l’accueil du hub,
  *Open another folder* y revient. Les arguments donnes en console
  restent verifies avant tout lancement.

- NOUVEAU
  [`accept_batch_landmarks()`](https://funtraits.github.io/intraitR/reference/accept_batch_landmarks.md)
  : enregistre dans le journal les points d’une pre-passe
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  SANS les relire. Photos signalees par la pre-passe exclues (sauf
  `include_flagged = TRUE`), photo deja mesuree jamais ecrasee, planches
  exclues ; conventions du digitizer appliquees (profondeurs, points
  derives, LM23). Rien n’est maquille : chaque point reste
  `"predicted"`, l’entree `reviewed = "no"`, `app_version` dit d’ou elle
  vient. Le classeur est mis a jour en GARDANT ses autres feuilles
  (bias, bias_summary…) et son schema de colonnes ; `dry_run = TRUE`
  pour voir.

- Hub, onglet Digitize : bouton *Accept the pre-pass without review*
  sous *Stop the digitizer*. Une boite d’avertissement dit ce qui sera
  enregistre (photos sans drapeau), ce qui est exclu (photos signalees,
  par drapeau ; deja mesurees ; planches), avec une case pour inclure
  les photos signalees. Refuse tant que le digitizer ou la pre-passe
  tournent. Apres coup : rafraichissement et enregistrement dans la base
  (FishInTrait).

- Hub : page d’ACCUEIL (premier onglet). Ce qu’il reste a mesurer
  (titre, barre d’avancement, nombre de dossiers concernes), ou sont les
  photos, le dernier enregistrement (code, espece, operateur, il y a
  combien de temps) ; bouton *Resume* qui ouvre le dossier du dernier
  enregistrement (ou le premier ou il reste du travail), filtre sur les
  photos a mesurer ; liste des dossiers avec leur avancement (un clic
  ouvre le dossier dans Select) ; derniers enregistrements ; les quatre
  etapes en liens ; les autres applications. Illustration : un profil de
  poisson et ses landmarks, poses un a un a l’ouverture (aucune
  animation si le systeme demande moins de mouvement).

- Digitizer : VRAI Undo / Redo (Ctrl+Z / Cmd+Z, Ctrl+Maj+Z / Cmd+Maj+Z,
  boutons *Undo* / *Redo*). Chaque modification des points (clic,
  prediction, regle qui realigne les voisins, Mark NA, Validate, segment
  nul) est une etape ; Undo remet tout l’etat d’avant – un point predit
  deplace revient a sa place, avec les points que les regles avaient
  bouges. L’ancien *Undo* effacait seulement le dernier point pose.
  Historique par photographie (et par individu d’une planche), jusqu’a
  200 etapes ; un enregistrement n’est pas annule (le journal est en
  ajout seul).

- Theme commun
  [`Rfishmorph::app_theme()`](https://rdrr.io/pkg/Rfishmorph/man/app_theme.html)
  dans le hub et le digitizer (qui garde son accent bleu) ; le digitizer
  a une vraie barre de titre. Les couleurs ecrites en dur dans les
  styles passent par les variables du theme. Requiert Rfishmorph \>=
  0.19.0.

- Site pkgdown : 15 fonctions exportees manquaient a l’index de
  reference (hub, journal, base DuckDB,
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md),
  [`impute_traits()`](https://funtraits.github.io/intraitR/reference/impute_traits.md)…),
  ce qui faisait echouer la construction du site ; nouvelle section
  *Measurement hub and digitization*.

- CORRECTION. `impute_traits(method = "impute_group_mean")` (et
  `.apply_na_action()`) n’imputait RIEN quand les groupes etaient un
  vecteur de caracteres – le cas de
  [`impute_traits()`](https://funtraits.github.io/intraitR/reference/impute_traits.md)
  et de `FishInTrait::fit_build_space()` : la boucle parcourait
  `levels(groups)`, qui vaut `NULL` sur un caractere, et le message
  annoncait “imputed 0”. Les autres methodes (missForest par defaut)
  n’etaient pas touchees.

- CORRECTION. Digitizer FISHMORPH :
  [`openxlsx::read.xlsx()`](https://rdrr.io/pkg/openxlsx/man/read.xlsx.html)
  supprime par defaut les colonnes et lignes entierement vides. Une
  colonne vide (LM12 jamais saisi, colonnes de charniere 24-25 avant la
  premiere sauvegarde) decalait toutes les colonnes suivantes :
  `quality_score`, `reviewed`, `collapse_rules` relus dans la mauvaise
  colonne, points non mesurables perdus au rechargement.
  `skipEmptyCols/skipEmptyRows = FALSE`.

- TESTS. Les 6 tests en echec depuis plusieurs versions sont corriges (5
  par la correction ci-dessus, 1 donnee de test incoherente). Nouveau
  `test-app-digitizer.R` : le digitizer joue sans navigateur
  ([`shiny::testServer()`](https://rdrr.io/pkg/shiny/man/testServer.html))
  – Entree valide + enregistre + photo suivante, bouton Validate sans
  enregistrement, refus d’un enregistrement vide, bouton Save qui ecrit
  le classeur. withr en Suggests.

- CORRECTION IMPORTANTE. `.xlsx_sheet_names()` renvoyait une liste VIDE
  pour les classeurs ecrits par writexl comme par openxlsx
  ([`readLines()`](https://rdrr.io/r/base/readLines.html) sur une
  connexion [`unz()`](https://rdrr.io/r/base/connections.html) perd la
  derniere ligne sans fin de ligne, et `workbook.xml` tient en deux
  lignes). Les deux protections ajoutees apres l’incident du 23/10
  (1.42.1) ne se declenchaient donc jamais :
  [`write_xlsx_atomic()`](https://funtraits.github.io/intraitR/reference/write_xlsx_atomic.md)
  ne refusait pas de detruire des feuilles et
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  ne refusait pas un classeur FISHMORPH. Lecture binaire desormais ;
  trouve par un test.

- CORRECTION. Deux sessions de journal ouvertes dans la meme seconde
  produisaient les memes identifiants d’enregistrement (le nom de
  fichier recevait un suffixe, pas l’identifiant de session) ; la
  consolidation pouvait alors melanger deux enregistrements.

- NOUVEAU
  [`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md)
  : le hub de mesure, sur n’importe quel dossier de photos
  (sous-dossiers sur deux niveaux, ex. site/date ou espece). 1. Setup
  ; 2. Select : galerie avec espece et etat mesure, tableau des especes,
  selection libre ; 3. Digitize : pre-passe
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  optionnelle (regle oui/non) puis
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  sur exactement la selection, dans un processus R d’arriere-plan
  (callr) ;

  4.  Results : avancement, landmarks + statuts (journal), traits
      FISHMORPH (sans regle : ratios valides, segments en pixels), photo
      annotee, bouton *Remeasure* (cette photo seule, mode `correct`).
      Bouton *Finish* : rend la console et renvoie la selection et les
      traits. Especes : nom du dossier (`species = "folder"`) ou table
      photo/species. `traits_fun` permet a une couche de gestion
      (FishInTrait) de brancher son propre calcul de traits.

- Hub : point d’entree d’une session. `launch_measure_hub(apps = )`
  ouvre d’autres applications Shiny, chacune dans son processus R et son
  onglet : boutons de l’onglet Select (`place = "select"`), boutons sur
  une photo (`"photo"` : loupe de la galerie et onglet Annotated
  photograph, code de la photo passe en argument, avertissement
  optionnel si elle est deja mesuree), menu *Apps* (`"menu"`). Par
  defaut l’espace FISHMORPH
  ([`Rfishmorph::launch_fishmorph_space()`](https://rdrr.io/pkg/Rfishmorph/man/launch_fishmorph_space.html)).
  Photos et especes relues quand une de ces applications se ferme ;
  `species` peut etre une fonction. Le bouton Remeasure devient *Correct
  the points in the digitizer*. Images de la galerie rechargees quand le
  fichier change (recadrage).

- NOUVEAU `retract_landmarks(journal_dir, photo, row_key, xlsx_path)` :
  une photo redevient “non mesuree”. Le journal reste en ajout seul : un
  enregistrement de retrait (`mode = "retracted"`) est ajoute pour
  chaque cle vivante de la photo (individus d’une planche, repetitions)
  ;
  [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  laisse ces cles de cote (sauf `history = TRUE`), donc le digitizer ne
  les ressuscite pas en reconstruisant le classeur ; les lignes sont
  aussi retirees du classeur (ecriture atomique). Une nouvelle mesure de
  la cle remplace le retrait.

- Hub : une application connectee peut demander `close_digitizer = TRUE`
  (le digitizer ouvert est ferme d’abord) ; quand l’image d’une photo a
  change pendant qu’une application etait ouverte dessus, ses
  predictions de pre-saisie automatique sont retirees.

- Hub : une application sur photo peut declarer `photo_query` : deja
  ouverte, elle recoit la photo suivante par son URL, dans le meme
  onglet, au lieu d’etre relancee ; le hub surveille les images du
  dossier courant tant qu’elle est ouverte (pre-saisie perimee retiree,
  galerie redessinee).

- VITESSE.
  [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  vectorisee (une matrice remplie par index au lieu d’un petit tableau
  par enregistrement) : resultat identique
  ([`identical()`](https://rdrr.io/r/base/identical.html) sur un journal
  de campagne et un journal de cas limites), 4,0 s -\> 0,5 s pour 1 500
  specimens ;
  [`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md)
  1,6 -\> 0,4 s.
  [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md)
  garde en cache les fichiers deja lus (ils sont en ajout seul : seul
  celui de la session en cours change). Le hub lit le journal une fois
  par changement et en derive file, controle et tableaux ; vignettes de
  galerie generees a la demande et mises en cache
  (`tools::R_user_dir("intraitR", "cache")`) au lieu des images en
  pleine resolution.

- Digitizer : affichage CANEVAS par defaut (`display = "canvas"`, ancien
  affichage `"plot"` conserve). La photo est dessinee dans le navigateur
  : R envoie l’image une fois, puis apres chaque clic seulement les
  formes de la superposition (points, segments, guides, controles),
  quelques Ko au lieu d’un PNG du panneau refait par R. Zoom a la
  molette (au curseur) et deplacement (clic droit glisse) dans le
  navigateur, sans aller-retour. La superposition est le MEME code pour
  les deux affichages (rejoue avec des fonctions d’enregistrement), et
  le clic envoie `input$click` en pixels de l’image comme avant :
  regles, statuts et enregistrement inchanges.

- Ce qui est enregistre, et quand, toujours visible. Digitizer : bouton
  *Write the workbook now* dans la barre principale et pastille “LM…
  recorded at hh:mm:ss – workbook up to date / N save(s) to write” (le
  journal est ecrit a chaque *Save & next* ; le classeur suit). Hub :
  bouton *Save to the database* et etat (nombre mesure, dernier
  landmark, classeur) dans la barre ; `launch_measure_hub(sync_fun = )`
  : l’enregistrement propre a la couche de gestion, lance par le bouton,
  a la fermeture du digitizer et a *Finish*.

- Digitizer : *Validate points* (bleu) a cote de *Save & next* ; touche
  ENTREE = valider les points a l’ecran + Save & next (le controle des
  conventions s’applique toujours et son dialogue arrete la sequence ;
  la touche est sans effet dans un champ de saisie ou quand un dialogue
  est ouvert).

- Digitizer (campagnes) : bouton *Write the flip into the file* (onglet
  Display), comme pour la cible FISHMORPH : la photo est reecrite telle
  qu’affichee, a pleine resolution ; l’original est copie une fois dans
  `_original_photos/` a cote du classeur (hors de l’arborescence des
  photos, que le hub parcourt) ; si la photo etait deja enregistree, un
  avertissement demande de refaire Save & next.
  [`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md)
  ignore les dossiers `_originaux/` et `_original_photos/`.

- Hub : vignettes sans etiquette d’orientation EXIF (le navigateur les
  tournait ; elles montrent maintenant la grille brute, comme le
  digitizer).

- NOUVEAU
  [`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md)
  : la table du hub (photos, espece, etat mesure).

- callr, DT, httpuv en Suggests (hub uniquement).

- Digitizer : bouton *Finish* (a cote du titre) : ecrit le classeur,
  ferme l’app et rend la console R
  ([`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  /
  [`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
  renvoient le chemin du classeur). Lance depuis le hub FishInTrait, il
  termine proprement le processus d’arriere-plan.

## intraitR 1.45.0

- Digitizer : CORRECTION. Deplacer un point de repere du cadre (1, 2, 3
  ou une charniere) apres ‘Auto’ / ‘Predict’ relancait le pre-placement
  sur les proportions medianes FISHMORPH et ecrasait TOUTE la
  prediction. Desormais seuls les points encore a leur position de
  graine suivent ; les points predits ou places restent ou ils sont, et
  seules les regles d’alignement liees au point deplace sont
  reappliquees (partenaire perpendiculaire, points ventraux derives, axe
  de la tete). Les curseurs de graine ne touchent plus non plus a une
  prediction. Le bouton ‘Re-seed’ repart toujours de zero.

- `digitize_landmarks(photo_dir = )` accepte aussi un VECTEUR de
  fichiers image : seules ces photos forment la file (une selection
  faite avant, par ex. une espece d’une date). Noms de fichier distincts
  exiges (le nom est le code specimen) ; le dossier de la premiere tient
  lieu de `photo_dir`.

- `options(intraitR.background = TRUE)` leve le garde
  [`interactive()`](https://rdrr.io/r/base/interactive.html) pour un
  lanceur qui fait tourner l’app dans un processus R d’arriere-plan (le
  hub de mesure de FishInTrait, via callr), avec
  `launch.browser = FALSE` et un `port`.

- `batch_landmarks(ruler = TRUE, ruler_mm = 10)` : on declare si les
  photos portent une regle. `TRUE` (defaut, comportement inchange) : la
  regle (20-21) est detectee par le reseau `mlmorph_run_ruler`
  (`mm_per_px`, `bl_mm`) et une photo sans regle lisible est signalee
  `règle` ; un avertissement previent si ce reseau est absent. `FALSE` :
  aucune detection, aucun drapeau `règle`, mesures en pixels. Le choix
  est trace par photo dans la colonne `ruler` de `summary.csv` ;
  [`read_batch_landmarks()`](https://funtraits.github.io/intraitR/reference/read_batch_landmarks.md)
  met `ruler = TRUE` pour les lots anterieurs. `ruler_mm` (distance
  20-21) n’etait pas transmis jusqu’ici : 10 mm etait impose. La doc,
  qui disait la regle non detectee, est corrigee.

## intraitR 1.44.0

### Fusion des digitizers, etape 4 : la base FISHMORPH rejoint la mesure

- NOUVEAU (deplaces de Rfishmorph, qui ne mesure plus) :
  [`fishmorph_build_db()`](https://funtraits.github.io/intraitR/reference/fishmorph_build_db.md),
  [`fishmorph_validate()`](https://funtraits.github.io/intraitR/reference/fishmorph_validate.md),
  [`fishmorph_db_connect()`](https://funtraits.github.io/intraitR/reference/fishmorph_db_connect.md).
  La base DuckDB est construite depuis le journal COMMUN
  (`consolidate_landmarks(long = TRUE)`), qui relit les journaux de
  l’ancien digitizer comme ceux de
  [`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md).
  Vocabulaire des statuts : celui du journal (“placed” devient “clicked”
  ; la vue `v_specimen_qc` garde `n_placed` comme alias de `n_clicked`,
  les requetes existantes fonctionnent). DBI et duckdb en Suggests.
- NOUVEAU
  [`write_workbook_atomic()`](https://funtraits.github.io/intraitR/reference/write_workbook_atomic.md)
  : ecriture atomique d’un classeur openxlsx edite en place (remplace
  [`Rfishmorph::fm_save_workbook_atomic()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html),
  utilise par FishInTrait).
- `inst/MEMO_requetes_db.md` (requetes SQL sur la base) vient de
  Rfishmorph.
- Les scripts Python ml-morph n’existent plus qu’ici (`inst/mlmorph/`).

## intraitR 1.43.0

### Fusion des digitizers, etape 3b : la cible FISHMORPH est complete

[`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
fait desormais tout ce que faisait
[`Rfishmorph::launch_fishmorph_digitizer()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html).

- Page **New species** (onglet a cote de “Digitize”) : choisir une
  photo, la nommer (pre-rempli depuis le nom de fichier, forme du binome
  verifiee), la CADRER (rotations 90 degres, miroirs, recadrage a la
  souris, “Reset”), puis l’ajouter : copie dans le dossier des nouvelles
  photos sous `Genus_species.jpg` (suffixe 2, 3… si l’espece y est deja
  ; un PNG reste PNG), fichier fourni conserve dans `_originaux/`, file
  “new” reconstruite et specimen ouvert aussitot. Rien n’est ecrit dans
  le classeur avant le premier “Save & next”.
- **Verification FishBase** (via
  [`Rfishmorph::validate_species_names()`](https://rdrr.io/pkg/Rfishmorph/man/validate_species_names.html),
  qui garde la taxonomie) : signale nom accepte / synonyme / non resolu,
  ne bloque jamais ; bouton separe pour adopter le nom accepte.
- **Write the flip into the file** (onglet Display) : ecrit la photo
  telle qu’affichee, en PLEINE RESOLUTION (l’original est relu : l’image
  a l’ecran est reduite), original copie une fois dans `_originaux/`,
  selecteurs remis a None, points inchanges.
- Tests des fonctions d’integration (rotation, miroir, recadrage,
  binome, nommage, ecriture avec sauvegarde unique de l’original).

## intraitR 1.42.1

### Correctif de securite : un classeur n’est plus ecrase par un autre format

- INCIDENT du 23/10/2026 :
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  lance avec le classeur de reference FISHMORPH comme `xlsx_path` l’a
  REECRIT en classeur de campagne (`measurements`, `bias`,
  `bias_summary`), ses trois feuilles disparaissant. Restaure a
  l’identique depuis son `.prev.xlsx` (MD5 verifie) ; les deux versions
  sont conservees dans `_backups/fishmorph_restore_20261023/`.
- [`write_xlsx_atomic()`](https://funtraits.github.io/intraitR/reference/write_xlsx_atomic.md)
  refuse desormais d’ecraser un classeur qui contient des feuilles qu’il
  n’ecrit pas (erreur qui les nomme, fichier intact) ; argument
  `drop_sheets = TRUE` pour le faire volontairement. Protege aussi
  `consolidate_landmarks(xlsx_path =)`.
- [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  refuse de demarrer sur un classeur qui n’est pas un classeur de
  campagne, et oriente vers
  [`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
  quand c’est un classeur FISHMORPH.
- L’app affiche la vraie raison d’un echec d’ecriture du classeur.
- [`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
  : `new_sheet` vaut par defaut `New_specimen` (le nom des classeurs
  FISHMORPH) ; une feuille au nom approchant est reconnue au lieu d’en
  creer une nouvelle ; le dossier photo est trouve avec ou sans accents
  (“Photos utilisees” / “Photos utilisees” accentue) ; un dossier photo
  qui ne correspond a aucune espece est signale.

## intraitR 1.42.0

### Fusion des digitizers, etape 3a : la cible FISHMORPH dans l’app d’intraitR

- NOUVEAU
  [`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md)
  : l’app de
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  ouverte sur le classeur de reference FISHMORPH. Remplace
  [`Rfishmorph::launch_fishmorph_digitizer()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html)
  (memes arguments, memes feuilles, memes files `reconstruct` /
  `correct` / `new`, memes cles de journal : le nom d’espece, ou le nom
  de fichier pour une nouvelle photo – l’historique d’une espece
  continue d’un outil a l’autre).
- File `reconstruct` : une fois l’axe place, les points sont amorces aux
  proportions MESUREES de l’espece (ses segments publies ; Eh2/Mo2/PFi2
  pour les hauteurs) au lieu des medianes. `seed_configuration()` gagne
  l’argument `ratios` (defaut : medianes, rien ne change pour la
  campagne).
- Tout le reste est celui de l’app de campagne : conventions verifiees a
  l’enregistrement, regles de points confondus, prediction ml-morph et
  “Auto”, statuts par point, journal commun, note de qualite commune.
- `R/digitizer_fishmorph.R` : lecture/ecriture du classeur (feuilles
  `Global_segments`, `Global_Landmark`, `new_specimens` de la copie de
  travail, editee en place via openxlsx, ecriture atomique), fonctions
  photo/espece reprises a l’identique de Rfishmorph. `openxlsx` en
  Suggests.
- Le lancement est factorise (`.run_digitizer_app()`) entre les deux
  lanceurs.
- Pas encore portes (etape 3b) : la page “New species”, l’ecriture du
  retournement dans le fichier photo, la verification FishBase.

## intraitR 1.41.0

### Une seule echelle de qualite (CHANGEMENT DE CONVENTION)

Les deux digitizers notaient la saisie a l’envers : intraitR `quality`,
1 = tres bon .. 5 = mauvais (defaut 3) ; Rfishmorph `quality_score`, 1 =
inutilisable .. 5 = excellent, avec “Not scored”. L’echelle commune est
desormais celle de Rfishmorph, sous son nom.

- App : choix “Not scored” (defaut, cellule vide) puis 1..5 ; 5 =
  excellent. La note et la case “Checked” sont remises a zero a chaque
  specimen (elles suivaient l’operateur d’un poisson au suivant) et
  rechargees avec une saisie rouverte.
- Journal et classeur : colonne `quality_score` (meme position que
  l’ancienne `quality` dans l’en-tete du journal). Le NOM de colonne dit
  l’echelle : une ancienne `quality` est convertie a la lecture,
  `quality_score = 6 - quality` (journaux par
  [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md),
  classeur de campagne a sa relecture par l’app et par
  [`import_legacy_landmarks()`](https://funtraits.github.io/intraitR/reference/import_legacy_landmarks.md)).
  Rien n’est reecrit sur disque ; le classeur passe a `quality_score` a
  sa prochaine ecriture.
- [`landmark_journal_append()`](https://funtraits.github.io/intraitR/reference/landmark_journal_append.md)
  : l’argument `quality` devient `quality_score`.
- Jeu de donnees T-26 livre : sa colonne `quality` reste sur l’ancienne
  echelle (documente) ; 491 specimens sur 494 y portent 3, l’ancienne
  valeur par defaut, c’est-a-dire “non note”.

## intraitR 1.40.0

### Fusion des digitizers, etape 2 : un seul journal

- [`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md)
  relit aussi les journaux ecrits par
  [`Rfishmorph::launch_fishmorph_digitizer()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html),
  traduits a la volee (les fichiers ne sont jamais reecrits) :
  `quality_score` -\> `quality`, `collapse` -\> `collapse_rules`,
  `reviewed` TRUE/FALSE -\> “yes”/“no”, statut “placed” -\> “clicked”.
  Colonnes alignees par NOM (les journaux FISHMORPH ont insere des
  colonnes au milieu de leur en-tete au fil des versions). Verifie sur
  les 121 journaux FISHMORPH lisibles : 73 163 points, 3 181
  enregistrements, 2 800 especes, aucune ligne perdue.
- **Correctif** : un fichier de journal illisible (typiquement un
  fichier OneDrive/iCloud non telecharge) etait ignore EN SILENCE, et
  ses specimens disparaissaient de la consolidation. Il est toujours
  ignore, mais un avertissement le nomme. 14 journaux FISHMORPH sont
  dans ce cas sur la machine de reference le 23/10/2026.
- Nouvelle colonne de journal `species` (en fin d’en-tete) et argument
  `species` de
  [`landmark_journal_append()`](https://funtraits.github.io/intraitR/reference/landmark_journal_append.md),
  pour la cible FISHMORPH.
- [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  : nouveaux arguments `long`, `drop_na_points` (defaut `TRUE` ; sans
  effet sur les journaux intraitR, ou un point “na” n’a jamais de
  coordonnees) et `status_columns` ; accepte un journal deja lu ;
  colonne `species` ; `n_validated` aussi dans le resultat vide.
- NOUVEAU (portes de Rfishmorph) :
  [`landmark_journal_status()`](https://funtraits.github.io/intraitR/reference/landmark_journal_status.md),
  [`landmark_journal_history()`](https://funtraits.github.io/intraitR/reference/landmark_journal_history.md),
  [`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md).

## intraitR 1.39.0

### Fusion des digitizers, etape 1 : le noyau commun entre dans le package

Objectif : UNE application de numerisation dans intraitR, avec deux
cibles – la campagne
([`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md))
et le classeur de reference FISHMORPH
([`digitize_fishmorph_reference()`](https://funtraits.github.io/intraitR/reference/digitize_fishmorph_reference.md),
qui remplacera
[`Rfishmorph::launch_fishmorph_digitizer()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html)).

- Le noyau du digitizer (schema des 25 points, ordres de saisie, mise en
  page du classeur de campagne, conventions FISHMORPH verifiees a
  l’enregistrement : axe brise, points extremes 3/4, ordre de l’oeil,
  points confondus ; geometrie d’amorcage ; lecture/retournement des
  images) quitte `inst/shiny/landmarking_app/app.R` pour
  `R/digitizer_core.R`, **a l’identique** (79 definitions, ~1 130
  lignes). L’app les importe sous les memes noms au demarrage : aucun
  changement de comportement.
- Les tests prennent ces fonctions dans le namespace au lieu d’analyser
  le texte de `app.R` ; nouveau test : le noyau est complet et l’app ne
  le redefinit pas.

## intraitR 1.38.0

### Dedoublonnage avec Rfishmorph : la visualisation de l’espace FISHMORPH part dans Rfishmorph

Partage des roles : intraitR MESURE (numerisation, landmarks, segments,
ratios, erreur de mesure) et analyse l’ITV ; Rfishmorph detient la
reference FISHMORPH et VISUALISE son espace. Necessite Rfishmorph \>=
0.17.0.

- [`plotly_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/plotly_fishmorph.html),
  [`plot_fishmorph_density()`](https://rdrr.io/pkg/Rfishmorph/man/plot_fishmorph_density.html),
  [`max_pair_distance()`](https://rdrr.io/pkg/Rfishmorph/man/max_pair_distance.html),
  [`group_colors()`](https://rdrr.io/pkg/Rfishmorph/man/group_colors.html)
  et
  [`reset_group_colors()`](https://rdrr.io/pkg/Rfishmorph/man/reset_group_colors.html)
  sont desormais implementes dans Rfishmorph et **reexportes** ici : les
  appels [`intraitR::...`](https://rdrr.io/r/base/dots.html) (scripts,
  FishInTrait) restent valides sans modification.
- [`project_fishmorph()`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md)
  appelle
  [`Rfishmorph::project_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/project_fishmorph.html)
  (projection unique) puis ajoute
  [`itv_proportion()`](https://funtraits.github.io/intraitR/reference/itv_proportion.md).
  Le resultat est de classe
  `c("intrait_fishmorph_projection", "fishmorph_projection")` ; memes
  champs qu’avant. Le trace passe par
  [`Rfishmorph::plot.fishmorph_projection()`](https://rdrr.io/pkg/Rfishmorph/man/plot.fishmorph_projection.html)
  (memes arguments ; la methode `plot.intrait_fishmorph_projection()`
  est supprimee) ; [`print()`](https://rdrr.io/r/base/print.html)
  affiche le resume Rfishmorph puis le bloc ITV.
- Moteur de trace des ordinations (`trait_space`, `shape_space`,
  `itv_accumulation`, `species_sensitivity`,
  `bootstrap_functional_space`) : delegue a Rfishmorph
  (`fm_plot_ordination()`, `fm_group_palette()`,
  `fm_abbreviate_species()`). Il n’existe plus qu’un cache de couleurs
  par session : une espece a la meme couleur dans les figures intraitR
  et Rfishmorph (il y en avait deux, donc parfois deux couleurs).
- Bilan : ~2 300 lignes de code R (net) et ~375 lignes de tests en moins
  dans intraitR ; le code et ses tests vivent dans Rfishmorph.

## intraitR 1.37.0

### Landmarking tout automatique (sans clic)

- Bouton **« Auto (no clicks) »** dans
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  : un reseau GLOBAL (`ml_morph/train_global.py`,
  `mlmorph_run_global/model.onnx`) localise le museau (LM1), la base de
  la caudale (LM2) et le cote dorsal sur la photo entiere (puis sur un
  recadrage zoome du poisson) ; le modele choisi place ensuite les
  autres points dans le repere canonique. Un point deja clique garde la
  priorite ; LM1/LM2 detectes restent “predicted” (non verifies) tant
  qu’ils ne sont pas recliques. Worker : `--auto`.
- NOUVEAU
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  /
  [`read_batch_landmarks()`](https://funtraits.github.io/intraitR/reference/read_batch_landmarks.md)
  : meme chaine sur tout un dossier de photos, sans les ouvrir
  (`ml_morph/batch_auto.py`, ~0,3 s/photo sur CPU). Sorties :
  `landmarks_long.csv`, `landmarks_wide.csv`, `summary.csv` (drapeaux
  `instable`, `dorsal`, `petit`, `bord`, `confiance` et score de risque)
  et planche de controle `qc/index.html` triee par risque. Rien n’est
  ecrit dans le journal ; la regle (20-21) n’est pas detectee
  (coordonnees en pixels). Une seule espece/poisson par photo pour
  l’instant.
- Localisation verifiee (plusieurs candidats museau/caudale, chaque
  couple verifie par le modele fin ; planches : detection puis
  masquage). Reseau global final (20 epoques). Bloc test, points 4-19,
  mediane % de Bl : campagne 1,14 (= chaine cliquee 1,14), FISHMORPH
  1,66 (cliquee 1,58). `batch_landmarks(max_fish = )` pour les planches
  ; drapeau `plusieurs`. Details : `ml_morph/README.md`.
- Charnieres 22 et 24 placees par le modele fin (`cnn` a 21 sorties,
  `train_cnn.py --hinges`) : l’axe brise 1-22-24-2 suit les poissons
  courbes et les conventions s’appliquent segment par segment ; statut
  “predicted”, une charniere cliquee est conservee. Points 3-19 :
  campagne 0,99 % de Bl, FISHMORPH 1,56. Redressement des poissons
  courbes : option experimentale `--straighten` du worker, desactivee
  par defaut.
- 2e etage a haute resolution (`ml_morph/train_refine.py`) : tete,
  pectorale et caudale reaffinees automatiquement apres le modele fin.
  Erreur sur les traits (variance, % de l’ITV, chaine automatique) : BEl
  26 -\> 14, CPt 76 -\> 34, PFs 104 -\> 65, RMl 208 -\> 101, OGp 76 -\>
  53 ; aucun trait degrade.
- Nouveau statut de point **“validated”** et bouton **« Validate points
  »** : les points encore “predicted” ou “seeded” que l’operateur a
  regardes et acceptes sans les deplacer passent a “validated” (journal
  ; un point reclique redevient “clicked”, un point reecrit par le
  modele redevient “predicted”). A l’entrainement
  (`build_combined_dataset.py`), ils servent d’etiquettes avec un poids
  de 0,5 et ne sont jamais utilises pour evaluer un modele (effaces des
  blocs val/test). `landmark_journal` : vocabulaire et compteur
  `n_validated`.
- Echelle automatique : quand la regle (20-21) n’est pas cliquee, «
  Predict » et « Auto » la placent sur la regle (reseaux `ruler` et
  `ruler_period` + analyse spectrale des graduations,
  `ml_morph/ruler_scale.py`), statut “predicted”. Bloc test : ecart
  median 1,0 % a l’echelle cliquee (repetabilite humaine 1,4 %) ; photos
  sans regle rejetees.
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  : colonnes `mm_per_px`, `scale_quality`, `bl_mm`, drapeaux `regle` /
  `echelle`.
- Case **« Hinges 22/24 (curved fish) »** (decochee par defaut) :
  demande au modele de placer aussi les charnieres 22/24 (statut
  “predicted”), a utiliser au cas par cas sur les poissons courbes ;
  `batch_landmarks(hinges = TRUE)`.
- `digitize_landmarks(batch = <dossier de batch_landmarks()>)` : dans la
  file “new”, une photo traitee par lot arrive DEJA POINTEE (19 points,
  tous au statut “predicted”, LM1 et LM2 compris, avec les conventions
  FISHMORPH appliquees) ; le point actif est LM20 (regle).
  `batch_order = "risk"` (defaut) place en tete les photos signalees,
  par risque decroissant ; une notification rappelle les drapeaux de la
  photo. Ne s’applique pas aux planches (`individuals_per_photo > 1`).
- Correctif : apres le bouton « Auto », LM1/LM2 detectes sont
  journalises “predicted” (et non “clicked”) tant qu’ils ne sont pas
  recliques.

## intraitR 1.36.0

### Prediction : un modele entraine sur la campagne

- NOUVEAU MODELE PAR DEFAUT `cnn` : reseau de neurones a cartes de
  chaleur (ResNet-18 pre-entraine ImageNet + decodeur pyramidal,
  soft-argmax ; `ml_morph/train_cnn.py`), exporte en ONNX
  (`mlmorph_run_cnn/model.onnx`). Meme repere canonique et meme worker
  que les modeles dlib : le worker reconnait un fichier `.onnx` et
  l’execute avec onnxruntime (a installer une fois :
  `~/.venv_mlmorph/bin/pip install onnxruntime`) ; chaque point recoit
  une confiance (colonne `conf`). Bloc test (points 3-19, % de Bl) :
  campagne 1,03 (dlib `combined` 1,40), FISHMORPH 1,61 (dlib 2,48) ;
  meilleur sur 71 % et 78 % des specimens (Wilcoxon apparie p \< 1e-15).
  Les modeles dlib restent proposes dans la liste.

- Modele dlib `combined` : un seul modele ml-morph entraine sur la
  campagne INTRAIT ET sur FISHMORPH (5 730 especes). Bloc test, points
  3-19 : campagne mediane 1,40 % de Bl, FISHMORPH 2,48 % ; sans perte
  face au modele `campaign` sur les specimens jamais vus par les deux
  (1,44 vs 1,49 %, p = 0,59). Details : `ml_morph/README.md`. Repere
  canonique plus compact (Bl = 500 px), lu par le worker dans
  `canon_params.txt`.

- CORRECTIF. Placer la regle (LM20, LM21) deplacait des points
  anatomiques : le clic propageait les conventions (8/9/11 re-derives,
  paires de hauteur re-equerrees) sans re-imposer la verticale de
  l’oeil, si bien qu’apres une prediction LM8 bougeait et LM6 restait
  hors de la verticale 5-13-7-14-6. Les points d’echelle ne propagent
  plus rien, et, avec « Auto constraints » coche, les conventions sont
  appliquees en entier une fois juste apres « Predict » (elles ne
  l’etaient qu’en mode pin) : ce qui est affiche apres la prediction est
  ce qui sera enregistre.

- Le worker lit la box dlib dans `canon_params.txt` quand le jeu la
  declare (`box_w`, `box_h`) au lieu de la recalculer sur les TPS : la
  boucle d’apprentissage (`ml_morph/update_combined.py`) fige la box, et
  la recalculer sur un jeu modifie decalait le cadre de prediction de
  celui de l’entrainement. Sans ces cles, comportement inchange.

- CORRECTIF (worker). `predict_new_image.py` lit l’image SANS appliquer
  l’orientation EXIF (`cv2.IMREAD_IGNORE_ORIENTATION`), comme
  [`jpeg::readJPEG()`](https://rdrr.io/pkg/jpeg/man/readJPEG.html) dans
  l’app : 33 photographies preparees de la campagne portent une rotation
  EXIF (valeur 8), sur lesquelles la prediction tombait dans un autre
  repere. Meme worker que Rfishmorph 0.15.0.

- Apres « Predict », la selection passe directement au premier point de
  la regle encore manquant (LM20, puis LM21), en vue entiere pour que la
  regle soit a l’ecran ; si la regle est deja placee, la revue commence
  comme avant au premier point anatomique.

- [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  propose un troisieme modele, `campaign`
  (`ml_morph/mlmorph_run_campaign/predictor.dat`, 19 landmarks
  anatomiques), entraine sur le classeur de la campagne INTRAIT (5
  sites, 80 especes ; 1 570 specimens lisibles : 1 102 train / 230 val /
  238 test, partition par photographie, stratifiee par espece). Il est
  liste en premier dans « Predictor model » et detecte par
  `.resolve_mlmorph_dir()`.

- Le worker `inst/mlmorph/predict_new_image.py` lit desormais
  `<dataset>/canon_params.txt` (ecrit par
  `ml_morph/build_campaign_dataset.py`) : `target_len`, facteurs de
  recadrage, et `refine`. Le modele `campaign` est entraine dans une
  fenetre centree sur le MILIEU de LM1-LM2 – les deux points cliques –
  et declare `refine=0` : la passe de recentrage sur le barycentre
  predit, qui ne peut pas corriger une translation de la box (point
  fixe), decalait toute la configuration de ~70 px (erreur mediane 9,7 %
  de Bl au lieu de 1,1 % sur le bloc test). Sans `canon_params.txt`
  (modeles `app` et `aligned`), le comportement historique est inchange.

- Validation sur le bloc test (jamais vu), via le worker de l’app, clics
  LM1-LM2-LM3 : voir
  `ml_morph/mlmorph_run_campaign/validation_summary.csv`.

## intraitR 1.35.0

### Un seul corpus T-26 : celui de l’application

- RUPTURE. Les quatre tables ImageJ de juillet (`operators`,
  `repeatability`, `identifications`, `qc_log` ; codes `T-26-0001`,
  operateurs `Operator_N`) ne sont plus livrees.
  [`load_t26_saudrune()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune.md)
  ne connait plus que `"landmarks"` (defaut), `"specimens"`,
  `"repeatability"` et `"qc_log"`, et
  [`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)
  que `"landmarks"` et `"repeatability"`. Les anciennes valeurs
  (`"campaign"`, `"operators"`, `"identifications"`,
  `"campaign_identifications"`, `"campaign_renames"`,
  `"campaign_qc_log"`) sont des erreurs de
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html).
- POURQUOI. Deux corpus du meme ruisseau cohabitaient sous deux schemas
  de points (21 et 25), deux conventions de codes et deux nomenclatures
  ; les exemples et la demo melaient les deux. Le package illustre le
  protocole qu’il implemente –
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  – et rien d’autre.
- CE QUI CHANGE DANS LES TABLES. Les tables `campaign*` de 1.34.0 ne se
  joignaient plus entre elles (landmarks en `uid`, identifications en
  anciens codes a espece : zero code commun). Elles sont regenerees en
  une seule passe par `data-raw/t26_campaign_prepare.R`, qui lit
  `measurements/landmarks.xlsx` (plus `landmarks_rehashed.xlsx`), prend
  l’identite dans `export/specimens.csv`, la determination courante dans
  `export/determinations.csv` et les codes d’espece injectifs dans
  `export/taxa.csv`. 494 specimens (396 photographies a un poisson + 98
  individus de plaques `_iK`, deux dates de peche), 7 especes, 25 points
  par specimen (le point 25, reserve, est NA partout) ; 7
  enregistrements `_iK` doublant le code nu de leur photographie (meme
  poisson numerise deux fois) sont exclus et journalises dans
  `"qc_log"`. `"specimens"` remplace `"campaign_identifications"` et
  porte `uid`, `individual`, `n_landmarks`, `reviewed`, `confidence`,
  `determined_by`, `digitized`.
- NOUVEAU. `"repeatability"` est desormais la feuille `bias` du
  digitizer : l’essai de re-numerisation en aveugle (mode `repeat`),
  identifiants `<code>_<operateur>_rep<N>` ; 17 individus x 3 passes a
  ce jour, un operateur.
  [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md)
  et
  [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
  y trouvent leur exemple reel ;
  [`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md)
  attend un second operateur (son exemple est conditionne au nombre
  d’operateurs).
- `species = TRUE` joint `species` et `species_code` (plus `id_status`,
  qui n’existait que dans le pilote ImageJ). La nomenclature est celle
  de la campagne (*Gobio gobio*, *Leuciscus burdigalensis*).
- Exemples
  ([`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md),
  [`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
  [`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md),
  [`exclude_specimens()`](https://funtraits.github.io/intraitR/reference/exclude_specimens.md),
  [`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md),
  [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md)),
  `demo(pipeline_T26_saudrune)`, README, vignette, tests et
  `_pkgdown.yml` reecrits sur ce seul corpus ; plus aucun identifiant de
  specimen code en dur dans la documentation.
- Taille : `inst/extdata/T26_Saudrune` passe de 3,4 Mo a 0,28 Mo.

### Corrections

- [`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)
  : une ligne numerisee avant l’existence des colonnes `img_w`/`img_h`
  n’a rien qui contredise le cadre ; la verification du cadre ne
  s’applique que lorsque la ligne a enregistre ses dimensions. Jusqu’ici
  une telle ligne finissait en `frame_changed` et n’etait jamais
  re-clee, ce qui annulait le cas retroactif que la provenance sert.
- Tests remis au niveau du code (ils n’avaient pas ete relances depuis
  1.31) :
  [`phylo_pcoa()`](https://rdrr.io/pkg/Rfishmorph/man/phylo_pcoa.html)
  renvoie `fishmorph_phylopcoa` (reexport de Rfishmorph) ; le schema de
  la feuille `measurements` compte 23 colonnes de metadonnees
  (`reviewed`, `reviewed_by`, `review_date`, `collapse_rules`,
  `photo_hash`) ; `apply_collapse()` depend de `project_mid()` ; les
  info-bulles de
  [`plotly_fishmorph()`](https://rdrr.io/pkg/Rfishmorph/man/plotly_fishmorph.html)
  portent deux lignes de distances par defaut
  (`hover_distances = TRUE`).

## intraitR 1.34.0

### Le journal ne se deverse plus dans le classeur d’un autre dossier

- Le journal est en ajout seul et couvre tout le projet : il garde
  chaque enregistrement sous le code sous lequel il a ete sauve, pour
  tous les dossiers. Les reinjecter tous dans le classeur d’UN dossier
  formait une boucle. Un enregistrement dont la photographie n’est pas
  la ne peut etre ni revu, ni re-mesure, ni reconcilie : son ancien nom
  ne correspond a aucun fichier, aucune empreinte, aucune provenance. Il
  revenait en `frame_changed` ou `ambiguous` a CHAQUE lancement, etait
  vide ou re-cle, ecrit – et le journal, qui n’oublie rien, le remettait
  au lancement suivant. Sur T-26 : 49 enregistrements regenerant 37 + 12
  avertissements, execution apres execution, avec des compteurs qui
  decroissaient sans jamais atteindre zero.
- La reinjection est desormais conditionnee a la photographie :
  `photo_file` doit designer un fichier du dossier ouvert. Le filet de
  securite reste ou il sert – une ecriture du classeur qui a echoue pour
  les specimens en cours – et le reste de l’histoire du projet demeure
  au journal, pour la session qui ouvrira SON dossier. Aucun
  enregistrement n’est supprime ; il n’est simplement pas recopie dans
  un classeur qui n’en a pas l’usage.
- Une note discrete indique combien d’enregistrements ont ete retenus,
  et pourquoi rien n’est attendu de l’operateur a leur sujet.

### Tout doute renvoie le specimen en file d’attente

- Trois constats de la reconciliation veulent dire la meme chose pour
  l’operateur – *ces coordonnees ne valent plus contre cette image* – et
  ils etaient traites de trois facons. Le recadrage (`image_changed`)
  vidait les coordonnees et remettait le poisson dans la file « new ».
  Le changement de cadre (`frame_changed`) et l’ambiguite (`ambiguous`)
  se contentaient d’un avertissement, et laissaient la ligne dans la
  file « correct ».
- Un avertissement se lit une fois puis disparait ; la file d’attente
  est ce qui reste a l’ecran le lendemain. Sur la campagne T-26, cela
  signifiait une file annoncant « plus rien a faire » avec 42 + 12
  specimens a reprendre.
- Les trois cas vident desormais les coordonnees et renvoient le
  specimen dans la file. Quelques poissons de plus a mesurer coutent un
  apres-midi ; une file qui ment coute la campagne.
- Pour une ambiguite, les DEUX entrees repartent, pas seulement la ligne
  examinee : le constat est « cette image existe sous plusieurs noms
  avec des coordonnees differentes », et n’en requeuer qu’une laisserait
  l’autre paraitre terminee.
- Rien n’est perdu. La ligne est conservee, seules les coordonnees sont
  mises a NA, et le journal en ajout seul garde chaque configuration :
  [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  et « Rebuild from the journal » la restituent.
- Le compteur `pending` compte enfin les lignes touchees et non « 1 »
  par categorie.

### Une ligne au cadre change est re-clee avant d’etre remise en file

- [`reconcile_photo_names()`](https://funtraits.github.io/intraitR/reference/reconcile_photo_names.md)
  SIGNALE un changement de cadre, il ne renomme pas : la ligne garde le
  code et le nom de fichier sous lesquels elle a ete numerisee. Depuis
  la migration UID ceux-ci ne designent plus rien sur le disque
  (`GOBOCC_010_AT.jpeg` est devenu `..._0016.jpeg`).
- Vider ses coordonnees la sortait donc de la file « correct » sans
  jamais la faire entrer dans la file « new » – celle-ci etant
  construite a partir des PHOTOGRAPHIES du dossier, aucune ne repond a
  l’ancien nom. Sur T-26 la file annoncait 34 la ou il en restait 45 :
  11 specimens etaient invisibles, les autres lignes orphelines pointant
  sur des poissons deja re-mesures sous leur nouveau nom.
- La ligne est desormais re-clee sur `photo_file_new`, le fichier
  effectivement apparie, en conservant le suffixe `_iK` / `_repN` – il
  nomme un poisson dans une photographie, pas la photographie.
- La moitie eteinte d’une ambiguite est desormais SUPPRIMEE au moment ou
  l’ambiguite est constatee – et seulement si sa contrepartie vivante
  est presente. Sans coordonnees et sans photographie a son nom, elle ne
  pouvait plus etre atteinte ; et elle ne pouvait pas non plus etre
  nettoyee plus tard, puisque effacer son hash est precisement ce qui
  empeche l’execution suivante de la reconnaitre comme ambigue. C’est le
  seul instant ou la preuve existe.
