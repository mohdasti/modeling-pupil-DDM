# Quick script to check if we need to copy latest data to analysis_ready
latest_file <- "/Users/mohdasti/Documents/LC-BAP/BAP/Nov2025/bap_beh_trialdata_v2.csv"
target_file <- "data/analysis_ready/bap_ddm_ready.csv"

if (file.exists(latest_file)) {
  cat("Latest data file found\n")
  cat("Checking if we should copy to analysis_ready...\n")
  
  if (!file.exists(target_file) || 
      file.mtime(latest_file) > file.mtime(target_file)) {
    cat("Latest data is newer or target doesn't exist\n")
    cat("NOTE: Data preprocessing may be needed to convert raw to analysis-ready format\n")
  } else {
    cat("Analysis-ready file is up to date\n")
  }
}
