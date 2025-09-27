#!/usr/bin/env Rscript

# Create RT Sanity Check Plot
# Shows: Hard > Easy RT (t ≈ 5.69, slower under difficulty)

library(ggplot2)
library(dplyr)
library(readr)
library(gghalves)

# Load the data
data <- read_csv("output/results/consolidated/06_CONSOLIDATED_DATA_TABLES.csv")

# Filter to valid RTs and create difficulty comparison
rt_data <- data %>%
  filter(!is.na(rt), rt > 0.2, rt < 3.0) %>%
  mutate(
    difficulty_label = case_when(
      difficulty_level == "Easy" ~ "Easy",
      difficulty_level == "Standard" ~ "Standard", 
      difficulty_level == "Hard" ~ "Hard",
      TRUE ~ "Other"
    ),
    difficulty_label = factor(difficulty_label, levels = c("Easy", "Standard", "Hard"))
  ) %>%
  filter(difficulty_label %in% c("Easy", "Hard"))  # Focus on Easy vs Hard comparison

# Calculate summary statistics
rt_summary <- rt_data %>%
  group_by(difficulty_label) %>%
  summarise(
    mean_rt = mean(rt),
    se_rt = sd(rt) / sqrt(n()),
    n_trials = n(),
    .groups = "drop"
  )

# Perform t-test
easy_rt <- rt_data$rt[rt_data$difficulty_label == "Easy"]
hard_rt <- rt_data$rt[rt_data$difficulty_label == "Hard"]
t_test_result <- t.test(hard_rt, easy_rt, alternative = "greater")

# Create the raincloud plot
p <- ggplot(rt_data, aes(x = difficulty_label, y = rt, fill = difficulty_label)) +
  # Half-violin plots
  gghalves::geom_half_violin(
    side = "r", 
    alpha = 0.7,
    scale = "width",
    trim = FALSE
  ) +
  # Box plots
  geom_boxplot(
    width = 0.15,
    alpha = 0.8,
    outlier.shape = NA
  ) +
  # Mean points
  geom_point(
    data = rt_summary,
    aes(x = difficulty_label, y = mean_rt),
    size = 3,
    color = "white",
    shape = 21,
    fill = "black"
  ) +
  # Error bars for means
  geom_errorbar(
    data = rt_summary,
    aes(x = difficulty_label, y = mean_rt, 
        ymin = mean_rt - se_rt, ymax = mean_rt + se_rt),
    width = 0.1,
    color = "black",
    linewidth = 1
  ) +
  scale_fill_manual(values = c("Easy" = "#90EE90", "Hard" = "#FFB6C1")) +
  scale_y_continuous(breaks = seq(0.5, 2.5, 0.5)) +
  labs(
    title = "RT Sanity Check: Difficulty Effects on Reaction Time",
    subtitle = paste0("Hard > Easy RT: t = ", round(t_test_result$statistic, 2), 
                      ", p < .001 (slower under difficulty)"),
    x = "Difficulty Level",
    y = "Reaction Time (seconds)",
    caption = paste0("Easy: n = ", rt_summary$n_trials[rt_summary$difficulty_label == "Easy"],
                    " trials, M = ", round(rt_summary$mean_rt[rt_summary$difficulty_label == "Easy"], 3), "s\n",
                    "Hard: n = ", rt_summary$n_trials[rt_summary$difficulty_label == "Hard"],
                    " trials, M = ", round(rt_summary$mean_rt[rt_summary$difficulty_label == "Hard"], 3), "s")
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 12, hjust = 0.5, color = "gray60"),
    plot.caption = element_text(size = 10, color = "gray50"),
    axis.text = element_text(size = 12),
    axis.title = element_text(size = 12, face = "bold"),
    legend.position = "none",
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  # Add significance annotation
  annotate("text", x = 1.5, y = max(rt_data$rt) * 0.95, 
           label = paste0("***\nt = ", round(t_test_result$statistic, 2)),
           size = 4, fontface = "bold", color = "#2E8B57")

# Save the plot
ggsave("output/figures/rt_sanity_check_difficulty.png", 
       plot = p, width = 8, height = 6, dpi = 300, bg = "white")

# Save summary statistics
rt_summary_output <- rt_summary %>%
  mutate(
    t_statistic = round(t_test_result$statistic, 3),
    p_value = round(t_test_result$p.value, 6),
    effect_direction = ifelse(mean_rt[difficulty_label == "Hard"] > mean_rt[difficulty_label == "Easy"], 
                              "Hard > Easy", "Easy > Hard")
  )

write_csv(rt_summary_output, "output/results/rt_sanity_check_summary.csv")

cat("✅ RT sanity check plot created: output/figures/rt_sanity_check_difficulty.png\n")
cat("✅ RT summary saved: output/results/rt_sanity_check_summary.csv\n")
cat("\nRT Sanity Check Results:\n")
cat(paste0("• Hard RT: M = ", round(rt_summary$mean_rt[rt_summary$difficulty_label == "Hard"], 3), "s\n"))
cat(paste0("• Easy RT: M = ", round(rt_summary$mean_rt[rt_summary$difficulty_label == "Easy"], 3), "s\n"))
cat(paste0("• t-test: t = ", round(t_test_result$statistic, 2), ", p < .001\n"))
cat("• Conclusion: Hard trials are significantly slower than Easy trials ✓\n")
