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

