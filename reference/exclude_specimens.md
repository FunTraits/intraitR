# Exclude known-bad specimens (e.g. mismeasured fish) from a landmark data set

Removes one or more specimens from an `"intrait_landmarks"` object (as
returned by
[`read_tps()`](https://funtraits.github.io/intraitR/reference/read_tps.md),
[`read_landmarks_csv()`](https://funtraits.github.io/intraitR/reference/read_landmarks_csv.md),
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md),
or
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md))
or a raw `p x k x n` landmark array, dropping them consistently from the
coordinate array *and* from `$scale`/`$metadata` (if present), and
recording exactly which specimens were removed and why, so the exclusion
is reproducible and does not depend on remembering to repeat a manual
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
(or similar) every time the raw data is reloaded.

## Usage

``` r
exclude_specimens(landmarks, specimen, reason = NA_character_)
```

## Arguments

- landmarks:

  An object of class `"intrait_landmarks"`, or a raw `p x k x n`
  landmark array. Not `"intrait_gpa"` (the output of
  [`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md))
  – see Details.

- specimen:

  Character vector of specimen identifiers (matching
  `dimnames(landmarks$coords)[[3]]`, i.e. the row names used throughout
  the package, such as `rownames(landmarks$metadata)`), or an integer
  vector of positions, to remove. Every name must actually exist; unlike
  a manual `dplyr::filter(Code != "...")`, a typo or formatting mismatch
  (e.g. a leading zero, or `Site` vs `site`) errors immediately instead
  of silently matching (and removing) nothing.

- reason:

  Optional character vector explaining why each specimen in `specimen`
  is excluded (e.g.
  `"visibly mis-measured; landmarks 3-4 and 5-6 collapsed to the same point"`),
  recorded alongside the specimen identifier for a full, reproducible
  audit trail (see Return). Either length 1 (recycled for every
  specimen) or the same length as `specimen`. Defaults to `NA`, i.e.
  unrecorded.

## Value

An object of the same class as `landmarks`, with the specified
specimen(s) removed from `coords` (and from `scale`/`metadata`, if
present). Any `standardization_log`/`correction_log`/`corrected`/
`orientation_log` attribute already present on `coords` (from an earlier
[`standardize_orientation()`](https://funtraits.github.io/intraitR/reference/standardize_orientation.md)/[`standardize_geometry()`](https://funtraits.github.io/intraitR/reference/standardize_geometry.md)/
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md)/[`correct_geometry_conventions()`](https://funtraits.github.io/intraitR/reference/correct_geometry_conventions.md)/
[`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md)
call) is filtered the same way, so the audit trail never refers to a
specimen no longer in the data. A `removed_specimens` element
(`intrait_landmarks` input) or attribute (raw array input) records every
exclusion made so far as a `data.frame` with columns `specimen`,
`reason`; calling `exclude_specimens()` again on an already-cleaned
object accumulates into the same record rather than replacing it, so the
complete history of exclusions stays attached to the data, matching the
same spirit as
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)'s
`remove_outliers`/`$removed_outliers`.

## Details

Intended to be called right after loading raw landmark data (e.g.
immediately after
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md)
or
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)),
once a specimen has been confirmed – e.g. via
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md)
(`rule = "check_geometry"`), or the non-finite-ratio error from
[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)/
[`fishmorph_ratios()`](https://funtraits.github.io/intraitR/reference/fishmorph_ratios.md)
– to be a genuine measurement/digitization error rather than a real, if
unusual, morphology; every downstream function in the package
([`fishmorph_segments()`](https://funtraits.github.io/intraitR/reference/fishmorph_segments.md),
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
[`correct_geometry()`](https://funtraits.github.io/intraitR/reference/correct_geometry.md),
...) then simply never sees it, rather than relying on filtering
`segments`/`ratios`/[`trait_space()`](https://funtraits.github.io/intraitR/reference/trait_space.md)
output after the fact at every stage of the pipeline (easy to forget to
repeat consistently, and too late for any function – like
[`standardize_geometry()`](https://funtraits.github.io/intraitR/reference/standardize_geometry.md)
or
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
– whose result for the *other*, retained specimens can itself depend on
which specimens were included).

Not supported for `"intrait_gpa"` objects (the output of
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)):
Procrustes alignment is computed jointly across every specimen supplied
to
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md),
so a mis-digitized specimen can distort the consensus shape (and hence
every other specimen's alignment to it); simply deleting its row from an
already-aligned `coords` array afterwards does not undo that distortion.
Call `exclude_specimens()` *before*
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
instead (on the raw digitized landmarks), or use
[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)'s
own `remove_outliers = TRUE`, which re-runs
[`geomorph::gpagen()`](https://rdrr.io/pkg/geomorph/man/gpagen.html) on
the cleaned sample and records the exclusion in `$removed_outliers`.

## See also

[`gpa_fish()`](https://funtraits.github.io/intraitR/reference/gpa_fish.md)
(`remove_outliers`, for exclusions decided *after* Procrustes
alignment),
[`detect_outliers()`](https://funtraits.github.io/intraitR/reference/detect_outliers.md),
[`correct_landmarks()`](https://funtraits.github.io/intraitR/reference/correct_landmarks.md)
(`rule = "check_geometry"`),
[`plot_fishmorph_points()`](https://funtraits.github.io/intraitR/reference/plot_fishmorph_points.md),
[`load_t26_saudrune_landmarks()`](https://funtraits.github.io/intraitR/reference/load_t26_saudrune_landmarks.md),
[`read_landmarks_xlsx()`](https://funtraits.github.io/intraitR/reference/read_landmarks_xlsx.md)

## Examples

``` r
fish <- load_t26_saudrune_landmarks()

# after visually confirming these two specimens are mismeasured (not
# just morphologically unusual), remove them right after loading, so
# every downstream step (fishmorph_segments(), gpa_fish(), ...) is
# computed without them:
fish_clean <- exclude_specimens(
  fish,
  specimen = c("T-26-0050_Operator_2", "T-26-0230-1_Operator_2"),
  reason = "landmarks 3-4 and/or 5-6 collapsed to the same point (zero-length Bd/Hd)"
)
#> exclude_specimens(): removed 2 specimen(s) (556 remaining, out of 558): T-26-0050_Operator_2, T-26-0230-1_Operator_2.
fish_clean$removed_specimens # full record: which, and why
#>                 specimen
#> 1   T-26-0050_Operator_2
#> 2 T-26-0230-1_Operator_2
#>                                                                     reason
#> 1 landmarks 3-4 and/or 5-6 collapsed to the same point (zero-length Bd/Hd)
#> 2 landmarks 3-4 and/or 5-6 collapsed to the same point (zero-length Bd/Hd)
```
