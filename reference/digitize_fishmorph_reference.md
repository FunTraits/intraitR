# Digitize the FISHMORPH reference workbook

Opens the landmark digitizer of
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)
on the FISHMORPH reference workbook (`FISHMORPH_PUBLI_*.xlsx`) instead
of a campaign photo folder. It replaces
[`Rfishmorph::launch_fishmorph_digitizer()`](https://rdrr.io/pkg/Rfishmorph/man/Rfishmorph-defunct.html):
the same three queues, the same sheets, the same journal keys – and the
application, the conventions checked on save, the ml-morph prediction
and the append-only journal of the campaign digitizer, so the two kinds
of work no longer run on two separately maintained tools.

## Usage

``` r
digitize_fishmorph_reference(
  xlsx_path,
  photo_dir = file.path(dirname(xlsx_path), "Photos utilisees"),
  out_path = NULL,
  seg_sheet = "Global_segments",
  lm_sheet = "Global_Landmark",
  new_sheet = "New_specimen",
  new_photo_dir = file.path(dirname(xlsx_path), "Photos nouvelles"),
  ruler_mm = 10,
  journal_dir = file.path(dirname(xlsx_path), "landmark_journal"),
  operator = NULL,
  xlsx_flush_every = 10L,
  mode = c("reconstruct", "correct", "new"),
  mlmorph_dir = NULL,
  predictor = NULL,
  python = NULL,
  display = c("canvas", "plot"),
  launch.browser = TRUE,
  ...
)
```

## Arguments

- xlsx_path:

  The FISHMORPH workbook (sheets `seg_sheet` and `lm_sheet`).

- photo_dir:

  Folder of the species photographs. The default, `Photos utilisees`
  beside the workbook, is also found under its accented name
  `Photos utilisées`.

- out_path:

  Working copy that is written. `NULL` (default): `xlsx_path` itself
  when its name ends in `_reconstructed.xlsx`, otherwise
  `<name>_reconstructed.xlsx`, created from `xlsx_path` if absent.

- seg_sheet, lm_sheet, new_sheet:

  Sheet names: segments, landmarks, and the new specimens (created with
  the header of `lm_sheet` when absent). A sheet whose name differs only
  by case, separators or a final "s" (`new_specimens` / `New_specimen`)
  is recognised as the one asked for.

- new_photo_dir:

  Folder of the new photographs (the `"new"` queue).

- ruler_mm:

  Real length (mm) of the scale bar 20-21, `"new"` queue.

- journal_dir:

  Journal folder. Default: `landmark_journal` beside the workbook – the
  folder the old digitizer used, so both histories are read together.

- operator:

  Operator identifier (`NULL`: the system user).

- xlsx_flush_every:

  Records between two writes of the workbook.

- mode:

  Starting queue; switchable in the app.

- mlmorph_dir, predictor, python:

  ml-morph resources, as in
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).

- display:

  `"canvas"` (default, drawn in the browser) or `"plot"`; see
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md).

- launch.browser:

  Where the app opens (see
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)).

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

The path of the working copy, invisibly. Called for its side effect.

## The three queues

- `"reconstruct"`: species WITHOUT landmarks, WITH segments and a
  photograph. Once the axis (1, then 2, with the hinges 22/24 on a
  curved fish) is placed, every landmark is seeded at the species'
  MEASURED proportions – its published segments – rather than at the
  median FISHMORPH proportions, so most of the work is checking.

- `"correct"`: rows ALREADY landmarked, on the landmark sheet or on the
  new-specimen sheet; their points are reloaded, to be reviewed and
  moved.

- `"new"`: the photographs of `new_photo_dir`, one entry per photograph,
  written to `new_sheet` (species name typed in the *Species* field,
  scale bar 20-21 optional).

## What is written where

Every save is appended to the journal FIRST (the source of truth, read
by
[`landmark_journal_read()`](https://funtraits.github.io/intraitR/reference/landmark_journal_read.md)
and
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
together with the journals written by the old Rfishmorph digitizer),
then to the working copy of the workbook (`out_path`), edited in place
through openxlsx and written atomically every `xlsx_flush_every`
records. The journal `row_key` is the species name (`"reconstruct"`,
`"correct"`) or the photograph file name (`"new"`), as before, so the
history of a species continues across the two tools. The quality score
is on the common scale, 1 (unusable) to 5 (excellent), empty when not
scored.

## See also

[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
[`landmark_journal_status()`](https://funtraits.github.io/intraitR/reference/landmark_journal_status.md),
[`landmark_journal_qc()`](https://funtraits.github.io/intraitR/reference/landmark_journal_qc.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
digitize_fishmorph_reference(
  xlsx_path     = "FishMORPH/FISHMORPH_PUBLI_9556sp_reconstructed.xlsx",
  photo_dir     = "FishMORPH/Photos utilisees",
  new_photo_dir = "FishMORPH/Photos nouvelles",
  operator      = "AT",
  mode          = "correct")
} # }
```
