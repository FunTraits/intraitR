test_that("measure_queue() carries the provenance of the species table", {
  d <- file.path(tempfile("prov"), "S1")
  dir.create(d, recursive = TRUE)
  for (f in c("A_001.jpg", "A_002.jpg", "A_003.jpg")) writeLines("x", file.path(d, f))
  sp <- data.frame(photo = c("A_001", "A_002"), species = c("Sp a", "Sp b"),
                   data_source = c("campaign", "museum"))
  q <- measure_queue(dirname(d), species = sp)
  expect_equal(q$source[match(c("A_001", "A_002", "A_003"), q$code)], c("campaign", "museum", NA))
  # a table resolved once keeps it (launch_measure_hub() resolves it first)
  q2 <- measure_queue(dirname(d), species = .hub_species_table(sp))
  expect_equal(q2$source, q$source)
  # no provenance column: NA, nothing else changes
  q3 <- measure_queue(dirname(d), species = sp[, 1:2])
  expect_true(all(is.na(q3$source)))
  expect_equal(q3$species, q$species)
})

test_that(".hub_literature() normalises literature records", {
  l <- data.frame(species = c("Sp a", "Sp b", ""), study_id = "S1", BEl = c(2, 3, 4),
                  VEp = "0.5", stringsAsFactors = FALSE)
  h <- .hub_literature(function() l)
  expect_equal(nrow(h), 2)                         # no species: dropped
  expect_true(all(h$source == "literature"))
  expect_true(is.numeric(h$VEp))
  expect_true(all(is.na(h$PFv)))
  expect_false(anyNA(h$specimen_code))
  expect_equal(nrow(.hub_literature(NULL)), 0)
  expect_equal(nrow(suppressWarnings(.hub_literature(function() stop("no folder")))), 0)
})
