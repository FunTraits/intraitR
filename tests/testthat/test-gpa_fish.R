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

test_that("gpa_fish() flags a deliberately corrupted specimen by default", {
  testthat::skip_if_not_installed("geomorph")

  set.seed(1)
  fish <- simulate_fish_landmarks(n_per_species = 15, n_replicates = 1)
  # Corrupt one specimen's landmarks with a large, obviously wrong shift,
  # simulating a gross digitization error -- same recipe as
  # test-detect_outliers.R, since gpa_fish()'s own screening must agree.
  fish$coords[3, , 1] <- fish$coords[3, , 1] + 50

  gpa <- suppressMessages(gpa_fish(fish))

  expect_false(is.null(gpa$outlier_screen))
  expect_null(gpa$removed_outliers)
  expect_true(dimnames(gpa$coords)[[3]][1] %in% gpa$outlier_screen$specimen[gpa$outlier_screen$flagged])
})

test_that("remove_outliers = TRUE excludes the flagged specimen and re-aligns", {
  testthat::skip_if_not_installed("geomorph")

  set.seed(1)
  fish <- simulate_fish_landmarks(n_per_species = 15, n_replicates = 1)
  fish$coords[3, , 1] <- fish$coords[3, , 1] + 50
  corrupted_name <- dimnames(fish$coords)[[3]][1]

  gpa <- suppressMessages(gpa_fish(fish, remove_outliers = TRUE))

  expect_equal(dim(gpa$coords)[3], dim(fish$coords)[3] - 1)
  expect_false(corrupted_name %in% dimnames(gpa$coords)[[3]])
  expect_equal(nrow(gpa$removed_outliers), 1)
  expect_equal(gpa$removed_outliers$specimen, corrupted_name)
  # Metadata stays aligned with the cleaned coords.
  expect_equal(nrow(gpa$metadata), dim(gpa$coords)[3])
  # The cleaned sample is re-screened; the corrupted specimen is gone so it
  # cannot still be flagged.
  expect_false(any(gpa$outlier_screen$specimen == corrupted_name))
})

test_that("remove_outliers = TRUE is a no-op when nothing is flagged", {
  testthat::skip_if_not_installed("geomorph")

  set.seed(2)
  fish <- simulate_fish_landmarks(n_per_species = 30, species = "Species_A", n_replicates = 1)
  gpa <- gpa_fish(fish, outlier_threshold = 4, remove_outliers = TRUE)

  expect_null(gpa$removed_outliers)
  expect_equal(dim(gpa$coords)[3], dim(fish$coords)[3])
})

test_that("remove_outliers = TRUE requires flag_outliers = TRUE", {
  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  expect_error(
    gpa_fish(fish, flag_outliers = FALSE, remove_outliers = TRUE),
    "requires `flag_outliers = TRUE`"
  )
})

test_that("remove_outliers = TRUE messages about what was removed", {
  testthat::skip_if_not_installed("geomorph")

  set.seed(1)
  fish <- simulate_fish_landmarks(n_per_species = 15, n_replicates = 1)
  fish$coords[3, , 1] <- fish$coords[3, , 1] + 50

  expect_message(
    gpa_fish(fish, remove_outliers = TRUE),
    "remove_outliers: removing 1 specimen"
  )
})

test_that("flag_outliers = FALSE skips screening entirely", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
  gpa <- gpa_fish(fish, flag_outliers = FALSE)

  expect_null(gpa$outlier_screen)
  expect_null(gpa$removed_outliers)
})
