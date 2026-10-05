test_that("read_tps() parses a minimal valid TPS file", {
  tps_path <- tempfile(fileext = ".tps")
  writeLines(c(
    "LM=3", "10.0 20.0", "15.0 25.0", "20.0 20.0",
    "IMAGE=fish_01.jpg", "ID=1", "SCALE=0.05",
    "LM=3", "11.0 21.0", "16.0 26.0", "21.0 21.0",
    "IMAGE=fish_02.jpg", "ID=2", "SCALE=0.04"
  ), tps_path)

  lm <- read_tps(tps_path)

  expect_s3_class(lm, "intrait_landmarks")
  expect_equal(dim(lm$coords), c(3, 2, 2))
  expect_equal(dimnames(lm$coords)[[3]], c("fish_01.jpg", "fish_02.jpg"))
  expect_equal(unname(lm$scale), c(0.05, 0.04))
})

test_that("read_tps() uses specID = 'ID' when requested", {
  tps_path <- tempfile(fileext = ".tps")
  writeLines(c(
    "LM=2", "1 1", "2 2", "IMAGE=a.jpg", "ID=10",
    "LM=2", "3 3", "4 4", "IMAGE=b.jpg", "ID=20"
  ), tps_path)

  lm <- read_tps(tps_path, specID = "ID")
  expect_equal(dimnames(lm$coords)[[3]], c("10", "20"))
})

test_that("read_tps() errors on inconsistent landmark counts", {
  tps_path <- tempfile(fileext = ".tps")
  writeLines(c(
    "LM=2", "1 1", "2 2",
    "LM=3", "1 1", "2 2", "3 3"
  ), tps_path)

  expect_error(read_tps(tps_path), "same number of landmarks")
})

test_that("read_tps() errors on missing file", {
  expect_error(read_tps(tempfile()), "not found")
})

test_that("read_tps() merges metadata correctly", {
  tps_path <- tempfile(fileext = ".tps")
  writeLines(c(
    "LM=2", "1 1", "2 2", "IMAGE=a.jpg",
    "LM=2", "3 3", "4 4", "IMAGE=b.jpg"
  ), tps_path)

  meta <- data.frame(specimen = c("a.jpg", "b.jpg"), species = c("sp1", "sp2"))
  lm <- read_tps(tps_path, metadata = meta)
  expect_equal(lm$metadata$species, c("sp1", "sp2"))
})
