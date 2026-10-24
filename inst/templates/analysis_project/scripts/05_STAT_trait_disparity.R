#-------------------------------------------------------------------------------
# 05_STAT_trait_disparity.R — Differences in trait dispersion between species
#
# Trait variance per species (trace of the covariance matrix of the
# log-transformed, standardised ratios) and pairwise permutation tests of the
# differences (trait_disparity; PARAMS$disparity_iter permutations of the
# species labels). p-values are also given after Holm correction for the
# number of pairs.
#
# Prerequisites:
#   - data/processed/traits_analysed.csv
#
# Output:
#   - results/tables/Table4_trait_disparity.csv
#   - results/tables/TableS4_trait_disparity_pairwise.csv
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

tr <- read_traits()
if (length(unique(tr$species)) < 2) {
  message("Fewer than two species: no disparity test.")
} else {
  td <- trait_disparity(tr$x, groups = tr$species, iter = PARAMS$disparity_iter)
  n_sp <- table(tr$species)
  write_table(data.frame(species = names(td$disparity),
                         n = as.integer(n_sp[names(td$disparity)]),
                         trait_variance = unname(td$disparity)),
              "Table4_trait_disparity")
  pw <- merge(pairwise_long(td$pairwise_diff, "abs_difference"),
              pairwise_long(td$pairwise_p, "p_value"))
  pw$p_holm <- stats::p.adjust(pw$p_value, method = "holm")
  write_table(pw[order(pw$p_value), ], "TableS4_trait_disparity_pairwise")
}
