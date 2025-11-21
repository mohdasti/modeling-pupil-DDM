# R/extract_loo_summary.R
# Summarize ELPD, ΔELPD, stacking/PBMA (if present), and count Pareto-k > 0.7
# One tidy table for the model comparison paragraph

source("R/_helpers_extract.R")

suppressPackageStartupMessages({
  library(dplyr)
})

# Set working directory if needed
if (basename(getwd()) == "R") {
  setwd("..")
}

# Try to find LOO file (check multiple possible locations)
loo_paths <- c(
  LOO_PATH,
  "output/publish/table1_loo_primary.csv",
  "output/publish/loo_difficulty_all.csv",
  "loo_difficulty_all.csv"
)

loo <- NULL
for (path in loo_paths) {
  if (file.exists(path)) {
    loo <- safe_read_csv(path)
    cat("Loaded LOO file from:", path, "\n")
    break
  }
}

if (is.null(loo)) {
  stop("Could not find LOO file. Tried: ", paste(loo_paths, collapse = ", "))
}

# Expect columns: model, elpd, se, p_loo, weight_stack, weight_pbma, elpd_diff_from_best, se_diff
# Arrange by ELPD (descending, best first)
loo <- loo %>%
  arrange(desc(elpd))

# If elpd_diff_from_best is not present, compute it
if (!"elpd_diff_from_best" %in% names(loo)) {
  best_elpd <- max(loo$elpd, na.rm = TRUE)
  loo$elpd_diff_from_best <- loo$elpd - best_elpd
}

# Count Pareto-k > 0.7 if available
pareto_k_count <- NA_integer_
pareto_k_note <- ""

if ("pareto_k_max" %in% names(loo)) {
  pareto_k_count <- sum(loo$pareto_k_max > 0.7, na.rm = TRUE)
  pareto_k_note <- paste0(
    "Max pareto_k: ", sprintf("%.3f", max(loo$pareto_k_max, na.rm = TRUE)),
    "; Count > 0.7: ", pareto_k_count
  )
} else if (any(grepl("pareto", names(loo), ignore.case = TRUE))) {
  # Try to find any pareto-k column
  pareto_cols <- names(loo)[grepl("pareto", names(loo), ignore.case = TRUE)]
  if (length(pareto_cols) > 0) {
    pareto_k_max <- apply(loo[, pareto_cols, drop = FALSE], 1, max, na.rm = TRUE)
    pareto_k_count <- sum(pareto_k_max > 0.7, na.rm = TRUE)
    pareto_k_note <- paste0(
      "Max pareto_k: ", sprintf("%.3f", max(pareto_k_max, na.rm = TRUE)),
      "; Count > 0.7: ", pareto_k_count
    )
  } else {
    pareto_k_note <- "Pareto-k by-point file not provided; skip."
  }
} else {
  pareto_k_note <- "Pareto-k by-point file not provided; skip."
}

write_clean(loo, "output/publish/loo_summary_clean.csv")

# Create markdown summary
top_model <- loo$model[1]
top_elpd <- loo$elpd[1]
top_se <- loo$se[1]

md <- paste0(
  "## LOO Summary\n",
  "Top model: ", top_model, "\n",
  "ELPD: ", sprintf("%.2f", top_elpd), " (SE: ", sprintf("%.2f", top_se), ")\n",
  "\n",
  pareto_k_note, "\n"
)

writeLines(md, "output/publish/loo_summary.md")
message("✓ LOO summary written.")

cat("\n✓ LOO summary extraction complete.\n")
cat("  Generated files:\n")
cat("    - output/publish/loo_summary_clean.csv\n")
cat("    - output/publish/loo_summary.md\n")
cat("\n  Summary:\n")
cat("    - Top model: ", top_model, "\n")
cat("    - ELPD: ", sprintf("%.2f", top_elpd), " (SE: ", sprintf("%.2f", top_se), ")\n")
if (!is.na(pareto_k_count)) {
  cat("    - ", pareto_k_note, "\n")
} else {
  cat("    - ", pareto_k_note, "\n")
}

