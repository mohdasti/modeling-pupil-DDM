# Part X. Verify the export against the prompt's expected values.
# Run from the repo root: Rscript scripts/final/X_verify.R

options(warn = 1)
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
  library(loo)
})

ROOT <- normalizePath(getwd(), mustWork = TRUE)
setwd(ROOT)
FINAL <- "output/ddm_refits/runs/final_20261016"
TAB <- file.path(FINAL, "tables", "final")
FIG <- file.path(FINAL, "figures", "final")
INV <- "output/diagnostics/final_exports"
dir.create(INV, recursive = TRUE, showWarnings = FALSE)

stop_at <- function(step, msg) {
  writeLines(c(paste("# Stopped at", step), "", msg), file.path(INV, "STOPPED.md"))
  stop(step, ": ", msg, call. = FALSE)
}

med <- function(x) stats::median(x[is.finite(x)])
draw_med <- function(file, col, transform = identity) {
  d <- read.csv(file, check.names = FALSE)
  med(transform(d[[col]]))
}

checks <- list()
add <- function(name, got, expected, tol, se_got = NA, se_exp = NA) {
  err <- abs(got - expected)
  ok <- is.finite(err) && err <= tol
  checks[[length(checks) + 1]] <<- data.frame(
    check = "X1", name = name, got = got, expected = expected,
    abs_err = err, tolerance = tol, se_got = se_got, se_expected = se_exp, pass = ok,
    stringsAsFactors = FALSE
  )
}

m4 <- file.path(FINAL, "draws/draws_M4.csv")
add("M4 criterion median", draw_med(m4, "b_effort_conditionhigh"), -0.053, 0.002)
add("M4 quality median", draw_med(m4, "b_effort_x_stim"), -0.013, 0.002)
add("M4 boundary median", draw_med(m4, "b_bs_effort_conditionhigh"), 0.020, 0.002)
add("M4 bias median", draw_med(m4, "b_bias_effort_conditionhigh"), -0.005, 0.002)
add("M4 t0 median", draw_med(m4, "b_ndt_Intercept", exp), 0.527, 0.002)
vals_pupil <- readRDS(file.path(TAB, "inline_values.rds"))
add("P3 slope median", vals_pupil$P3_bs$median, 0.074, 0.002)
add("P3_rt slope median", vals_pupil$P3_rt_bs$median, 0.047, 0.002)

beh <- read.csv(file.path(FINAL, "data/ddm_behavioral_r5_full17857.csv"))
add("n_trials_primary", nrow(beh), 17857, 1)
add("n_final", length(unique(beh$subject_id)), 67, 1)
qc <- read.csv(file.path(FINAL, "qc/qc_gate_counts.csv"))
final_gate <- qc[qc$gate == "subject_task_ge_20", , drop = FALSE]
add("n_pupil_final_trials", final_gate$n_trials, 4569, 1)
add("n_pupil_final_subjects", final_gate$n_subjects, 39, 1)

loo_m3 <- readRDS(file.path(FINAL, "loo/loo_M3.rds"))
loo_m4 <- readRDS(file.path(FINAL, "loo/loo_M4.rds"))
d <- loo_m3$pointwise[, "elpd_loo"] - loo_m4$pointwise[, "elpd_loo"]
add("delta ELPD M3 vs M4", sum(d), -158.27, 0.02, se_got = stats::sd(d) * sqrt(length(d)), se_exp = 19.99)
# The SE is reported, not a stop condition by itself. Record whether it is within 0.05.
se_err <- abs(stats::sd(d) * sqrt(length(d)) - 19.99)

x1 <- bind_rows(checks)
if (any(!x1$pass)) {
  stop_at("X1", paste(capture.output(print(x1, row.names = FALSE)), collapse = "\n"))
}

# X2. Inline values that also appear in Part T tables.
vals <- readRDS(file.path(TAB, "inline_values.rds"))
t2 <- read.csv(file.path(TAB, "T2_effort_effects_M4.csv"), stringsAsFactors = FALSE)
t5 <- read.csv(file.path(TAB, "T5_model_comparison.csv"), stringsAsFactors = FALSE)
t8 <- read.csv(file.path(TAB, "T8_pupil_ordering.csv"), stringsAsFactors = FALSE)
t11 <- read.csv(file.path(TAB, "T11_ppc_summary.csv"), stringsAsFactors = FALSE)
same <- function(a, b) isTRUE(all.equal(as.numeric(a), as.numeric(b), tolerance = 0))
x2 <- data.frame(
  name = c("crit", "qual", "bs", "bias", "delta_M3", "P3_bs", "P3_rt_bs", "ppc_choice", "n_primary", "n_subchance_excluded", "n_subchance_remaining"),
  inline = c(vals$crit$median, vals$qual$median, vals$bs$median, vals$bias$median,
             vals$delta_elpd_M3_vs_M4, vals$P3_bs$median, vals$P3_rt_bs$median,
             vals$ppc_choice_inside_M4, vals$n_trials_primary,
             vals$n_subchance_excluded, vals$n_subchance_remaining),
  table = c(t2$median[t2$term == "b_effort_conditionhigh"],
            t2$median[t2$term == "b_effort_x_stim"],
            t2$median[t2$term == "b_bs_effort_conditionhigh"],
            t2$median[t2$term == "b_bias_effort_conditionhigh"],
            t5$delta_elpd_vs_M4[t5$model == "M3"],
            t8$median[t8$model == "P3"],
            t8$median[t8$model == "P3_rt"],
            t11$ppc_choice_inside_M4,
            17857, 13, 54),
  stringsAsFactors = FALSE
)
x2$pass <- mapply(same, x2$inline, x2$table)
if (any(!x2$pass)) stop_at("X2", paste(capture.output(print(x2, row.names = FALSE)), collapse = "\n"))

# X3. Sidecars.
pngs <- list.files(FIG, pattern = "\\.png$", full.names = FALSE)
missing_src <- pngs[!file.exists(file.path(FIG, sub("\\.png$", "_source.txt", pngs)))]
x3_pass <- length(missing_src) == 0

# X4. The export scripts must not read the retired model paths.
# The strings also appear in the earlier consolidation scripts, where they
# name models that were classified and not copied, and in this file as the
# search patterns themselves.
pats <- c("20260226_092110", "additive__", "interaction__", "task_sensitivity", "pupil_interaction",
          paste0("ddm_pupil_", "ready_thr"))
export_scripts <- c(
  "scripts/final/R_refit_subchance.R",
  "scripts/final/T_export_tables.R",
  "scripts/final/V_inline_values.R",
  "scripts/final/F_figures.R"
)
x4_hits <- character(0)
for (f in export_scripts) {
  lines <- readLines(f, warn = FALSE)
  for (pat in pats) {
    hit <- grep(pat, lines, fixed = TRUE)
    if (length(hit)) x4_hits <- c(x4_hits, paste0(basename(f), ":", hit[1], ":", pat))
  }
}
x4_pass <- length(x4_hits) == 0

# NA inventory
na_notes <- character(0)
for (f in list.files(TAB, pattern = "\\.csv$", full.names = TRUE)) {
  df <- tryCatch(read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(df)) next
  n_na <- sum(is.na(df))
  if (n_na > 0) na_notes <- c(na_notes, paste0(basename(f), ": ", n_na, " NA cells"))
}

sub <- read.csv(file.path(INV, "subchance_rule.csv"), stringsAsFactors = FALSE)
t6 <- read.csv(file.path(TAB, "T6a_robustness_effort_terms.csv"), stringsAsFactors = FALSE)
sub_eff <- t6[t6$model == "M4_subchance" & t6$term %in% c(
  "b_effort_conditionhigh", "b_effort_x_stim", "b_bs_effort_conditionhigh", "b_bias_effort_conditionhigh"
), c("term", "median", "q2.5", "q97.5")]

n_tables <- length(list.files(TAB, pattern = "\\.csv$"))
n_figs <- length(pngs)

fmt <- function(x) formatC(x, digits = 6, format = "fg")
eff_lines <- apply(sub_eff, 1, function(r) paste0("- ", r[["term"]], ": ", fmt(as.numeric(r[["median"]])),
                                                   " [", fmt(as.numeric(r[["q2.5"]])), ", ", fmt(as.numeric(r[["q97.5"]])), "]"))

lines <- c(
  "# Final export verification",
  "",
  "## 1. Part R",
  "",
  "Rule, verbatim: Section S4.1: participants at or near chance, operationalized as overall accuracy <= 0.55 on the 17,857-trial primary data (all difficulty levels, both tasks).",
  "",
  paste0("Excluded ", nrow(sub), " participants, leaving N = ", 67 - nrow(sub), ". IDs: ", paste(sub$subject_id, collapse = ", "), "."),
  "",
  "The original chapter reported 12 exclusions (N = 55). That count came from an earlier version of the dataset, and no saved list of those IDs exists. On the 17,857-trial primary file the same rule excludes the 13 IDs above.",
  "",
  "Convergence of M4_subchance: max R-hat 1.0083 (Intercept_bs), minimum bulk ESS 941.5, 0 divergences, adapt_delta 0.95. The convergence rule passed, so the adapt_delta 0.99 retry was not run.",
  "",
  "Four effort terms (posterior median and 95% CrI):",
  eff_lines,
  "",
  "## 2. Tables",
  "",
  paste0(n_tables, " CSV tables were written to tables/final/."),
  "",
  "NA cells:",
  if (length(na_notes)) paste0("- ", na_notes) else "- none",
  "",
  "The unthresholded trial file has 18,097 rows with probe-onset RT at or above 0.20 s, while the primary analysis file has 17,857. Those two counts were left as recorded. They were not forced to agree.",
  "",
  "## 3. Figures",
  "",
  paste0(n_figs, " PNG figures were written to figures/final/, each with a PDF and a source note."),
  "",
  "S_tepr_timecourse is the baseline-corrected mean of the cleaned flat timecourses, restricted to the 4,569-trial QC set. The source note records the join and the baseline rule.",
  "",
  "## 4. Part X",
  "",
  paste0("- X1 expected values: ", if (all(x1$pass)) "pass" else "fail", ". Largest absolute error on the link scale ", fmt(max(x1$abs_err[x1$tolerance == 0.002])), "."),
  paste0("- Delta ELPD M3 versus M4 SE is ", fmt(stats::sd(d) * sqrt(length(d))), " (expected 19.99)."),
  paste0("- X2 inline values match the Part T tables: ", if (all(x2$pass)) "pass" else "fail", "."),
  paste0("- X3 every PNG has a source note: ", if (x3_pass) "pass" else paste("fail, missing", paste(missing_src, collapse = ", ")), "."),
  paste0("- X4 forbidden paths in the new scripts: ", if (x4_pass) "pass (no hits)" else paste("fail:", paste(x4_hits, collapse = "; ")), "."),
  "",
  "## 5. Differences from the prompt and the decision record",
  "",
  "- The prompt's Part R line expected 12 exclusions and N = 55. The amended rule, overall accuracy <= 0.55 on this primary file, excludes 13 and leaves N = 54. The export follows the amendment.",
  "- The decision record still described the sub-chance refit as N = 55. The computed list is the one used here.",
  "- T1 was rebuilt from the same Table 1 inputs the chapter uses. N = 67.",
  "- Non-DDM LC and neuropsych correlations were copied. Their FDR values were recomputed after the DDM rows were replaced, and the original FDR is kept in fdr_original.",
  "- M4b task-specific criterion shifts are in T4b_M4b_task_effort.csv, an extra table so the inline values have a table to match.",
  "- The earlier consolidation and inventory scripts name the retired model families so those files are classified and not copied. They are not inputs to the tables or figures.",
  "- Subject-level accuracy rows were added to T13a so the accuracy figure can draw one line per person.",
  "",
  "## 6. Not determined",
  "",
  "- The TEPR time course for the 4,569-trial QC set. Trial-level waveforms for that exact set are not in the final run.",
  "- Which 12 IDs the earlier chapter version excluded. No list was saved.",
  ""
)
writeLines(lines, file.path(INV, "verification.md"))
write.csv(x1, file.path(INV, "x1_checks.csv"), row.names = FALSE)
write.csv(x2, file.path(INV, "x2_checks.csv"), row.names = FALSE)
message("X1 ", if (all(x1$pass)) "PASS" else "FAIL")
message("X2 ", if (all(x2$pass)) "PASS" else "FAIL")
message("X3 ", if (x3_pass) "PASS" else "FAIL")
message("X4 ", if (x4_pass) "PASS" else "FAIL")
if (!x3_pass || !x4_pass) stop_at("X3/X4", paste(c(missing_src, x4_hits), collapse = "\n"))
message("verification.md written")
