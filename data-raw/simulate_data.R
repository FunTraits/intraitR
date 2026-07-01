# Optional: bake a static example data set into data/fish_landmarks.rda
#
# This script is not run automatically (data-raw/ is excluded from the
# built package via .Rbuildignore). Run it once, interactively, if you
# would like to ship a pre-computed `fish_landmarks` data set with the
# package (documented in R/data.R) instead of relying on
# simulate_fish_landmarks() being called at example/vignette run time.
#
# usethis::use_data() takes care of saving with the compression settings
# CRAN expects and of updating DESCRIPTION accordingly.

fish_landmarks <- intraitR::simulate_fish_landmarks(
  n_per_species = 20,
  n_replicates = 3,
  seed = 123
)

usethis::use_data(fish_landmarks, overwrite = TRUE)

# After running this script:
#   1. Uncomment / add a roxygen @docType data block for `fish_landmarks`
#      in R/data.R (a template is provided there, commented out).
#   2. Run devtools::document() again to refresh man/fish_landmarks.Rd.
#   3. Consider referencing `fish_landmarks` instead of
#      simulate_fish_landmarks() in the vignette for a fully static,
#      reproducible example.
