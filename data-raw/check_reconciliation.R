# =============================================================================
# check_reconciliation.R -- does the reconciliation work, without launching the app
#
# Run this AFTER devtools::document() + devtools::install(), and BEFORE opening
# the digitizer. It reproduces exactly what the application does at launch --
# same folder, same workbook, same provenance lookup -- and prints what it
# found. Ten seconds, no Shiny, no clicking.
#
# If the last line says the specimen has LEFT the "new" queue, launching the app
# will behave the same way. If anything fails, it fails HERE, with the condition
# in plain sight rather than behind a notification.
# =============================================================================

library(intraitR)

PROJ <- path.expand(
  "~/Library/CloudStorage/OneDrive-Personnel/iCloud Drive/00_CampagneIntrait/00_project")
SITE  <- "SAUDRUNESUDTOULOUSE"
DATE  <- "20260427"
WATCH <- "SAUDRUNESUDTOULOUSE_20260427_BARBAR_025_AT"   # the specimen in question

photo_dir <- file.path(PROJ, "prepared", SITE, DATE)
xlsx      <- file.path(PROJ, "measurements", "landmarks.xlsx")

cat("\n== 0. the package is installed and exports what the app calls ==\n")
needed <- c("photo_hash", "photo_hash_cached", "photo_provenance_keys",
            "reconcile_photo_names", "digitize_landmarks",
            "landmark_journal_open", "landmark_journal_append",
            "consolidate_landmarks", "write_xlsx_atomic")
missing <- setdiff(needed, getNamespaceExports("intraitR"))
cat("version           :", as.character(utils::packageVersion("intraitR")), "\n")
cat("missing exports   :", if (length(missing)) paste(missing, collapse = ", ")
    else "none", "\n")
if (length(missing))
  stop("Re-run devtools::document() then devtools::install(): the app calls ",
       "these with intraitR:: and cannot reach them.", call. = FALSE)

cat("\n== 1. the photographs, as the app lists them ==\n")
photos <- list.files(photo_dir, full.names = TRUE, ignore.case = TRUE,
                     pattern = "\\.(jpe?g|png|gif|bmp|tiff?)$")
cat("photographs       :", length(photos), "in", photo_dir, "\n")
stopifnot(length(photos) > 0)
codes <- tools::file_path_sans_ext(basename(photos))
cat("watched photo here:", WATCH %in% codes, "\n")

cat("\n== 2. the workbook ==\n")
meas <- as.data.frame(readxl::read_excel(xlsx, sheet = "measurements",
                                         .name_repair = "minimal"),
                      stringsAsFactors = FALSE)
cat("rows              :", nrow(meas), "\n")
cat("watched measured  :", WATCH %in% meas$specimen,
    " (FALSE is the symptom: it is measured under its OLD code)\n")

cat("\n== 3. provenance, discovered the way digitize_landmarks() does ==\n")
pdir <- file.path(dirname(dirname(xlsx)), "journal")
prov <- photo_provenance_keys(pdir)
cat("journal directory :", pdir, "\n")
cat("provenance keys   :", length(prov), "\n")
if (WATCH %in% names(prov)) {
  k <- prov[[WATCH]]
  sib <- names(prov)[prov == k]
  cat("same original as  :", paste(setdiff(sib, WATCH), collapse = ", "), "\n")
  cat("  ... measured?   :",
      paste(intersect(setdiff(sib, WATCH), meas$specimen), collapse = ", "), "\n")
}

cat("\n== 4. reconcile (this is the call the app makes) ==\n")
hashes <- photo_hash_cached(photos, file.path(PROJ, "measurements",
                                              "landmark_journal",
                                              "photo_hash_cache.tsv"))
res <- reconcile_photo_names(meas, photos, hashes, provenance = prov)
ch  <- res$changes
cat("renamed           :", sum(ch$status == "renamed"), "\n")
cat("ambiguous         :", sum(ch$status == "ambiguous"), "\n")
cat("superseded        :", sum(ch$status == "superseded"),
    " (same digitization present twice -- duplicate dropped)\n")
cat("frame_changed     :", sum(ch$status == "frame_changed"),
    " (same fish, re-cropped picture -- must be measured again)\n")
cat("image_changed     :", sum(ch$status == "image_changed"),
    " (this photograph re-cropped since digitizing -- points cleared)\n")
if (any(ch$status == "image_changed"))
  print(ch[ch$status == "image_changed", c("specimen_old", "photo_file_old")])
if (any(ch$status == "renamed"))
  print(utils::head(ch[ch$status == "renamed",
                       c("specimen_old", "specimen_new")], 10))
if (any(ch$status == "frame_changed")) {
  cat("\nsame fish, DIFFERENT picture -- coordinates not transferable,",
      "these must be measured again:\n")
  print(ch[ch$status == "frame_changed",
           c("specimen_old", "photo_file_new")])
}

cat("\n== 5. the queue, before and after ==\n")
q_before <- setdiff(codes, meas$specimen)
q_after  <- setdiff(codes, res$data$specimen)
cat("\"new\" queue       :", length(q_before), "->", length(q_after),
    "photograph(s)\n")
cat("watched in \"new\"  :", WATCH %in% q_before, "->", WATCH %in% q_after, "\n")

cat("\n== VERDICT ==\n")
## THE TEST IS THE END STATE, NOT THE WORK DONE. An earlier version asked for
## the queue to SHRINK, which is only true the first time: once the re-keyings
## have been applied and written, `renamed` is legitimately 0 and the queue is
## already right. Reading that as a failure made a repaired workbook look
## broken -- a false alarm is not free, it costs exactly the trust the check
## exists to give.
if (WATCH %in% q_after) {
  cat("STILL BROKEN: the watched specimen is in the \"new\" queue although it\n",
      "is measured. Send this whole output back.\n", sep = "")
} else if (sum(ch$status == "renamed") > 0) {
  cat("OK -- and there was work to do: ", sum(ch$status == "renamed"),
      " row(s) re-keyed just now.\n",
      "The workbook on disk keeps the old codes until you press\n",
      "\"Write the workbook now\" in the digitizer.\n", sep = "")
} else {
  cat("OK -- and nothing left to do: the re-keyings are already applied and\n",
      "written. `renamed = 0` here means the workbook is in step with the\n",
      "photographs, not that the reconciliation failed.\n", sep = "")
}
if (sum(ch$status == "superseded") > 0)
  cat("\n", sum(ch$status == "superseded"), " dead duplicate row(s) are still",
      " in the workbook on disk.\nThey disappear at the next \"Write the",
      " workbook now\"; no measurement is lost\n(their surviving twin holds",
      " the identical coordinates).\n", sep = "")
if (sum(ch$status == "ambiguous") > 0)
  cat("\n", sum(ch$status == "ambiguous"), " genuine conflict(s) remain: the",
      " same photograph digitized twice under\ntwo names, with DIFFERENT",
      " coordinates. Only you can say which entry to keep:\n",
      "  ch <- reconcile_photo_names(meas, photos, hashes, provenance = prov)$changes\n",
      "  subset(ch, status == \"ambiguous\")\n", sep = "")
