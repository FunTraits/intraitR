# ---------------------------------------------------------------------------
# Precomputed phylogenetic PCoA axes, and the species/groups decoupling.
# ---------------------------------------------------------------------------

test_that("load_fishmorph_phylo_axes reads the bundled table", {
  ax <- load_fishmorph_phylo_axes()
  expect_s3_class(ax, "data.frame")
  expect_identical(names(ax)[1], "species")
  expect_equal(ncol(ax) - 1L, 10L)
  expect_gt(nrow(ax), 8000L)
  expect_equal(anyDuplicated(ax$species), 0L)
  expect_true(all(vapply(ax[-1], is.numeric, logical(1))))
  # names are canonical Genus_species: never a space or a dot
  expect_false(any(grepl("[ .]", ax$species)))
  # axes are ordered by decreasing eigenvalue, hence decreasing variance
  sds <- vapply(ax[-1], stats::sd, numeric(1))
  expect_true(all(diff(sds) < 1e-8))
})

test_that("k truncates and the session cache is consistent", {
  expect_equal(ncol(load_fishmorph_phylo_axes(k = 3)), 4L)
  expect_equal(ncol(load_fishmorph_phylo_axes(k = 99)), 11L)   # capped at 10
  expect_identical(load_fishmorph_phylo_axes(),
                   load_fishmorph_phylo_axes(refresh = TRUE))
})

test_that("axes are broadcast per ROW, from the precomputed table", {
  sp <- c("Coilia.nasus", "Aaptosyax grypus", "Coilia_nasus", NA, "No.suchfish")
  pax <- intraitR:::.phylo_axes_for_species(sp, k_phylo = 4)
  expect_equal(pax$source, "precomputed axis table")
  expect_equal(pax$k_used, 4L)
  expect_equal(nrow(pax$axes), length(sp))      # one row per element
  # dot / space / underscore are interchangeable: same species, same axes
  expect_equal(pax$axes[1, ], pax$axes[3, ], ignore_attr = TRUE)
  expect_true(all(is.na(pax$axes[5, ])))        # unknown species -> NA, not error
  expect_equal(pax$n_matched, 2L)
})

test_that("no species at all is reported as such, not as a missing `groups`", {
  none <- intraitR:::.phylo_axes_for_species(NULL)
  expect_null(none$axes)
  expect_match(none$reason, "species")
  expect_false(grepl("groups", none$reason))
})

test_that("an explicit axis table wins; a malformed one is reported", {
  fake <- data.frame(species = c("Coilia_nasus", "Aaptosyax_grypus"),
                     a = c(1, 2), b = c(3, 4))
  pax <- intraitR:::.phylo_axes_for_species(c("Coilia.nasus", "Aaptosyax.grypus"),
                                            k_phylo = 10, axes = fake)
  expect_equal(pax$source, "supplied axis table")
  expect_equal(pax$k_used, 2L)                  # capped at the columns available
  expect_equal(unname(pax$axes[[1]]), c(1, 2))

  bad <- intraitR:::.phylo_axes_for_species("Coilia.nasus",
                                             axes = data.frame(x = 1))
  expect_null(bad$axes)
  expect_match(bad$reason, "species")
})

test_that("missforest_phylo needs no `groups` (species come from the data)", {
  skip_if_not_installed("missForest")
  set.seed(1)
  ax <- load_fishmorph_phylo_axes()
  df <- data.frame(species = ax$species[1:60],
                   t1 = rnorm(60), t2 = rnorm(60), t3 = rnorm(60))
  df$t1[1:5] <- NA; df$t2[6:8] <- NA
  # No `groups` anywhere: `species` is detected on its own and only used as the
  # key to cbind the phylogenetic axes. That is all missforest_phylo requires.
  expect_warning(
    ts <- trait_space(df, na_action = "missforest_phylo", log_transform = FALSE),
    regexp = NA)
  expect_false(anyNA(ts$scores[, 1:2]))
})

test_that("a groups factor with too many levels is dropped, not fatal", {
  skip_if_not_installed("missForest")
  set.seed(2)
  ax <- load_fishmorph_phylo_axes()
  df <- data.frame(species = ax$species[1:60],
                   t1 = rnorm(60), t2 = rnorm(60), t3 = rnorm(60))
  df$t1[1:3] <- NA
  # 60 distinct species: randomForest refuses more than 53 categories, so the
  # factor is dropped with a warning rather than making missForest fail.
  expect_warning(
    trait_space(df, groups = df$species, na_action = "missforest",
                log_transform = FALSE),
    "53 categories")
})
