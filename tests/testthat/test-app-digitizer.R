# =============================================================================
# The digitizer as an operator uses it, without a browser: shiny::testServer()
# runs the server of inst/shiny/landmarking_app on a real session (photographs,
# journal, workbook in a temporary folder) and the test plays the inputs the
# interface would send.
#
# What the browser itself does is NOT covered here (the canvas, the keyboard
# handler that turns Enter into `kb_enter`, the echo of updateTextInput()); the
# test supplies those inputs by hand.
# =============================================================================

app_session <- function(n_photos = 2L) {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("shiny")
  testthat::skip_if_not_installed("magick")
  testthat::skip_if_not_installed("writexl")
  d <- tempfile("digapp_")
  dir.create(file.path(d, "photos"), recursive = TRUE)
  for (k in seq_len(n_photos))
    magick::image_write(magick::image_blank(400, 200, "grey"),
                        file.path(d, "photos", sprintf("fish_%02d.jpg", k)))
  cfg <- list(photo_dir = file.path(d, "photos"), photos = character(0),
              xlsx_path = file.path(d, "landmarks.xlsx"),
              journal_dir = file.path(d, "journal"), operator = "AT",
              mode = "new", ruler_mm = 10, display = "canvas")
  # the app reads its configuration when it is LOADED: the option comes first,
  # and stays for the duration of the calling test
  withr::local_options(intraitR.digitizer = cfg, .local_envir = parent.frame())
  list(dir = d, cfg = cfg,
       app = shiny::shinyAppDir(system.file("shiny", "landmarking_app",
                                            package = "intraitR")))
}

# A plausible configuration: axis 1-2 clicked, the rest seeded at the median
# FISHMORPH proportions (the state after a prediction), ruler 20-21 placed.
predicted_fish <- function() {
  P <- empty_coords(); P[1, ] <- c(40, 100); P[2, ] <- c(340, 100)
  P <- seed_configuration(P)
  P[20, ] <- c(20, 180); P[21, ] <- c(120, 180)
  P
}


test_that("Enter validates the prediction, journals the specimen and moves on", {
  s <- app_session(); on.exit(unlink(s$dir, recursive = TRUE), add = TRUE)
  P <- predicted_fish()
  suppressMessages(shiny::testServer(s$app, {
    session$setInputs(session_mode = "new")
    expect_equal(rv$photo, "fish_01")
    session$setInputs(specimen_id = rv$photo)     # the echo of updateTextInput()
    rv$pred <- P
    session$setInputs(kb_enter = 1)
    expect_equal(rv$photo, "fish_02")             # next photograph
  }))
  j <- landmark_journal_read(s$cfg$journal_dir)
  expect_setequal(unique(j$specimen), "fish_01")
  expect_false(any(j$status %in% c("predicted", "seeded")))  # all looked at
  expect_true(any(j$status == "validated"))
  expect_equal(j$x[j$landmark == 2], 340)
})

test_that("the Validate button marks the points without saving", {
  s <- app_session(); on.exit(unlink(s$dir, recursive = TRUE), add = TRUE)
  P <- predicted_fish()
  suppressMessages(shiny::testServer(s$app, {
    session$setInputs(session_mode = "new", specimen_id = "fish_01")
    rv$pred <- P
    expect_true(any(point_status(intraitR:::WB_PTS) == "predicted"))
    session$setInputs(validate_pts = 1)
    expect_false(any(point_status(intraitR:::WB_PTS) == "predicted"))
    expect_equal(rv$photo, "fish_01")             # still on the same photograph
  }))
  expect_equal(nrow(landmark_journal_read(s$cfg$journal_dir)), 0L)
})

test_that("saving a photograph with nothing placed writes nothing", {
  s <- app_session(); on.exit(unlink(s$dir, recursive = TRUE), add = TRUE)
  P <- predicted_fish()
  suppressMessages(shiny::testServer(s$app, {
    session$setInputs(session_mode = "new", specimen_id = "fish_01")
    session$setInputs(save_specimen = 1)
    expect_equal(rv$photo, "fish_01")
  }))
  expect_equal(nrow(landmark_journal_read(s$cfg$journal_dir)), 0L)
})

test_that("the Save button writes the workbook now, with the saved specimen", {
  testthat::skip_if_not_installed("readxl")
  s <- app_session(); on.exit(unlink(s$dir, recursive = TRUE), add = TRUE)
  P <- predicted_fish()
  suppressMessages(shiny::testServer(s$app, {
    session$setInputs(session_mode = "new", specimen_id = "fish_01")
    rv$pred <- P
    session$setInputs(kb_enter = 1)
    session$setInputs(flush_top = 1)
    expect_equal(rv$pending, 0L)
  }))
  expect_true(file.exists(s$cfg$xlsx_path))
  wb <- readxl::read_excel(s$cfg$xlsx_path, sheet = "measurements")
  expect_true("fish_01" %in% wb$specimen)
})

test_that("Undo puts back the whole state before a move, Redo replays it", {
  s <- app_session(); on.exit(unlink(s$dir, recursive = TRUE), add = TRUE)
  P <- predicted_fish()
  suppressMessages(shiny::testServer(s$app, {
    session$setInputs(session_mode = "new", specimen_id = "fish_01")
    rv$pred <- P
    session$flushReact()
    before <- rv$pred
    rv$sel <- 5L
    session$setInputs(click = list(x = before[5, 1] + 15, y = before[5, 2] + 4))
    moved <- rv$pred
    expect_false(identical(moved[5, ], before[5, ]))
    session$setInputs(kb_undo = 1)
    expect_equal(rv$pred, before)                 # every point, not only LM5
    expect_false(5L %in% rv$edited)
    expect_equal(rv$sel, 5L)                      # the point undone is active again
    session$setInputs(kb_redo = 1)
    expect_equal(rv$pred, moved)
    # a new change after an undo drops the redo branch
    session$setInputs(undo = 1)
    rv$sel <- 6L
    session$setInputs(click = list(x = before[6, 1] + 10, y = before[6, 2]))
    n <- rv$pred
    session$setInputs(redo = 1)                   # nothing to redo
    expect_equal(rv$pred, n)
  }))
})

test_that("Undo steps back through hand-placed points, and stops at the photograph", {
  s <- app_session(); on.exit(unlink(s$dir, recursive = TRUE), add = TRUE)
  suppressMessages(shiny::testServer(s$app, {
    session$setInputs(session_mode = "new", specimen_id = "fish_01")
    empty <- rv$pred
    rv$sel <- 1L; session$setInputs(click = list(x = 40, y = 100))
    rv$sel <- 2L; session$setInputs(click = list(x = 340, y = 100))
    expect_true(all(is.finite(rv$pred[1:2, ])))
    session$setInputs(kb_undo = 1)
    expect_true(all(is.finite(rv$pred[1, ])) && all(is.na(rv$pred[2, ])))
    session$setInputs(kb_undo = 2)
    expect_true(all(is.na(rv$pred[1:2, ])))
    session$setInputs(kb_undo = 3)                # nothing older: stays as is
    expect_false(is.null(rv$pred))
    # another photograph starts a new history
    rv$sel <- 1L; session$setInputs(click = list(x = 40, y = 100))
    session$setInputs(next_photo = 1)
    expect_equal(rv$photo, "fish_02")
    p2 <- rv$pred
    session$setInputs(kb_undo = 4)                # fish_01's clicks are not undone here
    expect_equal(rv$pred, p2)
  }))
})
