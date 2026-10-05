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

test_that("plot_landmarks() overlays a background_image without error", {
  testthat::skip_if_not_installed("png")
  fish <- simulate_fish_landmarks(n_per_species = 2, n_replicates = 1)
  img_path <- tempfile(fileext = ".png")
  png::writePNG(array(0.5, dim = c(20, 30, 3)), img_path)
  on.exit(unlink(img_path))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(
    plot_landmarks(fish, specimen = 1, background_image = img_path),
    NA
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_landmarks() errors clearly when background_image is missing", {
  fish <- simulate_fish_landmarks(n_per_species = 2, n_replicates = 1)
  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(
    plot_landmarks(fish, specimen = 1, background_image = "does_not_exist.jpg"),
    "not found"
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_landmarks() warns when background_image is used on a GPA-aligned object", {
  testthat::skip_if_not_installed("png")
  fish <- simulate_fish_landmarks(n_per_species = 2, n_replicates = 1)
  gpa <- gpa_fish(fish)
  img_path <- tempfile(fileext = ".png")
  png::writePNG(array(0.5, dim = c(20, 30, 3)), img_path)
  on.exit(unlink(img_path))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_warning(
    plot_landmarks(gpa, specimen = 1, background_image = img_path),
    "Procrustes"
  )
  grDevices::dev.off()
  unlink(tmp)
})
