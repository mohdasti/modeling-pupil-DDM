suppressPackageStartupMessages({library(tidyverse)})
dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

# Try multiple possible locations
ppc_file <- if (file.exists("output/ppc/metrics/consolidated_for_chatgpt/01_all_ppc_metrics.csv")) {
  "output/ppc/metrics/consolidated_for_chatgpt/01_all_ppc_metrics.csv"
} else if (file.exists("output/publish/01_all_ppc_metrics.csv")) {
  "output/publish/01_all_ppc_metrics.csv"
} else {
  stop("PPC metrics file not found. Checked: output/ppc/metrics/consolidated_for_chatgpt/01_all_ppc_metrics.csv and output/publish/01_all_ppc_metrics.csv")
}

m <- read_csv(ppc_file, show_col_types=FALSE)

# Check required columns
required_cols <- c("model", "task", "effort_condition", "difficulty_level")
if (!all(required_cols %in% names(m))) {
  stop("Missing required columns. Found: ", paste(names(m), collapse=", "))
}

# Check for metric columns
ks_col <- names(m)[grepl("ks.*mean|ks_mean", names(m), ignore.case=TRUE)][1] %||% "ks_mean_max"
qp_col <- names(m)[grepl("qp.*rmse|qp_rmse", names(m), ignore.case=TRUE)][1] %||% "qp_rmse_max"

if (!ks_col %in% names(m) || !qp_col %in% names(m)) {
  stop("Cannot find KS or QP columns. Found: ", paste(names(m), collapse=", "))
}

# Prepare data
# Short model labels
model_map <- c(
  "Model1_Baseline" = "Baseline",
  "Model2_Force" = "Force",
  "Model3_Difficulty" = "Difficulty",
  "Model4_Additive" = "Additive",
  "Model5_Interaction" = "Effort×Diff",
  "Model6_Pupillometry" = "Pupil",
  "Model7_Task" = "Task",
  "Model8_Task_Additive" = "Task+",
  "Model9_Task_Intx" = "Task×",
  "Model10_Param_v_bs" = "Primary"
)

m <- m |>
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
    difficulty_level = factor(difficulty_level, levels=c("Standard","Easy","Hard")),
    # Create task×effort label
    task_effort = paste0(task, " (", effort_condition, ")"),
    model_num = suppressWarnings(as.numeric(stringr::str_extract(model, "(?<=Model)\\d+"))),
    model_num = if_else(is.na(model_num), Inf, model_num),
    model_short = recode(model, !!!model_map, .default = model)
  )

model_levels <- m |>
  distinct(model_short, model_num) |>
  arrange(model_num, model_short) |>
  pull(model_short)

m <- m |>
  mutate(
    model_short = factor(model_short, levels = model_levels)
  )

# Reshape to long format
to_long <- m |>
  select(model, model_short, task, effort_condition, difficulty_level, task_effort,
         ks = !!sym(ks_col), qp = !!sym(qp_col)) |>
  pivot_longer(cols=c(ks, qp), names_to="metric", values_to="value") |>
  mutate(
    metric = factor(metric, levels=c("ks", "qp"), labels=c("KS statistic", "QP RMSE"))
  )

# Identify primary model
primary_models <- c("fit_primary_vza", "Model10_Param_v_bs", "v_z_a")
primary_model <- if (any(m$model %in% primary_models)) {
  m$model[m$model %in% primary_models][1]
} else if (any(grepl("primary|v_z_a|Model10", m$model, ignore.case=TRUE))) {
  m$model[grepl("primary|v_z_a|Model10", m$model, ignore.case=TRUE)][1]
} else {
  names(sort(table(m$model), decreasing=TRUE))[1]
}

cat("Primary model:", primary_model, "\n")

# Plot 1: All models
plt_all <- to_long |>
  ggplot(aes(x=difficulty_level, y=task_effort, fill=value)) +
  geom_tile(color="white", linewidth=0.3) +
  facet_grid(metric ~ model_short, scales="free_x") +
  scale_fill_gradient(low="white", high="firebrick", name="Value") +
  labs(
    x="Difficulty", 
    y="Task × Effort",
    title="PPC Residual Heatmaps: All Models",
    subtitle="KS statistic and QP RMSE by Task × Effort × Difficulty"
  ) +
  theme_minimal(base_size=10) +
  theme(
    strip.text.x = element_text(size=8, angle=0),
    strip.text.y = element_text(size=9, face="bold"),
    plot.title = element_text(size=12, face="bold", hjust=0.5),
    plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
    axis.text.x = element_text(angle=0),
    legend.position="right"
  )

# Plot 2: Primary model only
to_long_primary <- to_long |>
  filter(model == primary_model)

primary_model_short <- unique(to_long_primary$model_short)[1]

plt_primary <- to_long_primary |>
  ggplot(aes(x=difficulty_level, y=task_effort, fill=value)) +
  geom_tile(color="white", linewidth=0.5) +
  facet_wrap(~metric, ncol=1, scales="free_y") +
  scale_fill_gradient(low="white", high="firebrick", name="Value") +
  labs(
    x="Difficulty", 
    y="Task × Effort",
    title=paste0("PPC Residual Heatmaps: Primary Model (", primary_model_short, ")"),
    subtitle="KS statistic and QP RMSE by Task × Effort × Difficulty"
  ) +
  theme_minimal(base_size=11) +
  theme(
    strip.text = element_text(size=10, face="bold"),
    plot.title = element_text(size=12, face="bold", hjust=0.5),
    plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
    legend.position="right"
  )

# Combine plots
library(patchwork)
plt_combined <- plt_all / plt_primary + plot_layout(heights = c(2, 1))

ggsave("output/figures/fig_ppc_heatmaps.pdf", plt_combined, width=12, height=10)

cat("Created PPC heatmaps: output/figures/fig_ppc_heatmaps.pdf\n")
cat("  - Top: All models\n")
cat("  - Bottom: Primary model (", primary_model, ")\n")

