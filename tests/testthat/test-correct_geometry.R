make_std_source_array <- function(specimen_names = "s1") {
  # An UN-standardized 21-landmark configuration, built so every step of
  # correct_geometry()'s pipeline is exercised with numbers that are easy
  # to verify by hand: the main axis (1, 2) is already horizontal (Bl =
  # 8000, the longer of the two body-landmark spans) so step 3's rotation
  # is a clean no-op here (a separate test below perturbs this to check
  # the rotation math itself, using relational rather than absolute-value
  # assertions); all five landmark-coordinate-scatter conventions already
  # hold exactly; and the scale bar (20, 21, length 400) sits far below
  # the body, as it might in a real, un-standardized photograph.
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
# Body bounding box (landmarks 1-19): X in [1000, 9000] (span 8000), Y in
# [2500, 7500] (span 5000). X is the longer span, so scale_factor = 1/8000
# and X alone spans exactly [0, 1]; Y is not centered (step 3 re-anchors it
# to 0.5 anyway). Before step 3's Y-shift, both point 1 and point 2 land at
# Y = (5000 - 2500) / 8000 = 0.3125 (already equal -- a horizontal axis),
# so rotation_deg = 0 and y_shift = 0.5 - 0.3125 = 0.1875 exactly. After
# that shift, Bl = distance(point 1, point 2) = 1 exactly (point 1 at
# X = 0, point 2 at X = 1, same Y).

test_that("correct_geometry() rescales, repositions the scale bar, and leaves an already-conforming specimen's alignment untouched", {
  A <- make_std_source_array()
  expect_message(out <- correct_geometry(A), "nothing left to correct")

  log <- attr(out, "standardization_log")
  expect_s3_class(log, "data.frame")
  expect_equal(log$scale_factor, 1 / 8000)
  expect_equal(log$rotation_deg, 0)
  expect_equal(log$y_shift, 0.1875)
  expect_true(log$scale_bar_placed)

  # axis (1, 2): Bl = 1, anchored at Y = 0.5, point 1 left of point 2
  expect_equal(out[1, , 1], c(X = 0, Y = 0.5))
  expect_equal(out[2, , 1], c(X = 1, Y = 0.5))

  # scale bar repositioned to the default bottom-left corner, horizontal,
  # length rescaled by the same factor as the body (400 / 8000 = 0.05)
  expect_equal(out[20, , 1], c(X = 0.1, Y = 0.1))
  expect_equal(out[21, , 1], c(X = 0.15, Y = 0.1))

  # nothing corrected in step 4: this fixture is already conforming
  expect_null(attr(out, "correction_log"))
  expect_false(any(attr(out, "corrected")))
})

test_that("correct_geometry() places the scale bar at a custom `scale_bar_pos`", {
  A <- make_std_source_array()
  out <- suppressMessages(correct_geometry(A, scale_bar_pos = c(0.2, 0.05)))
  expect_equal(out[20, , 1], c(X = 0.2, Y = 0.05))
  expect_equal(out[21, , 1], c(X = 0.25, Y = 0.05))
})

test_that("correct_geometry() rotates a tilted axis to exactly horizontal, anchored at Y = 0.5", {
  # Break the axis' horizontality *before* standardization; verified via
  # relational invariants (not absolute values), since hand-checking exact
  # rotated coordinates would require independently re-deriving the same
  # trigonometry the function itself uses.
  A <- make_std_source_array()
  A[2, "Y", 1] <- A[2, "Y", 1] + 1500

  out <- suppressMessages(correct_geometry(A))
  expect_equal(out[1, "Y", 1], 0.5)
  expect_equal(out[2, "Y", 1], 0.5)
  expect_true(out[1, "X", 1] < out[2, "X", 1])

  log <- attr(out, "standardization_log")
  expect_true(log$rotation_deg != 0)
})

test_that("correct_geometry() snaps a two-point segment's companion point onto its anchor's X", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800 # break segment (10, 11)'s shared X

  expect_message(out <- correct_geometry(A), "corrected 1 landmark")
  log <- attr(out, "correction_log")
  expect_s3_class(log, "data.frame")
  expect_equal(log$check, "perpendicular_seg_10_11_vs_axis")
  expect_equal(log$landmark, 11)
  expect_equal(log$axis, "x")
  expect_equal(log$new_value, out[10, "X", 1]) # point 10's (rescaled) X, the trusted anchor

  expect_equal(out[11, "X", 1], out[10, "X", 1])
  corrected <- attr(out, "corrected")
  expect_true(corrected[11, 1])
  expect_equal(sum(corrected), 1)
})

test_that("correct_geometry() snaps the worst offender in the eye-socket line to the median of the rest", {
  A <- make_std_source_array()
  A[5, "X", 1] <- A[5, "X", 1] + 900 # points 13, 7, 14, 6, 8 remain at their shared X

  out <- suppressMessages(correct_geometry(A))
  log <- attr(out, "correction_log")
  expect_equal(log$check, "perpendicular_eye_vertical_vs_axis")
  expect_equal(log$landmark, 5)
  expect_equal(out[5, "X", 1], out[13, "X", 1])
})

test_that("correct_geometry() corrects two simultaneous deviants in the same multi-point group", {
  # The regression test for the reported bug: the eye-socket line (5, 13, 7,
  # 14, 6, 8) can have MORE than one misplaced point at once (e.g. landmarks
  # 6 and 8 both off), and both must be corrected in a single pass, not just
  # the single worst offender.
  A <- make_std_source_array()
  A[6, "X", 1] <- A[6, "X", 1] + 900
  A[8, "X", 1] <- A[8, "X", 1] - 600
  # reference (median of all six present points, computed once up front)
  # is unaffected here, since only 2 of 6 points moved symmetrically enough
  # to leave the median at the untouched shared value, 4500.

  out <- suppressMessages(correct_geometry(A))
  log <- attr(out, "correction_log")
  expect_equal(sum(log$check == "perpendicular_eye_vertical_vs_axis"), 2)
  expect_setequal(log$landmark[log$check == "perpendicular_eye_vertical_vs_axis"], c(6, 8))

  # both corrected onto the same shared reference as the untouched points
  expect_equal(out[6, "X", 1], out[5, "X", 1])
  expect_equal(out[8, "X", 1], out[5, "X", 1])

  corrected <- attr(out, "corrected")
  expect_true(corrected[6, 1])
  expect_true(corrected[8, 1])
})

test_that("correct_geometry() snaps the worst offender in the horizontal line to the median of the rest", {
  A <- make_std_source_array()
  A[11, "Y", 1] <- A[11, "Y", 1] + 700 # points 9, 8, 4 remain at their shared Y

  out <- suppressMessages(correct_geometry(A))
  log <- attr(out, "correction_log")
  expect_equal(log$check, "axis_horizontal_parallel")
  expect_equal(log$landmark, 11)
  expect_equal(log$axis, "y")
  expect_equal(out[11, "Y", 1], out[9, "Y", 1])
})

test_that("correct_geometry() respects `tolerance_coord`", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 8 # a tiny deviation: 8 / 8000 = 0.1% of the body span

  expect_message(out_strict <- correct_geometry(A, tolerance_coord = 0.0005), "corrected")
  expect_message(out_lenient <- correct_geometry(A, tolerance_coord = 0.01), "nothing left to correct")
  expect_equal(out_strict[11, "X", 1], out_strict[10, "X", 1])
  expect_false(isTRUE(all.equal(out_lenient[11, "X", 1], out_lenient[10, "X", 1])))
})

test_that("correct_geometry() corrects small deviations by default (tolerance_coord = 1e-6)", {
  # 8 / 8000 = 0.1% of Bl -- well under correct_landmarks(rule =
  # "check_geometry")'s 2% diagnostic default, but correct_geometry()'s own
  # default tightened to 1e-6 specifically so deviations like this one are
  # no longer silently left uncorrected (see the roxygen rationale).
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 8

  out <- suppressMessages(correct_geometry(A)) # no tolerance_coord passed
  log <- attr(out, "correction_log")
  expect_equal(log$check, "perpendicular_seg_10_11_vs_axis")
  expect_equal(out[11, "X", 1], out[10, "X", 1])
})

test_that("correct_geometry() works on a subset of specimens via `specimen`", {
  A <- make_std_source_array(c("s1", "s2"))
  A[11, "X", "s2"] <- A[11, "X", "s2"] + 800

  out <- suppressMessages(correct_geometry(A, specimen = "s2"))
  expect_equal(out[, , "s1"], A[, , "s1"]) # untouched: not standardized at all
  expect_equal(out[11, "X", "s2"], out[10, "X", "s2"])

  log <- attr(out, "standardization_log")
  expect_equal(log$specimen, "s2")
})

test_that("correct_geometry() and correct_landmarks(rule = 'align') accumulate into one correction_log", {
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800
  A_aligned <- suppressMessages(
    correct_landmarks(A, specimen = "s1", points = c(9, 8, 11, 4), correct = 9, axis = "y")
  )

  out <- suppressMessages(correct_geometry(A_aligned))
  corrected <- attr(out, "corrected")
  expect_true(corrected[9, 1]) # from the earlier rule = "align" call
  expect_true(corrected[11, 1]) # from this correct_geometry() call's step 4

  log <- attr(out, "correction_log")
  expect_equal(nrow(log), 2)
  expect_setequal(log$check, c("align", "perpendicular_seg_10_11_vs_axis"))
})

test_that("check_geometry() reports all five coordinate checks as ok after correct_geometry()", {
  # Regression test tying the two functions together: once
  # correct_geometry() has standardized *and* corrected a specimen, a
  # fresh correct_landmarks(rule = "check_geometry") pass (using the same
  # default tolerance_coord) must find nothing left to flag among the five
  # landmark-coordinate-scatter checks, since both rely on the exact same
  # .geometry_step_deviation() criterion.
  A <- make_std_source_array()
  A[11, "X", 1] <- A[11, "X", 1] + 800
  A[5, "X", 1] <- A[5, "X", 1] + 900

  out <- suppressMessages(correct_geometry(A))
  geom_check <- correct_landmarks(out, rule = "check_geometry")
  coord_checks <- c(
    "perpendicular_seg_1_9_vs_axis", "perpendicular_seg_3_4_vs_axis",
    "perpendicular_seg_10_11_vs_axis", "perpendicular_eye_vertical_vs_axis",
    "axis_horizontal_parallel"
  )
  expect_true(all(geom_check$ok[geom_check$check %in% coord_checks]))
})

test_that("correct_geometry() warns and skips rotation/step 4 when landmark 1 or 2 is missing", {
  A <- make_std_source_array()
  A[2, , 1] <- NA_real_

  expect_warning(out <- suppressMessages(correct_geometry(A)), "rotate/correct")
  log <- attr(out, "standardization_log")
  expect_false(is.na(log$scale_factor)) # step 1 still applied
  expect_true(is.na(log$rotation_deg)) # step 3 skipped
  expect_null(attr(out, "correction_log")) # step 4 skipped
})

test_that("correct_geometry() skips scale bar repositioning when landmarks 20/21 are missing", {
  A <- make_std_source_array()
  A[20, , 1] <- NA_real_

  out <- suppressMessages(correct_geometry(A))
  log <- attr(out, "standardization_log")
  expect_false(log$scale_bar_placed)
  expect_true(anyNA(out[20, , 1]))
})

test_that("correct_geometry() errors below 21 landmarks", {
  A <- array(0, dim = c(19, 2, 1), dimnames = list(NULL, NULL, "s1"))
  expect_error(correct_geometry(A), "21")
})

test_that("correct_geometry() errors on non-2D arrays", {
  A <- array(0, dim = c(21, 3, 1))
  expect_error(correct_geometry(A), "two-dimensional")
})

test_that("correct_geometry() errors on an invalid `scale_bar_pos`", {
  A <- make_std_source_array()
  expect_error(correct_geometry(A, scale_bar_pos = c(0.1, 0.1, 0.1)), "scale_bar_pos")
  expect_error(correct_geometry(A, scale_bar_pos = c(NA, 0.1)), "scale_bar_pos")
})

test_that("correct_geometry() keeps `landmarks$scale` consistent with rescaled coordinates, preserving true real-world size", {
  # Real-world Bl (distance between landmarks 1 and 2) before standardization:
  # raw distance is exactly 8000 (see make_std_source_array()'s comment
  # above), so at scale = 0.02 real-world-units per pixel, real Bl = 160.
  A <- make_std_source_array()
  landmarks <- structure(
    list(coords = A, scale = c(s1 = 0.02), metadata = NULL),
    class = "intrait_landmarks"
  )
  bl_before <- linear_distances(A, list(Bl = c(1, 2)), scale = c(s1 = 0.02))

  out <- suppressMessages(correct_geometry(landmarks))
  expect_s3_class(out, "intrait_landmarks")

  # scale_factor for this fixture is 1 / 8000 (see make_std_source_array());
  # landmarks$scale must be divided by it to stay calibrated for the
  # now-rescaled coordinates.
  expect_equal(out$scale[["s1"]], 0.02 / (1 / 8000))

  # Core invariant explicitly requested: a real-world distance computed
  # after correct_geometry() (via the automatically-used, rescaled
  # landmarks$scale) must be identical to the one computed before it, even
  # though the raw/digitized coordinates themselves are now rescaled to fit
  # inside [0, 1] -- i.e. only the *visual* size changed, never the true one.
  bl_after <- linear_distances(out, list(Bl = c(1, 2)))
  expect_equal(bl_after["s1", "Bl"], bl_before["s1", "Bl"])
})

test_that("correct_geometry() preserves each specimen's own distinct true size even though every specimen is drawn at the same visual size", {
  A <- make_std_source_array(c("s1", "s2"))
  # Make s2 a physically larger fish: scale its body landmarks (1-19) by 1.5
  # around landmark 1 (uniform scaling about a body point preserves axis
  # (1, 2)'s direction, so rotation_deg stays 0 for both specimens; the
  # scale bar, 20-21, is left as-is here since it is unrelated to body size).
  pivot <- A[1, , "s2"]
  for (li in 1:19) A[li, , "s2"] <- pivot + (A[li, , "s2"] - pivot) * 1.5

  landmarks <- structure(
    list(coords = A, scale = c(s1 = 0.02, s2 = 0.02), metadata = NULL),
    class = "intrait_landmarks"
  )
  bl_before <- linear_distances(A, list(Bl = c(1, 2)), scale = c(s1 = 0.02, s2 = 0.02))

  out <- suppressMessages(correct_geometry(landmarks))

  # Both specimens are now drawn at the same visual size...
  expect_equal(unname(out$coords[1, , "s1"]), c(0, 0.5))
  expect_equal(unname(out$coords[2, , "s1"]), c(1, 0.5))
  expect_equal(unname(out$coords[1, , "s2"]), c(0, 0.5))
  expect_equal(unname(out$coords[2, , "s2"]), c(1, 0.5))

  # ...yet their true real-world sizes, recovered via the independently
  # rescaled landmarks$scale, remain distinct and exactly match what they
  # were before standardization.
  bl_after <- linear_distances(out, list(Bl = c(1, 2)))
  expect_equal(bl_after["s1", "Bl"], bl_before["s1", "Bl"])
  expect_equal(bl_after["s2", "Bl"], bl_before["s2", "Bl"])
  expect_true(bl_after["s2", "Bl"] > bl_after["s1", "Bl"])
})

test_that("correct_geometry() leaves a raw (non-classed) array's behaviour unchanged when there is no `$scale` to update", {
  # Backward-compatibility check: every pre-existing test in this file uses
  # a raw array, for which `has_scale_attr` is FALSE and this code path is
  # a no-op; this test pins that down explicitly.
  A <- make_std_source_array()
  out <- suppressMessages(correct_geometry(A))
  expect_true(is.array(out))
  expect_false(inherits(out, "intrait_landmarks"))
})

test_that("correct_geometry() errors on an invalid `tolerance_coord`", {
  A <- make_std_source_array()
  expect_error(correct_geometry(A, tolerance_coord = -1), "tolerance_coord")
})
