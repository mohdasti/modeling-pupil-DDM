# =========================================================================
# REPORT: Combined vs ADT vs VDT – Fixed Effects and Forest Plots
# =========================================================================

suppressPackageStartupMessages({
    library(readr)
    library(dplyr)
    library(ggplot2)
    library(gridExtra)
    library(grid)
})

results_csv <- "output/results/ddm_effects_summary_combined_ADT_VDT.csv"
fixef_csv <- "output/results/ddm_per_task_vs_combined_fixef.csv"
fig_dir <- "output/figures/diagnostics"
report_pdf <- "output/results/DDM_PerTask_vs_Combined_Report.pdf"

dir.create(dirname(report_pdf), recursive = TRUE, showWarnings = FALSE)

stopifnot(file.exists(results_csv), file.exists(fixef_csv))

summary_tbl <- readr::read_csv(results_csv, show_col_types = FALSE)
fixef_all <- readr::read_csv(fixef_csv, show_col_types = FALSE)

# Select key terms and prettify labels
nice_term <- function(x) {
  x <- gsub("effort_conditionLow_Force_5pct", "Force: Low vs High", x, fixed = TRUE)
  x <- gsub("difficulty_levelHard", "Difficulty: Hard vs Easy", x, fixed = TRUE)
  x <- gsub("effort_conditionLow_Force_5pct:difficulty_levelHard", "Force × Difficulty", x, fixed = TRUE)
  x <- gsub("effort_arousal_scaled", "Phasic (effort_arousal)", x, fixed = TRUE)
  x <- gsub("tonic_arousal_scaled", "Tonic (baseline)", x, fixed = TRUE)
  x
}

key_models <- c("Model2_Force","Model3_Difficulty","Model4_Additive","Model5_Interaction","Model6_Pupillometry")
key_terms_regex <- "effort_conditionLow_Force_5pct|difficulty_levelHard|effort_conditionLow_Force_5pct:difficulty_levelHard|effort_arousal_scaled|tonic_arousal_scaled"

plot_data <- fixef_all %>%
  filter(model %in% key_models, grepl(key_terms_regex, term)) %>%
  mutate(term_pretty = nice_term(term), dataset = factor(dataset, levels = c("Combined","ADT","VDT")))

# One forest plot per term/model
make_forest <- function(df_term, title) {
  ggplot(df_term, aes(x = dataset, y = estimate)) +
    geom_point(size = 2) +
    geom_errorbar(aes(ymin = l95, ymax = u95), width = 0.1) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    labs(title = title, x = NULL, y = "Estimate (95% CI)") +
    theme_minimal(base_size = 12)
}

# Narrative summary (simple heuristic)
summary_points <- c(
  "Force effect is small and uncertain across datasets (CIs include 0).",
  "Difficulty effect is consistently negative and similar in magnitude across datasets.",
  "Force × Difficulty interaction is near 0; no clear interaction evidence.",
  "Pupillometry: Phasic positive (small); Tonic negative, slightly more negative in VDT, but overlapping CIs."
)

# Build PDF
pdf(report_pdf, width = 8.5, height = 11)
# Title page
grid.newpage()
grid.text("DDM Results: Combined vs ADT vs VDT", y = unit(0.92, "npc"), gp = gpar(fontsize = 18, fontface = "bold"))
sub <- paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M"))
grid.text(sub, y = unit(0.88, "npc"), gp = gpar(fontsize = 10, col = "gray40"))
# Narrative bullets (stacked)
ypos <- seq(0.80, 0.68, length.out = length(summary_points))
for (i in seq_along(summary_points)) {
  grid.text(paste0("• ", summary_points[i]), x = unit(0.06, "npc"), y = unit(ypos[i], "npc"), just = c("left","center"), gp = gpar(fontsize = 12))
}
# Preview table on a new page
grid.newpage()
grid.text("Effect size summary (preview)", y = unit(0.95, "npc"), gp = gpar(fontsize = 14, fontface = "bold"))
prev_tbl <- summary_tbl %>% head(20)
grid.draw(tableGrob(prev_tbl, rows = NULL, theme = ttheme_minimal(base_size = 9)))

# Forest plots pages
split_keys <- plot_data %>% dplyr::group_by(model, term_pretty) %>% dplyr::group_split()
for (df in split_keys) {
  title <- paste0(df$model[1], " – ", df$term_pretty[1])
  p <- make_forest(df, title)
  grid.newpage(); grid.draw(ggplotGrob(p))
}

# Full summary table (chunked across pages)
full_tbl <- summary_tbl
nrows <- nrow(full_tbl)
chunk <- 35
for (i in seq(1, nrows, by = chunk)) {
  grid.newpage()
  grid.text("Effect size summary (95% CI)", y = unit(0.95, "npc"), gp = gpar(fontsize = 14, fontface = "bold"))
  grid.draw(tableGrob(full_tbl[i:min(i+chunk-1, nrows), ], rows = NULL, theme = ttheme_minimal(base_size = 9)))
}

dev.off()

cat(sprintf("Report written to: %s\n", report_pdf))
