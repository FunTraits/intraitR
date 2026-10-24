#-------------------------------------------------------------------------------
# setup_environment.R — Environment initialisation
#
# Installs the packages needed by the pipeline and records them with renv.
# Run once when setting up the project on a new machine (not run by
# run_all.R). The versions that produced the results are in session_info.txt.
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------


# ============================================================================
# 0. Initialise renv ----------------------------------------------------------
# ============================================================================
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
renv::init(bare = TRUE)


# ============================================================================
# 1. Packages -----------------------------------------------------------------
# ============================================================================
install.packages(c("remotes", "here", "rmarkdown", "knitr", {{CRAN_PACKAGES}}))
remotes::install_github("FunTraits/Rfishmorph")   # used: Rfishmorph {{RFISHMORPH_VERSION}}
remotes::install_github("FunTraits/intraitR")     # used: intraitR {{INTRAITR_VERSION}}


# ============================================================================
# 2. Lockfile -----------------------------------------------------------------
# ============================================================================
renv::snapshot()
