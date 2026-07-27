# digitize_landmarks() launches the bundled landmarking Shiny app
# (shiny::runApp()); it cannot be exercised end-to-end in automated tests.
# These tests cover the console contract that runs *before* any interactive
# Shiny call is attempted -- the session validation, the resource resolution --
# plus the app file itself, which nothing else in the package would notice a
# syntax error in until an operator launched it.
#
# Note: `interactive()` reflects whether the R *session* was started
# interactively, not whether code runs inside test_that(). The tests that rely
# on reaching the `interactive()` guard therefore skip themselves (via
# `skip_if(interactive())`) when run from an interactive session, rather than
# risk actually launching the app.

# A photograph directory with one (invalid but present) image file: the launcher
# only lists names at this stage, it never decodes.
make_photo_dir <- function(codes = c("fish_01", "fish_02")) {
  d <- file.path(tempdir(), paste0("photos_", paste(sample(letters, 6), collapse = "")))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (k in codes) writeLines("not really a jpeg", file.path(d, paste0(k, ".jpg")))
  d
}

test_that("digitize_landmarks() validates `photo_dir`", {
  expect_error(digitize_landmarks(123), "single path")
  expect_error(digitize_landmarks(c("a", "b")), "single path")
  expect_error(digitize_landmarks(file.path(tempdir(), "no_such_dir_xyz")),
               "directory not found")
})

test_that("an empty photograph directory is refused", {
  d <- file.path(tempdir(), "photos_empty"); dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(digitize_landmarks(d), "No image found")
})

test_that("digitize_landmarks() validates the workbook path", {
  d <- make_photo_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(digitize_landmarks(d, xlsx_path = file.path(d, "out.csv")),
               "must end in")
  expect_error(
    digitize_landmarks(d, xlsx_path = file.path(d, "no_such_dir", "out.xlsx")),
    "directory of `xlsx_path` does not exist")
})

test_that("digitize_landmarks() validates the session parameters", {
  d <- make_photo_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(digitize_landmarks(d, mode = "reconstruct"), "should be one of")
  expect_error(digitize_landmarks(d, n_repeats = 1), "integer >= 2")
  expect_error(digitize_landmarks(d, ruler_mm = 0), "positive number")
  expect_error(digitize_landmarks(d, operator = c("AT", "GH")),
               "single character string")
  expect_error(
    digitize_landmarks(d, sheets = c(measurements = "a", bias = "a",
                                     summary = "b")),
    "distinct sheet names")
  expect_error(digitize_landmarks(d, sheets = c(measurements = "a")),
               "named measurements, bias, summary")
})

test_that("digitize_landmarks() validates the ml-morph resources", {
  d <- make_photo_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  expect_error(digitize_landmarks(d, mlmorph_dir = 123), "single path")
  expect_error(
    digitize_landmarks(d, mlmorph_dir = file.path(tempdir(), "no_such_dir_xyz")),
    "directory not found")
  expect_error(digitize_landmarks(d, predictor = "no_such_predictor.dat"),
               "file not found")
  expect_error(digitize_landmarks(d, python = "definitely_not_a_python_xyz"),
               "interpreter not found")
})

test_that("digitize_landmarks() refuses to run non-interactively", {
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("jpeg")
  testthat::skip_if_not_installed("png")
  testthat::skip_if_not_installed("writexl")
  testthat::skip_if(interactive(),
                    "cannot safely launch the Shiny app from an interactive session")
  d <- make_photo_dir(); on.exit(unlink(d, recursive = TRUE), add = TRUE)
  ml <- file.path(tempdir(), "mlm_ok"); dir.create(ml, showWarnings = FALSE)
  on.exit(unlink(ml, recursive = TRUE), add = TRUE)
  # A valid (if empty) mlmorph_dir avoids the auto-detection warning, so the
  # interactive() guard is what stops execution.
  expect_error(suppressMessages(digitize_landmarks(d, mlmorph_dir = ml)),
               "interactive")
})

## ---- the bundled app --------------------------------------------------------
app_file <- function() {
  p <- system.file("shiny", "landmarking_app", "app.R", package = "intraitR")
  if (!nzchar(p) || !file.exists(p)) testthat::skip("bundled app not installed")
  p
}
## Evaluate the app's identifier helpers -- and only those -- in a bare
## environment, so the convention they implement can be tested without starting
## Shiny (sourcing the file would call shinyApp()).
app_helpers <- function(wanted) {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(x, y) if (is.null(x)) y else x
  env$SAVE_PTS <- 1:22
  for (e in as.list(parse(app_file()))) {
    if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.name(e[[2L]]) &&
        as.character(e[[2L]]) %in% wanted) eval(e, env)
  }
  if (!all(wanted %in% ls(env)))
    testthat::skip(paste("helpers not found in app.R:",
                         paste(setdiff(wanted, ls(env)), collapse = ", ")))
  env
}

test_that("the bundled landmarking app parses", {
  expect_silent(invisible(parse(app_file())))
})

test_that("the app builds replicate identifiers the importer can parse back", {
  env <- app_helpers(c("REP_RE", "clean_operator", "make_id", "base_code",
                       "rep_of"))

  # outside repeat mode the identifier is the code itself
  expect_identical(env$make_id("T-26-0004"), "T-26-0004")
  expect_identical(env$make_id("T-26-0004", "", 2), "T-26-0004_rep2")
  expect_identical(env$make_id("T-26-0004", "AT", 2), "T-26-0004_AT_rep2")
  # an operator label is stripped of what would make the token ambiguous
  expect_identical(env$make_id("T-26-0004", "A T_1", 3), "T-26-0004_A-T-1_rep3")
  # a code reloaded from the workbook is rebuilt, never nested
  expect_identical(env$make_id("T-26-0004_rep2", "AT", 3), "T-26-0004_AT_rep3")

  ids <- c(env$make_id("T-26-0004", "AT", 1), env$make_id("T-26-0004", "AT", 2),
           env$make_id("T-26-0007", "AT", 1))
  got <- intraitR:::.parse_replicate_ids(ids, replicate = "parse",
                                         operator = "parse")
  expect_identical(got$individual, c("T-26-0004", "T-26-0004", "T-26-0007"))
  expect_identical(got$operator, rep("AT", 3))
  expect_identical(got$replicate, c(1L, 2L, 1L))

  expect_identical(env$base_code(ids, "AT"),
                   c("T-26-0004", "T-26-0004", "T-26-0007"))
  expect_identical(env$rep_of(ids), c(1L, 2L, 1L))
  expect_identical(env$base_code("T-26-0004", "AT"), "T-26-0004")
  expect_true(is.na(env$rep_of("T-26-0004")))
})

test_that("the app's workbook schema matches read_landmarks_xlsx()", {
  env <- app_helpers(c("SAVE_PTS", "EXTRA_HINGES", "WB_PTS", "WB_ID_COLS",
                       "WB_COORD_COLS", "WB_COLS", "WB_CHR_COLS", "wb_empty",
                       "wb_normalise"))
  # the wide FISHMORPH layout, "{i}_X"/"{i}_Y": 22 landmarks AND the two entry
  # hinges, which are recorded but are not part of a configuration
  expect_identical(env$WB_COORD_COLS[1:4], c("1_X", "1_Y", "2_X", "2_Y"))
  expect_identical(env$SAVE_PTS, 1:22)
  expect_identical(env$WB_PTS, c(1:22, 23L, 24L))
  expect_length(env$WB_COORD_COLS, 48L)
  expect_identical(utils::tail(env$WB_COORD_COLS, 4),
                   c("23_X", "23_Y", "24_X", "24_Y"))
  expect_true(all(c("specimen", "individual", "replicate", "operator") %in%
                    env$WB_ID_COLS))

  e <- env$wb_empty()
  expect_identical(names(e), env$WB_COLS)
  expect_equal(nrow(e), 0L)

  # a sheet from an older version (missing and extra columns) still reopens
  old <- data.frame(specimen = "fish_01", `1_X` = 10, `1_Y` = 20,
                    obsolete = "x", check.names = FALSE)
  n <- env$wb_normalise(old)
  expect_identical(names(n), env$WB_COLS)
  expect_equal(n[["1_X"]], 10)
  expect_true(is.na(n[["2_X"]]))
  expect_false("obsolete" %in% names(n))
})

test_that("bias_summary() measures the scatter of the repeats, not their level", {
  env <- app_helpers(c("bias_summary"))
  mk <- function(ind, rep, x1, y1) {
    d <- data.frame(specimen = paste0(ind, "_rep", rep), individual = ind,
                    replicate = rep, stringsAsFactors = FALSE)
    for (p in 1:22) { d[[paste0(p, "_X")]] <- NA_real_
                      d[[paste0(p, "_Y")]] <- NA_real_ }
    d[["1_X"]] <- x1; d[["1_Y"]] <- y1
    d[["2_X"]] <- 100; d[["2_Y"]] <- 0     # Bl = 100 px, whatever LM1 does
    d
  }
  # LM1 placed at x = -1, 0, +1 around 0: deviations 1, 0, 1 -> median 1 px = 1% Bl
  b <- rbind(mk("fish_01", 1, -1, 0), mk("fish_01", 2, 0, 0), mk("fish_01", 3, 1, 0))
  s <- env$bias_summary(b, 1:22)
  ov <- s[s$individual == "(all)" & s$landmark == 1, ]
  expect_equal(ov$median_dev_px, 1)
  expect_equal(ov$median_dev_pct_bl, 1)
  expect_equal(ov$n_replicates, 3)
  # LM2, identical in every repeat, has zero scatter: the summary is about
  # reproducibility, not about position
  expect_equal(s$median_dev_px[s$individual == "(all)" & s$landmark == 2], 0)
  # landmarks never placed are absent rather than reported as perfect
  expect_false(3 %in% s$landmark)
  # a single pass says nothing about reproducibility and is dropped
  expect_equal(nrow(env$bias_summary(mk("fish_02", 1, 0, 0), 1:22)), 0L)
  expect_equal(nrow(env$bias_summary(NULL)), 0L)
})

## ---- ml-morph resolution ----------------------------------------------------
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
