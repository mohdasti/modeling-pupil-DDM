# R/table_fixed_effects.R
# Export APA-ready fixed-effect summaries (mean, 95% CrI, Rhat, ESS) for v, a, z, ndt

suppressPackageStartupMessages({
  library(brms)
  library(tidyverse)
  library(posterior)
})

# Set working directory
if (basename(getwd()) == "R") {
  setwd("..")
}

# Load model
fit_file <- "output/publish/fit_primary_vza.rds"
if (!file.exists(fit_file)) {
  fit_file <- "output/models/primary_vza.rds"
}
if (!file.exists(fit_file)) {
  stop("Could not find primary model file. Expected: output/publish/fit_primary_vza.rds or output/models/primary_vza.rds")
}

fit <- readRDS(fit_file)
cat("Loaded model from:", fit_file, "\n")

# Extract fixed effects using brms::fixef
fx_summary <- fixef(fit, summary = TRUE) %>%
  as.data.frame() %>%
  rownames_to_column("term") %>%
  rename(
    mean = Estimate,
    est_error = Est.Error,
    q2.5 = Q2.5,
    q97.5 = Q97.5
  )

# Get Rhat and ESS separately using posterior package
# Extract all draws and filter for fixed effects
all_draws <- as_draws_df(fit)
fx_vars <- fx_summary$term

# Filter draws to only fixed effect variables
fx_draws <- all_draws %>%
  select(matches("^b_"), .chain, .iteration, .draw)

# Extract Rhat and ESS for matching variables
rhat_ess <- summarise_draws(fx_draws, default_convergence_measures()) %>%
  filter(variable %in% fx_vars) %>%
  select(variable, rhat, ess_bulk, ess_tail) %>%
  rename(term = variable)

# Join
fx_table <- fx_summary %>%
  left_join(rhat_ess, by = "term") %>%
  mutate(
    # Categorize by parameter family (check term names from fixef output)
    family = case_when(
      grepl("^b_bs_|^bs_", term) ~ "Boundary (a/bs)",
      grepl("^b_ndt_|^ndt_", term) ~ "Non-decision time (t0)",
      grepl("^b_bias_|^bias_", term) ~ "Bias (z)",
      term == "Intercept" ~ "Drift (v)",
      grepl("^b_", term) & !grepl("^(bs|ndt|bias)_", term) ~ "Drift (v)",
      TRUE ~ "Other"
    ),
    # Clean term names (remove b_ prefix and dpar prefixes)
    term_clean = str_remove(term, "^b_(bs|ndt|bias)_") %>%
      str_remove("^b_") %>%
      str_replace("Intercept", "Intercept") %>%
      str_replace("taskVDT", "Task (VDT vs ADT)") %>%
      str_replace("effort_conditionHigh_MVC", "Effort (High vs Low)") %>%
      str_replace("difficulty_levelHard", "Difficulty (Hard vs Standard)") %>%
      str_replace("difficulty_levelEasy", "Difficulty (Easy vs Standard)")
  ) %>%
  arrange(family, term) %>%
  select(family, term_clean, mean, q2.5, q97.5, rhat, ess_bulk, ess_tail)

# Save
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)
write_csv(fx_table, "output/publish/table_fixed_effects.csv")
cat("✓ Saved: output/publish/table_fixed_effects.csv\n")
cat("Rows:", nrow(fx_table), "\n")
cat("\nFirst few rows:\n")
print(head(fx_table, 10))

