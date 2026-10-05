test_that("summary_traits() summarises correctly by group", {
  traits <- data.frame(BD_ratio = c(0.2, 0.22, 0.4, 0.42))
  groups <- c("A", "A", "B", "B")
  out <- summary_traits(traits, groups)

  expect_equal(nrow(out), 2)
  expect_equal(out$mean[out$group == "A"], mean(c(0.2, 0.22)))
  expect_equal(out$n[out$group == "B"], 2)
})

test_that("summary_traits() errors with no numeric columns", {
  traits <- data.frame(label = c("x", "y"))
  expect_error(summary_traits(traits, c("A", "B")), "no numeric columns")
})

test_that("summary_traits() errors on mismatched lengths", {
  traits <- data.frame(x = c(1, 2, 3))
  expect_error(summary_traits(traits, c("A", "B")), "one entry per row")
})
