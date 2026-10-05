test_that(".papply() matches vapply() exactly for a scalar FUN.VALUE", {
  x <- 1:20
  expect_equal(
    intraitR:::.papply(x, function(i) i^2, numeric(1)),
    vapply(x, function(i) i^2, numeric(1))
  )
})

test_that(".papply() matches vapply()'s matrix output for a length > 1 FUN.VALUE", {
  x <- 1:5
  expect_equal(
    intraitR:::.papply(x, function(i) c(i, i^2), numeric(2)),
    vapply(x, function(i) c(i, i^2), numeric(2))
  )
})

test_that(".papply() runs correctly under an explicit sequential future::plan()", {
  testthat::skip_if_not_installed("future.apply")
  testthat::skip_if_not_installed("future")

  old_plan <- future::plan("sequential")
  on.exit(future::plan(old_plan), add = TRUE)

  x <- 1:10
  expect_equal(intraitR:::.papply(x, function(i) i * 2, numeric(1)), x * 2)
})

test_that(".papply() falls back to vapply() when future.apply is not installed", {
  testthat::skip_if(
    requireNamespace("future.apply", quietly = TRUE),
    "future.apply is installed; cannot test the fallback path"
  )
  x <- 1:8
  expect_equal(intraitR:::.papply(x, function(i) i + 1, numeric(1)), x + 1)
})
