test_that("bootstrap_functional_space() runs on an intrait_traitspace object", {
  testthat::skip_if_not_installed("geometry")

  set.seed(1)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 50)

  expect_s3_class(bf, "intrait_bootstrap_fspace")
  expect_equal(bf$n_axes, 2)
  expect_length(bf$fd_boot, 50)
  expect_true(is.finite(bf$fd_ref) && bf$fd_ref >= 0)
  expect_true(all(bf$fd_boot[!is.na(bf$fd_boot)] >= 0))
  expect_true(bf$p_value >= 0 && bf$p_value <= 1)
  expect_equal(bf$fd_boot_mean, mean(bf$fd_boot, na.rm = TRUE))
  expect_true(bf$fd_boot_q05 <= bf$fd_boot_mean && bf$fd_boot_mean <= bf$fd_boot_q95)
})

test_that("bootstrap_functional_space() runs on a raw trait table with explicit groups", {
  testthat::skip_if_not_installed("geometry")

  set.seed(2)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  bf <- bootstrap_functional_space(ratios, groups = fish$metadata$species,
                                    n_axes = 2, n_boot = 50)
  expect_s3_class(bf, "intrait_bootstrap_fspace")
})

test_that("bootstrap_functional_space() auto-selects n_axes from var_threshold", {
  testthat::skip_if_not_installed("geometry")

  set.seed(3)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(ts, n_boot = 30, var_threshold = 0.5)
  expect_true(bf$n_axes >= 2)
  expect_true(bf$var_explained >= 0.5)
})

test_that("bootstrap_functional_space() detects a strong, real excess of individual-based volume over the centroid reference", {
  testthat::skip_if_not_installed("geometry")

  # 20 species arranged on a circle, each with several individuals jittered
  # around their own position: this configuration (verified independently
  # in Python/scipy before being encoded here as an R regression test) was
  # checked to reliably give both a positive fd_boot_mean - fd_ref shift
  # and a significant p-value across many random seeds, unlike a
  # too-small/low-dimensional toy example (e.g. 3-4 species), where
  # bootstrap sampling variability alone can dominate the signal and the
  # test is underpowered essentially by construction, not because the
  # method is wrong.
  set.seed(42)
  n_species <- 20
  n_ind <- 15
  radius <- 10
  jitter_sd <- 3.5
  angles <- seq(0, 2 * pi, length.out = n_species + 1)[seq_len(n_species)]
  centers <- data.frame(cx = radius * cos(angles), cy = radius * sin(angles),
                         species = paste0("sp", seq_len(n_species)))

  df <- do.call(rbind, lapply(seq_len(nrow(centers)), function(i) {
    data.frame(
      a = centers$cx[i] + stats::rnorm(n_ind, sd = jitter_sd),
      b = centers$cy[i] + stats::rnorm(n_ind, sd = jitter_sd),
      species = centers$species[i]
    )
  }))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, n_axes = 2,
    n_boot = 300, log_transform = FALSE, scale = FALSE
  )

  expect_true(bf$fd_boot_mean > bf$fd_ref)
  expect_true(bf$diff > 0)
  expect_true(bf$p_value < 0.05)
})

test_that("bootstrap_functional_space() stays non-significant when intraspecific variability is negligible", {
  testthat::skip_if_not_installed("geometry")

  # Same layout as above, but with essentially no within-species jitter:
  # fd_boot should coincide with fd_ref (every bootstrap draw is
  # effectively the species centroid itself), so the test must NOT
  # spuriously report significance -- a calibration check for the
  # bootstrap p-value, complementing the "detects a real effect" test.
  set.seed(43)
  n_species <- 20
  n_ind <- 15
  radius <- 10
  angles <- seq(0, 2 * pi, length.out = n_species + 1)[seq_len(n_species)]
  centers <- data.frame(cx = radius * cos(angles), cy = radius * sin(angles),
                         species = paste0("sp", seq_len(n_species)))

  df <- do.call(rbind, lapply(seq_len(nrow(centers)), function(i) {
    data.frame(
      a = centers$cx[i] + stats::rnorm(n_ind, sd = 1e-6),
      b = centers$cy[i] + stats::rnorm(n_ind, sd = 1e-6),
      species = centers$species[i]
    )
  }))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, n_axes = 2,
    n_boot = 300, log_transform = FALSE, scale = FALSE
  )

  expect_true(bf$p_value > 0.1)
})

test_that("bootstrap_functional_space() errors on invalid input", {
  testthat::skip_if_not_installed("geometry")

  expect_error(bootstrap_functional_space(list()), "intrait_traitspace")
  expect_error(
    bootstrap_functional_space(data.frame(a = 1:9, b = 1:9)),
    "`groups` is required"
  )
  expect_error(
    bootstrap_functional_space(
      data.frame(a = 1:9, b = 1:9),
      groups = rep(c("G1", "G2"), c(5, 4))
    ),
    "at least 3 levels"
  )
})

test_that("bootstrap_functional_space() errors when trait_space() object lacks groups", {
  testthat::skip_if_not_installed("geometry")

  df <- data.frame(a = c(1, 10, 100, 5, 50), b = c(2, 20, 200, 10, 100))
  ts_nogroups <- trait_space(df, log_transform = TRUE, scale = FALSE)
  expect_error(bootstrap_functional_space(ts_nogroups), "has no `groups`")
})

test_that("bootstrap_functional_space() errors when `n_axes` leaves too few species for a non-degenerate hull", {
  testthat::skip_if_not_installed("geometry")

  set.seed(4)
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  # simulate_fishmorph_points() has 3 species; n_axes = 3 leaves no slack
  # (nlevels(groups) must be strictly greater than n_axes)
  expect_error(bootstrap_functional_space(ts, n_axes = 3), "requires more than")
})

test_that("bootstrap_functional_space() validates `n_axes` and `n_boot`", {
  testthat::skip_if_not_installed("geometry")

  set.seed(5)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  expect_error(bootstrap_functional_space(ts, n_axes = 1), ">= 2")
  expect_error(bootstrap_functional_space(ts, n_axes = 2, n_boot = 0), "positive integer")
})

test_that("bootstrap_functional_space() errors informatively without the geometry package", {
  testthat::skip_if(
    requireNamespace("geometry", quietly = TRUE),
    "geometry is installed; cannot test the missing-package error message"
  )
  df <- data.frame(a = 1:9, b = 1:9)
  expect_error(
    bootstrap_functional_space(df, groups = rep(c("G1", "G2", "G3"), 3)),
    "geometry"
  )
})

test_that("print.intrait_bootstrap_fspace() and plot.intrait_bootstrap_fspace() do not error", {
  testthat::skip_if_not_installed("geometry")

  set.seed(6)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))
  bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 30)

  expect_output(print(bf), "intrait_bootstrap_fspace")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(bf), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that(".convex_hull_volume() returns NA for degenerate point sets rather than erroring", {
  testthat::skip_if_not_installed("geometry")

  # fewer points than dimensions + 1
  expect_true(is.na(intraitR:::.convex_hull_volume(matrix(1:4, nrow = 2, ncol = 2))))
  # collinear points in 2D (zero-area hull): qhull errors on this input,
  # which must be caught and returned as NA, not propagated
  collinear <- cbind(x = 1:5, y = 1:5)
  expect_true(is.na(intraitR:::.convex_hull_volume(collinear)))
})

test_that(".convex_hull_volume() computes the known volume of a unit hypercube's vertices", {
  testthat::skip_if_not_installed("geometry")

  # all 8 vertices of the unit cube in 3D: convex hull volume is exactly 1
  cube <- as.matrix(expand.grid(x = c(0, 1), y = c(0, 1), z = c(0, 1)))
  expect_equal(intraitR:::.convex_hull_volume(cube), 1, tolerance = 1e-6)
})
