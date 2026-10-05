test_that("plot_fishmorph_shapes() selects a species and runs without error", {
  fish <- simulate_fishmorph_points(n_per_species = 4, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  result <- plot_fishmorph_shapes(fish, species = "Species_A")
  grDevices::dev.off()
  unlink(tmp)

  expect_type(result, "list")
  expect_length(result, 4)
  expect_true(all(vapply(result, function(m) all(dim(m) == c(21, 2)), logical(1))))
})

test_that("plot_fishmorph_shapes() selects an explicit vector of individuals", {
  fish <- simulate_fishmorph_points(n_per_species = 5, n_replicates = 1)
  some <- fish$metadata$individual[1:3]

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  result <- plot_fishmorph_shapes(fish, individuals = some)
  grDevices::dev.off()
  unlink(tmp)

  expect_length(result, 3)
})

test_that("plot_fishmorph_shapes() requires exactly one of species/individuals", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  expect_error(plot_fishmorph_shapes(fish), "exactly one of")
  expect_error(
    plot_fishmorph_shapes(fish, species = "Species_A", individuals = "x"),
    "exactly one of"
  )
})

test_that("plot_fishmorph_shapes() errors below 21 landmarks", {
  A <- array(0, dim = c(10, 2, 1))
  expect_error(plot_fishmorph_shapes(A, individuals = "specimen_1"), "at least 21 landmarks")
})

test_that("plot_fishmorph_shapes() errors for an unknown species, listing available ones", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)
  expect_error(
    plot_fishmorph_shapes(fish, species = "Not_A_Species"),
    "Available species"
  )
})

test_that("plot_fishmorph_shapes() warns but still plots when some individuals are unmatched", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)
  some <- c(fish$metadata$individual[1], "not_a_real_individual")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_warning(
    result <- plot_fishmorph_shapes(fish, individuals = some),
    "not found"
  )
  grDevices::dev.off()
  unlink(tmp)

  expect_length(result, 1)
})

test_that("plot_fishmorph_shapes(align = TRUE) centres and unit-scales each specimen", {
  fish <- simulate_fishmorph_points(n_per_species = 3, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  result <- plot_fishmorph_shapes(fish, species = "Species_A", align = TRUE)
  grDevices::dev.off()
  unlink(tmp)

  body_pts <- 1:19
  for (xy in result) {
    centroid <- colMeans(xy[body_pts, , drop = FALSE])
    expect_equal(unname(centroid), c(0, 0), tolerance = 1e-6)
    csize <- sqrt(sum(xy[body_pts, , drop = FALSE]^2))
    expect_equal(csize, 1, tolerance = 1e-6)
  }
})

test_that("plot_fishmorph_shapes(align = FALSE) leaves coordinates untouched", {
  fish <- simulate_fishmorph_points(n_per_species = 2, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  result <- plot_fishmorph_shapes(fish, species = "Species_A", align = FALSE)
  grDevices::dev.off()
  unlink(tmp)

  A <- intraitR:::.get_coords(fish)
  idx <- which(as.character(fish$metadata$species) == "Species_A")
  expect_equal(unname(result[[1]]), unname(A[, , idx[1]]))
})

test_that("plot_fishmorph_shapes() colours by a metadata column and by specimen without error", {
  fish <- simulate_fishmorph_points(n_per_species = 4, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  by_pop <- plot_fishmorph_shapes(fish, species = "Species_A", color_by = "population")
  by_spec <- plot_fishmorph_shapes(fish, species = "Species_A", color_by = "specimen")
  grDevices::dev.off()
  unlink(tmp)

  # colouring is purely cosmetic: the returned coordinates are unchanged
  expect_length(by_pop, 4)
  expect_length(by_spec, 4)
})

test_that("plot_fishmorph_shapes() reverts to a single colour past max_colors, with a message", {
  fish <- simulate_fishmorph_points(n_per_species = 4, n_replicates = 1)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_message(
    plot_fishmorph_shapes(fish, species = "Species_A", color_by = "specimen", max_colors = 3),
    "reverting to a single colour"
  )
  grDevices::dev.off()
  unlink(tmp)
})

test_that("plot_fishmorph_shapes() validates the colouring arguments", {
  fish <- simulate_fishmorph_points(n_per_species = 4, n_replicates = 1)

  # operator = TRUE and color_by are mutually exclusive
  expect_error(
    plot_fishmorph_shapes(fish, species = "Species_A", operator = TRUE, color_by = "population"),
    "not both"
  )
  # a colouring vector must have one value per plotted specimen (4 here)
  expect_error(
    plot_fishmorph_shapes(fish, species = "Species_A", color_by = c("a", "b")),
    "one value per plotted specimen"
  )
  # an unknown column name is rejected with an informative message
  expect_error(
    plot_fishmorph_shapes(fish, species = "Species_A", color_by = "not_a_column"),
    "neither .* nor a column"
  )
})
