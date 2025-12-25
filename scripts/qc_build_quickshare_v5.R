#!/usr/bin/env Rscript

# ============================================================================
# Quick-Share v5: QC + Analysis-Ready Builder
# ============================================================================
# - Starts from quick_share_v4/merged/BAP_triallevel_merged_v2.csv
# - Triage missing behavioral joins
# - Do basic timing QC
# - Prepare small analysis-ready CSVs for Ch2 / Ch3
# NOTE: Pupil features (AUC etc.) are left as TODO hooks to avoid overgrowth.
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(here)
})

cat("=== QUICK-SHARE v5 BUILDER ===\n\n")

REPO_ROOT   <- here::here()
V4_MERGED   <- file.path(REPO_ROOT, "quick_share_v4", "merged", "BAP_triallevel_merged_v2.csv")
V5_ROOT     <- file.path(REPO_ROOT, "quick_share_v5")
V5_MERGED   <- file.path(V5_ROOT, "merged")
V5_QC       <- file.path(V5_ROOT, "qc")
V5_ANALYSIS <- file.path(V5_ROOT, "analysis")

dir.create(V5_ROOT,     recursive = TRUE, showWarnings = FALSE)
dir.create(V5_MERGED,   recursive = TRUE, showWarnings = FALSE)
dir.create(V5_QC,       recursive = TRUE, showWarnings = FALSE)
dir.create(V5_ANALYSIS, recursive = TRUE, showWarnings = FALSE)

# ----------------------------------------------------------------------------
# STEP 0: Confirm inputs
# ----------------------------------------------------------------------------

cat("STEP 0: Checking inputs...\n")

if (!file.exists(V4_MERGED)) {
  stop("Missing merged v2 file: ", V4_MERGED,
       "\nRun scripts/make_merged_quickshare_v4.R first.")
}

cat("  ✓ Found merged v2 file: ", V4_MERGED, "\n", sep = "")

# Behavioral source path (for reference only; not re-used here yet)
CONFIG_FILE <- file.path(REPO_ROOT, "config", "data_paths.yaml")
if (file.exists(CONFIG_FILE)) {
  cat("  ✓ config/data_paths.yaml exists (behavioral_csv defined there)\n")
} else {
  cat("  ⚠ config/data_paths.yaml missing; v4 script was using hard-coded fallback paths\n")
}

# ----------------------------------------------------------------------------
# STEP 1: Sanity check merged v2
# ----------------------------------------------------------------------------

cat("\nSTEP 1: Sanity check merged v2...\n")

merged_v2 <- read_csv(V4_MERGED, show_col_types = FALSE)
n_total   <- nrow(merged_v2)

cat("  Total trials: ", n_total, "\n", sep = "")

if (n_total != 14586L) {
  cat("  ⚠ NOTE: total_trials != 14586 (got ", n_total, ")\n", sep = "")
}

# joined trials
if (!"has_behavioral_data" %in% names(merged_v2)) {
  stop("merged_v2 is missing has_behavioral_data column")
}
n_joined <- sum(merged_v2$has_behavioral_data, na.rm = TRUE)
pct_join <- 100 * n_joined / n_total

cat("  Joined behavioral trials: ", n_joined,
    " (", sprintf("%.1f", pct_join), "%)\n", sep = "")

# Choice encoding
if (!all(c("choice_num", "choice_label") %in% names(merged_v2))) {
  stop("merged_v2 missing choice_num or choice_label; re-run v4 builder")
}

choice_checks <- merged_v2 %>%
  summarise(
    choice_num_range   = paste(sort(unique(choice_num[!is.na(choice_num)])), collapse = ","),
    choice_label_range = paste(sort(unique(choice_label[!is.na(choice_label)])), collapse = ",")
  )

cat("  choice_num unique (non-NA): ", choice_checks$choice_num_range, "\n", sep = "")
cat("  choice_label unique (non-NA): ", choice_checks$choice_label_range, "\n", sep = "")

if (!all(sort(unique(merged_v2$choice_num[!is.na(merged_v2$choice_num)])) %in% c(0, 1))) {
  stop("choice_num contains values outside {0,1}")
}
if (!all(sort(unique(merged_v2$choice_label[!is.na(merged_v2$choice_label)])) %in%
         c("SAME", "DIFFERENT"))) {
  stop("choice_label contains unexpected values")
}

# isOddball derivation vs stimulus_intensity
if (!all(c("isOddball", "stimulus_intensity") %in% names(merged_v2))) {
  stop("merged_v2 missing isOddball or stimulus_intensity")
}

check_isOddball <- merged_v2 %>%
  filter(!is.na(stimulus_intensity)) %>%
  summarise(
    n = n(),
    n_match = sum(isOddball == as.integer(stimulus_intensity != 0), na.rm = TRUE),
    mismatch = n - n_match
  )

cat("  isOddball check (non-NA intensity): n = ", check_isOddball$n,
    ", mismatches = ", check_isOddball$mismatch, "\n", sep = "")

if (check_isOddball$mismatch > 0) {
  stop("isOddball != (stimulus_intensity != 0) for some rows")
}

# correct_final sanity
if (!"correct_final" %in% names(merged_v2)) {
  stop("merged_v2 missing correct_final column")
}

correct_final_vals <- sort(unique(merged_v2$correct_final[merged_v2$has_behavioral_data]))
cat("  correct_final unique (joined trials): ",
    paste(correct_final_vals, collapse = ","), "\n", sep = "")

if (!all(correct_final_vals %in% c(0, 1, NA))) {
  stop("correct_final is not binary/NA for joined trials")
}

cat("  ✓ Sanity checks passed\n")

# ----------------------------------------------------------------------------
# STEP 2: Missing behavioral triage
# ----------------------------------------------------------------------------

cat("\nSTEP 2: Missing behavioral triage...\n")

# A) subject-task summary
join_health <- merged_v2 %>%
  group_by(sub, task) %>%
  summarise(
    n_total     = n(),
    n_joined    = sum(has_behavioral_data, na.rm = TRUE),
    joined_rate = n_joined / n_total,
    n_runs      = n_distinct(run_used),
    sessions    = paste(sort(unique(session_used)), collapse = ";"),
    .groups     = "drop"
  ) %>%
  arrange(task, sub)

write_csv(join_health,
          file.path(V5_QC, "01_join_health_by_subject_task.csv"))
cat("  ✓ 01_join_health_by_subject_task.csv\n")

# Identify 0-join combos
zero_join <- join_health %>% filter(joined_rate == 0)
if (nrow(zero_join) > 0) {
  cat("  ⚠ Subject-task with joined_rate == 0:\n")
  print(zero_join)
} else {
  cat("  ✓ All subject-task combos have at least one joined trial\n")
}

# B) Missing-keys sample
missing_beh <- merged_v2 %>%
  filter(!has_behavioral_data) %>%
  select(sub, task, session_used, run_used, trial_index,
         any_of(c("trial_start_time_ptb", "time_min", "time_max", "target_onset_found")))

n_missing <- nrow(missing_beh)
cat("  Missing behavioral trials: ", n_missing, "\n", sep = "")

# sample ~200 missing rows stratified by task/session/run
missing_sample <- missing_beh %>%
  group_by(task, session_used, run_used) %>%
  slice_head(n = 5) %>%   # up to 5 rows per (task, session, run)
  ungroup()

write_csv(missing_sample,
          file.path(V5_QC, "02_missing_behavioral_sample_keys.csv"))
cat("  ✓ 02_missing_behavioral_sample_keys.csv\n")

# ----------------------------------------------------------------------------
# STEP 3: Timing / target-onset QC (summary only)
# ----------------------------------------------------------------------------

cat("\nSTEP 3: Timing / target-onset QC...\n")

timing_qc <- tibble()

has_target_flag <- "target_onset_found" %in% names(merged_v2)
if (has_target_flag) {
  timing_qc <- merged_v2 %>%
    group_by(task, session_used) %>%
    summarise(
      n_trials = n(),
      n_flag   = sum(target_onset_found, na.rm = TRUE),
      pct_flag = 100 * n_flag / n_trials,
      .groups  = "drop"
    )
  
  write_csv(timing_qc,
            file.path(V5_QC, "03_timing_target_onset_qc.csv"))
  cat("  ✓ 03_timing_target_onset_qc.csv\n")
  
  cat("  target_onset_found by task/session:\n")
  print(timing_qc)
} else {
  cat("  ⚠ merged_v2 has no target_onset_found column; timing QC limited\n")
}

# ----------------------------------------------------------------------------
# STEP 4: Gate pass rates & bias inputs (reuse existing QC columns)
# ----------------------------------------------------------------------------

cat("\nSTEP 4: Gate pass rates & bias inputs...\n")

if (!all(c("baseline_quality", "cog_quality") %in% names(merged_v2))) {
  stop("merged_v2 missing baseline_quality or cog_quality")
}

GATE_THRESHOLDS <- c(0.50, 0.60, 0.70)

gate_rates <- map_dfr(GATE_THRESHOLDS, function(th) {
  merged_v2 %>%
    filter(has_behavioral_data) %>%
    mutate(
      baseline_ok = !is.na(baseline_quality) & baseline_quality >= th,
      cog_ok      = !is.na(cog_quality)      & cog_quality      >= th
    ) %>%
    group_by(task) %>%
    summarise(
      threshold      = th,
      n_trials_total = n(),
      n_trials_pass  = sum(baseline_ok & cog_ok, na.rm = TRUE),
      pass_rate      = n_trials_pass / n_trials_total,
      pass_rate_pct  = 100 * pass_rate,
      .groups        = "drop"
    )
})

write_csv(gate_rates,
          file.path(V5_QC, "04_gate_pass_rates_by_task_threshold.csv"))
cat("  ✓ 04_gate_pass_rates_by_task_threshold.csv\n")

# 05_bias_missingness_logit_inputs.csv
bias_inputs <- merged_v2 %>%
  mutate(
    effort_group = if_else(is.na(effort), "Unknown", effort),
    intensity_bin = case_when(
      is.na(stimulus_intensity) ~ "NA",
      stimulus_intensity == 0   ~ "0",
      stimulus_intensity <= 2   ~ "1-2",
      stimulus_intensity <= 4   ~ "3-4",
      TRUE                      ~ ">4"
    ),
    missing_flag = !has_behavioral_data
  ) %>%
  group_by(task, effort_group, intensity_bin) %>%
  summarise(
    n_total   = n(),
    n_missing = sum(missing_flag),
    n_joined  = n_total - n_missing,
    .groups   = "drop"
  )

write_csv(bias_inputs,
          file.path(V5_QC, "05_bias_missingness_logit_inputs.csv"))
cat("  ✓ 05_bias_missingness_logit_inputs.csv\n")

# ----------------------------------------------------------------------------
# STEP 5: Analysis-ready Ch2 / Ch3 CSVs
# ----------------------------------------------------------------------------

cat("\nSTEP 5: Building analysis-ready tables for Ch2 / Ch3...\n")

# Base filter: joined trials only
base_ready <- merged_v2 %>%
  filter(has_behavioral_data) %>%
  mutate(rt = as.numeric(rt))

# Ch2: keep broad RT range, use QC gates as soft filter
ch2_ready <- base_ready %>%
  mutate(
    gate_primary_060 = !is.na(baseline_quality) & baseline_quality >= 0.60 &
                       !is.na(cog_quality)      & cog_quality      >= 0.60
  )

write_csv(ch2_ready,
          file.path(V5_ANALYSIS, "ch2_analysis_ready.csv"))
cat("  ✓ ch2_analysis_ready.csv\n")

# Ch3: DDM-ready, stricter RT + QC
ch3_ready <- base_ready %>%
  filter(rt >= 0.2, rt <= 3.0) %>%
  mutate(
    gate_primary_050 = !is.na(baseline_quality) & baseline_quality >= 0.50 &
                       !is.na(cog_quality)      & cog_quality      >= 0.50
  )

write_csv(ch3_ready,
          file.path(V5_ANALYSIS, "ch3_ddm_ready.csv"))
cat("  ✓ ch3_ddm_ready.csv\n")

# ----------------------------------------------------------------------------
# STEP 6: Write README for v5
# ----------------------------------------------------------------------------

cat("\nSTEP 6: Writing README_quick_share_v5.md...\n")

readme_path <- file.path(V5_ROOT, "README_quick_share_v5.md")
cat(
  "# Quick-Share v5\n\n",
  "This folder contains analysis-ready trial-level datasets and QC tables\n",
  "built from quick_share_v4/merged/BAP_triallevel_merged_v2.csv.\n\n",
  "Key files:\n\n",
  "- analysis/ch2_analysis_ready.csv\n",
  "- analysis/ch3_ddm_ready.csv\n",
  "- qc/01_join_health_by_subject_task.csv\n",
  "- qc/02_missing_behavioral_sample_keys.csv\n",
  "- qc/03_timing_target_onset_qc.csv (if target_onset_found exists)\n",
  "- qc/04_gate_pass_rates_by_task_threshold.csv\n",
  "- qc/05_bias_missingness_logit_inputs.csv\n\n",
  "For now, v5 focuses on join health, timing QC summaries, and\n",
  "analysis-ready Ch2/Ch3 tables using existing QC metrics.\n",
  file = readme_path
)

cat("  ✓ README_quick_share_v5.md\n")

# ----------------------------------------------------------------------------
# FINAL SUMMARY
# ----------------------------------------------------------------------------

cat("\n=== SUMMARY (v5) ===\n")
cat("Total trials: ", n_total, "\n", sep = "")
cat("Joined behavioral: ", n_joined, " (", sprintf("%.1f", pct_join), "%)\n", sep = "")
cat("Ch2 trials: ", nrow(ch2_ready), "\n", sep = "")
cat("Ch3 trials: ", nrow(ch3_ready), "\n", sep = "")
cat("\nOutputs written under: ", V5_ROOT, "\n", sep = "")

cat("\n=== DONE ===\n")


