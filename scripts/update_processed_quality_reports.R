#!/usr/bin/env Rscript
# Update quality reports in BAP_processed directory
# Generates: BAP_pupillometry_data_quality_report.csv
#          : BAP_pupillometry_data_quality_detailed.txt

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

cat("================================================================================\n")
cat("UPDATING QUALITY REPORTS IN BAP_PROCESSED DIRECTORY\n")
cat("================================================================================\n\n")

processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
output_csv <- file.path(processed_dir, "BAP_pupillometry_data_quality_report.csv")
output_txt <- file.path(processed_dir, "BAP_pupillometry_data_quality_detailed.txt")

# Find all merged files
merged_files <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files <- list.files(processed_dir, pattern = "_flat\\.csv$", full.names = TRUE)

# Remove flat files that have merged versions
if(length(merged_files) > 0 && length(flat_files) > 0) {
  merged_ids <- gsub("_flat_merged\\.csv$", "", basename(merged_files))
  flat_ids <- gsub("_flat\\.csv$", "", basename(flat_files))
  flat_to_keep <- !flat_ids %in% merged_ids
  all_files <- c(merged_files, flat_files[flat_to_keep])
} else {
  all_files <- c(merged_files, flat_files)
}

cat(sprintf("Processing %d files...\n\n", length(all_files)))

# Process each file to extract quality metrics
quality_data <- list()

for(file_path in all_files) {
  filename <- basename(file_path)
  
  tryCatch({
    # Extract subject and task
    parts <- regmatches(filename, gregexpr("BAP\\d+|ADT|VDT", filename))[[1]]
    subject <- if(length(parts) > 0) parts[1] else NA
    task <- if(length(parts) > 1) parts[2] else NA
    
    # Read file (sample to get structure)
    df_sample <- read_csv(file_path, n_max = 1000, show_col_types = FALSE, progress = FALSE)
    
    # Check if we have trial_label column
    if(!"trial_label" %in% colnames(df_sample)) {
      cat(sprintf("Skipping %s: missing trial_label column\n", filename))
      next
    }
    
    # Read full file
    df <- read_csv(file_path, show_col_types = FALSE, progress = FALSE)
    
    # Extract session from filename or data
    session <- NA
    if("session" %in% colnames(df)) {
      session <- unique(df$session)[1]
    } else {
      # Try to extract from filename
      session_match <- regmatches(filename, regexpr("session\\d+", filename))
      if(length(session_match) > 0) {
        session <- as.numeric(gsub("session", "", session_match))
      } else {
        # Default session based on task
        session <- if(task == "ADT") 2 else if(task == "VDT") 3 else 2
      }
    }
    
    # Get unique trials
    unique_trials <- unique(df$trial_index[!is.na(df$trial_index)])
    total_trials <- length(unique_trials)
    
    # Count valid trials (trials with behavioral data if available)
    if("has_behavioral_data" %in% colnames(df)) {
      valid_trials <- length(unique(df$trial_index[df$has_behavioral_data == 1 & !is.na(df$trial_index)]))
    } else {
      valid_trials <- total_trials
    }
    
    # Get runs
    unique_runs <- unique(df$run[!is.na(df$run)])
    runs_processed <- length(unique_runs)
    
    # Calculate phase proportions
    phase_props <- df %>%
      filter(!is.na(trial_label)) %>%
      count(trial_label) %>%
      mutate(prop = n / sum(n)) %>%
      arrange(trial_label)
    
    # Create phase proportion vector (8 phases)
    phase_names <- c(
      "phase_1_ITI_Baseline",
      "phase_2_Squeeze", 
      "phase_3_Post_Squeeze_Blank",
      "phase_4_Pre_Stimulus_Fixation",
      "phase_5_Stimulus",
      "phase_6_Post_Stimulus_Fixation",
      "phase_7_Response_Different",
      "phase_8_Confidence"
    )
    
    # Map trial labels to phases
    label_to_phase <- c(
      "ITI_Baseline" = "phase_1_ITI_Baseline",
      "Squeeze" = "phase_2_Squeeze",
      "Post_Squeeze_Blank" = "phase_3_Post_Squeeze_Blank",
      "Pre_Stimulus_Fixation" = "phase_4_Pre_Stimulus_Fixation",
      "Stimulus" = "phase_5_Stimulus",
      "Post_Stimulus_Fixation" = "phase_6_Post_Stimulus_Fixation",
      "Response_Different" = "phase_7_Response_Different",
      "Confidence" = "phase_8_Confidence"
    )
    
    # Initialize phase proportions
    phase_proportions <- setNames(rep(0, length(phase_names)), phase_names)
    
    # Fill in actual proportions
    for(i in 1:nrow(phase_props)) {
      label <- phase_props$trial_label[i]
      prop <- phase_props$prop[i]
      
      # Try to match label to phase
      phase_key <- names(label_to_phase)[sapply(names(label_to_phase), function(x) grepl(x, label, ignore.case = TRUE))]
      if(length(phase_key) > 0) {
        phase_name <- label_to_phase[phase_key[1]]
        phase_proportions[phase_name] <- prop
      }
    }
    
    # Store results
    quality_data[[filename]] <- list(
      subject = subject,
      task = task,
      session = session,
      total_trials = total_trials,
      valid_trials = valid_trials,
      valid_trial_proportion = if(total_trials > 0) valid_trials / total_trials else 0,
      runs_processed = runs_processed,
      phase_proportions = phase_proportions
    )
    
  }, error = function(e) {
    cat(sprintf("Error processing %s: %s\n", filename, e$message))
  })
}

# Convert to data frame
quality_df <- bind_rows(lapply(quality_data, function(x) {
  tibble(
    subject = x$subject,
    task = x$task,
    session = x$session,
    total_trials = x$total_trials,
    valid_trials = x$valid_trials,
    valid_trial_proportion = x$valid_trial_proportion,
    runs_processed = x$runs_processed,
    phase_1_ITI_Baseline_proportion = x$phase_proportions["phase_1_ITI_Baseline"],
    phase_2_Squeeze_proportion = x$phase_proportions["phase_2_Squeeze"],
    phase_3_Post_Squeeze_Blank_proportion = x$phase_proportions["phase_3_Post_Squeeze_Blank"],
    phase_4_Pre_Stimulus_Fixation_proportion = x$phase_proportions["phase_4_Pre_Stimulus_Fixation"],
    phase_5_Stimulus_proportion = x$phase_proportions["phase_5_Stimulus"],
    phase_6_Post_Stimulus_Fixation_proportion = x$phase_proportions["phase_6_Post_Stimulus_Fixation"],
    phase_7_Response_Different_proportion = x$phase_proportions["phase_7_Response_Different"],
    phase_8_Confidence_proportion = x$phase_proportions["phase_8_Confidence"]
  )
})) %>%
  arrange(subject, task)

# Write CSV file
write_csv(quality_df, output_csv)
cat(sprintf("✓ Updated CSV report: %s\n", output_csv))
cat(sprintf("  Rows: %d\n", nrow(quality_df)))

# Generate text report
total_sessions <- nrow(quality_df)
total_trials <- sum(quality_df$total_trials, na.rm = TRUE)
total_valid_trials <- sum(quality_df$valid_trials, na.rm = TRUE)
overall_valid_rate <- if(total_trials > 0) (total_valid_trials / total_trials) * 100 else 0

txt_content <- c(
  "BAP PUPILLOMETRY DATA QUALITY REPORT",
  "====================================",
  "",
  sprintf("Generated: %s", format(Sys.time(), "%d-%b-%Y %H:%M:%S")),
  "",
  "OVERALL SUMMARY:",
  sprintf("Total sessions processed: %d", total_sessions),
  sprintf("Total trials processed: %d", total_trials),
  sprintf("Overall valid trial rate: %.1f%%", overall_valid_rate),
  "",
  "BY SESSION:",
  "Subject\tTask\tSession\tTrials\tValid\tRate\tRuns"
)

# Add session details
for(i in 1:nrow(quality_df)) {
  row <- quality_df[i, ]
  rate <- if(row$total_trials > 0) (row$valid_trials / row$total_trials) * 100 else 0
  txt_content <- c(txt_content,
    sprintf("%s\t%s\t%d\t%d\t%d\t%.1f%%\t%d",
            row$subject, row$task, row$session,
            row$total_trials, row$valid_trials, rate, row$runs_processed)
  )
}

# Write text file
writeLines(txt_content, output_txt)
cat(sprintf("✓ Updated text report: %s\n", output_txt))

cat("\n================================================================================\n")
cat("QUALITY REPORTS UPDATED\n")
cat("================================================================================\n\n")

cat("Summary:\n")
cat(sprintf("  Total sessions: %d\n", total_sessions))
cat(sprintf("  Total trials: %d\n", total_trials))
cat(sprintf("  Valid trial rate: %.1f%%\n", overall_valid_rate))
cat("\n")









