# =============================================================================
# The prediction models, distributed OUTSIDE the package.
#
# The trained networks (ONNX, ~46 MB each) are too heavy for the package and
# change at their own pace: they are published as a zip attached to a GitHub
# release of intraitR (tag "models-v<version>") and installed once per machine
# in the user's data folder of intraitR. THIS version of the package names the
# model version it was validated with (.MLMORPH_MODELS), so that a given
# version of intraitR always predicts with the same model -- reproducible --
# and a new model is a deliberate update.
#
#   pack_mlmorph_models()     the maintainer: ml_morph folder -> zip + manifest
#   install_mlmorph_models()  the user: download, check, install
#   mlmorph_models_dir()      where the installed models are (or NULL)
#   mlmorph_models_info()     what is installed
#   install_mlmorph_python()  a Python environment able to run them
# =============================================================================

# Set by pack_mlmorph_models(package_dir = ) when a model bundle is published.
.MLMORPH_MODELS <- list(
  version = "1",
  file    = "intraitR_models_v1.zip",
  md5     = "732e2504fe8eb04890e04e43ec525a80",
  size_mb = 286.6,
  repo    = "FunTraits/intraitR"
)

# What prediction needs, folder by folder: the network and its parameters. The
# training checkpoints (best.pt, last.pt: 180 MB per model) and the
# validation tables stay behind.
.MLMORPH_BUNDLE <- list(
  mlmorph_run_global          = c("model.onnx", "global_params.json"),
  mlmorph_run_cnn             = c("model.onnx", "cnn_params.json", "validation_summary.csv"),
  mlmorph_run_ruler           = c("model.onnx", "global_params.json"),
  mlmorph_run_ruler_period    = c("model.onnx", "period_params.json"),
  mlmorph_run_refine_head     = c("model.onnx", "refine_params.json"),
  mlmorph_run_refine_pectoral = c("model.onnx", "refine_params.json"),
  mlmorph_run_refine_caudal   = c("model.onnx", "refine_params.json"),
  mlmorph_dataset_cnn         = "canon_params.txt"
)
.MLMORPH_REQUIRED <- c("mlmorph_run_global/model.onnx", "mlmorph_run_cnn/model.onnx",
                       "mlmorph_dataset_cnn/canon_params.txt")

.mlmorph_models_root <- function() file.path(tools::R_user_dir("intraitR", "data"), "mlmorph_models")

#' Package the prediction models for distribution
#'
#' For the maintainer: copies, from an ml-morph folder, exactly what prediction
#' needs -- the ONNX networks (global localisation, fine landmarks, ruler, ruler
#' period, and the three regional refinements) with their parameter files and
#' the canonical frame of the training set -- into a zip with a manifest
#' (`MANIFEST.tsv`: every file, its size and md5; `VERSION`). The training
#' checkpoints and datasets are left out (a few hundred MB instead of several
#' GB).
#'
#' Publish the zip as an asset of a GitHub release of intraitR tagged
#' `models-v<version>`. With `package_dir`, the source of intraitR is updated so
#' that this version of the package installs this version of the models
#' ([install_mlmorph_models()]); otherwise the lines to paste are printed.
#'
#' @param mlmorph_dir The ml-morph folder holding the `mlmorph_run_*` models.
#' @param version Version of the bundle (`"1"`, `"2"`, ...).
#' @param out_dir Where the zip is written.
#' @param refine Include the three regional refinement networks (used by
#'   default by the prediction when present; ~140 MB).
#' @param package_dir Optional: the source folder of intraitR, whose
#'   `R/mlmorph_models.R` gets the version, file name and checksum.
#' @return Invisibly, the path of the zip.
#' @seealso [install_mlmorph_models()]
#' @examples
#' \dontrun{
#' pack_mlmorph_models("~/ml_morph", version = "1", out_dir = "~/Desktop",
#'                     package_dir = "~/Packages/intraitR")
#' }
#' @export
pack_mlmorph_models <- function(mlmorph_dir, version, out_dir = ".", refine = TRUE,
                                package_dir = NULL) {
  version <- as.character(version)
  if (length(version) != 1L || !nzchar(version) || grepl("[^A-Za-z0-9._-]", version))
    stop("`version` must be a short label such as \"1\" or \"2.1\".", call. = FALSE)
  if (!dir.exists(mlmorph_dir)) stop("`mlmorph_dir` not found: ", mlmorph_dir, call. = FALSE)
  bundle <- .MLMORPH_BUNDLE
  if (!isTRUE(refine)) bundle <- bundle[!grepl("refine", names(bundle))]
  rel <- unlist(lapply(names(bundle), function(d) file.path(d, bundle[[d]])), use.names = FALSE)
  src <- file.path(mlmorph_dir, rel)
  miss_req <- .MLMORPH_REQUIRED[!file.exists(file.path(mlmorph_dir, .MLMORPH_REQUIRED))]
  if (length(miss_req))
    stop("Missing in ", mlmorph_dir, ": ", paste(miss_req, collapse = ", "), call. = FALSE)
  if (any(!file.exists(src))) {
    message("Not found, left out: ", paste(rel[!file.exists(src)], collapse = ", "))
    rel <- rel[file.exists(src)]; src <- src[file.exists(src)]
  }
  stage <- file.path(tempfile("mlmorph_pack_"), paste0("intraitR_models_v", version))
  dir.create(stage, recursive = TRUE)
  on.exit(unlink(dirname(stage), recursive = TRUE), add = TRUE)
  for (k in seq_along(rel)) {
    dir.create(dirname(file.path(stage, rel[k])), recursive = TRUE, showWarnings = FALSE)
    file.copy(src[k], file.path(stage, rel[k]), copy.date = TRUE)
  }
  man <- data.frame(file = rel, bytes = file.size(src),
                    md5 = unname(tools::md5sum(src)), stringsAsFactors = FALSE)
  utils::write.table(man, file.path(stage, "MANIFEST.tsv"), sep = "\t",
                     row.names = FALSE, quote = FALSE)
  writeLines(c(paste("version:", version),
               paste("created:", format(Sys.time(), "%Y-%m-%d %H:%M %Z")),
               paste("intraitR:", tryCatch(as.character(utils::packageVersion("intraitR")),
                                           error = function(e) "dev")),
               paste("source:", normalizePath(mlmorph_dir, winslash = "/"))),
             file.path(stage, "VERSION"))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  zipf <- normalizePath(file.path(out_dir, paste0("intraitR_models_v", version, ".zip")),
                        winslash = "/", mustWork = FALSE)
  if (file.exists(zipf)) file.remove(zipf)
  old <- setwd(dirname(stage)); on.exit(setwd(old), add = TRUE)
  st <- utils::zip(zipf, basename(stage), flags = "-r9Xq")
  setwd(old)
  if (!identical(as.integer(st), 0L) || !file.exists(zipf))
    stop("The zip could not be written (is a `zip` program available?).", call. = FALSE)
  md5 <- unname(tools::md5sum(zipf)); size <- round(file.size(zipf) / 1024^2, 1)
  spec <- sprintf(paste0(
    ".MLMORPH_MODELS <- list(\n  version = \"%s\",\n  file    = \"%s\",\n",
    "  md5     = \"%s\",\n  size_mb = %s,\n  repo    = \"FunTraits/intraitR\"\n)"),
    version, basename(zipf), md5, size)
  if (!is.null(package_dir)) {
    f <- file.path(package_dir, "R", "mlmorph_models.R")
    if (!file.exists(f)) stop("Not an intraitR source folder: ", package_dir, call. = FALSE)
    s <- paste(readLines(f, warn = FALSE), collapse = "\n")
    s2 <- sub("\\.MLMORPH_MODELS <- list\\((.|\n)*?\n\\)", spec, s, perl = TRUE)
    writeLines(s2, f)
    message("R/mlmorph_models.R updated: this intraitR now installs models v", version, ".")
  } else {
    message("Paste into R/mlmorph_models.R of intraitR:\n", spec)
  }
  message(sprintf(paste0("Written: %s (%.1f MB, %d files).\nPublish it as an asset of a ",
                         "GitHub release of intraitR tagged \"models-v%s\"."),
                  zipf, size, nrow(man), version))
  invisible(zipf)
}

#' Install the prediction models
#'
#' Downloads the model bundle this version of intraitR was validated with (a
#' zip attached to the GitHub release `models-v<version>`), checks it, and
#' installs it in the user's data folder of intraitR. Done once per machine;
#' [digitize_landmarks()], [batch_landmarks()] and [launch_measure_hub()] then
#' find the models without `mlmorph_dir`.
#'
#' Each file is checked against the manifest of the bundle (md5), and the zip
#' against the checksum this version of the package knows: a truncated or
#' altered download is refused, not installed.
#'
#' @param version Version of the bundle; `NULL`: the one this version of
#'   intraitR names.
#' @param url Where to download from; `NULL`: the release of the package's
#'   repository. A local path to a zip also works (an internal mirror, a USB
#'   key).
#' @param force Install again even when already installed.
#' @param token GitHub token, for a bundle published on a PRIVATE repository.
#' @return Invisibly, the folder of the installed models.
#' @seealso [mlmorph_models_info()], [install_mlmorph_python()],
#'   [pack_mlmorph_models()]
#' @examples
#' \dontrun{
#' install_mlmorph_models()
#' mlmorph_models_info()
#' }
#' @export
install_mlmorph_models <- function(version = NULL, url = NULL, force = FALSE,
                                   token = Sys.getenv("GITHUB_PAT")) {
  spec <- .MLMORPH_MODELS
  version <- as.character(version %||% spec$version)
  if (is.na(version) || !nzchar(version))
    stop("This version of intraitR names no published model bundle yet. Give `url` ",
         "(and `version`), or ask the maintainer.", call. = FALSE)
  dest <- file.path(.mlmorph_models_root(), paste0("v", version))
  if (!isTRUE(force) && .mlmorph_bundle_ok(dest)) {
    message("Models v", version, " already installed: ", dest)
    return(invisible(dest))
  }
  known <- identical(version, spec$version)
  file <- if (known) spec$file else paste0("intraitR_models_v", version, ".zip")
  if (is.null(url))
    url <- sprintf("https://github.com/%s/releases/download/models-v%s/%s",
                   spec$repo, version, file)
  zipf <- if (file.exists(url)) url else {
    tmp <- tempfile(fileext = ".zip")
    message(sprintf("Downloading the models v%s%s ...", version,
                    if (known && is.finite(spec$size_mb)) sprintf(" (%.0f MB)", spec$size_mb) else ""))
    old <- options(timeout = max(3600, getOption("timeout"))); on.exit(options(old), add = TRUE)
    hdr <- if (nzchar(token)) c(Authorization = paste("token", token)) else NULL
    ok <- tryCatch(utils::download.file(url, tmp, mode = "wb", quiet = FALSE, headers = hdr),
                   error = function(e) e)
    if (inherits(ok, "error") || !file.exists(tmp) || !file.size(tmp))
      stop("Download failed from ", url, "\n  ",
           if (inherits(ok, "error")) conditionMessage(ok) else "", call. = FALSE)
    tmp
  }
  if (known && !is.na(spec$md5) && !identical(unname(tools::md5sum(zipf)), spec$md5))
    stop("The downloaded file is not the expected one (checksum differs): incomplete ",
         "download, or another bundle. Nothing was installed.", call. = FALSE)
  ex <- tempfile("mlmorph_unzip_"); on.exit(unlink(ex, recursive = TRUE), add = TRUE)
  utils::unzip(zipf, exdir = ex)
  root <- dirname(list.files(ex, pattern = "^MANIFEST\\.tsv$", recursive = TRUE,
                             full.names = TRUE))[1]
  if (is.na(root)) stop("Not a model bundle: no MANIFEST.tsv in the zip.", call. = FALSE)
  if (!.mlmorph_bundle_ok(root, verbose = TRUE))
    stop("The bundle is damaged (files missing or altered). Nothing was installed.",
         call. = FALSE)
  if (dir.exists(dest)) unlink(dest, recursive = TRUE)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.rename(root, dest)) {          # another volume: copy
    dir.create(dest)
    file.copy(list.files(root, full.names = TRUE), dest, recursive = TRUE)
  }
  message("Models v", version, " installed: ", dest)
  invisible(dest)
}

# A bundle folder is usable when every file of its manifest is there, intact,
# and the required networks are among them.
.mlmorph_bundle_ok <- function(d, verbose = FALSE) {
  mf <- file.path(d, "MANIFEST.tsv")
  if (!file.exists(mf)) return(FALSE)
  m <- tryCatch(utils::read.delim(mf, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(m) || !all(c("file", "md5") %in% names(m))) return(FALSE)
  f <- file.path(d, m$file)
  bad <- !file.exists(f)
  bad[!bad] <- unname(tools::md5sum(f[!bad])) != m$md5[!bad]
  if (verbose && any(bad)) message("Damaged or missing: ", paste(m$file[bad], collapse = ", "))
  !any(bad) && all(file.exists(file.path(d, .MLMORPH_REQUIRED)))
}

#' Where the installed prediction models are
#'
#' @param version A bundle version; `NULL`: the one this version of intraitR
#'   names if installed, otherwise the most recent installed.
#' @return The folder (usable as `mlmorph_dir`), or `NULL` when none is
#'   installed.
#' @seealso [install_mlmorph_models()]
#' @export
mlmorph_models_dir <- function(version = NULL) {
  root <- .mlmorph_models_root()
  if (!dir.exists(root)) return(NULL)
  want <- as.character(version %||% .MLMORPH_MODELS$version)
  if (!is.na(want) && nzchar(want)) {
    d <- file.path(root, paste0("v", want))
    if (dir.exists(d) && file.exists(file.path(d, "MANIFEST.tsv"))) return(normalizePath(d, winslash = "/"))
    if (!is.null(version)) return(NULL)
  }
  ds <- list.dirs(root, recursive = FALSE)
  ds <- ds[file.exists(file.path(ds, "MANIFEST.tsv"))]
  if (!length(ds)) return(NULL)
  v <- sub("^v", "", basename(ds))
  normalizePath(ds[order(numeric_version(v, strict = FALSE), decreasing = TRUE)][1], winslash = "/")
}

#' The prediction models installed on this machine
#'
#' @return A data.frame: `version`, `folder`, `size_mb`, `intact` (every file
#'   matches the manifest), `this_package` (the version this intraitR names).
#' @seealso [install_mlmorph_models()]
#' @export
mlmorph_models_info <- function() {
  root <- .mlmorph_models_root()
  ds <- if (dir.exists(root)) list.dirs(root, recursive = FALSE) else character(0)
  ds <- ds[file.exists(file.path(ds, "MANIFEST.tsv"))]
  out <- data.frame(version = sub("^v", "", basename(ds)), folder = ds,
                    size_mb = vapply(ds, function(d) round(sum(file.size(
                      list.files(d, recursive = TRUE, full.names = TRUE))) / 1024^2, 1), 1),
                    intact = vapply(ds, .mlmorph_bundle_ok, TRUE),
                    stringsAsFactors = FALSE, row.names = NULL)
  out$this_package <- out$version %in% .MLMORPH_MODELS$version
  if (!nrow(out)) message("No prediction model installed: install_mlmorph_models().")
  out
}

#' A Python environment able to run the prediction models
#'
#' Creates a virtual environment in the user's data folder of intraitR and
#' installs what the prediction scripts import: `numpy`, `pandas`,
#' `opencv-python-headless`, `pillow` and `onnxruntime` (`dlib`, needed only by
#' the old `.dat` predictors, is not installed). The applications and
#' [batch_landmarks()] find this environment without `python =`.
#'
#' @param python The Python 3 used to create the environment (3.9 or later).
#' @param force Recreate it even when it exists.
#' @return Invisibly, the path of the environment's Python.
#' @seealso [install_mlmorph_models()]
#' @export
install_mlmorph_python <- function(python = NULL, force = FALSE) {
  env <- .mlmorph_venv_dir()
  py_env <- .mlmorph_venv_python(must_exist = FALSE)
  if (!isTRUE(force) && file.exists(py_env)) {
    message("The Python environment exists: ", env)
  } else {
    if (isTRUE(force)) unlink(env, recursive = TRUE)
    python <- python %||% Sys.which(c("python3", "python"))[nzchar(Sys.which(c("python3", "python")))][1]
    if (is.null(python) || is.na(python) || !nzchar(python))
      stop("No Python 3 found: install one (python.org), or give `python =`.", call. = FALSE)
    dir.create(dirname(env), recursive = TRUE, showWarnings = FALSE)
    message("Creating the environment with ", python, " ...")
    st <- system2(python, c("-m", "venv", shQuote(env)))
    if (!identical(st, 0L) || !file.exists(py_env))
      stop("The environment could not be created with ", python, ".", call. = FALSE)
  }
  pk <- c("numpy", "pandas", "opencv-python-headless", "pillow", "onnxruntime")
  message("Installing ", paste(pk, collapse = ", "), " ...")
  st <- system2(py_env, c("-m", "pip", "install", "--upgrade", "--quiet", "pip", pk))
  if (!identical(st, 0L)) stop("pip failed: see the messages above.", call. = FALSE)
  chk <- suppressWarnings(system2(py_env, c("-c", shQuote(
    "import numpy, pandas, cv2, PIL, onnxruntime; print('ok')")), stdout = TRUE, stderr = TRUE))
  if (!any(grepl("^ok$", chk))) stop("The packages do not import: ", paste(chk, collapse = "\n"),
                                     call. = FALSE)
  message("Python ready: ", py_env)
  invisible(py_env)
}
.mlmorph_venv_dir <- function() file.path(tools::R_user_dir("intraitR", "data"), "python")
.mlmorph_venv_python <- function(must_exist = TRUE) {
  p <- if (.Platform$OS.type == "windows") file.path(.mlmorph_venv_dir(), "Scripts", "python.exe")
       else file.path(.mlmorph_venv_dir(), "bin", "python")
  if (must_exist && !file.exists(p)) "" else p
}
