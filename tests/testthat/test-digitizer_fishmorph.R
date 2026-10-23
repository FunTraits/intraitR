## The FISHMORPH reference target of the digitizer: the store that reads and
## writes the reference workbook (R/digitizer_fishmorph.R), exercised without
## Shiny on a miniature workbook laid out like FISHMORPH_PUBLI_*.xlsx.

fm_fixture <- function() {
  testthat::skip_if_not_installed("openxlsx")
  d <- file.path(tempdir(), paste0("fm_", paste(sample(letters, 8), collapse = "")))
  dir.create(file.path(d, "Photos utilisees"), recursive = TRUE)
  dir.create(file.path(d, "Photos nouvelles"), recursive = TRUE)
  seg <- data.frame(Genus.species = c("Abramis.brama", "Barbus.barbus", "Coregonus.lavaretus"),
                    Bl = c(100, 200, NA), Bd = c(30, 40, 1), Hd = 20, Eh2 = 10,
                    Mo2 = 8, PFi2 = 6, PFl = 15, Ed = 5, Jl = 4, CPd = 9, CFd = 25)
  lm <- data.frame(Genus.species = c("Abramis.brama", "Barbus.barbus", "Coregonus.lavaretus"))
  for (p in c(1:19, 22L, 23L)) {
    lm[[paste0(p, "_X")]] <- NA_real_
    lm[[paste0(p, "_Y")]] <- NA_real_
  }
  # Barbus already landmarked (except LM12, left empty); the others are not
  for (p in setdiff(c(1:19, 22L, 23L), 12L)) {
    lm[2, paste0(p, "_X")] <- 10 * p
    lm[2, paste0(p, "_Y")] <- 5 * p
  }
  lm$quality_score <- c(NA, 4, NA)
  lm$collapse_rules <- c(NA, "Mo", NA)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Global_segments")
  openxlsx::writeData(wb, "Global_segments", seg)
  openxlsx::addWorksheet(wb, "Global_Landmark")
  openxlsx::writeData(wb, "Global_Landmark", lm)
  x <- file.path(d, "FISHMORPH_PUBLI_test.xlsx")
  openxlsx::saveWorkbook(wb, x)
  for (f in c("Abramis_brama.jpg", "Barbus_barbus.jpg", "Coregonus_lavaretus.jpg"))
    writeBin(as.raw(c(0xFF, 0xD8)), file.path(d, "Photos utilisees", f))
  writeBin(as.raw(c(0xFF, 0xD8)), file.path(d, "Photos nouvelles", "Squalius_cephalus.jpg"))
  list(dir = d, xlsx = x)
}
fm_open <- function(fx) suppressMessages(intraitR:::.fm_store_open(
  fx$xlsx, photo_dir = file.path(fx$dir, "Photos utilisees"),
  new_photo_dir = file.path(fx$dir, "Photos nouvelles")))

test_that("the store builds the three queues of the old FISHMORPH digitizer", {
  fx <- fm_fixture(); on.exit(unlink(fx$dir, recursive = TRUE), add = TRUE)
  st <- fm_open(fx)
  expect_true(file.exists(st$out_path))
  expect_match(basename(st$out_path), "_reconstructed\\.xlsx$")
  # Coregonus has no Bl -> no segments -> not reconstructible
  expect_equal(st$labels("reconstruct"), "Abramis.brama")
  expect_equal(st$labels("correct"), "Barbus.barbus")
  expect_equal(st$labels("new"), "Squalius_cephalus.jpg")
  e <- st$entry("correct", 1)
  expect_equal(e$key, "Barbus.barbus")        # row_key as before: the species
  expect_equal(st$entry("new", 1)$key, "Squalius_cephalus.jpg")
  expect_equal(st$entry("new", 1)$species, "Squalius cephalus")
  expect_null(st$entry("correct", 2))
})

test_that("a landmarked row is reloaded with its points, gaps and declarations", {
  fx <- fm_fixture(); on.exit(unlink(fx$dir, recursive = TRUE), add = TRUE)
  st <- fm_open(fx)
  s <- st$seed("correct", 1)
  expect_equal(unname(s$P[3, ]), c(30, 15))
  expect_equal(s$na, 12L)                     # empty anatomical point -> NA
  expect_equal(s$quality_score, 4)
  expect_equal(s$collapse_rules, "Mo")
  expect_null(st$seed("reconstruct", 1))      # nothing recorded yet
})

test_that("a species is seeded at its MEASURED proportions", {
  fx <- fm_fixture(); on.exit(unlink(fx$dir, recursive = TRUE), add = TRUE)
  st <- fm_open(fx)
  r <- st$ratios("reconstruct", 1)
  expect_equal(r[["Bd"]], 30 / 100)
  expect_equal(r[["Eh"]], 10 / 100)          # from Eh2, not Eh
  expect_length(attr(r, "fallback"), 0L)
  expect_null(st$ratios("new", 1))
  # the seed geometry uses them: a body depth twice the median gives 3-4 twice as far apart
  P <- intraitR:::empty_coords(); P[1, ] <- c(0, 0); P[2, ] <- c(1000, 0)
  a <- intraitR:::seed_configuration(P)
  b <- intraitR:::seed_configuration(P, ratios = c(Bd = 2 * intraitR:::FM_MEDIAN_RATIOS[["Bd"]]))
  da <- sqrt(sum((a[3, ] - a[4, ])^2)); db <- sqrt(sum((b[3, ] - b[4, ])^2))
  expect_equal(db / da, 2, tolerance = 1e-6)
  # a missing segment falls back on the median, and says so
  rr <- intraitR:::.fm_seed_ratios(list(Bl = 100, Bd = NA, Hd = 20))
  expect_true("Bd" %in% attr(rr, "fallback"))
  expect_equal(rr[["Bd"]], intraitR:::FM_MEDIAN_RATIOS[["Bd"]])
})

test_that("saving writes the row in place, and a new photograph appends a row", {
  fx <- fm_fixture(); on.exit(unlink(fx$dir, recursive = TRUE), add = TRUE)
  st <- fm_open(fx)
  P <- matrix(NA_real_, 25, 2)
  for (p in c(1:19, 22L, 23L)) P[p, ] <- c(p + 0.5, p + 1.5)
  st$save("reconstruct", 1, P, list(quality_score = 5, reviewed = TRUE,
                                    reviewed_by = "AT", review_date = "2026-10-23",
                                    collapse_rules = ""))
  expect_equal(st$pending(), 1L)
  Pn <- P; Pn[20, ] <- c(0, 0); Pn[21, ] <- c(100, 0)
  st$save("new", 1, Pn, list(species = "Squalius cephalus", quality_score = NA,
                             reviewed = FALSE, ruler_mm = 10, mm_per_px = 0.1))
  st$flush(force = TRUE)
  expect_equal(st$pending(), 0L)
  testthat::skip_if_not_installed("readxl")
  lm <- as.data.frame(readxl::read_excel(st$out_path, sheet = "Global_Landmark"))
  expect_equal(lm[lm$Genus.species == "Abramis.brama", "3_X"], 3.5)
  expect_equal(lm[lm$Genus.species == "Abramis.brama", "quality_score"], 5)
  expect_true(all(c("24_X", "25_Y", "reviewed_by") %in% names(lm)))
  nw <- as.data.frame(readxl::read_excel(st$out_path, sheet = "new_specimens"))
  expect_equal(nrow(nw), 1L)
  expect_equal(nw$photo_file, "Squalius_cephalus.jpg")
  expect_equal(nw[["21_X"]], 100)
  expect_equal(nw$mm_per_px, 0.1)
  # reopened, the saved species leaves "reconstruct" and joins "correct"
  st2 <- fm_open(list(dir = fx$dir, xlsx = st$out_path))
  expect_false("Abramis.brama" %in% st2$labels("reconstruct"))
  expect_true("Abramis.brama" %in% st2$labels("correct"))
  # the new specimen is in "correct" too, from the new-specimen sheet
  expect_true("Squalius cephalus" %in% st2$labels("correct"))
})

test_that("the launcher refuses a missing workbook before anything else", {
  expect_error(digitize_fishmorph_reference(file.path(tempdir(), "nope.xlsx")),
               "not found")
})

test_that("a sheet or folder named almost like the one asked for is recognised", {
  fx <- fm_fixture(); on.exit(unlink(fx$dir, recursive = TRUE), add = TRUE)
  st <- fm_open(fx)                       # creates "new_specimens" in the copy
  expect_equal(st$new_sheet, "new_specimens")
  st2 <- suppressMessages(intraitR:::.fm_store_open(
    st$out_path, photo_dir = file.path(fx$dir, "Photos utilisees"),
    new_photo_dir = file.path(fx$dir, "Photos nouvelles"),
    new_sheet = "New_specimen"))          # the name of the real workbooks
  expect_equal(st2$new_sheet, "new_specimens")
  expect_error(suppressMessages(intraitR:::.fm_store_open(
    st$out_path, photo_dir = file.path(fx$dir, "Photos utilisees"),
    new_photo_dir = file.path(fx$dir, "Photos nouvelles"), lm_sheet = "Nope")),
    "not found")
  acc <- file.path(fx$dir, "Photos utilisées")
  dir.create(acc)
  expect_equal(normalizePath(suppressMessages(
                 intraitR:::.fm_find_dir(file.path(fx$dir, "Photos utilisees x")))),
               normalizePath(file.path(fx$dir, "Photos utilisees x"), mustWork = FALSE))
  unlink(file.path(fx$dir, "Photos utilisees"), recursive = TRUE)
  expect_equal(basename(suppressMessages(
                 intraitR:::.fm_find_dir(file.path(fx$dir, "Photos utilisees")))),
               basename(acc))
})

test_that("a photo folder that matches no species is reported, not silent", {
  fx <- fm_fixture(); on.exit(unlink(fx$dir, recursive = TRUE), add = TRUE)
  empty <- file.path(fx$dir, "empty"); dir.create(empty)
  expect_warning(suppressMessages(intraitR:::.fm_store_open(
    fx$xlsx, photo_dir = empty, new_photo_dir = file.path(fx$dir, "Photos nouvelles"))),
    "matches a photograph")
})

test_that("the intake helpers frame, name and write a new photograph", {
  a <- array(0, c(4, 6, 3)); a[1, 1, ] <- 1          # a marked corner, top-left
  r <- intraitR:::.fm_rot90(a, 1L)                    # quarter turn
  expect_equal(dim(r), c(6, 4, 3))
  expect_equal(dim(intraitR:::.fm_rot90(a, 4L)), dim(a))   # full turn = identity
  expect_equal(intraitR:::.fm_rot90(a, 4L), a)
  m <- intraitR:::.fm_mirror(a, "h")
  expect_equal(m[1, 6, 1], 1)                         # corner now top-right
  expect_null(intraitR:::.fm_crop(a, 0, 2, 0, 2))     # below 8 px a side
  big <- array(0.5, c(40, 60, 3))
  expect_equal(dim(intraitR:::.fm_crop(big, 10, 30, 5, 25)), c(20, 20, 3))

  expect_equal(intraitR:::.fm_check_binomial("abramis  BRAMA")$name, "Abramis brama")
  expect_false(intraitR:::.fm_check_binomial("Abramis")$ok)
  expect_false(intraitR:::.fm_check_binomial("Abramis br4ma")$ok)
  expect_equal(intraitR:::.fm_name_from_file("Abramis_brama_2.JPG"), "Abramis brama")

  skip_if_not_installed("jpeg")
  d <- file.path(tempdir(), paste0("intake_", paste(sample(letters, 6), collapse = "")))
  dir.create(d); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  p1 <- intraitR:::.fm_new_photo_path(d, "Abramis brama")
  expect_equal(basename(p1), "Abramis_brama.jpg")
  intraitR:::.fm_write_img_as(big, p1)
  expect_true(file.exists(p1))
  expect_equal(basename(intraitR:::.fm_new_photo_path(d, "Abramis brama")),
               "Abramis_brama_2.jpg")                 # a second specimen, not a clash
  # writing a flip back keeps ONE pristine original in _originaux/
  res <- intraitR:::.fm_write_img(big[, 60:1, , drop = FALSE], p1)
  expect_true(res$jpeg)
  expect_true(file.exists(file.path(d, "_originaux", "Abramis_brama.jpg")))
  first <- tools::md5sum(file.path(d, "_originaux", "Abramis_brama.jpg"))
  intraitR:::.fm_write_img(big, p1)
  expect_identical(tools::md5sum(file.path(d, "_originaux", "Abramis_brama.jpg")), first)
})
