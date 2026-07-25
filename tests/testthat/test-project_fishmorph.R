traits9 <- c("REs", "VEp", "RMl", "OGp", "BEl", "BLs", "PFv", "PFs", "CPt")

make_reference <- function(n = 60, seed = 1) {
  set.seed(seed)
  m <- matrix(runif(n * length(traits9), 0.05, 0.9), nrow = n)
  colnames(m) <- traits9
  df <- as.data.frame(m)
  rownames(df) <- paste0("ref", seq_len(n))
  df
}

test_that("a specimen equal to a reference row projects onto that row (frozen PCA)", {
  ref <- make_reference()
  # specimens = first 3 reference rows, already on the (log) reference scale
  sp <- ref[1:3, traits9]
  sp$species <- c("A", "A", "B")

  proj <- project_fishmorph(
    sp, reference = ref,
    reference_prelogged = TRUE, specimens_prelogged = TRUE
  )

  expect_s3_class(proj, "intrait_fishmorph_projection")
  expect_equal(nrow(proj$scores), 3)
  expect_equal(proj$n_reference, nrow(ref))
  # each projected specimen must coincide with its reference row's own score
  for (id in rownames(sp)) {
    expect_equal(as.numeric(proj$scores[id, ]),
                 as.numeric(proj$global_scores[id, ]),
                 tolerance = 1e-8)
  }
})

test_that("log10(x + 1) transform of raw specimens reproduces the prelogged score", {
  ref <- make_reference(seed = 2)
  # raw specimen whose log10(x + 1) equals reference row 5 exactly
  raw <- 10^as.numeric(ref[5, traits9]) - 1
  sp <- as.data.frame(matrix(raw, nrow = 1, dimnames = list("s1", traits9)))
  sp$species <- "A"

  proj <- project_fishmorph(
    sp, reference = ref,
    reference_prelogged = TRUE, specimens_prelogged = FALSE, log_transform = TRUE
  )
  expect_equal(as.numeric(proj$scores["s1", ]),
               as.numeric(proj$global_scores["ref5", ]),
               tolerance = 1e-8)
})

test_that("variance explained matches a direct prcomp on the reference", {
  ref <- make_reference(seed = 3)
  sp <- ref[1:2, traits9]; sp$species <- c("A", "B")
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  pca <- prcomp(as.matrix(ref[traits9]), center = TRUE, scale. = TRUE)
  ve <- (pca$sdev^2 / sum(pca$sdev^2))[1:2] * 100
  expect_equal(unname(proj$var_explained), unname(ve), tolerance = 1e-8)
})

test_that("select_species and select_specimens filter the projected specimens", {
  ref <- make_reference(seed = 4)
  sp <- ref[1:6, traits9]
  sp$species <- rep(c("A", "B", "C"), each = 2)

  p_sp <- project_fishmorph(sp, reference = ref, select_species = c("A", "C"),
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  expect_setequal(levels(p_sp$groups), c("A", "C"))
  expect_equal(nrow(p_sp$scores), 4)

  p_id <- project_fishmorph(sp, reference = ref,
                            select_specimens = c("ref1", "ref2"),
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  expect_equal(sort(rownames(p_id$scores)), c("ref1", "ref2"))
})

test_that("na_action handles specimens with missing trait values", {
  ref <- make_reference(seed = 5)
  sp <- ref[1:3, traits9]; sp$species <- "A"
  sp[2, "BEl"] <- NA

  expect_message(
    p <- project_fishmorph(sp, reference = ref, na_action = "omit",
                           reference_prelogged = TRUE, specimens_prelogged = TRUE),
    "omit"
  )
  expect_equal(nrow(p$scores), 2)
  expect_error(
    project_fishmorph(sp, reference = ref, na_action = "fail",
                      reference_prelogged = TRUE, specimens_prelogged = TRUE),
    "missing"
  )
})

test_that("informative errors on missing trait columns and empty selections", {
  ref <- make_reference(seed = 6)
  sp <- ref[1:2, traits9]; sp$species <- c("A", "B")
  expect_error(
    project_fishmorph(sp, reference = ref[setdiff(names(ref), "BEl")]),
    "missing trait column"
  )
  expect_error(
    project_fishmorph(sp, reference = ref, select_species = "Z",
                      reference_prelogged = TRUE, specimens_prelogged = TRUE),
    "No specimens left"
  )
})

test_that("all plot styles run without error and return the object invisibly", {
  ref <- make_reference(seed = 7)
  sp <- ref[1:12, traits9]
  sp$species <- rep(c("A", "B"), each = 6)
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)

  grDevices::pdf(file = tempfile(fileext = ".pdf"))
  on.exit(grDevices::dev.off(), add = TRUE)
  for (st in c("points", "hull", "spider", "density")) {
    expect_invisible(plot(proj, style = st))
  }
  # background can be turned off, and a subset selected, without error
  expect_invisible(plot(proj, style = "hull", background = FALSE,
                        select_species = "A"))
})

test_that("global_species is stored aligned to global_scores", {
  ref <- make_reference(seed = 8)
  sp <- ref[1:4, traits9]; sp$species <- c("A", "A", "B", "B")
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  expect_length(proj$global_species, nrow(proj$global_scores))
  # no "Species" column in make_reference(), so labels fall back to rownames
  expect_identical(proj$global_species, rownames(proj$global_scores))
})

test_that("a Species column supplies the reference labels", {
  ref <- make_reference(seed = 8)
  ref$Species <- paste("Genus", seq_len(nrow(ref)))
  sp <- ref[1:4, traits9]; sp$species <- c("A", "A", "B", "B")
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  expect_identical(proj$global_species, ref$Species)
})

test_that("reference density / points toggles and itv_reference run", {
  ref <- make_reference(seed = 8)
  sp <- ref[1:12, traits9]
  # focal species named to coincide with reference row labels, so
  # itv_reference can locate their reference-database points
  sp$species <- rep(c("ref1", "ref2"), each = 6)
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  expect_true(all(c("ref1", "ref2") %in% proj$global_species))

  grDevices::pdf(file = tempfile(fileext = ".pdf"))
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_invisible(plot(proj, style = "hull"))                       # density default
  expect_invisible(plot(proj, style = "hull", reference_points = TRUE))
  expect_invisible(plot(proj, style = "points", reference_density = FALSE,
                        reference_points = TRUE))
  expect_invisible(plot(proj, style = "hull", itv_reference = TRUE))
  expect_invisible(plot(proj, style = "hull", background = FALSE,
                        itv_reference = TRUE))                        # master off
})

test_that("arrows overlay (trait loadings biplot) runs and validates its scale", {
  ref <- make_reference(seed = 8)
  sp <- ref[1:12, traits9]
  sp$species <- rep(c("ref1", "ref2"), each = 6)
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)

  grDevices::pdf(file = tempfile(fileext = ".pdf"))
  on.exit(grDevices::dev.off(), add = TRUE)
  # runs across styles and composes with the reference / itv_reference layers
  expect_invisible(plot(proj, style = "hull", arrows = TRUE))
  expect_invisible(plot(proj, style = "points", arrows = TRUE,
                        reference_density = FALSE))
  expect_invisible(plot(proj, style = "spider", arrows = TRUE,
                        itv_reference = TRUE))
  expect_invisible(plot(proj, style = "hull", arrows = TRUE, arrow_scale = 0.5,
                        arrow_col = "navy"))
  # an out-of-range arrow_scale is rejected
  expect_error(plot(proj, arrows = TRUE, arrow_scale = 0),
               "arrow_scale")
  expect_error(plot(proj, arrows = TRUE, arrow_scale = 1.5),
               "arrow_scale")
})

test_that("itv_reference warns when a focal species has no reference row", {
  ref <- make_reference(seed = 9)
  sp <- ref[1:6, traits9]; sp$species <- rep("NotInReference", 6)
  proj <- project_fishmorph(sp, reference = ref,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)
  grDevices::pdf(file = tempfile(fileext = ".pdf"))
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_warning(plot(proj, style = "points", itv_reference = TRUE),
                 "no reference row")
})
