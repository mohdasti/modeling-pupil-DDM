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

# STANDARDIZED PRIORS: Literature-justified for older adults + response-signal design
pri <- c(
  # Drift rate (v) - identity link
  prior(normal(0, 1), class = "Intercept"),
  prior(normal(0, 0.5), class = "b"),
  
  # Boundary separation (a/bs) - log link: center at log(1.7) for older adults
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.20), class = "b", dpar = "bs"),
  
  # Non-decision time (t0/ndt) - log link: center at log(0.35) for older adults + response-signal
  prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.15), class = "b", dpar = "ndt"),
  
  # Starting point bias (z) - logit link: centered at 0.5 with moderate spread
  prior(normal(0, 0.5), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.3), class = "b", dpar = "bias"),
  
  # Random effects - subject-level variability
  prior(student_t(3, 0, 0.5), class = "sd")
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
