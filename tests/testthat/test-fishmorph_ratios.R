make_segments_df <- function() {
  data.frame(
    Bl = c(40, 20), Bd = c(10, 10), Hd = c(6, 6), Eh = c(4, 4), Mo = c(3, 3),
    PFi = c(2, 2), PFl = c(5, 5), Ed = c(1, 1), Jl = c(5, 5), CPd = c(8, 8), CFd = c(20, 4),
    row.names = c("s1", "s2")
  )
}

test_that("fishmorph_ratios() computes the nine ratios correctly", {
  seg <- make_segments_df()
  r <- fishmorph_ratios(seg)

  expect_s3_class(r, "intrait_fishmorph")
  # fishmorph_ratios() rounds to `digits` (default 4) decimal places, so
  # expected values are rounded the same way before comparison.
  expect_equal(r$BEl, round(seg$Bl / seg$Bd, 4))
  expect_equal(r$VEp, round(seg$Eh / seg$Bd, 4))
  expect_equal(r$REs, round(seg$Ed / seg$Hd, 4))
  expect_equal(r$OGp, round(seg$Mo / seg$Bd, 4))
  expect_equal(r$RMl, round(seg$Jl / seg$Hd, 4))
  expect_equal(r$BLs, round(seg$Hd / seg$Bd, 4))
  expect_equal(r$PFv, round(seg$PFi / seg$Bd, 4))
  expect_equal(r$PFs, round(seg$PFl / seg$Bl, 4))
  expect_equal(r$CPt, round(seg$CFd / seg$CPd, 4))
})

test_that("fishmorph_ratios() applies Villeger et al. (2010) exception rules", {
  seg <- make_segments_df()
  r <- fishmorph_ratios(
    seg,
    no_caudal_fin = c(TRUE, FALSE),
    ventral_mouth = c(FALSE, TRUE),
    no_pectoral_fin = c(TRUE, TRUE)
  )
  expect_equal(r$CPt[1], 1)
  expect_equal(r$CPt[2], seg$CFd[2] / seg$CPd[2])
  expect_equal(r$OGp[2], 0)
  expect_equal(r$RMl[2], 0)
  expect_true(all(r$PFv == 0))
})

test_that("fishmorph_ratios() adds MBl when supplied", {
  seg <- make_segments_df()
  r <- fishmorph_ratios(seg, MBl = c(15, 8))
  expect_equal(r$MBl, c(15, 8))
  expect_equal(names(r)[1], "MBl")
})

test_that("fishmorph_ratios() errors on missing required columns", {
  expect_error(fishmorph_ratios(data.frame(Bl = 1, Bd = 1)), "missing required column")
})

test_that("fishmorph_ratios() errors on mismatched exception-flag length", {
  seg <- make_segments_df()
  expect_error(fishmorph_ratios(seg, no_caudal_fin = c(TRUE, TRUE, TRUE)), "length 1 or nrow")
})

test_that("fishmorph_ratios() end-to-end from simulated points", {
  fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
  seg <- fishmorph_segments(fish)
  r <- fishmorph_ratios(seg)
  expect_equal(nrow(r), nrow(seg))
  expect_true(all(c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt") %in% names(r)))
  expect_true("species" %in% names(r))
})

# --- na_action --------------------------------------------------------

make_segments_with_na <- function() {
  data.frame(
    species = rep(c("A", "B"), each = 3),
    Bl = c(40, 20, 30, 25, 35, 45), Bd = rep(10, 6), Hd = c(6, 6, NA, 6, 6, 6),
    Eh = rep(4, 6), Mo = rep(3, 6), PFi = rep(2, 6), PFl = rep(5, 6),
    Ed = rep(1, 6), Jl = rep(5, 6), CPd = rep(8, 6), CFd = c(20, 4, 12, 16, 8, 10),
    row.names = paste0("s", 1:6)
  )
}

test_that("fishmorph_ratios() na_action = 'keep' (default) leaves NA in place", {
  seg <- make_segments_with_na()
  r <- fishmorph_ratios(seg)
  expect_true(is.na(r$REs[3]))
  expect_true(is.na(r$RMl[3]))
  expect_true(is.na(r$BLs[3]))
  expect_false(anyNA(r$BEl)) # BEl (Bl/Bd) does not use Hd
})

test_that("fishmorph_ratios() na_action = 'omit' drops affected rows and messages", {
  seg <- make_segments_with_na()
  expect_message(
    r <- fishmorph_ratios(seg, na_action = "omit"),
    "removing 1 row"
  )
  expect_equal(nrow(r), nrow(seg) - 1)
  expect_false(anyNA(r$REs))
})

test_that("fishmorph_ratios() na_action = 'omit' subsets MBl consistently", {
  seg <- make_segments_with_na()
  expect_message(
    r <- fishmorph_ratios(seg, MBl = seq_len(nrow(seg)), na_action = "omit"),
    "removing 1 row"
  )
  expect_equal(nrow(r), nrow(seg) - 1)
  expect_equal(r$MBl, seq_len(nrow(seg))[-3])
})

test_that("fishmorph_ratios() na_action = 'impute_mean' fills NA with the column mean", {
  seg <- make_segments_with_na()
  r_keep <- fishmorph_ratios(seg)
  expect_message(
    r <- fishmorph_ratios(seg, na_action = "impute_mean"),
    "imputed"
  )
  expect_false(anyNA(r$REs))
  expect_equal(r$REs[3], round(mean(r_keep$REs, na.rm = TRUE), 4))
})

test_that("fishmorph_ratios() na_action = 'impute_group_mean' auto-detects species and uses within-group means", {
  seg <- make_segments_with_na()
  r_keep <- fishmorph_ratios(seg)
  expect_message(
    r <- fishmorph_ratios(seg, na_action = "impute_group_mean"),
    "imputed"
  )
  expect_false(anyNA(r$REs))
  expect_equal(r$REs[3], round(mean(r_keep$REs[seg$species == "A"], na.rm = TRUE), 4))
})

test_that("fishmorph_ratios() na_action = 'impute_group_mean' requires groups when none can be detected", {
  seg <- make_segments_with_na()
  seg$species <- NULL
  expect_error(
    fishmorph_ratios(seg, na_action = "impute_group_mean"),
    "requires `groups`"
  )
})

test_that("fishmorph_ratios() na_action = 'missforest' imputes missing values", {
  testthat::skip_if_not_installed("missForest")
  set.seed(654)
  seg <- make_segments_with_na()
  expect_message(
    r <- suppressWarnings(fishmorph_ratios(
      seg, na_action = "missforest", missforest_ntree = 20, missforest_maxiter = 2
    )),
    "missforest"
  )
  expect_false(anyNA(r$REs))
})

test_that("fishmorph_ratios() na_action = 'missforest_phylo' falls back to plain missforest, with a warning, below the 3-species phylogenetic minimum", {
  testthat::skip_if_not_installed("missForest")
  testthat::skip_if_not_installed("ape")
  set.seed(655)
  seg <- make_segments_with_na() # only 2 distinct species ("A", "B")
  tree <- ape::rcoal(3, tip.label = c("A", "B", "C"))
  expect_warning(
    r <- suppressMessages(fishmorph_ratios(
      seg, na_action = "missforest_phylo", tree = tree,
      missforest_ntree = 20, missforest_maxiter = 2
    )),
    "phylogenetic axes could not be used"
  )
  expect_false(anyNA(r$REs))
})

# --- landmarks-based ratio rescue for a missing scale bar --------------

test_that("fishmorph_ratios(landmarks = ...) rescues ratios exactly when only the scale bar is missing", {
  set.seed(701)
  fish <- simulate_fishmorph_points(n_per_species = 4, n_replicates = 1)
  seg_ok <- fishmorph_segments(fish)
  ratios_ok <- fishmorph_ratios(seg_ok)

  fish_bad <- fish
  fish_bad$coords[20, , 1] <- NA_real_ # specimen 1's scale bar goes missing
  seg_bad <- suppressWarnings(fishmorph_segments(fish_bad))
  required <- c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")
  expect_true(all(is.na(seg_bad[1, required])))

  ratio_cols <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
  expect_message(
    ratios_rescued <- fishmorph_ratios(seg_bad, landmarks = fish_bad),
    "rescued ratios for 1 specimen"
  )
  expect_equal(
    as.numeric(ratios_rescued[1, ratio_cols]),
    as.numeric(ratios_ok[1, ratio_cols])
  )
  # absolute segments are not, and cannot be, rescued -- only the ratios
  expect_false(anyNA(ratios_rescued[, ratio_cols]))
})

test_that("fishmorph_ratios(landmarks = ...) leaves specimens with only a partial NA pattern untouched", {
  set.seed(702)
  fish <- simulate_fishmorph_points(n_per_species = 4, n_replicates = 1)
  fish$coords[5, , 1] <- NA_real_ # specimen 1 missing one anatomical landmark; scale bar intact
  seg <- fishmorph_segments(fish) # Hd (and ratios using it) are NA for specimen 1; Bl/Bd/etc are not
  required <- c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")
  expect_false(all(is.na(seg[1, required])))

  ratios_before <- fishmorph_ratios(seg)
  expect_silent(ratios_after <- fishmorph_ratios(seg, landmarks = fish))
  # partial-NA specimen is left exactly as-is: same values, same NA pattern
  expect_equal(ratios_after[1, ], ratios_before[1, ])
})

test_that("fishmorph_ratios(landmarks = ...) warns and ignores a malformed `landmarks` argument", {
  set.seed(703)
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  fish$coords[20, , 1] <- NA_real_
  seg <- suppressWarnings(fishmorph_segments(fish))
  expect_warning(
    fishmorph_ratios(seg, landmarks = matrix(1:4, 2, 2)),
    "could not be used to rescue"
  )
})

test_that("fishmorph_ratios(landmarks = ...) is a silent no-op when no specimen matches", {
  set.seed(704)
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  fish$coords[20, , 1] <- NA_real_
  seg <- suppressWarnings(fishmorph_segments(fish))

  unrelated <- fish
  dimnames(unrelated$coords)[[3]] <- paste0("other_", seq_len(dim(unrelated$coords)[3]))

  ratio_cols <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
  expect_silent(r <- fishmorph_ratios(seg, landmarks = unrelated))
  expect_true(all(is.na(r[1, ratio_cols])))
})
