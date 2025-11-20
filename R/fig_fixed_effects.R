suppressPackageStartupMessages({library(brms); library(tidyverse); library(posterior)})
dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

# Try multiple possible locations for the model file
model_file <- if (file.exists("output/publish/fit_primary_vza.rds")) {
  "output/publish/fit_primary_vza.rds"
} else if (file.exists("output/publish/fit_primary_vza_vEff_censored.rds")) {
  "output/publish/fit_primary_vza_vEff_censored.rds"
} else {
  stop("Model file not found. Checked: output/publish/fit_primary_vza*.rds")
}

fit <- readRDS(model_file)

# Extract fixed effects for drift (b_), boundary (b_bs_), and bias (b_bias_)
# Exclude ndt effects (b_ndt_) as they're not part of drift/boundary/bias
fx_draws <- as_draws_df(fit, variable = "^b(_(bs|bias))?_", regex=TRUE) |>
  select(-contains("ndt_"))

# Get task effect to compute conditional effects per task
task_effect <- fx_draws |>
  select(-.chain, -.iteration, -.draw) |>
  select(contains("taskVDT")) |>
  pivot_longer(everything(), names_to="variable", values_to="task_value") |>
  mutate(
    family = case_when(
      grepl("bs_", variable) ~ "Boundary (a)",
      grepl("bias_", variable) ~ "Bias (z)",
      TRUE ~ "Drift (v)"
    )
  ) |>
  group_by(family, variable) |>
  summarise(
    task_mean = mean(task_value),
    task_q2.5 = quantile(task_value, 0.025),
    task_q97.5 = quantile(task_value, 0.975),
    .groups = "drop"
  ) |>
  # Take first task effect per family (should be same for all parameters in that family)
  group_by(family) |>
  slice(1) |>
  ungroup()

# Compute summary statistics including 95% quantiles
fx <- fx_draws |>
  select(-.chain, -.iteration, -.draw) |>
  pivot_longer(everything(), names_to="variable", values_to="value") |>
  group_by(variable) |>
  summarise(
    mean = mean(value),
    q2.5 = quantile(value, 0.025),
    q97.5 = quantile(value, 0.975),
    .groups = "drop"
  )

# Tidy names and categorize effects
fx <- fx |>
  mutate(
    param = gsub("^b_", "", variable),
    family = case_when(
      grepl("^b_bs_", variable) ~ "Boundary (a)",
      grepl("^b_bias_", variable) ~ "Bias (z)",
      TRUE ~ "Drift (v)"
    ),
    term = gsub("^(bs_|bias_)", "", param)
  ) |>
  # Clean term names for display
  mutate(
    term_clean = case_when(
      grepl("difficulty_levelHard", term) ~ "Hard vs Standard",
      grepl("difficulty_levelEasy", term) ~ "Easy vs Standard",
      grepl("effort_conditionHigh_MVC", term) ~ "High vs Low MVC",
      grepl("^taskVDT", term) ~ "VDT vs ADT",
      TRUE ~ term
    )
  )

# Separate meaningful contrasts (difficulty, effort) - exclude task and intercept
fx_contrasts <- fx |>
  filter(
    grepl("difficulty_level|effort_condition", term),
    term != "Intercept"
  )

# Create separate plots for ADT and VDT
# ADT: intercept + difficulty/effort effects (taskVDT = 0, so no task effect added)
# VDT: intercept + difficulty/effort effects + taskVDT effect

# Function to create plot for a specific task
create_task_plot <- function(task_name, task_label, fx_data, task_effects) {
  # In an additive model, contrasts (difficulty/effort effects) are the SAME for both tasks
  # The task effect only affects the intercept/base level, not the contrasts themselves
  # So we show the same contrasts for both tasks (they represent differences, not absolute levels)
  fx_plot <- fx_data
  
  plt <- fx_plot |>
    ggplot(aes(x = reorder(term_clean, mean), y = mean)) +
    geom_pointrange(aes(ymin = `q2.5`, ymax = `q97.5`), size=0.5, fatten=2) +
    geom_hline(yintercept=0, linetype="dashed", color="gray50", alpha=0.6) +
    facet_wrap(~family, scales="free_y", ncol=1) +
    coord_flip() +
    labs(
      x=NULL, 
      y="Posterior mean (link scale); bars = 95% CrI",
      title=paste0("Fixed Effects: ", task_label),
      subtitle="Difficulty and Effort Contrasts (same for both tasks in additive model)"
    ) +
    theme_minimal(base_size=11) +
    theme(
      plot.title = element_text(size=12, face="bold", hjust=0.5),
      plot.subtitle = element_text(size=9, color="gray50", hjust=0.5, face="italic"),
      strip.text = element_text(face="bold")
    )
  
  return(plt)
}

# Create plots for ADT and VDT
plt_adt <- create_task_plot("ADT", "ADT (Auditory Detection Task)", fx_contrasts, task_effect)
plt_vdt <- create_task_plot("VDT", "VDT (Visual Detection Task)", fx_contrasts, task_effect)

# Save separate files
ggsave("output/figures/fig_fixed_effects_ADT.pdf", plt_adt, width=7.5, height=8.5)
ggsave("output/figures/fig_fixed_effects_VDT.pdf", plt_vdt, width=7.5, height=8.5)

cat("Created separate fixed effects plots:\n")
cat("  - output/figures/fig_fixed_effects_ADT.pdf\n")
cat("  - output/figures/fig_fixed_effects_VDT.pdf\n")

