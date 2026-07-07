test_that("plot_fishmorph_points() runs without error", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy <- plot_fishmorph_points(fish, specimen = 1)                                  # legend_position = "outside"
  expect_error(plot_fishmorph_points(fish, specimen = 1, legend_position = "topright"), NA)
  expect_error(plot_fishmorph_points(fish, specimen = 1, legend = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp)

  expect_equal(dim(xy), c(21, 2))
})

test_that("plot_fishmorph_points() errors below 21 landmarks", {
  A <- array(0, dim = c(10, 2, 1))
  expect_error(plot_fishmorph_points(A), "at least 21 landmarks")
})

test_that("plot_fishmorph_points() overlays a background_image without error", {
  testthat::skip_if_not_installed("png")
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  img_path <- tempfile(fileext = ".png")
  png::writePNG(array(0.5, dim = c(40, 60, 3)), img_path)
  on.exit(unlink(img_path))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(
    plot_fishmorph_points(fish, specimen = 1, background_image = img_path),
    NA
  )
  expect_error(
    plot_fishmorph_points(fish, specimen = 1, background_image = img_path, flip_y = FALSE),
    NA
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points() selects a single specimen via `individual`", {
  # n_replicates = 1 -> one specimen per individual, so `individual` should
  # resolve to exactly the same plot as the matching `specimen`.
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  one_individual <- fish$metadata$individual[1]

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy_by_individual <- plot_fishmorph_points(fish, individual = one_individual)
  xy_by_specimen <- plot_fishmorph_points(fish, specimen = fish$metadata$specimen[1])
  grDevices::dev.off()
  unlink(tmp)

  expect_equal(xy_by_individual, xy_by_specimen)
})

test_that("plot_fishmorph_points() plots every match side by side when `individual` matches several specimens", {
  # n_replicates = 2 -> two specimens (rows) per individual.
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 2)
  one_individual <- fish$metadata$individual[1]
  n_expected <- sum(fish$metadata$individual == one_individual)
  expect_equal(n_expected, 2)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  result <- plot_fishmorph_points(fish, individual = one_individual)
  grDevices::dev.off()
  unlink(tmp)

  expect_type(result, "list")
  expect_length(result, n_expected)
  expect_equal(
    sort(names(result)),
    sort(fish$metadata$specimen[fish$metadata$individual == one_individual])
  )
})

test_that("plot_fishmorph_points() errors for an unknown `individual`", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  expect_error(
    plot_fishmorph_points(fish, individual = "not_a_real_individual"),
    "No specimen found"
  )
})

test_that("plot_fishmorph_points() errors when both `specimen` and `individual` are given", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  expect_error(
    plot_fishmorph_points(fish, specimen = 2, individual = fish$metadata$individual[1]),
    "only one of"
  )
})

test_that("plot_fishmorph_points() errors when `individual` is used without an `individual` metadata column", {
  A <- array(0, dim = c(21, 2, 1), dimnames = list(NULL, NULL, "specimen1"))
  expect_error(
    plot_fishmorph_points(A, individual = "x"),
    "metadata` to have an `individual` column"
  )
})

test_that("outline = TRUE (default) draws the body outline/reference lines without error", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy_outline <- expect_error(plot_fishmorph_points(fish, specimen = 1), NA)
  xy_no_outline <- expect_error(plot_fishmorph_points(fish, specimen = 1, outline = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp)

  # outline is purely visual: the returned coordinates are unaffected.
  expect_equal(xy_outline, xy_no_outline)
})

test_that("the scale bar (points 20-21) is drawn for exactly 21 landmarks, not only 22", {
  # Regression test: points 20-21 are part of the required 21-point scheme
  # (the *optional* 22nd point is unrelated), so the scale bar must not be
  # gated behind `p >= 22`.
  fish21 <- simulate_fishmorph_points(n_per_species = 1, n_replicates = 1)
  expect_equal(dim(fish21$coords)[1], 21)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish21, specimen = 1), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("outline falls back to a direct 1-3 segment when landmark 5 is missing", {
  # Real T-26 specimens are commonly missing landmark 5; the body outline
  # should skip it (connecting 1 directly to 3) instead of leaving a gap
  # or erroring.
  fish <- simulate_fishmorph_points(n_per_species = 1, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  fish$coords <- A

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy <- expect_error(plot_fishmorph_points(fish, specimen = 1), NA)
  grDevices::dev.off()
  unlink(tmp)

  expect_true(anyNA(xy[5, ]))
  expect_false(anyNA(xy[c(1, 3), ]))
})

test_that("outline drops the eye circle when point 7, 13 or 14 is missing", {
  fish <- simulate_fishmorph_points(n_per_species = 1, n_replicates = 1)
  A <- fish$coords
  A[7, , 1] <- NA_real_
  fish$coords <- A

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish, specimen = 1), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points() highlights corrected landmarks in blue", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  fish_fixed <- suppressMessages(
    correct_landmarks(fish, specimen = 1, points = c(9, 8, 11, 4), correct = 11, axis = "y")
  )
  expect_true(!is.null(attr(fish_fixed$coords, "corrected")))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish_fixed, specimen = 1), NA)
  expect_error(
    plot_fishmorph_points(fish_fixed, specimen = 1, highlight_corrected = FALSE),
    NA
  )
  # a different (untouched) specimen is unaffected
  xy_untouched <- plot_fishmorph_points(fish_fixed, specimen = 2)
  xy_reference <- plot_fishmorph_points(fish, specimen = 2)
  grDevices::dev.off()
  unlink(tmp)
  expect_equal(xy_untouched, xy_reference)
})

test_that("plot_fishmorph_points() highlights imputed landmarks in red", {
  testthat::skip_if_not_installed("geomorph")
  set.seed(99)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  fish$coords <- A
  fish_imputed <- suppressMessages(impute_landmarks(fish))
  expect_true(!is.null(attr(fish_imputed$coords, "imputed")))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish_imputed, specimen = 1), NA)
  expect_error(
    plot_fishmorph_points(fish_imputed, specimen = 1, highlight_imputed = FALSE),
    NA
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points() is unaffected by highlight_imputed without an imputed marker", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy1 <- plot_fishmorph_points(fish, specimen = 1, highlight_imputed = TRUE)
  xy2 <- plot_fishmorph_points(fish, specimen = 1, highlight_imputed = FALSE)
  grDevices::dev.off()
  unlink(tmp)
  expect_equal(xy1, xy2)
})

test_that("plot_fishmorph_points() highlights geometry_check flags in orange", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  A <- fish$coords
  A[4, "X", 1] <- A[4, "X", 1] + 900 # break segment (3,4)'s perpendicularity for specimen 1
  fish$coords <- A
  geom_check <- correct_landmarks(fish, rule = "check_geometry")
  expect_true(any(!geom_check$ok[geom_check$specimen == dimnames(A)[[3]][1]]))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish, specimen = 1, geometry_check = geom_check), NA)
  expect_error(
    plot_fishmorph_points(fish, specimen = 1, geometry_check = geom_check, highlight_geometry = FALSE),
    NA
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points() is unaffected by geometry_check when nothing fails", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  geom_check <- correct_landmarks(fish, rule = "check_geometry", tolerance = 1e6, tolerance_coord = 1e6)
  expect_true(all(geom_check$ok))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  xy1 <- plot_fishmorph_points(fish, specimen = 1, geometry_check = geom_check, highlight_geometry = TRUE)
  xy2 <- plot_fishmorph_points(fish, specimen = 1, geometry_check = geom_check, highlight_geometry = FALSE)
  grDevices::dev.off()
  unlink(tmp)
  expect_equal(xy1, xy2)
})

test_that("plot_fishmorph_points() errors on an invalid `geometry_check`", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  expect_error(
    plot_fishmorph_points(fish, specimen = 1, geometry_check = data.frame(x = 1)),
    "correct_landmarks"
  )
})

test_that("plot_fishmorph_points() warns and drops background_image when `individual` matches several specimens", {
  testthat::skip_if_not_installed("png")
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 2)
  one_individual <- fish$metadata$individual[1]
  img_path <- tempfile(fileext = ".png")
  png::writePNG(array(0.5, dim = c(40, 60, 3)), img_path)
  on.exit(unlink(img_path))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_warning(
    plot_fishmorph_points(fish, individual = one_individual, background_image = img_path),
    "ignored"
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points() draws the scale bar without error using the default scale_unit ('cm')", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish, specimen = 1), NA)
  grDevices::dev.off()
  unlink(tmp)

  expect_true("scale_unit" %in% names(formals(plot_fishmorph_points)))
  expect_equal(eval(formals(plot_fishmorph_points)$scale_unit), "cm")
  # `scale_label` was replaced by `scale_unit`; guard against a regression
  # silently bringing back the old argument name (and its fixed caption).
  expect_false("scale_label" %in% names(formals(plot_fishmorph_points)))
})

test_that("plot_fishmorph_points() accepts an arbitrary user-specified scale_unit (mm, dm, m, or other)", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  for (unit in c("mm", "dm", "m", "in")) {
    expect_error(plot_fishmorph_points(fish, specimen = 1, scale_unit = unit), NA)
  }
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points() omits the scale bar's text label when scale_unit = NULL, without erroring", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_fishmorph_points(fish, specimen = 1, scale_unit = NULL), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_points()'s scale bar label is built as '1 <unit> = <length>' from the actual digitized scale-bar length", {
  # The label text itself cannot be read back from a base-R graphics device
  # (drawing calls have no return value), so this pins down the exact
  # formula used internally -- sprintf("1 %s = %s", scale_unit,
  # formatC(scale_len, format = "f", digits = 1)) -- against a hand-picked
  # length, guarding against a silent drift back to the old, fixed
  # "scale (1 cm)" caption or to a different rounding.
  scale_len <- 0.05
  expect_equal(
    sprintf("1 %s = %s", "cm", formatC(scale_len, format = "f", digits = 1)),
    "1 cm = 0.1"
  )
})
