test_that("load_fishmorph_phylogeny() loads the bundled tree", {
  tree <- load_fishmorph_phylogeny()
  expect_s3_class(tree, "phylo")
  expect_true(all(c("edge", "edge.length", "Nnode", "tip.label") %in% names(tree)))
  expect_true(length(tree$tip.label) > 1000)
  expect_true(nrow(tree$edge) > 0)
})

test_that("load_fishmorph_phylogeny() tip labels use the dot separator", {
  tree <- load_fishmorph_phylogeny()
  expect_true(any(grepl(".", tree$tip.label, fixed = TRUE)))
})

test_that("load_fishmorph_phylogeny() works with phylo_pcoa() end-to-end", {
  testthat::skip_if_not_installed("ape")
  tree <- load_fishmorph_phylogeny()
  some_tips <- gsub("\\.", " ", utils::head(tree$tip.label, 5))
  pp <- suppressWarnings(phylo_pcoa(tree, species = some_tips, k = 2))
  expect_s3_class(pp, "intrait_phylopcoa")
  expect_true(nrow(pp$traits) >= 3)
})
