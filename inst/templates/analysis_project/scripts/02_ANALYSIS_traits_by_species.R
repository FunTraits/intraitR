#-------------------------------------------------------------------------------
# 02_ANALYSIS_traits_by_species.R — Descriptive statistics of the ratios
#
# Mean, standard deviation, minimum and maximum of the nine FISHMORPH ratios
# per species (summary_traits), and their coefficient of variation per species
# (intraspecific_variability).
#
# Prerequisites:
#   - data/processed/traits_analysed.csv
#
# Output:
#   - results/tables/Table2_traits_by_species.csv
#   - results/tables/TableS1_cv_by_species_trait.csv
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

tr <- read_traits()

# ============================================================================
# 1. Summary per species ------------------------------------------------------
# ============================================================================
s <- summary_traits(tr$x, groups = tr$species)
write_table(s, "Table2_traits_by_species")

# ============================================================================
# 2. Coefficient of variation per species and trait ---------------------------
# ============================================================================
iv <- intraspecific_variability(traits = tr$x, groups = tr$species)
write_table(iv$trait_cv, "TableS1_cv_by_species_trait")
