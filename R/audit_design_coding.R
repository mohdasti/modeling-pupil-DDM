suppressPackageStartupMessages({
  library(dplyr); library(readr); library(stringr); library(tidyr)
})

# ---- config ----
DATA <- "data/analysis_ready/bap_ddm_ready.csv"
OUT  <- "output/publish/audit"
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(x,y) if (is.null(x) || length(x)==0) y else x
writemd <- function(path, txt) { writeLines(txt, path); message("Wrote: ", path) }

stamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log <- c(); catlog <- function(...) { log <<- c(log, paste0(...)) }

# ---- load ----
dd <- read_csv(DATA, show_col_types = FALSE)

# ---- basic columns ----
have <- function(nm) nm %in% names(dd)
cand_acc <- c("decision","correct","is_correct","accuracy","acc","iscorr")
acc_col <- cand_acc[cand_acc %in% names(dd)][1] %||% NA_character_

if (is.na(acc_col)) stop("No accuracy/decision column found. Expected one of: ", paste(cand_acc, collapse=", "))

# standardize columns
dd <- dd %>% mutate(
  subject_id = factor(.data$subject_id),
  task = factor(.data$task),
  effort_condition = factor(.data$effort_condition, levels=c("Low_5_MVC","High_MVC")),
  difficulty_level = factor(.data$difficulty_level, levels=c("Standard","Hard","Easy")),
  rt = as.numeric(.data$rt),
  decision = if (have("decision")) as.integer(.data$decision) else as.integer(.data[[acc_col]])
)

# ---- sanity: counts ----
cell_counts <- dd %>%
  count(task, effort_condition, difficulty_level, name="n")
write_csv(cell_counts, file.path(OUT, "cell_counts.csv"))

# ---- empirical accuracy by cell ----
emp_acc <- dd %>%
  group_by(task, effort_condition, difficulty_level) %>%
  summarise(emp_acc = mean(decision, na.rm=TRUE), n=n(), .groups="drop")

# If a separate correctness exists, compare
possible_truth <- setdiff(c("correct","is_correct","accuracy","acc","iscorr"), "decision")
truth_col <- possible_truth[possible_truth %in% names(dd)][1] %||% NA_character_

if (!is.na(truth_col)) {
  comp <- dd %>%
    mutate(truth = as.integer(.data[[truth_col]])) %>%
    group_by(task, effort_condition, difficulty_level) %>%
    summarise(
      emp_acc_from_dec = mean(decision, na.rm=TRUE),
      emp_acc_from_truth = mean(truth, na.rm=TRUE),
      abs_diff = abs(emp_acc_from_dec - emp_acc_from_truth),
      n = n(), .groups="drop"
    )
  write_csv(comp, file.path(OUT, "decision_coding_check.csv"))
} else {
  # fall back: just write the emp_acc we have
  write_csv(emp_acc, file.path(OUT, "decision_coding_check.csv"))
}

# ---- RT floor audit ----
floor_target <- 0.250
rt_summary <- dd %>%
  summarise(
    n = n(),
    min_rt = min(rt, na.rm=TRUE),
    q01 = quantile(rt, 0.01, na.rm=TRUE),
    q05 = quantile(rt, 0.05, na.rm=TRUE),
    q10 = quantile(rt, 0.10, na.rm=TRUE),
    median = median(rt, na.rm=TRUE),
    mean = mean(rt, na.rm=TRUE),
    max_rt = max(rt, na.rm=TRUE),
    frac_250_260 = mean(rt >= 0.250 & rt < 0.260, na.rm=TRUE),
    n_lt_floor = sum(rt < floor_target, na.rm=TRUE)
  )
write_csv(rt_summary, file.path(OUT, "rt_floor_check_overall.csv"))

rt_by_cell <- dd %>%
  group_by(task, effort_condition, difficulty_level) %>%
  summarise(
    n=n(),
    min_rt=min(rt, na.rm=TRUE),
    frac_250_260 = mean(rt >= 0.250 & rt < 0.260, na.rm=TRUE),
    median=median(rt, na.rm=TRUE),
    mean=mean(rt, na.rm=TRUE),
    max_rt=max(rt, na.rm=TRUE),
    .groups="drop"
  )
write_csv(rt_by_cell, file.path(OUT, "rt_floor_check_by_cell.csv"))

# Heuristic flags
flags <- list()
if (rt_summary$n_lt_floor > 0) flags <- c(flags, "Some RT < 250 ms present after filtering.")
if (rt_summary$frac_250_260 > 0.10) flags <- c(flags, "High mass between 250-260 ms; check double flooring/clamping.")
if (any(rt_by_cell$min_rt < 0.250)) flags <- c(flags, "Some cells have min RT < 250 ms.")
if (any(is.na(dd$rt))) flags <- c(flags, "NA RTs present.")

# ---- factor levels & contrasts ----
fc_txt <- c(
  paste0("task levels: ", paste(levels(dd$task), collapse=", ")),
  paste0("effort_condition levels: ", paste(levels(dd$effort_condition), collapse=", ")),
  paste0("difficulty_level levels: ", paste(levels(dd$difficulty_level), collapse=", "))
)
con_txt <- c(
  "contrasts(task):", capture.output(print(contrasts(dd$task))),
  "contrasts(effort_condition):", capture.output(print(contrasts(dd$effort_condition))),
  "contrasts(difficulty_level):", capture.output(print(contrasts(dd$difficulty_level)))
)
writeLines(c(fc_txt, "", con_txt), file.path(OUT, "factor_contrasts.txt"))

# ---- fixed-effect design columns for DRIFT formula ----
# We emulate your latest drift fixed-effects: difficulty_level * task + effort_condition
# model.matrix ignores random effects; that's fine (we only need fixed columns).
X <- model.matrix(~ difficulty_level * task + effort_condition, data = dd)
writeLines(colnames(X), file.path(OUT, "drift_model_matrix_cols.txt"))

# ---- quick expected-prior sanity on link scales (informational text) ----
prior_txt <- c(
  "Link-scale prior sanity (informational):",
  "bs (log link): center log(1.7) ~ 0.531, sd ~ 0.30 (natural ~ 1.7)",
  "ndt (log link): center log(0.23) ~ -1.469, sd ~ 0.12 (natural ~ 0.23 s)",
  "bias (logit link): center 0 ~ 0.5 (no bias), sd ~ 0.5"
)
writeLines(prior_txt, file.path(OUT, "linkscale_prior_sanity.txt"))

# ---- summary markdown ----
md <- c(
  "# Design-Coding Audit Summary",
  paste0("- Timestamp: ", stamp),
  "",
  "## Data & columns",
  paste0("- Rows: ", nrow(dd), "; Subjects: ", length(unique(dd$subject_id))),
  paste0("- Found decision column: `", acc_col, "`; saved comparison to `decision_coding_check.csv`."),
  "",
  "## RT floor checks",
  readr::format_tsv(rt_summary),
  "- Per-cell floor summary saved to `rt_floor_check_by_cell.csv`.",
  "",
  "## Factor levels & contrasts",
  paste0("- See `factor_contrasts.txt`."),
  paste0("- Drift fixed-effect columns in `drift_model_matrix_cols.txt`."),
  "",
  "## Flags",
  if (length(flags)==0) "- No obvious red flags." else paste0("* ", paste(flags, collapse="\n* ")),
  "",
  "## Next steps",
  "- If flags are empty/minor, you can proceed to finalize and publish.",
  "- If flags mention clamping or decision mismatch, fix upstream encoding/filtering and rerun."
)

writemd(file.path(OUT, "audit_summary.md"), paste(md, collapse="\n"))

message("Audit complete. Outputs in: ", OUT)

