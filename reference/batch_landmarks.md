# Automatic landmarking of a batch of photographs (no clicks)

Runs the fully automatic ml-morph chain on every photograph of a folder,
without opening them: the GLOBAL network
(`mlmorph_run_global/model.onnx`) finds the snout (LM1), the caudal-fin
basis (LM2) and the dorsal side on the whole photograph (then on a
zoomed crop of the fish), and the neural-network model of the canonical
frame (`mlmorph_run_cnn/model.onnx`) places the other landmarks. Same
chain as the "Auto (no clicks)" button of
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
with the models loaded once (a fraction of a second per photograph on a
CPU).

## Usage

``` r
batch_landmarks(
  photos,
  out_dir,
  recursive = FALSE,
  qc = TRUE,
  open_qc = interactive(),
  max_fish = 1L,
  ruler = TRUE,
  ruler_mm = 10,
  min_bl_frac = 0.15,
  hinges = FALSE,
  redo = FALSE,
  mlmorph_dir = NULL,
  python = NULL
)
```

## Arguments

- photos:

  Folder of photographs, or a character vector of image paths.

- out_dir:

  Output folder (created). A photograph already processed there is
  skipped unless `redo = TRUE`.

- recursive:

  Look into sub-folders of `photos`.

- qc:

  Write annotated thumbnails and a contact sheet `qc/index.html`, sorted
  by decreasing risk.

- open_qc:

  Open the contact sheet in the browser when done.

- max_fish:

  Fish per photograph. `1` (default): one fish, and a photograph
  carrying more is flagged `plusieurs`. More (plates): up to `max_fish`
  fish are found, numbered `individual` 1, 2, ... from top to bottom.

- ruler:

  Do the photographs carry a ruler (scale bar)? `TRUE` (default): it is
  detected automatically (landmarks 20-21) and a photograph without a
  readable ruler is flagged `règle`. `FALSE`: no detection, no `règle`
  flag, measurements in pixels only. Applies to the whole call: run a
  folder with and a folder without ruler separately (a photograph
  already in `out_dir` keeps its first run unless `redo = TRUE`).

- ruler_mm:

  Real distance between landmarks 20 and 21, in mm (used only when
  `ruler = TRUE`).

- min_bl_frac:

  Flag threshold (see Details).

- hinges:

  Also write the hinges 22/24 of the broken axis predicted by the model
  (curved fish). Off by default: away from the sites where hinges were
  clicked for training, predicted hinges bias the derived points.

- redo:

  Process every photograph again.

- mlmorph_dir, python:

  As in
  [`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md):
  the ml-morph folder (`NULL` auto-detects it) and the Python
  interpreter (`NULL`: `INTRAITR_MLMORPH_PY`,
  `~/.venv_mlmorph/bin/python`, then `python3`).

## Value

Invisibly, a list: `summary` (one row per fish: `photo`, `individual`,
`ruler`, dimensions, standard length in pixels `bl_px`, `score`,
`flags`, `risk`, and with a ruler `mm_per_px`, `bl_mm`), `landmarks`
(long: `photo`, `individual`, `landmark`, `X`, `Y`, `conf`) and
`out_dir`.

## Details

Nothing is written to the measurement journal: the result is a proposal
to check. Every photograph gets quality flags and a risk score, so that
only the doubtful ones need opening:

- `plusieurs`: one fish more than `max_fish` was found (an undeclared
  plate);

- `dorsal`: the dorsal side of the global network and the LM3 of the
  fine model contradict each other (fish possibly upside down);

- `petit`: the fish spans less than `min_bl_frac` of the largest image
  side;

- `bord`: a landmark within 1 percent of the image border;

- `confiance`: score (mean confidence of the fine model) among the
  lowest 10 percent of the batch.

Localisation is robust to distractors (labels, reflections, other fish):
several candidates are taken for the snout and the caudal base, and each
snout-caudal pair is checked by the fine model, which recognises a real
fish in the canonical frame; on plates, each fish found is masked before
the next is searched.

Scale bar (20-21): when the photographs carry a ruler (`ruler = TRUE`,
the default) and the ruler network `mlmorph_run_ruler/model.onnx` is
present, the two graduations are located automatically and `summary`
gains `mm_per_px`, `scale_quality` and `bl_mm`; a photograph whose ruler
cannot be read is flagged `règle`, and one whose graduation period
departs from the network's order of magnitude is flagged `échelle`. With
`ruler = FALSE` nothing is searched and nothing is flagged: measurements
stay in pixels. The choice is recorded per photograph in the `ruler`
column of `summary`. Coordinates are in pixels of the raw pixel grid
(EXIF orientation ignored, as in the applications).

## See also

[`read_batch_landmarks()`](https://funtraits.github.io/intraitR/reference/read_batch_landmarks.md),
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
res <- batch_landmarks("00_project/prepared/SAUDRUNE/20260427",
                       out_dir = "batch_saudrune", open_qc = TRUE)
subset(res$summary, flags != "")   # photographs to review
} # }
```
