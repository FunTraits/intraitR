# Self-contained fixture (not sourced from another test file, so this file
# can be run in isolation regardless of test-file execution order): an
# UN-standardized 21-landmark configuration where the main axis (1, 2) is
# already horizontal (Bl = 8000), so step 4's checks -- which only require a
# horizontal axis, not the full [0, 1] rescale/scale-bar placement -- can be
# exercised directly on it without calling standardize_geometry() first. See
# test-correct_geometry.R for the full annotated version of this fixture.
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

test_that("correct_geometry_conventions() reports nothing to correct on an already-conforming specimen", {
  A <- make_std_source_array()
  expect_message(out <- correct_geometry_conventions(A), "nothing to correct")
  expect_null(attr(out, "correction_log"))
  expect_false(any(attr(out, "corrected")))
})

test_that("correct_geometry_conventions() snaps a two-point segment's companion point onto its anchor", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800 # break segment (10, 11)'s shared X

  expect_message(out <- correct_geometry_conventions(A), "corrected 1 landmark")
  log <- attr(out, "correction_log")
  expect_s3_class(log, "data.frame")
  expect_equal(log$check, "perpendicular_seg_10_11_vs_axis")
  expect_equal(log$landmark, 11)
  expect_equal(log$axis, "x")
  expect_equal(log$new_value, out[10, "X", 1])

  expect_equal(out[11, "X", 1], out[10, "X", 1])
  corrected <- attr(out, "corrected")
  expect_true(corrected[11, 1])
  expect_equal(sum(corrected), 1)
})

test_that("correct_geometry_conventions() snaps the worst offender in the eye-socket line to the median of the rest", {
  A <- make_std_source_array()
  A[5, "X", 1] <- A[5, "X", 1] + 900

  out <- suppressMessages(correct_geometry_conventions(A))
  log <- attr(out, "correction_log")
  expect_equal(log$check, "perpendicular_eye_vertical_vs_axis")
  expect_equal(log$landmark, 5)
  expect_equal(out[5, "X", 1], out[13, "X", 1])
})

test_that("correct_geometry_conventions() corrects two simultaneous deviants in the same multi-point group", {
  A <- make_std_source_array()
  A[6, "X", 1] <- A[6, "X", 1] + 900
  A[8, "X", 1] <- A[8, "X", 1] - 600

  out <- suppressMessages(correct_geometry_conventions(A))
  log <- attr(out, "correction_log")
  expect_equal(sum(log$check == "perpendicular_eye_vertical_vs_axis"), 2)
  expect_setequal(log$landmark[log$check == "perpendicular_eye_vertical_vs_axis"], c(6, 8))
  expect_equal(out[6, "X", 1], out[5, "X", 1])
  expect_equal(out[8, "X", 1], out[5, "X", 1])
})

test_that("correct_geometry_conventions() snaps the worst offender in the horizontal line to the median of the rest", {
  A <- make_std_source_array()
  A[11, "Y", 1] <- A[11, "Y", 1] + 700

  out <- suppressMessages(correct_geometry_conventions(A))
  log <- attr(out, "correction_log")
  expect_equal(log$check, "axis_horizontal_parallel")
  expect_equal(log$landmark, 11)
  expect_equal(log$axis, "y")
  expect_equal(out[11, "Y", 1], out[9, "Y", 1])
})

test_that("correct_geometry_conventions() respects `tolerance_coord`", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 8 # 8 / 8000 = 0.1% of Bl

  expect_message(out_strict <- correct_geometry_conventions(A, tolerance_coord = 0.0005), "corrected")
  expect_message(out_lenient <- correct_geometry_conventions(A, tolerance_coord = 0.01), "nothing to correct")
  expect_equal(out_strict[11, "X", 1], out_strict[10, "X", 1])
  expect_false(isTRUE(all.equal(out_lenient[11, "X", 1], out_lenient[10, "X", 1])))
})

test_that("correct_geometry_conventions() corrects small deviations by default (tolerance_coord = 1e-6)", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 8

  out <- suppressMessages(correct_geometry_conventions(A)) # no tolerance_coord passed
  log <- attr(out, "correction_log")
  expect_equal(log$check, "perpendicular_seg_10_11_vs_axis")
  expect_equal(out[11, "X", 1], out[10, "X", 1])
})

test_that("correct_geometry_conventions() works on a subset of specimens via `specimen`", {
  A <- make_std_source_array(c("s1", "s2"))
  A[11, "X", "s2"] <- A[11, "X", "s2"] + 800

  out <- suppressMessages(correct_geometry_conventions(A, specimen = "s2"))
  expect_equal(out[, , "s1"], A[, , "s1"]) # untouched
  expect_equal(out[11, "X", "s2"], out[10, "X", "s2"])
})

test_that("correct_geometry_conventions() and correct_landmarks(rule = 'align') accumulate into one correction_log", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800
  A_aligned <- suppressMessages(
    correct_landmarks(A, specimen = "s1", points = c(9, 8, 11, 4), correct = 9, axis = "y")
  )

  out <- suppressMessages(correct_geometry_conventions(A_aligned))
  corrected <- attr(out, "corrected")
  expect_true(corrected[9, 1]) # from the earlier rule = "align" call
  expect_true(corrected[11, 1]) # from this correct_geometry_conventions() call

  log <- attr(out, "correction_log")
  expect_equal(nrow(log), 2)
  expect_setequal(log$check, c("align", "perpendicular_seg_10_11_vs_axis"))
})

test_that("correct_geometry_conventions() warns and skips specimens missing landmark 1 or 2", {
  A <- make_std_source_array()
  A[2, , 1] <- NA_real_

  expect_warning(
    out <- suppressMessages(correct_geometry_conventions(A)),
    "missing landmark 1 or 2"
  )
  expect_null(attr(out, "correction_log"))
  expect_false(any(attr(out, "corrected")))
})

test_that("correct_geometry_conventions() errors below 21 landmarks", {
  A <- array(0, dim = c(19, 2, 1), dimnames = list(NULL, NULL, "s1"))
  expect_error(correct_geometry_conventions(A), "21")
})

test_that("correct_geometry_conventions() errors on non-2D arrays", {
  A <- array(0, dim = c(21, 3, 1))
  expect_error(correct_geometry_conventions(A), "two-dimensional")
})

test_that("correct_geometry_conventions() errors on an invalid `tolerance_coord`", {
  A <- make_std_source_array()
  expect_error(correct_geometry_conventions(A, tolerance_coord = -1), "tolerance_coord")
})

test_that("correct_geometry_conventions() is idempotent (a second pass leaves an already-corrected specimen unchanged)", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800

  out1 <- suppressMessages(correct_geometry_conventions(A))
  expect_message(out2 <- correct_geometry_conventions(out1), "nothing to correct")
  expect_equal(out2[11, "X", 1], out1[11, "X", 1])
})
