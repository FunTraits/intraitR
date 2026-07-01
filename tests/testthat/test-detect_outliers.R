test_that("detect_outliers() flags a deliberately corrupted specimen", {
  testthat::skip_if_not_installed("geomorph")

  set.seed(1)
  fish <- simulate_fish_landmarks(n_per_species = 15, n_replicates = 1)
  # Corrupt one specimen's landmarks with a large, obviously wrong shift,
  # simulating a gross digitization error.
  fish$coords[3, , 1] <- fish$coords[3, , 1] + 50

  gpa <- gpa_fish(fish)
  out <- detect_outliers(gpa, plot = FALSE)

  expect_s3_class(out, "intrait_outliers")
  expect_length(out$procrustes_distance, dim(gpa$coords)[3])
  expect_true(dimnames(gpa$coords)[[3]][1] %in% out$outliers)
  expect_equal(out$rank$specimen[1], dimnames(gpa$coords)[[3]][1])
  expect_true(out$rank$procrustes_distance[1] > out$threshold_value)
})

test_that("detect_outliers() flags nothing unusual on a clean, homogeneous sample", {
  testthat::skip_if_not_installed("geomorph")

  set.seed(2)
  # A single species/population (no between-species shape variance
  # component) so that all Procrustes distances to the consensus reflect
  # only ordinary individual + digitization noise.
  fish <- simulate_fish_landmarks(n_per_species = 30, species = "Species_A", n_replicates = 1)
  gpa <- gpa_fish(fish)
  out <- detect_outliers(gpa, threshold = 4, plot = FALSE)

  expect_s3_class(out, "intrait_outliers")
  # A generous threshold on a genuinely homogeneous simulated sample should
  # flag few or no specimens.
  expect_true(length(out$outliers) <= 2)
})

test_that("detect_outliers() errors on invalid input", {
  expect_error(detect_outliers(list()), "must be an object returned by gpa_fish")
  testthat::skip_if_not_installed("geomorph")
  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  expect_error(detect_outliers(gpa, threshold = -1), "positive number")
})

test_that("detect_outliers() plot = TRUE does not error", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
  gpa <- gpa_fish(fish)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(detect_outliers(gpa, plot = TRUE), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("print.intrait_outliers() prints without error", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
  gpa <- gpa_fish(fish)
  out <- detect_outliers(gpa, plot = FALSE)
  expect_output(print(out), "intrait_outliers")
})
