test_that("impute_traits(method = 'impute_group_mean') imputes with CHARACTER groups", {
  # levels() of a character vector is NULL: the group loop once never ran and
  # nothing was imputed, under a message saying "imputed 0"
  X <- data.frame(a = c(1, NA, 3, 4, 5, 6), b = c(1, 2, NA, 4, 5, 6))
  g <- rep(c("Gobio gobio", "Squalius cephalus"), each = 3)
  r <- suppressMessages(impute_traits(X, method = "impute_group_mean", groups = g))
  expect_equal(r$traits$a[2], 2)            # mean of 1 and 3, not of the column
  expect_equal(r$traits$b[3], 1.5)
  expect_equal(sum(as.matrix(r$imputed)), 2)
  # and a factor gives the same answer
  rf <- suppressMessages(impute_traits(X, method = "impute_group_mean", groups = factor(g)))
  expect_equal(rf$traits, r$traits)
})
