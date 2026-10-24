#-------------------------------------------------------------------------------
# 05_STAT_shape_disparity.R — Shape disparity per species
#
# Procrustes variance per species and pairwise permutation tests
# (intraspecific_variability -> geomorph::morphol.disparity;
# PARAMS$shape_disparity_iter permutations).
#
# Prerequisites:
#   - data/processed/gpa.rds
#
# Output:
#   - results/tables/Table9_shape_disparity.csv
#   - results/tables/TableS6_shape_disparity_pairwise.csv
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

gpa <- readRDS("data/processed/gpa.rds")
sp <- gpa$metadata$species
if (length(unique(sp)) < 2) {
  message("Fewer than two species: no shape disparity test.")
} else {
  sd <- intraspecific_variability(gpa = gpa, groups = sp, iter = PARAMS$shape_disparity_iter)
  md <- sd$shape_disparity
  pv <- if (!is.null(md$Procrustes.var)) md$Procrustes.var else md[[1]]
  n_sp <- table(sp)
  write_table(data.frame(species = names(pv), n = as.integer(n_sp[names(pv)]),
                         procrustes_variance = unname(pv)),
              "Table9_shape_disparity")
  if (!is.null(md$PV.dist) && !is.null(md$PV.dist.Pval)) {
    pw <- merge(pairwise_long(as.matrix(md$PV.dist), "abs_difference"),
                pairwise_long(as.matrix(md$PV.dist.Pval), "p_value"))
    pw$p_holm <- stats::p.adjust(pw$p_value, method = "holm")
    write_table(pw[order(pw$p_value), ], "TableS6_shape_disparity_pairwise")
  }
}
