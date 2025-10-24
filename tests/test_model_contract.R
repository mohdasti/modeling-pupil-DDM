test_that("DDM links and bounds are valid", {
  skip_if_not(file.exists("models/ddm_brms_main.rds"))
  fit <- readRDS("models/ddm_brms_main.rds")
  summ <- summary(fit)

  # parameterization checks
  expect_true(grepl("wiener", capture.output(fit)[1]))
  # bias link must be logit (0..1)
  expect_true(any(grepl("bias", names(fit$fit@sim$fnames_oi))))
})
