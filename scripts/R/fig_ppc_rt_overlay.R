suppressPackageStartupMessages({library(tidyverse); library(brms); library(here)})
source(here::here("R", "colors_manuscript.R"))
source(here::here("R", "fig_save_utils.R"))

# Load model and data
model_file <- if (file.exists("output/publish/fit_primary_vza.rds")) {
  "output/publish/fit_primary_vza.rds"
} else if (file.exists("output/publish/fit_primary_vza_vEff_censored.rds")) {
  "output/publish/fit_primary_vza_vEff_censored.rds"
} else {
  stop("Model file not found. Checked: output/publish/fit_primary_vza*.rds")
}

data_candidates <- c(
  "data/ddm_ready_data_unthresholded.csv",
  "data/analysis_ready/bap_ddm_ready.csv"
)
data_file <- data_candidates[file.exists(data_candidates)][1]
if (is.na(data_file)) stop("No behavioral data file found for PPC overlay.")

fit <- readRDS(model_file)
dd <- read_csv(data_file, show_col_types = FALSE)

# Prepare data
dd <- dd |>
  mutate(
    task = case_when(
      task %in% c("ADT", "aud") ~ "ADT",
      task %in% c("VDT", "vis") ~ "VDT",
      TRUE ~ as.character(task)
    ) |> factor(levels = c("ADT", "VDT")),
    effort_condition = case_when(
      effort_condition %in% c("High", "High_MVC", "High_40_MVC") ~ "High",
      effort_condition %in% c("Low", "Low_5_MVC") ~ "Low",
      TRUE ~ as.character(effort_condition)
    ) |> factor(levels = c("Low", "High")),
    difficulty_level = factor(difficulty_level, levels = c("Standard", "Easy", "Hard")),
    rt = dplyr::coalesce(rt, rt_probe_onset_locked)
  ) |>
  filter(!is.na(rt), rt > 0)

# Prepare empirical RTs
empirical_rts <- dd |>
  select(task, effort_condition, difficulty_level, rt) |>
  mutate(type = "Empirical")

pred_data <- NULL
if (requireNamespace("RWiener", quietly = TRUE)) {
  cat("Generating posterior predictive samples...\n")
  pp_samples <- tryCatch(
    brms::posterior_predict(fit, ndraws = 100),
    error = function(e) {
      message("posterior_predict failed: ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(pp_samples)) {
    cat("Generated", nrow(pp_samples), "draws ×", ncol(pp_samples), "trials\n")
    n_draws <- min(50, nrow(pp_samples))
    pred_rts <- as.vector(pp_samples[seq_len(n_draws), ])
    pred_data <- dd |>
      select(task, effort_condition, difficulty_level) |>
      slice(rep(seq_len(n()), n_draws)) |>
      mutate(rt = pred_rts, type = "Predictive")
  }
} else {
  message("RWiener not installed; fig_ppc_rt_overlay will show empirical RTs only.")
}

# Combine empirical and predictive (if available)
ppc <- bind_rows(empirical_rts, pred_data) |>
  mutate(type = factor(type, levels = c("Empirical", "Predictive"))) |>
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
    values=c("Empirical"=unname(stat_colors["empirical"]), "Predictive"=unname(stat_colors["predicted"])),
    labels=c("Empirical"="Observed", "Predictive"="Predicted")
  ) +
  facet_grid(task_effort ~ difficulty_level, scales="free_y") +
  labs(
    x="RT (s)", 
    y="Density", 
    color=NULL,
    title="Posterior Predictive Check: RT Distributions",
    subtitle=if (any(ppc$type == "Predictive")) {
      "Observed vs Predicted Densities by Task × Effort × Difficulty"
    } else {
      "Observed RT densities only (install RWiener for predictive overlay)"
    }
  ) +
  theme_minimal(base_size=11) +
  theme(
    legend.position="top",
    plot.title = element_text(size=12, face="bold", hjust=0.5),
    plot.subtitle = element_text(size=10, color="gray50", hjust=0.5),
    strip.text = element_text(face="bold")
  )

save_manuscript_fig(plt, "fig_ppc_rt_overlay", 9, 6.5)

