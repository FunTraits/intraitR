## The prediction models live outside the package: packed by the maintainer,
## installed per machine, found without `mlmorph_dir`.

fake_mlmorph <- function(d) {
  for (k in names(intraitR:::.MLMORPH_BUNDLE)) {
    dir.create(file.path(d, k), recursive = TRUE, showWarnings = FALSE)
    for (f in intraitR:::.MLMORPH_BUNDLE[[k]])
      writeLines(paste(k, f, "content"), file.path(d, k, f))
  }
  # training leftovers that must NOT travel
  writeLines("huge", file.path(d, "mlmorph_run_cnn", "last.pt"))
  dir.create(file.path(d, "mlmorph_dataset_combined"))
  d
}

test_that("a bundle is packed, installed from a local zip, checked and found", {
  testthat::skip_if(!nzchar(Sys.which("zip")), "no zip program")
  withr::local_envvar(R_USER_DATA_DIR = tempfile("udata"))
  src <- fake_mlmorph(tempfile("ml_")); out <- tempfile("out_")
  on.exit(unlink(c(src, out), recursive = TRUE), add = TRUE)
  z <- suppressMessages(pack_mlmorph_models(src, version = "9", out_dir = out))
  expect_true(file.exists(z))
  inside <- utils::unzip(z, list = TRUE)$Name
  expect_true(any(grepl("mlmorph_run_cnn/model.onnx$", inside)))
  expect_false(any(grepl("last\\.pt$|dataset_combined", inside)))   # left behind
  expect_true(any(grepl("MANIFEST\\.tsv$", inside)))

  expect_null(mlmorph_models_dir())
  d <- suppressMessages(install_mlmorph_models(version = "9", url = z))
  expect_true(file.exists(file.path(d, "mlmorph_run_global", "model.onnx")))
  expect_equal(mlmorph_models_dir(), normalizePath(d, winslash = "/"))
  info <- suppressMessages(mlmorph_models_info())
  expect_equal(info$version, "9"); expect_true(info$intact)
  # found without mlmorph_dir, from a folder that holds no ml_morph
  withr::with_dir(tempdir(), expect_equal(intraitR:::.resolve_mlmorph_dir(NULL), mlmorph_models_dir()))
  # a second install is a no-op
  expect_message(install_mlmorph_models(version = "9", url = z), "already installed")
  # an altered file is detected
  writeLines("tampered", file.path(d, "mlmorph_run_cnn", "model.onnx"))
  expect_false(suppressMessages(mlmorph_models_info())$intact)
})

test_that("a damaged bundle is refused, and nothing is installed", {
  testthat::skip_if(!nzchar(Sys.which("zip")), "no zip program")
  withr::local_envvar(R_USER_DATA_DIR = tempfile("udata"))
  src <- fake_mlmorph(tempfile("ml_")); out <- tempfile("out_")
  on.exit(unlink(c(src, out), recursive = TRUE), add = TRUE)
  z <- suppressMessages(pack_mlmorph_models(src, version = "8", out_dir = out))
  # rebuild the zip with one file altered after the manifest was written
  ex <- tempfile("ex_"); utils::unzip(z, exdir = ex)
  writeLines("altered", file.path(ex, "intraitR_models_v8", "mlmorph_run_global", "model.onnx"))
  z2 <- file.path(out, "bad.zip")
  withr::with_dir(ex, utils::zip(z2, "intraitR_models_v8", flags = "-rq"))
  expect_error(suppressMessages(install_mlmorph_models(version = "8", url = z2)), "damaged")
  expect_null(mlmorph_models_dir())
})

test_that("pack_mlmorph_models() writes the version into the package source", {
  testthat::skip_if(!nzchar(Sys.which("zip")), "no zip program")
  src <- fake_mlmorph(tempfile("ml_")); pkg <- tempfile("pkg_"); out <- tempfile("out_")
  on.exit(unlink(c(src, pkg, out), recursive = TRUE), add = TRUE)
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines(c("# header", ".MLMORPH_MODELS <- list(", "  version = NA_character_,",
               "  repo    = \"FunTraits/intraitR\"", ")", "other <- 1"),
             file.path(pkg, "R", "mlmorph_models.R"))
  suppressMessages(pack_mlmorph_models(src, version = "3", out_dir = out, package_dir = pkg))
  s <- readLines(file.path(pkg, "R", "mlmorph_models.R"))
  expect_true(any(grepl('version = "3"', s, fixed = TRUE)))
  expect_true(any(grepl("md5     = \"[0-9a-f]{32}\"", s)))
  expect_true("other <- 1" %in% s)
})

test_that("without a published bundle, install says so", {
  skip_if(!is.na(intraitR:::.MLMORPH_MODELS$version))
  expect_error(install_mlmorph_models(), "names no published model bundle")
})
