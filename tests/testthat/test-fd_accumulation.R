test_that(".fd_index_fun() computes FDis and Rao to hand-verified values", {
  # unit square, side 2: centroid (1,1); every vertex is sqrt(2) from it, so
  # FDis = sqrt(2). Rao (equal weights) = sum(D)/m^2 = (16 + 8*sqrt(2))/16.
  P <- matrix(c(0, 0, 2, 0, 0, 2, 2, 2), ncol = 2, byrow = TRUE)
  rownames(P) <- paste0("ind_", 1:4)
  f <- intraitR:::.fd_index_fun(c("fdis", "rao"), need_fd = FALSE,
                                method = "convexhull", aux = NULL)
  v <- f(P, factor(c("A", "A", "B", "B")))

  expect_equal(unname(v["fdis"]), sqrt(2), tolerance = 1e-8)
  expect_equal(unname(v["rao"]), (16 + 8 * sqrt(2)) / 16, tolerance = 1e-8)
})

test_that(".fd_index_fun() FRic equals the convex-hull volume", {
  skip_if_not_installed("geometry")
  P <- matrix(c(0, 0, 2, 0, 0, 2, 2, 2), ncol = 2, byrow = TRUE)
  rownames(P) <- paste0("ind_", 1:4)
  f <- intraitR:::.fd_index_fun("fric", need_fd = FALSE, method = "convexhull", aux = NULL)
  expect_equal(unname(f(P, factor(letters[1:4]))["fric"]), 4, tolerance = 1e-8)

  # too few points for the hull (m <= d) must yield NA, not an error
  P2 <- matrix(c(0, 0, 1, 1), ncol = 2, byrow = TRUE)
  rownames(P2) <- c("ind_1", "ind_2")
  expect_true(is.na(f(P2, factor(c("a", "b")))["fric"]))
})

test_that("fd_accumulation() returns a well-formed object with correct framing", {
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))

  acc <- suppressMessages(fd_accumulation(
    ratios[, c("BEl", "VEp", "REs", "OGp")], groups = fish$metadata$species,
    indices = c("fdis", "rao"), n_perm = 20, min_n = 10, seed = 1
  ))
  expect_s3_class(acc, "intrait_fd_accumulation")
  expect_setequal(unique(acc$curve$index), c("fdis", "rao"))
  expect_true(all(c("index", "n", "mean", "lower", "upper") %in% names(acc$curve)))

  # both are dispersion indices -> convergence framing, n* within sampled range
  expect_true(all(acc$summary$framing == "convergence"))
  ok <- with(acc$summary, is.na(n_star) | (n_star >= 2 & n_star <= n_cap))
  expect_true(all(ok))
  expect_true(all(is.na(acc$summary$asymptote)))  # no asymptote for convergence
})

test_that("fd_accumulation() treats FRic with the accumulation framing", {
  skip_if_not_installed("geometry")
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  acc <- suppressMessages(fd_accumulation(
    ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species,
    indices = "fric", n_perm = 20, min_n = 10, seed = 1
  ))
  expect_true(startsWith(acc$summary$framing[acc$summary$index == "fric"], "accumulation"))
  # FRic must be non-decreasing on average with sampling effort (accumulation)
  fr <- acc$curve[acc$curve$index == "fric", ]
  expect_gte(fr$mean[nrow(fr)], fr$mean[1])
})

test_that("fd_accumulation() FRic honours `method` (dendrogram needs no extra package)", {
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  acc <- suppressMessages(fd_accumulation(
    ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species,
    indices = "fric", method = "dendrogram", n_perm = 15, min_n = 10, seed = 1
  ))
  expect_equal(acc$method, "dendrogram")
  expect_true("fric" %in% acc$indices)             # not dropped: dendrogram needs no pkg
  expect_true(startsWith(acc$summary$framing[acc$summary$index == "fric"], "accumulation"))
  # dendrogram total branch length accumulates with sampling effort
  fr <- acc$curve[acc$curve$index == "fric", ]
  expect_gte(fr$mean[nrow(fr)], fr$mean[1])
  expect_output(print(acc), "method = dendrogram")
})

test_that("fd_accumulation() validates its inputs", {
  df <- as.data.frame(matrix(stats::rnorm(200), ncol = 2))
  g  <- rep(c("A", "B"), each = 50)  # only 2 species

  expect_error(fd_accumulation(df), "`groups` is required")
  expect_error(suppressMessages(fd_accumulation(df, groups = g, n_perm = 0)), "positive integer")
  expect_error(suppressMessages(fd_accumulation(df, groups = g, conv_tol = 1.5)), "in \\(0, 1\\)")
  expect_error(suppressMessages(fd_accumulation(df, groups = g, indices = "fdis")),
               "at least 3 levels")
})

test_that("fd_accumulation() drops feve/fdiv gracefully when FD is absent", {
  skip_if(requireNamespace("FD", quietly = TRUE),
          "FD is installed; cannot test the drop-with-message path")
  fish <- simulate_fishmorph_points(n_per_species = 18, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  expect_message(
    acc <- fd_accumulation(ratios[, c("BEl", "VEp", "REs")], groups = fish$metadata$species,
                           indices = c("fdis", "feve"), n_perm = 10, min_n = 10, seed = 1),
    "FD"
  )
  expect_false("feve" %in% acc$indices)
})

test_that("print and plot methods for intrait_fd_accumulation do not error", {
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  ratios <- fishmorph_ratios(fishmorph_segments(fish))
  acc <- suppressMessages(fd_accumulation(
    ratios[, c("BEl", "VEp", "REs", "OGp")], groups = fish$metadata$species,
    indices = c("fdis", "rao"), n_perm = 15, min_n = 10, seed = 1
  ))
  expect_output(print(acc), "intrait_fd_accumulation")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(acc), NA)
  expect_error(plot(acc, indices = "rao"), NA)
  grDevices::dev.off()
  unlink(tmp)
})
