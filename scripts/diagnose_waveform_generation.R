# Quick diagnostic to check why waveform generation might have failed

library(dplyr)
library(readr)
library(data.table)

REPO_ROOT <- normalizePath(".")
V7_ROOT <- file.path(REPO_ROOT, "quick_share_v7")
MERGED_FILE <- file.path(V7_ROOT, "merged", "BAP_triallevel_merged_v4.csv")
LATEST_BUILD <- "/Users/mohdasti/Documents/LC-BAP/BAP/BAP_Pupillometry/BAP/BAP_processed/build_20251225_154443"

cat("Diagnosing waveform generation issue...\n\n")

# Check merged file
if (!file.exists(MERGED_FILE)) {
  stop("Merged file not found: ", MERGED_FILE)
}

merged_v4 <- fread(MERGED_FILE)
cat("1. Merged file loaded: ", nrow(merged_v4), " trials\n")

# Check AUC-ready trials
waveform_trials <- merged_v4 %>%
  filter(auc_available == TRUE, !is.na(effort)) %>%
  select(trial_uid, sub, task, session_used, run_used, trial_index, effort, isOddball)

cat("2. AUC-ready trials (auc_available & has effort): ", nrow(waveform_trials), "\n")
if (nrow(waveform_trials) == 0) {
  cat("   ERROR: No AUC-ready trials found!\n")
  quit(status = 1)
}

# Check flat files
flat_files <- list.files(
  LATEST_BUILD,
  pattern = ".*_(ADT|VDT)_flat\\.csv$",
  full.names = TRUE
)

cat("3. Flat files in build directory: ", length(flat_files), "\n")
if (length(flat_files) == 0) {
  cat("   ERROR: No flat files found!\n")
  quit(status = 1)
}

# Check one flat file structure
cat("\n4. Checking one flat file structure...\n")
sample_file <- flat_files[1]
df_sample <- fread(sample_file, nrows = 1000, data.table = FALSE)

cat("   Columns in flat file: ", paste(names(df_sample), collapse = ", "), "\n")
cat("   Required columns check:\n")

required_cols <- c("sub", "task", "session_used", "run_used", "trial_index", "time", "pupil")
col_map <- list(
  sub = c("sub", "subject", "subject_id"),
  task = c("task", "task_name", "task_modality"),
  session_used = c("session_used", "ses", "session", "session_num"),
  run_used = c("run_used", "run", "run_num"),
  trial_index = c("trial_index", "trial_in_run_raw", "trial_in_run", "trial_num"),
  time = c("time", "time_ptb", "trial_pupilTime"),
  pupil = c("pupil", "pupilSize", "pupil_diameter")
)

for (target in names(col_map)) {
  found <- FALSE
  for (cand in col_map[[target]]) {
    if (cand %in% names(df_sample)) {
      cat("     ✓ ", target, " -> ", cand, "\n", sep = "")
      found <- TRUE
      break
    }
  }
  if (!found) {
    cat("     ✗ ", target, " NOT FOUND\n", sep = "")
  }
}

# Check if trial matching would work
cat("\n5. Checking trial matching...\n")
df_sample <- df_sample %>%
  mutate(
    sub = as.character(sub),
    task = as.character(task),
    session_used = if("session_used" %in% names(.)) session_used else if("ses" %in% names(.)) ses else NA_integer_,
    run_used = if("run_used" %in% names(.)) run_used else if("run" %in% names(.)) run else NA_integer_
  )

unique_keys_flat <- df_sample %>%
  distinct(sub, task, session_used, run_used) %>%
  filter(!is.na(session_used), !is.na(run_used))

cat("   Unique (sub, task, session, run) in sample file: ", nrow(unique_keys_flat), "\n")

waveform_trials_keys <- waveform_trials %>%
  distinct(sub, task, session_used, run_used)

matches <- inner_join(unique_keys_flat, waveform_trials_keys, 
                      by = c("sub", "task", "session_used", "run_used"))
cat("   Matching keys: ", nrow(matches), "\n")

if (nrow(matches) == 0) {
  cat("   ⚠ WARNING: No matching keys found! This would cause waveform generation to fail.\n")
}

cat("\n6. Recommendation: Re-run make_quick_share_v7.R and watch for:\n")
cat("   - 'Processing X AUC-ready trials for waveforms...' message\n")
cat("   - '⚠ No waveform data extracted' warning\n")
cat("   - Any error messages during waveform processing\n\n")

