#-------------------------------------------------------------------------------
# 03_FIGURE_itv.R — Intraspecific vs interspecific trait variability
#
# Partition of the variance of each ratio into a between-species and a
# within-species (ITV) component (itv_index; one-way sum-of-squares identity,
# Violle et al. 2012; de Bello et al. 2011). When PARAMS$itv_nested is
# "site" and at least one species was sampled at several sites, the ITV is
# further split into between-site (within species) and within-site parts.
# The multivariate summary adds the sums of squares of the standardised traits.
#
# Prerequisites:
#   - data/processed/traits_analysed.csv
#
# Output:
#   - results/figures/Fig3_itv_partition.png / .pdf
#   - results/tables/Table6_itv_partition.csv
#   - results/tables/Table6b_itv_multivariate.csv
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

tr <- read_traits()
if (length(unique(tr$species)) < 2) {
  message("Fewer than two species: no variance partition.")
} else {
  nested <- NULL
  if (identical(PARAMS$itv_nested, "site") && !is.null(tr$data$site)) {
    sites_per_sp <- tapply(tr$data$site, tr$species, function(s) length(unique(s)))
    if (any(sites_per_sp > 1)) nested <- tr$data$site
  }
  itv <- itv_index(tr$x, groups = tr$species, nested = nested)
  saveRDS(itv, "data/processed/itv_index.rds")
  write_table(itv$per_trait, "Table6_itv_partition")
  write_table(itv$multivariate, "Table6b_itv_multivariate")
  save_figure("Fig3_itv_partition", function() plot(itv))
}
