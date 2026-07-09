
library(intraitR)

## A single seed covers every stochastic step below (missForest imputation,
## trait_space()'s bootstrap, itv_index()/trait_disparity()'s permutations,
## bootstrap_functional_space()), since they are all run in this same fixed
## order every time the script is sourced -- no need to reset it repeatedly.
set.seed(2026)

## ----------------------------------------------------------------------
## 1. The survey tables (raw data.frames), and the two ways to load them
## ----------------------------------------------------------------------
## Four related tables ship with the package; each is one call.
ops    <- load_t26_saudrune("operators")        # long landmark table, 2 operators
rep_df <- load_t26_saudrune("repeatability")    # replicate-digitization trial
ident  <- load_t26_saudrune("identifications")  # species / id_status, one row / fish
qc     <- load_t26_saudrune("qc_log")           # specimens excluded during data prep

## optional arguments: subset to one operator, and/or join species on import
op1    <- load_t26_saudrune("operators", operator = "Operator_1")
ops_sp <- load_t26_saudrune("operators", species = TRUE)   # adds species/id_status
stopifnot(identical(ops_sp$code, ops$code))                 # same rows, in order

cat(sprintf(
  "operators: %d rows | repeatability: %d rows | %d identified species | %d specimen(s) pre-excluded (see qc$reason)\n",
  nrow(ops), nrow(rep_df), length(unique(ident$species)), nrow(qc)
))
print(table(ident$species, ident$id_status, useNA = "ifany"))

## read_landmarks_csv() reshapes a long (specimen, landmark, X, Y) table into
## the p x k x n array the rest of the package expects; only carries the
## metadata you hand it explicitly via `metadata =` (no auto-detection), so
## build a one-row-per-specimen table first and pass species/id_status
## through that way -- everything downstream (fishmorph_segments(),
## fishmorph_ratios(), plot_fishmorph_shapes(), ...) then finds them
## automatically in `lm$metadata`.
sp_meta <- unique(ops_sp[c("specimen", "code", "species", "id_status")])
lm      <- read_landmarks_csv(ops_sp, metadata = sp_meta)   # 21 x 2 x 558
lm_rep  <- read_landmarks_csv(rep_df)                       # the repeatability trial
cat("read_landmarks_csv ->", paste(dim(lm$coords), collapse = " x "), "\n")

## load_t26_saudrune_landmarks() is a convenience wrapper doing both steps
## (load the table AND build the intrait_landmarks object) in one call:
lm_op1 <- load_t26_saudrune_landmarks("operators", operator = "Operator_1")
cat("load_t26_saudrune_landmarks ->", paste(dim(lm_op1$coords), collapse = " x "), "\n")

## ----------------------------------------------------------------------
## 2. Landmark quality control: standardize_geometry(), impute_landmarks(),
##    correct_geometry(), and the two visual-check plots
## ----------------------------------------------------------------------
spec <- "T-26-0051_Operator_1"          # same specimen shown at every step

## Successive corrections, each building on the previous:
lm_geom <- standardize_geometry(lm)     # orient + rescale + scale-bar + rotate
lm_imp  <- impute_landmarks(lm_geom)    # fill missing landmarks
lm_corr <- correct_geometry(lm_imp)     # enforce the FISHMORPH conventions

step_label <- function(txt) {
  mtext(txt, side = 3, line = 0.3, adj = 0, font = 2, cex = 1.05, col = "grey20")
}

op <- par(no.readonly = TRUE)
par(mfrow = c(2, 2), mar = c(4, 2, 2, 1), oma = c(0, 0, 1, 0), mgp = c(2, 1.2, 0),
    col.main = "transparent")   # hides each panel's specimen title; step_label() replaces it

cc <- lm$coords[, , spec]
axis_range <- function(v) {
  r  <- range(v, na.rm = TRUE)
  pad <- 0.12 * diff(r)
  lo <- floor(r[1] - pad)
  c(lo, lo + ceiling((diff(r) + 2 * pad) / 4) * 4)
}
plot_fishmorph_points(lm, specimen = spec, labels = FALSE, legend = FALSE,
                      asp = NA, xlim = axis_range(cc[, 1]), ylim = axis_range(cc[, 2]),
                      flip_y = FALSE)
step_label("1 - Raw (as digitized)")
plot_fishmorph_points(lm_geom, specimen = spec, labels = FALSE, legend = FALSE)
step_label("2 - standardize_geometry()")
plot_fishmorph_points(lm_imp, specimen = spec, labels = FALSE, legend = FALSE)
step_label("3 - impute_landmarks()")
plot_fishmorph_points(lm_corr, specimen = spec, labels = TRUE, legend = FALSE)
step_label("4 - correct_geometry()")

par(mfrow = c(1, 2), mar = c(4, 4, 2, 1), oma = c(0, 0, 1, 0), mgp = c(2, 1.2, 0),
    col.main = "transparent")
## align = TRUE for both panels: `lm`/`lm_corr` are not Procrustes-aligned,
## so overlaying raw (unaligned) coordinates would show each specimen's own
## position/scale in its photograph rather than genuine shape differences
## (see plot_fishmorph_shapes()'s `align` argument) -- aligning both lets
## the comparison isolate exactly what correct_geometry()/impute_landmarks()
## changed.
plot_fishmorph_shapes(lm, species = "Gobio occitaniae", align = TRUE)
mtext("a) Uncorrected specimens", side = 3, adj = 0)
plot_fishmorph_shapes(lm_corr, species = "Gobio occitaniae", align = TRUE)
mtext("b) Corrected specimens", side = 3, adj = 0)
par(op)

## ----------------------------------------------------------------------
## 3. Linear measurements and the FISHMORPH ratios
## ----------------------------------------------------------------------
## linear_distances() is the general engine: `pairs` is a named list of
## length-2 landmark indices, in raw digitization units unless a
## per-specimen `scale` is supplied. Here: standard length (1-2), body
## depth (3-4), eye diameter (13-14).
dists <- linear_distances(lm, pairs = list(SL = c(1, 2), BD = c(3, 4), ED = c(13, 14)))
cat("linear_distances (first rows):\n"); print(utils::head(dists))

## fishmorph_segments(): the 11 standard measurements, in cm, using the
## scale bar (landmarks 20-21). "missforest_phylo" imputes any measurement
## still missing after digitization (falls back to plain "missforest" with
## a warning if the `ape`/phylogeny data aren't usable), so every
## downstream step in this script works from a complete data set; because
## `lm` carries species metadata, it is used automatically as `groups` and
## carried over into the output.
segments <- fishmorph_segments(lm, scale_cm = 1, na_action = "missforest_phylo")
cat("\nFISHMORPH measurements (cm):\n")
print(summary(segments[c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")]))

## Optional: NA-out measurements whose geometry failed a convention check
## before imputing, rather than trusting a geometrically inconsistent value:
if (FALSE) {
  gc_check  <- correct_landmarks(lm, rule = "check_geometry")
  segments2 <- fishmorph_segments(lm, geometry_check = gc_check, na_action = "missforest_phylo")
}

## fishmorph_ratios(): the 9 dimensionless ecomorphological ratios, each
## mapping to a functional axis (feeding, locomotion, habitat use). No
## further na_action needed: `segments` is already complete.
ratios     <- fishmorph_ratios(segments)
ratio_cols <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
cat("\nMissing values per ratio (%) -- expect (near) 0 after missforest_phylo imputation above:\n")
print(round(colMeans(is.na(ratios[ratio_cols])) * 100, 1))

## Safety net: missForest-based imputation fills in almost everything, but
## is not guaranteed to resolve every possible missingness pattern (e.g. a
## column missing for an entire species with no informative predictors); a
## single `complete_r` computed once here, and reused below, keeps every
## trait-based analysis in this script restricted to fully complete rows
## without silently propagating any leftover NA.
complete_r <- stats::complete.cases(ratios[ratio_cols])
if (!all(complete_r)) {
  message(sprintf(
    paste(
      "Note: %d specimen(s) still have a missing ratio after missforest_phylo",
      "imputation; excluding them from the trait-based analyses below",
      "(shape-based ones are unaffected)."
    ),
    sum(!complete_r)
  ))
}

## morpho_ratios(): roll your own ratio scheme for anything outside the
## FISHMORPH set -- give the landmark pairs and which one normalises the
## rest (here standard length, "SL"). Ratios are dimensionless, so no scale
## bar is needed.
my_ratios <- morpho_ratios(
  lm,
  distances = list(SL = c(1, 2), BD = c(3, 4), HD = c(5, 6), ED = c(13, 14)),
  norm_by = "SL"
)
cat("\nCustom morpho_ratios (first rows):\n"); print(utils::head(my_ratios))

## fishmorph_shape_landmarks(): a convenience shortcut for a *per-digitization*
## shape-only subset (scale bar dropped, incomplete configs dropped). Section
## 4 below instead builds one *consensus* configuration per fish (averaged
## across operators) for the actual GPA/morphospace analysis, but this is
## the function to reach for when per-digitization shape data is enough.
lm_shape_quick <- fishmorph_shape_landmarks(lm, drop_incomplete = TRUE)
cat("\nfishmorph_shape_landmarks() ->", paste(dim(lm_shape_quick$coords), collapse = " x "), "\n")

## summary_traits(): a per-species trait table, ready to drop into a
## results table.
trait_tab <- summary_traits(ratios[ratio_cols], groups = ratios$species)
cat("\nPer-species trait summary:\n"); print(trait_tab)

## ----------------------------------------------------------------------
## 4. One consensus configuration per fish, averaged across operators
## ----------------------------------------------------------------------
## Every fish (`code`) was digitized once per operator; morphological space
## (section 5) and intraspecific variability (section 7) both need one
## configuration per *fish*, not per *digitization*, so this consensus is
## built once here and reused by both.
codes   <- unique(ops_sp$code)
A       <- lm$coords
code_of <- ops_sp$code[match(dimnames(A)[[3]], ops_sp$specimen)]  # config -> fish code
A_cons  <- array(NA_real_, dim = c(dim(A)[1], dim(A)[2], length(codes)),
                 dimnames = list(dimnames(A)[[1]], dimnames(A)[[2]], codes))
for (code in codes) {
  A_cons[, , code] <- apply(A[, , code_of == code, drop = FALSE], c(1, 2), mean, na.rm = TRUE)
}
meta_cons <- unique(ops_sp[c("code", "species", "id_status")])
rownames(meta_cons) <- meta_cons$code
meta_cons <- meta_cons[codes, ]
lm_consensus <- structure(list(coords = A_cons, scale = NULL, metadata = meta_cons),
                          class = "intrait_landmarks")
cat("Per-fish consensus configurations ->", paste(dim(lm_consensus$coords), collapse = " x "), "\n")

## ----------------------------------------------------------------------
## 5. morpho_space() -- MORPHOLOGICAL (shape) space from GPA
## ----------------------------------------------------------------------
lm_consensus_imp <- impute_landmarks(standardize_orientation(lm_consensus), method = "missforest_phylo")
shape_coords <- lm_consensus_imp$coords[1:19, , ]           # drop the scale bar (20-21)
complete     <- apply(shape_coords, 3, function(x) !anyNA(x))
lm_shape <- structure(
  list(coords = shape_coords[, , complete], scale = NULL, metadata = meta_cons[complete, ]),
  class = "intrait_landmarks"
)
gpa <- gpa_fish(lm_shape, remove_outliers = TRUE)   # reused again in section 7
## `gpa$metadata` (not `lm_shape$metadata`) from here on: remove_outliers =
## TRUE may drop further specimens beyond `lm_shape`'s own "complete" filter,
## and gpa_fish() keeps `$metadata` filtered in step with the cleaned
## `$coords` -- using `lm_shape$metadata` instead would silently misalign
## (or, for intraspecific_variability()'s stricter check, outright error
## with "Inputs have different numbers of observations") if any outlier was
## actually removed.

ms <- morpho_space(gpa, groups = gpa$metadata$species)
print(ms)
plot(ms, style = "spider", legend_title = "Species", legend_italic = TRUE,
     abbreviate_species = TRUE)

## ----------------------------------------------------------------------
## 6. trait_space() -- FUNCTIONAL space from the ratios
## ----------------------------------------------------------------------
## `ratios[complete_r, ]` is already complete (section 3), so only
## `remove_outliers` (a functional-space-level screen, unrelated to
## missing-value handling) is needed here. `ts` is reused in sections 8
## and 9 below.
ts <- trait_space(ratios[complete_r, c("species", ratio_cols)], remove_outliers = TRUE)

reset_group_colors()   # start colour assignment from scratch for this figure
species_cols <- group_colors(ts)   # data.frame(group, color)

op <- par(no.readonly = TRUE)
layout(matrix(c(0, 1, 1, 0, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 6, 6), nrow = 4, byrow = TRUE),
       heights = c(0.9, 1, 1, 0.4))
par(mar = c(0, 0, 0, 0))
plot_correlation_circle(ts, inner_circle = FALSE)
par(mar = c(4, 4, 3, 1))
plot(ts, style = "none", legend = FALSE)
plot(ts, style = "hull", legend = FALSE)
plot(ts, style = "density", legend = FALSE)
plot(ts, style = "spider", legend = FALSE)
par(mar = c(0, 0, 0, 0))
plot.new()
legend("center", legend = species_cols$group, col = species_cols$color, pch = 19,
       ncol = 4, bty = "n", cex = 1.5, xpd = NA)
par(op)

## ----------------------------------------------------------------------
## 7. intraspecific_variability() and itv_index() -- variability within
##    vs among species
## ----------------------------------------------------------------------
## From Procrustes shape (the `gpa` built in section 5) -- `gpa$metadata`,
## not `lm_shape$metadata` (see the note in section 5) ...
iv_shape <- intraspecific_variability(gpa = gpa, groups = gpa$metadata$species, iter = 999)
print(iv_shape)
## ... or from any numeric trait matrix (the ratios):
iv_traits <- intraspecific_variability(traits = ratios[complete_r, ratio_cols],
                                       groups = ratios$species[complete_r], iter = 999)
print(iv_traits)

itv <- itv_index(ratios[complete_r, ratio_cols], groups = ratios$species[complete_r])
print(itv)
plot(itv, col.main = "transparent")

## ----------------------------------------------------------------------
## 8. measurement_error() and digitization_error() -- on the repeat trial
## ----------------------------------------------------------------------
## Percent measurement error and repeatability R (Bailey & Byrnes, 1990)
## for a single measurement (body length, Bl) from replicated digitizations
## of the same 25 fish.
segments_rep <- fishmorph_segments(lm_rep)
rep_meta     <- unique(rep_df[c("specimen", "code")])
indiv_rep    <- rep_meta$code[match(rownames(segments_rep), rep_meta$specimen)]

me_bl <- measurement_error(
  data.frame(individual = indiv_rep, value = segments_rep$Bl),
  individual = "individual", method = "anova"
)
print(me_bl)

## digitization_error(): decomposes placement error landmark by landmark;
## scale bar (20-21) excluded so only anatomical landmarks are assessed.
species_rep <- ident$species[match(indiv_rep, ident$code)]
derr <- digitization_error(lm_rep, individual = indiv_rep, species = species_rep,
                           exclude_landmarks = c(20, 21))
print(derr)
print(derr$by_landmark)   # landmarks ranked most -> least precise

## A more detailed, publication-style version of the same information,
## built directly from digitization_error()'s output (one row per landmark
## in `$by_landmark`, one row per individual x landmark in
## `$landmark_individual`): a boxplot of per-landmark placement error,
## ordered by increasing median bias and colour-graded to match.
bl_err <- derr$by_landmark
li_err <- derr$landmark_individual
ord <- bl_err$landmark[order(bl_err$median_bias_pct)]
li_err$landmark <- factor(li_err$landmark, levels = ord)

b   <- boxplot(sd_dist_pct ~ landmark, data = li_err, plot = FALSE)   # stats only, no plot yet
med <- bl_err$median_bias_pct[match(ord, bl_err$landmark)]
col_idx <- 1 + round(99 * (med - min(med)) / (max(med) - min(med)))
cols <- colorRampPalette(c("#dcecc9", "#fdbb84", "#b30000"))(100)[col_idx]

op <- par(no.readonly = TRUE)
par(mar = c(4.5, 4.5, 3, 1), mgp = c(2.6, 0.7, 0), las = 1)
n    <- length(ord)
ymax <- max(c(b$stats, b$out), na.rm = TRUE)
plot(NA, xlim = c(0.5, n + 0.5), ylim = c(0, ymax * 1.03),
     xlab = "", ylab = "Digitization bias (%)", axes = FALSE)
abline(h = axTicks(2), col = "grey92", lwd = 0.8)
bxp(b, add = TRUE, axes = FALSE, show.names = FALSE,
    boxfill = cols, boxwex = 0.62, boxcol = "grey40",
    staplewex = 0.5, outwex = 0.5,
    whisklty = 1, whiskcol = "grey45", staplecol = "grey45",
    medlwd = 2.6, medcol = "grey10",
    outpch = 21, outbg = "white", outcol = "grey50", outcex = 0.75)
axis(2, col = "grey40")
axis(1, at = 1:n, labels = ord, tick = FALSE)
mtext("Landmark (ordered by increasing median bias)", side = 1, line = 2.6)
par(op)

## ----------------------------------------------------------------------
## 9. trait_disparity() -- do species differ in overall dispersion?
## ----------------------------------------------------------------------
## Directly on the trait space built in section 6 ...
td <- trait_disparity(ts, iter = 999)
print(td)
## ... or on a raw trait matrix + groups:
td2 <- trait_disparity(ratios[complete_r, ratio_cols], groups = ratios$species[complete_r], iter = 999)
print(td2)

## ----------------------------------------------------------------------
## 10. Phylogeny and functional-richness sensitivity analyses
## ----------------------------------------------------------------------
if (requireNamespace("ape", quietly = TRUE)) {
  tree <- load_fishmorph_phylogeny()
  cat(sprintf("FISHMORPH phylogeny: %d tips\n", length(tree$tip.label)))

  ## phylo_pcoa(): phylogenetic axes for the species in this study --
  ## principal-coordinates decomposition of the patristic distances; the
  ## axes can be added as predictors to missForest imputation
  ## (na_action = "missforest_phylo", used throughout this script) or used
  ## as phylogenetic covariates.
  ppc <- phylo_pcoa(tree, species = unique(ratios$species), k = 5)
  print(ppc)
}

if (requireNamespace("geometry", quietly = TRUE)) {
  ## bootstrap_functional_space(): does representing species by individuals
  ## (not centroids) inflate functional richness? n_axes = 2 keeps the demo
  ## fast and matches the PC1-PC2 plots above.
  bf <- bootstrap_functional_space(ts, method = "convexhull", n_axes = 2, n_boot = 100)
  print(bf)
  plot(bf)

  ## compare_functional_richness(): across estimation methods. Convex hull
  ## is always available; dendrogram/TPD/hypervolume are added only if
  ## their optional packages are installed.
  methods <- "convexhull"
  if (requireNamespace("TPD", quietly = TRUE))         methods <- c(methods, "tpd")
  if (requireNamespace("hypervolume", quietly = TRUE)) methods <- c(methods, "hypervolume")
  fr <- compare_functional_richness(ts, methods = methods, n_axes = 2)
  print(fr)

  ## species_sensitivity(): who drives the individual-vs-centroid gap.
  ss <- species_sensitivity(ts, method = "convexhull", n_axes = 2)
  print(ss)   # species ranked by |mean % change in functional richness|
  plot(ss)
}

## End of pipeline_T26_saudrune.R
