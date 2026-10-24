# Install the prediction models

Downloads the model bundle this version of intraitR was validated with
(a zip attached to the GitHub release `models-v<version>`), checks it,
and installs it in the user's data folder of intraitR. Done once per
machine;
[`digitize_landmarks()`](https://funtraits.github.io/intraitR/reference/digitize_landmarks.md),
[`batch_landmarks()`](https://funtraits.github.io/intraitR/reference/batch_landmarks.md)
and
[`launch_measure_hub()`](https://funtraits.github.io/intraitR/reference/launch_measure_hub.md)
then find the models without `mlmorph_dir`.

## Usage

``` r
install_mlmorph_models(
  version = NULL,
  url = NULL,
  force = FALSE,
  token = Sys.getenv("GITHUB_PAT")
)
```

## Arguments

- version:

  Version of the bundle; `NULL`: the one this version of intraitR names.

- url:

  Where to download from; `NULL`: the release of the package's
  repository. A local path to a zip also works (an internal mirror, a
  USB key).

- force:

  Install again even when already installed.

- token:

  GitHub token, for a bundle published on a PRIVATE repository.

## Value

Invisibly, the folder of the installed models.

## Details

Each file is checked against the manifest of the bundle (md5), and the
zip against the checksum this version of the package knows: a truncated
or altered download is refused, not installed.

## See also

[`mlmorph_models_info()`](https://funtraits.github.io/intraitR/reference/mlmorph_models_info.md),
[`install_mlmorph_python()`](https://funtraits.github.io/intraitR/reference/install_mlmorph_python.md),
[`pack_mlmorph_models()`](https://funtraits.github.io/intraitR/reference/pack_mlmorph_models.md)

## Examples

``` r
if (FALSE) { # \dontrun{
install_mlmorph_models()
mlmorph_models_info()
} # }
```
