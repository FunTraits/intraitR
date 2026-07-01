test_that("plot_landmarks() runs without error and returns coordinates invisibly", {
  fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy <- plot_landmarks(fish, specimen = 1)
  grDevices::dev.off()
  unlink(tmp)

  expect_equal(dim(xy), c(dim(fish$coords)[1], 2))
})

test_that("plot_landmarks() errors on unknown specimen name", {
  fish <- simulate_fish_landmarks(n_per_species = 2, n_replicates = 1)
  expect_error(plot_landmarks(fish, specimen = "not_a_specimen"), "not found")
})
