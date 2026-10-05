#' Bootstrap-based estimate of functional space volume from individual data
#'
#' Compares the functional richness obtained when species are represented
#' by real individuals to the functional richness obtained when species
#' are collapsed to their centroid (mean trait position), in a PCA-based
#' trait space, following the bootstrap procedure of Bertrand (2026,
#' Section "Bootstrap-based functional space estimates"). For each of
#' `n_boot` bootstrap "communities", one individual is drawn at random per
#' species and the functional richness of these individual-level points is
#' computed (`fd_boot`); this distribution is compared to a single
#' centroid-based reference richness (`fd_ref`), obtained by replacing
#' each species with the mean position of its individuals before
#' recomputing the same richness measure. Because a single randomly chosen
#' individual necessarily sits somewhere within (or at the edge of) its
#' species' own dispersion, `fd_boot` is expected to equal or exceed
#' `fd_ref` whenever species show non-trivial intraspecific trait
#' variability (ITV); this function also tests whether `fd_ref` sits
#' unusually low relative to the bootstrap distribution (see Details).
#'
#' @param x Either an object of class `"intrait_traitspace"` (from
#'   [trait_space()], built with `groups` supplied), or a
#'   `data.frame`/matrix of numeric traits (one row per individual), in
#'   which case `groups` must also be supplied and the same
#'   `log_transform`/`scale` preprocessing as [trait_space()] is applied
#'   before the PCA described below.
#' @param groups Required when `x` is a raw trait table (one value per
#'   individual, typically species identity); ignored (taken from
#'   `x$groups`) when `x` is an `"intrait_traitspace"` object.
#' @param method Character, the functional richness measure to compute in
#'   the PCA-based trait space for `fd_ref` and every `fd_boot` draw. One
#'   of:
#'   \describe{
#'     \item{`"convexhull"`}{(default) n-dimensional convex-hull volume
#'       (Villeger, Mason & Mouillot, 2008), via [geometry::convhulln()]
#'       (Qhull; Barber, Dobkin & Huhdanpaa, 1996) -- the measure used by
#'       Bertrand (2026) and the only one that strictly requires
#'       `nlevels(groups) > n_axes` (see `n_axes`). Requires the
#'       (Suggested) `geometry` package.}
#'     \item{`"dendrogram"`}{Total branch length of a UPGMA functional
#'       dendrogram (Petchey & Gaston, 2002), via [stats::hclust()]. A
#'       distance-based (non-volumetric) alternative that needs no
#'       additional Suggested package and places no restriction on the
#'       number of species relative to `n_axes`.}
#'     \item{`"tpd"`}{Functional richness from Trait Probability Density
#'       (Carmona, de Bello, Mason & Leps, 2019), via
#'       [TPD::TPDsMean()]/[TPD::TPDc()]/[TPD::REND()]: each species is
#'       represented by a fixed-bandwidth Gaussian kernel rather than a
#'       single point, so `FRichness` is the proportion of a shared
#'       evaluation grid occupied by the union of these kernels. Requires
#'       the (Suggested) `TPD` package.}
#'     \item{`"hypervolume"`}{Gaussian-kernel hypervolume (Blonder et al.,
#'       2014, 2018), via [hypervolume::hypervolume_gaussian()]/
#'       [hypervolume::get_volume()]: conceptually similar to `"tpd"` (a
#'       smoothed, kernel-based volume rather than a hard-edged hull), but
#'       estimated by Monte Carlo sampling rather than on a fixed grid, and
#'       by far the most computationally expensive of the four -- consider
#'       a smaller `n_boot` (e.g. 20-50) and/or a smaller
#'       `hv_samples_per_point` than for the other methods. Requires the
#'       (Suggested) `hypervolume` package.}
#'   }
#'   `"tpd"` and `"hypervolume"` both represent each species (or each
#'   bootstrap-drawn individual) as a *kernel* rather than a bare point,
#'   using a bandwidth computed once from the full individual-level PCA
#'   scores and reused, unchanged, for `fd_ref` and every `fd_boot` draw
#'   (see Details for why this fixed-bandwidth/fixed-grid design is
#'   required for the draws to be comparable at all).
#' @param n_axes Integer, the number of PCA axes to retain. If `NULL`
#'   (default), the smallest number of axes whose cumulative proportion of
#'   variance reaches `var_threshold` is used automatically -- Bertrand
#'   (2026) used 8 axes, capturing 98% of total variance, for a similar
#'   ten-trait morphological data set. For `method = "convexhull"` only,
#'   must leave strictly more species than axes (`nlevels(groups) >
#'   n_axes`), since a non-degenerate n-dimensional convex hull requires
#'   at least `n_axes + 1` affinely independent points; lower `n_axes` (or
#'   `var_threshold`) if this is not satisfied. The other methods do not
#'   need this and only get a warning instead.
#' @param var_threshold Cumulative proportion of variance used to
#'   automatically choose `n_axes` when `n_axes = NULL`. Defaults to
#'   `0.98`, as in Bertrand (2026).
#' @param n_boot Integer, number of bootstrap "communities". For each, one
#'   individual is drawn at random (independently across species) for
#'   every species, and the functional richness of the resulting
#'   one-individual-per-species point set is computed. This is also the
#'   number of draws the significance test is based on (see Details), so
#'   larger values give a finer-grained p-value floor of `1 / (n_boot +
#'   1)`. Defaults to `100`, as in Bertrand (2026).
#' @param log_transform,scale As in [trait_space()]; only used when `x` is
#'   a raw trait table (ignored, and taken from `x`, when `x` is an
#'   `"intrait_traitspace"` object).
#' @param dendrogram_linkage Character, clustering method passed to
#'   `stats::hclust(method =)` when `method = "dendrogram"`. Defaults to
#'   `"average"` (UPGMA), as in Petchey & Gaston (2002).
#' @param tpd_alpha Numeric, greater than 0 and at most 1, passed to [TPD::TPDsMean()]'s
#'   `alpha` when `method = "tpd"`: the proportion of each species'
#'   kernel probability mass included. Defaults to `0.95` (the `TPD`
#'   package's own default).
#' @param tpd_bw_factor Numeric, when `method = "tpd"`, the fixed per-axis
#'   kernel standard deviation is `tpd_bw_factor` times that axis's
#'   overall (between-species) standard deviation across the full
#'   individual-level PCA scores -- a plug-in bandwidth, since a single
#'   bootstrap-drawn individual carries no within-species variance of its
#'   own to estimate a kernel from (see Details). Defaults to `0.5`.
#' @param tpd_n_divisions Passed to [TPD::TPDsMean()]'s `n_divisions` when
#'   `method = "tpd"` (grid resolution); `NULL` (default) uses that
#'   function's own default.
#' @param hv_bw_method Character, `method` passed to
#'   [hypervolume::estimate_bandwidth()] when `method = "hypervolume"`.
#'   Defaults to `"silverman"`.
#' @param hv_samples_per_point Integer, passed to
#'   [hypervolume::hypervolume_gaussian()]'s `samples.per.point` when
#'   `method = "hypervolume"`. Defaults to a more conservative `500`
#'   (rather than that function's own dimensionality-scaled default),
#'   since this value is paid `n_boot` times over; increase it for a more
#'   precise (but slower) estimate.
#' @param composition Optional numeric matrix or data.frame giving the
#'   species composition of one or more communities/sites: one row per
#'   community, one column per species, with column names matching the
#'   species labels used in `groups` (i.e. `levels(factor(groups))`).
#'   Entries can be presence/absence (`0`/`1`) or abundance -- either way,
#'   only whether an entry is greater than `0` is used (abundance values
#'   themselves do not otherwise weight the computation; see Details).
#'   Row names, if present, are used as community identifiers (otherwise
#'   `"community_1"`, `"community_2"`, ...). Columns not matching any
#'   species in `groups` are dropped with a warning. When supplied, the
#'   exact same reference-vs-bootstrap principle described above is
#'   repeated independently for each community, restricted to that
#'   community's own species (see Details); the results are returned in
#'   `$communities` (see Return) in addition to, not instead of, the
#'   whole-species-pool `fd_ref`/`fd_boot` above. Defaults to `NULL` (no
#'   per-community computation).
#'
#' @return An object of class `"intrait_bootstrap_fspace"`, a list with
#'   elements `fd_ref` (centroid-based reference richness), `fd_boot`
#'   (numeric vector of length `n_boot`, the bootstrap richness values),
#'   `fd_boot_mean`, `fd_boot_sd`, `fd_boot_q05`, `fd_boot_q95` (summary of
#'   `fd_boot`), `diff` (`fd_boot_mean - fd_ref`), `p_value` (one-sided
#'   bootstrap p-value, see Details), `method`, `n_axes` (actual number of
#'   PCA axes used), `var_explained` (cumulative proportion of variance
#'   captured by those `n_axes` axes), `n_boot`, and `groups`. Has
#'   dedicated [print()] and [plot()] methods. If `composition` was
#'   supplied, also includes:
#'   \describe{
#'     \item{`communities`}{A `data.frame`, one row per community (in
#'       `composition`'s row order), with columns `community`, `n_species`
#'       (species matched between that community and `groups`), `fd_obs`
#'       (that community's own centroid-based richness -- the direct,
#'       per-community analogue of the whole-pool `fd_ref` above),
#'       `fd_expected` (that community's own bootstrap mean, the analogue
#'       of `fd_boot_mean`), `fd_sd` (that community's own bootstrap SD),
#'       `ses` (Standardized Effect Size, `(fd_obs - fd_expected) /
#'       fd_sd`), and `p_value` (one-sided, same convention as the
#'       whole-pool `p_value`). A community matched to fewer than 2
#'       species has every one of these set to `NA` (nothing to compute a
#'       richness from), with a warning.}
#'     \item{`community_boot`}{A named list (by community identifier), the
#'       raw per-community bootstrap richness vectors (length `n_boot`,
#'       or length `0` for a community left `NA` above) `fd_expected`/
#'       `fd_sd`/`ses`/`p_value` were summarised from -- kept for custom
#'       downstream inspection or plotting.}
#'     \item{`composition`}{The `composition` matrix actually used, i.e.
#'       after dropping any column that did not match a species in
#'       `groups` (see `composition` above).}
#'   }
#'
#' @details
#' A fresh Principal Component Analysis is always performed inside this
#' function (on `x$X`, the standardised trait matrix, when `x` is an
#' `"intrait_traitspace"` object, or on freshly standardised `x`
#' otherwise), so that `n_axes` PCA dimensions -- rather than only the two
#' axes [trait_space()] retains for plotting -- are available for the
#' functional-richness computation, exactly as in Bertrand (2026) (who
#' used convex-hull volume specifically; the `"dendrogram"`/`"tpd"`/
#' `"hypervolume"` alternatives are provided here as different, commonly
#' used ways of quantifying functional richness from the same PCA scores,
#' not as a reproduction of Bertrand (2026)'s own results).
#'
#' For `method = "tpd"` and `"hypervolume"`, each call needs a kernel
#' bandwidth (and, for `"tpd"`, an evaluation grid). If this were
#' re-estimated separately from each bootstrap draw's own small,
#' single-individual-per-species point set, differences between draws
#' would partly reflect differences in the *estimated bandwidth/grid*
#' rather than genuine differences in point configuration -- making
#' `fd_ref` and `fd_boot` not actually comparable. Both are therefore
#' computed **once**, from the full individual-level PCA scores, before
#' any bootstrap draw, and reused unchanged for `fd_ref` and every
#' `fd_boot` draw.
#'
#' Bertrand (2026) compares the bootstrap distribution to `fd_ref` with a
#' one-sided permutation test (H0: mean(FD_boot) <= FD_ref, using 9,999
#' permutations of an unspecified scheme). Reproducing that test exactly
#' is not possible from the report's description alone, so two candidate
#' designs were evaluated by simulation before choosing an implementation,
#' and it is worth recording why the first one was rejected. The initial
#' candidate reassigned species labels to individuals at random
#' (preserving sample sizes, as in [trait_disparity()]'s permutation test)
#' and compared a permuted centroid volume to a permuted single-draw
#' volume. Simulation showed this null is not informative here: shuffling
#' labels collapses every permuted centroid toward the *global* mean of
#' all individuals (a permuted "species" is just a random subsample of the
#' whole data set), while a permuted single-individual draw still spans
#' the data's full range, so the permuted difference is typically far
#' larger than the real, structure-preserving difference regardless of
#' whether genuine ITV is present -- the test was essentially always
#' non-significant by construction, which does not match Bertrand (2026)'s
#' reported result and would silently mislead users.
#'
#' The implementation used here instead treats `fd_boot` itself as the
#' reference (empirical, resampling-based) distribution and asks how
#' extreme `fd_ref` is relative to it, which requires no separate
#' permutation scheme: `p_value` is the proportion of `fd_boot` draws less
#' than or equal to `fd_ref`, plus one, divided by `n_boot + 1` (the same
#' `+ 1` correction convention as [trait_disparity()]; Davison & Hinkley,
#' 1997). A small `p_value` means `fd_ref` sits in the low tail of the
#' bootstrap distribution, i.e. that individual-based functional richness
#' exceeds the centroid-based reference by more than would be expected
#' from the bootstrap resampling variability alone. This design was
#' verified by simulation (clustered points with known, tunable
#' intraspecific dispersion) to correctly stay non-significant when
#' intraspecific variability is negligible and to correctly detect a
#' strong, real excess when it is not.
#'
#' Species represented by a single individual necessarily contribute the
#' same point to every bootstrap draw (there is nothing to resample for
#' that species); this is expected behaviour, not an error.
#'
#' **Per-community results (`composition`).** When `composition` is
#' supplied, the exact same `fd_ref`/`fd_boot` machinery above is repeated
#' once per community, restricted to that community's own species subset:
#' the shared, whole-pool PCA space, and the shared `method`-specific
#' auxiliary quantities (kernel bandwidth/grid for `"tpd"`/`"hypervolume"`,
#' computed once from the full individual-level data, see above) are
#' reused unchanged for every community, so richness values stay
#' comparable *across* communities as well as within one -- only the set
#' of species (and their individuals) entering the centroid/bootstrap
#' computation changes from community to community. For community `c`:
#' `fd_obs` is the centroid-based richness of exactly the species present
#' in `c` (the direct analogue of `fd_ref`), `fd_expected`/`fd_sd` are the
#' mean/SD of `n_boot` draws of one random individual per species present
#' in `c` (the analogue of `fd_boot`), and the Standardized Effect Size
#' `ses = (fd_obs - fd_expected) / fd_sd` expresses how far `fd_obs` sits
#' from its own community-specific bootstrap expectation, in units of that
#' expectation's own bootstrap SD -- the standard way to make effect sizes
#' comparable across communities that differ in species richness and
#' composition (e.g. Gotelli & McCabe, 2002), unlike comparing raw
#' `fd_obs` values directly. `p_value` follows the same one-sided,
#' resampling-based convention as the whole-pool `p_value` above (the
#' proportion of that community's own `fd_boot` draws at or below its own
#' `fd_obs`, `+ 1` corrected). Only presence (`composition > 0`) is used to
#' decide which species enter a community's computation; an abundance
#' matrix is accepted for convenience but abundance values themselves do
#' not otherwise weight the centroid or the bootstrap draws (every present
#' species contributes exactly one point to `fd_obs`, and exactly one
#' randomly drawn individual to each bootstrap draw, regardless of its
#' abundance) -- a deliberate choice for comparability with `fd_ref`/
#' `fd_boot` above, which make the same assumption for the whole pool.
#' Every community's `n_boot` draws are combined with every other's into a
#' single flattened task list before being dispatched (via the same
#' `future.apply`-based mechanism described above), for the same reason
#' individual replacements are flattened in [species_sensitivity()] rather
#' than run as nested loops: each (community, draw) pair is entirely
#' independent of every other, so distributing them all at once lets a
#' parallel `future::plan()` (see above) balance the full workload across
#' its workers in one pass.
#'
#' The `n_boot` bootstrap draws are independent of one another (each is
#' just one random individual per species plus a functional-richness
#' recomputation), so they parallelise trivially. If the `future.apply`
#' package is installed and a parallel `future::plan()` (e.g.
#' `future::plan("multisession")`) has been set before calling this
#' function, the draws are distributed across that plan's workers
#' automatically; otherwise (no plan set, or `future.apply` not installed)
#' they simply run sequentially, with identical results either way. This
#' matters mainly for large `n_axes`/many-species data sets (`method =
#' "convexhull"`, see [species_sensitivity()] for a discussion of that
#' per-call cost) or for `method = "hypervolume"`, whose per-draw cost is
#' high regardless of data set size.
#'
#' @references
#' Bertrand P (2026). Intraspecific trait variability shapes the
#' functional space of freshwater fish in French Guiana assemblages. M2
#' Biodiversity Ecology Evolution (BEE) internship report, Lille
#' University / Centre de Recherche sur la Biodiversite et l'Environnement
#' (CRBE, AQUAECO team), unpublished, supervised by A. Toussaint and S.
#' Brosse.
#'
#' Villeger S, Mason NWH, Mouillot D (2008). New multidimensional
#' functional diversity indices for a multifaceted framework in functional
#' ecology. Ecology, 89(8), 2290-2301.
#'
#' Barber CB, Dobkin DP, Huhdanpaa H (1996). The Quickhull algorithm for
#' convex hulls. ACM Transactions on Mathematical Software, 22(4), 469-483.
#'
#' Petchey OL, Gaston KJ (2002). Functional diversity (FD), species
#' richness and community composition. Ecology Letters, 5(3), 402-411.
#'
#' Carmona CP, de Bello F, Mason NWH, Leps J (2019). Trait probability
#' density (TPD): measuring functional diversity across scales based on
#' TPD with R. Ecology, 100(12), e02876.
#'
#' Blonder B, Lamanna C, Violle C, Enquist BJ (2014). The n-dimensional
#' hypervolume. Global Ecology and Biogeography, 23(5), 595-609.
#'
#' Blonder B, Morrow CB, Maitner B, Harris DJ, Lamanna C, Violle C,
#' Enquist BJ, Kerkhoff AJ (2018). New approaches for delineating
#' n-dimensional hypervolumes. Methods in Ecology and Evolution, 9(2),
#' 305-319.
#'
#' Davison AC, Hinkley DV (1997). Bootstrap Methods and their Application.
#' Cambridge University Press.
#'
#' Gotelli NJ, McCabe DJ (2002). Species co-occurrence: a meta-analysis of
#' J. M. Diamond's assembly rules model. Ecology, 83(8), 2091-2096.
#'
#' @seealso [trait_space()], [trait_disparity()]
#'
#' @examples
#' \donttest{
#' fish <- load_t26_saudrune_landmarks()
#' segments <- fishmorph_segments(fish)
#' ratios <- fishmorph_ratios(segments)
#' ts <- trait_space(ratios, groups = fish$metadata$species, na_action = "omit")
#'
#' # method = "dendrogram" needs no extra Suggested package
#' bf_dendro <- bootstrap_functional_space(ts, method = "dendrogram", n_axes = 2, n_boot = 200)
#' bf_dendro
#' plot(bf_dendro)
#'
#' if (requireNamespace("geometry", quietly = TRUE)) {
#'   # n_axes = 2 here only to keep the example fast; Bertrand (2026) used 8
#'   bf <- bootstrap_functional_space(ts, n_axes = 2, n_boot = 200)
#'   bf
#' }
#' if (requireNamespace("TPD", quietly = TRUE)) {
#'   bf_tpd <- bootstrap_functional_space(ts, method = "tpd", n_axes = 2, n_boot = 50)
#'   bf_tpd
#' }
#' if (requireNamespace("hypervolume", quietly = TRUE)) {
#'   # small n_boot: method = "hypervolume" is comparatively slow
#'   bf_hv <- bootstrap_functional_space(ts, method = "hypervolume", n_axes = 2, n_boot = 20)
#'   bf_hv
#' }
#'
#' # Per-community results: a communities x species composition matrix
#' # (here, three toy communities over the species in `ts`) gives obs/
#' # expected/SES/p-value per community, restricted to each community's
#' # own species subset (see Details).
#' # levels(), not on the raw character column: fish$metadata$species is a
#' # plain character vector (not a factor), so levels(fish$metadata$species)
#' # would silently return NULL rather than erroring.
#' sp <- levels(factor(fish$metadata$species))
#' composition <- rbind(
#'   site_A = as.integer(sp %in% sp[1:3]),
#'   site_B = as.integer(sp %in% sp[2:4]),
#'   site_C = as.integer(sp %in% sp)
#' )
#' colnames(composition) <- sp
#' bf_comm <- bootstrap_functional_space(
#'   ts, method = "dendrogram", n_axes = 2, n_boot = 200, composition = composition
#' )
#' bf_comm$communities
#' plot(bf_comm, type = "communities")
#' }
#' @export
bootstrap_functional_space <- function(x, groups = NULL,
                                        method = c("convexhull", "dendrogram", "tpd", "hypervolume"),
                                        n_axes = NULL, var_threshold = 0.98,
                                        n_boot = 100,
                                        log_transform = TRUE, scale = TRUE,
                                        dendrogram_linkage = "average",
                                        tpd_alpha = 0.95, tpd_bw_factor = 0.5,
                                        tpd_n_divisions = NULL,
                                        hv_bw_method = "silverman",
                                        hv_samples_per_point = 500,
                                        composition = NULL) {
  method <- match.arg(method)
  if (identical(method, "convexhull") && !requireNamespace("geometry", quietly = TRUE)) {
    stop(
      "bootstrap_functional_space(method = \"convexhull\") requires the ",
      "\"geometry\" package (for n-dimensional convex-hull volumes). ",
      "Install it with install.packages(\"geometry\").",
      call. = FALSE
    )
  }
  if (identical(method, "tpd") && !requireNamespace("TPD", quietly = TRUE)) {
    stop(
      "bootstrap_functional_space(method = \"tpd\") requires the \"TPD\" ",
      "package. Install it with install.packages(\"TPD\").",
      call. = FALSE
    )
  }
  if (identical(method, "hypervolume") && !requireNamespace("hypervolume", quietly = TRUE)) {
    stop(
      "bootstrap_functional_space(method = \"hypervolume\") requires the ",
      "\"hypervolume\" package. Install it with install.packages(\"hypervolume\").",
      call. = FALSE
    )
  }
  if (!is.numeric(n_boot) || length(n_boot) != 1 || n_boot < 1) {
    stop("`n_boot` must be a single positive integer.", call. = FALSE)
  }
  if (!is.null(composition)) {
    if (!is.matrix(composition) && !is.data.frame(composition)) {
      stop(
        "`composition` must be a matrix or data.frame (communities x species).",
        call. = FALSE
      )
    }
    composition <- as.matrix(composition)
    if (!is.numeric(composition)) {
      stop(
        "`composition` must be numeric (a 0/1 presence-absence, or abundance, matrix).",
        call. = FALSE
      )
    }
    if (is.null(colnames(composition))) {
      stop(
        sprintf(
          paste(
            "`composition` must have column names matching the species labels",
            "used in `groups` (found %d column(s), none named). If this is",
            "unexpected, check whatever built the species-label vector you used",
            "for the column names -- e.g. levels(x) silently returns NULL (not",
            "an error) when `x` is a plain character vector rather than a",
            "factor; use levels(factor(x)) or sort(unique(x)) instead."
          ),
          ncol(composition)
        ),
        call. = FALSE
      )
    }
    if (is.null(rownames(composition))) {
      rownames(composition) <- paste0("community_", seq_len(nrow(composition)))
    }
  }

  fs <- .fspace_pca_scores(x, groups, n_axes, var_threshold, log_transform, scale, method = method)
  scores <- fs$scores
  groups <- fs$groups
  n_axes <- fs$n_axes

  if (!is.null(composition)) {
    sp_pool <- levels(groups)
    if (anyDuplicated(colnames(composition)) > 0) {
      stop(
        sprintf(
          paste(
            "`composition` has duplicated column names (%s); each species must",
            "appear as exactly one column, since a duplicate would make it",
            "ambiguous which one is used."
          ),
          paste(unique(colnames(composition)[duplicated(colnames(composition))]), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    # Deliberately a subset of `colnames(composition)` itself (not
    # `intersect(colnames(composition), sp_pool)`, whose result is drawn
    # from `sp_pool` instead): this guarantees every value in `matched_sp`
    # is already, verbatim, one of `composition`'s own column names, so the
    # subsetting below can never fail to find it -- `intersect()`'s value
    # provenance does not matter for plain `==`/`%in%` comparisons, but it
    # is safer to never depend on it.
    matched_sp <- colnames(composition)[colnames(composition) %in% sp_pool]
    if (length(matched_sp) == 0) {
      example_composition <- utils::head(colnames(composition), 5)
      example_pool <- utils::head(sp_pool, 5)
      stop(
        sprintf(
          paste(
            "None of `composition`'s column names match any species in",
            "`groups`/`x`; check that column names are spelled exactly as the",
            "species labels used to build the trait space (case, accents,",
            "and leading/trailing spaces all count). For example, `composition`",
            "has columns like: %s -- while `groups` has species like: %s."
          ),
          paste(dQuote(example_composition, q = FALSE), collapse = ", "),
          paste(dQuote(example_pool, q = FALSE), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    n_unmatched <- ncol(composition) - length(matched_sp)
    if (n_unmatched > 0) {
      unmatched_names <- setdiff(colnames(composition), matched_sp)
      warning(
        sprintf(
          "%d column(s) of `composition` do not match any species in `groups` and were ignored: %s.",
          n_unmatched,
          paste(dQuote(utils::head(unmatched_names, 10), q = FALSE), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    # Deliberately match()-then-integer-index rather than
    # `composition[, matched_sp, drop = FALSE]`: a character subscript in
    # `[` never matches a `""`-named column, even when one genuinely
    # exists (documented in `?Extract`: "Neither empty ('') nor NA indices
    # match any names, not even empty nor missing names") -- a real case
    # here, since an unresolved/unidentified specimen's species label can
    # legitimately be `""` in real field data. `match()` performs ordinary
    # value equality instead, so it has no such exception (see the same
    # fix in `.stable_group_colors()`).
    composition <- composition[, match(matched_sp, colnames(composition)), drop = FALSE]
  }

  # Method-specific auxiliary quantities (kernel bandwidth, evaluation
  # grid) computed once from the full individual-level `scores`, then
  # reused unchanged for fd_ref and every fd_boot draw -- see Details.
  aux <- .fspace_richness_setup(
    scores, method,
    dendrogram_linkage = dendrogram_linkage,
    tpd_alpha = tpd_alpha, tpd_bw_factor = tpd_bw_factor, tpd_n_divisions = tpd_n_divisions,
    hv_bw_method = hv_bw_method, hv_samples_per_point = hv_samples_per_point
  )

  .draw_one_per_species <- function(sc, g) {
    t(vapply(levels(g), function(lv) {
      idx <- which(g == lv)
      sc[if (length(idx) == 1) idx else sample(idx, 1), ]
    }, numeric(ncol(sc))))
  }

  ref_pts <- .group_centroids(scores, groups)
  rownames(ref_pts) <- levels(groups)
  fd_ref <- .fspace_richness(ref_pts, method, aux)
  if (is.na(fd_ref)) {
    stop(
      sprintf(
        paste(
          "The centroid-based functional-richness estimate (method = \"%s\")",
          "could not be computed (e.g. a degenerate configuration in %d",
          "dimensions, or a required package call failed); try a smaller",
          "`n_axes`."
        ),
        method, n_axes
      ),
      call. = FALSE
    )
  }

  fd_boot <- .papply(seq_len(n_boot), function(b) {
    pts <- .draw_one_per_species(scores, groups)
    rownames(pts) <- levels(groups)
    .fspace_richness(pts, method, aux)
  }, numeric(1))

  # One-sided bootstrap p-value: how far into the lower tail of the
  # bootstrap distribution itself does the fixed reference fd_ref fall?
  # See Details for why this replaces a label-permutation null.
  p_value <- (sum(fd_boot <= fd_ref, na.rm = TRUE) + 1) / (n_boot + 1)

  communities <- NULL
  community_boot <- NULL
  if (!is.null(composition)) {
    comm_names <- rownames(composition)
    n_comm <- nrow(composition)
    sp_list <- lapply(seq_len(n_comm), function(i) colnames(composition)[composition[i, ] > 0])
    n_sp <- lengths(sp_list)
    valid_comm <- which(n_sp >= 2)

    # `fd_obs` (this community's own centroid-based richness) is cheap --
    # one call per community, on nlevels(g_i) points -- so it is computed
    # directly here rather than distributed; only the n_boot bootstrap
    # draws (the expensive part) are flattened below.
    idx_list <- vector("list", n_comm)
    g_list <- vector("list", n_comm)
    fd_obs <- rep(NA_real_, n_comm)
    for (i in valid_comm) {
      idx_list[[i]] <- which(groups %in% sp_list[[i]])
      g_list[[i]] <- droplevels(groups[idx_list[[i]]])
      ref_pts_i <- .group_centroids(scores[idx_list[[i]], , drop = FALSE], g_list[[i]])
      rownames(ref_pts_i) <- levels(g_list[[i]])
      fd_obs[i] <- .fspace_richness(ref_pts_i, method, aux)
    }

    # Every (community, bootstrap draw) pair is independent of every
    # other, exactly like the per-individual replacements in
    # species_sensitivity() -- so every community's n_boot draws are
    # combined into a single flattened task list, rather than looping
    # over communities and calling .papply() separately inside each, so a
    # parallel future::plan() can balance the whole workload in one pass
    # (see Details).
    community_boot <- vector("list", n_comm)
    names(community_boot) <- comm_names
    for (i in setdiff(seq_len(n_comm), valid_comm)) community_boot[[i]] <- numeric(0)

    if (length(valid_comm) > 0) {
      task_comm <- rep(valid_comm, each = n_boot)
      fd_boot_flat <- .papply(seq_along(task_comm), function(t) {
        i <- task_comm[t]
        pts <- .draw_one_per_species(scores[idx_list[[i]], , drop = FALSE], g_list[[i]])
        rownames(pts) <- levels(g_list[[i]])
        .fspace_richness(pts, method, aux)
      }, numeric(1))
      fd_boot_mat <- matrix(fd_boot_flat, nrow = n_boot, ncol = length(valid_comm))
      for (j in seq_along(valid_comm)) {
        community_boot[[valid_comm[j]]] <- fd_boot_mat[, j]
      }
    }

    fd_expected <- unname(vapply(community_boot, function(v) if (length(v)) mean(v, na.rm = TRUE) else NA_real_, numeric(1)))
    fd_sd <- unname(vapply(community_boot, function(v) if (length(v)) stats::sd(v, na.rm = TRUE) else NA_real_, numeric(1)))
    ses <- (fd_obs - fd_expected) / fd_sd
    p_value_comm <- vapply(seq_len(n_comm), function(i) {
      if (is.na(fd_obs[i]) || length(community_boot[[i]]) == 0) return(NA_real_)
      (sum(community_boot[[i]] <= fd_obs[i], na.rm = TRUE) + 1) / (n_boot + 1)
    }, numeric(1))

    communities <- data.frame(
      community = comm_names, n_species = n_sp,
      fd_obs = fd_obs, fd_expected = fd_expected, fd_sd = fd_sd,
      ses = ses, p_value = p_value_comm,
      row.names = NULL, stringsAsFactors = FALSE
    )

    n_too_few <- sum(n_sp < 2)
    if (n_too_few > 0) {
      warning(sprintf(
        paste(
          "%d community/communities have fewer than 2 matched species and were",
          "left as NA (nothing to compute a functional richness from)."
        ),
        n_too_few
      ), call. = FALSE)
    }
    n_na_obs <- sum(is.na(communities$fd_obs) & n_sp >= 2)
    if (n_na_obs > 0) {
      warning(sprintf(
        paste(
          "%d community/communities had at least 2 matched species but a",
          "non-computable functional richness (e.g. a degenerate configuration",
          "in %d dimensions); their results are left as NA."
        ),
        n_na_obs, n_axes
      ), call. = FALSE)
    }
  }

  structure(
    list(
      fd_ref = fd_ref,
      fd_boot = fd_boot,
      fd_boot_mean = mean(fd_boot, na.rm = TRUE),
      fd_boot_sd = stats::sd(fd_boot, na.rm = TRUE),
      fd_boot_q05 = stats::quantile(fd_boot, 0.05, na.rm = TRUE, names = FALSE),
      fd_boot_q95 = stats::quantile(fd_boot, 0.95, na.rm = TRUE, names = FALSE),
      diff = mean(fd_boot, na.rm = TRUE) - fd_ref,
      p_value = p_value,
      method = method,
      n_axes = n_axes,
      var_explained = fs$var_explained,
      n_boot = as.integer(n_boot),
      groups = groups,
      communities = communities,
      community_boot = community_boot,
      composition = composition
    ),
    class = "intrait_bootstrap_fspace"
  )
}

#' Print and plot an `"intrait_bootstrap_fspace"` object
#'
#' `plot(type = "pool")` (the default) draws a histogram of the
#' whole-species-pool bootstrap distribution (`fd_boot`), with `fd_ref`
#' (centroid-based reference) marked by a dashed red line and
#' `fd_boot_mean` (the bootstrap mean) by a dashed blue line; both values
#' are printed directly on the x-axis, in matching colour, rather than in
#' a separate text annotation. `plot(type = "communities")` instead draws
#' a dot ("forest") plot of the per-community Standardized Effect Size
#' (`x$communities$ses`), one row per community, coloured by whether that
#' community's `p_value` falls below `alpha` -- only available when `x`
#' was built with a `composition` matrix (see [bootstrap_functional_space()]).
#'
#' @param x An object of class `"intrait_bootstrap_fspace"`, as returned by
#'   [bootstrap_functional_space()].
#' @param type Character, `"pool"` (default) for the whole-species-pool
#'   histogram, or `"communities"` for the per-community SES dot plot
#'   (requires `x$communities`, i.e. `composition` was supplied to
#'   [bootstrap_functional_space()]).
#' @param alpha Numeric, the significance threshold used only by `type =
#'   "communities"` to colour communities by `p_value < alpha`. Defaults
#'   to `0.05`.
#' @param order Logical, for `type = "communities"` only: sort communities
#'   by increasing `ses` (`TRUE`, default) rather than keeping
#'   `composition`'s original row order.
#' @param ... For `plot()`, further arguments passed to [graphics::hist()]
#'   (`type = "pool"`) or [graphics::plot()] (`type = "communities"`);
#'   currently unused by `print()`.
#' @return Invisibly returns `x` (`type = "pool"`), or the (possibly
#'   reordered, NA-dropped) `x$communities` data.frame actually plotted
#'   (`type = "communities"`).
#' @export
print.intrait_bootstrap_fspace <- function(x, ...) {
  method_label <- if (!is.null(x$method)) x$method else "convexhull"
  cat(sprintf("<intrait_bootstrap_fspace> (method = \"%s\")\n", method_label))
  cat(sprintf(
    "  %d PCA axes retained (%.1f%% of variance), %d species\n",
    x$n_axes, x$var_explained * 100, nlevels(x$groups)
  ))
  cat(sprintf("  Centroid-based reference richness (FD_ref): %.4g\n", x$fd_ref))
  cat(sprintf(
    "  Bootstrap richness (FD_boot, %d draws): mean = %.4g, SD = %.4g, 5-95%% = [%.4g, %.4g]\n",
    x$n_boot, x$fd_boot_mean, x$fd_boot_sd, x$fd_boot_q05, x$fd_boot_q95
  ))
  cat(sprintf(
    "  Difference (mean FD_boot - FD_ref): %.4g (one-sided bootstrap p = %.4g)\n",
    x$diff, x$p_value
  ))
  if (!is.null(x$communities)) {
    n_sig <- sum(x$communities$p_value < 0.05, na.rm = TRUE)
    n_ok <- sum(!is.na(x$communities$ses))
    cat(sprintf(
      "  %d communities (composition matrix): %d/%d significant at p < 0.05\n",
      nrow(x$communities), n_sig, n_ok
    ))
    print(
      format(x$communities, digits = 3, nsmall = 2),
      row.names = FALSE
    )
  }
  invisible(x)
}

#' @return Invisibly returns `x`.
#' @export
#' @rdname print.intrait_bootstrap_fspace
plot.intrait_bootstrap_fspace <- function(x, type = c("pool", "communities"),
                                           alpha = 0.05, order = TRUE, ...) {
  type <- match.arg(type)
  if (identical(type, "communities")) {
    if (is.null(x$communities)) {
      stop(
        "`x` has no per-community results: re-run bootstrap_functional_space() ",
        "with a `composition` matrix to use type = \"communities\".",
        call. = FALSE
      )
    }
    return(.plot_bootstrap_fspace_communities(x, alpha = alpha, order = order, ...))
  }

  method_label <- if (!is.null(x$method)) x$method else "convexhull"
  richness_label <- switch(
    method_label,
    convexhull = "convex-hull volume",
    dendrogram = "dendrogram total branch length",
    tpd = "TPD functional richness",
    hypervolume = "Gaussian hypervolume",
    method_label
  )

  # Extra bottom margin for the two coloured value labels added below the
  # ordinary x-axis (see below), in place of the former FD_ref-in-the-
  # title annotation.
  old_par <- graphics::par(mar = graphics::par("mar") + c(1.5, 0, 0, 0))
  on.exit(graphics::par(old_par), add = TRUE)

  graphics::hist(
    x$fd_boot, col = "grey85", border = "white",
    main = "Bootstrap-based functional space estimate",
    xlab = sprintf("Functional richness (%s)", richness_label),
    xlim = range(c(x$fd_boot, x$fd_ref, x$fd_boot_mean)),
    ...
  )
  graphics::abline(v = x$fd_ref, col = "firebrick", lwd = 2, lty = 2)
  graphics::abline(v = x$fd_boot_mean, col = "blue", lwd = 2, lty = 2)

  # FD_ref and the bootstrap mean are marked directly on the x-axis, in
  # the same colour as their reference line, rather than spelled out in a
  # text annotation above the plot.
  graphics::axis(
    side = 1, at = x$fd_ref, labels = sprintf("%.3g", x$fd_ref),
    col.axis = "firebrick", col.ticks = "firebrick", line = 1.1, cex.axis = 0.8
  )
  graphics::axis(
    side = 1, at = x$fd_boot_mean, labels = sprintf("%.3g", x$fd_boot_mean),
    col.axis = "blue", col.ticks = "blue", line = 1.1, cex.axis = 0.8
  )

  invisible(x)
}

#' Per-community SES dot ("forest") plot for `bootstrap_functional_space()`
#'
#' One horizontal row per community, plotting `ses` as a point joined to a
#' vertical reference line at 0 by a thin segment (a standard "forest plot"
#' layout for standardized effect sizes across many sites/communities,
#' e.g. as used for null-model community-assembly statistics such as NRI/
#' NTI), coloured by whether `p_value < alpha`. Chosen over a per-community
#' histogram grid (impractical once there are more than a handful of
#' communities) or a raw obs-vs-expected scatter (which does not scale
#' `SES` by its own bootstrap SD, so communities with different `n_species`
#' -- and hence different bootstrap variance -- are not directly
#' comparable) because it scales to many communities at once, on a single,
#' directly comparable axis.
#'
#' @param x An object of class `"intrait_bootstrap_fspace"` with a non-`NULL`
#'   `$communities` (i.e. built with `composition`).
#' @param alpha,order As in [plot.intrait_bootstrap_fspace()].
#' @param ... Further arguments passed to [graphics::plot()].
#' @return Invisibly returns the (possibly reordered, NA-dropped)
#'   `data.frame` actually plotted.
#' @noRd
.plot_bootstrap_fspace_communities <- function(x, alpha = 0.05, order = TRUE, ...) {
  comm <- x$communities
  ok <- !is.na(comm$ses)
  if (!any(ok)) {
    stop(
      "No community has a computable `ses` (all NA); nothing to plot.",
      call. = FALSE
    )
  }
  comm <- comm[ok, , drop = FALSE]
  if (isTRUE(order)) comm <- comm[order(comm$ses), , drop = FALSE]
  n <- nrow(comm)
  sig <- !is.na(comm$p_value) & comm$p_value < alpha
  point_col <- ifelse(sig, "firebrick", "grey50")
  point_pch <- ifelse(sig, 16, 1)

  old_par <- graphics::par(mar = c(4, max(6, max(nchar(comm$community)) * 0.55 + 2), 3, 1))
  on.exit(graphics::par(old_par), add = TRUE)

  # Always include 0 in the plotted range: it is the reference every point
  # is compared against (both the dashed abline and each point's
  # connecting segment run to it), so it must stay visible even when every
  # community's `ses` happens to sit far from 0 relative to their own
  # spread -- otherwise the reference line and part of every segment
  # silently run off the edge of the plot.
  xr <- range(c(comm$ses, 0))
  pad <- if (diff(xr) > 0) 0.15 * diff(xr) else 1
  plot_args <- utils::modifyList(
    list(
      x = comm$ses, y = seq_len(n), type = "n", yaxt = "n", ylab = "",
      xlab = "Standardized Effect Size (SES)",
      main = "Community-level functional richness (SES)",
      xlim = xr + c(-pad, pad), ylim = c(0.5, n + 0.5)
    ),
    list(...)
  )
  do.call(graphics::plot, plot_args)
  graphics::abline(v = 0, lty = 2, col = "grey40")
  graphics::segments(0, seq_len(n), comm$ses, seq_len(n), col = "grey70")
  graphics::points(comm$ses, seq_len(n), pch = point_pch, col = point_col)
  graphics::axis(2, at = seq_len(n), labels = comm$community, las = 1, cex.axis = 0.8)
  graphics::legend(
    "topleft",
    legend = c(sprintf("p < %.2g", alpha), sprintf("p >= %.2g", alpha)),
    pch = c(16, 1), col = c("firebrick", "grey50"), bty = "n", cex = 0.8
  )

  invisible(comm)
}
