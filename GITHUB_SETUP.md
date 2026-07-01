---
editor_options: 
  markdown: 
    wrap: 72
---

# Mise en ligne sur GitHub (FunTraits/intraitR)

## Important : à propos d'un dossier `.git` déjà présent

J'ai tenté d'initialiser `git` directement dans ce dossier depuis mon
environnement, mais celui-ci ne peut pas supprimer certains fichiers
temporaires que `git` crée puis nettoie normalement (limitation de mon
bac à sable sur ce dossier synchronisé OneDrive, pas de votre machine).
Résultat : il y a peut-être un dossier `.git` incomplet et verrouillé
dans `intraitR/`. **Supprimez-le d'abord depuis votre propre machine**
(Finder/Explorateur, ou un terminal local) avant de continuer :

``` bash
cd /chemin/vers/Intrait_Package/intraitR
rm -rf .git
```

Cette suppression devrait fonctionner normalement chez vous (la
restriction ne s'applique qu'à mon environnement). Tout le reste du
contenu du dossier (code R, tests, DESCRIPTION, etc.) est intact et n'a
pas été affecté.

## 1. Initialiser git et faire le premier commit (sur votre machine)

Dans un terminal, à la racine du dossier `intraitR` :

``` bash
cd /chemin/vers/Intrait_Package/intraitR
git init
git add -A
git commit -m "Initial commit: intraitR v0.7.3"
```

## 2. Créer le dépôt vide sur GitHub

Sur <https://github.com/organizations/FunTraits/repositories/new> (ou
`gh repo create FunTraits/intraitR --public --source=. --remote=origin`
si vous avez la CLI `gh` installée et authentifiée) :

-   Nom du dépôt : `intraitR`
-   **Ne cochez aucune case d'initialisation** (pas de README, pas de
    `.gitignore`, pas de licence) : votre dépôt local en contient déjà,
    et GitHub refusera sinon la première synchronisation (historiques
    divergents).
-   Visibilité : public ou privé, selon votre préférence.

## 3. Relier le dépôt local et pousser

``` bash
git remote add origin https://github.com/FunTraits/intraitR.git
git branch -M main
git push -u origin main
```

(Remplacez l'URL par `git@github.com:FunTraits/intraitR.git` si vous
utilisez l'authentification SSH plutôt que HTTPS.)

## Ce qui a été préparé pour vous

-   **`DESCRIPTION`, `README.md`, `inst/CITATION`** : toutes les
    références à l'ancienne URL provisoire (`aureletoussaint/intraitR`)
    ont été remplacées par `FunTraits/intraitR`.

-   **`.github/workflows/R-CMD-check.yaml`** : intégration continue
    standard (`usethis::use_github_action("check-standard")`), qui
    exécutera `R CMD check` sur Linux (R release, devel, oldrel), macOS
    et Windows à chaque push/pull request. Un badge peut être ajouté au
    `README.md` une fois le premier workflow exécuté avec succès :

    ``` markdown
    [![R-CMD-check](https://github.com/FunTraits/intraitR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/FunTraits/intraitR/actions/workflows/R-CMD-check.yaml)
    ```

-   **`.gitignore`** : complété pour exclure `.DS_Store`, ainsi que deux
    fichiers de test locaux qui traînaient dans le dossier
    (`specimens.tps` et `P5180033.jpg`, produits par votre essai de
    `digitize_landmarks()`) — ils ne seront donc pas poussés sur GitHub
    une fois que vous aurez lancé `git add`. Si vous souhaitez au
    contraire verser une vraie photo d'exemple ou des données
    digitalisées réelles au dépôt, retirez les lignes correspondantes du
    `.gitignore` (idéalement sous un chemin dédié comme `data-raw/`
    plutôt qu'à la racine).

## Après la mise en ligne

-   `BugReports:` (dans `DESCRIPTION`) pointe déjà vers
    `github.com/FunTraits/intraitR/issues`.
-   Pour publier la documentation du package en ligne (vignette, pages
    d'aide), `usethis::use_pkgdown()` puis un second workflow GitHub
    Actions (`usethis::use_pkgdown_github_pages()`) génèrent un site
    consultable à `https://funtraits.github.io/intraitR/` — dites-moi si
    vous voulez que je prépare ce workflow également.
-   Pour une soumission CRAN, `cran-comments.md` et
    `SUBMISSION_NOTES.md` restent à jour comme pense-bête
    (`devtools::check(cran = TRUE)` doit être lancé sur votre machine
    avant toute soumission, cette vérification n'étant pas possible dans
    mon environnement).
