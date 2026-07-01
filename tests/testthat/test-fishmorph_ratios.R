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
