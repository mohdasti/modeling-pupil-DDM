# R/check_decision_coding.R

# Verify decision coding by recomputing empirical accuracy per cell
# Abort if mismatch > 0.5% in any cell

suppressPackageStartupMessages({

  library(dplyr)

  library(readr)

})



PUBLISH_DIR <- "output/publish"

dir.create(PUBLISH_DIR, showWarnings = FALSE, recursive = TRUE)



# ---- Logging ----

log_msg <- function(...) {

  msg <- paste(..., collapse = " ")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  cat(sprintf("[%s] %s\n", timestamp, msg))

}



log_msg("================================================================================")

log_msg("START check_decision_coding.R")

log_msg("Working directory:", getwd())



# ---- Load data ----

data_path <- "data/analysis_ready/bap_ddm_ready.csv"

log_msg("Loading data:", data_path)

dd <- readr::read_csv(data_path, show_col_types = FALSE)



# ---- Derive decision column (same logic as fit scripts) ----

if (!"decision" %in% names(dd)) {

  log_msg("Column 'decision' not found; attempting to derive from alternatives...")

  if ("iscorr" %in% names(dd)) {

    dd$decision <- as.integer(dd$iscorr)

    log_msg("Derived 'decision' from 'iscorr'.")

  } else if ("correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$correct)

    log_msg("Derived 'decision' from 'correct'.")

  } else if ("is_correct" %in% names(dd)) {

    dd$decision <- as.integer(dd$is_correct)

    log_msg("Derived 'decision' from 'is_correct'.")

  } else if ("accuracy" %in% names(dd)) {

    dd$decision <- as.integer(dd$accuracy)

    log_msg("Derived 'decision' from 'accuracy'.")

  } else if ("acc" %in% names(dd)) {

    dd$decision <- as.integer(dd$acc)

    log_msg("Derived 'decision' from 'acc'.")

  } else {

    stop("ERROR: Could not find a column to derive 'decision'. Available columns: ", 

         paste(names(dd), collapse = ", "))

  }

}



# ---- Compute empirical accuracy per cell ----

dd <- dd %>%

  mutate(

    subject_id = factor(subject_id),

    task = factor(task),

    effort_condition = factor(effort_condition, levels = c("Low_5_MVC", "High_MVC")),

    difficulty_level = factor(difficulty_level, levels = c("Standard", "Hard", "Easy")),

    decision = as.integer(decision)

  )



cell_vars <- c("task", "effort_condition", "difficulty_level")

cells <- dd %>% 

  group_by(across(all_of(cell_vars))) %>% 

  summarise(

    n = n(),

    n_valid = sum(!is.na(decision) & !is.na(rt)),

    n_correct = sum(decision == 1, na.rm = TRUE),

    n_incorrect = sum(decision == 0, na.rm = TRUE),

    emp_accuracy = mean(decision, na.rm = TRUE),

    .groups = "drop"

  ) %>%

  mutate(

    pct_correct = (n_correct / n_valid) * 100,

    pct_incorrect = (n_incorrect / n_valid) * 100

  )



log_msg(sprintf("Computed empirical accuracy for %d cells", nrow(cells)))



# ---- Check for coding issues ----

log_msg("Checking for decision coding issues...")

log_msg("")

log_msg("Decision column summary:")

log_msg(sprintf("  Total trials: %d", nrow(dd)))

log_msg(sprintf("  Missing decision: %d", sum(is.na(dd$decision))))

log_msg(sprintf("  Decision == 1 (correct): %d (%.1f%%)", 

                sum(dd$decision == 1, na.rm = TRUE),

                mean(dd$decision == 1, na.rm = TRUE) * 100))

log_msg(sprintf("  Decision == 0 (incorrect): %d (%.1f%%)", 

                sum(dd$decision == 0, na.rm = TRUE),

                mean(dd$decision == 0, na.rm = TRUE) * 100))

log_msg(sprintf("  Decision not in {0, 1}: %d", 

                sum(!dd$decision %in% c(0, 1, NA), na.rm = TRUE)))



# ---- Check each cell for anomalies ----

issues <- cells %>%

  mutate(

    issue_none = n_valid == 0,

    issue_all_correct = n_incorrect == 0 & n_valid > 0,

    issue_all_incorrect = n_correct == 0 & n_valid > 0,

    issue_extreme = emp_accuracy < 0.01 | emp_accuracy > 0.99

  ) %>%

  filter(issue_none | issue_all_correct | issue_all_incorrect | issue_extreme)



if (nrow(issues) > 0) {

  log_msg("")

  log_msg("⚠️  WARNING: Found cells with potential issues:")

  print(issues)

  log_msg("")

}



# ---- Cross-check with alternative columns (if available) ----

check_cols <- c("iscorr", "correct", "is_correct", "accuracy", "acc")

available_check_cols <- check_cols[check_cols %in% names(dd)]



if (length(available_check_cols) > 0) {

  log_msg("")

  log_msg("Cross-checking decision column with alternative columns...")

  

  mismatches <- list()

  for (col in available_check_cols) {

    if (col %in% names(dd)) {

      alt_decision <- as.integer(dd[[col]])

      mismatch_idx <- !is.na(dd$decision) & !is.na(alt_decision) & (dd$decision != alt_decision)

      n_mismatch <- sum(mismatch_idx, na.rm = TRUE)

      pct_mismatch <- (n_mismatch / sum(!is.na(dd$decision) & !is.na(alt_decision))) * 100

      

      if (n_mismatch > 0) {

        log_msg(sprintf("  %s: %d mismatches (%.2f%% of trials)", col, n_mismatch, pct_mismatch))

        mismatches[[col]] <- list(n = n_mismatch, pct = pct_mismatch)

      } else {

        log_msg(sprintf("  %s: ✓ No mismatches", col))

      }

    }

  }

  

  # Check per-cell mismatches

  if (length(mismatches) > 0) {

    log_msg("")

    log_msg("Checking per-cell mismatches...")

    

    for (col in names(mismatches)) {

      if (mismatches[[col]]$pct > 0.5) {

        cell_mismatches <- dd %>%

          mutate(

            alt_decision = as.integer(.data[[col]]),

            mismatch = !is.na(decision) & !is.na(alt_decision) & (decision != alt_decision)

          ) %>%

          filter(mismatch) %>%

          group_by(across(all_of(cell_vars))) %>%

          summarise(

            n_mismatch = n(),

            n_total = n(),

            .groups = "drop"

          ) %>%

          mutate(pct_mismatch = (n_mismatch / n_total) * 100) %>%

          filter(pct_mismatch > 0.5)

        

        if (nrow(cell_mismatches) > 0) {

          log_msg(sprintf("  ⚠️  %s: Cells with >0.5%% mismatch:", col))

          print(cell_mismatches)

        }

      }

    }

  }

}



# ---- Cell-by-cell summary ----

log_msg("")

log_msg("================================================================================")

log_msg("Cell-by-cell accuracy summary:")

log_msg("")

print(cells %>% select(task, effort_condition, difficulty_level, n, emp_accuracy, pct_correct))



# ---- Save results ----

results_csv <- file.path(PUBLISH_DIR, "decision_coding_check.csv")

readr::write_csv(cells, results_csv)

log_msg("")

log_msg(sprintf("✓ Results saved: %s", results_csv))



# ---- Final verdict ----

max_issue_pct <- if (length(mismatches) > 0) {

  max(sapply(mismatches, function(x) x$pct))

} else {

  0

}



if (max_issue_pct > 0.5) {

  log_msg("")

  log_msg("❌ ABORT: Found >0.5% mismatch in decision coding!")

  log_msg(sprintf("   Maximum mismatch: %.2f%%", max_issue_pct))

  stop("Decision coding verification failed. Check logs above.")

} else {

  log_msg("")

  log_msg("✓ Decision coding verification PASSED")

  log_msg("   All cells have consistent decision coding (mismatch < 0.5%)")

}



log_msg("")

log_msg("================================================================================")

log_msg("COMPLETE")

