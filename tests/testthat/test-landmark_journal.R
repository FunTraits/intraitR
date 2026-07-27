# The journal is the capture layer behind digitize_landmarks(): append-only,
# one line per landmark, never rewritten. These tests exercise the three
# properties the design rests on -- that a record survives, that a crash costs
# at most the last line, and that the analysable table can be rebuilt from
# nothing but the journals.

tmp_dir <- function(prefix = "journal") {
  d <- file.path(tempdir(), paste0(prefix, "_",
                                   paste(sample(letters, 8), collapse = "")))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}
P2 <- function(x1 = 10, y1 = 20) rbind(c(x1, y1), c(110, 22))

test_that("opening a journal creates one session file with the header", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT",
                                               app_version = "1.16.0"))
  expect_s3_class(jr, "intrait_journal")
  expect_true(file.exists(jr$path))
  expect_match(basename(jr$path), "^landmarks_AT_.*\\.tsv$")
  hdr <- strsplit(readLines(jr$path)[1], "\t")[[1]]
  expect_identical(hdr, intraitR:::.INTRAITR_JOURNAL_COLS)
  # the operator is sanitised into the file name, never trusted as typed
  jr2 <- suppressMessages(landmark_journal_open(d, operator = "A T/1"))
  expect_match(basename(jr2$path), "^landmarks_A_T_1_")
  # a missing directory is created rather than refused
  d2 <- file.path(d, "nested", "deeper")
  expect_true(file.exists(suppressMessages(landmark_journal_open(d2))$path))
})

test_that("a record is one line per landmark, sharing a record_id", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  rid <- landmark_journal_append(jr, "fish_01", P2(), 1:2, specimen = "fish_01",
                                 individual = "fish_01", replicate = 1L,
                                 target_sheet = "measurements")
  j <- landmark_journal_read(d)
  expect_equal(nrow(j), 2L)
  expect_identical(unique(j$record_id), rid)
  expect_identical(j$specimen, rep("fish_01", 2))
  expect_equal(j$landmark, c(1, 2))
  expect_equal(j$x, c(10, 110))
  expect_identical(j$operator, rep("AT", 2))
  expect_identical(j$status, rep("clicked", 2))
})

test_that("a point without a finite coordinate is recorded as na", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d))
  P <- rbind(c(10, 20), c(NA, NA))
  landmark_journal_append(jr, "fish_01", P, 1:2,
                          status = c("1" = "clicked", "2" = "seeded"))
  j <- landmark_journal_read(d)
  # "seeded" would claim the point sits somewhere; without a coordinate it does
  # not sit anywhere, and the status has to say so.
  expect_identical(j$status, c("clicked", "na"))
})

test_that("coordinates keep their decimals on a large photograph", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d))
  landmark_journal_append(jr, "fish_01", rbind(c(12345.678, 9876.543)), 1L)
  j <- landmark_journal_read(d)
  # format() would apply getOption("digits") and round this to 12345.68
  expect_equal(j$x, 12345.678)
  expect_equal(j$y, 9876.543)
})

test_that("a line truncated by a crash is dropped, not fatal", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  landmark_journal_append(jr, "fish_01", P2(), 1:2, specimen = "fish_01")
  cat("truncated-mid-write", file = jr$path, append = TRUE)   # no newline, no tabs
  j <- landmark_journal_read(d)
  expect_equal(nrow(j), 2L)
  expect_true(all(nzchar(j$record_id)))
})

test_that("journals of two sessions merge by concatenation", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  j1 <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  landmark_journal_append(j1, "fish_01", P2(), 1:2, specimen = "fish_01",
                          individual = "fish_01")
  j2 <- suppressMessages(landmark_journal_open(d, operator = "GH"))
  landmark_journal_append(j2, "fish_02", P2(12), 1:2, specimen = "fish_02",
                          individual = "fish_02")
  j <- landmark_journal_read(d)
  expect_equal(nrow(j), 4L)
  expect_setequal(unique(j$operator), c("AT", "GH"))
})

test_that("an empty or absent journal directory reads as an empty table", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  j <- landmark_journal_read(d)
  expect_equal(nrow(j), 0L)
  expect_identical(names(j), intraitR:::.INTRAITR_JOURNAL_COLS)
  expect_equal(nrow(landmark_journal_read(file.path(d, "nope"))), 0L)
})

test_that("consolidate_landmarks() rebuilds the wide table, last record winning", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  landmark_journal_append(jr, "fish_01", P2(10), 1:2, specimen = "fish_01",
                          individual = "fish_01", target_sheet = "measurements")
  Sys.sleep(0.01)                       # the timestamp orders the records
  landmark_journal_append(jr, "fish_01", P2(99), 1:2, specimen = "fish_01",
                          individual = "fish_01", target_sheet = "measurements")
  landmark_journal_append(jr, "fish_02", P2(50), 1:2, specimen = "fish_02",
                          individual = "fish_02", target_sheet = "measurements")

  out <- consolidate_landmarks(d, points = 1:2)
  expect_equal(nrow(out), 2L)                       # one row per specimen
  expect_equal(out[["1_X"]][out$specimen == "fish_01"], 99)  # the CORRECTION
  expect_true(all(c("specimen", "individual", "replicate", "1_X", "2_Y",
                    "n_clicked") %in% names(out)))
  expect_false("record_id" %in% names(out))

  # history = TRUE keeps both, which is what makes a correction auditable
  h <- consolidate_landmarks(d, points = 1:2, history = TRUE)
  expect_equal(nrow(h), 3L)
  expect_setequal(h[["1_X"]][h$specimen == "fish_01"], c(10, 99))
  expect_true(all(c("record_id", "timestamp") %in% names(h)))
})

test_that("consolidate_landmarks() lays out only the points asked for", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d))
  landmark_journal_append(jr, "fish_01", P2(), 1:2, specimen = "fish_01")
  out <- consolidate_landmarks(d, points = 1:3)
  expect_true(all(is.na(out[["3_X"]])))          # never digitized -> NA, not absent
  expect_equal(out[["1_X"]], 10)
  expect_equal(nrow(consolidate_landmarks(tmp_dir(), points = 1:3)), 0L)
})

test_that("consolidate_landmarks() splits the sheets and writes a workbook", {
  testthat::skip_if_not_installed("writexl")
  testthat::skip_if_not_installed("readxl")
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  landmark_journal_append(jr, "fish_01", P2(), 1:2, specimen = "fish_01",
                          individual = "fish_01", target_sheet = "measurements")
  landmark_journal_append(jr, "fish_01_AT_rep1", P2(11), 1:2,
                          specimen = "fish_01_AT_rep1", individual = "fish_01",
                          replicate = 1L, target_sheet = "bias")
  f <- file.path(d, "rebuilt.xlsx")
  suppressMessages(consolidate_landmarks(d, points = 1:2, xlsx_path = f))
  expect_true(file.exists(f))
  expect_setequal(readxl::excel_sheets(f), c("measurements", "bias"))
  expect_equal(nrow(readxl::read_excel(f, sheet = "bias")), 1L)
})

test_that("write_xlsx_atomic() keeps one generation and never half-writes", {
  testthat::skip_if_not_installed("writexl")
  testthat::skip_if_not_installed("readxl")
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "wb.xlsx")
  write_xlsx_atomic(list(measurements = data.frame(specimen = "a")), f)
  expect_true(file.exists(f))
  expect_false(file.exists(sub("\\.xlsx$", ".prev.xlsx", f)))   # nothing to keep yet

  write_xlsx_atomic(list(measurements = data.frame(specimen = "b")), f)
  prev <- sub("\\.xlsx$", ".prev.xlsx", f)
  expect_true(file.exists(prev))
  expect_equal(readxl::read_excel(f)$specimen, "b")
  expect_equal(readxl::read_excel(prev)$specimen, "a")   # one generation back

  # no temporary file is left behind
  expect_length(list.files(d, pattern = "^\\.wb", all.files = TRUE), 0L)

  write_xlsx_atomic(list(measurements = data.frame(specimen = "c")), f,
                    keep_prev = FALSE)
  expect_false(file.exists(prev))
})

test_that("append refuses anything that is not a journal handle", {
  expect_error(landmark_journal_append(list(path = "x"), "k", P2(), 1:2),
               "not a journal handle")
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d))
  # nothing to write is not an error: it is a specimen with no point in range
  expect_null(landmark_journal_append(jr, "k", P2(), integer(0)))
  expect_null(landmark_journal_append(jr, "k", P2(), 5:6))
  expect_equal(nrow(landmark_journal_read(d)), 0L)
})
