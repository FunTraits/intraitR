#-------------------------------------------------------------------------------
# 04_SUPP_repeatability.R — Measurement error (repeated digitizations)
#
# The same photographs digitized several times (repeat mode of the
# digitizer). For each of the 11 measurements, a one-way ANOVA on individual
# identity gives the percent measurement error (%ME) and the repeatability R
# (measurement_error; Bailey & Byrnes 1990). The placement error of each
# landmark is the distance of the replicates to their consensus position, as
# a percentage of the reference distance (points 1-2), excluding the scale
# bar (digitization_error).
#
# Prerequisites:
#   - data/raw/repeats.csv, data/raw/repeats_specimens.csv
#
# Output:
#   - results/tables/TableS7_repeatability_segments.csv
#   - results/tables/TableS8_landmark_placement_error.csv
#   - results/figures/FigS1_landmark_placement_error.png / .pdf
#
# Author  : {{AUTHOR}}
#-------------------------------------------------------------------------------
source("scripts/00_START_GeneralScript.R")

rep_lm <- read_raw_landmarks("repeats")

# Only the photographs digitized at least twice carry a replicate variance
n_rep <- table(rep_lm$metadata$individual)
single <- names(n_rep)[n_rep < 2]
if (length(single))
  message(length(single), " photograph(s) digitized only once, left out: ",
          paste(single, collapse = ", "))
rep_lm <- subset_landmarks(rep_lm, rep_lm$metadata$specimen[
  rep_lm$metadata$individual %in% names(n_rep)[n_rep >= 2]])
ind <- rep_lm$metadata$individual
if (length(unique(ind)) < 2) {
  message("Fewer than two photographs digitized at least twice: no measurement-error estimate.")
} else {

  # ============================================================================
  # 1. Repeatability of the measurements ----------------------------------------
  # ============================================================================
  seg <- fishmorph_segments(rep_lm, scale_cm = PARAMS$scale_cm)  # no scale bar -> NA, never pixels
  seg <- as.data.frame(seg)
  ind_seg <- ind[match(seg$specimen, rep_lm$metadata$specimen)]
  tab <- do.call(rbind, lapply(intersect(SEG_COLS, names(seg)), function(s) {
    ok <- is.finite(seg[[s]])
    me <- tryCatch(measurement_error(data.frame(individual = ind_seg[ok], value = seg[[s]][ok]),
                                     individual = "individual", method = "anova"),
                   error = function(e) NULL)
    data.frame(segment = s, n_individuals = length(unique(ind_seg[ok])),
               n_digitizations = sum(ok),
               pct_ME = if (is.null(me)) NA_real_ else me$percent_measurement_error,
               R = if (is.null(me)) NA_real_ else me$repeatability)
  }))
  write_table(tab, "TableS7_repeatability_segments")

  # ============================================================================
  # 2. Placement error per landmark ---------------------------------------------
  # ============================================================================
  sp <- rep_lm$metadata$species
  if (is.null(sp) || all(is.na(sp) | !nzchar(sp))) sp <- rep("not identified", length(ind))
  sp[is.na(sp) | !nzchar(sp)] <- "not identified"
  de <- tryCatch(digitization_error(rep_lm, individual = ind, species = sp,
                                    exclude_landmarks = intersect(c(20, 21, 25), seq_len(dim(rep_lm$coords)[1]))),
                 error = function(e) { message("Placement error not computed: ", conditionMessage(e)); NULL })
  if (!is.null(de)) {
    write_table(de$by_landmark, "TableS8_landmark_placement_error")
    save_figure("FigS1_landmark_placement_error", function() plot(de))
  }
}
