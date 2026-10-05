skip_if_not_installed("readxl")
skip_if_not_installed("writexl")

.write_tmp_xlsx <- function(df) {
  path <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(df, path)
  path
}

test_that("read_landmarks_xlsx() reshapes a wide X_i/Y_i sheet correctly", {
  wide <- data.frame(
    Code = c("fish_01", "fish_02"),
    Utilisateur = c("Op1", "Op1"),
    X_1 = c(10, 11), Y_1 = c(20, 21),
    X_2 = c(15, 16), Y_2 = c(25, 26),
    X_3 = c(20, 21), Y_3 = c(20, 21)
  )
  path <- .write_tmp_xlsx(wide)

  lm <- read_landmarks_xlsx(path, n_landmarks = 3, id_cols = c("Code", "Utilisateur"))

  expect_s3_class(lm, "intrait_landmarks")
  expect_equal(dim(lm$coords), c(3, 2, 2))
  expect_null(lm$scale)
  expect_equal(dimnames(lm$coords)[[3]], c("fish_01_Op1", "fish_02_Op1"))
  expect_equal(lm$coords[2, "X", "fish_01_Op1"], 15)
  expect_equal(lm$metadata$Code, c("fish_01", "fish_02"))
})

test_that("read_landmarks_xlsx() supports a {i}_X/{i}_Y (replicate-style) pattern", {
  wide <- data.frame(
    Code = c("fish_01", "fish_01"),
    Mesure = c(1, 2),
    `1_X` = c(10, 10.5), `1_Y` = c(20, 20.5),
    `2_X` = c(15, 15.5), `2_Y` = c(25, 25.5),
    check.names = FALSE
  )
  path <- .write_tmp_xlsx(wide)

  lm <- read_landmarks_xlsx(
    path, n_landmarks = 2, id_cols = c("Code", "Mesure"),
    x_pattern = "{i}_X", y_pattern = "{i}_Y"
  )

  expect_equal(dim(lm$coords), c(2, 2, 2))
  expect_equal(dimnames(lm$coords)[[3]], c("fish_01_1", "fish_01_2"))
  expect_equal(lm$coords[1, "X", "fish_01_2"], 10.5)
})

test_that("read_landmarks_xlsx() drops blank rows and reports how many", {
  wide <- data.frame(
    Code = c("fish_01", NA, "fish_02"),
    X_1 = c(10, NA, 11), Y_1 = c(20, NA, 21)
  )
  path <- .write_tmp_xlsx(wide)

  expect_message(
    lm <- read_landmarks_xlsx(path, n_landmarks = 1, id_cols = "Code"),
    "Dropped 1 blank row"
  )
  expect_equal(dim(lm$coords)[3], 2)
})

test_that("read_landmarks_xlsx() treats blank/\"NA\" cells as missing without warning", {
  wide <- data.frame(
    Code = c("fish_01", "fish_02"),
    X_1 = c("10", "NA"), Y_1 = c("20", "21")
  )
  path <- .write_tmp_xlsx(wide)

  expect_no_warning(
    lm <- read_landmarks_xlsx(path, n_landmarks = 1, id_cols = "Code")
  )
  expect_true(is.na(lm$coords[1, "X", "fish_02"]))
})

test_that("read_landmarks_xlsx() warns on genuinely non-numeric coordinate cells", {
  wide <- data.frame(
    Code = c("fish_01", "fish_02"),
    X_1 = c("10", "oops"), Y_1 = c("20", "21")
  )
  path <- .write_tmp_xlsx(wide)

  expect_warning(
    lm <- read_landmarks_xlsx(path, n_landmarks = 1, id_cols = "Code"),
    "could not be parsed as numeric"
  )
  expect_true(is.na(lm$coords[1, "X", "fish_02"]))
})

test_that("read_landmarks_xlsx() errors with an informative message on missing columns", {
  wide <- data.frame(Code = "fish_01", X_1 = 10, Y_1 = 20)
  path <- .write_tmp_xlsx(wide)

  expect_error(
    read_landmarks_xlsx(path, n_landmarks = 2, id_cols = "Code"),
    "Column\\(s\\) not found"
  )
})

test_that("read_landmarks_xlsx() joins species_file by a shared key", {
  wide <- data.frame(
    Code = c("fish_01", "fish_02", "fish_03"),
    X_1 = c(10, 11, 9), Y_1 = c(20, 21, 19)
  )
  ident <- data.frame(
    Code = c("fish_01", "fish_02", "fish_03"),
    species = c("Gobio occitaniae", "Gobio occitaniae", "Squalius cephalus"),
    site = c("Saudrune", "Saudrune", "Saudrune")
  )
  landmarks_path <- .write_tmp_xlsx(wide)
  ident_path <- .write_tmp_xlsx(ident)

  lm <- read_landmarks_xlsx(
    landmarks_path, n_landmarks = 1, id_cols = "Code",
    species_file = ident_path
  )

  expect_equal(lm$metadata$species, c("Gobio occitaniae", "Gobio occitaniae", "Squalius cephalus"))
  expect_equal(lm$metadata$site, rep("Saudrune", 3))
})

test_that("read_landmarks_xlsx() warns and sets NA for species_file rows with no match", {
  wide <- data.frame(
    Code = c("fish_01", "fish_02"),
    X_1 = c(10, 11), Y_1 = c(20, 21)
  )
  ident <- data.frame(Code = "fish_01", species = "Gobio occitaniae")
  landmarks_path <- .write_tmp_xlsx(wide)
  ident_path <- .write_tmp_xlsx(ident)

  expect_warning(
    lm <- read_landmarks_xlsx(
      landmarks_path, n_landmarks = 1, id_cols = "Code",
      species_file = ident_path
    ),
    "no match in `species_file`"
  )
  expect_true(is.na(lm$metadata$species[2]))
})

test_that("read_landmarks_xlsx() de-duplicates repeated specimen identifiers with a warning", {
  wide <- data.frame(
    Code = c("fish_01", "fish_01"),
    X_1 = c(10, 11), Y_1 = c(20, 21)
  )
  path <- .write_tmp_xlsx(wide)

  expect_warning(
    lm <- read_landmarks_xlsx(path, n_landmarks = 1, id_cols = "Code"),
    "Duplicated specimen"
  )
  expect_equal(dimnames(lm$coords)[[3]], c("fish_01", "fish_01.1"))
})
