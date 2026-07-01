# digitize_landmarks() wraps geomorph::digitize2d(), which requires a real
# interactive graphics device and human point-and-click input; it cannot
# be exercised end-to-end in automated tests. These tests instead cover
# the argument validation that happens *before* any interactive call is
# attempted.
#
# Note: `interactive()` reflects whether the R *session* itself was
# started interactively, not whether code is running inside test_that().
# Tests that rely on digitize_landmarks() reaching its `interactive()`
# guard therefore skip themselves (via `skip_if(interactive())`) when run
# from an interactive session (e.g. `devtools::test()` in RStudio),
# rather than risk falling through to a real call to
# geomorph::digitize2d() against a placeholder (non-image) file.

test_that("digitize_landmarks() validates `images`", {
  expect_error(digitize_landmarks(character(0), tpsfile = tempfile()), "non-empty character vector")
  expect_error(digitize_landmarks(123, tpsfile = tempfile()), "non-empty character vector")
  expect_error(
    digitize_landmarks("no_such_file.jpg", tpsfile = tempfile()),
    "not found"
  )
})

test_that("digitize_landmarks() requires `tpsfile`", {
  img <- tempfile(fileext = ".jpg")
  writeLines("not a real image, just needs to exist", img)
  on.exit(unlink(img))

  expect_error(digitize_landmarks(img), "tpsfile.*required|required.*tpsfile")
  expect_error(digitize_landmarks(img, tpsfile = NULL), "tpsfile.*required|required.*tpsfile")
})

test_that("digitize_landmarks() validates `n_landmarks` for scheme = 'generic'", {
  img <- tempfile(fileext = ".jpg")
  writeLines("placeholder", img)
  on.exit(unlink(img))

  expect_error(
    digitize_landmarks(img, scheme = "generic", tpsfile = tempfile()),
    "n_landmarks.*at least 3"
  )
  expect_error(
    digitize_landmarks(img, scheme = "generic", n_landmarks = 2, tpsfile = tempfile()),
    "n_landmarks.*at least 3"
  )
})

test_that("digitize_landmarks() warns if n_landmarks is set with scheme = 'fishmorph'", {
  testthat::skip_if_not_installed("geomorph")
  testthat::skip_if(
    interactive(),
    "cannot safely exercise the interactive digitizing path from an interactive R session"
  )
  img <- tempfile(fileext = ".jpg")
  writeLines("placeholder", img)
  on.exit(unlink(img))

  # Non-interactively, digitize_landmarks() warns about the ignored
  # `n_landmarks` and then stops at its interactive() guard; the stop is
  # swallowed here to isolate and test the warning alone.
  expect_warning(
    tryCatch(
      digitize_landmarks(img, scheme = "fishmorph", n_landmarks = 12, tpsfile = tempfile()),
      error = function(e) NULL
    ),
    "n_landmarks.*is ignored"
  )
})

test_that("digitize_landmarks() refuses to run non-interactively", {
  testthat::skip_if_not_installed("geomorph")
  testthat::skip_if(
    interactive(),
    "cannot safely exercise the interactive digitizing path from an interactive R session"
  )
  img <- tempfile(fileext = ".jpg")
  writeLines("placeholder", img)
  on.exit(unlink(img))

  expect_error(
    digitize_landmarks(img, scheme = "fishmorph", tpsfile = tempfile()),
    "interactive"
  )
})
