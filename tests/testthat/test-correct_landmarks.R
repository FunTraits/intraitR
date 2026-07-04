make_alignment_array <- function() {
  # Two specimens, 21 landmarks. Points 9, 8, 11, 4 share Y = 100 for
  # specimen 1, except landmark 11 which is planted off at Y = 250.
  A <- array(0, dim = c(21, 2, 2), dimnames = list(NULL, c("X", "Y"), c("s1", "s2")))
  for (i in 1:21) A[i, , ] <- c(i * 10, 500)
  A[9, "Y", 1] <- 100
  A[8, "Y", 1] <- 100
  A[11, "Y", 1] <- 250 # misplaced
  A[4, "Y", 1] <- 100
  # specimen 2: all four already aligned, no correction expected there
  A[c(9, 8, 11, 4), "Y", 2] <- 100
  A
}

test_that("correct_landmarks() snaps only the specified point to the median of the reference points", {
  A <- make_alignment_array()
  expect_message(
    out <- correct_landmarks(A, specimen = 1, points = c(9, 8, 11, 4), correct = 11, axis = "y"),
    "landmark\\(s\\) 11"
  )
  # median of 9, 8, 4 (all Y = 100) is 100
  expect_equal(out[11, "Y", 1], 100)
  # reference points themselves are untouched
  expect_equal(out[9, "Y", 1], 100)
  expect_equal(out[8, "Y", 1], 100)
  expect_equal(out[4, "Y", 1], 100)
  # other specimen and other landmarks/coordinates are untouched
  expect_equal(out[, , 2], A[, , 2])
  expect_equal(out[1, , 1], A[1, , 1])
  expect_equal(out[11, "X", 1], A[11, "X", 1])
})

test_that("correct_landmarks() works by specimen name", {
  A <- make_alignment_array()
  out <- suppressMessages(
    correct_landmarks(A, specimen = "s1", points = c(9, 8, 11, 4), correct = 11, axis = "y")
  )
  expect_equal(out[11, "Y", "s1"], 100)
})

test_that("correct_landmarks() attaches a 'corrected' attribute and a cumulative correction_log", {
  A <- make_alignment_array()
  out <- suppressMessages(
    correct_landmarks(A, specimen = 1, points = c(9, 8, 11, 4), correct = 11, axis = "y")
  )
  corrected <- attr(out, "corrected")
  expect_false(is.null(corrected))
  expect_equal(dim(corrected), c(21, 2))
  expect_true(corrected[11, 1])
  expect_equal(sum(corrected), 1)

  log <- attr(out, "correction_log")
  expect_s3_class(log, "data.frame")
  expect_equal(nrow(log), 1)
  expect_equal(log$check, "align")
  expect_equal(log$landmark, 11)
  expect_equal(log$old_value, 250)
  expect_equal(log$new_value, 100)
})

test_that("correct_landmarks() accumulates the correction_log across successive calls", {
  A <- make_alignment_array()
  out1 <- suppressMessages(
    correct_landmarks(A, specimen = 1, points = c(9, 8, 11, 4), correct = 11, axis = "y")
  )
  out2 <- suppressMessages(
    correct_landmarks(out1, specimen = 2, points = c(9, 8, 11, 4), correct = 9, axis = "y")
  )
  log <- attr(out2, "correction_log")
  expect_equal(nrow(log), 2)
  expect_equal(sort(log$specimen), sort(c("s1", "s2")))
  corrected <- attr(out2, "corrected")
  expect_true(corrected[11, 1])
  expect_true(corrected[9, 2])
})

test_that("correct_landmarks() errors when `correct` is not a subset of `points`", {
  A <- make_alignment_array()
  expect_error(
    correct_landmarks(A, specimen = 1, points = c(9, 8, 4), correct = 11, axis = "y"),
    "subset"
  )
})

test_that("correct_landmarks() errors when `points` only contains the `correct` landmark(s)", {
  A <- make_alignment_array()
  expect_error(
    correct_landmarks(A, specimen = 1, points = 11, correct = 11, axis = "y"),
    "at least one landmark not in"
  )
})

test_that("correct_landmarks() errors on an unknown specimen name", {
  A <- make_alignment_array()
  expect_error(
    correct_landmarks(A, specimen = "not_a_specimen", points = c(9, 8, 4), correct = 9, axis = "y"),
    "not found"
  )
})

test_that("correct_landmarks() supports axis = 'x'", {
  A <- make_alignment_array()
  A[11, "X", 1] <- 999 # misplace on X instead
  out <- suppressMessages(
    correct_landmarks(A, specimen = 1, points = c(9, 8, 11, 4), correct = 11, axis = "x")
  )
  expect_equal(out[11, "X", 1], median(c(A[9, "X", 1], A[8, "X", 1], A[4, "X", 1])))
})

test_that("correct_landmarks(rule = 'align') still requires specimen/points/correct", {
  A <- make_alignment_array()
  expect_error(
    correct_landmarks(A, points = c(9, 8, 11, 4), correct = 11, axis = "y"),
    "specimen"
  )
  expect_error(
    correct_landmarks(A, specimen = 1, axis = "y"),
    "points.*correct"
  )
})

# --- rule = "check_geometry" ------------------------------------------------

make_geometry_array <- function(specimen_names = "s1") {
  # A 21-landmark configuration built to satisfy, exactly, every convention
  # checked by rule = "check_geometry": axis (1,2) and horizontal line
  # (9,8,11,4) are both perfectly horizontal (shared Y); segments (1,9),
  # (3,4), (10,11) and the eye-socket line (5,13,7,14,6,8) are all perfectly
  # vertical (shared X), hence mutually parallel and perpendicular to the
  # main axis. Landmarks not involved in any check are arbitrary.
  p <- 21
  n <- length(specimen_names)
  A <- array(0, dim = c(p, 2, n), dimnames = list(NULL, c("X", "Y"), specimen_names))
  pts <- list(
    `1` = c(0, 500), `2` = c(1000, 500), `3` = c(300, 700), `4` = c(300, 400),
    `5` = c(450, 650), `6` = c(450, 450), `7` = c(450, 490), `8` = c(450, 400),
    `9` = c(0, 400), `10` = c(600, 650), `11` = c(600, 400),
    `13` = c(450, 510), `14` = c(450, 470)
  )
  for (i in as.integer(names(pts))) {
    for (s in seq_len(n)) A[i, , s] <- pts[[as.character(i)]]
  }
  for (i in c(12, 15, 16, 17, 18, 19, 20, 21)) {
    for (s in seq_len(n)) A[i, , s] <- c(i * 50, 200)
  }
  A
}

test_that("check_geometry reports a well-formed specimen as fully conforming", {
  A <- make_geometry_array()
  out <- correct_landmarks(A, rule = "check_geometry")
  expect_s3_class(out, "intrait_geometry_check")
  expect_true(all(!is.na(out$ok)))
  expect_true(all(out$ok))
  expect_true(all(out$deviation < 1e-6))
})

test_that("check_geometry's five coordinate checks are 'rel_bl' and the two orientation checks are 'deg'", {
  A <- make_geometry_array()
  out <- correct_landmarks(A, rule = "check_geometry")
  coord_checks <- c(
    "perpendicular_seg_1_9_vs_axis", "perpendicular_seg_3_4_vs_axis",
    "perpendicular_seg_10_11_vs_axis", "perpendicular_eye_vertical_vs_axis",
    "axis_horizontal_parallel"
  )
  deg_checks <- c("eye_axis_vertical_alignment", "parallel_vertical_segments")
  expect_true(all(out$unit[out$check %in% coord_checks] == "rel_bl"))
  expect_true(all(out$unit[out$check %in% deg_checks] == "deg"))
  expect_true(all(out$tolerance[out$check %in% coord_checks] == 0.02))
  expect_true(all(out$tolerance[out$check %in% deg_checks] == 2))
})

test_that("check_geometry flags a broken vertical segment (perpendicularity and parallelism)", {
  A <- make_geometry_array()
  A[11, "X", 1] <- 900 # break segment (10, 11)'s verticality: X now 300 away from point 10's 600
  out <- correct_landmarks(A, specimen = "s1", rule = "check_geometry")

  perp_row <- out[out$check == "perpendicular_seg_10_11_vs_axis", ]
  expect_false(perp_row$ok)
  # Bl = distance(point 1, point 2) = 1000; |900 - 600| / 1000 = 0.3
  expect_equal(perp_row$deviation, 0.3)
  expect_equal(perp_row$unit, "rel_bl")

  parallel_row <- out[out$check == "parallel_vertical_segments", ]
  expect_false(parallel_row$ok)

  # the horizontal line's Y coordinates are untouched by this perturbation
  horiz_row <- out[out$check == "axis_horizontal_parallel", ]
  expect_true(horiz_row$ok)
})

test_that("check_geometry's `tolerance_coord` changes which coordinate checks are flagged", {
  A <- make_geometry_array()
  A[11, "X", 1] <- 900 # deviation = 0.3 (see above)
  strict <- correct_landmarks(A, specimen = "s1", rule = "check_geometry", tolerance_coord = 0.01)
  lenient <- correct_landmarks(A, specimen = "s1", rule = "check_geometry", tolerance_coord = 0.5)

  strict_row <- strict[strict$check == "perpendicular_seg_10_11_vs_axis", ]
  lenient_row <- lenient[lenient$check == "perpendicular_seg_10_11_vs_axis", ]
  expect_false(strict_row$ok)
  expect_true(lenient_row$ok)
})

test_that("check_geometry's `tolerance` (degrees) changes which orientation checks are flagged", {
  A <- make_geometry_array()
  A[11, "X", 1] <- 900 # also rotates seg (10, 11), tripping the two angle-based checks
  strict <- correct_landmarks(A, specimen = "s1", rule = "check_geometry", tolerance = 1)
  lenient <- correct_landmarks(A, specimen = "s1", rule = "check_geometry", tolerance = 80)

  strict_row <- strict[strict$check == "parallel_vertical_segments", ]
  lenient_row <- lenient[lenient$check == "parallel_vertical_segments", ]
  expect_false(strict_row$ok)
  expect_true(lenient_row$ok)
})

test_that("check_geometry checks every specimen by default, and a subset via `specimen`", {
  A <- make_geometry_array(c("s1", "s2"))
  A[11, "X", "s2"] <- 900

  out_all <- correct_landmarks(A, rule = "check_geometry")
  expect_setequal(unique(out_all$specimen), c("s1", "s2"))
  expect_true(all(out_all$ok[out_all$specimen == "s1"]))
  expect_false(all(out_all$ok[out_all$specimen == "s2"]))

  out_one <- correct_landmarks(A, specimen = "s1", rule = "check_geometry")
  expect_equal(unique(out_one$specimen), "s1")
})

test_that("check_geometry tolerates a specimen with a missing landmark (NA, not an error)", {
  A <- make_geometry_array()
  A[5, , 1] <- NA_real_ # eye-socket line loses one of its 6 points
  out <- expect_error(correct_landmarks(A, rule = "check_geometry"), NA)
  eye_row <- out[out$check == "eye_axis_vertical_alignment", ]
  # still computable from the 5 remaining eye-line points
  expect_false(is.na(eye_row$ok))
})

test_that("check_geometry errors with fewer than 19 landmarks", {
  A_small <- array(0, dim = c(10, 2, 1), dimnames = list(NULL, NULL, "s1"))
  expect_error(correct_landmarks(A_small, rule = "check_geometry"), "19")
})

test_that("check_geometry errors on an unknown specimen name", {
  A <- make_geometry_array()
  expect_error(
    correct_landmarks(A, specimen = "not_a_specimen", rule = "check_geometry"),
    "not found"
  )
})

test_that("print.intrait_geometry_check() prints a summary", {
  A <- make_geometry_array()
  out <- correct_landmarks(A, rule = "check_geometry")
  expect_output(print(out), "intrait_geometry_check")
})

test_that("print.intrait_geometry_check() prints non-conforming rows without erroring or recursing", {
  # Regression test: printing the "Non-conforming:" table used to
  # re-dispatch print.intrait_geometry_check() on itself (a row/column
  # subset of a data.frame subclass keeps its extra class under base
  # `[.data.frame`), which then errored on `!x$ok` once the `ok` column
  # was excluded from that subset.
  A <- make_geometry_array()
  A[11, "X", 1] <- 900
  out <- correct_landmarks(A, specimen = "s1", rule = "check_geometry")
  txt <- expect_error(capture.output(print(out)), NA)
  expect_equal(sum(grepl("<intrait_geometry_check>", txt)), 1)
  expect_true(any(grepl("Non-conforming", txt)))
  expect_true(any(grepl("perpendicular_seg_10_11_vs_axis", txt)))
})
