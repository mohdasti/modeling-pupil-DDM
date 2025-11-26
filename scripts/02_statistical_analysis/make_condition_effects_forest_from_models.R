#!/usr/bin/env Rscript

# Real-data condition-effects forest plots (styled like the illustrative version)

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(ggplot2)
})

fixef_csv <- "output/results/ddm_per_task_vs_combined_fixef.csv"
stopifnot(file.exists(fixef_csv))
fx <- readr::read_csv(fixef_csv, show_col_types = FALSE)

# Helper: pick effect for a given model/term/dataset
pick_effect <- function(df, model_name, term_regex, dataset_label) {
  row <- df %>% filter(model == model_name, dataset == dataset_label, grepl(term_regex, term))
  if (nrow(row) == 0) return(NULL)
  row %>% slice(1) %>% select(estimate, l95, u95) %>% as.list()
}

# Build table for a dataset
build_table_for <- function(dataset_label) {
  # Prefer parameterized model (Model10_Param_v_bs) for both drift (b_) and boundary (bs_)
  # Fallback to v-only models when b_ terms are not present
  # Drift(v) difficulty
  drift_diff <- pick_effect(fx, "Model10_Param_v_bs", "(^b_|Intercept$).*difficulty_levelHard", dataset_label)
  if (is.null(drift_diff)) {
    drift_diff <- pick_effect(fx, "Model3_Difficulty", "^difficulty_levelHard$", dataset_label)
  }
  # Drift(v) effort
  drift_eff <- pick_effect(fx, "Model10_Param_v_bs", "(^b_|Intercept$).*effort_conditionLow_Force_5pct", dataset_label)
  if (is.null(drift_eff)) {
    drift_eff <- pick_effect(fx, "Model2_Force", "^effort_conditionLow_Force_5pct$", dataset_label)
  }
  # Boundary(alpha) difficulty
  bound_diff <- pick_effect(fx, "Model10_Param_v_bs", "^bs_difficulty_levelHard$", dataset_label)
  # Boundary(alpha) effort
  bound_eff <- pick_effect(fx, "Model10_Param_v_bs", "^bs_effort_conditionLow_Force_5pct$", dataset_label)

  out <- tibble::tibble(
    Parameter = c("Difficulty → Drift Rate (v)",
                  "Difficulty → Boundary Separation (α)",
                  "Effort → Boundary Separation (α)",
                  "Effort → Drift Rate (v)"),
    Estimate = c(drift_diff$estimate %||% NA_real_,
                 bound_diff$estimate %||% NA_real_,
                 bound_eff$estimate %||% NA_real_,
                 drift_eff$estimate %||% NA_real_),
    CI_lower = c(drift_diff$l95 %||% NA_real_,
                 bound_diff$l95 %||% NA_real_,
                 bound_eff$l95 %||% NA_real_,
                 drift_eff$l95 %||% NA_real_),
    CI_upper = c(drift_diff$u95 %||% NA_real_,
                 bound_diff$u95 %||% NA_real_,
                 bound_eff$u95 %||% NA_real_,
                 drift_eff$u95 %||% NA_real_)
  )
  out$dataset <- dataset_label
  out
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

datasets <- c("Combined","ADT","VDT")
tables <- lapply(datasets, build_table_for)
tbl_all <- bind_rows(tables)

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

make_plot <- function(df, title_suffix) {
  # Visual style similar to scripts/create_condition_effects_forest_plot.R
  p <- ggplot(df, aes(x = Estimate, y = Parameter)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray60", alpha = 0.7) +
    geom_point(color = "#2E8B57", size = 3) +
    geom_errorbarh(aes(xmin = CI_lower, xmax = CI_upper),
                   height = 0.2, linewidth = 1.2, color = "#2E8B57") +
    scale_x_continuous(breaks = scales::pretty_breaks(7)) +
    labs(
      title = paste0("Condition Effects on DDM Parameters (", title_suffix, ")"),
      subtitle = "Real estimates with 95% CIs from fitted models",
      x = "Standardized Coefficient (95% CI)", y = NULL
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5, color = "gray60"),
      axis.text.y = element_text(size = 12),
      axis.text.x = element_text(size = 11),
      axis.title.x = element_text(size = 12, face = "bold"),
      panel.grid.minor = element_blank()
    )
  p
}

for (ds in datasets) {
  df <- tbl_all %>% filter(dataset == ds)
  out_png <- file.path("output/figures", paste0("condition_effects_forest_plot_", tolower(ds), ".png"))
  ggsave(out_png, make_plot(df, ds), width = 10, height = 6, dpi = 300, bg = "white")
}

readr::write_csv(tbl_all, "output/results/condition_effects_forest_data.csv")
cat("Saved real-data condition effects forests to output/figures/:\n",
    paste0(" - ", file.path("output/figures", paste0("condition_effects_forest_plot_", tolower(datasets), ".png")), collapse = "\n"), "\n")

















