################################################################################
#  Shared helpers of the analysis scripts
################################################################################

# The nine unitless FISHMORPH ratios (Villeger et al. 2010; Brosse et al. 2021)
ALL_RATIOS <- c("BEl", "VEp", "REs", "OGp", "RMl", "BLs", "PFv", "PFs", "CPt")
# ...and those the analyses use (PARAMS$ratios; a specimen needs all of them)
RATIO_COLS <- if (!is.null(PARAMS$ratios)) PARAMS$ratios else ALL_RATIOS
# The eleven linear measurements they are computed from
SEG_COLS <- c("Bl", "Bd", "Hd", "Eh", "Mo", "PFi", "PFl", "Ed", "Jl", "CPd", "CFd")

# Write a table to results/tables/<name>.csv
write_table <- function(x, name) {
  f <- file.path("results", "tables", paste0(name, ".csv"))
  utils::write.csv(x, f, row.names = FALSE, na = "")
  invisible(f)
}

# Draw a base-graphics figure into results/figures/<name>.png and .pdf
save_figure <- function(name, draw,
                        width_mm = PARAMS$fig_width_mm, height_mm = PARAMS$fig_height_mm,
                        dpi = PARAMS$fig_dpi) {
  w <- width_mm / 25.4; h <- height_mm / 25.4
  grDevices::png(file.path("results", "figures", paste0(name, ".png")),
                 width = w, height = h, units = "in", res = dpi)
  on.exit(grDevices::dev.off(), add = TRUE)
  draw()
  grDevices::pdf(file.path("results", "figures", paste0(name, ".pdf")), width = w, height = h)
  draw()
  grDevices::dev.off()
  invisible(name)
}

# Landmark object of the raw data, rebuilt from the long tables of data/raw/
read_raw_landmarks <- function(prefix = "landmarks") {
  coords <- utils::read.csv(file.path("data", "raw", paste0(prefix, ".csv")),
                            stringsAsFactors = FALSE)
  meta <- utils::read.csv(file.path("data", "raw", paste0(prefix, "_specimens.csv")),
                          stringsAsFactors = FALSE, colClasses = "character")
  read_landmarks_csv(coords, metadata = meta)
}

# Keep the specimens `keep` (names) of a landmark object
subset_landmarks <- function(lm, keep) {
  sp <- dimnames(lm$coords)[[3]]
  i <- which(sp %in% keep)
  lm$coords <- lm$coords[, , i, drop = FALSE]
  if (!is.null(lm$metadata)) lm$metadata <- lm$metadata[i, , drop = FALSE]
  lm
}

# The analysed trait table written by 01_DATA_load_and_clean.R
read_traits <- function() {
  f <- file.path("data", "processed", "traits_analysed.csv")
  txt_cols <- intersect(c("specimen", "species", "site", "date"),
                        names(utils::read.csv(f, nrows = 1)))
  d <- utils::read.csv(f, stringsAsFactors = FALSE,
                       colClasses = stats::setNames(rep("character", length(txt_cols)), txt_cols))
  list(data = d, x = d[, RATIO_COLS], species = d$species)
}

# Pairwise matrix (symmetric) -> long table, upper triangle
pairwise_long <- function(m, value = "value") {
  idx <- which(upper.tri(m), arr.ind = TRUE)
  out <- data.frame(group_1 = rownames(m)[idx[, 1]], group_2 = colnames(m)[idx[, 2]],
                    v = m[idx], stringsAsFactors = FALSE)
  names(out)[3] <- value
  out
}
