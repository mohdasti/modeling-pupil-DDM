# scripts/modeling/fit_ddm_brms.R
suppressPackageStartupMessages({
  library(dplyr); library(brms); library(readr); library(stringr)
})

# ---- Load cleaned trial-level data ----
# Read from analysis-ready data
d <- read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE) %>%
  mutate(
    # Rename columns
    subj = factor(subject_id),
    choice = as.integer(choice)
  ) %>%
  filter(
    !is.na(rt), !is.na(choice),
    rt >= 0.2, rt <= 3.0  # Filter extreme RTs (standardized threshold)
  )

# ---- Simple DDM model ----
f_ddm <- bf(
  rt | dec(choice) ~ 1 + difficulty_level + effort_condition + (1 | subj),
  bs   ~ 1 + difficulty_level + effort_condition + (1 | subj),
  ndt  ~ 1 + (1 | subj),
  bias ~ 1 + (1 | subj)
)

pri <- c(
  prior(normal(0, 0.3), class = "b"),
  prior(normal(0, 0.5), class = "sd"),
  prior(normal(log(0.2), 0.3), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bias")
)

fit <- brm(
  formula = f_ddm,
  data = d,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = pri,
  cores = 4,
  chains = 4, 
  iter = 2000, 
  warmup = 1000,
  control = list(adapt_delta = 0.95, max_treedepth = 12),
  seed = 123,
  init = 0.1
)

dir.create("models", showWarnings = FALSE)
saveRDS(fit, file = "models/ddm_brms_main.rds")
