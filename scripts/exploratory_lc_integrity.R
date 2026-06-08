#!/usr/bin/env Rscript
# =========================================================================
# Exploratory LC Integrity Analyses
# =========================================================================
# Exploratory association and moderation analyses examining relationships
# between LC structural integrity metrics and:
# (i) subject-level pupil indices
# (ii) subject-level DDM parameters and effort-related shifts
# =========================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(dplyr)
  library(stringr)
  library(ggplot2)
  library(broom)
})

# =========================================================================
# HELPER FUNCTIONS
# =========================================================================

first_existing <- function(paths) {
  # Return the first path that exists, or NULL if none exist
  for (path in paths) {
    if (file.exists(path)) {
      return(path)
    }
  }
  return(NULL)
}

normalize_subject_id <- function(id) {
  # Normalize subject ID to BAP%03d format (vectorized)
  id <- as.character(id)
  
  # Remove any "BAP" prefix if present
  id_clean <- str_replace(id, "^BAP", "")
  # Extract numeric part
  num_match <- str_extract(id_clean, "\\d+")
  
  # Use ifelse for vectorized conditional logic
  result <- ifelse(
    !is.na(num_match),
    sprintf("BAP%03d", as.integer(num_match)),
    ifelse(
      str_detect(id, "^BAP\\d{3}$"),
      id,  # Already in correct format
      id   # Return original if can't parse
    )
  )
  
  return(result)
}

# =========================================================================
# CONFIGURATION
# =========================================================================

SCRIPT_NAME <- "exploratory_lc_integrity.R"
START_TIME <- Sys.time()

# Output directories
OUTPUT_BASE <- "output/lc_integrity"
OUTPUT_FIGURES <- "output/figures"
dir.create(OUTPUT_BASE, showWarnings = FALSE, recursive = TRUE)
dir.create(OUTPUT_FIGURES, showWarnings = FALSE, recursive = TRUE)

# =========================================================================
# STEP 1: LOCATE INPUT FILES
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 1: Locating input files...\n")
cat(strrep("=", 80), "\n\n")

# (A) LC CSV file
lc_paths <- c(
  "data/raw/bap_beh_subjxtaskdata_v2.csv",
  "data/LC_Grant_Updated_LC_values.2026.csv",
  "LC_Grant_Updated_LC_values.2026.csv",
  file.path(getwd(), "data", "LC_Grant_Updated_LC_values.2026.csv"),
  file.path(getwd(), "LC_Grant_Updated_LC_values.2026.csv")
)

lc_file <- first_existing(lc_paths)
if (is.null(lc_file)) {
  stop("LC CSV file not found. Checked paths:\n  ", 
       paste(lc_paths, collapse = "\n  "))
}
cat("✓ Found LC file:", lc_file, "\n")

# (B) Subject-level pupil summary
pupil_paths <- c(
  "output/pupil_ddm/tables/pupil_subject_summary.csv",
  "output/pupil_ddm/tables/subject_merged_pupil_ddm.csv",
  "output/tables/pupil_subject_summary.csv",
  "output/tables/subject_merged_pupil_ddm.csv",
  "pupil_subject_summary.csv"
)

pupil_file <- first_existing(pupil_paths)
if (is.null(pupil_file)) {
  stop("Subject-level pupil summary not found. Checked paths:\n  ",
       paste(pupil_paths, collapse = "\n  "))
}
cat("✓ Found pupil summary:", pupil_file, "\n")

# (C) Subject-level DDM parameters (or merged pupil+DDM)
ddm_paths <- c(
  "output/pupil_ddm/tables/subject_merged_pupil_ddm.csv",  # Prefer merged if exists
  "output/pupil_ddm/tables/subject_ddm_params.csv",
  "output/tables/subject_merged_pupil_ddm.csv",
  "output/tables/subject_ddm_params.csv",
  "subject_ddm_params.csv"
)

ddm_file <- first_existing(ddm_paths)
if (is.null(ddm_file)) {
  stop("Subject-level DDM parameters not found. Checked paths:\n  ",
       paste(ddm_paths, collapse = "\n  "))
}
cat("✓ Found DDM parameters:", ddm_file, "\n")

# Check if we have a merged file (preferred)
has_merged <- any(str_detect(ddm_file, "merged"))
if (has_merged) {
  cat("  → Using merged pupil+DDM file (preferred)\n")
  chapter3_file <- ddm_file
} else {
  # Need to merge pupil and DDM
  chapter3_file <- NULL
  cat("  → Will merge pupil and DDM files\n")
}

# =========================================================================
# STEP 2: LOAD AND PREPARE DATA
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 2: Loading and preparing data...\n")
cat(strrep("=", 80), "\n\n")

# Load LC data
lc_data <- read_csv(lc_file, show_col_types = FALSE)
cat("✓ Loaded LC data:", nrow(lc_data), "rows\n")

# Filter to BAP participants only
lc_bap <- lc_data %>%
  filter(str_detect(`Subject ID`, "^BAP", negate = FALSE)) %>%
  mutate(
    subject_id_raw = `Subject ID`,
    subject_id_norm = normalize_subject_id(`Subject ID`)
  )
cat("✓ BAP participants:", nrow(lc_bap), "rows\n")

# Load Chapter 3 subject-level data
if (!is.null(chapter3_file)) {
  chapter3_data <- read_csv(chapter3_file, show_col_types = FALSE)
  cat("✓ Loaded Chapter 3 data:", nrow(chapter3_data), "rows\n")
} else {
  # Load and merge pupil + DDM separately
  pupil_data <- read_csv(pupil_file, show_col_types = FALSE)
  ddm_data <- read_csv(ddm_file, show_col_types = FALSE)
  
  # Standardize subject_id column name
  if ("sub" %in% names(pupil_data) && !"subject_id" %in% names(pupil_data)) {
    pupil_data$subject_id <- as.character(pupil_data$sub)
  }
  if ("sub" %in% names(ddm_data) && !"subject_id" %in% names(ddm_data)) {
    ddm_data$subject_id <- as.character(ddm_data$sub)
  }
  
  # Merge
  chapter3_data <- pupil_data %>%
    inner_join(ddm_data, by = "subject_id", suffix = c("_pupil", "_ddm"))
  cat("✓ Merged pupil + DDM data:", nrow(chapter3_data), "rows\n")
}

# Standardize Chapter 3 subject IDs
if (!"subject_id_raw" %in% names(chapter3_data)) {
  chapter3_data$subject_id_raw <- chapter3_data$subject_id
}
chapter3_data$subject_id_norm <- normalize_subject_id(chapter3_data$subject_id_raw)

# =========================================================================
# STEP 3: MERGE LC WITH CHAPTER 3 DATA
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 3: Merging LC with Chapter 3 data...\n")
cat(strrep("=", 80), "\n\n")

merged_data <- lc_bap %>%
  inner_join(chapter3_data, by = "subject_id_norm", suffix = c("_lc", "_ch3"))

n_lc_bap <- nrow(lc_bap)
n_ch3_subj <- length(unique(chapter3_data$subject_id_norm))
n_matched <- nrow(merged_data)

cat("LC BAP rows:", n_lc_bap, "\n")
cat("Chapter 3 subjects:", n_ch3_subj, "\n")
cat("Matched rows:", n_matched, "\n\n")

# Merge diagnostics
unmatched_lc <- lc_bap %>%
  anti_join(chapter3_data, by = "subject_id_norm") %>%
  head(5)

unmatched_ch3 <- chapter3_data %>%
  distinct(subject_id_norm) %>%
  anti_join(lc_bap, by = "subject_id_norm") %>%
  head(5)

merge_diagnostics <- tibble(
  metric = c("n_lc_bap", "n_ch3_subjects", "n_matched", 
             "n_unmatched_lc", "n_unmatched_ch3"),
  value = c(n_lc_bap, n_ch3_subj, n_matched,
            nrow(lc_bap) - n_matched,
            n_ch3_subj - n_matched),
  unmatched_examples_lc = c("", "", "", 
                            paste(unmatched_lc$subject_id_norm[1:min(3, nrow(unmatched_lc))], collapse = ", "),
                            ""),
  unmatched_examples_ch3 = c("", "", "", "",
                             paste(unmatched_ch3$subject_id_norm[1:min(3, nrow(unmatched_ch3))], collapse = ", "))
)

write_csv(merge_diagnostics, file.path(OUTPUT_BASE, "lc_merge_diagnostics.csv"))
cat("✓ Saved merge diagnostics\n")

if (n_matched == 0) {
  stop("No matched subjects found! Check ID standardization.")
}

# =========================================================================
# STEP 4: DEFINE LC INTEGRITY VARIABLES
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 4: Creating LC integrity composites...\n")
cat(strrep("=", 80), "\n\n")

# Identify LC metric columns (case-insensitive search)
lc_cols <- names(merged_data)
cnr_col <- lc_cols[str_detect(lc_cols, regex("cnr|contrast", ignore_case = TRUE))][1]
md_col <- lc_cols[str_detect(lc_cols, regex("^md$|mean.*diff", ignore_case = TRUE))][1]
fa_col <- lc_cols[str_detect(lc_cols, regex("^fa$|fractional", ignore_case = TRUE))][1]
fiso_col <- lc_cols[str_detect(lc_cols, regex("fiso|free.*water", ignore_case = TRUE))][1]
ficvf_col <- lc_cols[str_detect(lc_cols, regex("ficvf|intra", ignore_case = TRUE))][1]
vol_col <- lc_cols[str_detect(lc_cols, regex("vol|volume", ignore_case = TRUE))][1]

# Standardize column names
merged_data <- merged_data %>%
  mutate(
    LC_CNR = !!sym(cnr_col),
    MD = !!sym(md_col),
    FA = !!sym(fa_col),
    fiso = !!sym(fiso_col),
    ficvf = !!sym(ficvf_col),
    LC_Vol = !!sym(vol_col)
  )

# Create z-scores for composite
merged_data <- merged_data %>%
  mutate(
    z_CNR = scale(LC_CNR)[,1],
    z_MD = scale(MD)[,1],
    z_FA = scale(FA)[,1],
    z_fiso = scale(fiso)[,1],
    z_ficvf = scale(ficvf)[,1]
  )

# (i) Directed z composite
merged_data <- merged_data %>%
  mutate(
    lc_composite_directed = z_CNR + z_ficvf - z_fiso - z_MD + z_FA
  )

# (ii) PCA-based composite
lc_metrics <- merged_data %>%
  select(LC_CNR, MD, FA, fiso, ficvf) %>%
  na.omit()

if (nrow(lc_metrics) > 0) {
  pca_result <- prcomp(lc_metrics, center = TRUE, scale = TRUE)
  pc1_scores <- predict(pca_result, merged_data %>% select(LC_CNR, MD, FA, fiso, ficvf))
  merged_data$lc_pc1 <- pc1_scores[,1]
  
  # Save PC1 loadings
  pc1_loadings <- tibble(
    metric = c("LC_CNR", "MD", "FA", "fiso", "ficvf"),
    PC1_loading = pca_result$rotation[,1],
    PC1_variance_explained = summary(pca_result)$importance[2,1]
  )
  write_csv(pc1_loadings, file.path(OUTPUT_BASE, "lc_pc1_loadings.csv"))
  cat("✓ Saved PC1 loadings\n")
} else {
  warning("No complete LC metrics for PCA")
  merged_data$lc_pc1 <- NA
}

# Use PCA composite as primary (more data-driven)
merged_data$lc_composite <- merged_data$lc_pc1

# Save descriptives
lc_descriptives <- merged_data %>%
  select(LC_CNR, MD, FA, fiso, ficvf, LC_Vol, lc_composite, lc_composite_directed) %>%
  summarise_all(list(
    mean = ~mean(., na.rm = TRUE),
    sd = ~sd(., na.rm = TRUE),
    min = ~min(., na.rm = TRUE),
    max = ~max(., na.rm = TRUE),
    n = ~sum(!is.na(.))
  ), .names = "{.col}_{.fn}")

write_csv(lc_descriptives, file.path(OUTPUT_BASE, "lc_descriptives.csv"))
cat("✓ Saved LC descriptives\n")

# =========================================================================
# STEP 5: EXPLORATORY ANALYSES
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 5: Running exploratory analyses...\n")
cat(strrep("=", 80), "\n\n")

all_models <- list()

# Check for age/sex covariates
has_age <- any(str_detect(names(merged_data), regex("age", ignore_case = TRUE)))
has_sex <- any(str_detect(names(merged_data), regex("sex|gender", ignore_case = TRUE)))

if (has_age) {
  age_col <- names(merged_data)[str_detect(names(merged_data), regex("age", ignore_case = TRUE))][1]
  merged_data$age <- merged_data[[age_col]]
} else {
  merged_data$age <- NA
  cat("⚠ Age not found in dataset\n")
}

if (has_sex) {
  sex_col <- names(merged_data)[str_detect(names(merged_data), regex("sex|gender", ignore_case = TRUE))][1]
  merged_data$sex <- merged_data[[sex_col]]
} else {
  merged_data$sex <- NA
  cat("⚠ Sex not found in dataset\n")
}

# A) LC integrity vs. pupil measures
cat("A) LC integrity vs. pupil measures...\n")

# Find pupil columns
pupil_cols <- names(merged_data)[str_detect(names(merged_data), 
  regex("baseline|tonic|phasic|cognitive|auc|mean", ignore_case = TRUE))]

for (pupil_col in pupil_cols[1:min(5, length(pupil_cols))]) {  # Limit to first 5
  if (has_age && has_sex) {
    formula_str <- paste0(pupil_col, " ~ lc_composite + age + sex")
  } else {
    formula_str <- paste0(pupil_col, " ~ lc_composite")
  }
  
  tryCatch({
    mod <- lm(as.formula(formula_str), data = merged_data)
    model_name <- paste0("pupil_", pupil_col)
    all_models[[model_name]] <- mod
    cat("  ✓", pupil_col, "\n")
  }, error = function(e) {
    cat("  ✗", pupil_col, "-", e$message, "\n")
  })
}

# B) LC integrity vs. DDM parameters
cat("\nB) LC integrity vs. DDM parameters...\n")

# Find DDM parameter columns
ddm_cols <- names(merged_data)[str_detect(names(merged_data), 
  regex("^v_|^bs_|^z_|^ndt_|^t0_|drift|boundary|bias", ignore_case = TRUE))]

for (ddm_col in ddm_cols[1:min(5, length(ddm_cols))]) {  # Limit to first 5
  if (has_age && has_sex) {
    formula_str <- paste0(ddm_col, " ~ lc_composite + age + sex")
  } else {
    formula_str <- paste0(ddm_col, " ~ lc_composite")
  }
  
  tryCatch({
    mod <- lm(as.formula(formula_str), data = merged_data)
    model_name <- paste0("ddm_", ddm_col)
    all_models[[model_name]] <- mod
    cat("  ✓", ddm_col, "\n")
  }, error = function(e) {
    cat("  ✗", ddm_col, "-", e$message, "\n")
  })
}

# C) Targeted moderation: bias shift by effort
cat("\nC) Targeted moderation: bias shift by effort...\n")

# Check if we have z by effort condition
has_z_by_effort <- any(str_detect(names(merged_data), 
  regex("z.*high|z.*low|bias.*effort", ignore_case = TRUE)))

if (has_z_by_effort) {
  z_high_col <- names(merged_data)[str_detect(names(merged_data), 
    regex("z.*high|bias.*high", ignore_case = TRUE))][1]
  z_low_col <- names(merged_data)[str_detect(names(merged_data), 
    regex("z.*low|bias.*low", ignore_case = TRUE))][1]
  
  merged_data$delta_z <- merged_data[[z_high_col]] - merged_data[[z_low_col]]
  outcome_var <- "delta_z"
  cat("  ✓ Using z_high - z_low\n")
} else {
  # Need to compute from trial-level data
  cat("  → Computing bias shift from trial-level data...\n")
  
  # Try to find trial-level file
  trial_paths <- c(
    "data/pupil_processed/analysis_ready/ch3_triallevel.csv",
    "quick_share_v7/analysis_ready/ch3_triallevel.csv",
    "data/analysis_ready/BAP_analysis_ready_PUPIL.csv"
  )
  
  trial_file <- first_existing(trial_paths)
  if (!is.null(trial_file)) {
    trial_data <- read_csv(trial_file, show_col_types = FALSE)
    
    # Standardize IDs
    if ("sub" %in% names(trial_data) && !"subject_id" %in% names(trial_data)) {
      trial_data$subject_id <- as.character(trial_data$sub)
    }
    trial_data$subject_id_norm <- normalize_subject_id(trial_data$subject_id)
    
    # Standardize effort column
    if ("effort" %in% names(trial_data)) {
      trial_data <- trial_data %>%
        mutate(effort_condition = case_when(
          effort == "High" ~ "High",
          effort == "Low" ~ "Low",
          TRUE ~ as.character(effort)
        ))
    }
    
    # Compute p(different) by effort
    if ("resp_is_diff" %in% names(trial_data) || "decision" %in% names(trial_data)) {
      decision_col <- ifelse("resp_is_diff" %in% names(trial_data), "resp_is_diff", "decision")
      
      p_diff_by_effort <- trial_data %>%
        filter(!is.na(effort_condition)) %>%
        group_by(subject_id_norm, effort_condition) %>%
        summarise(
          p_diff = mean(!!sym(decision_col) == TRUE | !!sym(decision_col) == "different", na.rm = TRUE),
          .groups = "drop"
        ) %>%
        pivot_wider(names_from = effort_condition, values_from = p_diff, 
                   names_prefix = "p_diff_") %>%
        mutate(delta_pdiff = p_diff_High - p_diff_Low)
      
      merged_data <- merged_data %>%
        left_join(p_diff_by_effort, by = "subject_id_norm")
      
      outcome_var <- "delta_pdiff"
      cat("  ✓ Computed delta_pdiff\n")
    } else {
      cat("  ✗ Cannot find decision column in trial data\n")
      outcome_var <- NULL
    }
  } else {
    cat("  ✗ Trial-level file not found\n")
    outcome_var <- NULL
  }
}

# Fit targeted moderation model
if (!is.null(outcome_var) && outcome_var %in% names(merged_data)) {
  if (has_age && has_sex) {
    formula_str <- paste0(outcome_var, " ~ lc_composite + age + sex")
  } else {
    formula_str <- paste0(outcome_var, " ~ lc_composite")
  }
  
  mod_targeted <- lm(as.formula(formula_str), data = merged_data)
  all_models[["targeted_bias_shift"]] <- mod_targeted
  cat("  ✓ Fitted targeted model:", outcome_var, "\n")
} else {
  cat("  ✗ Cannot fit targeted model - outcome variable not available\n")
}

# =========================================================================
# STEP 6: SAVE MODEL RESULTS
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 6: Saving model results...\n")
cat(strrep("=", 80), "\n\n")

# Extract all model summaries using broom
model_summaries <- map_dfr(all_models, function(mod) {
  tidy(mod, conf.int = TRUE) %>%
    mutate(
      model_name = deparse(formula(mod)),
      n_obs = nobs(mod),
      r_squared = summary(mod)$r.squared
    )
}, .id = "model_id")

write_csv(model_summaries, file.path(OUTPUT_BASE, "lc_models_summary.csv"))
cat("✓ Saved model summaries\n")

# Correlations (if requested)
lc_corr_data <- merged_data %>%
  select(LC_CNR, MD, FA, fiso, ficvf, lc_composite, 
         matches("baseline|tonic|phasic|v_|bs_|z_"))

if (ncol(lc_corr_data) > 1) {
  lc_correlations <- cor(lc_corr_data, use = "pairwise.complete.obs")
  lc_corr_df <- as.data.frame(lc_correlations) %>%
    rownames_to_column("variable")
  write_csv(lc_corr_df, file.path(OUTPUT_BASE, "lc_correlations.csv"))
  cat("✓ Saved correlations\n")
} else {
  cat("⚠ Not enough columns for correlation matrix\n")
}

# =========================================================================
# STEP 7: CREATE FIGURES
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("STEP 7: Creating figures...\n")
cat(strrep("=", 80), "\n\n")

# Figure 1: LC CNR vs delta_z (or delta_pdiff)
if (exists("outcome_var") && !is.null(outcome_var) && outcome_var %in% names(merged_data)) {
  p1 <- ggplot(merged_data, aes(x = LC_CNR, y = !!sym(outcome_var))) +
    geom_point(alpha = 0.6) +
    geom_smooth(method = "lm", se = TRUE, color = "blue") +
    labs(
      x = "LC Contrast-to-Noise Ratio (CNR)",
      y = ifelse(outcome_var == "delta_z", 
                 "Bias Shift (z_high - z_low)",
                 "Choice Proportion Shift (p_diff_high - p_diff_low)"),
      title = "LC Integrity vs. Effort-Related Bias Shift",
      subtitle = "Exploratory"
    ) +
    theme_minimal()
  
  ggsave(file.path(OUTPUT_FIGURES, "fig_lc_integrity_cnr_vs_delta_z.pdf"), 
         p1, width = 6, height = 5)
  ggsave(file.path(OUTPUT_FIGURES, "fig_lc_integrity_cnr_vs_delta_z.png"), 
         p1, width = 6, height = 5, dpi = 300)
  cat("✓ Saved fig_lc_integrity_cnr_vs_delta_z\n")
}

# Figure 2: LC PC1 vs DDM v
if ("v_mean" %in% names(merged_data) || any(str_detect(names(merged_data), "^v_"))) {
  v_col <- names(merged_data)[str_detect(names(merged_data), "^v_")][1]
  if (!is.null(v_col)) {
    p2 <- ggplot(merged_data, aes(x = lc_pc1, y = !!sym(v_col))) +
      geom_point(alpha = 0.6) +
      geom_smooth(method = "lm", se = TRUE, color = "blue") +
      labs(
        x = "LC Integrity (PC1)",
        y = "Drift Rate (v)",
        title = "LC Integrity vs. Drift Rate",
        subtitle = "Exploratory"
      ) +
      theme_minimal()
    
    ggsave(file.path(OUTPUT_FIGURES, "fig_lc_integrity_pc1_vs_ddm_v.pdf"), 
           p2, width = 6, height = 5)
    ggsave(file.path(OUTPUT_FIGURES, "fig_lc_integrity_pc1_vs_ddm_v.png"), 
           p2, width = 6, height = 5, dpi = 300)
    cat("✓ Saved fig_lc_integrity_pc1_vs_ddm_v\n")
  }
}

# Figure 3: LC PC1 vs phasic pupil
phasic_cols <- names(merged_data)[str_detect(names(merged_data), 
  regex("phasic|cognitive.*auc|cog_auc|phasic_mean", ignore_case = TRUE))]

# Remove any columns that are all NA
phasic_cols <- phasic_cols[sapply(phasic_cols, function(col) {
  !all(is.na(merged_data[[col]]))
})]

if (length(phasic_cols) > 0) {
  phasic_col <- phasic_cols[1]
  cat("  → Using phasic column:", phasic_col, "\n")
  
  # Check if we have valid data
  valid_data <- merged_data %>%
    select(lc_pc1, !!sym(phasic_col)) %>%
    filter(!is.na(lc_pc1), !is.na(!!sym(phasic_col)))
  
  if (nrow(valid_data) > 0) {
    p3 <- ggplot(merged_data, aes(x = lc_pc1, y = !!sym(phasic_col))) +
      geom_point(alpha = 0.6) +
      geom_smooth(method = "lm", se = TRUE, color = "blue") +
      labs(
        x = "LC Integrity (PC1)",
        y = paste("Phasic Pupil Response (", phasic_col, ")", sep = ""),
        title = "LC Integrity vs. Phasic Arousal",
        subtitle = "Exploratory"
      ) +
      theme_minimal()
    
    ggsave(file.path(OUTPUT_FIGURES, "fig_lc_integrity_pc1_vs_pupil_phasic.pdf"), 
           p3, width = 6, height = 5)
    ggsave(file.path(OUTPUT_FIGURES, "fig_lc_integrity_pc1_vs_pupil_phasic.png"), 
           p3, width = 6, height = 5, dpi = 300)
    cat("✓ Saved fig_lc_integrity_pc1_vs_pupil_phasic\n")
  } else {
    cat("  ✗ No valid data for phasic pupil figure (all NA)\n")
  }
} else {
  cat("  ✗ No phasic pupil columns found in merged data\n")
  cat("  Available columns:", paste(names(merged_data)[1:min(10, length(names(merged_data)))], collapse = ", "), "...\n")
}

# =========================================================================
# STEP 8: CONSOLE SUMMARY
# =========================================================================

cat("\n", strrep("=", 80), "\n")
cat("SUMMARY\n")
cat(strrep("=", 80), "\n\n")

cat("N matched subjects:", n_matched, "\n\n")

if (exists("mod_targeted") && !is.null(mod_targeted)) {
  targeted_summary <- tidy(mod_targeted, conf.int = TRUE) %>%
    filter(term == "lc_composite")
  cat("Targeted model (", outcome_var, "):\n", sep = "")
  cat("  Slope:", sprintf("%.4f", targeted_summary$estimate), 
      "[", sprintf("%.4f", targeted_summary$conf.low), 
      ",", sprintf("%.4f", targeted_summary$conf.high), "]\n")
  cat("  p-value:", sprintf("%.4f", targeted_summary$p.value), "\n\n")
}

cat("Outputs saved to:\n")
cat("  Tables:", OUTPUT_BASE, "\n")
cat("  Figures:", OUTPUT_FIGURES, "\n\n")

cat("Script completed successfully!\n")
cat(strrep("=", 80), "\n\n")
