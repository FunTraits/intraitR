test_that("simulate_fish_landmarks() returns the expected structure", {
  fish <- simulate_fish_landmarks(n_per_species = 4, species = c("A", "B"), n_landmarks = 6, n_replicates = 2)

  expect_s3_class(fish, "intrait_landmarks")
  expect_equal(dim(fish$coords), c(6, 2, 4 * 2 * 2))
  expect_equal(nrow(fish$metadata), 4 * 2 * 2)
  expect_setequal(unique(fish$metadata$species), c("A", "B"))
  expect_true(all(fish$scale == 1))
})

test_that("simulate_fish_landmarks() is reproducible with the same seed", {
  fish1 <- simulate_fish_landmarks(n_per_species = 3, seed = 42)
  fish2 <- simulate_fish_landmarks(n_per_species = 3, seed = 42)
  expect_equal(fish1$coords, fish2$coords)
})

test_that("simulate_fish_landmarks() differs across seeds", {
  fish1 <- simulate_fish_landmarks(n_per_species = 3, seed = 1)
  fish2 <- simulate_fish_landmarks(n_per_species = 3, seed = 2)
  expect_false(isTRUE(all.equal(fish1$coords, fish2$coords)))
})
