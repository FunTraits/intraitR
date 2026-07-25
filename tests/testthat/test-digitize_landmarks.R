# digitize_landmarks() now launches the bundled ml-morph landmarking Shiny
# app (shiny::runApp()); it cannot be exercised end-to-end in automated
# tests. These tests cover the argument validation and resource resolution
# that happen *before* any interactive Shiny call is attempted.
#
# Note: `interactive()` reflects whether the R *session* was started
# interactively, not whether code runs inside test_that(). The tests that
# rely on reaching the `interactive()` guard therefore skip themselves (via
# `skip_if(interactive())`) when run from an interactive session, rather
# than risk actually launching the app.

test_that("digitize_landmarks() validates `mlmorph_dir`", {
  expect_error(digitize_landmarks(mlmorph_dir = 123), "single directory path")
  expect_error(digitize_landmarks(mlmorph_dir = c("a", "b")), "single directory path")
  expect_error(
    digitize_landmarks(mlmorph_dir = file.path(tempdir(), "no_such_dir_xyz")),
    "directory not found"
  )
})

test_that("digitize_landmarks() validates `predictor`", {
  d <- file.path(tempdir(), "mlm_ok"); dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(
    digitize_landmarks(mlmorph_dir = d, predictor = 1L),
    "single file path"
  )
  expect_error(
    digitize_landmarks(mlmorph_dir = d, predictor = "no_such_predictor.dat"),
    "file not found"
  )
})

test_that("digitize_landmarks() validates `python` and `autosave`", {
  d <- file.path(tempdir(), "mlm_ok2"); dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(
    digitize_landmarks(mlmorph_dir = d, python = "definitely_not_a_python_xyz"),
    "interpreter not found"
  )
  expect_error(
    digitize_landmarks(mlmorph_dir = d, autosave = 42),
    "single file path"
  )
})

test_that("digitize_landmarks() refuses to run non-interactively", {
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("jpeg")
  testthat::skip_if_not_installed("png")
  testthat::skip_if(
    interactive(),
    "cannot safely launch the Shiny app from an interactive R session"
  )
  d <- file.path(tempdir(), "mlm_ok3"); dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  # A valid (if empty) mlmorph_dir avoids the auto-detection warning so the
  # interactive() guard is what stops execution.
  expect_error(
    digitize_landmarks(mlmorph_dir = d),
    "interactive"
  )
})

test_that(".resolve_mlmorph_dir() honours an explicit path unchanged", {
  d <- file.path(tempdir(), "mlm_explicit"); dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_identical(
    normalizePath(intraitR:::.resolve_mlmorph_dir(d), mustWork = FALSE),
    normalizePath(d, mustWork = FALSE)
  )
})

test_that(".resolve_mlmorph_dir() honours INTRAITR_MLMORPH_DIR", {
  d <- file.path(tempdir(), "mlm_env"); dir.create(d, showWarnings = FALSE)
  old <- Sys.getenv("INTRAITR_MLMORPH_DIR", unset = NA)
  Sys.setenv(INTRAITR_MLMORPH_DIR = d)
  on.exit({
    unlink(d, recursive = TRUE)
    if (is.na(old)) Sys.unsetenv("INTRAITR_MLMORPH_DIR")
    else Sys.setenv(INTRAITR_MLMORPH_DIR = old)
  }, add = TRUE)

  expect_identical(
    normalizePath(intraitR:::.resolve_mlmorph_dir(NULL), mustWork = FALSE),
    normalizePath(d, mustWork = FALSE)
  )
})

test_that(".resolve_mlmorph_dir() auto-detects an ml_morph/ subdirectory by marker", {
  parent <- file.path(tempdir(), "mlm_parent"); dir.create(parent, showWarnings = FALSE)
  sub    <- file.path(parent, "ml_morph");      dir.create(sub, showWarnings = FALSE)
  # A directory "looks like" ml-morph when it holds the worker script.
  writeLines("# worker", file.path(sub, "predict_new_image.py"))

  old <- Sys.getenv("INTRAITR_MLMORPH_DIR", unset = NA)
  Sys.unsetenv("INTRAITR_MLMORPH_DIR")
  old_wd <- getwd(); setwd(parent)
  on.exit({
    setwd(old_wd); unlink(parent, recursive = TRUE)
    if (!is.na(old)) Sys.setenv(INTRAITR_MLMORPH_DIR = old)
  }, add = TRUE)

  expect_identical(
    normalizePath(intraitR:::.resolve_mlmorph_dir(NULL), mustWork = FALSE),
    normalizePath(sub, mustWork = FALSE)
  )
})

test_that(".resolve_mlmorph_dir() returns NULL when nothing looks like ml-morph", {
  parent <- file.path(tempdir(), "mlm_none"); dir.create(parent, showWarnings = FALSE)
  sub    <- file.path(parent, "work");        dir.create(sub, showWarnings = FALSE)

  old <- Sys.getenv("INTRAITR_MLMORPH_DIR", unset = NA)
  Sys.unsetenv("INTRAITR_MLMORPH_DIR")
  old_wd <- getwd(); setwd(sub)   # no ml_morph/ here or in the parent, no markers
  on.exit({
    setwd(old_wd); unlink(parent, recursive = TRUE)
    if (!is.na(old)) Sys.setenv(INTRAITR_MLMORPH_DIR = old)
  }, add = TRUE)

  expect_null(intraitR:::.resolve_mlmorph_dir(NULL))
})
