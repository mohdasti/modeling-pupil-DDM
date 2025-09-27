# BAP Pupillometry Data Quality Control Suite
# Comprehensive validation for DDM-pupillometry analysis readiness

library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)
library(stringr)
library(corrplot)
library(survival)
library(survminer)

# Set paths
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
behavioral_file <- file.path(processed_dir, "bap_trial_data_grip_type1.csv")

cat("=== BAP PUPILLOMETRY COMPREHENSIVE QC SUITE ===\n\n")

# Load behavioral data for reference
behavioral_data <- read_csv(behavioral_file, show_col_types = FALSE)

# QC1: PUPILLOMETRY DATA QUALITY ASSESSMENT
qc1_pupillometry_quality <- function() {
    cat("=== QC1: PUPILLOMETRY DATA QUALITY ASSESSMENT ===\n")
    
    # Find all merged files
    merged_files <- list.files(processed_dir, pattern = ".*_flat_merged\\.csv$", full.names = TRUE)
    
    if(length(merged_files) == 0) {
        cat("ERROR: No merged files found. Run merger script first.\n")
        return(NULL)
    }
    
    pupil_quality_results <- list()
    
    for(file_path in merged_files) {
        filename <- basename(file_path)
        cat(sprintf("\nAnalyzing %s...\n", filename))
        
        data <- read_csv(file_path, show_col_types = FALSE)
        
        # Extract subject and task
        parts <- str_extract_all(filename, "BAP\\d+|ADT|VDT")[[1]]
        subject <- parts[1]
        task <- parts[2]
        
        # Basic metrics
        total_rows <- nrow(data)
        total_trials <- length(unique(data$trial_index))
        trials_with_behavioral <- length(unique(data$trial_index[data$has_behavioral_data]))
        
        # Pupillometry quality metrics
        pupil_quality <- data %>%
            summarise(
                # Basic coverage
                total_samples = n(),
                missing_pupil = sum(is.na(pupil)),
                zero_pupil = sum(pupil == 0, na.rm = TRUE),
                
                # Outlier detection (based on pupillometry literature)
                pupil_mean = mean(pupil, na.rm = TRUE),
                pupil_sd = sd(pupil, na.rm = TRUE),
                extreme_values = sum(pupil < 10 | pupil > 100, na.rm = TRUE), # Unrealistic pupil sizes
                
                # Temporal consistency
                time_gaps = sum(diff(data$time[order(data$time)]) > 0.1, na.rm = TRUE), # >100ms gaps
                
                # Quality metrics from pipeline
                high_quality_samples = sum(valid == 1, na.rm = TRUE),
                baseline_quality_mean = mean(baseline_quality, na.rm = TRUE),
                trial_quality_mean = mean(trial_quality, na.rm = TRUE),
                
                # Phase coverage
                phases_present = length(unique(trial_label)),
                has_squeeze_phase = "Squeeze" %in% unique(trial_label),
                has_stimulus_phase = "Stimulus" %in% unique(trial_label),
                has_response_phase = "Response_Different" %in% unique(trial_label),
                has_confidence_phase = "Confidence" %in% unique(trial_label)
            )
        
        # Trial-level quality assessment
        trial_quality <- data %>%
            group_by(trial_index) %>%
            summarise(
                trial_duration = max(time) - min(time),
                samples_per_trial = n(),
                missing_in_trial = sum(is.na(pupil)),
                has_behavioral = any(has_behavioral_data),
                phases_in_trial = length(unique(trial_label)),
                baseline_qual = mean(baseline_quality, na.rm = TRUE),
                trial_qual = mean(trial_quality, na.rm = TRUE),
                .groups = "drop"
            )
        
        # Store results
        pupil_quality_results[[filename]] <- list(
            subject = subject,
            task = task,
            filename = filename,
            total_trials = total_trials,
            trials_with_behavioral = trials_with_behavioral,
            overall_quality = pupil_quality,
            trial_quality = trial_quality,
            raw_data = data
        )
        
        # Print summary
        cat(sprintf("  Total trials: %d (with behavioral: %d)\n", total_trials, trials_with_behavioral))
        cat(sprintf("  Pupil data quality: %.1f%% valid samples\n", 
                    100 * pupil_quality$high_quality_samples / pupil_quality$total_samples))
        cat(sprintf("  Mean baseline quality: %.3f, trial quality: %.3f\n", 
                    pupil_quality$baseline_quality_mean, pupil_quality$trial_quality_mean))
        cat(sprintf("  Phase coverage: %d phases (Squeeze: %s, Stimulus: %s)\n", 
                    pupil_quality$phases_present, pupil_quality$has_squeeze_phase, pupil_quality$has_stimulus_phase))
    }
    
    return(pupil_quality_results)
}

# QC2: MERGE ACCURACY VALIDATION
qc2_merge_validation <- function(pupil_results) {
    cat("\n=== QC2: MERGE ACCURACY VALIDATION ===\n")
    
    merge_validation_results <- list()
    
    for(result in pupil_results) {
        cat(sprintf("\nValidating merge for %s %s...\n", result$subject, result$task))
        
        data <- result$raw_data
        
        # Get behavioral data for this subject-task
        behavioral_subset <- behavioral_data %>%
            filter(sub == result$subject, 
                   case_when(task == "aud" ~ "ADT", task == "vis" ~ "VDT", TRUE ~ task) == result$task)
        
        # Merge validation metrics
        validation <- list()
        
        # 1. Trial count consistency
        validation$behavioral_trials_available <- nrow(behavioral_subset)
        validation$pupil_trials_total <- result$total_trials
        validation$pupil_trials_with_behavioral <- result$trials_with_behavioral
        validation$merge_rate <- result$trials_with_behavioral / result$total_trials
        
        # 2. Condition consistency check
        merged_with_behavioral <- data %>%
            filter(has_behavioral_data) %>%
            distinct(trial_index, force_condition, stimulus_condition, .keep_all = TRUE)
        
        if(nrow(merged_with_behavioral) > 0) {
            validation$force_conditions_present <- unique(merged_with_behavioral$force_condition)
            validation$stimulus_conditions_present <- unique(merged_with_behavioral$stimulus_condition)
            validation$n_force_low <- sum(merged_with_behavioral$force_condition == "Low_Force_5pct", na.rm = TRUE)
            validation$n_force_high <- sum(merged_with_behavioral$force_condition == "High_Force_40pct", na.rm = TRUE)
            validation$n_stimulus_standard <- sum(merged_with_behavioral$stimulus_condition == "Standard", na.rm = TRUE)
            validation$n_stimulus_oddball <- sum(merged_with_behavioral$stimulus_condition == "Oddball", na.rm = TRUE)
        } else {
            validation$force_conditions_present <- "None"
            validation$stimulus_conditions_present <- "None"
            validation$n_force_low <- 0
            validation$n_force_high <- 0
            validation$n_stimulus_standard <- 0
            validation$n_stimulus_oddball <- 0
        }
        
        # 3. Timing consistency
        if(nrow(merged_with_behavioral) > 0) {
            timing_check <- merged_with_behavioral %>%
                filter(!is.na(resp1RT)) %>%
                summarise(
                    mean_rt = mean(resp1RT, na.rm = TRUE),
                    rt_range = paste(round(range(resp1RT, na.rm = TRUE), 3), collapse = " - "),
                    reasonable_rts = sum(resp1RT >= 0.2 & resp1RT <= 3.0, na.rm = TRUE),
                    total_rts = sum(!is.na(resp1RT))
                )
            validation$rt_check <- timing_check
        }
        
        merge_validation_results[[paste(result$subject, result$task)]] <- validation
        
        # Print summary
        cat(sprintf("  Behavioral trials available: %d\n", validation$behavioral_trials_available))
        cat(sprintf("  Pupil trials merged: %d/%d (%.1f%%)\n", 
                    validation$pupil_trials_with_behavioral, validation$pupil_trials_total,
                    100 * validation$merge_rate))
        cat(sprintf("  Force conditions: Low=%d, High=%d\n", 
                    validation$n_force_low, validation$n_force_high))
        cat(sprintf("  Stimulus conditions: Standard=%d, Oddball=%d\n", 
                    validation$n_stimulus_standard, validation$n_stimulus_oddball))
    }
    
    return(merge_validation_results)
}

# QC3: EXPERIMENTAL DESIGN COVERAGE ANALYSIS
qc3_coverage_analysis <- function(pupil_results) {
    cat("\n=== QC3: EXPERIMENTAL DESIGN COVERAGE ANALYSIS ===\n")
    
    # Combine all data
    all_merged_data <- pupil_results %>%
        map_dfr(~.x$raw_data %>% filter(has_behavioral_data) %>% distinct(trial_index, .keep_all = TRUE))
    
    if(nrow(all_merged_data) == 0) {
        cat("ERROR: No merged behavioral data found across all files\n")
        return(NULL)
    }
    
    # Create comprehensive coverage matrix
    coverage_matrix <- all_merged_data %>%
        filter(!is.na(force_condition) & !is.na(stimulus_condition)) %>%
        group_by(sub, task, force_condition, stimulus_condition) %>%
        summarise(
            n_trials = n(),
            mean_accuracy = mean(iscorr, na.rm = TRUE),
            mean_rt = mean(resp1RT, na.rm = TRUE),
            mean_pupil_squeeze = mean(pupil[trial_label == "Squeeze"], na.rm = TRUE),
            .groups = "drop"
        )
    
    # Pivot for easy viewing
    coverage_wide <- coverage_matrix %>%
        unite("condition", force_condition, stimulus_condition, sep = "_") %>%
        pivot_wider(names_from = condition, values_from = n_trials, values_fill = 0)
    
    cat("Coverage Matrix (trials per condition):\n")
    print(coverage_wide)
    
    # Missing cells analysis
    expected_cells <- expand_grid(
        sub = unique(all_merged_data$sub),
        task = unique(all_merged_data$task),
        force_condition = c("Low_Force_5pct", "High_Force_40pct"),
        stimulus_condition = c("Standard", "Oddball")
    )
    
    missing_cells <- expected_cells %>%
        anti_join(coverage_matrix, by = c("sub", "task", "force_condition", "stimulus_condition"))
    
    cat(sprintf("\nMissing experimental cells: %d/%d (%.1f%%)\n", 
                nrow(missing_cells), nrow(expected_cells), 
                100 * nrow(missing_cells) / nrow(expected_cells)))
    
    if(nrow(missing_cells) > 0) {
        cat("Missing cells:\n")
        print(missing_cells)
    }
    
    # Minimum trials per condition
    min_trials_per_condition <- coverage_matrix %>%
        group_by(force_condition, stimulus_condition) %>%
        summarise(
            min_trials = min(n_trials),
            max_trials = max(n_trials),
            mean_trials = mean(n_trials),
            subjects_with_data = n(),
            .groups = "drop"
        )
    
    cat("\nTrials per condition summary:\n")
    print(min_trials_per_condition)
    
    return(list(
        coverage_matrix = coverage_matrix,
        missing_cells = missing_cells,
        summary = min_trials_per_condition
    ))
}

# QC4: DATA USEFULNESS FOR DDM ANALYSIS
qc4_ddm_readiness <- function(pupil_results) {
    cat("\n=== QC4: DDM ANALYSIS READINESS ASSESSMENT ===\n")
    
    ddm_readiness <- list()
    
    for(result in pupil_results) {
        cat(sprintf("\nAssessing DDM readiness for %s %s...\n", result$subject, result$task))
        
        data <- result$raw_data %>% filter(has_behavioral_data)
        
        if(nrow(data) == 0) {
            cat("  No behavioral data - skipping DDM assessment\n")
            next
        }
        
        # DDM-specific quality metrics
        ddm_assessment <- list()
        
        # 1. Baseline period quality (critical for DDM)
        baseline_data <- data %>% filter(trial_label == "ITI_Baseline")
        ddm_assessment$baseline_samples <- nrow(baseline_data)
        ddm_assessment$baseline_quality <- mean(baseline_data$valid, na.rm = TRUE)
        
        # 2. Decision period quality (squeeze through confidence)
        decision_phases <- c("Squeeze", "Post_Squeeze_Blank", "Stimulus", 
                             "Post_Stimulus_Fixation", "Response_Different", "Confidence")
        decision_data <- data %>% filter(trial_label %in% decision_phases)
        ddm_assessment$decision_samples <- nrow(decision_data)
        ddm_assessment$decision_quality <- mean(decision_data$valid, na.rm = TRUE)
        
        # 3. Key phase coverage
        phase_coverage <- data %>%
            group_by(trial_label) %>%
            summarise(samples = n(), quality = mean(valid, na.rm = TRUE), .groups = "drop")
        
        ddm_assessment$phase_coverage <- phase_coverage
        
        # 4. Trial-level DDM metrics
        trial_level_ddm <- data %>%
            group_by(trial_index) %>%
            summarise(
                has_baseline = "ITI_Baseline" %in% trial_label,
                has_squeeze = "Squeeze" %in% trial_label,
                has_stimulus = "Stimulus" %in% trial_label,
                has_response = "Response_Different" %in% trial_label,
                baseline_pupil = mean(pupil[trial_label == "ITI_Baseline"], na.rm = TRUE),
                squeeze_pupil = mean(pupil[trial_label == "Squeeze"], na.rm = TRUE),
                stimulus_pupil = mean(pupil[trial_label == "Stimulus"], na.rm = TRUE),
                response_pupil = mean(pupil[trial_label == "Response_Different"], na.rm = TRUE),
                rt = first(resp1RT[!is.na(resp1RT)]),
                accuracy = first(iscorr[!is.na(iscorr)]),
                force_condition = first(force_condition[!is.na(force_condition)]),
                .groups = "drop"
            )
        
        # 5. DDM analysis viability
        complete_trials <- trial_level_ddm %>%
            filter(has_baseline & has_squeeze & has_stimulus & has_response & 
                       !is.na(rt) & !is.na(accuracy))
        
        ddm_assessment$total_trials <- nrow(trial_level_ddm)
        ddm_assessment$complete_trials <- nrow(complete_trials)
        ddm_assessment$ddm_viability <- nrow(complete_trials) / nrow(trial_level_ddm)
        
        # 6. Force manipulation effect (key for your study)
        if(nrow(complete_trials) > 0) {
            force_effect <- complete_trials %>%
                filter(!is.na(force_condition) & force_condition != "Unknown") %>%
                group_by(force_condition) %>%
                summarise(
                    n_trials = n(),
                    mean_squeeze_pupil = mean(squeeze_pupil, na.rm = TRUE),
                    mean_rt = mean(rt, na.rm = TRUE),
                    mean_accuracy = mean(accuracy, na.rm = TRUE),
                    .groups = "drop"
                )
            
            ddm_assessment$force_effect <- force_effect
            
            # Statistical test for force effect on squeeze pupil
            if(nrow(force_effect) == 2) {
                force_test_data <- complete_trials %>%
                    filter(!is.na(force_condition) & force_condition != "Unknown")
                
                if(nrow(force_test_data) > 5) {
                    force_test <- t.test(squeeze_pupil ~ force_condition, data = force_test_data)
                    ddm_assessment$force_effect_pvalue <- force_test$p.value
                    ddm_assessment$force_effect_significant <- force_test$p.value < 0.05
                }
            }
        }
        
        ddm_readiness[[paste(result$subject, result$task)]] <- ddm_assessment
        
        # Print summary
        cat(sprintf("  Total trials: %d, Complete for DDM: %d (%.1f%%)\n", 
                    ddm_assessment$total_trials, ddm_assessment$complete_trials,
                    100 * ddm_assessment$ddm_viability))
        cat(sprintf("  Baseline quality: %.3f, Decision quality: %.3f\n", 
                    ddm_assessment$baseline_quality, ddm_assessment$decision_quality))
        
        if("force_effect_pvalue" %in% names(ddm_assessment)) {
            cat(sprintf("  Force manipulation effect p-value: %.4f (%s)\n", 
                        ddm_assessment$force_effect_pvalue,
                        ifelse(ddm_assessment$force_effect_significant, "SIGNIFICANT", "non-significant")))
        }
    }
    
    return(ddm_readiness)
}

# QC5: SURVIVAL ANALYSIS FOR DATA USEFULNESS
qc5_survival_analysis <- function(pupil_results) {
    cat("\n=== QC5: SURVIVAL ANALYSIS FOR DATA USEFULNESS ===\n")
    
    # Combine all trial-level data
    all_trial_data <- pupil_results %>%
        map_dfr(~{
            .x$raw_data %>%
                filter(has_behavioral_data) %>%
                group_by(trial_index) %>%
                summarise(
                    subject = first(sub),
                    task = first(task),
                    run = first(run),
                    force_condition = first(force_condition[!is.na(force_condition)]),
                    stimulus_condition = first(stimulus_condition[!is.na(stimulus_condition)]),
                    baseline_quality = first(baseline_quality),
                    trial_quality = first(trial_quality),
                    overall_quality = first(overall_quality),
                    has_complete_phases = all(c("ITI_Baseline", "Squeeze", "Stimulus", "Response_Different") %in% trial_label),
                    rt = first(resp1RT[!is.na(resp1RT)]),
                    accuracy = first(iscorr[!is.na(iscorr)]),
                    .groups = "drop"
                )
        })
    
    if(nrow(all_trial_data) == 0) {
        cat("No trial data available for survival analysis\n")
        return(NULL)
    }
    
    # Define "success" as having all necessary components for DDM
    all_trial_data <- all_trial_data %>%
        mutate(
            ddm_success = !is.na(rt) & !is.na(accuracy) & has_complete_phases & 
                baseline_quality >= 0.5 & trial_quality >= 0.5,
            quality_category = case_when(
                overall_quality >= 0.8 ~ "High",
                overall_quality >= 0.6 ~ "Medium", 
                TRUE ~ "Low"
            )
        )
    
    # Summary statistics
    survival_summary <- all_trial_data %>%
        group_by(subject, task) %>%
        summarise(
            total_trials = n(),
            ddm_ready_trials = sum(ddm_success, na.rm = TRUE),
            survival_rate = mean(ddm_success, na.rm = TRUE),
            mean_baseline_quality = mean(baseline_quality, na.rm = TRUE),
            mean_trial_quality = mean(trial_quality, na.rm = TRUE),
            force_conditions = length(unique(force_condition[!is.na(force_condition)])),
            .groups = "drop"
        )
    
    cat("Trial survival rates by subject-task:\n")
    print(survival_summary)
    
    # Overall survival rates
    overall_rates <- all_trial_data %>%
        summarise(
            total_trials = n(),
            ddm_ready = sum(ddm_success, na.rm = TRUE),
            overall_survival_rate = mean(ddm_success, na.rm = TRUE),
            by_quality_high = mean(ddm_success[quality_category == "High"], na.rm = TRUE),
            by_quality_medium = mean(ddm_success[quality_category == "Medium"], na.rm = TRUE),
            by_quality_low = mean(ddm_success[quality_category == "Low"], na.rm = TRUE)
        )
    
    cat("\nOverall survival analysis:\n")
    cat(sprintf("Total trials analyzed: %d\n", overall_rates$total_trials))
    cat(sprintf("DDM-ready trials: %d (%.1f%%)\n", overall_rates$ddm_ready, 
                100 * overall_rates$overall_survival_rate))
    cat(sprintf("Survival by quality - High: %.1f%%, Medium: %.1f%%, Low: %.1f%%\n",
                100 * overall_rates$by_quality_high,
                100 * overall_rates$by_quality_medium, 
                100 * overall_rates$by_quality_low))
    
    return(list(
        trial_data = all_trial_data,
        summary = survival_summary,
        overall = overall_rates
    ))
}

# MAIN QC EXECUTION FUNCTION
run_complete_qc <- function() {
    cat("Starting comprehensive QC analysis...\n\n")
    
    # Run all QC modules
    qc1_results <- qc1_pupillometry_quality()
    if(is.null(qc1_results)) return(NULL)
    
    qc2_results <- qc2_merge_validation(qc1_results)
    qc3_results <- qc3_coverage_analysis(qc1_results)
    qc4_results <- qc4_ddm_readiness(qc1_results)
    qc5_results <- qc5_survival_analysis(qc1_results)
    
    # Compile final QC report
    cat("\n", paste(rep("=", 60), collapse = ""), "\n")
    cat("=== FINAL QC SUMMARY ===\n")
    cat("\n", paste(rep("=", 60), collapse = ""), "\n")
    
    # Overall data status
    total_subjects <- length(unique(names(qc2_results)))
    ready_for_ddm <- sum(sapply(qc4_results, function(x) x$ddm_viability > 0.5), na.rm = TRUE)
    
    cat(sprintf("Total subject-task combinations: %d\n", total_subjects))
    cat(sprintf("Ready for DDM analysis: %d (%.1f%%)\n", ready_for_ddm, 100 * ready_for_ddm / total_subjects))
    
    if(!is.null(qc5_results)) {
        cat(sprintf("Overall trial survival rate: %.1f%%\n", 100 * qc5_results$overall$overall_survival_rate))
    }
    
    # Recommendations
    cat("\nRECOMMENDATIONS:\n")
    if(ready_for_ddm / total_subjects > 0.8) {
        cat("✓ Data quality is excellent for DDM analysis\n")
    } else if(ready_for_ddm / total_subjects > 0.5) {
        cat("⚠ Data quality is adequate but could benefit from additional preprocessing\n")
    } else {
        cat("❌ Data quality is poor - consider improving pupillometry pipeline\n")
    }
    
    # Return comprehensive results
    return(list(
        pupil_quality = qc1_results,
        merge_validation = qc2_results,
        coverage_analysis = qc3_results,
        ddm_readiness = qc4_results,
        survival_analysis = qc5_results
    ))
}

# Execute complete QC
qc_results <- run_complete_qc()
