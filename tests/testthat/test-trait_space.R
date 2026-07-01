test_that("trait_space() builds a PCA ordination with correct dimensions", {
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  # `ratios` carries non-numeric metadata (specimen, individual, species,
  # population) and a constant `replicate` column (n_replicates = 1);
  # trait_space() drops both with informative warnings, which are expected
  # here and therefore suppressed rather than left to clutter test output.
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  expect_s3_class(ts, "intrait_traitspace")
  expect_equal(nrow(ts$scores), nrow(ratios))
  expect_equal(ncol(ts$scores), 2)
  expect_length(ts$var_explained, 2)
  expect_true(all(ts$var_explained >= 0 & ts$var_explained <= 100))
  expect_equal(nlevels(ts$groups), 3)
})

test_that("trait_space() auto-detects a species column", {
  fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ratios$species <- fish$metadata$species

  ts <- suppressWarnings(trait_space(ratios))
  expect_false(is.null(ts$groups))
  expect_equal(nlevels(ts$groups), 3)
})

test_that("trait_space() supports method = 'pcoa'", {
  fish <- simulate_fishmorph_points(n_per_species = 8, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  ts <- suppressWarnings(
    trait_space(ratios[, setdiff(names(ratios), "species")], method = "pcoa")
  )
  expect_equal(ts$method, "pcoa")
  expect_true(all(grepl("^MDS", names(ts$scores))))
})

test_that("trait_space() warns about dropped non-numeric and constant columns", {
  fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  expect_warning(trait_space(ratios, groups = fish$metadata$species), "non-numeric column")
  expect_warning(trait_space(ratios, groups = fish$metadata$species), "constant \\(zero-variance\\) column")
})

test_that("trait_space() errors with fewer than two numeric columns", {
  expect_error(trait_space(data.frame(x = 1:5)), "at least two numeric columns")
})

test_that("trait_space() errors on missing values", {
  df <- data.frame(a = c(1, NA, 3), b = c(1, 2, 3))
  expect_error(trait_space(df), "missing values")
})

test_that("plot.intrait_traitspace() does not error, in any style", {
  fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(ts), NA)
  expect_error(plot(ts, style = "hull"), NA)
  expect_error(plot(ts, style = "none"), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("trait_space() log-transforms traits by default", {
  df <- data.frame(a = c(1, 10, 100), b = c(2, 20, 200))
  ts_log <- trait_space(df, log_transform = TRUE, scale = FALSE)
  ts_raw <- trait_space(df, log_transform = FALSE, scale = FALSE)
  expect_false(isTRUE(all.equal(ts_log$scores, ts_raw$scores)))

  # manual PCA on log10(x + 1) should match trait_space()'s PC1 up to sign
  manual <- stats::prcomp(log10(as.matrix(df) + 1), center = TRUE, scale. = FALSE)
  ratio <- ts_log$scores[[1]] / manual$x[, 1]
  expect_true(all(abs(abs(ratio) - 1) < 1e-8))
})

test_that("trait_space() errors when log_transform = TRUE meets negative values", {
  df <- data.frame(a = c(-1, 2, 3), b = c(1, 2, 3))
  expect_error(trait_space(df, log_transform = TRUE), "non-negative")
  expect_error(trait_space(df, log_transform = FALSE), NA)
})

test_that("trait_space() na_action = 'fail' (default) still errors on missing values", {
  df <- data.frame(a = c(1, NA, 3), b = c(1, 2, 3))
  expect_error(trait_space(df), "missing values")
  expect_error(trait_space(df, na_action = "fail"), "missing values")
})

test_that("trait_space() na_action = 'omit' drops incomplete rows and messages", {
  df <- data.frame(a = c(1, NA, 3, 4), b = c(1, 2, 3, 4))
  expect_message(
    ts <- trait_space(df, na_action = "omit", log_transform = FALSE),
    "removing 1 row"
  )
  expect_equal(nrow(ts$scores), 3)
})

test_that("trait_space() na_action = 'omit' also subsets groups", {
  df <- data.frame(a = c(1, NA, 3, 4), b = c(1, 2, 3, 4))
  groups <- c("A", "A", "B", "B")
  ts <- suppressMessages(
    trait_space(df, groups = groups, na_action = "omit", log_transform = FALSE)
  )
  expect_equal(nrow(ts$scores), 3)
  expect_equal(length(ts$groups), 3)
  expect_equal(as.character(ts$groups), c("A", "B", "B"))
})

test_that("trait_space() na_action = 'impute_mean' fills NAs with column means", {
  df <- data.frame(a = c(2, NA, 4, 6), b = c(1, 2, 3, 4))
  expect_message(
    ts <- trait_space(df, na_action = "impute_mean", log_transform = FALSE, scale = FALSE),
    "imputed 1 missing value"
  )
  expect_equal(nrow(ts$scores), 4)
  # mean of a excluding NA is (2+4+6)/3 = 4; imputed row 2 should not be an
  # extreme outlier on PC1 relative to the other rows.
  expect_false(anyNA(ts$scores))
})

test_that("trait_space() na_action = 'impute_group_mean' uses within-group means", {
  df <- data.frame(
    a = c(1, 2, NA, 10, 11, 12),
    b = c(1, 2, 3, 10, 11, 12)
  )
  groups <- c("Low", "Low", "Low", "High", "High", "High")
  expect_message(
    ts <- trait_space(
      df, groups = groups, na_action = "impute_group_mean",
      log_transform = FALSE, scale = FALSE
    ),
    "imputed 1 missing value"
  )
  expect_false(anyNA(ts$scores))
})

test_that("trait_space() na_action = 'impute_group_mean' requires groups", {
  df <- data.frame(a = c(1, NA, 3), b = c(1, 2, 3))
  expect_error(
    trait_space(df, na_action = "impute_group_mean"),
    "requires `groups`"
  )
})

test_that("trait_space() na_action = 'missforest' imputes missing values using groups", {
  testthat::skip_if_not_installed("missForest")

  set.seed(123)
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  na_idx <- sample(seq_len(nrow(ratios)), 5)
  ratios$BEl[na_idx[1:3]] <- NA
  ratios$VEp[na_idx[4:5]] <- NA

  expect_message(
    ts <- suppressWarnings(trait_space(
      ratios, groups = fish$metadata$species,
      na_action = "missforest", log_transform = FALSE,
      missforest_ntree = 20, missforest_maxiter = 2
    )),
    "missforest"
  )

  expect_s3_class(ts, "intrait_traitspace")
  expect_false(anyNA(ts$scores))
  expect_equal(nrow(ts$scores), nrow(ratios))
})

test_that("trait_space() na_action = 'missforest' also works without groups", {
  testthat::skip_if_not_installed("missForest")

  set.seed(124)
  df <- data.frame(
    a = rnorm(40, 5, 1), b = rnorm(40, 2, 1), c = rnorm(40, 1, 1)
  )
  df$a[c(3, 10, 20)] <- NA

  expect_message(
    ts <- trait_space(
      df, na_action = "missforest", log_transform = FALSE,
      missforest_ntree = 20, missforest_maxiter = 2
    ),
    "missforest"
  )
  expect_false(anyNA(ts$scores))
})

test_that("trait_space() na_action = 'missforest' errors informatively without the package", {
  testthat::skip_if(
    requireNamespace("missForest", quietly = TRUE),
    "missForest is installed; cannot test the missing-package error message"
  )
  df <- data.frame(a = c(1, NA, 3), b = c(1, 2, 3))
  expect_error(trait_space(df, na_action = "missforest"), "missForest")
})
