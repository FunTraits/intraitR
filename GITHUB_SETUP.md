# Mise en ligne sur GitHub (FunTraits/intraitR)

## Important : à propos d'un dossier `.git` déjà présent

J'ai tenté d'initialiser `git` directement dans ce dossier depuis mon environnement, mais celui-ci ne peut pas supprimer certains fichiers temporaires que `git` crée puis nettoie normalement (limitation de mon bac à sable sur ce dossier synchronisé OneDrive, pas de votre machine). Résultat : il y a peut-être un dossier `.git` incomplet et verrouillé dans `intraitR/`. **Supprimez-le d'abord depuis votre propre machine** (Finder/Explorateur, ou un terminal local) avant de continuer :

``` bash
cd /chemin/vers/Intrait_Package/intraitR
rm -rf .git
```

Cette suppression devrait fonctionner normalement chez vous (la restriction ne s'applique qu'à mon environnement). Tout le reste du contenu du dossier (code R, tests, DESCRIPTION, etc.) est intact et n'a pas été affecté.

## 1. Initialiser git et faire le premier commit (sur votre machine)

Dans un terminal, à la racine du dossier `intraitR` :

``` bash
cd /chemin/vers/Intrait_Package/intraitR
git init
git add -A
git commit -m "intraitR v1.0.0"
```

## 2. Créer le dépôt vide sur GitHub

Sur <https://github.com/organizations/FunTraits/repositories/new> (ou `gh repo create FunTraits/intraitR --public --source=. --remote=origin` si vous avez la CLI `gh` installée et authentifiée) :

-   Nom du dépôt : `intraitR`
-   **Ne cochez aucune case d'initialisation** (pas de README, pas de `.gitignore`, pas de licence) : votre dépôt local en contient déjà, et GitHub refusera sinon la première synchronisation (historiques divergents).
-   Visibilité : public ou privé, selon votre préférence.

## 3. Relier le dépôt local et pousser

``` bash
git remote add origin https://github.com/FunTraits/intraitR.git
git branch -M main
git push -u origin main
```

(Remplacez l'URL par `git@github.com:FunTraits/intraitR.git` si vous utilisez l'authentification SSH plutôt que HTTPS.)

## Ce qui a été préparé pour vous

-   **`DESCRIPTION`, `README.md`, `inst/CITATION`** : toutes les références à l'ancienne URL provisoire (`aureletoussaint/intraitR`) ont été remplacées par `FunTraits/intraitR`.
-   **`.github/workflows/R-CMD-check.yaml`** : intégration continue standard (`usethis::use_github_action("check-standard")`), qui exécutera `R CMD check` sur Linux (R release, devel, oldrel), macOS et Windows à chaque push/pull request.
-   **`.github/workflows/pkgdown.yaml`** : construit et déploie automatiquement un site de documentation sur `gh-pages` à chaque push sur la branche par défaut (voir `_pkgdown.yml` pour la configuration de l'index de référence) ; il sera consultable à `https://funtraits.github.io/intraitR/` après le premier déploiement réussi.
-   **`.github/workflows/test-coverage.yaml`** : calcule la couverture de tests (`covr::package_coverage()`) et l'envoie à Codecov à chaque push. Nécessite un secret de dépôt `CODECOV_TOKEN` (à créer sur <https://codecov.io> après avoir lié le dépôt) pour que l'envoi fonctionne ; sans ce secret, le workflow s'exécute mais l'étape d'envoi échoue silencieusement en pull request externe.
-   **Badges** : les quatre badges de statut (R-CMD-check, couverture de tests, Codecov, pkgdown) sont déjà dans `README.md` ; ils s'activeront automatiquement une fois les workflows correspondants exécutés au moins une fois sur GitHub.
-   **`.gitignore`** : complété pour exclure `.DS_Store`, ainsi que deux fichiers de test locaux qui traînaient dans le dossier (`specimens.tps` et `P5180033.jpg`, produits par votre essai de `digitize_landmarks()`) — ils ne seront donc pas poussés sur GitHub une fois que vous aurez lancé `git add`. Si vous souhaitez au contraire verser une vraie photo d'exemple ou des données digitalisées réelles au dépôt, retirez les lignes correspondantes du `.gitignore` (idéalement sous un chemin dédié comme `data-raw/` plutôt qu'à la racine).

## Après la mise en ligne

-   `BugReports:` (dans `DESCRIPTION`) pointe déjà vers `github.com/FunTraits/intraitR/issues`.
-   Le site pkgdown (voir ci-dessus) se déploiera automatiquement au premier push sur `main` ; activez GitHub Pages sur la branche `gh-pages` dans Settings \> Pages si ce n'est pas fait automatiquement par le workflow.
-   Pour une soumission CRAN, `cran-comments.md` et `SUBMISSION_NOTES.md` restent à jour comme pense-bête. `devtools::test()` a maintenant été exécuté avec succès sur votre poste (465 tests passés, 0 échec après correction d'un bug de précédence d'opérateur dans un test de régression — voir `NEWS.md`, v1.0.0) ; il reste à lancer `devtools::check(cran = TRUE)` avant toute soumission effective.
