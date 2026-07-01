test_that("morpho_space() builds a PCA-based morphospace", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 8, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- morpho_space(gpa, groups = fish$metadata$species)

  expect_s3_class(ms, "intrait_morphospace")
  expect_equal(nrow(ms$scores), dim(gpa$coords)[3])
  expect_equal(ncol(ms$scores), 2)
  expect_length(ms$var_explained, 2)
  expect_true(all(ms$var_explained >= 0 & ms$var_explained <= 100))
})

test_that("morpho_space() auto-detects species from metadata", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  gpa$metadata <- fish$metadata
  ms <- morpho_space(gpa)

  expect_false(is.null(ms$groups))
  expect_equal(nlevels(ms$groups), 3)
})

test_that("morpho_space() errors on invalid input", {
  expect_error(morpho_space(list()), "must be an object returned by gpa_fish")
})

test_that("plot.intrait_morphospace() does not error, in any style", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- morpho_space(gpa, groups = fish$metadata$species)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(ms), NA)                  # default: style = "spider"
  expect_error(plot(ms, style = "hull"), NA)
  expect_error(plot(ms, style = "none"), NA)
  grDevices::dev.off()
  unlink(tmp)
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
