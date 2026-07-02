test_that("load_t26_saudrune_landmarks() returns an intrait_landmarks object shaped like simulate_fishmorph_points()", {
  fish <- load_t26_saudrune_landmarks()

  expect_s3_class(fish, "intrait_landmarks")
  expect_true(all(c("coords", "scale", "metadata") %in% names(fish)))
  expect_null(fish$scale)
  expect_equal(dim(fish$coords)[1], 21)
  expect_equal(dim(fish$coords)[2], 2)
  expect_equal(dim(fish$coords)[3], nrow(fish$metadata))

  expect_true(all(c("specimen", "individual", "species", "population", "replicate") %in% names(fish$metadata)))
  # T-26 sampled a single electrofishing point: no fabricated population structure.
  expect_true(all(is.na(fish$metadata$population)))
  # two operators -> replicate takes exactly two values
  expect_setequal(unique(fish$metadata$replicate), c(1L, 2L))
})

test_that("load_t26_saudrune_landmarks() works as a drop-in for simulate_fishmorph_points() in the FISHMORPH pipeline", {
  fish <- load_t26_saudrune_landmarks()
  segments <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(segments)

  expect_s3_class(segments, "intrait_segments")
  expect_s3_class(ratios, "intrait_fishmorph")
  expect_true(all(c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt") %in% names(ratios)))
})

test_that("load_t26_saudrune_landmarks(source = 'repeatability') returns the 25-individual replicate trial", {
  rep_fish <- load_t26_saudrune_landmarks(source = "repeatability")
  expect_s3_class(rep_fish, "intrait_landmarks")
  expect_equal(length(unique(rep_fish$metadata$individual)), 25)
  expect_true(all(table(rep_fish$metadata$individual) >= 9))
})

test_that("load_t26_saudrune_landmarks() can restrict to a subset of species", {
  sub <- load_t26_saudrune_landmarks(species = c("Gobio occitaniae", "Squalius cephalus"))
  expect_true(all(sub$metadata$species %in% c("Gobio occitaniae", "Squalius cephalus")))
  expect_lt(dim(sub$coords)[3], dim(load_t26_saudrune_landmarks()$coords)[3])
})
