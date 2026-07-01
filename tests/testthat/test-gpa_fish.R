test_that("gpa_fish() runs a Procrustes superimposition and preserves metadata", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)

  expect_s3_class(gpa, "intrait_gpa")
  expect_equal(dim(gpa$coords), dim(fish$coords))
  expect_length(gpa$Csize, dim(fish$coords)[3])
  expect_true(all(gpa$Csize > 0))
  expect_identical(gpa$metadata, fish$metadata)
})

test_that("print and summary methods for intrait_gpa do not error", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)

  expect_output(print(gpa), "intrait_gpa")
  expect_s3_class(summary(gpa), "summary.intrait_gpa")
})

test_that("gpa_fish() rejects invalid input", {
  expect_error(gpa_fish(matrix(1:4, 2, 2)), "must be an object returned")
})
