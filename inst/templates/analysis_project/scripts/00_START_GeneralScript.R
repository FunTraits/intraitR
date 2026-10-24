#-------------------------------------------------------------------------------
# 00_START_GeneralScript.R — Environment initialisation
#
# Loads the packages, the analysis parameters and the shared utilities, and
# sets the random seed. Sourced at the top of every analysis script.
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------


# ============================================================================
# 0. Shared utilities ---------------------------------------------------------
# ============================================================================
source("utils/library.R")
source("utils/parameters.R")
source("utils/functions.R")


# ============================================================================
# 1. Global settings ----------------------------------------------------------
# ============================================================================
set.seed(PARAMS$seed)
for (d in c("data/processed", "results/figures", "results/tables"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
