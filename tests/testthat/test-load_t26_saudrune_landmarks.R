test_that("the default source is the landmark table, on the 25-point scheme", {
  fish <- load_t26_saudrune_landmarks()

  expect_s3_class(fish, "intrait_landmarks")
  expect_true(all(c("coords", "scale", "metadata") %in% names(fish)))
  expect_null(fish$scale)
  expect_equal(dim(fish$coords)[1], 25)
  expect_equal(dim(fish$coords)[2], 2)
  expect_equal(dim(fish$coords)[3], nrow(fish$metadata))

  expect_true(all(c("specimen", "individual", "species", "population",
                    "replicate", "operator", "species_code") %in% names(fish$metadata)))
  expect_true(all(is.na(fish$metadata$population)))
  # one digitization per specimen: repeats live in the repeat trial
  expect_setequal(unique(fish$metadata$replicate), 1L)
  expect_identical(fish$metadata$individual, fish$metadata$specimen)
  expect_equal(length(unique(fish$metadata$specimen)), dim(fish$coords)[3])
  expect_false(anyNA(fish$metadata$species))
  expect_true(all(grepl("^SAUDRUNESUDTOULOUSE_", fish$metadata$specimen)))
  # metadata rows are aligned with the coordinate slices
  expect_identical(dimnames(fish$coords)[[3]], fish$metadata$specimen)
})

test_that("the body axis and the curvature point are present on every specimen", {
  fish <- load_t26_saudrune_landmarks()
  expect_false(anyNA(fish$coords[1:2, , ]))
  # LM22 is placed on the axis before anything anatomical, so a configuration
  # without it was never digitized by the app
  expect_false(anyNA(fish$coords[22, , ]))
  # LM23 is derived, so it exists wherever 1, 6 and 9 do
  ok <- !is.na(fish$coords[1, 1, ]) & !is.na(fish$coords[6, 1, ]) &
    !is.na(fish$coords[9, 1, ])
  expect_false(anyNA(fish$coords[23, , ok]))
})

test_that("load_t26_saudrune_landmarks() works as a drop-in for simulate_fishmorph_points() in the FISHMORPH pipeline", {
  fish <- load_t26_saudrune_landmarks()
  segments <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(segments)

  expect_s3_class(segments, "intrait_segments")
  expect_s3_class(ratios, "intrait_fishmorph")
  expect_true(all(c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt") %in% names(ratios)))
})

test_that("source = 'repeatability' returns the repeat trial, several passes per individual", {
  rep_fish <- load_t26_saudrune_landmarks("repeatability")
  expect_s3_class(rep_fish, "intrait_landmarks")
  expect_equal(dim(rep_fish$coords)[1], 25)
  expect_true(all(table(rep_fish$metadata$individual) >= 2))
  expect_true(all(rep_fish$metadata$replicate >= 1))
  expect_equal(anyDuplicated(rep_fish$metadata$specimen), 0L)
  expect_false(anyNA(rep_fish$metadata$species))
  # the repeated individuals are specimens of the main table
  expect_true(all(rep_fish$metadata$individual %in%
                    load_t26_saudrune_landmarks()$metadata$specimen))
  # ready for digitization_error(): one error table, scale bar excluded
  derr <- digitization_error(rep_fish, individual = rep_fish$metadata$individual,
                             exclude_landmarks = c(20, 21, 25))
  expect_true(is.list(derr))
})

test_that("load_t26_saudrune_landmarks() can restrict to a subset of species", {
  all_fish <- load_t26_saudrune_landmarks()
  two <- names(sort(table(all_fish$metadata$species), decreasing = TRUE))[1:2]
  sub <- load_t26_saudrune_landmarks(species = two)
  expect_true(all(sub$metadata$species %in% two))
  expect_lt(dim(sub$coords)[3], dim(all_fish$coords)[3])
})

test_that("load_t26_saudrune_landmarks()'s `operator` argument subsets and is validated", {
  fish_all <- load_t26_saudrune_landmarks()
  ops <- unique(fish_all$metadata$operator)
  one <- load_t26_saudrune_landmarks(operator = ops[1])
  expect_true(all(one$metadata$operator == ops[1]))
  expect_equal(dim(one$coords)[3], sum(fish_all$metadata$operator == ops[1]))

  expect_error(load_t26_saudrune_landmarks(operator = "Operator_99"), "does not match")
  expect_error(load_t26_saudrune_landmarks(source = "operators"))
})
