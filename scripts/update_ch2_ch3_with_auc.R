#!/usr/bin/env Rscript
# ============================================================================
# Update Ch2/Ch3 Analysis-Ready Datasets with AUC Features
# ============================================================================
# Updates analysis-ready CSVs with AUC features and generates waveform summaries
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(tidyr)
  library(here)
  library(ggplot2)
})

cat("=== UPDATING Ch2/Ch3 ANALYSIS-READY DATASETS ===\n\n")

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

REPO_ROOT <- here::here()
V5_ROOT <- file.path(REPO_ROOT, "quick_share_v5")
V5_ANALYSIS <- file.path(V5_ROOT, "analysis")
V5_FIGURES <- file.path(V5_ROOT, "figures")
V5_MERGED <- file.path(V5_ROOT, "merged", "BAP_triallevel_merged_v3.csv")

dir.create(V5_ANALYSIS, recursive = TRUE, showWarnings = FALSE)
dir.create(V5_FIGURES, recursive = TRUE, showWarnings = FALSE)

cat("Repo root: ", REPO_ROOT, "\n", sep = "")
cat("Output dir: ", V5_ROOT, "\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 1: Load merged v3 with AUC features
# ----------------------------------------------------------------------------

cat("STEP 1: Loading merged v3 dataset...\n")

if (!file.exists(V5_MERGED)) {
  stop("Merged v3 file not found: ", V5_MERGED,
       "\nPlease run scripts/compute_auc_features_from_flats.R first.")
}

merged_v3 <- read_csv(V5_MERGED, show_col_types = FALSE)
cat("  ✓ Loaded ", nrow(merged_v3), " trials\n", sep = "")

# Check AUC coverage
n_with_auc <- sum(!is.na(merged_v3$total_auc), na.rm = TRUE)
cat("  AUC coverage: ", n_with_auc, " / ", nrow(merged_v3), 
    " (", sprintf("%.1f", 100 * n_with_auc / nrow(merged_v3)), "%)\n\n", sep = "")

# ----------------------------------------------------------------------------
# STEP 2: Build Chapter 2 analysis-ready dataset
# ----------------------------------------------------------------------------

cat("STEP 2: Building Ch2 analysis-ready dataset...\n")

ch2_ready <- merged_v3 %>%
  filter(has_behavioral_data) %>%
  mutate(
    # Primary gate at 0.60 (recompute if not present, or use existing)
    gate_primary_060 = if ("pass_primary_060" %in% names(.)) {
      pass_primary_060
    } else {
      !is.na(baseline_quality) & baseline_quality >= 0.60 &
      !is.na(cog_quality) & cog_quality >= 0.60
    },
    # Additional AUC quality gate: require >=10 baseline samples (if AUC computed)
    auc_quality_ok = if_else(
      is.na(n_valid_b0) | is.na(n_valid_target_base),
      TRUE,  # If AUC not computed, don't fail on this check
      n_valid_b0 >= 10L & n_valid_target_base >= 10L
    ),
    # Combined quality flag
    ch2_quality_pass = gate_primary_060 & auc_quality_ok
  ) %>%
  select(
    # Identifiers
    any_of(c("trial_uid", "sub", "task", "session_used", "run_used", "trial_index")),
    # Behavioral
    any_of(c("effort", "stimulus_intensity", "isOddball", "choice_num", "choice_label", "rt", "correct_final")),
    # Pupil features
    any_of(c("total_auc", "cog_auc_fixed1s", "cog_mean_fixed1s")),
    # QC metrics
    any_of(c("baseline_quality", "cog_quality", "overall_quality",
             "pct_non_nan_baseline", "pct_non_nan_cogwin", "pct_non_nan_overall",
             "n_valid_b0", "n_valid_target_base", "n_valid_total_window", "n_valid_cog_window")),
    # Quality gates (use pass_primary_* if available, otherwise gate_primary_*)
    any_of(c("pass_primary_050", "pass_primary_060", "pass_primary_070",
             "gate_primary_050", "gate_primary_060", "gate_primary_070")),
    auc_quality_ok, ch2_quality_pass
  )

write_csv(ch2_ready, file.path(V5_ANALYSIS, "ch2_analysis_ready.csv"))
cat("  ✓ Saved: analysis/ch2_analysis_ready.csv\n")
cat("  Trials: ", nrow(ch2_ready), "\n")
cat("  With AUC: ", sum(!is.na(ch2_ready$total_auc)), "\n")
cat("  Quality pass: ", sum(ch2_ready$ch2_quality_pass, na.rm = TRUE), "\n\n")

# ----------------------------------------------------------------------------
# STEP 3: Build Chapter 3 (DDM) analysis-ready dataset
# ----------------------------------------------------------------------------

cat("STEP 3: Building Ch3 (DDM) analysis-ready dataset...\n")

ch3_ready <- merged_v3 %>%
  filter(
    has_behavioral_data,
    # RT range for DDM
    rt >= 0.2, rt <= 3.0,
    # Basic quality gate at 0.50
    !is.na(baseline_quality) & baseline_quality >= 0.50,
    !is.na(cog_quality) & cog_quality >= 0.50
  ) %>%
  mutate(
    # Primary gate at 0.50 (use existing if available)
    gate_primary_050 = if ("pass_primary_050" %in% names(.)) {
      pass_primary_050
    } else {
      !is.na(baseline_quality) & baseline_quality >= 0.50 &
      !is.na(cog_quality) & cog_quality >= 0.50
    },
    # AUC quality check (if AUC computed)
    auc_quality_ok = if_else(
      is.na(n_valid_b0) | is.na(n_valid_target_base),
      TRUE,  # If AUC not computed, don't fail on this check
      n_valid_b0 >= 10L & n_valid_target_base >= 10L
    ),
    # DDM-ready flag
    ch3_ddm_ready = gate_primary_050 & auc_quality_ok
  ) %>%
  select(
    # Identifiers
    any_of(c("trial_uid", "sub", "task", "session_used", "run_used", "trial_index")),
    # Behavioral (DDM inputs)
    any_of(c("effort", "stimulus_intensity", "isOddball", "choice_num", "rt", "correct_final")),
    # Pupil features (250 Hz derived)
    any_of(c("total_auc", "cog_auc_fixed1s", "cog_mean_fixed1s")),
    # QC
    any_of(c("baseline_quality", "cog_quality", "n_valid_b0", "n_valid_target_base")),
    any_of(c("pass_primary_050", "gate_primary_050")),
    auc_quality_ok, ch3_ddm_ready
  )

write_csv(ch3_ready, file.path(V5_ANALYSIS, "ch3_ddm_ready.csv"))
cat("  ✓ Saved: analysis/ch3_ddm_ready.csv\n")
cat("  Trials: ", nrow(ch3_ready), "\n")
cat("  With AUC: ", sum(!is.na(ch3_ready$total_auc)), "\n")
cat("  DDM-ready: ", sum(ch3_ready$ch3_ddm_ready, na.rm = TRUE), "\n\n")

# ----------------------------------------------------------------------------
# STEP 4: Generate waveform summaries (50 Hz downsampled)
# ----------------------------------------------------------------------------

cat("STEP 4: Generating waveform summaries...\n")
cat("  (This requires reading flat files; may take time)\n\n")

# This is a placeholder - full implementation would:
# 1. Read flat files
# 2. Downsample to 50 Hz
# 3. Compute condition means
# 4. Save summary CSV

# For now, create a minimal summary structure
waveform_summary <- ch2_ready %>%
  filter(!is.na(total_auc), ch2_quality_pass) %>%
  group_by(task, effort) %>%
  summarise(
    n_trials = n(),
    mean_total_auc = mean(total_auc, na.rm = TRUE),
    se_total_auc = sd(total_auc, na.rm = TRUE) / sqrt(n()),
    mean_cog_auc = mean(cog_auc_fixed1s, na.rm = TRUE),
    se_cog_auc = sd(cog_auc_fixed1s, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# Note: Full waveform summary would require reading sample-level data
# and computing time-series means. This is a placeholder structure.
cat("  ⚠ Full waveform summary requires sample-level data processing\n")
cat("  ✓ Created summary structure\n\n")

# ----------------------------------------------------------------------------
# STEP 5: Create plots
# ----------------------------------------------------------------------------

cat("STEP 5: Creating plots...\n")

# Plot 1: AUC distributions by task and effort
if (nrow(ch2_ready) > 0 && sum(!is.na(ch2_ready$total_auc)) > 0) {
  p_auc_dist <- ch2_ready %>%
    filter(!is.na(total_auc)) %>%
    ggplot(aes(x = total_auc, fill = task)) +
    geom_histogram(alpha = 0.7, bins = 50) +
    facet_wrap(~ effort, scales = "free_y") +
    labs(x = "Total AUC (baseline-corrected)", y = "Count", fill = "Task") +
    theme_minimal()
  
  ggsave(file.path(V5_FIGURES, "auc_distributions.png"), 
         p_auc_dist, width = 10, height = 6, dpi = 100)
  cat("  ✓ Saved: figures/auc_distributions.png\n")
}

# Plot 2: Gate pass rates overview
if (nrow(merged_v3) > 0) {
  # Get gate columns (prefer pass_primary_*, fallback to gate_primary_*)
  gate_050_col <- if ("pass_primary_050" %in% names(merged_v3)) "pass_primary_050" else "gate_primary_050"
  gate_060_col <- if ("pass_primary_060" %in% names(merged_v3)) "pass_primary_060" else "gate_primary_060"
  gate_070_col <- if ("pass_primary_070" %in% names(merged_v3)) "pass_primary_070" else "gate_primary_070"
  
  gate_summary <- merged_v3 %>%
    filter(has_behavioral_data) %>%
    mutate(
      gate_050 = if (gate_050_col %in% names(.)) .data[[gate_050_col]] else NA,
      gate_060 = if (gate_060_col %in% names(.)) .data[[gate_060_col]] else NA,
      gate_070 = if (gate_070_col %in% names(.)) .data[[gate_070_col]] else NA
    ) %>%
    group_by(task) %>%
    summarise(
      n_total = n(),
      pass_050 = sum(gate_050, na.rm = TRUE),
      pass_060 = sum(gate_060, na.rm = TRUE),
      pass_070 = sum(gate_070, na.rm = TRUE),
      with_auc = sum(!is.na(total_auc), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      pct_pass_050 = 100 * pass_050 / n_total,
      pct_pass_060 = 100 * pass_060 / n_total,
      pct_pass_070 = 100 * pass_070 / n_total,
      pct_with_auc = 100 * with_auc / n_total
    )
  
  p_gates <- gate_summary %>%
    select(task, pct_pass_050, pct_pass_060, pct_pass_070, pct_with_auc) %>%
    pivot_longer(cols = starts_with("pct_"), names_to = "gate", values_to = "pct") %>%
    ggplot(aes(x = gate, y = pct, fill = task)) +
    geom_col(position = "dodge") +
    labs(x = "Gate/Threshold", y = "Pass Rate (%)", fill = "Task") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(file.path(V5_FIGURES, "gate_pass_rates_overview.png"), 
         p_gates, width = 8, height = 5, dpi = 100)
  cat("  ✓ Saved: figures/gate_pass_rates_overview.png\n")
}

cat("\n=== Ch2/Ch3 UPDATE COMPLETE ===\n")

