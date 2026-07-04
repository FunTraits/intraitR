make_oriented_array <- function(specimen_names = "s1") {
  # A minimal array with landmarks 1-4 placed in the target orientation:
  # snout (1) left of caudal fin base (2); bottom of body (4) below its
  # top (3). Other landmarks are irrelevant to this function and left at
  # an arbitrary but distinct position.
  p <- 21
  n <- length(specimen_names)
  A <- array(0, dim = c(p, 2, n), dimnames = list(NULL, c("X", "Y"), specimen_names))
  pts <- list(`1` = c(0, 50), `2` = c(100, 50), `3` = c(50, 80), `4` = c(50, 20))
  for (i in as.integer(names(pts))) {
    for (s in seq_len(n)) A[i, , s] <- pts[[as.character(i)]]
  }
  for (i in 5:21) {
    for (s in seq_len(n)) A[i, , s] <- c(i * 5, i * 3)
  }
  A
}

test_that("standardize_orientation() leaves an already correctly-oriented specimen untouched", {
  A <- make_oriented_array()
  expect_message(out <- standardize_orientation(A), "0 of 1")
  expect_equal(out, A, ignore_attr = TRUE)
  log <- attr(out, "orientation_log")
  expect_s3_class(log, "data.frame")
  expect_false(log$flipped_x)
  expect_false(log$flipped_y)
})

test_that("standardize_orientation() mirrors a head-right specimen horizontally", {
  A <- make_oriented_array()
  A[1, "X", 1] <- 100 # snout now to the right of the tail
  A[2, "X", 1] <- 0

  expect_message(out <- standardize_orientation(A), "mirrored")
  log <- attr(out, "orientation_log")
  expect_true(log$flipped_x)
  expect_false(log$flipped_y)
  expect_true(out[1, "X", 1] < out[2, "X", 1]) # snout now left of the tail
  # Y untouched
  expect_equal(out[, "Y", 1], A[, "Y", 1])
})

test_that("standardize_orientation() mirrors an upside-down specimen vertically", {
  A <- make_oriented_array()
  A[3, "Y", 1] <- 20 # top of body now below its bottom
  A[4, "Y", 1] <- 80

  expect_message(out <- standardize_orientation(A), "mirrored")
  log <- attr(out, "orientation_log")
  expect_false(log$flipped_x)
  expect_true(log$flipped_y)
  expect_true(out[4, "Y", 1] < out[3, "Y", 1]) # bottom now below the top
  expect_equal(out[, "X", 1], A[, "X", 1])
})

test_that("standardize_orientation() flips both axes when both are wrong", {
  A <- make_oriented_array()
  A[1, "X", 1] <- 100; A[2, "X", 1] <- 0
  A[3, "Y", 1] <- 20; A[4, "Y", 1] <- 80

  out <- suppressMessages(standardize_orientation(A))
  log <- attr(out, "orientation_log")
  expect_true(log$flipped_x)
  expect_true(log$flipped_y)
  expect_true(out[1, "X", 1] < out[2, "X", 1])
  expect_true(out[4, "Y", 1] < out[3, "Y", 1])
})

test_that("standardize_orientation() checks each specimen of a multi-specimen array independently", {
  A <- make_oriented_array(c("s1", "s2"))
  A[1, "X", "s2"] <- 100
  A[2, "X", "s2"] <- 0

  out <- suppressMessages(standardize_orientation(A))
  log <- attr(out, "orientation_log")
  expect_false(log$flipped_x[log$specimen == "s1"])
  expect_true(log$flipped_x[log$specimen == "s2"])
  expect_equal(out[, , "s1"], A[, , "s1"])
})

test_that("standardize_orientation() works on a subset of specimens via `specimen`", {
  A <- make_oriented_array(c("s1", "s2"))
  A[1, "X", "s2"] <- 100; A[2, "X", "s2"] <- 0
  A[1, "X", "s1"] <- 100; A[2, "X", "s1"] <- 0 # s1 also needs flipping, but excluded

  out <- suppressMessages(standardize_orientation(A, specimen = "s2"))
  expect_true(out[1, "X", "s2"] < out[2, "X", "s2"])
  expect_equal(out[, , "s1"], A[, , "s1"]) # untouched: not in `specimen`
})

test_that("standardize_orientation() warns and skips checks when landmarks 1-4 are missing", {
  A <- make_oriented_array()
  A[1, , 1] <- NA_real_

  expect_warning(out <- suppressMessages(standardize_orientation(A)), "missing landmarks")
  # dorsal-ventral check still applied normally
  expect_equal(out[3:4, , 1], A[3:4, , 1])
})

test_that("standardize_orientation() warns when applied to an intrait_gpa object", {
  A <- make_oriented_array()
  gpa_obj <- structure(list(coords = A, consensus = A[, , 1]), class = "intrait_gpa")
  expect_warning(suppressMessages(standardize_orientation(gpa_obj)), "intrait_gpa")
})

test_that("standardize_orientation() errors on non-2D arrays or too few landmarks", {
  A3d <- array(0, dim = c(21, 3, 1))
  expect_error(standardize_orientation(A3d), "two-dimensional")

  A_small <- array(0, dim = c(2, 2, 1), dimnames = list(NULL, NULL, "s1"))
  expect_error(standardize_orientation(A_small), "landmarks 1-4")
})
