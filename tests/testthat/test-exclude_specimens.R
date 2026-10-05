# simulate_fish_landmarks() gives a small "intrait_landmarks" fixture with
# both `metadata` and `scale` populated for every specimen (see
# R/simulate_fish_landmarks.R), which is exactly what exclude_specimens()
# needs to filter consistently, without depending on the full 21-landmark
# FISHMORPH scheme other test fixtures in this package use.
make_fish <- function() {
  simulate_fish_landmarks(n_per_species = 3, n_replicates = 1, seed = 1)
}

test_that("exclude_specimens() removes a specimen by name, filtering coords/scale/metadata", {
  fish <- make_fish()
  target <- dimnames(fish$coords)[[3]][1]

  expect_message(out <- exclude_specimens(fish, specimen = target), "removed 1 specimen")
  expect_s3_class(out, "intrait_landmarks")
  expect_equal(dim(out$coords)[3], dim(fish$coords)[3] - 1)
  expect_false(target %in% dimnames(out$coords)[[3]])
  expect_false(target %in% names(out$scale))
  expect_false(target %in% rownames(out$metadata))
  expect_equal(nrow(out$metadata), dim(out$coords)[3])
  expect_length(out$scale, dim(out$coords)[3])
})

test_that("exclude_specimens() removes several specimens by name and records `reason`", {
  fish <- make_fish()
  targets <- dimnames(fish$coords)[[3]][1:2]

  out <- suppressMessages(exclude_specimens(
    fish,
    specimen = targets,
    reason = c("mis-measured: Bd = 0", "mis-measured: Hd = 0")
  ))

  expect_equal(dim(out$coords)[3], dim(fish$coords)[3] - 2)
  expect_false(any(targets %in% dimnames(out$coords)[[3]]))
  expect_s3_class(out$removed_specimens, "data.frame")
  expect_equal(nrow(out$removed_specimens), 2)
  expect_setequal(out$removed_specimens$specimen, targets)
  expect_setequal(out$removed_specimens$reason, c("mis-measured: Bd = 0", "mis-measured: Hd = 0"))
})

test_that("exclude_specimens() recycles a length-1 `reason` across every specimen", {
  fish <- make_fish()
  targets <- dimnames(fish$coords)[[3]][1:2]

  out <- suppressMessages(exclude_specimens(fish, specimen = targets, reason = "bad measurement"))
  expect_true(all(out$removed_specimens$reason == "bad measurement"))
})

test_that("exclude_specimens() removes a specimen by integer position", {
  fish <- make_fish()
  target <- dimnames(fish$coords)[[3]][2]

  out <- suppressMessages(exclude_specimens(fish, specimen = 2))
  expect_false(target %in% dimnames(out$coords)[[3]])
})

test_that("exclude_specimens() errors on an unknown specimen name (no silent no-op)", {
  fish <- make_fish()
  expect_error(exclude_specimens(fish, specimen = "not_a_real_specimen"), "not found")
})

test_that("exclude_specimens() errors on an out-of-range integer position", {
  fish <- make_fish()
  n <- dim(fish$coords)[3]
  expect_error(exclude_specimens(fish, specimen = n + 1), "outside 1:")
  expect_error(exclude_specimens(fish, specimen = 0), "outside 1:")
})

test_that("exclude_specimens() requires at least one specimen", {
  fish <- make_fish()
  expect_error(exclude_specimens(fish, specimen = character(0)), "at least one specimen")
})

test_that("exclude_specimens() refuses to remove every specimen", {
  fish <- make_fish()
  expect_error(
    exclude_specimens(fish, specimen = dimnames(fish$coords)[[3]]),
    "leave zero specimens"
  )
})

test_that("exclude_specimens() warns and de-duplicates a specimen listed twice", {
  fish <- make_fish()
  target <- dimnames(fish$coords)[[3]][1]

  expect_warning(
    out <- suppressMessages(exclude_specimens(fish, specimen = c(target, target))),
    "more than once"
  )
  expect_equal(nrow(out$removed_specimens), 1)
  expect_equal(dim(out$coords)[3], dim(fish$coords)[3] - 1)
})

test_that("exclude_specimens() errors on a `reason` of the wrong length", {
  fish <- make_fish()
  targets <- dimnames(fish$coords)[[3]][1:2]
  expect_error(
    exclude_specimens(fish, specimen = targets, reason = c("a", "b", "c")),
    "reason"
  )
})

test_that("exclude_specimens() rejects \"intrait_gpa\" objects, pointing to gpa_fish()", {
  testthat::skip_if_not_installed("geomorph")
  fish <- make_fish()
  gpa <- gpa_fish(fish)
  target <- dimnames(gpa$coords)[[3]][1]
  expect_error(exclude_specimens(gpa, specimen = target), "gpa_fish")
})

test_that("exclude_specimens() accumulates `removed_specimens` across successive calls", {
  fish <- make_fish()
  ids <- dimnames(fish$coords)[[3]]

  step1 <- suppressMessages(exclude_specimens(fish, specimen = ids[1], reason = "first pass"))
  step2 <- suppressMessages(exclude_specimens(step1, specimen = ids[2], reason = "second pass"))

  expect_equal(nrow(step2$removed_specimens), 2)
  expect_setequal(step2$removed_specimens$specimen, ids[1:2])
  expect_equal(dim(step2$coords)[3], dim(fish$coords)[3] - 2)
})

test_that("exclude_specimens() filters pre-existing per-specimen audit-trail attributes", {
  fish <- make_fish()
  ids <- dimnames(fish$coords)[[3]]

  oriented <- suppressMessages(standardize_orientation(fish))
  target <- ids[1]

  out <- suppressMessages(exclude_specimens(oriented, specimen = target))
  orientation_log <- attr(out$coords, "orientation_log")
  expect_false(target %in% orientation_log$specimen)
  expect_equal(nrow(orientation_log), dim(out$coords)[3])
})

test_that("exclude_specimens() works on a raw (non-classed) array, using an attribute instead of a list element", {
  fish <- make_fish()
  target <- dimnames(fish$coords)[[3]][1]

  out <- suppressMessages(exclude_specimens(fish$coords, specimen = target))
  expect_true(is.array(out))
  expect_false(inherits(out, "intrait_landmarks"))
  expect_false(target %in% dimnames(out)[[3]])
  removed <- attr(out, "removed_specimens")
  expect_s3_class(removed, "data.frame")
  expect_equal(removed$specimen, target)
})

test_that("print.intrait_landmarks() reports removed_specimens when present", {
  fish <- make_fish()
  target <- dimnames(fish$coords)[[3]][1]
  out <- suppressMessages(exclude_specimens(fish, specimen = target, reason = "bad measurement"))
  expect_output(print(out), "excluded via exclude_specimens")
})
