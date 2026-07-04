test_that("species_sensitivity() runs on an intrait_traitspace object", {
  testthat::skip_if_not_installed("geometry")

  set.seed(1)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  ss <- species_sensitivity(ts, n_axes = 2)

  expect_s3_class(ss, "intrait_species_sensitivity")
  expect_equal(ss$n_axes, 2)
  expect_equal(nrow(ss$summary), nlevels(ts$groups))
  expect_setequal(ss$summary$species, levels(ts$groups))
  expect_equal(sum(ss$summary$n_individuals), nrow(ratios))
  expect_equal(nrow(ss$individual), nrow(ratios))
  expect_true(all(ss$summary$min_dFD <= ss$summary$mean_dFD))
  expect_true(all(ss$summary$mean_dFD <= ss$summary$max_dFD))
})

test_that("species_sensitivity() runs on a raw trait table with explicit groups", {
  testthat::skip_if_not_installed("geometry")

  set.seed(2)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  ss <- species_sensitivity(ratios, groups = fish$metadata$species, n_axes = 2)
  expect_s3_class(ss, "intrait_species_sensitivity")
})

test_that("species_sensitivity() per-individual dFD matches a direct recomputation of the convex-hull volume", {
  testthat::skip_if_not_installed("geometry")

  # Regression/consistency check: dFD for one specific (species, individual)
  # pair must equal 100 * (hull volume with that individual substituted for
  # its species' centroid - fd_ref) / fd_ref, recomputed independently here
  # rather than trusting the function's own internal arithmetic.
  set.seed(3)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  ss <- species_sensitivity(ts, n_axes = 2)

  pca <- stats::prcomp(ts$X, center = TRUE, scale. = FALSE)
  scores <- pca$x[, 1:2, drop = FALSE]
  groups <- ts$groups
  lv <- levels(groups)
  centroids <- t(vapply(lv, function(g) colMeans(scores[groups == g, , drop = FALSE]), numeric(2)))

  k <- 1
  idx_k <- which(groups == lv[k])
  i <- idx_k[1]
  config <- centroids
  config[k, ] <- scores[i, ]
  fd_ki <- intraitR:::.convex_hull_volume(config)
  expected_dFD <- 100 * (fd_ki - ss$fd_ref) / ss$fd_ref

  actual_dFD <- ss$individual$dFD[ss$individual$species == lv[k]][1]
  expect_equal(actual_dFD, expected_dFD, tolerance = 1e-6)
})

test_that("species_sensitivity() gives a wide dFD range to a species with one strong outlier individual", {
  testthat::skip_if_not_installed("geometry")

  # 6 species on a circle, each with 8 jittered individuals, except species
  # "sp1" which additionally has one individual placed far outside the
  # cloud: only sp1 should show a markedly wider min-max range than the
  # other species, since only its outlier individual, substituted for the
  # centroid, meaningfully expands the hull.
  set.seed(7)
  n_species <- 6
  n_ind <- 8
  radius <- 10
  angles <- seq(0, 2 * pi, length.out = n_species + 1)[seq_len(n_species)]
  centers <- data.frame(cx = radius * cos(angles), cy = radius * sin(angles),
                         species = paste0("sp", seq_len(n_species)))

  df <- do.call(rbind, lapply(seq_len(nrow(centers)), function(k) {
    data.frame(
      a = centers$cx[k] + stats::rnorm(n_ind, sd = 1.5),
      b = centers$cy[k] + stats::rnorm(n_ind, sd = 1.5),
      species = centers$species[k]
    )
  }))
  # push one sp1 individual far out along its own radial direction
  sp1_idx <- which(df$species == "sp1")[1]
  df$a[sp1_idx] <- centers$cx[1] * 2.5
  df$b[sp1_idx] <- centers$cy[1] * 2.5

  ss <- species_sensitivity(df[c("a", "b")], groups = df$species, n_axes = 2,
                             log_transform = FALSE, scale = FALSE)

  ranges <- ss$summary$max_dFD - ss$summary$min_dFD
  names(ranges) <- ss$summary$species
  expect_equal(names(which.max(ranges)), "sp1")
  expect_true(ranges[["sp1"]] > 2 * median(ranges[names(ranges) != "sp1"]))
})

test_that("species_sensitivity() errors on invalid input", {
  testthat::skip_if_not_installed("geometry")

  expect_error(species_sensitivity(list()), "intrait_traitspace")
  expect_error(
    species_sensitivity(data.frame(a = 1:9, b = 1:9)),
    "`groups` is required"
  )
  expect_error(
    species_sensitivity(
      data.frame(a = 1:9, b = 1:9),
      groups = rep(c("G1", "G2"), c(5, 4))
    ),
    "at least 3 levels"
  )
})

test_that("species_sensitivity() errors informatively without the geometry package", {
  testthat::skip_if(
    requireNamespace("geometry", quietly = TRUE),
    "geometry is installed; cannot test the missing-package error message"
  )
  df <- data.frame(a = 1:9, b = 1:9)
  expect_error(
    species_sensitivity(df, groups = rep(c("G1", "G2", "G3"), 3)),
    "geometry"
  )
})

test_that("print.intrait_species_sensitivity() and plot.intrait_species_sensitivity() do not error", {
  testthat::skip_if_not_installed("geometry")

  set.seed(8)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))
  ss <- species_sensitivity(ts, n_axes = 2)

  expect_output(print(ss), "intrait_species_sensitivity")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(ss), NA)
  expect_error(plot(ss, n = 2, abbreviate_species = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp)
})
