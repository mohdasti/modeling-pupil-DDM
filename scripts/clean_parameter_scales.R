## ================================================================
## Clean up scale reporting for DDM dpars and save cleaned table
## - bs (a): exp(link-scale)
## - ndt (t0): exp(link-scale)
## - bias (z): inv_logit(link-scale)
## - For bs slopes: multiplicative fold-change = exp(beta)
## - For bias slopes: probability shift using bias_Intercept baseline
## Output: output/tables/parameter_estimates_clean.csv
## ================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

logit_inv <- function(x) 1/(1+exp(-x))

in_file <- "model_parameter_estimates.csv"
out_dir <- "output/tables"
out_file <- file.path(out_dir, "parameter_estimates_clean.csv")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(in_file)) {
  stop(paste0("Input not found: ", in_file))
}

raw <- suppressMessages(readr::read_csv(in_file, show_col_types = FALSE))
# Expected columns: model, parameter, estimate, est_error, ci_lower, ci_upper

# Identify dpar from parameter naming convention
identify_dpar <- function(param) {
  if (startsWith(param, "bs_")) return("bs")
  if (startsWith(param, "ndt_")) return("ndt")
  if (startsWith(param, "bias_")) return("bias")
  return("v")
}

clean <- raw %>%
  mutate(
    dpar = vapply(parameter, identify_dpar, character(1)),
    link = dplyr::case_when(
      dpar == "bs" ~ "log",
      dpar == "ndt" ~ "log",
      dpar == "bias" ~ "logit",
      TRUE ~ "identity"
    ),
    # Natural-scale transform for point and CI
    estimate_natural = dplyr::case_when(
      dpar == "bs" ~ exp(estimate),
      dpar == "ndt" ~ exp(estimate),
      dpar == "bias" ~ logit_inv(estimate),
      TRUE ~ estimate
    ),
    ci_lower_natural = dplyr::case_when(
      dpar == "bs" ~ exp(ci_lower),
      dpar == "ndt" ~ exp(ci_lower),
      dpar == "bias" ~ logit_inv(ci_lower),
      TRUE ~ ci_lower
    ),
    ci_upper_natural = dplyr::case_when(
      dpar == "bs" ~ exp(ci_upper),
      dpar == "ndt" ~ exp(ci_upper),
      dpar == "bias" ~ logit_inv(ci_upper),
      TRUE ~ ci_upper
    ),
    scale_reported = dplyr::case_when(
      dpar == "bs" ~ "a (natural, exp link)",
      dpar == "ndt" ~ "t0 (natural, exp link)",
      dpar == "bias" ~ "z (probability, inv_logit link)",
      TRUE ~ "v (identity)"
    )
  )

# Compute bs multiplicative fold-change for slopes; and bias probability shifts using bias_Intercept
# Get bias intercept per model (on link scale) to compute probability shifts
bias_intercepts <- raw %>%
  dplyr::filter(parameter == "bias_Intercept") %>%
  dplyr::select(model, bias_intercept_est = estimate)

clean <- clean %>%
  dplyr::left_join(bias_intercepts, by = "model") %>%
  dplyr::mutate(
    is_intercept = grepl("_Intercept$", parameter),
    # For bs slopes (log link): fold-change = exp(beta)
    bs_fold_change = ifelse(dpar == "bs" & !is_intercept, exp(estimate), NA_real_),
    bs_fold_change_lower = ifelse(dpar == "bs" & !is_intercept, exp(ci_lower), NA_real_),
    bs_fold_change_upper = ifelse(dpar == "bs" & !is_intercept, exp(ci_upper), NA_real_),
    # For bias slopes (logit): probability shift at +1 of predictor using bias intercept baseline
    z0 = ifelse(!is.na(bias_intercept_est), logit_inv(bias_intercept_est), NA_real_),
    bias_prob_shift = ifelse(dpar == "bias" & !is_intercept & !is.na(z0),
                             logit_inv(bias_intercept_est + estimate) - z0, NA_real_),
    bias_prob_shift_lower = ifelse(dpar == "bias" & !is_intercept & !is.na(z0),
                                   logit_inv(bias_intercept_est + ci_lower) - z0, NA_real_),
    bias_prob_shift_upper = ifelse(dpar == "bias" & !is_intercept & !is.na(z0),
                                   logit_inv(bias_intercept_est + ci_upper) - z0, NA_real_)
  ) %>%
  dplyr::select(
    model, parameter, dpar, link,
    estimate_natural, ci_lower_natural, ci_upper_natural,
    est_error,  # Note: SE remains on link scale
    bs_fold_change, bs_fold_change_lower, bs_fold_change_upper,
    bias_prob_shift, bias_prob_shift_lower, bias_prob_shift_upper,
    scale_reported
  )

readr::write_csv(clean, out_file)
cat("\u2713 Saved:", out_file, "\n")








