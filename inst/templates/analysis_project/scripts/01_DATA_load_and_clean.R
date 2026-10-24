#-------------------------------------------------------------------------------
# 01_DATA_load_and_clean.R — Landmarks, FISHMORPH traits and analysed sample
#
# Rebuilds the landmark configurations from data/raw/, applies the optional
# landmark corrections, computes the 11 FISHMORPH measurements and the 9
# unitless ratios, adds the individual records taken from the literature
# (when any), and defines the analysed sample: specimens with all nine
# ratios, of the chosen provenances, of species represented by at least
# PARAMS$min_n individuals.
#
# Prerequisites:
#   - data/raw/landmarks.csv, data/raw/landmarks_specimens.csv (photographs)
#   - data/raw/traits_literature.csv (literature records, optional)
#
# Output:
#   - data/processed/landmarks_clean.rds
#   - data/processed/fishmorph_segments.csv, fishmorph_ratios.csv
#   - data/processed/traits_analysed.csv
#   - results/tables/Table1_sample.csv
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")


# ============================================================================
# 1. Landmarks -> FISHMORPH measurements and ratios (photographs) -------------
# ============================================================================
r <- NULL
if (file.exists("data/raw/landmarks.csv")) {
  fish <- read_raw_landmarks("landmarks")
  if (isTRUE(PARAMS$impute))      fish <- impute_landmarks(fish)
  if (isTRUE(PARAMS$orientation)) fish <- standardize_orientation(fish)
  if (isTRUE(PARAMS$geometry))    fish <- correct_geometry(fish)
  saveRDS(fish, "data/processed/landmarks_clean.rds")

  segments <- fishmorph_segments(fish, scale_cm = PARAMS$scale_cm,
                                 scale_action = PARAMS$scale_action)
  ratios <- fishmorph_ratios(segments,
                             no_caudal_fin   = PARAMS$no_caudal_fin,
                             ventral_mouth   = PARAMS$ventral_mouth,
                             no_pectoral_fin = PARAMS$no_pectoral_fin)
  utils::write.csv(as.data.frame(segments), "data/processed/fishmorph_segments.csv", row.names = FALSE)
  utils::write.csv(as.data.frame(ratios), "data/processed/fishmorph_ratios.csv", row.names = FALSE)

  r <- as.data.frame(ratios)
  md <- fish$metadata
  src <- if (!is.null(md$source)) md$source else md$data_source
  src <- if (is.null(src)) rep(NA_character_, nrow(r)) else
    as.character(src)[match(r$specimen, md$specimen)]
  r$source <- ifelse(is.na(src) | !nzchar(src), "photographs", src)
  r$study_id <- NA_character_
}


# ============================================================================
# 2. Literature records (the nine ratios as published) ------------------------
# ============================================================================
if (file.exists("data/raw/traits_literature.csv")) {
  lit <- utils::read.csv("data/raw/traits_literature.csv", stringsAsFactors = FALSE,
                         colClasses = c(specimen = "character", site = "character",
                                        date = "character", study_id = "character"))
  lit$source <- "literature"
  if (is.null(r)) r <- lit else {
    cols <- unique(c(names(r), names(lit)))
    fill <- function(d) { for (cc in setdiff(cols, names(d))) d[[cc]] <- NA; d[, cols, drop = FALSE] }
    r <- rbind(fill(r), fill(lit))
  }
}


# ============================================================================
# 3. Analysed sample ----------------------------------------------------------
# ============================================================================
r$complete <- stats::complete.cases(r[, RATIO_COLS]) & !is.na(r$species) & nzchar(r$species)
if (!is.null(PARAMS$species)) r$complete <- r$complete & r$species %in% PARAMS$species
if (!is.null(PARAMS$sites) && !is.null(r$site)) r$complete <- r$complete & r$site %in% PARAMS$sites
if (!is.null(PARAMS$sources)) r$complete <- r$complete & r$source %in% PARAMS$sources
n_complete <- table(r$species[r$complete])
kept_species <- sort(names(n_complete)[n_complete >= PARAMS$min_n])
r$analysed <- r$complete & r$species %in% kept_species

keep_cols <- intersect(c("specimen", "species", "site", "date", "source", "study_id", "scale_units"),
                       names(r))
traits <- r[r$analysed, c(keep_cols, intersect(ALL_RATIOS, names(r))), drop = FALSE]
utils::write.csv(traits, "data/processed/traits_analysed.csv", row.names = FALSE)

# Table 1 — sample per species (every species measured, analysed or not)
all_sp <- sort(unique(r$species[!is.na(r$species) & nzchar(r$species)]))
tab1 <- do.call(rbind, lapply(all_sp, function(s) {
  d <- r[r$species %in% s, , drop = FALSE]
  a <- d[d$analysed, , drop = FALSE]
  st <- table(a$source)
  data.frame(species = s,
             n_measured = nrow(d),
             n_complete = sum(d$complete),
             n_analysed = nrow(a),
             n_sites = if (is.null(d$site)) NA_integer_ else length(unique(stats::na.omit(a$site))),
             sites = if (is.null(d$site)) "" else paste(sort(unique(stats::na.omit(a$site))), collapse = "; "),
             sources = paste(sprintf("%s %d", names(st), as.integer(st)), collapse = "; "),
             analysed = s %in% kept_species,
             stringsAsFactors = FALSE)
}))
write_table(tab1, "Table1_sample")

message(sprintf("%d records (%s), %d analysed (%d species with >= %d individuals).",
                nrow(r), paste(sprintf("%s %d", names(table(r$source)), as.integer(table(r$source))),
                               collapse = ", "),
                nrow(traits), length(kept_species), PARAMS$min_n))
