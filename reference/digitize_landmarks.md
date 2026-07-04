# Interactively digitize landmarks from specimen photographs

A convenience wrapper around
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html)
for point-and-click digitization of two-dimensional landmarks directly
from specimen photographs, following either the fixed 21/22-point
FISHMORPH digitization scheme (Brosse et al., 2021; see
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md))
or a user-specified number of generic landmarks. Digitized coordinates
are written to a `tpsDig`-format file and immediately re-read with
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
so the result is a ready-to-use `"intrait_landmarks"` object.

## Usage

``` r
digitize_landmarks(
  images,
  scheme = c("fishmorph", "generic"),
  n_landmarks = NULL,
  curvature = FALSE,
  tpsfile,
  metadata = NULL,
  ...
)
```

## Arguments

- images:

  Character vector of paths to `.jpg`/`.jpeg` specimen photographs (one
  file per specimen), passed on to
  [`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html)
  as its `filelist` argument. `geomorph`'s underlying reader
  ([`jpeg::readJPEG()`](https://rdrr.io/pkg/jpeg/man/readJPEG.html))
  only supports JPEG images; convert other formats (PNG, TIFF, etc.) to
  `.jpg` first.

- scheme:

  Character, one of `"fishmorph"` (the fixed FISHMORPH scheme of Brosse
  et al., 2021: 21 landmarks, or 22 with `curvature = TRUE`) or
  `"generic"` (any fixed number of landmarks, set via `n_landmarks`).

- n_landmarks:

  Integer, number of landmarks to digitize per specimen when
  `scheme = "generic"`. Ignored (and set automatically to 21 or 22) when
  `scheme = "fishmorph"`.

- curvature:

  Logical, digitize the optional 22nd FISHMORPH body-curvature
  correction point in addition to the 21 fixed points (see
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).
  Ignored when `scheme = "generic"`.

- tpsfile:

  Path to the `tpsDig`-format file that will store the digitized
  coordinates (see
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md));
  required, since it is also how this function retrieves the digitized
  data back from
  [`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html).

- metadata:

  Optional `data.frame` of specimen-level metadata, passed on to
  [`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
  after digitizing (see its `metadata` argument).

- ...:

  Further arguments passed on to
  [`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html),
  for example `verbose = FALSE` for uninterrupted (non-prompted)
  digitizing of each landmark, or `scale`/`MultScale` to additionally
  digitize a scale bar per image via `digitize2d()`'s own mechanism (not
  needed for `scheme = "fishmorph"`, whose embedded scale-bar landmarks
  are handled separately by
  [`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)).
  Do not pass `filelist`, `nlandmarks`, or `tpsfile` here; use the
  dedicated arguments above instead.

## Value

An object of class `"intrait_landmarks"` (see
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)),
built from the coordinates written to `tpsfile` by
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html).

## Details

This function requires an interactive graphics device (it calls
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html),
which in turn uses
[`graphics::locator()`](https://rdrr.io/r/graphics/locator.html)) and
cannot be used non-interactively — e.g. via `Rscript`, inside a knitted
vignette, or inside automated tests — where it stops with an informative
error instead of hanging.

For the FISHMORPH scheme, digitize landmarks 1 to 21 (or 1 to 22 with
`curvature = TRUE`) in the exact anatomical order shown by
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
(points 20-21 are the embedded scale bar, used by
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md)
to convert pixel distances to centimetres via its own `scale_cm`
argument — no separate scale-bar step is requested here). Digitizing
points out of order silently produces wrong measurements downstream in
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md);
always spot-check immediately after digitizing with
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md)
on the resulting object, and consider
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)
across a full batch once Procrustes-aligned.

This wrapper relies on
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html)'s
`filelist`, `nlandmarks`, and `tpsfile` arguments; if a future
`geomorph` release renames these, digitize directly with
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html)
and import the resulting file with
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md)
instead.

[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html)
checks for an existing file of the same name as `tpsfile` in the current
working directory to decide whether to start a fresh digitizing session
or resume an interrupted one; use a `tpsfile` name not already present
in the working directory for a new batch of specimens (an unrelated
pre-existing file of that name, from an earlier, differently sized
`images` batch, causes
[`geomorph::digitize2d()`](https://rdrr.io/pkg/geomorph/man/digitize2d.html)
to error with "Filelist not the same length as input TPS file").

## References

Adams DC, Collyer ML, Kaliontzopoulou A, Baken EK (2024). geomorph:
Software for geometric morphometric analyses. R package.

Brosse S, Charpin N, Su G, Toussaint A, Herrera-R GA, Tedesco PA,
Villeger S (2021). FISHMORPH: A global database on morphological traits
of freshwater fishes. Global Ecology and Biogeography, 30(12),
2330-2336. [doi:10.1111/geb.13395](https://doi.org/10.1111/geb.13395)

## See also

[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# FISHMORPH scheme, three photographs, writing a tpsDig file:
lm <- digitize_landmarks(
  images = c("specimen1.jpg", "specimen2.jpg", "specimen3.jpg"),
  scheme = "fishmorph", tpsfile = "specimens.tps"
)

# Generic 12-landmark scheme:
lm <- digitize_landmarks(
  images = "specimen1.jpg", scheme = "generic", n_landmarks = 12,
  tpsfile = "specimen1.tps"
)
} # }
```
