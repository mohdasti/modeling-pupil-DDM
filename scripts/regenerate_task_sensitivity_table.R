#!/usr/bin/env Rscript
# Regenerate task_sensitivity_comparison.csv from current brms fits.
suppressPackageStartupMessages(library(brms))

run_dir <- Sys.getenv("DDM_RUN_DIR", "output/ddm_refits/runs/20260226_092110")
primary_path <- file.path(run_dir, "models/additive__probe_onset_locked__thr0.20.rds")
task_path <- file.path(run_dir, "models/task_sensitivity__probe_onset_locked__thr0.20.rds")
stopifnot(file.exists(primary_path), file.exists(task_path))

primary <- readRDS(primary_path)
task_sens <- readRDS(task_path)
fixef_primary <- brms::fixef(primary, summary = TRUE)
fixef_task_sens <- brms::fixef(task_sens, summary = TRUE)

eff_term <- intersect(
  c("effort_conditionhigh", "effort_conditionHigh40MVC", "effort_conditionHigh_40_MVC"),
  rownames(fixef_primary)
)[1]
task_term <- intersect(c("taskVDT"), rownames(fixef_task_sens))[1]
int_term <- intersect(
  c("effort_conditionhigh:taskVDT", "effort_conditionHigh40MVC:taskVDT",
    "effort_conditionHigh_40_MVC:taskVDT"),
  rownames(fixef_task_sens)
)[1]

pick <- function(fe, term, col) {
  if (is.na(term) || !(term %in% rownames(fe))) return(NA_real_)
  fe[term, col]
}

task_comparison <- tibble::tibble(
  Parameter = c(
    "Effort → Drift (Primary)", "Effort → Drift (Task-Sens)",
    "Task → Drift", "Effort × Task → Drift"
  ),
  Estimate = c(
    pick(fixef_primary, eff_term, "Estimate"),
    pick(fixef_task_sens, eff_term, "Estimate"),
    pick(fixef_task_sens, task_term, "Estimate"),
    pick(fixef_task_sens, int_term, "Estimate")
  ),
  CI_lower = c(
    pick(fixef_primary, eff_term, "Q2.5"),
    pick(fixef_task_sens, eff_term, "Q2.5"),
    pick(fixef_task_sens, task_term, "Q2.5"),
    pick(fixef_task_sens, int_term, "Q2.5")
  ),
  CI_upper = c(
    pick(fixef_primary, eff_term, "Q97.5"),
    pick(fixef_task_sens, eff_term, "Q97.5"),
    pick(fixef_task_sens, task_term, "Q97.5"),
    pick(fixef_task_sens, int_term, "Q97.5")
  )
)

out <- file.path(run_dir, "tables/task_sensitivity_comparison.csv")
readr::write_csv(task_comparison, out)
cat("Wrote", out, "\n")
print(task_comparison)
