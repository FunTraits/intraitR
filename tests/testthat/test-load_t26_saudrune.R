test_that("load_t26_saudrune() reads all four bundled tables with the expected shape", {
  ops <- load_t26_saudrune("operators")
  expect_s3_class(ops, "data.frame")
  expect_true(all(c("specimen", "code", "operator", "landmark", "X", "Y") %in% names(ops)))
  expect_equal(length(unique(ops$landmark)), 21)
  expect_equal(length(unique(ops$operator)), 2)

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
