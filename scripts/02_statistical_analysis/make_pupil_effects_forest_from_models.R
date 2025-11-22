#!/usr/bin/env Rscript

# Real-data forest plots for pupillometry effects across Combined, ADT, VDT

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

fixef_csv <- "output/results/ddm_per_task_vs_combined_fixef.csv"
stopifnot(file.exists(fixef_csv))
fx <- readr::read_csv(fixef_csv, show_col_types = FALSE)

pick <- function(df, term_pat, dataset_label) {
  row <- df %>% filter(model == "Model6_Pupillometry", dataset == dataset_label, grepl(term_pat, term, ignore.case = TRUE))
  if (nrow(row) == 0) return(NULL)
  row %>% slice(1) %>% select(estimate, l95, u95) %>% as.list()
}

build_tbl <- function(dataset_label) {
  phasic <- pick(fx, "effort_arousal_scaled", dataset_label)
  tonic  <- pick(fx, "tonic_arousal_scaled", dataset_label)
  tibble::tibble(
    Parameter = c("Phasic (effort_arousal) → Drift Rate (v)",
                  "Tonic (baseline) → Drift Rate (v)"),
    Estimate = c(phasic$estimate %||% NA_real_, tonic$estimate %||% NA_real_),
    CI_lower = c(phasic$l95 %||% NA_real_, tonic$l95 %||% NA_real_),
    CI_upper = c(phasic$u95 %||% NA_real_, tonic$u95 %||% NA_real_),
    dataset = dataset_label
  )
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

datasets <- c("Combined","ADT","VDT")
tbl <- dplyr::bind_rows(lapply(datasets, build_tbl))

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/results", recursive = TRUE, showWarnings = FALSE)

plot_one <- function(df, label) {
  ggplot(df, aes(x = Estimate, y = Parameter)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray60", alpha = 0.7) +
    geom_point(color = "#1f77b4", size = 3) +
    geom_errorbarh(aes(xmin = CI_lower, xmax = CI_upper), height = 0.2, linewidth = 1.2, color = "#1f77b4") +
    labs(title = paste0("Pupillometry Effects (", label, ")"),
         subtitle = "Real estimates with 95% CIs from Model6_Pupillometry",
         x = "Standardized Coefficient (95% CI)", y = NULL) +
    theme_minimal(base_size = 14) +
    theme(plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
          plot.subtitle = element_text(size = 12, hjust = 0.5, color = "gray60"),
          axis.text.y = element_text(size = 12),
          axis.text.x = element_text(size = 11),
          axis.title.x = element_text(size = 12, face = "bold"),
          panel.grid.minor = element_blank())
}

for (ds in datasets) {
  out_png <- file.path("output/figures", paste0("pupil_effects_forest_plot_", tolower(ds), ".png"))
  ggsave(out_png, plot_one(tbl %>% filter(dataset == ds), ds), width = 10, height = 5, dpi = 300, bg = "white")
}

readr::write_csv(tbl, "output/results/pupil_effects_forest_data.csv")
cat("Saved real-data pupillometry forest plots to output/figures/:\n",
    paste0(" - ", file.path("output/figures", paste0("pupil_effects_forest_plot_", tolower(datasets), ".png")), collapse = "\n"), "\n")
















