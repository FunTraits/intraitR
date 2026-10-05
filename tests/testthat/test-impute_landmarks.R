test_that("impute_landmarks() errors below 21 landmarks", {
  A <- array(0, dim = c(10, 2, 1))
  expect_error(impute_landmarks(A), "at least 21 landmarks")
})

test_that("impute_landmarks() errors on non-2D arrays", {
  A <- array(0, dim = c(21, 3, 1))
  expect_error(impute_landmarks(A), "two-dimensional")
})

test_that("impute_landmarks() messages and returns unchanged input when nothing is missing", {
  testthat::skip_if_not_installed("geomorph")
  fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
  expect_message(
    fish_out <- impute_landmarks(fish),
    "nothing to impute"
  )
  expect_identical(fish_out, fish)
})

test_that("impute_landmarks() fills a missing anatomical landmark and leaves the scale bar untouched", {
  testthat::skip_if_not_installed("geomorph")
  set.seed(42)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_ # a single missing anatomical landmark, as in real T-26 data
  fish$coords <- A

  expect_message(fish_imputed <- impute_landmarks(fish), "estimated 1 missing")
  expect_s3_class(fish_imputed, "intrait_landmarks")
  expect_equal(dim(fish_imputed$coords), dim(fish$coords))
  expect_false(anyNA(fish_imputed$coords[1:19, , ]))
  # scale bar (20-21) and metadata are untouched
  expect_equal(fish_imputed$coords[20:21, , ], fish$coords[20:21, , ])
  expect_identical(fish_imputed$metadata, fish$metadata)
})

test_that("impute_landmarks() warns and leaves NA when the scale bar itself is missing", {
  testthat::skip_if_not_installed("geomorph")
  set.seed(43)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[20, , 1] <- NA_real_
  A[5, , 2] <- NA_real_ # also plant an imputable anatomical NA elsewhere
  fish$coords <- A

  expect_warning(fish_imputed <- impute_landmarks(fish), "scale bar")
  expect_true(anyNA(fish_imputed$coords[20, , 1]))
  expect_false(anyNA(fish_imputed$coords[1:19, , 2]))
})

test_that("impute_landmarks() accepts method = 'regression'", {
  testthat::skip_if_not_installed("geomorph")
  set.seed(44)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[6, , 1] <- NA_real_
  fish$coords <- A
  expect_error(impute_landmarks(fish, method = "regression"), NA)
})

test_that("impute_landmarks() attaches an 'imputed' attribute marking exactly the estimated points", {
  testthat::skip_if_not_installed("geomorph")
  set.seed(46)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  A[6, 1, 2] <- NA_real_ # only the X coordinate missing -> still counts as landmark 6 imputed
  fish$coords <- A

  fish_imputed <- suppressMessages(impute_landmarks(fish))
  imputed <- attr(fish_imputed$coords, "imputed")

  expect_false(is.null(imputed))
  expect_equal(dim(imputed), c(dim(A)[1], dim(A)[3]))
  expect_true(imputed[5, 1])
  expect_true(imputed[6, 2])
  # nothing else was missing, and landmarks 20+ are never marked as imputed
  expect_equal(sum(imputed), 2)
})

test_that("impute_landmarks() works on a raw p x k x n array and returns a raw array", {
  testthat::skip_if_not_installed("geomorph")
  set.seed(45)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  out <- impute_landmarks(A)
  expect_true(is.array(out))
  expect_false(inherits(out, "intrait_landmarks"))
  expect_false(anyNA(out[1:19, , ]))
})

test_that("impute_landmarks(method = 'impute_mean') fills missing coordinates with column means", {
  set.seed(47)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, 1, 1] <- NA_real_
  # computed *after* inserting the NA, matching impute_landmarks()'s own
  # mean(M[, j], na.rm = TRUE): the mean of the *other*, non-missing
  # specimens, not one that also includes the value about to be imputed.
  col_mean <- mean(A[5, 1, ], na.rm = TRUE)
  fish$coords <- A

  expect_message(fish_imputed <- impute_landmarks(fish, method = "impute_mean"), "column means")
  expect_false(anyNA(fish_imputed$coords[1:19, , ]))
  expect_equal(fish_imputed$coords[5, 1, 1], col_mean)
  # scale bar and metadata untouched
  expect_equal(fish_imputed$coords[20:21, , ], fish$coords[20:21, , ])
  expect_identical(fish_imputed$metadata, fish$metadata)
})

test_that("impute_landmarks(method = 'impute_group_mean') uses the specimen's own group, auto-detected from metadata$species", {
  set.seed(48)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  sp1 <- fish$metadata$species[1]
  same_sp <- which(fish$metadata$species == sp1)
  A[5, 1, same_sp[1]] <- NA_real_
  # computed *after* inserting the NA, matching impute_landmarks()'s own
  # mean(col[groups == g], na.rm = TRUE): the within-group mean of the
  # *other*, non-missing specimens in that group.
  g_mean <- mean(A[5, 1, same_sp], na.rm = TRUE)
  fish$coords <- A

  expect_message(fish_imputed <- impute_landmarks(fish, method = "impute_group_mean"), "within-group means")
  expect_equal(fish_imputed$coords[5, 1, same_sp[1]], g_mean)
})

test_that("impute_landmarks(method = 'impute_group_mean') errors without groups and no metadata$species", {
  set.seed(49)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  expect_error(impute_landmarks(A, method = "impute_group_mean"), "requires `groups`")
})

test_that("impute_landmarks(method = 'impute_group_mean') falls back to the overall mean, with a warning, for a group entirely missing that coordinate", {
  set.seed(50)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  sp1 <- fish$metadata$species[1]
  same_sp <- which(fish$metadata$species == sp1)
  A[5, 1, same_sp] <- NA_real_ # entire group missing this coordinate
  fish$coords <- A

  expect_warning(
    suppressMessages(fish_imputed <- impute_landmarks(fish, method = "impute_group_mean")),
    "no non-missing values"
  )
  expect_false(anyNA(fish_imputed$coords[5, 1, same_sp]))
})

test_that("impute_landmarks(method = 'impute_group_mean') accepts an explicit `groups` argument on a raw array", {
  set.seed(51)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  out <- suppressMessages(impute_landmarks(A, method = "impute_group_mean", groups = fish$metadata$species))
  expect_false(anyNA(out[1:19, , ]))
})

test_that("impute_landmarks(method = 'missforest') imputes using random-forest imputation", {
  testthat::skip_if_not_installed("missForest")
  set.seed(52)
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  fish$coords <- A

  expect_message(fish_imputed <- impute_landmarks(fish, method = "missforest"), "missForest")
  expect_false(anyNA(fish_imputed$coords[1:19, , ]))
  expect_equal(fish_imputed$coords[20:21, , ], fish$coords[20:21, , ])
})

test_that("impute_landmarks(method = 'missforest_phylo') imputes using phylogenetic axes from a supplied tree", {
  testthat::skip_if_not_installed("missForest")
  testthat::skip_if_not_installed("ape")
  set.seed(55)
  fish <- simulate_fishmorph_points(n_per_species = 20, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  fish$coords <- A
  tree <- ape::rcoal(3, tip.label = c("Species_A", "Species_B", "Species_C"))

  expect_message(
    fish_imputed <- impute_landmarks(fish, method = "missforest_phylo", tree = tree),
    "missForest"
  )
  expect_false(anyNA(fish_imputed$coords[1:19, , ]))
  expect_equal(fish_imputed$coords[20:21, , ], fish$coords[20:21, , ])
})

test_that("impute_landmarks(method = 'missforest_phylo') falls back to plain missforest, with a warning, when the tree doesn't match", {
  testthat::skip_if_not_installed("missForest")
  testthat::skip_if_not_installed("ape")
  set.seed(56)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  fish$coords <- A
  tree <- ape::rcoal(3, tip.label = c("Unrelated_1", "Unrelated_2", "Unrelated_3"))

  expect_warning(
    fish_imputed <- suppressMessages(impute_landmarks(fish, method = "missforest_phylo", tree = tree)),
    "phylogenetic axes could not be used"
  )
  expect_false(anyNA(fish_imputed$coords[1:19, , ]))
})

test_that("impute_landmarks(method = 'missforest') errors informatively without the missForest package", {
  testthat::skip_if(requireNamespace("missForest", quietly = TRUE), "missForest is installed")
  set.seed(53)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  fish$coords <- A
  expect_error(impute_landmarks(fish, method = "missforest"), "requires the .missForest. package")
})

test_that("impute_landmarks() validates `groups` length", {
  set.seed(54)
  fish <- simulate_fishmorph_points(n_per_species = 15, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_
  expect_error(
    impute_landmarks(A, method = "impute_group_mean", groups = c("a", "b")),
    "one entry per specimen"
  )
})
