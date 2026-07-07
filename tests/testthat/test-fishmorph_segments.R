make_minimal_fishmorph_array <- function(n_landmarks = 21, scale_dist = 10) {
  # Build a single-specimen 21-landmark array with simple, hand-checkable
  # coordinates: every measurement pair is placed a known Euclidean
  # distance apart, and the scale bar (20-21) spans `scale_dist` units.
  A <- array(0, dim = c(n_landmarks, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  # Bl: 1 -> 2, distance 40
  A[1, , 1] <- c(0, 0)
  A[2, , 1] <- c(40, 0)
  # Bd: 3 -> 4, distance 10
  A[3, , 1] <- c(5, 10)
  A[4, , 1] <- c(5, 0)
  # Hd: 5 -> 6, distance 6
  A[5, , 1] <- c(2, 6)
  A[6, , 1] <- c(2, 0)
  # Eh: 7 -> 8, distance 4
  A[7, , 1] <- c(3, 4)
  A[8, , 1] <- c(3, 0)
  # Mo: 1 -> 9, distance 3 (point 1 already at origin)
  A[9, , 1] <- c(0, 3)
  # PFi: 10 -> 11, distance 2 ; PFl: 10 -> 12, distance 5
  A[10, , 1] <- c(6, 2)
  A[11, , 1] <- c(6, 0)
  A[12, , 1] <- c(11, 2)
  # Ed: 13 -> 14, distance 1
  A[13, , 1] <- c(3, 5)
  A[14, , 1] <- c(3, 4)
  # Jl: 1 -> 15, distance 5 (point 1 at origin)
  A[15, , 1] <- c(3, 4)
  # CPd: 16 -> 17, distance 8
  A[16, , 1] <- c(30, 8)
  A[17, , 1] <- c(30, 0)
  # CFd: 18 -> 19, distance 20
  A[18, , 1] <- c(35, 15)
  A[19, , 1] <- c(35, -5)
  # scale bar 20 -> 21
  A[20, , 1] <- c(0, -20)
  A[21, , 1] <- c(scale_dist, -20)
  A
}

test_that("fishmorph_segments() computes correct distances and applies scale", {
  A <- make_minimal_fishmorph_array(scale_dist = 10) # 10 px = 1 cm -> px_to_cm = 0.1
  seg <- fishmorph_segments(A, scale_cm = 1)

  expect_s3_class(seg, "intrait_segments")
  expect_equal(seg$Bl, 4)   # 40 * 0.1
  expect_equal(seg$Bd, 1)   # 10 * 0.1
  expect_equal(seg$Hd, 0.6) # 6 * 0.1
  expect_equal(seg$Eh, 0.4) # 4 * 0.1
  expect_equal(seg$Mo, 0.3) # 3 * 0.1
  expect_equal(seg$PFi, 0.2)
  expect_equal(seg$PFl, 0.5)
  expect_equal(seg$Ed, 0.1)
  expect_equal(seg$Jl, 0.5)
  expect_equal(seg$CPd, 0.8)
  expect_equal(seg$CFd, 2)
})

test_that("fishmorph_segments() errors below 21 landmarks", {
  A <- array(0, dim = c(10, 2, 1))
  expect_error(fishmorph_segments(A), "at least 21 landmarks")
})

test_that("fishmorph_segments() errors on non-2D arrays", {
  A <- array(0, dim = c(21, 3, 1))
  expect_error(fishmorph_segments(A), "two-dimensional")
})

test_that("fishmorph_segments() warns and returns NA for zero-length scale bars", {
  A <- make_minimal_fishmorph_array(scale_dist = 10)
  A[21, , 1] <- A[20, , 1] # collapse the scale bar to zero length
  expect_warning(seg <- fishmorph_segments(A), "scale bar")
  expect_true(is.na(seg$Bl))
})

test_that("fishmorph_segments() applies curvature correction via point 22 when present", {
  A21 <- make_minimal_fishmorph_array(scale_dist = 10)
  A22 <- array(0, dim = c(22, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A22[1:21, , ] <- A21
  A22[22, , 1] <- c(20, 6) # midpoint bent upward -> curved path longer than straight line
  seg <- fishmorph_segments(A22, scale_cm = 1)
  straight <- fishmorph_segments(A21, scale_cm = 1)
  expect_true(seg$Bl > straight$Bl)
})

test_that("fishmorph_segments() ignores point 22 when it is all zero", {
  A22 <- array(0, dim = c(22, 2, 1), dimnames = list(NULL, c("X", "Y"), "s1"))
  A22[1:21, , ] <- make_minimal_fishmorph_array(scale_dist = 10)
  # point 22 left at (0,0) -> "not used"
  seg <- fishmorph_segments(A22, scale_cm = 1)
  expect_equal(seg$Bl, 4)
})

test_that("fishmorph_segments() carries over metadata", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  expect_true("species" %in% names(seg))
  expect_equal(nrow(seg), dim(fish$coords)[3])
})

# --- na_action --------------------------------------------------------

make_fish_with_missing_landmark <- function() {
  fish <- simulate_fishmorph_points(n_per_species = 6, n_replicates = 1)
  A <- fish$coords
  A[5, , 1] <- NA_real_ # plant a missing landmark 5, as in ~1/4 of real T-26 fish
  fish$coords <- A
  fish
}

test_that("fishmorph_segments() na_action = 'keep' (default) leaves NA in place", {
  fish <- make_fish_with_missing_landmark()
  seg <- fishmorph_segments(fish)
  expect_true(is.na(seg$Hd[1]))
  expect_false(anyNA(seg$Bl)) # Bl (1-2) does not use landmark 5
})

test_that("fishmorph_segments() na_action = 'omit' drops affected specimens and messages", {
  fish <- make_fish_with_missing_landmark()
  expect_message(
    seg <- fishmorph_segments(fish, na_action = "omit"),
    "removing 1 row"
  )
  expect_equal(nrow(seg), dim(fish$coords)[3] - 1)
  expect_false(anyNA(seg$Hd))
})

test_that("fishmorph_segments() na_action = 'impute_mean' fills NA with the column mean", {
  fish <- make_fish_with_missing_landmark()
  seg_keep <- fishmorph_segments(fish)
  expect_message(
    seg <- fishmorph_segments(fish, na_action = "impute_mean"),
    "imputed 1 missing value"
  )
  expect_false(anyNA(seg$Hd))
  expect_equal(seg$Hd[1], mean(seg_keep$Hd, na.rm = TRUE))
})

test_that("fishmorph_segments() na_action = 'impute_group_mean' auto-detects species and uses within-group means", {
  fish <- make_fish_with_missing_landmark()
  seg_keep <- fishmorph_segments(fish)
  sp <- seg_keep$species[1]
  expect_message(
    seg <- fishmorph_segments(fish, na_action = "impute_group_mean"),
    "imputed 1 missing value"
  )
  expect_false(anyNA(seg$Hd))
  expect_equal(seg$Hd[1], mean(seg_keep$Hd[seg_keep$species == sp], na.rm = TRUE))
})

test_that("fishmorph_segments() na_action = 'impute_group_mean' requires groups when none can be detected", {
  A <- make_minimal_fishmorph_array(scale_dist = 10)
  A2 <- array(0, dim = c(21, 2, 2), dimnames = list(NULL, c("X", "Y"), c("s1", "s2")))
  A2[, , 1] <- A[, , 1]
  A2[, , 2] <- A[, , 1]
  A2[5, , 2] <- NA_real_
  expect_error(
    fishmorph_segments(A2, na_action = "impute_group_mean"),
    "requires `groups`"
  )
})

test_that("fishmorph_segments() na_action = 'missforest' imputes missing values", {
  testthat::skip_if_not_installed("missForest")
  set.seed(321)
  fish <- make_fish_with_missing_landmark()
  expect_message(
    seg <- suppressWarnings(fishmorph_segments(
      fish, na_action = "missforest", missforest_ntree = 20, missforest_maxiter = 2
    )),
    "missforest"
  )
  expect_false(anyNA(seg$Hd))
})

test_that("fishmorph_segments() na_action = 'missforest_phylo' imputes using phylogenetic axes from a supplied tree", {
  testthat::skip_if_not_installed("missForest")
  testthat::skip_if_not_installed("ape")
  set.seed(322)
  fish <- make_fish_with_missing_landmark()
  tree <- ape::rcoal(3, tip.label = c("Species_A", "Species_B", "Species_C"))
  expect_message(
    seg <- suppressWarnings(fishmorph_segments(
      fish, na_action = "missforest_phylo", tree = tree,
      missforest_ntree = 20, missforest_maxiter = 2
    )),
    "missforest_phylo"
  )
  expect_false(anyNA(seg$Hd))
})

# --- geometry_check -----------------------------------------------------

make_conforming_fishmorph_array <- function(specimen_names = "s1") {
  # A 21-landmark configuration that satisfies every convention checked by
  # correct_landmarks(rule = "check_geometry") exactly (see
  # test-correct_landmarks.R's make_geometry_array(), duplicated here so
  # this file stays self-contained), plus real values for every other
  # landmark fishmorph_segments() needs (12, 15, 16-19, scale bar 20-21),
  # so every one of the 11 measurements is a finite, checkable number.
  p <- 21
  n <- length(specimen_names)
  A <- array(0, dim = c(p, 2, n), dimnames = list(NULL, c("X", "Y"), specimen_names))
  pts <- list(
    `1` = c(0, 500), `2` = c(1000, 500), `3` = c(300, 700), `4` = c(300, 400),
    `5` = c(450, 650), `6` = c(450, 450), `7` = c(450, 490), `8` = c(450, 400),
    `9` = c(0, 400), `10` = c(600, 650), `11` = c(600, 400),
    `12` = c(700, 650), `13` = c(450, 510), `14` = c(450, 470), `15` = c(100, 450),
    `16` = c(800, 700), `17` = c(800, 300), `18` = c(900, 750), `19` = c(900, 250),
    `20` = c(0, 100), `21` = c(100, 100)
  )
  for (i in as.integer(names(pts))) {
    for (s in seq_len(n)) A[i, , s] <- pts[[as.character(i)]]
  }
  A
}

test_that("fishmorph_segments() sets NA for measurements tied to a failing geometry check", {
  A <- make_conforming_fishmorph_array()
  A[4, "X", 1] <- 900 # break segment (3,4)'s perpendicularity to the main axis
  geom_check <- correct_landmarks(A, rule = "check_geometry")
  expect_true(any(!geom_check$ok[geom_check$check == "perpendicular_seg_3_4_vs_axis"]))
  expect_true(any(!geom_check$ok[geom_check$check == "parallel_vertical_segments"]))

  seg_plain <- fishmorph_segments(A)
  expect_false(anyNA(seg_plain[, c("Mo", "Bd", "PFi", "Hd", "Eh", "Ed")]))

  expect_message(
    seg_flagged <- fishmorph_segments(A, geometry_check = geom_check),
    "geometry_check"
  )
  # Bd directly (its own segment failed), and the rest of the "vertical
  # segments" family, since a mutual-parallelism failure could implicate
  # any of the four lines, not just the one that moved:
  expect_true(all(is.na(seg_flagged[, c("Mo", "Bd", "PFi", "Hd", "Eh", "Ed")])))
  # traits outside the checked battery are untouched
  expect_false(anyNA(seg_flagged[, c("Bl", "PFl", "Jl", "CPd", "CFd")]))
})

test_that("fishmorph_segments()'s geometry_check only affects the specific trait(s) implicated", {
  A <- make_conforming_fishmorph_array()
  A[9, "Y", 1] <- 300 # break the horizontal line's parallelism to the axis only
  geom_check <- correct_landmarks(A, rule = "check_geometry")
  expect_true(any(!geom_check$ok[geom_check$check == "axis_horizontal_parallel"]))
  expect_true(all(geom_check$ok[geom_check$check == "parallel_vertical_segments"]))

  seg_flagged <- suppressMessages(fishmorph_segments(A, geometry_check = geom_check))
  expect_true(is.na(seg_flagged$Bl))
  expect_false(anyNA(seg_flagged[, c("Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")]))
})

test_that("fishmorph_segments()'s geometry_check NAs are handled by na_action", {
  # Two specimens: only s1's segment (3, 4) is broken, s2 stays conforming,
  # so the column mean impute_mean() falls back on has a real value to draw
  # from (with a single flagged specimen, the column would be entirely NA
  # and "impute_mean" would have nothing to impute from).
  A <- make_conforming_fishmorph_array(c("s1", "s2"))
  A[4, "X", 1] <- 900
  geom_check <- correct_landmarks(A, rule = "check_geometry")
  seg <- suppressMessages(fishmorph_segments(A, geometry_check = geom_check, na_action = "impute_mean"))
  expect_false(anyNA(seg$Bd))
})

test_that("fishmorph_segments() warns and ignores a geometry_check with no matching specimen", {
  A <- make_conforming_fishmorph_array()
  geom_check <- correct_landmarks(A, rule = "check_geometry")
  dimnames(A)[[3]] <- "a_different_specimen_name"
  expect_warning(
    seg <- fishmorph_segments(A, geometry_check = geom_check),
    "no specimen matching"
  )
  expect_false(anyNA(seg$Bd))
})

test_that("fishmorph_segments() errors on an invalid `geometry_check`", {
  A <- make_conforming_fishmorph_array()
  expect_error(
    fishmorph_segments(A, geometry_check = data.frame(x = 1)),
    "correct_landmarks"
  )
})
