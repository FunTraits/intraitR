## -----------------------------------------------------------------------
## pipeline_T26_saudrune.R
##
## Complete intraitR pipeline applied to the T-26 La Saudrune electrofishing
## survey (Adour-Garonne basin, France, 21 April 2026): the first REAL
## (non-simulated) worked example shipped with the package. Every stage of
## the intraitR workflow is exercised in turn: import -> Generalised
## Procrustes Analysis -> digitization quality control -> FISHMORPH linear
## measurements and ratios (Brosse et al., 2021) -> functional trait space
## -> interspecific/intraspecific trait variability -> measurement error
## and digitization error from replicated digitizations -> trait disparity
## among species.
##
## Run with: demo("pipeline_T26_saudrune", package = "intraitR")
## Data documentation: ?load_t26_saudrune
## -----------------------------------------------------------------------

library(intraitR)

## =========================================================================
## 0. Load the data
## =========================================================================
ops    <- load_t26_saudrune("operators")        # 279 fish x 2 operators x 21 landmarks
rep_df <- load_t26_saudrune("repeatability")     # 25 fish x 9-10 replicates x 21 landmarks
ident  <- load_t26_saudrune("identifications")   # species / id_status, one row per fish

cat(sprintf(
  "%d fish digitized by %d operators; %d fish used for the intra-operator repeatability trial\n",
  length(unique(ops$code)), length(unique(ops$operator)), length(unique(rep_df$code))
))
print(table(ident$species, ident$id_status, useNA = "ifany"))

## =========================================================================
## 1. Import + build a per-fish consensus configuration
## =========================================================================
lm_operators <- read_landmarks_csv(ops)   # -> intrait_landmarks, 21 x 2 x 558
cat("Operator-level landmarks:", paste(dim(lm_operators$coords), collapse = " x "), "\n")

# Average the two operators' digitizations per fish into a single
# 'consensus' configuration. intraitR does not yet ship a dedicated
# multi-operator averaging helper, so the consensus array is built here
# directly on the p x k x n geomorph-style array used throughout the
# package (see ?read_landmarks_csv, ?gpa_fish).
codes <- unique(ops$code)
A <- lm_operators$coords
code_of <- sub("_[^_]+$", "", dimnames(A)[[3]])

A_consensus <- array(
  NA_real_, dim = c(dim(A)[1], dim(A)[2], length(codes)),
  dimnames = list(dimnames(A)[[1]], dimnames(A)[[2]], codes)
)
for (code in codes) {
  A_consensus[, , code] <- apply(A[, , code_of == code, drop = FALSE], c(1, 2), mean, na.rm = TRUE)
}

fish_meta <- merge(data.frame(code = codes), ident, by = "code", all.x = TRUE, sort = FALSE)
rownames(fish_meta) <- fish_meta$code
fish_meta <- fish_meta[codes, ]

lm_consensus <- structure(
  list(coords = A_consensus, scale = NULL, metadata = fish_meta),
  class = "intrait_landmarks"
)
cat("Consensus (per-fish) landmarks:", paste(dim(lm_consensus$coords), collapse = " x "), "\n")

## =========================================================================
## 2. FISHMORPH linear measurements and ratios (Brosse et al., 2021)
## =========================================================================
# Landmarks 20-21 are the ends of a 1 cm calibration segment digitized
# next to each fish, so scale_cm = 1 (the default) converts pixels to cm.
# Because lm_consensus carries fish_meta as its `metadata`, both
# fishmorph_segments() and fishmorph_ratios() automatically prepend
# `species`/`id_status`/etc. to their output.
segments <- fishmorph_segments(lm_operators)
ratios <- fishmorph_ratios(segments)

cat("\nFISHMORPH linear measurements (cm), summary:\n")
print(summary(segments[c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")]))
cat("\nMissing values per ratio (%):\n")
ratio_cols <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
print(round(colMeans(is.na(ratios[ratio_cols])) * 100, 1))

## =========================================================================
## 3. Generalised Procrustes Analysis + digitization quality control
## =========================================================================
# Shape analysis uses the 19 anatomical landmarks only (20-21 are the
# scale bar, not shape) and requires a complete configuration.
shape_coords <- lm_consensus$coords[1:19, , ]
complete <- apply(shape_coords, 3, function(x) !anyNA(x))
lm_shape <- structure(
  list(coords = shape_coords[, , complete], scale = NULL, metadata = fish_meta[complete, ]),
  class = "intrait_landmarks"
)
cat(sprintf(
  "\n%d / %d fish have a complete 19-landmark configuration (%.1f%%)\n",
  sum(complete), length(complete), 100 * mean(complete)
))

gpa <- gpa_fish(lm_shape)
print(gpa)

# Naive pooled outlier screen -- kept here deliberately as a cautionary
# example: with 8 taxonomically distinct species pooled together, a
# global median + 3*MAD Procrustes-distance threshold mostly flags
# genuine interspecific shape diversity, not digitization errors (see
# the manuscript's Discussion for the full argument).
out_pooled <- detect_outliers(gpa, plot = FALSE)
cat(sprintf(
  "\nPooled (multi-species) detect_outliers(): %d / %d flagged -- interpret with caution,\n"
  , length(out_pooled$outliers), length(out_pooled$procrustes_distance)
))
cat("see ?detect_outliers and the manuscript Discussion: run within a single species instead.\n")

# Correct usage: run detect_outliers() *within* a single, well-sampled
# species (Gobio occitaniae, the dominant species in this sample).
gobio_idx <- which(lm_shape$metadata$species == "Gobio occitaniae")
lm_gobio <- structure(
  list(coords = lm_shape$coords[, , gobio_idx], scale = NULL,
       metadata = lm_shape$metadata[gobio_idx, ]),
  class = "intrait_landmarks"
)
gpa_gobio <- gpa_fish(lm_gobio)
out_gobio <- detect_outliers(gpa_gobio, plot = TRUE)
print(out_gobio)

## =========================================================================
## 4. Functional trait space on the FISHMORPH ratios
## =========================================================================
# Built here on the FULL cleaned data set (all 279 fish, no manual removal
# of individuals): trait_space()'s default flag_outliers = TRUE screens for
# potential within-species errors automatically (see ?trait_space) instead,
# so that any specimen distorting the ordination is flagged, inspected, and
# excluded (or not) transparently -- rather than removed ad hoc beforehand.
ts <- trait_space(ratios[ratio_cols], groups = ratios$species, na_action = "omit",remove_outliers = F)
print(ts)   # lists any flagged within-species outlier(s), if present

# Inspect the full outlier screen (one row per specimen): every species with
# >= outlier_min_n (default 5) specimens gets a group-specific median/MAD
# threshold; specimens in smaller species get a distance but are not
# flagged (too few points for a reliable threshold).
print(utils::head(ts$outlier_screen[order(-ts$outlier_screen$distance), ], 10))

plot(ts, style = "hull", legend_title = "Species", legend_italic = TRUE,
     abbreviate_species = TRUE)

# If any specimen was flagged above, visually inspect it before deciding
# whether to exclude it (never drop a flagged specimen purely because
# trait_space() flagged it -- confirm the issue first, e.g. a genuinely
# misplaced landmark or a likely misidentification):
flagged_codes <- rownames(ts$outlier_screen)[which(ts$outlier_screen$flagged)]
if (length(flagged_codes) > 0) {
  cat("\nFlagged specimen(s) to inspect visually:", paste(flagged_codes, collapse = ", "), "\n")
  # e.g. plot_fishmorph_points(lm_consensus, specimen = flagged_codes[1])
}

# na_action = "missforest" imputes the ~25-38% of REs/RMl/BLs values that
# are missing (rather than dropping ~26% of specimens outright) using
# random-forest imputation; compare with the "omit" ordination above.
if (requireNamespace("missForest", quietly = TRUE)) {
  set.seed(2026)
  ts_imputed <- trait_space(ratios[ratio_cols], groups = ratios$species,
                             na_action = "missforest")
  print(ts_imputed)
}

## =========================================================================
## 5. Interspecific vs. intraspecific trait variability (itv_index)
## =========================================================================
complete_ratios <- stats::complete.cases(ratios[ratio_cols])
itv <- itv_index(ratios[complete_ratios, ratio_cols], groups = ratios$species[complete_ratios])
print(itv)
plot(itv)

## =========================================================================
## 6. Measurement error (Bailey & Byrnes, 1990) from the repeatability
##    trial: 25 individuals x 9-10 independent replicate digitizations
## =========================================================================
lm_rep <- read_landmarks_csv(rep_df)
segments_rep <- fishmorph_segments(lm_rep)
rep_meta <- unique(rep_df[c("specimen", "code")])
individual_rep <- rep_meta$code[match(rownames(segments_rep), rep_meta$specimen)]

me_bl <- measurement_error(
  data.frame(individual = individual_rep, value = segments_rep$Bl),
  individual = "individual", method = "anova"
)
print(me_bl)   # body length (Bl): percent measurement error and repeatability R

## =========================================================================
## 7. Digitization (operator) error, landmark by landmark (Boutic, 2026
##    protocol), on the same repeatability trial
##    Landmarks 20-21 are the embedded 1 cm scale-bar calibration segment
##    (fishmorph_segments()'s scale_cm conversion), not a biological
##    landmark: they are excluded here so that the bias decomposition only
##    reflects anatomical landmark placement.
## =========================================================================
species_rep <- ident$species[match(individual_rep, ident$code)]
derr <- digitization_error(
  lm_rep, individual = individual_rep, species = species_rep,
  exclude_landmarks = c(20, 21)
)
print(derr)
print(derr$by_landmark)   # landmarks ranked from most (top) to least precise
plot(derr)

## =========================================================================
## 8. Trait disparity: do species differ in overall trait dispersion?
## =========================================================================
td <- trait_disparity(ts, iter = 999)
print(td)

## =========================================================================
## 9. Morphological (shape) space
## =========================================================================
ms <- morpho_space(gpa, groups = lm_shape$metadata$species)
plot(ms, style = "spider", legend_title = "Species", legend_italic = TRUE,
     abbreviate_species = TRUE)

## =========================================================================
## 10. Bootstrap-based functional space estimate (Bertrand, 2026): does
##     representing species by individuals (rather than by their centroid)
##     inflate the estimated functional space?
## =========================================================================
if (requireNamespace("geometry", quietly = TRUE)) {
  # n_axes = 2 keeps this demo fast and matches the PC1-PC2 plots above;
  # Bertrand (2026) used 8 axes (98% of variance) for the full comparison.
  bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 100)
  print(bf)
  plot(bf)
}

## =========================================================================
## 11. Species-level sensitivity index (Bertrand, 2026): which species
##     drive the individual-vs-centroid difference in functional richness?
## =========================================================================
if (requireNamespace("geometry", quietly = TRUE)) {
  ss <- species_sensitivity(ts, n_axes = 2)
  print(ss)   # top species by |mean % change in functional richness|
  plot(ss)
}
