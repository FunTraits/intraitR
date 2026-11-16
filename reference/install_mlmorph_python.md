# A Python environment able to run the prediction models

Creates a virtual environment in the user's data folder of intraitR and
installs what the prediction scripts import: `numpy`, `pandas`,
`opencv-python-headless`, `pillow` and `onnxruntime` (`dlib`, needed
only by the old `.dat` predictors, is not installed). The applications
and
[`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
find this environment without `python =`.

## Usage

``` r
install_mlmorph_python(python = NULL, force = FALSE)
```

## Arguments

- python:

  The Python 3 used to create the environment (3.9 or later).

- force:

  Recreate it even when it exists.

## Value

Invisibly, the path of the environment's Python.

## Details

On Windows, `onnxruntime` needs a recent Microsoft Visual C++
Redistributable (x64; `msvcp140.dll` 14.40 or later): with an older
runtime it crashes on import (status 5, access violation). Install it
first, e.g. `winget install --id Microsoft.VCRedist.2015+.x64 -e`.

## See also

[`install_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_models.md)
