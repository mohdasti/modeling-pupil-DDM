# R/extract_design_qa.R
# Extract trial exclusion counts, decision-coding mismatches, subject inclusion stats, MVC compliance
# Output 4 CSVs + 1 MD summary

source("R/_helpers_extract.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(glue)
})

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

dd <- safe_read_csv(DATA_PATH) |> ensure_decision()

# If raw (unfiltered) flags exist, compute; otherwise infer from RT
excl <- dd |>
  mutate(
    flag_low_rt  = ifelse(!is.na(rt) & rt < 0.25, 1L, 0L),
    flag_high_rt = ifelse(!is.na(rt) & rt > 3.0, 1L, 0L),
    flag_na      = ifelse(is.na(rt) | is.na(decision), 1L, 0L)
  ) |>
  group_by(task, effort_condition, difficulty_level) |>
  summarise(
    n = n(),
    n_low = sum(flag_low_rt),
    n_high = sum(flag_high_rt),
    n_na  = sum(flag_na),
    .groups = "drop"
  ) |>
  mutate(
    pct_low = n_low / n,
    pct_high = n_high / n,
    pct_na = n_na / n
  )

write_clean(excl, "output/publish/qa_trial_exclusions.csv")

# Decision coding audit (if any comparison column exists)
cand <- c("correct", "iscorr", "is_correct", "accuracy", "acc")
have <- cand[cand %in% names(dd)]

audit <- if (length(have)) {
  comp <- have[1]
  dd |>
    mutate(
      decision2 = as.integer(.data[[comp]]),
      mismatch = as.integer(decision != decision2)
    ) |>
    summarise(
      n = n(),
      mismatches = sum(mismatch, na.rm = TRUE),
      mismatch_rate = mismatches / n,
      .groups = "drop"
    )
} else {
  tibble(n = nrow(dd), mismatches = NA_integer_, mismatch_rate = NA_real_)
}

write_clean(audit, "output/publish/qa_decision_coding_audit.csv")

# Subject inclusion: trials per cell + overall accuracy; flag sub-chance
subsum <- dd |>
  group_by(subject_id) |>
  summarise(
    n_trials = n(),
    acc_overall = mean(decision, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(sub_chance_flag = acc_overall <= 0.55)

write_clean(subsum, "output/publish/qa_subject_inclusion.csv")

# Per cell counts (for inclusion rule transparency)
cell_counts <- dd |>
  group_by(subject_id, task, effort_condition, difficulty_level) |>
  summarise(n = n(), acc = mean(decision, na.rm = TRUE), .groups = "drop")

write_clean(cell_counts, "output/publish/qa_subject_cell_counts.csv")

# MVC compliance (if gf_trPer present)
mvc <- if ("gf_trPer" %in% names(dd)) {
  dd |>
    group_by(effort_condition) |>
    summarise(
      median_force = median(gf_trPer, na.rm = TRUE),
      q25 = quantile(gf_trPer, 0.25, na.rm = TRUE),
      q75 = quantile(gf_trPer, 0.75, na.rm = TRUE),
      .groups = "drop"
    )
} else {
  tibble(note = "gf_trPer not found; using effort_condition labels as manipulation only.")
}

write_clean(mvc, "output/publish/qa_mvc_compliance.csv")

# MD summary
md <- glue(
  "## Design & Data QA Summary

- Trials: {nrow(dd)}, Subjects: {n_distinct(dd$subject_id)}

- Exclusion (inferred): see qa_trial_exclusions.csv (columns pct_low, pct_high, pct_na).

- Decision coding audit: see qa_decision_coding_audit.csv (mismatch_rate).

- Subject inclusion: see qa_subject_inclusion.csv (sub_chance_flag).

- MVC compliance: see qa_mvc_compliance.csv.
"
)

writeLines(md, "output/publish/qa_summary.md")
message("✓ wrote: output/publish/qa_summary.md")

cat("\n✓ Design QA extraction complete.\n")
cat("  Generated files:\n")
cat("    - output/publish/qa_trial_exclusions.csv\n")
cat("    - output/publish/qa_decision_coding_audit.csv\n")
cat("    - output/publish/qa_subject_inclusion.csv\n")
cat("    - output/publish/qa_subject_cell_counts.csv\n")
cat("    - output/publish/qa_mvc_compliance.csv\n")
cat("    - output/publish/qa_summary.md\n")


