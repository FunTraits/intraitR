make_fishmorph_toy <- function() {
  # 4 specimens, 21 FISHMORPH landmarks (body 1-19 + scale bar 20-21):
  # specimen 1: complete, identified; specimen 2: missing landmark 5;
  # specimen 3: complete but unresolved species (NA); specimen 4: complete,
  # identified -- exercises both filtering criteria independently.
  p <- 21
  specimen_names <- paste0("s", 1:4)
  A <- array(
    as.numeric(seq_len(p * 2 * 4)), dim = c(p, 2, 4),
    dimnames = list(NULL, c("X", "Y"), specimen_names)
  )
  A[5, , 2] <- NA_real_

  landmarks <- structure(
    list(
      coords = A,
      scale = stats::setNames(rep(1, 4), specimen_names),
      metadata = data.frame(
        specimen = specimen_names,
        species = c("Species_A", "Species_A", NA_character_, "Species_B"),
        row.names = specimen_names
      )
    ),
    class = "intrait_landmarks"
  )
  landmarks
}

test_that("fishmorph_shape_landmarks() drops the scale bar and incomplete/unidentified specimens", {
  fish <- make_fishmorph_toy()
  out <- suppressMessages(fishmorph_shape_landmarks(fish))

  expect_equal(dim(out$coords)[1], 19) # scale bar (20, 21) removed
  expect_equal(dim(out$coords)[3], 2) # only s1 and s4 are complete + identified
  expect_setequal(dimnames(out$coords)[[3]], c("s1", "s4"))
  expect_equal(nrow(out$metadata), 2)
  expect_equal(length(out$scale), 2)
  expect_false(anyNA(out$coords))
})

test_that("fishmorph_shape_landmarks() reports how many specimens were dropped", {
  fish <- make_fishmorph_toy()
  expect_message(fishmorph_shape_landmarks(fish), "dropping 2 specimen")
})

test_that("fishmorph_shape_landmarks() ignores species NA when species = NULL is not from metadata", {
  fish <- make_fishmorph_toy()
  fish$metadata$species <- NULL
  out <- suppressMessages(fishmorph_shape_landmarks(fish))
  # only the missing-landmark-5 specimen (s2) is dropped now; the formerly
  # NA-species specimen (s3) is kept since species is no longer available
  expect_setequal(dimnames(out$coords)[[3]], c("s1", "s3", "s4"))
})

test_that("fishmorph_shape_landmarks() keeps every specimen when drop_incomplete = FALSE", {
  fish <- make_fishmorph_toy()
  out <- fishmorph_shape_landmarks(fish, drop_incomplete = FALSE)
  expect_equal(dim(out$coords)[3], 4)
  expect_equal(dim(out$coords)[1], 19)
  expect_true(anyNA(out$coords)) # s2's missing landmark 5 left in place
})

test_that("fishmorph_shape_landmarks() errors on invalid input", {
  expect_error(fishmorph_shape_landmarks(list()), "intrait_landmarks")

  fish <- make_fishmorph_toy()
  fish$coords <- fish$coords[1:19, , ]
  expect_error(fishmorph_shape_landmarks(fish), "21")
})
