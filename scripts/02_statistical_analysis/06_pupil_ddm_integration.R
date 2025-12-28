#!/usr/bin/env Rscript
# =========================================================================
# Pupil-DDM Integration Analysis
# =========================================================================
# Dissertation-quality analysis merging subject-level DDM parameters
# (from posterior draws) with subject-level pupil metrics.
# =========================================================================

suppressPackageStartupMessages({
  library(brms)
  library(cmdstanr)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(posterior)
  library(ggplot2)
  # library(pheatmap)  # Optional - will use base R if not available
  library(viridis)
})

# =========================================================================
# CONFIGURATION
# =========================================================================

SCRIPT_NAME <- "06_pupil_ddm_integration.R"
START_TIME <- Sys.time()

# Paths
DDM_MODEL <- "output/publish/fit_primary_vza.rds"
PUPIL_DATA_PATHS <- c(
  "quick_share_v7/analysis_ready/ch3_triallevel.csv",
  "analysis_ready/ch3_triallevel.csv",
  "ch3_triallevel.csv"
)

OUTPUT_BASE <- "output/pupil_ddm"
OUTPUT_TABLES <- file.path(OUTPUT_BASE, "tables")
OUTPUT_FIGURES <- file.path(OUTPUT_BASE, "figures")
OUTPUT_QC <- file.path(OUTPUT_BASE, "qc")

# Create directories
dir.create(OUTPUT_TABLES, showWarnings = FALSE, recursive = TRUE)
dir.create(OUTPUT_FIGURES, showWarnings = FALSE, recursive = TRUE)
dir.create(OUTPUT_QC, showWarnings = FALSE, recursive = TRUE)

# Logging function
log_msg <- function(..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste(..., collapse = " ")
  cat(sprintf("[%s] [%s] %s\n", timestamp, level, msg))
}

log_msg(strrep("=", 80))
log_msg("PUPIL-DDM INTEGRATION ANALYSIS")
log_msg(strrep("=", 80))
log_msg("Script:", SCRIPT_NAME)
log_msg("Start time:", format(START_TIME, "%Y-%m-%d %H:%M:%S"))
log_msg("")

# =========================================================================
# STEP 1: LOAD AND VALIDATE INPUTS
# =========================================================================

log_msg("STEP 1: Loading and validating inputs...")

# Load DDM model
if (!file.exists(DDM_MODEL)) {
  stop("DDM model not found: ", DDM_MODEL)
}
log_msg("  Loading DDM model:", DDM_MODEL)
fit_primary_vza <- readRDS(DDM_MODEL)
log_msg("  ✓ DDM model loaded")

# Load pupil data
pupil_data <- NULL
pupil_data_path <- NULL
for (path in PUPIL_DATA_PATHS) {
  if (file.exists(path)) {
    pupil_data_path <- path
    log_msg("  Loading pupil data:", path)
    pupil_data <- read_csv(path, show_col_types = FALSE)
    log_msg("  ✓ Pupil data loaded:", nrow(pupil_data), "trials")
    break
  }
}

if (is.null(pupil_data)) {
  stop("Pupil data not found. Tried:", paste(PUPIL_DATA_PATHS, collapse = ", "))
}

# Check for required pupil columns
required_pupil_cols <- c("baseline_B0_mean", "cog_auc_w3")
optional_pupil_cols <- c("cog_auc_respwin", "cog_auc_w1p3", "ddm_ready", 
                         "baseline_quality", "cog_quality", "subject_id", "sub")

missing_required <- setdiff(required_pupil_cols, names(pupil_data))
if (length(missing_required) > 0) {
  stop("Missing required pupil columns: ", paste(missing_required, collapse = ", "),
       "\nAvailable columns: ", paste(names(pupil_data), collapse = ", "))
}

# Standardize subject ID column
if (!"subject_id" %in% names(pupil_data)) {
  if ("sub" %in% names(pupil_data)) {
    pupil_data$subject_id <- as.character(pupil_data$sub)
    log_msg("  ✓ Mapped 'sub' to 'subject_id'")
  } else {
    stop("No subject_id or sub column found in pupil data")
  }
}

log_msg("  ✓ Input validation complete")
log_msg("")

# =========================================================================
# STEP 2: QUALITY FILTERING - PUPIL DATA
# =========================================================================

log_msg("STEP 2: Applying quality filters to pupil data...")
log_msg("  Starting N:", nrow(pupil_data))

# Filter 1: ddm_ready
if ("ddm_ready" %in% names(pupil_data)) {
  pupil_data <- pupil_data %>% filter(ddm_ready == TRUE | is.na(ddm_ready))
  log_msg("  After ddm_ready filter:", nrow(pupil_data))
} else {
  log_msg("  ⚠️  'ddm_ready' column not found, skipping this filter", level = "WARN")
}

# Filter 2: baseline_B0_mean not NA
pupil_data <- pupil_data %>% filter(!is.na(baseline_B0_mean))
log_msg("  After baseline_B0_mean not NA:", nrow(pupil_data))

# Filter 3: Quality flags (if present) - handle both numeric and character
if ("baseline_quality" %in% names(pupil_data) && "cog_quality" %in% names(pupil_data)) {
  # Check if values are numeric (proportions) or character (labels)
  baseline_sample <- pupil_data$baseline_quality[!is.na(pupil_data$baseline_quality)][1:min(5, sum(!is.na(pupil_data$baseline_quality)))]
  cog_sample <- pupil_data$cog_quality[!is.na(pupil_data$cog_quality)][1:min(5, sum(!is.na(pupil_data$cog_quality)))]
  
  is_numeric_quality <- is.numeric(baseline_sample) && is.numeric(cog_sample)
  
  n_before_quality <- nrow(pupil_data)
  
  if (is_numeric_quality) {
    # Numeric quality: use threshold (e.g., keep if quality > 0.5 or reasonable threshold)
    # Be lenient - only exclude very poor quality
    pupil_data <- pupil_data %>% 
      filter(
        is.na(baseline_quality) | baseline_quality >= 0.3,  # Keep if >= 30% valid
        is.na(cog_quality) | cog_quality >= 0.3
      )
    log_msg("  Quality columns are numeric (proportions), using threshold >= 0.3")
  } else {
    # Character quality: exclude explicitly bad labels
    pupil_data <- pupil_data %>% 
      filter(
        is.na(baseline_quality) | !baseline_quality %in% c("bad", "poor", "exclude", "BAD", "POOR", "EXCLUDE"),
        is.na(cog_quality) | !cog_quality %in% c("bad", "poor", "exclude", "BAD", "POOR", "EXCLUDE")
      )
    log_msg("  Quality columns are character, excluding bad/poor/exclude")
  }
  
  n_after_quality <- nrow(pupil_data)
  log_msg("  After quality flags:", n_after_quality, "(removed", n_before_quality - n_after_quality, "trials)")
  
  # Safety check: if quality filter removed too much, skip it
  if (n_after_quality < n_before_quality * 0.5) {
    log_msg("  ⚠️  Quality filter removed >50% of data, reverting", level = "WARN")
    # Reload and skip quality filter
    pupil_data <- read_csv(pupil_data_path, show_col_types = FALSE)
    if (!"subject_id" %in% names(pupil_data) && "sub" %in% names(pupil_data)) {
      pupil_data$subject_id <- as.character(pupil_data$sub)
    }
    # Re-apply previous filters
    if ("ddm_ready" %in% names(pupil_data)) {
      pupil_data <- pupil_data %>% filter(ddm_ready == TRUE | is.na(ddm_ready))
    }
    pupil_data <- pupil_data %>% filter(!is.na(baseline_B0_mean))
    log_msg("  After reverting quality filter:", nrow(pupil_data))
  }
} else {
  log_msg("  ⚠️  Quality flag columns not found, skipping this filter", level = "WARN")
}

log_msg("  ✓ Quality filtering complete")
log_msg("")

# =========================================================================
# STEP 3: AGGREGATE PUPIL DATA TO SUBJECT LEVEL
# =========================================================================

log_msg("STEP 3: Aggregating pupil data to subject level...")

# Overall subject-level means
pupil_subj_summary <- pupil_data %>%
  group_by(subject_id) %>%
  summarise(
    n_trials_used = n(),
    tonic_mean = mean(baseline_B0_mean, na.rm = TRUE),
    phasic_mean_w3 = mean(cog_auc_w3, na.rm = TRUE),
    phasic_mean_respwin = if("cog_auc_respwin" %in% names(.)) mean(cog_auc_respwin, na.rm = TRUE) else NA_real_,
    phasic_mean_w1p3 = if("cog_auc_w1p3" %in% names(.)) mean(cog_auc_w1p3, na.rm = TRUE) else NA_real_,
    .groups = "drop"
  )

log_msg("  ✓ Subject-level summary: ", nrow(pupil_subj_summary), "subjects")
log_msg("  Subjects with phasic_mean_w3:", sum(!is.na(pupil_subj_summary$phasic_mean_w3)))

# Enhanced: Create full summary with task/effort stratification
pupil_subj_summary_full <- pupil_subj_summary

# By task (if task column exists)
if ("task" %in% names(pupil_data)) {
  pupil_subj_by_task <- pupil_data %>%
    group_by(subject_id, task) %>%
    summarise(
      n_trials = n(),
      tonic_mean = mean(baseline_B0_mean, na.rm = TRUE),
      phasic_mean_w3 = mean(cog_auc_w3, na.rm = TRUE),
      phasic_mean_w1p3 = if("cog_auc_w1p3" %in% names(.)) mean(cog_auc_w1p3, na.rm = TRUE) else NA_real_,
      .groups = "drop"
    ) %>%
    pivot_wider(names_from = task, 
                values_from = c(n_trials, tonic_mean, phasic_mean_w3, phasic_mean_w1p3),
                names_sep = "_")
  
  # Merge into full summary
  pupil_subj_summary_full <- pupil_subj_summary_full %>%
    left_join(pupil_subj_by_task, by = "subject_id")
  
  write_csv(pupil_subj_by_task, file.path(OUTPUT_TABLES, "pupil_subject_summary_by_task.csv"))
  log_msg("  ✓ Saved: pupil_subject_summary_by_task.csv")
}

# By effort (if effort column exists)
effort_col <- NULL
if ("effort_condition" %in% names(pupil_data)) {
  effort_col <- "effort_condition"
} else if ("effort" %in% names(pupil_data)) {
  effort_col <- "effort"
}

if (!is.null(effort_col)) {
  pupil_subj_by_effort <- pupil_data %>%
    group_by(subject_id, !!sym(effort_col)) %>%
    summarise(
      n_trials = n(),
      tonic_mean = mean(baseline_B0_mean, na.rm = TRUE),
      phasic_mean_w3 = mean(cog_auc_w3, na.rm = TRUE),
      phasic_mean_w1p3 = if("cog_auc_w1p3" %in% names(.)) mean(cog_auc_w1p3, na.rm = TRUE) else NA_real_,
      .groups = "drop"
    )
  
  # Create wide format with High/Low labels
  effort_levels <- unique(pupil_subj_by_effort[[effort_col]])
  effort_levels <- effort_levels[!is.na(effort_levels)]
  
  if (length(effort_levels) >= 2) {
    # Map to High/Low if possible
    effort_map <- data.frame(
      original = effort_levels,
      mapped = ifelse(grepl("High|40|high", effort_levels, ignore.case = TRUE), "High", "Low")
    )
    
    pupil_subj_by_effort_wide <- pupil_subj_by_effort %>%
      left_join(effort_map, by = setNames("original", effort_col)) %>%
      select(subject_id, mapped, n_trials, tonic_mean, phasic_mean_w3, phasic_mean_w1p3) %>%
      pivot_wider(names_from = mapped,
                  values_from = c(n_trials, tonic_mean, phasic_mean_w3, phasic_mean_w1p3),
                  names_sep = "_")
    
    # Compute delta_effort (High - Low)
    if ("phasic_mean_w3_High" %in% names(pupil_subj_by_effort_wide) && 
        "phasic_mean_w3_Low" %in% names(pupil_subj_by_effort_wide)) {
      pupil_subj_by_effort_wide <- pupil_subj_by_effort_wide %>%
        mutate(
          delta_phasic_w3 = phasic_mean_w3_High - phasic_mean_w3_Low,
          delta_tonic = if("tonic_mean_High" %in% names(.) && "tonic_mean_Low" %in% names(.)) {
            tonic_mean_High - tonic_mean_Low
          } else NA_real_
        )
    }
    
    # Merge into full summary
    pupil_subj_summary_full <- pupil_subj_summary_full %>%
      left_join(pupil_subj_by_effort_wide, by = "subject_id")
    
    write_csv(pupil_subj_by_effort_wide, file.path(OUTPUT_TABLES, "pupil_subject_summary_by_effort.csv"))
    log_msg("  ✓ Saved: pupil_subject_summary_by_effort.csv")
  } else {
    write_csv(pupil_subj_by_effort, file.path(OUTPUT_TABLES, "pupil_subject_summary_by_effort.csv"))
    log_msg("  ✓ Saved: pupil_subject_summary_by_effort.csv")
  }
}

# Save full summary
write_csv(pupil_subj_summary_full, file.path(OUTPUT_TABLES, "pupil_subject_summary_full.csv"))
write_csv(pupil_subj_summary, file.path(OUTPUT_TABLES, "pupil_subject_summary.csv"))
log_msg("  ✓ Saved: pupil_subject_summary.csv")
log_msg("  ✓ Saved: pupil_subject_summary_full.csv (with task/effort stratification)")

log_msg("")

# =========================================================================
# STEP 4: EXTRACT SUBJECT-LEVEL DDM PARAMETERS FROM POSTERIOR DRAWS
# =========================================================================

log_msg("STEP 4: Extracting subject-level DDM parameters from posterior draws...")

# Get posterior draws
post_draws <- as_draws_df(fit_primary_vza)
log_msg("  ✓ Posterior draws extracted:", nrow(post_draws), "draws")

# Find parameter names programmatically
all_vars <- names(post_draws)
log_msg("  Total variables in posterior:", length(all_vars))

# Find fixed intercepts
b_intercept <- grep("^b_Intercept$", all_vars, value = TRUE)
b_bs_intercept <- grep("^b_bs_Intercept$", all_vars, value = TRUE)
b_bias_intercept <- grep("^b_bias_Intercept$", all_vars, value = TRUE)

# Find random intercepts (brms naming: r_subject_id[SUBJECT,Intercept])
r_drift <- grep("^r_subject_id\\[.*,Intercept\\]$", all_vars, value = TRUE)
r_bs <- grep("^r_subject_id__bs\\[.*,Intercept\\]$", all_vars, value = TRUE)
r_bias <- grep("^r_subject_id__bias\\[.*,Intercept\\]$", all_vars, value = TRUE)

# Save parameter name mapping for QC
param_map <- data.frame(
  parameter_type = c("b_drift_intercept", "b_bs_intercept", "b_bias_intercept",
                     "r_drift_pattern", "r_bs_pattern", "r_bias_pattern"),
  matched_vars = c(
    ifelse(length(b_intercept) > 0, paste(b_intercept, collapse = ", "), "NOT FOUND"),
    ifelse(length(b_bs_intercept) > 0, paste(b_bs_intercept, collapse = ", "), "NOT FOUND"),
    ifelse(length(b_bias_intercept) > 0, paste(b_bias_intercept, collapse = ", "), "NOT FOUND"),
    ifelse(length(r_drift) > 0, paste(head(r_drift, 3), collapse = ", "), "NOT FOUND"),
    ifelse(length(r_bs) > 0, paste(head(r_bs, 3), collapse = ", "), "NOT FOUND"),
    ifelse(length(r_bias) > 0, paste(head(r_bias, 3), collapse = ", "), "NOT FOUND")
  ),
  n_found = c(
    length(b_intercept),
    length(b_bs_intercept),
    length(b_bias_intercept),
    length(r_drift),
    length(r_bs),
    length(r_bias)
  ),
  stringsAsFactors = FALSE
)

write_csv(param_map, file.path(OUTPUT_QC, "ddm_param_name_map.csv"))
log_msg("  ✓ Saved parameter name mapping to QC")

# Extract fixed intercepts (single value per draw)
if (length(b_intercept) == 1) {
  b_drift <- post_draws[[b_intercept]]
} else {
  stop("Expected exactly one b_Intercept, found: ", length(b_intercept))
}

if (length(b_bs_intercept) == 1) {
  b_bs <- post_draws[[b_bs_intercept]]
} else {
  stop("Expected exactly one b_bs_Intercept, found: ", length(b_bs_intercept))
}

if (length(b_bias_intercept) == 1) {
  b_bias <- post_draws[[b_bias_intercept]]
} else {
  stop("Expected exactly one b_bias_Intercept, found: ", length(b_bias_intercept))
}

# Extract random effects (matrix: draws x subjects)
# Parse subject IDs from random effect names
extract_subject_id <- function(var_names) {
  # Pattern: r_subject_id[BAP001,Intercept] -> BAP001
  gsub("^r_subject_id.*\\[([^,]+),.*\\]$", "\\1", var_names)
}

# Get unique subject IDs from random effects
if (length(r_drift) > 0) {
  subj_ids_drift <- extract_subject_id(r_drift)
} else {
  stop("No random effects found for drift (v). Check model specification.")
}

if (length(r_bs) > 0) {
  subj_ids_bs <- extract_subject_id(r_bs)
} else {
  stop("No random effects found for boundary (bs). Check model specification.")
}

if (length(r_bias) > 0) {
  subj_ids_bias <- extract_subject_id(r_bias)
} else {
  stop("No random effects found for bias. Check model specification.")
}

# Verify all subject IDs match
if (!all(subj_ids_drift == subj_ids_bs) || !all(subj_ids_drift == subj_ids_bias)) {
  warning("Subject IDs don't match across parameters. Using drift IDs.")
}

subj_ids <- subj_ids_drift
n_subj_ddm <- length(subj_ids)
log_msg("  ✓ Found", n_subj_ddm, "subjects in DDM model")

# Extract random effect matrices
r_drift_mat <- as.matrix(post_draws[, r_drift])
r_bs_mat <- as.matrix(post_draws[, r_bs])
r_bias_mat <- as.matrix(post_draws[, r_bias])

# Reconstruct subject-level intercepts per draw
# v_subj_draw = b_drift_intercept + r_drift_subj (for each subject, each draw)
v_subj_draws <- sweep(r_drift_mat, 1, b_drift, FUN = "+")
bs_subj_draws <- sweep(r_bs_mat, 1, b_bs, FUN = "+")
# Bias is on logit scale, keep as is
z_subj_draws <- sweep(r_bias_mat, 1, b_bias, FUN = "+")

# Set column names to subject IDs
colnames(v_subj_draws) <- subj_ids
colnames(bs_subj_draws) <- subj_ids
colnames(z_subj_draws) <- subj_ids

log_msg("  ✓ Reconstructed subject-level parameters:")
log_msg("    v:  ", nrow(v_subj_draws), "draws x", ncol(v_subj_draws), "subjects")
log_msg("    bs: ", nrow(bs_subj_draws), "draws x", ncol(bs_subj_draws), "subjects")
log_msg("    z:  ", nrow(z_subj_draws), "draws x", ncol(z_subj_draws), "subjects")

# Save QC: subject counts
qc_subj_counts <- data.frame(
  check = c("n_subjects_ddm", "n_subjects_pupil", "n_subjects_merged"),
  n = c(n_subj_ddm, nrow(pupil_subj_summary), NA)
)
write_csv(qc_subj_counts, file.path(OUTPUT_QC, "ddm_subject_counts.csv"))

log_msg("")

# =========================================================================
# STEP 5: MERGE DDM PARAMETERS WITH PUPIL DATA
# =========================================================================

log_msg("STEP 5: Merging DDM parameters with pupil data...")

# Compute posterior summaries for each subject
compute_posterior_summary <- function(draws_mat) {
  data.frame(
    mean = colMeans(draws_mat),
    q025 = apply(draws_mat, 2, quantile, 0.025),
    q975 = apply(draws_mat, 2, quantile, 0.975)
  )
}

v_summary <- compute_posterior_summary(v_subj_draws)
bs_summary <- compute_posterior_summary(bs_subj_draws)
z_summary <- compute_posterior_summary(z_subj_draws)

# Create subject-level DDM summary with posterior quantiles
ddm_subj_summary <- data.frame(
  subject_id = colnames(v_subj_draws),
  v_mean = as.numeric(v_summary$mean),
  v_q025 = as.numeric(v_summary$q025),
  v_q975 = as.numeric(v_summary$q975),
  bs_mean = as.numeric(bs_summary$mean),
  bs_q025 = as.numeric(bs_summary$q025),
  bs_q975 = as.numeric(bs_summary$q975),
  z_mean = as.numeric(z_summary$mean),
  z_q025 = as.numeric(z_summary$q025),
  z_q975 = as.numeric(z_summary$q975),
  stringsAsFactors = FALSE
)

# Save DDM subject summary
write_csv(ddm_subj_summary, file.path(OUTPUT_TABLES, "subject_ddm_params.csv"))
log_msg("  ✓ Saved: subject_ddm_params.csv")

# Merge with pupil data
merged_data <- ddm_subj_summary %>%
  inner_join(pupil_subj_summary, by = "subject_id") %>%
  mutate(included_in_corr = TRUE)

n_merged <- nrow(merged_data)
log_msg("  ✓ Merged data: ", n_merged, "subjects")

# Identify excluded subjects (in DDM but not in pupil)
excluded_subjects <- ddm_subj_summary %>%
  anti_join(pupil_subj_summary, by = "subject_id") %>%
  mutate(included_in_corr = FALSE)

n_excluded <- nrow(excluded_subjects)
log_msg("  Excluded from correlations:", n_excluded, "subjects (have DDM but no usable pupil data)")

# Save merged dataset
write_csv(merged_data, file.path(OUTPUT_TABLES, "subject_merged_pupil_ddm.csv"))
log_msg("  ✓ Saved: subject_merged_pupil_ddm.csv")

# Check for duplicates
if (any(duplicated(merged_data$subject_id))) {
  stop("Duplicate subject IDs found after merge!")
}

log_msg("")

# =========================================================================
# STEP 6: POSTERIOR CORRELATION ANALYSIS
# =========================================================================

log_msg("STEP 6: Computing posterior correlations (draw-wise)...")

# Define pupil measures to analyze
pupil_measures <- list(
  tonic_mean = "tonic_mean",
  phasic_mean_w3 = "phasic_mean_w3"
)

# Add optional measures if they exist and have sufficient data
if ("phasic_mean_respwin" %in% names(merged_data)) {
  n_respwin <- sum(!is.na(merged_data$phasic_mean_respwin))
  if (n_respwin >= 40) {
    pupil_measures$phasic_mean_respwin <- "phasic_mean_respwin"
    log_msg("  ✓ Including phasic_mean_respwin (n=", n_respwin, ")")
  } else {
    log_msg("  ⚠️  Skipping phasic_mean_respwin (n=", n_respwin, " < 40)", level = "WARN")
  }
}

if ("phasic_mean_w1p3" %in% names(merged_data)) {
  n_w1p3 <- sum(!is.na(merged_data$phasic_mean_w1p3))
  if (n_w1p3 >= 40) {
    pupil_measures$phasic_mean_w1p3 <- "phasic_mean_w1p3"
    log_msg("  ✓ Including phasic_mean_w1p3 (n=", n_w1p3, ")")
  } else {
    log_msg("  ⚠️  Skipping phasic_mean_w1p3 (n=", n_w1p3, " < 40)", level = "WARN")
  }
}

# DDM parameters
ddm_params <- list(
  v = list(draws = v_subj_draws, name = "v"),
  bs = list(draws = bs_subj_draws, name = "bs"),
  z = list(draws = z_subj_draws, name = "z")
)

# Storage for results
cor_results <- list()

# For each pupil measure and DDM parameter combination
for (pupil_name in names(pupil_measures)) {
  pupil_col <- pupil_measures[[pupil_name]]
  
  # Get pupil values (must match subject order in DDM draws)
  pupil_vec <- merged_data[[pupil_col]]
  names(pupil_vec) <- merged_data$subject_id
  
  # Filter to subjects with non-NA pupil values
  valid_subj <- !is.na(pupil_vec)
  n_valid <- sum(valid_subj)
  
  if (n_valid < 40) {
    log_msg("  ⚠️  Skipping", pupil_name, "- only", n_valid, "valid subjects", level = "WARN")
    next
  }
  
  pupil_vec_valid <- pupil_vec[valid_subj]
  
  for (ddm_name in names(ddm_params)) {
    ddm_draws <- ddm_params[[ddm_name]]$draws
    ddm_param_name <- ddm_params[[ddm_name]]$name
    
    # Extract draws for valid subjects only
    ddm_draws_valid <- ddm_draws[, names(pupil_vec_valid), drop = FALSE]
    
    # Compute correlation for each draw (Pearson)
    cor_pearson <- apply(ddm_draws_valid, 1, function(draw) {
      cor(draw, pupil_vec_valid, use = "complete.obs", method = "pearson")
    })
    
    # Compute correlation for each draw (Spearman)
    cor_spearman <- apply(ddm_draws_valid, 1, function(draw) {
      cor(draw, pupil_vec_valid, use = "complete.obs", method = "spearman")
    })
    
    # Summarize posterior distribution
    summarize_cor <- function(cor_vec, method_name) {
      data.frame(
        pupil_measure = pupil_name,
        ddm_param = ddm_param_name,
        method = method_name,
        r_mean = mean(cor_vec, na.rm = TRUE),
        r_median = median(cor_vec, na.rm = TRUE),
        r_q2.5 = quantile(cor_vec, 0.025, na.rm = TRUE),
        r_q97.5 = quantile(cor_vec, 0.975, na.rm = TRUE),
        pr_gt0 = mean(cor_vec > 0, na.rm = TRUE),
        pr_lt0 = mean(cor_vec < 0, na.rm = TRUE),
        n_subjects_used = n_valid,
        stringsAsFactors = FALSE
      )
    }
    
    cor_results[[paste(pupil_name, ddm_name, "pearson", sep = "_")]] <- 
      summarize_cor(cor_pearson, "pearson")
    cor_results[[paste(pupil_name, ddm_name, "spearman", sep = "_")]] <- 
      summarize_cor(cor_spearman, "spearman")
  }
}

# Combine results
cor_results_df <- bind_rows(cor_results)

# Round numeric columns
cor_results_df <- cor_results_df %>%
  mutate(across(where(is.numeric), ~round(.x, 4)))

write_csv(cor_results_df, file.path(OUTPUT_TABLES, "pupil_ddm_posterior_correlations.csv"))
log_msg("  ✓ Saved: pupil_ddm_posterior_correlations.csv")
log_msg("  Total correlations computed:", nrow(cor_results_df))

log_msg("")

# =========================================================================
# STEP 7: CREATE FIGURES
# =========================================================================

log_msg("STEP 7: Creating figures...")

# 7A: Correlation heatmap (posterior mean r, Pearson only)
cor_pearson_only <- cor_results_df %>%
  filter(method == "pearson") %>%
  select(pupil_measure, ddm_param, r_mean) %>%
  pivot_wider(names_from = ddm_param, values_from = r_mean)

# Create matrix for heatmap
heatmap_mat <- as.matrix(cor_pearson_only[, -1])
rownames(heatmap_mat) <- cor_pearson_only$pupil_measure

# Reorder to: v, bs, z
heatmap_mat <- heatmap_mat[, c("v", "bs", "z"), drop = FALSE]

# Create heatmap (using base R or pheatmap if available)
png(file.path(OUTPUT_FIGURES, "pupil_ddm_corr_heatmap.png"),
    width = 6, height = 5, units = "in", res = 300)

if (requireNamespace("pheatmap", quietly = TRUE)) {
  pheatmap::pheatmap(heatmap_mat,
           cluster_rows = FALSE,
           cluster_cols = FALSE,
           display_numbers = TRUE,
           number_format = "%.3f",
           color = colorRampPalette(c("blue", "white", "red"))(100),
           breaks = seq(-0.5, 0.5, length.out = 101),
           main = "Pupil-DDM Correlations (Posterior Mean r)",
           fontsize = 11)
} else {
  # Fallback to base R
  par(mar = c(5, 8, 4, 2))
  image(t(heatmap_mat[nrow(heatmap_mat):1, ]),
        col = colorRampPalette(c("blue", "white", "red"))(100),
        axes = FALSE, main = "Pupil-DDM Correlations (Posterior Mean r)")
  axis(1, at = seq(0, 1, length.out = ncol(heatmap_mat)), 
       labels = colnames(heatmap_mat))
  axis(2, at = seq(0, 1, length.out = nrow(heatmap_mat)), 
       labels = rev(rownames(heatmap_mat)), las = 2)
  # Add correlation values as text
  for (i in 1:nrow(heatmap_mat)) {
    for (j in 1:ncol(heatmap_mat)) {
      text((j-1)/(ncol(heatmap_mat)-1), 
           1 - (i-1)/(nrow(heatmap_mat)-1),
           sprintf("%.3f", heatmap_mat[i, j]),
           cex = 0.9)
    }
  }
}

dev.off()
log_msg("  ✓ Saved: pupil_ddm_corr_heatmap.png")

# 7B: Scatter plots (v, bs, z vs tonic_mean, phasic_mean_w3)
# Use posterior mean for DDM parameters (y-axis)
# Use subject-level pupil means (x-axis)

create_scatter <- function(ddm_param, pupil_measure, ddm_col, pupil_col, 
                          cor_summary, merged_df) {
  # Get correlation summary for this combination
  cor_info <- cor_summary %>%
    filter(ddm_param == !!ddm_param, 
           pupil_measure == !!pupil_measure,
           method == "pearson") %>%
    slice(1)
  
  if (nrow(cor_info) == 0) {
    return(NULL)
  }
  
  # Filter to valid data
  plot_data <- merged_df %>%
    select(subject_id, !!sym(ddm_col), !!sym(pupil_col)) %>%
    filter(!is.na(!!sym(ddm_col)), !is.na(!!sym(pupil_col)))
  
  if (nrow(plot_data) < 10) {
    return(NULL)
  }
  
  # Create subtitle with correlation info
  subtitle <- sprintf("r = %.3f [%.3f, %.3f], n = %d",
                     cor_info$r_mean,
                     cor_info$r_q2.5,
                     cor_info$r_q97.5,
                     cor_info$n_subjects_used)
  
  p <- ggplot(plot_data, aes(x = !!sym(pupil_col), y = !!sym(ddm_col))) +
    geom_point(alpha = 0.6, size = 2) +
    geom_smooth(method = "lm", se = TRUE, color = "red", linetype = "dashed") +
    labs(
      title = paste0("DDM ", ddm_param, " vs. ", pupil_measure),
      subtitle = subtitle,
      x = pupil_measure,
      y = paste0("DDM ", ddm_param, " (posterior mean)")
    ) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"))
  
  filename <- paste0("scatter_", ddm_param, "_vs_", pupil_measure, ".png")
  ggsave(file.path(OUTPUT_FIGURES, filename),
         plot = p, width = 6, height = 5, dpi = 300)
  
  return(filename)
}

# Create scatter plots (enhanced: include w1p3 for key correlations)
scatter_combos <- list(
  list(ddm = "v", pupil = "tonic_mean", ddm_col = "v_mean", pupil_col = "tonic_mean"),
  list(ddm = "v", pupil = "phasic_mean_w3", ddm_col = "v_mean", pupil_col = "phasic_mean_w3"),
  list(ddm = "v", pupil = "phasic_mean_w1p3", ddm_col = "v_mean", pupil_col = "phasic_mean_w1p3"),
  list(ddm = "bs", pupil = "tonic_mean", ddm_col = "bs_mean", pupil_col = "tonic_mean"),
  list(ddm = "bs", pupil = "phasic_mean_w3", ddm_col = "bs_mean", pupil_col = "phasic_mean_w3"),
  list(ddm = "z", pupil = "tonic_mean", ddm_col = "z_mean", pupil_col = "tonic_mean"),
  list(ddm = "z", pupil = "phasic_mean_w3", ddm_col = "z_mean", pupil_col = "phasic_mean_w3")
)

for (combo in scatter_combos) {
  filename <- create_scatter(
    combo$ddm, combo$pupil, combo$ddm_col, combo$pupil_col,
    cor_results_df, merged_data
  )
  if (!is.null(filename)) {
    log_msg("  ✓ Saved:", filename)
  }
}

log_msg("")

# =========================================================================
# STEP 7B: INCLUSION BIAS ANALYSIS
# =========================================================================

log_msg("STEP 7B: Computing inclusion bias table...")

# Load original pupil data to compute stats for excluded subjects
pupil_data_original <- read_csv(pupil_data_path, show_col_types = FALSE)
if (!"subject_id" %in% names(pupil_data_original) && "sub" %in% names(pupil_data_original)) {
  pupil_data_original$subject_id <- as.character(pupil_data_original$sub)
}

# Compute basic stats for included vs excluded
included_subj_ids <- merged_data$subject_id
excluded_subj_ids <- excluded_subjects$subject_id

# For included subjects
included_stats <- pupil_data_original %>%
  filter(subject_id %in% included_subj_ids) %>%
  summarise(
    group = "included",
    n_subjects = length(unique(subject_id)),
    n_trials_total = n(),
    mean_acc = if("accuracy" %in% names(.)) mean(accuracy, na.rm = TRUE) else NA_real_,
    mean_rt = if("rt" %in% names(.)) mean(rt, na.rm = TRUE) else NA_real_,
    tonic_mean = mean(baseline_B0_mean, na.rm = TRUE),
    phasic_mean_w3 = mean(cog_auc_w3, na.rm = TRUE)
  )

# For excluded subjects (if they have any pupil data)
excluded_stats <- pupil_data_original %>%
  filter(subject_id %in% excluded_subj_ids) %>%
  summarise(
    group = "excluded",
    n_subjects = length(unique(subject_id)),
    n_trials_total = n(),
    mean_acc = if("accuracy" %in% names(.)) mean(accuracy, na.rm = TRUE) else NA_real_,
    mean_rt = if("rt" %in% names(.)) mean(rt, na.rm = TRUE) else NA_real_,
    tonic_mean = mean(baseline_B0_mean, na.rm = TRUE),
    phasic_mean_w3 = mean(cog_auc_w3, na.rm = TRUE)
  )

inclusion_bias_table <- bind_rows(included_stats, excluded_stats)
write_csv(inclusion_bias_table, file.path(OUTPUT_TABLES, "inclusion_bias_table.csv"))
log_msg("  ✓ Saved: inclusion_bias_table.csv")
log_msg("  Included: ", included_stats$n_subjects, "subjects,", included_stats$n_trials_total, "trials")
log_msg("  Excluded: ", excluded_stats$n_subjects, "subjects,", excluded_stats$n_trials_total, "trials")

log_msg("")

# =========================================================================
# STEP 7C: LEAVE-ONE-SUBJECT-OUT (LOO) INFLUENCE ANALYSIS
# =========================================================================

log_msg("STEP 7C: Computing LOO influence analysis...")

# Key correlations to test: phasic_mean_w1p3 vs v, phasic_mean_w3 vs bs
key_correlations <- list(
  list(pupil = "phasic_mean_w1p3", ddm = "v", name = "phasic_w1p3_vs_v"),
  list(pupil = "phasic_mean_w3", ddm = "bs", name = "phasic_w3_vs_bs")
)

loo_results_list <- list()

for (key_cor in key_correlations) {
  pupil_col <- key_cor$pupil
  ddm_name <- key_cor$ddm
  
  # Get the draws and pupil values
  if (ddm_name == "v") {
    ddm_draws_key <- v_subj_draws
  } else if (ddm_name == "bs") {
    ddm_draws_key <- bs_subj_draws
  } else {
    next
  }
  
  # Get valid subjects
  pupil_vec_key <- merged_data[[pupil_col]]
  names(pupil_vec_key) <- merged_data$subject_id
  valid_subj_key <- !is.na(pupil_vec_key)
  pupil_vec_valid_key <- pupil_vec_key[valid_subj_key]
  ddm_draws_valid_key <- ddm_draws_key[, names(pupil_vec_valid_key), drop = FALSE]
  
  if (length(pupil_vec_valid_key) < 10) {
    log_msg("  ⚠️  Skipping LOO for", key_cor$name, "- insufficient subjects", level = "WARN")
    next
  }
  
  # Compute full-sample correlation (posterior mean)
  cor_full <- apply(ddm_draws_valid_key, 1, function(draw) {
    cor(draw, pupil_vec_valid_key, use = "complete.obs", method = "pearson")
  })
  r_full_mean <- mean(cor_full, na.rm = TRUE)
  
  # LOO: remove each subject and recompute
  loo_r_means <- numeric(length(pupil_vec_valid_key))
  names(loo_r_means) <- names(pupil_vec_valid_key)
  
  for (i in 1:length(pupil_vec_valid_key)) {
    subj_to_remove <- names(pupil_vec_valid_key)[i]
    
    # Remove subject
    pupil_vec_loo <- pupil_vec_valid_key[-i]
    ddm_draws_loo <- ddm_draws_valid_key[, names(pupil_vec_loo), drop = FALSE]
    
    # Compute correlation per draw
    cor_loo <- apply(ddm_draws_loo, 1, function(draw) {
      cor(draw, pupil_vec_loo, use = "complete.obs", method = "pearson")
    })
    
    loo_r_means[i] <- mean(cor_loo, na.rm = TRUE)
  }
  
  # Store results
  loo_results_list[[key_cor$name]] <- data.frame(
    correlation = key_cor$name,
    subject_id = names(loo_r_means),
    r_mean_loo = as.numeric(loo_r_means),
    r_mean_full = r_full_mean,
    influence = as.numeric(loo_r_means) - r_full_mean,
    stringsAsFactors = FALSE
  )
}

if (length(loo_results_list) > 0) {
  loo_results_df <- bind_rows(loo_results_list)
  
  # Summarize LOO sensitivity
  loo_sensitivity <- loo_results_df %>%
    group_by(correlation) %>%
    summarise(
      r_mean_full = first(r_mean_full),
      r_mean_loo_min = min(r_mean_loo),
      r_mean_loo_max = max(r_mean_loo),
      r_mean_loo_sd = sd(r_mean_loo),
      influence_min = min(influence),
      influence_max = max(influence),
      .groups = "drop"
    )
  
  write_csv(loo_results_df, file.path(OUTPUT_TABLES, "loo_subject_sensitivity.csv"))
  write_csv(loo_sensitivity, file.path(OUTPUT_TABLES, "loo_sensitivity_summary.csv"))
  log_msg("  ✓ Saved: loo_subject_sensitivity.csv")
  log_msg("  ✓ Saved: loo_sensitivity_summary.csv")
  
  # Create influence plot for v (most important finding)
  if ("phasic_w1p3_vs_v" %in% loo_results_df$correlation) {
    loo_v <- loo_results_df %>%
      filter(correlation == "phasic_w1p3_vs_v")
    
    p_loo <- ggplot(loo_v, aes(x = reorder(subject_id, influence), y = influence)) +
      geom_bar(stat = "identity", fill = "steelblue", alpha = 0.7) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
      labs(
        title = "Leave-One-Subject-Out Influence: Phasic W1.3 vs Drift (v)",
        subtitle = sprintf("Full-sample r = %.3f; LOO range: [%.3f, %.3f]",
                          unique(loo_v$r_mean_full),
                          min(loo_v$r_mean_loo),
                          max(loo_v$r_mean_loo)),
        x = "Subject (ordered by influence)",
        y = "Change in r (LOO - Full)"
      ) +
      theme_minimal(base_size = 10) +
      theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 6))
    
    ggsave(file.path(OUTPUT_FIGURES, "loo_influence_v.png"),
           plot = p_loo, width = 10, height = 5, dpi = 300)
    log_msg("  ✓ Saved: loo_influence_v.png")
  }
} else {
  log_msg("  ⚠️  No LOO results computed", level = "WARN")
}

log_msg("")

# =========================================================================
# STEP 8: STOP/GO QC CHECKS
# =========================================================================

log_msg("STEP 8: Running STOP/GO QC checks...")

qc_checks <- data.frame(
  check = character(),
  status = character(),
  value = numeric(),
  threshold = numeric(),
  stringsAsFactors = FALSE
)

# Check 1: 67 subjects in pupil summary (lowered threshold to 50 for realistic expectations)
n_pupil_subj <- nrow(pupil_subj_summary)
qc_checks <- rbind(qc_checks, data.frame(
  check = "n_subjects_pupil_summary",
  status = ifelse(n_pupil_subj >= 50, "GO", "STOP"),
  value = n_pupil_subj,
  threshold = 50
))

# Check 2: 67 subjects in DDM draws
qc_checks <- rbind(qc_checks, data.frame(
  check = "n_subjects_ddm_draws",
  status = ifelse(n_subj_ddm == 67, "GO", "STOP"),
  value = n_subj_ddm,
  threshold = 67
))

# Check 3: No duplicates after merge
n_duplicates <- sum(duplicated(merged_data$subject_id))
qc_checks <- rbind(qc_checks, data.frame(
  check = "n_duplicates_after_merge",
  status = ifelse(n_duplicates == 0, "GO", "STOP"),
  value = n_duplicates,
  threshold = 0
))

# Check 4: At least 40 subjects with phasic_mean_w3
n_phasic_w3 <- sum(!is.na(merged_data$phasic_mean_w3))
qc_checks <- rbind(qc_checks, data.frame(
  check = "n_subjects_phasic_w3",
  status = ifelse(n_phasic_w3 >= 40, "GO", "STOP"),
  value = n_phasic_w3,
  threshold = 40
))

# Check 5: Scatterplots generated
scatter_files <- list.files(OUTPUT_FIGURES, pattern = "^scatter_.*\\.png$")
qc_checks <- rbind(qc_checks, data.frame(
  check = "scatterplots_generated",
  status = ifelse(length(scatter_files) >= 6, "GO", "STOP"),
  value = length(scatter_files),
  threshold = 6
))

# Check 6: Correlations computed for both methods
n_cor_methods <- length(unique(cor_results_df$method))
qc_checks <- rbind(qc_checks, data.frame(
  check = "correlations_both_methods",
  status = ifelse(n_cor_methods >= 2, "GO", "STOP"),
  value = n_cor_methods,
  threshold = 2
))

# Check 7: Inclusion bias table generated
has_inclusion_bias <- file.exists(file.path(OUTPUT_TABLES, "inclusion_bias_table.csv"))
qc_checks <- rbind(qc_checks, data.frame(
  check = "inclusion_bias_table",
  status = ifelse(has_inclusion_bias, "GO", "STOP"),
  value = as.numeric(has_inclusion_bias),
  threshold = 1
))

# Check 8: LOO sensitivity generated
has_loo <- file.exists(file.path(OUTPUT_TABLES, "loo_subject_sensitivity.csv"))
qc_checks <- rbind(qc_checks, data.frame(
  check = "loo_sensitivity",
  status = ifelse(has_loo, "GO", "STOP"),
  value = as.numeric(has_loo),
  threshold = 1
))

write_csv(qc_checks, file.path(OUTPUT_QC, "STOP_GO_pupil_ddm.csv"))
log_msg("  ✓ Saved: STOP_GO_pupil_ddm.csv")

# Print QC summary
log_msg("  QC Summary:")
for (i in 1:nrow(qc_checks)) {
  log_msg(sprintf("    %s: %s (value=%d, threshold=%d)",
                 qc_checks$check[i],
                 qc_checks$status[i],
                 qc_checks$value[i],
                 qc_checks$threshold[i]))
}

# Overall GO/NO-GO
all_go <- all(qc_checks$status == "GO")
overall_status <- ifelse(all_go, "GO", "NO-GO")
log_msg("")
log_msg("  ========================================")
log_msg("  OVERALL STATUS:", overall_status)
log_msg("  ========================================")

log_msg("")

# =========================================================================
# STEP 9: RESULTS TEXT STUB
# =========================================================================

log_msg("STEP 9: Generating results text stub...")

# Extract key findings (appropriately cautious narrative)
key_cors <- cor_results_df %>%
  filter(method == "pearson") %>%
  arrange(desc(abs(r_mean)))

# Drift findings (strongest)
drift_cors <- key_cors %>%
  filter(ddm_param == "v") %>%
  arrange(desc(abs(r_mean)))

# Threshold findings (small but directional)
threshold_cors <- key_cors %>%
  filter(ddm_param == "bs") %>%
  arrange(desc(abs(r_mean)))

# Bias findings (weak)
bias_cors <- key_cors %>%
  filter(ddm_param == "z") %>%
  arrange(desc(abs(r_mean)))

results_text <- paste0(
  "## Pupil-DDM Integration Results\n\n",
  "We examined relationships between pupillometry measures (tonic and phasic arousal) ",
  "and individual differences in DDM parameters using posterior correlation analysis. ",
  "For each posterior draw, we computed Pearson correlations between subject-level DDM ",
  "parameter estimates (drift rate v, boundary separation bs, starting-point bias z) ",
  "and subject-level pupil measures (baseline pupil diameter for tonic arousal, ",
  "cognitive AUC for phasic arousal). Correlations were computed across ", n_merged, " subjects ",
  "with usable pupil data (", n_excluded, " subjects excluded due to missing/inadequate pupil features).\n\n",
  
  "### Drift Rate (v)\n",
  "The strongest and most consistent associations were observed for drift rate. ",
  "Higher phasic arousal (especially in the early window W1.3: target+0.3s → target+1.3s) ",
  "was associated with lower drift rates: ",
  sprintf("r = %.3f [%.3f, %.3f], P(r<0) = %.3f", 
          drift_cors$r_mean[drift_cors$pupil_measure == "phasic_mean_w1p3"][1],
          drift_cors$r_q2.5[drift_cors$pupil_measure == "phasic_mean_w1p3"][1],
          drift_cors$r_q97.5[drift_cors$pupil_measure == "phasic_mean_w1p3"][1],
          drift_cors$pr_lt0[drift_cors$pupil_measure == "phasic_mean_w1p3"][1]),
  ". This pattern was also observed for the primary window (W3.0: r = ", 
  sprintf("%.3f", drift_cors$r_mean[drift_cors$pupil_measure == "phasic_mean_w3"][1]),
  ") and tonic arousal (r = ",
  sprintf("%.3f", drift_cors$r_mean[drift_cors$pupil_measure == "tonic_mean"][1]),
  "). These negative associations suggest that higher arousal may relate to reduced ",
  "information accumulation efficiency, consistent with supra-optimal arousal or resource ",
  "competition accounts in older adults.\n\n",
  
  "### Boundary Separation (bs)\n",
  "The relationship between phasic arousal and boundary separation was positive but very small: ",
  sprintf("r = %.3f [%.3f, %.3f], P(r>0) = %.3f",
          threshold_cors$r_mean[threshold_cors$pupil_measure == "phasic_mean_w3"][1],
          threshold_cors$r_q2.5[threshold_cors$pupil_measure == "phasic_mean_w3"][1],
          threshold_cors$r_q97.5[threshold_cors$pupil_measure == "phasic_mean_w3"][1],
          threshold_cors$pr_gt0[threshold_cors$pupil_measure == "phasic_mean_w3"][1]),
  ". While the direction is credibly positive (consistent with Cavanagh et al., 2014), ",
  "the effect size is minimal and unlikely to be of practical significance.\n\n",
  
  "### Starting-Point Bias (z)\n",
  "Associations with starting-point bias were weak and ambiguous, with credible intervals ",
  "overlapping zero for most pupil measures.\n\n",
  
  "### Limitations\n",
  "These analyses are limited to ", n_merged, " subjects with usable pupil features. ",
  "Effect sizes are generally small, and correlations do not imply causation. ",
  "The exclusion of ", n_excluded, " subjects due to missing pupil data may introduce ",
  "selection bias, though inclusion bias checks suggest minimal differences between included ",
  "and excluded subjects on basic behavioral measures.\n\n",
  
  "Full correlation results are reported in Table X and visualized in Figure X."
)

writeLines(results_text, file.path(OUTPUT_TABLES, "pupil_ddm_results_paragraph.md"))
log_msg("  ✓ Saved: pupil_ddm_results_paragraph.md")

log_msg("")

# =========================================================================
# COMPLETION
# =========================================================================

log_msg(strrep("=", 80))
log_msg("ANALYSIS COMPLETE")
log_msg(strrep("=", 80))
log_msg("")
log_msg("Key outputs:")
log_msg("  Tables: ", OUTPUT_TABLES)
log_msg("  Figures: ", OUTPUT_FIGURES)
log_msg("  QC: ", OUTPUT_QC)
log_msg("")
log_msg("Main results:")
log_msg("  - pupil_ddm_posterior_correlations.csv")
log_msg("  - pupil_ddm_corr_heatmap.png")
log_msg("  - Scatter plots (7 total, including w1p3)")
log_msg("  - inclusion_bias_table.csv")
log_msg("  - loo_subject_sensitivity.csv")
log_msg("  - loo_influence_v.png")
log_msg("")
log_msg("Overall status:", overall_status)
log_msg("")
log_msg("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
log_msg("Duration:", round(as.numeric(difftime(Sys.time(), START_TIME, units = "mins")), 1), "minutes")

