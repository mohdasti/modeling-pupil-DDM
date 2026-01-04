# R/fig_pdiff_heatmap.R

suppressPackageStartupMessages({
  library(brms); library(dplyr); library(readr); library(ggplot2); library(tidyr); library(posterior)
})

dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)

fit <- readRDS("output/publish/fit_joint_vza_stdconstrained.rds")

dd <- read_csv("data/analysis_ready/bap_ddm_ready_with_upper.csv", show_col_types = FALSE) %>%
  mutate(
    subject_id = factor(subject_id),
    task = factor(task),
    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),
    decision = as.integer(dec_upper),
    is_nonstd = ifelse(difficulty_level == "Standard", 0L, 1L),
    cell = interaction(task, effort_condition, difficulty_level, drop = TRUE)
  )

# Observed p("different") by cell
obs <- dd %>%
  group_by(cell, task, effort_condition, difficulty_level) %>%
  summarize(
    p_obs = mean(dec_upper == 1, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

# Compute predicted p("different") from model parameters
# For DDM, p(upper) = 1 / (1 + exp(-2*a*z*v)) where a=boundary, z=bias, v=drift
# But this is complex. Instead, use posterior_linpred to get linear predictors,
# then compute predicted probabilities from the bias parameter (which is on logit scale)

# Get population-level predictions for bias (logit scale)
# Create newdata for each cell
newdata <- obs %>%
  select(task, effort_condition, difficulty_level) %>%
  distinct() %>%
  mutate(
    subject_id = dd$subject_id[1],  # Use any subject for population-level
    is_nonstd = ifelse(difficulty_level == "Standard", 0L, 1L)
  )

# Get posterior draws of bias (logit scale) for each cell
set.seed(20251119)
bias_pred <- posterior_linpred(
  fit,
  newdata = newdata,
  dpar = "bias",
  re_formula = NA,  # Population-level only
  transform = FALSE  # Keep on logit scale
)

# Convert to probability scale and compute mean across draws
bias_prob <- apply(bias_pred, 2, function(x) mean(plogis(x)))  # Mean of expit(bias)

# Add predicted probabilities
newdata$p_pred <- bias_prob

# Merge with observed
hm <- obs %>%
  left_join(newdata, by = c("task", "effort_condition", "difficulty_level")) %>%
  mutate(
    task_label = factor(task, levels = c("ADT", "VDT")),
    effort_label = factor(effort_condition, 
                          levels = c("Low_5_MVC", "High_MVC"),
                          labels = c("Low", "High")),
    difficulty_label = factor(difficulty_level,
                             levels = c("Standard", "Hard", "Easy"))
  )

# Create two-panel plot: observed and predicted
hm_long <- hm %>%
  select(task_label, effort_label, difficulty_label, p_obs, p_pred) %>%
  pivot_longer(cols = c(p_obs, p_pred), names_to = "type", values_to = "p") %>%
  mutate(
    type_label = factor(type, 
                       levels = c("p_obs", "p_pred"),
                       labels = c("Observed", "Predicted"))
  )

p <- ggplot(hm_long, aes(x = effort_label, y = difficulty_label, fill = p)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f", p)), color = "white", size = 3, fontface = "bold") +
  facet_grid(type_label ~ task_label) +
  scale_fill_gradient2(
    low = "darkblue",
    mid = "white",
    high = "darkred",
    midpoint = 0.5,
    name = "p('different')",
    limits = c(0, 1)
  ) +
  labs(
    x = "Effort Condition",
    y = "Difficulty Level",
    title = "Observed vs Predicted p('different') by Cell",
    subtitle = "Values shown in each tile"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.subtitle = element_text(size = 9, color = "gray40"),
    strip.text = element_text(face = "bold"),
    panel.grid = element_blank()
  )

ggsave("output/figures/fig_pdiff_heatmap.png", p, width = 6.18, height = 4.63, units = "in", dpi = 300)
ggsave("output/figures/fig_pdiff_heatmap.pdf", p, width = 6.18, height = 4.63, units = "in")

cat("✓ Wrote output/figures/fig_pdiff_heatmap.png\n")
cat("✓ Wrote output/figures/fig_pdiff_heatmap.pdf\n")

# Print summary
cat("\nObserved vs Predicted p('different'):\n")
print(hm %>% select(task, effort_condition, difficulty_level, p_obs, p_pred) %>%
      mutate(diff = p_obs - p_pred) %>%
      arrange(desc(abs(diff))))

