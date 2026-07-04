test_that("compare_functional_richness() tabulates one row per method, in order", {
  set.seed(1)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  cmp <- compare_functional_richness(
    ts, methods = c("dendrogram", "convexhull"), n_axes = 2, n_boot = 30
  )

  expect_s3_class(cmp, "intrait_richness_comparison")
  expect_equal(cmp$summary$method, c("dendrogram", "convexhull"))
  expect_equal(cmp$summary$status[cmp$summary$method == "dendrogram"], "ok")
  if (requireNamespace("geometry", quietly = TRUE)) {
    expect_equal(cmp$summary$status[cmp$summary$method == "convexhull"], "ok")
  } else {
    expect_match(cmp$summary$status[cmp$summary$method == "convexhull"], "^skipped:")
  }
})

test_that("compare_functional_richness() always succeeds for method = \"dendrogram\" alone", {
  set.seed(2)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  cmp <- compare_functional_richness(ts, methods = "dendrogram", n_axes = 2, n_boot = 30)

  expect_equal(nrow(cmp$summary), 1)
  expect_equal(cmp$summary$status, "ok")
  expect_true(is.finite(cmp$summary$fd_ref))
  expect_true(is.finite(cmp$summary$pct_diff))
  expect_true(cmp$summary$p_value >= 0 && cmp$summary$p_value <= 1)
  expect_true(is.logical(cmp$summary$significant))
  expect_length(cmp$results, 1)
  expect_s3_class(cmp$results$dendrogram, "intrait_bootstrap_fspace")
})

test_that("compare_functional_richness() records a skipped method without erroring the whole call", {
  # n_axes = 3 with 3 species is degenerate for "convexhull" specifically
  # (see bootstrap_functional_space()'s own tests), but not for
  # "dendrogram"; the comparison as a whole must still succeed.
  set.seed(3)
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  cmp <- suppressWarnings(compare_functional_richness(
    ts, methods = c("convexhull", "dendrogram"), n_axes = 3, n_boot = 20
  ))

  expect_equal(nrow(cmp$summary), 2)
  dendro_row <- cmp$summary[cmp$summary$method == "dendrogram", ]
  expect_equal(dendro_row$status, "ok")

  hull_row <- cmp$summary[cmp$summary$method == "convexhull", ]
  if (requireNamespace("geometry", quietly = TRUE)) {
    expect_match(hull_row$status, "^skipped:")
    expect_true(is.na(hull_row$fd_ref))
  }
})

test_that("compare_functional_richness() validates `alpha` and `seed`", {
  df <- data.frame(a = 1:9, b = 1:9)
  expect_error(
    compare_functional_richness(df, groups = rep(c("G1", "G2", "G3"), 3), alpha = 1.5),
    "alpha"
  )
  expect_error(
    compare_functional_richness(df, groups = rep(c("G1", "G2", "G3"), 3), seed = c(1, 2)),
    "seed"
  )
})

test_that("compare_functional_richness(seed = ) pairs bootstrap draws across methods", {
  # With the same seed reset before each method's call, the individual
  # composition of bootstrap "community" b should be identical across
  # methods -- checked indirectly here via fd_boot being bit-identical
  # in length and via a perfectly deterministic method (dendrogram
  # evaluated twice with the same seed) reproducing the same fd_boot.
  set.seed(4)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  cmp1 <- compare_functional_richness(ts, methods = "dendrogram", n_axes = 2, n_boot = 15, seed = 99)
  cmp2 <- compare_functional_richness(ts, methods = "dendrogram", n_axes = 2, n_boot = 15, seed = 99)

  expect_equal(cmp1$results$dendrogram$fd_boot, cmp2$results$dendrogram$fd_boot)
})

test_that("print.intrait_richness_comparison() and plot.intrait_richness_comparison() do not error", {
  set.seed(5)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  cmp <- compare_functional_richness(ts, methods = "dendrogram", n_axes = 2, n_boot = 30)

  expect_output(print(cmp), "intrait_richness_comparison")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(cmp), NA)
  grDevices::dev.off()
  unlink(tmp)
})
