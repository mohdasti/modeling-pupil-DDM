# =========================================================================
# EXTRACT AND COMPARE DDM FIXED EFFECTS: Combined vs ADT vs VDT
# =========================================================================
suppressPackageStartupMessages({
    library(brms)
    library(dplyr)
    library(purrr)
    library(readr)
    library(tidyr)
    library(ggplot2)
})

models_dir <- "output/models"
results_dir <- "output/results"
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

core_models <- c(
  "Model1_Baseline","Model2_Force","Model3_Difficulty",
  "Model4_Additive","Model5_Interaction","Model6_Pupillometry","Model10_Param_v_bs"
)
variants <- c(Combined = "", ADT = "_ADT", VDT = "_VDT")

safe_load <- function(path) if (file.exists(path)) readRDS(path) else NULL

extract_fixef <- function(fit, model_name, dataset_label) {
  if (is.null(fit)) return(NULL)
  fe <- tryCatch(brms::fixef(fit, summary = TRUE) %>% as.data.frame(), error = function(e) NULL)
  if (is.null(fe)) return(NULL)
  fe$term <- rownames(fe)
  fe %>%
    transmute(
      model = model_name,
      dataset = dataset_label,
      term,
      estimate = Estimate,
      est_error = `Est.Error`,
      l95 = `Q2.5`,
      u95 = `Q97.5`
    )
}

all_rows <- list()
for (m in core_models) {
  for (lab in names(variants)) {
    suf <- variants[[lab]]
    path <- file.path(models_dir, paste0(m, suf, ".rds"))
    fit <- safe_load(path)
    all_rows[[paste0(m, suf)]] <- extract_fixef(fit, m, lab)
  }
}

results <- bind_rows(all_rows) %>%
  filter(!is.na(estimate)) %>%
  arrange(model, dataset, term)

outfile <- file.path(results_dir, "ddm_per_task_vs_combined_fixef.csv")
write_csv(results, outfile)
cat(sprintf("\nWrote fixed effects comparison to: %s\n", outfile))

# Print a concise comparison for key condition terms
key <- results %>%
  filter(model %in% c("Model2_Force","Model3_Difficulty","Model4_Additive","Model5_Interaction") |
           (model %in% c("Model6_Pupillometry") & grepl("tonic|effort", term, ignore.case = TRUE)) |
           (model == "Model10_Param_v_bs" & grepl("^bs_|^b_", term)))
print(key)

# -------------------------------------------------------------------------
# Concise table: effect sizes and 95% CIs by dataset
# -------------------------------------------------------------------------
nice_term <- function(x) {
  x <- gsub("effort_conditionLow_Force_5pct", "Force: Low vs High", x, fixed = TRUE)
  x <- gsub("difficulty_levelHard", "Difficulty: Hard vs Easy", x, fixed = TRUE)
  x <- gsub("effort_conditionLow_Force_5pct:difficulty_levelHard", "Force × Difficulty", x, fixed = TRUE)
  x <- gsub("effort_arousal_scaled", "Phasic (effort_arousal)", x, fixed = TRUE)
  x <- gsub("tonic_arousal_scaled", "Tonic (baseline)", x, fixed = TRUE)
  # brms names for parameterized wiener: b_... are drift rate effects, bs_... are boundary separation
  x <- gsub("^b_", "Drift v: ", x)
  x <- gsub("^bs_", "Boundary α: ", x)
  x
}

summary_table <- key %>%
  mutate(term_pretty = nice_term(term)) %>%
  transmute(model, term = term_pretty, dataset,
            estimate_ci = sprintf("%.3f [%.3f, %.3f]", estimate, l95, u95)) %>%
  arrange(model, term, match(dataset, c("Combined","ADT","VDT"))) %>%
  group_by(model, term) %>%
  summarise(
    Combined = estimate_ci[dataset == "Combined"][1],
    ADT = estimate_ci[dataset == "ADT"][1],
    VDT = estimate_ci[dataset == "VDT"][1],
    .groups = "drop"
  )

summary_outfile <- file.path(results_dir, "ddm_effects_summary_combined_ADT_VDT.csv")
write_csv(summary_table, summary_outfile)
cat(sprintf("Wrote concise summary table to: %s\n", summary_outfile))

# -------------------------------------------------------------------------
# Forest plots: each term across Combined/ADT/VDT
# -------------------------------------------------------------------------
fig_dir <- file.path("output", "figures", "diagnostics")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

plot_key <- key %>% mutate(term_pretty = nice_term(term))

plot_one <- function(df_term, model_name, term_name) {
  df_term <- df_term %>% mutate(dataset = factor(dataset, levels = c("Combined","ADT","VDT")))
  ggplot(df_term, aes(x = dataset, y = estimate)) +
    geom_point(size = 2) +
    geom_errorbar(aes(ymin = l95, ymax = u95), width = 0.1) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(title = paste0(model_name, " - ", term_name), x = NULL, y = "Estimate (95% CI)") +
    theme_minimal(base_size = 12)
}

by_term <- plot_key %>% group_by(model, term_pretty)
plot_files <- c()
by_term %>% group_walk(function(df, keys) {
  p <- plot_one(df, keys$model, keys$term_pretty)
  file_slug <- paste0(gsub("[^A-Za-z0-9]+", "_", keys$model), "__", gsub("[^A-Za-z0-9]+", "_", keys$term_pretty), ".png")
  out_path <- file.path(fig_dir, file_slug)
  ggsave(out_path, p, width = 6, height = 4, dpi = 300)
  plot_files <<- c(plot_files, out_path)
})

cat("Saved forest plots:\n")
cat(paste0(" - ", plot_files, collapse = "\n"), "\n")

