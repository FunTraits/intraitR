# =============================================================================
# t26_campaign_prepare.R -- build the T-26 La Saudrune example data set
#
# Turns the working files of the FishInTrait campaign into the four tables
# under inst/extdata/T26_Saudrune/ that load_t26_saudrune() reads:
#
#   t26_campaign_landmarks.csv.gz      long-format coordinates, 25 points per
#                                      digitized specimen (one digitization each)
#   t26_campaign_specimens.csv         one row per digitized specimen: identity,
#                                      current determination, quality, scale
#   t26_campaign_repeatability.csv.gz  the `bias` sheet of the digitizer: the
#                                      same individuals re-digitized blind, in
#                                      `digitize_landmarks()`'s repeat mode
#   t26_campaign_qc_log.csv            what was excluded from the above, and why
#
# Not run automatically: data-raw/ scripts are run once, by hand, when the
# shipped tables need to be regenerated. The raw files are NOT distributed.
#
# IDENTITY. A specimen is its `uid`, `SITE_YYYYMMDD_NNNN`, immutable, anchored on
# the photograph's fingerprint (export/uid_registry.csv); an individual on a
# multi-fish plate is `<uid>_iK`. The species is a revisable hypothesis and is
# taken from the LAST non-superseded line of export/determinations.csv, never
# from a file name and never from the digitizing workbook (see the campaign's
# README_identite.md). export/taxa.csv supplies the injective species codes.
# All four tables are written in ONE run so that they share one set of codes:
# the 1.34.0 tables had been regenerated piecemeal and no longer joined.
#
# EXCLUSIONS, ALL LOGGED. A record saved with no anatomical landmark at all; a
# specimen whose uid has no entry in export/specimens.csv (no identity); a
# specimen with no current determination (no species). Nothing is guessed.
# Point 25 is reserved by the digitizer and currently never placed: it is kept
# as an all-NA row so the table stays rectangular (25 rows per specimen).
#
# A fifth file, qc/t26_remeasure_list_<date>.csv, is written to the CAMPAIGN
# folder (not the package): photographs to re-digitize, with the reason.
# =============================================================================

library(readxl)

project <- path.expand(
  "~/Library/CloudStorage/OneDrive-Personnel/iCloud Drive/00_CampagneIntrait/00_project")
pkg     <- path.expand(
  "~/Library/CloudStorage/OneDrive-Personnel/iCloud Drive/00_Papier_5_EnProjet/Packages/intraitR")
outdir  <- file.path(pkg, "inst", "extdata", "T26_Saudrune")
site    <- "SAUDRUNESUDTOULOUSE"
pts     <- 1:25

xlsx <- file.path(project, "measurements", "landmarks.xlsx")
meas <- as.data.frame(read_excel(xlsx, sheet = "measurements", .name_repair = "minimal"))
bias <- as.data.frame(read_excel(xlsx, sheet = "bias",         .name_repair = "minimal"))
message(nrow(meas), " digitizations, ", nrow(bias), " repeat records")

## ---- 1. identity, current determination, taxon codes ------------------------
export <- utils::read.csv(file.path(project, "export", "specimens.csv"),
                          stringsAsFactors = FALSE)
export <- export[export$site == site, , drop = FALSE]
det <- utils::read.csv(file.path(project, "export", "determinations.csv"),
                       stringsAsFactors = FALSE)
det <- det[startsWith(det$uid, site) & toupper(det$superseded) != "TRUE", , drop = FALSE]
det <- det[!duplicated(det$uid, fromLast = TRUE), , drop = FALSE]   # last line wins
taxa <- utils::read.csv(file.path(project, "export", "taxa.csv"), stringsAsFactors = FALSE)

uid_of <- function(code) sub("_i[0-9]+$", "", code)
ind_of <- function(code) {
  k <- regmatches(code, regexpr("_i[0-9]+$", code))
  out <- rep(1L, length(code)); out[grepl("_i[0-9]+$", code)] <- as.integer(sub("_i", "", k)); out
}
coord <- function(d, p, ax) suppressWarnings(as.numeric(d[[paste0(p, "_", ax)]]))

## ---- 2. exclusions ----------------------------------------------------------
meas$specimen <- as.character(meas$specimen)
uid   <- uid_of(meas$specimen)
anat  <- rowSums(sapply(1:19, function(p) is.finite(coord(meas, p, "X")))) > 0
known <- uid %in% export$specimen_code
deter <- uid %in% det$uid

qc <- rbind(
  data.frame(code = meas$specimen[!anat],
             reason = "row saved with no anatomical landmark at all (empty configuration); excluded"),
  data.frame(code = meas$specimen[anat & !known],
             reason = "no entry in the campaign specimen export (export/specimens.csv): no identity, excluded rather than guessed"),
  data.frame(code = meas$specimen[anat & known & !deter],
             reason = "no current determination in export/determinations.csv: no species, excluded rather than guessed"))
keep <- anat & known & deter
## A photograph holding both a bare record and indexed `_iK` records is a
## convention conflict: the same fish digitized again under a plate index. The
## bare record is kept; the indexed siblings are excluded pending a decision.
bare     <- meas$specimen[keep & !grepl("_i[0-9]+$", meas$specimen)]
conflict <- keep & grepl("_i[0-9]+$", meas$specimen) & uid %in% bare
qc <- rbind(qc, data.frame(code = meas$specimen[conflict],
  reason = "photograph also digitized under its bare code: same fish measured again under a plate index; excluded pending an operator decision (bare record kept)"))
qc <- qc[order(qc$code), , drop = FALSE]
keep <- keep & !conflict
meas <- meas[keep, , drop = FALSE]; uid <- uid[keep]
stopifnot(!anyDuplicated(meas$specimen))
meas <- meas[order(meas$specimen), , drop = FALSE]; uid <- uid_of(meas$specimen)
message(nrow(meas), " specimen(s) kept, ", nrow(qc), " excluded")

## ---- 3. long tables ---------------------------------------------------------
to_long <- function(d, specimen, code, operator, extra = NULL) {
  out <- do.call(rbind, lapply(pts, function(p) {
    df <- data.frame(specimen = specimen, code = code, operator = operator,
                     stringsAsFactors = FALSE)
    if (!is.null(extra)) df <- cbind(df, extra)
    df$landmark <- p
    df$X <- round(coord(d, p, "X"), 3); df$Y <- round(coord(d, p, "Y"), 3)
    df
  }))
  out[order(out$specimen, out$landmark), , drop = FALSE]
}
op <- ifelse(is.na(meas$operator) | !nzchar(meas$operator), "AT", trimws(meas$operator))
long <- to_long(meas, meas$specimen, meas$specimen, op)

## repeat mode writes `<code>_<operator>_rep<N>`: the replicate is the LAST
## token and the operator label holds no underscore, so split from the right.
rx <- "^(.*)_([^_]+)_rep([0-9]+)$"
stopifnot(all(grepl(rx, bias$specimen)))
rep_code <- sub(rx, "\\1", bias$specimen)
rep_op   <- sub(rx, "\\2", bias$specimen)
rep_n    <- as.integer(sub(rx, "\\3", bias$specimen))
o <- order(rep_code, rep_op, rep_n); bias <- bias[o, , drop = FALSE]
repeatability <- to_long(bias, as.character(bias$specimen), rep_code[o], rep_op[o],
                         extra = data.frame(replicate = rep_n[o]))
repeatability <- repeatability[c("specimen", "code", "operator", "replicate",
                                 "landmark", "X", "Y")]

## ---- 4. specimen table ------------------------------------------------------
e <- export[match(uid, export$specimen_code), ]
d <- det[match(uid, det$uid), ]
specimens <- data.frame(
  code = meas$specimen, uid = uid, individual = ind_of(meas$specimen),
  photo = meas$photo_file, species = d$taxon,
  species_code = taxa$species_code[match(d$taxon, taxa$species)],
  confidence = d$confidence, determined_by = d$determined_by,
  site = site, date = sub("^[^_]+_([0-9]{8})_.*$", "\\1", uid), operator = op,
  quality = meas$quality, reviewed = meas$reviewed,
  n_landmarks = rowSums(sapply(pts, function(p) is.finite(coord(meas, p, "X")))),
  ruler_mm = meas$ruler_mm,
  mm_per_px = round(suppressWarnings(as.numeric(meas$mm_per_px)), 9),
  img_w = meas$img_w, img_h = meas$img_h, photo_hash = meas$photo_hash,
  app_version = meas$app_version, digitized = substr(as.character(meas$timestamp), 1, 10),
  stringsAsFactors = FALSE)
stopifnot(!anyNA(specimens$species), setequal(specimens$code, unique(long$code)))

## ---- 5. write ---------------------------------------------------------------
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
wgz <- function(df, file) { con <- gzfile(file.path(outdir, file), "w")
  utils::write.csv(df, con, row.names = FALSE, na = ""); close(con) }
wgz(long, "t26_campaign_landmarks.csv.gz")
wgz(repeatability, "t26_campaign_repeatability.csv.gz")
utils::write.csv(specimens, file.path(outdir, "t26_campaign_specimens.csv"),
                 row.names = FALSE, na = "")
utils::write.csv(qc, file.path(outdir, "t26_campaign_qc_log.csv"), row.names = FALSE)

## ---- 6. what to re-digitize (campaign QC artefact, not shipped) --------------
digitized <- unique(uid_of(as.character(meas$specimen)))
never <- export[!export$specimen_code %in% digitized, , drop = FALSE]
anat_missing <- sapply(seq_len(nrow(meas)), function(i)
  paste(which(!is.finite(sapply(1:19, function(p) coord(meas, p, "X")[i]))), collapse = ","))
scale_missing <- sapply(seq_len(nrow(meas)), function(i)
  paste(c(20, 21)[!is.finite(sapply(20:21, function(p) coord(meas, p, "X")[i]))], collapse = ","))
q <- suppressWarnings(as.numeric(meas$quality))
reason <- paste0(
  ifelse(nzchar(anat_missing), paste0("anatomical landmark(s) missing: ", anat_missing, "; "), ""),
  ifelse(nzchar(scale_missing), paste0("scale bar missing: ", scale_missing, "; "), ""),
  ifelse(is.finite(q) & q <= 2, paste0("operator quality score ", q, "; "), ""),
  ifelse(nzchar(e$qc_flag), paste0("export qc_flag=", e$qc_flag, "; "), ""))
remeasure <- rbind(
  data.frame(code = never$specimen_code, species = never$species,
             reason = "never digitized: photograph in export/specimens.csv with no measurement row"),
  data.frame(code = meas$specimen, species = d$taxon, reason = sub("; $", "", reason))[nzchar(reason), ],   # kept specimens only
  data.frame(code = qc$code[grepl("plate index", qc$reason)],
             species = det$taxon[match(uid_of(qc$code[grepl("plate index", qc$reason)]), det$uid)],
             reason = "duplicate digitization under a plate index: arbitrate (delete the index record, or renumber if it really is a second fish)"))
qcdir <- file.path(project, "qc"); dir.create(qcdir, showWarnings = FALSE)
utils::write.csv(remeasure, file.path(qcdir, sprintf("t26_remeasure_list_%s.csv", Sys.Date())),
                 row.names = FALSE)

message("written to ", outdir)
print(table(specimens$species)); print(table(specimens$date))
message(nrow(remeasure), " photograph(s) to re-digitize -> ", qcdir)
