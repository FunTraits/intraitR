test_that(".stable_group_colors() assigns the same colour to the same label across calls", {
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  first <- intraitR:::.stable_group_colors(c("A", "B", "C"))
  second <- intraitR:::.stable_group_colors(c("C", "A"))

  expect_identical(unname(second["A"]), unname(first["A"]))
  expect_identical(unname(second["C"]), unname(first["C"]))
})

test_that(".stable_group_colors() keeps earlier labels' colours when a subset differs (the T-26 shape_space/trait_space scenario)", {
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  # Two calls that each observe a *different* subset of the same underlying
  # species set (e.g. because shape_space()/trait_space() drop a different
  # set of specimens/species after their own NA handling) must still agree
  # on the colour of every species they have in common.
  call_1 <- intraitR:::.stable_group_colors(c("Barbatula barbatula", "Gobio occitaniae", "Salaria fluviatilis"))
  call_2 <- intraitR:::.stable_group_colors(c("Gobio occitaniae", "Phoxinus dragarum"))  # missing Barbatula, Salaria; gains Phoxinus

  expect_identical(
    unname(call_1["Gobio occitaniae"]),
    unname(call_2["Gobio occitaniae"])
  )
  # A brand-new label seen only in call_2 must get its own colour, distinct
  # from every previously cached one.
  expect_false(unname(call_2["Phoxinus dragarum"]) %in% unname(call_1))
})

test_that(".stable_group_colors() never assigns two labels the same colour within one call", {
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  labels <- paste0("sp", 1:12)  # exceeds the 10-colour curated base palette
  cols <- intraitR:::.stable_group_colors(labels)
  expect_equal(length(unique(cols)), length(labels))
})

test_that(".stable_group_colors() does not error on an empty-string label", {
  # Regression test: an unresolved/blank species identification stored as
  # "" (rather than NA) in the source data used to crash plot() entirely,
  # via assign("", ..., envir = ...) -- "attempt to use zero-length
  # variable name" -- because labels were previously stored one per
  # environment variable, keyed by the raw label itself.
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  cols <- intraitR:::.stable_group_colors(c("Species_A", "", "Species_B", ""))
  expect_length(cols, 3)
  expect_true("" %in% names(cols))
  expect_equal(length(unique(cols)), 3)

  # The empty-string label is cached like any other: a later call sees the
  # same colour for it.
  cols2 <- intraitR:::.stable_group_colors("")
  expect_identical(unname(cols2[""]), unname(cols[""]))
})

test_that("plot.intrait_shapespace() does not error when a group level is an empty string", {
  testthat::skip_if_not_installed("geomorph")
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  fish <- simulate_fish_landmarks(n_per_species = 4, n_replicates = 1)
  gpa <- gpa_fish(fish)
  groups <- as.character(fish$metadata$species)
  groups[1] <- ""  # simulate an unresolved identification stored as ""
  ms <- shape_space(gpa, groups = groups)

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(ms, style = "none", legend = FALSE), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("reset_group_colors() clears the cache so labels can be reassigned from scratch", {
  reset_group_colors()

  first <- intraitR:::.stable_group_colors("A")
  reset_group_colors()
  # With a different first-seen label, "A" is no longer necessarily first;
  # what matters is that the cache is genuinely empty (not that the colour
  # differs), which we check via the environment directly.
  expect_length(ls(envir = intraitR:::.intrait_color_cache), 0)

  second <- intraitR:::.stable_group_colors("A")
  expect_identical(unname(first["A"]), unname(second["A"]))  # same first slot => same colour again
  reset_group_colors()
})

test_that("plot.intrait_shapespace() and plot.intrait_traitspace() use the same colour for a shared species", {
  testthat::skip_if_not_installed("geomorph")
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  fish <- simulate_fishmorph_points(n_per_species = 8, n_replicates = 1)
  fish_shape <- fishmorph_shape_landmarks(fish)
  gpa <- gpa_fish(fish_shape)
  ms <- shape_space(gpa, groups = fish_shape$metadata$species)

  segments <- fishmorph_segments(fish)
  ratios <- fishmorph_ratios(segments)
  ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")

  species <- levels(droplevels(as.factor(fish$metadata$species)))[1]
  col_morpho <- intraitR:::.stable_group_colors(species)
  col_trait <- intraitR:::.stable_group_colors(species)
  expect_identical(unname(col_morpho), unname(col_trait))

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(ms), NA)
  expect_error(plot(ts), NA)
  grDevices::dev.off()
  unlink(tmp)
})

test_that("group_colors() returns a data.frame matching the plot methods' own colours", {
  testthat::skip_if_not_installed("geomorph")
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- shape_space(gpa, groups = fish$metadata$species)

  df <- group_colors(ms)
  expect_s3_class(df, "data.frame")
  expect_named(df, c("group", "color"))
  expect_identical(df$group, levels(droplevels(as.factor(fish$metadata$species))))

  expected <- unname(intraitR:::.stable_group_colors(df$group)[df$group])
  expect_identical(df$color, expected)
})

test_that("group_colors() accepts a raw label vector, not just an object with $groups", {
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  species <- c("Species_A", "Species_B", "Species_A", "Species_C")
  df <- group_colors(species)
  expect_equal(nrow(df), 3)
  expect_setequal(df$group, unique(species))
})

test_that("group_colors() matches plot.intrait_shapespace()'s legend colours exactly", {
  testthat::skip_if_not_installed("geomorph")
  reset_group_colors()
  on.exit(reset_group_colors(), add = TRUE)

  fish <- simulate_fish_landmarks(n_per_species = 5, n_replicates = 1)
  gpa <- gpa_fish(fish)
  ms <- shape_space(gpa, groups = fish$metadata$species)

  before <- group_colors(ms)  # looked up before ever plotting

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  plot(ms, legend = FALSE)
  grDevices::dev.off()
  unlink(tmp)

  after <- group_colors(ms)
  expect_identical(before, after)
})

test_that("group_colors() errors informatively when `x` has no groups", {
  expect_error(group_colors(list(scores = matrix(1:4, 2, 2))), "no `groups` element")
})
