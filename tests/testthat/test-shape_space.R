test_that("shape_space() builds a PCA-based shape space", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- shape_space(gpa, groups = fish$metadata$species)

  expect_s3_class(ms, "intrait_shapespace")
  expect_equal(nrow(ms$scores), dim(gpa$coords)[3])
  expect_equal(ncol(ms$scores), 2)
  expect_length(ms$var_explained, 2)
  expect_true(all(ms$var_explained >= 0 & ms$var_explained <= 100))
})

test_that("shape_space() auto-detects species from metadata", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  gpa$metadata <- fish$metadata
  ms <- shape_space(gpa)

  expect_false(is.null(ms$groups))
  expect_equal(nlevels(ms$groups), 3)
})

test_that("shape_space() errors on invalid input", {
  expect_error(shape_space(list()), "must be an object returned by gpa_fish")
})

test_that("plot.intrait_shapespace() does not error, in any style", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- shape_space(gpa, groups = fish$metadata$species)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(ms), NA)                  # default: style = "spider", legend_position = "outside"
  expect_error(plot(ms, style = "hull"), NA)
  expect_error(plot(ms, style = "density"), NA)
  expect_error(plot(ms, style = "none"), NA)
  expect_error(plot(ms, legend_position = "topright"), NA)   # legend inside the plot box, as before
  expect_error(plot(ms, legend = FALSE), NA)
  expect_error(
    plot(ms, legend_title = "Species", legend_italic = TRUE, abbreviate_species = TRUE),
    NA
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot.intrait_shapespace()'s automatic axis limits fully contain the group ellipses", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- shape_space(gpa, groups = fish$metadata$species)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  plot(ms, style = "spider")
  usr <- graphics::par("usr")   # c(x1, x2, y1, y2) of the established plot region
  grDevices::dev.off()
  unlink(tmp)

  # recompute each group's ellipse independently and check it falls inside
  # the plot region the function actually established -- i.e. the ellipse
  # is not silently clipped at the box edge (the bug this test guards
  # against: axis limits sized only to the raw points, not the geometry
  # drawn on top of them).
  for (g in levels(ms$groups)) {
    idx <- ms$groups == g
    ell <- intraitR:::.covariance_ellipse(ms$scores[idx, 1], ms$scores[idx, 2])
    if (is.null(ell)) next
    expect_true(all(ell[, 1] >= usr[1] & ell[, 1] <= usr[2]))
    expect_true(all(ell[, 2] >= usr[3] & ell[, 2] <= usr[4]))
  }
})

test_that(".abbreviate_species_name() abbreviates clean binomials only", {
  expect_equal(intraitR:::.abbreviate_species_name("Barbatula barbatula"), "B. barbatula")
  expect_equal(intraitR:::.abbreviate_species_name("Gobio occitaniae"), "G. occitaniae")
  # informal multi-taxon labels: only the first word is abbreviated
  expect_equal(
    intraitR:::.abbreviate_species_name("Phoxinus phoxinus/bigerri"),
    "P. phoxinus/bigerri"
  )
  # not a clean binomial: left unchanged rather than mangled
  expect_equal(intraitR:::.abbreviate_species_name("unresolved"), "unresolved")
  expect_equal(intraitR:::.abbreviate_species_name(""), "")
  # vectorised, preserves order and length
  expect_equal(
    intraitR:::.abbreviate_species_name(c("Barbatula barbatula", "Gobio occitaniae")),
    c("B. barbatula", "G. occitaniae")
  )
})

test_that(".ordination_palette() returns one distinct colour per group, any size", {
  p5 <- intraitR:::.ordination_palette(5)
  expect_length(p5, 5)
  expect_equal(length(unique(p5)), 5)

  p10 <- intraitR:::.ordination_palette(10)
  expect_length(p10, 10)
  expect_equal(length(unique(p10)), 10)

  # more groups than the curated palette has colours: falls back gracefully
  p15 <- intraitR:::.ordination_palette(15)
  expect_length(p15, 15)
})

test_that(".kde2d() and .density_contour() produce a sensible bivariate density estimate", {
  set.seed(11)
  n <- 200
  x <- stats::rnorm(n, mean = 3, sd = 1)
  y <- stats::rnorm(n, mean = -1, sd = 2)

  kd <- intraitR:::.kde2d(x, y, n = 40)
  expect_equal(length(kd$x), 40)
  expect_equal(length(kd$y), 40)
  expect_equal(dim(kd$z), c(40, 40))
  expect_true(all(kd$z >= 0))
  # the grid must comfortably contain the data (padded on both sides)
  expect_true(min(kd$x) < min(x) && max(kd$x) > max(x))
  expect_true(min(kd$y) < min(y) && max(kd$y) > max(y))

  contours <- intraitR:::.density_contour(x, y, level = 0.5)
  expect_true(is.list(contours))
  expect_true(length(contours) >= 1)
  expect_true(all(c("x", "y", "level") %in% names(contours[[1]])))

  # too few points: skipped gracefully rather than erroring
  expect_null(intraitR:::.density_contour(x[1:3], y[1:3]))
})

test_that(".covariance_ellipse() traces a level-consistent dispersion ellipse", {
  set.seed(42)
  n <- 300
  x <- stats::rnorm(n, mean = 2, sd = 3)
  y <- 0.5 * x + stats::rnorm(n, sd = 1)

  level <- 0.95
  ell <- intraitR:::.covariance_ellipse(x, y, level = level)
  expect_true(is.matrix(ell))
  expect_equal(ncol(ell), 2)

  # Points on the ellipse should all sit at (approximately) the same
  # Mahalanobis distance from the centroid, equal to sqrt(qchisq(level, 2)).
  S <- stats::cov(cbind(x, y))
  Sinv <- solve(S)
  centre <- c(mean(x), mean(y))
  d2 <- apply(ell, 1, function(p) {
    dv <- p - centre
    as.numeric(t(dv) %*% Sinv %*% dv)
  })
  expect_true(all(abs(d2 - stats::qchisq(level, df = 2)) < 1e-6))

  # roughly `level` proportion of the underlying data should fall inside
  d2_pts <- apply(cbind(x, y), 1, function(p) {
    dv <- p - centre
    as.numeric(t(dv) %*% Sinv %*% dv)
  })
  frac_inside <- mean(d2_pts <= stats::qchisq(level, df = 2))
  expect_true(abs(frac_inside - level) < 0.05)
})

test_that(".covariance_ellipse() returns NULL for fewer than 3 points", {
  expect_null(intraitR:::.covariance_ellipse(c(1, 2), c(1, 2)))
})
