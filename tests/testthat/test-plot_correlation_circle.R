test_that("plot_correlation_circle() requires an intrait_traitspace object", {
  expect_error(
    plot_correlation_circle(list(scores = data.frame(PC1 = 1:3, PC2 = 1:3))),
    "intrait_traitspace"
  )
})

test_that("plot_correlation_circle() returns trait-axis correlations matching cor(X, scores)", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  expected <- stats::cor(ts$X, as.matrix(ts$scores))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  cors <- plot_correlation_circle(ts)
  grDevices::dev.off()
  unlink(tmp)

  expect_equal(cors, expected)
  # Every trait-axis correlation must lie within the unit circle, by
  # construction (Pearson correlations are bounded in [-1, 1]).
  expect_true(all(abs(cors) <= 1 + 1e-8))
  expect_identical(rownames(cors), ts$traits_used)
})

test_that("plot_correlation_circle() works for method = \"pcoa\" too", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species, method = "pcoa"))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(cors <- plot_correlation_circle(ts), NA)
  grDevices::dev.off()
  unlink(tmp)

  expect_true(all(abs(cors) <= 1 + 1e-8))
})

test_that("plot_correlation_circle() honours inner_circle = FALSE without erroring", {
  testthat::skip_if_not_installed("geomorph")

  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot_correlation_circle(ts, inner_circle = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp)
})
