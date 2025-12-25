#!/usr/bin/env Rscript

# ============================================================================
# Prompt 5: Gap-Length Classification in Prestim Region
# ============================================================================
# Computes invalid segment durations (gaps) that overlap:
# A) fixation-only window (fixST to A/V_ST)
# B) old prestim window (3.25-3.75)
# Classifies gaps by duration: <=200ms, 200-500ms, >500ms
# Compares ADT vs VDT, effort, difficulty
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(purrr)
  library(tidyr)
})

cat("=== ANALYZE PRESTIM GAP LENGTHS ===\n")
cat("Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Configuration
processed_dir <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed"
qc_dir <- "data/qc"
dir.create(qc_dir, recursive = TRUE, showWarnings = FALSE)

output_file <- file.path(qc_dir, "prestim_gap_analysis.csv")
summary_file <- file.path(qc_dir, "prestim_gap_summary.csv")

# Discover flat files
flat_files_merged <- list.files(processed_dir, pattern = "_flat_merged\\.csv$", full.names = TRUE)
flat_files_reg    <- list.files(processed_dir, pattern = "_flat\\.csv$",        full.names = TRUE)

if (length(flat_files_merged) > 0) {
  flat_files <- flat_files_merged
} else {
  flat_files <- flat_files_reg
}

if (length(flat_files) == 0) {
  stop("ERROR: No flat files found in ", processed_dir)
}

cat("Found", length(flat_files), "flat file(s)\n\n")

# Helper function to find gaps (invalid segments)
find_gaps <- function(time, is_valid, window_start, window_end) {
  # Filter to window
  in_window <- !is.na(time) & time >= window_start & time <= window_end
  if (!any(in_window)) {
    return(tibble(gap_start = numeric(), gap_end = numeric(), gap_duration = numeric()))
  }
  
  time_window <- time[in_window]
  valid_window <- is_valid[in_window]
  
  # Sort by time
  ord <- order(time_window)
  time_window <- time_window[ord]
  valid_window <- valid_window[ord]
  
  # Find gaps (consecutive invalid samples)
  gaps <- tibble()
  in_gap <- FALSE
  gap_start <- NA_real_
  
  for (i in seq_along(time_window)) {
    if (!valid_window[i] && !in_gap) {
      # Start of gap
      in_gap <- TRUE
      gap_start <- time_window[i]
    } else if (valid_window[i] && in_gap) {
      # End of gap
      gap_end <- time_window[i-1]
      gap_duration <- gap_end - gap_start
      gaps <- bind_rows(gaps, tibble(
        gap_start = gap_start,
        gap_end = gap_end,
        gap_duration = gap_duration
      ))
      in_gap <- FALSE
    }
  }
  
  # Handle gap that extends to end of window
  if (in_gap) {
    gap_end <- time_window[length(time_window)]
    gap_duration <- gap_end - gap_start
    gaps <- bind_rows(gaps, tibble(
      gap_start = gap_start,
      gap_end = gap_end,
      gap_duration = gap_duration
    ))
  }
  
  gaps
}

# Classify gap duration
classify_gap <- function(duration) {
  case_when(
    duration <= 0.200 ~ "<=200ms",
    duration > 0.200 & duration <= 0.500 ~ "200-500ms",
    duration > 0.500 ~ ">500ms"
  )
}

cat("Processing files and computing gaps...\n")

gap_analysis_list <- map(flat_files, function(f) {
  cat("  Reading:", basename(f), "\n")
  df <- read_csv(f, show_col_types = FALSE, progress = FALSE)
  
  if (!all(c("time", "pupil") %in% names(df))) {
    return(tibble())
  }
  
  # Derive identifiers
  df <- df %>%
    mutate(
      sub = if ("sub" %in% names(.)) sub else if ("subject_id" %in% names(.)) as.character(subject_id) else NA_character_,
      task = if ("task" %in% names(.)) {
        dplyr::if_else(task == "aud", "ADT",
                       dplyr::if_else(task == "vis", "VDT", as.character(task)))
      } else if ("task_modality" %in% names(.)) {
        dplyr::case_when(
          task_modality == "aud" ~ "ADT",
          task_modality == "vis" ~ "VDT",
          TRUE ~ as.character(task_modality)
        )
      } else NA_character_,
      run = if ("run" %in% names(.)) run else if ("run_num" %in% names(.)) run_num else NA_integer_,
      trial_index = if ("trial_index" %in% names(.)) trial_index
      else if ("trial_in_run" %in% names(.)) trial_in_run
      else if ("trial" %in% names(.)) trial
      else if ("trial_num" %in% names(.)) trial_num
      else NA_integer_,
      gf_trPer = dplyr::coalesce(
        if ("gf_trPer" %in% names(.)) gf_trPer else NA_real_,
        if ("grip_targ_prop_mvc" %in% names(.)) grip_targ_prop_mvc else NA_real_
      ),
      stimLev = if ("stimLev" %in% names(.)) stimLev else if ("stim_level_index" %in% names(.)) stim_level_index else NA_real_,
      isOddball = if ("isOddball" %in% names(.)) isOddball else if ("stim_is_diff" %in% names(.)) as.integer(stim_is_diff) else NA_integer_
    ) %>%
    filter(!is.na(sub), !is.na(task), !is.na(run), !is.na(trial_index))
  
  if (nrow(df) == 0) {
    return(tibble())
  }
  
  # Mark invalid pupil
  df$pupil[df$pupil == 0] <- NA_real_
  df$is_valid <- !is.na(df$pupil)
  
  # Compute gaps per trial
  df %>%
    group_by(sub, task, run, trial_index) %>%
    summarise(
      subject_id = first(as.character(sub)),
      task = first(as.character(task)),
      run = first(run),
      trial_index = first(trial_index),
      
      # Effort and difficulty
      effort_condition = factor(case_when(
        first(gf_trPer) == 0.05 ~ "Low_5_MVC",
        first(gf_trPer) == 0.40 ~ "High_40_MVC",
        TRUE ~ NA_character_
      ), levels = c("Low_5_MVC", "High_40_MVC")),
      difficulty_level = factor(case_when(
        first(isOddball) == 0 ~ "Standard",
        first(isOddball) == 1 & first(stimLev) %in% c(8, 16, 0.06, 0.12) ~ "Hard",
        first(isOddball) == 1 & first(stimLev) %in% c(32, 64, 0.24, 0.48) ~ "Easy",
        TRUE ~ NA_character_
      ), levels = c("Standard", "Easy", "Hard")),
      
      # Window A: Fixation-only (fixST to A/V_ST = 3.25 to 3.75)
      gaps_fixation = list(find_gaps(time, is_valid, 3.25, 3.75)),
      
      # Window B: Old prestim (3.25 to 3.75) - same as fixation for now
      gaps_prestim_old = list(find_gaps(time, is_valid, 3.25, 3.75)),
      
      .groups = "drop"
    ) %>%
    mutate(
      # Extract gap information
      n_gaps_fixation = map_int(gaps_fixation, nrow),
      n_gaps_prestim_old = map_int(gaps_prestim_old, nrow),
      
      # Gap durations
      gap_durations_fixation = map(gaps_fixation, ~ .x$gap_duration),
      gap_durations_prestim_old = map(gaps_prestim_old, ~ .x$gap_duration)
    ) %>%
    select(-gaps_fixation, -gaps_prestim_old)
})

gap_analysis <- bind_rows(gap_analysis_list)

if (nrow(gap_analysis) == 0) {
  stop("ERROR: No gap analysis data produced.")
}

# Expand gap durations into individual rows
gap_expanded_list <- map(1:nrow(gap_analysis), function(i) {
  row <- gap_analysis[i, ]
  
  # Get gap durations for both windows
  gaps_fix <- row$gap_durations_fixation[[1]]
  gaps_prestim <- row$gap_durations_prestim_old[[1]]
  
  # Combine gaps (they're the same for now, but handle both)
  all_gaps <- unique(c(gaps_fix, gaps_prestim))
  all_gaps <- all_gaps[!is.na(all_gaps)]
  
  if (length(all_gaps) == 0) {
    return(tibble())
  }
  
  tibble(
    subject_id = row$subject_id,
    task = row$task,
    run = row$run,
    trial_index = row$trial_index,
    effort_condition = row$effort_condition,
    difficulty_level = row$difficulty_level,
    gap_duration = all_gaps,
    gap_category = classify_gap(all_gaps),
    window = "fixation_prestim"  # Both windows are the same
  )
})

gap_expanded <- bind_rows(gap_expanded_list)

# Summary: % gaps by category
gap_summary <- gap_expanded %>%
  group_by(task, effort_condition, difficulty_level, gap_category) %>%
  summarise(
    n_gaps = n(),
    mean_duration = mean(gap_duration, na.rm = TRUE),
    median_duration = median(gap_duration, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(task, effort_condition, difficulty_level) %>%
  mutate(
    total_gaps = sum(n_gaps),
    pct_gaps = round(100 * n_gaps / total_gaps, 1)
  ) %>%
  ungroup()

# Overall summary (across all conditions)
gap_summary_overall <- gap_expanded %>%
  group_by(task, gap_category) %>%
  summarise(
    n_gaps = n(),
    mean_duration = mean(gap_duration, na.rm = TRUE),
    median_duration = median(gap_duration, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  group_by(task) %>%
  mutate(
    total_gaps = sum(n_gaps),
    pct_gaps = round(100 * n_gaps / total_gaps, 1)
  ) %>%
  ungroup()

# Save results
write_csv(gap_expanded, output_file)
write_csv(gap_summary, summary_file)

cat("\n  ✓ Saved gap analysis to:", output_file, "\n")
cat("  ✓ Saved gap summary to:", summary_file, "\n\n")

# Print summary
cat("=== GAP LENGTH SUMMARY ===\n\n")
cat("Overall (by task):\n")
print(gap_summary_overall)

cat("\nBy effort and difficulty:\n")
print(gap_summary)

# Interpretation
cat("\n=== INTERPRETATION ===\n")
cat("Gap categories:\n")
cat("  <=200ms:  Likely blinks (can be interpolated)\n")
cat("  200-500ms: Possibly blinks or brief tracking loss\n")
cat("  >500ms:   Likely tracking loss (Gate A may need redesign)\n\n")

cat("If most gaps are <=200ms, blink interpolation is justified.\n")
cat("If many gaps are >500ms, it's tracking loss and Gate A must be redesigned.\n\n")

cat("=== ANALYSIS COMPLETE ===\n")
cat("Completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

