suppressPackageStartupMessages({library(tidyverse)})
dir.create("output/figures", recursive=TRUE, showWarnings=FALSE)

# Try multiple possible locations
loo_file <- if (file.exists("output/modelcomp/loo_difficulty_all.csv")) {
  "output/modelcomp/loo_difficulty_all.csv"
} else if (file.exists("output/publish/loo_difficulty_all.csv")) {
  "output/publish/loo_difficulty_all.csv"
} else {
  stop("LOO file not found. Checked: output/modelcomp/ and output/publish/")
}

loo <- read_csv(loo_file, show_col_types=FALSE)

# Calculate delta ELPD if not present
if (!"elpd_diff_from_best" %in% names(loo)) {
  loo <- loo |> mutate(elpd_diff_from_best = elpd - max(elpd))
}

# Get best model
best_elpd <- max(loo$elpd)
best_model <- loo |> filter(elpd == best_elpd) |> pull(model)

# Prepare data for plotting
loo_plot <- loo |>
  mutate(
    delta = elpd_diff_from_best,
    model_label = if_else(
      !is.na(weight_stack) & !is.na(weight_pbma),
      paste0(model, "\n(stack=", round(weight_stack, 3), ", PBMA=", round(weight_pbma, 3), ")"),
      model
    )
  ) |>
  arrange(elpd)

plt <- loo_plot |>
  ggplot(aes(x=reorder(model, elpd), y=elpd)) +
  geom_point(size=2.5) +
  geom_errorbar(aes(ymin=elpd - 1.96*se, ymax=elpd + 1.96*se), width=.15, linewidth=0.8) +
  geom_hline(yintercept=best_elpd, linetype="dashed", color="red", alpha=0.6) +
  # Annotate delta ELPD - position just above the data point
  geom_text(aes(y=elpd + 30, label=paste0("diff=", round(delta, 1))), 
            hjust=0.5, vjust=-0.55 , size=3, color="gray40") +
  coord_flip() + 
  labs(
    x=NULL, 
    y="ELPD (higher is better)",
    title="Model Comparison: Leave-One-Out Cross-Validation",
    subtitle=paste0("Best model: ", best_model, " (ELPD diff = 0)")
  ) +
  theme_minimal(base_size=11) +
  theme(
    plot.title = element_text(size=12, face="bold"),
    plot.subtitle = element_text(size=10, color="gray50")
  )

ggsave("output/figures/fig_loo.pdf", plt, width=7, height=4.5)

 