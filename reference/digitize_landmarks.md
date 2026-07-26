# Launch the interactive ml-morph landmarking application

Opens the bundled Shiny application for semi-automatic digitization of
fish landmarks. The user loads a specimen photograph (or a folder of
photographs), places a handful of calibration clicks (snout, caudal-fin
base, a dorsal orientation point and the two scale-bar points), and a
trained ml-morph shape predictor (Porto & Voje, 2020) proposes the 19
anatomical FISHMORPH landmarks (Brosse et al., 2021); the remaining
points can then be reviewed and corrected by hand, quality-scored, and
exported to `CSV`/`tpsDig`. The exported `CSV`
(`specimen, landmark, X, Y, mm_per_px, note, status`) is read back into
an `"intrait_landmarks"` object with
[`read_mlmorph_landmarks()`](https://funtraits.github.io/intraitR/reference/read_mlmorph_landmarks.md).

## Usage

``` r
digitize_landmarks(
  mlmorph_dir = NULL,
  predictor = NULL,
  python = NULL,
  autosave = NULL,
  launch.browser = getOption("shiny.launch.browser", interactive()),
  ...
)
```

## Arguments

- mlmorph_dir:

  Path to the ml-morph resource directory holding the trained
  predictor(s) (`mlmorph_run_app/predictor.dat`,
  `mlmorph_run_aligned/predictor.dat`), the aligned dataset
  (`mlmorph_dataset_aligned/`) and, optionally, a Python virtual
  environment (`.venv_mlmorph/`). If `NULL` (default), the location is
  auto-detected from the `INTRAITR_MLMORPH_DIR` environment variable and
  then from a small set of conventional locations relative to the
  current working directory (`ml_morph/`, `../ml_morph/`, and the
  working directory itself). A directory "looks like" an ml-morph
  directory when it contains a trained predictor, the worker script, or
  the aligned dataset.

- predictor:

  Optional path to a specific trained predictor (`.dat`) file to offer
  first in the app's model selector, in addition to any predictors
  auto-discovered under `mlmorph_dir`.

- python:

  Optional path to (or name of) the Python interpreter used to run the
  prediction worker. It must have `numpy`, `opencv-python` and `dlib`
  available (typically the `.venv_mlmorph` environment). If `NULL`
  (default), the interpreter is resolved from the
  `INTRAITR_MLMORPH_PY`/`PY` environment variables, then from
  `~/.venv_mlmorph/bin/python`, then from a `.venv_mlmorph/` inside
  `mlmorph_dir`, falling back to `python3` on the search path.

- autosave:

  Path to the writable `CSV` file the app uses to auto-save the
  cumulative multi-specimen table (reloaded on start-up). If `NULL`
  (default), a file `intraitR_landmarking_autosave.csv` is used in the
  working directory *from which this function is called* (necessary
  because [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)
  switches the working directory to the read-only installed app folder
  while the app runs).

- launch.browser:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html);
  whether to open the app in a browser. Defaults to the
  `shiny.launch.browser` option, or to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

- ...:

  Further arguments passed on to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html) (for
  example `port` or `host`). Do not pass `appDir`; the packaged app
  directory is used automatically.

## Value

Invisibly `NULL`. Called for its side effect of running the Shiny
application (a blocking call in an interactive session). Landmark tables
produced by the app are written to disk (`CSV`/`TPS`) and imported
separately with
[`read_mlmorph_landmarks()`](https://funtraits.github.io/intraitR/reference/read_mlmorph_landmarks.md)
or
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md).

## Details

This function replaces the former point-and-click wrapper around
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html):
rather than digitizing every landmark manually, it drives a
predictor-assisted workflow with far fewer clicks per specimen and an
active-learning loop (corrected specimens can be fed back into training;
see the `ml_morph/README.md` pipeline).

The Shiny application is shipped inside the package
(`system.file("shiny/landmarking_app", package = "intraitR")`) together
with its Python worker (`system.file("mlmorph", package = "intraitR")`).
The heavier ml-morph assets — the trained predictor(s), the aligned
training dataset, and the Python virtual environment with `dlib` — are
*not* bundled (they are large and platform-specific) and must live in an
external ml-morph directory located via `mlmorph_dir`. When no predictor
is found the app still launches, but the prediction step is disabled
until a valid predictor is supplied.

Resource locations are handed to the app through environment variables
(`INTRAITR_MLMORPH_DIR`, `INTRAITR_MLMORPH_WORKER`,
`INTRAITR_MLMORPH_PY`, `INTRAITR_MLMORPH_PREDICTOR`,
`INTRAITR_MLMORPH_AUTOSAVE`); these are set for the duration of the call
and restored on exit, so the app can also be launched directly with
`shiny::runApp("ml_morph/landmarking_app")`, in which case it falls back
to paths relative to the `ml_morph/` folder.

## Working in the app

Everything follows one *active-landmark* model, from the first click to
the last: a single point is active, a click on the photograph places it,
and the selection advances along one sequence,
`1, 22, 23, 2, 3 ... 19, 20, 21` – the axis first and complete, then the
anatomical landmarks, then the scale bar. Only the derived points 8, 9
and 11 and the spare hinge 24 are skipped, and they stay reachable from
the button bar, as does any other landmark at any moment.

The moment LM2 goes down the whole configuration is seeded, so placing
by hand is the default way to work rather than a mode to switch into,
and there is no calibration/review distinction. Running the predictor is
optional and available throughout: it refines the anatomical landmarks
over the seeded configuration. The app is therefore fully usable with no
trained predictor at all. The button bar above the photograph is also a
status display – active, placed by hand, marked `NA`, automatic or
derived, hinge, scale bar, and not yet placed are all distinguishable at
a glance, which makes an unreviewed point visible before it is exported
rather than after.

Field photographs of 12 to 24 Mpx would otherwise make clicking
sluggish, since the plot redraws on every interaction. The image is
therefore downsampled once when it is loaded and the full-resolution
array is dropped, the display bitmap is converted to a raster once
rather than on every redraw, and only the visible crop is drawn when
zoomed. A `Display` selector above the photograph trades sharpness
against speed (800 to 2400 px, or full resolution; 1200 px by default).
None of this touches the coordinates – landmarks are always recorded in
original image pixels – and the predictor is still handed the file
itself at full resolution.

Flipping the photograph remaps the points already placed instead of
discarding them, and a separate display-only flip mirrors the image
while leaving the coordinates untouched (useful when a reloaded table is
mirrored relative to its photograph). Images are routed by their magic
bytes rather than their file extension, so the `.jpg` files that are in
fact `PNG`, `GIF` or `BMP` – common in specimen archives – open
correctly, through `magick` when it is installed.

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
is exported; landmarks 23 and 24 are entry aids and are never written
out. Placing no hinge reproduces exactly the straight-axis behaviour.

## Auditing a batch

Each exported row carries a `status`: `"clicked"` for a point placed or
moved by hand, `"seeded"` for one still at the median FISHMORPH
proportion the app used to lay out the configuration, `"predicted"` for
one still sitting exactly where the model put it, `"derived"` for the
geometrically computed ventral points 8, 9 and 11, `"na"` for a point
declared non-measurable and `"missing"` for one never placed. This is
the piece of information a coordinate table cannot carry, and it is what
distinguishes a measurement from a plausible guess: a `"predicted"`
point was at least inferred from this image, whereas a `"seeded"` one
was measured on no specimen at all. Both are counted on screen and again
when a specimen is saved, and both are worth auditing before the
coordinates are analysed.

Once the axis (LM1, the hinges, LM2) is in place the app seeds every
remaining landmark at the median proportion of the body – medians of
segment over standard length across 6,492 to 7,706 FISHMORPH species –
so the work is repositioning rather than placing from nothing. Sliders
expose the quantities those ratios leave free: where a segment sits
along the body, how it splits dorsal to ventral, and the pectoral-fin
and jaw angles. A landmark moved by hand is never re-seeded.

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

[`read_mlmorph_landmarks()`](https://funtraits.github.io/intraitR/reference/read_mlmorph_landmarks.md),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Auto-detect the ml-morph resources (e.g. an "ml_morph/" folder in the
# working directory) and open the landmarking app:
digitize_landmarks()

# Point explicitly at the ml-morph directory, a specific predictor and
# the dlib-enabled Python environment:
digitize_landmarks(
  mlmorph_dir = "~/projects/fish/ml_morph",
  predictor   = "~/projects/fish/ml_morph/mlmorph_run_app/predictor.dat",
  python      = "~/.venv_mlmorph/bin/python"
)

# Import the CSV exported from the app into an "intrait_landmarks" object:
lm <- read_mlmorph_landmarks("mesures.csv")
} # }
```
