# =========================================================================
# STATE/TRAIT DECOMPOSITION AND RESIDUALIZATION
# =========================================================================
# This script implements state/trait decomposition for pupillometry features
# and creates properly residualized within-person effects
# =========================================================================

library(dplyr)
library(readr)
library(car)
library(corrplot)

# =========================================================================
# CONFIGURATION
# =========================================================================

INPUT_FILES <- list(
    main = "data/analysis_ready/BAP_trialwise_pupil_features.csv",
    alternative = "data/analysis_ready/BAP_trialwise_pupil_features_alternative_windows.csv"
)

OUTPUT_FILE <- "data/analysis_ready/bap_clean_pupil.csv"
OUTPUT_DIR <- "output/results"

# Pupillometry features to decompose
PUPIL_FEATURES <- c(
    "TONIC_BASELINE_scaled",
    "PHASIC_TER_PEAK_scaled", 
    "PHASIC_TER_AUC_scaled",
    "PHASIC_SLOPE_scaled"
)

# Alternative window features (if available)
ALT_PUPIL_FEATURES <- c(
    "PHASIC_EARLY_PEAK_scaled",
    "PHASIC_LATE_PEAK_scaled",
    "PHASIC_EARLY_AUC_scaled", 
    "PHASIC_LATE_AUC_scaled"
)

# =========================================================================
# UTILITY FUNCTIONS
# =========================================================================

#' Calculate between-person and within-person components
#' @param data Data frame with participant and feature columns
#' @param feature_col Name of the feature column
#' @param participant_col Name of the participant column
calculate_bp_wp <- function(data, feature_col, participant_col = "subject_id") {
    
    # Calculate between-person means
    bp_means <- data %>%
        group_by(!!sym(participant_col)) %>%
        summarise(
            !!paste0(feature_col, "_bp") := mean(!!sym(feature_col), na.rm = TRUE),
            .groups = "drop"
        )
    
    # Merge with original data
    data_with_bp <- data %>%
        left_join(bp_means, by = participant_col)
    
    # Calculate within-person deviations
    data_with_bp <- data_with_bp %>%
        mutate(
            !!paste0(feature_col, "_wp") := !!sym(feature_col) - !!sym(paste0(feature_col, "_bp"))
        )
    
    return(data_with_bp)
}

#' Z-score within-person effects within participant
#' @param data Data frame with within-person columns
#' @param feature_col Name of the within-person feature column
#' @param participant_col Name of the participant column
zscore_wp <- function(data, feature_col, participant_col = "subject_id") {
    
    data %>%
        group_by(!!sym(participant_col)) %>%
        mutate(
            !!paste0(feature_col, "_z") := scale(!!sym(feature_col))[,1]
        ) %>%
        ungroup()
}

#' Residualize within-person effects
#' @param data Data frame with within-person columns
#' @param outcome_col Name of the outcome column to residualize
#' @param predictor_cols Vector of predictor column names
#' @param participant_col Name of the participant column
residualize_wp <- function(data, outcome_col, predictor_cols, participant_col = "subject_id") {
    
    # Create formula for residualization
    formula_str <- paste(outcome_col, "~", paste(predictor_cols, collapse = " + "))
    
    # Initialize residual column
    residual_col <- paste0(outcome_col, "_resid_wp")
    data[[residual_col]] <- NA_real_
    
    # Fit model per participant
    for (participant in unique(data[[participant_col]])) {
        participant_indices <- which(data[[participant_col]] == participant)
        participant_data <- data[participant_indices, ]
        
        # Check if we have enough data points and valid predictors
        valid_rows <- complete.cases(participant_data[, c(outcome_col, predictor_cols)])
        
        if (sum(valid_rows) < 5) {
            # If not enough data, use NA
            data[participant_indices, residual_col] <- NA_real_
        } else {
            # Fit model for this participant
            tryCatch({
                model <- lm(as.formula(formula_str), data = participant_data[valid_rows, ])
                residuals_vec <- rep(NA_real_, nrow(participant_data))
                residuals_vec[valid_rows] <- residuals(model)
                data[participant_indices, residual_col] <- residuals_vec
            }, error = function(e) {
                # If model fails, use NA
                data[participant_indices, residual_col] <- NA_real_
            })
        }
    }
    
    return(data)
}

#' Calculate VIF for a set of predictors
#' @param data Data frame
#' @param predictor_cols Vector of predictor column names
#' @param outcome_col Name of outcome column
calculate_vif <- function(data, predictor_cols, outcome_col) {
    
    # Create formula
    formula_str <- paste(outcome_col, "~", paste(predictor_cols, collapse = " + "))
    
    # Fit model
    model <- lm(as.formula(formula_str), data = data)
    
    # Calculate VIF
    vif_results <- tryCatch({
        vif_values <- vif(model)
        data.frame(
            predictor = names(vif_values),
            vif = as.numeric(vif_values),
            stringsAsFactors = FALSE
        )
    }, error = function(e) {
        data.frame(
            predictor = predictor_cols,
            vif = NA,
            stringsAsFactors = FALSE
        )
    })
    
    return(vif_results)
}

# =========================================================================
# MAIN PROCESSING
# =========================================================================

cat("================================================================================\n")
cat("STATE/TRAIT DECOMPOSITION AND RESIDUALIZATION\n")
cat("================================================================================\n")
cat("Starting state/trait decomposition...\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Load main data
cat("📁 Loading main pupillometry data...\n")
main_data <- read_csv(INPUT_FILES$main, show_col_types = FALSE)
cat("Loaded", nrow(main_data), "trials from", length(unique(main_data$subject_id)), "participants\n")

# Check for alternative windows data
has_alt_windows <- file.exists(INPUT_FILES$alternative)
if (has_alt_windows) {
    cat("📁 Loading alternative windows data...\n")
    alt_data <- read_csv(INPUT_FILES$alternative, show_col_types = FALSE)
    cat("Loaded", nrow(alt_data), "trials with alternative windows\n")
    
    # Merge alternative windows data
    alt_features <- alt_data %>%
        select(subject_id, task, run, trial_index, all_of(ALT_PUPIL_FEATURES))
    
    main_data <- main_data %>%
        left_join(alt_features, by = c("subject_id", "task", "run", "trial_index"))
    
    # Add alternative features to the list
    PUPIL_FEATURES <- c(PUPIL_FEATURES, ALT_PUPIL_FEATURES)
    cat("Added alternative window features:", paste(ALT_PUPIL_FEATURES, collapse = ", "), "\n")
} else {
    cat("⚠️  Alternative windows data not found, using main features only\n")
}

# Filter for valid trials (non-missing pupil data)
cat("\n🔍 Filtering for valid trials...\n")
valid_data <- main_data %>%
    filter(!is.na(TONIC_BASELINE_scaled) & !is.na(PHASIC_TER_PEAK_scaled))

cat("Valid trials:", nrow(valid_data), "from", nrow(main_data), "total trials\n")
cat("Valid participants:", length(unique(valid_data$subject_id)), "\n")

# Create effort_numeric variable if not present
if (!"effort_numeric" %in% colnames(valid_data)) {
    valid_data <- valid_data %>%
        mutate(
            effort_numeric = case_when(
                effort_condition == "Low_5_MVC" ~ 5,
                effort_condition == "High_40_MVC" ~ 40,
                TRUE ~ NA_real_
            )
        )
}

# Create choice_binary if not present
if (!"choice_binary" %in% colnames(valid_data)) {
    valid_data <- valid_data %>%
        mutate(
            choice_binary = case_when(
                choice == "correct" ~ 1,
                choice == "incorrect" ~ 0,
                TRUE ~ NA_real_
            )
        )
}

# Create prev_choice if not present
if (!"prev_choice" %in% colnames(valid_data)) {
    valid_data <- valid_data %>%
        group_by(subject_id, task, run) %>%
        arrange(trial_index) %>%
        mutate(
            prev_choice = lag(choice_binary),
            prev_choice = case_when(
                prev_choice == 1 ~ 1,
                prev_choice == 0 ~ -1,
                TRUE ~ 0
            )
        ) %>%
        ungroup()
}

# =========================================================================
# STATE/TRAIT DECOMPOSITION
# =========================================================================

cat("\n🧮 Performing state/trait decomposition...\n")

# Start with base data
decomposed_data <- valid_data

# Process each pupil feature
for (feature in PUPIL_FEATURES) {
    if (feature %in% colnames(decomposed_data)) {
        cat("Processing:", feature, "\n")
        
        # Calculate between-person and within-person components
        decomposed_data <- calculate_bp_wp(decomposed_data, feature)
        
        # Z-score within-person effects
        decomposed_data <- zscore_wp(decomposed_data, paste0(feature, "_wp"))
    } else {
        cat("⚠️  Feature not found:", feature, "\n")
    }
}

# =========================================================================
# RESIDUALIZATION
# =========================================================================

cat("\n🔄 Performing residualization...\n")

# Residualize PHASIC effects on TONIC + controls
phasic_features <- PUPIL_FEATURES[grepl("PHASIC", PUPIL_FEATURES)]

for (phasic_feature in phasic_features) {
    wp_feature <- paste0(phasic_feature, "_wp")
    if (wp_feature %in% colnames(decomposed_data)) {
        cat("Residualizing:", phasic_feature, "\n")
        
        # Define predictors
        predictors <- c("TONIC_BASELINE_scaled_wp", "difficulty_level", "effort_condition")
        
        # Add effort_numeric if available
        if ("effort_numeric" %in% colnames(decomposed_data)) {
            predictors <- c(predictors, "effort_numeric")
        }
        
        # Residualize
        decomposed_data <- residualize_wp(
            decomposed_data, 
            wp_feature, 
            predictors
        )
    }
}

# =========================================================================
# ORTHOGONALIZATION (if early/late features exist)
# =========================================================================

if (has_alt_windows) {
    cat("\n📐 Performing orthogonalization for early/late features...\n")
    
    # Orthogonalize PHASIC_EARLY on PHASIC_LATE + controls
    if ("PHASIC_EARLY_PEAK_scaled_wp" %in% colnames(decomposed_data) && 
        "PHASIC_LATE_PEAK_scaled_wp" %in% colnames(decomposed_data)) {
        
        cat("Orthogonalizing PHASIC_EARLY on PHASIC_LATE...\n")
        
        # Define predictors for orthogonalization
        orthogonal_predictors <- c("PHASIC_LATE_PEAK_scaled_wp", "TONIC_BASELINE_scaled_wp", 
                                  "difficulty_level", "effort_condition")
        
        if ("effort_numeric" %in% colnames(decomposed_data)) {
            orthogonal_predictors <- c(orthogonal_predictors, "effort_numeric")
        }
        
        # Orthogonalize EARLY on LATE
        decomposed_data <- residualize_wp(
            decomposed_data,
            "PHASIC_EARLY_PEAK_scaled_wp",
            orthogonal_predictors
        )
        
        # Rename the residual column
        colnames(decomposed_data)[colnames(decomposed_data) == "PHASIC_EARLY_PEAK_scaled_wp_resid_wp"] <- 
            "PHASIC_EARLY_PEAK_scaled_orthogonal_wp"
    }
    
    # Orthogonalize PHASIC_LATE on PHASIC_EARLY + controls (if fitting solo)
    if ("PHASIC_LATE_PEAK_scaled_wp" %in% colnames(decomposed_data) && 
        "PHASIC_EARLY_PEAK_scaled_wp" %in% colnames(decomposed_data)) {
        
        cat("Orthogonalizing PHASIC_LATE on PHASIC_EARLY...\n")
        
        # Define predictors for orthogonalization
        orthogonal_predictors <- c("PHASIC_EARLY_PEAK_scaled_wp", "TONIC_BASELINE_scaled_wp", 
                                  "difficulty_level", "effort_condition")
        
        if ("effort_numeric" %in% colnames(decomposed_data)) {
            orthogonal_predictors <- c(orthogonal_predictors, "effort_numeric")
        }
        
        # Orthogonalize LATE on EARLY
        decomposed_data <- residualize_wp(
            decomposed_data,
            "PHASIC_LATE_PEAK_scaled_wp",
            orthogonal_predictors
        )
        
        # Rename the residual column
        colnames(decomposed_data)[colnames(decomposed_data) == "PHASIC_LATE_PEAK_scaled_wp_resid_wp"] <- 
            "PHASIC_LATE_PEAK_scaled_orthogonal_wp"
    }
}

# =========================================================================
# VIF ANALYSIS
# =========================================================================

cat("\n📊 Calculating VIF for multicollinearity assessment...\n")

# Create VIF report
vif_report <- list()

# VIF for between-person effects
bp_predictors <- paste0(PUPIL_FEATURES, "_bp")
bp_predictors <- bp_predictors[bp_predictors %in% colnames(decomposed_data)]

if (length(bp_predictors) > 1) {
    vif_report$between_person <- calculate_vif(
        decomposed_data, 
        bp_predictors, 
        "rt"
    )
}

# VIF for within-person effects
wp_predictors <- paste0(PUPIL_FEATURES, "_wp")
wp_predictors <- wp_predictors[wp_predictors %in% colnames(decomposed_data)]

if (length(wp_predictors) > 1) {
    vif_report$within_person <- calculate_vif(
        decomposed_data, 
        wp_predictors, 
        "rt"
    )
}

# VIF for residualized effects
resid_predictors <- paste0(phasic_features, "_wp_resid_wp")
resid_predictors <- resid_predictors[resid_predictors %in% colnames(decomposed_data)]

if (length(resid_predictors) > 1) {
    vif_report$residualized <- calculate_vif(
        decomposed_data, 
        resid_predictors, 
        "rt"
    )
}

# Print VIF summary
cat("\nVIF Summary:\n")
for (level in names(vif_report)) {
    cat("\n", toupper(level), "LEVEL:\n")
    print(vif_report[[level]])
}

# =========================================================================
# SAVE RESULTS
# =========================================================================

cat("\n💾 Saving results...\n")

# Create output directory if it doesn't exist
if (!dir.exists(OUTPUT_DIR)) {
    dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Save the clean dataset
write_csv(decomposed_data, OUTPUT_FILE)
cat("Saved clean dataset to:", OUTPUT_FILE, "\n")

# Save VIF report
vif_report_file <- file.path(OUTPUT_DIR, "vif_report_state_trait.csv")
vif_report_df <- do.call(rbind, lapply(names(vif_report), function(level) {
    if (!is.null(vif_report[[level]])) {
        cbind(level = level, vif_report[[level]])
    }
}))
write_csv(vif_report_df, vif_report_file)
cat("Saved VIF report to:", vif_report_file, "\n")

# =========================================================================
# SUMMARY STATISTICS
# =========================================================================

cat("\n📈 Summary Statistics:\n")
cat("Total trials:", nrow(decomposed_data), "\n")
cat("Participants:", length(unique(decomposed_data$subject_id)), "\n")
cat("Tasks:", paste(unique(decomposed_data$task), collapse = ", "), "\n")

# Count valid observations for each feature
feature_summary <- data.frame(
    feature = character(),
    n_valid = numeric(),
    n_missing = numeric(),
    stringsAsFactors = FALSE
)

for (feature in PUPIL_FEATURES) {
    if (feature %in% colnames(decomposed_data)) {
        n_valid <- sum(!is.na(decomposed_data[[feature]]))
        n_missing <- sum(is.na(decomposed_data[[feature]]))
        
        feature_summary <- rbind(feature_summary, data.frame(
            feature = feature,
            n_valid = n_valid,
            n_missing = n_missing
        ))
    }
}

cat("\nFeature Summary:\n")
print(feature_summary)

# Between-person vs within-person variance
cat("\nBetween-Person vs Within-Person Variance:\n")
for (feature in PUPIL_FEATURES) {
    bp_col <- paste0(feature, "_bp")
    wp_col <- paste0(feature, "_wp")
    
    if (bp_col %in% colnames(decomposed_data) && wp_col %in% colnames(decomposed_data)) {
        bp_var <- var(decomposed_data[[bp_col]], na.rm = TRUE)
        wp_var <- var(decomposed_data[[wp_col]], na.rm = TRUE)
        total_var <- bp_var + wp_var
        bp_prop <- bp_var / total_var
        
        cat(sprintf("%s: BP=%.3f, WP=%.3f, BP/Total=%.3f\n", 
                   feature, bp_var, wp_var, bp_prop))
    }
}

cat("\n================================================================================\n")
cat("✅ STATE/TRAIT DECOMPOSITION COMPLETE!\n")
cat("================================================================================\n")
cat("Output files:\n")
cat("- Clean dataset:", OUTPUT_FILE, "\n")
cat("- VIF report:", vif_report_file, "\n")
cat("\nNew columns created:\n")

# List new columns
new_columns <- colnames(decomposed_data)[!colnames(decomposed_data) %in% colnames(valid_data)]
cat("-", paste(new_columns, collapse = "\n- "), "\n")

cat("\nReady for state/trait modeling!\n")
