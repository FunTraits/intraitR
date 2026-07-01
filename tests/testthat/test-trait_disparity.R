test_that("trait_disparity() runs on an intrait_traitspace object", {
  set.seed(1)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  td <- trait_disparity(ts, iter = 49)

  expect_s3_class(td, "intrait_disparity")
  expect_length(td$disparity, 3)
  expect_equal(names(td$disparity), levels(ts$groups))
  expect_true(all(td$disparity >= 0))
  expect_equal(dim(td$pairwise_diff), c(3, 3))
  expect_equal(dim(td$pairwise_p), c(3, 3))
  expect_true(all(diag(td$pairwise_diff) == 0 | is.na(diag(td$pairwise_diff))))
  expect_true(all(td$pairwise_p[upper.tri(td$pairwise_p)] >= 0 &
                     td$pairwise_p[upper.tri(td$pairwise_p)] <= 1, na.rm = TRUE))
})

test_that("trait_disparity() runs on a raw trait table with explicit groups", {
  set.seed(2)
  df <- data.frame(
    a = c(rnorm(10, 5, 1), rnorm(10, 5, 3)),
    b = c(rnorm(10, 2, 1), rnorm(10, 2, 3))
  )
  groups <- rep(c("G1", "G2"), each = 10)

  # log_transform = FALSE: with sd = 3, some simulated values fall below
  # zero, which log10(x + 1) does not support (see trait_space()).
  td <- trait_disparity(df, groups = groups, iter = 49, log_transform = FALSE)
  expect_s3_class(td, "intrait_disparity")
  expect_length(td$disparity, 2)
  # G2 was simulated with 3x the SD of G1 on every trait: its trait
  # variance (sum of per-trait variances) should be detectably larger.
  expect_true(td$disparity[["G2"]] > td$disparity[["G1"]])
})

test_that("trait_disparity() recovers a low p-value for a strong, real dispersion difference", {
  set.seed(3)
  n <- 25
  df <- data.frame(
    a = c(rnorm(n, 5, 0.5), rnorm(n, 5, 5)),
    b = c(rnorm(n, 2, 0.5), rnorm(n, 2, 5)),
    c = c(rnorm(n, 1, 0.5), rnorm(n, 1, 5))
  )
  groups <- rep(c("Low", "High"), each = n)

  td <- trait_disparity(df, groups = groups, iter = 499, log_transform = FALSE)
  expect_true(td$pairwise_p["Low", "High"] < 0.05)
})

test_that("trait_disparity() errors on invalid input", {
  expect_error(trait_disparity(list()), "intrait_traitspace")
  expect_error(trait_disparity(data.frame(a = 1:6, b = 1:6)), "`groups` is required")
  expect_error(
    trait_disparity(data.frame(a = 1:6, b = 1:6), groups = rep("only_one_group", 6)),
    "at least two levels"
  )
})

test_that("trait_disparity() errors when trait_space() object lacks groups", {
  df <- data.frame(a = c(1, 10, 100), b = c(2, 20, 200))
  ts_nogroups <- trait_space(df, log_transform = TRUE, scale = FALSE)
  expect_error(trait_disparity(ts_nogroups), "has no `groups`")
})

test_that("print.intrait_disparity() prints without error", {
  set.seed(4)
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))
  td <- trait_disparity(ts, iter = 29)
  expect_output(print(td), "intrait_disparity")
})
