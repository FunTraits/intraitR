test_that("bootstrap_functional_space() runs on an intrait_traitspace object", {
  testthat::skip_if_not_installed("geometry")

  set.seed(1)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 50)

  expect_s3_class(bf, "intrait_bootstrap_fspace")
  expect_equal(bf$n_axes, 2)
  expect_length(bf$fd_boot, 50)
  expect_true(is.finite(bf$fd_ref) && bf$fd_ref >= 0)
  expect_true(all(bf$fd_boot[!is.na(bf$fd_boot)] >= 0))
  expect_true(bf$p_value >= 0 && bf$p_value <= 1)
  expect_equal(bf$fd_boot_mean, mean(bf$fd_boot, na.rm = TRUE))
  expect_true(bf$fd_boot_q05 <= bf$fd_boot_mean && bf$fd_boot_mean <= bf$fd_boot_q95)
})

test_that("bootstrap_functional_space() runs on a raw trait table with explicit groups", {
  testthat::skip_if_not_installed("geometry")

  set.seed(2)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)

  bf <- bootstrap_functional_space(ratios, groups = fish$metadata$species,
                                    n_axes = 2, n_boot = 50)
  expect_s3_class(bf, "intrait_bootstrap_fspace")
})

test_that("bootstrap_functional_space() auto-selects n_axes from var_threshold", {
  testthat::skip_if_not_installed("geometry")

  set.seed(3)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(ts, n_boot = 30, var_threshold = 0.5)
  expect_true(bf$n_axes >= 2)
  expect_true(bf$var_explained >= 0.5)
})

test_that("bootstrap_functional_space() detects a strong, real excess of individual-based volume over the centroid reference", {
  testthat::skip_if_not_installed("geometry")

  # 20 species arranged on a circle, each with several individuals jittered
  # around their own position: this configuration (verified independently
  # in Python/scipy before being encoded here as an R regression test) was
  # checked to reliably give both a positive fd_boot_mean - fd_ref shift
  # and a significant p-value across many random seeds, unlike a
  # too-small/low-dimensional toy example (e.g. 3-4 species), where
  # bootstrap sampling variability alone can dominate the signal and the
  # test is underpowered essentially by construction, not because the
  # method is wrong.
  set.seed(42)
  n_species <- 20
  n_ind <- 15
  radius <- 10
  jitter_sd <- 3.5
  angles <- seq(0, 2 * pi, length.out = n_species + 1)[seq_len(n_species)]
  centers <- data.frame(cx = radius * cos(angles), cy = radius * sin(angles),
                         species = paste0("sp", seq_len(n_species)))

  df <- do.call(rbind, lapply(seq_len(nrow(centers)), function(i) {
    data.frame(
      a = centers$cx[i] + stats::rnorm(n_ind, sd = jitter_sd),
      b = centers$cy[i] + stats::rnorm(n_ind, sd = jitter_sd),
      species = centers$species[i]
    )
  }))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, n_axes = 2,
    n_boot = 300, log_transform = FALSE, scale = FALSE
  )

  expect_true(bf$fd_boot_mean > bf$fd_ref)
  expect_true(bf$diff > 0)
  expect_true(bf$p_value < 0.05)
})

test_that("bootstrap_functional_space() stays non-significant when intraspecific variability is negligible", {
  testthat::skip_if_not_installed("geometry")

  # Same layout as above, but with essentially no within-species jitter:
  # fd_boot should coincide with fd_ref (every bootstrap draw is
  # effectively the species centroid itself), so the test must NOT
  # spuriously report significance -- a calibration check for the
  # bootstrap p-value, complementing the "detects a real effect" test.
  set.seed(43)
  n_species <- 20
  n_ind <- 15
  radius <- 10
  angles <- seq(0, 2 * pi, length.out = n_species + 1)[seq_len(n_species)]
  centers <- data.frame(cx = radius * cos(angles), cy = radius * sin(angles),
                         species = paste0("sp", seq_len(n_species)))

  df <- do.call(rbind, lapply(seq_len(nrow(centers)), function(i) {
    data.frame(
      a = centers$cx[i] + stats::rnorm(n_ind, sd = 1e-6),
      b = centers$cy[i] + stats::rnorm(n_ind, sd = 1e-6),
      species = centers$species[i]
    )
  }))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, n_axes = 2,
    n_boot = 300, log_transform = FALSE, scale = FALSE
  )

  expect_true(bf$p_value > 0.1)
})

test_that("bootstrap_functional_space() errors on invalid input", {
  testthat::skip_if_not_installed("geometry")

  expect_error(bootstrap_functional_space(list()), "intrait_traitspace")
  expect_error(
    bootstrap_functional_space(data.frame(a = 1:9, b = 1:9)),
    "`groups` is required"
  )
  expect_error(
    bootstrap_functional_space(
      data.frame(a = 1:9, b = 1:9),
      groups = rep(c("G1", "G2"), c(5, 4))
    ),
    "at least 3 levels"
  )
})

test_that("bootstrap_functional_space() errors when trait_space() object lacks groups", {
  testthat::skip_if_not_installed("geometry")

  df <- data.frame(a = c(1, 10, 100, 5, 50), b = c(2, 20, 200, 10, 100))
  ts_nogroups <- trait_space(df, log_transform = TRUE, scale = FALSE)
  expect_error(bootstrap_functional_space(ts_nogroups), "has no `groups`")
})

test_that("bootstrap_functional_space() errors when `n_axes` leaves too few species for a non-degenerate hull", {
  testthat::skip_if_not_installed("geometry")

  set.seed(4)
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  # simulate_fishmorph_points() has 3 species; n_axes = 3 leaves no slack
  # (nlevels(groups) must be strictly greater than n_axes)
  expect_error(bootstrap_functional_space(ts, n_axes = 3), "requires more than")
})

test_that("bootstrap_functional_space() validates `n_axes` and `n_boot`", {
  testthat::skip_if_not_installed("geometry")

  set.seed(5)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  expect_error(bootstrap_functional_space(ts, n_axes = 1), ">= 2")
  expect_error(bootstrap_functional_space(ts, n_axes = 2, n_boot = 0), "positive integer")
})

test_that("bootstrap_functional_space() errors informatively without the geometry package", {
  testthat::skip_if(
    requireNamespace("geometry", quietly = TRUE),
    "geometry is installed; cannot test the missing-package error message"
  )
  df <- data.frame(a = 1:9, b = 1:9)
  expect_error(
    bootstrap_functional_space(df, groups = rep(c("G1", "G2", "G3"), 3)),
    "geometry"
  )
})

test_that("print.intrait_bootstrap_fspace() and plot.intrait_bootstrap_fspace() do not error", {
  testthat::skip_if_not_installed("geometry")

  set.seed(6)
  fish <- simulate_fishmorph_points(n_per_species = 12, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))
  bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 30)

  expect_output(print(bf), "intrait_bootstrap_fspace")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(bf), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that(".convex_hull_volume() returns NA for degenerate point sets rather than erroring", {
  testthat::skip_if_not_installed("geometry")

  # fewer points than dimensions + 1
  expect_true(is.na(intraitR:::.convex_hull_volume(matrix(1:4, nrow = 2, ncol = 2))))
  # collinear points in 2D (zero-area hull): qhull errors on this input,
  # which must be caught and returned as NA, not propagated
  collinear <- cbind(x = 1:5, y = 1:5)
  expect_true(is.na(intraitR:::.convex_hull_volume(collinear)))
})

test_that(".convex_hull_volume() computes the known volume of a unit hypercube's vertices", {
  testthat::skip_if_not_installed("geometry")

  # all 8 vertices of the unit cube in 3D: convex hull volume is exactly 1
  cube <- as.matrix(expand.grid(x = c(0, 1), y = c(0, 1), z = c(0, 1)))
  expect_equal(intraitR:::.convex_hull_volume(cube), 1, tolerance = 1e-6)
})

test_that("bootstrap_functional_space() runs with method = \"dendrogram\" (no extra package required)", {
  set.seed(7)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(ts, method = "dendrogram", n_axes = 2, n_boot = 50)

  expect_s3_class(bf, "intrait_bootstrap_fspace")
  expect_equal(bf$method, "dendrogram")
  expect_length(bf$fd_boot, 50)
  expect_true(is.finite(bf$fd_ref) && bf$fd_ref >= 0)
  expect_true(all(bf$fd_boot[!is.na(bf$fd_boot)] >= 0))
  expect_true(bf$p_value >= 0 && bf$p_value <= 1)

  expect_output(print(bf), "dendrogram")
  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(bf), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("bootstrap_functional_space(method = \"dendrogram\") does not require nlevels(groups) > n_axes", {
  # Unlike \"convexhull\", the dendrogram method should only warn (not
  # error) when n_axes is not smaller than the number of species -- it has
  # no affine-independence requirement.
  set.seed(8)
  fish <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  # simulate_fishmorph_points() has 3 species; n_axes = 3 leaves no slack
  expect_warning(
    bf <- bootstrap_functional_space(ts, method = "dendrogram", n_axes = 3, n_boot = 20),
    "not smaller than"
  )
  expect_s3_class(bf, "intrait_bootstrap_fspace")
})

test_that(".dendrogram_richness() returns 0 for a small deterministic point set and NA for < 2 points", {
  expect_true(is.na(intraitR:::.dendrogram_richness(matrix(1, nrow = 1, ncol = 2))))

  # two points at unit distance, one merge at height 1: the tree has two
  # edges (one per leaf, each running from height 0 up to the single
  # internal node at height 1), so total branch length = 2 * 1 = 2,
  # exactly twice the pairwise distance.
  two_pts <- rbind(c(0, 0), c(1, 0))
  expect_equal(intraitR:::.dendrogram_richness(two_pts), 2, tolerance = 1e-8)
})

test_that("bootstrap_functional_space() errors informatively for method = \"tpd\"/\"hypervolume\" without the package", {
  testthat::skip_if(
    requireNamespace("TPD", quietly = TRUE),
    "TPD is installed; cannot test the missing-package error message"
  )
  df <- data.frame(a = 1:9, b = 1:9)
  expect_error(
    bootstrap_functional_space(df, groups = rep(c("G1", "G2", "G3"), 3), method = "tpd"),
    "TPD"
  )
})

test_that("bootstrap_functional_space() runs with method = \"tpd\" when the TPD package is available", {
  testthat::skip_if_not_installed("TPD")

  set.seed(9)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(ts, method = "tpd", n_axes = 2, n_boot = 10)
  expect_s3_class(bf, "intrait_bootstrap_fspace")
  expect_equal(bf$method, "tpd")
  expect_true(is.finite(bf$fd_ref))
})

test_that("bootstrap_functional_space() runs with method = \"hypervolume\" when the hypervolume package is available", {
  testthat::skip_if_not_installed("hypervolume")
  testthat::skip_on_cran() # comparatively slow even at small n_boot

  set.seed(10)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(seg)
  ts <- suppressWarnings(trait_space(ratios, groups = fish$metadata$species))

  bf <- bootstrap_functional_space(
    ts, method = "hypervolume", n_axes = 2, n_boot = 5,
    hv_samples_per_point = 100
  )
  expect_s3_class(bf, "intrait_bootstrap_fspace")
  expect_equal(bf$method, "hypervolume")
  expect_true(is.finite(bf$fd_ref))
})

# Shared fixture for the `composition` (per-community) tests below: the
# same "20 species on a circle" layout used above (deterministic, known to
# be well-powered), reused here so per-community results can be checked
# against the whole-pool fd_ref/fd_boot computed from the very same data.
.make_circle_traits <- function(seed = 100, n_species = 8, n_ind = 12, jitter_sd = 3.5) {
  set.seed(seed)
  radius <- 10
  angles <- seq(0, 2 * pi, length.out = n_species + 1)[seq_len(n_species)]
  centers <- data.frame(
    cx = radius * cos(angles), cy = radius * sin(angles),
    species = paste0("sp", seq_len(n_species))
  )
  do.call(rbind, lapply(seq_len(nrow(centers)), function(i) {
    data.frame(
      a = centers$cx[i] + stats::rnorm(n_ind, sd = jitter_sd),
      b = centers$cy[i] + stats::rnorm(n_ind, sd = jitter_sd),
      species = centers$species[i]
    )
  }))
}

test_that("bootstrap_functional_space(composition = ...) computes a per-community table with the expected structure", {
  df <- .make_circle_traits(seed = 101)
  sp <- paste0("sp", 1:8)

  composition <- rbind(
    site_A = as.integer(sp %in% sp[1:4]),
    site_B = as.integer(sp %in% sp[3:8])
  )
  colnames(composition) <- sp

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 60, log_transform = FALSE, scale = FALSE, composition = composition
  )

  expect_s3_class(bf$communities, "data.frame")
  expect_equal(nrow(bf$communities), 2)
  expect_equal(bf$communities$community, c("site_A", "site_B"))
  expect_equal(bf$communities$n_species, c(4L, 6L))
  expect_true(all(bf$communities$fd_obs >= 0))
  expect_true(all(bf$communities$p_value >= 0 & bf$communities$p_value <= 1))
  expect_type(bf$community_boot, "list")
  expect_length(bf$community_boot$site_A, 60)
  expect_length(bf$community_boot$site_B, 60)
  expect_equal(dim(bf$composition), c(2, 8))

  # ses is recomputed by hand from fd_obs/community_boot, exactly as the
  # function itself must compute it internally.
  expect_equal(
    bf$communities$ses[1],
    (bf$communities$fd_obs[1] - mean(bf$community_boot$site_A)) / stats::sd(bf$community_boot$site_A)
  )
})

test_that("bootstrap_functional_space(composition = ...) gives a community spanning the whole pool the exact same fd_obs as fd_ref", {
  df <- .make_circle_traits(seed = 102)
  sp <- paste0("sp", 1:8)
  composition <- matrix(1L, nrow = 1, ncol = 8, dimnames = list("whole_pool", sp))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 30, log_transform = FALSE, scale = FALSE, composition = composition
  )

  # Same species set, same underlying scores -> the centroid-based
  # richness is deterministic and must match the whole-pool fd_ref exactly
  # (no randomness enters fd_obs/fd_ref, unlike fd_boot/fd_expected).
  expect_equal(bf$communities$fd_obs, bf$fd_ref)
  expect_equal(bf$communities$n_species, nlevels(bf$groups))
})

test_that("bootstrap_functional_space(composition = ...) leaves a community with < 2 matched species as NA, with a warning", {
  df <- .make_circle_traits(seed = 103)
  sp <- paste0("sp", 1:8)
  composition <- rbind(
    too_small = as.integer(sp %in% sp[1]),
    ok = as.integer(sp %in% sp[1:3])
  )
  colnames(composition) <- sp

  expect_warning(
    bf <- bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      n_boot = 20, log_transform = FALSE, scale = FALSE, composition = composition
    ),
    "fewer than 2 matched species"
  )
  expect_equal(bf$communities$n_species, c(1L, 3L))
  expect_true(is.na(bf$communities$fd_obs[1]))
  expect_true(is.na(bf$communities$ses[1]))
  expect_true(is.na(bf$communities$p_value[1]))
  expect_length(bf$community_boot$too_small, 0)
  expect_false(is.na(bf$communities$fd_obs[2]))
})

test_that("bootstrap_functional_space(composition = ...) drops unmatched species columns with a warning", {
  df <- .make_circle_traits(seed = 104)
  sp <- paste0("sp", 1:8)
  composition <- matrix(
    as.integer(c(sp, "not_a_real_species") %in% sp), nrow = 1,
    dimnames = list("site_A", c(sp, "not_a_real_species"))
  )

  expect_warning(
    bf <- bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      n_boot = 20, log_transform = FALSE, scale = FALSE, composition = composition
    ),
    "not_a_real_species"
  )
  expect_equal(ncol(bf$composition), 8)
  expect_equal(bf$communities$n_species, 8L)
})

test_that("bootstrap_functional_space() errors informatively on duplicated `composition` column names, rather than silently using the first match", {
  df <- .make_circle_traits(seed = 110)
  sp <- paste0("sp", 1:8)
  composition <- matrix(
    1L, nrow = 1, ncol = 9, dimnames = list("site_A", c(sp, "sp1"))
  )

  expect_error(
    bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      n_boot = 10, log_transform = FALSE, scale = FALSE, composition = composition
    ),
    "duplicated column names"
  )
})

test_that("bootstrap_functional_space(composition = ...) never fails with \"subscript out of bounds\" when only some species match", {
  # Regression test: matched_sp must be built from composition's own
  # column names (a strict subset by construction), never from the
  # species pool's own labels, so the final `composition[, matched_sp]`
  # subsetting can never fail to find a name it just matched.
  df <- .make_circle_traits(seed = 111)
  sp <- paste0("sp", 1:8)
  composition <- matrix(
    1L, nrow = 2, ncol = 6,
    dimnames = list(c("site_A", "site_B"), c(sp[1:5], "unknown_species"))
  )

  expect_warning(
    bf <- bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      n_boot = 10, log_transform = FALSE, scale = FALSE, composition = composition
    ),
    "unknown_species"
  )
  expect_equal(colnames(bf$composition), sp[1:5])
  expect_equal(bf$communities$n_species, c(5L, 5L))
})

test_that("bootstrap_functional_space(composition = ...) auto-generates community identifiers when `composition` has no row names", {
  df <- .make_circle_traits(seed = 105)
  sp <- paste0("sp", 1:8)
  composition <- matrix(1L, nrow = 2, ncol = 8, dimnames = list(NULL, sp))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 10, log_transform = FALSE, scale = FALSE, composition = composition
  )
  expect_equal(bf$communities$community, c("community_1", "community_2"))
})

test_that("bootstrap_functional_space() gives an informative, actionable error when `composition` ends up with 0 columns because `groups` was not a factor", {
  # Regression test for a real user mistake: `groups` (e.g. df$species) is
  # commonly a plain character vector, not a factor, so levels(groups)
  # silently returns NULL (not an error) rather than the species labels --
  # building a composition matrix from that NULL leaves it with 0 columns,
  # which must fail with a message pointing at the actual cause rather
  # than a bare "no column names" error.
  df <- .make_circle_traits(seed = 109)
  expect_true(is.character(df$species)) # not a factor, by construction

  sp_wrong <- levels(df$species) # silently NULL: the mistake being tested
  expect_null(sp_wrong)
  # The real-world consequence of building `composition`'s column names
  # from `sp_wrong`: a matrix with 0 columns (constructed directly here,
  # rather than relying on how rbind()/as.integer() happen to handle a
  # length-0 vector, to keep this test's premise unambiguous).
  composition_wrong <- matrix(numeric(0), nrow = 1, ncol = 0, dimnames = list("site_A", NULL))

  expect_error(
    bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      n_boot = 10, log_transform = FALSE, scale = FALSE, composition = composition_wrong
    ),
    "levels\\(factor\\(x\\)\\)"
  )

  # The correct fix (levels(factor(...)), as in the roxygen example) works.
  sp_right <- levels(factor(df$species))
  composition_right <- matrix(
    1L, nrow = 1, ncol = length(sp_right), dimnames = list("site_A", sp_right)
  )
  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 10, log_transform = FALSE, scale = FALSE, composition = composition_right
  )
  expect_s3_class(bf$communities, "data.frame")
  expect_false(is.na(bf$communities$fd_obs))
})

test_that("bootstrap_functional_space(composition = ...) handles a genuine \"\" species label (e.g. an unresolved specimen) without \"subscript out of bounds\"", {
  # Regression test for a real-data failure: `[`-name-indexing never
  # matches a `\"\"`-named element even when one genuinely exists (see
  # ?Extract: "Neither empty (\"\") nor NA indices match any names, not
  # even empty nor missing names") -- real T-26-style data can legitimately
  # have `\"\"` as a species label for an unresolved/unidentified specimen
  # (see also group_colors()'s own \"\"-label fix). `composition[, matched_sp]`
  # must not rely on `[`-name-matching for this to work.
  df <- .make_circle_traits(seed = 112)
  df$species[df$species == "sp1"] <- ""
  sp <- sort(unique(df$species)) # levels(factor(...)) puts "" first, alphabetically
  expect_true("" %in% sp)

  composition <- matrix(1L, nrow = 1, ncol = length(sp), dimnames = list("site_A", sp))

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 10, log_transform = FALSE, scale = FALSE, composition = composition
  )
  expect_s3_class(bf$communities, "data.frame")
  expect_equal(bf$communities$n_species, length(sp))
  expect_false(is.na(bf$communities$fd_obs))
  expect_true("" %in% colnames(bf$composition))
})

test_that("bootstrap_functional_space() errors informatively for an invalid `composition`", {
  df <- .make_circle_traits(seed = 106)
  sp <- paste0("sp", 1:8)

  expect_error(
    bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      log_transform = FALSE, scale = FALSE, composition = list(a = 1)
    ),
    "matrix or data.frame"
  )
  expect_error(
    bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      log_transform = FALSE, scale = FALSE, composition = matrix(1, nrow = 1, ncol = 1)
    ),
    "column names"
  )
  bad_composition <- matrix(1, nrow = 1, ncol = 1, dimnames = list(NULL, "not_a_species"))
  expect_error(
    bootstrap_functional_space(
      df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
      log_transform = FALSE, scale = FALSE, composition = bad_composition
    ),
    "None of `composition`"
  )
})

test_that("plot.intrait_bootstrap_fspace(type = \"communities\") draws without error, and errors without `composition`", {
  df <- .make_circle_traits(seed = 107)
  sp <- paste0("sp", 1:8)
  composition <- rbind(
    site_A = as.integer(sp %in% sp[1:4]),
    site_B = as.integer(sp %in% sp[3:8]),
    site_C = as.integer(sp %in% sp)
  )
  colnames(composition) <- sp

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 30, log_transform = FALSE, scale = FALSE, composition = composition
  )

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(bf), NA) # type = "pool" (default) still works unchanged
  expect_error(plot(bf, type = "communities"), NA)
  expect_error(plot(bf, type = "communities", order = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp)

  bf_nocomm <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2, n_boot = 10,
    log_transform = FALSE, scale = FALSE
  )
  expect_error(plot(bf_nocomm, type = "communities"), "no per-community results")
})

test_that("plot.intrait_bootstrap_fspace(type = \"communities\") always keeps SES = 0 (the reference line/segments) inside the plotted x-range", {
  # Regression test: when every community's `ses` sits far from 0 relative
  # to their own spread, an xlim computed only from range(ses) can leave 0
  # outside the plotted area, silently hiding the abline(v = 0) reference
  # and truncating every connecting segment at the plot edge instead of at
  # 0 -- exactly what happened with real, consistently negative SES values.
  df <- .make_circle_traits(seed = 113)
  sp <- paste0("sp", 1:8)
  composition <- rbind(
    site_A = as.integer(sp %in% sp[1:3]),
    site_B = as.integer(sp %in% sp[2:4]),
    site_C = as.integer(sp %in% sp)
  )
  colnames(composition) <- sp

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 30, log_transform = FALSE, scale = FALSE, composition = composition
  )
  # Force every ses value far from 0 (well beyond its own spread), the
  # exact condition that exposed the bug, regardless of what this
  # particular random draw happened to produce.
  bf$communities$ses <- c(-5, -8, -12)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  plot(bf, type = "communities")
  usr <- graphics::par("usr")
  grDevices::dev.off()
  unlink(tmp)

  expect_true(usr[1] <= 0 && 0 <= usr[2])
})

test_that("print.intrait_bootstrap_fspace() reports the per-community summary when `composition` was supplied", {
  df <- .make_circle_traits(seed = 108)
  sp <- paste0("sp", 1:8)
  composition <- rbind(
    site_A = as.integer(sp %in% sp[1:4]),
    site_B = as.integer(sp %in% sp[3:8])
  )
  colnames(composition) <- sp

  bf <- bootstrap_functional_space(
    df[c("a", "b")], groups = df$species, method = "dendrogram", n_axes = 2,
    n_boot = 20, log_transform = FALSE, scale = FALSE, composition = composition
  )
  expect_output(print(bf), "communities")
  expect_output(print(bf), "site_A")
})
