make_hub_dir <- function() {
  root <- file.path(tempdir(), paste0("hub_", paste(sample(letters, 6), collapse = "")))
  a <- file.path(root, "Gobio occitaniae"); b <- file.path(root, "Squalius cephalus", "2026")
  dir.create(a, recursive = TRUE); dir.create(b, recursive = TRUE)
  for (f in file.path(a, c("GOBOCC_001.jpg", "GOBOCC_002.jpg"))) writeLines("x", f)
  writeLines("x", file.path(b, "SQUCEP_001.png"))
  writeLines("x", file.path(root, "loose.jpg"))
  writeLines("x", file.path(a, "notes.txt"))                    # not an image
  root
}

test_that("measure_queue() lists photographs with their folder levels", {
  root <- make_hub_dir(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  q <- measure_queue(root)
  expect_identical(sort(q$code), c("GOBOCC_001", "GOBOCC_002", "SQUCEP_001", "loose"))
  expect_identical(q$folder[q$code == "SQUCEP_001"], "Squalius cephalus")
  expect_identical(q$subfolder[q$code == "SQUCEP_001"], "2026")
  expect_identical(q$folder[q$code == "loose"], "")
  expect_true(all(file.exists(q$path)))
  expect_false(any(q$measured))
  expect_true(all(is.na(q$species)))
})

test_that("species come from the folder or from a table", {
  root <- make_hub_dir(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  q <- measure_queue(root, species = "folder")
  expect_identical(q$species[q$code == "GOBOCC_001"], "Gobio occitaniae")
  expect_identical(q$species[q$code == "SQUCEP_001"], "2026")     # immediate folder
  expect_true(is.na(q$species[q$code == "loose"]))
  tab <- data.frame(photo = c("GOBOCC_001.jpg", "SQUCEP_001"),
                    species = c("Gobio occitaniae", "Squalius cephalus"))
  q <- measure_queue(root, species = tab)
  expect_identical(q$species[q$code == "SQUCEP_001"], "Squalius cephalus")
  expect_true(is.na(q$species[q$code == "GOBOCC_002"]))
  f <- tempfile(fileext = ".csv"); utils::write.csv(tab, f, row.names = FALSE)
  expect_identical(measure_queue(root, species = f)$species, q$species)
  expect_error(measure_queue(root, species = data.frame(a = 1)), "column `species`")
  # a named vector code -> species (what launch_measure_hub() hands on)
  v <- c(GOBOCC_002 = "Gobio occitaniae")
  expect_identical(measure_queue(root, species = v)$species[
    measure_queue(root)$code == "GOBOCC_002"], "Gobio occitaniae")
})

test_that("excluded folders are left out", {
  root <- make_hub_dir(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  ex <- file.path(root, "batch", "qc"); dir.create(ex, recursive = TRUE)
  writeLines("x", file.path(ex, "GOBOCC_001.jpg"))
  expect_identical(nrow(measure_queue(root)), 5L)
  expect_identical(nrow(measure_queue(root, exclude = file.path(root, "batch"))), 4L)
})

test_that("the measured state is read from the journal", {
  root <- make_hub_dir(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  jd <- file.path(tempdir(), paste0("j_", basename(root)))
  on.exit(unlink(jd, recursive = TRUE), add = TRUE)
  jr <- landmark_journal_open(jd, operator = "AT")
  landmark_journal_append(jr, "GOBOCC_002", cbind(c(10, 200), c(50, 60)), 1:2,
                          specimen = "GOBOCC_002", photo_file = "GOBOCC_002.jpg",
                          target_sheet = "measurements")
  q <- measure_queue(root, journal_dir = jd)
  expect_identical(q$code[q$measured], "GOBOCC_002")
  expect_identical(q$n_records[q$code == "GOBOCC_002"], 1L)
  expect_identical(q$operator[q$code == "GOBOCC_002"], "AT")
  expect_true(q$n_missing[q$code == "GOBOCC_002"] > 0)
})

test_that("launch_measure_hub() checks its arguments before launching", {
  testthat::skip_if_not(all(vapply(c("shiny", "bslib", "DT", "callr", "httpuv", "jpeg",
                                     "png", "writexl", "readxl"),
                                   requireNamespace, logical(1), quietly = TRUE)))
  root <- make_hub_dir(); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_error(launch_measure_hub(file.path(root, "nope")), "existing folder")
  expect_error(launch_measure_hub(root, xlsx_path = "a.csv"), "must end in")
  expect_error(launch_measure_hub(root, ruler_mm = 0), "positive number")
  expect_error(launch_measure_hub(root, traits_fun = 1), "must be a function")
  expect_error(launch_measure_hub(root, species = data.frame(a = 1)), "column `species`")
})

test_that("the hub app is shipped", {
  f <- system.file("shiny", "measure_hub", "app.R", package = "intraitR")
  testthat::skip_if(!nzchar(f), "package not installed")
  expect_true(file.exists(f))
})

test_that("the connected applications are checked at launch", {
  ha <- intraitR:::.hub_apps
  expect_identical(ha(NULL), list())
  a <- ha(list(list(label = "Space", fun = "Rfishmorph::launch_fishmorph_space"),
               list(id = "crop", label = "Crop", fun = "pkg::f", place = "photo",
                    photo_arg = "specimen")))
  expect_identical(names(a), c("app1", "crop"))
  expect_identical(a$app1$place, "menu")
  expect_identical(a$app1$args, list())
  expect_error(ha(list(list(label = "x"))), "`label` and `fun`")
  expect_error(ha(list(list(label = "x", fun = "f"))), "package::function")
  expect_error(ha(list(list(label = "x", fun = "p::f", place = "elsewhere"))), "place")
  expect_error(ha(list(list(label = "x", fun = "p::f", place = "photo"))), "photo_arg")
  expect_error(ha(list(list(id = "a", label = "x", fun = "p::f"),
                       list(id = "a", label = "y", fun = "p::g"))), "duplicated")
})

test_that("retract_landmarks() puts a photograph back to 'not measured'", {
  d <- file.path(tempdir(), paste0("retract_", paste(sample(letters, 6), collapse = "")))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  P <- cbind(c(10, 200), c(50, 60))
  for (k in c("A_001", "A_002"))
    landmark_journal_append(jr, k, P, 1:2, specimen = k, photo_file = paste0(k, ".jpg"),
                            target_sheet = "measurements")
  # a plate: two individuals of one photograph
  for (k in c("B_001_i1", "B_001_i2"))
    landmark_journal_append(jr, k, P, 1:2, specimen = k, photo_file = "B_001.jpg",
                            target_sheet = "measurements")
  expect_identical(nrow(consolidate_landmarks(d)), 4L)

  r <- suppressMessages(retract_landmarks(d, photo = "B_001"))
  expect_setequal(r$row_key, c("B_001_i1", "B_001_i2"))
  expect_setequal(consolidate_landmarks(d)$specimen, c("A_001", "A_002"))
  expect_identical(nrow(landmark_journal_qc(d)), 2L)
  # nothing erased: the history still holds the measurement and the retraction
  h <- consolidate_landmarks(d, history = TRUE)
  expect_true(all(c("retracted") %in% h$mode))
  expect_identical(sum(h$specimen == "B_001_i1"), 2L)
  # retracting again finds nothing live
  expect_identical(nrow(suppressMessages(retract_landmarks(d, photo = "B_001"))), 0L)
  # a later digitization supersedes the retraction
  Sys.sleep(0.01)
  jr2 <- suppressMessages(landmark_journal_open(d, operator = "AT"))
  landmark_journal_append(jr2, "B_001_i1", P, 1:2, specimen = "B_001_i1",
                          photo_file = "B_001.jpg", target_sheet = "measurements")
  expect_true("B_001_i1" %in% consolidate_landmarks(d)$specimen)
  # every key retracted: an empty table, with its columns
  suppressMessages(retract_landmarks(d, row_key = c("A_001", "A_002", "B_001_i1")))
  e <- consolidate_landmarks(d)
  expect_identical(nrow(e), 0L)
  expect_true("1_X" %in% names(e))
  expect_error(retract_landmarks(d), "Give `photo`")
})

test_that("retract_landmarks() also removes the rows from the workbook", {
  testthat::skip_if_not_installed("readxl"); testthat::skip_if_not_installed("writexl")
  d <- file.path(tempdir(), paste0("retractx_", paste(sample(letters, 6), collapse = "")))
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- suppressMessages(landmark_journal_open(file.path(d, "j"), operator = "AT"))
  for (k in c("A_001", "A_002"))
    landmark_journal_append(jr, k, cbind(c(1, 2), c(3, 4)), 1:2, specimen = k,
                            photo_file = paste0(k, ".jpg"), target_sheet = "measurements")
  x <- file.path(d, "landmarks.xlsx")
  writexl::write_xlsx(list(measurements = data.frame(specimen = c("A_001", "A_002"), `1_X` = 1:2,
                                                     check.names = FALSE),
                           bias = data.frame(specimen = "A_002_AT_rep1", `1_X` = 1,
                                             check.names = FALSE)), x)
  suppressMessages(retract_landmarks(file.path(d, "j"), photo = "A_002", xlsx_path = x))
  expect_identical(readxl::read_excel(x, "measurements")$specimen, "A_001")
  expect_identical(nrow(readxl::read_excel(x, "bias")), 1L)        # other key kept
  expect_true(file.exists(sub("\\.xlsx$", ".prev.xlsx", x)))
})

test_that("the batch predictions of a changed photograph are purged", {
  b <- file.path(tempdir(), paste0("batch_", paste(sample(letters, 6), collapse = "")), "S_D")
  dir.create(b, recursive = TRUE); on.exit(unlink(dirname(b), recursive = TRUE), add = TRUE)
  utils::write.csv(data.frame(photo = c("/x/A_001.jpg", "/x/A_002.jpg"), landmark = 1, X = 1, Y = 2),
                   file.path(b, "landmarks_long.csv"), row.names = FALSE)
  utils::write.csv(data.frame(photo = c("/x/A_001.jpg", "/x/A_002.jpg"), risk = 1),
                   file.path(b, "summary.csv"), row.names = FALSE)
  expect_identical(intraitR:::.hub_purge_batch(dirname(b), "A_002.jpg"), 2L)
  expect_identical(utils::read.csv(file.path(b, "summary.csv"))$photo, "/x/A_001.jpg")
})

test_that("the start page hands launch_measure_hub() what was chosen", {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("shiny"); testthat::skip_if_not_installed("bslib")
  root <- tempfile("start_"); on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "photos", "T26", "20260615"), recursive = TRUE)
  for (k in 1:3) writeBin(as.raw(c(0xFF, 0xD8, 0xFF, 0xD9)),
                          file.path(root, "photos", "T26", "20260615", sprintf("fish_%d.jpg", k)))
  utils::write.csv(data.frame(photo = paste0("fish_", 1:3), species = "Gobio gobio"),
                   file.path(root, "sp.csv"), row.names = FALSE)
  withr::local_options(intraitR.hub_start = list(last = list(), recent = list()))
  app <- shiny::shinyAppDir(system.file("shiny", "hub_start", package = "intraitR"))
  suppressMessages(shiny::testServer(app, {
    session$setInputs(photo_dir = "", sp_mode = "none", sp_path = "", xlsx_path = "",
                      journal_dir = "", operator = "AT", ruler_mm = 10,
                      levels = "Site / Date", mlmorph_dir = "")
    expect_match(problem(), "choose the folder")
    session$setInputs(photo_dir = file.path(root, "photos"))
    expect_null(problem())
    expect_equal(nrow(queue()), 3L)
    session$setInputs(sp_mode = "table")
    expect_match(problem(), "species table")
    session$setInputs(sp_path = file.path(root, "sp.csv"))
    expect_null(problem())
    ch <- choices()
    expect_equal(ch$photo_dir, normalizePath(file.path(root, "photos"), winslash = "/"))
    expect_equal(ch$levels, c("Site", "Date"))
    expect_match(ch$species, "sp\\.csv$")
    # what the hub will check, checked the same way
    cfg <- intraitR:::.hub_cfg(ch)
    expect_equal(basename(cfg$xlsx_path), "intraitR_landmarks.xlsx")
    expect_equal(unname(cfg$species["fish_2"]), "Gobio gobio")
    expect_match(output$code, "launch_measure_hub\\(")
  }))
})

test_that("recent sessions are remembered, most recent first, without duplicates", {
  withr::local_envvar(R_USER_DATA_DIR = tempfile("udata"))
  d1 <- tempfile("p1"); d2 <- tempfile("p2"); dir.create(d1); dir.create(d2)
  on.exit(unlink(c(d1, d2), recursive = TRUE), add = TRUE)
  intraitR:::.hub_recent_add(list(photo_dir = d1, species = "folder"))
  intraitR:::.hub_recent_add(list(photo_dir = d2, species = data.frame(x = 1)))
  intraitR:::.hub_recent_add(list(photo_dir = d1, operator = "AT"))
  r <- intraitR:::.hub_recent_read()
  expect_length(r, 2L)
  expect_equal(basename(r[[1]]$photo_dir), basename(d1))
  expect_equal(r[[1]]$operator, "AT")
  expect_null(r[[2]]$species)           # a table in memory is not remembered
  unlink(d2, recursive = TRUE)
  expect_length(intraitR:::.hub_recent_read(), 1L)   # a vanished folder is dropped
})
