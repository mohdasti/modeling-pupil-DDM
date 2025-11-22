suppressPackageStartupMessages({ library(brms); library(loo) })

fit_full <- readRDS("models/ddm_brms_main.rds")

# Refit restricted variants if not already saved
        ensure_fit <- function(path, formula_fun) {
          if (!file.exists(path)) {
            d <- readr::read_csv("data/analysis_ready/bap_ddm_ready.csv", show_col_types = FALSE)
    f <- formula_fun()
    saveRDS(brm(
      formula = f, data = d,
      family = wiener(link_bs="log", link_ndt="log", link_bias="logit"),
      prior = c(
        # STANDARDIZED PRIORS: Literature-justified for older adults + response-signal design
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
      ),
      cores = 4, iter = 3000, warmup = 1000, control = list(adapt_delta=0.9), seed=123
    ), file = path)
  }
  readRDS(path)
}

bf_base <- function() bf(rt | dec(choice) ~ 1 + condition + (1 | subj),
                         bs ~ 1 + (1 | subj), ndt ~ 1 + (1 | subj), bias ~ 1 + (1 | subj))

bf_v_only <- function() bf(rt | dec(choice) ~ 1 + pupil_evoked_z + condition + (1 + pupil_evoked_z | subj),
                           bs ~ 1 + (1 | subj), ndt ~ 1 + (1 | subj), bias ~ 1 + (1 | subj))

bf_a_only <- function() bf(rt | dec(choice) ~ 1 + condition + (1 | subj),
                           bs ~ 1 + pupil_baseline_z + (1 | subj),
                           ndt ~ 1 + (1 | subj), bias ~ 1 + (1 | subj))

bf_bias_only <- function() bf(rt | dec(choice) ~ 1 + condition + (1 | subj),
                              bs ~ 1 + (1 | subj), ndt ~ 1 + (1 | subj),
                              bias ~ 1 + pupil_evoked_z + (1 | subj))

fit_base  <- ensure_fit("models/ddm_base.rds",       bf_base)
fit_v     <- ensure_fit("models/ddm_v_only.rds",     bf_v_only)
fit_a     <- ensure_fit("models/ddm_a_only.rds",     bf_a_only)
fit_bias  <- ensure_fit("models/ddm_bias_only.rds",  bf_bias_only)

lc <- loo_compare(loo(fit_full), loo(fit_v), loo(fit_a), loo(fit_bias), loo(fit_base))
print(lc)
readr::write_lines(capture.output(lc), "models/loo_compare.txt")
