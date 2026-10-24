#-------------------------------------------------------------------------------
# 03_FIGURE_fishmorph_projection.R — The sample in the global FISHMORPH space
#
# The specimens are projected, without refitting, into the PCA of the
# FISHMORPH database (species means of the nine ratios of the world's
# freshwater fishes; Brosse et al. 2021) with project_fishmorph(). The
# proportion of the global space occupied by each species and by the whole
# sample (convex-hull volume on the first two axes, and range of each ratio)
# is returned by the bundled itv_proportion().
#
# Prerequisites:
#   - data/processed/traits_analysed.csv
#
# Output:
#   - results/figures/Fig2_fishmorph_projection.png / .pdf
#   - results/tables/Table5_fishmorph_space_occupancy.csv
#   - results/tables/TableS5_fishmorph_trait_ranges.csv
#   - data/processed/fishmorph_projection.rds
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

tr <- read_traits()

pf <- project_fishmorph(tr$x, groups = tr$species, traits = RATIO_COLS)
saveRDS(pf, "data/processed/fishmorph_projection.rds")

vol <- pf$itv_proportion$volume
vol$pct_global <- 100 * vol$proportion
write_table(vol, "Table5_fishmorph_space_occupancy")
rg <- pf$itv_proportion$trait
write_table(rg, "TableS5_fishmorph_trait_ranges")
write_table(data.frame(axis = names(pf$var_explained), pct_variance = unname(pf$var_explained),
                       n_reference_species = pf$n_reference),
            "TableS5b_fishmorph_axes")

save_figure("Fig2_fishmorph_projection",
            function() plot(pf, style = PARAMS$pf_style,
                            itv_reference = PARAMS$pf_itv_reference,
                            arrows = PARAMS$pf_arrows))
