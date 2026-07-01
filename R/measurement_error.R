#' Estimate measurement error from replicated digitization
#'
#' Quantifies measurement error and repeatability from repeated
#' measurements (replicate digitizations of the same specimen), for either
#' univariate linear traits/ratios (ANOVA-based percent measurement error
#' and repeatability, Bailey & Byrnes, 1990; Yezerinac et al., 1992) or
#' landmark shape data (Procrustes ANOVA, Fruciano, 2016). Assessing
#' measurement error is a necessary step before interpreting any
#' biological pattern of intraspecific variability, since it partitions
#' observed variance into a biological and a technical (digitization)
#' component.
#'
#' @param x For `method = "anova"`: either a numeric matrix/data.frame with
#'   one row per individual and one column per replicate measurement, or a
#'   long-format `data.frame` with an `individual` grouping column and a
#'   `value` column. For `method = "procrustes"`: an object of class
#'   `"intrait_gpa"` built from replicate-digitized specimens (i.e. each
#'   individual appears multiple times in the sample, once per
#'   digitization replicate).
#' @param individual For long-format univariate input, the name of the
#'   column identifying individuals. For `method = "procrustes"`, a factor
#'   (or character vector) of the same length as the number of specimens
#'   in `x`, giving the individual identity of each replicate. Required
#'   for `method = "procrustes"`.
#' @param method Character, one of `"anova"` (default) or `"procrustes"`.
#' @param iter Integer, number of permutations for `method = "procrustes"`.
#'   Defaults to `999`.
#'
#' @return An object of class `"intrait_measurement_error"`.
#'   For `method = "anova"`, a list with `anova_table` (a one-way ANOVA of
#'   trait value on individual identity), `percent_measurement_error`
#'   (`%ME`, the proportion of total variance attributable to measurement
#'   error), and `repeatability` (the intraclass correlation coefficient,
#'   `R`). For `method = "procrustes"`, a list with `procD_table`, the
#'   Procrustes ANOVA table testing whether shape variance among
#'   individuals exceeds variance among replicates within individuals.
#'
#' @details
#' For `method = "anova"`, with among-individual and residual (replicate)
#' mean squares \eqn{MS_a} and \eqn{MS_e} from a one-way ANOVA, and `n`
#' replicates per individual:
#' \deqn{\%ME = \frac{MS_e}{MS_e + MS_a} \times 100}
#' \deqn{R = \frac{MS_a - MS_e}{MS_a + (n - 1) MS_e}}
#' Low `%ME` (and high `R`, close to 1) indicate that measurement error is
#' small relative to genuine among-individual variation, and that
#' subsequent analyses of intraspecific variability
#' ([intraspecific_variability()]) are unlikely to be confounded by
#' digitization noise.
#'
#' @references
#' Bailey RC, Byrnes J (1990). A new, old method for assessing measurement
#' error in both univariate and multivariate morphometric studies.
#' Systematic Zoology, 39(2), 124-130.
#'
#' Yezerinac SM, Lougheed SC, Handford P (1992). Measurement error and
#' morphometric studies: statistical power and observational error.
#' Systematic Biology, 41(4), 471-482.
#'
#' Fruciano C (2016). Measurement error in geometric morphometrics.
#' Development Genes and Evolution, 226(3), 139-158.
#'
#' @seealso [gpa_fish()], [intraspecific_variability()]
#'
#' @examples
#' set.seed(1)
#' replicate_data <- data.frame(
#'   r1 = rnorm(10, 50, 5), r2 = rnorm(10, 50, 5), r3 = rnorm(10, 50, 5)
#' )
#' rownames(replicate_data) <- paste0("ind", 1:10)
#' measurement_error(replicate_data, method = "anova")
#'
#' @export
#' @importFrom geomorph geomorph.data.frame procD.lm
measurement_error <- function(x, individual = NULL, method = c("anova", "procrustes"), iter = 999) {
  method <- match.arg(method)

  if (method == "anova") {
    if (is.matrix(x) || (is.data.frame(x) && is.null(individual))) {
      x <- as.data.frame(x)
      if (is.null(rownames(x))) rownames(x) <- paste0("ind", seq_len(nrow(x)))
      long <- utils::stack(x)
      names(long) <- c("value", "replicate")
      long$individual <- factor(rep(rownames(x), times = ncol(x)))
    } else {
      if (is.null(individual)) stop("`individual` is required for long-format input.", call. = FALSE)
      long <- x
      if (!"value" %in% names(long)) stop("Long-format `x` must contain a 'value' column.", call. = FALSE)
      long$individual <- factor(long[[individual]])
    }

    n_rep_per_ind <- table(long$individual)
    if (length(unique(as.vector(n_rep_per_ind))) > 1) {
      warning("Unequal numbers of replicates per individual; repeatability estimate follows Bailey & Byrnes (1990) approximation using the mean replicate count.", call. = FALSE)
    }
    n_rep <- mean(n_rep_per_ind)

    fit <- stats::aov(value ~ individual, data = long)
    tab <- summary(fit)[[1]]
    ms_among <- tab["individual", "Mean Sq"]
    ms_error <- tab["Residuals", "Mean Sq"]

    pct_me <- ms_error / (ms_error + ms_among) * 100
    repeatability <- (ms_among - ms_error) / (ms_among + (n_rep - 1) * ms_error)

    result <- list(
      method = "ANOVA-based measurement error (Bailey & Byrnes, 1990)",
      anova_table = tab,
      percent_measurement_error = pct_me,
      repeatability = repeatability,
      n_replicates = n_rep
    )
  } else {
    if (!inherits(x, "intrait_gpa")) {
      stop("For method = 'procrustes', `x` must be an object returned by gpa_fish(), built from replicate-digitized specimens.", call. = FALSE)
    }
    if (is.null(individual)) {
      stop("`individual` (identity of the specimen each replicate belongs to) is required for method = 'procrustes'.", call. = FALSE)
    }
    individual_f <- factor(individual)
    if (length(individual_f) != dim(x$coords)[3]) {
      stop("`individual` must have one entry per specimen (replicate) in `x`.", call. = FALSE)
    }
    gdf <- geomorph::geomorph.data.frame(coords = x$coords, individual = individual_f)
    fit <- geomorph::procD.lm(coords ~ individual, data = gdf, iter = iter, print.progress = FALSE)

    result <- list(
      method = "Procrustes ANOVA measurement error (Fruciano, 2016)",
      procD_table = fit$aov.table
    )
  }

  structure(result, class = "intrait_measurement_error")
}

#' @export
print.intrait_measurement_error <- function(x, ...) {
  cat("<intrait_measurement_error>\n")
  cat(" Method:", x$method, "\n\n")
  if (!is.null(x$anova_table)) {
    print(x$anova_table)
    cat(sprintf("\n Percent measurement error (%%ME): %.2f%%\n", x$percent_measurement_error))
    cat(sprintf(" Repeatability (R): %.3f\n", x$repeatability))
  }
  if (!is.null(x$procD_table)) {
    print(x$procD_table)
  }
  invisible(x)
}
