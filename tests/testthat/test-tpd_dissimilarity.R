test_that("tpd_dissimilarity() returns a valid overlap dissimilarity matrix", {
  skip_if_not_installed("TPD")
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))

  d <- suppressMessages(tpd_dissimilarity(
    ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species, n_axes = 2
  ))
  expect_s3_class(d, "intrait_tpd_dissim")

  D <- d$dissimilarity
  S <- length(d$species)
  expect_equal(dim(D), c(S, S))
  # symmetric, zero self-dissimilarity, bounded in [0, 1]
  expect_equal(D, t(D), tolerance = 1e-8)
  expect_true(all(abs(diag(D)) < 1e-6))
  expect_true(all(D >= -1e-8 & D <= 1 + 1e-8))
})

test_that("as.dist() and the print/plot methods work", {
  skip_if_not_installed("TPD")
  fish <- simulate_fishmorph_points(n_per_species = 18, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  d <- suppressMessages(tpd_dissimilarity(
    ratios[, c("BEl", "VEp")], groups = fish$metadata$species, n_axes = 2
  ))

  dd <- as.dist(d)
  expect_s3_class(dd, "dist")
  expect_equal(length(dd), choose(length(d$species), 2))

  expect_output(print(d), "intrait_tpd_dissim")
  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(d), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("tpd_dissimilarity() validates its inputs", {
  skip_if_not_installed("TPD")
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  tr <- ratios[, c("BEl", "VEp", "REs")]

  expect_error(tpd_dissimilarity(tr), "`groups` is required")
  expect_error(tpd_dissimilarity(tr, groups = rep("only_one", nrow(tr))),
               "at least two levels")
  # a group with a single individual cannot get a density
  g <- fish$metadata$species
  g[1] <- "singleton"
  expect_error(suppressMessages(tpd_dissimilarity(tr, groups = g)),
               "at least two individuals")
})

test_that("tpd_dissimilarity() errors informatively when TPD is absent", {
  skip_if(requireNamespace("TPD", quietly = TRUE),
          "TPD is installed; cannot test the missing-package path")
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  expect_error(
    tpd_dissimilarity(ratios[, c("BEl", "VEp")], groups = fish$metadata$species),
    "requires the .*'TPD' package"
  )
})
