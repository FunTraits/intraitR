#-------------------------------------------------------------------------------
# 03_FIGURE_itv_accumulation.R — Within-species variability vs sampling effort
#
# Rarefaction of the within-species variability (itv_accumulation): for each
# species and each sub-sample size n = 2 ... N, PARAMS$acc_n_perm sub-samples
# of n individuals are drawn without replacement and the metric
# PARAMS$acc_metric is computed on the nine ratios (log10(x + 1)-transformed;
# for "variance", standardised on the pooled sample and summed over traits).
# For a dispersion metric (variance, sd, cv) n* is the smallest n beyond which
# the half-width of the resampling band, relative to the full-sample value,
# stays at or below PARAMS$acc_conv_tol (precision of the estimate); for
# "range", n* is the size reaching PARAMS$acc_asymptote of the fitted
# asymptote.
#
# Prerequisites:
#   - data/processed/traits_analysed.csv
#
# Output:
#   - results/figures/Fig4_itv_accumulation.png / .pdf
#   - results/tables/Table7_itv_accumulation.csv
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

tr <- read_traits()
acc <- itv_accumulation(tr$x, groups = tr$species, metric = PARAMS$acc_metric,
                        n_perm = PARAMS$acc_n_perm, conv_tol = PARAMS$acc_conv_tol,
                        asymptote_prop = PARAMS$acc_asymptote,
                        min_n = PARAMS$min_n, log_transform = TRUE,
                        seed = PARAMS$seed)
saveRDS(acc, "data/processed/itv_accumulation.rds")
write_table(acc$summary, "Table7_itv_accumulation")
save_figure("Fig4_itv_accumulation", function() plot(acc))
