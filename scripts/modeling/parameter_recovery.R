suppressPackageStartupMessages({ library(rtdists); library(dplyr); library(brms); library(purrr) })

set.seed(42)
n_subj <- 30; n_trials <- 400
sim <- map_dfr(1:n_subj, function(s) {
  # subject-level baselines
  b_pupil <- rnorm(1, 0, 1)
  # trial-level covariates
  pupil_evoked_z   <- rnorm(n_trials, 0, 1)
  pupil_baseline_z <- b_pupil + rnorm(n_trials, 0, 0.5)

  # true generative links
  v   <- 0.8 + 0.25*pupil_evoked_z + 0.10*pupil_baseline_z - 0.10*(pupil_baseline_z^2)
  a   <- exp(log(1.3) + (-0.15)*pupil_baseline_z)      # lower a with higher baseline
  ndt <- exp(log(0.3))
  z   <- plogis(qlogis(0.5) + (-0.10)*pupil_evoked_z)  # bias -> center with higher evoked

  # simulate
  rw <- rwiener(n_trials, alpha = a, tau = ndt, beta = z, delta = v)
  tibble(subj = s, rt = rw$q, choice = as.integer(rw$resp=="upper"),
         pupil_evoked_z, pupil_baseline_z)
})

# fit same model as in fit_ddm_brms.R (shorter iter for speed)
f <- bf(
  rt | dec(choice) ~ 1 + pupil_evoked_z + pupil_baseline_z + I(pupil_baseline_z^2) + (1 + pupil_evoked_z | subj),
  bs ~ 1 + pupil_baseline_z + (1 | subj),
  ndt ~ 1 + (1 | subj),
  bias ~ 1 + pupil_evoked_z + (1 | subj)
)
fit_rec <- brm(f, sim, family = wiener(link_bs="log", link_ndt="log", link_bias="logit"),
               cores=4, chains=4, iter=3000, warmup=1000, seed=42)

saveRDS(fit_rec, "models/ddm_recovery.rds")
