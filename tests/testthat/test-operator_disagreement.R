# Build a small synthetic "intrait_landmarks" object with an operator column.
# `configs` is a named list operator -> (p x 2) matrix; every operator
# digitizes every individual once. Landmarks 1-2 span a fixed reference
# distance so normalization = "landmarks" is hand-computable.
.make_operator_landmarks <- function(indiv_configs) {
  # indiv_configs: named list individual -> (named list operator -> p x 2)
  specs <- list()
  meta_rows <- list()
  arrs <- list()
  for (ind in names(indiv_configs)) {
    for (op in names(indiv_configs[[ind]])) {
      sid <- paste(ind, op, sep = "_")
      arrs[[sid]] <- indiv_configs[[ind]][[op]]
      meta_rows[[sid]] <- data.frame(
        specimen = sid, individual = ind, species = "Species_A",
        operator = op, stringsAsFactors = FALSE
      )
    }
  }
  p <- nrow(arrs[[1]])
  n <- length(arrs)
  coords <- array(NA_real_, dim = c(p, 2, n), dimnames = list(NULL, c("X", "Y"), names(arrs)))
  for (i in seq_len(n)) coords[, , i] <- arrs[[i]]
  meta <- do.call(rbind, meta_rows)
  rownames(meta) <- meta$specimen
  structure(
    list(coords = coords, scale = NULL, metadata = meta),
    class = "intrait_landmarks"
  )
}

test_that("operator_disagreement() matches a hand computation (3 operators)", {
  # Individual A: 3 operators, 3 landmarks.
  # L1 = (0,0) for all; L2 = (10,0) for all (reference distance = 10);
  # L3 = (5,0), (5,0), (5,3) -> Operator_3 is the culprit.
  cfg <- function(l3) rbind(c(0, 0), c(10, 0), l3)
  lm <- .make_operator_landmarks(list(
    indA = list(
      Operator_1 = cfg(c(5, 0)),
      Operator_2 = cfg(c(5, 0)),
      Operator_3 = cfg(c(5, 3))
    )
  ))

  # Single individual -> zero MAD -> a "cannot flag" warning is expected.
  od <- suppressWarnings(operator_disagreement(
    lm, normalization = "landmarks", ref_landmarks = c(1, 2), digits = 10
  ))

  expect_s3_class(od, "intrait_operator_disagreement")

  bi <- od$by_individual
  expect_equal(nrow(bi), 1)
  # spread: L1 = L2 = 0; L3: positions (5,0),(5,0),(5,3), consensus (5,1),
  # distances 1,1,2 -> pct 10,10,20 -> RMS = sqrt(200) = 14.142136.
  # disagreement = mean(0, 0, 14.142136) = 4.714045.
  expect_equal(bi$disagreement_pct, 4.7140452079, tolerance = 1e-6)
  expect_equal(bi$max_landmark_pct, 14.1421356237, tolerance = 1e-6)

  # Leave-one-out attribution correctly fingers Operator_3.
  expect_equal(bi$responsible_operator, "Operator_3")
  expect_equal(bi$responsible_deviation_pct, 17.3205080757, tolerance = 1e-6)
  expect_equal(bi$attribution_margin_pct, 8.6602540378, tolerance = 1e-6)

  # by_operator mean deviation (mean over landmarks of displacement to consensus).
  bo <- od$by_operator
  expect_equal(
    bo$mean_deviation_pct[bo$operator == "Operator_3"], 6.6666666667, tolerance = 1e-6
  )
  expect_equal(
    bo$mean_deviation_pct[bo$operator == "Operator_1"], 3.3333333333, tolerance = 1e-6
  )
  expect_equal(bo$n_responsible[bo$operator == "Operator_3"], 1)

  # by_landmark: only landmark 3 shows any spread.
  bl <- od$by_landmark
  expect_equal(bl$mean_spread_pct[bl$landmark == 3], 14.1421356237, tolerance = 1e-6)
  expect_equal(bl$mean_spread_pct[bl$landmark == 1], 0)
})

test_that("two-operator individuals are not attributable without a reference", {
  cfg <- function(l3) rbind(c(0, 0), c(10, 0), l3)
  lm <- .make_operator_landmarks(list(
    indB = list(
      Operator_1 = cfg(c(5, 0)),
      Operator_2 = cfg(c(5, 2))
    )
  ))

  od <- suppressWarnings(operator_disagreement(
    lm, normalization = "landmarks", ref_landmarks = c(1, 2)
  ))
  # With only two operators and no reference, the culprit is not identifiable.
  expect_true(is.na(od$by_individual$responsible_operator))
  # ...but the disagreement magnitude is still reported (> 0).
  expect_gt(od$by_individual$disagreement_pct, 0)

  # A reference operator breaks the tie: Operator_2 (the one that moved) is named.
  od_ref <- suppressWarnings(operator_disagreement(
    lm, normalization = "landmarks", ref_landmarks = c(1, 2),
    reference_operator = "Operator_1"
  ))
  expect_equal(od_ref$by_individual$responsible_operator, "Operator_2")
})

test_that("operator_disagreement() flags at-risk individuals with a robust threshold", {
  set.seed(1)
  base <- rbind(c(0, 0), c(10, 0), c(5, 3), c(5, -3), c(2, 1))
  jitter_cfg <- function(sd = 0.03) base + matrix(stats::rnorm(nrow(base) * 2, 0, sd), ncol = 2)

  configs <- list()
  # 12 low-disagreement individuals
  for (i in seq_len(12)) {
    configs[[paste0("clean", i)]] <- list(
      Operator_1 = jitter_cfg(), Operator_2 = jitter_cfg(), Operator_3 = jitter_cfg()
    )
  }
  # one clearly discordant individual: Operator_2 grossly misplaces landmark 4
  bad <- jitter_cfg(); bad[4, ] <- bad[4, ] + c(3, -3)
  configs[["risky1"]] <- list(
    Operator_1 = jitter_cfg(), Operator_2 = bad, Operator_3 = jitter_cfg()
  )

  lm <- .make_operator_landmarks(configs)
  od <- operator_disagreement(lm, normalization = "centroid_size")

  expect_s3_class(od, "intrait_operator_disagreement")
  # by_individual is ordered by decreasing disagreement.
  expect_equal(od$by_individual$disagreement_pct,
               sort(od$by_individual$disagreement_pct, decreasing = TRUE))
  # the seeded discordant individual is flagged and blamed on Operator_2.
  risky_row <- od$by_individual[od$by_individual$individual == "risky1", ]
  expect_true(risky_row$at_risk)
  expect_equal(risky_row$responsible_operator, "Operator_2")
  # at_risk is a logical column, threshold is a positive scalar.
  expect_type(od$by_individual$at_risk, "logical")
  expect_gt(od$threshold_value, 0)

  # print()/plot() run without error.
  expect_output(print(od))
  expect_invisible(plot(od, type = "operator"))
})

test_that("operator_disagreement() validates its inputs", {
  cfg <- function(l3) rbind(c(0, 0), c(10, 0), l3)
  lm <- .make_operator_landmarks(list(
    indA = list(Operator_1 = cfg(c(5, 0)), Operator_2 = cfg(c(5, 1)), Operator_3 = cfg(c(5, 2)))
  ))
  expect_error(operator_disagreement(lm, threshold = -1), "positive")
  expect_error(operator_disagreement(lm, reference_operator = "Operator_9"), "not among")
  expect_error(
    operator_disagreement(lm, exclude_landmarks = 1:3),
    "excludes all available landmarks"
  )
})
