library(testthat)

minus <- "\u2212"
helpers_path <- if (file.exists("R/ch3_report_helpers.R")) {
  "R/ch3_report_helpers.R"
} else {
  "../R/ch3_report_helpers.R"
}

setup_iv <- function() {
  .keys_used <<- character(0)
  iv <<- list(
    tepr_window_start = 4.65,
    tepr_window_end = 7.65,
    tepr_baseline_start = 3.85,
    tepr_baseline_end = 4.35,
    rope_v = 0.02,
    rope_a = 0.05,
    rope_z = 0.05,
    crit = list(
      median = -0.053317561, lo = -0.10270809525, hi = -0.00334680101,
      p_lt0 = 0.981333333, p_gt0 = 0.018666667, pct_rope = 9.26666667
    ),
    bs = list(
      median = 0.01979186, lo = 0.00643820074, hi = 0.0330813421,
      p_lt0 = 0.003, p_gt0 = 0.997, pct_rope = 100
    ),
    zero_eff = list(
      median = 0, lo = -0.01, hi = 0.01,
      p_lt0 = 0.5, p_gt0 = 0.5, pct_rope = 0
    ),
    bigp = list(
      median = 0.2, lo = 0.1, hi = 0.3,
      p_lt0 = 0, p_gt0 = 1, pct_rope = 0.4
    ),
    elpd_pos = list(delta = 64.59027992, se = 8.99490922),
    elpd_neg = list(delta = -1.580887, se = 1.529493),
    elpd_zero = list(delta = 0, se = 0),
    pct_direct = list(pct = 7.69033003, pct_lo = 6.3010095, pct_hi = 9.0694986),
    pct_neg = list(
      median = -0.017457431, lo = -0.030758454, hi = -0.004189786,
      pct = "NA"
    ),
    has_na = NA_real_,
    has_null_field = list(median = NULL, lo = 0, hi = 1)
  )
}

setup_iv()
source(helpers_path, local = TRUE)
.keys_used <- character(0)

test_that("fmt_num keeps decimals and uses a Unicode minus", {
  expect_identical(fmt_num(0, 3), "0.000")
  expect_identical(fmt_num(-0.053317561, 3), paste0(minus, "0.053"))
  expect_identical(fmt_num(1.2, 1), "1.2")
  expect_identical(fmt_num(-0.0004, 3), "0.000")
  expect_false(grepl("-", fmt_num(-1.25, 2), fixed = TRUE))
  expect_true(grepl(minus, fmt_num(-1.25, 2), fixed = TRUE))
})

test_that("fmt_num prints a negative zero as an unsigned zero", {
  expect_identical(fmt_num(-0.04, 1), "0.0")
  expect_identical(fmt_num(-1e-8, 1), "0.0")
  expect_identical(fmt_num(-0.0004, 3), "0.000")
  expect_false(grepl("-", fmt_num(-0.04, 1), fixed = TRUE))
  expect_false(grepl(minus, fmt_num(-0.04, 1), fixed = TRUE))
  expect_false(grepl(minus, fmt_num(-1e-12, 2), fixed = TRUE))
})

test_that("fmt_int uses a thousands separator", {
  expect_identical(fmt_int(17857), "17,857")
  expect_identical(fmt_int(0), "0")
  expect_identical(fmt_int(-17857), paste0(minus, "17,857"))
  expect_identical(fmt_int(17857.4), "17,857")
})

test_that("fmt_ci and fmt_est", {
  expect_identical(
    fmt_ci(-0.10270809525, -0.00334680101, 3),
    paste0("[", minus, "0.103, ", minus, "0.003]")
  )
  expect_identical(fmt_ci(0, 1, 1), "[0.0, 1.0]")
  expect_identical(fmt_ci(-1, 0, 0), paste0("[", minus, "1, 0]"))
  expect_identical(
    fmt_est("crit", 3),
    paste0(minus, "0.053 [", minus, "0.103, ", minus, "0.003]")
  )
})

test_that("fmt_pct shows an explicit sign on the point estimate", {
  expect_identical(fmt_pct("pct_direct", 1), "+7.7% [6.3, 9.1]")
  expect_identical(fmt_pct("bs", 1), "+2.0% [0.6, 3.4]")
  neg <- fmt_pct("pct_neg", 1)
  expect_identical(neg, paste0(minus, "1.7% [", minus, "3.0, ", minus, "0.4]"))
  expect_false(grepl("-", neg, fixed = TRUE))
})

test_that("fmt_pct zero effect", {
  # exp(0) - 1 = 0; exp(-0.01)-1 and exp(0.01)-1 are about -1.0% and +1.0%.
  got <- fmt_pct("zero_eff", 1)
  expect_identical(got, paste0("0.0% [", minus, "1.0, 1.0]"))
})

test_that("fmt_prob and fmt_p", {
  expect_identical(fmt_prob(0.981333333), ".981")
  expect_identical(fmt_prob(0), "< .001")
  expect_identical(fmt_prob(1), "> .999")
  expect_identical(fmt_prob(0.9995), "> .999")
  expect_identical(fmt_prob(0.0004), "< .001")
  expect_identical(fmt_p(0.02278481), "p = .023")
  expect_identical(fmt_p(0.0000001), "p < .001")
  expect_identical(fmt_p(0.5), "p = .500")
  expect_identical(fmt_p(0), "p < .001")
})

test_that("fmt_r drops the leading zero", {
  expect_identical(fmt_r(0.2919, 0.2274, 0.3538), "r = .29 [.23, .35]")
  expect_identical(
    fmt_r(-0.29, -0.35, -0.23),
    paste0("r = ", minus, ".29 [", minus, ".35, ", minus, ".23]")
  )
  expect_identical(fmt_r(0, -0.01, 0.01), paste0("r = .00 [", minus, ".01, .01]"))
  expect_false(grepl("-", fmt_r(-0.2, -0.3, -0.1), fixed = TRUE))
})

test_that("fmt_elpd, fmt_t, and fmt_rope", {
  expect_identical(fmt_elpd("elpd_pos"), "\u0394ELPD = 64.6 \u00b1 9.0")
  expect_identical(fmt_elpd("elpd_neg"), paste0("\u0394ELPD = ", minus, "1.6 \u00b1 1.5"))
  expect_identical(fmt_elpd("elpd_zero"), "\u0394ELPD = 0.0 \u00b1 0.0")
  expect_identical(fmt_t(2.331589, 66, 0.02278481), "t(66) = 2.33, p = .023")
  expect_identical(fmt_t(-4.833, 66, 8.37e-6), paste0("t(66) = ", minus, "4.83, p < .001"))
  expect_identical(fmt_t(0, 10, 1), "t(10) = 0.00, p = 1.000")
  expect_identical(fmt_rope("crit"), "9% in ROPE")
  expect_identical(fmt_rope("bs"), "100% in ROPE")
  expect_identical(fmt_rope("zero_eff"), "0% in ROPE")
})

test_that("report_effect", {
  expect_identical(
    report_effect("crit", "drift"),
    paste0(
      minus, "0.053, 95% CrI [", minus, "0.103, ", minus, "0.003], ",
      "P(\u03b2 < 0) = .981, 9% in ROPE"
    )
  )
  expect_identical(
    report_effect("bs", "log"),
    "0.020, 95% CrI [0.006, 0.033], P(\u03b2 > 0) = .997, 100% in ROPE (+2.0% [0.6, 3.4])"
  )
  expect_identical(
    report_effect("bigp", "logit"),
    "0.200, 95% CrI [0.100, 0.300], P(\u03b2 > 0) > .999, 0% in ROPE"
  )
  expect_match(report_effect("zero_eff", "drift"), "P\\(\u03b2 > 0\\)")
})

test_that("v() errors on a missing key, a missing field, NULL, and NA", {
  expect_error(v("not_a_key"), "not_a_key")
  expect_error(v("crit", "no_such_field"), "crit\\$no_such_field")
  expect_error(v("has_na"), "NA")
  expect_error(v("has_null_field", "median"), "NULL")
})

test_that("v() accepts dotted access and logs the base key", {
  .keys_used <<- character(0)
  expect_equal(v("crit", "median"), iv$crit$median)
  expect_equal(v("crit.median"), iv$crit$median)
  expect_identical(.keys_used, c("crit", "crit"))
})

test_that("design constants come from iv and a missing one stops", {
  expect_equal(design$rope_v, 0.02)
  expect_equal(design$tepr_window_start, 4.65)
  expect_equal(design$tepr_baseline_end, 4.35)
  env <- new.env(parent = globalenv())
  env$iv <- iv
  env$iv$rope_z <- NULL
  env$.keys_used <- character(0)
  expect_error(
    sys.source(helpers_path, envir = env),
    "rope_z"
  )
})

test_that("negative formatters do not contain an ASCII hyphen", {
  samples <- c(
    fmt_num(-2, 1),
    fmt_int(-1000),
    fmt_ci(-0.2, -0.1, 1),
    fmt_est("crit"),
    fmt_pct("pct_neg"),
    fmt_r(-0.4, -0.5, -0.3),
    fmt_elpd("elpd_neg"),
    fmt_t(-1.2, 10, 0.2),
    report_effect("crit", "drift")
  )
  for (s in samples) {
    expect_false(grepl("-", s, fixed = TRUE))
    expect_true(grepl(minus, s, fixed = TRUE))
  }
})
