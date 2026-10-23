# The DuckDB database of the FISHMORPH digitization (moved from Rfishmorph in
# intraitR 1.44.0). The schema and the journal must share ONE status
# vocabulary: they drifted apart once in Rfishmorph, and a single point with a
# status the CHECK did not list aborted the whole build.

fm_journal_stub <- function(statuses = union(intraitR:::.INTRAITR_JOURNAL_STATUS,
                                             "imported"), n = 25L) {
  statuses <- rep_len(statuses, n)
  data.frame(
    record_id = "rec1", timestamp = "2026-07-31T10:00:00.000Z", operator = "AT",
    app_version = "test", mode = "reconstruct", target_sheet = "Global_Landmark",
    row_key = "Genus.species", species = "Genus species",
    photo_file = "Genus_species.jpg", img_w = 1000, img_h = 500, ruler_mm = 10,
    mm_per_px = 0.1, landmark = seq_len(n),
    x = seq(100, by = 10, length.out = n), y = seq(200, by = 10, length.out = n),
    status = statuses, stringsAsFactors = FALSE)
}

test_that("the schema accepts every status the journal can write", {
  skip_if_not_installed("DBI"); skip_if_not_installed("duckdb")
  res <- fishmorph_build_db(fm_journal_stub(), db_path = NULL, validate = FALSE)
  expect_equal(res$n_points, 25L)
})

test_that("statuses survive the round trip, and the QC view counts them all", {
  skip_if_not_installed("DBI"); skip_if_not_installed("duckdb")
  db <- tempfile(fileext = ".duckdb"); on.exit(unlink(db), add = TRUE)
  fishmorph_build_db(fm_journal_stub(), db_path = db, validate = FALSE)
  con <- fishmorph_db_connect(db)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  st <- DBI::dbGetQuery(con, "SELECT status FROM landmark_obs")$status
  expect_true(all(st %in% union(intraitR:::.INTRAITR_JOURNAL_STATUS, "imported")))
  qc <- DBI::dbGetQuery(con, "SELECT * FROM v_specimen_qc")
  expect_true(all(c("n_clicked", "n_placed", "n_adjusted") %in% names(qc)))
  expect_equal(qc$n_placed, qc$n_clicked)          # alias kept for old queries
  w <- DBI::dbGetQuery(con, "SELECT * FROM v_landmarks_wide")
  expect_equal(w$`3_X`, 120)
})

test_that("a status outside the vocabulary is degraded, not fatal", {
  skip_if_not_installed("DBI"); skip_if_not_installed("duckdb")
  J <- fm_journal_stub(c("clicked", "not_a_status"))
  expect_warning(res <- fishmorph_build_db(J, db_path = NULL, validate = FALSE),
                 "unknown status")
  expect_equal(res$n_points, 25L)
})

test_that("the database is built from journals of the old Rfishmorph digitizer", {
  skip_if_not_installed("DBI"); skip_if_not_installed("duckdb")
  d <- file.path(tempdir(), paste0("fmdb_", paste(sample(letters, 6), collapse = "")))
  dir.create(d); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  hdr <- c("record_id", "timestamp", "operator", "app_version", "mode",
           "target_sheet", "row_key", "species", "photo_file", "img_w", "img_h",
           "ruler_mm", "mm_per_px", "quality_score", "reviewed", "collapse",
           "landmark", "x", "y", "status")
  rows <- t(vapply(1:25, function(p) c(
    "AT_20260801T101010Z-00001", "2026-08-01T10:10:11.000Z", "AT", "0.10.0",
    "correct", "Global_Landmark", "Abramis.brama", "Abramis brama",
    "Abramis_brama.jpg", "1000", "500", "", "", "5", "TRUE", "",
    as.character(p), as.character(100 + 10 * p), as.character(200 + 5 * p),
    if (p %in% c(8, 9, 11, 23)) "derived" else "placed"), character(20)))
  writeLines(c(paste(hdr, collapse = "\t"), apply(rows, 1, paste, collapse = "\t")),
             file.path(d, "landmarks_AT_20260801T101010Z.tsv"))
  res <- fishmorph_build_db(d, db_path = NULL, validate = TRUE)
  expect_equal(res$n_specimens, 1L)
  expect_equal(res$n_points, 25L)
  expect_s3_class(res$issues, "data.frame")
})
