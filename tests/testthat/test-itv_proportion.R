traits9 <- c("REs", "VEp", "RMl", "OGp", "BEl", "BLs", "PFv", "PFs", "CPt")

make_reference <- function(n = 40, seed = 11) {
  set.seed(seed)
  m <- matrix(runif(n * length(traits9), 0.05, 0.9), nrow = n)
  colnames(m) <- traits9
  df <- as.data.frame(m)
  rownames(df) <- paste0("ref", seq_len(n))
  df
}

# specimens taken from reference rows, already on the (log) reference scale:
# analysis scale == raw input, so the expected ranges are computable directly.
make_projection <- function(volume_dims = 2L) {
  ref <- make_reference()
  sp  <- ref[1:5, traits9]
  sp$species <- c("A", "A", "A", "B", "B")   # A: 3 specimens, B: 2 specimens
  proj <- project_fishmorph(
    sp, reference = ref, volume_dims = volume_dims,
    reference_prelogged = TRUE, specimens_prelogged = TRUE
  )
  list(proj = proj, ref = ref, sp = sp)
}

test_that("project_fishmorph() bundles an intrait_itv_proportion result", {
  p <- make_projection()
  ip <- p$proj$itv_proportion
  expect_s3_class(ip, "intrait_itv_proportion")
  expect_true(all(c("trait", "trait_species", "volume") %in% names(ip)))
  expect_identical(ip$trait$trait, traits9)
  expect_output(print(ip), "intrait_itv_proportion")
})

test_that("per-trait proportion is the ITV range over the reference range", {
  p <- make_projection()
  ip <- p$proj$itv_proportion

  ref_range <- apply(p$ref[traits9], 2, function(v) diff(range(v)))
  itv_range <- apply(p$sp[traits9], 2, function(v) diff(range(v)))
  expected  <- as.numeric(itv_range / ref_range)

  expect_equal(ip$trait$proportion_pooled, expected, tolerance = 1e-10)
  expect_equal(ip$trait$global_range, as.numeric(ref_range), tolerance = 1e-10)
  # focal ITV is a subset of the reference, so every proportion is in [0, 1]
  expect_true(all(ip$trait$proportion_pooled >= 0 & ip$trait$proportion_pooled <= 1))
})

test_that("per-species trait proportions match a manual per-group computation", {
  p <- make_projection()
  ip <- p$proj$itv_proportion
  ref_range <- apply(p$ref[traits9], 2, function(v) diff(range(v)))

  a_range <- apply(p$sp[p$sp$species == "A", traits9], 2, function(v) diff(range(v)))
  a_prop  <- ip$trait_species[ip$trait_species$species == "A", ]
  a_prop  <- a_prop[match(traits9, a_prop$trait), ]
  expect_equal(a_prop$proportion, as.numeric(a_range / ref_range), tolerance = 1e-10)
  expect_true(all(a_prop$n == 3))
})

test_that("functional-volume proportion is the convex-hull ratio, per species", {
  skip_if_not_installed("geometry")
  p  <- make_projection(volume_dims = 2L)
  ip <- p$proj$itv_proportion

  expect_equal(ip$volume_dims, 2L)
  expect_true(is.finite(ip$global_volume) && ip$global_volume > 0)

  pooled <- ip$volume[ip$volume$group == "(all focal species)", ]
  expect_equal(pooled$n, 5L)
  expect_true(is.finite(pooled$proportion) &&
                pooled$proportion > 0 && pooled$proportion <= 1)

  # species A has 3 specimens -> a 2-D hull exists; species B has 2 -> NA
  vA <- ip$volume[ip$volume$group == "A", ]
  vB <- ip$volume[ip$volume$group == "B", ]
  expect_true(is.finite(vA$proportion))
  expect_true(is.na(vB$volume))

  # cross-check the pooled ratio against a direct geometry computation
  gv <- geometry::convhulln(p$proj$global_scores_all[, 1:2], options = "FA")$vol
  iv <- geometry::convhulln(p$proj$scores_all[, 1:2],       options = "FA")$vol
  expect_equal(pooled$proportion, iv / gv, tolerance = 1e-8)
})

test_that("volume_dims can be recomputed on demand and is validated", {
  skip_if_not_installed("geometry")
  p <- make_projection(volume_dims = 2L)
  ip3 <- itv_proportion(p$proj, volume_dims = 3)
  expect_equal(ip3$volume_dims, 3L)
  expect_error(itv_proportion(p$proj, volume_dims = 999),
               "exceeds")
})

test_that("default metric is the convex hull and is recorded", {
  skip_if_not_installed("geometry")
  ip <- make_projection()$proj$itv_proportion
  expect_identical(ip$metric, "hull")
  expect_output(print(ip), "convex hull")
})

test_that("metric = \"tpd\" returns a comparable, density-based volume proportion", {
  skip_if_not_installed("TPD")
  # A larger, structured reference so the KDE grid is well-populated.
  set.seed(3)
  ref <- make_reference(n = 200, seed = 3)
  # Focal specimens: a central cluster (should occupy little TPD volume even
  # though a convex hull over the same points spans more of the space).
  sp <- as.data.frame(matrix(runif(60 * length(traits9), 0.4, 0.6),
                             nrow = 60))
  colnames(sp) <- traits9
  sp$species <- rep(c("A", "B"), each = 30)
  proj <- project_fishmorph(sp, reference = ref, volume_dims = 2L,
                            reference_prelogged = TRUE, specimens_prelogged = TRUE)

  ip <- itv_proportion(proj, metric = "tpd")
  expect_identical(ip$metric, "tpd")
  expect_true(is.finite(ip$global_volume) && ip$global_volume > 0)

  pooled <- ip$volume[ip$volume$group == "(all focal species)", ]
  expect_equal(pooled$n, 60L)
  expect_true(is.finite(pooled$proportion) &&
                pooled$proportion > 0 && pooled$proportion <= 1)
  # per-species TPD richness is available (30 specimens each)
  expect_true(all(is.finite(
    ip$volume$proportion[ip$volume$group %in% c("A", "B")]
  )))
  expect_output(print(ip), "TPD FRichness")

  # the per-trait (range) decomposition is unaffected by the metric choice
  ip_hull <- itv_proportion(proj, metric = "hull")
  expect_equal(ip$trait$proportion_pooled, ip_hull$trait$proportion_pooled)
})

test_that("metric = \"tpd\" validates its arguments", {
  skip_if_not_installed("TPD")
  proj <- make_projection()$proj
  expect_error(itv_proportion(proj, metric = "tpd", tpd_alpha = 1.5),
               "tpd_alpha")
  expect_error(itv_proportion(proj, metric = "tpd", tpd_n_divisions = 1),
               "tpd_n_divisions")
  expect_error(itv_proportion(proj, metric = "nonsense"))
})
