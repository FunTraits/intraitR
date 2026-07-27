make_measures <- function() {
  data.frame(
    specimen  = rep(c("fish_01", "fish_02"), each = 3),
    landmark  = rep(1:3, times = 2),
    X = c(10, 15, 20, 11, 16, 21),
    Y = c(20, 25, 20, 21, 26, 21),
    mm_per_px = c(0.22, 0.22, 0.22, NA, NA, NA),  # fish_02 has no scale bar
    stringsAsFactors = FALSE
  )
}

test_that("read_mlmorph_landmarks() builds an intrait_landmarks object", {
  lm <- suppressWarnings(read_mlmorph_landmarks(make_measures()))

  expect_s3_class(lm, "intrait_landmarks")
  expect_equal(dim(lm$coords), c(3, 2, 2))
  expect_equal(lm$coords[2, "X", "fish_01"], 15)
  # standard intraitR metadata columns, in canonical leading order
  expect_identical(
    names(lm$metadata)[1:5],
    c("specimen", "individual", "species", "population", "replicate")
  )
  expect_equal(lm$metadata$operator, rep("ml_morph", 2))
  expect_equal(lm$metadata$individual, lm$metadata$specimen)
})

test_that("the per-specimen scale and has_scalebar flag are carried", {
  lm <- suppressWarnings(read_mlmorph_landmarks(make_measures()))

  expect_equal(lm$metadata[["fish_01", "mm_per_px"]], 0.22)
  expect_true(is.na(lm$metadata[["fish_02", "mm_per_px"]]))
  expect_equal(lm$metadata$has_scalebar, c(TRUE, FALSE))
})

test_that("uncalibrated individuals raise a warning", {
  expect_warning(
    read_mlmorph_landmarks(make_measures()),
    "without a calibration scale"
  )
})

test_that("scale_col = NULL drops the scale columns", {
  lm <- read_mlmorph_landmarks(make_measures(), scale_col = NULL)
  expect_false("mm_per_px" %in% names(lm$metadata))
  expect_false("has_scalebar" %in% names(lm$metadata))
})

test_that("metadata is joined by an auto-detected or explicit key", {
  ident <- data.frame(
    code = c("fish_01", "fish_02"),
    species = c("Gobio occitaniae", "Squalius cephalus"),
    stage = c("adult", "juvenile"),
    stringsAsFactors = FALSE
  )
  lm <- suppressWarnings(
    read_mlmorph_landmarks(make_measures(), metadata = ident, by = "code")
  )
  expect_equal(lm$metadata$species, c("Gobio occitaniae", "Squalius cephalus"))
  expect_equal(lm$metadata$stage, c("adult", "juvenile"))
  expect_false("code" %in% names(lm$metadata))  # join key is dropped

  # auto-detection picks "code" when `by` is not given
  lm_auto <- suppressWarnings(read_mlmorph_landmarks(make_measures(), metadata = ident))
  expect_equal(lm_auto$metadata$species, lm$metadata$species)
})

test_that("individuals absent from metadata keep NA descriptors, with a warning", {
  ident <- data.frame(code = "fish_01", species = "Gobio occitaniae",
                      stringsAsFactors = FALSE)
  expect_warning(
    lm <- read_mlmorph_landmarks(make_measures(), metadata = ident, by = "code"),
    "no matching row"
  )
  expect_true(is.na(lm$metadata[["fish_02", "species"]]))
})

test_that("missing coordinate columns are reported", {
  bad <- make_measures()[c("specimen", "landmark", "X")]
  expect_error(read_mlmorph_landmarks(bad), "Missing column")
})

## ---- replicated identifiers ------------------------------------------------
## The repeat mode of digitize_landmarks() distinguishes passes over the same
## individual by the identifier, "<individual>[_<operator>]_rep<N>", since the
## exported schema is one row per specimen and landmark.
make_repeats <- function(ids) {
  data.frame(
    specimen = rep(ids, each = 3),
    landmark = rep(1:3, times = length(ids)),
    X = rep(c(10, 15, 20), times = length(ids)),
    Y = rep(c(20, 25, 20), times = length(ids)),
    stringsAsFactors = FALSE
  )
}

test_that("replicate = 'parse' splits <individual>_rep<N>", {
  ids <- c("fish_01_rep1", "fish_01_rep2", "fish_02_rep1")
  lm <- suppressMessages(
    read_mlmorph_landmarks(make_repeats(ids), scale_col = NULL,
                           replicate = "parse")
  )
  # specimen ids are sorted: fish_01_rep1, fish_01_rep2, fish_02_rep1
  expect_equal(lm$metadata$individual, c("fish_01", "fish_01", "fish_02"))
  expect_equal(lm$metadata$replicate, c(1L, 2L, 1L))
  # a scalar operator is still recycled untouched
  expect_equal(lm$metadata$operator, rep("ml_morph", 3))
})

test_that("operator = 'parse' takes the token before the replicate suffix", {
  ids <- c("fish_01_AT_rep1", "fish_01_GH_rep1", "fish_02_AT_rep2")
  lm <- suppressMessages(
    read_mlmorph_landmarks(make_repeats(ids), scale_col = NULL,
                           replicate = "parse", operator = "parse")
  )
  expect_equal(lm$metadata$individual, c("fish_01", "fish_01", "fish_02"))
  expect_equal(lm$metadata$operator, c("AT", "GH", "AT"))
  expect_equal(lm$metadata$replicate, c(1L, 1L, 2L))
})

test_that("identifiers with no suffix are left alone (replicate 1)", {
  ids <- c("fish_01_rep1", "fish_01_rep2", "fish_03")
  lm <- suppressMessages(
    read_mlmorph_landmarks(make_repeats(ids), scale_col = NULL,
                           replicate = "parse")
  )
  expect_equal(lm$metadata$individual, c("fish_01", "fish_01", "fish_03"))
  expect_equal(lm$metadata$replicate, c(1L, 2L, 1L))
})

test_that("parsing is never silent: unsuffixed tables warn and stay unchanged", {
  expect_warning(
    lm <- read_mlmorph_landmarks(make_repeats(c("fish_01", "fish_02")),
                                 scale_col = NULL, replicate = "parse"),
    "ends in"
  )
  expect_equal(lm$metadata$individual, lm$metadata$specimen)
  expect_equal(lm$metadata$replicate, c(1L, 1L))
})

test_that("a replicate suffix without an operator token keeps operator = NA", {
  expect_warning(
    lm <- suppressMessages(
      read_mlmorph_landmarks(make_repeats(c("fish01_rep1", "fish01_rep2")),
                             scale_col = NULL, replicate = "parse",
                             operator = "parse")
    ),
    "no operator token"
  )
  expect_equal(lm$metadata$individual, c("fish01", "fish01"))
  expect_true(all(is.na(lm$metadata$operator)))
})

test_that("the defaults are unchanged and bad values are rejected", {
  lm <- read_mlmorph_landmarks(make_repeats(c("fish_01_rep1", "fish_01_rep2")),
                               scale_col = NULL)
  expect_equal(lm$metadata$individual, lm$metadata$specimen)   # no parsing
  expect_equal(lm$metadata$replicate, c(1L, 1L))
  expect_error(
    read_mlmorph_landmarks(make_repeats("fish_01_rep1"), scale_col = NULL,
                           replicate = "toutes"),
    "single integer"
  )
})

test_that("save_to writes a readable .rds", {
  path <- tempfile(fileext = ".rds")
  lm <- suppressWarnings(read_mlmorph_landmarks(make_measures(), save_to = path))
  expect_true(file.exists(path))
  expect_s3_class(readRDS(path), "intrait_landmarks")
  unlink(path)
})
