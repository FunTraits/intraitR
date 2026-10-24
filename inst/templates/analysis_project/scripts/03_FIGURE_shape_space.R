#-------------------------------------------------------------------------------
# 03_FIGURE_shape_space.R — Shape space (geometric morphometrics)
#
# Generalised Procrustes analysis of the anatomical landmarks of the analysed
# specimens (fishmorph_shape_landmarks, gpa_fish built on geomorph::gpagen;
# Rohlf & Slice 1990), Procrustes-distance outliers flagged (median + 3 MAD)
# and removed if PARAMS$shape_remove_outliers, then a PCA of the aligned
# coordinates (shape_space).
#
# Prerequisites:
#   - data/processed/landmarks_clean.rds, data/processed/traits_analysed.csv
#
# Output:
#   - results/figures/Fig5_shape_space.png / .pdf
#   - results/tables/Table8_shape_space_axes.csv
#   - data/processed/gpa.rds
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

fish <- readRDS("data/processed/landmarks_clean.rds")
tr <- read_traits()
fish <- subset_landmarks(fish, tr$data$specimen)

shape <- fishmorph_shape_landmarks(fish, drop_incomplete = TRUE)
gpa   <- gpa_fish(shape, remove_outliers = PARAMS$shape_remove_outliers)
saveRDS(gpa, "data/processed/gpa.rds")
ss <- shape_space(gpa, groups = gpa$metadata$species)
saveRDS(ss, "data/processed/shape_space.rds")

n <- dim(gpa$coords)[3]
X <- t(matrix(gpa$coords, ncol = n))           # n x (p * k)
ev <- stats::prcomp(X, center = TRUE, scale. = FALSE)$sdev^2
write_table(data.frame(axis = paste0("PC", seq_along(ev)), eigenvalue = ev,
                       pct_variance = 100 * ev / sum(ev),
                       cumulative_pct = cumsum(100 * ev / sum(ev)),
                       n_specimens = n),
            "Table8_shape_space_axes")

save_figure("Fig5_shape_space", function() plot(ss, style = PARAMS$shape_style,
                                                legend_italic = TRUE))
