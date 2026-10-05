## Identity of a photograph, and what survives a rename.
##
## The case these tests exist for is real and was silent: a determination
## corrected renames the file, the specimen code follows, and the measurements
## are left behind under a name nothing points to any more. The fish comes back
## in the "new" queue as if it had never been digitized.

make_photo <- function(dir, name, content) {
  f <- file.path(dir, name)
  writeLines(content, f)
  f
}

test_that("photo_hash is stable, content-dependent and name-independent", {
  d <- file.path(tempdir(), "ph_id_1")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  a <- make_photo(d, "a.jpeg", "pixels of fish one")
  b <- make_photo(d, "b.jpeg", "pixels of fish two")

  h_a <- photo_hash(a)
  expect_identical(photo_hash(a), h_a)                    # stable
  expect_false(identical(h_a, photo_hash(b)))             # content-dependent

  a2 <- file.path(d, "renamed_entirely.jpeg")
  expect_true(file.rename(a, a2))
  expect_identical(photo_hash(a2), h_a)                   # the name is not the file

  expect_true(is.na(photo_hash(file.path(d, "does_not_exist.jpeg"))))
  expect_identical(photo_hash(character(0)), character(0))
})

test_that("a renamed photograph keeps its measurements", {
  d <- file.path(tempdir(), "ph_id_2")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  # The real case: T-26-0011 imported as SQUCEP_004, digitized, then
  # re-determined as BARBAR_025 and re-imported under that name.
  f <- make_photo(d, "SITE_20260427_BARBAR_025_AT.jpeg", "pixels of T-26-0011")
  meas <- data.frame(
    specimen   = "SITE_20260427_SQUCEP_004_AT",
    individual = "SITE_20260427_SQUCEP_004_AT",
    photo_file = "SITE_20260427_SQUCEP_004_AT.jpeg",
    photo_hash = photo_hash(f),
    stringsAsFactors = FALSE)

  r <- reconcile_photo_names(meas, f)
  expect_equal(nrow(r$changes), 1L)
  expect_identical(r$changes$status, "renamed")
  expect_identical(r$data$specimen,   "SITE_20260427_BARBAR_025_AT")
  expect_identical(r$data$individual, "SITE_20260427_BARBAR_025_AT")
  expect_identical(r$data$photo_file, "SITE_20260427_BARBAR_025_AT.jpeg")

  # ... and the specimen is now IN the folder's code set, which is the whole
  # point: the queue built from the file names finds it as already digitized.
  expect_true(r$data$specimen %in% tools::file_path_sans_ext(basename(f)))
})

test_that("the plate and repeat suffixes are carried across a rename", {
  d <- file.path(tempdir(), "ph_id_3")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  f <- make_photo(d, "PLATE_NEW.jpeg", "four fish on a tray")
  h <- photo_hash(f)
  meas <- data.frame(
    specimen   = c("PLATE_OLD_i1", "PLATE_OLD_i2", "PLATE_OLD_i2_AT_rep2"),
    individual = c("PLATE_OLD_i1", "PLATE_OLD_i2", "PLATE_OLD_i2"),
    photo_file = rep("PLATE_OLD.jpeg", 3L),
    photo_hash = rep(h, 3L), stringsAsFactors = FALSE)

  r <- reconcile_photo_names(meas, f)
  expect_identical(r$data$specimen,
                   c("PLATE_NEW_i1", "PLATE_NEW_i2", "PLATE_NEW_i2_AT_rep2"))
  expect_identical(r$data$individual,
                   c("PLATE_NEW_i1", "PLATE_NEW_i2", "PLATE_NEW_i2"))
})

test_that("photo_hash is back-filled from the name when the name still holds", {
  d <- file.path(tempdir(), "ph_id_4")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  f <- make_photo(d, "FISH_001.jpeg", "one fish")
  meas <- data.frame(specimen = "FISH_001", individual = "FISH_001",
                     photo_file = "FISH_001.jpeg", stringsAsFactors = FALSE)
  r <- reconcile_photo_names(meas, f)
  expect_identical(r$data$photo_hash, photo_hash(f))
  expect_equal(nrow(r$changes), 0L)          # nothing was renamed
  expect_identical(r$data$specimen, "FISH_001")
})

test_that("a rename made before photo_hash existed is repaired from provenance", {
  # THE CASE THAT THE FINGERPRINT ALONE CANNOT REACH. The workbook row names
  # SQUCEP_004.jpeg; the folder holds BARBAR_025.jpeg; no file is called
  # SQUCEP_004.jpeg any more, so the back-fill has nothing to recognise the row
  # by and the fish stays in the "new" queue. The link exists only in whatever
  # renamed the file.
  d <- file.path(tempdir(), "ph_id_10")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  src <- file.path(d, "T-26-0011.jpeg")           # the source image, untouched
  writeLines("pixels of T-26-0011", src)
  cur <- file.path(d, "SITE_20260427_BARBAR_025_AT.jpeg")
  file.copy(src, cur)

  meas <- data.frame(specimen = "SITE_20260427_SQUCEP_004_AT",
                     individual = "SITE_20260427_SQUCEP_004_AT",
                     photo_file = "SITE_20260427_SQUCEP_004_AT.jpeg",
                     stringsAsFactors = FALSE)

  # Without provenance: nothing can be done, and nothing is invented.
  bare <- reconcile_photo_names(meas, cur)
  expect_equal(nrow(bare$changes), 0L)
  expect_identical(bare$data$specimen, "SITE_20260427_SQUCEP_004_AT")

  # With it: the two codes are seen to share a source, and the row is re-keyed.
  jd <- file.path(d, "journal")
  dir.create(jd, showWarnings = FALSE)
  writeLines(c(
    paste("r1", "2026-07-28T10:07:55Z", "AT", "0.17.0", "import",
          "SITE_20260427_SQUCEP_004_AT", "source_path", src, sep = "\t"),
    paste("r2", "2026-07-31T20:03:36Z", "AT", "0.17.0", "import",
          "SITE_20260427_BARBAR_025_AT", "source_path", src, sep = "\t")),
    file.path(jd, "campaign_AT_1.tsv"))

  known <- photo_provenance_keys(jd)
  expect_length(known, 2L)
  # The two codes share ONE key -- that is the whole content of the map.
  expect_identical(unname(known[["SITE_20260427_SQUCEP_004_AT"]]),
                   unname(known[["SITE_20260427_BARBAR_025_AT"]]))

  r <- reconcile_photo_names(meas, cur, provenance = known)
  expect_identical(r$changes$status, "renamed")
  expect_identical(r$data$specimen, "SITE_20260427_BARBAR_025_AT")
  expect_identical(r$data$photo_file, "SITE_20260427_BARBAR_025_AT.jpeg")
  # The fingerprint of the file it now belongs to is recorded, so the NEXT
  # reconciliation needs no provenance journal at all.
  expect_identical(r$data$photo_hash, photo_hash(cur))
})

test_that("provenance groups codes, not renderings: no shared fingerprint needed", {
  # THE CASE THE APP ACTUALLY MEETS. The digitizer runs over `prepared/`, which
  # holds CROPPED working copies; the provenance journal names the original
  # camera files in `raw/`. The two share no bytes and therefore no fingerprint.
  # Matching code to code does not need one -- and the pixel dimensions are
  # checked before any coordinate is carried across.
  d <- file.path(tempdir(), "ph_id_12")
  dir.create(file.path(d, "raw"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "prepared"), recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  # A PNG signature and an IHDR chunk declaring 40 x 30. The frame check reads
  # the HEADER and nothing else, so this is all it needs -- and writing the
  # bytes by hand keeps the test free of the (Suggested) 'png' package.
  write_png_header <- function(path, w, h) {
    con <- file(path, "wb"); on.exit(close(con), add = TRUE)
    writeBin(as.raw(c(137, 80, 78, 71, 13, 10, 26, 10)), con)   # signature
    writeBin(as.integer(13), con, size = 4L, endian = "big")     # IHDR length
    writeBin(charToRaw("IHDR"), con)
    writeBin(as.integer(c(w, h)), con, size = 4L, endian = "big")
    writeBin(as.raw(c(8, 2, 0, 0, 0)), con)                      # bit depth etc.
  }
  prep_path <- file.path(d, "prepared", "SITE_BARBAR_025.png")
  write_png_header(prep_path, 40L, 30L)
  expect_identical(intraitR:::.intraitr_image_size(prep_path), c(40L, 30L))
  writeLines("original camera bytes, quite different",
             file.path(d, "raw", "T-26-0011.jpeg"))

  prep <- prep_path
  expect_false(identical(photo_hash(prep),
                         photo_hash(file.path(d, "raw", "T-26-0011.jpeg"))))

  known <- c(SITE_SQUCEP_004 = "/raw/T-26-0011.jpeg",
             SITE_BARBAR_025 = "/raw/T-26-0011.jpeg")

  meas <- data.frame(specimen = "SITE_SQUCEP_004",
                     individual = "SITE_SQUCEP_004",
                     photo_file = "SITE_SQUCEP_004.png",
                     img_w = 40, img_h = 30, stringsAsFactors = FALSE)
  r <- reconcile_photo_names(meas, prep, provenance = known)
  expect_identical(r$changes$status, "renamed")
  expect_identical(r$data$specimen, "SITE_BARBAR_025")

  # Same fish, different picture: the frame check refuses to move the points.
  meas2 <- meas; meas2$img_w <- 3485; meas2$img_h <- 1771
  r2 <- reconcile_photo_names(meas2, prep, provenance = known)
  expect_identical(r2$changes$status, "frame_changed")
  expect_identical(r2$data$specimen, "SITE_SQUCEP_004")
})

test_that("photo_provenance_keys tolerates an absent or unrelated directory", {
  expect_length(photo_provenance_keys(file.path(tempdir(), "no_such_dir")), 0L)
  d <- file.path(tempdir(), "ph_id_11")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines("not\ta\tjournal", file.path(d, "stray.tsv"))
  expect_length(photo_provenance_keys(d), 0L)

  # A key is an identifier, so it holds whether or not the original is still on
  # the machine -- which is the point: originals get archived, and the
  # renamings they explain do not stop needing explaining.
  writeLines(paste("r1", "2026-07-31T20:03:36Z", "AT", "0.17.0", "import",
                   "ARCHIVED", "source_path", "/long/gone/IMG_0042.jpeg",
                   sep = "\t"),
             file.path(d, "campaign.tsv"))
  k <- photo_provenance_keys(d)
  expect_length(k, 1L)
  expect_identical(unname(k[["ARCHIVED"]]), "/long/gone/IMG_0042.jpeg")
})

test_that("an ambiguous match is reported, never applied", {
  d <- file.path(tempdir(), "ph_id_5")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  # The same photograph present twice under two names says nothing about which
  # of the two the row belongs to.
  f1 <- make_photo(d, "COPY_A.jpeg", "identical bytes")
  f2 <- make_photo(d, "COPY_B.jpeg", "identical bytes")
  meas <- data.frame(specimen = "ORIGINAL", individual = "ORIGINAL",
                     photo_file = "ORIGINAL.jpeg",
                     photo_hash = photo_hash(f1), stringsAsFactors = FALSE)
  r <- reconcile_photo_names(meas, c(f1, f2))
  expect_identical(r$changes$status, "ambiguous")
  expect_identical(r$data$specimen, "ORIGINAL")     # untouched

  # A target code another row already occupies is a collision, not a rename.
  d2 <- file.path(tempdir(), "ph_id_5b")
  dir.create(d2, showWarnings = FALSE)
  on.exit(unlink(d2, recursive = TRUE), add = TRUE)
  g <- make_photo(d2, "TAKEN.jpeg", "some fish")
  meas2 <- data.frame(specimen = c("OLDNAME", "TAKEN"),
                      individual = c("OLDNAME", "TAKEN"),
                      photo_file = c("OLDNAME.jpeg", "TAKEN.jpeg"),
                      photo_hash = c(photo_hash(g), photo_hash(g)),
                      stringsAsFactors = FALSE)
  r2 <- reconcile_photo_names(meas2, g)
  expect_true("ambiguous" %in% r2$changes$status)
  expect_true(all(c("OLDNAME", "TAKEN") %in% r2$data$specimen))
})

test_that("two different photographs of the same fish are never merged", {
  d <- file.path(tempdir(), "ph_id_6")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  # 20260427 and 20260518 are two shots of BARBAR_025: different pixels,
  # different coordinate frames, and therefore two digitizations.
  f1 <- make_photo(d, "SITE_20260427_BARBAR_025_AT.jpeg", "shot one")
  f2 <- make_photo(d, "SITE_20260518_BARBAR_025_AT.jpg",  "shot two")
  meas <- data.frame(
    specimen   = c("SITE_20260427_BARBAR_025_AT", "SITE_20260518_BARBAR_025_AT"),
    individual = c("SITE_20260427_BARBAR_025_AT", "SITE_20260518_BARBAR_025_AT"),
    photo_file = c(basename(f1), basename(f2)),
    photo_hash = c(photo_hash(f1), photo_hash(f2)), stringsAsFactors = FALSE)
  r <- reconcile_photo_names(meas, c(f1, f2))
  expect_equal(nrow(r$changes), 0L)
  expect_identical(r$data$specimen, meas$specimen)
})

test_that("the fingerprint cache returns the same answer as a direct read", {
  d <- file.path(tempdir(), "ph_id_7")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  fs <- c(make_photo(d, "x.jpeg", "aaa"), make_photo(d, "y.jpeg", "bbb"))
  cache <- file.path(d, "cache", "photo_hash_cache.tsv")
  h1 <- photo_hash_cached(fs, cache)
  expect_true(file.exists(cache))
  h2 <- photo_hash_cached(fs, cache)                 # served from the cache
  expect_identical(h1, h2)
  expect_identical(h1, photo_hash(fs))

  # Content changed -> mtime and/or size change -> the cache must not be used.
  Sys.sleep(1.1)
  writeLines("aaa changed and longer", fs[1])
  h3 <- photo_hash_cached(fs, cache)
  expect_false(identical(h3[1], h1[1]))
  expect_identical(h3[2], h1[2])
})

test_that("reconciliation leaves an empty or unrelated table alone", {
  d <- file.path(tempdir(), "ph_id_8")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- make_photo(d, "SOME.jpeg", "a fish")

  e <- data.frame(specimen = character(0), photo_file = character(0),
                  stringsAsFactors = FALSE)
  expect_equal(nrow(reconcile_photo_names(e, f)$changes), 0L)

  # A row whose photograph is simply not in this folder is not a rename.
  other <- data.frame(specimen = "ELSEWHERE", individual = "ELSEWHERE",
                      photo_file = "ELSEWHERE.jpeg",
                      photo_hash = "0123456789abcdef0123456789abcdef",
                      stringsAsFactors = FALSE)
  r <- reconcile_photo_names(other, f)
  expect_equal(nrow(r$changes), 0L)
  expect_identical(r$data$specimen, "ELSEWHERE")

  expect_error(reconcile_photo_names(data.frame(a = 1), f), "photo_file")
})

test_that("the journal carries the entry-level columns through consolidation", {
  d <- file.path(tempdir(), "ph_id_9")
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  jr <- landmark_journal_open(d, operator = "AT")
  P <- cbind(X = c(10, 60, 30), Y = c(20, 22, 40))
  landmark_journal_append(
    jr, row_key = "fish_01", coords = P, points = 1:3,
    specimen = "fish_01", individual = "fish_01",
    target_sheet = "measurements", photo_file = "fish_01.jpeg",
    photo_hash = "deadbeef", reviewed = "yes", reviewed_by = "AT",
    review_date = "2026-08-04T10:00:00Z", collapse_rules = "Mo;Hd6")

  j <- landmark_journal_read(d)
  expect_true(all(c("photo_hash", "reviewed", "reviewed_by", "review_date",
                    "collapse_rules") %in% names(j)))
  expect_identical(unique(j$photo_hash), "deadbeef")

  cons <- consolidate_landmarks(d, points = 1:3)
  expect_identical(cons$photo_hash, "deadbeef")
  expect_identical(cons$reviewed, "yes")
  expect_identical(cons$collapse_rules, "Mo;Hd6")
})


test_that("the provenance route does not throw on its first frame check", {
  # REGRESSION. `list()[["42"]]` is an error in R -- "subscript out of bounds"
  # -- not NULL, unlike the same expression on a data.frame. The dimension
  # cache was read that way, so the very first provenance match threw, the
  # caller's tryCatch turned the throw into "nothing to reconcile", and two
  # releases reported success while doing nothing at all.
  d <- file.path(tempdir(), "ph_id_13")
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)

  con <- file(file.path(d, "NEW.png"), "wb")
  writeBin(as.raw(c(137, 80, 78, 71, 13, 10, 26, 10)), con)
  writeBin(as.integer(13), con, size = 4L, endian = "big")
  writeBin(charToRaw("IHDR"), con)
  writeBin(as.integer(c(120L, 80L)), con, size = 4L, endian = "big")
  writeBin(as.raw(c(8, 2, 0, 0, 0)), con)
  close(con)

  meas <- data.frame(specimen = "OLD", individual = "OLD",
                     photo_file = "OLD.png", img_w = 120, img_h = 80,
                     stringsAsFactors = FALSE)
  r <- expect_silent(reconcile_photo_names(
    meas, file.path(d, "NEW.png"), provenance = c(OLD = "k", NEW = "k")))
  expect_identical(r$changes$status, "renamed")
  expect_identical(r$data$specimen, "NEW")
})

test_that("every function the app calls with :: is actually exported", {
  # REGRESSION. A roxygen block attaches to the object that FOLLOWS it. An
  # internal helper inserted between the block and its function silently stole
  # both the documentation and the `@export`, so `reconcile_photo_names` was
  # never exported -- and the app, which calls it as `intraitR::`, failed at
  # launch with "not an exported object". The workbook was left alone and the
  # renamed specimens stayed in the "new" queue, which is exactly the symptom
  # the function exists to remove.
  #
  # Checking the NAMESPACE rather than the source: what the app can reach is
  # what is exported, whatever the roxygen comments intended.
  exported <- getNamespaceExports("intraitR")
  app <- system.file("shiny", "landmarking_app", "app.R", package = "intraitR")
  skip_if(!nzchar(app) || !file.exists(app), "app source not installed")
  src <- readLines(app, warn = FALSE)
  called <- unique(unlist(regmatches(
    src, gregexpr("(?<=intraitR::)[A-Za-z._][A-Za-z._0-9]*", src, perl = TRUE))))
  expect_true(all(called %in% exported),
              info = paste("not exported:",
                           paste(setdiff(called, exported), collapse = ", ")))
})
