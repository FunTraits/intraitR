test_that(".hub_photos_present finds copies on disk and within the upload", {
  d <- withr::local_tempdir()
  dir.create(file.path(d, "T26_a"))
  img <- function(path, seed) { set.seed(seed); writeBin(as.raw(sample(0:255, 500, TRUE)), path); path }
  img(file.path(d, "T26_a", "IMG_1.jpg"), 1)
  up <- c(img(tempfile(fileext = ".jpg"), 1),   # identical to IMG_1 on disk
          img(tempfile(fileext = ".jpg"), 2),   # new
          img(tempfile(fileext = ".jpg"), 2))   # sent twice
  r <- .hub_photos_present(up, c("renamed.jpg", "new.jpg", "new_copy.jpg"), d)
  expect_setequal(r$name, c("renamed.jpg", "new_copy.jpg"))
  expect_equal(r$where[r$name == "renamed.jpg"], "on disk")
  expect_match(r$found[r$name == "renamed.jpg"], "IMG_1.jpg$")
  expect_equal(r$found[r$name == "new_copy.jpg"], "new.jpg")
  expect_equal(nrow(.hub_photos_present(up[2], "new.jpg", d)), 0L)
  expect_equal(nrow(.hub_photos_present(character(0))), 0L)
})
