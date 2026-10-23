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

## ---- merge of the two digitizers (1.40.0) -------------------------------------

# A journal exactly as Rfishmorph's digitizer wrote it (latest generation of
# its header: quality_score/reviewed/collapse INSERTED before `landmark`).
write_fm_journal <- function(d, name = "landmarks_AT_20260801T101010Z.tsv") {
  hdr <- c("record_id", "timestamp", "operator", "app_version", "mode",
           "target_sheet", "row_key", "species", "photo_file", "img_w", "img_h",
           "ruler_mm", "mm_per_px", "quality_score", "reviewed", "collapse",
           "landmark", "x", "y", "status")
  row <- function(rid, ts, key, lm, x, y, st, q = "5", rv = "TRUE", co = "Mo")
    c(rid, ts, "AT", "0.10.0", "correct", "Global_Landmark", key,
      sub("\\.", " ", key), paste0(key, ".jpg"), "800", "300", "", "", q, rv,
      co, lm, x, y, st)
  rows <- rbind(
    row("AT_20260801T101010Z-00001", "2026-08-01T10:10:11.000Z", "Abramis.brama",
        "1", "10", "20", "placed"),
    row("AT_20260801T101010Z-00001", "2026-08-01T10:10:11.000Z", "Abramis.brama",
        "2", "300", "22", "derived"),
    row("AT_20260801T101010Z-00002", "2026-08-01T10:12:00.000Z", "Abramis.brama",
        "1", "12", "20", "placed", rv = "FALSE"),
    row("AT_20260801T101010Z-00002", "2026-08-01T10:12:00.000Z", "Abramis.brama",
        "2", "301", "22", "na"))
  writeLines(c(paste(hdr, collapse = "\t"),
               apply(rows, 1, paste, collapse = "\t")),
             file.path(d, name))
}

test_that("journals written by Rfishmorph's digitizer are read and translated", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  write_fm_journal(d)
  j <- landmark_journal_read(d)
  expect_equal(nrow(j), 4L)
  expect_setequal(names(j), intraitR:::.INTRAITR_JOURNAL_COLS)
  expect_false("collapse" %in% names(j))
  expect_equal(j$status[1], "clicked")                 # "placed" translated
  expect_equal(j$quality_score, rep(5, 4))        # same scale: kept as is
  expect_equal(j$reviewed, c("yes", "yes", "no", "no"))
  expect_equal(j$collapse_rules, rep("Mo", 4))
  expect_equal(j$species[1], "Abramis brama")
  expect_equal(j$x[1], 10)
  # the file on disk is never rewritten
  expect_true(grepl("quality_score", readLines(list.files(d, full.names = TRUE))[1]))
})

test_that("both journal formats merge, and the last record per key wins", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  write_fm_journal(d)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  landmark_journal_append(jr, "fish_01", P2(), 1:2, specimen = "fish_01",
                          species = "Squalius cephalus")
  w <- consolidate_landmarks(d, points = 1:2)
  expect_equal(nrow(w), 2L)                            # Abramis.brama + fish_01
  ab <- w[w$species %in% "Abramis brama", ]
  expect_equal(ab$`1_X`, 12)                           # the correction
  expect_true(is.na(ab$`2_X`))                         # declared "na"
  expect_equal(ab$n_na, 1L)
  expect_equal(w$species[w$specimen %in% "fish_01"], "Squalius cephalus")

  ws <- consolidate_landmarks(d, points = 1:2, status_columns = TRUE)
  expect_true(all(c("1_status", "2_status") %in% names(ws)))
  expect_equal(ws$`2_status`[ws$species %in% "Abramis brama"], "na")

  lg <- consolidate_landmarks(d, long = TRUE)
  expect_equal(nrow(lg), 4L)                           # 2 kept records x 2 points
  expect_true(all(c("landmark", "x", "y", "status") %in% names(lg)))

  keep <- consolidate_landmarks(d, points = 1:2, drop_na_points = FALSE)
  expect_equal(keep$`2_X`[keep$species %in% "Abramis brama"], 301)
})

test_that("journal status, history and qc summarise the journals", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_null(suppressMessages(landmark_journal_status(file.path(d, "nope"))))
  write_fm_journal(d)
  st <- suppressMessages(landmark_journal_status(d))
  expect_equal(st$n_records, 2L)
  expect_equal(st$n_points, 4L)

  h <- landmark_journal_history(d, "Abramis.brama")
  expect_equal(nrow(h), 2L)
  expect_equal(h$n_clicked, c(1L, 1L))
  expect_equal(h$n_na, c(0L, 1L))
  expect_equal(nrow(landmark_journal_history(d, "absent")), 0L)

  q <- landmark_journal_qc(d, expect = 1:3)
  expect_equal(q$row_key, "Abramis.brama")
  expect_equal(q$missing, "3")
  expect_equal(q$n_na, 1L)
  expect_false(q$has_scale)
})

test_that("consolidate_landmarks() accepts a journal already read", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  write_fm_journal(d)
  j <- landmark_journal_read(d)
  expect_identical(consolidate_landmarks(j, points = 1:2),
                   consolidate_landmarks(d, points = 1:2))
})

test_that("an old intraitR `quality` (1 = very good) becomes quality_score = 6 - q", {
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  hdr <- c("record_id", "timestamp", "operator", "app_version", "mode",
           "target_sheet", "row_key", "specimen", "individual", "replicate",
           "photo_file", "img_w", "img_h", "quality", "ruler_mm", "mm_per_px",
           "landmark", "x", "y", "status")
  rows <- rbind(
    c("AT_20260601T080000Z-00001", "2026-06-01T08:00:01.000Z", "AT", "1.30.0",
      "new", "measurements", "f1", "f1", "f1", "1", "f1.jpg", "800", "300",
      "1", "", "", "1", "10", "20", "clicked"),
    c("AT_20260601T080000Z-00002", "2026-06-01T08:01:01.000Z", "AT", "1.30.0",
      "new", "measurements", "f2", "f2", "f2", "1", "f2.jpg", "800", "300",
      "", "", "", "1", "11", "21", "clicked"))
  writeLines(c(paste(hdr, collapse = "\t"), apply(rows, 1, paste, collapse = "\t")),
             file.path(d, "landmarks_AT_20260601T080000Z.tsv"))
  j <- landmark_journal_read(d)
  expect_false("quality" %in% names(j))
  expect_equal(j$quality_score, c(5, NA))
  w <- consolidate_landmarks(d, points = 1)
  expect_equal(w$quality_score[w$specimen == "f1"], 5)
})

test_that("the campaign workbook layout converts an old `quality` column", {
  old <- data.frame(specimen = c("a", "b"), quality = c(1, 4), `1_X` = c(1, 2),
                    check.names = FALSE)
  w <- intraitR:::wb_normalise(old)
  expect_false("quality" %in% names(w))
  expect_equal(w$quality_score, c(5, 2))
  expect_equal(w$`1_X`, c(1, 2))
})

test_that("write_xlsx_atomic() refuses to destroy sheets it does not write", {
  skip_if_not_installed("writexl")
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "ref.xlsx")
  writexl::write_xlsx(list(Global_segments = data.frame(a = 1),
                           Global_Landmark = data.frame(b = 2)), f)
  expect_equal(intraitR:::.xlsx_sheet_names(f), c("Global_segments", "Global_Landmark"))
  before <- tools::md5sum(f)
  expect_error(write_xlsx_atomic(list(measurements = data.frame(x = 1)), f),
               "DESTROY")
  expect_identical(tools::md5sum(f), before)          # untouched
  expect_false(file.exists(sub("\\.xlsx$", ".prev.xlsx", f)))
  # same sheets (or a superset) is the normal rewrite
  write_xlsx_atomic(list(Global_segments = data.frame(a = 3),
                         Global_Landmark = data.frame(b = 4)), f)
  # and an explicit drop is still possible
  write_xlsx_atomic(list(measurements = data.frame(x = 1)), f, drop_sheets = TRUE)
  expect_equal(intraitR:::.xlsx_sheet_names(f), "measurements")
})

test_that("digitize_landmarks() refuses a workbook that is not a campaign workbook", {
  skip_if_not_installed("writexl")
  for (pkg in c("shiny", "jpeg", "png")) skip_if_not_installed(pkg)
  d <- tmp_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  ph <- file.path(d, "photos"); dir.create(ph)
  writeBin(as.raw(c(0xFF, 0xD8)), file.path(ph, "a.jpg"))
  f <- file.path(d, "FISHMORPH_PUBLI_x_reconstructed.xlsx")
  writexl::write_xlsx(list(Global_segments = data.frame(a = 1),
                           Global_Landmark = data.frame(b = 2)), f)
  expect_error(suppressMessages(digitize_landmarks(ph, xlsx_path = f)),
               "digitize_fishmorph_reference")
})
