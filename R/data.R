# This package does not ship a pre-baked binary data set: every example,
# test and vignette instead calls simulate_fish_landmarks() directly,
# which is fast, dependency-free, and fully reproducible via `seed`.
#
# If you would rather ship a static `fish_landmarks` data set (data/
# fish_landmarks.rda), run data-raw/simulate_data.R once and then
# uncomment and adapt the roxygen block below before re-running
# devtools::document().
#
# #' Simulated freshwater fish landmark data set
# #'
# #' A simulated data set of 2D landmark configurations for three
# #' artificial fish "species", produced by
# #' \code{simulate_fish_landmarks(n_per_species = 20, n_replicates = 3,
# #' seed = 123)}. Provided for reproducible examples and teaching; it is
# #' not derived from real specimens.
# #'
# #' @format An object of class \code{"intrait_landmarks"}: a list with
# #'   \code{coords} (a 12 x 2 x 360 array), \code{scale}, and
# #'   \code{metadata} (a data.frame with columns \code{specimen},
# #'   \code{species}, \code{population}, \code{standard_length_mm},
# #'   \code{replicate}).
# #' @source Simulated; see \code{data-raw/simulate_data.R}.
# "fish_landmarks"
