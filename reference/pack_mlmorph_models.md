# Package the prediction models for distribution

For the maintainer: copies, from an ml-morph folder, exactly what
prediction needs – the ONNX networks (global localisation, fine
landmarks, ruler, ruler period, and the three regional refinements) with
their parameter files and the canonical frame of the training set – into
a zip with a manifest (`MANIFEST.tsv`: every file, its size and md5;
`VERSION`). The training checkpoints and datasets are left out (a few
hundred MB instead of several GB).

## Usage

``` r
pack_mlmorph_models(
  mlmorph_dir,
  version,
  out_dir = ".",
  refine = TRUE,
  package_dir = NULL
)
```

## Arguments

- mlmorph_dir:

  The ml-morph folder holding the `mlmorph_run_*` models.

- version:

  Version of the bundle (`"1"`, `"2"`, ...).

- out_dir:

  Where the zip is written.

- refine:

  Include the three regional refinement networks (used by default by the
  prediction when present; ~140 MB).

- package_dir:

  Optional: the source folder of intraitR, whose `R/mlmorph_models.R`
  gets the version, file name and checksum.

## Value

Invisibly, the path of the zip.

## Details

Publish the zip as an asset of a GitHub release of intraitR tagged
`models-v<version>`. With `package_dir`, the source of intraitR is
updated so that this version of the package installs this version of the
models
([`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md));
otherwise the lines to paste are printed.

## See also

[`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pack_mlmorph_models("~/ml_morph", version = "1", out_dir = "~/Desktop",
                    package_dir = "~/Packages/intraitR")
} # }
```
