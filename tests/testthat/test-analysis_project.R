test_that("analysis_params() fills defaults and refuses unknown names", {
  p <- analysis_params(min_n = 12)
  expect_equal(p$min_n, 12)
  expect_null(p$species)
  expect_true("acc_n_perm" %in% names(p))
  expect_error(analysis_params(minn = 3), "Unknown analysis parameter")
  r <- .ana_parameters_r(p)
  e <- new.env(); eval(parse(text = r), envir = e)
  expect_equal(e$PARAMS, p)                       # parameters.R round-trips
})

test_that(".ana_read_workbook() keeps landmarks by position, hinges 24/25 included", {
  skip_if_not_installed("readxl"); skip_if_not_installed("writexl")
  P <- matrix(c(0, 0,  100, 0,  50, -20,  50, 20,  40, -10,  40, 10,  30, 0,  30, -5,
                10, 0,  20, 5,  20, 8,  35, 8,  25, -2,  28, -2,  12, 1,  85, -8,
                85, 8,  98, -15,  98, 15,  0, 40,  10, 40), ncol = 2, byrow = TRUE)
  wide <- data.frame(specimen = c("a", "b"), species = "Sp one")
  for (i in 1:21) { wide[[paste0(i, "_X")]] <- P[i, 1]; wide[[paste0(i, "_Y")]] <- P[i, 2] }
  wide[["22_X"]] <- c(30, NA); wide[["22_Y"]] <- c(15, NA)        # hinges on "a" only
  wide[["24_X"]] <- c(70, NA); wide[["24_Y"]] <- c(15, NA)        # 23 absent from the sheet
  f <- tempfile(fileext = ".xlsx"); writexl::write_xlsx(list(measurements = wide), f)
  lm <- .ana_read_workbook(f)
  expect_equal(dim(lm$coords), c(24L, 2L, 2L))
  expect_true(all(is.na(lm$coords["23", , ])))
  expect_equal(unname(lm$coords["24", , "a"]), c(70, 15))
  seg <- as.data.frame(suppressMessages(fishmorph_segments(lm, scale_cm = 1)))
  chord <- 100
  poly <- sqrt(30^2 + 15^2) + 40 + sqrt(30^2 + 15^2)               # 1 -> 22 -> 24 -> 2
  expect_equal(seg$Bl[seg$specimen == "b"] * 10, chord, tolerance = 1e-6)
  expect_equal(seg$Bl[seg$specimen == "a"] * 10, poly, tolerance = 1e-6)
})

test_that("write_analysis_project() writes, runs and zips a reproducible project", {
  skip_on_cran()
  skip_if_not_installed("callr")
  lm <- load_t26_saudrune_landmarks()
  d <- file.path(tempfile("anaproj"), "T26_test")
  pr <- analysis_params(min_n = 20, acc_n_perm = 9, disparity_iter = 19, shape = FALSE)
  res <- suppressWarnings(write_analysis_project(lm, d, params = pr, title = "T26 test",
                                                 author = "Tester", quiet = TRUE))
  expect_true(res$ok, info = res$error)
  expect_true(file.exists(res$zip))
  for (f in c("run_all.R", "README.md", "T26_test.Rproj", ".gitignore", "session_info.txt",
              "utils/parameters.R", "scripts/01_DATA_load_and_clean.R",
              "data/raw/landmarks.csv", "data/metadata.csv",
              "results/tables/Table1_sample.csv", "results/tables/Table6_itv_partition.csv",
              "results/tables/Table5_fishmorph_space_occupancy.csv",
              "results/figures/Fig1_trait_space.png", "manuscript/Methods_Results.Rmd"))
    expect_true(file.exists(file.path(d, f)), info = f)
  expect_false(file.exists(file.path(d, "scripts/03_FIGURE_shape_space.R")))
  expect_false(any(grepl("\\{\\{", readLines(file.path(d, "README.md")))))
  # the scripts' analysed sample is the app's (.ana_prepare)
  a <- suppressMessages(.ana_prepare(lm, pr))$traits
  b <- utils::read.csv(file.path(d, "data/processed/traits_analysed.csv"), stringsAsFactors = FALSE,
                       colClasses = c(specimen = "character", date = "character"))
  a <- a[order(a$specimen), ]; b <- b[order(b$specimen), ]
  expect_equal(nrow(a), nrow(b))
  for (r in .ANA_RATIOS) expect_equal(a[[r]], b[[r]], tolerance = 1e-10, info = r)
  # the zip holds the project folder
  z <- utils::unzip(res$zip, list = TRUE)$Name
  expect_true("T26_test/run_all.R" %in% z)
})

test_that("a photograph digitized only once does not stop the measurement error", {
  skip_on_cran()
  skip_if_not_installed("callr")
  rep <- load_t26_saudrune_landmarks("repeatability")
  ind <- rep$metadata$individual
  first <- unique(ind)[1]
  drop <- which(ind == first)[-1]                     # `first` keeps a single pass
  keep <- setdiff(seq_along(ind), drop)
  rep$coords <- rep$coords[, , keep, drop = FALSE]
  rep$metadata <- rep$metadata[keep, , drop = FALSE]
  if (is.null(rep$metadata$specimen)) rep$metadata$specimen <- dimnames(rep$coords)[[3]]
  kr <- .ana_keep_replicated(rep)
  expect_equal(kr$dropped, first)
  expect_false(first %in% kr$rep$metadata$individual)
  lm <- load_t26_saudrune_landmarks()
  d <- file.path(tempfile("anaproj"), "T26_rep")
  res <- suppressWarnings(write_analysis_project(
    lm, d, repeats = rep, quiet = TRUE,
    params = analysis_params(min_n = 20, acc_n_perm = 9, disparity_iter = 19, shape = FALSE)))
  expect_true(res$ok, info = res$error)
  expect_true(file.exists(file.path(d, "results/tables/TableS7_repeatability_segments.csv")))
  expect_true(any(grepl("digitized only once", readLines(res$log))))
})

test_that("literature records enter the ratio analyses, with a choice of ratios", {
  lm <- load_t26_saudrune_landmarks()
  set.seed(3)
  sp <- c("Gobio gobio", "Squalius cephalus", "Lit species")
  lit <- data.frame(specimen_code = sprintf("L%03d", 1:60), species = rep(sp, each = 20),
                    site = "Elsewhere", study_id = rep(c("S1", "S2"), 30), stringsAsFactors = FALSE)
  for (r in .ANA_RATIOS) lit[[r]] <- stats::runif(60, 0.2, 2)
  lit$PFv <- NA                                     # a data set without PFv
  p9 <- analysis_params(min_n = 10)
  a <- suppressMessages(.ana_prepare(lm, p9, lit))
  expect_false("literature" %in% a$traits$source)   # excluded: PFv missing
  p8 <- analysis_params(min_n = 10, ratios = setdiff(.ANA_RATIOS, "PFv"))
  b <- suppressMessages(.ana_prepare(lm, p8, lit))
  expect_equal(sum(b$traits$source == "literature"), 60)
  expect_true("Lit species" %in% b$kept_species)
  expect_equal(names(b$x), setdiff(.ANA_RATIOS, "PFv"))
  c1 <- suppressMessages(.ana_prepare(lm, analysis_params(min_n = 10, ratios = setdiff(.ANA_RATIOS, "PFv"),
                                                          sources = "literature"), lit))
  expect_true(all(c1$traits$source == "literature"))
  # literature alone
  d <- suppressMessages(.ana_prepare(NULL, p8, lit))
  expect_null(d$fish)
  expect_equal(nrow(d$traits), 60)
})

test_that("write_analysis_project() runs with literature records and a subset of ratios", {
  skip_on_cran(); skip_if_not_installed("callr")
  lm <- load_t26_saudrune_landmarks()
  set.seed(4)
  lit <- data.frame(specimen_code = sprintf("L%03d", 1:40),
                    species = rep(c("Gobio gobio", "Lit species"), each = 20),
                    site = "Elsewhere", study_id = "S1", stringsAsFactors = FALSE)
  for (r in .ANA_RATIOS) lit[[r]] <- stats::runif(40, 0.2, 2)
  lit$PFv <- NA
  pr <- analysis_params(min_n = 15, acc_n_perm = 9, disparity_iter = 19, shape = FALSE,
                        ratios = setdiff(.ANA_RATIOS, "PFv"))
  d <- file.path(tempfile("anaproj"), "T26_lit")
  res <- suppressWarnings(write_analysis_project(lm, d, params = pr, literature = lit, quiet = TRUE))
  expect_true(res$ok, info = res$error)
  t1 <- utils::read.csv(file.path(d, "results/tables/Table1_sample.csv"), stringsAsFactors = FALSE)
  expect_match(t1$sources[t1$species == "Gobio gobio"], "literature 20")
  tr <- utils::read.csv(file.path(d, "data/processed/traits_analysed.csv"), stringsAsFactors = FALSE)
  a <- suppressMessages(.ana_prepare(lm, pr, lit))$traits
  expect_equal(sort(tr$specimen), sort(a$specimen))
  # literature only: no landmark script, the ratio analyses run
  d2 <- file.path(tempfile("anaproj"), "lit_only")
  res2 <- suppressWarnings(write_analysis_project(NULL, d2, params = pr, literature = lit, quiet = TRUE))
  expect_true(res2$ok, info = res2$error)
  expect_false(file.exists(file.path(d2, "data/raw/landmarks.csv")))
  expect_true(file.exists(file.path(d2, "results/tables/Table6_itv_partition.csv")))
})
