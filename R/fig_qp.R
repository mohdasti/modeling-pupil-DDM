suppressPackageStartupMessages({library(tidyverse)})
dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

# Try multiple possible locations
qp_file <- if (file.exists("output/ppc/metrics/consolidated_for_chatgpt/03_all_qp_detail.csv")) {
  "output/ppc/metrics/consolidated_for_chatgpt/03_all_qp_detail.csv"
} else if (file.exists("output/publish/03_all_qp_detail.csv")) {
  "output/publish/03_all_qp_detail.csv"
} else {
  stop("QP file not found. Checked: output/ppc/metrics/consolidated_for_chatgpt/03_all_qp_detail.csv and output/publish/03_all_qp_detail.csv")
}

qp <- read_csv(qp_file, show_col_types=FALSE)

# Filter to primary model if model column exists
if ("model" %in% names(qp)) {
  # Try to find primary model
  primary_models <- c("fit_primary_vza", "Model10_Param_v_bs", "v_z_a")
  model_match <- qp$model %in% primary_models | grepl("primary|v_z_a", qp$model, ignore.case=TRUE)
  if (any(model_match)) {
    qp <- qp |> filter(model_match)
    cat("Filtered to primary model. Rows:", nrow(qp), "\n")
  } else {
    # Take first model or most common
    qp <- qp |> filter(model == names(sort(table(qp$model), decreasing=TRUE))[1])
    cat("Using model:", unique(qp$model), ". Rows:", nrow(qp), "\n")
  }
}

# Check required columns
required_cols <- c("task","effort_condition","difficulty_level")
if (!all(required_cols %in% names(qp))) {
  stop("Missing required columns. Found: ", paste(names(qp), collapse=", "))
}

# Check format: wide format with rt_q10, rt_q30, etc. and rt_q10_mean, etc.
has_wide_format <- any(grepl("^rt_q[0-9]", names(qp))) && any(grepl("_mean$", names(qp)))

if (has_wide_format) {
  # Reshape from wide to long format
  # Empirical quantiles: rt_q10, rt_q30, rt_q50, rt_q70, rt_q90
  # Predicted quantiles: rt_q10_mean, rt_q30_mean, rt_q50_mean, rt_q70_mean, rt_q90_mean
  
  # Extract empirical quantiles
  qp_emp <- qp |>
    select(task, effort_condition, difficulty_level, correct, 
           rt_q10, rt_q30, rt_q50, rt_q70, rt_q90) |>
    pivot_longer(
      cols = c(rt_q10, rt_q30, rt_q50, rt_q70, rt_q90),
      names_to = "quantile_col",
      values_to = "q_emp"
    ) |>
    mutate(
      q = case_when(
        quantile_col == "rt_q10" ~ 0.1,
        quantile_col == "rt_q30" ~ 0.3,
        quantile_col == "rt_q50" ~ 0.5,
        quantile_col == "rt_q70" ~ 0.7,
        quantile_col == "rt_q90" ~ 0.9,
        TRUE ~ NA_real_
      )
    ) |>
    select(-quantile_col)
  
  # Extract predicted quantiles
  qp_pred <- qp |>
    select(task, effort_condition, difficulty_level, correct,
           rt_q10_mean, rt_q30_mean, rt_q50_mean, rt_q70_mean, rt_q90_mean) |>
    pivot_longer(
      cols = c(rt_q10_mean, rt_q30_mean, rt_q50_mean, rt_q70_mean, rt_q90_mean),
      names_to = "quantile_col",
      values_to = "q_pred"
    ) |>
    mutate(
      q = case_when(
        quantile_col == "rt_q10_mean" ~ 0.1,
        quantile_col == "rt_q30_mean" ~ 0.3,
        quantile_col == "rt_q50_mean" ~ 0.5,
        quantile_col == "rt_q70_mean" ~ 0.7,
        quantile_col == "rt_q90_mean" ~ 0.9,
        TRUE ~ NA_real_
      )
    ) |>
    select(-quantile_col)
  
  # Combine (ensure one-to-one join)
  qp <- qp_emp |>
    left_join(qp_pred, by=c("task", "effort_condition", "difficulty_level", "correct", "q"), 
              relationship = "one-to-one") |>
    mutate(
      acc_type = if_else(correct, "Correct", "Error")
    )
} else if (all(c("q_emp", "q_pred") %in% names(qp))) {
  # Already in correct format
  if (!"acc_type" %in% names(qp)) {
    if ("correct" %in% names(qp)) {
      qp <- qp |> mutate(acc_type = if_else(correct, "Correct", "Error"))
    } else if ("decision" %in% names(qp)) {
      qp <- qp |> mutate(acc_type = if_else(decision == 1, "Correct", "Error"))
    } else {
      qp <- qp |> mutate(acc_type = "All")
    }
  }
} else {
  stop("Cannot parse QP data format. Found columns: ", paste(names(qp), collapse=", "))
}

# Prepare data
qp <- qp |>
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
    acc_type = factor(acc_type, levels=c("Correct","Error","All"))
  ) |>
  filter(!is.na(q_emp), !is.na(q_pred), is.finite(q_emp), is.finite(q_pred))

plt <- qp |>
  ggplot(aes(x=q_emp, y=q_pred, color=difficulty_level, shape=acc_type, 
             group=interaction(difficulty_level,acc_type))) +
  geom_abline(slope=1, intercept=0, linetype="dashed", color="gray50", alpha=0.6) +
  geom_point(size=2) +
  geom_path(alpha=0.6, linewidth=0.7) +
  facet_grid(task ~ effort_condition) +
  labs(
    x="Empirical RT quantile (s)", 
    y="Predicted RT quantile (s)", 
    color="Difficulty",
    shape="Response",
    title="Quantile-Probability Plot: Predicted vs Empirical RT Quantiles",
    subtitle="By Task × Effort (colored by Difficulty, grouped by Response Type)"
  ) +
  scale_color_manual(
    values=c("Standard"="gray40", "Easy"="steelblue", "Hard"="darkred")
  ) +
  scale_shape_manual(values=c("Correct"=16, "Error"=17, "All"=15)) +
  theme_minimal(base_size=11) +
  theme(
    legend.position="top",
    plot.title = element_text(size=12, face="bold", hjust=0.5),
    plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
    strip.text = element_text(face="bold")
  )

ggsave("output/figures/fig_qp.pdf", plt, width=8.5, height=5.5)

cat("Created QP plot: output/figures/fig_qp.pdf\n")

