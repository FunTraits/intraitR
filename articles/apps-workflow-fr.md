# Des photographies à l'article : les applications d'intraitR, pas à pas

*English version:
[`vignette("apps-workflow", package = "intraitR")`](https://funtraits.github.io/intraitR/articles/apps-workflow.md).*

## À quoi sert intraitR

**intraitR** mesure la morphologie des poissons sur photographies et
l’analyse, du premier clic jusqu’à un projet reproductible prêt pour un
article. Il suit le protocole FISHMORPH (Brosse et al. 2021) : des
points repères placés sur une photographie latérale donnent onze mesures
linéaires et les neuf rapports sans unité qui décrivent la locomotion et
l’acquisition de la nourriture (Villéger et al. 2010). Chaque spécimen
étant mesuré individuellement, intraitR est conçu pour la **variabilité
intraspécifique des traits** (ITV) : de combien les individus d’une
espèce diffèrent, comparé à ce qui sépare les espèces.

Tout peut se faire depuis R, mais le chemin habituel passe par quatre
applications qui s’ouvrent dans le navigateur, l’une après l’autre :

| Étape | Application | Ouverte par | Ce qu’on y fait |
|----|----|----|----|
| 1 | **Page d’accueil** | [`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md) sans argument | choisir (ou téléverser) les photographies, les espèces, l’emplacement des résultats |
| 2 | **Hub de mesure** | la page d’accueil, ou `launch_measure_hub(photo_dir, ...)` | sélectionner les photographies, lancer la pré-passe automatique, suivre l’avancement, vérifier les résultats |
| 3 | **Digitizer** | le hub (*3. Digitize*) | placer, prédire et corriger les points, photographie par photographie |
| 4 | **Analyses** | le hub (*4. Results*), ou [`launch_intrait_analyses()`](https://funtraits.github.io/intraitR/reference/launch_intrait_analyses.md) | traits, espace des traits, FISHMORPH, ITV, forme, erreur de mesure ; export d’un projet reproductible |

Deux packages compagnons se branchent sur le même hub : **Rfishmorph**
(la base de référence FISHMORPH et son espace fonctionnel) et, pour une
base de campagne, **FishInTrait** (voir la dernière section).

## Avant la première session

``` r

install.packages("remotes")
remotes::install_github("FunTraits/Rfishmorph")
remotes::install_github("FunTraits/intraitR")

# Une fois par ordinateur, facultatif : les modèles qui prédisent les points
# (~290 Mo, téléchargés depuis la release GitHub d'intraitR) et leur
# environnement Python. Sans eux, chaque point est placé à la main.
intraitR::install_mlmorph_models()
intraitR::install_mlmorph_python()
```

La page d’accueil indique si les modèles sont installés et propose ces
deux installations par un bouton.

**Photographies.** Un poisson (ou plusieurs, voir *plaques*) par
photographie, en vue latérale, tête à gauche si possible, avec une
**barre d’échelle** de longueur connue dans le plan du poisson. Le nom
du fichier sans extension devient le code du spécimen. Organisez le
dossier sur deux niveaux si vous le pouvez — par exemple
`site/date/photo.jpg` — le hub s’en sert comme *dossier* et
*sous-dossier*.

## Étape 1 — la page d’accueil

``` r

library(intraitR)
res <- launch_measure_hub()
```

1.  **Photographies.** *Browse* jusqu’au dossier (le nombre de
    photographies de chaque sous-dossier est affiché), ou téléversez des
    photographies dans un nouveau dossier. Un téléversement ne copie
    jamais une photographie déjà présente sous un autre nom, ni deux
    fois le même fichier : une fenêtre les liste.
2.  **Espèces.** *Pas encore connues* ; *un dossier par espèce* (les
    noms de dossiers sont les espèces) ; ou *depuis une table* (CSV ou
    Excel : une ligne par photographie, une colonne qui la nomme et une
    colonne `species`, éventuellement `source` pour la provenance —
    campagne, musée…).
3.  **Où enregistrer.** Le classeur (`.xlsx`) et le dossier du journal.
    Par défaut, à côté des photographies. **Le journal est la source de
    vérité** : chaque spécimen enregistré y est ajouté aussitôt et n’est
    jamais réécrit ; le classeur est un export que l’on peut toujours
    reconstruire à partir du journal
    ([`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)).
4.  **Session.** Opérateur (tracé dans chaque enregistrement), longueur
    de la barre d’échelle.
5.  *Open the photographs*. Le bas de la page montre l’appel équivalent
    en console, pour relancer la même session depuis un script ; les
    dernières sessions sont listées et se rouvrent en un clic.

## Étape 2 — le hub de mesure

Le hub reste ouvert pendant toute la session ; les autres applications
s’ouvrent dans leurs propres onglets du navigateur et le hub suit ce
qu’elles écrivent.

**Home.** L’avancement du dossier (mesurées / à mesurer, par dossier),
les derniers enregistrements, *Resume* pour reprendre là où l’on s’était
arrêté, et les autres applications.

**1. Setup.** Opérateur, longueur de la barre d’échelle, emplacement du
prédicteur ; les applications ouvertes (et *Close them all*).

**2. Select.** Choisissez un dossier, puis un sous-dossier : la galerie
montre chaque photographie avec son espèce et son état (mesurée ou non).
Un clic la sélectionne ; *Select shown not measured* prend tout ce qui
reste à faire. La loupe ouvre une photographie en grand. *Next: digitize
the selection →*.

**3. Digitize.**

- *Automatic pre-pass (optional)* :
  [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
  prédit en arrière-plan les points de toute la sélection, charnières
  22/24 comprises (utile pour les poissons courbés). Les prédictions
  arrivent dans le digitizer comme points **predicted**, à vérifier.
- *Open the digitizer* sur exactement la sélection (étape 3 ci-dessous).
- *Accept the pre-pass without review* enregistre les prédictions telles
  quelles, après un avertissement : réservez-le aux photographies que
  vous ne vérifierez pas, en sachant qu’elles restent marquées
  `predicted` / non revues dans le journal.

**4. Results.** Les menus du haut choisissent sur quoi les tableaux, les
traits et les analyses sont calculés — vide signifie tout :

| Menu | Sélectionne |
|----|----|
| Folder, Sub-folder | des photographies (par ex. sites, dates) |
| Species | des photographies et des enregistrements de littérature |
| Provenance | campagne, musée… et **littérature** (enregistrements de traits sans photographie, quand le hub en dispose) |
| Studies | les jeux de données publiés, quand *literature* est choisie |

Une ligne résume la sélection (photographies, mesurées, espèces,
enregistrements de littérature). Onglets :

- *Progress* : mesurées / à mesurer par dossier, sous-dossier et espèce.
- *Landmarks & statuses* : pour chaque spécimen, comment ses points ont
  été obtenus — `clicked`/`validated` (vérifiés par l’opérateur),
  `adjusted` (déplacés par une convention du protocole), `predicted`
  (modèle, non revus), `seeded` (jamais déplacés : non mesurés),
  `derived`, `na` — et le nombre de points attendus qui manquent.
- *Traits* : *Compute the FISHMORPH traits* — les onze mesures (en cm,
  ou en pixels pour une photographie sans barre d’échelle : ses rapports
  restent exacts) et les neuf rapports, plus les enregistrements de
  littérature choisis.
- *Annotated photograph* : les points dessinés sur la photographie ;
  *Correct the points in the digitizer* rouvre cette seule photographie,
  en mode correction.

*💾 Save to the database* relit tout et enregistre les mesures (avec
FishInTrait : dans le manifeste du projet). *Finish* ferme le digitizer
et le hub et rend la main à R.

## Étape 3 — le digitizer

Une photographie à la fois. Les boutons de points à droite indiquent
quel point le prochain clic place ; la numérotation suit FISHMORPH :
**1** museau, **2** base de la nageoire caudale, **3 à 19** les points
anatomiques, **20–21** les deux extrémités de la barre d’échelle, **22,
24, 25** des charnières le long de l’axe du corps d’un poisson courbé
(la longueur standard suit alors la ligne brisée), 23 la base de la tête
(dérivée).

| Action | Comment |
|----|----|
| Placer un point | cliquer sur la photographie |
| Prédire les 19 points anatomiques | cliquer 1 (museau) et 2 (base de la caudale), puis *Predict 19 landmarks* ; la barre d’échelle est prédite aussi si elle n’est pas placée (statut `predicted` tant qu’on ne la clique pas) |
| Prédire sans cliquer | *Auto (no clicks)* (nécessite le modèle global) |
| Annuler / rétablir | **Ctrl+Z** / **Ctrl+Maj+Z** (Cmd sur Mac), ou les boutons |
| Valider les points | *Validate points* |
| Enregistrer et passer à la photographie suivante | **Entrée**, ou *Save & next* |
| Un point invisible | *Mark NA* |
| Zoomer, se déplacer | *Zoom + / −*, *Whole view*, les flèches |
| Écrire le classeur maintenant | *💾 Write the workbook now* (il est aussi écrit régulièrement) |

Trois files, depuis la barre d’actions : **new** (photographies pas
encore mesurées), **correct** (spécimens mesurés, points rechargés, pour
déplacer ceux qui sont faux) et **repeat** (la même photographie mesurée
plusieurs fois, à l’aveugle par défaut : ces passes vont dans la feuille
`bias` et donnent l’erreur de mesure). Plusieurs poissons sur une
photographie : *+ individual* (les codes deviennent `<photo>_i1`, `_i2`…
et partagent la barre d’échelle).

Avant l’enregistrement, des contrôles du protocole s’exécutent :
verticale de l’œil, points extrêmes 3/4, règles de coïncidence de
FISHMORPH. Un spécimen suspect est présenté avec *Measure again*,
*Auto-correct and save* ou *Save without correcting*.

*Finish* écrit le classeur et ferme le digitizer ; le hub s’en aperçoit
et se met à jour.

## Étape 4 — les analyses, et un projet prêt pour un article

Dans *4. Results*, réglez les menus, puis **📊 Analyses → reproducible
project (.zip)**. L’application d’analyses s’ouvre sur les photographies
mesurées (et les enregistrements de littérature) de la sélection. Elle
fonctionne aussi seule :

``` r

launch_intrait_analyses(xlsx_path = "landmarks.xlsx")
```

| Onglet | Contenu | Fonctions |
|----|----|----|
| 1\. Data | échantillon par espèce (tableau 1) ; nombre minimal d’individus par espèce, espèces, sites, provenance ; **rapports utilisés** (avec la part des enregistrements qui ont chaque rapport, par provenance et par étude) ; corrections des points | [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md), [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md) |
| 2\. Traits | les rapports par espèce, coefficients de variation | [`summary_traits()`](https://funtraits.github.io/intraitR/reference/summary_traits.md), [`intraspecific_variability()`](https://funtraits.github.io/intraitR/reference/intraspecific_variability.md) |
| 3\. Trait space | ACP des rapports log-transformés et standardisés ; dispersion par espèce, tests par permutations (Holm) | [`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md), [`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md) |
| 4\. FISHMORPH | l’échantillon dans l’espace des ~9 000 espèces d’eau douce ; part de l’espace global | [`project_fishmorph()`](https://funtraits.github.io/intraitR/reference/project_fishmorph.md) |
| 5\. ITV | variance entre et au sein des espèces (et entre sites) ; raréfaction et nombre d’individus nécessaire (n\*) | [`itv_index()`](https://funtraits.github.io/intraitR/reference/itv_index.md), [`itv_accumulation()`](https://funtraits.github.io/intraitR/reference/itv_accumulation.md) |
| 6\. Shape | superposition Procrustes, espace des formes, disparité de forme | [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md), [`shape_space()`](https://funtraits.github.io/intraitR/reference/shape_space.md) |
| 7\. Measurement error | %ME et répétabilité par mesure, erreur de placement par point (passes répétées) | [`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md), [`digitization_error()`](https://funtraits.github.io/intraitR/reference/digitization_error.md) |
| 8\. Export | le projet (.zip) et son rapport | [`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md) |

**Export.** Donnez un titre, les auteurs et un nom de dossier, puis
*Build the project*. Le projet a l’architecture d’un article publié :

    mon_projet/
    ├── scripts/      00_START, 01_DATA, 02_ANALYSIS, 03_FIGURE_*, 04_SUPP_*, 05_STAT_*
    ├── utils/        library.R, parameters.R (tous les paramètres, un seul endroit), functions.R
    ├── data/         raw/ (points tels que numérisés, littérature), processed/, metadata.csv
    ├── results/      figures/ (Fig*, FigS* : png + pdf), tables/ (Table*, TableS* : csv)
    ├── manuscript/   Methods_Results.Rmd et .docx, references.bib
    ├── run_all.R     exécute tout, puis produit le rapport
    └── README.md, <projet>.Rproj, .gitignore, session_info.txt

Les tableaux, figures et le rapport ne sont pas des copies de l’écran :
l’export **exécute les propres scripts du projet** (`run_all.R`, dans
une session R séparée), si bien que l’archive contient exactement ce que
l’on obtient en le relançant. Changez une valeur dans
`utils/parameters.R` et relancez `run_all.R` pour tout mettre à jour.

Le rapport (`manuscript/Methods_Results.docx`) ne contient que les
Méthodes et les Résultats, chaque chiffre lu dans `results/tables/`,
avec les références. Le texte entre \[crochets\] est à compléter par
vous (échantillonnage, protocole photographique, jeux de données
utilisés) — l’application ne peut pas le connaître.

## Les autres applications du hub

Le menu *Apps* ouvre, chacune dans son onglet : l’**espace fonctionnel
FISHMORPH** (Rfishmorph) et, quand le hub est lancé par FishInTrait, les
applications de la base de campagne.

## Avec FishInTrait (base de campagne)

FishInTrait gère une campagne d’échantillonnage : photographies reçues
du terrain, codes des spécimens, sites, dates, identifications, jeux de
données publiés. Il ouvre le même hub sur son projet :

``` r

library(FishInTrait)
p <- fit_project_open("chemin/vers/00_project")
launch_fishintrait_measure(p, operator = "AT")
```

| Besoin | Application (depuis le menu *Apps* du hub ou une photographie) |
|----|----|
| Faire entrer des photographies, une fiche terrain, des points | *Import* — `launch_fishintrait_import()` : projet, livraison (avec contrôle des photographies **déjà importées**), fiche terrain, photographies (espèce, effectif, pose), import, corrections, qualité & export |
| Ajouter des données de traits publiées | *Literature* — `launch_fishintrait_literature()` |
| Recadrer, tourner, ré-identifier une photographie | *Edit this photograph* — `launch_fishintrait_photo()` |
| Vérifier les identifications | *Review* — `launch_fishintrait_review()` |
| Explorer les traits par site, espèce, dans l’espace FISHMORPH | *Explore* — `launch_fishintrait_explorer()` |

Le hub connaît alors la **provenance** de chaque photographie (campagne
ou musée) et propose la **littérature** du projet dans *4. Results*. Les
enregistrements publiés n’ont pas de photographie : ils entrent dans les
traits et dans toutes les analyses fondées sur les rapports, jamais dans
les tableaux de points, la forme ou l’erreur de mesure. Un jeu de
données peut ne pas avoir un rapport (par exemple un jeu sans PFv) :
l’onglet *Data* des analyses le montre, et décocher ce rapport fait
entrer ses enregistrements — à dire, et à justifier, dans les Méthodes.

## Sans les applications

Chaque étape a sa fonction, pour écrire un script ou reproduire une
session :

``` r

q   <- measure_queue("photos", species = "folder", journal_dir = "journal")
batch_landmarks(...)                          # pré-passe automatique
digitize_landmarks(photo_dir = "photos", xlsx_path = "landmarks.xlsx",
                   journal_dir = "journal", operator = "AT")
consolidate_landmarks("journal", xlsx_path = "landmarks.xlsx")  # classeur reconstruit depuis le journal
fish <- read_digitizer_workbook("landmarks.xlsx")  # tous les points, charnières 24/25 comprises
seg <- fishmorph_segments(fish, scale_cm = 1)
rat <- fishmorph_ratios(seg)
write_analysis_project(fish, "mon_projet", params = analysis_params(min_n = 10))
```

## Quand quelque chose ne va pas

| Symptôme | Cause, remède |
|----|----|
| *Predict* indique qu’aucun modèle n’est disponible | [`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md) puis [`install_mlmorph_python()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_python.md), une fois par ordinateur |
| Un spécimen déjà mesuré réapparaît comme *new* | il a été enregistré dans un autre classeur ou journal : donnez toujours les mêmes `xlsx_path`, `journal_dir` et `operator` |
| Erreur de mesure : « every individual must have at least 2 replicates » (anciennes versions) | une photographie de la feuille `bias` n’a été numérisée qu’une fois ; elle est maintenant écartée et nommée — numérisez-la une deuxième fois |
| Des enregistrements de littérature jamais analysés | un rapport manque dans le jeu de données : voir le tableau de couverture de *1. Data* |
| Bl et BEl semblent trop faibles sur des poissons courbés | placez les charnières 22/24(/25) sur l’axe du corps ; la longueur standard suit alors le corps |
| Un classeur paraît faux | reconstruisez-le depuis le journal : *Rebuild from the journal* dans le digitizer, ou [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md) |

## Références

Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
Villéger S (2021) FISHMORPH: a global database on morphological traits
of freshwater fishes. *Global Ecology and Biogeography* 30 : 2330–2336.

Villéger S, Ramos Miranda J, Flores Hernández D, Mouillot D (2010)
Contrasting changes in taxonomic vs. functional diversity of tropical
fish communities after habitat degradation. *Ecological Applications* 20
: 1512–1522.

Violle C, Enquist BJ, McGill BJ, Jiang L, Albert CH, Hulshof C, Jung V,
Messier J (2012) The return of the variance: intraspecific variability
in community ecology. *Trends in Ecology & Evolution* 27 : 244–252.
