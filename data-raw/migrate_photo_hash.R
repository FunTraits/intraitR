# =============================================================================
# migrate_photo_hash.R -- one-off repair of a workbook digitized before the
# image fingerprint was recorded.
#
# THE PROBLEM THIS REPAIRS. The specimen code is the photograph's file name, and
# a determination corrected renames the file. Before `photo_hash` existed, that
# rename took the measurements away from the fish: the workbook kept the row
# under the old code, the digitizing queue matched on the new one, and an
# already-measured specimen reappeared in the "new" queue with nothing to say it
# had ever been touched.
#
# From now on reconcile_photo_names() handles this at every launch, because the
# fingerprint is written next to the coordinates. It cannot handle the
# RETROACTIVE case on its own: for a rename that already happened, the old name
# is gone from the folder and the table holds nothing that points at a file.
#
# The link has to come from wherever the provenance was written down. In a
# FishInTrait project that is the campaign journal, which records, for every
# import, which SOURCE image became which specimen. Two specimen codes sharing a
# source are the same fish, photographed once. Fingerprinting the sources gives
# the `provenance_keys` map reconcile_photo_names() needs, and the retroactive
# cases then resolve like any other.
#
# WHAT IT DOES NOT DO. A rename whose target code is already occupied by another
# digitized row is a duplicate, not a rename: the same photograph was measured
# twice, under two names, and only the operator can say which of the two entries
# is the one to keep. Those are reported as "ambiguous" and left strictly alone.
#
# Nothing is overwritten in place: the repaired workbook is written beside the
# original, which is left untouched.
# =============================================================================

library(intraitR)

## ---- where the project is ---------------------------------------------------
project <- "~/Library/CloudStorage/OneDrive-Personnel/iCloud Drive/00_CampagneIntrait/00_project"
project <- path.expand(project)

xlsx_in   <- file.path(project, "measurements", "landmarks.xlsx")
xlsx_out  <- file.path(project, "measurements", "landmarks_rehashed.xlsx")
photo_dir <- file.path(project, "photos")            # the CURRENT names
camp_jrnl <- file.path(project, "journal")           # the import journal

stopifnot(file.exists(xlsx_in), dir.exists(photo_dir))

## ---- the photographs, as they are named today -------------------------------
photos <- list.files(photo_dir, recursive = TRUE, full.names = TRUE,
                     pattern = "\\.(jpe?g|png|gif|bmp|tiff?)$", ignore.case = TRUE)
message(length(photos), " photograph(s) in ", photo_dir)
hashes <- photo_hash_cached(
  photos, file.path(project, "measurements", "landmark_journal",
                    "photo_hash_cache.tsv"))

## ---- the provenance map: photograph code -> key of the original -------------
## The campaign journal is long-format: one line per (record, specimen, field,
## value). The field read is `source_path`, and the LAST import of a specimen
## wins. Two codes sharing a key are one fish; reconcile_photo_names() then
## matches CODE TO CODE, which is what makes this work when the digitizing
## session runs over cropped working copies rather than the camera files.
known <- photo_provenance_keys(camp_jrnl)
message(length(known), " provenance key(s) available")

## ---- reconcile ---------------------------------------------------------------
sheets <- c("measurements", "bias")
out <- list(); changes <- NULL
for (sh in sheets) {
  d <- tryCatch(as.data.frame(readxl::read_excel(xlsx_in, sheet = sh,
                                                 .name_repair = "minimal"),
                              stringsAsFactors = FALSE),
                error = function(e) NULL)
  if (is.null(d) || !nrow(d)) { out[[sh]] <- d; next }
  r <- reconcile_photo_names(d, photos, hashes, provenance = known)
  out[[sh]] <- r$data
  if (nrow(r$changes)) changes <- rbind(changes, cbind(sheet = sh, r$changes))
}

if (is.null(changes)) {
  message("Nothing to reconcile: the workbook and the folder already agree.")
} else {
  ren <- changes[changes$status == "renamed", , drop = FALSE]
  amb <- changes[changes$status == "ambiguous", , drop = FALSE]
  message("\n", nrow(ren), " row(s) re-keyed:")
  if (nrow(ren)) print(utils::head(ren[, c("specimen_old", "specimen_new")], 50))
  message("\n", nrow(amb), " row(s) left alone as ambiguous -- the target code ",
          "is already taken, i.e. the same photograph was digitized twice ",
          "under two names. Decide which entry to keep, by hand:")
  if (nrow(amb)) print(amb[, c("specimen_old", "specimen_new", "photo_file_new")])
  utils::write.csv(changes, file.path(project, "qc", "photo_hash_migration.csv"),
                   row.names = FALSE)
}

## ---- write, beside the original ---------------------------------------------
writexl::write_xlsx(out, xlsx_out)
message("\nWritten: ", xlsx_out,
        "\nThe original is untouched. Check the re-keyed codes against the ",
        "photographs before putting it in place of ", basename(xlsx_in), ".")
