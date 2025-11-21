# R/extract_params_and_contrasts.R
# Export fixed-effect summaries for v, a (bs), z (bias), ndt
# Compute key contrasts with directional probabilities and ROPE

source("R/_helpers_extract.R")

suppressPackageStartupMessages({
  library(brms)
  library(posterior)
  library(tidyverse)
  library(broom.mixed)
})

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

# Load model
cat("Loading model from:", MODEL_PATH, "\n")
fit <- readRDS(MODEL_PATH)

# Fixed effects table (APA-ish)
cat("Extracting fixed effects...\n")
fx_tidy <- broom.mixed::tidy(fit, effects = "fixed")

# Get Rhat and ESS separately using posterior package
fx_draws <- as_draws_df(fit, variable = "^b_", regex = TRUE)
fx_vars <- fx_tidy$term

# Extract Rhat and ESS for matching variables
rhat_ess <- summarise_draws(fx_draws, default_convergence_measures()) %>%
  filter(variable %in% fx_vars) %>%
  select(variable, rhat, ess_bulk) %>%
  rename(term = variable)

# Join with tidy output
fx <- fx_tidy %>%
  left_join(rhat_ess, by = "term") %>%
  transmute(
    parameter = term,
    estimate,
    conf.low,
    conf.high,
    rhat,
    ess = ess_bulk
  )

write_clean(fx, "output/publish/table_fixed_effects.csv")
cat("✓ Fixed effects written.\n")

# Build small contrast helper (works on linear predictor/link scale)
post_diff <- function(fit, dpar, new1, new0) {
  d1 <- posterior_linpred(fit, newdata = new1, dpar = dpar, transform = FALSE, re_formula = NA)
  d0 <- posterior_linpred(fit, newdata = new0, dpar = dpar, transform = FALSE, re_formula = NA)
  as.numeric(d1 - d0)
}

# Factor levels from fitted data
dat <- fit$data
lev_task <- levels(dat$task)
lev_diff <- levels(dat$difficulty_level)
lev_eff  <- levels(dat$effort_condition)

# ROPE widths per parameter (link scales)
rope <- list(mu = 0.02, bs = 0.05, bias = 0.05)  # mu=v identity; bs log; bias logit

# Helper to create newdata frame
mk_nd <- function(task, diff, eff) {
  tibble(
    task = factor(task, levels = lev_task),
    difficulty_level = factor(diff, levels = lev_diff),
    effort_condition = factor(eff, levels = lev_eff),
    subject_id = dat$subject_id[1]  # any valid id for population-level draws
  )
}

# Key contrasts: Easy - Hard for v, bs, bias within each task at Low effort
cat("Computing Easy - Hard contrasts...\n")
pairs <- tibble(
  dpar = rep(c("mu", "bs", "bias"), each = length(lev_task)),
  task = rep(lev_task, times = 3)
)

res <- map2_dfr(pairs$dpar, pairs$task, function(dpar, task) {
  n1 <- mk_nd(task, "Easy", "Low_5_MVC")
  n0 <- mk_nd(task, "Hard", "Low_5_MVC")
  dif <- post_diff(fit, dpar, n1, n0)
  tibble(
    parameter = dpar,
    contrast = paste0("Easy - Hard (", task, ", Low)"),
    mean = mean(dif),
    q05 = quantile(dif, 0.05),
    q95 = quantile(dif, 0.95),
    p_gt0 = mean(dif > 0),
    p_lt0 = mean(dif < 0),
    p_in_rope = mean(abs(dif) < rope[[dpar]])
  )
})

# Effort contrast on drift and ndt: High - Low, collapsed over difficulty
cat("Computing Effort contrasts...\n")
eff_pairs <- tibble(dpar = c("mu", "ndt"))
res_eff <- map_dfr(eff_pairs$dpar, function(dpar) {
  n1 <- mk_nd("ADT", "Hard", "High_MVC")
  n0 <- mk_nd("ADT", "Hard", "Low_5_MVC")
  dif <- post_diff(fit, dpar, n1, n0)
  tibble(
    parameter = dpar,
    contrast = "High - Low (ADT, Hard)",
    mean = mean(dif),
    q05 = quantile(dif, 0.05),
    q95 = quantile(dif, 0.95),
    p_gt0 = mean(dif > 0),
    p_lt0 = mean(dif < 0),
    p_in_rope = mean(abs(dif) < ifelse(dpar == "ndt", 0.02, rope[[dpar]]))
  )
})

out <- bind_rows(res, res_eff)
write_clean(out, "output/publish/table_effect_contrasts.csv")
cat("✓ Contrasts written.\n")

message("✓ Parameter tables and contrasts written.")

cat("\n✓ Parameter extraction complete.\n")
cat("  Generated files:\n")
cat("    - output/publish/table_fixed_effects.csv\n")
cat("    - output/publish/table_effect_contrasts.csv\n")
cat("\n  Contrasts computed:\n")
cat("    - Easy - Hard for v, bs, bias (per task)\n")
cat("    - High - Low for v and ndt\n")

