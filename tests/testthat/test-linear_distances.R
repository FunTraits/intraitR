test_that("linear_distances() computes correct Euclidean distances", {
  A <- array(0, dim = c(3, 2, 2), dimnames = list(NULL, c("X", "Y"), c("s1", "s2")))
  A[, , "s1"] <- rbind(c(0, 0), c(3, 4), c(0, 0))
  A[, , "s2"] <- rbind(c(0, 0), c(6, 8), c(0, 0))

  d <- linear_distances(A, list(D12 = c(1, 2)))
  expect_equal(d["s1", "D12"], 5)
  expect_equal(d["s2", "D12"], 10)
})

test_that("linear_distances() applies scale factors", {
  A <- array(0, dim = c(2, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A[, , "s1"] <- rbind(c(0, 0), c(10, 0))
  d <- linear_distances(A, list(D = c(1, 2)), scale = c(s1 = 0.1))
  expect_equal(d["s1", "D"], 1)
})

test_that("linear_distances() errors on out-of-range landmark indices", {
  A <- array(0, dim = c(2, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  expect_error(linear_distances(A, list(D = c(1, 5))), "between 1 and")
})

test_that("linear_distances() auto-names unnamed pairs", {
  A <- array(0, dim = c(3, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A[, , "s1"] <- rbind(c(0, 0), c(1, 0), c(0, 1))
  d <- linear_distances(A, list(c(1, 2)))
  expect_true("lm1_lm2" %in% names(d))
})
