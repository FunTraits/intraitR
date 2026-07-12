test_that("load_t26_saudrune() reads all four bundled tables with the expected shape", {
  ops <- load_t26_saudrune("operators")
  expect_s3_class(ops, "data.frame")
  expect_true(all(c("specimen", "code", "operator", "landmark", "X", "Y") %in% names(ops)))
  expect_equal(length(unique(ops$landmark)), 21)
  expect_equal(length(unique(ops$operator)), 4)

  rep_df <- load_t26_saudrune("repeatability")
  expect_s3_class(rep_df, "data.frame")
  expect_true(all(c("specimen", "code", "replicate", "landmark", "X", "Y") %in% names(rep_df)))
  rep_counts <- table(unique(rep_df[c("code", "replicate")])$code)
  expect_true(all(rep_counts >= 2))

  ident <- load_t26_saudrune("identifications")
  expect_s3_class(ident, "data.frame")
  expect_true(all(c("code", "species", "id_status") %in% names(ident)))
  expect_true(all(ident$id_status %in% c("curated", "preliminary", "unresolved")))

  qc <- load_t26_saudrune("qc_log")
  expect_s3_class(qc, "data.frame")
  expect_true(all(c("code", "reason") %in% names(qc)))
})

test_that("load_t26_saudrune() validates its `dataset` argument", {
  expect_error(load_t26_saudrune("not_a_dataset"))
})

test_that("load_t26_saudrune() operator identities are anonymised", {
  ops <- load_t26_saudrune("operators")
  rep_df <- load_t26_saudrune("repeatability")
  expect_setequal(unique(ops$operator),
                  c("Operator_1", "Operator_2", "Operator_3", "Operator_4"))
  expect_true(all(grepl("^Operator_[0-9]+$", unique(rep_df$operator))))
  # the real names must not survive anywhere in the shipped tables
  all_text <- c(unlist(ops, use.names = FALSE), unlist(rep_df, use.names = FALSE))
  expect_false(any(grepl("breuil|rougean", all_text, ignore.case = TRUE)))
})

test_that("load_t26_saudrune()'s `operator` argument filters rows and is modular", {
  ops <- load_t26_saudrune("operators")
  op1 <- load_t26_saudrune("operators", operator = "Operator_1")
  expect_true(all(op1$operator == "Operator_1"))
  expect_lt(nrow(op1), nrow(ops))
  expect_equal(nrow(op1), sum(ops$operator == "Operator_1"))

  # case-insensitive matching
  op1_lower <- load_t26_saudrune("operators", operator = "operator_1")
  expect_equal(nrow(op1_lower), nrow(op1))

  # more than one operator can be requested at once
  both <- load_t26_saudrune("operators", operator = c("Operator_1", "Operator_2"))
  expect_equal(nrow(both), sum(ops$operator %in% c("Operator_1", "Operator_2")))

  # a table with no `operator` column (e.g. "identifications") ignores the
  # argument with a warning rather than erroring
  expect_warning(
    ident_filtered <- load_t26_saudrune("identifications", operator = "Operator_1"),
    "no `operator` column"
  )
  expect_equal(nrow(ident_filtered), nrow(load_t26_saudrune("identifications")))

  # an operator label that matches nothing is an informative error
  expect_error(load_t26_saudrune("operators", operator = "Operator_99"), "does not match")
})

test_that("load_t26_saudrune()'s `species` argument joins species identity by `code`", {
  ops <- load_t26_saudrune("operators")
  expect_false("species" %in% names(ops))

  ops_sp <- load_t26_saudrune("operators", species = TRUE)
  expect_true(all(c("species", "id_status") %in% names(ops_sp)))
  # the join must not reorder or duplicate rows: same row count, same `code`
  # sequence, as guaranteed by match()-based (not merge()-based) joining
  expect_equal(nrow(ops_sp), nrow(ops))
  expect_identical(ops_sp$code, ops$code)

  # every joined value must agree with a direct lookup in "identifications"
  ident <- load_t26_saudrune("identifications")
  idx <- match(ops_sp$code, ident$code)
  expect_identical(ops_sp$species, ident$species[idx])
  expect_identical(ops_sp$id_status, ident$id_status[idx])

  # same behaviour on "repeatability" (also long-format, many rows per code)
  rep_sp <- load_t26_saudrune("repeatability", species = TRUE)
  expect_true("species" %in% names(rep_sp))
  expect_equal(nrow(rep_sp), nrow(load_t26_saudrune("repeatability")))

  # default is unchanged (species = FALSE): no behaviour change for existing code
  expect_false("species" %in% names(load_t26_saudrune("repeatability")))

  # a no-op, without warning, on "identifications" itself (species already there)
  expect_no_warning(ident_sp <- load_t26_saudrune("identifications", species = TRUE))
  expect_identical(ident_sp, ident)

  # `operator` and `species` compose: filtering then joining still preserves order
  op1_sp <- load_t26_saudrune("operators", operator = "Operator_1", species = TRUE)
  expect_true(all(op1_sp$operator == "Operator_1"))
  expect_true("species" %in% names(op1_sp))
})

test_that("load_t26_saudrune()'s `species` argument is modular: no-op with a warning if `code` is absent", {
  # none of the four bundled tables lack `code`, so exercise the no-op path
  # directly against the internal helper on a synthetic table, mirroring how
  # .filter_by_operator()'s no-op path is tested for `operator`
  df <- data.frame(x = 1:3)
  expect_warning(
    out <- intraitR:::.join_species(df, dataset_label = "a synthetic table"),
    "no `code` column"
  )
  expect_identical(out, df)
})

test_that("the operators table can be imported with read_landmarks_csv() and passed to gpa_fish()", {
  ops <- load_t26_saudrune("operators")
  # restrict to a handful of specimens with a fully digitized (non-missing),
  # complete 21-landmark configuration for a fast smoke test
  ops_ok <- ops[!is.na(ops$X) & !is.na(ops$Y), ]
  complete_specimens <- names(which(table(ops_ok$specimen) == 21))
  sub <- ops[ops$specimen %in% complete_specimens[1:10], ]

  lm <- read_landmarks_csv(sub)
  expect_s3_class(lm, "intrait_landmarks")
  expect_equal(dim(lm$coords)[1], 21)
  expect_equal(dim(lm$coords)[3], 10)

  gpa <- gpa_fish(lm)
  expect_s3_class(gpa, "intrait_gpa")
  expect_equal(length(gpa$Csize), 10)
})
