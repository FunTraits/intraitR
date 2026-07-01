# Notes de finalisation avant soumission CRAN

Ce package a été écrit intégralement à la main (code R + DESCRIPTION +
NAMESPACE + Rd via roxygen2 non exécuté), car l'environnement dans lequel
il a été généré ne dispose ni de R, ni d'un accès root, ni d'un accès
réseau vers CRAN — il n'a donc pas été possible d'exécuter
`devtools::document()`, `devtools::check()` ou `R CMD build/check` pour
valider automatiquement le paquet. Une relecture statique (équilibrage des
parenthèses/accolades sur l'ensemble des fichiers R, cohérence entre les
tags `@export`/`@importFrom` et le fichier `NAMESPACE`) a été effectuée,
et une incohérence trouvée lors de cette relecture (`print.intrait_morphospace`
manquant du `NAMESPACE`) a été corrigée. Mais **une vérification complète
sous R reste nécessaire avant toute soumission**.

### Ajout v0.2.0 : protocole FISHMORPH (Brosse et al., 2021)

`fishmorph_segments()`, `fishmorph_ratios()`, `trait_space()`,
`plot_fishmorph_points()` et `simulate_fishmorph_points()` implémentent le
schéma de digitalisation à 21/22 points et les 9 ratios de Brosse et al.
(2021), tel que défini dans votre figure "Points Orga". Points à vérifier
en priorité sur votre poste :
- Les indices de landmarks (1-22) et leurs correspondances aux mesures
  (Bl, Bd, Hd, Eh, Mo, PFi, PFl, Ed, Jl, CPd, CFd) ont été retranscrits à
  la main depuis votre figure ; reproduisez le calcul sur un spécimen réel
  digitalisé pour confirmer l'alignement exact des points, en particulier
  pour Eh (7-8) et le point de courbure optionnel (22), moins explicites
  sur la figure que les autres mesures.
- Les tests unitaires de `fishmorph_segments()` utilisent une
  configuration de points construite à la main (distances connues) et
  vérifient les 11 segments et la mise à l'échelle ; ceci couvre la
  logique de calcul mais ne remplace pas une validation sur vos propres
  photos digitalisées.
- `trait_space()` n'utilise que des fonctions de base R (`stats::prcomp`,
  `stats::cmdscale`, `stats::dist`), sans nouvelle dépendance.

## Étapes à effectuer sur votre poste (R + RStudio déjà installés)

1. Installer les dépendances si nécessaire :
   ```r
   install.packages(c("geomorph", "devtools", "roxygen2", "testthat", "knitr", "rmarkdown"))
   ```
2. Régénérer `NAMESPACE` et `man/*.Rd` à partir des commentaires roxygen2
   (déjà présents dans chaque fichier `R/*.R`) :
   ```r
   devtools::document()
   ```
   Cela doit reproduire un `NAMESPACE` identique à celui fourni ; sinon,
   `devtools::document()` fait foi.
3. Lancer les tests unitaires :
   ```r
   devtools::test()
   ```
4. Construire la vignette et vérifier le paquet dans son ensemble :
   ```r
   devtools::check(cran = TRUE)
   ```
   Corriger toute erreur, avertissement (`WARNING`) ou note (`NOTE`)
   avant soumission. Points à surveiller en particulier :
   - Les noms d'arguments exacts des fonctions `geomorph` utilisées
     (`gpagen()`, `gm.prcomp()`, `geomorph.data.frame()`,
     `morphol.disparity()`, `procD.lm()`, `two.d.array()`,
     `arrayspecs()`) ont été écrits de mémoire d'après une version
     récente de `geomorph` ; vérifiez qu'ils correspondent bien à la
     version de `geomorph` installée sur votre poste (`packageVersion("geomorph")`),
     en particulier la structure retournée par `gm.prcomp()`
     (élément `$rotation`).
5. `DESCRIPTION` :
   - `URL:`/`BugReports:` pointent vers `https://github.com/FunTraits/intraitR`
     (dépôt créé le 2026-07-01 ; voir `GITHUB_SETUP.md` pour la mise en
     ligne). Si le dépôt venait à changer de nom ou d'organisation,
     pensez à mettre à jour ces deux champs (ainsi que `inst/CITATION`
     et l'exemple `remotes::install_github()` du `README.md`).
   - Vérifiez le champ `Version:` (actuellement 0.7.2 ; voir `NEWS.md`
     pour l'historique complet des versions) et ajoutez un champ `Date:`
     si vous le souhaitez.
6. (Optionnel) Générer un jeu de données statique inclus dans le paquet :
   exécutez `data-raw/simulate_data.R` (voir les instructions dans ce
   fichier et dans `R/data.R`) si vous préférez livrer `fish_landmarks`
   comme objet de données plutôt que de le générer à la volée avec
   `simulate_fish_landmarks()`.
7. Vérifier win-builder / R-hub avant soumission :
   ```r
   devtools::check_win_devel()
   rhub::check_for_cran()  # ou usethis::use_github_action("check-standard")
   ```
8. Compléter `cran-comments.md` avec les résultats réels de
   `devtools::check()` puis soumettre via :
   ```r
   devtools::submit_cran()
   ```

## Choix de conception à connaître

* Le paquet ne dépend que de fonctions `geomorph` appelées explicitement
  via `geomorph::fonction()` (aucun `library(geomorph)` requis), ce qui
  est conforme aux bonnes pratiques CRAN pour les paquets en `Imports`.
* Aucune donnée binaire (`data/*.rda`) n'est livrée par défaut : tous les
  exemples, tests et la vignette utilisent `simulate_fish_landmarks()`,
  ce qui évite toute dépendance à un fichier de données pré-calculé et
  garantit une reproductibilité totale via `seed`.
* `read_tps()` réimplémente un analyseur de fichiers `.tps` en base R
  (plutôt que de s'appuyer sur `geomorph::readland.tps()`) afin
  d'exposer explicitement le facteur d'échelle (`SCALE=`) nécessaire à
  `linear_distances()`/`morpho_ratios()` ; le cœur statistique (GPA, PCA
  de forme, ANOVA procustéenne, disparité) reste entièrement délégué à
  `geomorph`, conformément à votre préférence.
