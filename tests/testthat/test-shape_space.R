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
    ell <- Rfishmorph:::.covariance_ellipse(ms$scores[idx, 1], ms$scores[idx, 2])
    if (is.null(ell)) next
    expect_true(all(ell[, 1] >= usr[1] & ell[, 1] <= usr[2]))
    expect_true(all(ell[, 2] >= usr[3] & ell[, 2] <= usr[4]))
  }
})
