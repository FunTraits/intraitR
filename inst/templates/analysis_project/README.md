# {{TITLE}}

This repository contains the code, data, figures and result tables of the
morphological analyses of {{N_SPECIMENS}} fish specimens ({{N_SPECIES}} species),
produced with the R package [intraitR](https://github.com/FunTraits/intraitR)
({{INTRAITR_VERSION}}) on {{DATE}}.

**Author(s):** {{AUTHOR}}

------------------------------------------------------------------------

## 🗂️ Repository structure

``` text
{{PROJECT}}/
├── scripts/                  # Analysis pipeline (sourced in numeric order by run_all.R)
{{SCRIPT_TREE}}
│   └── setup_environment.R               # Installs the packages (not run by run_all.R)
│
├── utils/                    # Shared code
│   ├── library.R                         # Packages
│   ├── parameters.R                      # Every analysis parameter (one place)
│   └── functions.R                       # Helpers (tables, figures, data reading)
│
├── data/
│   ├── raw/                  # Landmark coordinates as digitized (long format) + specimen table
│   ├── processed/            # Measurements, ratios, analysed sample, fitted objects (.rds)
│   └── metadata.csv          # Definition of every variable
│
├── results/
│   ├── figures/              # Main (Fig*) and supplementary (FigS*) figures, .png and .pdf
│   └── tables/               # Main (Table*) and supplementary (TableS*) tables, .csv
│
├── manuscript/
│   ├── Methods_Results.Rmd   # Methods and Results, numbers read from results/tables
│   ├── Methods_Results.docx  # The same, rendered
│   ├── references.bib
│   └── ecology-letters.csl
│
├── run_all.R                 # Runs the full pipeline, then renders the report
├── {{PROJECT}}.Rproj         # RStudio project file
├── session_info.txt          # R and package versions that produced the results
├── README.md                 # This file
└── .gitignore
```

> **Note:** as in the original projects, `data/` and `manuscript/` are listed
> in `.gitignore`; archive `data/` separately (e.g. Zenodo) if the code goes
> to GitHub.

------------------------------------------------------------------------

## 📦 Data

`data/raw/landmarks.csv` holds the landmark coordinates in pixels of the
photographs, one row per specimen and landmark (`specimen`, `landmark`, `X`,
`Y`; y axis pointing down, as in an image), and
`data/raw/landmarks_specimens.csv` one row per specimen (species, site, date,
operator). Landmark numbering follows the FISHMORPH protocol (Brosse et al.
2021): 1–19 anatomical, 20–21 the scale bar, 22/24/25 the midline hinges of
curved specimens. {{REPEATS_SENTENCE}}

`data/metadata.csv` defines every variable of the data and result tables.

------------------------------------------------------------------------

## 🧪 Reproducing the analysis

1.  Open `{{PROJECT}}.Rproj` in RStudio.
2.  Install the packages once: `source("scripts/setup_environment.R")`
    (or let `utils/library.R` install what is missing).
3.  Run the full pipeline:

    ``` r
    source("run_all.R")
    ```

Every script reads its inputs from `data/` and writes its outputs to
`data/processed/` and `results/`, so each can also be run on its own after
`01_DATA_load_and_clean.R`. All parameters (minimum number of individuals per
species, permutations, display options...) are in `utils/parameters.R`.

------------------------------------------------------------------------

## 📌 Methods

The Methods and Results, with their references, are in
`manuscript/Methods_Results.docx`; every number in it is read from
`results/tables/` when the document is knitted.

Main references: Brosse et al. (2021) *Global Ecology and Biogeography* 30:
2330–2336 (FISHMORPH); Villéger et al. (2010) *Ecological Applications* 20:
1512–1522 (the nine ratios); Violle et al. (2012) *Trends in Ecology &
Evolution* 27: 244–252 (intraspecific variability).
