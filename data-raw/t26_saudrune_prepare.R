# -----------------------------------------------------------------------
# Cleaning / QC pipeline for the T-26 La Saudrune real fish landmark data
# -----------------------------------------------------------------------
# Produces the four tables shipped in inst/extdata/T26_Saudrune/ and
# loadable with load_t26_saudrune(). This script is provided for full
# transparency and reproducibility of the cleaning pipeline; it is NOT run
# automatically (data-raw/ scripts are run once, by hand, when the package
# data needs to be regenerated) and the raw spreadsheets it reads are NOT
# distributed with the package, for two reasons: (1) package size, and (2)
# the raw identification file's "confidence"/"remarques" columns and the
# original photographs are project-internal working material rather than
# a finished, citable data product. Only the cleaned, analysis-ready
# tables below are bundled.
#
# Raw sources (not included in the package; adjust MPATH/IPATH to your
# local copy of the T_26_LaSaudrune project folder to re-run this script):
#   - T_26_Saudrune_mesures.xlsx
#       sheet "Principal": 2 operators x 1 digitization each, 21 FISHMORPH
#         landmarks (Brosse et al., 2021) per fish (567 rows).
#       sheet "Biais_ut": 1 operator x up to 10 replicate digitizations of
#         25 individuals, used for measurement_error()/digitization_error()
#         (250 rows).
#   - T-26_identifications_pilote.xlsx
#       sheet "donnees_poissons": species identification (curated, with an
#         AI-vision-assisted preliminary fallback) and capture metadata,
#         one row per fish (283 rows).
#
# As explicitly instructed by the data owner (A. Toussaint), this script
# does NOT attempt to correct or second-guess species identifications: it
# only records, via `id_status`, whether an identification was manually
# curated, still preliminary (AI-vision call only), or unresolved.
# -----------------------------------------------------------------------

library(readxl)
library(dplyr)

MPATH <- "T_26_LaSaudrune/T_26_Saudrune_mesures.xlsx"
IPATH <- "T_26_LaSaudrune/T-26_identifications_pilote.xlsx"
OUTDIR <- "inst/extdata/T26_Saudrune"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

qc_log <- list()
log_exclusion <- function(code, reason) {
  qc_log[[length(qc_log) + 1]] <<- data.frame(code = code, reason = reason, stringsAsFactors = FALSE)
}

norm_code <- function(x) {
  x <- trimws(as.character(x))
  x <- gsub("\\s*\\(.*\\)\\s*", "", x)   # drop parenthetical annotations, e.g. " (T-26-0066)"
  x <- gsub("_", "-", x, fixed = TRUE)
  x
}

## ---- 1. Identifications ----------------------------------------------
ident <- read_excel(IPATH, sheet = "donnees_poissons")
ident$code_norm <- norm_code(ident$Code)

build_species <- function(espece, rb_genre, rb_espece) {
  if (!is.na(espece)) return(list(species = espece, id_status = "curated"))
  if (!is.na(rb_espece) && !is.na(rb_genre) && !grepl("NA", rb_genre)) {
    return(list(species = paste(rb_genre, rb_espece), id_status = "preliminary"))
  }
  list(species = NA_character_, id_status = "unresolved")
}

sp_flag <- Map(build_species, ident$espece, ident$RB_Genre, ident$`RB_Espèce`)
ident$species <- vapply(sp_flag, `[[`, character(1), "species")
ident$id_status <- vapply(sp_flag, `[[`, character(1), "id_status")

# harmonise the two "uncertain Phoxinus" labels
ident$species[ident$species == "Phoxinus phoxinus ou bigerri"] <- "Phoxinus phoxinus/bigerri"

ident_clean <- ident %>%
  transmute(
    code = code_norm, species, id_status,
    french_name = nom_francais, stage = stade_adulte, confidence = confiance,
    n_individus, date_capture, site
  ) %>%
  distinct(code, .keep_all = TRUE)

write.csv(ident_clean, file.path(OUTDIR, "t26_identifications.csv"), row.names = FALSE)
cat("identifications:", nrow(ident_clean), "rows | curated =", sum(ident_clean$id_status == "curated"),
    "preliminary =", sum(ident_clean$id_status == "preliminary"),
    "unresolved =", sum(ident_clean$id_status == "unresolved"), "\n")

## ---- 2. Principal sheet (2 operators x 1 digitization) -> long format --
principal <- read_excel(MPATH, sheet = "Principal")
n_before <- nrow(principal)
principal <- principal[!is.na(principal$Code), ]
if (n_before - nrow(principal) > 0) {
  log_exclusion("(blank rows)", sprintf("%d fully blank spreadsheet row(s) dropped", n_before - nrow(principal)))
}
principal$code_norm <- norm_code(principal$Code)

unmatched <- setdiff(unique(principal$code_norm), ident_clean$code)
for (code in unmatched) {
  log_exclusion(code, paste(
    "code not found in identification file even after normalising '_'/'-' and",
    "removing parenthetical annotations; excluded from the analysis-ready dataset",
    "(kept out rather than guessed)"
  ))
}
principal_ok <- principal[!principal$code_norm %in% unmatched, ]

long_principal <- do.call(rbind, lapply(seq_len(nrow(principal_ok)), function(i) {
  row <- principal_ok[i, ]
  specimen <- paste0(row$code_norm, "_", row$Utilisateur)
  data.frame(
    specimen = specimen, code = row$code_norm, operator = row$Utilisateur,
    landmark = 1:21,
    X = as.numeric(row[paste0("X_", 1:21)]),
    Y = as.numeric(row[paste0("Y_", 1:21)])
  )
}))
write.csv(long_principal, file.path(OUTDIR, "t26_landmarks_operators.csv"), row.names = FALSE)
cat("\nlandmarks_operators long:", nrow(long_principal), "rows |",
    length(unique(long_principal$specimen)), "specimens |",
    length(unique(long_principal$code)), "fish\n")

## ---- 3. Biais_ut sheet (1 operator x up to 10 replicates) -> long format -
biais <- read_excel(MPATH, sheet = "Biais_ut")
n_before <- nrow(biais)
biais <- biais[!is.na(biais$Code), ]
if (n_before - nrow(biais) > 0) {
  log_exclusion("(blank rows, Biais_ut)", sprintf("%d fully blank spreadsheet row(s) dropped", n_before - nrow(biais)))
}
biais$code_norm <- norm_code(biais$Code)

unmatched_b <- setdiff(unique(biais$code_norm), ident_clean$code)
for (code in unmatched_b) {
  log_exclusion(code, "(Biais_ut) code not found in identification file; excluded")
}
biais_ok <- biais[!biais$code_norm %in% unmatched_b, ]

long_biais <- do.call(rbind, lapply(seq_len(nrow(biais_ok)), function(i) {
  row <- biais_ok[i, ]
  rep <- as.integer(row$Mesure)
  specimen <- paste0(row$code_norm, "_rep", rep)
  data.frame(
    specimen = specimen, code = row$code_norm, replicate = rep,
    operator = row$Utilisateur, site = row$Site, landmark = 1:21,
    X = as.numeric(row[paste0(1:21, "_X")]),
    Y = as.numeric(row[paste0(1:21, "_Y")])
  )
}))
write.csv(long_biais, file.path(OUTDIR, "t26_landmarks_repeatability.csv"), row.names = FALSE)
cat("\nlandmarks_repeatability long:", nrow(long_biais), "rows |",
    length(unique(long_biais$specimen)), "specimens |",
    length(unique(long_biais$code)), "fish\n")

## ---- 4. QC log ----------------------------------------------------------
qc_df <- do.call(rbind, qc_log)
write.csv(qc_df, file.path(OUTDIR, "t26_qc_log.csv"), row.names = FALSE)
cat("\nQC log entries:", nrow(qc_df), "\n")
print(qc_df)

## ---- 5. Species distribution (sanity check) ------------------------------
fish_species <- long_principal %>%
  distinct(code) %>%
  left_join(ident_clean, by = "code")
cat("\nFinal species distribution (n unique fish =", nrow(fish_species), "):\n")
print(table(fish_species$species, useNA = "ifany"))
cat("\nid_status distribution:\n")
print(table(fish_species$id_status, useNA = "ifany"))
