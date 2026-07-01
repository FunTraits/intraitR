## intraitR: comparing na_action options in trait_space()
##
## This demo simulates a FISHMORPH-style landmark data set, computes the
## nine FISHMORPH ratios, artificially deletes a known set of values (so
## the *true* values are still available for comparison), and shows how
## each `na_action` option of trait_space() handles them -- including
## "missforest" (random-forest imputation, Stekhoven & Buhlmann, 2012)
## benchmarked against "impute_mean" and "impute_group_mean" for
## imputation accuracy against the true (deleted) values.

library(intraitR)

set.seed(42)
fish     <- simulate_fishmorph_points(n_per_species = 10, n_replicates = 1)
segments <- fishmorph_segments(fish)
ratios   <- fishmorph_ratios(segments)
species  <- fish$metadata$species

ratio_cols  <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
traits_true <- ratios[, ratio_cols]

## --- 1. Introduce missing values at known locations -----------------------

n_specimens <- nrow(traits_true)
n_cells     <- n_specimens * length(ratio_cols)
n_missing   <- round(0.10 * n_cells)  # ~10% missing, a realistic gap rate

set.seed(1)
missing_cells <- unique(data.frame(
  row = sample(n_specimens, n_missing, replace = TRUE),
  col = sample(ratio_cols, n_missing, replace = TRUE),
  stringsAsFactors = FALSE
))

traits_na   <- traits_true
true_values <- numeric(nrow(missing_cells))
for (i in seq_len(nrow(missing_cells))) {
  r  <- missing_cells$row[i]
  cl <- missing_cells$col[i]
  true_values[i]   <- traits_true[r, cl]
  traits_na[r, cl] <- NA
}

cat(sprintf(
  "Introduced %d missing values out of %d cells (%.1f%%)\n\n",
  nrow(missing_cells), n_cells, 100 * nrow(missing_cells) / n_cells
))

## --- 2. na_action = "fail" (default): trait_space() refuses to run --------

cat("--- na_action = \"fail\" (default) ---\n")
err <- tryCatch(trait_space(traits_na, groups = species), error = function(e) e)
cat("Error:", conditionMessage(err), "\n\n")

## --- 3. na_action = "omit": drop incomplete specimens ---------------------

cat("--- na_action = \"omit\" ---\n")
ts_omit <- trait_space(traits_na, groups = species, na_action = "omit")
cat(sprintf("Retained %d of %d specimens.\n\n", nrow(ts_omit$scores), n_specimens))

## --- 4. na_action = "impute_mean" / "impute_group_mean" -------------------
## trait_space() only returns ordination scores, not the imputed trait
## table itself, so we recompute the same simple imputations by hand here
## purely to compare *imputed* vs *true* values below.

impute_mean_table <- function(df) {
  for (cl in names(df)) df[[cl]][is.na(df[[cl]])] <- mean(df[[cl]], na.rm = TRUE)
  df
}
impute_group_mean_table <- function(df, groups) {
  groups <- factor(groups)
  for (cl in names(df)) {
    for (g in levels(groups)) {
      idx <- groups == g & is.na(df[[cl]])
      if (any(idx)) df[[cl]][idx] <- mean(df[[cl]][groups == g], na.rm = TRUE)
    }
  }
  df
}

imp_mean       <- impute_mean_table(traits_na)
imp_group_mean <- impute_group_mean_table(traits_na, species)

ts_mean       <- trait_space(traits_na, groups = species, na_action = "impute_mean")
ts_group_mean <- trait_space(traits_na, groups = species, na_action = "impute_group_mean")

## --- 5. na_action = "missforest" -------------------------------------------

have_missforest <- requireNamespace("missForest", quietly = TRUE)
if (have_missforest) {
  set.seed(2)
  imp_rf <- missForest::missForest(
    cbind(traits_na, .group = factor(species)), verbose = FALSE
  )$ximp
  imp_rf$.group <- NULL

  set.seed(2)
  ts_rf <- trait_space(traits_na, groups = species, na_action = "missforest")
} else {
  message(
    "Package 'missForest' not installed; skipping na_action = \"missforest\". ",
    "Install with install.packages(\"missForest\") to include it in the comparison."
  )
  imp_rf <- NULL
  ts_rf  <- NULL
}

## --- 6. Compare imputation accuracy against the true (deleted) values -----

extract_imputed <- function(imputed_traits) {
  vapply(seq_len(nrow(missing_cells)), function(i) {
    imputed_traits[missing_cells$row[i], missing_cells$col[i]]
  }, numeric(1))
}
rmse <- function(x, y) sqrt(mean((x - y)^2))

methods <- c("impute_mean", "impute_group_mean", if (have_missforest) "missforest")
rmses <- c(
  rmse(extract_imputed(imp_mean), true_values),
  rmse(extract_imputed(imp_group_mean), true_values),
  if (have_missforest) rmse(extract_imputed(imp_rf), true_values)
)

comparison <- data.frame(method = methods, rmse_vs_true = round(rmses, 4))

cat("--- Imputation accuracy vs. the true (deleted) values ---\n")
print(comparison, row.names = FALSE)
cat(
  "\nLower RMSE = imputed values closer to the true, pre-deletion values.\n",
  "impute_mean/impute_group_mean shrink imputed values toward a (group) mean\n",
  "and ignore correlations among the other 8 traits; missforest exploits\n",
  "those correlations (and `groups`) and is expected to do better whenever\n",
  "traits are correlated -- as FISHMORPH ratios typically are.\n",
  sep = ""
)

cat("\n--- trait_space() summary per na_action ---\n")
cat(sprintf("omit:               %d specimens retained\n", nrow(ts_omit$scores)))
cat(sprintf(
  "impute_mean:        %d specimens, PC1 = %.1f%%\n",
  nrow(ts_mean$scores), ts_mean$var_explained[1]
))
cat(sprintf(
  "impute_group_mean:  %d specimens, PC1 = %.1f%%\n",
  nrow(ts_group_mean$scores), ts_group_mean$var_explained[1]
))
if (have_missforest) {
  cat(sprintf(
    "missforest:         %d specimens, PC1 = %.1f%%\n",
    nrow(ts_rf$scores), ts_rf$var_explained[1]
  ))
}

