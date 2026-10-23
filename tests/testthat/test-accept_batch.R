## accept_batch_landmarks(): the predictions of a pre-pass recorded without
## review -- and recorded AS unreviewed.

fake_batch <- function(d) {
  dir.create(file.path(d, "photos"), recursive = TRUE)
  dir.create(file.path(d, "batch"))
  ph <- file.path(d, "photos", c("fish_01.jpg", "fish_02.jpg", "fish_03.jpg", "plate_04.jpg"))
  for (f in ph) writeBin(as.raw(c(0xFF, 0xD8, 0xFF, 0xD9)), f)
  S <- data.frame(photo = ph[c(1, 2, 3, 4, 4)], individual = c(1, 1, 1, 1, 2),
                  ruler = TRUE, width = 800, height = 400,
                  flags = c("", "", "dorsal", "", ""), risk = c(0, 0, 3, 0, 0))
  utils::write.csv(S, file.path(d, "batch", "summary.csv"), row.names = FALSE)
  P <- empty_coords(); P[1, ] <- c(40, 200); P[2, ] <- c(700, 200)
  P <- seed_configuration(P)
  P[20, ] <- c(50, 380); P[21, ] <- c(150, 380)
  pts <- c(1:19, 20, 21)
  L <- do.call(rbind, lapply(ph[1:3], function(f)
    data.frame(photo = f, individual = 1, landmark = pts,
               X = P[pts, 1], Y = P[pts, 2], conf = 0.9)))
  utils::write.csv(L, file.path(d, "batch", "landmarks_long.csv"), row.names = FALSE)
  list(batch = file.path(d, "batch"), journal = file.path(d, "journal"), photos = ph)
}

test_that("unflagged photographs are recorded, every point still 'predicted'", {
  d <- tempfile("acc"); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  b <- fake_batch(d)
  r <- suppressMessages(accept_batch_landmarks(b$batch, b$journal, operator = "AT"))
  expect_equal(r$status[r$code == "fish_01"], "accepted")
  expect_equal(r$status[r$code == "fish_03"], "flagged")       # left for a person
  expect_equal(r$status[r$code == "plate_04"], "plate")
  j <- landmark_journal_read(b$journal)
  expect_setequal(unique(j$specimen), c("fish_01", "fish_02"))
  expect_false(any(j$status %in% c("clicked", "validated")))   # nobody looked
  expect_true(all(j$status %in% c("predicted", "derived", "na")))   # absent points: na
  expect_true(all(j$reviewed == "no"))
  expect_true(all(grepl("not reviewed", j$app_version)))
  expect_equal(unique(j$mm_per_px[j$specimen == "fish_01"]), 10 / 100)
})

test_that("a measured photograph is never overwritten, and dry_run writes nothing", {
  d <- tempfile("acc"); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  b <- fake_batch(d)
  r0 <- suppressMessages(accept_batch_landmarks(b$batch, b$journal, operator = "AT",
                                                dry_run = TRUE))
  expect_equal(sum(r0$status == "dry-run"), 2L)
  expect_false(dir.exists(b$journal) && length(list.files(b$journal)))
  suppressMessages(accept_batch_landmarks(b$batch, b$journal, operator = "AT",
                                          photos = "fish_01"))
  r <- suppressMessages(accept_batch_landmarks(b$batch, b$journal, operator = "AT",
                                               include_flagged = TRUE))
  expect_equal(r$status[r$code == "fish_01"], "already measured")
  expect_equal(r$status[r$code == "fish_03"], "accepted")      # asked for
  j <- landmark_journal_read(b$journal)
  expect_equal(length(unique(j$record_id[j$specimen == "fish_01"])), 1L)
})

test_that("the workbook is updated without losing its other sheets or its schema", {
  testthat::skip_if_not_installed("writexl"); testthat::skip_if_not_installed("readxl")
  d <- tempfile("acc"); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  b <- fake_batch(d)
  wb <- file.path(d, "landmarks.xlsx")
  suppressMessages(accept_batch_landmarks(b$batch, b$journal, operator = "AT",
                                          photos = "fish_01", xlsx_path = wb))
  m1 <- readxl::read_excel(wb, "measurements")
  # a sheet only the workbook holds, and a column order of its own
  write_xlsx_atomic(list(measurements = m1[, rev(names(m1))],
                         bias_summary = data.frame(note = "kept")), wb, drop_sheets = TRUE)
  suppressMessages(accept_batch_landmarks(b$batch, b$journal, operator = "AT", xlsx_path = wb))
  expect_setequal(readxl::excel_sheets(wb), c("measurements", "bias_summary"))
  m2 <- readxl::read_excel(wb, "measurements")
  expect_equal(names(m2), rev(names(m1)))
  expect_setequal(m2$specimen, c("fish_01", "fish_02"))
  expect_equal(readxl::read_excel(wb, "bias_summary")$note, "kept")
})
