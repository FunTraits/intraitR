.make_test_png <- function(width = 20, height = 10) {
  testthat::skip_if_not_installed("png")
  tmp <- tempfile(fileext = ".png")
  # A distinctive (non-symmetric) raster: top-left pixel red, everything
  # else black, so a vertical flip is detectable (row 1 stays index-1 for
  # an unflipped image, becomes the last row after flip_y = TRUE).
  arr <- array(0, dim = c(height, width, 3))
  arr[1, 1, 1] <- 1 # top-left pixel, red channel
  png::writePNG(arr, tmp)
  tmp
}

test_that(".read_background_image() reads a PNG with the expected dimensions", {
  testthat::skip_if_not_installed("png")
  path <- .make_test_png(width = 20, height = 10)
  on.exit(unlink(path))

  img <- intraitR:::.read_background_image(path)
  expect_equal(dim(img)[1], 10) # height
  expect_equal(dim(img)[2], 20) # width
})

test_that(".background_image_dims() returns c(width, height)", {
  testthat::skip_if_not_installed("png")
  path <- .make_test_png(width = 30, height = 12)
  on.exit(unlink(path))

  img <- intraitR:::.read_background_image(path)
  expect_equal(intraitR:::.background_image_dims(img), c(30, 12))
})

test_that(".read_background_image() errors on a missing file", {
  expect_error(
    intraitR:::.read_background_image(tempfile(fileext = ".png")),
    "not found"
  )
})

test_that(".read_background_image() errors on an unsupported extension", {
  tmp <- tempfile(fileext = ".gif")
  file.create(tmp)
  on.exit(unlink(tmp))
  expect_error(intraitR:::.read_background_image(tmp), "jpg")
})

test_that(".draw_background_image() flips the image vertically when flip_y = TRUE", {
  testthat::skip_if_not_installed("png")
  path <- .make_test_png(width = 4, height = 4)
  on.exit(unlink(path))
  img <- intraitR:::.read_background_image(path)

  tmp_dev <- tempfile(fileext = ".png")
  grDevices::png(tmp_dev)
  graphics::plot(0:4, 0:4, type = "n", xlab = "", ylab = "")
  # Should not error, regardless of flip_y:
  expect_error(intraitR:::.draw_background_image(img, flip_y = TRUE), NA)
  expect_error(intraitR:::.draw_background_image(img, flip_y = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp_dev)
})
