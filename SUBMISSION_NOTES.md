# Notes de finalisation avant soumission CRAN

Ce package a été écrit intégralement à la main (code R + DESCRIPTION +
NAMESPACE + Rd via roxygen2 non exécuté), car l’environnement dans
lequel il a été généré ne dispose ni de R, ni d’un accès root, ni d’un
accès réseau vers CRAN — il n’a donc pas été possible d’exécuter
`devtools::document()`, `devtools::check()` ou `R CMD build/check` pour
valider automatiquement le paquet. Une relecture statique (équilibrage
des parenthèses/accolades sur l’ensemble des fichiers R, cohérence entre
les tags `@export`/`@importFrom` et le fichier `NAMESPACE`) a été
effectuée, et une incohérence trouvée lors de cette relecture
(`print.intrait_shapespace` manquant du `NAMESPACE`) a été corrigée.
Mais **une vérification complète sous R reste nécessaire avant toute
soumission**.

## Mise à jour v1.1.0 : `method` multi-mesures + `compare_functional_richness()`

Ajouté après le premier run réel de v1.0.0, et donc **de nouveau non
exécuté sous R** dans cet environnement (toujours pas de R disponible
ici) :
[`bootstrap_functional_space()`](https://funtraits.github.io/intraitR/reference/bootstrap_functional_space.md)
et
[`species_sensitivity()`](https://funtraits.github.io/intraitR/reference/species_sensitivity.md)
acceptent désormais un argument `method` (`"convexhull"`, comportement
par défaut inchangé ; `"dendrogram"`, `"tpd"`, `"hypervolume"`), et une
nouvelle fonction
[`compare_functional_richness()`](https://funtraits.github.io/intraitR/reference/compare_functional_richness.md)
exécute plusieurs méthodes sur les mêmes données et tabule les
résultats.

Point d’attention prioritaire avant soumission : les appels à
[`TPD::TPDsMean()`](https://rdrr.io/pkg/TPD/man/TPDsMean.html)/[`TPD::TPDc()`](https://rdrr.io/pkg/TPD/man/TPDc.html)/[`TPD::REND()`](https://rdrr.io/pkg/TPD/man/REND.html)
et
[`hypervolume::hypervolume_gaussian()`](https://rdrr.io/pkg/hypervolume/man/hypervolume_gaussian.html)/`estimate_bandwidth()`/`get_volume()`
ont été écrits à partir de la documentation CRAN de référence de ces
deux packages (manuels `.Rd` lus au moment de l’écriture, via recherche
web puisqu’aucun R local n’était disponible pour vérifier
interactivement
[`?TPD::TPDsMean`](https://rdrr.io/pkg/TPD/man/TPDsMean.html) etc.), et
non testés par exécution réelle. Avant toute soumission :

- Installer `TPD` et `hypervolume` sur votre poste et lancer les tests
  `method = "tpd"`/`method = "hypervolume"` de
  `test-bootstrap_functional_space.R`, `test-species_sensitivity.R`, et
  `test-compare_functional_richness.R` (protégés par
  [`testthat::skip_if_not_installed()`](https://testthat.r-lib.org/reference/skip.html),
  donc silencieusement ignorés sans ces packages — vérifiez qu’ils
  s’exécutent bien et passent, pas seulement qu’ils sont “skip”).
- Vérifier en particulier que `trait_ranges` (grille fixe passée à
  [`TPD::TPDsMean()`](https://rdrr.io/pkg/TPD/man/TPDsMean.html)) et
  `kde.bandwidth` (largeur de bande fixe passée à
  [`hypervolume::hypervolume_gaussian()`](https://rdrr.io/pkg/hypervolume/man/hypervolume_gaussian.html))
  acceptent bien le format construit par `.fspace_richness_setup()` dans
  la version de ces packages installée sur votre poste
  (`packageVersion("TPD")`, `packageVersion("hypervolume")`).
- `method = "dendrogram"` ne dépend que de
  [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html) (aucune
  nouvelle dépendance) et a été raisonné à la main (longueur totale de
  branches UPGMA, Petchey & Gaston 2002) ; à vérifier aussi par un vrai
  `devtools::test()`, par prudence, comme pour tout le reste du paquet.
- `DESCRIPTION` : `TPD` et `hypervolume` ont été ajoutés à `Suggests` ;
  `Version:` est passé à 1.1.0 et un champ `Date:` a été ajouté.

## Mise à jour v1.0.0 : premier `devtools::test()` réel

Pour la version 1.0.0, `devtools::test()` a enfin été exécuté sur un
poste avec R (celui du mainteneur), et non plus seulement relu
statiquement comme pour toutes les versions précédentes. Résultat : 465
tests passés, 0 échec, 5 avertissements attendus (documentés ci-dessous)
et 6 tests ignorés (`skip`) pour des raisons attendues (chemins
nécessitant un package absent volontairement du test, ou une session R
interactive). Un seul problème a été détecté :

- **`test-trait_disparity.R`, test de régression sur `iter` à 2
  groupes** : `%in%` a en réalité une précédence plus forte que `/` en R
  (voir [`?Syntax`](https://rdrr.io/r/base/Syntax.html)), si bien que
  `x %in% ((0:5) + 1) / 6` s’analysait en `(x %in% ((0:5) + 1)) / 6` au
  lieu de `x %in% (((0:5) + 1) / 6)` — c’est-à-dire une erreur dans le
  **test lui-même**, pas dans
  [`trait_disparity()`](https://funtraits.github.io/intraitR/reference/trait_disparity.md)
  (dont les *autres* tests, y compris un test de puissance statistique
  réelle, passaient déjà). Corrigé en parenthésant explicitement le
  dénominateur ; voir `NEWS.md`.

Ceci confirme, a posteriori, la fiabilité de la méthode suivie jusqu’ici
en l’absence de R (relecture manuelle systématique + réimplémentation
Python indépendante de la logique statistique) : aucun bug de *logique
métier* n’a été détecté dans le code du paquet lui-même par ce premier
run réel, seulement un bug de syntaxe R localisé dans un test. Il reste
néanmoins recommandé de lancer `devtools::check(cran = TRUE)` (pas
seulement `devtools::test()`) avant toute soumission, celui-ci vérifiant
des aspects que `test()` ne couvre pas (documentation, exemples,
`NAMESPACE`, taille du paquet, etc.).

### Ajout v0.2.0 : protocole FISHMORPH (Brosse et al., 2021)

[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md),
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
et
[`simulate_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/simulate_fishmorph_points.md)
implémentent le schéma de digitalisation à 21/22 points et les 9 ratios
de Brosse et al. (2021), tel que défini dans votre figure “Points Orga”.
Points à vérifier en priorité sur votre poste : - Les indices de
landmarks (1-22) et leurs correspondances aux mesures (Bl, Bd, Hd, Eh,
Mo, PFi, PFl, Ed, Jl, CPd, CFd) ont été retranscrits à la main depuis
votre figure ; reproduisez le calcul sur un spécimen réel digitalisé
pour confirmer l’alignement exact des points, en particulier pour Eh
(7-8) et le point de courbure optionnel (22), moins explicites sur la
figure que les autres mesures. - Les tests unitaires de
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
utilisent une configuration de points construite à la main (distances
connues) et vérifient les 11 segments et la mise à l’échelle ; ceci
couvre la logique de calcul mais ne remplace pas une validation sur vos
propres photos digitalisées. -
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
n’utilise que des fonctions de base R
([`stats::prcomp`](https://rdrr.io/r/stats/prcomp.html),
[`stats::cmdscale`](https://rdrr.io/r/stats/cmdscale.html),
[`stats::dist`](https://rdrr.io/r/stats/dist.html)), sans nouvelle
dépendance.

## Étapes à effectuer sur votre poste (R + RStudio déjà installés)

1.  Installer les dépendances si nécessaire :

    ``` r

    install.packages(c("geomorph", "devtools", "roxygen2", "testthat", "knitr", "rmarkdown"))
    ```

2.  Régénérer `NAMESPACE` et `man/*.Rd` à partir des commentaires
    roxygen2 (déjà présents dans chaque fichier `R/*.R`) :

    ``` r

    devtools::document()
    ```

    Cela doit reproduire un `NAMESPACE` identique à celui fourni ;
    sinon, `devtools::document()` fait foi.

3.  Lancer les tests unitaires :

    ``` r

    devtools::test()
    ```

4.  Construire la vignette et vérifier le paquet dans son ensemble :

    ``` r

    devtools::check(cran = TRUE)
    ```

    Corriger toute erreur, avertissement (`WARNING`) ou note (`NOTE`)
    avant soumission. Points à surveiller en particulier :

    - Les noms d’arguments exacts des fonctions `geomorph` utilisées
      (`gpagen()`, `gm.prcomp()`, `geomorph.data.frame()`,
      `morphol.disparity()`, `procD.lm()`, `two.d.array()`,
      `arrayspecs()`) ont été écrits de mémoire d’après une version
      récente de `geomorph` ; vérifiez qu’ils correspondent bien à la
      version de `geomorph` installée sur votre poste
      (`packageVersion("geomorph")`), en particulier la structure
      retournée par `gm.prcomp()` (élément `$rotation`).

5.  `DESCRIPTION` :

    - `URL:`/`BugReports:` pointent vers
      `https://github.com/FunTraits/intraitR` (dépôt créé le 2026-07-01
      ; voir `GITHUB_SETUP.md` pour la mise en ligne). Si le dépôt
      venait à changer de nom ou d’organisation, pensez à mettre à jour
      ces deux champs (ainsi que `inst/CITATION` et l’exemple
      `remotes::install_github()` du `README.md`).
    - Vérifiez le champ `Version:` (actuellement 1.1.0 ; voir `NEWS.md`
      pour l’historique complet des versions) et le champ `Date:`
      (actuellement 2026-07-04).

6.  (Optionnel) Générer un jeu de données statique inclus dans le paquet
    : exécutez `data-raw/simulate_data.R` (voir les instructions dans ce
    fichier et dans `R/data.R`) si vous préférez livrer `fish_landmarks`
    comme objet de données plutôt que de le générer à la volée avec
    [`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md).

7.  Vérifier win-builder / R-hub avant soumission :

    ``` r

    devtools::check_win_devel()
    rhub::check_for_cran()  # ou usethis::use_github_action("check-standard")
    ```

8.  Compléter `cran-comments.md` avec les résultats réels de
    `devtools::check()` puis soumettre via :

    ``` r

    devtools::submit_cran()
    ```

## Choix de conception à connaître

- Le paquet ne dépend que de fonctions `geomorph` appelées explicitement
  via `geomorph::fonction()` (aucun
  [`library(geomorph)`](https://github.com/geomorphR/geomorph) requis),
  ce qui est conforme aux bonnes pratiques CRAN pour les paquets en
  `Imports`.
- Aucune donnée binaire (`data/*.rda`) n’est livrée par défaut : tous
  les exemples, tests et la vignette utilisent
  [`simulate_fish_landmarks()`](https://funtraits.github.io/intraitR/reference/simulate_fish_landmarks.md),
  ce qui évite toute dépendance à un fichier de données pré-calculé et
  garantit une reproductibilité totale via `seed`.
- [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
  réimplémente un analyseur de fichiers `.tps` en base R (plutôt que de
  s’appuyer sur
  [`geomorph::readland.tps()`](https://rdrr.io/pkg/geomorph/man/readland.tps.html))
  afin d’exposer explicitement le facteur d’échelle (`SCALE=`)
  nécessaire à
  [`linear_distances()`](https://funtraits.github.io/intraitR/reference/linear_distances.md)/[`morpho_ratios()`](https://funtraits.github.io/intraitR/reference/morpho_ratios.md)
  ; le cœur statistique (GPA, PCA de forme, ANOVA procustéenne,
  disparité) reste entièrement délégué à `geomorph`, conformément à
  votre préférence.
