test_that("simulate_fishmorph_points() returns 21 landmarks by default", {
  fish <- simulate_fishmorph_points(n_per_species = 4, species = c("A", "B"), n_replicates = 2)

  expect_s3_class(fish, "intrait_landmarks")
  expect_equal(dim(fish$coords)[1], 21)
  expect_equal(dim(fish$coords)[2], 2)
  expect_equal(dim(fish$coords)[3], 4 * 2 * 2)
  expect_null(fish$scale)
  expect_setequal(unique(fish$metadata$species), c("A", "B"))
})

test_that("simulate_fishmorph_points() adds a 22nd landmark when curvature = TRUE", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1, curvature = TRUE)
  expect_equal(dim(fish$coords)[1], 22)
})

test_that("simulate_fishmorph_points() is reproducible with the same seed", {
  fish1 <- simulate_fishmorph_points(n_per_species = 3, seed = 7)
  fish2 <- simulate_fishmorph_points(n_per_species = 3, seed = 7)
  expect_equal(fish1$coords, fish2$coords)
})

test_that("simulate_fishmorph_points() produces a usable scale bar", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1, scale_cm = 2, px_per_cm = 10)
  seg <- fishmorph_segments(fish, scale_cm = 2)
  expect_true(all(seg$Bl > 0))
  expect_false(anyNA(seg$Bl))
})
