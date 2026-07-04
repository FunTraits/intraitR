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

test_that("trait_disparity()'s permutation null distribution scales with `iter` for exactly 2 groups", {
  # Regression test for a reshape bug: with exactly 2 groups there is a
  # single pairwise comparison, so apply()/vapply() return a plain vector
  # rather than a matrix; naively t()-ing that vector produces a
  # 1 x iter matrix instead of iter x 1, silently collapsing the null
  # distribution to a single arbitrary permutation. That bug would make
  # the possible p-value denominator constant (always "out of 2")
  # regardless of `iter`, instead of scaling as iter + 1 as it should;
  # checked here directly (not via statistical power, which a degenerate
  # null could pass by chance) by confirming the p-value's possible
  # denominator actually reflects the requested `iter`.
  set.seed(11)
  df <- data.frame(a = c(rnorm(10, 0, 1), rnorm(10, 0, 4)),
                    b = c(rnorm(10, 0, 1), rnorm(10, 0, 4)))
  groups <- rep(c("G1", "G2"), each = 10)

  td_small <- trait_disparity(df, groups = groups, iter = 5, log_transform = FALSE)
  td_large <- trait_disparity(df, groups = groups, iter = 999, log_transform = FALSE)

  # NB: `%in%` binds *tighter* than `/` in R (see ?Syntax), so the
  # denominator must be fully parenthesised -- `x %in% (0:5 + 1) / 6`
  # would silently parse as `(x %in% (0:5 + 1)) / 6` instead.
  expect_true(td_small$pairwise_p["G1", "G2"] %in% (((0:5) + 1) / 6))
  expect_true(td_large$pairwise_p["G1", "G2"] %in% (((0:999) + 1) / 1000))
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

test_that("trait_disparity() drops rows with an NA group instead of corrupting every group's disparity", {
  # Regression test: a single specimen with an unresolved/NA group used to
  # silently propagate into the logical indexing `Xmat[g == lv, ]` for
  # EVERY level of `g` (since `NA == lv` is NA, not FALSE, and `x[NA]`
  # inserts an NA row), turning every group's disparity into NA -- found
  # while validating the package against the real T-26 Saudrune data set,
  # which has exactly this kind of unresolved identification.
  set.seed(5)
  n <- 15
  df <- data.frame(
    a = c(rnorm(n, 5, 1), rnorm(n, 5, 1), rnorm(1, 5, 1)),
    b = c(rnorm(n, 2, 1), rnorm(n, 2, 1), rnorm(1, 2, 1))
  )
  groups <- c(rep("G1", n), rep("G2", n), NA)

  expect_message(
    td <- trait_disparity(df, groups = groups, iter = 49, log_transform = FALSE),
    "missing/unresolved"
  )
  expect_false(anyNA(td$disparity))
  expect_setequal(names(td$disparity), c("G1", "G2"))
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
