test_that("correct_allometry() returns an array with the same dimensions", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 10, n_replicates = 1)
  gpa <- gpa_fish(fish)
  corrected <- correct_allometry(gpa)

  expect_equal(dim(corrected), dim(gpa$coords))
  expect_equal(dimnames(corrected)[[3]], dimnames(gpa$coords)[[3]])
})

test_that("correct_allometry() 'group' method uses species metadata", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 10, n_replicates = 1)
  gpa <- gpa_fish(fish)
  gpa$metadata <- fish$metadata
  corrected <- correct_allometry(gpa, method = "group")

  expect_equal(dim(corrected), dim(gpa$coords))
})

test_that("correct_allometry() errors when group metadata is missing", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  gpa$metadata <- NULL
  expect_error(correct_allometry(gpa, method = "group"), "requires `groups`")
})
