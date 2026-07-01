test_that("measurement_error() computes %ME and repeatability for univariate traits", {
  set.seed(1)
  wide <- data.frame(
    r1 = c(10, 20, 30, 40),
    r2 = c(10.1, 19.9, 30.2, 39.8),
    r3 = c(9.9, 20.1, 29.9, 40.1)
  )
  rownames(wide) <- paste0("ind", 1:4)

  me <- measurement_error(wide, method = "anova")

  expect_s3_class(me, "intrait_measurement_error")
  expect_true(me$percent_measurement_error < 10)
  expect_true(me$repeatability > 0.9)
})

test_that("measurement_error() accepts long-format input", {
  long <- data.frame(
    ind = rep(c("a", "b"), each = 3),
    value = c(10, 10.1, 9.9, 20, 20.2, 19.8)
  )
  me <- measurement_error(long, individual = "ind", method = "anova")
  expect_s3_class(me, "intrait_measurement_error")
})

test_that("measurement_error() runs Procrustes ANOVA for replicated shape data", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 6, n_replicates = 3)
  gpa <- gpa_fish(fish)
  me <- measurement_error(
    gpa, individual = fish$metadata$species, method = "procrustes", iter = 49
  )
  expect_s3_class(me, "intrait_measurement_error")
  expect_false(is.null(me$procD_table))
})

test_that("measurement_error() errors when individual is missing for procrustes method", {
  testthat::skip_if_not_installed("geomorph")
  fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 2)
  gpa <- gpa_fish(fish)
  expect_error(measurement_error(gpa, method = "procrustes"), "`individual`")
})
