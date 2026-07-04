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

test_that("load_t26_saudrune_landmarks()'s `operator` argument builds separate, non-overlapping functional spaces", {
  fish_all <- load_t26_saudrune_landmarks()
  fish_op1 <- load_t26_saudrune_landmarks(operator = "Operator_1")
  fish_op2 <- load_t26_saudrune_landmarks(operator = "Operator_2")

  expect_true(all(fish_op1$metadata$operator == "Operator_1"))
  expect_true(all(fish_op2$metadata$operator == "Operator_2"))
  # each fish was digitized once by each operator: filtering to one operator
  # halves the number of specimens, and every fish appears exactly once
  expect_equal(dim(fish_op1$coords)[3], dim(fish_all$coords)[3] / 2)
  expect_equal(dim(fish_op2$coords)[3], dim(fish_all$coords)[3] / 2)
  expect_equal(length(unique(fish_op1$metadata$individual)), dim(fish_op1$coords)[3])
  expect_setequal(fish_op1$metadata$individual, fish_op2$metadata$individual)

  # downstream functions run unaffected on either single-operator subset
  ratios_op1 <- fishmorph_ratios(fishmorph_segments(fish_op1))
  ratios_op2 <- fishmorph_ratios(fishmorph_segments(fish_op2))
  expect_equal(nrow(ratios_op1), dim(fish_op1$coords)[3])
  expect_equal(nrow(ratios_op2), dim(fish_op2$coords)[3])

  # modular: `source = "repeatability"` has a single (anonymised) operator,
  # so requesting it explicitly is a no-op, not an error
  rep_all <- load_t26_saudrune_landmarks(source = "repeatability")
  rep_op2 <- load_t26_saudrune_landmarks(source = "repeatability", operator = "Operator_2")
  expect_equal(dim(rep_op2$coords)[3], dim(rep_all$coords)[3])

  # an operator with no digitizations in this source is an informative error
  expect_error(
    load_t26_saudrune_landmarks(source = "repeatability", operator = "Operator_1"),
    "does not match"
  )
})
