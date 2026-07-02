test_that("digitization_error() runs end-to-end and returns the expected structure", {
  set.seed(1)
  fish <- simulate_fish_landmarks(n_per_species = 4, n_replicates = 10)
  indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))

  derr <- digitization_error(fish, individual = indiv_id)

  expect_s3_class(derr, "intrait_digitization_error")
  expect_true(all(c(
    "landmark_individual", "by_landmark", "by_individual", "by_species", "global"
  ) %in% names(derr)))

  n_lmk <- dim(fish$coords)[1]
  n_individuals <- length(unique(indiv_id))

  expect_equal(nrow(derr$landmark_individual), n_lmk * n_individuals)
  expect_equal(nrow(derr$by_landmark), n_lmk)
  expect_equal(nrow(derr$by_individual), n_individuals)
  expect_equal(sum(derr$by_species$n_individuals), n_individuals)
  expect_equal(derr$global$n_individuals, n_individuals)
  expect_equal(derr$global$n_species, length(unique(fish$metadata$species)))

  # Bias percentages must be non-negative.
  expect_true(all(derr$landmark_individual$mean_dist_pct >= 0))
  expect_true(all(derr$landmark_individual$rms_dist_pct >= 0))

  # by_landmark must be ordered by increasing median bias.
  expect_equal(derr$by_landmark$median_bias_pct, sort(derr$by_landmark$median_bias_pct))
})

test_that("digitization_error() global bias matches a hand computation on a toy example", {
  # Two individuals, one species, 2 landmarks, 3 replicates each; landmarks
  # 1-2 used as the size reference (as in the original protocol).
  coords <- array(0, dim = c(2, 2, 6), dimnames = list(NULL, c("X", "Y"), paste0("obs", 1:6)))
  # Individual A: landmark 1 replicated at (0,0),(0,0),(0,0) -> zero dispersion
  coords[1, , 1:3] <- 0
  # landmark 2 replicated at (10,0),(10,0),(10,0) -> reference distance = 10
  coords[2, , 1] <- c(10, 0)
  coords[2, , 2] <- c(10, 0)
  coords[2, , 3] <- c(10, 0)
  # Individual B: landmark 1 replicated with a bit of dispersion: (0,0),(1,0),(-1,0)
  coords[1, , 4] <- c(0, 0)
  coords[1, , 5] <- c(1, 0)
  coords[1, , 6] <- c(-1, 0)
  # landmark 2 fixed at (10,0) for all three replicates
  coords[2, , 4] <- c(10, 0)
  coords[2, , 5] <- c(10, 0)
  coords[2, , 6] <- c(10, 0)

  landmarks <- structure(
    list(
      coords = coords,
      scale = stats::setNames(rep(1, 6), paste0("obs", 1:6)),
      metadata = data.frame(
        specimen = paste0("obs", 1:6),
        species = rep("Species_A", 6),
        row.names = paste0("obs", 1:6)
      )
    ),
    class = "intrait_landmarks"
  )
  individual <- rep(c("indA", "indB"), each = 3)

  derr <- digitization_error(landmarks, individual = individual, ref_landmarks = c(1, 2), digits = 10)

  # Reference distance (landmark1-landmark2), pooled across all 6 observations,
  # is exactly 10 for every replicate, so ref distance for Species_A is 10.
  expect_equal(as.numeric(derr$reference_distance["Species_A"]), 10)

  # Individual A has zero dispersion at landmark 1 -> sd_dist_pct == 0 for that landmark.
  li <- derr$landmark_individual
  a_lmk1 <- li[li$individual == "indA" & li$landmark == 1, ]
  expect_equal(a_lmk1$sd_dist_pct, 0)
  expect_equal(a_lmk1$mean_dist_pct, 0)

  # Individual B landmark 1: positions (0,0), (1,0), (-1,0); consensus = (0,0);
  # distances = 0, 1, 1; sd(c(0,1,1)) is the sd_dist (unnormalized).
  b_lmk1 <- li[li$individual == "indB" & li$landmark == 1, ]
  expected_sd <- stats::sd(c(0, 1, 1)) / 10 * 100
  expect_equal(b_lmk1$sd_dist_pct, expected_sd, tolerance = 1e-8)
  expected_mean <- mean(c(0, 1, 1)) / 10 * 100
  expect_equal(b_lmk1$mean_dist_pct, expected_mean, tolerance = 1e-8)

  # Landmark 2 has zero dispersion for both individuals.
  lmk2 <- li[li$landmark == 2, ]
  expect_true(all(lmk2$sd_dist_pct == 0))
})

test_that("digitization_error() errors informatively on invalid input", {
  fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 5)
  indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))

  expect_error(digitization_error(list(), individual = indiv_id), "intrait_landmarks")
  expect_error(digitization_error(fish, individual = indiv_id[1:3]), "one entry per specimen")
  expect_error(digitization_error(fish, individual = indiv_id, ref_landmarks = c(1, 100)), "valid landmarks")
  expect_error(
    digitization_error(fish, individual = indiv_id, normalization = "standard_length_mm"),
    "should be one of"
  )

  # An individual with only 1 replicate should error.
  fish1 <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 1)
  indiv_id1 <- sub("_rep[0-9]+$", "", rownames(fish1$metadata))
  expect_error(digitization_error(fish1, individual = indiv_id1), "at least 2 digitization replicates")
})

test_that("digitization_error() supports standard_length and centroid_size normalization", {
  set.seed(3)
  fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 6)
  indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))

  derr_sl <- digitization_error(fish, individual = indiv_id, normalization = "standard_length")
  expect_s3_class(derr_sl, "intrait_digitization_error")
  expect_equal(derr_sl$normalization, "standard_length")
  expect_equal(length(derr_sl$reference_distance), length(unique(indiv_id)))

  derr_cs <- digitization_error(fish, individual = indiv_id, normalization = "centroid_size")
  expect_s3_class(derr_cs, "intrait_digitization_error")
  expect_equal(derr_cs$normalization, "centroid_size")
  expect_true(all(derr_cs$reference_distance > 0))
})

test_that("digitization_error() excludes landmarks via exclude_landmarks", {
  set.seed(5)
  fish <- simulate_fish_landmarks(n_per_species = 3, n_replicates = 6)
  indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))
  n_lmk <- dim(fish$coords)[1]

  derr_full <- digitization_error(fish, individual = indiv_id)
  derr_excl <- digitization_error(fish, individual = indiv_id, exclude_landmarks = c(n_lmk - 1, n_lmk))

  # Excluded landmarks must not appear anywhere in the output.
  expect_false(any(c(n_lmk - 1, n_lmk) %in% derr_excl$landmark_individual$landmark))
  expect_false(any(c(n_lmk - 1, n_lmk) %in% derr_excl$by_landmark$landmark))
  expect_equal(nrow(derr_excl$by_landmark), n_lmk - 2)
  expect_equal(derr_excl$excluded_landmarks, c(n_lmk - 1, n_lmk))
  expect_null(derr_full$excluded_landmarks)

  # Excluding landmarks changes by_individual/global aggregates in general
  # (they are averaged over fewer landmarks), so the two results need not
  # match, but both must remain valid (non-negative, well-formed) outputs.
  expect_true(all(derr_excl$landmark_individual$mean_dist_pct >= 0))

  # ref_landmarks can still reference an excluded landmark: the reference
  # distance calculation is independent of the per-landmark decomposition.
  derr_ref_excl <- digitization_error(
    fish, individual = indiv_id,
    ref_landmarks = c(n_lmk - 1, n_lmk),
    exclude_landmarks = c(n_lmk - 1, n_lmk)
  )
  expect_s3_class(derr_ref_excl, "intrait_digitization_error")
  expect_equal(nrow(derr_ref_excl$by_landmark), n_lmk - 2)

  # Excluding every landmark is an error.
  expect_error(
    digitization_error(fish, individual = indiv_id, exclude_landmarks = seq_len(n_lmk)),
    "nothing left to analyse"
  )

  # Invalid indices are rejected like ref_landmarks.
  expect_error(
    digitization_error(fish, individual = indiv_id, exclude_landmarks = c(1, 100)),
    "valid landmarks"
  )
})

test_that("print.intrait_digitization_error() and plot method run without error", {
  set.seed(4)
  fish <- simulate_fish_landmarks(n_per_species = 4, n_replicates = 6)
  indiv_id <- sub("_rep[0-9]+$", "", rownames(fish$metadata))
  derr <- digitization_error(fish, individual = indiv_id)

  expect_output(print(derr), "intrait_digitization_error")

  tmp <- tempfile(fileext = ".png")
  grDevices::png(tmp)
  expect_error(plot(derr), NA)
  grDevices::dev.off()
  unlink(tmp)
})
