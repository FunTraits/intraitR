make_minimal_fishmorph_array <- function(n_landmarks = 21, scale_dist = 10) {
  # Build a single-specimen 21-landmark array with simple, hand-checkable
  # coordinates: every measurement pair is placed a known Euclidean
  # distance apart, and the scale bar (20-21) spans `scale_dist` units.
  A <- array(0, dim = c(n_landmarks, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  # Bl: 1 -> 2, distance 40
  A[1, , 1] <- c(0, 0)
  A[2, , 1] <- c(40, 0)
  # Bd: 3 -> 4, distance 10
  A[3, , 1] <- c(5, 10)
  A[4, , 1] <- c(5, 0)
  # Hd: 5 -> 6, distance 6
  A[5, , 1] <- c(2, 6)
  A[6, , 1] <- c(2, 0)
  # Eh: 7 -> 8, distance 4
  A[7, , 1] <- c(3, 4)
  A[8, , 1] <- c(3, 0)
  # Mo: 1 -> 9, distance 3 (point 1 already at origin)
  A[9, , 1] <- c(0, 3)
  # PFi: 10 -> 11, distance 2 ; PFl: 10 -> 12, distance 5
  A[10, , 1] <- c(6, 2)
  A[11, , 1] <- c(6, 0)
  A[12, , 1] <- c(11, 2)
  # Ed: 13 -> 14, distance 1
  A[13, , 1] <- c(3, 5)
  A[14, , 1] <- c(3, 4)
  # Jl: 1 -> 15, distance 5 (point 1 at origin)
  A[15, , 1] <- c(3, 4)
  # CPd: 16 -> 17, distance 8
  A[16, , 1] <- c(30, 8)
  A[17, , 1] <- c(30, 0)
  # CFd: 18 -> 19, distance 20
  A[18, , 1] <- c(35, 15)
  A[19, , 1] <- c(35, -5)
  # scale bar 20 -> 21
  A[20, , 1] <- c(0, -20)
  A[21, , 1] <- c(scale_dist, -20)
  A
}

test_that("fishmorph_segments() computes correct distances and applies scale", {
  A <- make_minimal_fishmorph_array(scale_dist = 10) # 10 px = 1 cm -> px_to_cm = 0.1
  seg <- fishmorph_segments(A, scale_cm = 1)

  expect_s3_class(seg, "intrait_segments")
  expect_equal(seg$Bl, 4)   # 40 * 0.1
  expect_equal(seg$Bd, 1)   # 10 * 0.1
  expect_equal(seg$Hd, 0.6) # 6 * 0.1
  expect_equal(seg$Eh, 0.4) # 4 * 0.1
  expect_equal(seg$Mo, 0.3) # 3 * 0.1
  expect_equal(seg$PFi, 0.2)
  expect_equal(seg$PFl, 0.5)
  expect_equal(seg$Ed, 0.1)
  expect_equal(seg$Jl, 0.5)
  expect_equal(seg$CPd, 0.8)
  expect_equal(seg$CFd, 2)
})

test_that("fishmorph_segments() errors below 21 landmarks", {
  A <- array(0, dim = c(10, 2, 1))
  expect_error(fishmorph_segments(A), "at least 21 landmarks")
})

test_that("fishmorph_segments() errors on non-2D arrays", {
  A <- array(0, dim = c(21, 3, 1))
  expect_error(fishmorph_segments(A), "two-dimensional")
})

test_that("fishmorph_segments() warns and returns NA for zero-length scale bars", {
  A <- make_minimal_fishmorph_array(scale_dist = 10)
  A[21, , 1] <- A[20, , 1] # collapse the scale bar to zero length
  expect_warning(seg <- fishmorph_segments(A), "scale bar")
  expect_true(is.na(seg$Bl))
})

test_that("fishmorph_segments() applies curvature correction via point 22 when present", {
  A21 <- make_minimal_fishmorph_array(scale_dist = 10)
  A22 <- array(0, dim = c(22, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A22[1:21, , ] <- A21
  A22[22, , 1] <- c(20, 6) # midpoint bent upward -> curved path longer than straight line
  seg <- fishmorph_segments(A22, scale_cm = 1)
  straight <- fishmorph_segments(A21, scale_cm = 1)
  expect_true(seg$Bl > straight$Bl)
})

test_that("fishmorph_segments() ignores point 22 when it is all zero", {
  A22 <- array(0, dim = c(22, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A22[1:21, , ] <- make_minimal_fishmorph_array(scale_dist = 10)
  # point 22 left at (0,0) -> "not used"
  seg <- fishmorph_segments(A22, scale_cm = 1)
  expect_equal(seg$Bl, 4)
})

test_that("fishmorph_segments() carries over metadata", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  expect_true("species" %in% names(seg))
  expect_equal(nrow(seg), dim(fish$coords)[3])
})
