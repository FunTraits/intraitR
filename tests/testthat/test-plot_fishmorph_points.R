test_that("plot_fishmorph_points() runs without error", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy <- plot_fishmorph_points(fish, specimen = 1)
  grDevices::dev.off()
  unlink(tmp)

  expect_equal(dim(xy), c(21, 2))
})

test_that("plot_fishmorph_points() errors below 21 landmarks", {
  A <- array(0, dim = c(10, 2, 1))
  expect_error(plot_fishmorph_points(A), "at least 21 landmarks")
})
