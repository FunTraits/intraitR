# Analyses of measured fishes, exported as a reproducible project

Opens a Shiny application for the ANALYSIS part of the intraitR
workflow, on specimens already measured: FISHMORPH traits, functional
trait space and dispersion tests, position in the global FISHMORPH
space, intraspecific variability (variance partition, coefficients of
variation, sampling effort), shape space, measurement error. Each tab
shows the result live; the *Export* tab writes the whole analysis as a
project with the architecture of a published paper – numbered scripts,
data, results, `run_all.R`, README, and a Methods & Results report – by
running the project's own scripts, then zips it (see
[`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md)).

## Usage

``` r
launch_intrait_analyses(
  xlsx_path = NULL,
  specimens = NULL,
  landmarks = NULL,
  literature = NULL,
  title = NULL,
  author = NULL,
  launch.browser = TRUE,
  port = NULL,
  host = "127.0.0.1",
  ...
)
```

## Arguments

- xlsx_path:

  A digitizer workbook (sheet `measurements`; a `bias` sheet, when
  present, gives the repeated digitizations for measurement error).
  Landmarks are read up to point 25, so that the hinges of curved
  specimens count in standard length.

- specimens:

  Optional table of the specimens (a data.frame or the path of a CSV
  file): column `specimen` (the workbook's identifier) and any of
  `species`, `site`, `date`, `operator`. It overrides the workbook's own
  columns and restricts the analysis to the specimens it lists.

- landmarks:

  Alternatively, an `"intrait_landmarks"` object (or the path of an
  `.rds` file holding one), metadata with `species`.

- literature:

  Optional individual trait records without photographs (a data.frame or
  the path of a CSV file): `species`, the nine FISHMORPH ratios, and
  optionally `specimen_code`, `site`, `date`, `study_id`. They enter the
  analyses based on the ratios, with the provenance `"literature"`; the
  hub passes those of its Results filters.

- title, author:

  Pre-filled title and author of the exported project.

- launch.browser, port, host:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

- ...:

  Other arguments for
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Called for its side effect; the app's value when it closes.

## Details

The measurement hub
([`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md))
opens it from its *Results* tab on the measured specimens of the chosen
scope.

## See also

[`write_analysis_project()`](https://funtraits.github.io/intraitR/reference/write_analysis_project.md),
[`analysis_params()`](https://funtraits.github.io/intraitR/reference/analysis_params.md)

## Examples

``` r
if (FALSE) { # \dontrun{
launch_intrait_analyses(xlsx_path = "T26_landmarks.xlsx")
} # }
```
