# intraitR 1.45.0

* Digitizer : CORRECTION. Deplacer un point de repere du cadre (1, 2, 3 ou une
  charniere) apres 'Auto' / 'Predict' relancait le pre-placement sur les
  proportions medianes FISHMORPH et ecrasait TOUTE la prediction. Desormais
  seuls les points encore a leur position de graine suivent ; les points
  predits ou places restent ou ils sont, et seules les regles d'alignement
  liees au point deplace sont reappliquees (partenaire perpendiculaire, points
  ventraux derives, axe de la tete). Les curseurs de graine ne touchent plus
  non plus a une prediction. Le bouton 'Re-seed' repart toujours de zero.

* `digitize_landmarks(photo_dir = )` accepte aussi un VECTEUR de fichiers
  image : seules ces photos forment la file (une selection faite avant, par
  ex. une espece d'une date). Noms de fichier distincts exiges (le nom est le
  code specimen) ; le dossier de la premiere tient lieu de `photo_dir`.
* `options(intraitR.background = TRUE)` leve le garde `interactive()` pour un
  lanceur qui fait tourner l'app dans un processus R d'arriere-plan (le hub de
  mesure de FishInTrait, via callr), avec `launch.browser = FALSE` et un `port`.

* `batch_landmarks(ruler = TRUE, ruler_mm = 10)` : on declare si les photos
  portent une regle. `TRUE` (defaut, comportement inchange) : la regle (20-21)
  est detectee par le reseau `mlmorph_run_ruler` (`mm_per_px`, `bl_mm`) et une
  photo sans regle lisible est signalee `règle` ; un avertissement previent si
  ce reseau est absent. `FALSE` : aucune detection, aucun drapeau `règle`,
  mesures en pixels. Le choix est trace par photo dans la colonne `ruler` de
  `summary.csv` ; `read_batch_landmarks()` met `ruler = TRUE` pour les lots
  anterieurs. `ruler_mm` (distance 20-21) n'etait pas transmis jusqu'ici :
  10 mm etait impose. La doc, qui disait la regle non detectee, est corrigee.

# intraitR 1.44.0

## Fusion des digitizers, etape 4 : la base FISHMORPH rejoint la mesure

* NOUVEAU (deplaces de Rfishmorph, qui ne mesure plus) : `fishmorph_build_db()`,
  `fishmorph_validate()`, `fishmorph_db_connect()`. La base DuckDB est
  construite depuis le journal COMMUN (`consolidate_landmarks(long = TRUE)`),
  qui relit les journaux de l'ancien digitizer comme ceux de
  `digitize_fishmorph_reference()`. Vocabulaire des statuts : celui du journal
  ("placed" devient "clicked" ; la vue `v_specimen_qc` garde `n_placed` comme
  alias de `n_clicked`, les requetes existantes fonctionnent). DBI et duckdb en
  Suggests.
* NOUVEAU `write_workbook_atomic()` : ecriture atomique d'un classeur openxlsx
  edite en place (remplace `Rfishmorph::fm_save_workbook_atomic()`, utilise par
  FishInTrait).
* `inst/MEMO_requetes_db.md` (requetes SQL sur la base) vient de Rfishmorph.
* Les scripts Python ml-morph n'existent plus qu'ici (`inst/mlmorph/`).

# intraitR 1.43.0

## Fusion des digitizers, etape 3b : la cible FISHMORPH est complete

`digitize_fishmorph_reference()` fait desormais tout ce que faisait
`Rfishmorph::launch_fishmorph_digitizer()`.

* Page **New species** (onglet a cote de "Digitize") : choisir une photo, la
  nommer (pre-rempli depuis le nom de fichier, forme du binome verifiee), la
  CADRER (rotations 90 degres, miroirs, recadrage a la souris, "Reset"), puis
  l'ajouter : copie dans le dossier des nouvelles photos sous
  `Genus_species.jpg` (suffixe 2, 3... si l'espece y est deja ; un PNG reste
  PNG), fichier fourni conserve dans `_originaux/`, file "new" reconstruite et
  specimen ouvert aussitot. Rien n'est ecrit dans le classeur avant le premier
  "Save & next".
* **Verification FishBase** (via `Rfishmorph::validate_species_names()`, qui
  garde la taxonomie) : signale nom accepte / synonyme / non resolu, ne bloque
  jamais ; bouton separe pour adopter le nom accepte.
* **Write the flip into the file** (onglet Display) : ecrit la photo telle
  qu'affichee, en PLEINE RESOLUTION (l'original est relu : l'image a l'ecran
  est reduite), original copie une fois dans `_originaux/`, selecteurs remis a
  None, points inchanges.
* Tests des fonctions d'integration (rotation, miroir, recadrage, binome,
  nommage, ecriture avec sauvegarde unique de l'original).

# intraitR 1.42.1

## Correctif de securite : un classeur n'est plus ecrase par un autre format

* INCIDENT du 23/10/2026 : `digitize_landmarks()` lance avec le classeur de
  reference FISHMORPH comme `xlsx_path` l'a REECRIT en classeur de campagne
  (`measurements`, `bias`, `bias_summary`), ses trois feuilles disparaissant.
  Restaure a l'identique depuis son `.prev.xlsx` (MD5 verifie) ; les deux
  versions sont conservees dans `_backups/fishmorph_restore_20261023/`.
* `write_xlsx_atomic()` refuse desormais d'ecraser un classeur qui contient des
  feuilles qu'il n'ecrit pas (erreur qui les nomme, fichier intact) ; argument
  `drop_sheets = TRUE` pour le faire volontairement. Protege aussi
  `consolidate_landmarks(xlsx_path =)`.
* `digitize_landmarks()` refuse de demarrer sur un classeur qui n'est pas un
  classeur de campagne, et oriente vers `digitize_fishmorph_reference()` quand
  c'est un classeur FISHMORPH.
* L'app affiche la vraie raison d'un echec d'ecriture du classeur.
* `digitize_fishmorph_reference()` : `new_sheet` vaut par defaut `New_specimen`
  (le nom des classeurs FISHMORPH) ; une feuille au nom approchant est
  reconnue au lieu d'en creer une nouvelle ; le dossier photo est trouve avec
  ou sans accents ("Photos utilisees" / "Photos utilisees" accentue) ; un
  dossier photo qui ne correspond a aucune espece est signale.

# intraitR 1.42.0

## Fusion des digitizers, etape 3a : la cible FISHMORPH dans l'app d'intraitR

* NOUVEAU `digitize_fishmorph_reference()` : l'app de `digitize_landmarks()`
  ouverte sur le classeur de reference FISHMORPH. Remplace
  `Rfishmorph::launch_fishmorph_digitizer()` (memes arguments, memes feuilles,
  memes files `reconstruct` / `correct` / `new`, memes cles de journal : le
  nom d'espece, ou le nom de fichier pour une nouvelle photo -- l'historique
  d'une espece continue d'un outil a l'autre).
* File `reconstruct` : une fois l'axe place, les points sont amorces aux
  proportions MESUREES de l'espece (ses segments publies ; Eh2/Mo2/PFi2 pour
  les hauteurs) au lieu des medianes. `seed_configuration()` gagne l'argument
  `ratios` (defaut : medianes, rien ne change pour la campagne).
* Tout le reste est celui de l'app de campagne : conventions verifiees a
  l'enregistrement, regles de points confondus, prediction ml-morph et
  "Auto", statuts par point, journal commun, note de qualite commune.
* `R/digitizer_fishmorph.R` : lecture/ecriture du classeur (feuilles
  `Global_segments`, `Global_Landmark`, `new_specimens` de la copie de
  travail, editee en place via openxlsx, ecriture atomique), fonctions
  photo/espece reprises a l'identique de Rfishmorph. `openxlsx` en Suggests.
* Le lancement est factorise (`.run_digitizer_app()`) entre les deux lanceurs.
* Pas encore portes (etape 3b) : la page "New species", l'ecriture du
  retournement dans le fichier photo, la verification FishBase.

# intraitR 1.41.0

## Une seule echelle de qualite (CHANGEMENT DE CONVENTION)

Les deux digitizers notaient la saisie a l'envers : intraitR `quality`,
1 = tres bon .. 5 = mauvais (defaut 3) ; Rfishmorph `quality_score`,
1 = inutilisable .. 5 = excellent, avec "Not scored". L'echelle commune est
desormais celle de Rfishmorph, sous son nom.

* App : choix "Not scored" (defaut, cellule vide) puis 1..5 ; 5 = excellent.
  La note et la case "Checked" sont remises a zero a chaque specimen (elles
  suivaient l'operateur d'un poisson au suivant) et rechargees avec une saisie
  rouverte.
* Journal et classeur : colonne `quality_score` (meme position que l'ancienne
  `quality` dans l'en-tete du journal). Le NOM de colonne dit l'echelle : une
  ancienne `quality` est convertie a la lecture, `quality_score = 6 - quality`
  (journaux par `landmark_journal_read()`, classeur de campagne a sa relecture
  par l'app et par `import_legacy_landmarks()`). Rien n'est reecrit sur disque ;
  le classeur passe a `quality_score` a sa prochaine ecriture.
* `landmark_journal_append()` : l'argument `quality` devient `quality_score`.
* Jeu de donnees T-26 livre : sa colonne `quality` reste sur l'ancienne echelle
  (documente) ; 491 specimens sur 494 y portent 3, l'ancienne valeur par defaut,
  c'est-a-dire "non note".

# intraitR 1.40.0

## Fusion des digitizers, etape 2 : un seul journal

* `landmark_journal_read()` relit aussi les journaux ecrits par
  `Rfishmorph::launch_fishmorph_digitizer()`, traduits a la volee (les
  fichiers ne sont jamais reecrits) : `quality_score` -> `quality`,
  `collapse` -> `collapse_rules`, `reviewed` TRUE/FALSE -> "yes"/"no", statut
  "placed" -> "clicked". Colonnes alignees par NOM (les journaux FISHMORPH ont
  insere des colonnes au milieu de leur en-tete au fil des versions). Verifie
  sur les 121 journaux FISHMORPH lisibles : 73 163 points, 3 181
  enregistrements, 2 800 especes, aucune ligne perdue.
* **Correctif** : un fichier de journal illisible (typiquement un fichier
  OneDrive/iCloud non telecharge) etait ignore EN SILENCE, et ses specimens
  disparaissaient de la consolidation. Il est toujours ignore, mais un
  avertissement le nomme. 14 journaux FISHMORPH sont dans ce cas sur la
  machine de reference le 23/10/2026.
* Nouvelle colonne de journal `species` (en fin d'en-tete) et argument
  `species` de `landmark_journal_append()`, pour la cible FISHMORPH.
* `consolidate_landmarks()` : nouveaux arguments `long`, `drop_na_points`
  (defaut `TRUE` ; sans effet sur les journaux intraitR, ou un point "na" n'a
  jamais de coordonnees) et `status_columns` ; accepte un journal deja lu ;
  colonne `species` ; `n_validated` aussi dans le resultat vide.
* NOUVEAU (portes de Rfishmorph) : `landmark_journal_status()`,
  `landmark_journal_history()`, `landmark_journal_qc()`.

# intraitR 1.39.0

## Fusion des digitizers, etape 1 : le noyau commun entre dans le package

Objectif : UNE application de numerisation dans intraitR, avec deux cibles --
la campagne (`digitize_landmarks()`) et le classeur de reference FISHMORPH
(`digitize_fishmorph_reference()`, qui remplacera
`Rfishmorph::launch_fishmorph_digitizer()`).

* Le noyau du digitizer (schema des 25 points, ordres de saisie, mise en page
  du classeur de campagne, conventions FISHMORPH verifiees a l'enregistrement :
  axe brise, points extremes 3/4, ordre de l'oeil, points confondus ; geometrie
  d'amorcage ; lecture/retournement des images) quitte
  `inst/shiny/landmarking_app/app.R` pour `R/digitizer_core.R`, **a
  l'identique** (79 definitions, ~1 130 lignes). L'app les importe sous les
  memes noms au demarrage : aucun changement de comportement.
* Les tests prennent ces fonctions dans le namespace au lieu d'analyser le
  texte de `app.R` ; nouveau test : le noyau est complet et l'app ne le
  redefinit pas.

# intraitR 1.38.0

## Dedoublonnage avec Rfishmorph : la visualisation de l'espace FISHMORPH part dans Rfishmorph

Partage des roles : intraitR MESURE (numerisation, landmarks, segments,
ratios, erreur de mesure) et analyse l'ITV ; Rfishmorph detient la reference
FISHMORPH et VISUALISE son espace. Necessite Rfishmorph >= 0.17.0.

* `plotly_fishmorph()`, `plot_fishmorph_density()`, `max_pair_distance()`,
  `group_colors()` et `reset_group_colors()` sont desormais implementes dans
  Rfishmorph et **reexportes** ici : les appels `intraitR::...` (scripts,
  FishInTrait) restent valides sans modification.
* `project_fishmorph()` appelle `Rfishmorph::project_fishmorph()` (projection
  unique) puis ajoute `itv_proportion()`. Le resultat est de classe
  `c("intrait_fishmorph_projection", "fishmorph_projection")` ; memes champs
  qu'avant. Le trace passe par `Rfishmorph::plot.fishmorph_projection()`
  (memes arguments ; la methode `plot.intrait_fishmorph_projection()` est
  supprimee) ; `print()` affiche le resume Rfishmorph puis le bloc ITV.
* Moteur de trace des ordinations (`trait_space`, `shape_space`,
  `itv_accumulation`, `species_sensitivity`, `bootstrap_functional_space`) :
  delegue a Rfishmorph (`fm_plot_ordination()`, `fm_group_palette()`,
  `fm_abbreviate_species()`). Il n'existe plus qu'un cache de couleurs par
  session : une espece a la meme couleur dans les figures intraitR et
  Rfishmorph (il y en avait deux, donc parfois deux couleurs).
* Bilan : ~2 300 lignes de code R (net) et ~375 lignes de tests en moins dans
  intraitR ; le code et ses tests vivent dans Rfishmorph.

# intraitR 1.37.0

## Landmarking tout automatique (sans clic)

* Bouton **« Auto (no clicks) »** dans `digitize_landmarks()` : un reseau
  GLOBAL (`ml_morph/train_global.py`, `mlmorph_run_global/model.onnx`)
  localise le museau (LM1), la base de la caudale (LM2) et le cote dorsal sur
  la photo entiere (puis sur un recadrage zoome du poisson) ; le modele choisi
  place ensuite les autres points dans le repere canonique. Un point deja
  clique garde la priorite ; LM1/LM2 detectes restent "predicted" (non
  verifies) tant qu'ils ne sont pas recliques. Worker : `--auto`.
* NOUVEAU `batch_landmarks()` / `read_batch_landmarks()` : meme chaine sur
  tout un dossier de photos, sans les ouvrir (`ml_morph/batch_auto.py`,
  ~0,3 s/photo sur CPU). Sorties : `landmarks_long.csv`, `landmarks_wide.csv`,
  `summary.csv` (drapeaux `instable`, `dorsal`, `petit`, `bord`, `confiance`
  et score de risque) et planche de controle `qc/index.html` triee par risque.
  Rien n'est ecrit dans le journal ; la regle (20-21) n'est pas detectee
  (coordonnees en pixels). Une seule espece/poisson par photo pour l'instant.
* Localisation verifiee (plusieurs candidats museau/caudale, chaque couple
  verifie par le modele fin ; planches : detection puis masquage). Reseau
  global final (20 epoques). Bloc test, points 4-19, mediane % de Bl :
  campagne 1,14 (= chaine cliquee 1,14), FISHMORPH 1,66 (cliquee 1,58).
  `batch_landmarks(max_fish = )` pour les planches ; drapeau `plusieurs`.
  Details : `ml_morph/README.md`.
* Charnieres 22 et 24 placees par le modele fin (`cnn` a 21 sorties,
  `train_cnn.py --hinges`) : l'axe brise 1-22-24-2 suit les poissons courbes
  et les conventions s'appliquent segment par segment ; statut "predicted",
  une charniere cliquee est conservee. Points 3-19 : campagne 0,99 % de Bl,
  FISHMORPH 1,56. Redressement des poissons courbes : option experimentale
  `--straighten` du worker, desactivee par defaut.
* 2e etage a haute resolution (`ml_morph/train_refine.py`) : tete, pectorale et
  caudale reaffinees automatiquement apres le modele fin. Erreur sur les traits
  (variance, % de l'ITV, chaine automatique) : BEl 26 -> 14, CPt 76 -> 34,
  PFs 104 -> 65, RMl 208 -> 101, OGp 76 -> 53 ; aucun trait degrade.
* Nouveau statut de point **"validated"** et bouton **« Validate points »** :
  les points encore "predicted" ou "seeded" que l'operateur a regardes et
  acceptes sans les deplacer passent a "validated" (journal ; un point reclique
  redevient "clicked", un point reecrit par le modele redevient "predicted").
  A l'entrainement (`build_combined_dataset.py`), ils servent d'etiquettes avec
  un poids de 0,5 et ne sont jamais utilises pour evaluer un modele (effaces des
  blocs val/test). `landmark_journal` : vocabulaire et compteur `n_validated`.
* Echelle automatique : quand la regle (20-21) n'est pas cliquee, « Predict » et
  « Auto » la placent sur la regle (reseaux `ruler` et `ruler_period` + analyse
  spectrale des graduations, `ml_morph/ruler_scale.py`), statut "predicted".
  Bloc test : ecart median 1,0 % a l'echelle cliquee (repetabilite humaine 1,4 %) ;
  photos sans regle rejetees. `batch_landmarks()` : colonnes `mm_per_px`,
  `scale_quality`, `bl_mm`, drapeaux `regle` / `echelle`.
* Case **« Hinges 22/24 (curved fish) »** (decochee par defaut) : demande au
  modele de placer aussi les charnieres 22/24 (statut "predicted"), a utiliser
  au cas par cas sur les poissons courbes ; `batch_landmarks(hinges = TRUE)`.
* `digitize_landmarks(batch = <dossier de batch_landmarks()>)` : dans la file
  "new", une photo traitee par lot arrive DEJA POINTEE (19 points, tous au
  statut "predicted", LM1 et LM2 compris, avec les conventions FISHMORPH
  appliquees) ; le point actif est LM20 (regle). `batch_order = "risk"`
  (defaut) place en tete les photos signalees, par risque decroissant ; une
  notification rappelle les drapeaux de la photo. Ne s'applique pas aux
  planches (`individuals_per_photo > 1`).
* Correctif : apres le bouton « Auto », LM1/LM2 detectes sont journalises
  "predicted" (et non "clicked") tant qu'ils ne sont pas recliques.

# intraitR 1.36.0

## Prediction : un modele entraine sur la campagne

* NOUVEAU MODELE PAR DEFAUT `cnn` : reseau de neurones a cartes de chaleur
  (ResNet-18 pre-entraine ImageNet + decodeur pyramidal, soft-argmax ;
  `ml_morph/train_cnn.py`), exporte en ONNX (`mlmorph_run_cnn/model.onnx`).
  Meme repere canonique et meme worker que les modeles dlib : le worker
  reconnait un fichier `.onnx` et l'execute avec onnxruntime (a installer une
  fois : `~/.venv_mlmorph/bin/pip install onnxruntime`) ; chaque point recoit
  une confiance (colonne `conf`). Bloc test (points 3-19, % de Bl) : campagne
  1,03 (dlib `combined` 1,40), FISHMORPH 1,61 (dlib 2,48) ; meilleur sur 71 %
  et 78 % des specimens (Wilcoxon apparie p < 1e-15). Les modeles dlib restent
  proposes dans la liste.
* Modele dlib `combined` : un seul
  modele ml-morph entraine sur la campagne INTRAIT ET sur FISHMORPH
  (5 730 especes). Bloc test, points 3-19 : campagne mediane 1,40 % de Bl,
  FISHMORPH 2,48 % ; sans perte face au modele `campaign` sur les specimens
  jamais vus par les deux (1,44 vs 1,49 %, p = 0,59). Details :
  `ml_morph/README.md`. Repere canonique plus compact (Bl = 500 px), lu par le
  worker dans `canon_params.txt`.

* CORRECTIF. Placer la regle (LM20, LM21) deplacait des points anatomiques :
  le clic propageait les conventions (8/9/11 re-derives, paires de hauteur
  re-equerrees) sans re-imposer la verticale de l'oeil, si bien qu'apres une
  prediction LM8 bougeait et LM6 restait hors de la verticale 5-13-7-14-6.
  Les points d'echelle ne propagent plus rien, et, avec « Auto constraints »
  coche, les conventions sont appliquees en entier une fois juste apres
  « Predict » (elles ne l'etaient qu'en mode pin) : ce qui est affiche apres
  la prediction est ce qui sera enregistre.
* Le worker lit la box dlib dans `canon_params.txt` quand le jeu la declare
  (`box_w`, `box_h`) au lieu de la recalculer sur les TPS : la boucle
  d'apprentissage (`ml_morph/update_combined.py`) fige la box, et la recalculer
  sur un jeu modifie decalait le cadre de prediction de celui de
  l'entrainement. Sans ces cles, comportement inchange.
* CORRECTIF (worker). `predict_new_image.py` lit l'image SANS appliquer
  l'orientation EXIF (`cv2.IMREAD_IGNORE_ORIENTATION`), comme `jpeg::readJPEG()`
  dans l'app : 33 photographies preparees de la campagne portent une rotation
  EXIF (valeur 8), sur lesquelles la prediction tombait dans un autre repere.
  Meme worker que Rfishmorph 0.15.0.
* Apres « Predict », la selection passe directement au premier point de la
  regle encore manquant (LM20, puis LM21), en vue entiere pour que la regle
  soit a l'ecran ; si la regle est deja placee, la revue commence comme avant
  au premier point anatomique.

* `digitize_landmarks()` propose un troisieme modele, `campaign`
  (`ml_morph/mlmorph_run_campaign/predictor.dat`, 19 landmarks anatomiques),
  entraine sur le classeur de la campagne INTRAIT (5 sites, 80 especes ;
  1 570 specimens lisibles : 1 102 train / 230 val / 238 test, partition par
  photographie, stratifiee par espece). Il est liste en premier dans
  « Predictor model » et detecte par `.resolve_mlmorph_dir()`.
* Le worker `inst/mlmorph/predict_new_image.py` lit desormais
  `<dataset>/canon_params.txt` (ecrit par `ml_morph/build_campaign_dataset.py`) :
  `target_len`, facteurs de recadrage, et `refine`. Le modele `campaign` est
  entraine dans une fenetre centree sur le MILIEU de LM1-LM2 -- les deux points
  cliques -- et declare `refine=0` : la passe de recentrage sur le barycentre
  predit, qui ne peut pas corriger une translation de la box (point fixe),
  decalait toute la configuration de ~70 px (erreur mediane 9,7 % de Bl au
  lieu de 1,1 % sur le bloc test). Sans `canon_params.txt` (modeles `app` et
  `aligned`), le comportement historique est inchange.
* Validation sur le bloc test (jamais vu), via le worker de l'app, clics
  LM1-LM2-LM3 : voir `ml_morph/mlmorph_run_campaign/validation_summary.csv`.

# intraitR 1.35.0

## Un seul corpus T-26 : celui de l'application

* RUPTURE. Les quatre tables ImageJ de juillet (`operators`, `repeatability`,
  `identifications`, `qc_log` ; codes `T-26-0001`, operateurs `Operator_N`)
  ne sont plus livrees. `load_t26_saudrune()` ne connait plus que
  `"landmarks"` (defaut), `"specimens"`, `"repeatability"` et `"qc_log"`, et
  `load_t26_saudrune_landmarks()` que `"landmarks"` et `"repeatability"`.
  Les anciennes valeurs (`"campaign"`, `"operators"`, `"identifications"`,
  `"campaign_identifications"`, `"campaign_renames"`, `"campaign_qc_log"`)
  sont des erreurs de `match.arg()`.
* POURQUOI. Deux corpus du meme ruisseau cohabitaient sous deux schemas de
  points (21 et 25), deux conventions de codes et deux nomenclatures ; les
  exemples et la demo melaient les deux. Le package illustre le protocole
  qu'il implemente -- `digitize_landmarks()` -- et rien d'autre.
* CE QUI CHANGE DANS LES TABLES. Les tables `campaign*` de 1.34.0 ne se
  joignaient plus entre elles (landmarks en `uid`, identifications en
  anciens codes a espece : zero code commun). Elles sont regenerees en une
  seule passe par `data-raw/t26_campaign_prepare.R`, qui lit
  `measurements/landmarks.xlsx` (plus `landmarks_rehashed.xlsx`), prend
  l'identite dans `export/specimens.csv`, la determination courante dans
  `export/determinations.csv` et les codes d'espece injectifs dans
  `export/taxa.csv`. 494 specimens (396 photographies a un poisson + 98
  individus de plaques `_iK`, deux dates de peche), 7 especes, 25 points par
  specimen (le point 25, reserve, est NA partout) ; 7 enregistrements `_iK`
  doublant le code nu de leur photographie (meme poisson numerise deux fois)
  sont exclus et journalises dans `"qc_log"`. `"specimens"` remplace
  `"campaign_identifications"` et porte `uid`, `individual`, `n_landmarks`,
  `reviewed`, `confidence`, `determined_by`, `digitized`.
* NOUVEAU. `"repeatability"` est desormais la feuille `bias` du digitizer :
  l'essai de re-numerisation en aveugle (mode `repeat`), identifiants
  `<code>_<operateur>_rep<N>` ; 17 individus x 3 passes a ce jour, un
  operateur. `digitization_error()` et `measurement_error()` y trouvent leur
  exemple reel ; `operator_disagreement()` attend un second operateur (son
  exemple est conditionne au nombre d'operateurs).
* `species = TRUE` joint `species` et `species_code` (plus `id_status`, qui
  n'existait que dans le pilote ImageJ). La nomenclature est celle de la
  campagne (*Gobio gobio*, *Leuciscus burdigalensis*).
* Exemples (`correct_landmarks()`, `plot_fishmorph_points()`,
  `correct_geometry()`, `exclude_specimens()`, `operator_disagreement()`,
  `digitization_error()`), `demo(pipeline_T26_saudrune)`, README, vignette,
  tests et `_pkgdown.yml` reecrits sur ce seul corpus ; plus aucun
  identifiant de specimen code en dur dans la documentation.
* Taille : `inst/extdata/T26_Saudrune` passe de 3,4 Mo a 0,28 Mo.

## Corrections

* `reconcile_photo_names()` : une ligne numerisee avant l'existence des
  colonnes `img_w`/`img_h` n'a rien qui contredise le cadre ; la verification
  du cadre ne s'applique que lorsque la ligne a enregistre ses dimensions.
  Jusqu'ici une telle ligne finissait en `frame_changed` et n'etait jamais
  re-clee, ce qui annulait le cas retroactif que la provenance sert.
* Tests remis au niveau du code (ils n'avaient pas ete relances depuis
  1.31) : `phylo_pcoa()` renvoie `fishmorph_phylopcoa` (reexport de
  Rfishmorph) ; le schema de la feuille `measurements` compte 23 colonnes de
  metadonnees (`reviewed`, `reviewed_by`, `review_date`, `collapse_rules`,
  `photo_hash`) ; `apply_collapse()` depend de `project_mid()` ; les
  info-bulles de `plotly_fishmorph()` portent deux lignes de distances par
  defaut (`hover_distances = TRUE`).

# intraitR 1.34.0

## Le journal ne se deverse plus dans le classeur d'un autre dossier

* Le journal est en ajout seul et couvre tout le projet : il garde chaque
  enregistrement sous le code sous lequel il a ete sauve, pour tous les
  dossiers. Les reinjecter tous dans le classeur d'UN dossier formait une
  boucle. Un enregistrement dont la photographie n'est pas la ne peut etre ni
  revu, ni re-mesure, ni reconcilie : son ancien nom ne correspond a aucun
  fichier, aucune empreinte, aucune provenance. Il revenait en
  `frame_changed` ou `ambiguous` a CHAQUE lancement, etait vide ou re-cle,
  ecrit -- et le journal, qui n'oublie rien, le remettait au lancement suivant.
  Sur T-26 : 49 enregistrements regenerant 37 + 12 avertissements, execution
  apres execution, avec des compteurs qui decroissaient sans jamais atteindre
  zero.
* La reinjection est desormais conditionnee a la photographie : `photo_file`
  doit designer un fichier du dossier ouvert. Le filet de securite reste ou il
  sert -- une ecriture du classeur qui a echoue pour les specimens en cours --
  et le reste de l'histoire du projet demeure au journal, pour la session qui
  ouvrira SON dossier. Aucun enregistrement n'est supprime ; il n'est
  simplement pas recopie dans un classeur qui n'en a pas l'usage.
* Une note discrete indique combien d'enregistrements ont ete retenus, et
  pourquoi rien n'est attendu de l'operateur a leur sujet.

## Tout doute renvoie le specimen en file d'attente

* Trois constats de la reconciliation veulent dire la meme chose pour
  l'operateur -- *ces coordonnees ne valent plus contre cette image* -- et ils
  etaient traites de trois facons. Le recadrage (`image_changed`) vidait les
  coordonnees et remettait le poisson dans la file « new ». Le changement de
  cadre (`frame_changed`) et l'ambiguite (`ambiguous`) se contentaient d'un
  avertissement, et laissaient la ligne dans la file « correct ».
* Un avertissement se lit une fois puis disparait ; la file d'attente est ce
  qui reste a l'ecran le lendemain. Sur la campagne T-26, cela signifiait une
  file annoncant « plus rien a faire » avec 42 + 12 specimens a reprendre.
* Les trois cas vident desormais les coordonnees et renvoient le specimen dans
  la file. Quelques poissons de plus a mesurer coutent un apres-midi ; une file
  qui ment coute la campagne.
* Pour une ambiguite, les DEUX entrees repartent, pas seulement la ligne
  examinee : le constat est « cette image existe sous plusieurs noms avec des
  coordonnees differentes », et n'en requeuer qu'une laisserait l'autre
  paraitre terminee.
* Rien n'est perdu. La ligne est conservee, seules les coordonnees sont mises a
  NA, et le journal en ajout seul garde chaque configuration :
  `consolidate_landmarks()` et « Rebuild from the journal » la restituent.
* Le compteur `pending` compte enfin les lignes touchees et non « 1 » par
  categorie.

## Une ligne au cadre change est re-clee avant d'etre remise en file

* `reconcile_photo_names()` SIGNALE un changement de cadre, il ne renomme pas :
  la ligne garde le code et le nom de fichier sous lesquels elle a ete
  numerisee. Depuis la migration UID ceux-ci ne designent plus rien sur le
  disque (`GOBOCC_010_AT.jpeg` est devenu `..._0016.jpeg`).
* Vider ses coordonnees la sortait donc de la file « correct » sans jamais la
  faire entrer dans la file « new » -- celle-ci etant construite a partir des
  PHOTOGRAPHIES du dossier, aucune ne repond a l'ancien nom. Sur T-26 la file
  annoncait 34 la ou il en restait 45 : 11 specimens etaient invisibles, les
  autres lignes orphelines pointant sur des poissons deja re-mesures sous leur
  nouveau nom.
* La ligne est desormais re-clee sur `photo_file_new`, le fichier effectivement
  apparie, en conservant le suffixe `_iK` / `_repN` -- il nomme un poisson dans
  une photographie, pas la photographie.
* La moitie eteinte d'une ambiguite est desormais SUPPRIMEE au moment ou
  l'ambiguite est constatee -- et seulement si sa contrepartie vivante est
  presente. Sans coordonnees et sans photographie a son nom, elle ne pouvait
  plus etre atteinte ; et elle ne pouvait pas non plus etre nettoyee plus tard,
  puisque effacer son hash est precisement ce qui empeche l'execution suivante
  de la reconnaitre comme ambigue. C'est le seul instant ou la preuve existe.

