test_that("intraspecific_variability() computes shape disparity and trait CV", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 10, n_replicates = 1)
  gpa <- gpa_fish(fish)
  distances <- list(SL = c(1, 7), BD = c(3, 10))
  ratios <- morpho_ratios(fish, distances, norm_by = "SL")

  iv <- intraspecific_variability(
    gpa = gpa, groups = fish$metadata$species,
    traits = ratios[, "BD_ratio", drop = FALSE], iter = 49
  )

  expect_s3_class(iv, "intrait_variability")
  expect_false(is.null(iv$shape_disparity))
  expect_false(is.null(iv$trait_cv))
  expect_true(all(c("group", "trait", "cv_percent") %in% names(iv$trait_cv)))
})

test_that("intraspecific_variability() works with traits only", {
  traits <- data.frame(x = c(1, 2, 3, 10, 11, 12))
  groups <- rep(c("A", "B"), each = 3)
  iv <- intraspecific_variability(groups = groups, traits = traits)

  expect_null(iv$shape_disparity)
  expect_equal(nrow(iv$trait_cv), 2)
})

test_that("intraspecific_variability() errors without gpa or traits", {
  expect_error(intraspecific_variability(groups = c("A", "B")), "Supply at least one")
})
