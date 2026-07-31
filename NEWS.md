# intraitR 1.29.0

## La numerisation ne repart plus en boucle

* SYMPTOME : des photographies deja mesurees reviennent dans la file « new »
  a chaque lancement, indefiniment.
* CAUSE PREMIERE -- le classeur pris pour la verite. Le journal EST la source
  de verite : chaque enregistrement y va d'abord, et le classeur n'est qu'un
  export reecrit tous les `xlsx_flush_every` enregistrements. Mais la file
  d'attente, elle, ne lisait que le CLASSEUR. Une ecriture refusee -- fichier
  ouvert dans Excel, dossier en cours de synchronisation -- laissait donc les
  enregistrements dans le seul journal, et le lancement suivant remettait
  leurs photographies dans « new ». Les remesurer ecrivait dans le meme
  classeur qui ne pouvait pas etre ecrit : la boucle etait complete. Un
  operateur qui remesure les memes poissons chaque matin est le symptome
  visible d'une ecriture qui a echoue sans etre vue.
* Le journal est desormais consulte AU DEMARRAGE et reconcilie EN MEMOIRE : la
  file est immediatement juste, RIEN N'EST ECRIT, et un message dit combien
  d'enregistrements manquaient au classeur et quoi faire (« Write the workbook
  now »). Reparer le classeur reste un geste delibere.
* CAUSE SECONDE -- le nombre d'individus par photographie. Il vit en memoire et
  son defaut est un argument de lancement : une plaque de quatre numerisee en
  `<photo>_i1 ... _i4` etait, au lancement suivant, cherchee sous le
  `<photo>` nu du defaut a un, introuvable, et repartait dans « new » avec ses
  quatre poissons deja mesures. Le compte est desormais RELU DES IDENTIFIANTS
  eux-memes, qui le disent, au lieu d'etre suppose.
* Les deux reconciliations sont enveloppees dans `isolate()` : elles s'executent
  dans le CORPS de la fonction serveur, ou ECRIRE dans un `reactiveValues` est
  permis mais le LIRE ne l'est pas (« Can't access reactive value outside of
  reactive consumer »). Elles ne dependent de rien et n'ont lieu qu'une fois,
  ce qui est precisement l'usage d'`isolate()`.

# intraitR 1.28.0

## Le zoom montre enfin les cotes

* La fenetre visible etait le rectangle de la PHOTOGRAPHIE divise par le zoom.
  Avec `asp = 1`, une photo en portrait dans un panneau large de deux mille
  pixels etait donc dessinee en colonne etroite, toute la largeur de l'ecran
  restant vide de part et d'autre -- et zoomer sur la tete d'un poisson
  montrait une lamelle verticale, le corps filant hors du bord droit dans un
  espace qui n'avait jamais servi. Le poisson est horizontal ; la fenetre etait
  verticale.
* La fenetre suit desormais la forme du PANNEAU, pas celle du fichier. Au zoom
  1 c'est la plus petite fenetre de cette forme qui contient encore toute la
  photographie -- rien n'est perdu, la vue d'ensemble est celle d'avant --, et
  au-dela le supplement va la ou le panneau est large, c'est-a-dire sur les
  cotes.
* La HAUTEUR DU PANNEAU devient un reglage (« Panel 500 / 700 / 900 / 1200 px »)
  parce qu'elle decide la forme de la vue : panneau court, bande large ;
  panneau haut, colonne etroite. C'est a l'operateur de choisir, pas a une
  constante ecrite dans le code.
* Le deplacement au clic droit est converti avec la fenetre du panneau et non
  avec le rectangle du fichier. Sans cela, un glissement d'une largeur de
  panneau deplacait l'image d'une largeur de photographie, et le curseur
  cessait d'avancer avec elle des que les deux formes differaient -- c'est-a-
  dire desormais toujours.
* DES GUIDES POUR SE DEPLACER, HORS DU CHAMP DE L'IMAGE. Une barre grise
  verticale a droite de la photographie, une horizontale en dessous : la piste
  claire est la photographie entiere, le rectangle sombre la portion a
  l'ecran, et une fleche cliquable a chaque bout deplace la vue d'un CINQUIEME
  de ce qui est visible. Un tiers avait ete choisi d'abord, et il depasse : au
  zoom ou l'on pose reellement un point, un tiers de la fenetre fait plus que
  la tete du poisson, et le point vise quitte l'ecran entre deux appuis. Un
  cinquieme conserve quatre cinquiemes de la vue precedente -- l'oeil ne perd
  jamais son reperage -- au prix d'un clic de plus par ecran, ce qui est le bon
  cote du compromis pour un travail fait point par point.
* Ils ont d'abord ete DESSINES DANS l'image, et c'etait une faute : le clic sur
  le graphique pose un point de repere, donc viser un rail en posait un. Un
  controle que l'oeil lit comme cliquable, dans une surface ou cliquer signifie
  tout autre chose, est un piege quelle que soit la clarte de son etiquette.
  Les guides sont donc du HTML ordinaire, hors du graphique, et ne peuvent pas
  atteindre son gestionnaire de clic.
* Les fleches sont STATIQUES ; seuls les rectangles sombres sont rendus par le
  serveur. Un `actionButton` reconstruit par `renderUI` revient avec son
  compteur remis a zero, que son observateur lit comme un nouvel appui -- et un
  appui qui deplace la vue, qui reconstruit le bouton, qui le rappuie, est un
  defilement infini.
* Un clic dans le fond, a cote de la photographie, est REFUSE avec sa raison.
  Cet arriere-plan cliquable n'existait pas tant que la region de trace etait
  l'image elle-meme, et un point pose la aurait ete une coordonnee hors du
  fichier.

## Un troisieme sens de numerotation : l'ordre de lecture

* Une plaque disposee en GRILLE -- quatre poissons en deux rangees de deux, la
  facon la plus courante de photographier un plateau -- ne peut pas etre
  ordonnee par une seule coordonnee : le deuxieme poisson de la premiere rangee
  est a DROITE du premier, et le troisieme est EN DESSOUS des deux. Chacune des
  deux regles a une dimension refusait donc un clic CORRECT sur la moitie d'une
  telle plaque, et un operateur qu'on refuse quand il a raison cesse vite de
  lire les messages.
* `individual_order = "reading"` compare les DEUX coordonnees : meme rangee, le
  museau doit etre plus a droite ; nouvelle rangee, il doit etre plus bas. Le
  refus nomme laquelle des deux conditions a echoue et avec quelles valeurs,
  au lieu de renvoyer « hors de l'intervalle attendu ».
* Comment une rangee est decidee. DITE, quand `individuals_per_row` est fourni
  (le selecteur « Individuals per row » de l'application) : la rangee de
  l'individu k vaut `ceiling(k / individuals_per_row)`, exacte quel que soit
  l'espacement, sans aucun parametre a regler -- l'operateur connait sa propre
  plaque. INFEREE sinon, depuis les museaux deja places, deux d'entre eux
  partageant une rangee lorsqu'ils sont a moins d'un cinquieme de la hauteur du
  cadre l'un de l'autre. C'est une supposition, elle est ENONCEE, et c'est
  pourquoi la voie exacte est proposee en premier.
* L'avertissement sur le premier poisson suit : `i1` est attendu EN HAUT A
  GAUCHE, et un museau hors de la premiere cellule de la grille vaut un mot,
  jamais un refus -- une plaque n'est pas toujours rangee, et c'est l'operateur
  qui regarde le poisson.
* Les deux modes existants sont inchanges.

## Les applications s'ouvrent dans le navigateur, pas dans le Viewer

* `shiny::runApp(launch.browser = TRUE)` finit dans `utils::browseURL()`, qui
  passe par `options("browser")` -- que RStudio REMPLACE par un gestionnaire
  gardant les URL localhost dans l'IDE. L'application atterrissait donc dans le
  panneau Viewer : quelques centaines de pixels de large, sans barre
  d'adresse, sans second onglet, et avec un moteur JavaScript qui n'est pas
  celui pour lequel l'interface a ete ecrite. Ce n'est pas une affaire de gout :
  une carte leaflet ou une figure plotly y sont inutilisables.
* `launch.browser` accepte desormais quatre formes, avec le meme sens dans les
  trois packages : `TRUE` (defaut) ou `"browser"` force le navigateur du
  systeme ; `"viewer"` restitue le panneau a qui le prefere ; `FALSE` n'ouvre
  rien et imprime l'URL ; une fonction est utilisee telle quelle.
* Le gestionnaire « fenetre externe » de RStudio est cherche PAR NOM dans
  `tools:rstudio`, jamais suppose : hors RStudio, nom disparu dans une version
  future, environnement non attache -- chaque echec retombe sur `browseURL()`.
  Un lanceur ne doit pas s'interrompre parce qu'un nom interne d'un autre
  programme a bouge.

# intraitR 1.27.0

## `impute_traits()` : l'imputation, et le masque de ce qui a ete invente

* L'imputation que `trait_space()`, `fishmorph_ratios()` et
  `fishmorph_segments()` font en interne est desormais EXPOSEE seule, pour
  qu'une table remplie puisse etre CONSERVEE au lieu d'etre recalculee dans
  chaque ordination -- et surtout pour que les cellules remplies voyagent
  avec elle.
* Le retour porte `traits` (la table remplie) ET `imputed`, une matrice
  logique de meme forme, `TRUE` la ou une valeur a ete inventee. C'est la
  seule chose qui distingue ensuite une valeur mesuree d'une valeur imputee :
  une fois dans une table, la seconde a le meme type, le meme ordre de
  grandeur, et fait passer tous les controles de completude. Une fonction qui
  ne rendrait que la matrice remplie rendrait une table qui a discretement
  cesse d'etre un releve de mesures.
* Le masque est preleve AVANT l'imputation, puis intersecte avec ce qui est
  effectivement non-manquant apres : `"impute_mean"` laisse intacte une
  colonne entierement vide, et la declarer remplie serait l'exact contraire de
  ce a quoi ce masque sert.
* `method` accepte aussi `"omit"` et `"keep"`, pour qu'un appelant puisse
  transmettre tel quel le choix de l'utilisateur.

# intraitR 1.26.0

## Les distances des cartouches en % de l'etendue de FISHMORPH

* Les deux distances introduites en 1.25.0 sont desormais rapportees en
  POURCENTAGE DE L'ETENDUE DE FISHMORPH -- la plus grande distance entre deux
  especes de reference sur les deux memes axes, c'est-a-dire le diametre du
  morphospace mondial -- la valeur en unites de scores restant entre
  parentheses. Une distance en unites de scores ne s'interprete pas seule :
  elle depend des traits, de la standardisation et de la paire d'axes
  affichee. La meme distance rapportee a l'etendue occupee est sans dimension
  et se compare entre paires d'axes, entre especes et entre campagnes.
* Nouvelle fonction interne `.cloud_diameter()`. Le diametre d'un ensemble
  plan est atteint par deux sommets de son enveloppe convexe, la recherche
  quadratique ne porte donc que sur l'enveloppe : pour les ~9 500 especes de
  FISHMORPH, quelques dizaines de sommets au lieu de 45 millions de paires.
* L'echelle est celle du nuage de REFERENCE COMPLET, qu'il soit dessine ou non,
  et elle est recalculee a chaque paire d'axes -- le denominateur suit donc la
  figure. Faute d'echelle etablie (moins de deux points distincts), les
  cartouches reviennent aux unites de scores et le disent.

# intraitR 1.25.0

## Deux distances dans les cartouches de `plotly_fishmorph()`

* Nouvel argument `hover_distances` (TRUE par defaut). Le cartouche d'un
  specimen porte desormais sa distance au CENTROIDE de son espece -- sa
  contribution a la dispersion intraspecifique -- et, quand une couche de
  points de reference est dessinee (`reference_points` ou `itv_reference`),
  sa distance au POINT FISHMORPH de son espece, c'est-a-dire a l'individu par
  lequel la base mondiale represente toute l'espece.
* Le losange du style `"spider"` porte la meme seconde distance, du centroide
  au point FISHMORPH : la lecture, par la figure, de l'ecart entre la moyenne
  echantillonnee et le morphotype de reference.
* Ce sont des distances euclidiennes SUR LES DEUX AXES AFFICHES, en unites de
  scores : ce sont celles que la figure montre (`equal_aspect = TRUE` est ce
  qui les rend lisibles), elles changent avec `axes`, et ce ne sont pas des
  distances dans l'espace complet a neuf traits.
* L'appariement de l'espece a la base suit la regle de `itv_reference`
  (casse ignoree, espaces et underscores equivalents) ; une espece absente de
  la base laisse la distance absente plutot que fausse. Le centroide est celui
  des specimens AFFICHES, donc `select_species` / `select_specimens` le
  deplacent -- il coincide toujours avec le losange trace.

# intraitR 1.24.0

## Une coincidence avec une DROITE : LM4 sur l'axe median

* Nouvelle regle dans la barre *Coincident landmarks* de `digitize_landmarks()`
  : **`LM4 on 22-24`**. LM4, l'extremite ventrale de la hauteur de corps, est
  projete perpendiculairement sur l'axe median LM22 -> LM24. Il conserve
  l'abscisse cliquee le long de l'axe et sa hauteur devient nulle ; la droite
  n'est pas bornee par les deux charnieres, le pied de la perpendiculaire peut
  tomber sur leur prolongement.
* C'est un second GENRE de regle. Les quatre existantes enoncent que deux POINTS
  sont confondus et s'ecrivent comme une copie de coordonnees ; celle-ci enonce
  qu'un point appartient a une DROITE et s'ecrit comme une projection. Les
  entrees de `COLLAPSE_RULES` portent donc `moves` (copies) et/ou `project`
  (projections), et `apply_collapse()` recoit un argument `kinds`.
* L'ordre d'application decoule de la geometrie. LM4 est le maitre de la ligne
  ventrale : la projection precede les conventions et `derive_ventral()` est
  rejoue derriere elle, de sorte que LM11, puis LM8 et LM9, soient recalcules a
  partir du LM4 projete. Appliquee a la fin, comme les copies, elle aurait
  laisse une ligne ventrale ne passant plus par son propre pivot.
* Declarer la regle SUSPEND la moitie ventrale du controle des points extremes
  a l'enregistrement (`extreme_violations(skip = )`) : LM4 ne pretend plus etre
  le point le plus ventral, signaler LM6, LM10 ou LM14 en dessous de lui
  reviendrait a signaler la regle elle-meme. La moitie dorsale, sur LM3, est
  inchangee.
* LM4 reste dans `edited` -- seule sa hauteur est imposee, sa position le long
  du corps demeure une mesure et survit a un re-semis -- mais il est reporte
  `"adjusted"` dans le journal, une regle l'ayant place.
* Une projection ne laisse derriere elle aucun couple de points confondus :
  la relecture d'un specimen la retrouve par la geometrie (`collapse_detect()`,
  0,5 px de l'axe). Un ventre reel se situe a la moitie de la hauteur de corps
  de l'axe median, soit environ 12 % de la longueur standard : la bande est
  vide.

# intraitR 1.23.0

## Une seule implementation par operation

* intraitR et Rfishmorph exportaient 13 noms identiques : un script attachant
  les deux obtenait celle du dernier `library()` charge, sans autre signal que
  le message de demarrage. La resolution retenue est une implementation unique
  par operation, detenue par le package dont c'est le domaine, et re-exportee
  par l'autre. `Rfishmorph` passe de `Suggests` a `Imports`.
* Premier lot, sans aucun changement de comportement :
  `load_fishmorph_phylogeny()`, `load_fishmorph_phylo_axes()` et `phylo_pcoa()`
  vivent desormais dans Rfishmorph et sont re-exportees (`R/reexports.R`). Les
  appels non qualifies continuent de fonctionner a l'identique.
* Corollaire : `inst/extdata/Phylogeny/` est supprime d'intraitR. Les deux
  fichiers (852 ko) etaient des copies octet pour octet de ceux de Rfishmorph,
  et deux copies d'une meme donnee sur le disque finissent toujours par diverger.
* `phylo_pcoa()` renvoie maintenant un objet de classe `fishmorph_phylopcoa` et
  non plus `intrait_phylopcoa`. Verifie : rien ne dispatchait sur cette classe
  en dehors de sa propre methode `print()`, donc seul l'affichage change.

## Reste a fusionner

Les huit noms restants ne sont pas interchangeables malgre des signatures
proches, et sont traites un par un avec un controle de non-regression. Cas le
plus instructif : `group_colors()` et `reset_group_colors()` ont la meme
signature et la meme sortie dans les deux packages, mais chacune est liee a son
propre cache de couleurs de session (`.intrait_color_cache` contre
`.fm_color_cache`). Une re-exportation naive rendrait des couleurs qu'aucune
figure intraitR n'a jamais tracees, et `reset_group_colors()` viderait le mauvais
cache -- silencieusement. Le cache doit etre unifie avant la fusion.

# intraitR 1.22.0

## The FISHMORPH reference now has a single owner

* `project_fishmorph()`'s `reference` argument becomes optional. Left `NULL`,
  it asks `Rfishmorph::load_fishmorph_reference()` for the bundled table
  instead of requiring a path. intraitR ships no copy of the FISHMORPH data on
  purpose: two CSVs on disk is precisely how the two packages end up describing
  different species pools without anyone noticing. Rfishmorph moves to
  `Suggests`, so intraitR still installs and tests without it -- the error
  raised when it is missing says what to install and how to bypass it.
* New `source` argument, forwarded to Rfishmorph: `"segment"` for the published
  table (ratios from the eleven measured segments) or `"landmark"` for the
  table recomputed from the landmark re-digitization, which covers only the
  species digitized so far. `NULL` follows
  `getOption("fishmorph.source", "segment")`. Ignored when `reference` is
  supplied, so existing calls behave exactly as before.
* Switching campaign **refits** the global PCA on the chosen table rather than
  reprojecting into the other one. Axis order and sign may therefore differ
  between the two, and scores are not comparable term by term.

# intraitR 1.21.0

## A specimen without a scale bar still has a shape

* `fishmorph_segments()` gains `scale_action`. The default `"na"` is the old
  behaviour -- no scale bar, no centimetres, 11 `NA`s -- because returning pixel
  numbers in a column documented as centimetres is a silent unit error.
  `scale_action = "pixels"` instead measures those specimens in **pixels**: each
  of the nine FISHMORPH ratios divides two measurements of the *same* specimen,
  so the unknown per-specimen factor cancels and the ratios are numerically
  identical to the calibrated ones. `fishmorph_ratios()` then needs no
  `landmarks` argument at all.
* **The mixing is made visible rather than assumed harmless.** A `scale_units`
  column (`"cm"` / `"px"`) is returned, a `"pixel_specimens"` attribute lists
  the affected rows, `fishmorph_ratios()` carries the column through as
  metadata, and a new `print.intrait_segments()` method states the mix at the
  console. What stays invalid is anything absolute -- a pixel is a property of
  one photograph's resolution, so a mean, a variance or an allometric
  regression over mixed rows is meaningless: restrict it explicitly with
  `subset(segments, scale_units == "cm")`.
* The column's presence follows the *call*, not the data (it is there whenever
  `scale_action = "pixels"` was used, even if every specimen was calibrated), so
  downstream code can rely on it, and a default call returns exactly the columns
  it did before.
* The old warning now names the new option, and becomes a `message()` under
  `scale_action = "pixels"` -- nothing is being lost there, so there is nothing
  to warn about.
* **Signature note:** `scale_action` sits third, right after `scale_cm`, where it
  belongs semantically. Calls that passed `groups`, `na_action`, ... *positionally*
  past `scale_cm` must be updated; named calls are unaffected.

## Bl uses the whole broken axis, not just its first hinge

* `fishmorph_segments()` now measures the standard length along **every**
  midline hinge a specimen carries -- 22, 24 and 25 -- as the curvilinear
  length of the polyline 1 -> hinges -> 2. Only landmark 22 was read before, so
  a specimen digitized with two or three hinges (the case the digitizer's
  broken axis exists for) had the rest of its bend measured as a chord, and
  came out too short. Landmark 23 is skipped: it is the derived head base, not
  a point on the axis.
* A hinge counts, specimen by specimen, when its coordinates are complete and
  not all zero -- the protocol's own "+22 if needed, otherwise 22 = 0"
  convention, extended unchanged to 24 and 25. With no hinge placed `Bl` is
  exactly `d(1, 2)` again, so **no 21- or 22-landmark data set changes value**.
* **The chain follows the numbering (1, 22, 24, 25, 2), not the geometry.** The
  numbering *is* the antero-posterior order of the protocol, so a hinge placed
  out of anatomical sequence produces a visibly inflated `Bl` instead of being
  silently re-sorted: that specimen is a digitization error to fix, not a
  measurement to keep. (`digitize_landmarks()`'s on-screen `Bl` orders its
  hinges by projection on the 1-2 chord, so the two agree on every correctly
  digitized specimen and can disagree on a mis-ordered one.)
* Two of the nine ratios move with it: `BEl = Bl / Bd` rises and
  `PFs = PFl / Bl` falls. An uncorrected bend biases both the same way -- a
  curved fish measured chord-wise is recorded as shorter, hence stubbier, than
  it is -- which is why the correction is automatic rather than optional.
  `fishmorph_ratios()`'s scale-bar rescue path shares the same engine
  (`.fishmorph_pixel_segments()`) and therefore inherits it.
* Unchanged on purpose: the shape-analysis helpers (`gpa_fish()`,
  `fishmorph_shape_landmarks()`, `standardize_geometry()`,
  `correct_geometry()`) still use body landmarks 1-19 plus 22 only. Hinges 24
  and 25 are axis constructs, not homologous points, and have no place in a
  Procrustes configuration.

## An interactive FISHMORPH projection

* New `plotly_fishmorph()`: the same figure as
  `plot.intrait_fishmorph_projection()` -- reference density heatmap and/or
  point cloud, per-species hulls / ellipses / density contours, biplot arrows,
  the focal species' own database points -- rendered as a **plotly**
  htmlwidget. `plot()` is untouched and stays base graphics; this is a
  separate function, and plotly is only in `Suggests`.
* **What the static figure cannot do is identify a point.** A ~9,000-species
  morphospace with a few hundred individuals projected into it has no room for
  labels, so hovering is the only practical way to ask which specimen sits at
  a given position: each point reports its identifier, its species, its
  coordinates and its nine ratios *on the analysis scale* (from
  `$specimen_traits`, i.e. the same `log10(x + 1)` scale as the reference that
  defines the space -- the tooltip would otherwise invite a comparison between
  numbers that are not on the same scale). A hull reports its species, its `n`
  and that species' share of the global functional volume, read from
  `$itv_proportion`.
* **The legend is a selection tool, not a caption.** Every trace of one
  species shares a plotly `legendgroup`, so one click hides a species' points
  *and* its hull together and a double-click isolates it: an overplotted cloud
  becomes readable without recomputing anything. The reference layers sit
  outside any group and stay put, since they are the frame the selection is
  read against.
* **Tooltips are sized for a morphospace, not for a number.** The trait values
  are off by default (`hover_traits = FALSE`): nine ratios on one line produced
  a box wider than the plotting region, which covered the very space the point
  was being located in. Switched on, they wrap three per line. Tooltip text is
  10 px (`hover_font_size`), the legend 10 px, and a reserved top margin keeps
  the title clear of plotly's mode bar.
* `axes` takes any pair of components (from the stored all-component scores,
  no refitting), and `equal_aspect = TRUE` anchors the vertical scale to the
  horizontal one -- both axes are in score units, and an unequal ratio
  silently distorts every distance, hull shape and arrow direction read off
  the figure, at every zoom step. Set it to `FALSE` for the base-graphics
  behaviour.
* The reference cloud is drawn with WebGL by default (`webgl = TRUE`): 9,000
  points as one SVG trace make the widget sluggish and slow to save, while
  the specimens stay SVG so their markers and hover boxes are unchanged.

# intraitR 1.20.0

## Plates: several individuals on one photograph

* `digitize_landmarks()` gains `individuals_per_photo` and `individual_order`.
  One photograph = one specimen was an assumption of the app, not a property of
  the data: a plate of four fish over one ruler is the normal field object.
* Each fish is saved as `"<photo>_i1"`, `"<photo>_i2"` ..., a suffix carried by
  the INDIVIDUAL code, so the repeat convention composes on top of it unchanged
  (`"PLATE12_i2_AT_rep3"`) and `read_mlmorph_landmarks()`, the bias sheet and
  the operator-bias summary need no modification at all.
* **The scale bar is placed once per plate.** Landmarks 20-21 survive the move
  to the next individual: one ruler in one focal plane calibrates every fish
  lying on it, and re-digitizing the pair per fish would add an independent
  scale error to each. (Keep the ruler in the plane of the fish: an individual
  far from it carries the plate's residual perspective and lens distortion.)
* **The individual number is spatial, not chronological.** `_i2` has to name the
  same fish for two operators, otherwise a repeat compares two different fish
  and the operator bias it reports measures nothing. The numbering runs top to
  bottom (or left to right) and is enforced ON THE CLICK THAT PLACES LM1: a
  snout falling outside the interval left by the individuals already placed is
  refused, so the operator is stopped before digitizing the wrong fish and no
  identifier already in the journal ever has to be rewritten. The first fish of
  a plate has no neighbour to be checked against, so it gets a warning instead
  when it is not in the first band of the frame.
* The individuals already measured are drawn faintly on the photograph with
  their number, an individual bar in the Specimen panel gives the state of the
  plate and the way back to a fish already saved, and the count is adjustable
  plate by plate (`+ individual` / `- individual`, the latter refusing to orphan
  a row already written).
* **Bug fixed on the way.** The queues tested `PHOTO_CODES %in% saved`, which on
  a plate is never true -- the sheet holds `_i1 ... _in` and the photo code
  appears nowhere. A photograph is now complete when every individual declared
  on it is, so a partly measured plate stays in the "new" queue instead of
  either vanishing from it or never leaving it.

# intraitR 1.19.0

## The caudal depths are measured on the axis again

* **Bug.** The caudal-peduncle pair (16-17) and the caudal-fin pair (18-19) were
  held PARALLEL TO EACH OTHER and to nothing else. That constraint is satisfied
  by a pair oblique to the caudal axis 24 -> 2 -- both segments simply rotate
  together -- so as soon as the axis was adjusted the two pairs kept their old
  absolute orientation and CPd and CFd were returned as hypotenuses rather than
  as depths. A 15 degree obliquity inflates a depth by 3.5 %, silently and in
  one direction only.
* The reference is now the AXIS, not the other pair: both caudal pairs are
  squared onto the perpendicular of the caudal segment 24 -> 2, exactly as
  1-9 is on the head segment and 3-4 and 10-11 are on the mid segment. The five
  perpendicular pairs are now declared in one place (`PERP_PAIRS`) and imposed
  by one function (`enforce_perp()`), so a convention cannot hold for one pair
  and not for another.
* The conventions are re-imposed when the FRAME changes, not only when a point
  moves. Clicking LM2 or a hinge triggers a re-seed, and a re-seed KEEPS every
  hand-placed landmark -- which is how hand-placed caudal points survived under
  an axis they no longer matched. `apply_conventions()` now squares the whole
  battery, so the re-seed and the "pin" prediction path are covered too.
* The FISHMORPH geometry check displays the caudal pairs against the same
  criterion (deviation from the perpendicular to 24 -> 2, tolerance 8 degrees)
  instead of the mutual-parallelism test it used before.
* **This changes measurements.** Specimens digitized before this version may
  carry caudal depths taken off the perpendicular; re-open and re-save them if
  CPd or CFd matter to the analysis.

# intraitR 1.18.1

## The overlay stops hiding the specimen

* `digitize_landmarks()`: every overlay drawn on the photograph is now thin,
  black and dashed instead of thick and saturated. The point of the canvas is
  the fish, and an operator who cannot see the fin ray cannot place the landmark
  on it -- ink spent on the guides is ink taken from the evidence.
* Concretely: the active landmark is a thin black ring (`cex` 3 -> 1.6, `lwd`
  3 -> 1) rather than a heavy green disc; landmark discs go from `cex` 1.2 to
  0.7 with smaller labels; the cyan outline, the gold broken axis, the yellow
  alignment guides and the scale bar are thin translucent black dashes.
* The FISHMORPH geometry check now treats **compliance as the silent state**: a
  compliant segment is a faint black dash, only a violation is drawn loudly in
  orange. Attention is spent on what needs fixing rather than on what is already
  right, which is the reverse of the previous behaviour (green everywhere).
* No measurement, landmark or export changes -- rendering only.

# intraitR 1.18.0

## LM23, the derived head base -- and the FISHMORPH numbering

* The scheme gains **LM23, the head-base point**, derived exactly as in
  Rfishmorph and in the published FISHMORPH database: the intersection of the
  line (1, 9) -- the mouth-height line -- with the line through LM6 parallel to
  the head axis (1 -> 22). Segment 23-6 is therefore parallel to that axis, and
  1 -> 23 is the axial distance from the snout to the base of the head.
* The numbering follows FISHMORPH from now on: **22** curvature point, **23**
  derived head base, **24** and **25** entry hinges (they were 23 and 24). The
  alignment is the point of the change -- landmark tables travel between
  intraitR and Rfishmorph, and a "23" meaning the head base in one and an entry
  hinge in the other is the kind of divergence that produces two incomparable
  corpora without anyone noticing.
* LM23 is COMPUTED, never clicked: it is rebuilt after every move of LM1, LM6,
  LM9 or the axis, after every re-seed, prediction and propagation, so it cannot
  drift out of step with the landmarks it comes from. A click on it is refused
  with the reason rather than silently undone. It stays empty when the
  construction is degenerate (LM1 and LM9 coincident, or the two directions
  parallel): a derived point with a degenerate input has no value, and inventing
  one would be worse than leaving it empty.
* The coincident-landmark rules take it into account. `Mo = 0` now moves LM9
  **and LM23** onto LM1 -- which is also what saves LM23 from the degeneracy it
  would otherwise fall into. `LM6 = LM8` moves LM6 onto LM8 **and LM23 onto
  LM9**: a consequence, not an extra convention, since the belly line is
  parallel to the head axis, so once LM6 sits on it the parallel through LM6 IS
  the belly line and its intersection with (1, 9) is LM9. Checked numerically,
  tilted photograph included.
* Consequences on the schema: `SAVE_PTS` is now `1:23` (the landmarks proper,
  the derived point included) and the workbook carries `1_X ... 25_Y`, 50
  coordinate columns. Read a configuration back with `n_landmarks = 23`, not 22;
  `consolidate_landmarks()` defaults to `points = 1:25`. The auto-advance runs
  `1, 22, 24, 2, ...`, and the landmark bar shows LM23 in the "never clicked"
  group with the derived ventral points.
* No data migration was needed: nothing had ever been recorded under the old
  23/24, which were the entry hinges and had never been placed in any workbook
  or journal. This was verified before the renumbering rather than assumed.

# intraitR 1.17.0

## Coincident landmarks: a measurement of zero

* A bar under the photograph declares the segments that are ZERO on the
  specimen in view. A zero is a measurement like any other -- neither a missing
  value nor a placement error -- and the FISHMORPH ratios are defined to take
  it: `OGp = 0` for a mouth opening on the ventral profile, `PFv = 0` for a
  pectoral fin inserted on the belly. Four rules: **`Mo = 0`** (LM9 takes the
  coordinates of LM1), **`LM6 = LM8`** (the bottom of the head is the body
  underside), **`PFi = 0`** (LM10 takes the coordinates of LM11) and
  **`LM5 = LM13`** (an eye reaching the top of the head).
* **Nothing is deleted.** Both landmarks keep a position, both are drawn on the
  photograph and both are written to the workbook; one simply takes the
  coordinates of the other, so the segment between them measures zero. A
  coincidence is a measurement, an absence is `NA`, and the two must not be
  confused downstream.
* Clicking two landmarks onto the same pixel expresses the same thing but does
  not SURVIVE: the conventions re-derive the ventral points on the belly line
  and `enforce_head_order()` re-separates the eye group by its margin, so the
  zero was undone at the next click. A declared rule is re-applied after every
  propagation, every re-seed and every prediction -- which is what makes a zero
  a stable statement about the fish rather than a position that drifts.
* Which landmark moves is a protocol decision and is not the same for every
  rule. For the mouth the fixed point is LM1, the snout, which must not move.
  For the two ventral rules the BELLY LINE holds: LM8 and LM11 are its
  intersections with the eye and the pectoral verticals, so the head bottom and
  the fin insertion come onto them -- a global fit is steadier than a single
  click. For the eye at the top of the head, LM5 comes onto LM13, since moving
  LM13 would change `Ed`, a measurement in its own right.
* Landmarks moved by a rule are exported with status `"adjusted"`, whose meaning
  widens accordingly: placed by a rule the operator invoked, neither pointed at
  by hand nor left at a seed.
* Declarations are reset for every specimen, and read back from the coordinates
  when one is reopened in the `"correct"` queue: two coincident landmarks
  re-tick their box, so a zero saved yesterday is still visibly a zero today.

## The eye vertical is checked, in order

* The save-time check of `digitize_landmarks()` now also verifies the ORDER of
  the six landmarks the FISHMORPH conventions put on one vertical -- 5, 13, 7,
  14, 6, 8, read from the back downwards: top of the head, top of the eye,
  centre of the eye, bottom of the eye, bottom of the head, body underside. Two
  things are tested and they are not the same statement: that **LM5 tops the
  group** (the `Hd` analogue of the LM3/LM4 rule for `Bd`), and that **every
  consecutive pair is in order**, which catches a local swap the first cannot
  see.
* This is the failure no other check catches, because each pair stays
  internally consistent: with 13 and 14 exchanged -- the eye clicked
  bottom-first -- `Ed` (13-14) keeps its exact length while `Eh` (7-8) silently
  measures to the wrong edge of the eye. Neither a coordinate table nor a
  Procrustes fit shows it.
* Settled on the data, like the extreme-point rule. The expected order already
  holds for **98.6 %** of the 1,036 digitized T-26 configurations (13 above 5 in
  9 specimens, 0.87 %, the same nine as "LM5 does not top the group"; 7 above 13
  in 4; 14 above 7 in 1; 8 above 6 in 1) and for **100 %** of the 250
  repeatability configurations. An order a hand-digitized corpus already
  satisfies to that degree is a convention, not a preference.
* An inversion is reported but **never auto-corrected**: moving a landmark to
  satisfy the order would invent a measurement rather than repair one. The
  dialog offers *Measure again* -- which selects the landmark found on the wrong
  side, not the reference it was compared with -- and *Save without correcting*;
  *Auto-correct* only appears when there is an extreme-point violation, the only
  kind a snap can repair.
* Same tolerance as the extremes, `max(5 px, 0.003 * Bl)`, and the same
  invariances: heights are read perpendicular to the body axis, segment by
  segment on a curved specimen, and the dorsal side from the relative position
  of LM3 and LM4 -- so the test holds head left or right, photograph flipped or
  mirrored. A landmark left out is stepped over rather than breaking the chain.
* New internals `eye_order_violations()` and `convention_violations()` in the
  bundled app; the violation tables gain a `kind` column (`"extreme"` /
  `"order"`).

# intraitR 1.16.0

## `digitize_landmarks()` is now a console-declared session

* The whole session is declared **at the console** and nothing about it can be
  changed by hand once the app is open: `photo_dir`, `xlsx_path`, `journal_dir`,
  `operator`, `mode`, `n_repeats`, `xlsx_flush_every`. The folder text box, the
  single-photograph upload and the CSV re-import are gone with it. A digitizing
  session is a piece of a protocol, not a set of choices to re-make every
  morning: written down in a script it is reproducible, and it stops being one
  of the things that can silently differ between two operators.

```r
digitize_landmarks(
  photo_dir        = "T26/photos",
  xlsx_path        = "T26/T26_landmarks.xlsx",
  journal_dir      = "T26/landmark_journal",   # default
  operator         = "AT",
  xlsx_flush_every = 10,
  mode             = "new")
```

* The **entry hinges 23 and 24 are now recorded** (`23_X ... 24_Y`), in the
  workbook and in the journal. They are not landmarks and belong in no shape
  analysis -- `n_landmarks = 22` still reads a configuration, and the TPS export
  still contains 22 points -- but they define the frames every FISHMORPH
  convention was applied in. Without them, a specimen reopened for correction
  came back with a straight axis, and its geometry silently stopped matching the
  one it had been digitized under. `consolidate_landmarks()` now defaults to
  `points = 1:24` accordingly.
* **One workbook, three sheets.** `measurements` (one row per specimen) and
  `bias` (one row per repeated digitization, with `individual`, `operator` and
  `replicate` columns) share the wide FISHMORPH layout `1_X, 1_Y, ... 22_X,
  22_Y`, read back by `read_landmarks_xlsx(x_pattern = "{i}_X", y_pattern =
  "{i}_Y")`. `bias_summary` is recomputed at every write: per individual and per
  landmark, the median distance of the repeats to their own mean position, in
  pixels and as a percentage of standard length, plus a per-landmark overview
  across individuals. It says which points the protocol places reproducibly
  while the session is still open, rather than a month later.
* **Three queues**, switchable from the action bar: `new` (photographs absent
  from the workbook), `correct` (specimens already digitized, whose points are
  reloaded onto the photograph for review -- this replaces the old CSV
  re-import) and `repeat` (the same photograph, blind, until the individual has
  its complement of repeats).

## An append-only journal behind the workbook

* Every save is written FIRST to a session journal
  (`landmarks_<operator>_<timestamp>.tsv`, one immutable line per landmark,
  never rewritten), and only then to the in-memory sheets; the workbook itself
  is rewritten in full every `xlsx_flush_every` records and **atomically**
  (temporary file, then rename, keeping one generation as `.prev.xlsx`). The
  previous design rewrote a single table on every specimen, in a cloud-synced
  folder: a crash, a sync lock or a power cut during that rewrite could cost the
  whole file rather than the last specimen. The volume was never the problem;
  the write pattern was.
* New exported functions `landmark_journal_open()`, `landmark_journal_append()`,
  `landmark_journal_read()`, `consolidate_landmarks()` and
  `write_xlsx_atomic()`. `consolidate_landmarks()` rebuilds the wide sheets from
  the journals -- keeping the last record per specimen, or every record with
  `history = TRUE`, which makes each correction auditable -- and can write the
  workbook itself. It is the recovery path, and the app exposes it as a button.
* A line truncated mid-write is detected and dropped on read; journals from two
  workstations merge by plain concatenation; a journal written by an earlier
  version is filled with `NA` rather than refused.

## A tabbed, themed interface

* The side panel is a **tabset** -- `Specimen`, `Repeats`, `Display`, `Checks`,
  `Seed` -- instead of one long scroll. The controls fall into groups touched at
  different rhythms (once per specimen, once per batch, once per session), and
  stacking them in one column put the ones used constantly below the ones used
  never.
* With `bslib` (new, in `Suggests`) the app uses a Bootstrap 5 theme, cards and
  a wider sidebar; without it, the same content falls back to the standard Shiny
  layout. No feature depends on `bslib`, only the appearance does.
* The header strip shows what the session IS -- photograph folder, workbook,
  journal, operator -- since those are declared at the console and are no longer
  editable. The `Repeats` tab shows the running per-landmark bias table.

## Breaking changes

* `digitize_landmarks()` now requires `photo_dir`; `autosave` is gone (the
  workbook and the journal replace the CSV autosave), and `mlmorph_dir`,
  `predictor` and `python` are still available but are no longer the first
  arguments.
* `writexl` is required by `digitize_landmarks()` (it writes the workbook), and
  `readxl` as soon as an existing workbook is resumed from. Both were already in
  `Suggests`.

# intraitR 1.15.0

## Repeated digitization in the landmarking app

* The `digitize_landmarks()` app gains a **`Session type`** selector. Alongside
  `New photographs` -- the previous behaviour, unchanged and still the default
  -- a `Repeats (measurement error / operator bias)` mode keeps "Save & next" on
  the **same photograph** and saves each pass separately, until the individual
  carries the number of repeats asked for. This is what turns a digitization
  batch into an estimate of its own technical variance, which
  `measurement_error()` and `operator_disagreement()` need and which no amount
  of care in a single pass can supply.
* Each pass is written under `"<code>_rep<N>"`, or `"<code>_<operator>_rep<N>"`
  when the optional operator field is filled -- the convention already carried
  by the T-26 repeatability set. The replicate number is always the last
  underscore-separated token and the operator label is stripped of underscores,
  so identifiers decompose unambiguously from the right. The exported CSV schema
  is unchanged.
* Repeats are **blind by default**: the configuration is cleared after each
  save, so the next pass starts from the snout. A pass resumed from the one just
  saved measures the operator's reluctance to revise their own points rather
  than the precision of the protocol, and drives `%ME` towards zero. The box can
  be unticked, with a standing warning on screen that the repeats are then not
  independent.
* Progress, the `Skip` action and the saved-table summary now count
  **individuals** rather than rows: an individual is done once it has its full
  complement of repeats, and reopening a photograph half-way through its series
  continues it instead of overwriting it.

## Replicated identifiers read back by the importer

* `read_mlmorph_landmarks()` gains `replicate = "parse"` and
  `operator = "parse"`, which decompose `"<individual>[_<operator>]_rep<N>"`
  identifiers into `metadata$individual`, `metadata$operator` and
  `metadata$replicate` -- the grouping `measurement_error()`
  (`method = "procrustes"`) and `operator_disagreement()` expect. Parsing is
  never silent: `"fish_rep2"` is a valid individual name, so the decomposition
  must be asked for. Identifiers without a suffix keep `replicate = 1`, so a
  table mixing single and repeated digitizations imports in one pass. The
  defaults (`replicate = 1L`, `operator = "ml_morph"`) are unchanged.

# intraitR 1.14.0

## Extreme-point convention checked on save

* The `digitize_landmarks()` app now verifies, when "Save & next" is pressed,
  that **LM3 is the most dorsal and LM4 the most ventral** landmark of the body
  outline -- the definition of `Bd` as the maximum body depth. Nothing is
  written until the specimen passes or the operator decides. A dialog offers
  three routes: **measure again** (the offending landmark becomes active and the
  view centres on it), **auto-correct** (LM3, resp. LM4, takes the height of the
  point overshooting it while keeping its position along the axis, so `Bd` grows
  and the 3-4 perpendicularity is preserved), or **save without correcting**.
  Toggled by the new "Check LM3 / LM4 (extremes) on save" box, on by default.
* Heights are perpendicular coordinates read **in each point's own body
  segment** (the frames `propagate_conventions()` already uses), so a specimen
  photographed bent or tilted is not flagged for its posture, and the dorsal
  side is inferred from the relative position of LM3 and LM4 rather than from
  the image -- the test holds head left or right, photograph flipped, "Flip
  dorsal / ventral" ticked.
* Excluded from the comparison: the caudal peduncle and fin (16-19), outside the
  outline by definition; the appendage tips (12, 15); and the **derived ventral
  points 8, 9 and 11**, which are computed from LM4 itself, so testing LM4
  against them is circular. That last exclusion was settled on the data: over
  the 1,036 digitized T-26 specimens, including 8/9/11 flags 20.6% of the batch
  (198 of 213 flags are those three points, median overshoot 0.5% of `Bl` --
  belly-line noise); excluding them flags 1.5%, median overshoot 6.8% of `Bl`,
  and the rate is flat from 0.003 to 0.02 `Bl`, so what remains is gross error
  cleanly separated from noise.
* Tolerance is `max(5 px, 0.003 * Bl)`. The absolute floor matters on small
  photographs, where the relative term falls below click noise; it costs no
  detection, since compliant T-26 specimens top out at -0.4 px of overshoot
  (p98) while the smallest real breach is 11.8 px.
* New export status **`"adjusted"`** for landmarks moved by that correction,
  distinct from `"clicked"`: an auto-corrected `Bd` stays auditable in the
  measurement table, is counted on the status line and in the save message, and
  the landmark shows mauve in the numbered bar.

# intraitR 1.13.0

## The landmarking app rewritten around the operator

The Shiny application behind `digitize_landmarks()` has been rebuilt along the
lines of the FISHMORPH digitizer, and its interface and comments are now
entirely in English.

* **Active-landmark model, from the first click.** The separate "calibration
  clicks" list is gone: a coordinate matrix exists as soon as a photograph is
  loaded, so the numbered bar is usable immediately and any landmark can be
  selected and placed at any moment. The calibration points are simply the
  landmarks the predictor needs. Previously the bar only appeared *after*
  `Predict`, which left the first five clicks with no way to revisit a
  mis-placed point except starting over, and made the scale bar and the
  curvature point unreachable until the model had run. A prediction now also
  preserves the points already placed instead of replacing the whole matrix.
* One point is active at a time; a click places it and the selection advances.
  The numbered button bar
  doubles as a status display: active, placed by hand, marked `NA`, automatic
  or derived, hinge, scale bar, and *not yet placed* are now distinguishable at
  a glance. An unreviewed point is therefore visible **before** it is exported
  rather than after — which is the whole point of the change.
* **One auto-advance sequence**, printed in the help from its own definition so
  the two cannot drift apart:

      1 > 22 > 23 > 2 > 3 ... 19 > 20 > 21

  The axis first and complete, then the anatomical landmarks in numeric order,
  then the scale bar. The only numbers skipped are the derived points 8, 9 and
  11 — stopping on them would invite a click that the next derivation
  immediately undoes — and LM24, the spare hinge; both stay reachable from the
  button bar, which is laid out in the same order. Hinges are ordinary stops in
  that sequence — a special case that skipped them left the selection stuck on
  LM22.
* **Placing by hand is the default, not a mode.** The seed fires the moment LM2
  goes down, so from there the work is repositioning; there is no button to
  press to get into that state and no calibration/review phase distinction
  left. `Predict` stays available throughout as an optional accelerator over
  the seeded configuration, rather than a step to get past first — which also
  means the app is fully usable with no trained predictor at all.
* **One action bar above the photograph**, as in the FISHMORPH digitizer:
  Previous / Next, Mark NA, Clear point, Save & next, Skip, Write the table and
  the jump-to-photograph field, all on one row where the eye already is. These
  used to be split between the side panel and a phase-dependent block, which
  meant a trip across the window for actions taken once per specimen. Only the
  editing *modes* (move the block, auto constraints) stay below, since they
  change how the next click is interpreted.
* `Skip` advances to the next photograph **not yet saved**, wrapping round to
  earlier gaps, rather than simply the next one — which is what skipping is for
  in a batch, and is what distinguishes it from `Next`.
* The bar is laid out as in the FISHMORPH digitizer, and in the same order as
  the auto-advance: the broken axis first (1, 22, 23, 2), then the anatomical
  points, then the derived points, the spare hinge and the scale bar.
* **Per-point provenance.** The exported table gains a `status` column
  (`"clicked"`, `"predicted"`, `"derived"`, `"na"`, `"missing"`).
  `"predicted"` flags a landmark still sitting exactly where the model put it,
  never verified by eye; the count is shown on screen and repeated when a
  specimen is saved. A coordinate table cannot carry this distinction, and
  without it a measurement and a plausible guess are indistinguishable
  downstream.

## The configuration is seeded, not placed point by point

* The calibration sequence is now the **axis, complete and first**: 1, 22, 23, 2
  (the hinges on the bends; anywhere on the midline if the fish is straight).
  Every convention downstream is expressed in the frame of a body segment, so
  defining the axis last meant seeding everything against the wrong reference.
* As soon as that axis is placed, **every remaining landmark is dropped onto the
  median FISHMORPH proportion** of the body (medians of segment/`Bl` over 6,492
  to 7,706 species) and the conventions are applied, so the operator repositions
  points instead of placing them one by one on a bare photograph. Sliders expose
  what the ratios do not fix — position along the body, dorsal/ventral split,
  fin and jaw angles — and a dorsal/ventral switch. **A point moved by hand is
  never re-seeded.**
* New per-point status `"seeded"`, distinct from `"predicted"`: a seeded point
  was measured on *no* specimen, which is worse than one the model guessed from
  this image. Both are reported on screen and again when a specimen is saved,
  and seeded points are amber in the button bar.

## Broken axis for curved specimens

* The FISHMORPH conventions are defined against the antero-posterior axis, so a
  fish photographed with a bent body had all of them misstated at once by a
  single straight axis 1-2. Hinge points now break the axis into up to four
  segments and each convention is applied in the frame of the segment it
  belongs to: head on 1-22, body depth and pectoral fin on 22-23, caudal
  peduncle and fin on 23-2.
* Fixed an ordering fault in the derivation of the ventral points 8, 9 and 11:
  their abscissas were set *after* their heights had been propagated, and since
  moving a point changes its coordinate in the other segment's frame, this
  pulled 8 and 9 off the belly line — by 9.8 px on a fish bent 35 degrees.
  Abscissas are now fixed first; the residual is at machine precision up to at
  least 55 degrees of bend.
* Landmark **22 is exported** — `fishmorph_segments()` already used it to split
  the standard length into (1-22) + (22-2) — while 23 and 24 are entry aids and
  are never written out. Placing no hinge reproduces the previous straight-axis
  behaviour exactly, so nothing changes for straight specimens.

## Large photographs no longer make the app unusable

Field photographs are routinely 12 to 24 Mpx, and the plot redraws on *every*
click, slider and checkbox. Three changes, none of which touch the coordinates
— landmarks stay in original-pixel space, so nothing downstream is affected:

* The image is **downsampled once at load and the full-resolution array is
  dropped**. A `Display` selector above the photograph offers 800 / 1200 /
  1600 / 2400 px or full resolution; 1200 px is the default. The predictor
  still receives the file itself, at full resolution.
* The display bitmap is **converted to a raster once**, instead of handing
  `rasterImage()` a numeric array that it re-converts to colours on every
  redraw.
* **Only the visible crop is drawn** when zoomed, rather than rasterizing the
  whole bitmap and letting the device clip it: 8.8 % of the pixels at 3.4x,
  1.8 % at 7.6x. The crop arithmetic was checked against the full-image draw
  over 105 view windows — the sub-image lands on exactly the same coordinates
  and always covers the view.

Zoom moved to a bar directly above the photograph: at high magnification the
operator alternates between placing a point and re-framing, and a trip to the
side panel between the two breaks that loop. The seed sliders moved to the
bottom of the side panel, being set once per batch and then left alone.

## Robustness and quality control

* **Images are routed by their magic bytes, not their file extension.** A
  sizeable minority of `.jpg` files in specimen archives are in fact `PNG`,
  `GIF` or `BMP`; these used to fail outright and now open through `magick`
  (added to `Suggests`; a message on start-up says so when it is missing).
* **Flipping a photograph remaps the points already placed** instead of
  discarding them, and a separate display-only flip mirrors the image while
  leaving the coordinates untouched — for the case where a reloaded table is
  mirrored relative to its photograph.
* **On-screen control table** of the eleven FISHMORPH segments as digitized: in
  pixels, as a ratio to the standard length (comparable across specimens, which
  raw pixels are not) and, once the scale bar is placed, in millimetres. `Bl` is
  measured along the broken axis.
* **Reference lines** (body outline, belly line, eye vertical, eye circle,
  broken axis) drawn over the photograph, alongside the existing FISHMORPH
  geometry check, which is now evaluated segment by segment.
* Jump straight to a photograph by name (server-side `selectize`), notifications
  on every state change, zoom centred on the active landmark, and a "Clear this
  point" action distinct from "Mark NA" — *not placed* and *not measurable* are
  different claims and no longer collapse into the same `NA`.

# intraitR 1.12.0

## Phylogenetic imputation now works on precomputed eigenvalues

* New `load_fishmorph_phylo_axes()`: reads
  `inst/extdata/Phylogeny/pcoaPhylogenyFish.rds`, the **precomputed** PCoA axes
  of the bundled fish phylogeny (8,970 species, 10 axes), cached once per R
  session. Shipped as a compressed `.rds` (540 kB); the loader also accepts the
  whitespace-separated text format, dispatching on the file extension.
* Every `"missforest_phylo"` option — in `trait_space()`, `fishmorph_segments()`,
  `fishmorph_ratios()` and `impute_landmarks()` — now uses that table by default
  instead of eigendecomposing the patristic distance matrix on every call.
  Beyond the cost (that matrix is *n* × *n*, and the decomposition cubic in *n*),
  this fixes a **comparability** problem: axes recomputed on whichever species
  happened to be present defined a different coordinate system for each
  analysis, so two imputations on two subsets did not live in the same
  phylogenetic space. A `phylo_axes` argument accepts an alternative table;
  passing `tree` still recomputes from that tree, as before.
* The imputation message now names the **source** of the axes, so two runs can be
  told apart.

## `species` is now separate from `groups`

* `trait_space()`, `fishmorph_segments()`, `fishmorph_ratios()` and
  `impute_landmarks()` gain a `species` argument. The two roles were conflated
  under `groups`, so `"missforest_phylo"` refused to work without a grouping
  vector — yet the phylogeny only needs to know which species each row belongs
  to, not a categorical predictor for the forest.
* `species` is auto-detected (a `species` / `Species` / `Genus.species` column,
  the metadata, or the specimen names). **`groups` is no longer auto-filled with
  species**, except for `"impute_group_mean"`, where the species genuinely is the
  group.
* A `groups` factor with more than 53 levels is now dropped from the missForest
  predictors with a warning instead of failing: `randomForest` cannot handle more
  than 53 categories, so auto-filling `groups` with thousands of species names
  would have made the imputation error out.
* Row subsets (`na_action = "omit"`, dropping rows with an unresolved group) now
  carry `species` along, so the phylogenetic axes cannot end up attached to the
  wrong specimens.

# intraitR 1.11.0

* `digitize_landmarks()` has been re-implemented as a launcher for the bundled
  ml-morph landmarking Shiny application, replacing the former point-and-click
  wrapper around `geomorph::digitize2d()`. Instead of digitizing every landmark
  by hand, the user loads a photograph (or a folder of photographs), places a
  few calibration clicks, and a trained ml-morph shape predictor proposes the
  19 anatomical FISHMORPH landmarks for review, correction, quality scoring and
  export to `CSV`/`tpsDig` (import the result with `read_mlmorph_landmarks()`).
  The Shiny app now ships inside the package
  (`inst/shiny/landmarking_app/`) together with its Python worker
  (`inst/mlmorph/`); the heavier ml-morph assets (trained predictor, aligned
  dataset, `dlib`-enabled Python environment) remain external and are located
  through the new `mlmorph_dir`, `predictor` and `python` arguments (with
  auto-detection from the working directory and `INTRAITR_MLMORPH_*`
  environment variables). The former `images`, `scheme`, `n_landmarks`,
  `curvature` and `tpsfile` arguments are removed. `shiny` is a new Suggested
  dependency, and `geomorph::digitize2d()` is no longer imported.

# intraitR 1.10.0

* `fishmorph_ratios()` gains an `MBw` argument (`FALSE` by default). When
  `TRUE`, it adds a maximum body weight (`MBw`) column derived from the
  supplied `MBl` through the species-level allometric length-weight
  relationship `W = a * MBl^b`, whose coefficients `a` and `b` are looked up
  in FishBase with `rfishbase::length_weight()` (per species, the study with
  the highest coefficient of determination, selected in base R). Species
  names are taken from `groups` or a `species` column in `segments`; species
  without usable FishBase coefficients yield `NA`, with a warning. The new
  `MBw` column is placed immediately after `MBl`, and is subset consistently
  under `na_action = "omit"`. `rfishbase` is a Suggested dependency, loaded
  only when `MBw = TRUE`.

# intraitR 1.9.0

* New `plot_fishmorph_density()` draws, for a `project_fishmorph()`
  projection, a panel of kernel-density curves per functional axis and per
  morphological ratio, comparing the whole FISHMORPH reference database (a
  filled grey curve) with each focal species (a coloured, translucently filled
  curve, using the same session-stable colours as the ordination). Each curve
  is rescaled to a percentage of its own maximum (peak = 100%) and drawn on a
  shared 0-100% axis, so species with very different spreads or sample sizes
  stay directly comparable in position and width rather than in raw height.
  Axis panels use the projected PCA scores; ratio panels use the trait values
  on the analysis (log) scale, so the reference and species curves are always
  directly comparable. Arguments select which axes/ratios and which
  species/specimens to show, and control the reference fill, the per-species
  translucent fill (`species_fill`, `species_fill_alpha`), rug, legend and
  panel grid. To support the ratio panels,
  `project_fishmorph()` now also stores the full reference trait matrix
  (analysis scale) as `reference_traits` in its returned object (older
  projections without it are handled by exact reconstruction from the frozen
  PCA).

* `plot.intrait_fishmorph_projection()` gains an `arrows` argument (with
  `arrow_scale` and `arrow_col`) that overlays the PCA trait loadings
  (`x$loadings`) on the FISHMORPH functional space as biplot arrows -- one per
  trait, drawn from the origin along its loading on the two plotted axes and
  labelled with the trait name -- so a reader can see which morphological
  ratios drive each axis. The loadings are unit-scaled direction vectors with
  no natural length in score units, so they are rescaled to the current plot:
  the longest arrow reaches `arrow_scale` (default `0.8`) of the distance from
  the origin to the nearest plot edge, all arrows sharing that one factor so
  their relative lengths and directions are preserved. The overlay is purely
  visual and does not change the ordination. Works with every `style` and
  composes with the reference background and `itv_reference` layers.

# intraitR 1.8.0

* `itv_proportion()` gains a `metric` argument selecting how the multivariate
  functional-volume proportion is measured:
  - `metric = "hull"` (default, unchanged): the convex-hull volume ratio
    (Villeger, Mason & Mouillot, 2008) -- an *extent*-based richness driven by
    the outermost specimens.
  - `metric = "tpd"`: a *density*-based richness, the Trait Probability
    Density FRichness (Carmona et al. 2016, 2019), via `TPD::TPDs()`/`TPDc()`/
    `REND()`. A kernel density is estimated from the individuals and the
    proportion is the volume of trait space it occupies above a `tpd_alpha`
    density threshold, so sparse outliers are down-weighted instead of
    stretching the volume as they do under a convex hull. Every unit (the
    reference, the pooled focal set, each species) is evaluated on the same
    fixed grid, keeping the volumes comparable; it typically returns a
    smaller, more conservative proportion than the hull for a
    centrally-clustered focal set. New arguments `tpd_alpha` (default `0.99`)
    and `tpd_n_divisions` (default `NULL`, auto-scaled with `volume_dims`)
    tune the density threshold and grid resolution. Requires the Suggested
    'TPD' package.
* The `"intrait_itv_proportion"` object now records the metric used (`$metric`)
  and a `$volume_scale` note; its `print()` method labels the volume as
  "convex hull" or "TPD FRichness" accordingly. The per-trait (range)
  proportions are identical under either metric.

# intraitR 1.7.0

* New `itv_proportion()`: quantifies how much of the global functional
  diversity of the reference database a group's projected intraspecific trait
  variation (ITV) occupies, from a `project_fishmorph()` projection, along two
  decompositions -- **per trait** (univariate range ratio: focal ITV range
  divided by the whole-reference range, on the analysis scale) and **per
  functional volume** (multivariate convex-hull volume ratio in the
  `volume_dims` leading principal components, Villeger, Mason & Mouillot,
  2008). Both are reported pooled over all focal specimens and per species.
  Returns an `"intrait_itv_proportion"` object with a dedicated `print()`
  method.
* `project_fishmorph()` gains a `volume_dims` argument (default `2L`) and now
  bundles the ITV proportion in its result as `$itv_proportion` (an
  `"intrait_itv_proportion"` object). The returned projection additionally
  stores `scores_all`/`global_scores_all` (scores on all components),
  `specimen_traits` (transformed specimen traits) and
  `trait_ranges_reference` (per-trait reference envelope) so the proportion
  can be recomputed on a different number of axes. Its `print()` method now
  reports the pooled ITV-to-global volume and trait-range proportions.
* The convex-hull volume uses the Suggested `geometry` package; when it is not
  installed the volume proportions degrade to `NA` (never an error), while the
  per-trait proportions are always available.

# intraitR 1.6.0

* `plot.intrait_fishmorph_projection()` now renders the FISHMORPH reference
  database as a **kernel-density heatmap** by default (a white-to-red
  gradient with nested highest-density-region contour lines), instead of an
  unreadably dense ~9,000-point cloud. New arguments control the background
  and overlays:
  - `reference_density` (default `TRUE`): draw the reference distribution as
    the density heatmap. `density_probs` and `density_palette` tune its
    contour probabilities and colour ramp.
  - `reference_points` (default `FALSE`): draw the reference species as the
    previous light point cloud (can be combined with the heatmap). This is
    the explicit yes/no toggle for the reference species points; the old
    `background = TRUE` default cloud is now off unless requested.
  - `itv_reference` (default `FALSE`): mark each focal species' *own* entry
    in the FISHMORPH database as a filled circle coloured to match its
    species, so the single database morphotype can be compared with the
    spread of the projected intraspecific trait variation. Matching is
    case-insensitive and treats spaces/underscores as equivalent.
  - `background` remains a master off-switch (`FALSE` suppresses every
    reference layer).
* `project_fishmorph()` now stores `global_species`, the reference species
  labels aligned row-for-row to `global_scores` (from a `"Species"` column
  when present, else the reference row names), used by `itv_reference` above.
* New internal helper `.density_field()` (kernel-density grid + HDR contour
  levels) backing the reference heatmap; `.plot_ordination()` gains
  `background_density`/`background_points`/`highlight` support, shared with
  any ordination that supplies a background cloud.

# intraitR 1.5.0

* New `project_fishmorph()`: builds a **fixed** functional trait space by
  PCA of a reference FISHMORPH database (e.g. the ~9,000-species
  `fishmorph_data.csv`) and projects new specimens -- typically the
  individuals of a few focal species from `fishmorph_ratios()` -- into that
  *same, frozen* space with `stats::predict()`, without re-fitting the
  ordination. This shows how much of the global morphospace a group's
  intraspecific trait variation (ITV) occupies relative to the whole
  diversity of fishes, on axes defined once by the reference alone.
  Arguments `select_species`/`select_specimens` restrict which specimens
  are projected. The published FISHMORPH database ships already
  `log10(x + 1)`-transformed while `fishmorph_ratios()` returns raw ratios;
  the `reference_prelogged`/`specimens_prelogged`/`log_transform` defaults
  encode the correct combination so the two never end up on incompatible
  scales (which would otherwise displace the projected points by a large,
  spurious offset). A `print()` method summarises the space, and a `plot()`
  method draws the reference database as a light background cloud with the
  projected specimens on top, in `style = "hull"` (per-species ITV
  footprint), `"spider"`, `"density"`, or `"points"`.

* `plot.intrait_traitspace()`/`plot.intrait_shapespace()`'s shared internal
  plotting engine gained an optional background point cloud (used by
  `plot.intrait_fishmorph_projection()`); existing plots are unchanged.

# intraitR 1.4.0

* New `operator_disagreement()`: screens a landmark data set in which the
  **same individuals were digitized by several independent operators** (as
  produced by `load_t26_saudrune_landmarks(source = "operators")`) and
  returns, for every individual, a single inter-operator disagreement
  index, an automatic robust "at-risk" flag (median + `threshold`*MAD, the
  same rule as `detect_outliers()`), and -- where identifiable -- the
  operator responsible for the disagreement. It is the population-level,
  one-number-per-individual companion to the by-eye overlay of
  `plot_fishmorph_shapes(..., operator = TRUE)`: instead of paging through
  each fish to spot the ones whose operators drew visibly different shapes,
  it ranks all individuals and names the outlier operator. The magnitude is
  the mean across landmarks of the root-mean-square across-operator
  displacement from the per-landmark consensus, normalised (per individual)
  by centroid size, an inter-landmark reference distance, or standard
  length -- the inter-operator analogue of the intra-operator
  `digitization_error()`. Operator attribution uses a leave-one-out
  consensus of the other operators (identifiable for three or more
  operators); a `reference_operator` argument (e.g. a trusted expert)
  makes attribution identifiable for two-operator individuals as well.
  Returns `by_individual`, `by_operator` (which operator is systematically
  discordant), and `by_landmark` (which anatomical points operators
  disagree on most) tables, with dedicated `print()` and `plot()` methods
  (`type = "individual"`/`"operator"`/`"landmark"`).

# intraitR 1.3.0

* New `read_mlmorph_landmarks()`: imports the long-format measure table
  exported by the **ml-morph** shape predictor or by the interactive
  landmarking Shiny app (columns `specimen`, `landmark`, `X`, `Y`,
  optional `mm_per_px`) directly into an `"intrait_landmarks"` object. It
  carries the per-specimen calibration scale into `metadata$mm_per_px`,
  flags uncalibrated individuals via `metadata$has_scalebar`, and
  optionally joins a specimen-level metadata table (e.g. species
  identifications) by a key column. Wraps `read_landmarks_csv()`.

* `plot()` for `itv_accumulation()` objects gains a `legend` argument.
  With many groups or trait panels the per-panel colour/line-type keys
  overplotted the curves; the default is now `legend = "panel"`, which
  draws a single shared legend in a dedicated cell of the panel grid.
  `legend = "each"` restores the previous per-panel keys and
  `legend = "none"` suppresses them.

* New `fd_accumulation()`: rarefies community **functional diversity
  indices** against intraspecific sampling effort -- the community-level
  companion to `itv_accumulation()`. It draws balanced sub-samples of `n`
  individuals per species, pools them into one assemblage in a fixed trait
  space built exactly as in `trait_space()` (shared PCA machinery, with
  `n_axes`/`var_threshold` axis selection), and recomputes each requested
  index, estimating the effort
  `n*` at which the index stabilises. Functional dispersion (FDis), Rao's
  quadratic entropy and functional richness (FRic) are computed directly;
  functional evenness (FEve) and divergence (FDiv) are delegated to
  `FD::dbFD()` when the Suggested `FD` package is installed. Functional
  richness honours a `method` argument (`"convexhull"`, `"dendrogram"`,
  `"tpd"`, `"hypervolume"`), reusing the same richness engines and tuning
  arguments as `bootstrap_functional_space()`. As in `itv_accumulation()`,
  richness uses the accumulation/asymptote framing (with a guard that
  rejects an implausible extrapolated asymptote) while the
  dispersion/regularity indices use the convergence/precision framing.
  Dedicated `print()` and `plot()` methods; parallelised via `future.apply`.

* `load_t26_saudrune_landmarks(source = "repeatability")` no longer errors
  with "duplicate 'row.names'": the repeatability table reuses per-replicate
  `specimen` ids (e.g. `"T-26-0004_rep1"`) across the two operators that
  redigitised it, so the operator label is now appended to keep every
  digitisation uniquely identified. Dataset documentation updated to the
  current T-26 data (four operators in `"operators"`; two in
  `"repeatability"`).

* New `tpd_dissimilarity()`: intraspecific-variability-aware functional
  dissimilarity between species, computed as `1 - overlap` of their Trait
  Probability Density kernels (Carmona et al., 2016, 2019) via the Suggested
  `TPD` package. Unlike a Euclidean distance between species means, it lets
  within-species spread shape the distances (species whose individuals
  overlap in trait space are treated as functionally closer). Returns a
  species-by-species dissimilarity matrix (with its shared/non-shared
  decomposition) as an `"intrait_tpd_dissim"` object with `print()`,
  `plot()` (a heat map) and `as.dist()` methods, usable directly for
  ordination, clustering, or distance-based diversity indices.

# intraitR 1.2.0

* New `itv_accumulation()`: builds a rarefaction/accumulation curve of
  intraspecific trait variability against the number of individuals
  sampled, and estimates the sample size `n*` at which that variability
  stabilises -- the trait-based analogue of a species accumulation curve.
  For each sub-sample size `n`, `n_perm` sub-samples of `n` individuals are
  drawn without replacement per group and the metric is recomputed. The
  meaning of "stabilises" adapts to the metric: for *dispersion* metrics
  (`"variance"`, the multivariate trace of the trait covariance; `"sd"`;
  `"cv"`) the sample estimator is unbiased, so the expected curve is flat
  and `n*` is a *precision* threshold (smallest `n` at which the resampling
  band's relative half-width stays below `conv_tol`); for the *accumulation*
  metric (`"range"`) the curve genuinely saturates and `n*` is taken at a
  fraction (`asymptote_prop`) of a fitted Michaelis-Menten or negative-
  exponential asymptote. Parallelised via `future.apply` like
  `bootstrap_functional_space()`/`trait_disparity()`, with dedicated
  `print()` and `plot()` methods. For accumulation metrics the `plot()`
  method draws a rarefaction/extrapolation curve: the observed portion
  solid, the fitted saturating model extended in a dashed line beyond the
  sampled range up to `n*` (controllable via `extrapolate`/`xmax`), and the
  fitted asymptote as a horizontal reference. The fitted half-saturation/
  rate parameter is returned as a new `k` column of `$summary`.

# intraitR 1.1.0

* `plot_fishmorph_shapes()` gains per-specimen colouring: `color_by`
  (a metadata column name such as `"operator"`/`"species"`, the special
  value `"specimen"` for one colour per shape, or a grouping vector), the
  `operator = TRUE` shortcut for `color_by = "operator"`, a custom
  `palette`, and a `legend`. To keep overcrowded overlays legible,
  `max_colors` (default `10`) reverts to the single `color` -- with a
  message -- when the requested colouring would need more than that many
  distinct colours.

* `plot()` for `itv_index()` results now draws the mean (multivariate)
  %ITV reference line bold and in colour, and labels it with its value,
  instead of the previous faint dotted grey line.

* **Breaking rename**: `morpho_space()` is now `shape_space()`, and its
  output class `"intrait_morphospace"` is now `"intrait_shapespace"` (with
  the corresponding `print()`/`plot()` methods renamed accordingly). The
  term "morphological space" was ambiguous for what is, specifically, the
  ordination of Procrustes (GPA) shape coordinates; "shape space" names it
  unambiguously. Figure titles now read "Shape space" instead of
  "Morphological space". The linear-ratio function `morpho_ratios()` is
  unchanged, as it concerns classical morphometric ratios rather than the
  shape space.

* New function `exclude_specimens()`: removes one or more known-bad (e.g.
  mismeasured/mis-digitized) specimens from an `"intrait_landmarks"` object
  (as returned by `read_tps()`, `read_landmarks_csv()`,
  `read_landmarks_xlsx()`, or `load_t26_saudrune_landmarks()`) or a raw
  landmark array, right after loading, so every downstream step
  (`fishmorph_segments()`, `gpa_fish()`, `correct_geometry()`, ...) simply
  never sees it -- rather than repeating an ad hoc `dplyr::filter()` on
  derived output (`segments`/`ratios`/`trait_space()`) at every stage of a
  pipeline, which is easy to apply inconsistently and, in the case of a
  typo/formatting mismatch (e.g. a leading zero), can silently filter out
  nothing at all. `coords`, `scale`, and `metadata` are filtered
  consistently by specimen name; any pre-existing per-specimen audit-trail
  attribute (`standardization_log`, `correction_log`, `corrected`,
  `orientation_log`) is filtered the same way, so it never refers to a
  specimen no longer in the data. Every exclusion is recorded, with an
  optional `reason`, in a `$removed_specimens` data.frame that accumulates
  across successive calls (mirroring `gpa_fish()`'s own
  `remove_outliers`/`$removed_outliers`), and is now surfaced by
  `print.intrait_landmarks()`. Explicitly errors, rather than silently
  doing the wrong thing, for an `"intrait_gpa"` object (Procrustes
  alignment is computed jointly across all specimens, so deleting a row
  after the fact does not undo its effect on the consensus shape) or an
  unknown specimen name (a typo no longer just matches, and removes,
  nothing).

* `correct_geometry()`'s pipeline is now also available as two separate
  functions, for workflows that want to inspect or use its value-preserving
  standardization on its own before deciding whether its value-changing
  correction is appropriate: `standardize_geometry()` performs steps 1-3
  only (isotropic rescale, scale-bar repositioning, rotation to a
  horizontal axis anchored at `Y = 0.5`) and, because these are all rigid/
  isotropic transforms, never changes any FISHMORPH segment or ratio
  value; `correct_geometry_conventions()` performs step 4 only (active
  correction of landmarks still violating the five geometric-scatter
  conventions once the axis is horizontal), and does change values, so it
  requires already-standardized input (the output of
  `standardize_geometry()` or `correct_geometry()`). `standardize_geometry()`
  gains an `orient` argument (default `TRUE`) that calls
  `standardize_orientation()` first, internalizing the manual chaining
  earlier versions of this package's documentation already recommended
  (`fish %>% standardize_orientation() %>% standardize_geometry(orient =
  FALSE)` is equivalent to the default `standardize_geometry(fish)`).
  `correct_geometry()` itself is unaffected and remains the same one-call
  pipeline as before, with identical messages, warnings, and numerical
  output (implemented by extracting the shared per-specimen geometry math
  into internal helpers, `.geometry_standardize_one()`/
  `.geometry_correct_one()`, reused by all three functions, so its
  orchestration/messaging code is untouched) -- confirmed equivalent to
  `standardize_geometry(landmarks, ..., orient = FALSE)` followed by
  `correct_geometry_conventions()` (see `test-standardize_geometry.R`'s
  reproduction test).

* `fishmorph_ratios()` gains a `landmarks` argument: the same
  `"intrait_landmarks"` object/array originally passed to
  `fishmorph_segments()`. A missing or zero-length scale bar (landmarks
  20-21) makes every one of `fishmorph_segments()`'s 11 measurements `NA`
  for that specimen, since the pixel-to-centimetre conversion factor is a
  single per-specimen scalar applied to all of them -- which previously
  also made all nine ratios `NA` for that specimen, even when every
  anatomical landmark (1-19) was perfectly digitized. Because a ratio is
  always (segment / segment) computed *within* the same specimen, the
  unknown/missing scale factor cancels out of the division exactly, so
  `landmarks` lets these nine ratios (only -- not the absolute segments,
  nor `MBl`) be recomputed directly from raw pixel-space landmark
  distances instead. Only applied to specimens whose `segments` row is
  entirely `NA` (the missing-scale-bar signature); a specimen with just
  one missing anatomical landmark, or a single `geometry_check`-flagged
  segment, is left untouched, since mixing pixel-space and calibrated
  values for the same specimen would defeat that quality control. New
  internal helper `.fishmorph_pixel_segments()` (`R/utils-internal.R`)
  extracts the shared pixel-distance geometry engine out of
  `fishmorph_segments()` (a pure refactor, no behaviour change there) so
  both functions compute the same 11 raw measurements identically.

* Fixed a bug where the `expect_equal()` reference value in two
  `impute_landmarks()` regression tests (`method = "impute_mean"` and
  `"impute_group_mean"`) was computed from the column/group mean
  *including* the very point about to be deleted and imputed, rather than
  excluding it as `impute_landmarks()` itself does (`mean(x, na.rm =
  TRUE)` computed *after* the value is set to `NA`). This was a test-only
  defect, caught by a real `devtools::test()` run; `impute_landmarks()`'s
  own imputation logic was unaffected.

* Fixed a bug where `trait_space()` could crash with a cryptic
  `Error in while (stopCriterion(...)) : missing value where TRUE/FALSE
  needed` under `na_action = "missforest"` (and could otherwise silently
  corrupt the ordination under any `na_action`) if a trait column
  contained a non-finite value (`Inf`/`-Inf`), typically from a ratio
  with a zero-length denominator segment (e.g. a degenerate or
  duplicated landmark; see `fishmorph_segments()`/`fishmorph_ratios()`).
  `Inf`/`-Inf` are not detected by `is.na()`/`anyNA()`, so such a value
  used to pass straight through every `na_action` unimputed;
  `missForest::missForest()`'s internal convergence check then computed
  `Inf - Inf = NaN`, crashing its `while()` loop. `trait_space()` now
  checks for non-finite trait values unconditionally, before any
  missing-value handling, and stops with an informative error naming the
  offending column(s) and row(s), regardless of `na_action`.

* `bootstrap_functional_space()` gains a `composition` argument: a
  communities x species matrix (presence/absence or abundance; only
  presence is used) giving the species composition of one or more
  communities/sites. When supplied, the same centroid-based-reference-vs-
  bootstrap-distribution principle used for the whole species pool is
  repeated independently for each community, restricted to that
  community's own species, using the same shared PCA space and
  method-specific auxiliary quantities (kernel bandwidth/grid) so results
  stay comparable across communities. Results are returned in a new
  `$communities` data.frame (`community`, `n_species`, `fd_obs`,
  `fd_expected`, `fd_sd`, `ses` -- Standardized Effect Size, `(fd_obs -
  fd_expected) / fd_sd` -- and `p_value`) and a new `$community_boot` list
  of the raw per-community bootstrap vectors, in addition to the unchanged
  whole-pool `fd_ref`/`fd_boot` outputs. `print()` now reports a
  per-community summary when present, and `plot()` gains a `type =
  c("pool", "communities")` argument: `"communities"` draws a dot ("forest")
  plot of `ses` per community, coloured by significance -- chosen over a
  per-community histogram grid (impractical for more than a handful of
  communities) or a raw obs-vs-expected scatter (not directly comparable
  across communities with different species richness, unlike `ses`).
  Species-column matching is defensive against a mismatch between
  `composition`'s column names and `groups`'s species labels: duplicated
  column names now error immediately (rather than silently using the
  first match), and unmatched columns are reported by name, not just by
  count, to make a spelling/case/whitespace mismatch easy to spot. Fixed
  a bug where a genuine `""` species label (e.g. an unresolved/
  unidentified specimen, as can occur in real field data) caused
  `composition[, matched_sp]` to fail with "subscript out of bounds" --
  `[`-indexing never matches a `""`-named column even when one exists
  (see `?Extract`); column selection now goes through `match()` instead
  (the same fix already used in `group_colors()`'s own `""`-label
  handling). `plot(type = "communities")` now always keeps `SES = 0` (the
  dashed reference line and every point's connecting segment) inside the
  plotted x-range, even when every community's `ses` sits far from 0
  relative to their own spread -- previously the x-axis limits were
  computed only from `range(ses)`, which could push 0 off-screen and
  silently truncate the reference line/segments at the plot edge.

* `impute_landmarks()` gains three statistical imputation methods
  alongside the existing geometric-morphometric `"tps"`/`"regression"`:
  `"impute_mean"`, `"impute_group_mean"`, and `"missforest"`, mirroring
  `trait_space()`'s `na_action` options but applied directly to raw
  landmark coordinates rather than derived traits. `"impute_mean"`
  replaces a missing coordinate with its column mean across all
  specimens; `"impute_group_mean"` uses the within-group mean instead
  (new `groups` argument, auto-detected from `landmarks$metadata$species`
  when available; falls back to the overall mean, with a warning, for a
  group entirely missing that coordinate); `"missforest"` uses
  `missForest::missForest()` across all landmark coordinates jointly, with
  `groups` as an optional auxiliary predictor (new `missforest_ntree`/
  `missforest_maxiter` arguments). These treat each coordinate as an
  ordinary numeric variable and ignore shape covariation, so
  `"tps"`/`"regression"` remain preferable whenever enough complete
  specimens are available; the statistical options are meant for
  exploratory use or when too few complete configurations remain for
  `geomorph::estimate.missing()` to work reliably.

* New function `phylo_pcoa()`: derives phylogenetic ordination axes from a
  tree (`ape::drop.tip()` + `ape::cophenetic.phylo()` + `ape::pcoa()`, with
  optional `phytools::force.ultrametric()` coercion and Cailliez/Lingoes
  negative-eigenvalue correction), returning a `species` + `PCoA1..k`
  `data.frame` deliberately shaped to be passed directly as `traits` to
  [trait_space()]. This lets a phylogenetic space be built with the exact
  same ordination/bootstrap machinery already used for morphological trait
  spaces ([bootstrap_functional_space()], [species_sensitivity()]), so
  functional and phylogenetic diversity loss can be compared using the same
  statistics. Deliberately scoped to the generic tree-to-axes step only:
  taxonomic name resolution, tree sourcing, and external trait/occurrence
  data assembly are considered out of scope and are left to the user's own
  data-preparation code. Adds `ape` and `phytools` to `Suggests`.

* New `na_action`/`method` option, `"missforest_phylo"`, added everywhere
  `"missforest"` was already available -- `trait_space()`,
  `fishmorph_segments()`, `fishmorph_ratios()`, and
  `impute_landmarks()` -- augmenting `missForest::missForest()`'s
  predictors with phylogenetic PCoA axes ([phylo_pcoa()]) computed from a
  `tree` (a user-supplied `ape::phylo` object, or, by default, the
  package's own newly bundled `load_fishmorph_phylogeny()` tree), matched
  to each row's `groups` (species) label. This lets imputation borrow
  information from phylogenetically related species, not just from
  correlations among traits/coordinates and the raw species factor, as in
  plain `"missforest"`. Matching is robust to whether species labels use a
  space, underscore, or dot as the genus/species separator (new internal
  `.canon_species_name()` helper), since the bundled tree's tip labels use
  the `"Genus.species"` convention. Phylogenetic augmentation is designed
  to never turn a working `"missforest"` call into a hard error: if no
  `groups`/`tree` is available, fewer than 3 species can be matched to the
  tree, or the `ape` package is missing, `"missforest_phylo"` falls back
  to plain `"missforest"` (no phylogenetic predictors) with an explanatory
  `warning()` rather than stopping. New shared arguments `tree` (default
  `NULL`, meaning "use the bundled phylogeny") and `missforest_phylo_k`
  (default `10`, the number of phylogenetic PCoA axes used as auxiliary
  predictors) added alongside the existing `missforest_ntree`/
  `missforest_maxiter`.

* New function `load_fishmorph_phylogeny()` and bundled data file
  `inst/extdata/Phylogeny/FishMORPH_Phylogeny.rds`: loads the package's
  default phylogenetic tree (an `ape::phylo` object, 10,705 tips) used as
  the default `tree` for `"missforest_phylo"` (above) and available
  directly as input to `phylo_pcoa()`. **Provenance note**: the exact
  source/citation of this tree has not been independently verified in
  this package's documentation; users relying on it for publication
  should confirm and cite its original source themselves (e.g. the
  phylogeny associated with the FISHMORPH trait database, Brosse et al.
  2021) rather than citing `?load_fishmorph_phylogeny`.

* `phylo_pcoa()` bug fix: species-name matching between `species`/`tree`
  only normalised spaces and underscores (`gsub(" ", "_", ...)`), so it
  silently failed to match any species against a tree using dot-separated
  tip labels (`"Genus.species"`), as the newly bundled
  `load_fishmorph_phylogeny()` tree does. Matching now goes through the
  same `.canon_species_name()` helper used by `"missforest_phylo"`
  (above), collapsing runs of spaces, dots, and underscores to a single
  underscore before comparison; matched species are consequently returned
  in this canonical underscore form.

* `correct_geometry()` bug fix: step 1's isotropic rescale to `[0, 1]` left
  an `intrait_landmarks` object's `$scale` element (real-world units per
  digitization pixel, see `read_tps()`) uncorrected, silently making
  `linear_distances()`/`morpho_ratios()` return wrong real-world distances
  from the rescaled coordinates afterwards (the visual, on-screen size of
  every specimen is intentionally equalized by this step, but each
  specimen's true, individual real-world size must still be recoverable
  downstream). `$scale` is now divided by the same per-specimen
  `scale_factor` applied to the coordinates, so real-world distances
  computed before and after `correct_geometry()` are now identical;
  `fishmorph_segments()` was never affected, since it always re-derives its
  own pixel-to-real-world factor fresh from the scale bar's current length
  rather than trusting a stored value. A new `message()` reports how many
  specimens' `$scale` was updated this way.

* `plot_fishmorph_points()`: the digitization scale bar (landmarks 20-21)
  is now drawn as a solid, filled bar with its own border (not two
  triangle point markers, nor a thin open line), placed lower down near
  the plot's origin, with its caption placed directly below it rather
  than above. The caption is now built automatically as `"1 <unit> =
  <length>"` (e.g. `"1 cm = 3.2"`), where `<length>` is that specimen's own
  digitized scale-bar length, rather than the previous fixed `"scale (1
  cm)"` text. The `scale_label` argument is replaced by `scale_unit`
  (default `"cm"`, matching the FISHMORPH protocol's standard 1 cm
  calibration segment), letting users specify the real-world unit a data
  set was actually digitized against (e.g. `"mm"`, `"dm"`, `"m"`, or any
  other label); set `scale_unit = NULL` to omit the caption entirely (the
  bar itself is still drawn). This is a breaking change for any code
  calling `plot_fishmorph_points(..., scale_label = ...)`.

* New `plot_correlation_circle()`: draws the classical correlation circle
  (variable factor map) of a `trait_space()` ordination -- each trait as
  an arrow to its Pearson correlation with the two plotted axes, inside a
  unit circle, with an optional inner circle at radius `sqrt(0.5)`
  marking the conventional "well represented" threshold. Unlike a plot of
  raw `loadings`, arrow length is directly comparable across traits and
  meaningful regardless of `method` (`"pca"`/`"pcoa"`) or `scale`. Drawn
  without a surrounding box: tick values run along the `y = 0`/`x = 0`
  reference lines through the origin, each labelled with its axis name
  only (e.g. `"PC1"`), in a small italic font, just outside the circle
  and centred on its own reference line.

* `bootstrap_functional_space()` gains a `method` argument for the
  functional-richness measure computed in the PCA-based trait space:
  `"convexhull"` (default, unchanged behaviour: n-dimensional convex-hull
  volume via `geometry::convhulln()`), `"dendrogram"` (total branch
  length of a UPGMA functional dendrogram, Petchey & Gaston 2002 -- needs
  no extra Suggested package), `"tpd"` (Trait Probability Density
  richness via the `TPD` package, Carmona et al. 2019), and
  `"hypervolume"` (Gaussian-kernel hypervolume via the `hypervolume`
  package, Blonder et al. 2014, 2018). For `"tpd"`/`"hypervolume"`, the
  kernel bandwidth (and, for `"tpd"`, the evaluation grid) is computed
  once from the full individual-level data and reused, unchanged, for the
  centroid-based reference and every bootstrap draw, so richness values
  stay comparable across draws; new `dendrogram_linkage`, `tpd_alpha`,
  `tpd_bw_factor`, `tpd_n_divisions`, `hv_bw_method`,
  `hv_samples_per_point` arguments tune these. `TPD` and `hypervolume`
  are new Suggested dependencies, only required when their respective
  `method` is used. `print()`/`plot()` methods for
  `"intrait_bootstrap_fspace"` now report which `method` was used.
  `plot.intrait_bootstrap_fspace()` also drops the previous FD_ref
  text annotation above the histogram in favour of marking `fd_ref` (red)
  and the bootstrap mean `fd_boot_mean` (blue) directly on the x-axis,
  each with a matching dashed vertical line.

* `species_sensitivity()` gains the same `method` argument (and matching
  `dendrogram_linkage`/`tpd_*`/`hv_*` tuning arguments) as
  `bootstrap_functional_space()`, for computing the species-level
  sensitivity index with `"convexhull"` (default), `"dendrogram"`,
  `"tpd"`, or `"hypervolume"` functional richness instead of only
  convex-hull volume. `print()`/`plot()` methods report which `method`
  was used.

* New `compare_functional_richness()`: runs `bootstrap_functional_space()`
  once per requested `method` (`"convexhull"`, `"dendrogram"`, `"tpd"`,
  `"hypervolume"`; all four by default) on the same data and tabulates the
  results side by side (`fd_ref`, `fd_boot_mean`, `pct_diff`, `p_value`,
  `significant`), for methodological triangulation across richness
  measures. A method whose package is missing, or that otherwise errors,
  is recorded as a skipped row rather than failing the whole comparison.
  Optional `seed` argument pairs the bootstrap draws across methods. Has
  dedicated `print()` (summary table + agreement count) and `plot()`
  (dot-and-whisker comparison, one row per method) methods.

* Fixed group/species colours not staying consistent between
  `plot.intrait_shapespace()` and `plot.intrait_traitspace()` built from
  the same dataset: colours were previously derived from each call's own
  `nlevels(groups)`/position within its *observed* factor levels, so the
  same species could get a different colour whenever the two objects
  happened to retain a different subset of species after their own
  upstream missing-data or outlier filtering. Colours are now looked up
  by label from a session-persistent cache, so a given species always
  gets the same colour once assigned, regardless of which other species
  are present in a later call. New `reset_group_colors()` clears this
  cache (e.g. before an unrelated dataset, or for full reproducibility
  irrespective of call history).

* New `plot_fishmorph_shapes()`: overlays the landmark points and body
  outline (the same FISHMORPH outline path used by
  `plot_fishmorph_points()`) of every specimen in a given species, or of
  an explicit vector of individuals, on a single figure -- no landmark
  numbers, measurement segments, eye, or internal reference lines -- for
  a fast visual read of shape variability across many specimens at once.
  By default (`align = TRUE`) each specimen is independently centred on
  its own centroid and rescaled to unit centroid size (translation and
  scale only, no rotation) before being drawn, so the overlay compares
  shape rather than raw digitization position/size; set `align = FALSE`
  for already-comparable coordinates (e.g. `gpa_fish()` output). Axis
  tick labels use `grDevices::axisTicks()` (the same "round numbers"
  computation behind R's own default axes) rather than evenly spaced raw
  fractions of the data range, since that range is data-driven here and
  generally not already round -- unlike `plot_fishmorph_points()`'s fixed
  `[0, 1]` convention, whose quarter increments are round by construction.

* Fixed a crash ("attempt to use zero-length variable name") in
  `plot.intrait_shapespace()`/`plot.intrait_traitspace()` whenever a
  group level was an empty string `""` (e.g. an unresolved species
  identification stored as `""` rather than `NA` in the source data): the
  session-level colour cache previously stored one colour per group by
  `assign()`ing an environment variable named after the raw label, which
  errors on `""`. Colours are now stored in a single named vector instead,
  which has no such restriction; `""` is now treated like any other
  distinct label.

* Fixed a follow-on bug from the `""`-label fix above: the colour cache's
  own lookup, `cache[uniq]`, relied on `[`'s character-name matching,
  which R documents as never matching a `""` index to a `""` name even
  when that name is genuinely present (`?Extract`: "Neither empty ('')
  nor NA indices match any names, not even empty nor missing names.").
  A `""`-labelled group was therefore still assigned `NA` instead of its
  cached colour on lookup, even though storage worked correctly. Lookup
  now uses `match()`, which has no such exception.

* New `group_colors()`: returns the exact group/species colours
  `plot.intrait_shapespace()`/`plot.intrait_traitspace()` use (or would
  use), as a `group`/`color` `data.frame`, in the same order as their own
  legend -- for building a single shared legend across several panels
  (e.g. `par(mfrow = c(2, 2))`, each plotted with `legend = FALSE`)
  without reimplementing or guessing at the underlying colour
  assignment. Accepts either an object with a `$groups` element (e.g.
  `shape_space()`/`trait_space()` output) or a raw label vector.

* Fixed a bug in `group_colors()` where passing a list without a
  `$groups` element (anything other than the intended
  `shape_space()`/`trait_space()` output or a raw label vector) silently
  used the list itself as if it were the label vector instead of raising
  the documented "no `groups` element" error.

# intraitR 1.0.0

First stable release. Functionally identical to 0.13.0, promoted to
1.0.0 after the first real (non-static) validation of the package: the
maintainer ran `devtools::test()` on an actual R installation for the
first time in this project's history (every prior version was validated
only by manual code reading, independent Python reimplementation of the
statistical logic, and static analysis, for lack of an R interpreter in
the authoring environment).

Result: **465 tests passed, 0 failures**, 5 expected warnings, and 6
expected skips (all environment-dependent negative-path tests, e.g.
"package already installed, cannot test the missing-package error" or
"cannot run the interactive digitizer non-interactively"). Only one
issue surfaced, and it was in a test, not in the package:

* **Fixed `test-trait_disparity.R`'s regression test** for the
  exactly-2-groups permutation reshape fix (see 0.13.0 below). `%in%`
  binds *tighter* than `/` in R's operator precedence (`?Syntax`), so
  `x %in% ((0:5) + 1) / 6` parsed as `(x %in% ((0:5) + 1)) / 6` instead
  of the intended `x %in% (((0:5) + 1) / 6)` — silently turning the
  assertion into `FALSE / 6 = 0`, which then failed `expect_true()`
  regardless of whether `trait_disparity()` itself was correct. Fixed by
  parenthesising the denominator explicitly. `trait_disparity()`'s own
  logic was not at fault: its other tests, including a real statistical
  power check, already passed under this same test run.

No changes to any exported function's behaviour, arguments, or return
values relative to 0.13.0.

# intraitR 0.13.0

* **`background_image` overlay** for `plot_landmarks()` and
  `plot_fishmorph_points()` (closing the long-pending image-overlay task).
  Both functions gain `background_image` (a path to a `.jpg`/`.jpeg` or
  `.png` photograph of the specimen) and `flip_y` (default `TRUE`)
  arguments: the photograph is drawn as a background layer, sized to its
  full pixel extent, with the digitized landmarks plotted on top, for
  visual quality control (e.g. spotting a landmark placed off the body
  outline). Requires the `jpeg` package for `.jpg`/`.jpeg` files or `png`
  for `.png` files (both newly Suggested, neither installed by default);
  a clear error is raised if the relevant package is missing. `tools`
  (for `tools::file_ext()`, dispatching on the file extension) is now
  declared in `DESCRIPTION`'s `Imports`. Only
  meaningful for the original, un-aligned digitized coordinates: a
  warning is issued if `background_image` is combined with an
  `"intrait_gpa"` (Procrustes-aligned) object, since the photograph will
  not line up with aligned coordinates. New internal helpers
  `.read_background_image()`, `.draw_background_image()`, and
  `.background_image_dims()` in `R/utils-internal.R`.
* **Parallelization**: `bootstrap_functional_space()`,
  `species_sensitivity()`, and `trait_disparity()` now distribute their
  independent resampling loops (bootstrap draws, per-individual
  sensitivity replacements, and label permutations, respectively) across
  worker processes via the (Suggested) `future.apply` package, through a
  new internal `.papply()` helper that falls back to a plain `vapply()`
  when `future.apply` is not installed or no `future::plan()` has been
  set — i.e. purely opt-in, with identical results either way (reproducible
  across workers via `future.seed = TRUE`, L'Ecuyer-CMRG streams). See the
  new "Performance on large data sets" section of the README for details,
  including a note on convex-hull complexity in higher dimensions
  (McMullen, 1970). While refactoring `trait_disparity()`'s permutation
  loop, fixed a latent shape bug where reshaping the loop's output with
  `t()` would have silently corrupted p-values for the common
  exactly-two-groups case (a plain vector, not a matrix, is returned by
  `vapply()`/`future_vapply()` when `FUN.VALUE` has length 1, and `t()` of
  a vector produces a `1 x n` matrix, not `n x 1`); replaced with an
  explicit `matrix(..., byrow = TRUE)` reshape that handles both cases
  correctly, with a new regression test.
* **CRAN-readiness audit**: added missing `@return`/`\value` documentation
  to 17 exported `print()`/`plot()`/`summary()` methods that lacked one
  (an `R CMD check --as-cran` NOTE), spanning
  `bootstrap_functional_space()`, `detect_outliers()`,
  `digitization_error()`, `gpa_fish()`, `intraspecific_variability()`,
  `itv_index()`, `measurement_error()`, `shape_space()`, `read_tps()`,
  `species_sensitivity()`, `trait_disparity()`, and `trait_space()`.
  Fixed `plot.intrait_digitization_error()`, which — unlike every other
  `plot()` method in the package — did not explicitly return
  `invisible(x)`.
* **Infrastructure**: added a `pkgdown` site configuration
  (`_pkgdown.yml`, with a thematic reference index) and two new GitHub
  Actions workflows, `pkgdown.yaml` (builds and deploys the site to
  `gh-pages` on pushes to the default branch) and `test-coverage.yaml`
  (runs `covr::package_coverage()` and uploads results to Codecov;
  requires a `CODECOV_TOKEN` repository secret to actually upload).
  Status badges added to `README.md`.

# intraitR 0.12.0

* **`species_sensitivity()`** (new function). Implements the
  "species-level sensitivity index" of Bertrand (2026): for each species,
  its centroid (in the same `n_axes`-dimensional PCA space as
  `bootstrap_functional_space()`) is replaced, one individual at a time,
  by that individual's own position, with every other species held fixed
  at its centroid; each replacement's convex-hull volume is expressed as
  a percent change relative to the unmodified centroid-based reference
  (`fd_ref`). Per species, this yields a mean effect (`mean_dFD`, `mu_k`
  in Bertrand, 2026) and a min-max range, exposed both as a `summary`
  table and a full `individual`-level long table. Unlike
  `bootstrap_functional_space()`, this index is exact and deterministic
  (no resampling, no significance test): every replacement is a single,
  reproducible recomputation. Has `print()` (top species by
  `|mean_dFD|`, 12 by default, matching Bertrand, 2026's figure) and
  `plot()` (dot-and-range plot reproducing the report's Fig. 7 style,
  species names italicised and abbreviated by default) methods.
  Demonstrated in `demo(pipeline_T26_saudrune)`, Section 11. Requires the
  `geometry` package, as `bootstrap_functional_space()` does.
* **Internal refactor**: the `x`/`groups` resolution, preprocessing, PCA,
  and `n_axes` selection logic shared by `bootstrap_functional_space()`
  and the new `species_sensitivity()` was extracted into a single internal
  helper, `.fspace_pca_scores()` (`R/utils-internal.R`), together with
  `.group_centroids()`; `bootstrap_functional_space()`'s own behaviour and
  error messages are unchanged (verified by re-reading the refactored code
  path line by line, since this package still cannot be executed in this
  environment -- see below).

# intraitR 0.11.1

* Fixed `devtools::document()` warnings surfaced by the user immediately
  after 0.11.0: several `@noRd` (internal, undocumented-on-purpose)
  helpers in `R/utils-internal.R` -- `.plot_ordination()`,
  `.covariance_ellipse()`, `.kde2d()`, `.abbreviate_species_name()` -- were
  cross-referenced using markdown link syntax (e.g. `` [.kde2d()] ``),
  which roxygen2 can never resolve for a function with no generated `.Rd`
  page, producing a permanent "Could not resolve link to topic" warning on
  every `document()` run. Replaced with plain code-formatted text (e.g.
  `` `.kde2d()` ``), which was always the intent (pointing a reader at the
  helper's name, not producing a clickable cross-reference that cannot
  exist). The one warning that will *not* recur (`bootstrap_functional_space`
  in `.convex_hull_volume()`'s doc) was, per roxygen2's own message, a
  transient first-run artifact: that link target is a normal, exported,
  documented function and resolves correctly starting on the next
  `document()` call. No code behaviour changed.

# intraitR 0.11.0

* **`bootstrap_functional_space()`** (new function). Implements the
  "bootstrap-based functional space estimate" of Bertrand (2026, M2
  internship report supervised by A. Toussaint and S. Brosse): for
  `n_boot` bootstrap "communities", one individual is drawn at random per
  species and the n-dimensional convex-hull volume (functional richness)
  of these points is computed (`fd_boot`), and compared to a
  centroid-based reference volume (`fd_ref`, each species replaced by its
  mean position). A fresh PCA is performed internally (on as many axes as
  needed to reach a variance threshold, or a user-specified `n_axes`;
  Bertrand, 2026, used 8 axes for 98% of variance), and convex-hull
  volumes are computed with `geometry::convhulln()` (new Suggested
  dependency, gated with the same `requireNamespace()` pattern as
  `missForest` for `trait_space(na_action = "missforest")`). Reports a
  one-sided significance test of whether `fd_ref` sits unusually low
  relative to the bootstrap distribution. The source report describes a
  "one-sided permutation test" without fully specifying its scheme; a
  label-permutation design (reassigning species labels to individuals, as
  in `trait_disparity()`) was implemented and then simulation-tested
  before being rejected: it collapses every permuted centroid toward the
  global mean while permuted single-individual draws keep the data's full
  spread, so the resulting null was found to be uninformative regardless
  of whether real intraspecific variability is present, which does not
  match Bertrand (2026)'s reported result. The shipped implementation
  instead uses the bootstrap distribution itself as the null (a standard
  bootstrap percentile p-value), verified by simulation to correctly stay
  non-significant when intraspecific variability is negligible and to
  detect a strong, real effect when it is not (see `?bootstrap_functional_space`
  for the full reasoning). Has `print()` and `plot()` methods; demonstrated
  in `demo(pipeline_T26_saudrune)`, Section 10.
* **Ordination plot improvements** (`plot.intrait_traitspace()`,
  `plot.intrait_shapespace()`, via the shared internal
  `.plot_ordination()`): new `legend_title`, `legend_italic`, and
  `abbreviate_species` arguments (e.g. `legend_title = "Species",
  legend_italic = TRUE, abbreviate_species = TRUE` renders
  `"Barbatula barbatula"` as italic *B. barbatula* in the legend, used
  throughout `demo(pipeline_T26_saudrune)` and the vignette); axis ticks
  are now short and point inward (`par(tcl = 0.3)`); the qualitative
  colour palette was replaced with a higher-contrast, curated 10-colour
  set (falling back to `hcl.colors()` beyond 10 groups); and axis limits
  are now computed from the group ellipses/hulls/density contours in
  addition to the raw points, so this geometry is never clipped at the
  plot box edge (previously possible whenever a group's dispersion
  ellipse extended beyond its own points, which is the rule rather than
  the exception). Unused factor levels in `groups` are now dropped
  defensively before colouring/legending.

# intraitR 0.10.1

* **`species` argument** added to `load_t26_saudrune()`. The
  `"operators"`/`"repeatability"` landmark tables are keyed by `code` only
  (species identity lives in the separate `"identifications"` table by
  design: a landmark measurement does not need a species, and
  identifications can be revised independently of the coordinates), so
  `species` was never a column of those two tables and its absence is not
  a regression. `species = TRUE` restores convenient access by left-joining
  `species`/`id_status` from `"identifications"` via `code`. Implemented
  with a vectorised `match()` lookup (new internal helper `.join_species()`
  in `R/utils-internal.R`), not `merge()`, specifically because the
  long-format tables have many rows sharing the same `code` (one per
  landmark, and per operator/replicate): `match()` preserves the original
  row order by construction, removing any need to verify a duplicate-key
  join's ordering behaviour. Modular by design, matching the existing
  `operator` argument's convention: a no-op (with a warning) if `dataset`
  has no `code` column, and a harmless no-op on `"identifications"` itself.

# intraitR 0.10.0

* **Operator anonymisation (T-26 Saudrune data).** The `operator` column
  and `specimen` identifiers of `load_t26_saudrune("operators")` /
  `load_t26_saudrune("repeatability")` no longer contain the real names of
  the two field digitizers; they are replaced with anonymous labels
  (`"Operator_1"`, `"Operator_2"`), consistently across both tables
  (matched case-insensitively against the original spreadsheets, where the
  same person was recorded with different capitalisation in each). Operator
  identity is not itself a biological variable of interest, so nothing
  about the package's statistical results changes. `data-raw/t26_saudrune_prepare.R`
  documents the anonymisation step for full provenance. Note: this fixes
  the *shipped data*; if the package's git history has ever been pushed
  publicly with an earlier version of these files, the real names may
  still be recoverable from that history, which is outside what this
  in-place data fix can address (git history rewriting is a separate,
  deliberate operation the maintainer should consider if that applies).
* **`operator` argument** added to `load_t26_saudrune()` and
  `load_t26_saudrune_landmarks()`, restricting the returned rows/specimens
  to one or more (anonymous) operators. This is the natural way to build
  **two separate functional trait spaces**, one per operator, to check
  whether downstream results (e.g. `trait_space()`, `fishmorph_ratios()`)
  are sensitive to who did the digitizing. Modular by design: on a table
  with no `operator` column, `operator` is ignored with a warning and all
  rows are returned, rather than raising an error.
* **`style = "density"`** added to `plot.intrait_traitspace()` and
  `plot.intrait_shapespace()`: a non-parametric kernel-density contour
  (highest-density-region construction, Hyndman 1996) per group, as an
  alternative to the parametric bivariate-normal "spider" ellipse — useful
  when a group's points are visibly skewed or multimodal (as can happen
  with real digitization data). Implemented with a small, dependency-free
  bivariate Gaussian kernel density estimator (the same formula underlying
  `MASS::kde2d()`), so no new package dependency is introduced.
* **Legend placement overhauled.** `plot.intrait_traitspace()`,
  `plot.intrait_shapespace()`, `plot.intrait_itv()`, and
  `plot_fishmorph_points()` all gained a `legend_position` argument,
  defaulting to `"outside"`: the group/measurement legend is now drawn
  just outside the plot box (in the margin) by default, so it no longer
  risks overlapping data points or bars, whatever corner they happen to
  cluster in. Any standard `graphics::legend()` position keyword (e.g.
  `"topright"`) can still be passed to recover the previous, inside-the-box
  placement.

# intraitR 0.9.4

* Completed the 0.9.3 fix, which was itself incomplete. 0.9.3 added the
  correct inner assignment (`expect_message(x <- f(...), regexp)`) to the
  three regression tests but left the pre-existing *outer* assignment in
  place as well (`x <- expect_message(x <- f(...), regexp)`); the outer
  assignment executes after the quosure and unconditionally overwrites `x`
  with `expect_message()`'s own return value, silently discarding the
  correct one just captured by the inner assignment. This reproduced
  exactly the same failures as 0.9.2, which is why re-running
  `devtools::test()` after 0.9.3 still failed identically. The outer
  assignment has now been removed from `test-trait_space.R`,
  `test-itv_index.R`, and `test-trait_disparity.R`, matching the pattern
  already used correctly elsewhere in the same test files (e.g.
  `test-trait_space.R`'s `na_action = "omit"` tests). `trait_space()`,
  `itv_index()`, and `trait_disparity()` themselves are unchanged. As
  before, this development environment has no R installation available to
  verify with an actual `devtools::test()` run; please re-run locally to
  confirm.

# intraitR 0.9.3

* Fixed three regression tests (`test-trait_space.R`, `test-itv_index.R`,
  `test-trait_disparity.R`, all added in 0.9.0 for the NA/unresolved-`groups`
  fix) that used the pattern `x <- expect_message(f(...), regexp)`, which
  does not reliably capture `f()`'s return value in testthat (it can return
  the captured message condition instead). Corrected to the idiom already
  used elsewhere in the suite, `expect_message(x <- f(...), regexp)`
  (assignment *inside* the call). This was a test-only defect: confirmed by
  running `devtools::test()` under a real R installation for the first time
  (previous validation in this development environment relied on static
  code review and an independent Python re-implementation, R itself not
  being available); the underlying `trait_space()`/`itv_index()`/
  `trait_disparity()` NA-handling logic added in 0.9.0 was unaffected and
  is unchanged here; only the three test files were edited. This
  development environment still has no R installation available to the
  assistant, so this fix (like all preceding R code in this package) has
  been verified by careful manual trace of the R semantics involved, not
  by re-running `devtools::test()` directly; please re-run the full suite
  locally to confirm before relying on it.

# intraitR 0.9.2

* Added an `exclude_landmarks` argument to `digitization_error()`, allowing
  one or more landmark indices to be dropped from the per-landmark bias
  decomposition (`landmark_individual`, `by_landmark`, and all downstream
  aggregates). This is intended for landmarks that are not homologous
  biological points and so are not meaningfully comparable to the others
  in a landmark-by-landmark decomposition — most notably the embedded
  scale-bar calibration points (landmarks 20-21) of the FISHMORPH
  digitization scheme, which encode a fixed 1 cm real-world distance
  rather than a body landmark. `demo/pipeline_T26_saudrune.R` and the
  manuscript's real-data validation (Section 4.5) now call
  `digitization_error(..., exclude_landmarks = c(20, 21))` on the T-26
  repeatability trial accordingly; the resulting community-level bias
  estimate (now computed over the 19 anatomical landmarks only) and the
  ranking of least/most precise landmarks are both revised in the
  manuscript relative to 0.9.1, where the scale bar's placement was
  incorrectly pooled with genuine anatomical landmark bias.

# intraitR 0.9.1

* Added `load_t26_saudrune_landmarks()`, which loads the real T-26 Saudrune
  data (see 0.9.0, below) directly as an object of class
  `"intrait_landmarks"`, in exactly the same format returned by
  `simulate_fishmorph_points()` (`coords`, `scale = NULL`, and a `metadata`
  data.frame with `specimen`, `individual`, `species`, `population`,
  `replicate`). This makes the real data set a drop-in replacement for the
  simulated one, and the runnable `@examples` of `fishmorph_segments()`,
  `fishmorph_ratios()`, `trait_space()`, `itv_index()`, `trait_disparity()`,
  and `plot_fishmorph_points()` now use it instead of
  `simulate_fishmorph_points()`. `simulate_fishmorph_points()` itself is
  unchanged and remains available for teaching, testing, and the one
  demonstration (nested population structure in `itv_index()`) that the
  real, single-site T-26 survey cannot illustrate honestly.

# intraitR 0.9.0

* Added the package's first **real** (non-simulated) data set: `T26_Saudrune`,
  a 279-fish landmark data set from an electric-fishing survey of the
  Saudrune (Adour-Garonne basin, France, 21 April 2026), covering 8
  freshwater fish species (dominated by *Gobio occitaniae* and *Squalius
  cephalus*), digitized on the 21-landmark FISHMORPH scheme by two
  independent operators, plus a dedicated intra-operator repeatability
  trial (25 individuals x 9-10 replicate digitizations). Accessible via
  the new `load_t26_saudrune()` function (`?load_t26_saudrune`); raw
  spreadsheets and photographs are not distributed with the package, only
  the cleaned, analysis-ready tables (see `data-raw/t26_saudrune_prepare.R`
  for the full, transparent cleaning/QC pipeline, including every excluded
  specimen and why).
* Added `demo/pipeline_T26_saudrune.R` (`demo("pipeline_T26_saudrune")`), a
  complete worked pipeline running every stage of the intraitR workflow on
  this real data set: import, Generalised Procrustes Analysis, digitization
  quality control (including a worked illustration of why `detect_outliers()`
  should be run within, not across, taxonomically distinct species),
  FISHMORPH linear measurements and ratios, functional trait space,
  `itv_index()`, `measurement_error()`, `digitization_error()`, and
  `trait_disparity()`.
* Species identifications in `T26_Saudrune` are exposed with an explicit
  `id_status` field (`"curated"`, `"preliminary"`, or `"unresolved"`),
  since a small number of AI-vision-assisted calls have not yet been
  manually audited; per the data owner's instruction, this release does
  not attempt to resolve or correct them.
* **Bug fix**, found precisely because of the above: `trait_space()`,
  `itv_index()`, and `trait_disparity()` previously mishandled a `groups`
  vector containing `NA` (e.g. a specimen with an unresolved
  identification but otherwise-complete trait values, as in
  `T26_Saudrune`). In `trait_disparity()` this was a real correctness bug,
  not just an edge case: `Xmat[g == lv, ]` with an `NA` entry in `g`
  inserts an `NA`-valued row into the subset for *every* group level
  (since `NA == lv` is `NA`, not `FALSE`), turning every group's
  dispersion into `NA`. `itv_index()`/`trait_space()` instead silently
  treated the `NA` label as its own size-1 pseudo-group. All three
  functions now drop rows with a missing/unresolved `groups` value up
  front, with an explicit `message()`.

# intraitR 0.8.0

* Added `digitization_error()`, a new function quantifying hierarchical
  digitization (operator) error from repeated landmark placement,
  implementing the protocol developed by L. Boutic (2026, unpublished
  internship report, CRBE / INTRAIT project, supervised by A. Toussaint)
  to quantify operator bias in freshwater fish landmark digitization from
  French Guiana. For each landmark and individual, the dispersion of
  repeated digitizations around their consensus position is normalised by
  a reference distance (by default, the mean inter-landmark distance
  between two anchor landmarks per species, exactly as in the original
  protocol; `standard_length_mm` and centroid size are also available as
  alternative, individual-level normalizations, the latter addressing a
  methodological improvement suggested in the original report's
  discussion) and aggregated hierarchically from landmark to individual,
  species, and overall community bias. Includes `print()` and `plot()`
  methods (the latter reproducing the report's by-landmark boxplot,
  ordered by increasing median bias). This complements the existing
  `measurement_error()` (Bailey & Byrnes, 1990 / Procrustes ANOVA
  approach): `digitization_error()` is deliberately GPA-free and
  landmark-by-landmark, to directly flag which specific landmarks need a
  stricter operational definition, whereas `measurement_error()` gives an
  overall, rotation/scale-invariant repeatability estimate.

# intraitR 0.7.5

* Fixed stale package-level help (`man/intraitR-package.Rd`, `?intraitR`):
  its "Useful links" section still hard-coded the old
  `aureletoussaint/intraitR` URLs, because this file is generated by
  roxygen2 from `DESCRIPTION`'s `URL`/`BugReports` fields and had not
  been regenerated since those fields were updated to
  `FunTraits/intraitR` in 0.7.3. Fixed directly in the generated `.Rd`
  file; running `devtools::document()` again will now also regenerate it
  correctly from the (already-correct) `DESCRIPTION`.

# intraitR 0.7.4

* Fixed a real `R CMD check` WARNING found by the maintainer:
  `demo/00Index` separated the demo name and description with two
  spaces, but "Writing R Extensions" requires a tab or at least three
  spaces, which was silently treated as missing/empty index information.
* Fixed a real `R CMD check` NOTE ("Non-standard files/directories found
  at top level"): `GITHUB_SETUP.md` and the leftover local testing
  artefacts `specimens.tps`/`P5180033.jpg` are now excluded from the
  built package via `.Rbuildignore` (they were already excluded from git
  via `.gitignore`, which does not affect `R CMD build`/`check`).
* The remaining NOTE ("checking for future file timestamps ... unable to
  verify current time") is not a package issue: it means the checking
  machine could not reach a time-verification service over the network,
  and is unrelated to any file in this package.

# intraitR 0.7.3

* Repository moved to https://github.com/FunTraits/intraitR; `URL`,
  `BugReports` (`DESCRIPTION`), `inst/CITATION`, and the
  `remotes::install_github()` example in `README.md` updated
  accordingly.
* Added a standard GitHub Actions `R CMD check` workflow
  (`.github/workflows/R-CMD-check.yaml`, Linux release/devel/oldrel,
  macOS, Windows).
* `.gitignore` extended to exclude `.DS_Store` and two local testing
  artefacts that are not part of the package source.

# intraitR 0.7.2

* Test suite only: two `test-itv_index.R` failures reported by
  `devtools::test()` were bugs in the tests, not in `itv_index()` itself.
  (1) Hand-computed-precision tests compared unrounded expected values
  against `itv_index()`'s default `digits = 4`-rounded percentages with a
  tolerance too tight for that rounding (rounding a small percentage
  shifts its *relative* difference far more than a large one) — fixed by
  passing `digits = 12` in those tests. (2) A FISHMORPH test called
  `nlevels()` directly on `fish$metadata$species`, a plain character
  vector rather than a factor, which always returns 0 — fixed by wrapping
  it in `factor()` first. `itv_index()`'s own code was unaffected by
  either issue.

# intraitR 0.7.1

* Bug fix: `itv_index(nested = ...)` incorrectly errored ("Each level of
  `nested` must belong to a single level of `groups`") whenever
  population labels were reused identically across species — which is
  exactly what `simulate_fishmorph_points()`/`simulate_fish_landmarks()`
  do (`population` is `"Pop_1"`/`"Pop_2"` for every species), and is
  common in real data too. Found by the maintainer running the
  `itv_nested` vignette/help example verbatim. Fixed: `nested` levels no
  longer need to be globally unique; each *combination* of `groups` and
  `nested` is now automatically treated as a distinct population (via
  `interaction(groups, nested)`), exactly as the nesting operator in
  `aov(y ~ Error(groups/nested))` would handle it. The strict "must
  belong to a single group" validation and its error were removed as no
  longer necessary.

# intraitR 0.7.0

* New function `itv_index()`: decomposes total trait variance into an
  interspecific (between-group, e.g. between-species) component and an
  intraspecific trait variability (ITV) component, following the
  variance-partitioning approach of Violle et al. (2012) and de Bello et
  al. (2011) (`%ITV = 100 x SS_within / SS_total`). Accepts an optional
  `nested` grouping factor (e.g. population within species) to further
  split the ITV component into between-population and within-population
  (residual) parts, following the within-/among-population distinction
  used in ITV meta-analyses (Siefert et al., 2015); this nested
  decomposition is exact for any design, including unbalanced group and
  population sizes. Returns both a per-trait breakdown and a multivariate
  summary aggregated across (optionally standardised) traits, with
  dedicated print and stacked-bar-chart plot methods.

# intraitR 0.6.1

* New demo, `demo("na_handling", package = "intraitR")`: simulates a
  FISHMORPH data set, deletes a known set of trait values, and compares
  `"impute_mean"`, `"impute_group_mean"`, and `"missforest"` by RMSE
  against the true (deleted) values, alongside `"omit"` and the default
  `"fail"` behaviour of `trait_space()`.

# intraitR 0.6.0

* `trait_space()` gains `na_action = "missforest"`: nonparametric
  random-forest imputation of missing trait values via
  `missForest::missForest()` (Stekhoven & Bühlmann, 2012), using `groups`
  (when supplied) as an auxiliary predictor. Unlike `"impute_mean"`/
  `"impute_group_mean"`, this exploits correlations among traits and is
  generally preferable once more than a few values are missing. Reports
  the number of values imputed and the out-of-bag normalised RMSE via
  `message()`. Requires the (new, `Suggests`-only) `missForest` package;
  results are stochastic unless `set.seed()` is called beforehand. New
  arguments `missforest_ntree` (default `100`) and `missforest_maxiter`
  (default `10`) control the underlying random forests.

# intraitR 0.5.1

* Bug fix: `digitize_landmarks()` called `geomorph::digitize2d()` with an
  incorrect argument name (`image.list`, which does not exist in
  `geomorph`) instead of the actual argument name, `filelist`, causing an
  immediate "unused argument" error on every call. Found by the
  maintainer testing against a real photograph. Fixed by using
  `filelist`, and the `...` documentation corrected from a non-existent
  `MultCurvatures` argument to the real `scale`/`MultScale`/`verbose`
  arguments of `geomorph::digitize2d()`.

# intraitR 0.5.0

* New function `digitize_landmarks()`: a convenience wrapper around
  `geomorph::digitize2d()` for point-and-click digitization of landmarks
  directly from specimen photographs, following either the fixed
  21/22-point FISHMORPH scheme (`scheme = "fishmorph"`) or a
  user-specified number of generic landmarks (`scheme = "generic"`).
  Digitized coordinates are written to a `tpsDig` file and immediately
  re-read with `read_tps()`, so the result is a ready-to-use
  `"intrait_landmarks"` object. Requires an interactive graphics device;
  stops with an informative error rather than hanging when called
  non-interactively (e.g. in scripts, knitted vignettes, or automated
  tests).

# intraitR 0.4.0

* New function `trait_disparity()`: tests whether groups (e.g. species)
  differ in the multivariate dispersion of their functional traits, using
  a permutation test on trait variance (the trace of the group's trait
  covariance matrix), computed on the full standardised trait matrix built
  by `trait_space()` (i.e. not truncated to the two plotting axes). This
  complements `intraspecific_variability()`, which reports shape disparity
  and univariate coefficients of variation but does not test for group
  differences in multivariate trait dispersion. Accepts either an
  `"intrait_traitspace"` object or a raw trait table with `groups`.
* `trait_space()` now returns an additional (previously internal) element
  `X`, the standardised trait matrix actually analysed (post
  log-transformation and removal of constant columns, centred/scaled as
  requested), used by `trait_disparity()`. This is an additive change and
  does not affect any existing use of `trait_space()`'s output.
* `trait_space()` gains an `na_action` argument (`"fail"` (default,
  unchanged behaviour), `"omit"`, `"impute_mean"`, or
  `"impute_group_mean"`) for handling missing values in the numeric trait
  columns, instead of always erroring. `"omit"` and both imputation modes
  report, via `message()`, how many rows were dropped or values imputed,
  so the operation is never silent.
* New function `detect_outliers()`: a quality-control screen for
  landmark digitization errors, flagging specimens whose Procrustes
  distance to the sample consensus shape exceeds a robust (median +
  `threshold` x MAD) cut-off, in the spirit of
  `geomorph::plotOutliers()`. Includes a diagnostic plot and a ranked
  table of the most atypical specimens.

# intraitR 0.3.0

* `trait_space()` gains a `log_transform` argument (default `TRUE`):
  numeric traits are `log10(x + 1)`-transformed before centring/scaling
  and ordination, standard practice for ratio-type functional traits that
  are bounded at zero and often right-skewed (the `+ 1` accommodates
  traits that legitimately equal 0 under the Villéger et al., 2010,
  exception rules implemented in `fishmorph_ratios()`). Set
  `log_transform = FALSE` to disable. This does not apply to, and is not
  used by, `shape_space()`, which ordinates Procrustes shape coordinates
  rather than trait ratios.
* `plot.intrait_shapespace()` and `plot.intrait_traitspace()` gain a
  `style` argument (`"spider"`, `"hull"`, or `"none"`), replacing the
  previous `convex_hull` logical. The new default, `style = "spider"`,
  displays each group as its individual points, dashed segments linking
  every point to its group mean, the group mean itself, and a
  `ellipse_level` (default 95%) dispersion ellipse under a
  bivariate-normal approximation — the classical "spider"/"star" plot
  used to depict group structure in ordination diagrams. `style = "hull"`
  reproduces the previous convex-hull display.

# intraitR 0.2.2

* `trait_space()`'s "fewer than two numeric columns" error message now
  reads "... at least two numeric columns after removing constant
  (zero-variance) columns." (kept the original wording intact so
  downstream code/tests matching on "at least two numeric columns" still
  work) instead of a reworded message that accidentally broke that match.
* Test suite: warnings that are an expected, documented side effect of
  `trait_space()` (dropping non-numeric/constant columns) are now
  suppressed with `suppressWarnings()` in the tests that don't
  specifically test for them, and a dedicated test asserts both warnings
  are raised when expected.

# intraitR 0.2.1

Bug fixes found by `devtools::test()` on a real R installation:

* `trait_space()` now drops constant (zero-variance) numeric columns
  automatically, with a warning, instead of erroring inside
  `stats::prcomp()`/`stats::cmdscale()` ("cannot rescale a constant/zero
  column to unit variance"). This most commonly occurred when incidental
  numeric metadata carried over from `fishmorph_segments()` /
  `fishmorph_ratios()` (e.g. a digitization `replicate` counter that is
  constant when `n_replicates = 1`) was passed to `trait_space()`
  unfiltered.
* `summary_traits()` and `trait_space()` now check for "no usable numeric
  columns" before warning about dropped non-numeric columns, instead of
  emitting a spurious warning right before erroring.
* Fixed unit tests in `test-fishmorph_ratios.R` that compared rounded
  output (default `digits = 4`) against un-rounded expected values for
  ratios with repeating decimals (`REs`, `RMl`).

# intraitR 0.2.0

* Implements the FISHMORPH digitization and trait protocol of Brosse et al.
  (2021, Global Ecology and Biogeography): a fixed scheme of 21 (optionally
  22) landmarks per specimen (snout, caudal fin basis, body depth, head
  depth, eye position/diameter, mouth, pectoral fin, caudal peduncle and
  caudal fin depth, plus an embedded scale bar and an optional body-curvature
  correction point).
* `fishmorph_segments()` computes the 11 linear measurements of the protocol
  (`Bl`, `Bd`, `Hd`, `Eh`, `Mo`, `PFi`, `PFl`, `Ed`, `Jl`, `CPd`, `CFd`)
  directly from digitized points, automatically converting pixel units to
  centimetres using an embedded scale bar, and applying the optional
  body-curvature correction for standard length.
* `fishmorph_ratios()` computes the 9 unitless FISHMORPH ratios (`BEl`,
  `VEp`, `REs`, `OGp`, `RMl`, `BLs`, `PFv`, `PFs`, `CPt`) from these
  measurements, optionally adds maximum body length (`MBl`), and implements
  the special-case rules of Villeger et al. (2010) for species without a
  visible caudal fin, with a ventrally positioned mouth, or without
  pectoral fins.
* `trait_space()` builds a generic functional trait space (PCA or PCoA) from
  any numeric trait table, with group convex-hull plotting; `shape_space()`
  now shares its plotting code with `trait_space()`.
* `plot_fishmorph_points()` visualises the 21/22-point digitization scheme
  on a specimen, following the colour scheme of the original protocol
  figure.
* `simulate_fishmorph_points()` generates simulated multi-species landmark
  data following the FISHMORPH point scheme, for examples, teaching and
  testing of the functions above.

# intraitR 0.1.0

* Initial release.
* Landmark import from TPS files (`read_tps()`) and generic long-format CSV
  files (`read_landmarks_csv()`).
* Generalised Procrustes Analysis wrapper (`gpa_fish()`) built on
  `geomorph::gpagen()`.
* Linear inter-landmark distances (`linear_distances()`) and classical
  fish morphometric ratios (`morpho_ratios()`).
* Shape space construction and plotting (`shape_space()`).
* Allometry correction (`correct_allometry()`).
* Intraspecific morphological variability, combining shape disparity
  (`geomorph::morphol.disparity()`) and coefficients of variation of linear
  traits (`intraspecific_variability()`).
* Measurement error / repeatability analysis for replicated digitization,
  both for univariate traits (ANOVA-based percent measurement error and
  repeatability, Bailey & Byrnes 1990) and for shape data (Procrustes ANOVA,
  Fruciano 2016) via `measurement_error()`.
* Landmark configuration plotting (`plot_landmarks()`) and trait summary
  tables (`summary_traits()`).
* Simulated example data set `fish_landmarks` and generator function
  `simulate_fish_landmarks()`.
