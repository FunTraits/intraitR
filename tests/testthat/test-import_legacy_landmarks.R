# A minimal "earlier digitization": three specimens, two operators each, in the
# wide x_i / y_i layout of the T-26 pilot workbook. The coordinates are chosen so
# that every consensus is verifiable by hand: for each specimen the two operators
# straddle the value the median must return.
legacy_table <- function() {
  data.frame(
    Code     = rep(c("F-01", "F-02", "F-03"), each = 2),
    operator = rep(c("op1", "op2"), times = 3),
    x_1 = c(10, 20, 100, 110, 200, 210), y_1 = c(5, 15, 5, 15, 5, 15),
    x_2 = c(90, 100, 180, 190, 280, 290), y_2 = c(5, 15, 5, 15, 5, 15),
    x_3 = c(50, 60, 140, 150, 240, 250), y_3 = c(30, 40, 30, 40, 30, 40),
    stringsAsFactors = FALSE
  )
}

# The tests that touch a real workbook need the two spreadsheet backends; the
# consensus tests run on a data.frame and need neither.
skip_no_xlsx <- function() {
  testthat::skip_if_not_installed("readxl")
  testthat::skip_if_not_installed("writexl")
}

# A workbook already holding one of those specimens, digitized by the app.
seed_workbook <- function(path, specimens = "F-02") {
  d <- intraitR:::.ilm_blank(length(specimens))
  d$specimen <- specimens
  d$individual <- specimens
  d$replicate <- 1
  d$operator <- "app_operator"
  d$mode <- "new"
  d[["1_X"]] <- 1; d[["1_Y"]] <- 1
  write_xlsx_atomic(list(measurements = d), path)
  path
}

test_that("the consensus over operators is the coordinate-wise median", {
  add <- import_legacy_landmarks(legacy_table(), file.path(tempdir(), "none.xlsx"),
                                 points = 1:3, dry_run = TRUE)
  expect_equal(nrow(add), 3L)
  expect_equal(add$specimen, c("F-01", "F-02", "F-03"))
  # median of (10, 20) = 15, of (90, 100) = 95, and so on
  expect_equal(add[["1_X"]], c(15, 105, 205))
  expect_equal(add[["2_X"]], c(95, 185, 285))
  expect_equal(add[["1_Y"]], c(10, 10, 10))
  expect_equal(add[["3_X"]], c(55, 145, 245))
})

test_that("mean and first give the centroid and one operator's own clicks", {
  m <- import_legacy_landmarks(legacy_table(), file.path(tempdir(), "none.xlsx"),
                               points = 1:3, consensus = "mean", dry_run = TRUE)
  expect_equal(m[["1_X"]], c(15, 105, 205))          # two rows: mean = median
  f <- import_legacy_landmarks(legacy_table(), file.path(tempdir(), "none.xlsx"),
                               points = 1:3, consensus = "first", dry_run = TRUE)
  expect_equal(f[["1_X"]], c(10, 100, 200))          # op1, untouched
  k <- import_legacy_landmarks(legacy_table(), file.path(tempdir(), "none.xlsx"),
                               points = 1:3, operator_keep = "op2", dry_run = TRUE)
  expect_equal(k[["1_X"]], c(20, 110, 210))
  expect_true(all(grepl("_n1$", k$operator)))
})

test_that("specimens already in the workbook are never overwritten", {
  skip_no_xlsx()
  wb <- seed_workbook(file.path(tempdir(), "wb_keep.xlsx"))
  add <- import_legacy_landmarks(legacy_table(), wb, points = 1:3)
  expect_equal(sort(add$specimen), c("F-01", "F-03"))   # F-02 left alone

  back <- as.data.frame(readxl::read_excel(wb, sheet = "measurements"))
  expect_equal(nrow(back), 3L)
  kept <- back[back$specimen == "F-02", ]
  expect_equal(kept$operator, "app_operator")           # the app's row survived
  expect_equal(kept[["1_X"]], 1)
})

test_that("a second call imports nothing (idempotence)", {
  skip_no_xlsx()
  wb <- file.path(tempdir(), "wb_idem.xlsx")
  unlink(wb)
  first <- import_legacy_landmarks(legacy_table(), wb, points = 1:3)
  expect_equal(nrow(first), 3L)
  second <- import_legacy_landmarks(legacy_table(), wb, points = 1:3)
  expect_equal(nrow(second), 0L)
  back <- as.data.frame(readxl::read_excel(wb, sheet = "measurements"))
  expect_equal(nrow(back), 3L)
})

test_that("overwrite = TRUE replaces the app's rows, and says so by its result", {
  skip_no_xlsx()
  wb <- seed_workbook(file.path(tempdir(), "wb_over.xlsx"))
  add <- import_legacy_landmarks(legacy_table(), wb, points = 1:3, overwrite = TRUE)
  expect_equal(nrow(add), 3L)
  back <- as.data.frame(readxl::read_excel(wb, sheet = "measurements"))
  expect_equal(nrow(back), 3L)
  expect_false(any(back$operator == "app_operator"))
})

test_that("the imported rows carry their provenance and their counts", {
  add <- import_legacy_landmarks(legacy_table(), file.path(tempdir(), "none.xlsx"),
                                 points = 1:3, label = "T26", dry_run = TRUE)
  expect_true(all(grepl("^imported\\(", add$mode)))
  expect_true(all(add$operator == "T26_n2"))
  expect_true(all(grepl("^import_legacy_landmarks/", add$app_version)))
  expect_equal(add$n_clicked, rep(3, 3))
  expect_equal(add$n_na, rep(0, 3))
  expect_equal(add$n_seeded, rep(0, 3))
})

test_that("landmarks absent from the source stay NA, and the schema is complete", {
  add <- import_legacy_landmarks(legacy_table(), file.path(tempdir(), "none.xlsx"),
                                 points = 1:25, dry_run = TRUE)
  expect_true(all(is.na(add[["22_X"]])))
  expect_true(all(is.na(add[["23_X"]])))        # derived by the app, not here
  expect_equal(add$n_clicked, rep(3, 3))
  expect_equal(add$n_na, rep(22, 3))
  expect_true(all(c("1_X", "25_Y", "app_version") %in% names(add)))
  expect_equal(ncol(add), 18L + 50L)             # same schema as the app's sheet
})

test_that("the {i} template reads the app's own layout too", {
  d <- legacy_table()
  names(d) <- sub("^x_([0-9]+)$", "\\1_X", names(d))
  names(d) <- sub("^y_([0-9]+)$", "\\1_Y", names(d))
  add <- import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                                 x_pattern = "{i}_X", y_pattern = "{i}_Y",
                                 points = 1:3, dry_run = TRUE)
  expect_equal(add[["1_X"]], c(15, 105, 205))
})

test_that("mm_per_px is computed from the calibration bar when ruler_mm is given", {
  d <- legacy_table()
  d$x_20 <- 0; d$y_20 <- 0; d$x_21 <- c(20, 20, 40, 40, 50, 50); d$y_21 <- 0
  add <- import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                                 points = c(1:3, 20:21), ruler_mm = 10,
                                 dry_run = TRUE)
  expect_equal(add$mm_per_px, 10 / c(20, 40, 50))
  expect_equal(add$ruler_mm, rep(10, 3))
})

test_that("digitizations that are not in one frame are reported", {
  d <- legacy_table()
  d$x_2[2] <- 900                     # op2 measures F-01 four times too long
  expect_warning(
    import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                            points = 1:3, dry_run = TRUE),
    "standard length")
})

test_that("a missing identifier column or unreadable coordinates error early", {
  d <- legacy_table()
  expect_error(import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                                       id_from = "specimen", dry_run = TRUE),
               "not found in `from`")
  expect_error(import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                                       x_pattern = "X{i}", y_pattern = "Y{i}",
                                       dry_run = TRUE),
               "None of the coordinate columns")
  expect_error(import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                                       x_pattern = "x_1", dry_run = TRUE),
               "\\{i\\}")
})

test_that("the other sheets of the workbook are carried over untouched", {
  skip_no_xlsx()
  wb <- file.path(tempdir(), "wb_sheets.xlsx")
  unlink(wb)
  extra <- data.frame(individual = "F-02", landmark = 1, n_replicates = 2,
                      stringsAsFactors = FALSE)
  write_xlsx_atomic(list(measurements = intraitR:::.ilm_blank(0),
                         bias_summary = extra), wb)
  import_legacy_landmarks(legacy_table(), wb, points = 1:3)
  expect_true("bias_summary" %in% readxl::excel_sheets(wb))
  back <- as.data.frame(readxl::read_excel(wb, sheet = "bias_summary"))
  expect_equal(back$individual, "F-02")
})

test_that("a single specimen imports (the length-1 corner case)", {
  d <- legacy_table()[1:2, ]
  add <- import_legacy_landmarks(d, file.path(tempdir(), "none.xlsx"),
                                 points = 1:3, dry_run = TRUE)
  expect_equal(nrow(add), 1L)
  expect_equal(add[["1_X"]], 15)
  expect_equal(add$n_clicked, 3)
})

test_that("the journal receives the imported specimens when asked", {
  skip_no_xlsx()
  wb <- file.path(tempdir(), "wb_journal.xlsx"); unlink(wb)
  jd <- file.path(tempdir(), "journal_import"); unlink(jd, recursive = TRUE)
  import_legacy_landmarks(legacy_table(), wb, points = 1:3, journal_dir = jd)
  j <- landmark_journal_read(jd)
  expect_equal(length(unique(j$specimen)), 3L)
  expect_true(all(j$status[j$landmark %in% as.character(1:3)] == "imported"))
})
