################################################################################
#  Packages
#
#  intraitR and Rfishmorph come from GitHub (FunTraits); the others from CRAN.
#  Versions used to produce the results are listed in session_info.txt.
################################################################################

packages_cran   <- c({{CRAN_PACKAGES}})
packages_github <- c(intraitR = "FunTraits/intraitR", Rfishmorph = "FunTraits/Rfishmorph")

missing_cran <- packages_cran[!vapply(packages_cran, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_cran)) install.packages(missing_cran)
missing_gh <- names(packages_github)[!vapply(names(packages_github), requireNamespace,
                                             logical(1), quietly = TRUE)]
if (length(missing_gh)) {
  if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
  remotes::install_github(packages_github[missing_gh])
}

suppressPackageStartupMessages(library(intraitR))
