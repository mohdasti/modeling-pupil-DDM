# =========================================================================
# LOGGING AND VALIDATION UTILITIES
# =========================================================================
# Utility functions for logging and data validation in DDM pipeline
# =========================================================================

# -------------------------------------------------------------------------
# 1. log_step(msg)
# -------------------------------------------------------------------------
# Prints a timestamped message using message() not print()
# Format: [YYYY-mm-dd HH:MM:SS] <msg>
# -------------------------------------------------------------------------
log_step <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  message("[", timestamp, "] ", msg)
}

# -------------------------------------------------------------------------
# 2. assert_has_cols(df, cols, df_name)
# -------------------------------------------------------------------------
# Stops with a clear error if any required columns are missing
# -------------------------------------------------------------------------
assert_has_cols <- function(df, cols, df_name = deparse(substitute(df))) {
  missing_cols <- setdiff(cols, names(df))
  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns in '", df_name, "': ",
      paste(missing_cols, collapse = ", ")
    )
  }
  invisible(TRUE)
}

# -------------------------------------------------------------------------
# 3. assert_no_all_na(df, cols, df_name)
# -------------------------------------------------------------------------
# Stops if any of the specified columns are ALL NA
# -------------------------------------------------------------------------
assert_no_all_na <- function(df, cols, df_name = deparse(substitute(df))) {
  assert_has_cols(df, cols, df_name)
  for (col in cols) {
    if (all(is.na(df[[col]]))) {
      stop(
        "Column '", col, "' in '", df_name, "' contains only NA values"
      )
    }
  }
  invisible(TRUE)
}

# -------------------------------------------------------------------------
# 4. assert_no_na(df, cols, df_name)
# -------------------------------------------------------------------------
# Stops if ANY NA appears in the specified columns
# -------------------------------------------------------------------------
assert_no_na <- function(df, cols, df_name = deparse(substitute(df))) {
  assert_has_cols(df, cols, df_name)
  for (col in cols) {
    if (any(is.na(df[[col]]))) {
      n_na <- sum(is.na(df[[col]]))
      stop(
        "Column '", col, "' in '", df_name, "' contains ", n_na,
        " NA value(s). No NA values allowed."
      )
    }
  }
  invisible(TRUE)
}

# -------------------------------------------------------------------------
# 5. assert_reasonable_threshold_counts(count_df)
# -------------------------------------------------------------------------
# Validates threshold count data frame:
# - expects columns: threshold, n_trials
# - ensures threshold is numeric (not "0.20 s")
# - ensures n_trials are nonnegative
# - warns if n_trials are identical across thresholds (common symptom of
#   "not actually filtering")
# -------------------------------------------------------------------------
assert_reasonable_threshold_counts <- function(count_df) {
  # Check required columns
  assert_has_cols(count_df, c("threshold", "n_trials"), "count_df")
  
  # Check threshold is numeric
  if (!is.numeric(count_df$threshold)) {
    stop(
      "Column 'threshold' must be numeric. Found: ",
      class(count_df$threshold)[1],
      ". Did you pass strings like '0.20 s' instead of numbers?"
    )
  }
  
  # Check n_trials are nonnegative
  if (any(count_df$n_trials < 0, na.rm = TRUE)) {
    stop("Column 'n_trials' contains negative values")
  }
  
  # Warn if all n_trials are identical (symptom of not filtering)
  if (length(unique(count_df$n_trials)) == 1 && nrow(count_df) > 1) {
    warning(
      "All thresholds have identical n_trials (", unique(count_df$n_trials),
      "). This suggests thresholds may not be filtering trials correctly."
    )
  }
  
  invisible(TRUE)
}

# -------------------------------------------------------------------------
# 6. write_csv_logged(df, path)
# -------------------------------------------------------------------------
# Logs rows, cols, path, then writes with readr::write_csv()
# -------------------------------------------------------------------------
write_csv_logged <- function(df, path) {
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("readr package is required for write_csv_logged()")
  }
  
  n_rows <- nrow(df)
  n_cols <- ncol(df)
  
  log_step(paste0(
    "Writing CSV: ", n_rows, " rows, ", n_cols, " cols -> ", path
  ))
  
  readr::write_csv(df, path)
  invisible(path)
}
