# R/00_build_decision_upper_diff.R

# Set the upper boundary (dec=1) to the *response "different"* on every trial.
# This changes from accuracy coding (dec=1 = correct) to response-side coding (dec=1 = "different")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

in_csv  <- "data/analysis_ready/bap_ddm_ready.csv"
out_csv <- "data/analysis_ready/bap_ddm_ready_with_upper.csv"

# Ensure output directory exists
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

dd <- read_csv(in_csv, show_col_types = FALSE)

cat("Original data: ", nrow(dd), " trials\n")

# ---- 1) Infer response side from correctness + difficulty level ----

# The 'choice' column appears to be correctness (identical to iscorr), not response side.
# We need to infer response side from: correctness + difficulty level
# - Standard: correct = "same" (no change)
# - Easy: correct = "different" (change detected)  
# - Hard: correct = "different" (change detected, but harder)

check_col <- if ("iscorr" %in% names(dd)) "iscorr" else if ("decision" %in% names(dd)) "decision" else if ("choice" %in% names(dd) && all(dd$choice == dd$iscorr, na.rm=TRUE)) "iscorr" else NULL

if (is.null(check_col) || !"difficulty_level" %in% names(dd)) {
  stop("Need 'iscorr' (or 'decision') and 'difficulty_level' columns to infer response side")
}

cat("Inferring response side from correctness + difficulty level\n")
cat("Using correctness column: '", check_col, "'\n", sep="")

# Infer response side:
# - On Standard: correct (iscorr=1) → "same", incorrect (iscorr=0) → "different"
# - On Easy/Hard: correct (iscorr=1) → "different", incorrect (iscorr=0) → "same"
dd$response_label <- dplyr::case_when(
  dd$difficulty_level == "Standard" & dd[[check_col]] == 1 ~ "same",
  dd$difficulty_level == "Standard" & dd[[check_col]] == 0 ~ "different",
  dd$difficulty_level %in% c("Easy", "Hard") & dd[[check_col]] == 1 ~ "different",
  dd$difficulty_level %in% c("Easy", "Hard") & dd[[check_col]] == 0 ~ "same",
  TRUE ~ NA_character_
)

# Check for missing labels
n_missing <- sum(is.na(dd$response_label))
if (n_missing > 0) {
  warning("Found ", n_missing, " trials with missing response labels")
  cat("Missing response labels:", n_missing, "trials\n")
  cat("Unique values in ", resp_col, ": ", paste(unique(dd[[resp_col]][is.na(dd$response_label)])[1:5], collapse=", "), "\n", sep="")
}

# ---- 2) dec() boundary: upper=1 for "different", lower=0 for "same" ----

dd$dec_upper <- ifelse(dd$response_label == "different", 1L,
                  ifelse(dd$response_label == "same", 0L, NA_integer_))

# ---- 3) Quick audit: how often upper vs lower by condition ----

audit <- dd %>%
  filter(!is.na(dec_upper)) %>%
  count(task, effort_condition, difficulty_level, dec_upper) %>%
  tidyr::pivot_wider(names_from = dec_upper, values_from = n, values_fill = 0) %>%
  rename(n_lower = `0`, n_upper = `1`) %>%
  mutate(
    total = n_lower + n_upper,
    p_upper = round(n_upper / total, 3),
    p_lower = round(n_lower / total, 3)
  )

# ---- 4) Compare with old decision coding (if available) ----

check_col <- if ("iscorr" %in% names(dd)) "iscorr" else if ("decision" %in% names(dd)) "decision" else NULL

if (!is.null(check_col)) {
  comparison <- dd %>%
    filter(!is.na(dec_upper) & !is.na(.data[[check_col]])) %>%
    group_by(difficulty_level) %>%
    summarise(
      n = n(),
      p_correct_old = round(mean(.data[[check_col]]), 3),
      p_upper_new = round(mean(dec_upper), 3),
      p_lower_new = round(mean(1 - dec_upper), 3),
      .groups = "drop"
    )
  
  cat("\n=== Comparison: Old (correctness) vs New (response-side) ===\n")
  print(comparison)
  
  write_csv(comparison, "output/publish/decision_coding_comparison.csv")
}

# ---- 5) Write outputs ----

write_csv(dd, out_csv)
write_csv(audit, "output/publish/decision_upper_audit_diff.csv")

cat("\n✓ Wrote:", out_csv, "\n")
cat("✓ Audit table:", "output/publish/decision_upper_audit_diff.csv", "\n")
cat("\n=== Summary ===\n")
cat("Total trials:", nrow(dd), "\n")
cat("Trials with dec_upper=1 (different):", sum(dd$dec_upper == 1, na.rm=TRUE), "\n")
cat("Trials with dec_upper=0 (same):", sum(dd$dec_upper == 0, na.rm=TRUE), "\n")
cat("Missing:", sum(is.na(dd$dec_upper)), "\n")
cat("\n=== Response distribution by condition ===\n")
print(audit)

cat("\n\nNOTE: This changes the decision coding from accuracy-based to response-side.\n")
cat("Upper boundary (dec=1) = 'different' response\n")
cat("Lower boundary (dec=0) = 'same' response\n")
cat("This affects drift (v) and bias (z) interpretation:\n")
cat("  - v > 0: evidence toward 'different'\n")
cat("  - z > 0.5: bias toward 'different'\n")

