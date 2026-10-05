test_that("read_landmarks_csv() reshapes long-format data correctly", {
  df <- data.frame(
    specimen = rep(c("fish_01", "fish_02"), each = 3),
    landmark = rep(1:3, times = 2),
    X = c(10, 15, 20, 11, 16, 21),
    Y = c(20, 25, 20, 21, 26, 21)
  )

  lm <- read_landmarks_csv(df)

  expect_s3_class(lm, "intrait_landmarks")
  expect_equal(dim(lm$coords), c(3, 2, 2))
  expect_null(lm$scale)
  expect_equal(lm$coords[2, "X", "fish_01"], 15)
})

test_that("read_landmarks_csv() errors on missing columns", {
  df <- data.frame(specimen = "a", landmark = 1, X = 1)
  expect_error(read_landmarks_csv(df), "Missing column")
})

test_that("read_landmarks_csv() errors on unbalanced specimens", {
  df <- data.frame(
    specimen = c("a", "a", "b"),
    landmark = c(1, 2, 1),
    X = c(1, 2, 3), Y = c(1, 2, 3)
  )
  expect_error(read_landmarks_csv(df), "same number of landmarks")
})
