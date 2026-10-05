test_that("phylo_pcoa() errors on a non-'phylo' tree", {
  expect_error(phylo_pcoa(list(a = 1)), "class .phylo.")
})

test_that("phylo_pcoa() matches species across dot/underscore/space tip-label conventions", {
  # Regression test: the bundled load_fishmorph_phylogeny() tree uses
  # "Genus.species" tip labels, unlike this package's own "Genus species"
  # convention; species-name matching must normalise all three separators.
  testthat::skip_if_not_installed("ape")
  set.seed(9)
  tree <- ape::rcoal(6, tip.label = c(
    "Barbus.barbus", "Gobio.gobio", "Perca.fluviatilis",
    "Squalius.cephalus", "Phoxinus.phoxinus", "Anguilla.anguilla"
  ))
  pp <- phylo_pcoa(tree, species = c("Barbus barbus", "Gobio gobio", "Perca fluviatilis"), k = 2)
  expect_equal(nrow(pp$traits), 3)
  expect_equal(length(pp$dropped_species), 0)
  # tip labels are canonicalised (dots/spaces -> underscore) internally,
  # so the matched species come back in that canonical underscore form
  expect_setequal(pp$traits$species, c("Barbus_barbus", "Gobio_gobio", "Perca_fluviatilis"))
})

test_that("phylo_pcoa() builds axes from an ultrametric coalescent tree", {
  testthat::skip_if_not_installed("ape")
  set.seed(1)
  tree <- ape::rcoal(8, tip.label = paste0("sp_", 1:8))
  pp <- phylo_pcoa(tree, k = 3)

  expect_s3_class(pp, "intrait_phylopcoa")
  expect_equal(pp$k, 3)
  expect_equal(nrow(pp$traits), 8)
  expect_equal(ncol(pp$traits), 4) # species + 3 axes
  expect_named(pp$traits, c("species", "PCoA1", "PCoA2", "PCoA3"))
  expect_length(pp$var_explained, 3)
  expect_equal(length(pp$dropped_species), 0)
})

test_that("phylo_pcoa() output is usable directly as `traits` in trait_space()", {
  testthat::skip_if_not_installed("ape")
  set.seed(2)
  tree <- ape::rcoal(10, tip.label = paste0("sp_", 1:10))
  pp <- phylo_pcoa(tree, k = 2)

  ts_phylo <- trait_space(pp$traits, na_action = "fail", log_transform = FALSE)
  expect_s3_class(ts_phylo, "intrait_traitspace")
  expect_equal(nlevels(ts_phylo$groups), 10)
})

test_that("phylo_pcoa() restricts to a requested species subset and matches space/underscore names", {
  testthat::skip_if_not_installed("ape")
  set.seed(3)
  tree <- ape::rcoal(8, tip.label = paste0("Genus_species", 1:8))
  wanted <- gsub("_", " ", paste0("Genus_species", 1:5)) # space-separated, like a `species` column
  pp <- phylo_pcoa(tree, species = wanted, k = 2)

  expect_equal(nrow(pp$traits), 5)
  expect_equal(length(pp$dropped_species), 0)
})

test_that("phylo_pcoa() warns and reports species absent from the tree", {
  testthat::skip_if_not_installed("ape")
  set.seed(4)
  tree <- ape::rcoal(8, tip.label = paste0("sp_", 1:8))
  wanted <- c(paste0("sp_", 1:8), "not_a_real_species")

  expect_warning(pp <- phylo_pcoa(tree, species = wanted, k = 2), "not found in")
  expect_equal(pp$dropped_species, "not_a_real_species")
})

test_that("phylo_pcoa() errors below 3 matched species", {
  testthat::skip_if_not_installed("ape")
  set.seed(5)
  tree <- ape::rcoal(8, tip.label = paste0("sp_", 1:8))
  expect_error(phylo_pcoa(tree, species = c("sp_1", "sp_2")), "At least 3 species")
})

test_that("phylo_pcoa() errors when `k` exceeds the available positive-eigenvalue axes", {
  testthat::skip_if_not_installed("ape")
  set.seed(6)
  tree <- ape::rcoal(5, tip.label = paste0("sp_", 1:5))
  expect_error(phylo_pcoa(tree, k = 100), "requests more axes")
})

test_that("print.intrait_phylopcoa() prints a summary and returns x invisibly", {
  testthat::skip_if_not_installed("ape")
  set.seed(7)
  tree <- ape::rcoal(6, tip.label = paste0("sp_", 1:6))
  pp <- phylo_pcoa(tree, k = 2)
  expect_output(print(pp), "intrait_phylopcoa")
  expect_output(print(pp), "PCoA1")
  ret <- withVisible(print(pp))
  expect_false(ret$visible)
  expect_identical(ret$value, pp)
})
