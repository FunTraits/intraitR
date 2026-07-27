# Launch the interactive ml-morph landmarking application

Opens the bundled Shiny application for semi-automatic digitization of
fish landmarks. Everything the session needs is declared **at the
console** – the photograph folder, the output workbook, the operator,
the working queue – and everything it produces goes to **one workbook**
with a `measurements` sheet, a `bias` sheet holding the repeated
digitizations, and a `bias_summary` sheet quantifying them, backed by an
append-only journal that survives a crash. The operator loads a
photograph, places a handful of clicks, and a trained ml-morph shape
predictor (Porto & Voje, 2020) proposes the 19 anatomical FISHMORPH
landmarks (Brosse et al., 2021); the remaining points are reviewed and
corrected by hand, quality-scored, and saved.

## Usage

``` r
digitize_landmarks(
  photo_dir,
  xlsx_path = NULL,
  journal_dir = NULL,
  operator = NULL,
  mode = c("new", "correct", "repeat"),
  n_repeats = 3L,
  ruler_mm = 10,
  xlsx_flush_every = 10L,
  mlmorph_dir = NULL,
  predictor = NULL,
  python = NULL,
  sheets = c(measurements = "measurements", bias = "bias", summary = "bias_summary"),
  launch.browser = getOption("shiny.launch.browser", interactive()),
  ...
)
```

## Arguments

- photo_dir:

  Directory of specimen photographs. Every image in it forms the working
  queue (`jpg`, `jpeg`, `png`, `gif`, `bmp`, `tif`, `tiff`); the file
  name without its extension is the specimen code. Photographs stay
  where they are – only their name and pixel size are ever recorded.

- xlsx_path:

  Path of the single output workbook. `NULL` (default) uses
  `intraitR_landmarks.xlsx` next to `photo_dir`. Created if absent; an
  existing workbook is resumed from (its specimens are excluded from the
  `"new"` queue and are the `"correct"` queue).

- journal_dir:

  Directory of the append-only JOURNAL (see
  [`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md)).
  Every record goes there BEFORE any workbook write: it is the source of
  truth, and it survives a crash –
  [`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md)
  rebuilds the workbook from it at any time. Defaults to
  `landmark_journal/` next to the workbook.

- operator:

  Operator identifier, traced in the journal, in the workbook and in the
  identifiers of repeated digitizations. `NULL` (default) uses the
  system user.

- mode:

  Starting queue, switchable at any moment from the app: `"new"`
  (photographs not yet in the workbook), `"correct"` (specimens already
  digitized, whose points are reloaded onto the photograph for review)
  or `"repeat"` (the same photograph digitized several times, to measure
  digitization error and operator bias). If the requested queue is empty
  the app starts on another one.

- n_repeats:

  Number of digitizations per individual in `mode = "repeat"`. Defaults
  to `3`.

- ruler_mm:

  Real length, in millimetres, of the scale bar digitized by landmarks
  20-21. Changeable in the app, specimen by specimen. Defaults to `10`.

- xlsx_flush_every:

  Number of records between two workbook writes. The workbook is
  REWRITTEN IN FULL each time, so taking it out of the digitizing loop
  removes both the wait and the risk; unwritten records stay in memory,
  are written when the session ends or on demand, and are in the journal
  in any case. `1` writes after every specimen. Defaults to `10`.

- mlmorph_dir:

  Path to the ml-morph resource directory holding the trained
  predictor(s) (`mlmorph_run_app/predictor.dat`,
  `mlmorph_run_aligned/predictor.dat`), the aligned dataset
  (`mlmorph_dataset_aligned/`) and, optionally, a Python virtual
  environment (`.venv_mlmorph/`). `NULL` (default) auto-detects it from
  the `INTRAITR_MLMORPH_DIR` environment variable, then from
  `ml_morph/`, `../ml_morph/` and the working directory. The app runs
  without a predictor; only the prediction step is then disabled.

- predictor:

  Optional path to a specific trained predictor (`.dat`) to offer first
  in the app's model selector.

- python:

  Optional path to (or name of) the Python interpreter running the
  prediction worker; it needs `numpy`, `opencv-python` and `dlib`
  (typically `.venv_mlmorph`). `NULL` (default) resolves it from
  `INTRAITR_MLMORPH_PY`/`PY`, then `~/.venv_mlmorph/bin/python`, then
  `.venv_mlmorph/` inside `mlmorph_dir`, then `python3` on the search
  path.

- sheets:

  Named character vector giving the three sheet names. Defaults to
  `c(measurements = "measurements", bias = "bias", summary = "bias_summary")`.

- launch.browser:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).
  Defaults to the `shiny.launch.browser` option, or to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

- ...:

  Further arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html) (for
  example `port` or `host`). Do not pass `appDir`; the packaged app
  directory is used.

## Value

Invisibly, the path of the workbook. Called for its side effect of
running the Shiny application (a blocking call in an interactive
session).

## Details

The workbook is read back into an `"intrait_landmarks"` object with
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md),
and the journal with
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md).

The Shiny application is shipped inside the package
(`system.file("shiny/landmarking_app", package = "intraitR")`) together
with its Python worker (`system.file("mlmorph", package = "intraitR")`).
The heavier ml-morph assets – the trained predictor(s), the aligned
training set, the Python environment with `dlib` – are *not* bundled
(they are large and platform-specific) and must live in an external
directory located via `mlmorph_dir`.

The session configuration is handed to the app through the
`intraitR.digitizer` option (and the `INTRAITR_MLMORPH_*` environment
variables for the ml-morph paths); both are set for the duration of the
call and restored on exit.

## One workbook, three sheets

`measurements` holds one row per specimen, in the wide FISHMORPH layout
(`1_X, 1_Y, ... 24_X, 24_Y`) read back by
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)
(`n_landmarks = 22`, `x_pattern = "{i}_X"`, `y_pattern = "{i}_Y"`),
together with the operator, the photograph, its pixel size, the quality
score, `mm_per_px`, and the per-record status counts (`n_seeded`,
`n_predicted`, ...) that say how much of the configuration was actually
looked at. The last two coordinate pairs are the entry hinges 23-24 (see
*Curved specimens* below): recorded so that a specimen can be reopened
in the axis it was digitized under, and deliberately outside the
`n_landmarks = 22` an analysis reads.

`bias` has the same layout but one row per *repeated* digitization, with
`individual`, `operator` and `replicate` columns: it is the input of
[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md)
and
[`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md).
`bias_summary` is computed from it at each write – per individual and
per landmark, the median distance of the repeats to their own mean
position, in pixels and as a percentage of the standard length (`Bl`,
landmarks 1-2) – which is the one-number-per-landmark view that says
where the protocol is imprecise before any modelling.

The workbook is an EXPORT. The journal is the source of truth: every
record is appended to it first, as one immutable line per landmark, so
an interrupted session costs at most the specimen being digitized. See
[`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md)
and
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md).

## Working in the app

Everything follows one *active-landmark* model, from the first click to
the last: a single point is active, a click on the photograph places it,
and the selection advances along one sequence,
`1, 22, 23, 2, 3 ... 19, 20, 21` – the axis first and complete, then the
anatomical landmarks, then the scale bar. Only the derived points 8, 9
and 11 and the spare hinge 24 are skipped, and they stay reachable from
the button bar, as does any other landmark at any moment.

The moment LM2 goes down the whole configuration is seeded, so placing
by hand is the default way to work rather than a mode to switch into.
Running the predictor is optional and available throughout: it refines
the anatomical landmarks over the seeded configuration. The button bar
above the photograph is also a status display – active, placed by hand,
marked `NA`, automatic or derived, hinge, scale bar, and not yet placed
are all distinguishable at a glance, which makes an unreviewed point
visible before it is exported rather than after.

The side panel is organised in tabs – `Specimen`, `Repeats`, `Display`,
`Checks`, `Seed` – so that what is set once per batch (the seeding
sliders, the quality controls) does not stand between the operator and
what is set once per specimen. With `bslib` installed the app uses a
Bootstrap 5 theme; without it, it falls back to the standard Shiny
layout, unchanged in function.

Field photographs of 12 to 24 Mpx would otherwise make clicking
sluggish, since the plot redraws on every interaction. The image is
therefore downsampled once when it is loaded and the full-resolution
array is dropped, the display bitmap is converted to a raster once
rather than on every redraw, and only the visible crop is drawn when
zoomed. A `Display` selector trades sharpness against speed (800 to 2400
px, or full resolution; 1200 px by default). None of this touches the
coordinates – landmarks are always recorded in original image pixels –
and the predictor is still handed the file itself at full resolution.

Flipping the photograph remaps the points already placed instead of
discarding them, and a separate display-only flip mirrors the image
while leaving the coordinates untouched (useful when a reloaded
configuration is mirrored relative to its photograph). Images are routed
by their magic bytes rather than their file extension, so the `.jpg`
files that are in fact `PNG`, `GIF` or `BMP` – common in specimen
archives – open correctly, through `magick` when it is installed.

## Curved specimens: the broken axis

The FISHMORPH conventions (segment 3-4 perpendicular to the body axis,
the eye group on one vertical, the ventral group on one line) are
defined against the antero-posterior axis. On a fish photographed with a
bent body a single straight axis 1-2 misstates all of them at once. The
app therefore accepts *hinge* points that break the axis into up to four
segments, each convention being applied in the frame of the segment it
belongs to: head conventions on 1-22, body depth and pectoral fin on
22-23, caudal peduncle and fin on 23-2. Landmark 22 is a genuine
landmark –
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
already uses it to split the standard length into (1-22) + (22-2) – and
is exported. Landmarks 23 and 24 are entry aids rather than landmarks,
but they are written out all the same, in their own `23_X ... 24_Y`
columns: they define the frames every convention was applied in, so
without them a specimen reopened for correction comes back with a
straight axis and its geometry silently stops matching the one it was
digitized under. They must be left out of any shape analysis – read the
first 22 points (`n_landmarks = 22`), not every column ending in `_X`.
Placing no hinge reproduces exactly the straight-axis behaviour.

## Auditing a batch

Each record carries, per point, a `status`: `"clicked"` for a point
placed or moved by hand, `"seeded"` for one still at the median
FISHMORPH proportion the app used to lay out the configuration,
`"predicted"` for one still sitting exactly where the model put it,
`"derived"` for the geometrically computed ventral points 8, 9 and 11,
`"adjusted"` for one snapped onto the body outline by the extreme-point
check below, `"na"` for a point declared non-measurable and `"missing"`
for one never placed. This is the piece of information a coordinate
table cannot carry, and it is what distinguishes a measurement from a
plausible guess: a `"predicted"` point was at least inferred from this
image, whereas a `"seeded"` one was measured on no specimen at all. The
journal keeps them point by point; the workbook keeps the counts per
specimen. Both are worth auditing before the coordinates are analysed.

## Repeated digitization: measurement error and operator bias

A landmark coordinate is a measurement, and like any measurement it has
a technical variance that has to be estimated before a biological one is
interpreted: the same operator does not click twice in exactly the same
place, and two operators disagree more than one operator with
themselves. In `mode = "repeat"` the app saves the pass and stays on the
same photograph, until the individual has `n_repeats` digitizations.

Each pass is saved under an identifier of its own – `"<code>_rep<N>"`,
or `"<code>_<operator>_rep<N>"` when an operator is named, the
convention of the T-26 repeatability set
([`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md),
`source = "repeatability"`). The replicate number is always the last
underscore-separated token and the operator label is stripped of
underscores, so an identifier decomposes unambiguously from the right;
[`read_mlmorph_landmarks()`](https://funtraits.github.io/intraitR/reference/read_mlmorph_landmarks.md)
reverses it with `replicate = "parse"` and `operator = "parse"`, and the
`bias` sheet carries `individual`, `operator` and `replicate` as columns
anyway.

Repeats are cleared by default (`Blind repeat`): the app wipes the
configuration after each save so the next pass starts from the snout.
This is not a convenience setting. A pass resumed from the configuration
just saved measures how far the operator chose to move points they had
already placed, not how reproducibly they place them; the replicate
variance then reflects the operator's reluctance to revise rather than
the precision of the protocol, and `%ME` collapses towards zero.

## The extreme-point check

FISHMORPH defines `Bd` as the MAXIMUM body depth, so LM3 must be the
most dorsal and LM4 the most ventral landmark of the body outline. No
per-pair convention catches a breach of that – each pair stays
internally consistent while `Bd` is quietly under-measured – so the app
tests it when the specimen is saved (box "Check LM3 / LM4 (extremes) on
save", on by default) and offers to measure the landmark again, to snap
it onto the true extreme, or to save as is. Auto-correction keeps the
landmark's position along the axis and only changes its height, so `Bd`
grows without disturbing the perpendicularity of the 3-4 segment; the
points it moves are exported as `"adjusted"`.

Heights are perpendicular coordinates taken in each point's own body
segment, so posture is not mistaken for error, and the dorsal side is
read off the relative position of LM3 and LM4 rather than assumed from
the image. The caudal peduncle and fin (16-19), the appendage tips (12,
15) and the derived ventral points (8, 9, 11 – computed from LM4, so
circular as a test of LM4) are excluded. On the 1,036 digitized T-26
specimens the check flags 1.5 % of the batch at a median overshoot of
6.8 % of `Bl`, and the flagged specimens have a median `Bd/Bl` of 0.14
against a FISHMORPH median of 0.248 – that is, they are genuinely
under-measured, and correction brings them back into the expected range.

Once the axis (LM1, the hinges, LM2) is in place the app seeds every
remaining landmark at the median proportion of the body – medians of
segment over standard length across 6,492 to 7,706 FISHMORPH species –
so the work is repositioning rather than placing from nothing. Sliders
expose the quantities those ratios leave free. A landmark moved by hand
is never re-seeded.

Digitizing points out of order silently produces wrong measurements
downstream in
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md);
always spot-check immediately with
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
on the imported object, and consider
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)
across a full batch once Procrustes-aligned.

## References

Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
Villeger S (2021). FISHMORPH: A global database on morphological traits
of freshwater fishes. Global Ecology and Biogeography, 30(12),
2330-2336. [doi:10.1111/geb.13395](https://doi.org/10.1111/geb.13395)

Porto A, Voje KL (2020). ML-morph: A fast, accurate and general approach
for automated detection and landmarking of biological structures in
images. Methods in Ecology and Evolution, 11(4), 500-512.
[doi:10.1111/2041-210X.13373](https://doi.org/10.1111/2041-210X.13373)

## See also

[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md),
[`consolidate_landmarks()`](https://funtraits.github.io/intraitR/reference/consolidate_landmarks.md),
[`landmark_journal_open()`](https://funtraits.github.io/intraitR/reference/landmark_journal_open.md),
[`read_mlmorph_landmarks()`](https://funtraits.github.io/intraitR/reference/read_mlmorph_landmarks.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
[`measurement_error()`](https://funtraits.github.io/intraitR/reference/measurement_error.md),
[`operator_disagreement()`](https://funtraits.github.io/intraitR/reference/operator_disagreement.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# A digitizing session: photographs in, one workbook out.
digitize_landmarks(
  photo_dir        = "T26/photos",
  xlsx_path        = "T26/T26_landmarks.xlsx",
  journal_dir      = "T26/landmark_journal",   # default
  operator         = "AT",
  xlsx_flush_every = 10,
  mode             = "new"
)

# A repeatability session on the same photographs: 5 blind passes each.
digitize_landmarks(
  photo_dir = "T26/photos", xlsx_path = "T26/T26_landmarks.xlsx",
  operator  = "AT", mode = "repeat", n_repeats = 5
)

# Read the workbook back, one object per sheet.
lm <- read_landmarks_xlsx("T26/T26_landmarks.xlsx", sheet = "measurements",
                          n_landmarks = 22, x_pattern = "{i}_X",
                          y_pattern = "{i}_Y", id_cols = "specimen")
rep_lm <- read_landmarks_xlsx("T26/T26_landmarks.xlsx", sheet = "bias",
                              n_landmarks = 22, x_pattern = "{i}_X",
                              y_pattern = "{i}_Y",
                              id_cols = c("individual", "operator", "replicate"))
measurement_error(gpa_fish(rep_lm), individual = rep_lm$metadata$individual,
                  method = "procrustes")

# After a crash: rebuild the workbook from the journals.
consolidate_landmarks("T26/landmark_journal",
                      xlsx_path = "T26/T26_landmarks_rebuilt.xlsx")
} # }
```
