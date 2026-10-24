#-------------------------------------------------------------------------------
# 03_FIGURE_trait_space.R — Functional trait space of the sample
#
# Principal component analysis of the nine log10(x + 1)-transformed and
# standardised ratios (trait_space), species as groups; within-species
# outliers are screened (median + 3 MAD of the distance to the group
# centroid) and, if PARAMS$ts_remove_outliers, removed.
#
# Prerequisites:
#   - data/processed/traits_analysed.csv
#
# Output:
#   - results/figures/Fig1_trait_space.png / .pdf
#   - results/tables/Table3_trait_space_axes.csv
#   - results/tables/TableS2_trait_space_loadings.csv
#   - results/tables/TableS3_trait_space_outliers.csv
#   - data/processed/trait_space.rds
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

tr <- read_traits()

# ============================================================================
# 1. Ordination ---------------------------------------------------------------
# ============================================================================
ts <- trait_space(tr$x, groups = tr$species, axes = PARAMS$ts_axes,
                  remove_outliers = PARAMS$ts_remove_outliers)
saveRDS(ts, "data/processed/trait_space.rds")

# Variance carried by every axis (the PCA of the standardised matrix ts$X)
ev <- stats::prcomp(ts$X, center = TRUE, scale. = FALSE)$sdev^2
axes_tab <- data.frame(axis = paste0("PC", seq_along(ev)),
                       eigenvalue = ev,
                       pct_variance = 100 * ev / sum(ev),
                       cumulative_pct = cumsum(100 * ev / sum(ev)))
write_table(axes_tab, "Table3_trait_space_axes")
L <- as.data.frame(ts$loadings); L <- cbind(trait = rownames(L), L)
write_table(L, "TableS2_trait_space_loadings")
os <- ts$outlier_screen
if (!is.null(os)) {
  os <- cbind(specimen = rownames(os), os)
  write_table(os[os$flagged %in% TRUE, , drop = FALSE], "TableS3_trait_space_outliers")
}

# ============================================================================
# 2. Figure -------------------------------------------------------------------
# ============================================================================
save_figure("Fig1_trait_space",
            function() plot(ts, style = PARAMS$ts_style, legend_italic = TRUE))
