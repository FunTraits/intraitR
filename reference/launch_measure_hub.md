# Choose, digitize and check photographs: the measuring hub

Launches the screen that comes before
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
and the one that comes after it, for any folder of photographs.

## Usage

``` r
launch_measure_hub(
  photo_dir = NULL,
  xlsx_path = NULL,
  journal_dir = NULL,
  species = NULL,
  operator = NULL,
  ruler_mm = 10,
  mlmorph_dir = NULL,
  python = NULL,
  levels = c("Folder", "Sub-folder"),
  traits_fun = NULL,
  apps = NULL,
  default_apps = TRUE,
  sync_fun = NULL,
  literature = NULL,
  title = "intraitR - measure",
  launch.browser = TRUE,
  ...
)
```

## Arguments

- photo_dir:

  Root folder of the photographs (sub-folders included). `NULL`
  (default): the hub opens on a start page where the folder is chosen
  (or photographs are uploaded into a new one), with the species, where
  the measurements are saved, the operator and the ruler – and the
  recent sessions, reopened in one click. *Open another folder*, on the
  home page of the hub, comes back to it.

- xlsx_path:

  Workbook written by the digitizer. `NULL`: `intraitR_landmarks.xlsx`
  next to `photo_dir`, as
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).

- journal_dir:

  Landmark journal. `NULL`: `landmark_journal` next to the workbook.

- species:

  Where the species come from: `NULL`, `"folder"` (one folder per
  species) or a table; see
  [`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md).
  Also a function without argument returning such a table, called again
  at every refresh (so that photographs imported while the hub is open
  get their species).

- operator:

  Operator identifier (editable in the hub). `NULL`: the system user.

- ruler_mm:

  Real distance between landmarks 20 and 21, in mm (editable).

- mlmorph_dir, python:

  ml-morph folder and Python interpreter, as in
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
  (editable).

- levels:

  Labels of the two folder levels in the hub, e.g. `c("Site", "Date")`
  or `c("Species", "Sub-folder")`.

- traits_fun:

  Optional function computing the trait table, called as
  `traits_fun(codes, xlsx_path, ruler_mm, scale_action)` with the
  photograph codes to keep; it must return a data.frame with a column
  `specimen_code` (and may return `photo_code` and `species`). `NULL`
  uses
  [`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md),
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
  and
  [`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md).
  This is how a data-management layer attaches its own metadata.

- apps:

  Other applications the hub opens, each in its own background R process
  and browser tab, so that the hub is the one place a session starts
  from. A list of entries
  `list(label = , fun = "pkg::launcher", args = list(...), place = )`,
  `place` being `"select"` (a button of the Select tab: importing data,
  for example), `"photo"` (a button on one photograph, in the gallery
  magnifier and in the Annotated photograph tab; its code is passed in
  the argument named `photo_arg`; `warn_measured` is shown first when
  the photograph is already measured; `close_digitizer = TRUE` closes an
  open digitizer first, for an application that rewrites the workbook;
  `photo_query`: the URL parameter the application reads the photograph
  from, so that an open application is pointed at the next photograph in
  its own tab instead of being restarted) or `"menu"` (the Apps menu
  only; every non-photograph application is in that menu). The launcher
  must pass `...` to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html). The
  hub refreshes its photographs when one of these applications closes.

- default_apps:

  Add the FISHMORPH functional space
  ([`Rfishmorph::launch_fishmorph_space()`](https://rdrr.io/pkg/Rfishmorph/man/launch_fishmorph_space.html))
  to the Apps menu.

- sync_fun:

  Optional function without argument, run by the hub's *Save to the
  database* button, when the digitizer closes and at *Finish*: what a
  data-management layer needs to register the measurements (for
  FishInTrait, linking the workbook's specimens in the project
  manifest). It returns a short message, shown in the hub. The landmarks
  themselves need no such step: each *Save & next* of the digitizer
  writes them to the journal at once.

- literature:

  Optional individual trait records that have no photograph – published
  data sets, typically: a data.frame, or a function without argument
  returning one (called when needed), with a column `species`, the nine
  FISHMORPH ratios (`BEl` ... `CPt`) and optionally `site`, `date`,
  `study_id`, `specimen_code`. They appear in the Results page under the
  provenance "literature" (one filter per study), in its Traits table,
  and in the analyses it opens
  ([`launch_intrait_analyses()`](https://funtraits.github.io/intraitR/reference/launch_intrait_analyses.md))
  for every analysis based on the ratios. FishInTrait passes the
  literature of the project.

- title:

  Title shown in the hub.

- launch.browser:

  Where the hub opens; see
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Invisibly, when closed with *Finish*, a list: `photo_dir`, `xlsx_path`,
`journal_dir`, `selected` (the selected photographs, as in
[`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md))
and `traits` (the last table computed, or `NULL`). `NULL` when the hub
is stopped otherwise.

## Details

1.  *Setup*: paths, operator, ruler, ml-morph folder; the sub-folders
    with their numbers of photographs and of measured ones.

2.  *Select*: a folder and a sub-folder (for example a site and a date,
    or a species), a gallery of their photographs with species and
    measured state, a species table; any subset can be picked (a
    species, the photographs not yet measured, a few by hand).

3.  *Digitize*: optionally the automatic pre-pass
    [`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
    (with or without a ruler on the photographs), then
    [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
    on exactly the selection. The digitizer runs in a separate R process
    and opens in its own browser tab; the hub stays usable.

4.  *Results*: progress by folder and species; landmarks and their
    statuses (clicked, predicted, seeded...) read from the journal, with
    its quality control; the FISHMORPH traits (a specimen without a
    ruler keeps its nine ratios, its segments then being in pixels); any
    photograph with its landmarks drawn on it, and a *Remeasure* button
    that reopens the digitizer on that photograph alone, in `correct`
    mode. The tables follow the journal while the digitizer is running.

*Finish* (top right) stops the digitizer and the pre-pass if they are
running – the digitizer is interrupted cleanly, which writes its
workbook – closes the hub and returns to the console.

## See also

[`measure_queue()`](https://funtraits.github.io/intraitR/reference/measure_queue.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
[`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# one folder per species, a 10 mm ruler on the photographs
# no argument: choose everything on the start page
res <- launch_measure_hub()

res <- launch_measure_hub("~/my_photos", species = "folder",
                          levels = c("Species", "Sub-folder"),
                          operator = "XX", mlmorph_dir = "~/ml_morph")
res$traits
} # }
```
