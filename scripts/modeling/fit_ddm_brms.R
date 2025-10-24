# scripts/modeling/fit_ddm_brms.R
suppressPackageStartupMessages({
  library(dplyr); library(brms); library(readr); library(stringr)
})

# ---- Load cleaned trial-level data ----
# expects cols: rt (sec), choice (0/1), subj, condition,
# pupil_baseline_z, pupil_evoked_z, prev_choice, prev_outcome, luminance_z
d <- read_csv("data/derived/trials_with_pupil.csv") %>%
  mutate(
    choice = as.integer(choice),
    subj   = factor(subj)
  )

# ---- DDM with Wiener family ----
f_ddm <- bf(
  rt | dec(choice) ~ 1 +
    pupil_evoked_z + pupil_baseline_z + I(pupil_baseline_z^2) +
    condition + prev_choice + prev_outcome + luminance_z +
    (1 + pupil_evoked_z | subj),
  bs   ~ 1 + pupil_baseline_z + (1 | subj),   # boundary separation
  ndt  ~ 1 + (1 | subj),                      # non-decision time
  bias ~ 1 + pupil_evoked_z + (1 | subj)      # starting point (0..1)
)

pri <- c(
  prior(normal(0, 0.5), class = "b"),     # fixed effects on standardized inputs
  prior(normal(0, 1),   class = "sd"),    # random effect sds
  prior(normal(0, 0.2), class = "Intercept", dpar = "bias"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.2), class = "Intercept", dpar = "ndt")
)

fit <- brm(
  formula = f_ddm,
  data = d,
  family = wiener(link_bs = "log", link_ndt = "log", link_bias = "logit"),
  prior = pri,
  cores = max(2, parallel::detectCores() - 2),
  chains = 4, iter = 4000, warmup = 1000,
  control = list(adapt_delta = 0.9, max_treedepth = 12),
  seed = 123
)

dir.create("models", showWarnings = FALSE)
saveRDS(fit, file = "models/ddm_brms_main.rds")
