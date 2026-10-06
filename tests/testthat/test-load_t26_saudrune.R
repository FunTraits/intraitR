test_that("the landmark table is the default dataset and is rectangular", {
  lm <- load_t26_saudrune()
  expect_s3_class(lm, "data.frame")
  expect_true(all(c("specimen", "code", "operator", "landmark", "X", "Y") %in% names(lm)))
  expect_setequal(unique(lm$landmark), 1:25)
  # Rectangular: 25 rows per specimen, points a specimen does not carry present
  # as NA rather than as absent rows -- otherwise a specimen's landmark numbers
  # would depend on what happened to be measurable on it.
  expect_true(all(table(lm$specimen) == 25L))
  # one digitization per specimen in this table: specimen == code
  expect_identical(lm$specimen, lm$code)
  # the codes are the campaign's own immutable identifiers, never a species
  expect_true(all(grepl("^SAUDRUNESUDTOULOUSE_[0-9]{8}_[0-9]{4}(_i[0-9]+)?$", unique(lm$code))))
  # every specimen carries the anatomical landmarks 1 and 2 (the body axis)
  expect_false(anyNA(lm$X[lm$landmark %in% 1:2]))
})

test_that("the specimen table is one data set with the landmark table, split in two", {
  lm   <- load_t26_saudrune()
  spec <- load_t26_saudrune("specimens")
  expect_true(all(c("code", "uid", "individual", "species", "species_code", "date",
                    "operator", "quality", "n_landmarks", "photo_hash") %in% names(spec)))
  # Every digitized specimen is identified, and every identification has a
  # specimen: no slack in the join, which is what the 1.34.0 tables had lost.
  expect_setequal(unique(lm$code), spec$code)
  expect_equal(anyDuplicated(spec$code), 0L)
  expect_false(anyNA(spec$species))
  expect_false(any(spec$species == ""))
  # species codes are injective: one code per species, one species per code
  expect_equal(anyDuplicated(unique(spec[c("species", "species_code")])$species_code), 0L)
  # a plate individual shares its photograph (uid) with its plate-mates
  plates <- spec[spec$individual > 1, , drop = FALSE]
  expect_true(all(sub("_i[0-9]+$", "", plates$code) == plates$uid))
  # n_landmarks agrees with the coordinate table
  placed <- tapply(!is.na(lm$X), lm$code, sum)   # 1-d array: drop names and dim
  expect_equal(as.integer(placed[spec$code]), as.integer(spec$n_landmarks))
})

test_that("the repeat trial has several passes per individual and unique specimen ids", {
  rep_df <- load_t26_saudrune("repeatability")
  expect_true(all(c("specimen", "code", "operator", "replicate", "landmark", "X", "Y") %in%
                    names(rep_df)))
  expect_true(all(table(rep_df$specimen) == 25L))
  passes <- unique(rep_df[c("specimen", "code", "operator", "replicate")])
  expect_equal(anyDuplicated(passes$specimen), 0L)
  expect_equal(anyDuplicated(passes[c("code", "operator", "replicate")]), 0L)
  expect_true(all(table(passes$code) >= 2))
  # <code>_<operator>_rep<N>: the replicate is the last token, the operator
  # label holds no underscore
  expect_true(all(passes$specimen == paste0(passes$code, "_", passes$operator, "_rep",
                                            passes$replicate)))
  expect_false(any(grepl("_", passes$operator, fixed = TRUE)))
  # the repeated individuals are campaign specimens
  expect_true(all(passes$code %in% load_t26_saudrune("specimens")$code))
})

test_that("the qc log has the expected shape and excludes what it names", {
  qc <- load_t26_saudrune("qc_log")
  expect_s3_class(qc, "data.frame")
  expect_true(all(c("code", "reason") %in% names(qc)))
  expect_length(intersect(qc$code, load_t26_saudrune("specimens")$code), 0L)
})

test_that("load_t26_saudrune() validates its `dataset` argument and refuses the legacy names", {
  expect_error(load_t26_saudrune("not_a_dataset"))
  expect_error(load_t26_saudrune("operators"))
  expect_error(load_t26_saudrune("identifications"))
})

test_that("load_t26_saudrune()'s `operator` argument filters rows and is modular", {
  lm <- load_t26_saudrune()
  ops <- unique(lm$operator)
  expect_true(all(nzchar(ops)))
  one <- load_t26_saudrune(operator = ops[1])
  expect_true(all(one$operator == ops[1]))
  expect_equal(nrow(one), sum(lm$operator == ops[1]))

  # case-insensitive matching
  expect_equal(nrow(load_t26_saudrune(operator = tolower(ops[1]))), nrow(one))

  # a table with no `operator` column ignores the argument with a warning
  expect_warning(
    qc_filtered <- load_t26_saudrune("qc_log", operator = ops[1]),
    "no `operator` column"
  )
  expect_equal(nrow(qc_filtered), nrow(load_t26_saudrune("qc_log")))

  # an operator label that matches nothing is an informative error
  expect_error(load_t26_saudrune(operator = "Operator_99"), "does not match")
})

test_that("load_t26_saudrune()'s `species` argument joins species identity by `code`", {
  lm <- load_t26_saudrune()
  expect_false("species" %in% names(lm))

  lm_sp <- load_t26_saudrune(species = TRUE)
  expect_true(all(c("species", "species_code") %in% names(lm_sp)))
  # the join must not reorder or duplicate rows
  expect_equal(nrow(lm_sp), nrow(lm))
  expect_identical(lm_sp$code, lm$code)
  expect_false(anyNA(lm_sp$species))

  # every joined value agrees with a direct lookup in "specimens"
  spec <- load_t26_saudrune("specimens")
  idx <- match(lm_sp$code, spec$code)
  expect_identical(lm_sp$species, spec$species[idx])
  expect_identical(lm_sp$species_code, spec$species_code[idx])

  # same behaviour on "repeatability" (many rows per code)
  rep_sp <- load_t26_saudrune("repeatability", species = TRUE)
  expect_true("species" %in% names(rep_sp))
  expect_equal(nrow(rep_sp), nrow(load_t26_saudrune("repeatability")))
  expect_false(anyNA(rep_sp$species))

  # a no-op, without warning, on "specimens" itself
  expect_no_warning(spec_sp <- load_t26_saudrune("specimens", species = TRUE))
  expect_identical(spec_sp, spec)
})

test_that("load_t26_saudrune()'s `species` argument is modular: no-op with a warning if `code` is absent", {
  df <- data.frame(x = 1:3)
  expect_warning(
    out <- intraitR:::.join_species(df, dataset_label = "a synthetic table"),
    "no `code` column"
  )
  expect_identical(out, df)
})

test_that("the landmark table can be imported with read_landmarks_csv() and passed to gpa_fish()", {
  lm <- load_t26_saudrune()
  # anatomical landmarks only (1-19), on a handful of complete specimens
  sub <- lm[lm$landmark %in% 1:19, ]
  complete <- names(which(tapply(!is.na(sub$X), sub$specimen, all)))
  sub <- sub[sub$specimen %in% complete[1:10], ]

  obj <- read_landmarks_csv(sub)
  expect_s3_class(obj, "intrait_landmarks")
  expect_equal(dim(obj$coords)[1], 19)
  expect_equal(dim(obj$coords)[3], 10)

  gpa <- gpa_fish(obj)
  expect_s3_class(gpa, "intrait_gpa")
  expect_equal(length(gpa$Csize), 10)
})
