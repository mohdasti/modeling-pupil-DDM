# R/extract_manip_checks.R
# Run mixed models: (a) accuracy ~ difficulty*task; (b) median RT ~ difficulty*task
# Export tidy tables

source("R/_helpers_extract.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(lme4)
  library(broom.mixed)
})

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

dd <- safe_read_csv(DATA_PATH) |> ensure_decision()

# Ensure factors are properly set
dd$subject_id <- factor(dd$subject_id)
dd$difficulty_level <- factor(dd$difficulty_level, levels = c("Standard", "Hard", "Easy"))
dd$task <- factor(dd$task)

# Accuracy GLMM (binomial)
cat("Fitting accuracy GLMM (binomial)...\n")
glmm <- glmer(
  decision ~ difficulty_level * task + (1 | subject_id),
  data = dd,
  family = binomial()
)

acc_tab <- broom.mixed::tidy(glmm, conf.int = TRUE, conf.method = "Wald")
write_clean(acc_tab, "output/publish/checks_accuracy_glmm.csv")
cat("✓ Accuracy GLMM complete.\n")

# Median RT per trial grouping; then LMM on per-trial quantile proxy
cat("Computing median RT per subject×task×difficulty...\n")
rt_med <- dd %>%
  group_by(subject_id, task, difficulty_level) %>%
  summarise(rt_med = median(rt, na.rm = TRUE), .groups = "drop")

cat("Fitting RT LMM...\n")
lmm <- lmer(rt_med ~ difficulty_level * task + (1 | subject_id), data = rt_med)

rt_tab <- broom.mixed::tidy(lmm, conf.int = TRUE)
write_clean(rt_tab, "output/publish/checks_rt_lmm.csv")
cat("✓ RT LMM complete.\n")

message("✓ Manipulation checks complete.")
cat("\nGenerated files:\n")
cat("  - output/publish/checks_accuracy_glmm.csv\n")
cat("  - output/publish/checks_rt_lmm.csv\n")


