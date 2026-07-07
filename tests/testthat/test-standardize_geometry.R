# Self-contained fixture (deliberately not sourced from test-correct_geometry.R,
# so this file can be run in isolation regardless of test-file execution order):
# an UN-standardized 21-landmark configuration where the main axis (1, 2) is
# already horizontal (Bl = 8000, the longer of the two body-landmark spans),
# so step 3's rotation is a clean no-op, and all five landmark-coordinate-
# scatter conventions already hold exactly. See test-correct_geometry.R for
# the full annotated version of this fixture.
make_std_source_array <- function(specimen_names = "s1") {
  p <- 21
  n <- length(specimen_names)
  A <- array(0, dim = c(p, 2, n), dimnames = list(NULL, c("X", "Y"), specimen_names))
  pts <- list(
    `1` = c(1000, 5000), `2` = c(9000, 5000),
    `3` = c(3000, 7000), `4` = c(3000, 4000),
    `5` = c(4500, 6500), `6` = c(4500, 4500), `7` = c(4500, 4900), `8` = c(4500, 4000),
    `9` = c(1000, 4000), `10` = c(6000, 6500), `11` = c(6000, 4000),
    `12` = c(7000, 6500), `13` = c(4500, 5100), `14` = c(4500, 4700), `15` = c(1500, 4500),
    `16` = c(8000, 7000), `17` = c(8000, 3000), `18` = c(9000, 7500), `19` = c(9000, 2500),
    `20` = c(500, -3000), `21` = c(900, -3000)
  )
  for (i in as.integer(names(pts))) {
    for (s in seq_len(n)) A[i, , s] <- pts[[as.character(i)]]
  }
  A
}

# Euclidean distance between two landmarks in a single specimen's `p x k`
# coordinate matrix -- computed independently of any package function, so
# ratio-invariance checks below do not depend on linear_distances()'s own
# correctness.
dist2 <- function(xy, a, b) sqrt(sum((xy[a, ] - xy[b, ])^2))

test_that("standardize_geometry() rescales and repositions the scale bar identically to correct_geometry()'s steps 1-3", {
  A <- make_std_source_array()
  out <- suppressMessages(standardize_geometry(A, orient = FALSE))

  log <- attr(out, "standardization_log")
  expect_s3_class(log, "data.frame")
  expect_equal(log$scale_factor, 1 / 8000)
  expect_equal(log$rotation_deg, 0)
  expect_equal(log$y_shift, 0.1875)
  expect_true(log$scale_bar_placed)

  expect_equal(out[1, , 1], c(X = 0, Y = 0.5))
  expect_equal(out[2, , 1], c(X = 1, Y = 0.5))
  expect_equal(out[20, , 1], c(X = 0.1, Y = 0.1))
  expect_equal(out[21, , 1], c(X = 0.15, Y = 0.1))
})

test_that("standardize_geometry() never changes any FISHMORPH ratio (isometric transform only)", {
  A <- make_std_source_array()
  ratio_before <- dist2(A[, , 1], 3, 4) / dist2(A[, , 1], 1, 2)

  out <- suppressMessages(standardize_geometry(A, orient = FALSE))
  ratio_after <- dist2(out[, , 1], 3, 4) / dist2(out[, , 1], 1, 2)

  expect_equal(ratio_after, ratio_before)
})

test_that("standardize_geometry() leaves step-4 geometric-convention violations uncorrected", {
  # The core deliverable of the split: steps 1-3 alone must NOT touch a
  # landmark-coordinate-scatter violation that only step 4 (now
  # correct_geometry_conventions()) is responsible for.
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800 # breaks segment (10, 11)'s shared X

  out_std <- suppressMessages(standardize_geometry(A, orient = FALSE))
  expect_null(attr(out_std, "correction_log"))
  expect_false(isTRUE(all.equal(out_std[11, "X", 1], out_std[10, "X", 1])))

  out_corrected <- suppressMessages(correct_geometry_conventions(out_std))
  expect_equal(out_corrected[11, "X", 1], out_corrected[10, "X", 1])
})

test_that("standardize_geometry(orient = FALSE) + correct_geometry_conventions() reproduces correct_geometry() exactly", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800
  A[5, "X", 1] <- A[5, "X", 1] + 900

  out_combined <- suppressMessages(correct_geometry(A))
  out_split <- suppressMessages(
    correct_geometry_conventions(standardize_geometry(A, orient = FALSE))
  )
  expect_equal(out_split, out_combined)
})

test_that("standardize_geometry() couples with standardize_orientation() by default (orient = TRUE)", {
  A <- make_std_source_array()
  # flip the specimen dorsal-ventral (landmark 4 now above landmark 3):
  A[3, "Y", 1] <- 4000
  A[4, "Y", 1] <- 7000

  out_default <- suppressMessages(standardize_geometry(A))
  out_manual <- suppressMessages(standardize_geometry(standardize_orientation(A), orient = FALSE))
  expect_equal(out_default, out_manual)

  out_noorient <- suppressMessages(standardize_geometry(A, orient = FALSE))
  # without the coupling, the dorsal-ventral flip never happens:
  expect_true(out_noorient[4, "Y", 1] > out_noorient[3, "Y", 1])
  # with the default coupling, orientation is fixed before rescaling/rotation:
  expect_true(out_default[3, "Y", 1] > out_default[4, "Y", 1])
})

test_that("standardize_geometry() emits both standardize_orientation()'s and its own message, in order, when orient = TRUE", {
  # NB: expect_message()/expect_warning() return the *captured condition*
  # (not the tested expression's value) whenever `regexp` is a string, so
  # piping the function call through successive expect_message() calls and
  # assigning the final result would capture a condition object, not the
  # array. evaluate_promise() sidesteps this entirely: it returns the real
  # `result` alongside every `messages`/`warnings` string, unambiguously.
  A <- make_std_source_array()
  ep <- evaluate_promise(standardize_geometry(A))
  expect_true(is.array(ep$result))
  expect_length(ep$messages, 2)
  expect_match(ep$messages[1], "mirrored")
  expect_match(ep$messages[2], "standardized")
})

test_that("standardize_geometry(orient = FALSE) emits only its own message", {
  A <- make_std_source_array()
  expect_message(out <- standardize_geometry(A, orient = FALSE), "standardized")
  expect_s3_class(attr(out, "standardization_log"), "data.frame")
})

test_that("standardize_geometry() errors on an invalid `orient`", {
  A <- make_std_source_array()
  expect_error(standardize_geometry(A, orient = "yes"), "orient")
  expect_error(standardize_geometry(A, orient = NA), "orient")
})

test_that("standardize_geometry() places the scale bar at a custom `scale_bar_pos`", {
  A <- make_std_source_array()
  out <- suppressMessages(standardize_geometry(A, scale_bar_pos = c(0.2, 0.05), orient = FALSE))
  expect_equal(out[20, , 1], c(X = 0.2, Y = 0.05))
  expect_equal(out[21, , 1], c(X = 0.25, Y = 0.05))
})

test_that("standardize_geometry() warns and skips rotation when landmark 1 or 2 is missing", {
  A <- make_std_source_array()
  A[2, , 1] <- NA_real_

  expect_warning(
    out <- suppressMessages(standardize_geometry(A, orient = FALSE)),
    "could not rotate"
  )
  log <- attr(out, "standardization_log")
  expect_false(is.na(log$scale_factor)) # step 1 still applied
  expect_true(is.na(log$rotation_deg)) # step 3 skipped
})

test_that("standardize_geometry() warns and skips rescaling when body landmarks are degenerate", {
  A <- make_std_source_array()
  # collapse every body landmark onto a single point: span_x = span_y = 0
  # (this also collapses landmarks 1 and 2 together, so rotation is skipped
  # too -- both warnings fire and must be caught in order, per testthat 3e's
  # single-condition-per-expectation semantics)
  for (li in 1:19) A[li, , 1] <- c(1000, 1000)

  ep <- evaluate_promise(standardize_geometry(A, orient = FALSE))
  expect_length(ep$warnings, 2)
  expect_match(ep$warnings[1], "could not rescale")
  expect_match(ep$warnings[2], "could not rotate")

  log <- attr(ep$result, "standardization_log")
  expect_true(is.na(log$scale_factor))
  expect_true(is.na(log$rotation_deg))
})

test_that("standardize_geometry() works on a subset of specimens via `specimen`", {
  A <- make_std_source_array(c("s1", "s2"))
  out <- suppressMessages(standardize_geometry(A, specimen = "s2", orient = FALSE))
  expect_equal(out[, , "s1"], A[, , "s1"]) # untouched
  expect_equal(out[1, , "s2"], c(X = 0, Y = 0.5))

  log <- attr(out, "standardization_log")
  expect_equal(log$specimen, "s2")
})

test_that("standardize_geometry() accumulates standardization_log across successive calls without touching correction_log/corrected", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800

  step1 <- suppressMessages(correct_geometry_conventions(standardize_geometry(A, orient = FALSE)))
  expect_true(any(attr(step1, "corrected")))
  prior_correction_log <- attr(step1, "correction_log")

  step2 <- suppressMessages(standardize_geometry(step1, orient = FALSE))
  expect_equal(nrow(attr(step2, "standardization_log")), 2) # accumulated: 2 rows for 1 specimen
  # standardize_geometry() must not touch a pre-existing correction_log/corrected:
  expect_identical(attr(step2, "correction_log"), prior_correction_log)
  expect_identical(attr(step2, "corrected"), attr(step1, "corrected"))
})

test_that("standardize_geometry() keeps `landmarks$scale` consistent with rescaled coordinates", {
  A <- make_std_source_array()
  landmarks <- structure(
    list(coords = A, scale = c(s1 = 0.02), metadata = NULL),
    class = "intrait_landmarks"
  )
  bl_before <- linear_distances(A, list(Bl = c(1, 2)), scale = c(s1 = 0.02))

  out <- suppressMessages(standardize_geometry(landmarks, orient = FALSE))
  expect_s3_class(out, "intrait_landmarks")
  expect_equal(out$scale[["s1"]], 0.02 / (1 / 8000))

  bl_after <- linear_distances(out, list(Bl = c(1, 2)))
  expect_equal(bl_after["s1", "Bl"], bl_before["s1", "Bl"])
})

test_that("standardize_geometry() errors below 21 landmarks", {
  A <- array(0, dim = c(19, 2, 1), dimnames = list(NULL, NULL, "s1"))
  expect_error(standardize_geometry(A, orient = FALSE), "21")
})

test_that("standardize_geometry() errors on non-2D arrays", {
  A <- array(0, dim = c(21, 3, 1))
  expect_error(standardize_geometry(A, orient = FALSE), "two-dimensional")
})

test_that("standardize_geometry() errors on an invalid `scale_bar_pos`", {
  A <- make_std_source_array()
  expect_error(standardize_geometry(A, scale_bar_pos = c(0.1, 0.1, 0.1), orient = FALSE), "scale_bar_pos")
  expect_error(standardize_geometry(A, scale_bar_pos = c(NA, 0.1), orient = FALSE), "scale_bar_pos")
})

test_that("standardize_geometry() leaves a raw (non-classed) array's behaviour unchanged when there is no `$scale` to update", {
  A <- make_std_source_array()
  out <- suppressMessages(standardize_geometry(A, orient = FALSE))
  expect_true(is.array(out))
  expect_false(inherits(out, "intrait_landmarks"))
})
