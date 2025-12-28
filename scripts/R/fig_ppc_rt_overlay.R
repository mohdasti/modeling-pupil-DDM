suppressPackageStartupMessages({library(tidyverse); library(brms)})
dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

# Load model and data
model_file <- if (file.exists("output/publish/fit_primary_vza.rds")) {
  "output/publish/fit_primary_vza.rds"
} else if (file.exists("output/publish/fit_primary_vza_vEff_censored.rds")) {
  "output/publish/fit_primary_vza_vEff_censored.rds"
} else {
  stop("Model file not found. Checked: output/publish/fit_primary_vza*.rds")
}

data_file <- "data/analysis_ready/bap_ddm_ready.csv"

fit <- readRDS(model_file)
dd <- read_csv(data_file, show_col_types=FALSE)

# Prepare data
dd <- dd |>
  mutate(
    task = factor(task),
    # Rename effort conditions
    effort_condition = case_when(
      effort_condition == "High_MVC" ~ "High",
      effort_condition == "Low_5_MVC" ~ "Low",
      TRUE ~ as.character(effort_condition)
    ) |>
      factor(levels=c("Low","High")),
    # Reorder difficulty: Standard, Easy, Hard
    difficulty_level = factor(difficulty_level, levels=c("Standard","Easy","Hard"))
  )

# Generate posterior predictive samples (use subset for speed)
cat("Generating posterior predictive samples...\n")
pp_samples <- posterior_predict(fit, ndraws=100)
cat("Generated", nrow(pp_samples), "draws ×", ncol(pp_samples), "trials\n")

# Prepare empirical RTs
empirical_rts <- dd |>
  select(task, effort_condition, difficulty_level, rt) |>
  mutate(type = "Empirical")

# Prepare predictive RTs (sample from posterior predictive)
# Reshape pp_samples: each row is a draw, each column is a trial
n_draws <- min(50, nrow(pp_samples))  # Use 50 draws for density estimation
pred_rts <- as.vector(pp_samples[1:n_draws, ])

# Match predictive RTs to conditions (repeat conditions for each draw)
pred_data <- dd |>
  select(task, effort_condition, difficulty_level) |>
  slice(rep(1:n(), n_draws)) |>
  mutate(
    rt = pred_rts,
    type = "Predictive"
  )

# Combine empirical and predictive
ppc <- bind_rows(empirical_rts, pred_data) |>
  mutate(
    type = factor(type, levels=c("Empirical","Predictive")),
    task = factor(task),
    # Rename effort conditions
    effort_condition = case_when(
      effort_condition == "High_MVC" ~ "High",
      effort_condition == "Low_5_MVC" ~ "Low",
      TRUE ~ as.character(effort_condition)
    ) |>
      factor(levels=c("Low","High")),
    # Reorder difficulty: Standard, Easy, Hard
    difficulty_level = factor(difficulty_level, levels=c("Standard","Easy","Hard"))
  ) |>
  filter(!is.na(rt), is.finite(rt), rt > 0)

# Create combined facet label for task × effort
ppc <- ppc |>
  mutate(
    task_effort = paste0(task, " (", effort_condition, ")")
  )

plt <- ppc |>
  ggplot(aes(x=rt, color=type)) +
  geom_density(adjust=1.2, linewidth=0.7) +
  scale_color_manual(
    values=c("Empirical"="black", "Predictive"="steelblue"),
    labels=c("Empirical"="Observed", "Predictive"="Predicted")
  ) +
  facet_grid(task_effort ~ difficulty_level, scales="free_y") +
  labs(
    x="RT (s)", 
    y="Density", 
    color=NULL,
    title="Posterior Predictive Check: RT Distributions",
    subtitle="Observed vs Predicted Densities by Task × Effort × Difficulty"
  ) +
  theme_minimal(base_size=11) +
  theme(
    legend.position="top",
    plot.title = element_text(size=12, face="bold", hjust=0.5),
    plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
    strip.text = element_text(face="bold")
  )

ggsave("output/figures/fig_ppc_rt_overlay.pdf", plt, width=9, height=6.5)

cat("Created RT overlay plot: output/figures/fig_ppc_rt_overlay.pdf\n")

