test_that("batch_landmarks() validates `ruler` and `ruler_mm` before anything else", {
  expect_error(batch_landmarks(tempdir(), tempfile(), ruler = NA), "`ruler` must be TRUE or FALSE")
  expect_error(batch_landmarks(tempdir(), tempfile(), ruler = c(TRUE, FALSE)), "`ruler` must be")
  expect_error(batch_landmarks(tempdir(), tempfile(), ruler = "yes"), "`ruler` must be")
  expect_error(batch_landmarks(tempdir(), tempfile(), ruler_mm = 0), "`ruler_mm` must be")
  expect_error(batch_landmarks(tempdir(), tempfile(), ruler_mm = NA_real_), "`ruler_mm` must be")
})

test_that("read_batch_landmarks() reads the `ruler` column and defaults old runs to TRUE", {
  d <- tempfile("batch_"); dir.create(d)
  S <- data.frame(photo = c("a.jpg", "b.jpg"), individual = 1L, bl_px = c(100, 120),
                  score = c(0.9, 0.8), flags = c(NA, "règle"), risk = c(0.1, 1.2))
  utils::write.csv(S, file.path(d, "summary.csv"), row.names = FALSE)
  r <- read_batch_landmarks(d)
  expect_identical(r$summary$ruler, c(TRUE, TRUE))      # run older than the option
  expect_identical(r$summary$flags[r$summary$photo == "a.jpg"], "")

  S$ruler <- c(FALSE, NA)
  utils::write.csv(S, file.path(d, "summary.csv"), row.names = FALSE)
  r <- read_batch_landmarks(d)
  expect_identical(r$summary$ruler[match(c("a.jpg", "b.jpg"), r$summary$photo)], c(FALSE, TRUE))
})
