# R/extract_manip_checks.R
# Run mixed models: (a) accuracy ~ difficulty; (b) median RT ~ difficulty
# IMPORTANT: Restricted to Easy vs Hard only (excluding Standard trials)
# Standard trials are "same" trials (Δ=0), while Easy/Hard are "different" trials
# The difficulty manipulation is only meaningful within "different" trials
#
# MODEL SPECIFICATION JUSTIFICATION:
# For a manipulation check, the core question is: "Does the difficulty manipulation work?"
# This question is answered by testing Easy vs Hard (pooled across tasks).
# We do NOT include task because:
# 1. The manipulation check should validate the manipulation works overall
# 2. Task differences are secondary to the core manipulation question
# 3. Pooling across tasks maximizes power for the primary question
# 4. If we wanted to test generalization, we would run separate models per task
#    OR include task as a factor (but that's beyond a pure manipulation check)
#
# If you want to test if manipulation works across tasks, options are:
# - Separate models: decision ~ difficulty + (1|subject) per task
# - With task control: decision ~ difficulty + task + (1|subject)
# - With interaction: decision ~ difficulty * task + (1|subject) [tests generalization]

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

# Filter to Easy and Hard only (exclude Standard)
# Standard trials are "same" trials (Δ=0), conceptually different from Easy/Hard "different" trials
cat("Filtering to Easy and Hard trials only (excluding Standard)...\n")
dd_manip <- dd %>%
  filter(difficulty_level %in% c("Easy", "Hard"))

cat(sprintf("  - Total trials: %d\n", nrow(dd)))
cat(sprintf("  - Easy + Hard trials: %d\n", nrow(dd_manip)))
cat(sprintf("  - Standard trials excluded: %d\n", nrow(dd) - nrow(dd_manip)))

# Ensure factors are properly set
# Easy as reference level (higher accuracy expected)
dd_manip$subject_id <- factor(dd_manip$subject_id)
dd_manip$difficulty_level <- factor(dd_manip$difficulty_level, levels = c("Easy", "Hard"))
dd_manip$task <- factor(dd_manip$task)

# Accuracy GLMM (binomial)
# Model: difficulty + effort (both manipulations validated)
# For manipulation check, we test if BOTH experimental manipulations work:
# 1. Difficulty: Does Easy differ from Hard?
# 2. Effort: Does Low differ from High?
# We include both to validate both manipulations while controlling for each other.
cat("\nFitting accuracy GLMM (binomial): decision ~ difficulty_level + effort_condition + (1 | subject_id)...\n")
cat("  Reference levels: Easy, Low_5_MVC\n")
cat("  Questions: (1) Does Easy differ from Hard? (2) Does Low effort differ from High effort?\n")
dd_manip$effort_condition <- factor(dd_manip$effort_condition, levels = c("Low_5_MVC", "High_MVC"))
glmm <- glmer(
  decision ~ difficulty_level + effort_condition + (1 | subject_id),
  data = dd_manip,
  family = binomial()
)

acc_tab <- broom.mixed::tidy(glmm, conf.int = TRUE, conf.method = "Wald")
write_clean(acc_tab, "output/publish/checks_accuracy_glmm.csv")
cat("✓ Accuracy GLMM complete.\n")

# Median RT per trial grouping; then LMM on per-trial quantile proxy
cat("\nComputing median RT per subject×task×difficulty×effort...\n")
rt_med <- dd_manip %>%
  group_by(subject_id, task, difficulty_level, effort_condition) %>%
  summarise(rt_med = median(rt, na.rm = TRUE), .groups = "drop")

cat("Fitting RT LMM: rt_med ~ difficulty_level + effort_condition + (1 | subject_id)...\n")
cat("  Reference levels: Easy, Low_5_MVC\n")
cat("  Questions: (1) Does Easy differ from Hard in RT? (2) Does Low effort differ from High effort in RT?\n")
rt_med$effort_condition <- factor(rt_med$effort_condition, levels = c("Low_5_MVC", "High_MVC"))
lmm <- lmer(rt_med ~ difficulty_level + effort_condition + (1 | subject_id), data = rt_med)

rt_tab <- broom.mixed::tidy(lmm, conf.int = TRUE)
write_clean(rt_tab, "output/publish/checks_rt_lmm.csv")
cat("✓ RT LMM complete.\n")

# Summary statistics for verification
cat("\n=== Summary Statistics ===\n")
cat("\nAccuracy by Difficulty:\n")
dd_manip %>%
  group_by(difficulty_level) %>%
  summarise(
    n_trials = n(),
    accuracy = mean(decision, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

cat("\nMedian RT by Difficulty:\n")
dd_manip %>%
  group_by(difficulty_level) %>%
  summarise(
    n_trials = n(),
    median_rt = median(rt, na.rm = TRUE),
    mean_rt = mean(rt, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

cat("\nAccuracy by Effort:\n")
dd_manip %>%
  group_by(effort_condition) %>%
  summarise(
    n_trials = n(),
    accuracy = mean(decision, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

cat("\nMedian RT by Effort:\n")
dd_manip %>%
  group_by(effort_condition) %>%
  summarise(
    n_trials = n(),
    median_rt = median(rt, na.rm = TRUE),
    mean_rt = mean(rt, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

message("✓ Manipulation checks complete (Easy vs Hard only).")
cat("\nGenerated files:\n")
cat("  - output/publish/checks_accuracy_glmm.csv\n")
cat("  - output/publish/checks_rt_lmm.csv\n")


