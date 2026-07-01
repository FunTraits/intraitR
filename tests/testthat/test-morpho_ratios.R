test_that("morpho_ratios() correctly normalises distances", {
  A <- array(0, dim = c(3, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A[, , "s1"] <- rbind(c(0, 0), c(10, 0), c(2, 0))
  distances <- list(SL = c(1, 2), BD = c(1, 3))
  r <- morpho_ratios(A, distances, norm_by = "SL")
  expect_equal(r$BD_ratio, 0.2)
  expect_false("SL_ratio" %in% names(r))
})

test_that("morpho_ratios() errors when norm_by is not in distances", {
  A <- array(0, dim = c(2, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  expect_error(
    morpho_ratios(A, list(SL = c(1, 2)), norm_by = "nope"),
    "is not one of the names"
  )
})

test_that("morpho_ratios() carries over metadata", {
  fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 1)
  distances <- list(SL = c(1, 7), BD = c(3, 10))
  r <- morpho_ratios(fish, distances, norm_by = "SL")
  expect_true("species" %in% names(r))
  expect_equal(nrow(r), dim(fish$coords)[3])
})
