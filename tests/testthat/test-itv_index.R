test_that("itv_index() matches a hand-computed two-group decomposition", {
  # A = c(1,2,3), B = c(10,11,12); grand mean = 6.5
  # ss_total = 125.5, ss_between = 121.5, ss_within = 4 (verified by hand)
  df <- data.frame(x = c(1, 2, 3, 10, 11, 12))
  groups <- rep(c("A", "B"), each = 3)

  # digits = 12 avoids the default digits = 4 rounding masking the tight
  # tolerances used below (percentages especially: e.g. round(pct_itv, 4)
  # differs from the unrounded value by ~5e-5, which exceeds a 1e-6
  # *relative* tolerance once the percentage itself is small, as it is
  # here).
  itv <- itv_index(df, groups = groups, digits = 12)

  expect_s3_class(itv, "intrait_itv")
  expect_equal(itv$per_trait$ss_total, 125.5, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_between, 121.5, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_within, 4, tolerance = 1e-8)
  expect_equal(itv$per_trait$pct_interspecific, 121.5 / 125.5 * 100, tolerance = 1e-6)
  expect_equal(itv$per_trait$pct_itv, 4 / 125.5 * 100, tolerance = 1e-6)
  # percentages must sum to 100
  expect_equal(itv$per_trait$pct_interspecific + itv$per_trait$pct_itv, 100, tolerance = 1e-6)
})

test_that("itv_index() nested decomposition matches a hand-computed example", {
  # species A: populations A1 = c(1,2), A2 = c(5,6)
  # species B: populations B1 = c(20,21), B2 = c(24,25)
  # hand-verified: ss_total = 756, ss_between = 722, ss_population = 32, ss_residual = 2
  df <- data.frame(x = c(1, 2, 5, 6, 20, 21, 24, 25))
  species    <- rep(c("A", "A", "A", "A", "B", "B", "B", "B"))
  population <- c("A1", "A1", "A2", "A2", "B1", "B1", "B2", "B2")

  itv <- itv_index(df, groups = species, nested = population, digits = 12)

  expect_equal(itv$per_trait$ss_total, 756, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_between, 722, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_population, 32, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_residual, 2, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_within, 34, tolerance = 1e-8)

  # the three percentage components must sum to 100
  total_pct <- itv$per_trait$pct_interspecific +
    itv$per_trait$pct_itv_between_pop + itv$per_trait$pct_itv_within_pop
  expect_equal(total_pct, 100, tolerance = 1e-6)
  # pct_itv must equal the sum of its two nested components
  expect_equal(
    itv$per_trait$pct_itv,
    itv$per_trait$pct_itv_between_pop + itv$per_trait$pct_itv_within_pop,
    tolerance = 1e-6
  )
})

test_that("itv_index() nested decomposition holds exactly under an unbalanced design", {
  set.seed(1)
  species <- rep(c("A", "B", "C"), times = c(12, 9, 15))
  population <- character(length(species))
  for (sp in unique(species)) {
    idx <- which(species == sp)
    n_pop <- sample(2:3, 1)
    population[idx] <- paste0(sp, sample(seq_len(n_pop), length(idx), replace = TRUE))
  }
  x <- stats::rnorm(length(species), mean = as.numeric(factor(species)) * 5, sd = 1)
  df <- data.frame(t1 = x, t2 = x * 2 + stats::rnorm(length(x), sd = 0.5))

  itv <- itv_index(df, groups = species, nested = population, digits = 12)

  # the orthogonal sum-of-squares identity must hold (to floating point
  # precision) regardless of the unbalanced group/population sizes
  expect_equal(
    itv$per_trait$ss_between + itv$per_trait$ss_population + itv$per_trait$ss_residual,
    itv$per_trait$ss_total,
    tolerance = 1e-6
  )
})

test_that("itv_index() drops rows with an NA/unresolved group rather than treating NA as its own group", {
  # Regression test found while validating against the real T-26 Saudrune
  # data set, which contains one specimen with an unresolved species
  # identification (id_status = "unresolved") but otherwise-complete trait
  # values. Left unhandled, that NA would form a spurious size-1 "species"
  # via stats::ave(x, groups), inflating the interspecific SS.
  df <- data.frame(x = c(1, 2, 3, 10, 11, 12, 999))
  groups <- c(rep("A", 3), rep("B", 3), NA)

  expect_message(
    itv_with_na <- itv_index(df, groups = groups, digits = 12),
    "missing/unresolved"
  )
  itv_without_na <- itv_index(df[1:6, , drop = FALSE], groups = groups[1:6], digits = 12)

  expect_equal(itv_with_na$per_trait$ss_total, itv_without_na$per_trait$ss_total, tolerance = 1e-8)
  expect_equal(nlevels(itv_with_na$groups), 2)
})

test_that("itv_index() multivariate summary aggregates across (optionally scaled) traits", {
  df <- data.frame(
    x = c(1, 2, 3, 10, 11, 12),
    y = c(100, 200, 300, 1000, 1100, 1200)
  )
  groups <- rep(c("A", "B"), each = 3)

  itv_scaled   <- itv_index(df, groups = groups, scale = TRUE)
  itv_unscaled <- itv_index(df, groups = groups, scale = FALSE)

  # per-trait percentages are scale-invariant and must not depend on `scale`
  expect_equal(itv_scaled$per_trait$pct_itv, itv_unscaled$per_trait$pct_itv, tolerance = 1e-8)

  # but the multivariate aggregate can differ once traits are standardised
  expect_equal(nrow(itv_scaled$multivariate), 1)
  expect_true(itv_scaled$multivariate$pct_interspecific >= 0 &&
                itv_scaled$multivariate$pct_interspecific <= 100)
})

test_that("itv_index() works on simulated FISHMORPH data with species groups", {
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  segments <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(segments)

  itv <- itv_index(
    ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species
  )
  expect_equal(nrow(itv$per_trait), 3)
  expect_true(all(itv$per_trait$pct_itv >= 0 & itv$per_trait$pct_itv <= 100))

  # fish$metadata$population reuses labels "Pop_1"/"Pop_2" identically
  # across every species (see simulate_fishmorph_points()); this must not
  # error, and each (species, population) combination must be treated as
  # a distinct population.
  itv_nested <- itv_index(
    ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species,
    nested = fish$metadata$population
  )
  expect_true(all(c("pct_itv_between_pop", "pct_itv_within_pop") %in% names(itv_nested$per_trait)))
  # fish$metadata$species is a plain character vector (not a factor), so
  # nlevels() on it directly would return 0; wrap it in factor() first.
  expect_equal(nlevels(itv_nested$nested), nlevels(factor(fish$metadata$species)) * 2)
})

test_that("itv_index() disambiguates `nested` levels reused across `groups`", {
  # "p1"/"p2" are reused identically in both "A" and "B": with reused,
  # non-globally-unique labels this must NOT error, and must be treated
  # as 4 distinct populations (A/p1, A/p2, B/p1, B/p2), matching the
  # nesting operator in aov(y ~ Error(groups/nested)).
  df <- data.frame(x = c(1, 2, 5, 6, 20, 21, 24, 25))
  groups <- rep(c("A", "B"), each = 4)
  nested <- rep(c("p1", "p1", "p2", "p2"), times = 2)

  itv <- itv_index(df, groups = groups, nested = nested)

  expect_equal(nlevels(itv$nested), 4)
  # matches the hand-verified nested example (same values/groups, just
  # with reused rather than globally unique population labels)
  expect_equal(itv$per_trait$ss_total, 756, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_between, 722, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_population, 32, tolerance = 1e-8)
  expect_equal(itv$per_trait$ss_residual, 2, tolerance = 1e-8)
})

test_that("itv_index() validates inputs", {
  df <- data.frame(x = 1:6)
  expect_error(itv_index(df), "`groups` is required")
  expect_error(itv_index(df, groups = rep("only_one", 6)), "at least two levels")
  expect_error(itv_index(df, groups = c("A", "B")), "one entry per row")
  expect_error(itv_index(list(), groups = c("A", "B")), "data.frame or matrix")

  df_na <- data.frame(x = c(1, NA, 3, 4, 5, 6))
  expect_error(itv_index(df_na, groups = rep(c("A", "B"), each = 3)), "missing values")

  # `nested` need not be globally unique across `groups` (see the
  # disambiguation test above); this must run without error either way.
  expect_error(
    itv_index(df, groups = rep(c("A", "B"), each = 3),
              nested = c("p1", "p1", "p2", "p1", "p1", "p2")),
    NA
  )
})

test_that("itv_index() drops non-numeric columns with a warning", {
  df <- data.frame(x = c(1, 2, 3, 10, 11, 12), label = letters[1:6])
  groups <- rep(c("A", "B"), each = 3)
  expect_warning(itv_index(df, groups = groups), "non-numeric")
})

test_that("itv_index() warns when groups have no replication", {
  df <- data.frame(x = c(1, 2, 3))
  groups <- c("A", "B", "C")
  expect_warning(itv_index(df, groups = groups), "cannot be estimated")
})

test_that("print and plot methods for intrait_itv do not error", {
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  segments <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(segments)
  itv <- itv_index(ratios[, c("BEl", "VEp")], groups = fish$metadata$species)

  expect_output(print(itv), "intrait_itv")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(itv), NA)
  grDevices::dev.off()
  unlink(tmp)

  itv_nested <- itv_index(
    ratios[, c("BEl", "VEp")], groups = fish$metadata$species,
    nested = fish$metadata$population
  )
  tmp2 <- tempfile(fileext = ".png")
  grDevices::png(tmp2)
  expect_error(plot(itv_nested), NA)
  grDevices::dev.off()
  unlink(tmp2)
})
