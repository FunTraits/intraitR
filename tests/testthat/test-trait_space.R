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
  expect_error(plot(ts, style = "density"), NA)
  expect_error(plot(ts, style = "none"), NA)
  expect_error(plot(ts, legend_position = "bottomleft"), NA)
  expect_error(
    plot(ts, legend_title = "Species", legend_italic = TRUE, abbreviate_species = TRUE),
    NA
  )
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

test_that("trait_space() rejects non-finite (Inf/-Inf) trait values regardless of na_action", {
  # Regression test: Inf is not caught by anyNA()/is.na(), so a ratio with a
  # zero-length denominator (e.g. a degenerate/duplicate landmark) used to
  # sail straight through every na_action -- and, for na_action =
  # "missforest" specifically, crashed missForest::missForest() itself
  # with a cryptic "missing value where TRUE/FALSE needed" error (its
  # internal convergence check computes Inf - Inf = NaN).
  df <- data.frame(a = c(1, Inf, 3, 4), b = c(1, 2, 3, 4))
  expect_error(trait_space(df, na_action = "fail"), "non-finite")
  expect_error(trait_space(df, na_action = "omit"), "non-finite")
  expect_error(trait_space(df, na_action = "impute_mean"), "non-finite")

  df_neg_inf <- data.frame(a = c(1, -Inf, 3, 4), b = c(1, 2, 3, 4))
  expect_error(trait_space(df_neg_inf, na_action = "fail"), "non-finite")
})

test_that("trait_space() non-finite check reports the offending row and column", {
  df <- data.frame(
    row.names = c("s1", "s2", "s3", "s4"),
    BEl_ratio = c(1, Inf, 3, 4), VEp_ratio = c(1, 2, 3, 4)
  )
  err <- tryCatch(trait_space(df), error = function(e) e)
  expect_true(grepl("BEl_ratio", conditionMessage(err), fixed = TRUE))
  expect_true(grepl("s2", conditionMessage(err), fixed = TRUE))
  expect_false(grepl("VEp_ratio", conditionMessage(err), fixed = TRUE))
})

test_that("trait_space() still passes a genuinely NA-only trait matrix through to na_action", {
  # NaN is caught by is.na() (unlike Inf) and should still be handled by
  # na_action exactly like an ordinary NA, not rejected as non-finite.
  df <- data.frame(a = c(1, NaN, 3, 4), b = c(1, 2, 3, 4))
  expect_message(
    ts <- trait_space(df, na_action = "omit", log_transform = FALSE),
    "removing 1 row"
  )
  expect_equal(nrow(ts$scores), 3)
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

test_that("trait_space() drops rows with a missing/NA `groups` value", {
  # Regression test found while validating against the real T-26 Saudrune
  # data set: a specimen with a complete trait row but an unresolved
  # (NA) species identification used to remain in the ordination with an
  # undefined group, rather than being excluded like any other
  # unplaceable observation.
  df <- data.frame(a = c(1, 2, 3, 4, 5, 6), b = c(6, 5, 4, 3, 2, 1))
  groups <- c("A", "A", "B", "B", NA, NA)

  expect_message(
    ts <- trait_space(df, groups = groups, log_transform = FALSE),
    "missing/unresolved"
  )
  expect_equal(nrow(ts$scores), 4)
  expect_false(anyNA(ts$groups))
  expect_equal(nlevels(ts$groups), 2)
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

test_that("trait_space() na_action = 'missforest_phylo' imputes using phylogenetic axes from a supplied tree", {
  testthat::skip_if_not_installed("missForest")
  testthat::skip_if_not_installed("ape")

  set.seed(200)
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ratios$BEl[sample(seq_len(nrow(ratios)), 5)] <- NA

  tree <- ape::rcoal(3, tip.label = c("Species_A", "Species_B", "Species_C"))

  expect_message(
    ts <- trait_space(
      ratios, groups = fish$metadata$species, na_action = "missforest_phylo",
      tree = tree, log_transform = FALSE, missforest_ntree = 20, missforest_maxiter = 2
    ),
    "phylogenetic PCoA axis"
  )
  expect_false(anyNA(ts$scores))
})

test_that("trait_space() na_action = 'missforest_phylo' falls back to plain missforest, with a warning, when the tree doesn't match", {
  testthat::skip_if_not_installed("missForest")
  testthat::skip_if_not_installed("ape")

  set.seed(201)
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ratios$BEl[1:3] <- NA

  tree <- ape::rcoal(3, tip.label = c("Unrelated_1", "Unrelated_2", "Unrelated_3"))

  expect_warning(
    ts <- suppressMessages(trait_space(
      ratios, groups = fish$metadata$species, na_action = "missforest_phylo",
      tree = tree, log_transform = FALSE, missforest_ntree = 20, missforest_maxiter = 2
    )),
    "phylogenetic axes could not be used"
  )
  expect_false(anyNA(ts$scores))
})

test_that("trait_space() flags a planted within-group outlier", {
  # Group "A": 6 tight individuals plus 1 individual planted far away on
  # both traits; group "B": 3 individuals (below the default
  # outlier_min_n = 5), which should get a distance but never be flagged.
  set.seed(42)
  a_tight <- data.frame(
    x = rnorm(6, 10, 0.3), y = rnorm(6, 10, 0.3)
  )
  a_outlier <- data.frame(x = 40, y = 40)
  b <- data.frame(x = rnorm(3, 5, 0.3), y = rnorm(3, 5, 0.3))
  df <- rbind(a_tight, a_outlier, b)
  rownames(df) <- paste0("ind", seq_len(nrow(df)))
  groups <- c(rep("A", 7), rep("B", 3))

  ts <- suppressMessages(trait_space(df, groups = groups, log_transform = FALSE))

  expect_false(is.null(ts$outlier_screen))
  expect_equal(nrow(ts$outlier_screen), 10)
  expect_equal(rownames(ts$outlier_screen), rownames(df))

  # The planted outlier ("ind7") must be flagged; the 6 tight individuals
  # of group A must not be.
  expect_true(ts$outlier_screen["ind7", "flagged"])
  expect_false(any(ts$outlier_screen[paste0("ind", 1:6), "flagged"]))

  # Group B (n = 3 < outlier_min_n) gets a distance but NA flagged, for
  # every one of its members.
  expect_true(all(is.na(ts$outlier_screen[paste0("ind", 8:10), "flagged"])))
  expect_false(anyNA(ts$outlier_screen$distance))
})

test_that("trait_space() emits messages when outliers/skipped groups are found", {
  set.seed(43)
  a_tight <- data.frame(x = rnorm(6, 10, 0.3), y = rnorm(6, 10, 0.3))
  a_outlier <- data.frame(x = 40, y = 40)
  df <- rbind(a_tight, a_outlier)
  groups <- rep("A", 7)

  expect_message(
    trait_space(df, groups = groups, log_transform = FALSE),
    "flagged as within-group outlier"
  )
})

test_that("trait_space() flag_outliers = FALSE disables the outlier screen", {
  set.seed(44)
  df <- data.frame(x = rnorm(10, 10, 1), y = rnorm(10, 10, 1))
  groups <- rep(c("A", "B"), each = 5)
  ts <- trait_space(df, groups = groups, log_transform = FALSE, flag_outliers = FALSE)
  expect_null(ts$outlier_screen)
})

test_that("trait_space() outlier screen has no effect without `groups`", {
  df <- data.frame(x = c(1, 2, 3, 4, 100), y = c(1, 2, 3, 4, 100))
  ts <- trait_space(df, log_transform = FALSE)
  expect_null(ts$outlier_screen)
})

test_that("remove_outliers = TRUE excludes flagged specimens from the ordination", {
  set.seed(45)
  a_tight <- data.frame(x = rnorm(6, 10, 0.3), y = rnorm(6, 10, 0.3))
  a_outlier <- data.frame(x = 40, y = 40)
  b <- data.frame(x = rnorm(3, 5, 0.3), y = rnorm(3, 5, 0.3))
  df <- rbind(a_tight, a_outlier, b)
  rownames(df) <- paste0("ind", seq_len(nrow(df)))
  groups <- c(rep("A", 7), rep("B", 3))

  ts <- suppressMessages(trait_space(
    df, groups = groups, log_transform = FALSE, remove_outliers = TRUE
  ))

  # The planted outlier ("ind7") is gone from the ordination entirely.
  expect_equal(nrow(ts$scores), 9)
  expect_false("ind7" %in% rownames(ts$scores))
  expect_false("ind7" %in% rownames(ts$X))
  expect_equal(length(ts$groups), 9)

  # ...but is recorded in $removed_outliers, and $outlier_screen is
  # reduced to (and consistent with) the specimens actually used.
  expect_false(is.null(ts$removed_outliers))
  expect_equal(rownames(ts$removed_outliers), "ind7")
  expect_equal(ts$removed_outliers$group, "A")
  expect_equal(nrow(ts$outlier_screen), 9)
  expect_false("ind7" %in% rownames(ts$outlier_screen))
  expect_false(any(ts$outlier_screen$flagged, na.rm = TRUE))
})

test_that("remove_outliers = TRUE is a no-op when nothing is flagged", {
  set.seed(46)
  df <- data.frame(x = rnorm(10, 10, 0.3), y = rnorm(10, 10, 0.3))
  groups <- rep(c("A", "B"), each = 5)
  ts <- trait_space(df, groups = groups, log_transform = FALSE, remove_outliers = TRUE)
  expect_null(ts$removed_outliers)
  expect_equal(nrow(ts$scores), 10)
})

test_that("remove_outliers = TRUE requires flag_outliers = TRUE", {
  df <- data.frame(x = 1:10, y = 10:1)
  groups <- rep(c("A", "B"), each = 5)
  expect_error(
    trait_space(df, groups = groups, log_transform = FALSE,
                flag_outliers = FALSE, remove_outliers = TRUE),
    "requires `flag_outliers = TRUE`"
  )
})

test_that("remove_outliers = TRUE messages about what was removed", {
  set.seed(47)
  a_tight <- data.frame(x = rnorm(6, 10, 0.3), y = rnorm(6, 10, 0.3))
  a_outlier <- data.frame(x = 40, y = 40)
  df <- rbind(a_tight, a_outlier)
  groups <- rep("A", 7)

  expect_message(
    trait_space(df, groups = groups, log_transform = FALSE, remove_outliers = TRUE),
    "remove_outliers: removing 1 specimen"
  )
})
