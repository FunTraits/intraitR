# Write an analysis as a reproducible project (paper architecture)

Writes a folder organised like the repository of a published paper –
`scripts/` numbered (`00_START`, `01_DATA`, `02_ANALYSIS`, `03_FIGURE`,
`04_SUPP`, `05_STAT`), `utils/`, `data/raw` and `data/processed`,
`results/figures` and `results/tables`, `manuscript/`, `run_all.R`,
`README.md`, an RStudio project and `.gitignore` – then RUNS it: the
tables, figures and the Methods & Results report
(`manuscript/ Methods_Results.docx`) are produced by the project's own
scripts, in a separate R process, from the raw landmarks written in
`data/raw`. What the archive contains is therefore exactly what running
it again gives.

## Usage

``` r
write_analysis_project(
  landmarks,
  dir,
  params = analysis_params(),
  repeats = NULL,
  literature = NULL,
  title = "Morphological analyses",
  author = "",
  run = TRUE,
  zip = TRUE,
  quiet = FALSE
)
```

## Arguments

- landmarks:

  An `"intrait_landmarks"` object (coordinates in pixels, metadata with
  at least `species`; `site`, `date`, `operator`, `source` used when
  present), e.g. from
  [`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md).
  May be `NULL` when `literature` is given (the analyses based on
  landmarks – shape, measurement error – are then left out).

- dir:

  Folder to create (its name is the project name). Must not exist or be
  empty.

- params:

  Analysis parameters, see
  [`analysis_params()`](https://funtraits.github.io/intraitR/reference/analysis_params.md).

- repeats:

  Optional `"intrait_landmarks"` object of repeated digitizations
  (metadata `individual`, `operator`, `replicate`), for the
  measurement-error script.

- literature:

  Optional individual trait records without photographs (published data
  sets): a data.frame with `species`, the nine FISHMORPH ratios and
  optionally `specimen_code`, `site`, `date`, `study_id`. They enter
  every analysis based on the ratios, with the provenance
  `"literature"`; written in `data/raw/traits_literature.csv`.

- title, author:

  Title of the project and author(s), written in the README, the script
  headers and the report.

- run:

  Run the project (`run_all.R`) after writing it.

- zip:

  Zip the folder (`<dir>.zip`, next to it).

- quiet:

  No progress messages.

## Value

A list: `dir`, `zip` (path or `NULL`), `log` (the run log), `ok` (`TRUE`
when the run completed), `error` (message, when it did not).

## See also

[`launch_intrait_analyses()`](https://funtraits.github.io/intraitR/reference/launch_intrait_analyses.md),
[`analysis_params()`](https://funtraits.github.io/intraitR/reference/analysis_params.md)

## Examples

``` r
if (FALSE) { # \dontrun{
lm <- read_landmarks_xlsx("landmarks.xlsx", sheet = "measurements",
                          n_landmarks = 25, id_cols = "specimen")
res <- write_analysis_project(lm, "~/Desktop/T26_morphology",
                              params = analysis_params(min_n = 10),
                              title = "Morphology of the T26 fishes",
                              author = "A. Toussaint")
res$zip
} # }
```
