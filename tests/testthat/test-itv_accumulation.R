test_that(".itv_convergence_n() finds the size after the last band-width breach", {
  sizes <- 2:6
  vfull <- 10
  # relative half-widths, tol = 0.05:
  # F, F, T, T, T -> n* = 4 (first size that stays within to the end)
  lower <- c(9.2, 9.4, 9.6, 9.8, 10)
  upper <- c(10.8, 10.6, 10.4, 10.2, 10)     # hw/vfull: .08,.06,.04,.02,0
  expect_equal(intraitR:::.itv_convergence_n(sizes, lower, upper, vfull, 0.05), 4L)

  # a late breach: T, T, F, T, T -> last FALSE at n = 4 -> n* = 5
  lower2 <- c(9.8, 9.9, 9.1, 9.95, 10)
  upper2 <- c(10.2, 10.1, 10.9, 10.05, 10)   # hw/vfull: .02,.01,.09,.005,0
  expect_equal(intraitR:::.itv_convergence_n(sizes, lower2, upper2, vfull, 0.05), 5L)

  # everything already within tolerance -> the smallest size
  expect_equal(
    intraitR:::.itv_convergence_n(sizes, rep(9.99, 5), rep(10.01, 5), vfull, 0.05),
    2L
  )
})

test_that(".itv_saturating_fit() recovers a Michaelis-Menten n* in closed form", {
  # data generated exactly on V(n) = Vmax n / (K + n): the fit must recover
  # Vmax and K, and n* = ceiling(K * p / (1 - p)).
  Vmax <- 5; K <- 8; n <- 2:60
  y <- Vmax * n / (K + n)
  fit <- intraitR:::.itv_saturating_fit(n, y, model = "michaelis", prop = 0.95)
  expect_equal(fit$asymptote, Vmax, tolerance = 1e-4)
  expect_equal(fit$k, K, tolerance = 1e-4)
  expect_equal(fit$n_star, as.integer(ceiling(K * 0.95 / 0.05)))
  # V(n*) must indeed reach >= 95% of the asymptote
  expect_gte((Vmax * fit$n_star / (K + fit$n_star)) / Vmax, 0.95)

  # exponential parameterisation: n* = ceiling(-log(1 - p) / b)
  b <- 0.3; ye <- Vmax * (1 - exp(-b * n))
  fite <- intraitR:::.itv_saturating_fit(n, ye, model = "exponential", prop = 0.95)
  expect_equal(fite$asymptote, Vmax, tolerance = 1e-4)
  expect_equal(fite$n_star, as.integer(ceiling(-log(0.05) / b)))
})

test_that("itv_accumulation() 'variance' equals the trace of the group covariance at n = N", {
  set.seed(1)
  X <- cbind(stats::rnorm(30), stats::rnorm(30, sd = 2), stats::rnorm(30, sd = 3))
  colnames(X) <- c("t1", "t2", "t3")
  groups <- rep("A", 30)

  acc <- itv_accumulation(X, groups = groups, metric = "variance",
                          n_perm = 10, min_n = 5, scale = FALSE)
  expect_s3_class(acc, "intrait_itv_accumulation")

  # full-sample multivariate variance = trace of the covariance = sum of
  # the per-column sample variances
  expected <- sum(apply(X, 2, stats::var))
  v_full <- acc$summary$v_full[acc$summary$group == "A"]
  expect_equal(v_full, expected, tolerance = 1e-8)

  # convergence framing: one multivariate series, no asymptote
  expect_equal(acc$framing, "convergence")
  expect_equal(unique(acc$summary$trait), "multivariate")
  expect_true(all(is.na(acc$summary$asymptote)))
})

test_that("itv_accumulation() produces one series per trait for univariate metrics", {
  fish <- simulate_fishmorph_points(n_per_species = 25, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  tr <- ratios[, c("BEl", "VEp", "REs")]

  acc <- itv_accumulation(tr, groups = fish$metadata$species,
                          metric = "cv", n_perm = 20, min_n = 5, seed = 1)
  expect_setequal(unique(acc$summary$trait), c("BEl", "VEp", "REs"))
  # one summary row per (group, trait)
  expect_equal(nrow(acc$summary), nlevels(factor(fish$metadata$species)) * 3)
  # the curve is monotone in n within each series (sizes increasing)
  expect_true(all(acc$curve$n >= 2))
  # n* never below 2 and never above the group's own N
  ok <- with(acc$summary, is.na(n_star) | (n_star >= 2 & n_star <= n_max))
  expect_true(all(ok))
})

test_that("itv_accumulation() 'range' uses the accumulation framing and fits an asymptote", {
  fish <- simulate_fishmorph_points(n_per_species = 30, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))

  acc <- itv_accumulation(ratios[, c("BEl", "VEp")], groups = fish$metadata$species,
                          metric = "range", n_perm = 20, min_n = 5, seed = 1)
  expect_equal(acc$framing, "accumulation")
  # asymptote, prop_reached and the fitted k parameter are reported
  expect_true(all(c("asymptote", "prop_reached", "k") %in% names(acc$summary)))
  finite_fits <- acc$summary[is.finite(acc$summary$asymptote), ]
  expect_gt(nrow(finite_fits), 0)
  # the observed full-sample range cannot exceed the fitted asymptote
  expect_true(all(finite_fits$v_full <= finite_fits$asymptote * 1.001))
  expect_true(all(finite_fits$prop_reached > 0 & finite_fits$prop_reached <= 1.001))
  # a fitted asymptote must come with a finite half-saturation/rate k, and
  # evaluating the fitted curve at n* must reach ~asymptote_prop of Vmax
  expect_true(all(is.finite(finite_fits$k)))
  # .itv_fitted_curve() takes scalar Vmax/k (one series), so evaluate per row
  vn <- mapply(
    function(ns, vm, kk) intraitR:::.itv_fitted_curve(ns, acc$model, vm, kk),
    finite_fits$n_star, finite_fits$asymptote, finite_fits$k
  )
  expect_true(all(vn / finite_fits$asymptote >= acc$asymptote_prop - 1e-6))
})

test_that("itv_accumulation() drops NA groups and skips undersized groups", {
  set.seed(2)
  X <- matrix(stats::rnorm(120), ncol = 2)
  colnames(X) <- c("t1", "t2")
  # group A: 40, group B: 3 (too small), one NA group
  groups <- c(rep("A", 40), rep("B", 3), rep(NA, 17))

  expect_message(
    expect_message(
      acc <- itv_accumulation(X, groups = groups, metric = "variance",
                              n_perm = 10, min_n = 5, scale = FALSE),
      "missing/unresolved"
    ),
    "Skipped"
  )
  # only group A survives
  expect_equal(unique(acc$summary$group), "A")
})

test_that("itv_accumulation() validates its inputs", {
  X <- matrix(stats::rnorm(60), ncol = 2)
  groups <- rep(c("A", "B"), each = 15)

  expect_error(itv_accumulation(X), "`groups` is required")
  expect_error(itv_accumulation(X, groups = groups, n_perm = 0), "positive integer")
  expect_error(itv_accumulation(X, groups = groups, conv_tol = 0), "in \\(0, 1\\)")
  expect_error(itv_accumulation(X, groups = groups, asymptote_prop = 1), "in \\(0, 1\\)")
  expect_error(itv_accumulation(X, groups = groups, probs = c(0.9, 0.1)), "increasing")
  expect_error(itv_accumulation(list(), groups = groups), "data.frame/matrix")
  # no group large enough
  expect_error(
    itv_accumulation(X, groups = groups, min_n = 50),
    "No group had enough individuals"
  )
})

test_that("itv_accumulation() rejects cv on a centred trait space", {
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  ts <- trait_space(ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species)
  expect_error(itv_accumulation(ts, metric = "cv"), "not meaningful")
})

test_that("print and plot methods for intrait_itv_accumulation do not error", {
  fish <- simulate_fishmorph_points(n_per_species = 25, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))

  acc <- itv_accumulation(ratios[, c("BEl", "VEp")], groups = fish$metadata$species,
                          metric = "variance", n_perm = 15, seed = 1)
  expect_output(print(acc), "intrait_itv_accumulation")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(acc), NA)
  grDevices::dev.off()
  unlink(tmp)

  acc_r <- itv_accumulation(ratios[, c("BEl", "VEp")], groups = fish$metadata$species,
                            metric = "range", n_perm = 15, seed = 1)
  tmp2 <- tempfile(fileext = ".png")
  grDevices::png(tmp2)
  expect_error(plot(acc_r, series = "BEl"), NA)          # default: extrapolate to asymptote
  expect_error(plot(acc_r, extrapolate = FALSE), NA)     # observed range only
  expect_error(plot(acc_r, xmax = 60), NA)               # fixed extrapolation horizon
  grDevices::dev.off()
  unlink(tmp2)
})
