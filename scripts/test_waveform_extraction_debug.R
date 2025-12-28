# Test waveform extraction logic to find the bug

library(dplyr)
library(readr)
library(data.table)

REPO_ROOT <- normalizePath(".")
V7_ROOT <- file.path(REPO_ROOT, "quick_share_v7")
MERGED_FILE <- file.path(V7_ROOT, "merged", "BAP_triallevel_merged_v4.csv")
LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"

cat("Testing waveform extraction logic...\n\n")

# Load merged data
merged_v4 <- fread(MERGED_FILE)
waveform_trials <- merged_v4 %>%
  filter(auc_available == TRUE, !is.na(effort)) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, effort, isOddball) %>%
  slice(1:3)  # Test first 3 trials

cat("Testing with ", nrow(waveform_trials), " trials\n\n")

# Find matching flat file
flat_files <- list.files(LATEST_BUILD, pattern = paste0("^", waveform_trials$sub[1], "_", waveform_trials$task[1], "_flat\\.csv$"), full.names = TRUE)

if (length(flat_files) == 0) {
  stop("No matching flat file found")
}

cat("Using flat file: ", basename(flat_files[1]), "\n\n")

# Read and process like the actual code
df <- fread(flat_files[1], showProgress = FALSE, data.table = FALSE)

# Standardize columns
col_map <- list(
  sub = c("sub", "subject", "subject_id"),
  task = c("task", "task_name", "task_modality"),
  session_used = c("session_used", "ses", "session", "session_num"),
  run_used = c("run_used", "run", "run_num"),
  trial_index = c("trial_index", "trial_in_run_raw", "trial_in_run", "trial_num"),
  time = c("time", "time_ptb", "trial_pupilTime"),
  pupil = c("pupil", "pupilSize", "pupil_diameter"),
  trial_label = c("trial_label", "phase", "label")
)

for (target in names(col_map)) {
  candidates <- col_map[[target]]
  for (cand in candidates) {
    if (cand %in% names(df)) {
      df[[target]] <- df[[cand]]
      break
    }
  }
}

df <- df %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = as.integer(session_used),
    run_used = as.integer(run_used),
    trial_index = as.integer(trial_index),
    time = as.numeric(time),
    pupil = as.numeric(pupil)
  ) %>%
  mutate(pupil = if_else(is.nan(pupil), NA_real_, pupil)) %>%
  filter(session_used %in% c(2L, 3L))

cat("Flat file loaded: ", nrow(df), " rows\n")
cat("Columns: ", paste(names(df), collapse = ", "), "\n\n")

# Check if seg_start_rel_used exists
if ("seg_start_rel_used" %in% names(df)) {
  cat("✓ seg_start_rel_used column found\n")
  cat("  Sample values: ", paste(head(unique(df$seg_start_rel_used), 5), collapse = ", "), "\n\n")
} else {
  cat("✗ seg_start_rel_used column NOT found\n\n")
}

# Derive trial_in_run
if ("trial_in_run_raw" %in% names(df)) {
  df$trial_in_run <- as.integer(df$trial_in_run_raw)
} else {
  df$trial_in_run <- ((df$trial_index - 1) %% 30) + 1
}

# Get trial keys
trial_keys_flat <- df %>% 
  distinct(sub, task, session_used, run_used)

# Match trials
trial_matches <- waveform_trials %>%
  inner_join(trial_keys_flat, by = c("sub", "task", "session_used", "run_used"))

cat("Trial matches: ", nrow(trial_matches), "\n\n")

if (nrow(trial_matches) == 0) {
  stop("No matching trials found")
}

# Add trial_index_per_run
df$trial_index_per_run <- df$trial_in_run

# Join and test extraction
test_trial <- df %>%
  inner_join(trial_matches, by = c("sub", "task", "session_used", "run_used", 
                                   "trial_index_per_run" = "trial_index")) %>%
  filter(trial_in_run == trial_matches$trial_index[1]) %>%
  slice(1:100)  # Just test first 100 rows

cat("Testing trial extraction for trial_index ", trial_matches$trial_index[1], ":\n")
cat("  Rows: ", nrow(test_trial), "\n")
cat("  Columns in test_trial: ", paste(names(test_trial), collapse = ", "), "\n")

# Check seg_start_rel_used availability
if ("seg_start_rel_used" %in% names(test_trial)) {
  cat("  ✓ seg_start_rel_used available in test_trial\n")
  seg_start_rel <- first(test_trial$seg_start_rel_used[!is.na(test_trial$seg_start_rel_used)])
  cat("  seg_start_rel value: ", seg_start_rel, "\n")
  
  # Test calculation
  squeeze_onset <- min(test_trial$time, na.rm = TRUE) - seg_start_rel
  t_rel <- test_trial$time - squeeze_onset
  cat("  Computed t_rel range: ", min(t_rel, na.rm = TRUE), " to ", max(t_rel, na.rm = TRUE), "\n")
  cat("  Expected range: ", seg_start_rel, " to ~7.7\n")
  
  wave_mask <- t_rel >= -0.5 & t_rel <= 7.7
  cat("  Samples in wave_mask: ", sum(wave_mask), "\n")
} else {
  cat("  ✗ seg_start_rel_used NOT available in test_trial\n")
  cat("  This is the bug! The column is not preserved through the join/grouping.\n")
}

